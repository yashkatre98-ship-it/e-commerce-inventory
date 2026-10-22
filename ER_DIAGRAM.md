# Entity-Relationship (ER) Diagram & Relational Schema

This document details the conceptual, logical, and physical entity-relationship architecture for the **E-Commerce Inventory & Order Management System**.

---

## 1. Conceptual & Logical ER Diagram (Mermaid)

```mermaid
erDiagram
    SUPPLIERS ||--o{ PRODUCTS : supplies
    CATEGORIES ||--o{ CATEGORIES : "parent of"
    CATEGORIES ||--o{ PRODUCTS : categorizes
    PRODUCTS ||--o{ INVENTORY : "stocked in"
    WAREHOUSES ||--o{ INVENTORY : stores
    WAREHOUSES ||--o{ STOCK_TRANSFERS : "transfers from"
    WAREHOUSES ||--o{ STOCK_TRANSFERS : "transfers to"
    PRODUCTS ||--o{ STOCK_TRANSFERS : transferred

    CUSTOMERS ||--o{ ORDERS : places
    COUPONS ||--o{ ORDERS : applies_to
    ORDERS ||--|{ ORDER_ITEMS : contains
    PRODUCTS ||--o{ ORDER_ITEMS : "ordered as"
    WAREHOUSES ||--o{ ORDER_ITEMS : fulfills

    ORDERS ||--o{ PAYMENTS : "paid by"
    ORDERS ||--o{ SHIPMENTS : "dispatched via"
    WAREHOUSES ||--o{ SHIPMENTS : "ships from"

    ORDERS ||--o{ ORDER_STATUS_HISTORY : audits
    PRODUCTS ||--o{ INVENTORY_AUDIT_LOG : tracks
    WAREHOUSES ||--o{ INVENTORY_AUDIT_LOG : locates

    SUPPLIERS {
        int supplier_id PK
        string company_name UK
        string contact_name
        string email UK
        string phone
        string address
        string city
        string country
        decimal rating
        datetime created_at
    }

    CATEGORIES {
        int category_id PK
        string category_name UK
        string description
        int parent_category_id FK
        datetime created_at
    }

    PRODUCTS {
        int product_id PK
        string sku UK
        string product_name
        string description
        int category_id FK
        int supplier_id FK
        decimal unit_price
        decimal cost_price
        int reorder_level
        bit is_active
        datetime created_at
    }

    WAREHOUSES {
        int warehouse_id PK
        string warehouse_name UK
        string location_address
        string city
        string state
        string postal_code
        int capacity
        bit is_active
        datetime created_at
    }

    INVENTORY {
        int inventory_id PK
        int product_id FK
        int warehouse_id FK
        int quantity_on_hand
        int quantity_reserved
        datetime last_restocked_at
        datetime last_updated_at
    }

    STOCK_TRANSFERS {
        int transfer_id PK
        int product_id FK
        int from_warehouse_id FK
        int to_warehouse_id FK
        int quantity
        string transfer_status
        datetime transfer_date
        string notes
    }

    CUSTOMERS {
        int customer_id PK
        string first_name
        string last_name
        string email UK
        string phone
        string address_line
        string city
        string state
        string postal_code
        string country
        int loyalty_points
        datetime created_at
    }

    COUPONS {
        int coupon_id PK
        string coupon_code UK
        string discount_type
        decimal discount_value
        decimal min_order_amount
        decimal max_discount_amount
        datetime valid_from
        datetime valid_to
        int usage_limit
        int times_used
        bit is_active
    }

    ORDERS {
        int order_id PK
        int customer_id FK
        datetime order_date
        string order_status
        decimal subtotal
        decimal discount_amount
        decimal tax_amount
        decimal shipping_fee
        decimal total_amount
        int coupon_id FK
        string shipping_address
        string notes
    }

    ORDER_ITEMS {
        int order_item_id PK
        int order_id FK
        int product_id FK
        int warehouse_id FK
        int quantity
        decimal unit_price
        decimal line_total
    }

    PAYMENTS {
        int payment_id PK
        int order_id FK
        datetime payment_date
        string payment_method
        string payment_status
        decimal amount
        string transaction_reference UK
    }

    SHIPMENTS {
        int shipment_id PK
        int order_id FK
        int warehouse_id FK
        string carrier_name
        string tracking_number UK
        string shipment_status
        datetime shipped_date
        datetime delivered_date
    }

    ORDER_STATUS_HISTORY {
        int history_id PK
        int order_id FK
        string old_status
        string new_status
        datetime changed_at
        string changed_by
        string notes
    }

    INVENTORY_AUDIT_LOG {
        bigint audit_id PK
        int product_id FK
        int warehouse_id FK
        string change_type
        int quantity_change
        int previous_quantity
        int new_quantity
        int reference_id
        datetime logged_at
        string logged_by
    }
```

