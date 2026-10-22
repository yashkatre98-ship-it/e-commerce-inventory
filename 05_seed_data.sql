-- ============================================================================
-- E-COMMERCE INVENTORY & ORDER MANAGEMENT SYSTEM (DBMS PROJECT)
-- Dialect: Microsoft SQL Server (T-SQL)
-- Script 05: Realistic Seed Data (DML)
-- ============================================================================

USE EcommerceInventoryDB;
GO

-- Temporarily disable constraint checks during mass seeding
EXEC sp_MSforeachtable "ALTER TABLE ? NOCHECK CONSTRAINT all";
GO

-- Clean existing data
DELETE FROM dbo.Inventory_Audit_Log;
DELETE FROM dbo.Order_Status_History;
DELETE FROM dbo.Shipments;
DELETE FROM dbo.Payments;
DELETE FROM dbo.Order_Items;
DELETE FROM dbo.Orders;
DELETE FROM dbo.Coupons;
DELETE FROM dbo.Stock_Transfers;
DELETE FROM dbo.Inventory;
DELETE FROM dbo.Warehouses;
DELETE FROM dbo.Products;
DELETE FROM dbo.Categories;
DELETE FROM dbo.Suppliers;
DELETE FROM dbo.Customers;
GO

-- Re-enable constraints
EXEC sp_MSforeachtable "ALTER TABLE ? WITH CHECK CHECK CONSTRAINT all";
GO

-- Reseed identity values
DBCC CHECKIDENT ('dbo.Suppliers', RESEED, 1000);
DBCC CHECKIDENT ('dbo.Categories', RESEED, 100);
DBCC CHECKIDENT ('dbo.Products', RESEED, 0);
DBCC CHECKIDENT ('dbo.Warehouses', RESEED, 0);
DBCC CHECKIDENT ('dbo.Inventory', RESEED, 0);
DBCC CHECKIDENT ('dbo.Stock_Transfers', RESEED, 0);
DBCC CHECKIDENT ('dbo.Customers', RESEED, 5000);
DBCC CHECKIDENT ('dbo.Coupons', RESEED, 0);
DBCC CHECKIDENT ('dbo.Orders', RESEED, 10000);
DBCC CHECKIDENT ('dbo.Order_Items', RESEED, 0);
DBCC CHECKIDENT ('dbo.Payments', RESEED, 0);
DBCC CHECKIDENT ('dbo.Shipments', RESEED, 0);
DBCC CHECKIDENT ('dbo.Order_Status_History', RESEED, 0);
DBCC CHECKIDENT ('dbo.Inventory_Audit_Log', RESEED, 0);
GO

-- ============================================================================
-- 1. SEED SUPPLIERS
-- ============================================================================
INSERT INTO dbo.Suppliers (company_name, contact_name, email, phone, address, city, country, rating)
VALUES 
    (N'Apex Electronics Global', N'Marcus Vance', N'marcus@apexelectronics.com', N'+1-555-0101', N'400 Silicon Way', N'San Jose', N'USA', 4.9),
    (N'OmniTech Components Inc.', N'Elena Rostova', N'elena@omnitech.com', N'+1-555-0102', N'88 Precision Blvd', N'Austin', N'USA', 4.7),
    (N'Nexus Logistics & Supply', N'David Kim', N'david.kim@nexussupply.com', N'+1-555-0103', N'12 Logistics Way', N'Seattle', N'USA', 4.5),
    (N'PureSound Audio Labs', N'Sarah Jenkins', N'sarah@puresound.com', N'+1-555-0104', N'55 Acoustic Park', N'Boston', N'USA', 4.8),
    (N'ErgoPro Office Innovations', N'Tariq Mansoor', N'tariq@ergopro.com', N'+1-555-0105', N'710 Comfort Drive', N'Chicago', N'USA', 4.6);
GO

