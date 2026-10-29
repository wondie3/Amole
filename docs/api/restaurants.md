# Restaurants and menus (DRAFT)

## GET /v1/restaurants  (Public)
Query: `q`, `category`, `sort=recommended|rating|eta|fee`, `limit`, `cursor`.
```json
{ "items": [
  { "id": "rest_1", "name": "Sheger Grill", "cuisine": "Tibs and kitfo",
    "rating": 4.4, "etaMinMinutes": 20, "etaMaxMinutes": 30,
    "deliveryFeeSantim": 4500, "isOpen": true }
], "nextCursor": null }
```

## GET /v1/restaurants/{id}  (Public)
Returns the restaurant plus its menu grouped by category:
```json
{ "id": "rest_1", "name": "Sheger Grill", "isOpen": true,
  "menu": [ { "category": "grill", "dishes": [
    { "id": "dish_1", "name": "Tibs", "priceSantim": 32000,
      "description": "...", "imageUrl": "https://...",
      "available": true, "spiceOptions": ["mild","medium","spicy"] } ] } ] }
```
Errors: `404 not_found`.

## Server must enforce
- `available` and `isOpen` come from the restaurant, not the app.
- Ratings and ETAs must be computed from real data. Sample values in the
  current app are not real.
- Images carry license and credit metadata (`credit` field) where required.