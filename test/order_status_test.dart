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

final DateTime _now = DateTime.utc(2026, 10, 28, 9, 40);

CancellationRequest _pending() => CancellationRequest(
  status: CancellationRequestStatus.pending,
  requestedAt: DateTime.utc(2026, 10, 28, 9, 35),
);

Order _order({
  OrderStatus status = OrderStatus.placed,
  int? etaMin = 20,
  int? etaMax = 30,
  String id = 'SIM-1',
  CancellationRequest? request,
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
  cancellationRequest: request,
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
      expect(nextStatus(OrderStatus.preparing), OrderStatus.ready);
      expect(nextStatus(OrderStatus.ready), OrderStatus.outForDelivery);
      expect(nextStatus(OrderStatus.outForDelivery), OrderStatus.delivered);
      expect(nextStatus(OrderStatus.delivered), isNull);
      expect(nextStatus(OrderStatus.cancelled), isNull);
    });

    test('advancing five times delivers the order, then refuses', () {
      Order? o = _order();
      for (var i = 0; i < 5; i++) {
        o = advanceOrder(o!);
        expect(o, isNotNull);
      }
      expect(o!.status, OrderStatus.delivered);
      expect(advanceOrder(o), isNull);
    });

    test('a cancelled order cannot move forward', () {
      expect(advanceOrder(_order(status: OrderStatus.cancelled)), isNull);
    });
  });

  group('direct cancellation', () {
    test('only placed orders can be cancelled directly', () {
      expect(canCancel(OrderStatus.placed), isTrue);
      for (final s in [
        OrderStatus.confirmed,
        OrderStatus.preparing,
        OrderStatus.ready,
        OrderStatus.outForDelivery,
        OrderStatus.delivered,
        OrderStatus.cancelled,
      ]) {
        expect(canCancel(s), isFalse, reason: s.name);
      }
    });

    test('cancelOrder follows the rule', () {
      expect(cancelOrder(_order())!.status, OrderStatus.cancelled);
      expect(cancelOrder(_order(status: OrderStatus.confirmed)), isNull);
    });
  });

  group('cancellation requests', () {
    test('only confirmed, preparing and ready orders can ask', () {
      for (final s in [
        OrderStatus.confirmed,
        OrderStatus.preparing,
        OrderStatus.ready,
      ]) {
        expect(
          canRequestCancellation(_order(status: s)),
          isTrue,
          reason: s.name,
        );
      }
      for (final s in [
        OrderStatus.placed,
        OrderStatus.outForDelivery,
        OrderStatus.delivered,
        OrderStatus.cancelled,
      ]) {
        expect(
          canRequestCancellation(_order(status: s)),
          isFalse,
          reason: s.name,
        );
      }
    });

    test('requesting keeps the status and records a pending request', () {
      final o = applyCancellationRequest(
        _order(status: OrderStatus.preparing),
        _now,
      )!;
      expect(o.status, OrderStatus.preparing);
      expect(o.cancellationRequest!.status, CancellationRequestStatus.pending);
      expect(o.cancellationRequest!.requestedAt.isAtSameMomentAs(_now), isTrue);
      expect(applyCancellationRequest(o, _now), isNull);
    });

    test('placed orders use direct cancel, not a request', () {
      expect(applyCancellationRequest(_order(), _now), isNull);
    });

    test('a pending request can be withdrawn and asked again', () {
      final pending = _order(
        status: OrderStatus.confirmed,
        request: _pending(),
      );
      final withdrawn = applyWithdrawal(pending)!;
      expect(withdrawn.cancellationRequest, isNull);
      expect(canRequestCancellation(withdrawn), isTrue);
      expect(applyWithdrawal(withdrawn), isNull);
    });

    test('a decided request cannot be withdrawn or repeated', () {
      final pending = _order(
        status: OrderStatus.confirmed,
        request: _pending(),
      );
      final declined = applyDecision(
        pending,
        accept: false,
        now: _now,
        reason: 'No',
      )!;
      expect(applyWithdrawal(declined), isNull);
      expect(canRequestCancellation(declined), isFalse);
    });
  });

  group('restaurant decisions (simulated)', () {
    test('accepting cancels the order', () {
      final o = applyDecision(
        _order(status: OrderStatus.ready, request: _pending()),
        accept: true,
        now: _now,
      )!;
      expect(o.status, OrderStatus.cancelled);
      expect(o.cancellationRequest!.status, CancellationRequestStatus.accepted);
      expect(o.cancellationRequest!.decidedAt!.isAtSameMomentAs(_now), isTrue);
    });

    test('declining keeps the previous status and stores the reason', () {
      final o = applyDecision(
        _order(status: OrderStatus.preparing, request: _pending()),
        accept: false,
        now: _now,
        reason: 'Already cooking',
      )!;
      expect(o.status, OrderStatus.preparing);
      expect(o.cancellationRequest!.status, CancellationRequestStatus.declined);
      expect(o.cancellationRequest!.decisionReason, 'Already cooking');
    });

    test('a decline needs a reason', () {
      final o = _order(status: OrderStatus.confirmed, request: _pending());
      expect(applyDecision(o, accept: false, now: _now), isNull);
      expect(applyDecision(o, accept: false, now: _now, reason: '  '), isNull);
    });

    test('accepting is refused once the order is out for delivery', () {
      final o = _order(status: OrderStatus.outForDelivery, request: _pending());
      expect(canAcceptCancellation(o), isFalse);
      expect(applyDecision(o, accept: true, now: _now), isNull);
      expect(
        applyDecision(o, accept: false, now: _now, reason: 'Support')!.status,
        OrderStatus.outForDelivery,
      );
    });

    test('decisions need a pending request', () {
      expect(
        applyDecision(
          _order(status: OrderStatus.confirmed),
          accept: true,
          now: _now,
        ),
        isNull,
      );
    });

    test('the order can move on while a request is pending', () {
      final o = advanceOrder(
        _order(status: OrderStatus.confirmed, request: _pending()),
      )!;
      expect(o.status, OrderStatus.preparing);
      expect(o.cancellationRequest!.isPending, isTrue);
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
      expect(result.order!.cancellationRequest, isNull);
    });
  });

  group('saving', () {
    test('status and estimate survive a round trip', () {
      final back = decodeOrders(
        encodeOrders([_order(status: OrderStatus.ready)]),
      ).first;
      expect(back.status, OrderStatus.ready);
      expect(back.etaMinMinutes, 20);
      expect(back.etaMaxMinutes, 30);
    });

    test('a pending request survives a round trip', () {
      final back = decodeOrders(
        encodeOrders([
          _order(status: OrderStatus.preparing, request: _pending()),
        ]),
      ).first;
      expect(back.cancellationRequest!.isPending, isTrue);
      expect(
        back.cancellationRequest!.requestedAt.isAtSameMomentAs(
          DateTime.utc(2026, 10, 28, 9, 35),
        ),
        isTrue,
      );
    });

    test('a decided request keeps its reason', () {
      final declined = applyDecision(
        _order(status: OrderStatus.confirmed, request: _pending()),
        accept: false,
        now: _now,
        reason: 'Already cooking',
      )!;
      final back = decodeOrders(encodeOrders([declined])).first;
      expect(back.status, OrderStatus.confirmed);
      expect(
        back.cancellationRequest!.status,
        CancellationRequestStatus.declined,
      );
      expect(back.cancellationRequest!.decisionReason, 'Already cooking');
    });

    test('orders saved before requests existed still load', () {
      final list = jsonDecode(encodeOrders([_order()])) as List;
      (list.first as Map).remove('cancellation');
      final back = decodeOrders(jsonEncode(list));
      expect(back.length, 1);
      expect(back.first.cancellationRequest, isNull);
    });

    test('a malformed request is ignored, not fatal', () {
      final list = jsonDecode(encodeOrders([_order()])) as List;
      (list.first as Map)['cancellation'] = 'nonsense';
      final back = decodeOrders(jsonEncode(list));
      expect(back.length, 1);
      expect(back.first.cancellationRequest, isNull);
    });

    test('orders saved before the estimate existed still load', () {
      final list = jsonDecode(encodeOrders([_order()])) as List;
      final map = list.first as Map;
      map.remove('etaMin');
      map.remove('etaMax');
      final back = decodeOrders(jsonEncode(list));
      expect(back.length, 1);
      expect(back.first.etaMinMinutes, isNull);
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
          _order(id: 'SIM-C', status: OrderStatus.confirmed),
        ]),
      });
      final c = _container(prefs);
      final n = c.read(ordersProvider.notifier);
      expect(n.advance('SIM-1'), isFalse);
      expect(n.cancel('SIM-1'), isFalse);
      expect(n.cancel('SIM-C'), isFalse);
      expect(n.requestCancellation('SIM-1'), isFalse);
      expect(n.advance('ghost'), isFalse);
      expect(c.read(ordersProvider).first.status, OrderStatus.delivered);
    });

    test('request, decline and accept are saved', () async {
      final prefs = await _prefs({
        OrdersNotifier.storageKey: encodeOrders([
          _order(id: 'SIM-A', status: OrderStatus.confirmed),
          _order(id: 'SIM-B', status: OrderStatus.preparing),
        ]),
      });
      final c = _container(prefs);
      final n = c.read(ordersProvider.notifier);
      expect(n.requestCancellation('SIM-A'), isTrue);
      expect(n.requestCancellation('SIM-A'), isFalse);
      expect(n.simulateDecision('SIM-A', accept: false), isTrue);
      expect(n.requestCancellation('SIM-B'), isTrue);
      expect(n.simulateDecision('SIM-B', accept: true), isTrue);
      await Future<void>.delayed(Duration.zero);

      final restored = _container(prefs).read(ordersProvider);
      final a = restored.firstWhere((o) => o.id == 'SIM-A');
      final b = restored.firstWhere((o) => o.id == 'SIM-B');
      expect(a.status, OrderStatus.confirmed);
      expect(a.cancellationRequest!.status, CancellationRequestStatus.declined);
      expect(a.cancellationRequest!.decisionReason, simulatedDeclineReason);
      expect(b.status, OrderStatus.cancelled);
      expect(b.cancellationRequest!.status, CancellationRequestStatus.accepted);
    });

    test('withdrawing a request is saved', () async {
      final prefs = await _prefs({
        OrdersNotifier.storageKey: encodeOrders([
          _order(status: OrderStatus.ready),
        ]),
      });
      final c = _container(prefs);
      final n = c.read(ordersProvider.notifier);
      expect(n.requestCancellation('SIM-1'), isTrue);
      expect(n.withdrawCancellation('SIM-1'), isTrue);
      expect(n.withdrawCancellation('SIM-1'), isFalse);
      await Future<void>.delayed(Duration.zero);

      expect(
        _container(prefs).read(ordersProvider).first.cancellationRequest,
        isNull,
      );
    });
  });
}
