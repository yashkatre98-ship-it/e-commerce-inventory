# Data Dictionary

This document specifies the schema data dictionary for the **E-Commerce Inventory & Order Management System**, covering column definitions, data types, nullability, constraints, default values, and functional business descriptions.

---

## 1. Suppliers

| Column Name | Data Type (SQL Server / Oracle) | Nullable | Key / Constraint | Default | Description |
|---|---|---|---|---|---|
| `supplier_id` | `INT IDENTITY` / `NUMBER IDENTITY` | NO | PK | Auto | Unique identifier for supplier vendor |
| `company_name` | `NVARCHAR(150)` / `VARCHAR2(150)` | NO | UNIQUE | - | Commercial name of supplying firm |
| `contact_name` | `NVARCHAR(100)` / `VARCHAR2(100)` | NO | - | - | Primary account manager or contact person |
| `email` | `NVARCHAR(120)` / `VARCHAR2(120)` | NO | UNIQUE, CHECK | - | Vendor email (validated with format regex) |
| `phone` | `NVARCHAR(25)` / `VARCHAR2(25)` | NO | - | - | Vendor business phone number |
| `address` | `NVARCHAR(200)` / `VARCHAR2(200)` | NO | - | - | Street address of corporate headquarters |
| `city` | `NVARCHAR(60)` / `VARCHAR2(60)` | NO | - | - | Operating city |
| `country` | `NVARCHAR(60)` / `VARCHAR2(60)` | NO | - | `'USA'` | Vendor country |
| `rating` | `DECIMAL(2,1)` / `NUMBER(2,1)` | NO | CHECK (1.0 to 5.0) | `5.0` | Vendor quality & reliability performance score |
| `created_at` | `DATETIME2` / `TIMESTAMP` | NO | - | Current Time | Record insertion timestamp |

---

## 2. Categories

| Column Name | Data Type (SQL Server / Oracle) | Nullable | Key / Constraint | Default | Description |
|---|---|---|---|---|---|
| `category_id` | `INT IDENTITY` / `NUMBER IDENTITY` | NO | PK | Auto | Unique identifier for product category |
| `category_name` | `NVARCHAR(100)` / `VARCHAR2(100)` | NO | UNIQUE | - | Display name of product category |
| `description` | `NVARCHAR(255)` / `VARCHAR2(255)` | YES | - | NULL | Category overview and description |
| `parent_category_id` | `INT` / `NUMBER` | YES | FK -> `Categories(category_id)` | NULL | Self-referencing key for sub-category hierarchies |
| `created_at` | `DATETIME2` / `TIMESTAMP` | NO | - | Current Time | Timestamp of category creation |

---

## 3. Products

| Column Name | Data Type (SQL Server / Oracle) | Nullable | Key / Constraint | Default | Description |
|---|---|---|---|---|---|
| `product_id` | `INT IDENTITY` / `NUMBER IDENTITY` | NO | PK | Auto | System product identifier |
| `sku` | `NVARCHAR(50)` / `VARCHAR2(50)` | NO | UNIQUE | - | Stock Keeping Unit (merchant barcode code) |
| `product_name` | `NVARCHAR(150)` / `VARCHAR2(150)` | NO | - | - | Commercial title of item |
| `description` | `NVARCHAR(500)` / `VARCHAR2(500)` | YES | - | NULL | Technical specifications and details |
| `category_id` | `INT` / `NUMBER` | NO | FK -> `Categories(category_id)` | - | Associated category |
| `supplier_id` | `INT` / `NUMBER` | NO | FK -> `Suppliers(supplier_id)` | - | Sourcing supplier |
| `unit_price` | `DECIMAL(10,2)` / `NUMBER(10,2)` | NO | CHECK (`unit_price > 0`) | - | Customer selling retail price |
| `cost_price` | `DECIMAL(10,2)` / `NUMBER(10,2)` | NO | CHECK (`cost_price > 0`) | - | Wholesale cost price from supplier |
| `reorder_level` | `INT` / `NUMBER` | NO | CHECK (`reorder_level >= 0`) | `10` | Safety stock threshold triggering restock alerts |
| `is_active` | `BIT` / `NUMBER(1)` | NO | CHECK (`is_active IN (0,1)`) | `1` | Flag marking item active for order placement |
| `created_at` | `DATETIME2` / `TIMESTAMP` | NO | - | Current Time | Product listing date |

