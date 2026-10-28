import 'dart:math' as math;

import '../../models/cart_line.dart';
import '../../models/dish.dart';

const int maxQuantity = 20;

int _indexOf(List<CartLine> lines, CartLine line) =>
    lines.indexWhere((x) => x.key == line.key);

/// True if adding [add] would push its line past [maxQuantity].
bool exceedsLimit(List<CartLine> lines, CartLine add) {
  final i = _indexOf(lines, add);
  final existing = i < 0 ? 0 : lines[i].quantity;
  return existing + add.quantity > maxQuantity;
}

/// Returns a new list with [add] merged in. Same dish and spice level share
/// a line. Quantities are capped at [maxQuantity]. Non-positive quantities
/// are ignored.
List<CartLine> addToCart(List<CartLine> lines, CartLine add) {
  if (add.quantity < 1) return lines;
  final i = _indexOf(lines, add);
  if (i < 0) {
    return [
      ...lines,
      add.copyWith(quantity: math.min(add.quantity, maxQuantity)),
    ];
  }
  final merged = math.min(lines[i].quantity + add.quantity, maxQuantity);
  return [
    for (var j = 0; j < lines.length; j++)
      j == i ? lines[i].copyWith(quantity: merged) : lines[j],
  ];
}

int cartItemCount(List<CartLine> lines) =>
    lines.fold(0, (sum, l) => sum + l.quantity);

/// Subtotal in santim. Integer math only. Lines whose dish is unknown count
/// as zero.
int cartSubtotalSantim(List<CartLine> lines, Map<String, Dish> dishesById) {
  var total = 0;
  for (final l in lines) {
    final dish = dishesById[l.dishId];
    if (dish != null) total += dish.priceSantim * l.quantity;
  }
  return total;
}
