import 'package:amole/data/catalog_providers.dart';
import 'package:amole/data/preferences_provider.dart';
import 'package:amole/features/cart/cart_provider.dart';
import 'package:amole/features/checkout/checkout_logic.dart';
import 'package:amole/features/orders/orders_provider.dart';
import 'package:amole/models/cart_line.dart';
import 'package:amole/models/dish.dart';
import 'package:amole/models/order.dart';
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

const _delivery = DeliveryDetails(
  name: 'Abebe Kebede',
  phone: '+251911223344',
  subCity: 'Bole',
  address: 'Near the roundabout',
);

OrderBuild _build(
  List<CartLine> lines, {
  PaymentMethod payment = PaymentMethod.cashOnDelivery,
}) => buildOrder(
  lines: lines,
  dishesById: _dishes,
  restaurantsById: _restaurants,
  delivery: _delivery,
  payment: payment,
  id: 'SIM-TEST',
  createdAt: DateTime(2026, 10, 28),
);

void main() {
  group('phone numbers', () {
    test('accepted formats normalize to +251', () {
      expect(normalizePhone('0911223344'), '+251911223344');
      expect(normalizePhone('0711223344'), '+251711223344');
      expect(normalizePhone('+251 91 122 3344'), '+251911223344');
      expect(normalizePhone('251911223344'), '+251911223344');
      expect(normalizePhone('(091) 122-3344'), '+251911223344');
    });

    test('rejected formats', () {
      expect(normalizePhone('091122334'), isNull);
      expect(normalizePhone('0111223344'), isNull);
      expect(normalizePhone('+254911223344'), isNull);
      expect(normalizePhone('abc'), isNull);
    });

    test('validatePhone messages', () {
      expect(validatePhone(''), 'Enter your phone number');
      expect(validatePhone('123'), isNotNull);
      expect(validatePhone('0911223344'), isNull);
    });
  });

  group('field validators', () {
    test('name', () {
      expect(validateName(' '), isNotNull);
      expect(validateName('A'), isNotNull);
      expect(validateName('Abebe Kebede'), isNull);
      expect(validateName('አበበ ከበደ'), isNull);
      expect(validateName('x' * 61), isNotNull);
    });

    test('sub-city, address and landmark', () {
      expect(validateSubCity(null), isNotNull);
      expect(validateSubCity('Bole'), isNull);
      expect(validateAddress(''), isNotNull);
      expect(validateAddress('abc'), isNotNull);
      expect(validateAddress('Near Edna Mall'), isNull);
      expect(validateLandmark(null), isNull);
      expect(validateLandmark('x' * 81), isNotNull);
    });
  });

  group('buildOrder', () {
    test('builds an order with snapshot items and totals', () {
      final result = _build(const [
        CartLine(dishId: 'tibs', quantity: 2, spice: SpiceLevel.spicy),
      ]);
      final order = result.order!;
      expect(order.subtotalSantim, 64000);
      expect(order.deliveryFeeSantim, 4500);
      expect(order.totalSantim, 68500);
      expect(order.items.first.spiceLabel, 'Spicy');
      expect(order.status, OrderStatus.placed);
      expect(order.simulated, isTrue);
      expect(order.restaurantName, 'Alpha Grill');
    });

    test('refuses an empty cart', () {
      expect(_build(const []).error, isNotNull);
    });

    test('refuses unknown dishes', () {
      expect(
        _build(const [CartLine(dishId: 'ghost', quantity: 1)]).order,
        isNull,
      );
    });

    test('refuses mixed restaurants', () {
      final result = _build(const [
        CartLine(dishId: 'tibs', quantity: 1),
        CartLine(dishId: 'shiro', quantity: 1),
      ]);
      expect(result.order, isNull);
      expect(result.error, contains('more than one restaurant'));
    });

    test('refuses a payment method that is not available', () {
      final result = _build(const [
        CartLine(dishId: 'tibs', quantity: 1),
      ], payment: PaymentMethod.telebirr);
      expect(result.order, isNull);
    });
  });

  group('orders provider', () {
    test('placing twice creates one order and empties the cart', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(c.dispose);

      c
          .read(cartProvider.notifier)
          .add(const CartLine(dishId: 'tibs', quantity: 2));
      final data = HomeData(
        categories: const [],
        restaurants: [_r1, _r2],
        dishes: [_tibs, _shiro],
      );

      final orders = c.read(ordersProvider.notifier);
      final first = orders.placeOrder(
        data: data,
        delivery: _delivery,
        payment: PaymentMethod.cashOnDelivery,
      );
      final second = orders.placeOrder(
        data: data,
        delivery: _delivery,
        payment: PaymentMethod.cashOnDelivery,
      );

      expect(first.order, isNotNull);
      expect(second.order, isNull);
      expect(c.read(ordersProvider).length, 1);
      expect(c.read(cartProvider), isEmpty);
    });
  });
}
