import 'package:amole/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: AmoleApp()));
  await tester.pumpAndSettle();
}

Finder _navLabel(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

Future<void> _openSearch(WidgetTester tester) async {
  // Tall test screen so every lazily built list row is on screen.
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await _pumpApp(tester);
  await tester.tap(_navLabel('Search'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Home shows branding, sections and sample dishes', (
    tester,
  ) async {
    await _pumpApp(tester);

    expect(find.text('Amole'), findsOneWidget);
    expect(find.text('Good food, delivered.'), findsOneWidget);
    expect(find.text('Popular dishes'), findsOneWidget);
    expect(find.text('Featured restaurants'), findsOneWidget);
    expect(find.text('Tibs'), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
  });

  testWidgets('Home category filter shows an empty state', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Breakfast'));
    await tester.pumpAndSettle();
    expect(find.text('No dishes in this category yet.'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
    await tester.pumpAndSettle();
    expect(find.text('Tibs'), findsOneWidget);
  });

  testWidgets('bottom navigation switches between tabs', (tester) async {
    await _pumpApp(tester);

    await tester.tap(_navLabel('Search'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    await tester.tap(_navLabel('Cart'));
    await tester.pumpAndSettle();
    expect(find.text('Cart is on its way'), findsOneWidget);

    await tester.tap(_navLabel('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Profile is on its way'), findsOneWidget);

    await tester.tap(_navLabel('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Popular dishes'), findsOneWidget);
  });

  testWidgets('Search filters dishes, shows empty state and clears', (
    tester,
  ) async {
    await _openSearch(tester);
    expect(find.text('Doro wat'), findsOneWidget);
    expect(find.text('Tibs'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'tibs');
    await tester.pumpAndSettle();
    expect(find.text('Tibs'), findsOneWidget);
    expect(find.text('Doro wat'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Nothing matches your search or filter.'), findsOneWidget);

    await tester.tap(find.text('Clear search and filters'));
    await tester.pumpAndSettle();
    expect(find.text('Doro wat'), findsOneWidget);
  });

  testWidgets('Search restaurants opens a restaurant menu', (tester) async {
    await _openSearch(tester);

    await tester.tap(find.text('Restaurants'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Meskel Kitchen'));
    await tester.pumpAndSettle();

    expect(find.text('Menu'), findsOneWidget);
    expect(find.text('Doro wat'), findsOneWidget);
  });

  testWidgets('A restaurant without dishes says the menu is coming', (
    tester,
  ) async {
    await _openSearch(tester);

    await tester.tap(find.text('Restaurants'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gursha Corner'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Menu coming soon'), findsOneWidget);
  });
}