---

## 4. Warehouses

| Column Name | Data Type (SQL Server / Oracle) | Nullable | Key / Constraint | Default | Description |
|---|---|---|---|---|---|
| `warehouse_id` | `INT IDENTITY` / `NUMBER IDENTITY` | NO | PK | Auto | Unique identifier for warehouse facility |
| `warehouse_name` | `NVARCHAR(100)` / `VARCHAR2(100)` | NO | UNIQUE | - | Name of distribution hub |
| `location_address`| `NVARCHAR(200)` / `VARCHAR2(200)` | NO | - | - | Physical street address |
| `city` | `NVARCHAR(60)` / `VARCHAR2(60)` | NO | - | - | City of facility |
| `state` | `NVARCHAR(60)` / `VARCHAR2(60)` | NO | - | - | State/Province |
| `postal_code` | `NVARCHAR(20)` / `VARCHAR2(20)` | NO | - | - | Postal/ZIP code |
| `capacity` | `INT` / `NUMBER` | NO | CHECK (`capacity > 0`) | - | Maximum product storage units |
| `is_active` | `BIT` / `NUMBER(1)` | NO | CHECK (`is_active IN (0,1)`) | `1` | Active operational status |
| `created_at` | `DATETIME2` / `TIMESTAMP` | NO | - | Current Time | Hub registration timestamp |

---

## 5. Inventory

| Column Name | Data Type (SQL Server / Oracle) | Nullable | Key / Constraint | Default | Description |
|---|---|---|---|---|---|
| `inventory_id` | `INT IDENTITY` / `NUMBER IDENTITY` | NO | PK | Auto | Unique stock row ID |
| `product_id` | `INT` / `NUMBER` | NO | FK -> `Products(product_id)` | - | Referenced product |
| `warehouse_id` | `INT` / `NUMBER` | NO | FK -> `Warehouses(warehouse_id)`| - | Stocking warehouse |
| `quantity_on_hand`| `INT` / `NUMBER` | NO | CHECK (`quantity_on_hand >= 0`)| `0` | Physical stock available |
| `quantity_reserved`| `INT` / `NUMBER` | NO | CHECK (`quantity_reserved >= 0`)| `0` | Stock allocated to pending orders |
| `last_restocked_at`| `DATETIME2` / `TIMESTAMP` | YES | - | NULL | Date of most recent replenishment |
| `last_updated_at`| `DATETIME2` / `TIMESTAMP` | NO | - | Current Time | Last inventory level modification |
| *(Composite)* | - | - | UNIQUE (`product_id`, `warehouse_id`) | - | Prevents duplicate product entries per warehouse |

---

## 6. Stock_Transfers

| Column Name | Data Type (SQL Server / Oracle) | Nullable | Key / Constraint | Default | Description |
|---|---|---|---|---|---|
| `transfer_id` | `INT IDENTITY` / `NUMBER IDENTITY` | NO | PK | Auto | Unique transfer ID |
| `product_id` | `INT` / `NUMBER` | NO | FK -> `Products(product_id)` | - | Product being transferred |
| `from_warehouse_id`| `INT` / `NUMBER` | NO | FK -> `Warehouses(warehouse_id)`| - | Source warehouse |
| `to_warehouse_id` | `INT` / `NUMBER` | NO | FK -> `Warehouses(warehouse_id)`| - | Target warehouse |
| `quantity` | `INT` / `NUMBER` | NO | CHECK (`quantity > 0`) | - | Number of units rebalanced |
| `transfer_status`| `NVARCHAR(20)` / `VARCHAR2(20)` | NO | CHECK (`status IN (...)`) | `'COMPLETED'`| Transfer status |
| `transfer_date` | `DATETIME2` / `TIMESTAMP` | NO | - | Current Time | Date transfer initiated |
| `notes` | `NVARCHAR(255)` / `VARCHAR2(255)` | YES | - | NULL | Reason or logistics remarks |

