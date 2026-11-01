import '../../models/cart_line.dart';
import '../../models/dish.dart';
import '../../models/order.dart';

const String orderNetworkMessage =
    'Could not reach the server. Check your connection and try again.';
const String orderSignInAgainMessage =
    'Please sign in again to manage your orders.';
const String orderGenericMessage = 'Something went wrong. Please try again.';
const String orderNotFoundMessage = 'That order could not be found.';
const String orderNotCancellableMessage =
    'This order can no longer be cancelled in the app. Please contact support.';
const String orderRequestDecidedMessage =
    'Your cancellation request was already decided.';
const String orderRefundMessage =
    'This order was paid online. Refunds are not available yet, so it cannot '
    'be cancelled in the app.';

const String placeNetworkMessage =
    'Could not confirm your order. Check your connection and try again. If it '
    'already went through, trying again will not place it twice.';
const String placeEmptyCartMessage = 'Your cart is empty.';
const String placeMenuOfflineMessage =
    'The menu could not be loaded from the server, so this order cannot be '
    'placed right now. Try again when you are online.';
const String placeUnreadableMessage =
    'Your order was received, but its confirmation could not be read. Check '
    'your order history.';

/// A failure reported by the backend, reduced to a code and message.
class OrderSourceException implements Exception {
  const OrderSourceException({this.code, this.message, this.details});

  final String? code;
  final String? message;
  final String? details;

  @override
  String toString() => 'OrderSourceException(code: $code)';
}

/// Where account orders live. The real one calls Supabase functions; tests
/// use a fake. Results are the raw JSON the server returned.
abstract interface class RemoteOrdersSource {
  Future<List<dynamic>> fetchOrders();
  Future<Object?> placeOrder({
    required String idempotencyKey,
    required List<Map<String, Object?>> lines,
    required String addressId,
    required int expectedTotalSantim,
  });
  Future<Object?> requestCancellation(String orderId);
  Future<Object?> withdrawCancellation(String orderId);
}

sealed class PlaceOrderResult {
  const PlaceOrderResult();
}

class PlaceOrderOk extends PlaceOrderResult {
  const PlaceOrderOk(this.order);

  final Order order;
}

/// The server's total differs from what the customer saw. Nothing was placed.
class PlaceOrderTotalChanged extends PlaceOrderResult {
  const PlaceOrderTotalChanged(this.newTotalSantim);

  final int newTotalSantim;
}

class PlaceOrderFailed extends PlaceOrderResult {
  const PlaceOrderFailed(this.message);

  final String message;
}

/// A message that is safe to show for cancellation actions. Never includes
/// server details.
String friendlyOrderError(Object error) {
  if (error is! OrderSourceException) return orderNetworkMessage;
  final text = (error.message ?? '').toLowerCase();
  if (text.contains('not_cancellable')) return orderNotCancellableMessage;
  if (text.contains('request_already_decided')) {
    return orderRequestDecidedMessage;
  }
  if (text.contains('refund_required')) return orderRefundMessage;
  if (text.contains('not_found')) return orderNotFoundMessage;
  if (text.contains('unauthenticated')) return orderSignInAgainMessage;
  switch (error.code) {
    case '42501':
    case 'PGRST301':
      return orderSignInAgainMessage;
  }
  return orderGenericMessage;
}

/// Turns an error from place_order into a result the screen can act on.
PlaceOrderResult placeOrderErrorToResult(Object error) {
  if (error is! OrderSourceException) {
    return const PlaceOrderFailed(placeNetworkMessage);
  }
  final text = (error.message ?? '').toLowerCase();
  final detail = error.details ?? '';
  if (text.contains('cart_invalid')) {
    const prefix = 'total_changed:';
    if (detail.startsWith(prefix)) {
      final total = int.tryParse(detail.substring(prefix.length));
      if (total != null) return PlaceOrderTotalChanged(total);
    }
    if (detail.contains('mixed')) {
      return const PlaceOrderFailed(
        'Your cart has dishes from more than one restaurant.',
      );
    }
    return const PlaceOrderFailed(
      'Some dishes are no longer available. Update your cart and try again.',
    );
  }
  if (text.contains('restaurant_closed')) {
    return const PlaceOrderFailed('This restaurant is closed right now.');
  }
  if (text.contains('address_not_found')) {
    return const PlaceOrderFailed(
      'Your delivery address could not be found. Choose another one.',
    );
  }
  if (text.contains('payment_not_available')) {
    return const PlaceOrderFailed('That payment method is not available yet.');
  }
  if (text.contains('validation_failed')) {
    return const PlaceOrderFailed(
      'Some order details were rejected. Check your cart and try again.',
    );
  }
  if (text.contains('unauthenticated') ||
      error.code == '42501' ||
      error.code == 'PGRST301') {
    return const PlaceOrderFailed(orderSignInAgainMessage);
  }
  return const PlaceOrderFailed(orderGenericMessage);
}

OrderStatus? _status(Object? v) => switch (v) {
  'placed' => OrderStatus.placed,
  'confirmed' => OrderStatus.confirmed,
  'preparing' => OrderStatus.preparing,
  'ready' => OrderStatus.ready,
  'out_for_delivery' => OrderStatus.outForDelivery,
  'delivered' => OrderStatus.delivered,
  'cancelled' => OrderStatus.cancelled,
  _ => null,
};

