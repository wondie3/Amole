begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select * from no_plan();

select set_eq(
  $$ select p.proname::text from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and has_function_privilege('authenticated', p.oid, 'execute') $$,
  $$ values ('is_staff_of'), ('select_address'), ('place_order'),
            ('request_order_cancellation'), ('withdraw_order_cancellation'),
            ('my_order_contact'), ('staff_advance_order'), ('staff_cancel_order'),
            ('staff_decide_cancellation'), ('staff_get_order_contact') $$,
  'authenticated can execute exactly the 10 intended functions'
);

select is_empty(
  $$ select p.proname from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and has_function_privilege('anon', p.oid, 'execute') $$,
  'anon can execute no public function'
);

select is_empty(
  $$ select c.relname from pg_class c
     where c.relnamespace = 'public'::regnamespace
       and c.relkind = 'r' and not c.relrowsecurity $$,
  'every public table has row level security enabled'
);

select ok(not has_table_privilege('anon', 'public.orders', 'select'),
  'anon cannot select orders');
select ok(not has_table_privilege('authenticated', 'public.orders', 'insert'),
  'authenticated cannot insert orders');
select ok(not has_table_privilege('authenticated', 'public.orders', 'update'),
  'authenticated cannot update orders');
select ok(not has_table_privilege('authenticated', 'public.audit_log', 'select'),
  'authenticated cannot read the audit log');
select ok(not has_column_privilege('authenticated', 'public.orders', 'delivery_phone', 'select'),
  'authenticated cannot select delivery_phone directly');
select ok(not has_column_privilege('authenticated', 'public.orders', 'delivery_street', 'select'),
  'authenticated cannot select delivery_street directly');

select * from finish();
rollback;