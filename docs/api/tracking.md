# Delivery tracking (DRAFT)

## GET /v1/orders/{id}/tracking
```json
{
  "status": "out_for_delivery",
  "updatedAt": "2026-10-28T09:55:00Z",
  "timeline": [
    { "status": "placed", "at": "2026-10-28T09:30:00Z" },
    { "status": "confirmed", "at": "2026-10-28T09:32:00Z" }
  ],
  "estimatedDeliveryFrom": "2026-10-28T09:50:00Z",
  "estimatedDeliveryTo": "2026-10-28T10:00:00Z",
  "courier": null
}
```
`courier` is `null` until a real courier is assigned. Then it may contain a
first name and a masked contact only.

## Live location (later, optional)
Only if real couriers send real GPS. A location is `{ lat, lng, at }` and is
shown to the customer **only while the order is out for delivery**, then
discarded. Until that exists, the app shows no map and no moving courier.

## Server must enforce
- Timeline entries are written by the server on real status changes.
- Customers see only their own order's tracking. Courier location is never
  exposed to anyone else, and is deleted after delivery.