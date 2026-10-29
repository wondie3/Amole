# Amole API contracts (DRAFT)

These are proposed contracts for a future backend. **No server exists yet** and
none of these endpoints are real. Agree on them before building anything.

## Conventions
- Base path: `/v1`. JSON only. UTF-8.
- Money: integer **santim** (1 ETB = 100 santim). Never floats.
- Timestamps: UTC ISO-8601, e.g. `2026-10-28T09:30:00Z`.
- IDs: opaque strings. The client must not parse them.
- Auth: `Authorization: Bearer <access_token>` unless an endpoint says "Public".
- Writes that create things (orders, payments) require an `Idempotency-Key`
  header (a client-generated UUID). Repeating a request with the same key
  returns the original result and never creates a second record.
- Lists are paginated: `?limit=20&cursor=...` returning `{ "items": [], "nextCursor": null }`.

## Error shape (all endpoints)
```json
{
  "error": {
    "code": "validation_failed",
    "message": "Some fields are invalid.",
    "fields": { "phone": "invalid_ethiopian_mobile" },
    "requestId": "req_123"
  }
}
```

| HTTP | code | Meaning |
|---|---|---|
| 400 | `validation_failed` | Body or query is invalid; `fields` says which |
| 401 | `unauthenticated` | Missing, expired or invalid token |
| 403 | `forbidden` | Authenticated but not allowed |
| 404 | `not_found` | Missing, or not visible to this user |
| 409 | `conflict` | State does not allow this (e.g. cancelling a preparing order) |
| 422 | `cart_invalid` | Cart changed (price, availability); see orders.md |
| 429 | `rate_limited` | Too many requests; honor `Retry-After` |
| 500 | `internal` | Server fault; no internal details in the message |

## Rules that apply everywhere
- The server never trusts the client for prices, fees, availability, order
  status, or payment results. It recomputes them.
- Users can only read and change their own data. A resource that belongs to
  someone else returns `404`, not `403`, so ids cannot be probed.
- Never log passwords, tokens, OTP codes, or full phone numbers.

## Files
auth, users, restaurants, addresses, cart, orders, payments, tracking,
notifications. See also `../backend_options.md`.