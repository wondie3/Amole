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

  testWidgets('category filter shows an empty state when nothing matches', (
    tester,
  ) async {
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
    expect(find.text('Search is on its way'), findsOneWidget);

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
}
