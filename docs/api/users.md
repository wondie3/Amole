# Users and profiles (DRAFT)

## GET /v1/me
Auth required. `200`:
```json
{ "id": "usr_1", "email": "abebe@example.com", "emailVerified": true,
  "name": "Abebe Kebede", "createdAt": "2026-10-28T09:30:00Z" }
```

## PATCH /v1/me
`{ "name": "Abebe Kebede" }`. Only `name` is editable here. Email changes
need a verification flow (not defined yet). Errors:
`400 validation_failed` (`name: too_short | too_long`, 2 to 60 chars).

## DELETE /v1/me
`{ "password": "..." }` required as re-authentication. Deletes the account
and personal data (addresses, device tokens). Orders are kept in anonymized
form for records. `204`. `401 invalid_credentials` if the password is wrong.

## Server must enforce
- A user can read and modify only their own record.
- Deleting an account must actually remove personal data.