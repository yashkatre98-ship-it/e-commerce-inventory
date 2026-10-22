"""
E-Commerce Inventory & Order Management System - Web Application
Zero-dependency Python HTTP Server with SQLite Database and Real DBMS Triggers.
Runs on: http://localhost:5000
"""

import http.server
import socketserver
import json
import sqlite3
import os
import sys
import urllib.parse
from datetime import datetime

PORT = 5000
DB_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ecommerce.db")

def init_db():
    conn = sqlite3.connect(DB_FILE)
    c = conn.cursor()
    c.execute("PRAGMA foreign_keys = ON;")

    # Drop existing tables
    c.executescript("""
    DROP TABLE IF EXISTS inventory_audit_log;
    DROP TABLE IF EXISTS order_status_history;
    DROP TABLE IF EXISTS shipments;
    DROP TABLE IF EXISTS payments;
    DROP TABLE IF EXISTS order_items;
    DROP TABLE IF EXISTS orders;
    DROP TABLE IF EXISTS coupons;
    DROP TABLE IF EXISTS stock_transfers;
    DROP TABLE IF EXISTS inventory;
    DROP TABLE IF EXISTS warehouses;
    DROP TABLE IF EXISTS products;
    DROP TABLE IF EXISTS categories;
    DROP TABLE IF EXISTS suppliers;
    DROP TABLE IF EXISTS customers;

    -- Suppliers
    CREATE TABLE suppliers (
        supplier_id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_name TEXT NOT NULL UNIQUE,
        contact_name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        phone TEXT NOT NULL,
        city TEXT NOT NULL,
        rating REAL DEFAULT 5.0
    );

    -- Categories
    CREATE TABLE categories (
        category_id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_name TEXT NOT NULL UNIQUE,
        description TEXT,
        parent_category_id INTEGER,
        FOREIGN KEY (parent_category_id) REFERENCES categories(category_id)
    );

    -- Products
    CREATE TABLE products (
        product_id INTEGER PRIMARY KEY AUTOINCREMENT,
        sku TEXT NOT NULL UNIQUE,
        product_name TEXT NOT NULL,
        category_id INTEGER NOT NULL,
        supplier_id INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        cost_price REAL NOT NULL,
        reorder_level INTEGER DEFAULT 10,
        FOREIGN KEY (category_id) REFERENCES categories(category_id),
        FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id)
    );

    -- Warehouses
    CREATE TABLE warehouses (
        warehouse_id INTEGER PRIMARY KEY AUTOINCREMENT,
        warehouse_name TEXT NOT NULL UNIQUE,
        city TEXT NOT NULL,
        state TEXT NOT NULL,
        capacity INTEGER NOT NULL
    );

    -- Inventory
    CREATE TABLE inventory (
        inventory_id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        warehouse_id INTEGER NOT NULL,
        quantity_on_hand INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (product_id) REFERENCES products(product_id),
        FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id),
        UNIQUE(product_id, warehouse_id)
    );

    -- Customers
    CREATE TABLE customers (
        customer_id INTEGER PRIMARY KEY AUTOINCREMENT,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        phone TEXT NOT NULL,
        loyalty_points INTEGER DEFAULT 0
    );

    -- Coupons
    CREATE TABLE coupons (
        coupon_id INTEGER PRIMARY KEY AUTOINCREMENT,
        coupon_code TEXT NOT NULL UNIQUE,
        discount_type TEXT NOT NULL, -- PERCENTAGE or FIXED_AMOUNT
        discount_value REAL NOT NULL,
        min_order_amount REAL DEFAULT 0.0,
        is_active INTEGER DEFAULT 1
    );

    -- Orders
    CREATE TABLE orders (
        order_id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        order_date TEXT NOT NULL,
        order_status TEXT DEFAULT 'CONFIRMED',
        subtotal REAL NOT NULL,
        discount_amount REAL DEFAULT 0.0,
        tax_amount REAL DEFAULT 0.0,
        shipping_fee REAL DEFAULT 0.0,
        total_amount REAL NOT NULL,
        shipping_address TEXT NOT NULL,
        notes TEXT,
        FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
    );

    -- Order Items
    CREATE TABLE order_items (
        order_item_id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        warehouse_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        line_total REAL NOT NULL,
        FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products(product_id),
        FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id)
    );

    -- Payments
    CREATE TABLE payments (
        payment_id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        payment_method TEXT NOT NULL,
        payment_status TEXT DEFAULT 'COMPLETED',
        amount REAL NOT NULL,
        transaction_reference TEXT NOT NULL UNIQUE,
        FOREIGN KEY (order_id) REFERENCES orders(order_id)
    );

    -- Order Status History (Audit)
    CREATE TABLE order_status_history (
        history_id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        old_status TEXT,
        new_status TEXT NOT NULL,
        changed_at TEXT NOT NULL,
        changed_by TEXT DEFAULT 'SYSTEM'
    );

    -- Inventory Audit Log (Audit)
    CREATE TABLE inventory_audit_log (
        audit_id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        warehouse_id INTEGER NOT NULL,
        change_type TEXT NOT NULL,
        quantity_change INTEGER NOT NULL,
        previous_quantity INTEGER NOT NULL,
        new_quantity INTEGER NOT NULL,
        reference_id INTEGER,
        logged_at TEXT NOT NULL,
        logged_by TEXT DEFAULT 'SYSTEM'
    );

    -- ========================================================================
    -- DBMS TRIGGERS
    -- ========================================================================

    -- Trigger 1: Stock Check & Auto-Deduct on Order Placement
    CREATE TRIGGER trg_order_items_deduct
    AFTER INSERT ON order_items
    BEGIN
        -- Deduct inventory
        UPDATE inventory
        SET quantity_on_hand = quantity_on_hand - NEW.quantity
        WHERE product_id = NEW.product_id AND warehouse_id = NEW.warehouse_id;

        -- Record audit
        INSERT INTO inventory_audit_log (
            product_id, warehouse_id, change_type, quantity_change,
            previous_quantity, new_quantity, reference_id, logged_at, logged_by
        )
        VALUES (
            NEW.product_id, NEW.warehouse_id, 'ORDER_DEDUCT', -NEW.quantity,
            (SELECT quantity_on_hand + NEW.quantity FROM inventory WHERE product_id = NEW.product_id AND warehouse_id = NEW.warehouse_id),
            (SELECT quantity_on_hand FROM inventory WHERE product_id = NEW.product_id AND warehouse_id = NEW.warehouse_id),
            NEW.order_id, datetime('now'), 'TRG_ORDER_ITEMS_DEDUCT'
        );
    END;

    -- Trigger 2: Order Status Audit Log
    CREATE TRIGGER trg_orders_audit
    AFTER UPDATE OF order_status ON orders
    BEGIN
        INSERT INTO order_status_history (order_id, old_status, new_status, changed_at, changed_by)
        VALUES (NEW.order_id, OLD.order_status, NEW.order_status, datetime('now'), 'TRG_STATUS_AUDIT');
    END;

    -- Trigger 3: Restore Stock on Order Cancellation
    CREATE TRIGGER trg_orders_restore_cancel
    AFTER UPDATE OF order_status ON orders
    WHEN NEW.order_status = 'CANCELLED' AND OLD.order_status != 'CANCELLED'
    BEGIN
        -- Update inventory by adding ordered quantities back
        UPDATE inventory
        SET quantity_on_hand = quantity_on_hand + (
            SELECT oi.quantity FROM order_items oi 
            WHERE oi.order_id = NEW.order_id 
              AND oi.product_id = inventory.product_id 
              AND oi.warehouse_id = inventory.warehouse_id
        )
        WHERE (product_id, warehouse_id) IN (
            SELECT product_id, warehouse_id FROM order_items WHERE order_id = NEW.order_id
        );

        -- Audit log entry
        INSERT INTO inventory_audit_log (product_id, warehouse_id, change_type, quantity_change, previous_quantity, new_quantity, reference_id, logged_at, logged_by)
        SELECT 
            oi.product_id, oi.warehouse_id, 'ORDER_CANCEL_RESTORE', oi.quantity,
            inv.quantity_on_hand - oi.quantity, inv.quantity_on_hand,
            NEW.order_id, datetime('now'), 'TRG_ORDERS_RESTORE_CANCEL'
        FROM order_items oi
        JOIN inventory inv ON oi.product_id = inv.product_id AND oi.warehouse_id = inv.warehouse_id
        WHERE oi.order_id = NEW.order_id;
    END;
    """)

    # Populate Seed Data
    c.executescript("""
    -- Suppliers
    INSERT INTO suppliers (company_name, contact_name, email, phone, city, rating) VALUES
    ('Apex Electronics Global', 'Marcus Vance', 'marcus@apexelectronics.com', '+1-555-0101', 'San Jose', 4.9),
    ('OmniTech Components Inc.', 'Elena Rostova', 'elena@omnitech.com', '+1-555-0102', 'Austin', 4.7),
    ('Nexus Logistics & Supply', 'David Kim', 'david.kim@nexussupply.com', '+1-555-0103', 'Seattle', 4.5),
    ('PureSound Audio Labs', 'Sarah Jenkins', 'sarah@puresound.com', '+1-555-0104', 'Boston', 4.8),
    ('ErgoPro Office Innovations', 'Tariq Mansoor', 'tariq@ergopro.com', '+1-555-0105', 'Chicago', 4.6);

    -- Categories
    INSERT INTO categories (category_name, description, parent_category_id) VALUES
    ('Computers & Laptops', 'Laptops, ultrabooks, workstations', NULL),
    ('Audio & Sound', 'Headphones and speakers', NULL),
    ('Office & Ergonomics', 'Desks, chairs, mounts', NULL),
    ('Computer Peripherals', 'Keyboards, mice, monitors', NULL);

    -- Products
    INSERT INTO products (sku, product_name, category_id, supplier_id, unit_price, cost_price, reorder_level) VALUES
    ('LAP-ROG-001', 'Asus ROG Zephyrus G16', 1, 1, 2499.99, 1850.00, 5),
    ('LAP-MBA-002', 'Apple MacBook Air M3', 1, 1, 1299.00, 980.00, 8),
    ('AUD-SNY-003', 'Sony WH-1000XM5 Wireless', 2, 4, 398.00, 240.00, 15),
    ('AUD-APP-004', 'Apple AirPods Pro 2nd Gen', 2, 1, 249.00, 165.00, 20),
    ('DKS-ERG-005', 'ErgoPro Apex Standing Desk', 3, 5, 680.00, 410.00, 6),
    ('CHR-ERG-006', 'AeroMesh Ergonomic Task Chair', 3, 5, 450.00, 260.00, 10),
    ('KBD-KEY-007', 'Keychron Q1 Pro Wireless Custom', 4, 2, 199.00, 115.00, 12),
    ('MOU-LOG-008', 'Logitech MX Master 3S', 4, 2, 99.99, 58.00, 25),
    ('MON-DEL-009', 'Dell UltraSharp 32-inch 4K', 4, 3, 749.50, 480.00, 7),
    ('CAM-LOG-010', 'Logitech Brio 4K Webcam', 4, 3, 169.99, 95.00, 10);

    -- Warehouses
    INSERT INTO warehouses (warehouse_name, city, state, capacity) VALUES
    ('West Coast Fulfillment Hub', 'Long Beach', 'CA', 50000),
    ('East Coast Distribution Center', 'Secaucus', 'NJ', 45000),
    ('Central Midwest Logistics Center', 'Chicago', 'IL', 35000);

    -- Inventory
    INSERT INTO inventory (product_id, warehouse_id, quantity_on_hand) VALUES
    (1, 1, 15), (1, 2, 8),  (1, 3, 3),
    (2, 1, 25), (2, 2, 18), (2, 3, 12),
    (3, 1, 40), (3, 2, 30), (3, 3, 20),
    (4, 1, 60), (4, 2, 55), (4, 3, 40),
    (5, 1, 2),  (5, 2, 1),  (5, 3, 1),  -- Low stock!
    (6, 1, 14), (6, 2, 10), (6, 3, 8),
    (7, 1, 22), (7, 2, 15), (7, 3, 9),
    (8, 1, 80), (8, 2, 70), (8, 3, 45),
    (9, 1, 4),  (9, 2, 2),  (9, 3, 0),  -- Low stock!
    (10, 1, 18), (10, 2, 14), (10, 3, 12);

    -- Customers
    INSERT INTO customers (first_name, last_name, email, phone, loyalty_points) VALUES
    ('Alexander', 'Wright', 'alex.wright@example.com', '+1-555-0201', 150),
    ('Sophia', 'Chen', 'sophia.chen@techcorp.io', '+1-555-0202', 380),
    ('Liam', 'O''Connor', 'liam.oc@domain.com', '+1-555-0203', 95),
    ('Maya', 'Patel', 'maya.patel@designstudio.net', '+1-555-0204', 520),
    ('Jordan', 'Taylor', 'jordan.taylor@freelance.org', '+1-555-0205', 45);

    -- Coupons
    INSERT INTO coupons (coupon_code, discount_type, discount_value, min_order_amount, is_active) VALUES
    ('WELCOME10', 'PERCENTAGE', 10.0, 100.0, 1),
    ('TECHSAVE50', 'FIXED_AMOUNT', 50.0, 500.0, 1),
    ('VIP20', 'PERCENTAGE', 20.0, 1000.0, 1);

    -- Initial Sample Order
    INSERT INTO orders (order_id, customer_id, order_date, order_status, subtotal, discount_amount, tax_amount, shipping_fee, total_amount, shipping_address, notes)
    VALUES (1001, 1, datetime('now', '-2 days'), 'CONFIRMED', 1299.00, 50.00, 99.92, 0.00, 1348.92, '742 Evergreen Terrace, Springfield, OR', 'Initial test order');

    INSERT INTO order_items (order_id, product_id, warehouse_id, quantity, unit_price, line_total)
    VALUES (1001, 2, 1, 1, 1299.00, 1299.00);

    INSERT INTO payments (order_id, payment_method, payment_status, amount, transaction_reference)
    VALUES (1001, 'CREDIT_CARD', 'COMPLETED', 1348.92, 'TXN-INIT-1001');

    INSERT INTO inventory_audit_log (product_id, warehouse_id, change_type, quantity_change, previous_quantity, new_quantity, reference_id, logged_at, logged_by)
    VALUES (2, 1, 'RESTOCK', 26, 0, 26, NULL, datetime('now', '-5 days'), 'INITIAL_SEED');
    """)
    conn.commit()
    conn.close()
    print("SQLite Database initialized with full schema, triggers, and seed data.")

