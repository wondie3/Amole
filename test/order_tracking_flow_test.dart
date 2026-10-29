import 'package:amole/app.dart';
import 'package:amole/data/preferences_provider.dart';
import 'package:amole/features/orders/orders_logic.dart';
import 'package:amole/features/orders/orders_provider.dart';
import 'package:amole/models/order.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

CancellationRequest _pending() => CancellationRequest(
  status: CancellationRequestStatus.pending,
  requestedAt: DateTime.utc(2026, 10, 28, 9, 33),
);

Order _saved({
  OrderStatus status = OrderStatus.placed,
  int? etaMin = 20,
  int? etaMax = 30,
  CancellationRequest? request,
}) => Order(
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
  status: status,
  etaMinMinutes: etaMin,
  etaMaxMinutes: etaMax,
  cancellationRequest: request,
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

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('A placed order shows the timeline and direct cancel', (
    tester,
  ) async {
    await _openDetail(tester, _saved());

    expect(find.text('Placed · Simulated'), findsOneWidget);
    expect(find.textContaining('Simulated tracking'), findsOneWidget);
    expect(find.text('Ready for pickup'), findsOneWidget);
    expect(
      find.textContaining('Estimated delivery (simulated)'),
      findsOneWidget,
    );
    expect(find.text('Simulate next step: Confirmed'), findsOneWidget);
    expect(find.text('Cancel order'), findsOneWidget);
    expect(find.text('Request cancellation'), findsNothing);
  });

  testWidgets('Stepping through every status reaches Delivered', (
    tester,
  ) async {
    await _openDetail(tester, _saved());

    await _tap(tester, 'Simulate next step: Confirmed');
    expect(find.text('Confirmed · Simulated'), findsOneWidget);
    expect(find.text('Cancel order'), findsNothing);
    expect(find.text('Request cancellation'), findsOneWidget);

    await _tap(tester, 'Simulate next step: Preparing');
    expect(find.text('Preparing · Simulated'), findsOneWidget);
    expect(find.text('Request cancellation'), findsOneWidget);

    await _tap(tester, 'Simulate next step: Ready for pickup');
    expect(find.text('Ready for pickup · Simulated'), findsOneWidget);
    expect(find.text('Request cancellation'), findsOneWidget);

    await _tap(tester, 'Simulate next step: Out for delivery');
    expect(find.text('Out for delivery · Simulated'), findsOneWidget);
    expect(find.text('Request cancellation'), findsNothing);
    expect(find.text('Cancel order'), findsNothing);

    await _tap(tester, 'Simulate next step: Delivered');
    expect(find.text('Delivered · Simulated'), findsOneWidget);
    expect(find.textContaining('Simulate next step:'), findsNothing);
    expect(find.textContaining('Estimated delivery'), findsNothing);
  });

  testWidgets('Cancelling a placed order asks first', (tester) async {
    await _openDetail(tester, _saved());

    await _tap(tester, 'Cancel order');
    expect(find.text('Cancel this order?'), findsOneWidget);

    await _tap(tester, 'Keep order');
    expect(find.text('Placed · Simulated'), findsOneWidget);

    await _tap(tester, 'Cancel order');
    await tester.tap(find.widgetWithText(FilledButton, 'Yes, cancel order'));
    await tester.pumpAndSettle();

    expect(find.text('Cancelled · Simulated'), findsOneWidget);
    expect(find.textContaining('Simulate next step:'), findsNothing);
    expect(find.text('Cancel order'), findsNothing);
  });

  testWidgets('A confirmed order asks the restaurant instead of cancelling', (
    tester,
  ) async {
    await _openDetail(tester, _saved(status: OrderStatus.confirmed));

    await _tap(tester, 'Request cancellation');
    expect(find.text('Request cancellation?'), findsOneWidget);

    await _tap(tester, 'Keep order');
    expect(find.text('Cancellation requested'), findsNothing);

    await _tap(tester, 'Request cancellation');
    await tester.tap(find.widgetWithText(FilledButton, 'Send request'));
    await tester.pumpAndSettle();

    expect(find.text('Cancellation requested'), findsOneWidget);
    expect(find.text('Confirmed · Simulated'), findsOneWidget);
    expect(find.text('Request cancellation'), findsNothing);
    expect(find.text('Withdraw request'), findsOneWidget);
  });

  testWidgets('A declined request leaves the order as it was', (tester) async {
    await _openDetail(
      tester,
      _saved(status: OrderStatus.preparing, request: _pending()),
    );

    await _tap(tester, 'Simulate: restaurant declines');

    expect(find.text('Cancellation declined'), findsOneWidget);
    expect(find.textContaining('Reason:'), findsOneWidget);
    expect(find.text('Preparing · Simulated'), findsOneWidget);
    expect(find.text('Request cancellation'), findsNothing);
    expect(find.text('Withdraw request'), findsNothing);
  });

  testWidgets('An accepted request cancels the order', (tester) async {
    await _openDetail(
      tester,
      _saved(status: OrderStatus.ready, request: _pending()),
    );

    await _tap(tester, 'Simulate: restaurant accepts');

    expect(find.text('Cancellation accepted'), findsOneWidget);
    expect(find.text('Cancelled · Simulated'), findsOneWidget);
    expect(find.textContaining('Simulate next step:'), findsNothing);
  });

  testWidgets('A pending request can be withdrawn and asked again', (
    tester,
  ) async {
    await _openDetail(
      tester,
      _saved(status: OrderStatus.confirmed, request: _pending()),
    );
    expect(find.text('Cancellation requested'), findsOneWidget);

    await _tap(tester, 'Withdraw request');
    expect(find.text('Cancellation requested'), findsNothing);
    expect(find.text('Request cancellation'), findsOneWidget);
  });

  testWidgets('An order out for delivery has no cancel buttons', (
    tester,
  ) async {
    await _openDetail(tester, _saved(status: OrderStatus.outForDelivery));

    expect(find.text('Cancel order'), findsNothing);
    expect(find.text('Request cancellation'), findsNothing);
    expect(find.text('Simulate next step: Delivered'), findsOneWidget);
  });

  testWidgets('An order without a saved estimate says so', (tester) async {
    await _openDetail(tester, _saved(etaMin: null, etaMax: null));
    expect(find.textContaining('not recorded'), findsOneWidget);
    expect(find.text('Simulate next step: Confirmed'), findsOneWidget);
  });
}
