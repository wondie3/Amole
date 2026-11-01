-- order_json gains the restaurant name, sub-city and fulfillment. CREATE OR
-- REPLACE keeps the existing (restricted) grants: clients still cannot call it.
create or replace function public.order_json(p_order_id uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', o.id, 'status', o.status, 'createdAt', o.created_at,
    'restaurantId', o.restaurant_id,
    'restaurantName', (select r.name from public.restaurants r where r.id = o.restaurant_id),
    'subCity', o.delivery_sub_city,
    'fulfillment', o.fulfillment,
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

-- The signed-in customer's own orders, newest first, at most 50.
create function public.my_orders() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'unauthenticated'; end if;
  return coalesce((
    select jsonb_agg(public.order_json(o.id) order by o.created_at desc)
    from (
      select id, created_at from public.orders
       where user_id = v_uid order by created_at desc limit 50
    ) o
  ), '[]'::jsonb);
end $$;

revoke all on function public.my_orders() from public, anon;
grant execute on function public.my_orders() to authenticated;