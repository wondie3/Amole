import 'package:amole/features/cart/cart_logic.dart';
import 'package:amole/models/cart_line.dart';
import 'package:amole/models/dish.dart';
import 'package:flutter_test/flutter_test.dart';

const _tibs = Dish(
  id: 'tibs',
  name: 'Tibs',
  restaurantId: 'r',
  categoryId: 'grill',
  priceSantim: 32000,
  rating: 4.4,
  imageAsset: 'x.jpg',
);
const _shiro = Dish(
  id: 'shiro',
  name: 'Shiro',
  restaurantId: 'r',
  categoryId: 'fasting',
  priceSantim: 19050,
  rating: 4.7,
  imageAsset: 'x.jpg',
);
final _byId = {'tibs': _tibs, 'shiro': _shiro};

void main() {
  test('adds a new line', () {
    final lines = addToCart(
      const [],
      const CartLine(dishId: 'tibs', quantity: 2),
    );
    expect(lines.length, 1);
    expect(lines.first.quantity, 2);
  });

  test('same dish and spice merge into one line', () {
    var lines = addToCart(
      const [],
      const CartLine(dishId: 'tibs', quantity: 1, spice: SpiceLevel.mild),
    );
    lines = addToCart(
      lines,
      const CartLine(dishId: 'tibs', quantity: 2, spice: SpiceLevel.mild),
    );
    expect(lines.length, 1);
    expect(lines.first.quantity, 3);
  });

  test('different spice levels stay separate', () {
    var lines = addToCart(
      const [],
      const CartLine(dishId: 'tibs', quantity: 1, spice: SpiceLevel.mild),
    );
    lines = addToCart(
      lines,
      const CartLine(dishId: 'tibs', quantity: 1, spice: SpiceLevel.spicy),
    );
    expect(lines.length, 2);
  });

  test('quantity is capped and the cap is reported', () {
    final start = addToCart(
      const [],
      const CartLine(dishId: 'tibs', quantity: 19),
    );
    const more = CartLine(dishId: 'tibs', quantity: 5);
    expect(exceedsLimit(start, more), isTrue);
    expect(addToCart(start, more).first.quantity, maxQuantity);
    expect(
      exceedsLimit(start, const CartLine(dishId: 'tibs', quantity: 1)),
      isFalse,
    );
  });

  test('non-positive quantities are ignored', () {
    final lines = addToCart(
      const [],
      const CartLine(dishId: 'tibs', quantity: 0),
    );
    expect(lines, isEmpty);
  });

  test('count and subtotal use integer santim', () {
    final lines = [
      const CartLine(dishId: 'tibs', quantity: 2),
      const CartLine(dishId: 'shiro', quantity: 3),
    ];
    expect(cartItemCount(lines), 5);
    expect(cartSubtotalSantim(lines, _byId), 2 * 32000 + 3 * 19050);
  });

  test('unknown dishes add nothing to the subtotal', () {
    final lines = [const CartLine(dishId: 'ghost', quantity: 4)];
    expect(cartSubtotalSantim(lines, _byId), 0);
  });
}
