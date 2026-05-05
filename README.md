# Meat Marketplace

## Project Overview

This project is a **B2B meat marketplace system** that connects suppliers and buyers through a digital platform.

Our goal is to reduce the problems in the traditional meat supply chain such as:
- too many middlemen
- unclear prices
- slow communication
- weak order tracking
- difficulty finding trusted suppliers and buyers

I am building this project with my team as a real startup-style product, not just as a simple class project.

The idea is to create a system where:
- **suppliers** can register and publish meat listings
- **buyers** can browse listings and place orders
- **admins** can verify suppliers and manage the system
- later, we can expand into logistics, butcher services, storage, analytics, and more

---

## Main Goal

The first goal of this project is to build a clean and working **MVP**.

The MVP should allow us to:
1. register users with roles
2. verify suppliers
3. create and manage listings
4. place and manage orders
5. track order statuses
6. provide separate dashboards for buyers and suppliers
7. manage operations through Django Admin

---

## Tech Stack

### Backend
- **Python Django**
- **Django REST Framework (DRF)**
- **Simple JWT** for authentication

### Frontend
- **Flutter**
- **Dio** for API requests
- **Riverpod** or **Provider** for state management

### Database
- **PostgreSQL**

### Development Tools
- **VS Code**
- **GitHub**
- **Docker** for PostgreSQL in local development
- **Postman / Swagger** for API testing

---

## Why We Chose This Stack

I chose this stack because it is practical for a startup MVP.

### Why Django
- fast backend development
- built-in admin panel
- good authentication and user management support
- strong integration with PostgreSQL
- good for business logic and dashboards

### Why Flutter
- single codebase for mobile app
- clean UI development
- good for Android and iOS later
- flexible enough for our product screens

### Why PostgreSQL
- reliable relational database
- good for structured business data
- strong support for filtering, relations, and analytics later

---

## High-Level System Architecture

```text
Flutter App
   |
   |  HTTP / JSON API
   v
Django REST Framework
   |
   |-- Auth
   |-- Users / Roles
   |-- Listings
   |-- Orders
   |-- Dashboards
   |-- Notifications
   |-- Admin Operations
   |
   v
PostgreSQL
   |
   v
Django Admin
```

---

## User Roles

### 1. Admin
Admin manages the whole system.

Responsibilities:
- verify suppliers
- monitor buyers and suppliers
- manage listings
- manage orders
- handle disputes or system problems

### 2. Supplier
Supplier is the seller side of the system.

Responsibilities:
- register profile
- wait for admin verification
- create meat listings
- manage own listings
- see incoming orders
- update order statuses

### 3. Buyer
Buyer is the customer side of the system.

Responsibilities:
- register profile
- browse listings
- place orders
- cancel pending orders
- track order statuses
- view order history

### 4. Butcher (later phase)
This role may be added later for service expansion.

---

## Core Business Flow

### Supplier Flow
1. Supplier registers
2. Admin verifies supplier
3. Supplier creates listing
4. Buyer places order
5. Supplier processes order
6. Supplier updates order status until delivery

### Buyer Flow
1. Buyer registers
2. Buyer browses listings
3. Buyer places order
4. Buyer tracks order
5. Buyer can cancel order if it is still pending

### Admin Flow
1. Admin logs into Django Admin or admin APIs
2. Admin verifies supplier accounts
3. Admin monitors listings and orders
4. Admin handles system management tasks

---

## MVP Scope

## Included in Version 1
- authentication
- role-based access
- supplier profile
- buyer profile
- supplier verification
- create listing
- update listing
- deactivate listing
- delete listing if allowed
- browse listings with filters
- place orders
- cancel orders
- update order statuses
- buyer dashboard
- supplier dashboard
- admin management through Django Admin

## Not Included Yet
- real payment integration
- butcher marketplace full version
- warehouse management
- logistics automation
- AI pricing or forecasting
- recommendation engine
- chat system
- import/export management
- advanced analytics

We should not try to build everything at once. The first target is a working, clean, and testable MVP.

