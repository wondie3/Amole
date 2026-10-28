import 'dart:convert';

import 'package:amole/data/preferences_provider.dart';
import 'package:amole/features/addresses/addresses_logic.dart';
import 'package:amole/features/addresses/addresses_provider.dart';
import 'package:amole/features/cart/cart_logic.dart';
import 'package:amole/features/cart/cart_provider.dart';
import 'package:amole/features/favorites/favorites_provider.dart';
import 'package:amole/features/orders/orders_logic.dart';
import 'package:amole/features/orders/orders_provider.dart';
import 'package:amole/features/settings/local_data.dart';
import 'package:amole/models/cart_line.dart';
import 'package:amole/models/order.dart';
import 'package:amole/models/saved_address.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

SavedAddress _addr(String id, {String label = 'Home'}) => SavedAddress(
  id: id,
  label: label,
  name: 'Abebe Kebede',
  phone: '+251911223344',
  subCity: 'Bole',
  address: 'Near Edna Mall',
  landmark: 'Blue gate',
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
  group('address book logic', () {
    test('adding selects the new address', () {
      var book = addAddress(const AddressBook(), _addr('a'));
      expect(book.addresses.length, 1);
      expect(book.selected?.id, 'a');
      book = addAddress(book, _addr('b', label: 'Work'));
      expect(book.addresses.length, 2);
      expect(book.selected?.id, 'b');
    });

    test('duplicate ids and the limit are refused', () {
      final book = addAddress(const AddressBook(), _addr('a'));
      expect(identical(addAddress(book, _addr('a')), book), isTrue);

      var full = const AddressBook();
      for (var i = 0; i < maxSavedAddresses; i++) {
        full = addAddress(full, _addr('id$i'));
      }
      expect(full.addresses.length, maxSavedAddresses);
      expect(identical(addAddress(full, _addr('extra')), full), isTrue);
    });

    test('update replaces an address in place', () {
      var book = addAddress(const AddressBook(), _addr('a'));
      book = updateAddress(book, _addr('a', label: 'Office'));
      expect(book.addresses.length, 1);
      expect(book.addresses.first.label, 'Office');
    });

    test('deleting the selected address falls back to the first', () {
      var book = addAddress(const AddressBook(), _addr('a'));
      book = addAddress(book, _addr('b', label: 'Work'));
      expect(book.selected?.id, 'b');
      book = deleteAddress(book, 'b');
      expect(book.selected?.id, 'a');
      book = deleteAddress(book, 'a');
      expect(book.selected, isNull);
      expect(book.addresses, isEmpty);
    });

    test('select ignores unknown ids', () {
      final book = addAddress(const AddressBook(), _addr('a'));
      expect(selectAddress(book, 'ghost').selected?.id, 'a');
    });

    test('label validation', () {
      expect(validateLabel(' '), isNotNull);
      expect(validateLabel('Home'), isNull);
      expect(validateLabel('x' * 21), isNotNull);
    });
  });

  group('saving and loading', () {
    test('round trip keeps fields and the selection', () {
      var book = addAddress(const AddressBook(), _addr('a'));
      book = addAddress(book, _addr('b', label: 'Work'));
      book = selectAddress(book, 'a');
      final back = decodeAddressBook(encodeAddressBook(book));
      expect(back.addresses.length, 2);
      expect(back.selected?.id, 'a');
      expect(back.addresses.last.label, 'Work');
      expect(back.addresses.first.phone, '+251911223344');
      expect(back.addresses.first.landmark, 'Blue gate');
    });

    test('empty or missing data gives an empty book', () {
      expect(decodeAddressBook(null).addresses, isEmpty);
      expect(decodeAddressBook('').addresses, isEmpty);
      expect(decodeAddressBook('{}').addresses, isEmpty);
      expect(decodeAddressBook('[]').addresses, isEmpty);
    });

    test('bad data gives an empty book instead of crashing', () {
      expect(decodeAddressBook('not json').addresses, isEmpty);
    });

    test('malformed and duplicate entries are skipped', () {
      final raw = jsonEncode({
        'selected': 'ghost',
        'items': [
          _addr('a').toJson(),
          {'id': 'x'},
          5,
          _addr('a').toJson(),
        ],
      });
      final book = decodeAddressBook(raw);
      expect(book.addresses.length, 1);
      expect(book.selected?.id, 'a');
    });
  });

  group('addresses provider', () {
    test('starts empty when nothing is saved', () async {
      final c = _container(await _prefs());
      expect(c.read(addressesProvider).addresses, isEmpty);
    });

    test('added addresses survive a restart', () async {
      final prefs = await _prefs();
      final c = _container(prefs);
      expect(c.read(addressesProvider.notifier).add(_addr('a')), isTrue);
      await Future<void>.delayed(Duration.zero);

      final restored = _container(prefs).read(addressesProvider);
      expect(restored.addresses.length, 1);
      expect(restored.selected?.address, 'Near Edna Mall');
    });

    test('update, select and delete are saved', () async {
      final prefs = await _prefs();
      final c = _container(prefs);
      final n = c.read(addressesProvider.notifier);
      n.add(_addr('a'));
      n.add(_addr('b', label: 'Work'));
      n.select('a');
      n.update(_addr('a', label: 'Office'));
      n.delete('b');
      await Future<void>.delayed(Duration.zero);

      final restored = _container(prefs).read(addressesProvider);
      expect(restored.addresses.length, 1);
      expect(restored.selected?.label, 'Office');
    });

    test('the limit is enforced by the provider', () async {
      final c = _container(await _prefs());
      final n = c.read(addressesProvider.notifier);
      for (var i = 0; i < maxSavedAddresses; i++) {
        expect(n.add(_addr('id$i')), isTrue);
      }
      expect(n.add(_addr('extra')), isFalse);
      expect(c.read(addressesProvider).addresses.length, maxSavedAddresses);
    });
  });

  test('clear local data removes everything saved', () async {
    final order = Order(
      id: 'SIM-1',
      createdAt: DateTime.utc(2026, 10, 28),
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
    final prefs = await _prefs({
      FavoritesNotifier.storageKey: <String>['tibs'],
      CartNotifier.storageKey: encodeCart(const [
        CartLine(dishId: 'tibs', quantity: 2),
      ]),
      OrdersNotifier.storageKey: encodeOrders([order]),
      AddressesNotifier.storageKey: encodeAddressBook(
        addAddress(const AddressBook(), _addr('a')),
      ),
    });
    final c = _container(prefs);
    expect(c.read(favoritesProvider), isNotEmpty);
    expect(c.read(cartProvider), isNotEmpty);
    expect(c.read(ordersProvider), isNotEmpty);
    expect(c.read(addressesProvider).addresses, isNotEmpty);

    await c.read(clearLocalDataProvider)();

    expect(c.read(favoritesProvider), isEmpty);
    expect(c.read(cartProvider), isEmpty);
    expect(c.read(ordersProvider), isEmpty);
    expect(c.read(addressesProvider).addresses, isEmpty);
    expect(prefs.getStringList(FavoritesNotifier.storageKey), isNull);
    expect(prefs.getString(CartNotifier.storageKey), isNull);
    expect(prefs.getString(OrdersNotifier.storageKey), isNull);
    expect(prefs.getString(AddressesNotifier.storageKey), isNull);
  });
}
