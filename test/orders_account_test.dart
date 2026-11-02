import 'dart:async';

import 'package:amole/data/catalog_providers.dart';
import 'package:amole/data/preferences_provider.dart';
import 'package:amole/data/repositories/auth_repository.dart';
import 'package:amole/data/repositories/result.dart';
import 'package:amole/data/repository_providers.dart';
import 'package:amole/features/cart/cart_provider.dart';
import 'package:amole/features/orders/orders_active.dart';
import 'package:amole/features/orders/orders_logic.dart';
import 'package:amole/features/orders/orders_provider.dart';
import 'package:amole/features/orders/orders_remote_logic.dart';
import 'package:amole/models/cart_line.dart';
import 'package:amole/models/dish.dart';
import 'package:amole/models/order.dart';
import 'package:amole/models/restaurant.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth implements AuthRepository {
  const _Auth(this.user);

  final AuthUser? user;

  @override
  bool get isConnected => true;

  @override
  AuthUser? get currentUser => user;

  @override
  Stream<AuthUser?> get authChanges => const Stream<AuthUser?>.empty();

  @override
  Future<Result<AuthUser?>> signUp({
    required String email,
    required String password,
    required String name,
  }) async => const Ok<AuthUser?>(null);

  @override
  Future<Result<AuthUser>> signIn({
    required String email,
    required String password,
  }) async => const Failure<AuthUser>('not used');

  @override
  Future<Result<void>> requestPasswordReset({required String email}) async =>
      const Ok<void>(null);

  @override
  Future<Result<void>> signOut() async => const Ok<void>(null);
}

const _signedIn = _Auth(AuthUser(id: 'u1', email: 'abebe@example.com'));

Map<String, dynamic> _serverOrder(String id, {Object? request}) => {
  'id': id,
  'status': 'placed',
  'createdAt': '2026-10-28T09:30:00+00:00',
  'restaurantId': 'rest-uuid',
  'restaurantName': 'Sheger Grill',
  'subCity': 'Bole',
  'fulfillment': 'delivery',
  'subtotalSantim': 64000,
  'deliveryFeeSantim': 4500,
  'totalSantim': 68500,
  'estimatedDeliveryFrom': '2026-10-28T09:50:00+00:00',
  'estimatedDeliveryTo': '2026-10-28T10:00:00+00:00',
  'payment': {'method': 'cash_on_delivery', 'status': 'pending'},
  'items': [
    {
      'dishId': 'dish-uuid',
      'name': 'Tibs',
      'quantity': 2,
      'unitPriceSantim': 32000,
      'spice': 'spicy',
    },
  ],
  'cancellationRequest': request,
};

class _FakeSource implements RemoteOrdersSource {
  final List<Map<String, dynamic>> orders = [];
  final Map<String, Map<String, dynamic>> byKey = {};
  final List<String> usedKeys = [];
  List<Map<String, Object?>> lastLines = const [];
  int? lastExpected;
  Object? failNext;
  bool loseResponseOnce = false;
  bool failFetch = false;
  int fetches = 0;
  int placeCalls = 0;

  @override
  Future<List<dynamic>> fetchOrders() async {
    fetches++;
    if (failFetch) throw const OrderSourceException(code: 'x');
    return [for (final o in orders) Map<String, dynamic>.of(o)];
  }

  @override
  Future<Object?> placeOrder({
    required String idempotencyKey,
    required List<Map<String, Object?>> lines,
    required String addressId,
    required int expectedTotalSantim,
  }) async {
    placeCalls++;
    usedKeys.add(idempotencyKey);
    lastLines = lines;
    lastExpected = expectedTotalSantim;
    final e = failNext;
    if (e != null) {
      failNext = null;
      throw e;
    }
    final existing = byKey[idempotencyKey];
    if (existing != null) return existing;
    final json = _serverOrder('srv-${byKey.length + 1}');
    byKey[idempotencyKey] = json;
    orders.insert(0, json);
    if (loseResponseOnce) {
      loseResponseOnce = false;
      throw TimeoutException('response lost');
    }
    return json;
  }

