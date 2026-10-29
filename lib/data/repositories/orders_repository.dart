import 'package:shared_preferences/shared_preferences.dart';

import '../../features/orders/orders_logic.dart';
import '../../models/order.dart';

/// Where orders are stored. Today: this phone. Later: a backend.
/// [load] is synchronous because the local store is; a remote implementation
/// will need an async version.
abstract interface class OrdersRepository {
  List<Order> load();
  Future<void> save(List<Order> orders);
}

class LocalOrdersRepository implements OrdersRepository {
  const LocalOrdersRepository(this._prefs);

  static const String storageKey = 'order_history_v1';

  final SharedPreferences _prefs;

  @override
  List<Order> load() => decodeOrders(_prefs.getString(storageKey));

  @override
  Future<void> save(List<Order> orders) =>
      _prefs.setString(storageKey, encodeOrders(orders));
}