# HTML Web Dashboard
HTML_PAGE = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>E-Commerce Inventory & Order DBMS Dashboard</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
        body { font-family: 'Plus Jakarta Sans', sans-serif; }
        .glass-card { background: rgba(255, 255, 255, 0.95); backdrop-filter: blur(10px); }
    </style>
</head>
<body class="bg-slate-900 text-slate-100 min-h-screen">
    <!-- Navbar -->
    <header class="border-b border-slate-800 bg-slate-950/80 sticky top-0 z-50 backdrop-blur-md">
        <div class="max-w-7xl mx-auto px-6 py-4 flex items-center justify-between">
            <div class="flex items-center space-x-3">
                <div class="w-10 h-10 rounded-xl bg-gradient-to-tr from-indigo-500 to-purple-600 flex items-center justify-center font-black text-xl shadow-lg shadow-indigo-500/30">
                    📦
                </div>
                <div>
                    <h1 class="text-xl font-bold bg-gradient-to-r from-white via-slate-200 to-indigo-300 bg-clip-text text-transparent">
                        E-Commerce DBMS Portal
                    </h1>
                    <p class="text-xs text-indigo-400 font-medium">Enterprise Inventory & Order Automation</p>
                </div>
            </div>
            <div class="flex items-center space-x-4">
                <button onclick="openOrderModal()" class="px-4 py-2 bg-gradient-to-r from-indigo-600 to-blue-600 hover:from-indigo-500 hover:to-blue-500 rounded-lg text-sm font-semibold shadow-lg shadow-indigo-500/25 transition flex items-center space-x-2">
                    <span>⚡ Place Live Order</span>
                </button>
                <button onclick="refreshData()" class="p-2 bg-slate-800 hover:bg-slate-700 text-slate-300 rounded-lg transition" title="Refresh Database">
                    🔄
                </button>
            </div>
        </div>
    </header>

    <!-- Main Content Container -->
    <main class="max-w-7xl mx-auto px-6 py-8 space-y-8">
        
        <!-- Live Alert Notification Toast -->
        <div id="toast" class="hidden fixed bottom-6 right-6 max-w-md p-4 rounded-xl shadow-2xl z-50 border transition-all duration-300 transform translate-y-2"></div>

        <!-- Metric KPI Cards -->
        <div class="grid grid-cols-1 md:grid-cols-4 gap-6">
            <div class="p-6 rounded-2xl bg-slate-800/60 border border-slate-700/60 relative overflow-hidden">
                <div class="text-slate-400 text-xs font-semibold uppercase tracking-wider">Total Sales Volume</div>
                <div id="kpi-sales" class="text-3xl font-black mt-2 text-white">$0.00</div>
                <div class="text-xs text-emerald-400 mt-1 font-medium flex items-center">
                    <span class="mr-1">✓</span> Confirmed & settled orders
                </div>
            </div>

            <div class="p-6 rounded-2xl bg-slate-800/60 border border-slate-700/60 relative overflow-hidden">
                <div class="text-slate-400 text-xs font-semibold uppercase tracking-wider">Total Stock Available</div>
                <div id="kpi-stock" class="text-3xl font-black mt-2 text-indigo-400">0</div>
                <div class="text-xs text-slate-400 mt-1 font-medium">Across 3 regional hubs</div>
            </div>

            <div class="p-6 rounded-2xl bg-slate-800/60 border border-slate-700/60 relative overflow-hidden">
                <div class="text-slate-400 text-xs font-semibold uppercase tracking-wider">Low Stock Warnings</div>
                <div id="kpi-low-stock" class="text-3xl font-black mt-2 text-amber-400">0</div>
                <div class="text-xs text-amber-400/80 mt-1 font-medium">Below safety reorder point</div>
            </div>

            <div class="p-6 rounded-2xl bg-slate-800/60 border border-slate-700/60 relative overflow-hidden">
                <div class="text-slate-400 text-xs font-semibold uppercase tracking-wider">Trigger Executions</div>
                <div id="kpi-triggers" class="text-3xl font-black mt-2 text-purple-400">0</div>
                <div class="text-xs text-purple-400 mt-1 font-medium">Automated stock/audit events</div>
            </div>
        </div>

        <!-- Navigation Tabs -->
        <div class="flex border-b border-slate-800 space-x-6 text-sm font-semibold">
            <button onclick="switchTab('inventory')" id="tab-inventory" class="pb-3 border-b-2 border-indigo-500 text-indigo-400 transition">
                📦 Multi-Warehouse Inventory
            </button>
            <button onclick="switchTab('orders')" id="tab-orders" class="pb-3 border-b-2 border-transparent text-slate-400 hover:text-slate-200 transition">
                🛒 Live Orders & Transactions
            </button>
            <button onclick="switchTab('audit')" id="tab-audit" class="pb-3 border-b-2 border-transparent text-slate-400 hover:text-slate-200 transition">
                🔍 DBMS Trigger Audit Trail
            </button>
        </div>

        <!-- Tab 1: Inventory Table -->
        <div id="view-inventory" class="space-y-4">
            <div class="bg-slate-800/40 border border-slate-700/60 rounded-2xl overflow-hidden shadow-xl">
                <div class="px-6 py-4 border-b border-slate-700/60 flex justify-between items-center bg-slate-800/20">
                    <h2 class="font-bold text-lg text-white">Catalog Products & Warehouse Levels</h2>
                    <span class="text-xs text-slate-400">Auto-decremented by DB Triggers upon purchases</span>
                </div>
                <div class="overflow-x-auto">
                    <table class="w-full text-left text-sm">
                        <thead class="bg-slate-900/60 text-slate-400 text-xs uppercase border-b border-slate-700/60">
                            <tr>
                                <th class="px-6 py-3">SKU</th>
                                <th class="px-6 py-3">Product Name</th>
                                <th class="px-6 py-3">Category</th>
                                <th class="px-6 py-3">Warehouse Hub</th>
                                <th class="px-6 py-3 text-right">Price</th>
                                <th class="px-6 py-3 text-center">Stock</th>
                                <th class="px-6 py-3 text-center">Status</th>
                                <th class="px-6 py-3 text-right">Action</th>
                            </tr>
                        </thead>
                        <tbody id="inventory-table-body" class="divide-y divide-slate-800 text-slate-300">
                            <tr><td colspan="8" class="text-center py-6 text-slate-500">Loading inventory data...</td></tr>
                        </tbody>
                    </table>
                </div>
            </div>
        </div>

        <!-- Tab 2: Orders Table -->
        <div id="view-orders" class="hidden space-y-4">
            <div class="bg-slate-800/40 border border-slate-700/60 rounded-2xl overflow-hidden shadow-xl">
                <div class="px-6 py-4 border-b border-slate-700/60 flex justify-between items-center bg-slate-800/20">
                    <h2 class="font-bold text-lg text-white">Customer Orders & Status Lifecycle</h2>
                    <span class="text-xs text-slate-400">Cancelling restores inventory automatically via DBMS Trigger</span>
                </div>
                <div class="overflow-x-auto">
                    <table class="w-full text-left text-sm">
                        <thead class="bg-slate-900/60 text-slate-400 text-xs uppercase border-b border-slate-700/60">
                            <tr>
                                <th class="px-6 py-3">Order #</th>
                                <th class="px-6 py-3">Customer</th>
                                <th class="px-6 py-3">Ordered Items</th>
                                <th class="px-6 py-3 text-right">Total Amount</th>
                                <th class="px-6 py-3 text-center">Status</th>
                                <th class="px-6 py-3 text-right">Action</th>
                            </tr>
                        </thead>
                        <tbody id="orders-table-body" class="divide-y divide-slate-800 text-slate-300">
                            <tr><td colspan="6" class="text-center py-6 text-slate-500">Loading order history...</td></tr>
                        </tbody>
                    </table>
                </div>
            </div>
        </div>

        <!-- Tab 3: DBMS Trigger Audit Trail -->
        <div id="view-audit" class="hidden space-y-4">
            <div class="bg-slate-800/40 border border-slate-700/60 rounded-2xl overflow-hidden shadow-xl">
                <div class="px-6 py-4 border-b border-slate-700/60 flex justify-between items-center bg-slate-800/20">
                    <h2 class="font-bold text-lg text-white">Real-Time DBMS Audit Log</h2>
                    <span class="text-xs text-purple-400 font-semibold">Logged automatically by database triggers</span>
                </div>
                <div class="overflow-x-auto">
                    <table class="w-full text-left text-sm">
                        <thead class="bg-slate-900/60 text-slate-400 text-xs uppercase border-b border-slate-700/60">
                            <tr>
                                <th class="px-6 py-3">Log ID</th>
                                <th class="px-6 py-3">Trigger Action</th>
                                <th class="px-6 py-3">Product Affected</th>
                                <th class="px-6 py-3">Warehouse</th>
                                <th class="px-6 py-3 text-center">Quantity Delta</th>
                                <th class="px-6 py-3 text-center">Previous $\to$ New</th>
                                <th class="px-6 py-3">Reference</th>
                                <th class="px-6 py-3">Timestamp</th>
                            </tr>
                        </thead>
                        <tbody id="audit-table-body" class="divide-y divide-slate-800 text-slate-300">
                            <tr><td colspan="8" class="text-center py-6 text-slate-500">Loading trigger logs...</td></tr>
                        </tbody>
                    </table>
                </div>
            </div>
        </div>

    </main>

    <!-- Modal: Place Order -->
    <div id="order-modal" class="fixed inset-0 bg-black/70 backdrop-blur-sm hidden items-center justify-center z-50 p-4">
        <div class="bg-slate-900 border border-slate-700 rounded-3xl max-w-lg w-full p-6 shadow-2xl relative">
            <div class="flex justify-between items-center mb-6">
                <div>
                    <h3 class="text-lg font-bold text-white">Place Atomic Order</h3>
                    <p class="text-xs text-slate-400">Executes transactional check & auto-deduct trigger</p>
                </div>
                <button onclick="closeOrderModal()" class="text-slate-400 hover:text-white text-xl">✕</button>
            </div>

            <form id="order-form" onsubmit="submitOrder(event)" class="space-y-4">
                <div>
                    <label class="block text-xs font-semibold text-slate-400 mb-1">Select Customer</label>
                    <select id="modal-customer" class="w-full bg-slate-800 border border-slate-700 rounded-xl px-4 py-2.5 text-sm text-white focus:outline-none focus:border-indigo-500">
                    </select>
                </div>

                <div class="grid grid-cols-2 gap-4">
                    <div>
                        <label class="block text-xs font-semibold text-slate-400 mb-1">Select Product</label>
                        <select id="modal-product" onchange="updateStockHint()" class="w-full bg-slate-800 border border-slate-700 rounded-xl px-4 py-2.5 text-sm text-white focus:outline-none focus:border-indigo-500">
                        </select>
                    </div>
                    <div>
                        <label class="block text-xs font-semibold text-slate-400 mb-1">Fulfillment Warehouse</label>
                        <select id="modal-warehouse" onchange="updateStockHint()" class="w-full bg-slate-800 border border-slate-700 rounded-xl px-4 py-2.5 text-sm text-white focus:outline-none focus:border-indigo-500">
                        </select>
                    </div>
                </div>

                <div class="grid grid-cols-2 gap-4">
                    <div>
                        <label class="block text-xs font-semibold text-slate-400 mb-1">Order Quantity</label>
                        <input id="modal-quantity" type="number" min="1" value="1" class="w-full bg-slate-800 border border-slate-700 rounded-xl px-4 py-2.5 text-sm text-white focus:outline-none focus:border-indigo-500">
                    </div>
                    <div>
                        <label class="block text-xs font-semibold text-slate-400 mb-1">Coupon (e.g. WELCOME10)</label>
                        <input id="modal-coupon" type="text" placeholder="WELCOME10" class="w-full bg-slate-800 border border-slate-700 rounded-xl px-4 py-2.5 text-sm text-white focus:outline-none focus:border-indigo-500 uppercase">
                    </div>
                </div>

                <div id="stock-hint" class="text-xs text-indigo-400 font-medium bg-indigo-950/40 p-3 rounded-xl border border-indigo-900/50">
                    Checking inventory stock...
                </div>

                <div class="pt-4 flex space-x-3">
                    <button type="button" onclick="closeOrderModal()" class="flex-1 py-2.5 bg-slate-800 hover:bg-slate-700 rounded-xl text-sm font-semibold transition">Cancel</button>
                    <button type="submit" class="flex-1 py-2.5 bg-gradient-to-r from-indigo-600 to-blue-600 hover:from-indigo-500 hover:to-blue-500 rounded-xl text-sm font-semibold shadow-lg shadow-indigo-500/25 transition">
                        Confirm Purchase
                    </button>
                </div>
            </form>
        </div>
    </div>

    <!-- JavaScript Client Logic -->
    <script>
        let appData = { inventory: [], orders: [], audits: [], customers: [], warehouses: [], products: [] };

        async function refreshData() {
            try {
                const res = await fetch('/api/data');
                appData = await res.json();
                renderUI();
            } catch (err) {
                console.error(err);
                showToast('Failed to connect to database API', 'error');
            }
        }

        function renderUI() {
            // Render KPIs
            document.getElementById('kpi-sales').innerText = '$' + (appData.kpi.total_revenue || 0).toLocaleString(undefined, {minimumFractionDigits: 2});
            document.getElementById('kpi-stock').innerText = (appData.kpi.total_stock || 0).toLocaleString();
            document.getElementById('kpi-low-stock').innerText = appData.kpi.low_stock_count || 0;
            document.getElementById('kpi-triggers').innerText = appData.audits.length;

            // Render Inventory
            const invBody = document.getElementById('inventory-table-body');
            if (appData.inventory.length === 0) {
                invBody.innerHTML = '<tr><td colspan="8" class="text-center py-6 text-slate-500">No inventory records found.</td></tr>';
            } else {
                invBody.innerHTML = appData.inventory.map(item => {
                    const statusClass = item.status === 'OUT_OF_STOCK' ? 'bg-rose-500/10 text-rose-400 border-rose-500/20'
                        : item.status === 'LOW_STOCK' ? 'bg-amber-500/10 text-amber-400 border-amber-500/20'
                        : 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20';

                    return `
                    <tr class="hover:bg-slate-800/40 transition">
                        <td class="px-6 py-4 font-mono text-xs text-slate-400">${item.sku}</td>
                        <td class="px-6 py-4 font-semibold text-white">${item.product_name}</td>
                        <td class="px-6 py-4 text-xs text-slate-400">${item.category_name}</td>
                        <td class="px-6 py-4 text-xs text-slate-300 font-medium">${item.warehouse_name}</td>
                        <td class="px-6 py-4 text-right font-mono font-bold">$${item.unit_price.toFixed(2)}</td>
                        <td class="px-6 py-4 text-center font-bold text-white">${item.quantity_on_hand}</td>
                        <td class="px-6 py-4 text-center">
                            <span class="px-2.5 py-1 rounded-full text-xs font-semibold border ${statusClass}">
                                ${item.status}
                            </span>
                        </td>
                        <td class="px-6 py-4 text-right">
                            <button onclick="quickRestock(${item.product_id}, ${item.warehouse_id})" class="px-3 py-1 bg-slate-800 hover:bg-slate-700 border border-slate-700 text-xs font-semibold rounded-lg text-slate-300 transition">
                                + Restock
                            </button>
                        </td>
                    </tr>`;
                }).join('');
            }

            // Render Orders
            const ordBody = document.getElementById('orders-table-body');
            if (appData.orders.length === 0) {
                ordBody.innerHTML = '<tr><td colspan="6" class="text-center py-6 text-slate-500">No orders yet. Place an order to test!</td></tr>';
            } else {
                ordBody.innerHTML = appData.orders.map(o => {
                    const statusColor = o.order_status === 'CANCELLED' ? 'text-rose-400 bg-rose-500/10 border-rose-500/20'
                        : o.order_status === 'CONFIRMED' ? 'text-indigo-400 bg-indigo-500/10 border-indigo-500/20'
                        : 'text-emerald-400 bg-emerald-500/10 border-emerald-500/20';

                    const actionBtn = o.order_status !== 'CANCELLED' 
                        ? `<button onclick="cancelOrder(${o.order_id})" class="px-3 py-1 bg-rose-950/40 hover:bg-rose-900/60 border border-rose-800 text-rose-300 text-xs font-semibold rounded-lg transition">
                            Cancel (Restore Stock)
                           </button>`
                        : `<span class="text-xs text-slate-500 italic">Restored</span>`;

                    return `
                    <tr class="hover:bg-slate-800/40 transition">
                        <td class="px-6 py-4 font-mono font-bold text-indigo-400">#${o.order_id}</td>
                        <td class="px-6 py-4">
                            <div class="font-semibold text-white">${o.customer_name}</div>
                            <div class="text-xs text-slate-400">${o.customer_email}</div>
                        </td>
                        <td class="px-6 py-4 text-xs text-slate-300">${o.item_summary}</td>
                        <td class="px-6 py-4 text-right font-mono font-bold text-white">$${o.total_amount.toFixed(2)}</td>
                        <td class="px-6 py-4 text-center">
                            <span class="px-2.5 py-1 rounded-full text-xs font-semibold border ${statusColor}">
                                ${o.order_status}
                            </span>
                        </td>
                        <td class="px-6 py-4 text-right">${actionBtn}</td>
                    </tr>`;
                }).join('');
            }

            // Render Audit Log
            const audBody = document.getElementById('audit-table-body');
            audBody.innerHTML = appData.audits.map(a => {
                const deltaColor = a.quantity_change > 0 ? 'text-emerald-400 font-bold' : 'text-rose-400 font-bold';
                return `
                <tr class="hover:bg-slate-800/40 transition text-xs font-mono">
                    <td class="px-6 py-3 text-slate-500">LOG-${a.audit_id}</td>
                    <td class="px-6 py-3 font-semibold text-indigo-300">${a.change_type}</td>
                    <td class="px-6 py-3 text-white">${a.product_name}</td>
                    <td class="px-6 py-3 text-slate-400">${a.warehouse_name}</td>
                    <td class="px-6 py-3 text-center ${deltaColor}">${a.quantity_change > 0 ? '+' : ''}${a.quantity_change}</td>
                    <td class="px-6 py-3 text-center text-slate-300">${a.previous_quantity} $\\rightarrow$ ${a.new_quantity}</td>
                    <td class="px-6 py-3 text-slate-400">Order #${a.reference_id || 'N/A'}</td>
                    <td class="px-6 py-3 text-slate-500">${a.logged_at}</td>
                </tr>`;
            }).join('');
        }

        function switchTab(tab) {
            document.getElementById('view-inventory').classList.toggle('hidden', tab !== 'inventory');
            document.getElementById('view-orders').classList.toggle('hidden', tab !== 'orders');
            document.getElementById('view-audit').classList.toggle('hidden', tab !== 'audit');

            ['inventory', 'orders', 'audit'].forEach(t => {
                const el = document.getElementById('tab-' + t);
                if (t === tab) {
                    el.className = 'pb-3 border-b-2 border-indigo-500 text-indigo-400 transition';
                } else {
                    el.className = 'pb-3 border-b-2 border-transparent text-slate-400 hover:text-slate-200 transition';
                }
            });
        }

        function openOrderModal() {
            const custSelect = document.getElementById('modal-customer');
            custSelect.innerHTML = appData.customers.map(c => `<option value="${c.customer_id}">${c.first_name} ${c.last_name} (${c.email})</option>`).join('');

            const prodSelect = document.getElementById('modal-product');
            prodSelect.innerHTML = appData.products.map(p => `<option value="${p.product_id}">${p.product_name} ($${p.unit_price})</option>`).join('');

            const whSelect = document.getElementById('modal-warehouse');
            whSelect.innerHTML = appData.warehouses.map(w => `<option value="${w.warehouse_id}">${w.warehouse_name} (${w.city})</option>`).join('');

            document.getElementById('order-modal').classList.remove('hidden');
            document.getElementById('order-modal').classList.add('flex');
            updateStockHint();
        }

        function closeOrderModal() {
            document.getElementById('order-modal').classList.add('hidden');
            document.getElementById('order-modal').classList.remove('flex');
        }

        function updateStockHint() {
            const pId = parseInt(document.getElementById('modal-product').value);
            const wId = parseInt(document.getElementById('modal-warehouse').value);
            const inv = appData.inventory.find(i => i.product_id === pId && i.warehouse_id === wId);
            const stock = inv ? inv.quantity_on_hand : 0;
            document.getElementById('stock-hint').innerText = `Available stock in this warehouse: ${stock} units. (Trigger will reject if order exceeds stock)`;
        }

        async function submitOrder(e) {
            e.preventDefault();
            const payload = {
                customer_id: parseInt(document.getElementById('modal-customer').value),
                product_id: parseInt(document.getElementById('modal-product').value),
                warehouse_id: parseInt(document.getElementById('modal-warehouse').value),
                quantity: parseInt(document.getElementById('modal-quantity').value),
                coupon_code: document.getElementById('modal-coupon').value.trim()
            };

            const res = await fetch('/api/orders/create', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify(payload)
            });

            const result = await res.json();
            if (result.success) {
                closeOrderModal();
                showToast(result.message, 'success');
                refreshData();
            } else {
                showToast(result.error, 'error');
            }
        }

        async function cancelOrder(orderId) {
            if (!confirm(`Cancel Order #${orderId}? This will automatically fire the DBMS Trigger to restore inventory!`)) return;

            const res = await fetch('/api/orders/cancel', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({order_id: orderId})
            });

            const result = await res.json();
            if (result.success) {
                showToast(result.message, 'success');
                refreshData();
            } else {
                showToast(result.error, 'error');
            }
        }

        async function quickRestock(productId, warehouseId) {
            const qty = prompt("Enter quantity to restock (+):", "10");
            if (!qty || isNaN(qty) || parseInt(qty) <= 0) return;

            const res = await fetch('/api/inventory/restock', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({product_id: productId, warehouse_id: warehouseId, quantity: parseInt(qty)})
            });

            const result = await res.json();
            if (result.success) {
                showToast(result.message, 'success');
                refreshData();
            }
        }

        function showToast(msg, type) {
            const toast = document.getElementById('toast');
            toast.innerText = msg;
            toast.className = `fixed bottom-6 right-6 max-w-md p-4 rounded-xl shadow-2xl z-50 border text-sm font-semibold transition-all ${
                type === 'error' ? 'bg-rose-950 border-rose-800 text-rose-200' : 'bg-emerald-950 border-emerald-800 text-emerald-200'
            }`;
            toast.classList.remove('hidden');
            setTimeout(() => toast.classList.add('hidden'), 4000);
        }

        // Initialize on load
        refreshData();
    </script>
