-- Amole server functions. DRAFT: never run until reviewed. Apply after
-- policies.sql. Every write to orders, requests and the audit log happens
-- here. Error codes are the exception MESSAGE (for example 'not_found'); the
-- API layer maps them to the HTTP errors in docs/api. Not yet tested.
--
-- SECURITY DEFINER functions bypass RLS. Each one therefore: fixes
-- search_path, schema-qualifies every name, and checks auth.uid() itself.

-- Functions are executable by PUBLIC (and Supabase default privileges) unless
-- revoked. Revoke everything, then grant only what clients need, at the end.
revoke execute on all functions in schema public from public, anon, authenticated;
alter default privileges in schema public revoke execute on functions from public, anon, authenticated;

-- ---------- Triggers ----------

-- New auth user -> profile row. Needs a trigger on auth.users, which may
-- require running this statement as the project owner (check current docs).
create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_name text := nullif(btrim(new.raw_user_meta_data ->> 'name'), '');
begin
  if v_name is not null and char_length(v_name) not between 2 and 60 then
    v_name := null;  -- never let a bad name block sign-up
  end if;
  insert into public.profiles (id, name) values (new.id, v_name)
  on conflict (id) do nothing;
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Account deletion: scrub personal contact data from the customer's orders
-- (the orders themselves stay, anonymized, via on delete set null).
create function public.scrub_deleted_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  update public.orders
     set delivery_name = null, delivery_phone = null,
         delivery_street = null, delivery_landmark = null
   where user_id = old.id;
  return old;
end $$;
create trigger on_auth_user_deleted before delete on auth.users
  for each row execute function public.scrub_deleted_user();

-- Defence in depth: whatever calls UPDATE on orders, these fields cannot
-- change, and status may only follow the allowed transitions.
create function public.orders_guard() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.restaurant_id is distinct from old.restaurant_id
     or new.subtotal_santim is distinct from old.subtotal_santim
     or new.delivery_fee_santim is distinct from old.delivery_fee_santim
     or new.total_santim is distinct from old.total_santim
     or new.payment_method is distinct from old.payment_method
     or new.idempotency_key is distinct from old.idempotency_key
     or new.created_at is distinct from old.created_at then
    raise exception 'order_field_immutable';
  end if;
  -- user_id may only become null (account deleted).
  if new.user_id is distinct from old.user_id and new.user_id is not null then
    raise exception 'order_field_immutable';
  end if;
  if new.status is distinct from old.status and not (
       (old.status, new.status) in (
         ('awaiting_payment', 'placed'), ('awaiting_payment', 'cancelled'),
         ('placed', 'confirmed'), ('placed', 'cancelled'),
         ('confirmed', 'preparing'), ('confirmed', 'cancelled'),
         ('preparing', 'ready'), ('preparing', 'cancelled'),
         ('ready', 'out_for_delivery'), ('ready', 'cancelled'),
         ('out_for_delivery', 'delivered'), ('out_for_delivery', 'cancelled'))
     ) then
    raise exception 'invalid_transition';
  end if;
  return new;
end $$;
create trigger orders_guard before update on public.orders
  for each row execute function public.orders_guard();

-- ---------- Internal helper (not executable by clients) ----------

-- Returns an order as JSON WITHOUT checking ownership. Only call it from the
-- functions below, after they have authorized the caller.
create function public.order_json(p_order_id uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', o.id, 'status', o.status, 'createdAt', o.created_at,
    'restaurantId', o.restaurant_id,
    'subtotalSantim', o.subtotal_santim,
    'deliveryFeeSantim', o.delivery_fee_santim,
    'totalSantim', o.total_santim,
    'estimatedDeliveryFrom', o.eta_from, 'estimatedDeliveryTo', o.eta_to,
    'payment', jsonb_build_object('method', o.payment_method, 'status', o.payment_status),
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
        'dishId', i.dish_id, 'name', i.name, 'quantity', i.quantity,
        'unitPriceSantim', i.unit_price_santim, 'spice', i.spice) order by i.id)
      from public.order_items i where i.order_id = o.id), '[]'::jsonb),
    'cancellationRequest', (
      select jsonb_build_object(
        'status', r.status, 'requestedAt', r.requested_at,
        'decidedAt', r.decided_at, 'decisionReason', r.decision_reason,
        'escalatedAt', r.escalated_at)
      from public.cancellation_requests r where r.order_id = o.id)
  )
  from public.orders o where o.id = p_order_id;
