import 'dart:convert';

import 'package:amole/core/utils/date_format.dart';
import 'package:amole/data/catalog_providers.dart';
import 'package:amole/data/preferences_provider.dart';
import 'package:amole/features/cart/cart_provider.dart';
import 'package:amole/features/orders/orders_logic.dart';
import 'package:amole/features/orders/orders_provider.dart';
import 'package:amole/models/cart_line.dart';
import 'package:amole/models/dish.dart';
import 'package:amole/models/order.dart';
import 'package:amole/models/restaurant.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _delivery = DeliveryDetails(
  name: 'Abebe Kebede',
  phone: '+251911223344',
  subCity: 'Bole',
  address: 'Near the roundabout',
  landmark: 'Blue gate',
);

Order _order(int i, {OrderStatus status = OrderStatus.placed}) => Order(
  id: 'SIM-$i',
  createdAt: DateTime.utc(2026, 10, 28, 9, i % 60),
  restaurantId: 'r1',
  restaurantName: 'Alpha Grill',
  items: const [
    OrderItem(
      dishId: 'tibs',
      name: 'Tibs',
      unitPriceSantim: 32000,
      quantity: 2,
      spiceLabel: 'Spicy',
    ),
    OrderItem(
      dishId: 'shiro',
      name: 'Shiro',
      unitPriceSantim: 19050,
      quantity: 1,
    ),
  ],
  deliveryFeeSantim: 4500,
  delivery: _delivery,
  payment: PaymentMethod.cashOnDelivery,
  status: status,
);

const _r1 = Restaurant(
  id: 'r1',
  name: 'Alpha Grill',
  cuisine: 'Grill',
  rating: 4.0,
  etaMinMinutes: 10,
  etaMaxMinutes: 20,
  deliveryFeeSantim: 4500,
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
  group('encode and decode', () {
    test('round trip keeps id, items, totals, status and date', () {
      final back = decodeOrders(
        encodeOrders([_order(1, status: OrderStatus.delivered)]),
      );
      expect(back.length, 1);
      final o = back.first;
      expect(o.id, 'SIM-1');
      expect(o.status, OrderStatus.delivered);
      expect(o.createdAt.toUtc(), DateTime.utc(2026, 10, 28, 9, 1));
      expect(o.restaurantName, 'Alpha Grill');
      expect(o.items.length, 2);
      expect(o.items.first.quantity, 2);
      expect(o.items.first.spiceLabel, 'Spicy');
      expect(o.items.last.spiceLabel, isNull);
      expect(o.subtotalSantim, 83050);
      expect(o.totalSantim, 87550);
      expect(o.payment, PaymentMethod.cashOnDelivery);
      expect(o.simulated, isTrue);
    });

    test('contact details are not saved, only the sub-city', () {
      final raw = encodeOrders([_order(1)]);
      expect(raw, isNot(contains('Abebe')));
      expect(raw, isNot(contains('911223344')));
      expect(raw, isNot(contains('roundabout')));
      expect(raw, isNot(contains('Blue gate')));
      final o = decodeOrders(raw).first;
      expect(o.delivery.subCity, 'Bole');
      expect(o.delivery.name, isEmpty);
      expect(o.delivery.phone, isEmpty);
    });

    test('empty or missing history gives an empty list', () {
      expect(decodeOrders(null), isEmpty);
      expect(decodeOrders(''), isEmpty);
      expect(decodeOrders('[]'), isEmpty);
    });

    test('bad data gives an empty list instead of crashing', () {
      expect(decodeOrders('not json'), isEmpty);
      expect(decodeOrders('{"a":1}'), isEmpty);
    });

    test('malformed entries are skipped', () {
      final good = jsonDecode(encodeOrders([_order(1)])) as List;
      final raw = jsonEncode([
        ...good,
        {'id': 'x'},
        5,
        {'id': 'SIM-9', 'createdAt': 'nope'},
      ]);
      final orders = decodeOrders(raw);
      expect(orders.length, 1);
      expect(orders.first.id, 'SIM-1');
    });

    test('only the most recent orders are kept', () {
      final many = [for (var i = 0; i < 60; i++) _order(i)];
      expect(decodeOrders(encodeOrders(many)).length, maxSavedOrders);
    });
  });

  group('orders provider', () {
    test('starts empty when nothing is saved', () async {
      final c = _container(await _prefs());
      expect(c.read(ordersProvider), isEmpty);
    });

    test('a placed order survives a restart', () async {
      final prefs = await _prefs();
      final c = _container(prefs);
      c
          .read(cartProvider.notifier)
          .add(const CartLine(dishId: 'tibs', quantity: 2));
      final data = HomeData(
        categories: const [],
        restaurants: const [_r1],
        dishes: const [_tibs],
      );
      final result = c
          .read(ordersProvider.notifier)
          .placeOrder(
            data: data,
            delivery: _delivery,
            payment: PaymentMethod.cashOnDelivery,
            now: DateTime.utc(2026, 10, 28, 9),
          );
      expect(result.order, isNotNull);
      await Future<void>.delayed(Duration.zero);

      final raw = prefs.getString(OrdersNotifier.storageKey)!;
      expect(raw, isNot(contains('Abebe')));

      final restored = _container(prefs).read(ordersProvider);
      expect(restored.length, 1);
      expect(restored.first.totalSantim, 68500);
      expect(restored.first.items.first.name, 'Tibs');
    });

    test('clearing the history is saved too', () async {
      final prefs = await _prefs({
        OrdersNotifier.storageKey: encodeOrders([_order(1), _order(2)]),
      });
      final c = _container(prefs);
      expect(c.read(ordersProvider).length, 2);
      c.read(ordersProvider.notifier).clearHistory();
      await Future<void>.delayed(Duration.zero);
      expect(_container(prefs).read(ordersProvider), isEmpty);
    });
  });

  test('formatOrderDate shows day, month, year and 24-hour time', () {
    expect(
      formatOrderDate(DateTime(2026, 10, 28, 14, 5)),
      '28 Oct 2026, 14:05',
    );
    expect(formatOrderDate(DateTime(2026, 1, 3, 9, 7)), '3 Jan 2026, 09:07');
  });
}
