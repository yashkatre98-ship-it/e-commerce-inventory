# Test Cases & Verification Scenarios

This document provides step-by-step test scripts with expected outputs to verify all DBMS mechanisms (ACID transactions, triggers, stored procedures, constraints, and audit logging) in **Microsoft SQL Server (T-SQL)** and **Oracle Database (PL/SQL)**.

---

## Test Scenario 1: Successful Order Placement & Auto-Decrement Trigger

### Objective:
Verify that `sp_PlaceOrder` correctly calculates totals, applies a coupon discount, inserts order items, fires the inventory deduction trigger, updates payment, and awards loyalty points inside a single atomic transaction.

### SQL Server Execution:
```sql
USE EcommerceInventoryDB;
GO

-- 1. Check initial stock for Product 8 (Logitech Mouse) in Warehouse 1
SELECT product_id, warehouse_id, quantity_on_hand 
FROM dbo.Inventory 
WHERE product_id = 8 AND warehouse_id = 1;
-- Initial stock: 80

-- 2. Execute Stored Procedure
DECLARE @Items dbo.OrderItemTableType;
INSERT INTO @Items (product_id, warehouse_id, quantity)
VALUES (8, 1, 2); -- Order 2 units

DECLARE @OrderID INT;

EXEC dbo.sp_PlaceOrder
    @CustomerID = 5001,
    @ShippingAddress = N'742 Evergreen Terrace, Springfield, OR',
    @CouponCode = N'WELCOME10', -- 10% discount
    @PaymentMethod = N'CREDIT_CARD',
    @ShippingFee = 10.00,
    @Notes = N'Test Order 1',
    @Items = @Items,
    @NewOrderID = @OrderID OUTPUT;

SELECT @OrderID AS GeneratedOrderID;

-- 3. Verify stock was automatically decremented to 78 by the trigger
SELECT product_id, warehouse_id, quantity_on_hand 
FROM dbo.Inventory 
WHERE product_id = 8 AND warehouse_id = 1;

-- 4. Verify audit ledger entry was written
SELECT TOP 1 * 
FROM dbo.Inventory_Audit_Log 
WHERE reference_id = @OrderID 
ORDER BY audit_id DESC;
```

### Oracle PL/SQL Execution:
```sql
SET SERVEROUTPUT ON;

DECLARE
    v_items pkg_ecommerce_ops.t_order_item_tab := pkg_ecommerce_ops.t_order_item_tab();
    v_order_id NUMBER;
BEGIN
    v_items.EXTEND;
    v_items(1) := pkg_ecommerce_ops.t_order_item_obj(8, 1, 2); -- 2 units of Product 8 in WH 1

    pkg_ecommerce_ops.sp_place_order(
        p_customer_id      => 5001,
        p_shipping_address => '742 Evergreen Terrace, Springfield, OR',
        p_coupon_code      => 'WELCOME10',
        p_payment_method   => 'CREDIT_CARD',
        p_shipping_fee     => 10.00,
        p_notes            => 'Test Order 1',
        p_items            => v_items,
        p_new_order_id     => v_order_id
    );

    DBMS_OUTPUT.PUT_LINE('Generated Order ID: ' || v_order_id);
END;
/
```

### Expected Output:
- Order is placed and assigned a new unique ID.
- Stock for Product 8 in Warehouse 1 drops from `80` to `78`.
- Payment status is `'COMPLETED'`.
- Customer loyalty points increment.
- `Inventory_Audit_Log` records `change_type = 'ORDER_DEDUCT'` with `quantity_change = -2`.

---

## Test Scenario 2: Insufficient Stock Prevention & Rollback Verification

### Objective:
Demonstrate that the trigger and procedure prevent overselling by throwing a fatal database exception and rolling back all operations if an order exceeds available inventory.

### SQL Server Execution:
```sql
USE EcommerceInventoryDB;
GO

-- Product 5 has only 2 units in Warehouse 1
SELECT quantity_on_hand 
FROM dbo.Inventory 
WHERE product_id = 5 AND warehouse_id = 1;

-- Attempt to purchase 999 units (exceeds inventory)
DECLARE @Items dbo.OrderItemTableType;
INSERT INTO @Items (product_id, warehouse_id, quantity)
VALUES (5, 1, 999);

DECLARE @OrderID INT;

BEGIN TRY
    EXEC dbo.sp_PlaceOrder
        @CustomerID = 5002,
        @ShippingAddress = N'San Francisco, CA',
        @CouponCode = NULL,
        @PaymentMethod = N'DEBIT_CARD',
        @ShippingFee = 0.00,
        @Notes = N'Should Fail',
        @Items = @Items,
        @NewOrderID = @OrderID OUTPUT;
END TRY
BEGIN CATCH
    PRINT 'Caught Expected Error: ' + ERROR_MESSAGE();
END CATCH;

-- Verify NO order was created and stock remains exactly 2
SELECT quantity_on_hand 
FROM dbo.Inventory 
WHERE product_id = 5 AND warehouse_id = 1;
```

