import '../../models/order.dart';

/// The happy path, in order. [OrderStatus.cancelled] is a side exit.
const List<OrderStatus> progression = [
  OrderStatus.placed,
  OrderStatus.confirmed,
  OrderStatus.preparing,
  OrderStatus.outForDelivery,
  OrderStatus.delivered,
];

/// The next simulated status, or null if the order is delivered or cancelled.
OrderStatus? nextStatus(OrderStatus status) {
  final i = progression.indexOf(status);
  if (i < 0 || i >= progression.length - 1) return null;
  return progression[i + 1];
}

/// An order can be cancelled only before the restaurant starts preparing it.
bool canCancel(OrderStatus status) =>
    status == OrderStatus.placed || status == OrderStatus.confirmed;

/// Moves the order one step forward, or returns null if it cannot move.
Order? advanceOrder(Order order) {
  final next = nextStatus(order.status);
  return next == null ? null : order.copyWith(status: next);
}

/// Cancels the order, or returns null if its status does not allow it.
Order? cancelOrder(Order order) => canCancel(order.status)
    ? order.copyWith(status: OrderStatus.cancelled)
    : null;

/// Estimated delivery window: order time plus the saved ETA. Null if the
/// order has no saved estimate. This is a sample estimate, not a promise.
({DateTime from, DateTime to})? estimatedWindow(Order order) {
  final min = order.etaMinMinutes;
  final max = order.etaMaxMinutes;
  if (min == null || max == null) return null;
  return (
    from: order.createdAt.add(Duration(minutes: min)),
    to: order.createdAt.add(Duration(minutes: max)),
  );
}
