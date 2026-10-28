import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/catalog_providers.dart';
import '../../models/order.dart';
import '../cart/cart_provider.dart';
import '../checkout/checkout_logic.dart';

/// Simulated orders, kept in memory only. Order history and saving arrive in
/// later milestones, and real orders will be created by a backend.
class OrdersNotifier extends Notifier<List<Order>> {
  @override
  List<Order> build() => const [];

  /// Creates an order from the current cart and empties the cart in one
  /// synchronous step. A second call finds an empty cart and creates nothing,
  /// which protects against double taps.
  OrderBuild placeOrder({
    required HomeData data,
    required DeliveryDetails delivery,
    required PaymentMethod payment,
    DateTime? now,
  }) {
    final time = now ?? DateTime.now();
    final result = buildOrder(
      lines: ref.read(cartProvider),
      dishesById: {for (final d in data.dishes) d.id: d},
      restaurantsById: {for (final r in data.restaurants) r.id: r},
      delivery: delivery,
      payment: payment,
      id: 'SIM-${time.millisecondsSinceEpoch.toRadixString(36).toUpperCase()}',
      createdAt: time,
    );
    final order = result.order;
    if (order != null) {
      state = [order, ...state];
      ref.read(cartProvider.notifier).clear();
    }
    return result;
  }
}

final ordersProvider = NotifierProvider<OrdersNotifier, List<Order>>(
  OrdersNotifier.new,
);