-- ============================================================================
-- 2. SEED CATEGORIES (Hierarchical parent & child)
-- ============================================================================
-- Parent categories
INSERT INTO dbo.Categories (category_name, description, parent_category_id)
VALUES 
    (N'Computers & Laptops', N'Desktop towers, laptops, ultrabooks, and workstations', NULL),    -- id 101
    (N'Audio & Sound', N'Headphones, speakers, studio microphones, and DACs', NULL),            -- id 102
    (N'Office & Ergonomics', N'Desks, ergonomic chairs, monitor arms, and accessories', NULL),   -- id 103
    (N'Computer Peripherals', N'Keyboards, mice, monitors, and webcams', NULL);                 -- id 104

-- Sub-categories
INSERT INTO dbo.Categories (category_name, description, parent_category_id)
VALUES 
    (N'Gaming Laptops', N'High performance GPUs and gaming portability', 101),                  -- id 105
    (N'Wireless Audio', N'Bluetooth active noise cancellation headphones and earbuds', 102),     -- id 106
    (N'Standing Desks', N'Motorized and dual-motor height adjustable work tables', 103),        -- id 107
    (N'Mechanical Keyboards', N'Custom hot-swappable tactile and linear mechanical decks', 104); -- id 108
GO

-- ============================================================================
-- 3. SEED PRODUCTS
-- ============================================================================
INSERT INTO dbo.Products (sku, product_name, description, category_id, supplier_id, unit_price, cost_price, reorder_level, is_active)
VALUES 
    (N'LAP-ROG-001', N'Asus ROG Zephyrus G16', N'16-inch OLED 240Hz, Core Ultra 9, RTX 4080, 32GB RAM', 105, 1001, 2499.99, 1850.00, 5, 1),
    (N'LAP-MBA-002', N'Apple MacBook Air M3', N'13.6-inch Liquid Retina, 16GB Unified Memory, 512GB SSD', 101, 1001, 1299.00, 980.00, 8, 1),
    (N'AUD-SNY-003', N'Sony WH-1000XM5 Wireless', N'Industry leading noise canceling over-ear headphones', 106, 1004, 398.00, 240.00, 15, 1),
    (N'AUD-APP-004', N'Apple AirPods Pro 2nd Gen', N'Active noise cancellation, USB-C MagSafe case', 106, 1001, 249.00, 165.00, 20, 1),
    (N'DKS-ERG-005', N'ErgoPro Apex Standing Desk', N'Dual motor 60x30 inch solid oak height-adjustable desk', 107, 1005, 680.00, 410.00, 6, 1),
    (N'CHR-ERG-006', N'AeroMesh Ergonomic Task Chair', N'Full lumbar adjustment, 4D armrests, breathable mesh', 103, 1005, 450.00, 260.00, 10, 1),
    (N'KBD-KEY-007', N'Keychron Q1 Pro Wireless Custom', N'Full CNC aluminum 75% mechanical keyboard with switches', 108, 1002, 199.00, 115.00, 12, 1),
    (N'MOU-LOG-008', N'Logitech MX Master 3S', N'Performance wireless mouse with quiet clicks and 8K DPI sensor', 104, 1002, 99.99, 58.00, 25, 1),
    (N'MON-DEL-009', N'Dell UltraSharp 32-inch 4K', N'IPS Black technology, USB-C 90W power delivery, 98% DCI-P3', 104, 1003, 749.50, 480.00, 7, 1),
    (N'CAM-LOG-010', N'Logitech Brio 4K Webcam', N'Ultra 4K HD webcam with HDR and Windows Hello facial recognition', 104, 1003, 169.99, 95.00, 10, 1);
GO

-- ============================================================================
-- 4. SEED WAREHOUSES
-- ============================================================================
INSERT INTO dbo.Warehouses (warehouse_name, location_address, city, state, postal_code, capacity, is_active)
VALUES 
    (N'West Coast Fulfillment Hub', N'1000 Harbor Gateway', N'Long Beach', N'CA', N'90802', 50000, 1),
    (N'East Coast Distribution Center', N'550 Meadowlands Pkwy', N'Secaucus', N'NJ', N'07094', 45000, 1),
    (N'Central Midwest Logistics Center', N'300 O Hare Logistics Way', N'Chicago', N'IL', N'60666', 35000, 1);
