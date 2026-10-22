-- ============================================================================
-- E-COMMERCE INVENTORY & ORDER MANAGEMENT SYSTEM (DBMS PROJECT)
-- Dialect: Microsoft SQL Server (T-SQL)
-- Script 01: Database Creation, Tables, Constraints & Indexes (DDL)
-- ============================================================================

-- 1. Create Database if not exists
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'EcommerceInventoryDB')
BEGIN
    CREATE DATABASE EcommerceInventoryDB;
END
GO

USE EcommerceInventoryDB;
GO

-- Drop tables in reverse dependency order if rerunning
IF OBJECT_ID('dbo.Inventory_Audit_Log', 'U') IS NOT NULL DROP TABLE dbo.Inventory_Audit_Log;
IF OBJECT_ID('dbo.Order_Status_History', 'U') IS NOT NULL DROP TABLE dbo.Order_Status_History;
IF OBJECT_ID('dbo.Shipments', 'U') IS NOT NULL DROP TABLE dbo.Shipments;
IF OBJECT_ID('dbo.Payments', 'U') IS NOT NULL DROP TABLE dbo.Payments;
IF OBJECT_ID('dbo.Order_Items', 'U') IS NOT NULL DROP TABLE dbo.Order_Items;
IF OBJECT_ID('dbo.Orders', 'U') IS NOT NULL DROP TABLE dbo.Orders;
IF OBJECT_ID('dbo.Coupons', 'U') IS NOT NULL DROP TABLE dbo.Coupons;
IF OBJECT_ID('dbo.Stock_Transfers', 'U') IS NOT NULL DROP TABLE dbo.Stock_Transfers;
IF OBJECT_ID('dbo.Inventory', 'U') IS NOT NULL DROP TABLE dbo.Inventory;
IF OBJECT_ID('dbo.Warehouses', 'U') IS NOT NULL DROP TABLE dbo.Warehouses;
IF OBJECT_ID('dbo.Products', 'U') IS NOT NULL DROP TABLE dbo.Products;
IF OBJECT_ID('dbo.Categories', 'U') IS NOT NULL DROP TABLE dbo.Categories;
IF OBJECT_ID('dbo.Suppliers', 'U') IS NOT NULL DROP TABLE dbo.Suppliers;
IF OBJECT_ID('dbo.Customers', 'U') IS NOT NULL DROP TABLE dbo.Customers;
GO

-- ============================================================================
-- 1. SUPPLIERS TABLE
-- Stores vendor details providing inventory stock.
-- ============================================================================
CREATE TABLE dbo.Suppliers (
    supplier_id       INT IDENTITY(1001, 1) NOT NULL,
    company_name      NVARCHAR(150) NOT NULL,
    contact_name      NVARCHAR(100) NOT NULL,
    email             NVARCHAR(120) NOT NULL,
    phone             NVARCHAR(25) NOT NULL,
    address           NVARCHAR(200) NOT NULL,
    city              NVARCHAR(60) NOT NULL,
    country           NVARCHAR(60) NOT NULL DEFAULT N'USA',
    rating            DECIMAL(2, 1) NOT NULL DEFAULT 5.0,
    created_at        DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_Suppliers PRIMARY KEY (supplier_id),
    CONSTRAINT UQ_Suppliers_Company UNIQUE (company_name),
    CONSTRAINT UQ_Suppliers_Email UNIQUE (email),
    CONSTRAINT CHK_Suppliers_Rating CHECK (rating >= 1.0 AND rating <= 5.0),
    CONSTRAINT CHK_Suppliers_Email CHECK (email LIKE '%_@__%.__%')
);
GO

-- ============================================================================
-- 2. CATEGORIES TABLE
-- Hierarchical category structure (supports sub-categories via parent_id).
-- ============================================================================
CREATE TABLE dbo.Categories (
    category_id         INT IDENTITY(101, 1) NOT NULL,
    category_name       NVARCHAR(100) NOT NULL,
    description         NVARCHAR(255) NULL,
    parent_category_id  INT NULL,
    created_at          DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_Categories PRIMARY KEY (category_id),
    CONSTRAINT UQ_Categories_Name UNIQUE (category_name),
    CONSTRAINT FK_Categories_Parent FOREIGN KEY (parent_category_id)
        REFERENCES dbo.Categories(category_id) ON DELETE NO ACTION
);
GO

