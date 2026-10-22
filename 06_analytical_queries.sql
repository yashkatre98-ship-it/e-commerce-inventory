-- ============================================================================
-- E-COMMERCE INVENTORY & ORDER MANAGEMENT SYSTEM (DBMS PROJECT)
-- Dialect: Microsoft SQL Server (T-SQL)
-- Script 06: Advanced Analytical SQL Queries
-- Includes: CTEs, Recursive Queries, Window Functions, ROLLUP & Aggregations
-- ============================================================================

USE EcommerceInventoryDB;
GO

-- ============================================================================
-- QUERY 1: Recursive CTE for Category Hierarchy
-- Traverses parent-to-child category trees and calculates nesting level & path.
-- ============================================================================
PRINT '--- Query 1: Recursive Category Hierarchy ---';
WITH CategoryHierarchy AS (
    -- Anchor member: top-level parent categories
    SELECT 
        category_id,
        category_name,
        parent_category_id,
        0 AS level_depth,
        CAST(category_name AS NVARCHAR(500)) AS category_path
    FROM dbo.Categories
    WHERE parent_category_id IS NULL

    UNION ALL

    -- Recursive member: child categories
    SELECT 
        c.category_id,
        c.category_name,
        c.parent_category_id,
        ch.level_depth + 1,
        CAST(ch.category_path + N' > ' + c.category_name AS NVARCHAR(500))
    FROM dbo.Categories c
    INNER JOIN CategoryHierarchy ch ON c.parent_category_id = ch.category_id
)
SELECT 
    category_id,
    REPLICATE(N'   ', level_depth) + category_name AS indented_category_name,
    level_depth,
    category_path
FROM CategoryHierarchy
ORDER BY category_path;
GO

-- ============================================================================
-- QUERY 2: Window Functions - Ranking Top Products Within Each Category
-- Uses DENSE_RANK() OVER (PARTITION BY category_id ORDER BY total_revenue DESC)
-- ============================================================================
PRINT '--- Query 2: Ranked Products by Category Sales ---';
WITH ProductSalesMetrics AS (
    SELECT 
        c.category_name,
        p.product_id,
        p.product_name,
        p.unit_price,
        COALESCE(SUM(oi.quantity), 0) AS total_units_sold,
        COALESCE(SUM(oi.line_total), 0.00) AS total_revenue
    FROM dbo.Products p
    INNER JOIN dbo.Categories c ON p.category_id = c.category_id
    LEFT JOIN dbo.Order_Items oi ON p.product_id = oi.product_id
    LEFT JOIN dbo.Orders o ON oi.order_id = o.order_id AND o.order_status <> N'CANCELLED'
    GROUP BY c.category_name, p.product_id, p.product_name, p.unit_price
)
SELECT 
    category_name,
    product_name,
    unit_price,
    total_units_sold,
    total_revenue,
    DENSE_RANK() OVER (
        PARTITION BY category_name 
        ORDER BY total_revenue DESC
    ) AS category_revenue_rank
FROM ProductSalesMetrics
ORDER BY category_name, category_revenue_rank;
GO

