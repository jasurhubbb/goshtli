
---

## `docs/workflow.md`

```md
# Workflow

## Overview
This document explains the main business workflows of the Meat Marketplace platform. It describes how users interact with the system and how the backend should respond in each major flow.

## 1. Supplier Registration and Verification Flow

### Step 1
Supplier registers through the app.

### Step 2
System creates:
- User with role `SUPPLIER`
- SupplierProfile linked to that user

### Step 3
Supplier remains unverified by default.

### Step 4
Admin reviews the supplier using Django Admin or admin APIs.

### Step 5
Admin verifies the supplier by setting `is_verified = true`.

### Result
Verified supplier is now allowed to create listings.

---

## 2. Buyer Registration Flow

### Step 1
Buyer registers through the app.

### Step 2
System creates:
- User with role `BUYER`
- BuyerProfile linked to that user

### Result
Buyer can now browse listings and place orders.

---

## 3. Supplier Listing Creation Flow

### Step 1
Verified supplier logs into the app.

### Step 2
Supplier creates a listing with:
- title
- meat type
- quantity
- price
- location
- available date
- description

### Step 3
System checks:
- user is authenticated
- user role is `SUPPLIER`
- supplier is verified

### Step 4
System saves listing with status `ACTIVE`.

### Result
Listing becomes visible in public listing APIs.

---

## 4. Buyer Browsing Listings Flow

### Step 1
Buyer opens listings screen.

### Step 2
App requests public listing API.

### Step 3
System returns paginated listings.

### Step 4
Buyer can filter by:
- meat type
- location
- price range
- status

### Result
Buyer can explore available stock and select a listing.

---

## 5. Buyer Order Creation Flow

### Step 1
Buyer selects a listing.

### Step 2
Buyer enters quantity, delivery address, and optional notes.

### Step 3
System checks:
- buyer is authenticated
- listing exists
- listing status is `ACTIVE`
- enough quantity is available

### Step 4
System creates order with status `PENDING`.

### Step 5
System reduces listing stock quantity.

### Step 6
If remaining quantity becomes zero, listing status becomes `SOLD_OUT`.

### Result
Order is created successfully.

---

## 6. Buyer Cancel Order Flow

### Step 1
Buyer opens own order details.

### Step 2
Buyer chooses cancel order.

### Step 3
System checks:
- order belongs to this buyer
- order status is still `PENDING`

### Step 4
System changes order status to `CANCELLED`.

### Step 5
System restores listing stock quantity.

### Step 6
If listing becomes available again, its status can return to `ACTIVE`.

### Result
Order is cancelled and stock is restored correctly.

---

## 7. Supplier Order Management Flow

### Step 1
Supplier opens supplier orders screen.

### Step 2
System returns only orders related to supplier’s own listings.

### Step 3
Supplier views order details.

### Step 4
Supplier updates order status.

Allowed order flow:
- PENDING → CONFIRMED
- CONFIRMED → PROCESSING
- PROCESSING → IN_TRANSIT
- IN_TRANSIT → DELIVERED

Possible cancellation:
- PENDING → CANCELLED
- CONFIRMED → CANCELLED
- PROCESSING → CANCELLED

### Step 5
If supplier cancels the order, stock quantity is restored.

### Result
Order moves through a controlled lifecycle.

---

## 8. Admin Monitoring Flow

### Step 1
Admin logs into Django Admin or admin dashboard.

### Step 2
Admin can:
- view users
- verify suppliers
- inspect listings
- inspect orders
- monitor general system activity

### Result
Admin supports platform operations and controls supplier access.

---

## 9. Order Lifecycle

### Main lifecycle
- PENDING
- CONFIRMED
- PROCESSING
- IN_TRANSIT
- DELIVERED

### Cancellation lifecycle
- PENDING → CANCELLED
- CONFIRMED → CANCELLED
- PROCESSING → CANCELLED

### Final states
- DELIVERED
- CANCELLED

These are terminal states.

---

## 10. Listing Lifecycle

### Main states
- ACTIVE
- SOLD_OUT
- INACTIVE

### Rules
- listing starts as `ACTIVE`
- listing becomes `SOLD_OUT` when quantity reaches zero
- supplier can manually set listing to `INACTIVE`
- cancelled orders may restore quantity and make listing active again

---

## 11. Ownership Rules

### Buyer
- can see only own orders
- can cancel only own pending orders

### Supplier
- can update only own listings
- can manage only orders related to own listings

### Admin
- can access all important records

---

## 12. Future Workflows (Not in MVP)
These workflows are planned for later versions:

- butcher booking
- payments
- delivery tracking
- ratings and reviews
- notifications through email/SMS
- warehouse and cold storage logic
- order status history