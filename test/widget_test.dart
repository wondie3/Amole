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
  testWidgets('starts on Home with branding and four tabs', (tester) async {
    await _pumpApp(tester);

    expect(find.text('Amole'), findsOneWidget);
    expect(find.text('Good food, delivered.'), findsOneWidget);
    expect(find.text('Home is on its way'), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
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
    expect(find.text('Home is on its way'), findsOneWidget);
  });

  testWidgets('placeholders state their milestone honestly', (tester) async {
    await _pumpApp(tester);

    expect(
      find.text('Planned for Milestone 2. Not functional yet.'),
      findsOneWidget,
    );
  });
}