GO

-- ============================================================================
-- 5. SEED INVENTORY LEVELS (Across 3 Warehouses)
-- Notice some items have healthy stock, and some are below reorder level.
-- ============================================================================
INSERT INTO dbo.Inventory (product_id, warehouse_id, quantity_on_hand, quantity_reserved, last_restocked_at)
VALUES 
    -- Product 1: Asus ROG Zephyrus G16 (Reorder Level = 5)
    (1, 1, 15, 2, DATEADD(DAY, -10, SYSUTCDATETIME())),
    (1, 2, 8,  0, DATEADD(DAY, -14, SYSUTCDATETIME())),
    (1, 3, 3,  0, DATEADD(DAY, -20, SYSUTCDATETIME())),

    -- Product 2: Apple MacBook Air M3 (Reorder Level = 8)
    (2, 1, 25, 1, DATEADD(DAY, -5, SYSUTCDATETIME())),
    (2, 2, 18, 0, DATEADD(DAY, -7, SYSUTCDATETIME())),
    (2, 3, 12, 0, DATEADD(DAY, -15, SYSUTCDATETIME())),

    -- Product 3: Sony WH-1000XM5 (Reorder Level = 15)
    (3, 1, 40, 3, DATEADD(DAY, -3, SYSUTCDATETIME())),
    (3, 2, 30, 2, DATEADD(DAY, -6, SYSUTCDATETIME())),
    (3, 3, 20, 0, DATEADD(DAY, -12, SYSUTCDATETIME())),

    -- Product 4: Apple AirPods Pro (Reorder Level = 20)
    (4, 1, 60, 5, DATEADD(DAY, -2, SYSUTCDATETIME())),
    (4, 2, 55, 4, DATEADD(DAY, -4, SYSUTCDATETIME())),
    (4, 3, 40, 0, DATEADD(DAY, -8, SYSUTCDATETIME())),

    -- Product 5: ErgoPro Apex Standing Desk (Reorder Level = 6) -> Low Stock intentional!
    (5, 1, 2,  0, DATEADD(DAY, -30, SYSUTCDATETIME())),
    (5, 2, 1,  0, DATEADD(DAY, -28, SYSUTCDATETIME())),
    (5, 3, 1,  0, DATEADD(DAY, -35, SYSUTCDATETIME())),

    -- Product 6: AeroMesh Ergonomic Task Chair (Reorder Level = 10)
    (6, 1, 14, 1, DATEADD(DAY, -12, SYSUTCDATETIME())),
    (6, 2, 10, 0, DATEADD(DAY, -15, SYSUTCDATETIME())),
    (6, 3, 8,  0, DATEADD(DAY, -18, SYSUTCDATETIME())),

    -- Product 7: Keychron Q1 Pro (Reorder Level = 12)
    (7, 1, 22, 0, DATEADD(DAY, -9, SYSUTCDATETIME())),
    (7, 2, 15, 0, DATEADD(DAY, -11, SYSUTCDATETIME())),
    (7, 3, 9,  0, DATEADD(DAY, -22, SYSUTCDATETIME())),

    -- Product 8: Logitech MX Master 3S (Reorder Level = 25)
    (8, 1, 80, 4, DATEADD(DAY, -1, SYSUTCDATETIME())),
    (8, 2, 70, 2, DATEADD(DAY, -3, SYSUTCDATETIME())),
    (8, 3, 45, 0, DATEADD(DAY, -5, SYSUTCDATETIME())),

    -- Product 9: Dell UltraSharp 32-inch 4K (Reorder Level = 7) -> Near threshold
    (9, 1, 4,  0, DATEADD(DAY, -25, SYSUTCDATETIME())),
    (9, 2, 2,  0, DATEADD(DAY, -30, SYSUTCDATETIME())),
    (9, 3, 0,  0, DATEADD(DAY, -40, SYSUTCDATETIME())),

    -- Product 10: Logitech Brio 4K Webcam (Reorder Level = 10)
    (10, 1, 18, 0, DATEADD(DAY, -8, SYSUTCDATETIME())),
    (10, 2, 14, 0, DATEADD(DAY, -10, SYSUTCDATETIME())),
    (10, 3, 12, 0, DATEADD(DAY, -16, SYSUTCDATETIME()));
