# Amole

A food-delivery app for Ethiopia, built with Flutter. **This is a prototype.**
No real restaurants, orders, payments or deliveries exist behind it.

Tagline: Good food, delivered.

## What is real

- Flutter app (Android tested on a Samsung Galaxy M15): home, search with
  filters and sorting, restaurant pages, dish details, favorites, cart,
  checkout, order history and cancellation rules.
- Email and password accounts against a **local** Supabase (Docker), with
  email verification.
- The menu is read from the local database and falls back to built-in sample
  data if the server cannot be reached.
- Saved delivery addresses in your account, with an optional, confirmed copy
  from the phone.
- Cart, favorites and demo orders are kept separately for each account on the
  phone.
- Database: schema, row level security, server functions (order pricing,
  idempotent ordering, cancellation requests, staff access) and 95 database
  tests.
- 235 Flutter tests. `flutter analyze` is clean.

## What is simulated or missing

- **Orders are demo orders.** Checkout, tracking and the order timeline run on
  the phone. Status changes happen only when you press a "Simulate" button.
  The server-side ordering code and tests exist in the repository, but the
  app screens do not use them yet.
- **No payments.** Cash on delivery is the only option. Telebirr and CBE Birr
  are listed but disabled.
- **No restaurant or staff app, and no couriers.** Nothing acts on an order.
- Restaurants, prices, ratings, delivery fees and delivery times are sample
  data. Restaurant names are fictional.
- No maps, GPS or live tracking.
- No push notifications.

## Known limits before any real release

- The login session and saved data are stored unencrypted in
  `shared_preferences`. Use secure storage first.
- Finishing a password reset inside the app needs deep links, which are not
  built.
- Debug builds allow plain HTTP to `127.0.0.1`. Release builds do not, so a
  release build needs a hosted backend.
- The Supabase SQL is tested locally only. It has not been deployed or
  reviewed by a security professional.
- Contact details are not shown on server orders.
- Dish photos are bundled files under Creative Commons licenses. See Photo
  credits in the app, and `assets/images/ATTRIBUTIONS.md`.

## Run it

1. Install Flutter, Docker Desktop and Node.
2. Start the local backend:
   `npx supabase start`
   then `npx supabase db reset` to apply the migrations and seed data.
3. Copy `env/local.example.json` to `env/local.json` and put the local
   **publishable** key in it. Never put a secret key in the app or in Git.
4. For a USB phone: `adb reverse tcp:54321 tcp:54321`.
5. `flutter run --dart-define-from-file=env/local.json`

Without the define file the app runs fully offline with sample data.

## Tests

- `flutter analyze` and `flutter test`
- `npx supabase test db`

## Documents

- `docs/api/` draft API contracts
- `docs/backend_options.md` backend comparison and decision
- `supabase/README.md` database review notes