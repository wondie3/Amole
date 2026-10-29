# Orders (DRAFT)

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
  "payment": { "method": "cash_on_delivery", "status": "pending" }
}
```
Errors:
- `422 cart_invalid` with `issues` (same shape as cart validation), including
  when `expectedTotalSantim` differs from the server total. The app shows the
  new total and asks the user to confirm.
- `400 validation_failed` (`addressId`, `payment.method`).
- `409 restaurant_closed`.
- Same `Idempotency-Key` again returns the original `201`, never a second order.

## GET /v1/orders   GET /v1/orders/{id}
Own orders only, newest first. Another user's order returns `404`.

## POST /v1/orders/{id}/cancel
`200` with the updated order. `409 conflict` (`code: not_cancellable`) once
the restaurant has started preparing.

## Status values and who may set them
`placed -> confirmed -> preparing -> out_for_delivery -> delivered`, plus
`cancelled`. Only the **server**, driven by restaurant and courier actions,
moves the status forward. The customer may only cancel, and only in `placed`
or `confirmed`. The app's "Simulate next step" has no equivalent endpoint.

## Server must enforce
- Recompute everything from the database. Ignore any client price.
- Valid status transitions only; terminal states never change.
- Store a copy of item names, prices and delivery details on the order.