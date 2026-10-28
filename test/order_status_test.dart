import 'dart:convert';

import 'package:amole/data/preferences_provider.dart';
import 'package:amole/features/checkout/checkout_logic.dart';
import 'package:amole/features/orders/order_status_logic.dart';
import 'package:amole/features/orders/orders_logic.dart';
import 'package:amole/features/orders/orders_provider.dart';
import 'package:amole/models/cart_line.dart';
import 'package:amole/models/dish.dart';
import 'package:amole/models/order.dart';
import 'package:amole/models/restaurant.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Order _order({
  OrderStatus status = OrderStatus.placed,
  int? etaMin = 20,
  int? etaMax = 30,
  String id = 'SIM-1',
}) => Order(
  id: id,
  createdAt: DateTime.utc(2026, 10, 28, 9, 30),
  restaurantId: 'r1',
  restaurantName: 'Alpha Grill',
  items: const [
    OrderItem(
      dishId: 'tibs',
      name: 'Tibs',
      unitPriceSantim: 32000,
      quantity: 1,
    ),
  ],
  deliveryFeeSantim: 4500,
  delivery: const DeliveryDetails(
    name: '',
    phone: '',
    subCity: 'Bole',
    address: '',
  ),
  payment: PaymentMethod.cashOnDelivery,
  status: status,
  etaMinMinutes: etaMin,
  etaMaxMinutes: etaMax,
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
  group('status transitions', () {
    test('the happy path runs in order and then stops', () {
      expect(nextStatus(OrderStatus.placed), OrderStatus.confirmed);
      expect(nextStatus(OrderStatus.confirmed), OrderStatus.preparing);
      expect(nextStatus(OrderStatus.preparing), OrderStatus.outForDelivery);
      expect(nextStatus(OrderStatus.outForDelivery), OrderStatus.delivered);
      expect(nextStatus(OrderStatus.delivered), isNull);
      expect(nextStatus(OrderStatus.cancelled), isNull);
    });

    test('only placed and confirmed orders can be cancelled', () {
      expect(canCancel(OrderStatus.placed), isTrue);
      expect(canCancel(OrderStatus.confirmed), isTrue);
      expect(canCancel(OrderStatus.preparing), isFalse);
      expect(canCancel(OrderStatus.outForDelivery), isFalse);
      expect(canCancel(OrderStatus.delivered), isFalse);
      expect(canCancel(OrderStatus.cancelled), isFalse);
    });

    test('advancing four times delivers the order, then refuses', () {
      Order? o = _order();
      for (var i = 0; i < 4; i++) {
        o = advanceOrder(o!);
        expect(o, isNotNull);
      }
      expect(o!.status, OrderStatus.delivered);
      expect(advanceOrder(o), isNull);
    });

    test('cancelling follows the rules', () {
      expect(cancelOrder(_order())!.status, OrderStatus.cancelled);
      expect(cancelOrder(_order(status: OrderStatus.preparing)), isNull);
      expect(cancelOrder(_order(status: OrderStatus.cancelled)), isNull);
    });

    test('a cancelled order cannot move forward', () {
      expect(advanceOrder(_order(status: OrderStatus.cancelled)), isNull);
    });
  });

  group('estimated window', () {
    test('adds the saved ETA to the order time', () {
      final w = estimatedWindow(_order())!;
      expect(
        w.from.isAtSameMomentAs(DateTime.utc(2026, 10, 28, 9, 50)),
        isTrue,
      );
      expect(w.to.isAtSameMomentAs(DateTime.utc(2026, 10, 28, 10)), isTrue);
    });

    test('is null when no estimate was saved', () {
      expect(estimatedWindow(_order(etaMin: null, etaMax: null)), isNull);
    });

    test('new orders copy the restaurant estimate', () {
      const restaurant = Restaurant(
        id: 'r1',
        name: 'Alpha Grill',
        cuisine: 'Grill',
        rating: 4.0,
        etaMinMinutes: 10,
        etaMaxMinutes: 20,
        deliveryFeeSantim: 4500,
      );
      const dish = Dish(
        id: 'tibs',
        name: 'Tibs',
        restaurantId: 'r1',
        categoryId: 'grill',
        priceSantim: 32000,
        rating: 4.4,
        imageAsset: 'x.jpg',
      );
      final result = buildOrder(
        lines: const [CartLine(dishId: 'tibs', quantity: 1)],
        dishesById: {'tibs': dish},
        restaurantsById: {'r1': restaurant},
        delivery: const DeliveryDetails(
          name: 'A B',
          phone: '+251911223344',
          subCity: 'Bole',
          address: 'Near the roundabout',
        ),
        payment: PaymentMethod.cashOnDelivery,
        id: 'SIM-T',
        createdAt: DateTime.utc(2026, 10, 28),
      );
      expect(result.order!.etaMinMinutes, 10);
      expect(result.order!.etaMaxMinutes, 20);
    });
  });

  group('saving the new fields', () {
    test('status and estimate survive a round trip', () {
      final back = decodeOrders(
        encodeOrders([_order(status: OrderStatus.preparing)]),
      ).first;
      expect(back.status, OrderStatus.preparing);
      expect(back.etaMinMinutes, 20);
      expect(back.etaMaxMinutes, 30);
    });

    test('orders saved before the estimate existed still load', () {
      final list = jsonDecode(encodeOrders([_order()])) as List;
      final map = list.first as Map;
      map.remove('etaMin');
      map.remove('etaMax');
      final back = decodeOrders(jsonEncode(list));
      expect(back.length, 1);
      expect(back.first.etaMinMinutes, isNull);
      expect(back.first.etaMaxMinutes, isNull);
    });

    test('a nonsense estimate is ignored, not fatal', () {
      final list = jsonDecode(encodeOrders([_order()])) as List;
      (list.first as Map)['etaMin'] = 'soon';
      final back = decodeOrders(jsonEncode(list));
      expect(back.length, 1);
      expect(back.first.etaMinMinutes, isNull);
    });
  });

  group('orders provider', () {
    test('advance and cancel are saved', () async {
      final prefs = await _prefs({
        OrdersNotifier.storageKey: encodeOrders([
          _order(id: 'SIM-A'),
          _order(id: 'SIM-B'),
        ]),
      });
      final c = _container(prefs);
      final n = c.read(ordersProvider.notifier);
      expect(n.advance('SIM-A'), isTrue);
      expect(n.cancel('SIM-B'), isTrue);
      await Future<void>.delayed(Duration.zero);

      final restored = _container(prefs).read(ordersProvider);
      expect(
        restored.firstWhere((o) => o.id == 'SIM-A').status,
        OrderStatus.confirmed,
      );
      expect(
        restored.firstWhere((o) => o.id == 'SIM-B').status,
        OrderStatus.cancelled,
      );
    });

    test('refused changes return false and change nothing', () async {
      final prefs = await _prefs({
        OrdersNotifier.storageKey: encodeOrders([
          _order(status: OrderStatus.delivered),
        ]),
      });
      final c = _container(prefs);
      final n = c.read(ordersProvider.notifier);
      expect(n.advance('SIM-1'), isFalse);
      expect(n.cancel('SIM-1'), isFalse);
      expect(n.advance('ghost'), isFalse);
      expect(c.read(ordersProvider).first.status, OrderStatus.delivered);
    });
  });
}