-- ============================================================================
-- 3. PRODUCTS TABLE
-- Catalog of items available for sale.
-- ============================================================================
CREATE TABLE dbo.Products (
    product_id        INT IDENTITY(1, 1) NOT NULL,
    sku               NVARCHAR(50) NOT NULL,
    product_name      NVARCHAR(150) NOT NULL,
    description       NVARCHAR(500) NULL,
    category_id       INT NOT NULL,
    supplier_id       INT NOT NULL,
    unit_price        DECIMAL(10, 2) NOT NULL,
    cost_price        DECIMAL(10, 2) NOT NULL,
    reorder_level     INT NOT NULL DEFAULT 10,
    is_active         BIT NOT NULL DEFAULT 1,
    created_at        DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_Products PRIMARY KEY (product_id),
    CONSTRAINT UQ_Products_SKU UNIQUE (sku),
    CONSTRAINT FK_Products_Category FOREIGN KEY (category_id)
        REFERENCES dbo.Categories(category_id),
    CONSTRAINT FK_Products_Supplier FOREIGN KEY (supplier_id)
        REFERENCES dbo.Suppliers(supplier_id),
    CONSTRAINT CHK_Products_Price CHECK (unit_price > 0),
    CONSTRAINT CHK_Products_Cost CHECK (cost_price > 0),
    CONSTRAINT CHK_Products_Margin CHECK (unit_price >= cost_price),
    CONSTRAINT CHK_Products_Reorder CHECK (reorder_level >= 0)
);
GO

-- ============================================================================
-- 4. WAREHOUSES TABLE
-- Physical locations where product stock is distributed and fulfilled.
-- ============================================================================
CREATE TABLE dbo.Warehouses (
    warehouse_id      INT IDENTITY(1, 1) NOT NULL,
    warehouse_name    NVARCHAR(100) NOT NULL,
    location_address  NVARCHAR(200) NOT NULL,
    city              NVARCHAR(60) NOT NULL,
    state             NVARCHAR(60) NOT NULL,
    postal_code       NVARCHAR(20) NOT NULL,
    capacity          INT NOT NULL,
    is_active         BIT NOT NULL DEFAULT 1,
    created_at        DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_Warehouses PRIMARY KEY (warehouse_id),
    CONSTRAINT UQ_Warehouses_Name UNIQUE (warehouse_name),
    CONSTRAINT CHK_Warehouses_Capacity CHECK (capacity > 0)
);
GO

-- ============================================================================
-- 5. INVENTORY TABLE
-- Multi-warehouse stock tracking for products.
-- Composite uniqueness on (product_id, warehouse_id).
-- ============================================================================
CREATE TABLE dbo.Inventory (
    inventory_id        INT IDENTITY(1, 1) NOT NULL,
    product_id          INT NOT NULL,
    warehouse_id        INT NOT NULL,
    quantity_on_hand    INT NOT NULL DEFAULT 0,
    quantity_reserved   INT NOT NULL DEFAULT 0,
    last_restocked_at   DATETIME2 NULL,
    last_updated_at     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_Inventory PRIMARY KEY (inventory_id),
    CONSTRAINT UQ_Inventory_Prod_WH UNIQUE (product_id, warehouse_id),
    CONSTRAINT FK_Inventory_Product FOREIGN KEY (product_id)
        REFERENCES dbo.Products(product_id) ON DELETE CASCADE,
    CONSTRAINT FK_Inventory_Warehouse FOREIGN KEY (warehouse_id)
        REFERENCES dbo.Warehouses(warehouse_id),
    CONSTRAINT CHK_Inventory_Qty CHECK (quantity_on_hand >= 0),
    CONSTRAINT CHK_Inventory_Reserved CHECK (quantity_reserved >= 0)
);
GO

