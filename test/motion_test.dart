import 'package:amole/app.dart';
import 'package:amole/data/preferences_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Key _splash = Key('splash_overlay');

Future<void> _start(WidgetTester tester) async {
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
}

Finder _navLabel(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

void main() {
  testWidgets('the opening animation plays once, then Home is usable', (
    tester,
  ) async {
    await _start(tester);
    await tester.pump();
    expect(find.byKey(_splash), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.byKey(_splash), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byKey(_splash), findsNothing);
    expect(find.text('Popular dishes'), findsOneWidget);

    await tester.tap(_navLabel('Search'));
    await tester.pumpAndSettle();
    await tester.tap(_navLabel('Home'));
    await tester.pumpAndSettle();
    expect(find.byKey(_splash), findsNothing);
    expect(find.text('Popular dishes'), findsOneWidget);
  });

  testWidgets('reduced motion skips the opening animation', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await _start(tester);
    await tester.pump();
    expect(find.byKey(_splash), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('Popular dishes'), findsOneWidget);
  });
}
