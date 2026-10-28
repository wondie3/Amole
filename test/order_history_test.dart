import 'package:amole/app.dart';
import 'package:amole/data/preferences_provider.dart';
import 'package:amole/features/orders/orders_logic.dart';
import 'package:amole/features/orders/orders_provider.dart';
import 'package:amole/models/order.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _saved = Order(
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
      spiceLabel: 'Spicy',
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

Future<void> _pump(WidgetTester tester, Map<String, Object> initial) async {
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
}

Finder _navLabel(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

Future<void> _openProfile(WidgetTester tester) async {
  await tester.tap(_navLabel('Profile'));
  await tester.pumpAndSettle();
}

Future<void> _openHistory(WidgetTester tester) async {
  await _openProfile(tester);
  await tester.tap(find.text('Order history'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Empty history shows a clear empty state', (tester) async {
    await _pump(tester, {});
    await _openProfile(tester);
    expect(find.text('No demo orders yet'), findsOneWidget);

    await tester.tap(find.text('Order history'));
    await tester.pumpAndSettle();
    expect(find.text('No orders yet'), findsOneWidget);
    expect(find.text('Clear history'), findsNothing);
  });

  testWidgets('Saved orders are listed after a restart and open details', (
    tester,
  ) async {
    await _pump(tester, {
      OrdersNotifier.storageKey: encodeOrders([_saved]),
    });
    await _openProfile(tester);
    expect(find.text('1 demo order saved on this phone'), findsOneWidget);

    await tester.tap(find.text('Order history'));
    await tester.pumpAndSettle();
    expect(find.text('Sheger Grill'), findsOneWidget);
    expect(find.textContaining('2 items'), findsOneWidget);
    expect(find.textContaining('ETB 685'), findsOneWidget);
    expect(find.text('Reference SIM-ABC'), findsOneWidget);

    await tester.tap(find.text('Sheger Grill'));
    await tester.pumpAndSettle();
    expect(find.text('Order details'), findsOneWidget);
    expect(find.text('2 × Tibs (Spicy)'), findsOneWidget);
    expect(
      find.text('Contact details are not saved on this phone.'),
      findsOneWidget,
    );
  });

  testWidgets('Clearing history asks first and then shows the empty state', (
    tester,
  ) async {
    await _pump(tester, {
      OrdersNotifier.storageKey: encodeOrders([_saved]),
    });
    await _openHistory(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Clear history'));
    await tester.pumpAndSettle();
    expect(find.text('Clear order history?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Sheger Grill'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Clear history'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Clear history'));
    await tester.pumpAndSettle();
    expect(find.text('No orders yet'), findsOneWidget);
  });
}
