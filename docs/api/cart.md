# Cart validation (DRAFT)

The cart lives on the phone. The server only **validates and prices** it.

## POST /v1/cart/validate
```json
{ "lines": [ { "dishId": "dish_1", "quantity": 2, "spice": "spicy" } ] }
```
`200`:
```json
{
  "restaurantId": "rest_1",
  "lines": [ { "dishId": "dish_1", "name": "Tibs", "quantity": 2,
               "unitPriceSantim": 32000, "lineTotalSantim": 64000,
               "available": true } ],
  "subtotalSantim": 64000, "deliveryFeeSantim": 4500, "totalSantim": 68500,
  "issues": []
}
```
Issues are returned in `issues`, for example:
`{ "dishId": "dish_2", "code": "unavailable" }`,
`{ "dishId": "dish_1", "code": "price_changed", "oldPriceSantim": 30000 }`,
`{ "code": "mixed_restaurants" }`.

Errors: `400 validation_failed` (`quantity: 1..20`, unknown `spice`).

## Server must enforce
- One restaurant per cart. Quantity 1 to 20 per line.
- Prices and the delivery fee come from the database, never the request.
- This call has no side effects, so it is safe to repeat.