GO

-- ============================================================================
-- 6. SEED CUSTOMERS
-- ============================================================================
INSERT INTO dbo.Customers (first_name, last_name, email, phone, address_line, city, state, postal_code, loyalty_points)
VALUES 
    (N'Alexander', N'Wright', N'alex.wright@example.com', N'+1-555-0201', N'742 Evergreen Terrace', N'Springfield', N'OR', N'97477', 150),
    (N'Sophia', N'Chen', N'sophia.chen@techcorp.io', N'+1-555-0202', N'120 Mission Street, Apt 14B', N'San Francisco', N'CA', N'94105', 380),
    (N'Liam', N'O''Connor', N'liam.oc@domain.com', N'+1-555-0203', N'45 Beacon Hill Rd', N'Boston', N'MA', N'02108', 95),
    (N'Maya', N'Patel', N'maya.patel@designstudio.net', N'+1-555-0204', N'880 North Michigan Ave', N'Chicago', N'IL', N'60611', 520),
    (N'Jordan', N'Taylor', N'jordan.taylor@freelance.org', N'+1-555-0205', N'1600 Amphitheatre Pkwy', N'Mountain View', N'CA', N'94043', 45);
GO

-- ============================================================================
-- 7. SEED COUPONS
-- ============================================================================
INSERT INTO dbo.Coupons (coupon_code, discount_type, discount_value, min_order_amount, max_discount_amount, valid_from, valid_to, usage_limit, times_used, is_active)
VALUES 
    (N'WELCOME10', N'PERCENTAGE', 10.00, 100.00, 50.00, DATEADD(MONTH, -6, SYSUTCDATETIME()), DATEADD(MONTH, 6, SYSUTCDATETIME()), 1000, 42, 1),
    (N'TECHSAVE50', N'FIXED_AMOUNT', 50.00, 500.00, 50.00, DATEADD(MONTH, -2, SYSUTCDATETIME()), DATEADD(MONTH, 4, SYSUTCDATETIME()), 500, 18, 1),
    (N'VIP20', N'PERCENTAGE', 20.00, 1000.00, 200.00, DATEADD(MONTH, -1, SYSUTCDATETIME()), DATEADD(MONTH, 3, SYSUTCDATETIME()), 100, 9, 1),
    (N'SUMMER25', N'PERCENTAGE', 25.00, 250.00, 75.00, DATEADD(MONTH, -5, SYSUTCDATETIME()), DATEADD(MONTH, -1, SYSUTCDATETIME()), 200, 200, 0); -- Expired
GO

-- ============================================================================
-- 8. SEED ORDERS, ORDER ITEMS, PAYMENTS & SHIPMENTS (Historical Data)
-- ============================================================================
-- Order 10001: Completed & Delivered
INSERT INTO dbo.Orders (order_id, customer_id, order_date, order_status, subtotal, discount_amount, tax_amount, shipping_fee, total_amount, coupon_id, shipping_address)
VALUES (10001, 5001, DATEADD(DAY, -18, SYSUTCDATETIME()), N'DELIVERED', 1697.00, 50.00, 131.76, 0.00, 1778.76, 1, N'742 Evergreen Terrace, Springfield, OR 97477');

INSERT INTO dbo.Order_Items (order_id, product_id, warehouse_id, quantity, unit_price, line_total)
VALUES 
    (10001, 2, 1, 1, 1299.00, 1299.00), -- MacBook Air M3
    (10001, 3, 1, 1, 398.00, 398.00);    -- Sony WH-1000XM5

