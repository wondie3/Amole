import 'dart:convert';

import '../../models/order.dart';

/// Only the most recent orders are kept on the phone.
const int maxSavedOrders = 50;

String encodeOrders(List<Order> orders) => jsonEncode([
  for (final o in orders.take(maxSavedOrders)) o.toStorageJson(),
]);

/// Reads saved orders. Anything malformed is skipped, so bad saved data can
/// never crash the app.
List<Order> decodeOrders(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final data = jsonDecode(raw);
    if (data is! List) return const [];
    final orders = <Order>[];
    for (final item in data) {
      final order = Order.tryFromStorageJson(item);
      if (order != null) orders.add(order);
    }
    return orders;
  } on FormatException {
    return const [];
  }
}
