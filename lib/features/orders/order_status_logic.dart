import '../../models/order.dart';

/// The happy path, in order. [OrderStatus.cancelled] is a side exit.
const List<OrderStatus> progression = [
  OrderStatus.placed,
  OrderStatus.confirmed,
  OrderStatus.preparing,
  OrderStatus.ready,
  OrderStatus.outForDelivery,
  OrderStatus.delivered,
];

/// Statuses in which a customer may ask the restaurant to cancel.
const List<OrderStatus> _requestable = [
  OrderStatus.confirmed,
  OrderStatus.preparing,
  OrderStatus.ready,
];

/// Reason recorded when the simulated restaurant declines.
const String simulatedDeclineReason =
    'The restaurant declined the request. (simulated)';

/// The next simulated status, or null if the order is delivered or cancelled.
OrderStatus? nextStatus(OrderStatus status) {
  final i = progression.indexOf(status);
  if (i < 0 || i >= progression.length - 1) return null;
  return progression[i + 1];
}

/// Direct cancellation is only possible before the restaurant accepts.
bool canCancel(OrderStatus status) => status == OrderStatus.placed;

/// A customer may request cancellation once, while the restaurant has
/// accepted the order but not yet sent it out.
bool canRequestCancellation(Order order) =>
    order.cancellationRequest == null && _requestable.contains(order.status);

/// Staff can accept a pending request only while the order has not left the
/// restaurant. After that, support handles it.
bool canAcceptCancellation(Order order) =>
    (order.cancellationRequest?.isPending ?? false) &&
    _requestable.contains(order.status);

/// Moves the order one step forward, or returns null if it cannot move. A
/// pending cancellation request stays pending.
Order? advanceOrder(Order order) {
  final next = nextStatus(order.status);
  return next == null ? null : order.copyWith(status: next);
}

/// Cancels a placed order, or returns null if its status does not allow it.
Order? cancelOrder(Order order) => canCancel(order.status)
    ? order.copyWith(status: OrderStatus.cancelled)
    : null;

/// Records a pending cancellation request. The status does not change.
Order? applyCancellationRequest(Order order, DateTime now) =>
    canRequestCancellation(order)
    ? order.copyWith(
        cancellationRequest: CancellationRequest(
          status: CancellationRequestStatus.pending,
          requestedAt: now,
        ),
      )
    : null;

/// Withdraws a pending request. Decided requests cannot be withdrawn.
Order? applyWithdrawal(Order order) =>
    (order.cancellationRequest?.isPending ?? false)
    ? order.copyWith(clearCancellationRequest: true)
    : null;

/// Applies the restaurant's decision. Accepting cancels the order; declining
/// keeps the status exactly as it was and needs a reason.
Order? applyDecision(
  Order order, {
  required bool accept,
  required DateTime now,
  String? reason,
}) {
  final request = order.cancellationRequest;
  if (request == null || !request.isPending) return null;
  if (accept) {
    if (!canAcceptCancellation(order)) return null;
    return order.copyWith(
      status: OrderStatus.cancelled,
      cancellationRequest: request.copyWith(
        status: CancellationRequestStatus.accepted,
        decidedAt: now,
      ),
    );
  }
  final why = (reason ?? '').trim();
  if (why.isEmpty) return null;
  return order.copyWith(
    cancellationRequest: request.copyWith(
      status: CancellationRequestStatus.declined,
      decidedAt: now,
      decisionReason: why,
    ),
  );
}

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