---

## 7. Customers

| Column Name | Data Type (SQL Server / Oracle) | Nullable | Key / Constraint | Default | Description |
|---|---|---|---|---|---|
| `customer_id` | `INT IDENTITY` / `NUMBER IDENTITY` | NO | PK | Auto | Unique customer identification number |
| `first_name` | `NVARCHAR(60)` / `VARCHAR2(60)` | NO | - | - | Customer given name |
| `last_name` | `NVARCHAR(60)` / `VARCHAR2(60)` | NO | - | - | Customer family name |
| `email` | `NVARCHAR(120)` / `VARCHAR2(120)` | NO | UNIQUE, CHECK | - | Login and contact email |
| `phone` | `NVARCHAR(25)` / `VARCHAR2(25)` | NO | - | - | Customer contact phone |
| `address_line` | `NVARCHAR(150)` / `VARCHAR2(150)` | NO | - | - | Default billing/shipping street address |
| `city` | `NVARCHAR(60)` / `VARCHAR2(60)` | NO | - | - | Customer city |
| `state` | `NVARCHAR(60)` / `VARCHAR2(60)` | NO | - | - | State or province |
| `postal_code` | `NVARCHAR(20)` / `VARCHAR2(20)` | NO | - | - | Postal/ZIP code |
| `country` | `NVARCHAR(60)` / `VARCHAR2(60)` | NO | - | `'USA'` | Customer country |
| `loyalty_points` | `INT` / `NUMBER` | NO | CHECK (`points >= 0`) | `0` | Accumulated store rewards points |
| `created_at` | `DATETIME2` / `TIMESTAMP` | NO | - | Current Time | Customer registration date |

---

## 8. Coupons

| Column Name | Data Type (SQL Server / Oracle) | Nullable | Key / Constraint | Default | Description |
|---|---|---|---|---|---|
| `coupon_id` | `INT IDENTITY` / `NUMBER IDENTITY` | NO | PK | Auto | Unique coupon ID |
| `coupon_code` | `NVARCHAR(30)` / `VARCHAR2(30)` | NO | UNIQUE | - | Promo code entered at checkout |
| `discount_type` | `NVARCHAR(20)` / `VARCHAR2(20)` | NO | CHECK (`'PERCENTAGE'`, `'FIXED_AMOUNT'`) | - | Algorithm for discount computation |
| `discount_value` | `DECIMAL(10,2)` / `NUMBER(10,2)` | NO | CHECK (`discount_value > 0`) | - | Percentage (e.g. 15.00) or flat dollar ($50.00) |
| `min_order_amount`| `DECIMAL(10,2)` / `NUMBER(10,2)`| NO | CHECK (`min_order >= 0`) | `0.00` | Minimum basket size required |
| `max_discount_amount`| `DECIMAL(10,2)` / `NUMBER(10,2)`| YES| - | NULL | Cap limit for percentage promotions |
| `valid_from` | `DATETIME2` / `TIMESTAMP` | NO | - | - | Activation start timestamp |
| `valid_to` | `DATETIME2` / `TIMESTAMP` | NO | CHECK (`valid_to >= valid_from`) | - | Expiration timestamp |
| `usage_limit` | `INT` / `NUMBER` | NO | - | `1000` | Global max number of redemptions allowed |
| `times_used` | `INT` / `NUMBER` | NO | CHECK (`times_used <= usage_limit`)| `0` | Redemptions consumed to date |
| `is_active` | `BIT` / `NUMBER(1)` | NO | CHECK (`is_active IN (0,1)`) | `1` | Enable/disable toggle switch |

---

## 9. Orders

