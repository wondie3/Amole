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

insert into public.dishes (id, restaurant_id, category, name, price_santim) values
  ('d1d1d1d1-d1d1-d1d1-d1d1-d1d1d1d1d1d1', '11111111-1111-1111-1111-111111111111', 'grill', 'Tibs', 32000);

insert into public.staff_memberships (user_id, restaurant_id) values
  ('00000000-0000-0000-0000-00000000000c', '11111111-1111-1111-1111-111111111111'),
  ('00000000-0000-0000-0000-00000000000d', '22222222-2222-2222-2222-222222222222');

insert into public.addresses (id, user_id, label, contact_name, phone, sub_city, street) values
  ('a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1', '00000000-0000-0000-0000-00000000000a', 'Home', 'Abebe Kebede', '+251911223344', 'Bole', 'Near Edna Mall'),
  ('a2a2a2a2-a2a2-a2a2-a2a2-a2a2a2a2a2a2', '00000000-0000-0000-0000-00000000000a', 'Work', 'Abebe Kebede', '+251911223344', 'Kirkos', 'Second street'),
  ('b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1', '00000000-0000-0000-0000-00000000000b', 'Home', 'Bekele Girma', '+251922334455', 'Kirkos', 'Near Meskel Square');

-- ---------- handle_new_user ----------
insert into auth.users (id, aud, role, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000e1', 'authenticated', 'authenticated', 'n1@test.local', '{"name":"Abebe Kebede"}'::jsonb),
  ('00000000-0000-0000-0000-0000000000e2', 'authenticated', 'authenticated', 'n2@test.local', '{"name":"x"}'::jsonb),
  ('00000000-0000-0000-0000-0000000000e3', 'authenticated', 'authenticated', 'n3@test.local', '{}'::jsonb);

select is((select name from public.profiles where id = '00000000-0000-0000-0000-0000000000e1'),
  'Abebe Kebede', 'a profile is created with the sign-up name');
select is((select count(*) from public.profiles
  where id in ('00000000-0000-0000-0000-0000000000e2', '00000000-0000-0000-0000-0000000000e3')),
  2::bigint, 'a bad or missing name never blocks the profile');
select is_empty($$ select 1 from public.profiles
  where id in ('00000000-0000-0000-0000-0000000000e2', '00000000-0000-0000-0000-0000000000e3')
    and name is not null $$, 'a too-short or missing name is stored as null');

-- ---------- select_address ----------
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
set local role authenticated;

select lives_ok($$ select public.select_address('a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1'::uuid) $$,
  'A selects the first address');
select is((select id::text from public.addresses where is_selected),
  'a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1', 'the first address is selected');
select lives_ok($$ select public.select_address('a2a2a2a2-a2a2-a2a2-a2a2-a2a2a2a2a2a2'::uuid) $$,
  'A switches to the second address');
select is((select count(*) from public.addresses where is_selected), 1::bigint,
  'exactly one address is selected after switching');
select is((select id::text from public.addresses where is_selected),
  'a2a2a2a2-a2a2-a2a2-a2a2-a2a2a2a2a2a2', 'the second address is now selected');
select throws_ok($$ select public.select_address('00000000-0000-0000-0000-00000000dead'::uuid) $$,
  'P0001', 'not_found', 'an unknown address id is not found');

reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000b","role":"authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.select_address('a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1'::uuid) $$,
  'P0001', 'not_found', 'B cannot select A''s address');

-- ---------- address limit (as postgres) ----------
reset role;
select lives_ok($$ insert into public.addresses (user_id, label, contact_name, phone, sub_city, street)
  select '00000000-0000-0000-0000-00000000000d', 'L' || g, 'Test Person', '+251911223344', 'Bole', 'Some street'
  from generate_series(1, 10) g $$, '10 addresses are allowed');
select throws_ok($$ insert into public.addresses (user_id, label, contact_name, phone, sub_city, street)
  values ('00000000-0000-0000-0000-00000000000d', 'L11', 'Test Person', '+251911223344', 'Bole', 'Some street') $$,
  '23514', 'address_limit_reached', 'the 11th address is refused');