-- ============================================================================
-- 6. STOCK_TRANSFERS TABLE
-- Tracks inter-warehouse stock rebalancing.
-- ============================================================================
CREATE TABLE dbo.Stock_Transfers (
    transfer_id        INT IDENTITY(1, 1) NOT NULL,
    product_id         INT NOT NULL,
    from_warehouse_id  INT NOT NULL,
    to_warehouse_id    INT NOT NULL,
    quantity           INT NOT NULL,
    transfer_status    NVARCHAR(20) NOT NULL DEFAULT N'COMPLETED',
    transfer_date      DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    notes              NVARCHAR(255) NULL,

    CONSTRAINT PK_Stock_Transfers PRIMARY KEY (transfer_id),
    CONSTRAINT FK_Transfers_Product FOREIGN KEY (product_id)
        REFERENCES dbo.Products(product_id),
    CONSTRAINT FK_Transfers_FromWH FOREIGN KEY (from_warehouse_id)
        REFERENCES dbo.Warehouses(warehouse_id),
    CONSTRAINT FK_Transfers_ToWH FOREIGN KEY (to_warehouse_id)
        REFERENCES dbo.Warehouses(warehouse_id),
    CONSTRAINT CHK_Transfers_Qty CHECK (quantity > 0),
    CONSTRAINT CHK_Transfers_DifferentWH CHECK (from_warehouse_id <> to_warehouse_id),
    CONSTRAINT CHK_Transfers_Status CHECK (transfer_status IN (N'PENDING', N'IN_TRANSIT', N'COMPLETED', N'CANCELLED'))
);
GO

-- ============================================================================
-- 7. CUSTOMERS TABLE
-- Registered users who place orders.
-- ============================================================================
CREATE TABLE dbo.Customers (
    customer_id        INT IDENTITY(5001, 1) NOT NULL,
    first_name         NVARCHAR(60) NOT NULL,
    last_name          NVARCHAR(60) NOT NULL,
    email              NVARCHAR(120) NOT NULL,
    phone              NVARCHAR(25) NOT NULL,
    address_line       NVARCHAR(150) NOT NULL,
    city               NVARCHAR(60) NOT NULL,
    state              NVARCHAR(60) NOT NULL,
    postal_code        NVARCHAR(20) NOT NULL,
    country            NVARCHAR(60) NOT NULL DEFAULT N'USA',
    loyalty_points     INT NOT NULL DEFAULT 0,
    created_at         DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_Customers PRIMARY KEY (customer_id),
    CONSTRAINT UQ_Customers_Email UNIQUE (email),
    CONSTRAINT CHK_Customers_Email CHECK (email LIKE '%_@__%.__%'),
    CONSTRAINT CHK_Customers_Loyalty CHECK (loyalty_points >= 0)
);
GO

-- ============================================================================
-- 8. COUPONS TABLE
-- Promotion engine supporting flat and percentage-based discounts.
-- ============================================================================
CREATE TABLE dbo.Coupons (
    coupon_id          INT IDENTITY(1, 1) NOT NULL,
    coupon_code        NVARCHAR(30) NOT NULL,
    discount_type      NVARCHAR(20) NOT NULL, -- 'PERCENTAGE' or 'FIXED_AMOUNT'
    discount_value     DECIMAL(10, 2) NOT NULL,
    min_order_amount   DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    max_discount_amount DECIMAL(10, 2) NULL,
    valid_from         DATETIME2 NOT NULL,
    valid_to           DATETIME2 NOT NULL,
    usage_limit        INT NOT NULL DEFAULT 1000,
    times_used         INT NOT NULL DEFAULT 0,
    is_active          BIT NOT NULL DEFAULT 1,

    CONSTRAINT PK_Coupons PRIMARY KEY (coupon_id),
    CONSTRAINT UQ_Coupons_Code UNIQUE (coupon_code),
    CONSTRAINT CHK_Coupons_Type CHECK (discount_type IN (N'PERCENTAGE', N'FIXED_AMOUNT')),
    CONSTRAINT CHK_Coupons_Value CHECK (discount_value > 0),
    CONSTRAINT CHK_Coupons_Dates CHECK (valid_to >= valid_from),
    CONSTRAINT CHK_Coupons_Usage CHECK (times_used <= usage_limit)
);
GO

-- ============================================================================
-- 9. ORDERS TABLE
-- High-level purchase record with financial calculations & status tracking.
-- ============================================================================
CREATE TABLE dbo.Orders (
    order_id           INT IDENTITY(10001, 1) NOT NULL,
    customer_id        INT NOT NULL,
    order_date         DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    order_status       NVARCHAR(30) NOT NULL DEFAULT N'PENDING',
    subtotal           DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    discount_amount    DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    tax_amount         DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    shipping_fee       DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    total_amount       DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    coupon_id          INT NULL,
    shipping_address   NVARCHAR(300) NOT NULL,
    notes              NVARCHAR(255) NULL,

    CONSTRAINT PK_Orders PRIMARY KEY (order_id),
    CONSTRAINT FK_Orders_Customer FOREIGN KEY (customer_id)
        REFERENCES dbo.Customers(customer_id),
    CONSTRAINT FK_Orders_Coupon FOREIGN KEY (coupon_id)
        REFERENCES dbo.Coupons(coupon_id),
    CONSTRAINT CHK_Orders_Status CHECK (order_status IN (N'PENDING', N'CONFIRMED', N'PROCESSING', N'SHIPPED', N'DELIVERED', N'CANCELLED')),
    CONSTRAINT CHK_Orders_Subtotal CHECK (subtotal >= 0),
    CONSTRAINT CHK_Orders_Discount CHECK (discount_amount >= 0),
    CONSTRAINT CHK_Orders_Tax CHECK (tax_amount >= 0),
    CONSTRAINT CHK_Orders_Total CHECK (total_amount >= 0)
);
GO

