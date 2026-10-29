begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
grant usage on schema extensions to anon, authenticated;
grant execute on all functions in schema extensions to anon, authenticated;
select * from no_plan();

-- ---------- Test data (as postgres) ----------
-- A, B customers; S1 staff of restaurant 1; S2 staff of restaurant 2.
insert into auth.users (id, aud, role, email) values
  ('00000000-0000-0000-0000-00000000000a', 'authenticated', 'authenticated', 'a@test.local'),
  ('00000000-0000-0000-0000-00000000000b', 'authenticated', 'authenticated', 'b@test.local'),
  ('00000000-0000-0000-0000-00000000000c', 'authenticated', 'authenticated', 's1@test.local'),
  ('00000000-0000-0000-0000-00000000000d', 'authenticated', 'authenticated', 's2@test.local');

insert into public.restaurants (id, name, cuisine, rating, eta_min_minutes, eta_max_minutes, delivery_fee_santim) values
  ('11111111-1111-1111-1111-111111111111', 'Test Grill', 'Grill', 4.0, 20, 30, 4500),
  ('22222222-2222-2222-2222-222222222222', 'Test Kitchen', 'Stews', 4.5, 30, 40, 3000);

insert into public.dishes (id, restaurant_id, category, name, price_santim, has_spice_options) values
  ('d1d1d1d1-d1d1-d1d1-d1d1-d1d1d1d1d1d1', '11111111-1111-1111-1111-111111111111', 'grill', 'Tibs', 32000, true),
  ('d2d2d2d2-d2d2-d2d2-d2d2-d2d2d2d2d2d2', '22222222-2222-2222-2222-222222222222', 'stew', 'Shiro', 19000, false);

insert into public.staff_memberships (user_id, restaurant_id) values
  ('00000000-0000-0000-0000-00000000000c', '11111111-1111-1111-1111-111111111111'),
  ('00000000-0000-0000-0000-00000000000d', '22222222-2222-2222-2222-222222222222');

insert into public.addresses (id, user_id, label, contact_name, phone, sub_city, street) values
  ('a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1', '00000000-0000-0000-0000-00000000000a', 'Home', 'Abebe Kebede', '+251911223344', 'Bole', 'Near Edna Mall'),
  ('b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1', '00000000-0000-0000-0000-00000000000b', 'Home', 'Bekele Girma', '+251922334455', 'Kirkos', 'Near Meskel Square');

-- ---------- Anonymous ----------
reset role;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;

select isnt_empty($$ select id from public.restaurants $$, 'anon can read restaurants');
select isnt_empty($$ select id from public.dishes $$, 'anon can read dishes');
select throws_ok($$ select id from public.orders $$, '42501', null, 'anon cannot read orders');
select throws_ok($$ select id from public.addresses $$, '42501', null, 'anon cannot read addresses');
select throws_ok(
  $$ select public.place_order('00000000-0000-0000-0000-000000000009'::uuid,
       '[{"dishId":"d1d1d1d1-d1d1-d1d1-d1d1-d1d1d1d1d1d1","quantity":1}]'::jsonb,
       'a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1'::uuid, 'cash_on_delivery'::public.payment_method, null) $$,
  '42501', null, 'anon cannot place an order');

-- ---------- Customer A ----------
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
set local role authenticated;

select throws_ok(
  $$ select public.place_order('00000000-0000-0000-0000-000000000001'::uuid,
       '[{"dishId":"d1d1d1d1-d1d1-d1d1-d1d1-d1d1d1d1d1d1","quantity":2,"spice":"spicy"}]'::jsonb,
       'a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1'::uuid, 'cash_on_delivery'::public.payment_method, 100) $$,
  'P0001', 'cart_invalid', 'a wrong expected total is rejected');

