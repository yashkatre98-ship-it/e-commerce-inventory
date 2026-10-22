-- ============================================================================
-- E-COMMERCE INVENTORY & ORDER MANAGEMENT SYSTEM (DBMS PROJECT)
-- Dialect: Microsoft SQL Server (T-SQL)
-- Script 04: Views (Analytics, Dashboards, Inventory Alerts & Financial Reports)
-- ============================================================================

USE EcommerceInventoryDB;
GO

-- ============================================================================
-- 1. VIEW: vw_ProductInventoryStock
-- Comprehensive stock overview across all warehouses with status badge.
-- ============================================================================
IF OBJECT_ID('dbo.vw_ProductInventoryStock', 'V') IS NOT NULL
    DROP VIEW dbo.vw_ProductInventoryStock;
GO

CREATE VIEW dbo.vw_ProductInventoryStock
AS
SELECT 
    p.product_id,
    p.sku,
    p.product_name,
    c.category_name,
    s.company_name AS supplier_name,
    p.unit_price,
    p.cost_price,
    (p.unit_price - p.cost_price) AS profit_margin_per_unit,
    p.reorder_level,
    w.warehouse_id,
    w.warehouse_name,
    COALESCE(inv.quantity_on_hand, 0) AS quantity_on_hand,
    COALESCE(inv.quantity_reserved, 0) AS quantity_reserved,
    (COALESCE(inv.quantity_on_hand, 0) - COALESCE(inv.quantity_reserved, 0)) AS quantity_available,
    CASE 
        WHEN COALESCE(inv.quantity_on_hand, 0) = 0 THEN N'OUT_OF_STOCK'
        WHEN COALESCE(inv.quantity_on_hand, 0) <= p.reorder_level THEN N'LOW_STOCK'
        ELSE N'IN_STOCK'
    END AS stock_status,
    inv.last_restocked_at,
    inv.last_updated_at
FROM dbo.Products p
INNER JOIN dbo.Categories c ON p.category_id = c.category_id
INNER JOIN dbo.Suppliers s ON p.supplier_id = s.supplier_id
CROSS JOIN dbo.Warehouses w
LEFT JOIN dbo.Inventory inv ON p.product_id = inv.product_id AND w.warehouse_id = inv.warehouse_id
WHERE p.is_active = 1 AND w.is_active = 1;
GO

-- ============================================================================
-- 2. VIEW: vw_LowStockAlerts
-- Critical operational view: Identifies products falling below reorder threshold
-- across the enterprise, together with vendor supplier contact info for purchase orders.
-- ============================================================================
IF OBJECT_ID('dbo.vw_LowStockAlerts', 'V') IS NOT NULL
    DROP VIEW dbo.vw_LowStockAlerts;
GO

CREATE VIEW dbo.vw_LowStockAlerts
AS
SELECT 
    p.product_id,
    p.sku,
    p.product_name,
    c.category_name,
    p.reorder_level,
    COALESCE(SUM(inv.quantity_on_hand), 0) AS total_network_stock,
    (p.reorder_level - COALESCE(SUM(inv.quantity_on_hand), 0)) AS units_shortfall,
    s.company_name AS supplier_name,
    s.contact_name AS supplier_contact,
    s.email AS supplier_email,
    s.phone AS supplier_phone,
    s.rating AS supplier_rating
FROM dbo.Products p
INNER JOIN dbo.Categories c ON p.category_id = c.category_id
INNER JOIN dbo.Suppliers s ON p.supplier_id = s.supplier_id
LEFT JOIN dbo.Inventory inv ON p.product_id = inv.product_id
WHERE p.is_active = 1
GROUP BY 
    p.product_id, p.sku, p.product_name, c.category_name, 
    p.reorder_level, s.company_name, s.contact_name, s.email, s.phone, s.rating
HAVING COALESCE(SUM(inv.quantity_on_hand), 0) <= p.reorder_level;
GO

-- ============================================================================
-- 3. VIEW: vw_OrderDetailsSummary
-- 360-degree view of customer orders, line counts, financials, payments, and shipping.
-- ============================================================================
IF OBJECT_ID('dbo.vw_OrderDetailsSummary', 'V') IS NOT NULL
    DROP VIEW dbo.vw_OrderDetailsSummary;
GO

CREATE VIEW dbo.vw_OrderDetailsSummary
AS
SELECT 
    o.order_id,
    o.order_date,
    o.order_status,
    c.customer_id,
    CONCAT(c.first_name, N' ', c.last_name) AS customer_name,
    c.email AS customer_email,
    c.phone AS customer_phone,
    COUNT(oi.order_item_id) AS total_distinct_items,
    COALESCE(SUM(oi.quantity), 0) AS total_units_ordered,
    o.subtotal,
    o.discount_amount,
    cp.coupon_code,
    o.tax_amount,
    o.shipping_fee,
    o.total_amount,
    pay.payment_method,
    pay.payment_status,
    pay.transaction_reference,
    sh.carrier_name,
    sh.tracking_number,
    sh.shipment_status,
    o.shipping_address