-- ---------- staff_cancel_order ----------
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
set local role authenticated;

select lives_ok($$ select set_config('test.o1',
  (public.place_order('10000000-0000-0000-0000-000000000001'::uuid,
    '[{"dishId":"d1d1d1d1-d1d1-d1d1-d1d1-d1d1d1d1d1d1","quantity":1}]'::jsonb,
    'a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1'::uuid, 'cash_on_delivery'::public.payment_method, null) ->> 'id'), true) $$,
  'A places order 1');

reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000d","role":"authenticated"}', true);
set local role authenticated;
select throws_ok(format('select public.staff_cancel_order(%L, %L)', current_setting('test.o1'), 'Out of stock'),
  'P0001', 'not_found', 'S2 cannot cancel restaurant 1 orders');

reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000c","role":"authenticated"}', true);
set local role authenticated;
select throws_ok(format('select public.staff_cancel_order(%L, %L)', current_setting('test.o1'), 'no'),
  'P0001', 'validation_failed', 'a too-short reason is refused');
select is((public.staff_cancel_order(current_setting('test.o1')::uuid, 'Out of stock') ->> 'status'),
  'cancelled', 'S1 cancels a placed order with a reason');
select throws_ok(format('select public.staff_cancel_order(%L, %L)', current_setting('test.o1'), 'Out of stock'),
  'P0001', 'invalid_transition', 'a cancelled order cannot be cancelled again');

-- Accepting a pending customer request by cancelling
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
set local role authenticated;
select lives_ok($$ select set_config('test.o2',
  (public.place_order('10000000-0000-0000-0000-000000000002'::uuid,
    '[{"dishId":"d1d1d1d1-d1d1-d1d1-d1d1-d1d1d1d1d1d1","quantity":1}]'::jsonb,
    'a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1'::uuid, 'cash_on_delivery'::public.payment_method, null) ->> 'id'), true) $$,
  'A places order 2');

reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000c","role":"authenticated"}', true);
set local role authenticated;
select is((public.staff_advance_order(current_setting('test.o2')::uuid) ->> 'status'), 'confirmed',
  'S1 confirms order 2');

reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
set local role authenticated;
select is((public.request_order_cancellation(current_setting('test.o2')::uuid) -> 'cancellationRequest' ->> 'status'),
  'pending', 'A requests cancellation of order 2');

reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000c","role":"authenticated"}', true);
set local role authenticated;
select is((public.staff_cancel_order(current_setting('test.o2')::uuid, 'Kitchen closed') -> 'cancellationRequest' ->> 'status'),
  'accepted', 'cancelling by staff accepts the pending request');

-- Paid orders cannot be cancelled until refunds exist
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
set local role authenticated;
select lives_ok($$ select set_config('test.o3',
  (public.place_order('10000000-0000-0000-0000-000000000003'::uuid,
    '[{"dishId":"d1d1d1d1-d1d1-d1d1-d1d1-d1d1d1d1d1d1","quantity":1}]'::jsonb,
    'a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1'::uuid, 'cash_on_delivery'::public.payment_method, null) ->> 'id'), true) $$,
  'A places order 3');

reset role;
update public.orders set payment_status = 'paid' where id = current_setting('test.o3')::uuid;

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
set local role authenticated;
select throws_ok(format('select public.request_order_cancellation(%L)', current_setting('test.o3')),
  'P0001', 'refund_required', 'a paid order cannot be cancelled by the customer yet');

reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000c","role":"authenticated"}', true);
set local role authenticated;
select throws_ok(format('select public.staff_cancel_order(%L, %L)', current_setting('test.o3'), 'Out of stock'),
  'P0001', 'refund_required', 'a paid order cannot be cancelled by staff yet');

reset role;
select is((select count(*) from public.audit_log
  where order_id = current_setting('test.o1')::uuid and action = 'order_cancelled'),
  1::bigint, 'the staff cancellation was written to the audit log');

