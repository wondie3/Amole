import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/catalog_providers.dart';
import '../../data/preferences_provider.dart';
import '../../models/order.dart';
import '../cart/cart_provider.dart';
import '../checkout/checkout_logic.dart';
import 'orders_logic.dart';

/// Simulated orders, newest first, saved on this phone only. Real orders will
/// be created and stored by a backend.
class OrdersNotifier extends Notifier<List<Order>> {
  static const String storageKey = 'order_history_v1';

  @override
  List<Order> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return decodeOrders(prefs.getString(storageKey));
  }

  Future<void> _save(List<Order> orders) async {
    try {
      await ref
          .read(sharedPreferencesProvider)
          .setString(storageKey, encodeOrders(orders));
    } catch (error) {
      // History still works for this session; saving failed.
      debugPrint('Could not save order history: $error');
    }
  }

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
      state = [order, ...state].take(maxSavedOrders).toList();
      _save(state);
      ref.read(cartProvider.notifier).clear();
    }
    return result;
  }

  void clearHistory() {
    state = const [];
    _save(state);
  }
}

final ordersProvider = NotifierProvider<OrdersNotifier, List<Order>>(
  OrdersNotifier.new,
);