$$;

-- ---------- Customer functions ----------

create function public.select_address(p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'unauthenticated'; end if;
  if not exists (select 1 from public.addresses where id = p_id and user_id = v_uid) then
    raise exception 'not_found';
  end if;
  -- Two statements, because the partial unique index is checked per row.
  update public.addresses set is_selected = false
   where user_id = v_uid and is_selected;
  update public.addresses set is_selected = true
   where id = p_id and user_id = v_uid;
end $$;

-- Prices, fees and totals come only from the database. The client sends dish
-- ids, quantities and an optional expected total, which is a check, never an
-- input to the price. Only cash on delivery works until a payment provider
-- exists.
create function public.place_order(
  p_idempotency_key uuid,
  p_lines jsonb,
  p_address_id uuid,
  p_payment_method public.payment_method,
  p_expected_total_santim int default null
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_existing uuid;
  v_addr public.addresses;
  v_rest public.restaurants;
  v_rest_id uuid;
  v_dish public.dishes;
  v_line jsonb;
  v_qty int;
  v_spice text;
  v_subtotal int := 0;
  v_total int;
  v_order_id uuid;
begin
  if v_uid is null then raise exception 'unauthenticated'; end if;
  if p_idempotency_key is null then raise exception 'validation_failed'; end if;

  -- Replay of an earlier request: return the original order, create nothing.
  select id into v_existing from public.orders
   where user_id = v_uid and idempotency_key = p_idempotency_key;
  if found then return public.order_json(v_existing); end if;

  if p_lines is null or jsonb_typeof(p_lines) <> 'array'
     or jsonb_array_length(p_lines) not between 1 and 30 then
    raise exception 'validation_failed' using detail = 'lines';
  end if;
  if p_payment_method <> 'cash_on_delivery' then
    raise exception 'payment_not_available';
  end if;

  select * into v_addr from public.addresses
   where id = p_address_id and user_id = v_uid;
  if not found then raise exception 'address_not_found'; end if;

  -- Pass 1: validate every line and sum prices from the dishes table.
  for v_line in select * from jsonb_array_elements(p_lines) loop
    v_qty := (v_line ->> 'quantity')::int;
    v_spice := v_line ->> 'spice';
    if v_qty is null or v_qty not between 1 and 20 then
      raise exception 'validation_failed' using detail = 'quantity';
    end if;
    if v_spice is not null and v_spice not in ('mild', 'medium', 'spicy') then
      raise exception 'validation_failed' using detail = 'spice';
    end if;
    select * into v_dish from public.dishes
     where id = (v_line ->> 'dishId')::uuid for share;
    if not found or not v_dish.available then
      raise exception 'cart_invalid' using detail = 'unavailable';
    end if;
    if v_spice is not null and not v_dish.has_spice_options then
      raise exception 'validation_failed' using detail = 'spice';
    end if;
    if v_rest_id is null then
      v_rest_id := v_dish.restaurant_id;
    elsif v_rest_id <> v_dish.restaurant_id then
      raise exception 'cart_invalid' using detail = 'mixed_restaurants';
    end if;
    v_subtotal := v_subtotal + v_dish.price_santim * v_qty;
  end loop;

  select * into v_rest from public.restaurants where id = v_rest_id for share;
  if not v_rest.is_open then raise exception 'restaurant_closed'; end if;

  v_total := v_subtotal + v_rest.delivery_fee_santim;
  if p_expected_total_santim is not null and p_expected_total_santim <> v_total then
    raise exception 'cart_invalid'
      using detail = format('total_changed:%s', v_total);
  end if;

  begin
    insert into public.orders (
      user_id, restaurant_id, status, subtotal_santim, delivery_fee_santim,
      total_santim, delivery_name, delivery_phone, delivery_sub_city,
      delivery_street, delivery_landmark, fulfillment, payment_method,
      eta_from, eta_to, idempotency_key
    ) values (
      v_uid, v_rest_id, 'placed', v_subtotal, v_rest.delivery_fee_santim,
      v_total, v_addr.contact_name, v_addr.phone, v_addr.sub_city,
      v_addr.street, v_addr.landmark, 'delivery', p_payment_method,
      now() + make_interval(mins => v_rest.eta_min_minutes),
      now() + make_interval(mins => v_rest.eta_max_minutes),
      p_idempotency_key
    ) returning id into v_order_id;
  exception when unique_violation then
    -- Two identical requests raced; return the winner.
    select id into v_order_id from public.orders
     where user_id = v_uid and idempotency_key = p_idempotency_key;
    return public.order_json(v_order_id);
  end;

  -- Pass 2: copy the items, with name and price as of now.
  for v_line in select * from jsonb_array_elements(p_lines) loop
    select * into v_dish from public.dishes where id = (v_line ->> 'dishId')::uuid;
    insert into public.order_items (order_id, dish_id, name, unit_price_santim, quantity, spice)
    values (v_order_id, v_dish.id, v_dish.name, v_dish.price_santim,
            (v_line ->> 'quantity')::int, v_line ->> 'spice');
  end loop;

  insert into public.audit_log (order_id, actor_id, actor_role, action, to_status)
  values (v_order_id, v_uid, 'customer', 'order_placed', 'placed');

  return public.order_json(v_order_id);
end $$;

-- placed: cancels at once. confirmed/preparing/ready: records a request and
-- changes nothing else. Later statuses: not cancellable (support handles it).
create function public.request_order_cancellation(p_order_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_order public.orders;
  v_req public.cancellation_status;
begin
  if v_uid is null then raise exception 'unauthenticated'; end if;
  select * into v_order from public.orders
   where id = p_order_id and user_id = v_uid for update;
  if not found then raise exception 'not_found'; end if;

  if v_order.status = 'placed' then
    if v_order.payment_status = 'paid' then raise exception 'refund_required'; end if;
    update public.orders set status = 'cancelled' where id = v_order.id;
    insert into public.audit_log (order_id, actor_id, actor_role, action, from_status, to_status)
    values (v_order.id, v_uid, 'customer', 'order_cancelled', 'placed', 'cancelled');
  elsif v_order.status in ('confirmed', 'preparing', 'ready') then
    select status into v_req from public.cancellation_requests where order_id = v_order.id;
    if found then
      if v_req = 'pending' then return public.order_json(v_order.id); end if;
      raise exception 'request_already_decided';
    end if;
    insert into public.cancellation_requests (order_id) values (v_order.id);
    insert into public.audit_log (order_id, actor_id, actor_role, action, from_status)
    values (v_order.id, v_uid, 'customer', 'cancellation_requested', v_order.status);
  else
    raise exception 'not_cancellable';
  end if;
  return public.order_json(v_order.id);
end $$;

create function public.withdraw_order_cancellation(p_order_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_deleted int;
begin
  if v_uid is null then raise exception 'unauthenticated'; end if;
  delete from public.cancellation_requests r
   using public.orders o
   where r.order_id = o.id and o.id = p_order_id and o.user_id = v_uid
     and r.status = 'pending';
  get diagnostics v_deleted = row_count;
  if v_deleted = 0 then raise exception 'not_found'; end if;
  insert into public.audit_log (order_id, actor_id, actor_role, action)
  values (p_order_id, v_uid, 'customer', 'cancellation_withdrawn');
  return public.order_json(p_order_id);
end $$;

-- The customer's own delivery contact details (not readable by direct select).
create function public.my_order_contact(p_order_id uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v_o public.orders;
begin
  select * into v_o from public.orders
   where id = p_order_id and user_id = auth.uid();
  if not found then raise exception 'not_found'; end if;
  return jsonb_build_object('name', v_o.delivery_name, 'phone', v_o.delivery_phone,
    'subCity', v_o.delivery_sub_city, 'street', v_o.delivery_street,
    'landmark', v_o.delivery_landmark);
end $$;

-- ---------- Staff functions ----------
-- All of them answer 'not_found' for orders of other restaurants, so ids
-- cannot be probed.

create function public.staff_advance_order(p_order_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_order public.orders;
  v_next public.order_status;
begin
  if v_uid is null then raise exception 'unauthenticated'; end if;
  select * into v_order from public.orders where id = p_order_id for update;
  if not found or not public.is_staff_of(v_order.restaurant_id) then
    raise exception 'not_found';
  end if;
  v_next := case v_order.status
    when 'placed' then 'confirmed'::public.order_status
    when 'confirmed' then 'preparing'::public.order_status
    when 'preparing' then 'ready'::public.order_status
    else null end;
  if v_next is null then raise exception 'invalid_transition'; end if;
  update public.orders set status = v_next where id = v_order.id;
  insert into public.audit_log (order_id, actor_id, actor_role, action, from_status, to_status)
  values (v_order.id, v_uid, 'staff', 'status_changed', v_order.status, v_next);
  return public.order_json(v_order.id);
end $$;

-- The restaurant cancels on its own (reject a new order, or cannot fulfil).
create function public.staff_cancel_order(p_order_id uuid, p_reason text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_order public.orders;
  v_reason text := btrim(coalesce(p_reason, ''));
begin
  if v_uid is null then raise exception 'unauthenticated'; end if;
  if char_length(v_reason) not between 3 and 200 then
    raise exception 'validation_failed' using detail = 'reason';
  end if;
  select * into v_order from public.orders where id = p_order_id for update;
  if not found or not public.is_staff_of(v_order.restaurant_id) then
    raise exception 'not_found';
  end if;
  if v_order.status not in ('placed', 'confirmed', 'preparing', 'ready') then
    raise exception 'invalid_transition';
  end if;
  if v_order.payment_status = 'paid' then raise exception 'refund_required'; end if;
  update public.orders set status = 'cancelled' where id = v_order.id;
  update public.cancellation_requests
     set status = 'accepted', decided_at = now(), decided_by = v_uid
   where order_id = v_order.id and status = 'pending';
  insert into public.audit_log (order_id, actor_id, actor_role, action, from_status, to_status, detail)
  values (v_order.id, v_uid, 'staff', 'order_cancelled', v_order.status, 'cancelled',
          jsonb_build_object('reason', v_reason));
  return public.order_json(v_order.id);
end $$;

-- Accept or decline a customer's cancellation request. Declining leaves the
-- order's status exactly as it was.
create function public.staff_decide_cancellation(
  p_order_id uuid, p_accept boolean, p_reason text default null
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_order public.orders;
  v_req public.cancellation_requests;
  v_reason text := btrim(coalesce(p_reason, ''));
begin
  if v_uid is null then raise exception 'unauthenticated'; end if;
  if p_accept is null then raise exception 'validation_failed'; end if;
  select * into v_order from public.orders where id = p_order_id for update;
  if not found or not public.is_staff_of(v_order.restaurant_id) then
    raise exception 'not_found';
  end if;
  select * into v_req from public.cancellation_requests
   where order_id = v_order.id for update;
  if not found then raise exception 'not_found'; end if;
  if v_req.status <> 'pending' then raise exception 'conflict'; end if;

  if p_accept then
    if v_order.status not in ('confirmed', 'preparing', 'ready') then
      raise exception 'invalid_transition';  -- left the restaurant: support
    end if;
    if v_order.payment_status = 'paid' then raise exception 'refund_required'; end if;
    update public.orders set status = 'cancelled' where id = v_order.id;
    update public.cancellation_requests
       set status = 'accepted', decided_at = now(), decided_by = v_uid
     where order_id = v_order.id;
    insert into public.audit_log (order_id, actor_id, actor_role, action, from_status, to_status)
    values (v_order.id, v_uid, 'staff', 'cancellation_accepted', v_order.status, 'cancelled');
  else
    if char_length(v_reason) not between 3 and 200 then
      raise exception 'validation_failed' using detail = 'reason';
    end if;
    update public.cancellation_requests
       set status = 'declined', decided_at = now(), decided_by = v_uid,
           decision_reason = v_reason
     where order_id = v_order.id;
    insert into public.audit_log (order_id, actor_id, actor_role, action, from_status, detail)
    values (v_order.id, v_uid, 'staff', 'cancellation_declined', v_order.status,
            jsonb_build_object('reason', v_reason));
  end if;
  return public.order_json(v_order.id);
end $$;

-- Phone, street and landmark for fulfilment. Only for active orders of the
-- caller's own restaurant, never street details for pickup, and every call is
-- written to the audit log.
create function public.staff_get_order_contact(p_order_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_o public.orders;
begin
  if v_uid is null then raise exception 'unauthenticated'; end if;
  select * into v_o from public.orders where id = p_order_id;
  if not found or not public.is_staff_of(v_o.restaurant_id) then
    raise exception 'not_found';
  end if;
  if v_o.status not in ('confirmed', 'preparing', 'ready', 'out_for_delivery') then
    raise exception 'contact_not_available';
  end if;
  insert into public.audit_log (order_id, actor_id, actor_role, action)
  values (v_o.id, v_uid, 'staff', 'contact_viewed');
  return jsonb_build_object(
    'name', v_o.delivery_name,
    'phone', v_o.delivery_phone,
    'subCity', v_o.delivery_sub_city,
    'street', case when v_o.fulfillment = 'delivery' then v_o.delivery_street end,
    'landmark', case when v_o.fulfillment = 'delivery' then v_o.delivery_landmark end);
end $$;

-- ---------- Scheduled job (service role / pg_cron only) ----------
-- Marks requests pending for over 5 minutes as escalated so support sees
-- them. It decides nothing. NOT granted to clients.
create function public.escalate_stale_cancellation_requests() returns int
language plpgsql security definer set search_path = '' as $$
declare v_n int;
begin
  update public.cancellation_requests set escalated_at = now()
   where status = 'pending' and escalated_at is null
     and requested_at < now() - interval '5 minutes';
  get diagnostics v_n = row_count;
  return v_n;
end $$;

-- ---------- Grants ----------
-- RLS policies call is_staff_of as the signed-in user, so it needs execute.
grant execute on function public.is_staff_of(uuid) to authenticated;

grant execute on function public.select_address(uuid) to authenticated;
grant execute on function public.place_order(uuid, jsonb, uuid, public.payment_method, int) to authenticated;
grant execute on function public.request_order_cancellation(uuid) to authenticated;
grant execute on function public.withdraw_order_cancellation(uuid) to authenticated;
grant execute on function public.my_order_contact(uuid) to authenticated;

-- Staff functions are executable by any signed-in user but answer
-- 'not_found' unless the caller is staff of that order's restaurant.
grant execute on function public.staff_advance_order(uuid) to authenticated;
grant execute on function public.staff_cancel_order(uuid, text) to authenticated;
grant execute on function public.staff_decide_cancellation(uuid, boolean, text) to authenticated;
grant execute on function public.staff_get_order_contact(uuid) to authenticated;

-- Not granted to any client role: order_json, handle_new_user,
-- scrub_deleted_user, orders_guard, escalate_stale_cancellation_requests.
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