import 'package:amole/data/preferences_provider.dart';
import 'package:amole/features/cart/cart_logic.dart';
import 'package:amole/features/cart/cart_provider.dart';
import 'package:amole/models/cart_line.dart';
import 'package:amole/models/dish.dart';
import 'package:amole/models/restaurant.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _r1 = Restaurant(
  id: 'r1',
  name: 'Alpha Grill',
  cuisine: 'Grill',
  rating: 4.0,
  etaMinMinutes: 10,
  etaMaxMinutes: 20,
  deliveryFeeSantim: 4500,
);
const _r2 = Restaurant(
  id: 'r2',
  name: 'Beta Kitchen',
  cuisine: 'Stews',
  rating: 4.8,
  etaMinMinutes: 30,
  etaMaxMinutes: 40,
  deliveryFeeSantim: 3000,
);
const _tibs = Dish(
  id: 'tibs',
  name: 'Tibs',
  restaurantId: 'r1',
  categoryId: 'grill',
  priceSantim: 32000,
  rating: 4.4,
  imageAsset: 'x.jpg',
);
const _shiro = Dish(
  id: 'shiro',
  name: 'Shiro',
  restaurantId: 'r2',
  categoryId: 'fasting',
  priceSantim: 19050,
  rating: 4.7,
  imageAsset: 'x.jpg',
);
final _dishes = {'tibs': _tibs, 'shiro': _shiro};
final _restaurants = {'r1': _r1, 'r2': _r2};

Future<SharedPreferences> _prefs([
  Map<String, Object> initial = const {},
]) async {
  SharedPreferences.setMockInitialValues(initial);
  return SharedPreferences.getInstance();
}

ProviderContainer _container(SharedPreferences prefs) {
  final c = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('quantity and removal', () {
    const start = [
      CartLine(dishId: 'tibs', quantity: 2),
      CartLine(dishId: 'shiro', quantity: 1),
    ];

    test('setLineQuantity updates one line', () {
      final lines = setLineQuantity(start, 'tibs|-', 5);
      expect(lines.first.quantity, 5);
      expect(lines.last.quantity, 1);
    });

    test('setLineQuantity caps at the maximum', () {
      expect(setLineQuantity(start, 'tibs|-', 99).first.quantity, maxQuantity);
    });

    test('setLineQuantity below 1 removes the line', () {
      final lines = setLineQuantity(start, 'tibs|-', 0);
      expect(lines.map((l) => l.dishId), ['shiro']);
    });

    test('removeLine removes only that line', () {
      expect(removeLine(start, 'shiro|-').map((l) => l.dishId), ['tibs']);
    });
  });

  group('one restaurant per cart', () {
    test('empty cart never conflicts', () {
      expect(conflictsWithCart(const [], _dishes, _tibs), isFalse);
    });

    test('same restaurant does not conflict', () {
      const lines = [CartLine(dishId: 'tibs', quantity: 1)];
      expect(conflictsWithCart(lines, _dishes, _tibs), isFalse);
    });

    test('different restaurant conflicts', () {
      const lines = [CartLine(dishId: 'tibs', quantity: 1)];
      expect(conflictsWithCart(lines, _dishes, _shiro), isTrue);
      expect(cartRestaurantId(lines, _dishes), 'r1');
    });
  });

  group('totals', () {
    test('subtotal plus the cart restaurant delivery fee', () {
      const lines = [CartLine(dishId: 'tibs', quantity: 2)];
      final t = computeTotals(lines, _dishes, _restaurants);
      expect(t.subtotalSantim, 64000);
      expect(t.deliveryFeeSantim, 4500);
      expect(t.totalSantim, 68500);
    });

    test('empty cart has no fee', () {
      final t = computeTotals(const [], _dishes, _restaurants);
      expect(t.totalSantim, 0);
    });

    test('unknown dishes add no fee', () {
      const lines = [CartLine(dishId: 'ghost', quantity: 3)];
      final t = computeTotals(lines, _dishes, _restaurants);
      expect(t.totalSantim, 0);
    });
  });

  group('saving and loading', () {
    test('round trip keeps dish, spice and quantity', () {
      const lines = [
        CartLine(dishId: 'tibs', quantity: 2, spice: SpiceLevel.spicy),
        CartLine(dishId: 'shiro', quantity: 1),
      ];
      final back = decodeCart(encodeCart(lines));
      expect(back.length, 2);
      expect(back.first.spice, SpiceLevel.spicy);
      expect(back.first.quantity, 2);
      expect(back.last.spice, isNull);
    });

    test('bad data gives an empty cart instead of crashing', () {
      expect(decodeCart(null), isEmpty);
      expect(decodeCart(''), isEmpty);
      expect(decodeCart('not json'), isEmpty);
      expect(decodeCart('{"a":1}'), isEmpty);
    });

    test('malformed entries are skipped', () {
      const raw =
          '[{"d":"tibs","s":"spicy","q":2},{"d":"x","q":0},'
          '{"d":"y","s":"volcanic","q":1},5]';
      final lines = decodeCart(raw);
      expect(lines.length, 1);
      expect(lines.first.dishId, 'tibs');
    });

    test('provider saves and a new container restores', () async {
      final prefs = await _prefs();
      final c = _container(prefs);
      c
          .read(cartProvider.notifier)
          .add(
            const CartLine(dishId: 'tibs', quantity: 2, spice: SpiceLevel.mild),
          );
      await Future<void>.delayed(Duration.zero);
      final restored = _container(prefs).read(cartProvider);
      expect(restored.length, 1);
      expect(restored.first.quantity, 2);
    });
  });

  group('cart provider', () {
    test('changeQuantity, remove, replaceWith and clear', () async {
      final c = _container(await _prefs());
      final cart = c.read(cartProvider.notifier);
      cart.add(const CartLine(dishId: 'tibs', quantity: 1));
      cart.changeQuantity('tibs|-', 2);
      expect(c.read(cartProvider).first.quantity, 3);

      cart.replaceWith(const CartLine(dishId: 'shiro', quantity: 1));
      expect(c.read(cartProvider).map((l) => l.dishId), ['shiro']);

      cart.remove('shiro|-');
      expect(c.read(cartProvider), isEmpty);

      cart.add(const CartLine(dishId: 'tibs', quantity: 1));
      cart.clear();
      expect(c.read(cartProvider), isEmpty);
    });
  });
}