  @override
  Future<Object?> requestCancellation(String orderId) async {
    final e = failNext;
    if (e != null) {
      failNext = null;
      throw e;
    }
    final i = orders.indexWhere((o) => o['id'] == orderId);
    if (i < 0) {
      throw const OrderSourceException(code: 'P0001', message: 'not_found');
    }
    orders[i] = {...orders[i], 'status': 'cancelled'};
    return orders[i];
  }

  @override
  Future<Object?> withdrawCancellation(String orderId) async => null;
}

const _restaurant = Restaurant(
  id: 'sheger_grill',
  name: 'Sheger Grill',
  cuisine: 'Tibs and kitfo',
  rating: 4.4,
  etaMinMinutes: 20,
  etaMaxMinutes: 30,
  deliveryFeeSantim: 4500,
  remoteId: 'rest-uuid',
);

const _tibs = Dish(
  id: 'tibs',
  name: 'Tibs',
  restaurantId: 'sheger_grill',
  categoryId: 'grill',
  priceSantim: 32000,
  rating: 4.4,
  imageAsset: 'x.jpg',
  hasSpiceOptions: true,
  remoteId: 'dish-uuid',
);

const _kitfo = Dish(
  id: 'kitfo',
  name: 'Kitfo',
  restaurantId: 'sheger_grill',
  categoryId: 'grill',
  priceSantim: 36000,
  rating: 4.5,
  imageAsset: 'x.jpg',
  remoteId: 'kitfo-uuid',
);

const _menu = HomeData(
  categories: [],
  restaurants: [_restaurant],
  dishes: [_tibs, _kitfo],
);

const _offlineMenu = HomeData(
  categories: [],
  restaurants: [
    Restaurant(
      id: 'sheger_grill',
      name: 'Sheger Grill',
      cuisine: 'Tibs and kitfo',
      rating: 4.4,
      etaMinMinutes: 20,
      etaMaxMinutes: 30,
      deliveryFeeSantim: 4500,
    ),
  ],
  dishes: [
    Dish(
      id: 'tibs',
      name: 'Tibs',
      restaurantId: 'sheger_grill',
      categoryId: 'grill',
      priceSantim: 32000,
      rating: 4.4,
      imageAsset: 'x.jpg',
    ),
  ],
);

Future<SharedPreferences> _prefs([
  Map<String, Object> initial = const {},
]) async {
  SharedPreferences.setMockInitialValues(initial);
  return SharedPreferences.getInstance();
}

