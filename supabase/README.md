# Supabase Backend

Amole uses Supabase for authentication and its PostgreSQL database.

The repository includes database migrations, sample development data, Row Level Security policies, database functions, and SQL tests.

## Backend status

The migrations have been pushed to the project's hosted Supabase database. The hosted catalog has been populated with five sample restaurants and five sample dishes.

The Flutter application has been tested against the hosted backend for authentication, email verification, catalog loading, and customer address storage.

This is still a prototype. The presence of server-side ordering functions does not mean the mobile checkout currently uses them.

## Project structure

```text
supabase/
├── migrations/
│   ├── 20261029000100_schema.sql
│   ├── 20261029000200_policies.sql
│   ├── 20261029000300_functions.sql
│   ├── 20261029000400_function_grants.sql
│   ├── 20261030000100_dish_image_asset.sql
│   ├── 20261030000200_catalog_slug_rating.sql
│   └── 20261031000100_my_orders.sql
├── tests/
│   └── database/
├── config.toml
├── seed.sql
├── schema.sql
├── policies.sql
└── functions.sql
```

### Migrations

The `migrations/` directory contains the ordered database changes and is the authoritative migration history.

Migrations cover:

- Database tables, constraints, and indexes.
- Row Level Security policies and permissions.
- Database functions and grants.
- Dish image asset references.
- Restaurant and dish catalog enhancements.
- Customer order-related database functionality.

Do not apply individual migrations manually or out of order.

### Seed data

`seed.sql` provides fictional restaurant and dish records for local development.

It contains five sample restaurants and five sample dishes. Names, prices, and ratings are demonstration data, not real business information.

The seed file is configured to run during a local database reset. It is not automatically included in a normal hosted migration push.

### SQL reference files

The standalone `schema.sql`, `policies.sql`, and `functions.sql` files are reference and review copies.

Use the ordered migration history as the source of truth when setting up or updating a database. Do not independently execute these files on a database that already has the migrations applied.

## Local development

### Requirements

- Node.js and npm
- Docker Desktop
- Supabase CLI

### Start the local backend

From the project root:

```bash
npx supabase start
```

Apply migrations and local seed data:

```bash
npx supabase db reset
```

This resets the local development database. Do not use it against a hosted production database.

### Run database tests

```bash
npx supabase test db
```

The SQL test files are located in `tests/database/`.

## Hosted project setup

To link a local repository to a Supabase project:

```bash
npx supabase login
npx supabase link --project-ref YOUR_PROJECT_REF
```

To push pending migrations:

```bash
npx supabase db push
```

Review migrations before applying them to a hosted database.

The sample seed data is separate from the migration push. Populate a fresh hosted project with appropriate sample or production catalog data through a reviewed process.

## Security considerations

- Never commit service-role keys, database passwords, or other private credentials.
- Never include a service-role key in the Flutter application.
- Keep Row Level Security enabled and review policies whenever database access changes.
- Review `SECURITY DEFINER` functions, grants, and access-control behavior before real-world deployment.
- Use a separate development project for experimental database changes.
- The backend and application have not undergone a professional security audit.

## Important prototype limitations

- The mobile checkout currently uses local demo orders rather than the server-side ordering workflow.
- Payment processing is not integrated.
- Restaurant staff and courier workflows are not implemented.
- Real customer order fulfillment is not available.

A complete security review and operational testing are required before using this backend for a real food-delivery service.
