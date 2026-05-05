# API Plan

## Overview
The mobile application communicates with the backend using REST APIs. All APIs are versioned under the `/api/v1/` prefix.

Authentication is based on JWT tokens. Protected endpoints require a valid access token in the Authorization header.

Example header:

`Authorization: Bearer <access_token>`

## Base API Prefix
`/api/v1/`

## Authentication APIs

### Register
- Method: `POST`
- Endpoint: `/api/v1/auth/register/`
- Access: Public

Purpose:
- create a new user account

Example request:
```json
{
  "full_name": "Ali Supplier",
  "email": "supplier@test.com",
  "password": "12345678",
  "phone": "+998901234567",
  "role": "SUPPLIER"
}