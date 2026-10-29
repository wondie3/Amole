# Users and profiles (DRAFT)

## GET /v1/me
Auth required. `200`:
```json
{ "id": "usr_1", "phone": "+251911223344", "name": "Abebe Kebede",
  "createdAt": "2026-10-28T09:30:00Z" }
```

## PATCH /v1/me
```json
{ "name": "Abebe Kebede" }
```
Only `name` is editable. Phone changes need a new OTP flow (not defined yet).
Errors: `400 validation_failed` (`name: too_short | too_long`, 2 to 60 chars).

## DELETE /v1/me
Deletes the account and its personal data (addresses, device tokens). Orders
are kept in anonymized form for records. `204`. Requires a recent OTP re-verify
(`409 reauth_required` otherwise).

## Server must enforce
- A user can read and modify only their own record.
- Deleting an account must actually remove personal data (privacy duty).