---

## Folder Structure

```bash
meat-marketplace/
├── backend/
│   ├── config/
│   │   ├── settings/
│   │   │   ├── base.py
│   │   │   ├── development.py
│   │   │   └── production.py
│   │   ├── urls.py
│   │   ├── asgi.py
│   │   └── wsgi.py
│   │
│   ├── apps/
│   │   ├── common/
│   │   ├── accounts/
│   │   ├── suppliers/
│   │   ├── buyers/
│   │   ├── listings/
│   │   ├── orders/
│   │   └── notifications/
│   │
│   ├── manage.py
│   ├── requirements.txt
│   ├── .env
│   └── Dockerfile
│
├── mobile/
│   ├── lib/
│   │   ├── core/
│   │   ├── shared/
│   │   ├── features/
│   │   └── main.dart
│   ├── pubspec.yaml
│   └── .env
│
├── docs/
│   ├── mvp-scope.md
│   ├── api-plan.md
│   ├── database-design.md
│   └── workflow.md
│
├── docker-compose.yml
├── .gitignore
└── README.md
```

---

## Backend App Structure

The backend is split into domain-based Django apps so that the code stays clean and understandable.

### `accounts`
Handles:
- custom user model
- login and registration
- JWT authentication
- roles and permissions

### `suppliers`
Handles:
- supplier profile
- supplier verification status
- supplier dashboard data

### `buyers`
Handles:
- buyer profile
- buyer dashboard data

### `listings`
Handles:
- meat listings
- public listing browsing
- listing filtering
- supplier listing management

### `orders`
Handles:
- order creation
- order detail
- order cancellation
- order status updates
- stock reduction and restoration

### `notifications`
Handles:
- in-app notifications
- future notification expansion

### `common`
Handles shared logic like:
- helper functions
- pagination
- permissions
- common responses
- base models

---

## Flutter Structure

The Flutter app is organized by feature so the team can work clearly.

```bash
mobile/lib/
├── core/
│   ├── config/
│   ├── constants/
│   ├── network/
│   ├── services/
│   ├── theme/
│   └── utils/
│
├── shared/
│   ├── widgets/
│   ├── models/
│   └── providers/
│
├── features/
│   ├── auth/
│   ├── listings/
│   ├── orders/
│   ├── supplier_dashboard/
│   ├── buyer_dashboard/
│   └── profile/
│
└── main.dart
```

### Flutter Layer Idea
- `data/` = API calls, repositories, models
- `presentation/` = screens and UI logic
- `widgets/` = reusable feature widgets

---

## Database Design (Main Models)

### User
Stores:
- full name
- email
- password
- phone number
- role

### SupplierProfile
Stores:
- linked user
- business name
- region
- address
- verification status

### BuyerProfile
Stores:
- linked user
- business name
- region
- address

### Listing
Stores:
- supplier
- title
- meat type
- quantity in kg
- price per kg
- location
- available from date
- description
- status

### Order
Stores:
- buyer
- listing
- quantity in kg
- total price
- delivery address
- notes
- order status

### Notification
Stores:
- user
- title
- message
- read status

---

## Order Status Flow

We will use these statuses:
- `PENDING`
- `CONFIRMED`
- `PROCESSING`
- `IN_TRANSIT`
- `DELIVERED`
- `CANCELLED`

### Allowed Flow
- `PENDING -> CONFIRMED`
- `PENDING -> CANCELLED`
- `CONFIRMED -> PROCESSING`
- `CONFIRMED -> CANCELLED`
- `PROCESSING -> IN_TRANSIT`
- `PROCESSING -> CANCELLED`
- `IN_TRANSIT -> DELIVERED`

This will help keep the business workflow clear and prevent random status changes.

---

## Listing Status Flow

We will use these statuses:
- `ACTIVE`
- `INACTIVE`
- `SOLD_OUT`

This helps us control which listings are visible and available.

---

## API Structure

All API routes should start with:

```text
/api/v1/
```

### Main Endpoint Groups

