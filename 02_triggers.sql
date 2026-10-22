-- ============================================================================
-- E-COMMERCE INVENTORY & ORDER MANAGEMENT SYSTEM (DBMS PROJECT)
-- Dialect: Microsoft SQL Server (T-SQL)
-- Script 02: Triggers (Inventory Deductions, Audits, Restorations)
-- ============================================================================

USE EcommerceInventoryDB;
GO

-- ============================================================================
-- TRIGGER 1: TRG_OrderItems_DeductStock
-- Purpose:
--   1. Validates sufficient stock exists in the selected warehouse.
--   2. If stock is insufficient, terminates and rolls back the transaction.
--   3. Decrements inventory quantity_on_hand.
--   4. Creates an entry in Inventory_Audit_Log for traceability.
-- ============================================================================
IF OBJECT_ID('dbo.TRG_OrderItems_DeductStock', 'TR') IS NOT NULL
    DROP TRIGGER dbo.TRG_OrderItems_DeductStock;
GO

CREATE TRIGGER dbo.TRG_OrderItems_DeductStock
ON dbo.Order_Items
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- Check if any ordered product exceeds available stock or doesn't exist in warehouse
    IF EXISTS (
        SELECT 1
        FROM inserted ins
        LEFT JOIN dbo.Inventory inv 
            ON ins.product_id = inv.product_id 
            AND ins.warehouse_id = inv.warehouse_id
        WHERE inv.inventory_id IS NULL OR inv.quantity_on_hand < ins.quantity
    )
    BEGIN
        RAISERROR ('[TRIGGER ERROR] Insufficient inventory stock or product not stocked in selected warehouse.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- Capture previous stock levels before decrementing
    DECLARE @AuditData TABLE (
        product_id INT,
        warehouse_id INT,
        qty_ordered INT,
        prev_qty INT,
        order_id INT
    );

    INSERT INTO @AuditData (product_id, warehouse_id, qty_ordered, prev_qty, order_id)
    SELECT ins.product_id, ins.warehouse_id, ins.quantity, inv.quantity_on_hand, ins.order_id
    FROM inserted ins
    INNER JOIN dbo.Inventory inv 
        ON ins.product_id = inv.product_id 
        AND ins.warehouse_id = inv.warehouse_id;

    -- Deduct stock from Inventory
    UPDATE inv
    SET inv.quantity_on_hand = inv.quantity_on_hand - a.qty_ordered,
        inv.last_updated_at = SYSUTCDATETIME()
    FROM dbo.Inventory inv
    INNER JOIN @AuditData a 
        ON inv.product_id = a.product_id 
        AND inv.warehouse_id = a.warehouse_id;

    -- Log transaction in Inventory_Audit_Log
    INSERT INTO dbo.Inventory_Audit_Log (
        product_id, warehouse_id, change_type, quantity_change, 
        previous_quantity, new_quantity, reference_id, logged_by
    )
    SELECT 
        product_id, 
        warehouse_id, 
        N'ORDER_DEDUCT', 
        -qty_ordered, 
        prev_qty, 
        (prev_qty - qty_ordered), 
        order_id, 
        N'TRG_OrderItems_DeductStock'
    FROM @AuditData;

END;
GO

-- ============================================================================
-- TRIGGER 2: TRG_Orders_StatusAudit
-- Purpose:
--   Tracks every status transition for orders (PENDING -> CONFIRMED -> SHIPPED, etc.)
--   and writes the history into Order_Status_History.
-- ============================================================================
IF OBJECT_ID('dbo.TRG_Orders_StatusAudit', 'TR') IS NOT NULL
    DROP TRIGGER dbo.TRG_Orders_StatusAudit;
GO

CREATE TRIGGER dbo.TRG_Orders_StatusAudit
ON dbo.Orders
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Case 1: New order inserted
    IF NOT EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO dbo.Order_Status_History (order_id, old_status, new_status, changed_by, notes)
        SELECT 
            ins.order_id, 
            NULL, 
            ins.order_status, 
            N'SYSTEM_CREATE', 
            N'Initial order created'
        FROM inserted ins;
    END
    ELSE
    -- Case 2: Order status changed
    BEGIN
        INSERT INTO dbo.Order_Status_History (order_id, old_status, new_status, changed_by, notes)
        SELECT 
            ins.order_id, 
            del.order_status, 
            ins.order_status, 
            N'STATUS_TRIGGER', 
            CONCAT(N'Status transition from ', del.order_status, N' to ', ins.order_status)
        FROM inserted ins
        INNER JOIN deleted del ON ins.order_id = del.order_id
        WHERE ins.order_status <> del.order_status;
    END
END;
GO

-- ============================================================================
-- TRIGGER 3: TRG_Orders_RestoreStockOnCancel
-- Purpose:
--   If an active order is changed to 'CANCELLED', this trigger automatically
--   restores product quantities back to the corresponding warehouses and writes
--   reversal records into the audit log.
-- ============================================================================
IF OBJECT_ID('dbo.TRG_Orders_RestoreStockOnCancel', 'TR') IS NOT NULL
    DROP TRIGGER dbo.TRG_Orders_RestoreStockOnCancel;
GO

CREATE TRIGGER dbo.TRG_Orders_RestoreStockOnCancel
ON dbo.Orders
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Only act if status changed to CANCELLED from a non-cancelled status
    IF EXISTS (
        SELECT 1 
        FROM inserted ins
        INNER JOIN deleted del ON ins.order_id = del.order_id
        WHERE ins.order_status = N'CANCELLED' AND del.order_status <> N'CANCELLED'
    )
    BEGIN
        DECLARE @CancelledOrders TABLE (order_id INT);
        INSERT INTO @CancelledOrders (order_id)
        SELECT ins.order_id
        FROM inserted ins
        INNER JOIN deleted del ON ins.order_id = del.order_id
        WHERE ins.order_status = N'CANCELLED' AND del.order_status <> N'CANCELLED';

        -- Record audit snapshot
        DECLARE @RestoreData TABLE (
            product_id INT,
            warehouse_id INT,
            qty_to_restore INT,
            prev_qty INT,
            order_id INT
        );

        INSERT INTO @RestoreData (product_id, warehouse_id, qty_to_restore, prev_qty, order_id)
        SELECT 
            oi.product_id, 
            oi.warehouse_id, 
            oi.quantity, 
            inv.quantity_on_hand, 
            oi.order_id
        FROM dbo.Order_Items oi
        INNER JOIN @CancelledOrders co ON oi.order_id = co.order_id
        INNER JOIN dbo.Inventory inv ON oi.product_id = inv.product_id AND oi.warehouse_id = inv.warehouse_id;

        -- Restore stock to inventory
        UPDATE inv
        SET inv.quantity_on_hand = inv.quantity_on_hand + rd.qty_to_restore,
            inv.last_updated_at = SYSUTCDATETIME()
        FROM dbo.Inventory inv
        INNER JOIN @RestoreData rd 
            ON inv.product_id = rd.product_id 
            AND inv.warehouse_id = rd.warehouse_id;

        -- Write restorative entries to Inventory_Audit_Log
        INSERT INTO dbo.Inventory_Audit_Log (
            product_id, warehouse_id, change_type, quantity_change, 
            previous_quantity, new_quantity, reference_id, logged_by
        )
        SELECT 
            product_id, 
            warehouse_id, 
            N'ORDER_CANCEL_RESTORE', 
            qty_to_restore, 
            prev_qty, 
            (prev_qty + qty_to_restore), 
            order_id, 
            N'TRG_Orders_RestoreStockOnCancel'
        FROM @RestoreData;
    END
END;
GO

PRINT 'Triggers created successfully (Stock Auto-Deduct, Status History Audit, Cancel Stock Restoration).';
GO

