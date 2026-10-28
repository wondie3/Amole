import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/cart_line.dart';
import 'cart_logic.dart';

/// In-memory cart. It is not saved between launches yet (Milestone 5).
class CartNotifier extends Notifier<List<CartLine>> {
  @override
  List<CartLine> build() => const [];

  /// Adds a line. Returns true if the per-line limit capped the quantity.
  bool add(CartLine line) {
    final capped = exceedsLimit(state, line);
    state = addToCart(state, line);
    return capped;
  }
}

final cartProvider = NotifierProvider<CartNotifier, List<CartLine>>(
  CartNotifier.new,
);

final cartCountProvider = Provider<int>(
  (ref) => cartItemCount(ref.watch(cartProvider)),
);