#### Auth
- `/api/v1/auth/register/`
- `/api/v1/auth/login/`
- `/api/v1/auth/refresh/`

#### Users
- `/api/v1/users/me/`

#### Suppliers
- `/api/v1/suppliers/me/`
- `/api/v1/suppliers/dashboard/`

#### Buyers
- `/api/v1/buyers/me/`
- `/api/v1/buyers/dashboard/`
- `/api/v1/buyers/orders/`

#### Listings
- `/api/v1/listings/`
- `/api/v1/listings/{id}/`
- `/api/v1/listings/my/`

#### Orders
- `/api/v1/orders/`
- `/api/v1/orders/my/`
- `/api/v1/orders/{id}/`
- `/api/v1/orders/{id}/cancel/`
- `/api/v1/orders/supplier/`
- `/api/v1/orders/supplier/{id}/status/`

#### Admin
- managed mainly through Django Admin in the first version
- custom admin APIs can be added later if needed

---

## Local Development Workflow

### Tools We Use
- VS Code for coding
- GitHub for version control
- Docker for PostgreSQL
- Postman or Swagger for API testing
- Android Studio emulator if needed for Flutter testing

### Local Setup Idea
- Django runs locally
- Flutter runs locally
- PostgreSQL runs in Docker

This is the cleanest way to start without making the setup too complicated.

---

## Team Workflow

### Branching Strategy
We should not push everything directly into `main`.

Recommended branches:
- `main` -> stable code
- `dev` -> integration branch
- feature branches:
  - `feature/auth`
  - `feature/listings`
  - `feature/orders`
  - `feature/flutter-auth`
  - `feature/flutter-dashboard`

### Commit Style
Use clear commit messages like:
- `feat: add supplier registration`
- `feat: implement listing filters`
- `fix: restore stock on order cancellation`
- `refactor: move order logic into service layer`
- `docs: update api plan`

Do not use unclear commit messages like:
- `update`
- `fix`
- `new`
- `done`

---

## Coding Rules

To keep the project clean, we should follow these rules:

### Backend Rules
- use a custom user model from the beginning
- keep business logic in service layer, not directly inside views
- use serializers for validation
- use role-based permissions
- keep apps separated by domain
- use pagination for list endpoints
- use clear response structure

### Flutter Rules
- organize code by features
- keep API logic separate from UI
- avoid hardcoded URLs and secrets
- store tokens securely
- do not mix everything into one giant folder

### General Rules
- do not commit `.env` files
- do not push broken code to main
- document important decisions in `/docs`
- keep code readable and simple

---

## Django Admin Role

I want Django Admin to be our first internal control panel.

This means we will use it to:
- verify suppliers
- inspect listings
- inspect orders
- monitor users
- manually fix issues if needed

This saves us from building a separate admin dashboard too early.

---

## Project Build Order

This is the order I want us to follow:

### Phase 1 - Foundation
- setup repository
- setup Django project
- setup PostgreSQL
- setup Flutter project
- configure Docker
- create custom user model
- configure JWT auth

### Phase 2 - Core Backend
- supplier profile
- buyer profile
- listings
- orders
- order status logic
- stock handling
- admin management

### Phase 3 - Core Flutter App
- auth screens
- listings screen
- order creation flow
- buyer dashboard
- supplier dashboard
- profile screens

### Phase 4 - Improvements
- notifications
- testing
- deployment
- analytics later

---

## What Success Looks Like for MVP

The MVP is successful if:
- suppliers can register and be verified
- suppliers can create listings
- buyers can browse and place orders
- buyers and suppliers can track orders
- admins can manage operations
- the codebase is clean enough for the team to continue building on it

---

## Final Note

This project should be built in a clean and disciplined way.

I do not want us to rush into random coding without structure. If the foundation is weak, everything later becomes harder.

So the main idea of this README is to make sure everyone on the team understands:
- what we are building
- why we are building it this way
- what technologies we are using
- how the system is structured
- how we should work together

If we follow this structure from the beginning, the project will be much easier to scale and maintain.