select lives_ok(
  $$ select set_config('test.order_id',
       (public.place_order('00000000-0000-0000-0000-000000000001'::uuid,
         '[{"dishId":"d1d1d1d1-d1d1-d1d1-d1d1-d1d1d1d1d1d1","quantity":2,"spice":"spicy"}]'::jsonb,
         'a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1'::uuid, 'cash_on_delivery'::public.payment_method, 68500) ->> 'id'), true) $$,
  'A places an order with the server-computed total (2 x 32000 + 4500)');

select is(
  (public.place_order('00000000-0000-0000-0000-000000000001'::uuid,
     '[{"dishId":"d1d1d1d1-d1d1-d1d1-d1d1-d1d1d1d1d1d1","quantity":2,"spice":"spicy"}]'::jsonb,
     'a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1'::uuid, 'cash_on_delivery'::public.payment_method, 68500) ->> 'id'),
  current_setting('test.order_id'),
  'replaying the same idempotency key returns the same order');

select throws_ok(
  $$ select public.place_order('00000000-0000-0000-0000-000000000002'::uuid,
       '[{"dishId":"d1d1d1d1-d1d1-d1d1-d1d1-d1d1d1d1d1d1","quantity":1}]'::jsonb,
       'b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1'::uuid, 'cash_on_delivery'::public.payment_method, null) $$,
  'P0001', 'address_not_found', 'A cannot order to B''s address');

select throws_ok(
  $$ select public.place_order('00000000-0000-0000-0000-000000000003'::uuid,
       '[{"dishId":"d1d1d1d1-d1d1-d1d1-d1d1-d1d1d1d1d1d1","quantity":1}]'::jsonb,
       'a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1'::uuid, 'telebirr'::public.payment_method, null) $$,
  'P0001', 'payment_not_available', 'online payment is refused until a provider exists');

select is((select count(*) from public.orders), 1::bigint, 'A sees exactly their one order');
select throws_ok($$ select delivery_phone from public.orders $$, '42501', null,
  'A cannot read delivery_phone directly');
select throws_ok($$ update public.orders set status = 'delivered' $$, '42501', null,
  'A cannot update orders directly');
select throws_ok($$ delete from public.orders $$, '42501', null, 'A cannot delete orders');
select throws_ok($$ select id from public.audit_log $$, '42501', null, 'A cannot read the audit log');
select is(
  (public.my_order_contact(current_setting('test.order_id')::uuid) ->> 'phone'),
  '+251911223344', 'A can read their own contact details via my_order_contact');

-- ---------- Customer B ----------
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000b","role":"authenticated"}', true);
set local role authenticated;

select is_empty($$ select id from public.orders $$, 'B cannot see A''s orders');
select is_empty($$ select id from public.order_items $$, 'B cannot see A''s order items');
select is_empty($$ select id from public.addresses where user_id <> auth.uid() $$,
  'B cannot see A''s addresses');
select throws_ok(
  format('select public.request_order_cancellation(%L)', current_setting('test.order_id')),
  'P0001', 'not_found', 'B cannot cancel A''s order');
select throws_ok(
  format('select public.my_order_contact(%L)', current_setting('test.order_id')),
  'P0001', 'not_found', 'B cannot read A''s contact details');

-- ---------- Staff of the OTHER restaurant (S2) ----------
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000d","role":"authenticated"}', true);
set local role authenticated;

select is_empty($$ select id from public.orders $$, 'S2 cannot see restaurant 1 orders');
select throws_ok(
  format('select public.staff_advance_order(%L)', current_setting('test.order_id')),
  'P0001', 'not_found', 'S2 cannot advance restaurant 1 orders');
select throws_ok(
  format('select public.staff_get_order_contact(%L)', current_setting('test.order_id')),
  'P0001', 'not_found', 'S2 cannot read restaurant 1 contact details');
select throws_ok(
  $$ update public.orders set restaurant_id = '22222222-2222-2222-2222-222222222222' $$,
  '42501', null, 'staff cannot update orders directly');