INSERT INTO dbo.Payments (order_id, payment_date, payment_method, payment_status, amount, transaction_reference)
VALUES (10001, DATEADD(DAY, -18, SYSUTCDATETIME()), N'CREDIT_CARD', N'COMPLETED', 1778.76, N'TXN-20261004-10001');

INSERT INTO dbo.Shipments (order_id, warehouse_id, carrier_name, tracking_number, shipment_status, shipped_date, delivered_date)
VALUES (10001, 1, N'FedEx Express', N'FDX-99823411', N'DELIVERED', DATEADD(DAY, -17, SYSUTCDATETIME()), DATEADD(DAY, -15, SYSUTCDATETIME()));

-- Order 10002: In Transit / Shipped
INSERT INTO dbo.Orders (order_id, customer_id, order_date, order_status, subtotal, discount_amount, tax_amount, shipping_fee, total_amount, coupon_id, shipping_address)
VALUES (10002, 5002, DATEADD(DAY, -3, SYSUTCDATETIME()), N'SHIPPED', 2698.99, 200.00, 199.92, 15.00, 2713.91, 3, N'120 Mission Street, Apt 14B, San Francisco, CA 94105');

INSERT INTO dbo.Order_Items (order_id, product_id, warehouse_id, quantity, unit_price, line_total)
VALUES 
    (10002, 1, 1, 1, 2499.99, 2499.99), -- ROG Zephyrus
    (10002, 7, 1, 1, 199.00, 199.00);    -- Keychron Q1

INSERT INTO dbo.Payments (order_id, payment_date, payment_method, payment_status, amount, transaction_reference)
VALUES (10002, DATEADD(DAY, -3, SYSUTCDATETIME()), N'NET_BANKING', N'COMPLETED', 2713.91, N'TXN-20261019-10002');

INSERT INTO dbo.Shipments (order_id, warehouse_id, carrier_name, tracking_number, shipment_status, shipped_date, delivered_date)
VALUES (10002, 1, N'UPS Next Day', N'1Z-9988776655', N'IN_TRANSIT', DATEADD(DAY, -2, SYSUTCDATETIME()), NULL);

-- Order 10003: Confirmed / Processing
INSERT INTO dbo.Orders (order_id, customer_id, order_date, order_status, subtotal, discount_amount, tax_amount, shipping_fee, total_amount, coupon_id, shipping_address)
VALUES (10003, 5004, DATEADD(DAY, -1, SYSUTCDATETIME()), N'PROCESSING', 1130.00, 50.00, 86.40, 25.00, 1191.40, 2, N'880 North Michigan Ave, Chicago, IL 60611');

INSERT INTO dbo.Order_Items (order_id, product_id, warehouse_id, quantity, unit_price, line_total)
VALUES 
    (10003, 5, 3, 1, 680.00, 680.00), -- Standing Desk
    (10003, 6, 3, 1, 450.00, 450.00); -- Task Chair

INSERT INTO dbo.Payments (order_id, payment_date, payment_method, payment_status, amount, transaction_reference)
VALUES (10003, DATEADD(DAY, -1, SYSUTCDATETIME()), N'CREDIT_CARD', N'COMPLETED', 1191.40, N'TXN-20261021-10003');

INSERT INTO dbo.Shipments (order_id, warehouse_id, carrier_name, tracking_number, shipment_status, shipped_date, delivered_date)
VALUES (10003, 3, N'DHL Express', N'DHL-443322110', N'PREPARING', NULL, NULL);

-- Order 10004: Cancelled Order
INSERT INTO dbo.Orders (order_id, customer_id, order_date, order_status, subtotal, discount_amount, tax_amount, shipping_fee, total_amount, coupon_id, shipping_address, notes)
VALUES (10004, 5003, DATEADD(DAY, -8, SYSUTCDATETIME()), N'CANCELLED', 269.98, 0.00, 21.60, 10.00, 301.58, NULL, N'45 Beacon Hill Rd, Boston, MA 02108', N'Cancelled by customer before dispatch');

