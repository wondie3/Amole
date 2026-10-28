import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/preferences_provider.dart';
import '../addresses/addresses_provider.dart';
import '../cart/cart_provider.dart';
import '../favorites/favorites_provider.dart';
import '../orders/orders_provider.dart';

/// Removes everything this app saved on the phone (favorites, cart, order
/// history, saved addresses) and resets the in-memory state to match.
final clearLocalDataProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final prefs = ref.read(sharedPreferencesProvider);
    const keys = [
      FavoritesNotifier.storageKey,
      CartNotifier.storageKey,
      OrdersNotifier.storageKey,
      AddressesNotifier.storageKey,
    ];
    for (final key in keys) {
      await prefs.remove(key);
    }
    ref.invalidate(favoritesProvider);
    ref.invalidate(cartProvider);
    ref.invalidate(ordersProvider);
    ref.invalidate(addressesProvider);
  };
});
