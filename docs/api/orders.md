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
`placed`, `confirmed`, `preparing`, `out_for_delivery`, `delivered`,
`cancelled`. Mobile-money orders may start in `awaiting_payment` (see
payments.md). `delivered` and `cancelled` are terminal and never change.

## Allowed transitions and who may trigger them
| From | To | Actor |
|---|---|---|
| awaiting_payment | placed | system (verified payment callback) |
| awaiting_payment | cancelled | system (payment failed or timed out) |
| placed | confirmed | restaurant |
| placed | cancelled | customer (instant) or restaurant (reject, reason required) |
| confirmed | preparing | restaurant |
| confirmed | cancelled | restaurant, or system when a customer request is accepted |
| preparing | out_for_delivery | restaurant or assigned courier |
| preparing | cancelled | restaurant only (cannot fulfil), reason required |
| out_for_delivery | delivered | assigned courier |
| out_for_delivery | cancelled | support only (failed delivery) |

Any other transition returns `409 conflict` (`code: invalid_transition`).
Customers can never set any status except through the cancel endpoints.
Restaurant and courier actions belong to a separate staff API with its own
roles. Staff see only their own restaurant's or assigned orders.

## Cancellation by the customer

### POST /v1/orders/{id}/cancel
Body: `{ "reason": "changed_my_mind" }` (optional, from a fixed list).

- Status `placed`: `200`, order is now `cancelled`.
- Status `confirmed`: `202`, status stays `confirmed` and the order gets
  a request:
```json
{ "id": "ord_1", "status": "confirmed",
  "cancellationRequest": { "status": "pending",
    "requestedAt": "2026-10-28T09:33:00Z", "decidedAt": null,
    "autoAcceptAt": "2026-10-28T09:35:00Z" } }
```
- Request already pending: `200` with the existing request (idempotent).
- Status `preparing` or later, or terminal: `409 conflict`
  (`code: not_cancellable`).

### Request lifecycle (`cancellationRequest.status`)
`pending` -> `accepted` (order becomes `cancelled`) or `declined`.
- Restaurant accepts or declines (staff API). A decline needs a reason.
- If still pending and the order is still `confirmed` at `autoAcceptAt`
  (2 minutes after the request), the server accepts it.
- If the restaurant moves the order to `preparing` first, the request is
  declined automatically with `reason: preparing_started`.
- Only one request per order. After a decline, the customer cannot request
  again; support handles exceptions.

### DELETE /v1/orders/{id}/cancel
Withdraws a pending request. `200`. `409` if it was already decided.

## Money on cancellation
- Cash on delivery: nothing was charged, nothing to refund.
- Online payment already `paid`: a refund is required, but **refund handling
  is undefined until a payment provider is chosen**. Until then the server
  must not mark such an order `cancelled` without a recorded refund task.

## Server must enforce
- Recompute everything from the database. Ignore any client price or total.
- Valid transitions only, by the right actor; terminal states never change.
- Apply the cancellation rules and timers on the server clock, never the
  app's. The app only displays the result.
- Store a copy of item names, prices and delivery details on the order.
- Write every status change and request decision to an audit log.