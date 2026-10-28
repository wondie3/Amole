import 'package:amole/app.dart';
import 'package:amole/data/preferences_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  // Tall test screen so every lazily built list row is on screen.
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
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

/// Adds one Tibs (ETB 320 + ETB 45 delivery = ETB 365) and opens checkout.
Future<void> _goToCheckout(WidgetTester tester) async {
  await _pumpApp(tester);
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
}

void main() {
  testWidgets('Checkout shows validation messages for an empty form', (
    tester,
  ) async {
    await _goToCheckout(tester);
    expect(find.textContaining('Demo checkout'), findsOneWidget);

    await tester.tap(
      find.widgetWithText(FilledButton, 'Place demo order · ETB 365'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Enter your full name'), findsOneWidget);
    expect(find.text('Enter your phone number'), findsOneWidget);
    expect(find.text('Choose your sub-city'), findsOneWidget);
    expect(find.text('Enter your street or area'), findsOneWidget);
  });

  testWidgets('Mobile money options are listed but disabled', (tester) async {
    await _goToCheckout(tester);

    expect(find.text('Telebirr'), findsOneWidget);
    expect(find.text('CBE Birr'), findsOneWidget);
    expect(find.text('Mobile money (not connected)'), findsNWidgets(2));
    expect(find.text('Cash on delivery'), findsOneWidget);
  });

  testWidgets('A valid form places a simulated order and clears the cart', (
    tester,
  ) async {
    await _goToCheckout(tester);

    await tester.enterText(
      find.byKey(const Key('checkout_name')),
      'Abebe Kebede',
    );
    await tester.enterText(
      find.byKey(const Key('checkout_phone')),
      '0911 22 33 44',
    );
    await tester.tap(find.widgetWithText(ChoiceChip, 'Bole'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('checkout_address')),
      'Near Edna Mall',
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(FilledButton, 'Place demo order · ETB 365'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Demo order placed'), findsOneWidget);
    expect(find.textContaining('This is a simulated order'), findsOneWidget);
    expect(find.text('+251911223344'), findsOneWidget);

    await tester.tap(find.text('Back to Home'));
    await tester.pumpAndSettle();
    expect(find.text('Popular dishes'), findsOneWidget);

    await tester.tap(_navLabel('Cart'));
    await tester.pumpAndSettle();
    expect(find.text('Your cart is empty'), findsOneWidget);
  });
}