</body>
</html>
"""

class RequestHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path in ["/", "/index.html"]:
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(HTML_PAGE.encode("utf-8"))
        elif parsed.path == "/api/data":
            self.send_json(self.fetch_app_data())
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        content_length = int(self.headers.get("Content-Length", 0))
        post_data = self.rfile.read(content_length).decode("utf-8")
        body = json.loads(post_data) if post_data else {}

        if parsed.path == "/api/orders/create":
            res = self.handle_create_order(body)
            self.send_json(res)
        elif parsed.path == "/api/orders/cancel":
            res = self.handle_cancel_order(body)
            self.send_json(res)
        elif parsed.path == "/api/inventory/restock":
            res = self.handle_restock(body)
            self.send_json(res)
        else:
            self.send_response(404)
            self.end_headers()

    def send_json(self, data):
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(data).encode("utf-8"))

    def fetch_app_data(self):
        conn = sqlite3.connect(DB_FILE)
        conn.row_factory = sqlite3.Row
        c = conn.cursor()

        # KPIs
        c.execute("SELECT COALESCE(SUM(total_amount), 0) as total_rev FROM orders WHERE order_status != 'CANCELLED'")
        total_rev = c.fetchone()["total_rev"]

        c.execute("SELECT COALESCE(SUM(quantity_on_hand), 0) as total_stock FROM inventory")
        total_stock = c.fetchone()["total_stock"]

        c.execute("""
            SELECT COUNT(*) as low_count 
            FROM products p 
            JOIN inventory inv ON p.product_id = inv.product_id 
            WHERE inv.quantity_on_hand <= p.reorder_level
        """)
        low_stock_count = c.fetchone()["low_count"]

        # Inventory
        c.execute("""
            SELECT p.product_id, p.sku, p.product_name, c.category_name, w.warehouse_id, w.warehouse_name,
                   p.unit_price, inv.quantity_on_hand, p.reorder_level,
                   CASE 
                       WHEN inv.quantity_on_hand = 0 THEN 'OUT_OF_STOCK'
                       WHEN inv.quantity_on_hand <= p.reorder_level THEN 'LOW_STOCK'
                       ELSE 'IN_STOCK'
                   END as status
            FROM products p
            JOIN categories c ON p.category_id = c.category_id
            JOIN inventory inv ON p.product_id = inv.product_id
            JOIN warehouses w ON inv.warehouse_id = w.warehouse_id
            ORDER BY p.product_name, w.warehouse_name
        """)
        inventory = [dict(row) for row in c.fetchall()]

        # Orders
        c.execute("""
            SELECT o.order_id, o.order_date, o.order_status, o.total_amount,
                   cust.first_name || ' ' || cust.last_name as customer_name, cust.email as customer_email,
                   (SELECT group_concat(p.product_name || ' (x' || oi.quantity || ')') 
                    FROM order_items oi JOIN products p ON oi.product_id = p.product_id WHERE oi.order_id = o.order_id) as item_summary
            FROM orders o
            JOIN customers cust ON o.customer_id = cust.customer_id
            ORDER BY o.order_id DESC
        """)
        orders = [dict(row) for row in c.fetchall()]

        # Audit logs
        c.execute("""
            SELECT a.audit_id, a.change_type, a.quantity_change, a.previous_quantity, a.new_quantity,
                   a.reference_id, a.logged_at, p.product_name, w.warehouse_name
            FROM inventory_audit_log a
            JOIN products p ON a.product_id = p.product_id
            JOIN warehouses w ON a.warehouse_id = w.warehouse_id
            ORDER BY a.audit_id DESC LIMIT 50
        """)
        audits = [dict(row) for row in c.fetchall()]

        # Select lookups
        c.execute("SELECT customer_id, first_name, last_name, email FROM customers")
        customers = [dict(row) for row in c.fetchall()]

        c.execute("SELECT product_id, product_name, unit_price FROM products")
        products = [dict(row) for row in c.fetchall()]

        c.execute("SELECT warehouse_id, warehouse_name, city FROM warehouses")
        warehouses = [dict(row) for row in c.fetchall()]

        conn.close()

        return {
            "kpi": {
                "total_revenue": total_rev,
                "total_stock": total_stock,
                "low_stock_count": low_stock_count
            },
            "inventory": inventory,
            "orders": orders,
            "audits": audits,
            "customers": customers,
            "products": products,
            "warehouses": warehouses
        }

    def handle_create_order(self, data):
        conn = sqlite3.connect(DB_FILE)
        conn.row_factory = sqlite3.Row
        c = conn.cursor()

        try:
            p_id = data["product_id"]
            w_id = data["warehouse_id"]
            qty = data["quantity"]
            cust_id = data["customer_id"]
            coupon = data.get("coupon_code", "").upper().strip()

            # Stock check
            c.execute("SELECT quantity_on_hand FROM inventory WHERE product_id = ? AND warehouse_id = ?", (p_id, w_id))
            row = c.fetchone()
            if not row or row["quantity_on_hand"] < qty:
                available = row["quantity_on_hand"] if row else 0
                return {"success": False, "error": f"[TRIGGER BLOCKED] Insufficient stock in this warehouse! (Available: {available}, Requested: {qty})"}

            # Get price
            c.execute("SELECT unit_price FROM products WHERE product_id = ?", (p_id,))
            price = c.fetchone()["unit_price"]
            subtotal = price * qty

            # Discount
            discount = 0.0
            if coupon == "WELCOME10" and subtotal >= 100.0:
                discount = round(subtotal * 0.10, 2)
            elif coupon == "TECHSAVE50" and subtotal >= 500.0:
                discount = 50.0

            tax = round((subtotal - discount) * 0.08, 2)
            total = (subtotal - discount) + tax

            # Insert Order
            c.execute("""
                INSERT INTO orders (customer_id, order_date, order_status, subtotal, discount_amount, tax_amount, total_amount, shipping_address)
                VALUES (?, datetime('now'), 'CONFIRMED', ?, ?, ?, ?, 'Default Address')
            """, (cust_id, subtotal, discount, tax, total))
            order_id = c.lastrowid

            # Insert Order Item (Triggers trg_order_items_deduct which decrements stock!)
            c.execute("""
                INSERT INTO order_items (order_id, product_id, warehouse_id, quantity, unit_price, line_total)
                VALUES (?, ?, ?, ?, ?, ?)
            """, (order_id, p_id, w_id, qty, price, subtotal))

            # Record payment
            c.execute("""
                INSERT INTO payments (order_id, payment_method, payment_status, amount, transaction_reference)
                VALUES (?, 'CREDIT_CARD', 'COMPLETED', ?, ?)
            """, (order_id, total, f"TXN-{datetime.now().strftime('%Y%m%d%H%M%S')}-{order_id}"))

            conn.commit()
            conn.close()
            return {"success": True, "message": f"Order #{order_id} placed! DB Trigger automatically decremented stock by -{qty} units."}
        except Exception as e:
            conn.rollback()
            conn.close()
            return {"success": False, "error": str(e)}

    def handle_cancel_order(self, data):
        conn = sqlite3.connect(DB_FILE)
        c = conn.cursor()
        order_id = data["order_id"]

        try:
            # Updating order status to CANCELLED triggers trg_orders_restore_cancel which automatically restores stock
            c.execute("UPDATE orders SET order_status = 'CANCELLED' WHERE order_id = ?", (order_id,))
            c.execute("UPDATE payments SET payment_status = 'REFUNDED' WHERE order_id = ?", (order_id,))
            conn.commit()
            conn.close()
            return {"success": True, "message": f"Order #{order_id} cancelled! DB Trigger automatically restored product inventory stock."}
        except Exception as e:
            conn.rollback()
            conn.close()
            return {"success": False, "error": str(e)}

    def handle_restock(self, data):
        conn = sqlite3.connect(DB_FILE)
        c = conn.cursor()
        p_id = data["product_id"]
        w_id = data["warehouse_id"]
        qty = data["quantity"]

        try:
            c.execute("SELECT quantity_on_hand FROM inventory WHERE product_id = ? AND warehouse_id = ?", (p_id, w_id))
            prev = c.fetchone()[0]

            c.execute("UPDATE inventory SET quantity_on_hand = quantity_on_hand + ? WHERE product_id = ? AND warehouse_id = ?", (qty, p_id, w_id))

            c.execute("""
                INSERT INTO inventory_audit_log (product_id, warehouse_id, change_type, quantity_change, previous_quantity, new_quantity, reference_id, logged_at, logged_by)
                VALUES (?, ?, 'RESTOCK', ?, ?, ?, NULL, datetime('now'), 'MANAGER')
            """, (p_id, w_id, qty, prev, prev + qty))

            conn.commit()
            conn.close()
            return {"success": True, "message": f"Successfully added +{qty} units to warehouse stock!"}
        except Exception as e:
            conn.rollback()
            conn.close()
            return {"success": False, "error": str(e)}

def run():
    init_db()
    with socketserver.TCPServer(("", PORT), RequestHandler) as httpd:
        print(f"Server live at: http://localhost:{PORT}")
        httpd.serve_forever()

if __name__ == "__main__":
    run()

