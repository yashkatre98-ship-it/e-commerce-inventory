# E-Commerce Inventory & Order Management System (DBMS Project)

An enterprise-grade, comprehensive relational database management system (DBMS) package designed for **Microsoft SQL Server (T-SQL)** and **Oracle Database (PL/SQL)**.

This system models a real-world multi-warehouse e-commerce platform with automated stock auto-decrement triggers, ACID-compliant order transactions, coupon and tax calculation engines, multi-warehouse logistics rebalancing, audit trail logging, and advanced analytical business intelligence queries.

---

## 🚀 Key Highlights & Capabilities

- **Normalized Relational Schema (BCNF / 3NF)**: 14 interconnected tables covering catalog, inventory, warehouses, suppliers, customers, coupons, orders, order items, payments, shipments, and audit ledgers.
- **Dual DBMS Implementations**: Native scripts tailored for:
  - **Microsoft SQL Server** (`sql_server/`) using T-SQL, User-Defined Table Types, and `OUTPUT` parameters.
  - **Oracle Database** (`oracle/`) using PL/SQL packages, Compound Triggers (immune to mutating table `ORA-04091`), and object collections.
- **Automated Business Logic Triggers**:
  - Automatically validates stock availability and decrements quantity on hand upon order item insertion.
  - Terminates and rolls back transactions if stock is insufficient (prevents overselling).
  - Automatically restores inventory when an order transitions to `'CANCELLED'`.
  - Captures complete audit trails for every order status change and inventory delta.
- **ACID Transaction Management**: Stored procedures wrap multi-step operations (`BEGIN TRANSACTION ... COMMIT / ROLLBACK`) guaranteeing Atomicity, Consistency, Isolation, and Durability.
- **Promotion & Financial Engine**: Flexible percentage and flat coupons with minimum spend thresholds, maximum discount caps, usage limits, 8% automated tax calculations, and customer loyalty rewards.
- **Advanced SQL Analytics**: Recursive hierarchy traversal (CTEs / `CONNECT BY`), Window Functions (`DENSE_RANK()`, `SUM() OVER`, `AVG() OVER`), Trend Analysis (`LAG()`), Multi-Level Aggregations (`GROUP BY ROLLUP`), and RFM customer segmentation.

---

## 📁 Repository Structure

```text
e-commerce inventry and order sytem/
│
├── sql_server/                        # Microsoft SQL Server (T-SQL) Suite
│   ├── 01_schema_ddl.sql              # Tables, Constraints, Keys & Performance Indexes
│   ├── 02_triggers.sql                # Stock auto-deduct, cancel restore & audit triggers
│   ├── 03_procedures_functions.sql    # sp_PlaceOrder, sp_RestockProduct, sp_TransferWarehouseStock, etc.
│   ├── 04_views.sql                   # Reporting views (Low stock alerts, sales analytics)
│   ├── 05_seed_data.sql               # Realistic multi-warehouse catalog & transaction data
│   ├── 06_analytical_queries.sql      # CTEs, Window functions, ROLLUP & RFM matrix
│   └── run_all_mssql.sql              # Master SQLCMD automation script
│
├── oracle/                            # Oracle Database (PL/SQL) Suite
│   ├── 01_schema_ddl.sql              # Oracle DDL, Identity columns, Constraints & Indexes
│   ├── 02_triggers.sql                # PL/SQL BEFORE INSERT & Compound Triggers
│   ├── 03_procedures_functions.sql    # pkg_ecommerce_ops (Package Specification & Body)
│   ├── 04_views.sql                   # Oracle reporting and inventory views
│   ├── 05_seed_data.sql               # Seed data formatted for Oracle TIMESTAMPs & types
│   ├── 06_analytical_queries.sql      # CONNECT BY, Window functions, LAG & ROLLUP
│   └── run_all_oracle.sql             # Master SQL Developer / SQL*Plus runner script
│
├── docs/                              # Project Documentation & Academic Reports
│   ├── ER_DIAGRAM.md                  # Conceptual & Physical ER Diagram + Relational Schema
│   ├── DATA_DICTIONARY.md             # Complete column dictionary, types, and constraints
│   ├── NORMALIZATION.md               # 1NF, 2NF, 3NF & BCNF formal mathematical proof
│   └── TEST_CASES.md                  # Step-by-step test scenarios & verification results
│
└── README.md                          # Master Project Guide & Setup Manual
```

---

## 🛠️ Step-by-Step Setup & Execution Guide

### Option A: Microsoft SQL Server (SSMS / Azure Data Studio / CLI)