### Expected Output:
```
Msg 50000, Level 16, State 1, Procedure sp_PlaceOrder
Insufficient stock available in requested warehouse for one or more items.
```
- No order row is created.
- Inventory is unchanged (Atomicity guaranteed).

---

## Test Scenario 3: Order Cancellation & Stock Restoration Trigger

### Objective:
Verify that changing an order status to `'CANCELLED'` automatically restores inventory to the fulfillment warehouse and logs a restorative audit event.

### SQL Server Execution:
```sql
USE EcommerceInventoryDB;
GO

-- 1. Check stock of Product 1 in Warehouse 1 prior to cancellation
SELECT product_id, warehouse_id, quantity_on_hand 
FROM dbo.Inventory 
WHERE product_id = 1 AND warehouse_id = 1;

-- 2. Cancel Order 10002 (which originally ordered 1 unit of Product 1 and 1 unit of Product 7)
EXEC dbo.sp_CancelOrder 
    @OrderID = 10002, 
    @CancellationReason = N'Customer cancelled prior to dispatch';

-- 3. Verify stock increased by +1
SELECT product_id, warehouse_id, quantity_on_hand 
FROM dbo.Inventory 
WHERE product_id = 1 AND warehouse_id = 1;

-- 4. Check Order status and Payment status
SELECT order_id, order_status, notes FROM dbo.Orders WHERE order_id = 10002;
SELECT order_id, payment_status FROM dbo.Payments WHERE order_id = 10002;

-- 5. Inspect Inventory Audit Log for ORDER_CANCEL_RESTORE
SELECT TOP 2 * 
FROM dbo.Inventory_Audit_Log 
WHERE reference_id = 10002 
ORDER BY audit_id DESC;
```

### Expected Output:
- Order status changes to `'CANCELLED'`.
- Payment status changes to `'REFUNDED'`.
- Stock quantities for the items are returned to `Inventory`.
- `Inventory_Audit_Log` logs `change_type = 'ORDER_CANCEL_RESTORE'`.
- `Order_Status_History` logs `'SHIPPED' -> 'CANCELLED'`.

---

## Test Scenario 4: Inter-Warehouse Stock Transfer

### Objective:
Verify atomic multi-warehouse inventory transfer and validation.

### SQL Server Execution:
```sql
USE EcommerceInventoryDB;
GO

-- Move 5 units of Product 2 from WH 1 to WH 3
EXEC dbo.sp_TransferWarehouseStock
    @ProductID = 2,
    @FromWarehouseID = 1,
    @ToWarehouseID = 3,
    @Quantity = 5,
    @Notes = N'Rebalancing regional inventory for demand';

-- Verify stock changes
SELECT product_id, warehouse_id, quantity_on_hand 
FROM dbo.Inventory 
WHERE product_id = 2;

-- Check Stock_Transfers record
SELECT TOP 1 * FROM dbo.Stock_Transfers ORDER BY transfer_id DESC;
```

### Expected Output:
- Warehouse 1 stock drops by 5.
- Warehouse 3 stock increases by 5.
- `Stock_Transfers` record created with status `'COMPLETED'`.
- Two audit log rows inserted: `'TRANSFER_OUT'` and `'TRANSFER_IN'`.

---

## Test Scenario 5: Low-Stock Alerts View Execution

### Objective:
Verify operational visibility for replenishment procurement.

### SQL Server Execution:
```sql
USE EcommerceInventoryDB;
GO

SELECT 
    product_id, 
    sku, 
    product_name, 
    reorder_level, 
    total_network_stock, 
    units_shortfall, 
    supplier_name, 
    supplier_email, 
    supplier_phone
FROM dbo.vw_LowStockAlerts;
```

### Expected Output:
Returns products where total stock $\le$ `reorder_level` (e.g. ErgoPro Standing Desk, Dell 4K Monitor) along with supplier contacts.

