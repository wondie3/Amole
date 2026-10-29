-- Amole access rules. DRAFT: never run until reviewed. Apply after schema.sql.
-- Principle: clients READ what they own; every WRITE to orders, requests and
-- audit rows goes through a function (functions.sql). A wrong policy here is
-- a data leak, so each one says who it allows and why.

-- 1. Start from nothing. Supabase grants broad default table privileges to the
--    anon and authenticated roles, so remove them and add back only what is
--    intended below. Verify this default against current Supabase docs.
revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
alter default privileges in schema public revoke all on tables from anon, authenticated;
alter default privileges in schema public revoke all on sequences from anon, authenticated;

-- 2. Helper: is the signed-in user staff of this restaurant?
--    SECURITY DEFINER so it can read staff_memberships, which clients cannot.
--    It only answers about auth.uid(), never about a caller-chosen user.
--    REVIEW CAREFULLY: fixed search_path, schema-qualified names.
create function public.is_staff_of(p_restaurant uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.staff_memberships m
    where m.user_id = (select auth.uid()) and m.restaurant_id = p_restaurant
  );
$$;
revoke all on function public.is_staff_of(uuid) from public;
grant execute on function public.is_staff_of(uuid) to authenticated;

-- 3. Turn on row-level security everywhere. With RLS on and no policy,
--    a table returns no rows and accepts no writes.
alter table public.profiles enable row level security;
alter table public.restaurants enable row level security;
alter table public.dishes enable row level security;
alter table public.staff_memberships enable row level security;
alter table public.addresses enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.cancellation_requests enable row level security;
alter table public.audit_log enable row level security;

-- profiles: a user reads and edits only their own row, and only the name.
grant select on public.profiles to authenticated;
grant update (name) on public.profiles to authenticated;
create policy profiles_select_own on public.profiles
  for select to authenticated using (id = (select auth.uid()));
create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));
-- No insert policy: rows are created by the handle_new_user trigger.

-- restaurants and dishes: public menu, read-only for everyone.
-- Staff editing availability will go through a function later.
grant select on public.restaurants, public.dishes to anon, authenticated;
create policy restaurants_public_read on public.restaurants
  for select to anon, authenticated using (true);
create policy dishes_public_read on public.dishes
  for select to anon, authenticated using (true);

-- staff_memberships: a user can see only their own memberships. Nobody can
-- write them through the API; an administrator uses the service role.
grant select on public.staff_memberships to authenticated;
create policy staff_memberships_select_own on public.staff_memberships
  for select to authenticated using (user_id = (select auth.uid()));

-- addresses: full control, but only over your own rows. WITH CHECK stops a
-- user from inserting or moving a row onto someone else's id.
grant select, insert, update, delete on public.addresses to authenticated;
create policy addresses_select_own on public.addresses
  for select to authenticated using (user_id = (select auth.uid()));
create policy addresses_insert_own on public.addresses
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy addresses_update_own on public.addresses
  for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy addresses_delete_own on public.addresses
  for delete to authenticated using (user_id = (select auth.uid()));

-- orders: READ-ONLY for clients. Customers see their own; staff see their
-- restaurant's. No insert, update or delete policy and no write grant, so
-- status, prices and totals cannot be changed from the app.
-- NOTE: staff can see the customer's delivery name, phone and street, which
-- the restaurant needs. Couriers get a separate, narrower rule later.
grant select on public.orders to authenticated;
create policy orders_select_own on public.orders
  for select to authenticated using (user_id = (select auth.uid()));
create policy orders_select_staff on public.orders
  for select to authenticated using (public.is_staff_of(restaurant_id));

-- order_items and cancellation_requests: visible exactly when the parent
-- order is visible. The subquery runs under the orders policies above.
grant select on public.order_items, public.cancellation_requests to authenticated;
create policy order_items_select_via_order on public.order_items
  for select to authenticated
  using (exists (select 1 from public.orders o where o.id = order_id));
create policy cancellation_requests_select_via_order on public.cancellation_requests
  for select to authenticated
  using (exists (select 1 from public.orders o where o.id = order_id));

-- audit_log: no grants and no policies, so clients cannot read or write it.
-- Support reads it with the service role.