-- ============================================================================
-- 10. ORDER_ITEMS TABLE
-- Line items inside an order, pinpointed to fulfillment warehouse.
-- ============================================================================
CREATE TABLE dbo.Order_Items (
    order_item_id      INT IDENTITY(1, 1) NOT NULL,
    order_id           INT NOT NULL,
    product_id         INT NOT NULL,
    warehouse_id       INT NOT NULL,
    quantity           INT NOT NULL,
    unit_price         DECIMAL(10, 2) NOT NULL,
    line_total         DECIMAL(12, 2) NOT NULL,

    CONSTRAINT PK_Order_Items PRIMARY KEY (order_item_id),
    CONSTRAINT UQ_Order_Item_Line UNIQUE (order_id, product_id, warehouse_id),
    CONSTRAINT FK_OrderItems_Order FOREIGN KEY (order_id)
        REFERENCES dbo.Orders(order_id) ON DELETE CASCADE,
    CONSTRAINT FK_OrderItems_Product FOREIGN KEY (product_id)
        REFERENCES dbo.Products(product_id),
    CONSTRAINT FK_OrderItems_Warehouse FOREIGN KEY (warehouse_id)
        REFERENCES dbo.Warehouses(warehouse_id),
    CONSTRAINT CHK_OrderItems_Qty CHECK (quantity > 0),
    CONSTRAINT CHK_OrderItems_Price CHECK (unit_price >= 0),
    CONSTRAINT CHK_OrderItems_Total CHECK (line_total >= 0)
);
GO

-- ============================================================================
-- 11. PAYMENTS TABLE
-- Captures payment methods, status, and external transaction IDs.
-- ============================================================================
CREATE TABLE dbo.Payments (
    payment_id             INT IDENTITY(1, 1) NOT NULL,
    order_id               INT NOT NULL,
    payment_date           DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    payment_method         NVARCHAR(30) NOT NULL,
    payment_status         NVARCHAR(20) NOT NULL DEFAULT N'PENDING',
    amount                 DECIMAL(12, 2) NOT NULL,
    transaction_reference  NVARCHAR(100) NOT NULL,

    CONSTRAINT PK_Payments PRIMARY KEY (payment_id),
    CONSTRAINT UQ_Payments_TxRef UNIQUE (transaction_reference),
    CONSTRAINT FK_Payments_Order FOREIGN KEY (order_id)
        REFERENCES dbo.Orders(order_id),
    CONSTRAINT CHK_Payments_Method CHECK (payment_method IN (N'CREDIT_CARD', N'DEBIT_CARD', N'UPI', N'NET_BANKING', N'CASH_ON_DELIVERY', N'PAYPAL')),
    CONSTRAINT CHK_Payments_Status CHECK (payment_status IN (N'PENDING', N'COMPLETED', N'FAILED', N'REFUNDED')),
    CONSTRAINT CHK_Payments_Amount CHECK (amount > 0)
);
GO

-- ============================================================================
-- 12. SHIPMENTS TABLE
-- Logistics and delivery tracking per order.
-- ============================================================================
CREATE TABLE dbo.Shipments (
    shipment_id        INT IDENTITY(1, 1) NOT NULL,
    order_id           INT NOT NULL,
    warehouse_id       INT NOT NULL,
    carrier_name       NVARCHAR(60) NOT NULL,
    tracking_number    NVARCHAR(100) NOT NULL,
    shipment_status    NVARCHAR(30) NOT NULL DEFAULT N'PREPARING',
    shipped_date       DATETIME2 NULL,
    delivered_date     DATETIME2 NULL,

    CONSTRAINT PK_Shipments PRIMARY KEY (shipment_id),
    CONSTRAINT UQ_Shipments_Tracking UNIQUE (tracking_number),
    CONSTRAINT FK_Shipments_Order FOREIGN KEY (order_id)
        REFERENCES dbo.Orders(order_id),
    CONSTRAINT FK_Shipments_Warehouse FOREIGN KEY (warehouse_id)
        REFERENCES dbo.Warehouses(warehouse_id),
    CONSTRAINT CHK_Shipments_Status CHECK (shipment_status IN (N'PREPARING', N'IN_TRANSIT', N'OUT_FOR_DELIVERY', N'DELIVERED', N'RETURNED'))
);
GO

