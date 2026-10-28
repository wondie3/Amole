import 'package:amole/app.dart';
import 'package:amole/data/preferences_provider.dart';
import 'package:amole/features/orders/orders_logic.dart';
import 'package:amole/features/orders/orders_provider.dart';
import 'package:amole/models/order.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Order _saved({int? etaMin = 20, int? etaMax = 30}) => Order(
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
  etaMinMinutes: etaMin,
  etaMaxMinutes: etaMax,
);

Finder _navLabel(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

Future<void> _openDetail(WidgetTester tester, Order order) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({
    OrdersNotifier.storageKey: encodeOrders([order]),
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const AmoleApp(),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(_navLabel('Profile'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Order history'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Sheger Grill'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Details show the simulated timeline and actions', (
    tester,
  ) async {
    await _openDetail(tester, _saved());

    expect(find.text('Placed · Simulated'), findsOneWidget);
    expect(find.textContaining('Simulated tracking'), findsOneWidget);
    expect(find.text('Confirmed'), findsOneWidget);
    expect(find.text('Delivered'), findsOneWidget);
    expect(
      find.textContaining('Estimated delivery (simulated)'),
      findsOneWidget,
    );
    expect(find.text('Simulate next step: Confirmed'), findsOneWidget);
    expect(find.text('Cancel order'), findsOneWidget);
  });

  testWidgets('Simulating steps reaches Delivered and removes the buttons', (
    tester,
  ) async {
    await _openDetail(tester, _saved());

    await tester.tap(find.text('Simulate next step: Confirmed'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmed · Simulated'), findsOneWidget);
    expect(find.text('Cancel order'), findsOneWidget);

    await tester.tap(find.text('Simulate next step: Preparing'));
    await tester.pumpAndSettle();
    expect(find.text('Preparing · Simulated'), findsOneWidget);
    expect(find.text('Cancel order'), findsNothing);

    await tester.tap(find.text('Simulate next step: Out for delivery'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simulate next step: Delivered'));
    await tester.pumpAndSettle();

    expect(find.text('Delivered · Simulated'), findsOneWidget);
    expect(find.textContaining('Simulate next step:'), findsNothing);
    expect(find.textContaining('Estimated delivery'), findsNothing);
  });

  testWidgets('Cancelling asks first, then marks the order cancelled', (
    tester,
  ) async {
    await _openDetail(tester, _saved());

    await tester.tap(find.text('Cancel order'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel this order?'), findsOneWidget);

    await tester.tap(find.text('Keep order'));
    await tester.pumpAndSettle();
    expect(find.text('Placed · Simulated'), findsOneWidget);

    await tester.tap(find.text('Cancel order'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Yes, cancel order'));
    await tester.pumpAndSettle();

    expect(find.text('Cancelled · Simulated'), findsOneWidget);
    expect(find.textContaining('Simulate next step:'), findsNothing);
    expect(find.text('Cancel order'), findsNothing);
  });

  testWidgets('An order without a saved estimate says so', (tester) async {
    await _openDetail(tester, _saved(etaMin: null, etaMax: null));
    expect(find.textContaining('not recorded'), findsOneWidget);
    expect(find.text('Simulate next step: Confirmed'), findsOneWidget);
  });
}