-- ---------- Staff of restaurant 1 (S1) ----------
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000c","role":"authenticated"}', true);
set local role authenticated;

select is((select count(*) from public.orders), 1::bigint, 'S1 sees their restaurant''s order');
select throws_ok($$ select delivery_phone from public.orders $$, '42501', null,
  'S1 cannot read phone numbers directly');
select throws_ok(
  format('select public.staff_get_order_contact(%L)', current_setting('test.order_id')),
  'P0001', 'contact_not_available', 'contact details are hidden until the order is confirmed');
select is(
  (public.staff_advance_order(current_setting('test.order_id')::uuid) ->> 'status'),
  'confirmed', 'S1 confirms the order');
select is(
  (public.staff_get_order_contact(current_setting('test.order_id')::uuid) ->> 'phone'),
  '+251911223344', 'S1 gets contact details once the order is confirmed');
select throws_ok($$ select id from public.audit_log $$, '42501', null,
  'S1 cannot read the audit log');

-- ---------- Cancellation request flow (order 1) ----------
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
set local role authenticated;

select is(
  (public.request_order_cancellation(current_setting('test.order_id')::uuid) -> 'cancellationRequest' ->> 'status'),
  'pending', 'A can request cancellation of a confirmed order');
select is(
  (select status::text from public.orders where id = current_setting('test.order_id')::uuid),
  'confirmed', 'the request does not change the order status');

reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000d","role":"authenticated"}', true);
set local role authenticated;
select throws_ok(
  format('select public.staff_decide_cancellation(%L, false, %L)', current_setting('test.order_id'), 'Nope'),
  'P0001', 'not_found', 'S2 cannot decide restaurant 1 requests');

reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000c","role":"authenticated"}', true);
set local role authenticated;
select throws_ok(
  format('select public.staff_decide_cancellation(%L, false, null)', current_setting('test.order_id')),
  'P0001', 'validation_failed', 'a decline needs a reason');
select is(
  (public.staff_decide_cancellation(current_setting('test.order_id')::uuid, false, 'Already cooking')
     -> 'cancellationRequest' ->> 'status'),
  'declined', 'S1 declines the request');
select is(
  (select status::text from public.orders where id = current_setting('test.order_id')::uuid),
  'confirmed', 'a declined request leaves the order status unchanged');

reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
set local role authenticated;
select throws_ok(
  format('select public.request_order_cancellation(%L)', current_setting('test.order_id')),
  'P0001', 'request_already_decided', 'A cannot ask again after a decline');

-- ---------- Second order: request accepted ----------
select lives_ok(
  $$ select set_config('test.order2_id',
       (public.place_order('00000000-0000-0000-0000-000000000004'::uuid,
         '[{"dishId":"d1d1d1d1-d1d1-d1d1-d1d1-d1d1d1d1d1d1","quantity":1}]'::jsonb,
         'a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1'::uuid, 'cash_on_delivery'::public.payment_method, null) ->> 'id'), true) $$,
  'A places a second order');
select is(
  (public.request_order_cancellation(current_setting('test.order2_id')::uuid) ->> 'status'),
  'cancelled', 'a placed order is cancelled instantly by the customer');

-- ---------- Triggers (as postgres) ----------
reset role;
select throws_ok(
  format('update public.orders set restaurant_id = %L where id = %L',
    '22222222-2222-2222-2222-222222222222', current_setting('test.order_id')),
  'P0001', 'order_field_immutable', 'restaurant_id can never be changed');
select throws_ok(
  format('update public.orders set total_santim = 1, subtotal_santim = 1 where id = %L', current_setting('test.order_id')),
  'P0001', 'order_field_immutable', 'prices and totals can never be changed');
select throws_ok(
  format('update public.orders set status = %L where id = %L', 'delivered', current_setting('test.order_id')),
  'P0001', 'invalid_transition', 'a confirmed order cannot jump to delivered');

select * from finish();
rollback;