| Column Name | Data Type (SQL Server / Oracle) | Nullable | Key / Constraint | Default | Description |
|---|---|---|---|---|---|
| `order_id` | `INT IDENTITY` / `NUMBER IDENTITY` | NO | PK | Auto | Master order number |
| `customer_id` | `INT` / `NUMBER` | NO | FK -> `Customers(customer_id)` | - | Customer placing the purchase |
| `order_date` | `DATETIME2` / `TIMESTAMP` | NO | - | Current Time | Order placement timestamp |
| `order_status` | `NVARCHAR(30)` / `VARCHAR2(30)` | NO | CHECK (`status IN (...)`) | `'PENDING'` | Current lifecycle stage |
| `subtotal` | `DECIMAL(12,2)` / `NUMBER(12,2)` | NO | CHECK (`subtotal >= 0`) | `0.00` | Sum of item line totals |
| `discount_amount`| `DECIMAL(12,2)` / `NUMBER(12,2)`| NO | CHECK (`discount >= 0`) | `0.00` | Deduction calculated from promo coupon |
| `tax_amount` | `DECIMAL(12,2)` / `NUMBER(12,2)` | NO | CHECK (`tax >= 0`) | `0.00` | Sales tax collected |
| `shipping_fee` | `DECIMAL(10,2)` / `NUMBER(10,2)` | NO | CHECK (`shipping_fee >= 0`)| `0.00` | Freight fee |
| `total_amount` | `DECIMAL(12,2)` / `NUMBER(12,2)` | NO | CHECK (`total_amount >= 0`)| `0.00` | Final payable balance |
| `coupon_id` | `INT` / `NUMBER` | YES | FK -> `Coupons(coupon_id)` | NULL | Applied promo coupon |
| `shipping_address`| `NVARCHAR(300)` / `VARCHAR2(300)` | NO | - | - | Delivery destination address |
| `notes` | `NVARCHAR(255)` / `VARCHAR2(255)` | YES | - | NULL | Special instructions or cancellation notes |

---

## 10. Order_Items

| Column Name | Data Type (SQL Server / Oracle) | Nullable | Key / Constraint | Default | Description |
|---|---|---|---|---|---|
| `order_item_id` | `INT IDENTITY` / `NUMBER IDENTITY` | NO | PK | Auto | Unique line item ID |
| `order_id` | `INT` / `NUMBER` | NO | FK -> `Orders(order_id)` ON DELETE CASCADE | - | Parent order reference |
| `product_id` | `INT` / `NUMBER` | NO | FK -> `Products(product_id)` | - | Purchased catalog item |
| `warehouse_id` | `INT` / `NUMBER` | NO | FK -> `Warehouses(warehouse_id)`| - | Sourced fulfillment location |
| `quantity` | `INT` / `NUMBER` | NO | CHECK (`quantity > 0`) | - | Quantity of units ordered |
| `unit_price` | `DECIMAL(10,2)` / `NUMBER(10,2)` | NO | CHECK (`unit_price >= 0`) | - | Unit price locked at time of order |
| `line_total` | `DECIMAL(12,2)` / `NUMBER(12,2)` | NO | CHECK (`line_total >= 0`) | - | Total for this line (`quantity * unit_price`) |
| *(Composite)* | - | - | UNIQUE (`order_id`, `product_id`, `warehouse_id`) | - | Enforces unique product per warehouse in order |

---

## 11. Payments

| Column Name | Data Type (SQL Server / Oracle) | Nullable | Key / Constraint | Default | Description |
|---|---|---|---|---|---|
| `payment_id` | `INT IDENTITY` / `NUMBER IDENTITY` | NO | PK | Auto | Unique payment transaction ID |
| `order_id` | `INT` / `NUMBER` | NO | FK -> `Orders(order_id)` | - | Settled order |
| `payment_date` | `DATETIME2` / `TIMESTAMP` | NO | - | Current Time | Payment execution time |
| `payment_method` | `NVARCHAR(30)` / `VARCHAR2(30)` | NO | CHECK (`method IN (...)`) | - | Card, UPI, NetBanking, COD, PayPal |
| `payment_status` | `NVARCHAR(20)` / `VARCHAR2(20)` | NO | CHECK (`status IN (...)`) | `'PENDING'` | Gateway settlement status |
| `amount` | `DECIMAL(12,2)` / `NUMBER(12,2)` | NO | CHECK (`amount > 0`) | - | Paid amount |
| `transaction_reference` | `NVARCHAR(100)` / `VARCHAR2(100)` | NO | UNIQUE | - | External payment gateway authorization code |

