-- Function grants (authoritative). Runs AFTER every function exists, so it
-- covers all of them. Postgres gives new functions EXECUTE to PUBLIC by
-- default; that default cannot be removed with "in schema" alone.
revoke execute on all functions in schema public from public, anon, authenticated;

grant execute on function public.is_staff_of(uuid) to authenticated;
grant execute on function public.select_address(uuid) to authenticated;
grant execute on function public.place_order(uuid, jsonb, uuid, public.payment_method, int) to authenticated;
grant execute on function public.request_order_cancellation(uuid) to authenticated;
grant execute on function public.withdraw_order_cancellation(uuid) to authenticated;
grant execute on function public.my_order_contact(uuid) to authenticated;
grant execute on function public.staff_advance_order(uuid) to authenticated;
grant execute on function public.staff_cancel_order(uuid, text) to authenticated;
grant execute on function public.staff_decide_cancellation(uuid, boolean, text) to authenticated;
grant execute on function public.staff_get_order_contact(uuid) to authenticated;

-- Future functions created by this role: no PUBLIC execute, and none for
-- anon/authenticated unless granted explicitly.
alter default privileges for role postgres revoke execute on functions from public;
alter default privileges for role postgres in schema public revoke execute on functions from public, anon, authenticated;