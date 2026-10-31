import 'package:amole/app.dart';
import 'package:amole/data/catalog_providers.dart';
import 'package:amole/data/catalog_repository.dart';
import 'package:amole/data/preferences_provider.dart';
import 'package:amole/data/repositories/auth_repository.dart';
import 'package:amole/data/repositories/result.dart';
import 'package:amole/data/repository_providers.dart';
import 'package:amole/features/addresses/addresses_active.dart';
import 'package:amole/features/addresses/addresses_logic.dart';
import 'package:amole/features/addresses/addresses_provider.dart';
import 'package:amole/features/addresses/addresses_remote_logic.dart';
import 'package:amole/models/saved_address.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth implements AuthRepository {
  const _Auth(this.user);

  final AuthUser? user;

  @override
  bool get isConnected => true;

  @override
  AuthUser? get currentUser => user;

  @override
  Stream<AuthUser?> get authChanges => const Stream<AuthUser?>.empty();

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
  }) async => const Failure<AuthUser>('not used');

  @override
  Future<Result<void>> requestPasswordReset({required String email}) async =>
      const Ok<void>(null);

  @override
  Future<Result<void>> signOut() async => const Ok<void>(null);
}

const _signedIn = _Auth(AuthUser(id: 'u1', email: 'abebe@example.com'));

class _FakeSource implements RemoteAddressesSource {
  _FakeSource([List<Map<String, dynamic>>? rows])
    : rows = rows ?? <Map<String, dynamic>>[];

  final List<Map<String, dynamic>> rows;
  Object? failWith;
  bool failFetch = false;
  int? failInsertNumber;
  int fetches = 0;
  int inserts = 0;

