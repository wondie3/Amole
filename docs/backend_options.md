# Backend options (DECISION OPEN)

Nothing is migrated, deployed or connected. This compares options for Amole;
verify current pricing, regions and features in each provider's docs before
committing, because they change.

## Must run on a server whichever option is chosen
Order pricing and fees, availability checks, order status changes, OTP
sending, and payment verification (Telebirr and CBE Birr need server-side
integration).

## A. Extend the existing Next.js app + its PostgreSQL
- Pros: no second backend, no data migration, teaches API concepts directly.
- Cons: mobile token auth, rate limiting, deployment and security are yours.
- Needs checking: does that project's schema and hosting suit restaurants and
  orders? Is it deployed, and who uses it today?

## B. Supabase (managed Postgres, auth, row-level security, functions)
- Pros: plain Postgres, official Flutter SDK, less lock-in than Firebase.
- Cons: row-level security mistakes are security bugs; pricing and payments
  still need server functions; moving existing Postgres data is a migration;
  check regions and latency from Addis Ababa; phone OTP provider coverage in
  Ethiopia must be tested.

## C. Firebase
- Pros: polished SDKs and push.
- Cons: Firestore is NoSQL, a weaker fit for relational orders; SMS auth
  coverage and cost in Ethiopia must be tested.

## Opinion (not a decision)
Lean A if the Next.js project is meant to serve Amole; otherwise B. Avoid
running two backends. Decide after reviewing the existing project's schema
and hosting.

## Open questions
Who hosts and pays? Which SMS/OTP provider works in Ethiopia? Which payment
provider and what onboarding does it require? Where may user data be stored?