# Database Design

## Overview
This project uses PostgreSQL as the main database. The database design is based on the core business flow of the platform: users register, suppliers create listings, buyers place orders, and admins monitor the system.

The MVP database is intentionally simple and focused only on the core features.

## Main Entities

### User
This table stores all authenticated users in the system.

Fields:
- id
- full_name
- email
- password
- phone
- role
- is_active
- created_at
- updated_at

Role values:
- ADMIN
- SUPPLIER
- BUYER

Notes:
- This should be implemented as a custom Django user model from the beginning.
- Every user must have exactly one role.

---

### SupplierProfile
This table stores extra information for supplier users.

Fields:
- id
- user (OneToOne with User)
- business_name
- region
- address
- is_verified
- created_at
- updated_at

Notes:
- Only users with role `SUPPLIER` should have a supplier profile.
- A supplier must be verified before creating listings.

---

### BuyerProfile
This table stores extra information for buyer users.

Fields:
- id
- user (OneToOne with User)
- business_name
- region
- address
- created_at
- updated_at

Notes:
- Only users with role `BUYER` should have a buyer profile.

---

### Listing
This table stores meat stock created by suppliers.

Fields:
- id
- supplier
- title
- meat_type
- quantity_kg
- price_per_kg
- location
- available_from
- description
- status
- created_at
- updated_at

Listing status values:
- ACTIVE
- INACTIVE
- SOLD_OUT

Notes:
- A listing belongs to one supplier.
- A supplier can have many listings.
- A listing should only be visible for ordering when its status is `ACTIVE`.

---

### Order
This table stores buyer orders for listings.

Fields:
- id
- buyer
- listing
- quantity_kg
- total_price
- delivery_address
- notes
- status
- created_at
- updated_at

Order status values:
- PENDING
- CONFIRMED
- PROCESSING
- IN_TRANSIT
- DELIVERED
- CANCELLED

Notes:
- An order belongs to one buyer.
- An order belongs to one listing.
- A listing can have many orders.
- `total_price` should be calculated from `quantity_kg * price_per_kg` at the time of order creation.

---

### Notification
This table stores in-app notifications for users.

Fields:
- id
- user
- title
- message
- is_read
- created_at

Notes:
- One user can have many notifications.
- This table is optional in early development, but it should exist in the project structure.

## Relationships

### User ↔ SupplierProfile
- One-to-one
- Only supplier users should have this relation

### User ↔ BuyerProfile
- One-to-one
- Only buyer users should have this relation

### Supplier ↔ Listing
- One supplier can create many listings
- Each listing belongs to one supplier

### Buyer ↔ Order
- One buyer can create many orders
- Each order belongs to one buyer

### Listing ↔ Order
- One listing can have many orders
- Each order belongs to one listing

### User ↔ Notification
- One user can have many notifications

## Business Rules

### Supplier Verification
- a supplier must be verified by admin before creating a listing

### Listing Creation
- only verified suppliers can create listings
- listing starts with status `ACTIVE`

### Order Creation
- buyer can only order from an `ACTIVE` listing
- order quantity cannot be greater than available stock
- listing quantity decreases when order is created
- if remaining quantity becomes zero, listing status becomes `SOLD_OUT`

### Order Cancellation
- buyer can cancel only own `PENDING` orders
- supplier can cancel only allowed orders related to own listings
- when order is cancelled, stock quantity must be restored

### Ownership Rules
- supplier can update only own listings
- supplier can manage only orders related to own listings
- buyer can view only own orders
- admin can view all records

## Suggested Django Model Strategy
- use `TextChoices` for roles and status values
- use `created_at` and `updated_at` fields on main models
- keep business logic in service layer, not only in views
- keep models simple and predictable

## Future Tables (Not in MVP)
The following models may be added later:

- ButcherProfile
- Rating
- Payment
- Delivery
- WarehouseStock
- OrderStatusHistory
- PriceHistory
- SupportTicket

## Notes
The goal of this database design is to support a clean MVP without unnecessary complexity. It should be easy to extend later without redesigning the whole system.