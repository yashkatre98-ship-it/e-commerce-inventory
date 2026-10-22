-- ============================================================================
-- E-COMMERCE INVENTORY & ORDER MANAGEMENT SYSTEM (DBMS PROJECT)
-- Dialect: Microsoft SQL Server (T-SQL)
-- Script 03: Functions, Table Types & Stored Procedures (ACID Transactions)
-- ============================================================================

USE EcommerceInventoryDB;
GO

-- ============================================================================
-- 1. USER-DEFINED TABLE TYPE: OrderItemTableType
-- Allows passing structured order items array to stored procedures.
-- ============================================================================
IF TYPE_ID(N'dbo.OrderItemTableType') IS NOT NULL
    DROP TYPE dbo.OrderItemTableType;
GO

CREATE TYPE dbo.OrderItemTableType AS TABLE (
    product_id   INT NOT NULL,
    warehouse_id INT NOT NULL,
    quantity     INT NOT NULL
);
GO

-- ============================================================================
-- 2. SCALAR FUNCTION: fn_GetTotalProductStock
-- Returns total available stock for a product across all active warehouses.
-- ============================================================================
IF OBJECT_ID('dbo.fn_GetTotalProductStock', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_GetTotalProductStock;
GO

CREATE FUNCTION dbo.fn_GetTotalProductStock (@ProductID INT)
RETURNS INT
AS
BEGIN
    DECLARE @TotalStock INT;

    SELECT @TotalStock = COALESCE(SUM(quantity_on_hand), 0)
    FROM dbo.Inventory
    WHERE product_id = @ProductID;

    RETURN @TotalStock;
END;
GO

-- ============================================================================
-- 3. SCALAR FUNCTION: fn_CalculateCouponDiscount
-- Computes discount amount based on coupon rules, min spend, and max cap.
-- ============================================================================
IF OBJECT_ID('dbo.fn_CalculateCouponDiscount', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_CalculateCouponDiscount;
GO

CREATE FUNCTION dbo.fn_CalculateCouponDiscount (
    @CouponCode NVARCHAR(30),
    @Subtotal   DECIMAL(12, 2)
)
RETURNS DECIMAL(12, 2)
AS
BEGIN
    DECLARE @Discount DECIMAL(12, 2) = 0.00;
    DECLARE @Type NVARCHAR(20);
    DECLARE @Value DECIMAL(10, 2);
    DECLARE @MinOrder DECIMAL(10, 2);
    DECLARE @MaxDiscount DECIMAL(10, 2);
    DECLARE @ValidFrom DATETIME2;
    DECLARE @ValidTo DATETIME2;
    DECLARE @UsageLimit INT;
    DECLARE @TimesUsed INT;
    DECLARE @IsActive BIT;

    SELECT 
        @Type = discount_type,
        @Value = discount_value,
        @MinOrder = min_order_amount,
        @MaxDiscount = max_discount_amount,
        @ValidFrom = valid_from,
        @ValidTo = valid_to,
        @UsageLimit = usage_limit,
        @TimesUsed = times_used,
        @IsActive = is_active
    FROM dbo.Coupons
    WHERE coupon_code = @CouponCode;

    -- Validate coupon eligibility
    IF @Type IS NOT NULL
       AND @IsActive = 1
       AND SYSUTCDATETIME() BETWEEN @ValidFrom AND @ValidTo
       AND @TimesUsed < @UsageLimit
       AND @Subtotal >= @MinOrder
    BEGIN
        IF @Type = N'PERCENTAGE'
        BEGIN
            SET @Discount = (@Subtotal * @Value) / 100.00;
            IF @MaxDiscount IS NOT NULL AND @Discount > @MaxDiscount
                SET @Discount = @MaxDiscount;
        END
        ELSE IF @Type = N'FIXED_AMOUNT'
        BEGIN
            SET @Discount = @Value;
            IF @Discount > @Subtotal
                SET @Discount = @Subtotal;
        END
    END

    RETURN ROUND(@Discount, 2);
END;
GO

-- ============================================================================
-- 4. TABLE-VALUED FUNCTION: fn_CustomerLifetimeValue
-- Computes customer order metrics, spend, and average order value.
-- ============================================================================
IF OBJECT_ID('dbo.fn_CustomerLifetimeValue', 'IF') IS NOT NULL
    DROP FUNCTION dbo.fn_CustomerLifetimeValue;
GO

CREATE FUNCTION dbo.fn_CustomerLifetimeValue (@CustomerID INT)
RETURNS TABLE
AS
RETURN (
    SELECT 
        c.customer_id,
        CONCAT(c.first_name, N' ', c.last_name) AS customer_name,
        c.email,
        c.loyalty_points,
        COUNT(o.order_id) AS total_orders_placed,
        SUM(CASE WHEN o.order_status <> N'CANCELLED' THEN 1 ELSE 0 END) AS successful_orders,
        COALESCE(SUM(CASE WHEN o.order_status <> N'CANCELLED' THEN o.total_amount ELSE 0 END), 0.00) AS total_lifetime_spent,
        COALESCE(AVG(CASE WHEN o.order_status <> N'CANCELLED' THEN o.total_amount ELSE NULL END), 0.00) AS average_order_value
    FROM dbo.Customers c
    LEFT JOIN dbo.Orders o ON c.customer_id = o.customer_id
    WHERE c.customer_id = @CustomerID
    GROUP BY c.customer_id, c.first_name, c.last_name, c.email, c.loyalty_points
);
GO

-- ============================================================================
-- 5. STORED PROCEDURE: sp_PlaceOrder
-- ACID Compliant Order Placement
-- Handles coupon application, tax calculation, inventory validation, order items,
-- automated inventory decrement trigger, and payment record creation.
-- ============================================================================
IF OBJECT_ID('dbo.sp_PlaceOrder', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_PlaceOrder;
GO

CREATE PROCEDURE dbo.sp_PlaceOrder
    @CustomerID       INT,
    @ShippingAddress  NVARCHAR(300),
    @CouponCode       NVARCHAR(30) = NULL,
    @PaymentMethod    NVARCHAR(30) = N'CREDIT_CARD',
    @ShippingFee      DECIMAL(10, 2) = 0.00,
    @Notes            NVARCHAR(255) = NULL,
    @Items            dbo.OrderItemTableType READONLY,
    @NewOrderID       INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Validation: Customer exists
        IF NOT EXISTS (SELECT 1 FROM dbo.Customers WHERE customer_id = @CustomerID)
        BEGIN
            RAISERROR (N'Invalid Customer ID provided.', 16, 1);
        END

        -- 2. Validation: Items provided
        IF NOT EXISTS (SELECT 1 FROM @Items)
        BEGIN
            RAISERROR (N'Order must contain at least one line item.', 16, 1);
        END

        -- 3. Calculate Item Lines & Subtotal
        DECLARE @ValidatedItems TABLE (
            product_id   INT,
            warehouse_id INT,
            quantity     INT,
            unit_price   DECIMAL(10, 2),
            line_total   DECIMAL(12, 2)
        );

        INSERT INTO @ValidatedItems (product_id, warehouse_id, quantity, unit_price, line_total)
        SELECT 
            it.product_id,
            it.warehouse_id,
            it.quantity,
            p.unit_price,
            (it.quantity * p.unit_price)
        FROM @Items it
        INNER JOIN dbo.Products p ON it.product_id = p.product_id
        WHERE p.is_active = 1;

        -- Ensure all items were resolved
        IF (SELECT COUNT(*) FROM @ValidatedItems) <> (SELECT COUNT(*) FROM @Items)
        BEGIN
            RAISERROR (N'One or more requested products are invalid or inactive.', 16, 1);
        END

        -- Check stock availability before initiating order
        IF EXISTS (
            SELECT 1 
            FROM @ValidatedItems vi
            LEFT JOIN dbo.Inventory inv 
                ON vi.product_id = inv.product_id 
                AND vi.warehouse_id = inv.warehouse_id
            WHERE inv.inventory_id IS NULL OR inv.quantity_on_hand < vi.quantity
        )
        BEGIN
            RAISERROR (N'Insufficient stock available in requested warehouse for one or more items.', 16, 1);
        END

        -- 4. Calculate Financials
        DECLARE @Subtotal DECIMAL(12, 2) = 0.00;
        SELECT @Subtotal = SUM(line_total) FROM @ValidatedItems;

        DECLARE @DiscountAmount DECIMAL(12, 2) = 0.00;
        DECLARE @CouponID INT = NULL;

        IF @CouponCode IS NOT NULL AND LEN(TRIM(@CouponCode)) > 0
        BEGIN
            SELECT @CouponID = coupon_id FROM dbo.Coupons WHERE coupon_code = @CouponCode;
            IF @CouponID IS NOT NULL
            BEGIN
                SET @DiscountAmount = dbo.fn_CalculateCouponDiscount(@CouponCode, @Subtotal);
                -- Increment coupon usage
                UPDATE dbo.Coupons
                SET times_used = times_used + 1
                WHERE coupon_id = @CouponID;
            END
        END

        -- Standard 8% sales tax calculation on discounted subtotal
        DECLARE @TaxableAmount DECIMAL(12, 2) = @Subtotal - @DiscountAmount;
        IF @TaxableAmount < 0 SET @TaxableAmount = 0.00;
        DECLARE @TaxAmount DECIMAL(12, 2) = ROUND(@TaxableAmount * 0.08, 2);

        DECLARE @TotalAmount DECIMAL(12, 2) = @TaxableAmount + @TaxAmount + @ShippingFee;

        -- 5. Insert Order
        INSERT INTO dbo.Orders (
            customer_id, order_date, order_status, subtotal, 
            discount_amount, tax_amount, shipping_fee, total_amount, 
            coupon_id, shipping_address, notes
        )
        VALUES (
            @CustomerID, SYSUTCDATETIME(), N'CONFIRMED', @Subtotal,
            @DiscountAmount, @TaxAmount, @ShippingFee, @TotalAmount,
            @CouponID, @ShippingAddress, @Notes
        );

        SET @NewOrderID = SCOPE_IDENTITY();

        -- 6. Insert Order Items (Trigger TRG_OrderItems_DeductStock will decrement inventory)
        INSERT INTO dbo.Order_Items (order_id, product_id, warehouse_id, quantity, unit_price, line_total)
        SELECT @NewOrderID, product_id, warehouse_id, quantity, unit_price, line_total
        FROM @ValidatedItems;

        -- 7. Record Payment
        DECLARE @TxRef NVARCHAR(100) = CONCAT(N'TXN-', FORMAT(SYSUTCDATETIME(), N'yyyyMMddHHmmss'), N'-', @NewOrderID);

        INSERT INTO dbo.Payments (
            order_id, payment_date, payment_method, payment_status, amount, transaction_reference
        )
        VALUES (
            @NewOrderID, SYSUTCDATETIME(), @PaymentMethod, N'COMPLETED', @TotalAmount, @TxRef
        );

        -- 8. Award Loyalty Points (1 point per whole $10 spent)
        DECLARE @PointsEarned INT = FLOOR(@TotalAmount / 10.00);
        IF @PointsEarned > 0
        BEGIN
            UPDATE dbo.Customers
            SET loyalty_points = loyalty_points + @PointsEarned
            WHERE customer_id = @CustomerID;
        END

        COMMIT TRANSACTION;
        PRINT CONCAT(N'Order #', @NewOrderID, N' placed successfully. Total: $', @TotalAmount);
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrState INT = ERROR_STATE();
        RAISERROR (@ErrMsg, @ErrSeverity, @ErrState);
    END CATCH;
END;
GO

-- ============================================================================
-- 6. STORED PROCEDURE: sp_RestockProduct
-- Adds quantity to a specific product in a warehouse with full audit trail.
-- ============================================================================
IF OBJECT_ID('dbo.sp_RestockProduct', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_RestockProduct;
GO

CREATE PROCEDURE dbo.sp_RestockProduct
    @ProductID    INT,
    @WarehouseID  INT,
    @Quantity     INT,
    @RestockedBy  NVARCHAR(60) = N'MANAGER'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @Quantity <= 0
        BEGIN
            RAISERROR (N'Restock quantity must be greater than zero.', 16, 1);
        END

        IF NOT EXISTS (SELECT 1 FROM dbo.Products WHERE product_id = @ProductID)
        BEGIN
            RAISERROR (N'Product not found.', 16, 1);
        END

        IF NOT EXISTS (SELECT 1 FROM dbo.Warehouses WHERE warehouse_id = @WarehouseID)
        BEGIN
            RAISERROR (N'Warehouse not found.', 16, 1);
        END

        DECLARE @PrevQty INT = 0;

        -- Check if row already exists in Inventory
        IF EXISTS (SELECT 1 FROM dbo.Inventory WHERE product_id = @ProductID AND warehouse_id = @WarehouseID)
        BEGIN
            SELECT @PrevQty = quantity_on_hand 
            FROM dbo.Inventory 
            WHERE product_id = @ProductID AND warehouse_id = @WarehouseID;

            UPDATE dbo.Inventory
            SET quantity_on_hand = quantity_on_hand + @Quantity,
                last_restocked_at = SYSUTCDATETIME(),
                last_updated_at = SYSUTCDATETIME()
            WHERE product_id = @ProductID AND warehouse_id = @WarehouseID;
        END
        ELSE
        BEGIN
            -- First stock addition for this product-warehouse combination
            INSERT INTO dbo.Inventory (product_id, warehouse_id, quantity_on_hand, quantity_reserved, last_restocked_at, last_updated_at)
            VALUES (@ProductID, @WarehouseID, @Quantity, 0, SYSUTCDATETIME(), SYSUTCDATETIME());
        END

        -- Audit log entry
        INSERT INTO dbo.Inventory_Audit_Log (
            product_id, warehouse_id, change_type, quantity_change,
            previous_quantity, new_quantity, reference_id, logged_by
        )
        VALUES (
            @ProductID, @WarehouseID, N'RESTOCK', @Quantity,
            @PrevQty, (@PrevQty + @Quantity), NULL, @RestockedBy
        );

        COMMIT TRANSACTION;
        PRINT CONCAT(N'Product ID ', @ProductID, N' in Warehouse ', @WarehouseID, N' successfully restocked by +', @Quantity, N' units.');
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- ============================================================================
-- 7. STORED PROCEDURE: sp_TransferWarehouseStock
-- Atomically transfers inventory from one warehouse to another.
-- ============================================================================
IF OBJECT_ID('dbo.sp_TransferWarehouseStock', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_TransferWarehouseStock;
GO

CREATE PROCEDURE dbo.sp_TransferWarehouseStock
    @ProductID         INT,
    @FromWarehouseID   INT,
    @ToWarehouseID     INT,
    @Quantity          INT,
    @Notes             NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @FromWarehouseID = @ToWarehouseID
        BEGIN
            RAISERROR (N'Source and destination warehouses cannot be identical.', 16, 1);
        END

        IF @Quantity <= 0
        BEGIN
            RAISERROR (N'Transfer quantity must be greater than zero.', 16, 1);
        END

        -- Verify available stock in source warehouse
        DECLARE @SourceStock INT = 0;
        SELECT @SourceStock = quantity_on_hand 
        FROM dbo.Inventory 
        WHERE product_id = @ProductID AND warehouse_id = @FromWarehouseID;

        IF @SourceStock IS NULL OR @SourceStock < @Quantity
        BEGIN
            RAISERROR (N'Insufficient stock in source warehouse to perform transfer.', 16, 1);
        END

        -- 1. Deduct from source warehouse
        UPDATE dbo.Inventory
        SET quantity_on_hand = quantity_on_hand - @Quantity,
            last_updated_at = SYSUTCDATETIME()
        WHERE product_id = @ProductID AND warehouse_id = @FromWarehouseID;

        -- 2. Add to destination warehouse (or insert if not yet existing)
        DECLARE @DestStock INT = 0;
        IF EXISTS (SELECT 1 FROM dbo.Inventory WHERE product_id = @ProductID AND warehouse_id = @ToWarehouseID)
        BEGIN
            SELECT @DestStock = quantity_on_hand 
            FROM dbo.Inventory 
            WHERE product_id = @ProductID AND warehouse_id = @ToWarehouseID;

            UPDATE dbo.Inventory
            SET quantity_on_hand = quantity_on_hand + @Quantity,
                last_updated_at = SYSUTCDATETIME()
            WHERE product_id = @ProductID AND warehouse_id = @ToWarehouseID;
        END
        ELSE
        BEGIN
            INSERT INTO dbo.Inventory (product_id, warehouse_id, quantity_on_hand, quantity_reserved, last_restocked_at, last_updated_at)
            VALUES (@ProductID, @ToWarehouseID, @Quantity, 0, SYSUTCDATETIME(), SYSUTCDATETIME());
        END

        -- 3. Record transfer record
        INSERT INTO dbo.Stock_Transfers (
            product_id, from_warehouse_id, to_warehouse_id, quantity, transfer_status, transfer_date, notes
        )
        VALUES (
            @ProductID, @FromWarehouseID, @ToWarehouseID, @Quantity, N'COMPLETED', SYSUTCDATETIME(), @Notes
        );

        DECLARE @TransferID INT = SCOPE_IDENTITY();

        -- 4. Audit entries
        INSERT INTO dbo.Inventory_Audit_Log (
            product_id, warehouse_id, change_type, quantity_change, previous_quantity, new_quantity, reference_id, logged_by
        )
        VALUES 
            (@ProductID, @FromWarehouseID, N'TRANSFER_OUT', -@Quantity, @SourceStock, (@SourceStock - @Quantity), @TransferID, N'sp_TransferWarehouseStock'),
            (@ProductID, @ToWarehouseID, N'TRANSFER_IN', @Quantity, @DestStock, (@DestStock + @Quantity), @TransferID, N'sp_TransferWarehouseStock');

        COMMIT TRANSACTION;
        PRINT CONCAT(N'Successfully transferred ', @Quantity, N' units of product ', @ProductID, N' from WH ', @FromWarehouseID, N' to WH ', @ToWarehouseID);
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- ============================================================================
-- 8. STORED PROCEDURE: sp_CancelOrder
-- Cancels an order, updates payment status, and activates stock restore trigger.
-- ============================================================================
IF OBJECT_ID('dbo.sp_CancelOrder', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_CancelOrder;
GO

CREATE PROCEDURE dbo.sp_CancelOrder
    @OrderID            INT,
    @CancellationReason NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @CurrentStatus NVARCHAR(30);
        SELECT @CurrentStatus = order_status FROM dbo.Orders WHERE order_id = @OrderID;

        IF @CurrentStatus IS NULL
        BEGIN
            RAISERROR (N'Order ID does not exist.', 16, 1);
        END

        IF @CurrentStatus IN (N'DELIVERED', N'CANCELLED')
        BEGIN
            RAISERROR (N'Cannot cancel an order that is already DELIVERED or CANCELLED.', 16, 1);
        END

        -- Updating order status to CANCELLED will automatically fire TRG_Orders_RestoreStockOnCancel
        UPDATE dbo.Orders
        SET order_status = N'CANCELLED',
            notes = CONCAT(COALESCE(notes + N' | ', N''), N'Cancelled: ', @CancellationReason)
        WHERE order_id = @OrderID;

        -- Update payment record to REFUNDED if completed
        UPDATE dbo.Payments
        SET payment_status = N'REFUNDED'
        WHERE order_id = @OrderID AND payment_status = N'COMPLETED';

        COMMIT TRANSACTION;
        PRINT CONCAT(N'Order #', @OrderID, N' cancelled successfully. Stock restored.');
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

PRINT 'Functions, User-Defined Table Types, and Stored Procedures created successfully.';
GO

