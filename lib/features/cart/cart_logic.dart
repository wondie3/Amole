import 'dart:convert';
import 'dart:math' as math;

import '../../models/cart_line.dart';
import '../../models/dish.dart';
import '../../models/restaurant.dart';

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

/// Sets a line's quantity. Below 1 removes the line; above [maxQuantity] is
/// capped.
List<CartLine> setLineQuantity(List<CartLine> lines, String key, int quantity) {
  if (quantity < 1) return removeLine(lines, key);
  final q = math.min(quantity, maxQuantity);
  return [for (final l in lines) l.key == key ? l.copyWith(quantity: q) : l];
}

List<CartLine> removeLine(List<CartLine> lines, String key) =>
    lines.where((l) => l.key != key).toList();

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

/// The restaurant the cart belongs to: the restaurant of the first line whose
/// dish is known. Null if the cart has no known dishes.
String? cartRestaurantId(List<CartLine> lines, Map<String, Dish> dishesById) {
  for (final l in lines) {
    final dish = dishesById[l.dishId];
    if (dish != null) return dish.restaurantId;
  }
  return null;
}

/// True if [dish] is from a different restaurant than the current cart.
bool conflictsWithCart(
  List<CartLine> lines,
  Map<String, Dish> dishesById,
  Dish dish,
) {
  final id = cartRestaurantId(lines, dishesById);
  return id != null && id != dish.restaurantId;
}

class CartTotals {
  const CartTotals({
    required this.subtotalSantim,
    required this.deliveryFeeSantim,
  });

  final int subtotalSantim;
  final int deliveryFeeSantim;

  int get totalSantim => subtotalSantim + deliveryFeeSantim;
}

/// Subtotal plus the delivery fee of the cart's restaurant. An empty cart (or
/// one with no known dishes) has no fee.
CartTotals computeTotals(
  List<CartLine> lines,
  Map<String, Dish> dishesById,
  Map<String, Restaurant> restaurantsById,
) {
  final restaurantId = cartRestaurantId(lines, dishesById);
  final fee = restaurantId == null
      ? 0
      : (restaurantsById[restaurantId]?.deliveryFeeSantim ?? 0);
  return CartTotals(
    subtotalSantim: cartSubtotalSantim(lines, dishesById),
    deliveryFeeSantim: fee,
  );
}

String encodeCart(List<CartLine> lines) => jsonEncode([
  for (final l in lines) {'d': l.dishId, 's': l.spice?.name, 'q': l.quantity},
]);

/// Reads a saved cart. Anything malformed is skipped, so bad saved data can
/// never crash the app.
List<CartLine> decodeCart(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final data = jsonDecode(raw);
    if (data is! List) return const [];
    var lines = <CartLine>[];
    for (final item in data) {
      if (item is! Map) continue;
      final id = item['d'];
      final q = item['q'];
      final s = item['s'];
      if (id is! String || id.isEmpty || q is! int || q < 1) continue;
      SpiceLevel? spice;
      if (s != null) {
        if (s is! String) continue;
        spice = SpiceLevel.values.where((v) => v.name == s).firstOrNull;
        if (spice == null) continue;
      }
      lines = addToCart(lines, CartLine(dishId: id, quantity: q, spice: spice));
    }
    return lines;
  } on FormatException {
    return const [];
  }
}
