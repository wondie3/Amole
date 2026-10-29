# Orders (DRAFT)

Customers can only see and manage **their own** orders. Another user's order
returns `404 not_found`, never `403`, so ids cannot be probed.

## POST /v1/orders
Headers: `Idempotency-Key: <uuid>`. Auth required.
```json
{
  "lines": [ { "dishId": "dish_1", "quantity": 2, "spice": "spicy" } ],
  "addressId": "adr_1",
  "payment": { "method": "cash_on_delivery" },
  "expectedTotalSantim": 68500
}
```
`201`:
```json
{
  "id": "ord_1", "status": "placed", "createdAt": "2026-10-28T09:30:00Z",
  "restaurant": { "id": "rest_1", "name": "Sheger Grill" },
  "items": [ { "dishId": "dish_1", "name": "Tibs", "quantity": 2,
               "unitPriceSantim": 32000, "spice": "spicy" } ],
  "subtotalSantim": 64000, "deliveryFeeSantim": 4500, "totalSantim": 68500,
  "estimatedDeliveryFrom": "2026-10-28T09:50:00Z",
  "estimatedDeliveryTo": "2026-10-28T10:00:00Z",
  "payment": { "method": "cash_on_delivery", "status": "pending" },
  "cancellationRequest": null
}
```
The client sends no prices. `expectedTotalSantim` is only a check: if it
differs from the server's total, the server answers `422 cart_invalid` with
the new totals and the user must confirm again.
Errors: `422 cart_invalid` (with `issues`), `400 validation_failed`
(`addressId`, `payment.method`), `409 restaurant_closed`,
`401 unauthenticated`. The same `Idempotency-Key` returns the original `201`.

## GET /v1/orders   GET /v1/orders/{id}
Own orders only, newest first, paginated.

## Statuses
`placed`, `confirmed`, `preparing`, `ready`, `out_for_delivery`, `delivered`,
`cancelled`. Mobile-money orders may start in `awaiting_payment` (see
payments.md). `delivered` and `cancelled` are terminal and never change.

## Allowed transitions and who may trigger them
| From | To | Actor |
|---|---|---|
| awaiting_payment | placed | system (verified payment callback) |
| awaiting_payment | cancelled | system (payment failed or timed out) |
| placed | confirmed | restaurant staff |
| placed | cancelled | customer (instant) or restaurant staff (reject, reason required) |
| confirmed | preparing | restaurant staff |
| confirmed | cancelled | restaurant staff (own decision, or accepting a customer request) |
| preparing | ready | restaurant staff |
| preparing | cancelled | restaurant staff (own decision, or accepting a request) |
| ready | out_for_delivery | assigned courier |
| ready | cancelled | restaurant staff (own decision, or accepting a request) |
| out_for_delivery | delivered | assigned courier |
| out_for_delivery | cancelled | support only (failed delivery) |

Any other transition returns `409 conflict` (`code: invalid_transition`).
Customers can never set any status except by cancelling a `placed` order.
Staff are users with a role tied to one restaurant and can act only on that
restaurant's orders. Courier actions apply only to the assigned courier.

## Cancellation by the customer

### POST /v1/orders/{id}/cancel
Body: `{ "reason": "changed_my_mind" }` (optional, from a fixed list).

- Status `placed`: `200`, the order is now `cancelled`.
- Status `confirmed`, `preparing` or `ready`: `202`. The status does **not**
  change; the order gets a request:
```json
{ "id": "ord_1", "status": "preparing",
  "cancellationRequest": { "status": "pending",
    "requestedAt": "2026-10-28T09:33:00Z", "decidedAt": null,
    "decisionReason": null, "escalatedAt": null } }
```
- A request already pending: `200` with the existing request (idempotent).
- Status `out_for_delivery`, `delivered` or `cancelled`: `409 conflict`
  (`code: not_cancellable`). The customer is told to contact support.

### Request lifecycle (`cancellationRequest.status`)
`pending` -> `accepted` or `declined`.
- **Only authorized staff of the order's restaurant** may accept or decline.
  A decline needs a reason shown to the customer.
- **Accepted:** the order becomes `cancelled`.
- **Declined:** the order keeps exactly the status it had. Nothing else
  changes.
- The server never accepts or declines on its own. If a request is still
  pending after 5 minutes, the server sets `escalatedAt` and notifies
  support. It does not decide the request. (Open question: keep this, or
  auto-accept after a timeout?)
- The order may move forward (for example `confirmed` to `preparing`) while a
  request is pending. The request stays pending until staff decide.
- One request per order. After a decline, the customer cannot ask again;
  support handles exceptions.

### DELETE /v1/orders/{id}/cancel
Withdraws a pending request. `200`. `409` if it was already decided.

## Staff endpoints (separate API, outline only)
`POST /v1/staff/orders/{id}/cancellation/accept` and `/decline`.
Authorization: authenticated, staff role, same restaurant as the order.
Otherwise `404`. The request must be `pending` or `409 conflict`.

## Money on cancellation
- Cash on delivery: nothing was charged, so nothing is refunded.
- Online payment already `paid`: a refund is required, but **refund handling
  is undefined until a payment provider is chosen**. Until then the server
  must not mark such an order `cancelled` without a recorded refund task.

## Server must enforce
- Recompute everything from the database. Ignore any client price or total.
- Valid transitions only, by the right actor; terminal states never change.
- Apply the rules and timers on the server clock, never the app's.
- Customers have no direct write access to order status or request fields.
- Store a copy of item names, prices and delivery details on the order.
- Write every status change and request decision to an audit log.