-- ---------- escalate_stale_cancellation_requests (as postgres) ----------
insert into public.orders (id, user_id, restaurant_id, status, subtotal_santim, delivery_fee_santim,
  total_santim, delivery_sub_city, payment_method, idempotency_key) values
  ('e1e1e1e1-e1e1-e1e1-e1e1-e1e1e1e1e1e1', '00000000-0000-0000-0000-00000000000a',
   '11111111-1111-1111-1111-111111111111', 'confirmed', 1000, 500, 1500, 'Bole', 'cash_on_delivery', gen_random_uuid()),
  ('e2e2e2e2-e2e2-e2e2-e2e2-e2e2e2e2e2e2', '00000000-0000-0000-0000-00000000000a',
   '11111111-1111-1111-1111-111111111111', 'confirmed', 1000, 500, 1500, 'Bole', 'cash_on_delivery', gen_random_uuid());
insert into public.cancellation_requests (order_id, requested_at) values
  ('e1e1e1e1-e1e1-e1e1-e1e1-e1e1e1e1e1e1', now() - interval '10 minutes'),
  ('e2e2e2e2-e2e2-e2e2-e2e2-e2e2e2e2e2e2', now());

select is((select public.escalate_stale_cancellation_requests()), 1, 'one stale request is escalated');
select ok((select escalated_at is not null and status = 'pending' from public.cancellation_requests
  where order_id = 'e1e1e1e1-e1e1-e1e1-e1e1-e1e1e1e1e1e1'),
  'the stale request is flagged but still pending (nothing is decided)');
select ok((select escalated_at is null from public.cancellation_requests
  where order_id = 'e2e2e2e2-e2e2-e2e2-e2e2-e2e2e2e2e2e2'), 'a fresh request is left alone');
select is((select public.escalate_stale_cancellation_requests()), 0, 'a second run changes nothing');

-- ---------- Account deletion scrub ----------
insert into auth.users (id, aud, role, email) values
  ('00000000-0000-0000-0000-0000000000f9', 'authenticated', 'authenticated', 'gone@test.local');
insert into public.addresses (user_id, label, contact_name, phone, sub_city, street) values
  ('00000000-0000-0000-0000-0000000000f9', 'Home', 'Gone Person', '+251911223344', 'Bole', 'Gone street');
insert into public.orders (id, user_id, restaurant_id, status, subtotal_santim, delivery_fee_santim,
  total_santim, delivery_name, delivery_phone, delivery_sub_city, delivery_street, delivery_landmark,
  payment_method, idempotency_key) values
  ('f9f9f9f9-f9f9-f9f9-f9f9-f9f9f9f9f9f9', '00000000-0000-0000-0000-0000000000f9',
   '11111111-1111-1111-1111-111111111111', 'delivered', 1000, 500, 1500, 'Gone Person', '+251911223344',
   'Bole', 'Gone street', 'Blue gate', 'cash_on_delivery', gen_random_uuid());

delete from auth.users where id = '00000000-0000-0000-0000-0000000000f9';

select ok((select user_id is null from public.orders where id = 'f9f9f9f9-f9f9-f9f9-f9f9-f9f9f9f9f9f9'),
  'the order survives and is anonymized');
select ok((select delivery_name is null and delivery_phone is null and delivery_street is null
    and delivery_landmark is null from public.orders where id = 'f9f9f9f9-f9f9-f9f9-f9f9-f9f9f9f9f9f9'),
  'name, phone, street and landmark are scrubbed');
select is((select delivery_sub_city from public.orders where id = 'f9f9f9f9-f9f9-f9f9-f9f9-f9f9f9f9f9f9'),
  'Bole', 'the sub-city is kept');
select is_empty($$ select 1 from public.profiles where id = '00000000-0000-0000-0000-0000000000f9' $$,
  'the profile is deleted');
select is_empty($$ select 1 from public.addresses where user_id = '00000000-0000-0000-0000-0000000000f9' $$,
  'saved addresses are deleted');

select * from finish();
rollback;