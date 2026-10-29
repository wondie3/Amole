# Supabase SQL (DRAFT)

**Nothing here has been run.** These files were written without a database to
test against and from memory of Supabase conventions. Check them against the
current Supabase docs first. Do not run them on any project that holds real
data.

## Files
| File | Status |
|---|---|
| `schema.sql` | Tables, constraints, indexes, small triggers |
| `policies.sql` | Grants, Row Level Security, `is_staff_of` helper |
| `functions.sql` | Drafted, untested: user trigger, `place_order`, `select_address`, cancellation, staff functions, contact functions |

Apply order: `schema.sql`, `policies.sql`, `functions.sql`.

## Review checklist (highest risk first)
1. **Grants.** `policies.sql` begins by revoking default privileges. Confirm
   that default behavior against current docs, then confirm the only write
   grants are `profiles.name` and `addresses`.
2. **`is_staff_of`.** `SECURITY DEFINER` bypasses RLS. It must keep the fixed
   `search_path`, schema-qualified names, and use only `auth.uid()`.
3. **Orders are read-only to clients.** No insert, update or delete policy or
   grant may ever be added to `orders`, `order_items`,
   `cancellation_requests` or `audit_log`.
4. **Staff see customer contact details** (name, phone, street) on their
   restaurant's orders. Decide if that is acceptable, and what couriers see.
5. **Account deletion.** `orders.user_id` becomes null, but the delivery
   contact columns still hold personal data. A scrub step is still needed
   (open item for `functions.sql`).
6. **Admin tasks** (creating staff memberships, restaurants, dishes) use the
   service role key. That key must never ship in the app or this repo.

## Testing before any real use
Use a throwaway local Supabase (the Supabase CLI runs it in Docker; check the
current docs for commands). Never test against a production project.
Write tests that sign in as customer A, customer B, a staff member and an
anonymous user, then confirm:
- A cannot read B's orders, items, requests or addresses.
- A cannot insert, update or delete any order, item or request.
- Staff can read only their own restaurant's orders.
- Anonymous can read menus and nothing else.
- Inserting an 11th address fails.
Once `functions.sql` exists, add tests for each function's allowed and
refused transitions from `docs/api/orders.md`.

## Not covered yet
Courier access, online payment records, push tokens, refund tasks, email
templates, and the escalation job for requests pending over 5 minutes.
## Staff access to customer details
- Staff see the customer name and sub-city on their restaurant's orders.
- Phone, street and landmark are not readable through the API by anyone.
  Staff get them only from `staff_get_order_contact`, for confirmed,
  preparing, ready or out-for-delivery orders, with no street for pickup,
  and each call is audited.
- Staff have no write access to orders. A trigger also blocks changes to
  `restaurant_id`, prices, totals and payment method, and enforces the
  allowed status transitions.
- Clients must select orders by column name. `select *` on `orders` fails.

## Extra review items for functions.sql
7. Every `security definer` function sets `search_path = ''` and calls
   `auth.uid()` itself. Check this for each one.
8. `order_json` ignores ownership. It must stay ungranted to clients.
9. `place_order`: only cash on delivery is accepted until a provider exists.
10. Cancelling an already-paid order raises `refund_required` until refunds
    are defined.
11. Courier functions (ready to out_for_delivery, delivered) do not exist.
12. Schedule `escalate_stale_cancellation_requests()` (for example pg_cron).
13. The triggers on `auth.users` may need to be created as the project owner.
    Confirm against current docs.