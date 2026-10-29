# Notifications (DRAFT)

Push delivery needs a push service (for example FCM) whichever database or
backend is chosen. The choice is open.

## PUT /v1/me/devices
```json
{ "platform": "android", "pushToken": "..." }
```
`204`. Replaces the token for this device. `DELETE /v1/me/devices/{id}` on
logout.

## Events the server may send
`order.status_changed` with `{ "orderId": "ord_1", "status": "preparing" }`.
Payloads contain ids and status only, never addresses or phone numbers; the
app fetches details after opening.

## Server must enforce
- Tokens belong to one user; remove them on logout and when the push service
  reports them invalid.
- Users can opt out. Marketing messages are opt-in only.