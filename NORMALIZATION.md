# Database Normalization Proof (1NF to BCNF)

This document provides a formal database normalization analysis and functional dependency proof for the **E-Commerce Inventory & Order Management System**, demonstrating how the relational schema eliminates update, insertion, and deletion anomalies.

---

## 1. Functional Dependency (FD) Analysis & Notation

Let $R$ denote a relational schema, and let $X \to Y$ denote a functional dependency where the attribute set $X$ uniquely determines the attribute set $Y$.

### Candidate Keys & Functional Dependencies per Entity

1. **Suppliers**:
   - Primary Key: `supplier_id`
   - Functional Dependencies:
     $$\text{supplier\_id} \to \{\text{company\_name}, \text{contact\_name}, \text{email}, \text{phone}, \text{address}, \text{city}, \text{country}, \text{rating}, \text{created\_at}\}$$
     $$\text{company\_name} \to \{\text{supplier\_id}, \dots\}$$
     $$\text{email} \to \{\text{supplier\_id}, \dots\}$$

2. **Categories**:
   - Primary Key: `category_id`
   - Functional Dependencies:
     $$\text{category\_id} \to \{\text{category\_name}, \text{description}, \text{parent\_category\_id}, \text{created\_at}\}$$
     $$\text{category\_name} \to \{\text{category\_id}, \dots\}$$

3. **Products**:
   - Primary Key: `product_id`
   - Candidate Key: `sku`
   - Functional Dependencies:
     $$\text{product\_id} \to \{\text{sku}, \text{product\_name}, \text{description}, \text{category\_id}, \text{supplier\_id}, \text{unit\_price}, \text{cost\_price}, \text{reorder\_level}, \text{is\_active}, \text{created\_at}\}$$
     $$\text{sku} \to \{\text{product\_id}, \dots\}$$

4. **Warehouses**:
   - Primary Key: `warehouse_id`
   - Functional Dependencies:
     $$\text{warehouse\_id} \to \{\text{warehouse\_name}, \text{location\_address}, \text{city}, \text{state}, \text{postal\_code}, \text{capacity}, \text{is\_active}, \text{created\_at}\}$$

5. **Inventory**:
   - Primary Key: `inventory_id`
   - Candidate Key: `(product_id, warehouse_id)`
   - Functional Dependencies:
     $$\{\text{product\_id}, \text{warehouse\_id}\} \to \{\text{inventory\_id}, \text{quantity\_on\_hand}, \text{quantity\_reserved}, \text{last\_restocked\_at}, \text{last\_updated\_at}\}$$

6. **Orders**:
   - Primary Key: `order_id`
   - Functional Dependencies:
     $$\text{order\_id} \to \{\text{customer\_id}, \text{order\_date}, \text{order\_status}, \text{subtotal}, \text{discount\_amount}, \text{tax\_amount}, \text{shipping\_fee}, \text{total\_amount}, \text{coupon\_id}, \text{shipping\_address}, \text{notes}\}$$

7. **Order_Items**:
   - Primary Key: `order_item_id`
   - Candidate Key: `(order_id, product_id, warehouse_id)`
   - Functional Dependencies:
     $$\{\text{order\_id}, \text{product\_id}, \text{warehouse\_id}\} \to \{\text{order\_item\_id}, \text{quantity}, \text{unit\_price}, \text{line\_total}\}$$

---

## 2. Unnormalized Form (UNF) & Anomalies

In a naive flat file / unnormalized design, an order might be recorded as:

$$\text{UNF\_Order}(\underline{\text{order\_id}}, \text{customer\_name}, \text{customer\_address}, \text{product\_sku}, \text{product\_name}, \text{supplier\_name}, \text{supplier\_phone}, \text{warehouse\_name}, \text{warehouse\_capacity}, \dots)$$

### Severe Anomalies in UNF:
1. **Redundancy & Repetition**: Customer address and supplier info repeated for every product line item in every order.
2. **Insertion Anomaly**: Cannot register a new product or supplier without creating a fake customer order.
3. **Deletion Anomaly**: Deleting the only order for a product erases the product catalog record and supplier history.
4. **Update Anomaly**: If a supplier changes their contact phone number, thousands of historic order rows must be modified; failure to update all rows causes data inconsistency.

---

## 3. First Normal Form (1NF)

### Requirements for 1NF:
1. Every attribute contains only **atomic (indivisible)** values.
2. No repeating groups or arrays of columns.
3. A distinct primary key is identified.

### Transformation to 1NF:
- Multi-valued columns (e.g. list of items `{item1, item2, item3}`) are broken into distinct rows.
- Atomic scalar types (`first_name`, `last_name`, `address_line`, `city`, `state`) replace composite values.
- Primary keys are explicitly defined on each table.

