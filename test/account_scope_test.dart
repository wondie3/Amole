import 'dart:async';

import 'package:amole/data/preferences_provider.dart';
import 'package:amole/data/repositories/auth_repository.dart';
import 'package:amole/data/repositories/result.dart';
import 'package:amole/data/repository_providers.dart';
import 'package:amole/data/storage_scope.dart';
import 'package:amole/features/auth/auth_provider.dart';
import 'package:amole/features/cart/cart_logic.dart';
import 'package:amole/features/cart/cart_provider.dart';
import 'package:amole/features/favorites/favorites_provider.dart';
import 'package:amole/features/orders/orders_logic.dart';
import 'package:amole/features/orders/orders_provider.dart';
import 'package:amole/features/settings/local_data.dart';
import 'package:amole/models/cart_line.dart';
import 'package:amole/models/order.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _a = AuthUser(id: 'user-a', email: 'a@example.com');
const _b = AuthUser(id: 'user-b', email: 'b@example.com');

class _FakeAuth implements AuthRepository {
  final StreamController<AuthUser?> _controller =
      StreamController<AuthUser?>.broadcast();
  AuthUser? _user;

  void emit(AuthUser? user) {
    _user = user;
    _controller.add(user);
  }

  @override
  bool get isConnected => true;

  @override
  AuthUser? get currentUser => _user;

  @override
  Stream<AuthUser?> get authChanges => _controller.stream;

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

Order _order(String id) => Order(
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
);

Future<(ProviderContainer, _FakeAuth, SharedPreferences)> _setup(
  Map<String, Object> initial,
) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final auth = _FakeAuth();
  final c = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authRepositoryProvider.overrideWithValue(auth),
    ],
  );
  addTearDown(() async {
    c.dispose();
    await auth._controller.close();
  });
  // Keep the signed-in user alive so changes are followed.
  c.listen(authUserProvider, (previous, next) {});
  return (c, auth, prefs);
}

Future<void> _switchTo(_FakeAuth auth, AuthUser? user) async {
  auth.emit(user);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  test('the guest keeps the original keys', () {
    expect(scopedKey('cart_lines_v1', null), 'cart_lines_v1');
    expect(scopedKey('cart_lines_v1', 'u1'), 'cart_lines_v1:u:u1');
  });

  test(
    'each account has its own data, and the guest data comes back',
    () async {
      final (c, auth, _) = await _setup({
        OrdersNotifier.storageKey: encodeOrders([_order('SIM-GUEST')]),
        scopedKey(OrdersNotifier.storageKey, 'user-a'): encodeOrders([
          _order('SIM-A'),
        ]),
      });

      // Guest data.
      c
          .read(cartProvider.notifier)
          .add(const CartLine(dishId: 'tibs', quantity: 2));
      await c.read(favoritesProvider.notifier).toggle('tibs');
      expect(c.read(ordersProvider).single.id, 'SIM-GUEST');

      // Account A: starts empty apart from what was saved for A.
      await _switchTo(auth, _a);
      expect(c.read(storageScopeProvider), 'user-a');
      expect(c.read(cartProvider), isEmpty);
      expect(c.read(favoritesProvider), isEmpty);
      expect(c.read(ordersProvider).single.id, 'SIM-A');
      c
          .read(cartProvider.notifier)
          .add(const CartLine(dishId: 'shiro', quantity: 1));
      await c.read(favoritesProvider.notifier).toggle('kitfo');

      // Account B sees nothing of A or the guest.
      await _switchTo(auth, _b);
      expect(c.read(cartProvider), isEmpty);
      expect(c.read(favoritesProvider), isEmpty);
      expect(c.read(ordersProvider), isEmpty);

      // A again: restored.
      await _switchTo(auth, _a);
      expect(c.read(cartProvider).single.dishId, 'shiro');
      expect(c.read(favoritesProvider), {'kitfo'});
      expect(c.read(ordersProvider).single.id, 'SIM-A');

      // Signed out: the guest data is back, untouched.
      await _switchTo(auth, null);
      expect(c.read(storageScopeProvider), isNull);
      final cart = c.read(cartProvider);
      expect(cart.single.dishId, 'tibs');
      expect(cart.single.quantity, 2);
      expect(c.read(favoritesProvider), {'tibs'});
      expect(c.read(ordersProvider).single.id, 'SIM-GUEST');
    },
  );

  test('changes are saved under the active scope only', () async {
    final (c, auth, prefs) = await _setup({});
    c
        .read(cartProvider.notifier)
        .add(const CartLine(dishId: 'tibs', quantity: 1));
    await Future<void>.delayed(Duration.zero);
    final guestBefore = prefs.getString(CartNotifier.storageKey);
    expect(guestBefore, isNotNull);

    await _switchTo(auth, _a);
    c
        .read(cartProvider.notifier)
        .add(const CartLine(dishId: 'shiro', quantity: 3));
    await Future<void>.delayed(Duration.zero);

    final accountKey = scopedKey(CartNotifier.storageKey, 'user-a');
    expect(prefs.getString(accountKey), isNotNull);
    expect(decodeCart(prefs.getString(accountKey)).single.dishId, 'shiro');
    expect(prefs.getString(CartNotifier.storageKey), guestBefore);
  });

  test('clearing while signed in removes only that account', () async {
    final guestCart = encodeCart(const [CartLine(dishId: 'tibs', quantity: 2)]);
    final aKey = scopedKey(CartNotifier.storageKey, 'user-a');
    final bKey = scopedKey(CartNotifier.storageKey, 'user-b');
    final (c, auth, prefs) = await _setup({
      CartNotifier.storageKey: guestCart,
      aKey: encodeCart(const [CartLine(dishId: 'shiro', quantity: 1)]),
      bKey: encodeCart(const [CartLine(dishId: 'kitfo', quantity: 1)]),
    });

    await _switchTo(auth, _a);
    expect(c.read(cartProvider), isNotEmpty);
    await c.read(clearLocalDataProvider)();

    expect(prefs.getString(aKey), isNull);
    expect(prefs.getString(bKey), isNotNull);
    expect(prefs.getString(CartNotifier.storageKey), guestCart);
    expect(c.read(cartProvider), isEmpty);

    await _switchTo(auth, null);
    expect(c.read(cartProvider).single.dishId, 'tibs');
  });

  test('clearing as a guest leaves account data alone', () async {
    final aKey = scopedKey(CartNotifier.storageKey, 'user-a');
    final aCart = encodeCart(const [CartLine(dishId: 'shiro', quantity: 1)]);
    final (c, auth, prefs) = await _setup({
      CartNotifier.storageKey: encodeCart(const [
        CartLine(dishId: 'tibs', quantity: 1),
      ]),
      aKey: aCart,
    });

    await c.read(clearLocalDataProvider)();
    expect(prefs.getString(CartNotifier.storageKey), isNull);
    expect(prefs.getString(aKey), aCart);

    await _switchTo(auth, _a);
    expect(c.read(cartProvider).single.dishId, 'shiro');
  });
}
