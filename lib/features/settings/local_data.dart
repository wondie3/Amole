import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/preferences_provider.dart';
import '../../data/storage_scope.dart';
import '../addresses/addresses_provider.dart';
import '../cart/cart_provider.dart';
import '../favorites/favorites_provider.dart';
import '../orders/orders_provider.dart';

/// Removes what this app saved on the phone for the CURRENT scope, then resets
/// the in-memory state to match.
/// - Signed out: the guest favorites, cart, demo orders and phone addresses.
/// - Signed in: that account's favorites, cart and demo orders only. Guest
///   data, other accounts' data and addresses stored on the server are kept.
final clearLocalDataProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final prefs = ref.read(sharedPreferencesProvider);
    final scope = ref.read(storageScopeProvider);
    final keys = [
      scopedKey(FavoritesNotifier.storageKey, scope),
      scopedKey(CartNotifier.storageKey, scope),
      scopedKey(OrdersNotifier.storageKey, scope),
      if (scope == null) AddressesNotifier.storageKey,
    ];
    for (final key in keys) {
      await prefs.remove(key);
    }
    ref.invalidate(favoritesProvider);
    ref.invalidate(cartProvider);
    ref.invalidate(ordersProvider);
    if (scope == null) ref.invalidate(addressesProvider);
  };
});