-- ============================================================================
-- QUERY 3: Cumulative Running Total & Moving Revenue
-- Uses SUM() OVER (ORDER BY order_date ROWS UNBOUNDED PRECEDING)
-- ============================================================================
PRINT '--- Query 3: Cumulative Running Sales Timeline ---';
SELECT 
    o.order_id,
    o.order_date,
    CONCAT(c.first_name, N' ', c.last_name) AS customer_name,
    o.total_amount AS current_order_amount,
    SUM(o.total_amount) OVER (
        ORDER BY o.order_date, o.order_id 
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_running_revenue,
    AVG(o.total_amount) OVER (
        ORDER BY o.order_date, o.order_id 
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS three_order_moving_avg
FROM dbo.Orders o
INNER JOIN dbo.Customers c ON o.customer_id = c.customer_id
WHERE o.order_status <> N'CANCELLED'
ORDER BY o.order_date;
GO

-- ============================================================================
-- QUERY 4: Month-over-Month Revenue Growth with LAG()
-- Analyzes sales trend, previous month revenue, and growth percentages.
-- ============================================================================
PRINT '--- Query 4: Month-over-Month Sales Growth ---';
WITH MonthlyAggregates AS (
    SELECT 
        FORMAT(order_date, N'yyyy-MM') AS sales_month,
        COUNT(order_id) AS order_volume,
        SUM(total_amount) AS current_month_revenue
    FROM dbo.Orders
    WHERE order_status <> N'CANCELLED'
    GROUP BY FORMAT(order_date, N'yyyy-MM')
)
SELECT 
    sales_month,
    order_volume,
    current_month_revenue,
    LAG(current_month_revenue, 1, NULL) OVER (ORDER BY sales_month) AS prior_month_revenue,
    ROUND(
        (current_month_revenue - LAG(current_month_revenue, 1, current_month_revenue) OVER (ORDER BY sales_month)) 
        / NULLIF(LAG(current_month_revenue, 1, NULL) OVER (ORDER BY sales_month), 0) * 100.0, 
        2
    ) AS mom_growth_pct
FROM MonthlyAggregates
ORDER BY sales_month;
GO

-- ============================================================================
-- QUERY 5: Multi-Level Dimensional Subtotals using GROUP BY ROLLUP
-- Calculates sales sub-totals across Supplier -> Category -> Product levels.
-- ============================================================================
PRINT '--- Query 5: Hierarchical Financial ROLLUP ---';
SELECT 
    COALESCE(s.company_name, N'[ALL SUPPLIERS]') AS supplier,
    COALESCE(c.category_name, N'[ALL CATEGORIES]') AS category,
    COALESCE(p.product_name, N'[ALL PRODUCTS]') AS product,
    COALESCE(SUM(oi.quantity), 0) AS total_quantity,
    COALESCE(SUM(oi.line_total), 0.00) AS total_revenue
FROM dbo.Suppliers s
INNER JOIN dbo.Products p ON s.supplier_id = p.supplier_id
INNER JOIN dbo.Categories c ON p.category_id = c.category_id
LEFT JOIN dbo.Order_Items oi ON p.product_id = oi.product_id
LEFT JOIN dbo.Orders o ON oi.order_id = o.order_id AND o.order_status <> N'CANCELLED'
GROUP BY ROLLUP(s.company_name, c.category_name, p.product_name)
ORDER BY s.company_name, c.category_name, p.product_name;
GO

-- ============================================================================
-- QUERY 6: Customer RFM Scoring (Recency, Frequency, Monetary)
-- Segments customers into tiers (VIP, Active, Occasional).
-- ============================================================================
PRINT '--- Query 6: Customer Segmentation & RFM Matrix ---';
WITH CustomerRFM AS (
    SELECT 
        c.customer_id,
        CONCAT(c.first_name, N' ', c.last_name) AS full_name,
        c.email,
        DATEDIFF(DAY, MAX(o.order_date), SYSUTCDATETIME()) AS recency_days,
        COUNT(o.order_id) AS frequency_orders,
        COALESCE(SUM(o.total_amount), 0.00) AS monetary_total_spent
    FROM dbo.Customers c
    LEFT JOIN dbo.Orders o ON c.customer_id = o.customer_id AND o.order_status <> N'CANCELLED'
    GROUP BY c.customer_id, c.first_name, c.last_name, c.email
)
SELECT 
    customer_id,
    full_name,
    email,
    recency_days,
    frequency_orders,
    monetary_total_spent,
    CASE 
        WHEN monetary_total_spent >= 2000.00 THEN N'TIER 1 (VIP)'
        WHEN monetary_total_spent >= 1000.00 THEN N'TIER 2 (REGULAR)'
        WHEN monetary_total_spent > 0.00     THEN N'TIER 3 (OCCASIONAL)'
        ELSE N'TIER 4 (PROSPECT / INACTIVE)'
    END AS customer_tier
FROM CustomerRFM
ORDER BY monetary_total_spent DESC;
GO

-- ============================================================================
-- QUERY 7: Cross-Warehouse Inventory Disparity & Rebalancing Analysis
-- Identifies items where one warehouse is overstocked while another is low.
-- ============================================================================
PRINT '--- Query 7: Warehouse Inventory Disbalance ---';
SELECT 
    p.product_id,
    p.sku,
    p.product_name,
    p.reorder_level,
    MAX(inv.quantity_on_hand) AS max_stock_in_any_wh,
    MIN(inv.quantity_on_hand) AS min_stock_in_any_wh,
    (MAX(inv.quantity_on_hand) - MIN(inv.quantity_on_hand)) AS warehouse_stock_delta,
    CASE 
        WHEN MIN(inv.quantity_on_hand) <= 2 AND MAX(inv.quantity_on_hand) >= 15 
        THEN N'RECOMMEND INTER-WAREHOUSE TRANSFER'
        ELSE N'BALANCED'
    END AS logistics_recommendation
FROM dbo.Products p
INNER JOIN dbo.Inventory inv ON p.product_id = inv.product_id
GROUP BY p.product_id, p.sku, p.product_name, p.reorder_level
HAVING (MAX(inv.quantity_on_hand) - MIN(inv.quantity_on_hand)) > 5
ORDER BY warehouse_stock_delta DESC;
GO

PRINT 'Analytical queries completed.';
GO