#### Method 1: Using SQL Server Management Studio (SSMS)
1. Open SSMS and connect to your SQL Server instance (e.g. `localhost` or `SQLEXPRESS`).
2. Open and execute the scripts in `sql_server/` in sequential order:
   - `01_schema_ddl.sql` $\to$ Creates `EcommerceInventoryDB` and 14 tables with indexes.
   - `02_triggers.sql` $\to$ Compiles auto-deduct, audit, and cancel-restore triggers.
   - `03_procedures_functions.sql` $\to$ Deploys functions, table types, and stored procedures.
   - `04_views.sql` $\to$ Creates reporting and analytical views.
   - `05_seed_data.sql` $\to$ Populates realistic seed records.
   - `06_analytical_queries.sql` $\to$ Runs advanced reporting queries.

#### Method 2: One-Click Execution via SQLCMD
In SSMS:
1. Open `sql_server/run_all_mssql.sql`.
2. Enable SQLCMD Mode from top menu: **Query $\to$ SQLCMD Mode**.
3. Click **Execute** (or press `F5`).

From PowerShell / Command Line:
```powershell
sqlcmd -S localhost -E -i sql_server\run_all_mssql.sql
```

---

### Option B: Oracle Database (Oracle SQL Developer / SQL*Plus / Oracle Cloud Live SQL)

#### Method 1: Using Oracle SQL Developer
1. Connect to your Oracle database schema (e.g., `HR`, `SYSTEM`, or custom schema).
2. Open and run each script using **Run Script (`F5`)**:
   - `oracle/01_schema_ddl.sql`
   - `oracle/02_triggers.sql`
   - `oracle/03_procedures_functions.sql`
   - `oracle/04_views.sql`
   - `oracle/05_seed_data.sql`
   - `oracle/06_analytical_queries.sql`

#### Method 2: Using SQL*Plus or SQLcl
```sql
sqlplus username/password@localhost:1521/XEPDB1
@oracle/run_all_oracle.sql
```

