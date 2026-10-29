# Addresses (DRAFT)

Addis Ababa addresses are unreliable; use sub-city + free text + landmark.

## GET /v1/me/addresses
`200`: `{ "items": [ { ...address } ], "selectedId": "adr_1" }`

## POST /v1/me/addresses
```json
{ "label": "Home", "contactName": "Abebe Kebede", "phone": "+251911223344",
  "subCity": "Bole", "street": "Near Edna Mall", "landmark": "Blue gate" }
```
`201` returns the address with an `id`.
Errors: `400 validation_failed` with fields such as
`label: required`, `phone: invalid_ethiopian_mobile`, `subCity: unknown`,
`street: too_short`; `409 limit_reached` (maximum 10 per user).

## PATCH /v1/me/addresses/{id}   DELETE /v1/me/addresses/{id}   PUT /v1/me/addresses/selected
Same validation. Another user's address returns `404`.

## Server must enforce
- Ownership on every call. Cap of 10. Sub-city must be in the known list.
- Orders store a **copy** of the delivery details, so later edits or deletes
  do not change past orders.