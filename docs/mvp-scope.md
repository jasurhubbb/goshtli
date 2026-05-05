# MVP Scope

## Project Overview
This project is a B2B meat marketplace platform. The main goal of the MVP is to create a working system where suppliers can list available meat stock, buyers can browse listings and place orders, and admins can verify suppliers and monitor the platform.

The first version is focused only on the core marketplace flow. We are not trying to build the full ecosystem in version one.

## Main Goal of the MVP
The main goal of this MVP is to build a stable and clear first version of the platform where:

- suppliers can register and manage listings
- buyers can browse listings and place orders
- admins can verify suppliers and monitor the system
- orders can move through a controlled lifecycle
- the backend and frontend can work together with a clean API structure

## Target Users
### Admin
The admin is responsible for monitoring and managing the platform, especially supplier verification and order oversight.

### Supplier
A supplier is a user who can register, get verified, create meat listings, manage their listings, and handle incoming orders related to their stock.

### Buyer
A buyer is a user who can register, browse available listings, place orders, view order history, and cancel eligible orders.

## What Is Included in the MVP

### Authentication and Access Control
- user registration
- user login
- JWT-based authentication
- role-based access control
- custom user model

### Supplier Features
- supplier profile creation
- admin verification of suppliers
- create listing
- update own listing
- deactivate own listing
- delete own listing when allowed
- view supplier dashboard
- view supplier-related orders
- update order status

### Buyer Features
- buyer profile creation
- browse public listings
- filter and paginate listings
- place order
- cancel own order if still pending
- view buyer dashboard
- view own orders
- view order details

### Listing Features
- create listing
- get all listings
- get listing details
- filter by meat type, location, status, and price range
- support pagination

### Order Features
- create order
- get order details
- buyer order history
- supplier order list
- controlled order status flow
- cancellation with stock restoration

### Admin Features
- access Django admin
- verify supplier accounts
- view users
- view listings
- view orders
- monitor overall platform activity

### Technical Scope
- Backend: Django + Django REST Framework
- Frontend: Flutter
- Database: PostgreSQL
- Local database through Docker
- API documentation through Swagger / OpenAPI
- GitHub for version control

## What Is Not Included in the MVP
The following features are intentionally excluded from version one:

- online payment integration
- full butcher marketplace
- warehouse automation
- import/export operations
- AI-based pricing or demand prediction
- real-time chat
- advanced analytics
- recommendation engine
- full notification delivery through SMS/email
- multilingual support
- delivery tracking system
- rating and review system

## MVP Success Criteria
The MVP will be considered successful if the following conditions are met:

- a supplier can register and get verified
- a verified supplier can create listings
- a buyer can browse listings and place an order
- a buyer can cancel a pending order
- a supplier can manage order status correctly
- stock quantity is updated correctly during ordering and cancellation
- admin can monitor suppliers, listings, and orders
- the mobile app can consume the backend APIs without confusion

## Notes
This MVP is only the first working version of the product. The goal is to validate the business workflow and build a stable base for future expansion.