PaymentMethod? _payment(Object? v) => switch (v) {
  'cash_on_delivery' => PaymentMethod.cashOnDelivery,
  'telebirr' => PaymentMethod.telebirr,
  'cbe_birr' => PaymentMethod.cbeBirr,
  _ => null,
};

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

String? _spiceLabel(Object? v) {
  if (v is! String) return null;
  return SpiceLevel.values.where((s) => s.name == v).firstOrNull?.label;
}

OrderItem? _item(Object? json) {
  if (json is! Map) return null;
  final name = json['name'];
  final qty = json['quantity'];
  final price = json['unitPriceSantim'];
  if (name is! String || qty is! int || qty < 1 || price is! int || price < 0) {
    return null;
  }
  final dishId = json['dishId'];
  return OrderItem(
    dishId: dishId is String ? dishId : '',
    name: name,
    unitPriceSantim: price,
    quantity: qty,
    spiceLabel: _spiceLabel(json['spice']),
  );
}

CancellationRequest? _request(Object? json) {
  if (json is! Map) return null;
  final status = CancellationRequestStatus.values
      .where((v) => v.name == json['status'])
      .firstOrNull;
  final requestedAt = _date(json['requestedAt']);
  if (status == null || requestedAt == null) return null;
  final reason = json['decisionReason'];
  return CancellationRequest(
    status: status,
    requestedAt: requestedAt,
    decidedAt: _date(json['decidedAt']),
    decisionReason: reason is String ? reason : null,
  );
}

(int, int)? _eta(DateTime createdAt, Object? from, Object? to) {
  final f = _date(from);
  final t = _date(to);
  if (f == null || t == null) return null;
  final lo = f.difference(createdAt).inMinutes;
  final hi = t.difference(createdAt).inMinutes;
  if (lo < 0 || hi < lo) return null;
  return (lo, hi);
}

/// Reads an order as the server's order_json returns it. Returns null if it
/// is not valid or has a status the app cannot show yet (for example
/// awaiting_payment). Contact details are never part of it.
Order? orderFromServerJson(Object? json) {
  if (json is! Map) return null;
  final id = json['id'];
  final restaurantId = json['restaurantId'];
  final fee = json['deliveryFeeSantim'];
  final createdAt = _date(json['createdAt']);
  final status = _status(json['status']);
  final payment = json['payment'];
  final method = payment is Map ? _payment(payment['method']) : null;
  final rawItems = json['items'];
  if (id is! String ||
      id.isEmpty ||
      restaurantId is! String ||
      fee is! int ||
      fee < 0 ||
      createdAt == null ||
      status == null ||
      method == null ||
      rawItems is! List ||
      rawItems.isEmpty) {
    return null;
  }
  final items = <OrderItem>[];
  for (final raw in rawItems) {
    final item = _item(raw);
    if (item == null) return null;
    items.add(item);
  }
  final name = json['restaurantName'];
  final subCity = json['subCity'];
  final eta = _eta(
    createdAt,
    json['estimatedDeliveryFrom'],
    json['estimatedDeliveryTo'],
  );
  return Order(
    id: id,
    createdAt: createdAt,
    restaurantId: restaurantId,
    restaurantName: name is String && name.isNotEmpty ? name : 'Restaurant',
    items: items,
    deliveryFeeSantim: fee,
    delivery: DeliveryDetails(
      name: '',
      phone: '',
      subCity: subCity is String ? subCity : '',
      address: '',
    ),
    payment: method,
    status: status,
    simulated: false,
    etaMinMinutes: eta?.$1,
    etaMaxMinutes: eta?.$2,
    cancellationRequest: _request(json['cancellationRequest']),
  );
}

/// Reads a list of server orders. Invalid entries are skipped.
List<Order> ordersFromServerList(Object? json) {
  if (json is! List) return const [];
  final out = <Order>[];
  for (final raw in json) {
    final o = orderFromServerJson(raw);
    if (o != null) out.add(o);
  }
  return out;
}

/// The lines sent to place_order: database dish ids and quantities only, never
/// prices. Null if any dish is unknown or has no database id (the offline
/// menu), because such an order cannot be placed on the server.
List<Map<String, Object?>>? buildPlaceLines(
  List<CartLine> lines,
  Map<String, Dish> dishesBySlug,
) {
  final out = <Map<String, Object?>>[];
  for (final l in lines) {
    final dish = dishesBySlug[l.dishId];
    final remoteId = dish?.remoteId;
    if (dish == null || remoteId == null) return null;
    final spice = l.spice;
    out.add({
      'dishId': remoteId,
      'quantity': l.quantity,
      if (spice != null && dish.hasSpiceOptions) 'spice': spice.name,
    });
  }
  return out;
}

/// Identifies one order attempt. The same cart, address and total reuse the
/// same idempotency key, so a retry cannot create a second order.
String placeSignature(
  List<CartLine> lines,
  String addressId,
  int expectedTotalSantim,
) {
  final parts = [for (final l in lines) '${l.key}x${l.quantity}']..sort();
  return '$addressId|$expectedTotalSantim|${parts.join(',')}';
}
