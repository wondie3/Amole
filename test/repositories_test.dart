import 'package:amole/data/repositories/addresses_repository.dart';
import 'package:amole/data/repositories/auth_repository.dart';
import 'package:amole/data/repositories/favorites_repository.dart';
import 'package:amole/data/repositories/orders_repository.dart';
import 'package:amole/data/repositories/payment_repository.dart';
import 'package:amole/data/repositories/result.dart';
import 'package:amole/data/repository_providers.dart';
import 'package:amole/features/addresses/addresses_logic.dart';
import 'package:amole/features/orders/orders_provider.dart';
import 'package:amole/models/order.dart';
import 'package:amole/models/saved_address.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class _FakeOrdersRepository implements OrdersRepository {
  _FakeOrdersRepository(this.stored);

  List<Order> stored;
  int saves = 0;

  @override
  List<Order> load() => stored;

  @override
  Future<void> save(List<Order> orders) async {
    stored = orders;
    saves++;
  }
}

Future<SharedPreferences> _prefs() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

void main() {
  group('local repositories', () {
    test('orders round trip and start empty', () async {
      final repo = LocalOrdersRepository(await _prefs());
      expect(repo.load(), isEmpty);
      await repo.save([_order('SIM-1')]);
      expect(repo.load().single.id, 'SIM-1');
    });

    test('addresses round trip and start empty', () async {
      final repo = LocalAddressesRepository(await _prefs());
      expect(repo.load().addresses, isEmpty);
      const a = SavedAddress(
        id: 'a',
        label: 'Home',
        name: 'Abebe Kebede',
        phone: '+251911223344',
        subCity: 'Bole',
        address: 'Near Edna Mall',
      );
      await repo.save(addAddress(const AddressBook(), a));
      expect(repo.load().selected?.id, 'a');
    });

    test('favorites round trip and start empty', () async {
      final repo = LocalFavoritesRepository(await _prefs());
      expect(repo.load(), isEmpty);
      await repo.save({'tibs', 'kitfo'});
      expect(repo.load(), {'tibs', 'kitfo'});
    });
  });

  group('not connected stand-ins', () {
    test('auth never signs anyone in', () async {
      const auth = NotConnectedAuthRepository();
      expect(auth.isConnected, isFalse);
      expect(auth.currentUser, isNull);
      expect(
        await auth.signIn(email: 'a@b.co', password: 'x'),
        isA<NotAvailable<AuthUser>>(),
      );
      expect(
        await auth.signUp(email: 'a@b.co', password: 'x', name: 'A B'),
        isA<NotAvailable<AuthUser?>>(),
      );
      expect(
        await auth.requestPasswordReset(email: 'a@b.co'),
        isA<NotAvailable<void>>(),
      );
      expect(await auth.signOut(), isA<NotAvailable<void>>());
      expect(await auth.authChanges.isEmpty, isTrue);
    });

    test('payments never report a payment as started or paid', () async {
      const pay = NotConnectedPaymentRepository();
      final started = await pay.startPayment(
        orderId: 'SIM-1',
        method: PaymentMethod.telebirr,
        amountSantim: 68500,
      );
      expect(started, isA<NotAvailable<PaymentStatus>>());
      expect(
        await pay.paymentStatus('SIM-1'),
        isA<NotAvailable<PaymentStatus>>(),
      );
    });

    test('without a backend the providers hand out the stand-ins', () async {
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(backendEnabledProvider), isFalse);
      expect(c.read(authRepositoryProvider), isA<NotConnectedAuthRepository>());
      expect(
        c.read(paymentRepositoryProvider),
        isA<NotConnectedPaymentRepository>(),
      );
    });
  });

  test('the orders notifier uses whatever repository is provided', () async {
    final fake = _FakeOrdersRepository([_order('SIM-1')]);
    final c = ProviderContainer(
      overrides: [ordersRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(c.dispose);

    expect(c.read(ordersProvider).single.id, 'SIM-1');
    expect(c.read(ordersProvider.notifier).advance('SIM-1'), isTrue);
    await Future<void>.delayed(Duration.zero);

    expect(fake.saves, 1);
    expect(fake.stored.single.status, OrderStatus.confirmed);
  });
}
