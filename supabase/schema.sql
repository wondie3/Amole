-- Amole database schema. DRAFT: never run against any database until reviewed.
-- Money is integer santim (1 ETB = 100 santim). Timestamps are UTC.
-- Matches docs/api/*.md. Apply order: schema.sql, policies.sql, functions.sql.

create type public.order_status as enum (
  'awaiting_payment', 'placed', 'confirmed', 'preparing', 'ready',
  'out_for_delivery', 'delivered', 'cancelled'
);
create type public.cancellation_status as enum ('pending', 'accepted', 'declined');
create type public.payment_method as enum ('cash_on_delivery', 'telebirr', 'cbe_birr');
create type public.payment_status as enum ('pending', 'paid', 'failed', 'refunded');
create type public.staff_role as enum ('manager', 'staff');

-- One row per signed-up user. Created by a trigger on auth.users
-- (handle_new_user, defined in functions.sql). Email lives in auth.users.
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  name text check (name is null or char_length(name) between 2 and 60),
  created_at timestamptz not null default now()
);

create table public.restaurants (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 2 and 80),
  cuisine text not null,
  rating numeric(2, 1) check (rating between 0 and 5),
  eta_min_minutes int not null check (eta_min_minutes >= 0),
  eta_max_minutes int not null check (eta_max_minutes >= eta_min_minutes),
  delivery_fee_santim int not null check (delivery_fee_santim >= 0),
  is_open boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.dishes (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants (id) on delete cascade,
  category text not null check (category in ('stew', 'grill', 'fasting', 'breakfast')),
  name text not null check (char_length(name) between 2 and 80),
  description text not null default '',
  price_santim int not null check (price_santim > 0),
  available boolean not null default true,
  has_spice_options boolean not null default false,
  image_url text,
  image_credit text,
  created_at timestamptz not null default now()
);
create index dishes_restaurant_idx on public.dishes (restaurant_id);

-- Which restaurants a user may act for. Rows are created by an administrator
-- only (service role), never by clients.
create table public.staff_memberships (
  user_id uuid not null references auth.users (id) on delete cascade,
  restaurant_id uuid not null references public.restaurants (id) on delete cascade,
  role public.staff_role not null default 'staff',
  created_at timestamptz not null default now(),
  primary key (user_id, restaurant_id)
);
create index staff_memberships_restaurant_idx on public.staff_memberships (restaurant_id);

-- Saved delivery addresses. Max 10 per user (trigger below).
create table public.addresses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  label text not null check (char_length(btrim(label)) between 1 and 20),
  contact_name text not null check (char_length(btrim(contact_name)) between 2 and 60),
  phone text not null check (phone ~ '^\+251[79][0-9]{8}$'),
  sub_city text not null check (sub_city in (
    'Addis Ketema', 'Akaky Kaliti', 'Arada', 'Bole', 'Gullele', 'Kirkos',
    'Kolfe Keranio', 'Lemi Kura', 'Lideta', 'Nifas Silk-Lafto', 'Yeka',
    'Other area')),
  street text not null check (char_length(btrim(street)) between 5 and 120),
  landmark text check (landmark is null or char_length(landmark) <= 80),
  is_selected boolean not null default false,
  created_at timestamptz not null default now()
);
create index addresses_user_idx on public.addresses (user_id);
-- At most one selected address per user. Switching selection must happen in
-- one function call (select_address, functions.sql), not two client updates.
create unique index addresses_one_selected on public.addresses (user_id) where is_selected;

create function public.enforce_address_limit() returns trigger
language plpgsql set search_path = '' as $$
begin
  if (select count(*) from public.addresses where user_id = new.user_id) >= 10 then
    raise exception 'address_limit_reached' using errcode = '23514';
  end if;
  return new;
end $$;
-- Known gap: two simultaneous inserts could exceed 10. Low risk; revisit.
create trigger addresses_limit before insert on public.addresses
  for each row execute function public.enforce_address_limit();

-- Orders are created only by place_order (functions.sql). Prices, fees and
-- totals are computed there from restaurants and dishes, never from the client.
create table public.orders (
  id uuid primary key default gen_random_uuid(),
  -- Set null when an account is deleted, so the order survives anonymized.
  user_id uuid references auth.users (id) on delete set null,
  restaurant_id uuid not null references public.restaurants (id),
  status public.order_status not null default 'placed',
  subtotal_santim int not null check (subtotal_santim >= 0),
  delivery_fee_santim int not null check (delivery_fee_santim >= 0),
  total_santim int not null,
  -- Copy of the delivery details at ordering time. Contact fields are
  -- nullable because they must be scrubbed when an account is deleted.
  delivery_name text,
  delivery_phone text,
  delivery_sub_city text not null,
  delivery_street text,
  delivery_landmark text,
  payment_method public.payment_method not null,
  payment_status public.payment_status not null default 'pending',
  eta_from timestamptz,
  eta_to timestamptz,
  idempotency_key uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint orders_total_matches check (total_santim = subtotal_santim + delivery_fee_santim),
  constraint orders_one_per_key unique (user_id, idempotency_key)
);
create index orders_user_idx on public.orders (user_id, created_at desc);
create index orders_restaurant_idx on public.orders (restaurant_id, status);

create function public.set_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at = now();
  return new;
end $$;
create trigger orders_updated_at before update on public.orders
  for each row execute function public.set_updated_at();

-- A copy of what was ordered, so later menu changes never alter an order.
create table public.order_items (
  id bigint generated always as identity primary key,
  order_id uuid not null references public.orders (id) on delete cascade,
  dish_id uuid references public.dishes (id) on delete set null,
  name text not null,
  unit_price_santim int not null check (unit_price_santim >= 0),
  quantity int not null check (quantity between 1 and 20),
  spice text check (spice in ('mild', 'medium', 'spicy'))
);
create index order_items_order_idx on public.order_items (order_id);

-- One request per order (primary key). Withdrawing a pending request deletes
-- the row. Only restaurant staff decide; the server never decides on its own.
create table public.cancellation_requests (
  order_id uuid primary key references public.orders (id) on delete cascade,
  status public.cancellation_status not null default 'pending',
  requested_at timestamptz not null default now(),
  decided_at timestamptz,
  decided_by uuid references auth.users (id) on delete set null,
  decision_reason text,
  -- Set when still pending after 5 minutes: support is notified, nothing is
  -- decided automatically.
  escalated_at timestamptz,
  constraint decline_needs_reason check (status <> 'declined' or decision_reason is not null)
);

-- Every status change and decision. Written by functions only.
create table public.audit_log (
  id bigint generated always as identity primary key,
  at timestamptz not null default now(),
  order_id uuid references public.orders (id) on delete set null,
  actor_id uuid,
  actor_role text not null,  -- customer | staff | courier | system | support
  action text not null,
  from_status public.order_status,
  to_status public.order_status,
  detail jsonb
);
create index audit_log_order_idx on public.audit_log (order_id);