  void _maybeFail() {
    final e = failWith;
    if (e != null) {
      failWith = null;
      throw e;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetch() async {
    fetches++;
    if (failFetch) throw const AddressSourceException(code: 'x');
    return [for (final r in rows) Map<String, dynamic>.of(r)];
  }

  @override
  Future<void> insert(Map<String, Object?> row) async {
    _maybeFail();
    inserts++;
    if (failInsertNumber == inserts) {
      throw const AddressSourceException(code: '23514');
    }
    if (rows.length >= maxSavedAddresses) {
      throw const AddressSourceException(
        code: '23514',
        message: 'address_limit_reached',
      );
    }
    rows.add({...row, 'is_selected': false});
  }

  @override
  Future<void> update(String id, Map<String, Object?> values) async {
    _maybeFail();
    final i = rows.indexWhere((r) => r['id'] == id);
    if (i >= 0) rows[i] = {...rows[i], ...values};
  }

  @override
  Future<void> delete(String id) async {
    _maybeFail();
    rows.removeWhere((r) => r['id'] == id);
  }

  @override
  Future<void> select(String id) async {
    _maybeFail();
    for (final r in rows) {
      r['is_selected'] = r['id'] == id;
    }
  }
}

Map<String, dynamic> _row(
  String id, {
  String label = 'Home',
  String street = 'Near Edna Mall',
  String subCity = 'Bole',
  bool selected = false,
}) => {
  'id': id,
  'label': label,
  'contact_name': 'Abebe Kebede',
  'phone': '+251911223344',
  'sub_city': subCity,
  'street': street,
  'landmark': null,
  'is_selected': selected,
};

SavedAddress _local(
  String id, {
  String label = 'Home',
  String street = 'Near Edna Mall',
  String subCity = 'Bole',
}) => SavedAddress(
  id: id,
  label: label,
  name: 'Abebe Kebede',
  phone: '+251911223344',
  subCity: subCity,
  address: street,
);

Future<SharedPreferences> _prefs([
  Map<String, Object> initial = const {},
]) async {
  SharedPreferences.setMockInitialValues(initial);
  return SharedPreferences.getInstance();
}

ProviderContainer _container(
  SharedPreferences prefs,
  _FakeSource source, {
  AuthRepository auth = _signedIn,
}) {
  final c = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      backendEnabledProvider.overrideWithValue(true),
      authRepositoryProvider.overrideWithValue(auth),
      remoteAddressesSourceProvider.overrideWithValue(source),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Map<String, Object> _localBook(List<SavedAddress> list) => {
  AddressesNotifier.storageKey: encodeAddressBook(
    AddressBook(addresses: list, selectedId: list.first.id),
  ),
};

void main() {
  group('mode', () {
    test('signed in with a backend uses the account, not the phone', () async {
      final source = _FakeSource([
        _row('s1'),
        _row('s2', label: 'Work', subCity: 'Kirkos', selected: true),
      ]);
      final c = _container(
        await _prefs(_localBook([_local('l1', street: 'Phone only street')])),
        source,
      );
      await c.read(remoteAddressesProvider.future);
      expect(c.read(addressModeProvider), AddressMode.account);
      final book = c.read(activeAddressesProvider);
      expect(book.addresses.map((a) => a.id), ['s1', 's2']);
      expect(book.selected?.id, 's2');
    });

    test(
      'signed out keeps using the phone and never calls the server',
      () async {
        final source = _FakeSource([_row('s1')]);
        final c = _container(
          await _prefs(_localBook([_local('l1')])),
          source,
          auth: const _Auth(null),
        );
        expect(c.read(addressModeProvider), AddressMode.local);
        expect(c.read(activeAddressesProvider).addresses.single.id, 'l1');
        expect(c.read(addressesStatusProvider), AddressesStatus.ready);
        expect(source.fetches, 0);
      },
    );

    test('a failed first load shows an error, and retry recovers', () async {
      final source = _FakeSource([_row('s1')])..failFetch = true;
      final c = _container(await _prefs(), source);
      try {
        await c.read(remoteAddressesProvider.future);
      } catch (_) {}
      expect(c.read(addressesStatusProvider), AddressesStatus.error);
      expect(c.read(activeAddressesProvider).addresses, isEmpty);

      source.failFetch = false;
      c.invalidate(remoteAddressesProvider);
      await c.read(remoteAddressesProvider.future);
      expect(c.read(addressesStatusProvider), AddressesStatus.ready);
      expect(c.read(activeAddressesProvider).addresses.length, 1);
    });
  });

  group('changes', () {
    test('add inserts a new UUID id and selects the address', () async {
      final source = _FakeSource([_row('s1', selected: true)]);
      final c = _container(await _prefs(), source);
      await c.read(remoteAddressesProvider.future);

      final error = await c
          .read(addressActionsProvider)
          .add(_local('addr-local', label: 'Work', street: 'Another street'));
      expect(error, isNull);
      expect(source.rows.length, 2);
      final created = source.rows.last;
      expect(created['id'], isNot('addr-local'));
      expect(created['is_selected'], isTrue);
      expect(c.read(activeAddressesProvider).selected?.label, 'Work');
    });

    test('the limit is checked before calling the server', () async {
      final source = _FakeSource([
        for (var i = 0; i < maxSavedAddresses; i++)
          _row('s$i', street: 'Street $i'),
      ]);
      final c = _container(await _prefs(), source);
      await c.read(remoteAddressesProvider.future);
      final error = await c.read(addressActionsProvider).add(_local('x'));
      expect(error, addressLimitMessage);
      expect(source.inserts, 0);
    });

    test('update, select and delete reach the server and refresh', () async {
      final source = _FakeSource([_row('s1'), _row('s2', label: 'Work')]);
      final c = _container(await _prefs(), source);
      await c.read(remoteAddressesProvider.future);
      final actions = c.read(addressActionsProvider);

      expect(await actions.update(_local('s1', label: 'Office')), isNull);
      expect(await actions.select('s2'), isNull);
      expect(await actions.delete('s1'), isNull);

      final book = c.read(activeAddressesProvider);
      expect(book.addresses.map((a) => a.id), ['s2']);
      expect(book.selected?.id, 's2');
      expect(source.rows.single['id'], 's2');
    });

    test(
      'a failed change gives a friendly message and keeps the list',
      () async {
        final source = _FakeSource([_row('s1')]);
        final c = _container(await _prefs(), source);
        await c.read(remoteAddressesProvider.future);

        source.failWith = const AddressSourceException(code: '42501');
        final error = await c.read(addressActionsProvider).delete('s1');
        expect(error, addressSignInAgainMessage);
        expect(c.read(activeAddressesProvider).addresses.length, 1);
      },
    );

    test('a server-side limit error maps to the limit message', () async {
      final source = _FakeSource([_row('s1')]);
      final c = _container(await _prefs(), source);
      await c.read(remoteAddressesProvider.future);
      source.failWith = const AddressSourceException(
        code: '23514',
        message: 'address_limit_reached',
      );
      expect(
        await c.read(addressActionsProvider).add(_local('x')),
        addressLimitMessage,
      );
    });

    test('phone addresses are untouched by account changes', () async {
      final initial = _localBook([_local('l1')]);
      final prefs = await _prefs(initial);
      final c = _container(prefs, _FakeSource([_row('s1')]));
      await c.read(remoteAddressesProvider.future);
      final actions = c.read(addressActionsProvider);
      await actions.add(_local('x', street: 'New account street'));
      await actions.delete('s1');
      expect(
        prefs.getString(AddressesNotifier.storageKey),
        initial[AddressesNotifier.storageKey],
      );
    });
  });

  group('copy to account', () {
    test(
      'copies new addresses, skips duplicates, keeps the phone copy',
      () async {
        final locals = [
          _local('l1'),
          _local(
            'l2',
            label: 'Work',
            street: 'Meskel Square area',
            subCity: 'Kirkos',
          ),
        ];
        final initial = _localBook(locals);
        final prefs = await _prefs(initial);
        final source = _FakeSource([_row('s1')]);
        final c = _container(prefs, source);
        await c.read(remoteAddressesProvider.future);

        final report = await c
            .read(remoteAddressesProvider.notifier)
            .copyLocal(locals);
        expect(report.copied, 1);
        expect(report.duplicates, 1);
        expect(report.failed, 0);
        expect(source.rows.length, 2);
        expect(c.read(activeAddressesProvider).addresses.length, 2);
        expect(
          prefs.getString(AddressesNotifier.storageKey),
          initial[AddressesNotifier.storageKey],
        );
      },
    );

    test('copying twice creates no duplicates', () async {
      final locals = [_local('l1'), _local('l2', street: 'Second street')];
      final source = _FakeSource();
      final c = _container(await _prefs(_localBook(locals)), source);
      await c.read(remoteAddressesProvider.future);
      final n = c.read(remoteAddressesProvider.notifier);

      expect((await n.copyLocal(locals)).copied, 2);
      final again = await n.copyLocal(locals);
      expect(again.copied, 0);
      expect(again.duplicates, 2);
      expect(source.rows.length, 2);
    });

    test('the account limit is reported, not exceeded', () async {
      final source = _FakeSource([
        for (var i = 0; i < 9; i++) _row('s$i', street: 'Street $i'),
      ]);
      final locals = [
        _local('l1', street: 'Phone street one'),
        _local('l2', street: 'Phone street two'),
      ];
      final c = _container(await _prefs(_localBook(locals)), source);
      await c.read(remoteAddressesProvider.future);
      final report = await c
          .read(remoteAddressesProvider.notifier)
          .copyLocal(locals);
      expect(report.copied, 1);
      expect(report.overLimit, 1);
      expect(source.rows.length, maxSavedAddresses);
    });

    test('one failed insert does not stop the rest', () async {
      final locals = [
        _local('l1', street: 'First street'),
        _local('l2', street: 'Second street'),
        _local('l3', street: 'Third street'),
      ];
      final source = _FakeSource()..failInsertNumber = 2;
      final c = _container(await _prefs(_localBook(locals)), source);
      await c.read(remoteAddressesProvider.future);
      final report = await c
          .read(remoteAddressesProvider.notifier)
          .copyLocal(locals);
      expect(report.copied, 2);
      expect(report.failed, 1);
      expect(report.firstError, isNotNull);
    });

    test('a server that cannot be reached reports failure', () async {
      final locals = [_local('l1')];
      final source = _FakeSource();
      final c = _container(await _prefs(_localBook(locals)), source);
      await c.read(remoteAddressesProvider.future);
      source.failFetch = true;
      final report = await c
          .read(remoteAddressesProvider.notifier)
          .copyLocal(locals);
      expect(report.copied, 0);
      expect(report.failed, 1);
      expect(source.rows, isEmpty);
    });
  });

  group('screens', () {
    Future<(SharedPreferences, _FakeSource)> pump(
      WidgetTester tester, {
      Map<String, Object> initial = const {},
      List<Map<String, dynamic>> rows = const [],
    }) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final prefs = await _prefs(initial);
      final source = _FakeSource([...rows]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            backendEnabledProvider.overrideWithValue(true),
            authRepositoryProvider.overrideWithValue(_signedIn),
            remoteAddressesSourceProvider.overrideWithValue(source),
            catalogRepositoryProvider.overrideWithValue(
              const MockCatalogRepository(),
            ),
          ],
          child: const AmoleApp(),
        ),
      );
      await tester.pumpAndSettle();
      return (prefs, source);
    }

    Finder navLabel(String label) => find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    );

    testWidgets(
      'signed in with no account addresses, the pill opens the form',
      (tester) async {
        await pump(tester, initial: _localBook([_local('l1')]));
        expect(find.text('Add a delivery address'), findsOneWidget);

        await tester.tap(find.text('Add a delivery address'));
        await tester.pumpAndSettle();
        expect(find.text('Add address'), findsOneWidget);
        expect(find.text('Save address'), findsOneWidget);
      },
    );

    testWidgets('the pill shows the account address', (tester) async {
      await pump(tester, rows: [_row('s1', selected: true)]);
      expect(find.text('Home · Bole'), findsOneWidget);
    });

    testWidgets('copying asks first and reports what happened', (tester) async {
      final locals = [
        _local('l1'),
        _local(
          'l2',
          label: 'Work',
          street: 'Meskel Square area',
          subCity: 'Kirkos',
        ),
      ];
      final initial = _localBook(locals);
      final (prefs, source) = await pump(
        tester,
        initial: initial,
        rows: [_row('s1')],
      );

      await tester.tap(navLabel('Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Saved addresses'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Copy my phone addresses to my account'));
      await tester.pumpAndSettle();
      expect(
        find.text('Copy phone addresses to your account?'),
        findsOneWidget,
      );
      expect(source.rows.length, 1);

      await tester.tap(find.widgetWithText(FilledButton, 'Copy addresses'));
      await tester.pumpAndSettle();
      expect(find.text('Copy finished'), findsOneWidget);
      expect(find.text('Copied: 1'), findsOneWidget);
      expect(find.text('Already in your account (skipped): 1'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'OK'));
      await tester.pumpAndSettle();
      expect(source.rows.length, 2);
      expect(
        prefs.getString(AddressesNotifier.storageKey),
        initial[AddressesNotifier.storageKey],
      );
    });

    testWidgets('cancelling the copy changes nothing', (tester) async {
      final (_, source) = await pump(
        tester,
        initial: _localBook([_local('l1')]),
      );
      await tester.tap(navLabel('Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Saved addresses'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Copy my phone addresses to my account'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(source.rows, isEmpty);
      expect(source.inserts, 0);
    });
  });
}
