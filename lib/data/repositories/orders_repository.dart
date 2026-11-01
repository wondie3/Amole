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
  const LocalOrdersRepository(this._prefs, {this.key = storageKey});

  static const String storageKey = 'order_history_v1';

  final SharedPreferences _prefs;

  /// The key to use. Differs per signed-in account.
  final String key;

  @override
  List<Order> load() => decodeOrders(_prefs.getString(key));

  @override
  Future<void> save(List<Order> orders) =>
      _prefs.setString(key, encodeOrders(orders));
}