#### Method 3: Oracle Live SQL (Web Browser)
If using [Oracle Live SQL](https://livesql.oracle.com):
1. Copy the contents of `oracle/01_schema_ddl.sql` and run in the SQL Worksheet.
2. Follow with `oracle/02_triggers.sql`, `oracle/03_procedures_functions.sql`, `oracle/04_views.sql`, `oracle/05_seed_data.sql`, and `oracle/06_analytical_queries.sql`.

---

## 🧪 Quick Test & Live Demonstration

To demonstrate the system live in viva or technical evaluation:

### 1. Place an Order (ACID Stored Procedure with Trigger Execution)
```sql
-- In SQL Server:
DECLARE @Items dbo.OrderItemTableType;
INSERT INTO @Items (product_id, warehouse_id, quantity)
VALUES (8, 1, 2); -- 2 units of Logitech MX Master Mouse from WH 1

DECLARE @NewID INT;
EXEC dbo.sp_PlaceOrder
    @CustomerID = 5001,
    @ShippingAddress = N'742 Evergreen Terrace, Springfield, OR',
    @CouponCode = N'WELCOME10',
    @PaymentMethod = N'CREDIT_CARD',
    @ShippingFee = 10.00,
    @Notes = N'Live Demo Order',
    @Items = @Items,
    @NewOrderID = @NewID OUTPUT;

-- Check updated inventory and generated order
SELECT * FROM dbo.Inventory WHERE product_id = 8 AND warehouse_id = 1;
SELECT * FROM dbo.Orders WHERE order_id = @NewID;
SELECT * FROM dbo.Inventory_Audit_Log WHERE reference_id = @NewID;
```

### 2. Verify Insufficient Stock Prevention (Rollback)
```sql
-- Attempting to order 999 units (stock is only ~80)
DECLARE @Items dbo.OrderItemTableType;
INSERT INTO @Items (product_id, warehouse_id, quantity) VALUES (8, 1, 999);
DECLARE @FailID INT;

-- This fails with error: Insufficient stock available in requested warehouse.
EXEC dbo.sp_PlaceOrder @CustomerID=5001, @ShippingAddress=N'Test', @PaymentMethod=N'UPI', @Items=@Items, @NewOrderID=@FailID OUTPUT;
```

### 3. Check Low-Stock Procurement Alerts
```sql
SELECT * FROM dbo.vw_LowStockAlerts;
```

For more detailed test scenarios and expected outputs, refer to [TEST_CASES.md](file:///c:/Users/yashk/OneDrive/Desktop/e-commerce%20inventry%20and%20order%20sytem/docs/TEST_CASES.md).

---

## 📊 Summary of Database Tables

| Table Name | Primary Key | Description |
|---|---|---|
| [`Suppliers`](file:///c:/Users/yashk/OneDrive/Desktop/e-commerce%20inventry%20and%20order%20sytem/docs/DATA_DICTIONARY.md#1-suppliers) | `supplier_id` | Vendor suppliers providing hardware and inventory stock |
| [`Categories`](file:///c:/Users/yashk/OneDrive/Desktop/e-commerce%20inventry%20and%20order%20sytem/docs/DATA_DICTIONARY.md#2-categories) | `category_id` | Hierarchical product taxonomy (supports nested sub-categories) |
| [`Products`](file:///c:/Users/yashk/OneDrive/Desktop/e-commerce%20inventry%20and%20order%20sytem/docs/DATA_DICTIONARY.md#3-products) | `product_id` | Sellable goods with pricing, SKU, and safety reorder thresholds |
| [`Warehouses`](file:///c:/Users/yashk/OneDrive/Desktop/e-commerce%20inventry%20and%20order%20sytem/docs/DATA_DICTIONARY.md#4-warehouses) | `warehouse_id` | Physical logistics distribution and fulfillment hubs |
| [`Inventory`](file:///c:/Users/yashk/OneDrive/Desktop/e-commerce%20inventry%20and%20order%20sytem/docs/DATA_DICTIONARY.md#5-inventory) | `inventory_id` | Multi-warehouse stock ledger per product with reservations |
| [`Stock_Transfers`](file:///c:/Users/yashk/OneDrive/Desktop/e-commerce%20inventry%20and%20order%20sytem/docs/DATA_DICTIONARY.md#6-stock_transfers) | `transfer_id` | Inter-warehouse stock rebalancing transactions |
| [`Customers`](file:///c:/Users/yashk/OneDrive/Desktop/e-commerce%20inventry%20and%20order%20sytem/docs/DATA_DICTIONARY.md#7-customers) | `customer_id` | Registered consumer profiles and loyalty rewards points |
| [`Coupons`](file:///c:/Users/yashk/OneDrive/Desktop/e-commerce%20inventry%20and%20order%20sytem/docs/DATA_DICTIONARY.md#8-coupons) | `coupon_id` | Discount promotions engine (percentage and fixed-amount) |
| [`Orders`](file:///c:/Users/yashk/OneDrive/Desktop/e-commerce%20inventry%20and%20order%20sytem/docs/DATA_DICTIONARY.md#9-orders) | `order_id` | Order transactions, status tracking, discounts, taxes, and shipping |
| [`Order_Items`](file:///c:/Users/yashk/OneDrive/Desktop/e-commerce%20inventry%20and%20order%20sytem/docs/DATA_DICTIONARY.md#10-order_items) | `order_item_id` | Line items specifying product, quantity, unit price, and warehouse |
| [`Payments`](file:///c:/Users/yashk/OneDrive/Desktop/e-commerce%20inventry%20and%20order%20sytem/docs/DATA_DICTIONARY.md#11-payments) | `payment_id` | Payment settlement records with gateway references |
| [`Shipments`](file:///c:/Users/yashk/OneDrive/Desktop/e-commerce%20inventry%20and%20order%20sytem/docs/DATA_DICTIONARY.md#12-shipments) | `shipment_id` | Courier package tracking, carriers, and dispatch timelines |
| [`Order_Status_History`](file:///c:/Users/yashk/OneDrive/Desktop/e-commerce%20inventry%20and%20order%20sytem/docs/DATA_DICTIONARY.md#13-order_status_history) | `history_id` | Chronological audit trail of order status transitions |
| [`Inventory_Audit_Log`](file:///c:/Users/yashk/OneDrive/Desktop/e-commerce%20inventry%20and%20order%20sytem/docs/DATA_DICTIONARY.md#14-inventory_audit_log) | `audit_id` | Immutable ledger of every stock deduction, restock, or transfer |

---

## 📚 Documentation Reference

- **[ER Diagram & Schema](file:///c:/Users/yashk/OneDrive/Desktop/e-commerce%20inventry%20and%20order%20sytem/docs/ER_DIAGRAM.md)**: Visual Mermaid diagram, entity relationships, and relational mappings.
- **[Data Dictionary](file:///c:/Users/yashk/OneDrive/Desktop/e-commerce%20inventry%20and%20order%20sytem/docs/DATA_DICTIONARY.md)**: Column specifications, data types, nullability, defaults, and constraints.
- **[Normalization Analysis](file:///c:/Users/yashk/OneDrive/Desktop/e-commerce%20inventry%20and%20order%20sytem/docs/NORMALIZATION.md)**: Functional dependencies, 1NF, 2NF, 3NF, and BCNF mathematical proofs.
- **[Test Cases & Verification](file:///c:/Users/yashk/OneDrive/Desktop/e-commerce%20inventry%20and%20order%20sytem/docs/TEST_CASES.md)**: Interactive verification scripts and test scenarios.