ProviderContainer _container(
  SharedPreferences prefs,
  _FakeSource source, {
  AuthRepository auth = _signedIn,
}) {
  final c = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      backendEnabledProvider.overrideWithValue(true),
      authRepositoryProvider.overrideWithValue(auth),
      remoteOrdersSourceProvider.overrideWithValue(source),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Order _localOrder(String id) => Order(
  id: id,
  createdAt: DateTime.utc(2026, 10, 28, 9, 30),
  restaurantId: 'r1',
  restaurantName: 'Local Demo Grill',
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
);

void _fillCart(ProviderContainer c, {int quantity = 2}) {
  c
      .read(cartProvider.notifier)
      .add(
        CartLine(dishId: 'tibs', quantity: quantity, spice: SpiceLevel.spicy),
      );
}

void main() {
  group('mode', () {
    test('signed in shows server orders, not the phone demo orders', () async {
      final source = _FakeSource()..orders.add(_serverOrder('srv-0'));
      final c = _container(
        await _prefs({
          OrdersNotifier.storageKey: encodeOrders([_localOrder('SIM-1')]),
        }),
        source,
      );
      await c.read(remoteOrdersProvider.future);
      expect(c.read(useServerOrdersProvider), isTrue);
      expect(c.read(activeOrdersProvider).single.id, 'srv-0');
    });

    test(
      'signed out keeps the demo orders and never calls the server',
      () async {
        final source = _FakeSource();
        final c = _container(
          await _prefs({
            OrdersNotifier.storageKey: encodeOrders([_localOrder('SIM-1')]),
          }),
          source,
          auth: const _Auth(null),
        );
        expect(c.read(useServerOrdersProvider), isFalse);
        expect(c.read(activeOrdersProvider).single.id, 'SIM-1');
        expect(c.read(ordersStatusProvider), OrdersStatus.ready);
        expect(source.fetches, 0);
      },
    );

    test('a failed load shows an error and retry recovers', () async {
      final source = _FakeSource()
        ..orders.add(_serverOrder('srv-0'))
        ..failFetch = true;
      final c = _container(await _prefs(), source);
      try {
        await c.read(remoteOrdersProvider.future);
      } catch (_) {}
      expect(c.read(ordersStatusProvider), OrdersStatus.error);
      expect(c.read(activeOrdersProvider), isEmpty);

      source.failFetch = false;
      c.invalidate(remoteOrdersProvider);
      await c.read(remoteOrdersProvider.future);
      expect(c.read(ordersStatusProvider), OrdersStatus.ready);
      expect(c.read(activeOrdersProvider).length, 1);
    });
  });

  group('placing an order', () {
    test(
      'success sends ids only, clears the cart and lists the order',
      () async {
        final source = _FakeSource();
        final c = _container(await _prefs(), source);
        await c.read(remoteOrdersProvider.future);
        _fillCart(c);

        final r = await c
            .read(remoteOrdersProvider.notifier)
            .placeOrder(data: _menu, addressId: 'addr-1');
        expect(r, isA<PlaceOrderOk>());
        expect((r as PlaceOrderOk).order.id, 'srv-1');
        expect(source.lastLines, [
          {'dishId': 'dish-uuid', 'quantity': 2, 'spice': 'spicy'},
        ]);
        expect(source.lastExpected, 68500);
        expect(c.read(cartProvider), isEmpty);
        expect(c.read(activeOrdersProvider).single.id, 'srv-1');
      },
    );

    test('a lost response and retry never creates a second order', () async {
      final source = _FakeSource()..loseResponseOnce = true;
      final c = _container(await _prefs(), source);
      await c.read(remoteOrdersProvider.future);
      _fillCart(c);
      final n = c.read(remoteOrdersProvider.notifier);

      final first = await n.placeOrder(data: _menu, addressId: 'addr-1');
      expect(first, isA<PlaceOrderFailed>());
      expect((first as PlaceOrderFailed).message, placeNetworkMessage);
      expect(c.read(cartProvider), isNotEmpty);

      final second = await n.placeOrder(data: _menu, addressId: 'addr-1');
      expect(second, isA<PlaceOrderOk>());
      expect(source.usedKeys.toSet().length, 1);
      expect(source.orders.length, 1);
      expect(c.read(cartProvider), isEmpty);
    });

    test('a different cart gets a new idempotency key', () async {
      final source = _FakeSource();
      final c = _container(await _prefs(), source);
      await c.read(remoteOrdersProvider.future);
      _fillCart(c);
      final n = c.read(remoteOrdersProvider.notifier);

      source.failNext = const OrderSourceException(
        code: 'P0001',
        message: 'restaurant_closed',
      );
      await n.placeOrder(data: _menu, addressId: 'addr-1');
      c
          .read(cartProvider.notifier)
          .add(const CartLine(dishId: 'kitfo', quantity: 1));
      await n.placeOrder(data: _menu, addressId: 'addr-1');
      expect(source.usedKeys.length, 2);
      expect(source.usedKeys.first, isNot(source.usedKeys.last));
    });

    test('a changed total reports the new total and keeps the cart', () async {
      final source = _FakeSource()
        ..failNext = const OrderSourceException(
          code: 'P0001',
          message: 'cart_invalid',
          details: 'total_changed:70000',
        );
      final c = _container(await _prefs(), source);
      await c.read(remoteOrdersProvider.future);
      _fillCart(c);

      final r = await c
          .read(remoteOrdersProvider.notifier)
          .placeOrder(data: _menu, addressId: 'addr-1');
      expect(r, isA<PlaceOrderTotalChanged>());
      expect((r as PlaceOrderTotalChanged).newTotalSantim, 70000);
      expect(c.read(cartProvider), isNotEmpty);
      expect(source.orders, isEmpty);
    });

    test('the offline menu blocks the order before any request', () async {
      final source = _FakeSource();
      final c = _container(await _prefs(), source);
      await c.read(remoteOrdersProvider.future);
      _fillCart(c);

      final r = await c
          .read(remoteOrdersProvider.notifier)
          .placeOrder(data: _offlineMenu, addressId: 'addr-1');
      expect((r as PlaceOrderFailed).message, placeMenuOfflineMessage);
      expect(source.placeCalls, 0);
      expect(c.read(cartProvider), isNotEmpty);
    });

    test('an empty cart is refused', () async {
      final source = _FakeSource();
      final c = _container(await _prefs(), source);
      await c.read(remoteOrdersProvider.future);
      final r = await c
          .read(remoteOrdersProvider.notifier)
          .placeOrder(data: _menu, addressId: 'addr-1');
      expect((r as PlaceOrderFailed).message, placeEmptyCartMessage);
      expect(source.placeCalls, 0);
    });

    test('a double tap places one order', () async {
      final source = _FakeSource();
      final c = _container(await _prefs(), source);
      await c.read(remoteOrdersProvider.future);
      _fillCart(c);
      final n = c.read(remoteOrdersProvider.notifier);

      final first = n.placeOrder(data: _menu, addressId: 'addr-1');
      final second = n.placeOrder(data: _menu, addressId: 'addr-1');
      expect(await second, isA<PlaceOrderFailed>());
      expect(await first, isA<PlaceOrderOk>());
      expect(source.orders.length, 1);
    });

    test('phone demo orders are untouched by a server order', () async {
      final initial = encodeOrders([_localOrder('SIM-1')]);
      final prefs = await _prefs({OrdersNotifier.storageKey: initial});
      final source = _FakeSource();
      final c = _container(prefs, source);
      await c.read(remoteOrdersProvider.future);
      _fillCart(c);
      await c
          .read(remoteOrdersProvider.notifier)
          .placeOrder(data: _menu, addressId: 'addr-1');
      expect(prefs.getString(OrdersNotifier.storageKey), initial);
    });
  });

  group('cancellation', () {
    test('a successful request reloads the order', () async {
      final source = _FakeSource()..orders.add(_serverOrder('srv-0'));
      final c = _container(await _prefs(), source);
      await c.read(remoteOrdersProvider.future);

      final error = await c
          .read(remoteOrdersProvider.notifier)
          .requestCancellation('srv-0');
      expect(error, isNull);
      expect(c.read(activeOrdersProvider).single.status, OrderStatus.cancelled);
    });

    test('server refusals become friendly messages', () async {
      final source = _FakeSource()..orders.add(_serverOrder('srv-0'));
      final c = _container(await _prefs(), source);
      await c.read(remoteOrdersProvider.future);
      final n = c.read(remoteOrdersProvider.notifier);

      source.failNext = const OrderSourceException(
        code: 'P0001',
        message: 'not_cancellable',
      );
      expect(await n.requestCancellation('srv-0'), orderNotCancellableMessage);

      expect(await n.requestCancellation('ghost'), orderNotFoundMessage);
      expect(c.read(activeOrdersProvider).length, 1);
    });
  });
}