FROM dbo.Orders o
INNER JOIN dbo.Customers c ON o.customer_id = c.customer_id
LEFT JOIN dbo.Order_Items oi ON o.order_id = oi.order_id
LEFT JOIN dbo.Coupons cp ON o.coupon_id = cp.coupon_id
LEFT JOIN dbo.Payments pay ON o.order_id = pay.order_id
LEFT JOIN dbo.Shipments sh ON o.order_id = sh.order_id
GROUP BY 
    o.order_id, o.order_date, o.order_status, c.customer_id, c.first_name, c.last_name,
    c.email, c.phone, o.subtotal, o.discount_amount, cp.coupon_code, o.tax_amount, 
    o.shipping_fee, o.total_amount, pay.payment_method, pay.payment_status, 
    pay.transaction_reference, sh.carrier_name, sh.tracking_number, sh.shipment_status, o.shipping_address;
GO

-- ============================================================================
-- 4. VIEW: vw_WarehouseUtilization
-- Real-time capacity utilization analytics for physical logistics hubs.
-- ============================================================================
IF OBJECT_ID('dbo.vw_WarehouseUtilization', 'V') IS NOT NULL
    DROP VIEW dbo.vw_WarehouseUtilization;
GO

CREATE VIEW dbo.vw_WarehouseUtilization
AS
SELECT 
    w.warehouse_id,
    w.warehouse_name,
    w.city,
    w.state,
    w.capacity AS total_unit_capacity,
    COALESCE(SUM(inv.quantity_on_hand), 0) AS current_stock_count,
    (w.capacity - COALESCE(SUM(inv.quantity_on_hand), 0)) AS available_storage_capacity,
    ROUND(
        (CAST(COALESCE(SUM(inv.quantity_on_hand), 0) AS FLOAT) / CAST(w.capacity AS FLOAT)) * 100.0, 
        2
    ) AS capacity_occupancy_pct,
    COUNT(DISTINCT inv.product_id) AS distinct_products_stocked
FROM dbo.Warehouses w
LEFT JOIN dbo.Inventory inv ON w.warehouse_id = inv.warehouse_id
WHERE w.is_active = 1
GROUP BY w.warehouse_id, w.warehouse_name, w.city, w.state, w.capacity;
GO

-- ============================================================================
-- 5. VIEW: vw_MonthlySalesPerformance
-- Financial metrics grouped by calendar month.
-- ============================================================================
IF OBJECT_ID('dbo.vw_MonthlySalesPerformance', 'V') IS NOT NULL
    DROP VIEW dbo.vw_MonthlySalesPerformance;
GO

CREATE VIEW dbo.vw_MonthlySalesPerformance
AS
SELECT 
    YEAR(o.order_date) AS order_year,
    MONTH(o.order_date) AS order_month,
    DATENAME(MONTH, o.order_date) AS month_name,
    COUNT(o.order_id) AS total_orders,
    SUM(CASE WHEN o.order_status = N'DELIVERED' THEN 1 ELSE 0 END) AS delivered_orders,
    SUM(CASE WHEN o.order_status = N'CANCELLED' THEN 1 ELSE 0 END) AS cancelled_orders,
    SUM(CASE WHEN o.order_status <> N'CANCELLED' THEN o.subtotal ELSE 0 END) AS gross_merchandise_subtotal,
    SUM(CASE WHEN o.order_status <> N'CANCELLED' THEN o.discount_amount ELSE 0 END) AS total_discounts_granted,
    SUM(CASE WHEN o.order_status <> N'CANCELLED' THEN o.tax_amount ELSE 0 END) AS total_tax_collected,
    SUM(CASE WHEN o.order_status <> N'CANCELLED' THEN o.shipping_fee ELSE 0 END) AS total_shipping_revenue,
    SUM(CASE WHEN o.order_status <> N'CANCELLED' THEN o.total_amount ELSE 0 END) AS net_revenue
FROM dbo.Orders o
GROUP BY YEAR(o.order_date), MONTH(o.order_date), DATENAME(MONTH, o.order_date);
GO

-- ============================================================================
-- 6. VIEW: vw_TopSellingProducts
-- Ranks products by revenue, volume sold, and estimated profit earned.
-- ============================================================================
IF OBJECT_ID('dbo.vw_TopSellingProducts', 'V') IS NOT NULL
    DROP VIEW dbo.vw_TopSellingProducts;
GO

CREATE VIEW dbo.vw_TopSellingProducts
AS
SELECT 
    p.product_id,
    p.sku,
    p.product_name,
    c.category_name,
    p.unit_price,
    p.cost_price,
    COALESCE(SUM(oi.quantity), 0) AS total_units_sold,
    COALESCE(SUM(oi.line_total), 0.00) AS total_revenue_generated,
    COALESCE(SUM(oi.quantity * p.cost_price), 0.00) AS total_cogs,
    COALESCE(SUM(oi.line_total) - SUM(oi.quantity * p.cost_price), 0.00) AS total_gross_profit,
    CASE 
        WHEN SUM(oi.line_total) > 0 
        THEN ROUND(((SUM(oi.line_total) - SUM(oi.quantity * p.cost_price)) / SUM(oi.line_total)) * 100.0, 2)
        ELSE 0.00 
    END AS gross_profit_margin_pct
FROM dbo.Products p
INNER JOIN dbo.Categories c ON p.category_id = c.category_id
LEFT JOIN dbo.Order_Items oi ON p.product_id = oi.product_id
LEFT JOIN dbo.Orders o ON oi.order_id = o.order_id AND o.order_status <> N'CANCELLED'
GROUP BY p.product_id, p.sku, p.product_name, c.category_name, p.unit_price, p.cost_price;
GO

PRINT 'Reporting and Analytical Views created successfully.';
GO