-- ============================================================================
-- 13. ORDER_STATUS_HISTORY TABLE (AUDIT TRAIL)
-- Automatically records every state transition of an order.
-- ============================================================================
CREATE TABLE dbo.Order_Status_History (
    history_id         INT IDENTITY(1, 1) NOT NULL,
    order_id           INT NOT NULL,
    old_status         NVARCHAR(30) NULL,
    new_status         NVARCHAR(30) NOT NULL,
    changed_at         DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    changed_by         NVARCHAR(60) NOT NULL DEFAULT N'SYSTEM',
    notes              NVARCHAR(255) NULL,

    CONSTRAINT PK_Order_Status_History PRIMARY KEY (history_id),
    CONSTRAINT FK_StatusHistory_Order FOREIGN KEY (order_id)
        REFERENCES dbo.Orders(order_id) ON DELETE CASCADE
);
GO

-- ============================================================================
-- 14. INVENTORY_AUDIT_LOG TABLE (AUDIT TRAIL)
-- Detailed ledger for every quantity addition, deduction, transfer, or restore.
-- ============================================================================
CREATE TABLE dbo.Inventory_Audit_Log (
    audit_id           BIGINT IDENTITY(1, 1) NOT NULL,
    product_id         INT NOT NULL,
    warehouse_id       INT NOT NULL,
    change_type        NVARCHAR(30) NOT NULL,
    quantity_change    INT NOT NULL,
    previous_quantity  INT NOT NULL,
    new_quantity       INT NOT NULL,
    reference_id       INT NULL, -- e.g. order_id or transfer_id
    logged_at          DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    logged_by          NVARCHAR(60) NOT NULL DEFAULT N'SYSTEM',

    CONSTRAINT PK_Inventory_Audit_Log PRIMARY KEY (audit_id),
    CONSTRAINT FK_InvAudit_Product FOREIGN KEY (product_id)
        REFERENCES dbo.Products(product_id),
    CONSTRAINT FK_InvAudit_Warehouse FOREIGN KEY (warehouse_id)
        REFERENCES dbo.Warehouses(warehouse_id),
    CONSTRAINT CHK_InvAudit_ChangeType CHECK (change_type IN (
        N'ORDER_DEDUCT', N'RESTOCK', N'TRANSFER_IN', N'TRANSFER_OUT',
        N'ORDER_CANCEL_RESTORE', N'MANUAL_ADJUSTMENT'
    ))
);
GO

-- ============================================================================
-- 15. PERFORMANCE INDEXES
-- Non-clustered indexes optimizing foreign key joins and analytical queries.
-- ============================================================================
CREATE NONCLUSTERED INDEX IX_Products_Category ON dbo.Products(category_id);
CREATE NONCLUSTERED INDEX IX_Products_Supplier ON dbo.Products(supplier_id);
CREATE NONCLUSTERED INDEX IX_Inventory_Product_WH ON dbo.Inventory(product_id, warehouse_id);
CREATE NONCLUSTERED INDEX IX_Orders_Customer ON dbo.Orders(customer_id);
CREATE NONCLUSTERED INDEX IX_Orders_Status_Date ON dbo.Orders(order_status, order_date);
CREATE NONCLUSTERED INDEX IX_OrderItems_Order ON dbo.Order_Items(order_id);
CREATE NONCLUSTERED INDEX IX_OrderItems_Product ON dbo.Order_Items(product_id);
CREATE NONCLUSTERED INDEX IX_Payments_Order ON dbo.Payments(order_id);
CREATE NONCLUSTERED INDEX IX_Shipments_Order ON dbo.Shipments(order_id);
CREATE NONCLUSTERED INDEX IX_InvAudit_Product ON dbo.Inventory_Audit_Log(product_id, logged_at);
GO

PRINT 'Schema DDL created successfully with 14 tables, constraints, and indexes.';
GO

