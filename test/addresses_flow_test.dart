import 'package:amole/app.dart';
import 'package:amole/data/preferences_provider.dart';
import 'package:amole/features/addresses/addresses_logic.dart';
import 'package:amole/features/addresses/addresses_provider.dart';
import 'package:amole/features/orders/orders_logic.dart';
import 'package:amole/features/orders/orders_provider.dart';
import 'package:amole/models/order.dart';
import 'package:amole/models/saved_address.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _home = SavedAddress(
  id: 'a',
  label: 'Home',
  name: 'Abebe Kebede',
  phone: '+251911223344',
  subCity: 'Bole',
  address: 'Near Edna Mall',
);
const _work = SavedAddress(
  id: 'b',
  label: 'Work',
  name: 'Abebe Kebede',
  phone: '+251911223344',
  subCity: 'Kirkos',
  address: 'Meskel Square area',
);

final _savedOrder = Order(
  id: 'SIM-ABC',
  createdAt: DateTime.utc(2026, 10, 28, 9, 30),
  restaurantId: 'sheger_grill',
  restaurantName: 'Sheger Grill',
  items: const [
    OrderItem(
      dishId: 'tibs',
      name: 'Tibs',
      unitPriceSantim: 32000,
      quantity: 2,
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

Future<SharedPreferences> _pump(
  WidgetTester tester,
  Map<String, Object> initial,
) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const AmoleApp(),
    ),
  );
  await tester.pumpAndSettle();
  return prefs;
}

Finder _navLabel(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

Future<void> _openProfile(WidgetTester tester) async {
  await tester.tap(_navLabel('Profile'));
  await tester.pumpAndSettle();
}

Future<void> _openAddressBook(WidgetTester tester) async {
  await _openProfile(tester);
  await tester.tap(find.text('Saved addresses'));
  await tester.pumpAndSettle();
}

Map<String, Object> _twoAddresses() => {
  AddressesNotifier.storageKey: encodeAddressBook(
    const AddressBook(addresses: [_home, _work], selectedId: 'a'),
  ),
};

void main() {
  testWidgets('Saved addresses starts empty and can add an address', (
    tester,
  ) async {
    await _pump(tester, {});
    await _openProfile(tester);
    expect(find.text('No saved addresses'), findsOneWidget);

    await tester.tap(find.text('Saved addresses'));
    await tester.pumpAndSettle();
    expect(find.text('No saved addresses yet'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Add address'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('address_label')), 'Home');
    await tester.enterText(
      find.byKey(const Key('address_name')),
      'Abebe Kebede',
    );
    await tester.enterText(
      find.byKey(const Key('address_phone')),
      '0911 22 33 44',
    );
    await tester.tap(find.widgetWithText(ChoiceChip, 'Bole'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('address_street')),
      'Near Edna Mall',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save address'));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Near Edna Mall, Bole'), findsOneWidget);
    expect(find.textContaining('+251911223344'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('1 saved address'), findsOneWidget);
  });

  testWidgets('The address form shows validation messages', (tester) async {
    await _pump(tester, {});
    await _openAddressBook(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Add address'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Save address'));
    await tester.pumpAndSettle();
    expect(find.text('Give this address a name, like Home'), findsOneWidget);
    expect(find.text('Enter your full name'), findsOneWidget);
    expect(find.text('Enter your phone number'), findsOneWidget);
    expect(find.text('Choose your sub-city'), findsOneWidget);
    expect(find.text('Enter your street or area'), findsOneWidget);
  });

  testWidgets('Editing and deleting a saved address', (tester) async {
    await _pump(tester, _twoAddresses());
    await _openAddressBook(tester);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete Work'));
    await tester.pumpAndSettle();
    expect(find.text('Delete address?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Work'), findsNothing);

    await tester.tap(find.byTooltip('Edit Home'));
    await tester.pumpAndSettle();
    expect(find.text('Edit address'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('address_label')), 'Home 2');
    await tester.tap(find.widgetWithText(FilledButton, 'Save address'));
    await tester.pumpAndSettle();
    expect(find.text('Home 2'), findsOneWidget);
  });

  testWidgets('The Home location pill shows and switches the address', (
    tester,
  ) async {
    await _pump(tester, _twoAddresses());
    expect(find.text('Home · Bole'), findsOneWidget);

    await tester.tap(find.text('Home · Bole'));
    await tester.pumpAndSettle();
    expect(find.text('Add new address'), findsOneWidget);
    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();
    expect(find.text('Work · Kirkos'), findsOneWidget);
  });

  testWidgets('Home asks for an address when none is saved', (tester) async {
    await _pump(tester, {});
    expect(find.text('Add a delivery address'), findsOneWidget);
  });

  testWidgets('Checkout is prefilled from the selected address', (
    tester,
  ) async {
    await _pump(tester, _twoAddresses());

    await tester.tap(_navLabel('Search'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tibs'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to cart · ETB 320'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('View cart'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Checkout · ETB 365'));
    await tester.pumpAndSettle();

    String fieldText(String key) =>
        tester.widget<TextFormField>(find.byKey(Key(key))).controller!.text;
    expect(fieldText('checkout_name'), 'Abebe Kebede');
    expect(fieldText('checkout_phone'), '+251911223344');
    expect(fieldText('checkout_address'), 'Near Edna Mall');

    await tester.tap(
      find.widgetWithText(FilledButton, 'Place demo order · ETB 365'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Demo order placed'), findsOneWidget);
  });

  testWidgets('Clear local data asks first, then removes saved data', (
    tester,
  ) async {
    final initial = <String, Object>{
      ..._twoAddresses(),
      OrdersNotifier.storageKey: encodeOrders([_savedOrder]),
    };
    final prefs = await _pump(tester, initial);

    await _openProfile(tester);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('About Amole'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Clear local data'));
    await tester.pumpAndSettle();
    expect(find.text('Clear all local data?'), findsOneWidget);
    expect(find.textContaining('2 saved addresses'), findsOneWidget);
    expect(find.textContaining('1 demo order'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(prefs.getString(AddressesNotifier.storageKey), isNotNull);
    expect(prefs.getString(OrdersNotifier.storageKey), isNotNull);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Clear local data'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Clear local data'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));

    expect(prefs.getString(AddressesNotifier.storageKey), isNull);
    expect(prefs.getString(OrdersNotifier.storageKey), isNull);
    expect(find.text('Local data cleared.'), findsOneWidget);
  });
}
