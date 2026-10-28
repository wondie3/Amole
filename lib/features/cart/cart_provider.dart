import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/preferences_provider.dart';
import '../../models/cart_line.dart';
import 'cart_logic.dart';

/// Cart saved on this phone only. Prices are never stored, only dish ids and
/// quantities, so totals always come from the current catalog.
class CartNotifier extends Notifier<List<CartLine>> {
  static const String storageKey = 'cart_lines_v1';

  @override
  List<CartLine> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return decodeCart(prefs.getString(storageKey));
  }

  void _set(List<CartLine> next) {
    state = next;
    _save(next);
  }

  Future<void> _save(List<CartLine> lines) async {
    try {
      await ref
          .read(sharedPreferencesProvider)
          .setString(storageKey, encodeCart(lines));
    } catch (error) {
      // The cart still works for this session; saving failed.
      debugPrint('Could not save cart: $error');
    }
  }

  /// Adds a line. Returns true if the per-line limit capped the quantity.
  bool add(CartLine line) {
    final capped = exceedsLimit(state, line);
    _set(addToCart(state, line));
    return capped;
  }

  /// Empties the cart and starts a new one with [line].
  void replaceWith(CartLine line) => _set(addToCart(const [], line));

  /// Changes a line's quantity relative to its current value, so rapid taps
  /// never act on stale numbers.
  void changeQuantity(String key, int delta) {
    final i = state.indexWhere((l) => l.key == key);
    if (i < 0) return;
    _set(setLineQuantity(state, key, state[i].quantity + delta));
  }

  void remove(String key) => _set(removeLine(state, key));

  void clear() => _set(const []);
}

final cartProvider = NotifierProvider<CartNotifier, List<CartLine>>(
  CartNotifier.new,
);

final cartCountProvider = Provider<int>(
  (ref) => cartItemCount(ref.watch(cartProvider)),
);
