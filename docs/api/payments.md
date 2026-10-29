# Payments (DRAFT)

Cash on delivery needs no payment call. Mobile money (Telebirr, CBE Birr)
needs a provider integration. **Provider endpoints, signing and callbacks are
not defined here and must be taken from each provider's official
documentation. Nothing below is a real provider API.**

## Flow for a mobile-money order (outline)
1. App calls `POST /v1/orders` with `payment.method = "telebirr"`.
2. Server creates the order in `awaiting_payment` and a payment record, then
   asks the provider to start a payment. It returns the provider's
   redirect or USSD instructions, never any secret.
3. The user pays in the provider's own screen. **The app never collects wallet
   PINs or credentials.**
4. The provider notifies the **server** (webhook). The server verifies the
   signature, checks the amount and reference, then marks the payment `paid`
   and the order `placed`.
5. The app polls `GET /v1/orders/{id}` for the result.

## GET /v1/orders/{id}/payment
```json
{ "method": "telebirr", "status": "pending", "amountSantim": 68500 }
```
Statuses: `pending`, `paid`, `failed`, `refunded`.

## Server must enforce
- Payment success is decided only by a verified provider callback, never by
  the app's say-so.
- Callbacks are idempotent, signature-checked, and matched against the
  expected amount. Unknown or duplicate callbacks are ignored safely.
- Provider keys live in server secrets, never in the app or the repo.
- Refunds, disputes and reconciliation are out of scope until a provider is
  chosen.