---

## 2. Cardinality & Multiplicity Analysis

| Relationship | Entities Involved | Cardinality | Explanation |
|---|---|---|---|
| Categorization | Categories (1) - Products (N) | `1:N` | One category contains zero or many products; each product belongs to one primary category. |
| Category Hierarchy | Categories (1) - Categories (N) | `1:N` (Self-referencing) | Sub-categories reference parent categories; allows arbitrary nested hierarchies. |
| Product Supply | Suppliers (1) - Products (N) | `1:N` | A supplier supplies many products; each product has a primary vendor supplier. |
| Warehouse Stocking | Products (M) - Warehouses (N) | `M:N` resolved by `Inventory` | A product is distributed across multiple regional fulfillment warehouses. |
| Customer Purchases | Customers (1) - Orders (N) | `1:N` | A customer places multiple orders over time. |
| Order Line Items | Orders (1) - Products (N) | `M:N` resolved by `Order_Items` | An order includes multiple items; each item specifies product, warehouse, and count. |
| Promotion Application | Coupons (0..1) - Orders (N) | `1:N` | An order can optionally have one valid coupon discount applied. |
| Payment Settlement | Orders (1) - Payments (1..N) | `1:N` | Orders have payment records (supports retries, splits, or refunds). |
| Logistics Fulfillment | Orders (1) - Shipments (1..N) | `1:N` | Orders may ship from different warehouses via carrier tracking numbers. |
| Order Audit Trail | Orders (1) - Order_Status_History (N) | `1:N` | Automatically records every status change over time. |
| Inventory Ledger | Products/Warehouses (1) - Inventory_Audit_Log (N) | `1:N` | Records every stock addition, deduction, transfer, or restore event. |

---

## 3. Relational Schema Representation

Underlined attributes denote **Primary Keys (PK)**; attributes marked with an asterisk `*` denote **Foreign Keys (FK)**.

1. **Suppliers** (<u>supplier_id</u>, company_name, contact_name, email, phone, address, city, country, rating, created_at)
2. **Categories** (<u>category_id</u>, category_name, description, *parent_category_id*, created_at)
3. **Products** (<u>product_id</u>, sku, product_name, description, *category_id*, *supplier_id*, unit_price, cost_price, reorder_level, is_active, created_at)
4. **Warehouses** (<u>warehouse_id</u>, warehouse_name, location_address, city, state, postal_code, capacity, is_active, created_at)
5. **Inventory** (<u>inventory_id</u>, *product_id*, *warehouse_id*, quantity_on_hand, quantity_reserved, last_restocked_at, last_updated_at)
6. **Stock_Transfers** (<u>transfer_id</u>, *product_id*, *from_warehouse_id*, *to_warehouse_id*, quantity, transfer_status, transfer_date, notes)
7. **Customers** (<u>customer_id</u>, first_name, last_name, email, phone, address_line, city, state, postal_code, country, loyalty_points, created_at)
8. **Coupons** (<u>coupon_id</u>, coupon_code, discount_type, discount_value, min_order_amount, max_discount_amount, valid_from, valid_to, usage_limit, times_used, is_active)
9. **Orders** (<u>order_id</u>, *customer_id*, order_date, order_status, subtotal, discount_amount, tax_amount, shipping_fee, total_amount, *coupon_id*, shipping_address, notes)
10. **Order_Items** (<u>order_item_id</u>, *order_id*, *product_id*, *warehouse_id*, quantity, unit_price, line_total)
11. **Payments** (<u>payment_id</u>, *order_id*, payment_date, payment_method, payment_status, amount, transaction_reference)
12. **Shipments** (<u>shipment_id</u>, *order_id*, *warehouse_id*, carrier_name, tracking_number, shipment_status, shipped_date, delivered_date)
13. **Order_Status_History** (<u>history_id</u>, *order_id*, old_status, new_status, changed_at, changed_by, notes)
14. **Inventory_Audit_Log** (<u>audit_id</u>, *product_id*, *warehouse_id*, change_type, quantity_change, previous_quantity, new_quantity, reference_id, logged_at, logged_by)