---

## 12. Shipments

| Column Name | Data Type (SQL Server / Oracle) | Nullable | Key / Constraint | Default | Description |
|---|---|---|---|---|---|
| `shipment_id` | `INT IDENTITY` / `NUMBER IDENTITY` | NO | PK | Auto | Unique delivery package ID |
| `order_id` | `INT` / `NUMBER` | NO | FK -> `Orders(order_id)` | - | Associated order |
| `warehouse_id` | `INT` / `NUMBER` | NO | FK -> `Warehouses(warehouse_id)`| - | Origin dispatch hub |
| `carrier_name` | `NVARCHAR(60)` / `VARCHAR2(60)` | NO | - | - | Logistics courier (FedEx, UPS, DHL) |
| `tracking_number`| `NVARCHAR(100)` / `VARCHAR2(100)`| NO | UNIQUE | - | Courier tracking consignment code |
| `shipment_status`| `NVARCHAR(30)` / `VARCHAR2(30)` | NO | CHECK (`status IN (...)`) | `'PREPARING'`| Shipping phase |
| `shipped_date` | `DATETIME2` / `TIMESTAMP` | YES | - | NULL | Date handed to courier |
| `delivered_date`| `DATETIME2` / `TIMESTAMP` | YES | - | NULL | Customer delivery confirmation time |

---

## 13. Order_Status_History

| Column Name | Data Type (SQL Server / Oracle) | Nullable | Key / Constraint | Default | Description |
|---|---|---|---|---|---|
| `history_id` | `INT IDENTITY` / `NUMBER IDENTITY` | NO | PK | Auto | Primary key of history record |
| `order_id` | `INT` / `NUMBER` | NO | FK -> `Orders(order_id)` ON DELETE CASCADE | - | Tracked order |
| `old_status` | `NVARCHAR(30)` / `VARCHAR2(30)` | YES | - | NULL | Preceding order status |
| `new_status` | `NVARCHAR(30)` / `VARCHAR2(30)` | NO | - | - | Updated status |
| `changed_at` | `DATETIME2` / `TIMESTAMP` | NO | - | Current Time | Timestamp of status event |
| `changed_by` | `NVARCHAR(60)` / `VARCHAR2(60)` | NO | - | `'SYSTEM'` | Actor or trigger modifying state |
| `notes` | `NVARCHAR(255)` / `VARCHAR2(255)` | YES | - | NULL | Operational reason or remarks |

---

## 14. Inventory_Audit_Log

| Column Name | Data Type (SQL Server / Oracle) | Nullable | Key / Constraint | Default | Description |
|---|---|---|---|---|---|
| `audit_id` | `BIGINT IDENTITY` / `NUMBER IDENTITY` | NO | PK | Auto | Unique chronological ledger sequence ID |
| `product_id` | `INT` / `NUMBER` | NO | FK -> `Products(product_id)` | - | Affected catalog product |
| `warehouse_id` | `INT` / `NUMBER` | NO | FK -> `Warehouses(warehouse_id)`| - | Affected warehouse site |
| `change_type` | `NVARCHAR(30)` / `VARCHAR2(30)` | NO | CHECK (`change_type IN (...)`) | - | `ORDER_DEDUCT`, `RESTOCK`, `TRANSFER_IN`, `TRANSFER_OUT`, etc. |
| `quantity_change`| `INT` / `NUMBER` | NO | - | - | Delta quantity signed (+/-) |
| `previous_quantity`| `INT` / `NUMBER` | NO | - | - | Stock before modification |
| `new_quantity` | `INT` / `NUMBER` | NO | - | - | Resulting stock balance |
| `reference_id` | `INT` / `NUMBER` | YES | - | NULL | Foreign order_id or transfer_id |
| `logged_at` | `DATETIME2` / `TIMESTAMP` | NO | - | Current Time | Audit event timestamp |
| `logged_by` | `NVARCHAR(60)` / `VARCHAR2(60)` | NO | - | `'SYSTEM'` | System component executing change |