INSERT INTO dbo.Order_Items (order_id, product_id, warehouse_id, quantity, unit_price, line_total)
VALUES 
    (10004, 8, 2, 1, 99.99, 99.99),   -- MX Master Mouse
    (10004, 10, 2, 1, 169.99, 169.99); -- Brio Webcam

INSERT INTO dbo.Payments (order_id, payment_date, payment_method, payment_status, amount, transaction_reference)
VALUES (10004, DATEADD(DAY, -8, SYSUTCDATETIME()), N'PAYPAL', N'REFUNDED', 301.58, N'TXN-20261014-10004');
GO

-- ============================================================================
-- 9. SEED AUDIT LOGS & ORDER STATUS HISTORY
-- ============================================================================
INSERT INTO dbo.Order_Status_History (order_id, old_status, new_status, changed_at, changed_by, notes)
VALUES 
    (10001, NULL, N'CONFIRMED', DATEADD(DAY, -18, SYSUTCDATETIME()), N'SYSTEM', N'Initial order created and paid'),
    (10001, N'CONFIRMED', N'SHIPPED', DATEADD(DAY, -17, SYSUTCDATETIME()), N'LOGISTICS_DISPATCH', N'Shipped with FedEx'),
    (10001, N'SHIPPED', N'DELIVERED', DATEADD(DAY, -15, SYSUTCDATETIME()), N'CARRIER_WEBHOOK', N'Delivered to front door'),
    (10002, NULL, N'CONFIRMED', DATEADD(DAY, -3, SYSUTCDATETIME()), N'SYSTEM', N'Order paid with Net Banking'),
    (10002, N'CONFIRMED', N'SHIPPED', DATEADD(DAY, -2, SYSUTCDATETIME()), N'LOGISTICS_DISPATCH', N'Shipped via UPS Next Day'),
    (10003, NULL, N'CONFIRMED', DATEADD(DAY, -1, SYSUTCDATETIME()), N'SYSTEM', N'Order placed'),
    (10003, N'CONFIRMED', N'PROCESSING', DATEADD(HOUR, -12, SYSUTCDATETIME()), N'WAREHOUSE_MANAGER', N'Picking items from shelf'),
    (10004, NULL, N'CONFIRMED', DATEADD(DAY, -8, SYSUTCDATETIME()), N'SYSTEM', N'Order placed'),
    (10004, N'CONFIRMED', N'CANCELLED', DATEADD(DAY, -7, SYSUTCDATETIME()), N'SUPPORT_REP', N'Customer requested order cancellation');

INSERT INTO dbo.Inventory_Audit_Log (product_id, warehouse_id, change_type, quantity_change, previous_quantity, new_quantity, reference_id, logged_at, logged_by)
VALUES 
    (2, 1, N'RESTOCK', 30, 0, 30, NULL, DATEADD(DAY, -25, SYSUTCDATETIME()), N'SUPPLY_CHAIN'),
    (2, 1, N'ORDER_DEDUCT', -1, 30, 29, 10001, DATEADD(DAY, -18, SYSUTCDATETIME()), N'TRG_OrderItems_DeductStock'),
    (1, 1, N'RESTOCK', 20, 0, 20, NULL, DATEADD(DAY, -20, SYSUTCDATETIME()), N'SUPPLY_CHAIN'),
    (1, 1, N'ORDER_DEDUCT', -1, 20, 19, 10002, DATEADD(DAY, -3, SYSUTCDATETIME()), N'TRG_OrderItems_DeductStock'),
    (8, 2, N'ORDER_DEDUCT', -1, 71, 70, 10004, DATEADD(DAY, -8, SYSUTCDATETIME()), N'TRG_OrderItems_DeductStock'),
    (8, 2, N'ORDER_CANCEL_RESTORE', 1, 70, 71, 10004, DATEADD(DAY, -7, SYSUTCDATETIME()), N'TRG_Orders_RestoreStockOnCancel');
GO

PRINT 'Realistic seed data inserted successfully.';
GO