$\implies$ **Schema satisfies 1NF.**

---

## 4. Second Normal Form (2NF)

### Definition of 2NF:
A relation is in 2NF if and only if:
1. It is in **1NF**.
2. **No non-prime attribute is partially dependent on any candidate key** (i.e. every non-prime attribute is fully functionally dependent on the whole candidate key).

### Proof of 2NF:
Consider candidate keys with multiple attributes:
- **`Inventory`**: Candidate key is `(product_id, warehouse_id)`.
  - `quantity_on_hand` and `quantity_reserved` depend on **both** `product_id` AND `warehouse_id`.
  - Product metadata (`product_name`, `unit_price`, `cost_price`) does not depend on `warehouse_id`; hence it is **isolated** into the `Products` table.
  - Warehouse metadata (`warehouse_name`, `capacity`) does not depend on `product_id`; hence it is **isolated** into the `Warehouses` table.
- **`Order_Items`**: Candidate key is `(order_id, product_id, warehouse_id)`.
  - `quantity`, `unit_price`, and `line_total` depend on the specific line in that order.
  - There are no partial dependencies where an attribute depends only on `product_id` alone.

All single-attribute primary key tables (`Customers`, `Orders`, `Products`, `Suppliers`, `Coupons`) trivially satisfy 2NF since a partial key cannot exist.

$\implies$ **Schema satisfies 2NF.**

---

## 5. Third Normal Form (3NF)

### Definition of 3NF:
A relation is in 3NF if and only if:
1. It is in **2NF**.
2. **No transitive dependencies exist** for non-prime attributes:
   $$\text{If } X \to Y \text{ and } Y \to Z \text{ (where } Y \text{ is not a superkey), then } X \to Z \text{ is a transitive dependency.}$$

### Proof of 3NF:
Let us analyze potential transitive dependencies:

1. **Products vs Categories**:
   - In `Products`, $\text{product\_id} \to \text{category\_id}$.
   - If we had kept `category_name` and `category_description` inside `Products`, then:
     $$\text{product\_id} \to \text{category\_id} \to \{\text{category\_name}, \text{category\_description}\}$$
     Since `category_id` is not a superkey of `Products`, this would violate 3NF.
   - **Resolution**: `category_name` and `description` are factored out into the independent `Categories` relation.

2. **Products vs Suppliers**:
   - Similarly, $\text{product\_id} \to \text{supplier\_id} \to \{\text{company\_name}, \text{phone}, \text{email}\}$.
   - **Resolution**: Supplier attributes are segregated into the `Suppliers` relation.

3. **Orders vs Customers**:
   - In `Orders`, $\text{order\_id} \to \text{customer\_id}$.
   - Customer profile details (`first_name`, `last_name`, `email`, `loyalty_points`) reside in `Customers`, avoiding $\text{order\_id} \to \text{customer\_id} \to \text{email}$.

4. **Line Total Calculation**:
   - While `line_total = quantity * unit_price`, in commercial and legal databases storing the computed contract line price is standard for fast index aggregation and immutable historical archiving (as product catalogue prices change over time).

$\implies$ **Schema satisfies 3NF.**

---

## 6. Boyce-Codd Normal Form (BCNF)

### Definition of BCNF:
A relation $R$ is in BCNF if and only if for every non-trivial functional dependency $X \to Y$, **$X$ is a superkey** of $R$.

### Proof of BCNF:
Examine every table:
- **`Suppliers`**: Determinants are `supplier_id`, `company_name`, and `email` (all unique keys $\implies$ superkeys).
- **`Categories`**: Determinants are `category_id` and `category_name` (both superkeys).
- **`Products`**: Determinants are `product_id` and `sku` (both superkeys).
- **`Warehouses`**: Determinants are `warehouse_id` and `warehouse_name` (both superkeys).
- **`Inventory`**: Determinants are `inventory_id` and `(product_id, warehouse_id)` (both superkeys).
- **`Customers`**: Determinants are `customer_id` and `email` (both superkeys).
- **`Coupons`**: Determinants are `coupon_id` and `coupon_code` (both superkeys).
- **`Orders`**: Determinant is `order_id` (superkey).
- **`Order_Items`**: Determinants are `order_item_id` and `(order_id, product_id, warehouse_id)` (both superkeys).
- **`Payments`**: Determinants are `payment_id` and `transaction_reference` (both superkeys).
- **`Shipments`**: Determinants are `shipment_id` and `tracking_number` (both superkeys).

Since **every single determinant in every table is a superkey**, no overlapping candidate key anomalies exist.

$\implies$ **The entire schema satisfies Boyce-Codd Normal Form (BCNF).**

