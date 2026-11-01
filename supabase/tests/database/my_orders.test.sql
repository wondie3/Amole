begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
grant usage on schema extensions to anon, authenticated;
grant execute on all functions in schema extensions to anon, authenticated;
select * from no_plan();

insert into auth.users (id, aud, role, email) values
  ('00000000-0000-0000-0000-00000000000a', 'authenticated', 'authenticated', 'a@test.local'),
  ('00000000-0000-0000-0000-00000000000b', 'authenticated', 'authenticated', 'b@test.local');
insert into public.restaurants (id, name, cuisine, rating, eta_min_minutes, eta_max_minutes, delivery_fee_santim) values
  ('11111111-1111-1111-1111-111111111111', 'Test Grill', 'Grill', 4.0, 20, 30, 4500);
insert into public.dishes (id, restaurant_id, category, name, price_santim) values
  ('d1d1d1d1-d1d1-d1d1-d1d1-d1d1d1d1d1d1', '11111111-1111-1111-1111-111111111111', 'grill', 'Tibs', 32000);
insert into public.addresses (id, user_id, label, contact_name, phone, sub_city, street) values
  ('a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1', '00000000-0000-0000-0000-00000000000a', 'Home', 'Abebe Kebede', '+251911223344', 'Bole', 'Near Edna Mall');

-- Customer A places two orders.
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
set local role authenticated;
select lives_ok($$ select set_config('test.o1',
  (public.place_order('10000000-0000-0000-0000-000000000001'::uuid,
    '[{"dishId":"d1d1d1d1-d1d1-d1d1-d1d1-d1d1d1d1d1d1","quantity":1}]'::jsonb,
    'a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1'::uuid, 'cash_on_delivery'::public.payment_method, null) ->> 'id'), true) $$,
  'A places order 1');
select lives_ok($$ select set_config('test.o2',
  (public.place_order('10000000-0000-0000-0000-000000000002'::uuid,
    '[{"dishId":"d1d1d1d1-d1d1-d1d1-d1d1-d1d1d1d1d1d1","quantity":2}]'::jsonb,
    'a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1'::uuid, 'cash_on_delivery'::public.payment_method, null) ->> 'id'), true) $$,
  'A places order 2');

-- Inside one transaction both orders share a timestamp, so move order 1 back
-- an hour (the guard trigger is switched off only for this setup).
reset role;
alter table public.orders disable trigger orders_guard;
update public.orders set created_at = now() - interval '1 hour'
 where id = current_setting('test.o1')::uuid;
alter table public.orders enable trigger orders_guard;

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
set local role authenticated;
select is(jsonb_array_length(public.my_orders()), 2, 'A gets both of their orders');
select is((public.my_orders() -> 0 ->> 'id'), current_setting('test.o2'), 'newest order first');
select is((public.my_orders() -> 0 ->> 'restaurantName'), 'Test Grill', 'the restaurant name is included');
select is((public.my_orders() -> 0 ->> 'subCity'), 'Bole', 'the sub-city is included');
select is((public.my_orders() -> 0 ->> 'deliveryFeeSantim')::int, 4500, 'the server delivery fee is included');

-- Customer B sees nothing of A's.
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000b","role":"authenticated"}', true);
set local role authenticated;
select is(jsonb_array_length(public.my_orders()), 0, 'B gets none of A''s orders');

-- Anonymous cannot call it.
reset role;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select throws_ok($$ select public.my_orders() $$, '42501', null, 'anon cannot call my_orders');

select * from finish();
rollback;