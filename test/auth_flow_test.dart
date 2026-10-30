import 'dart:async';

import 'package:amole/app.dart';
import 'package:amole/data/preferences_provider.dart';
import 'package:amole/data/repositories/auth_repository.dart';
import 'package:amole/data/repositories/result.dart';
import 'package:amole/data/repository_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _goodPassword = 'correct horse battery';
const String _badPassword = 'wrong-password-123';

class _FakeAuth implements AuthRepository {
  final StreamController<AuthUser?> _controller =
      StreamController<AuthUser?>.broadcast();
  AuthUser? _user;

  @override
  bool get isConnected => true;

  @override
  AuthUser? get currentUser => _user;

  @override
  Stream<AuthUser?> get authChanges => _controller.stream;

  @override
  Future<Result<AuthUser?>> signUp({
    required String email,
    required String password,
    required String name,
  }) async => const Ok<AuthUser?>(null);

  @override
  Future<Result<AuthUser>> signIn({
    required String email,
    required String password,
  }) async {
    if (password == _badPassword) {
      return const Failure<AuthUser>('Email or password is incorrect.');
    }
    _user = AuthUser(id: 'u1', email: email.trim(), name: 'Abebe Kebede');
    _controller.add(_user);
    return Ok<AuthUser>(_user!);
  }

  @override
  Future<Result<void>> requestPasswordReset({required String email}) async =>
      const Ok<void>(null);

  @override
  Future<Result<void>> signOut() async {
    _user = null;
    _controller.add(null);
    return const Ok<void>(null);
  }

  Future<void> close() => _controller.close();
}

Future<void> _pump(WidgetTester tester, {AuthRepository? auth}) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        if (auth != null) authRepositoryProvider.overrideWithValue(auth),
      ],
      child: const AmoleApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _navLabel(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

Future<void> _openAuth(WidgetTester tester) async {
  await tester.tap(_navLabel('Profile'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Sign in or create account'));
  await tester.pumpAndSettle();
}

Future<void> _fillSignIn(WidgetTester tester, String password) async {
  await tester.enterText(
    find.byKey(const Key('auth_email')),
    'abebe@example.com',
  );
  await tester.enterText(find.byKey(const Key('auth_password')), password);
}

void main() {
  testWidgets('Without a backend, Profile says sign-in is not available', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(_navLabel('Profile'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Sign-in is not available in this build'),
      findsOneWidget,
    );
    expect(find.text('Sign in or create account'), findsNothing);
  });

  testWidgets('Sign-in shows validation messages for an empty form', (
    tester,
  ) async {
    final auth = _FakeAuth();
    addTearDown(auth.close);
    await _pump(tester, auth: auth);
    await _openAuth(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Enter a password'), findsOneWidget);
  });

  testWidgets('A wrong password shows an error and stays on the form', (
    tester,
  ) async {
    final auth = _FakeAuth();
    addTearDown(auth.close);
    await _pump(tester, auth: auth);
    await _openAuth(tester);

    await _fillSignIn(tester, _badPassword);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Email or password is incorrect.'), findsOneWidget);
    expect(find.text('Sign in to Amole'), findsOneWidget);
  });

  testWidgets('Signing in and out updates the Profile account card', (
    tester,
  ) async {
    final auth = _FakeAuth();
    addTearDown(auth.close);
    await _pump(tester, auth: auth);
    await _openAuth(tester);

    await _fillSignIn(tester, _goodPassword);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Signed in'), findsOneWidget);
    expect(find.text('abebe@example.com'), findsOneWidget);
    expect(find.text('Sign in or create account'), findsNothing);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in or create account'), findsOneWidget);
    expect(find.text('Signed in'), findsNothing);
  });

  testWidgets('Creating an account asks to verify the email', (tester) async {
    final auth = _FakeAuth();
    addTearDown(auth.close);
    await _pump(tester, auth: auth);
    await _openAuth(tester);

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('auth_name')), 'Abebe Kebede');
    await tester.enterText(
      find.byKey(const Key('auth_email')),
      'abebe@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('auth_password')),
      _goodPassword,
    );
    await tester.enterText(
      find.byKey(const Key('auth_confirm')),
      _goodPassword,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Check your email'), findsOneWidget);
  });

  testWidgets('Sign-up rejects short or mismatched passwords', (tester) async {
    final auth = _FakeAuth();
    addTearDown(auth.close);
    await _pump(tester, auth: auth);
    await _openAuth(tester);

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('auth_password')), 'short');
    await tester.enterText(find.byKey(const Key('auth_confirm')), 'different');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Use at least 10 characters'), findsOneWidget);
    expect(find.text('Passwords do not match'), findsOneWidget);
  });

  testWidgets('Password reset never reveals whether an account exists', (
    tester,
  ) async {
    final auth = _FakeAuth();
    addTearDown(auth.close);
    await _pump(tester, auth: auth);
    await _openAuth(tester);

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('auth_email')),
      'nobody@example.com',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Send reset link'));
    await tester.pumpAndSettle();

    expect(find.textContaining('If an account exists'), findsOneWidget);
  });
}
