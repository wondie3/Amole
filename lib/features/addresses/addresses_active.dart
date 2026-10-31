import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../data/repositories/supabase_addresses_source.dart';
import '../../data/repository_providers.dart' show backendEnabledProvider;
import '../../models/saved_address.dart';
import '../auth/auth_provider.dart';
import 'addresses_logic.dart';
import 'addresses_provider.dart';
import 'addresses_remote_logic.dart';

enum AddressMode { local, account }

enum AddressesStatus { ready, loading, error }

final remoteAddressesSourceProvider = Provider<RemoteAddressesSource>(
  (ref) => SupabaseAddressesSource(Supabase.instance.client),
);

/// Account addresses only when a backend is configured AND someone is signed
/// in. Otherwise the addresses on this phone are used.
final addressModeProvider = Provider<AddressMode>((ref) {
  final backend = ref.watch(backendEnabledProvider);
  final userId = ref.watch(authUserProvider.select((u) => u?.id));
  return backend && userId != null ? AddressMode.account : AddressMode.local;
});

/// The signed-in user's addresses on the server. Reloads when the user
/// changes. Every change is followed by a reload, so the list always shows
/// what the server holds.
class RemoteAddressesNotifier extends AsyncNotifier<AddressBook> {
  static const Duration _timeout = Duration(seconds: 10);
  static const String _busyMessage =
      'Another change is still in progress. Try again in a moment.';

  bool _busy = false;

  RemoteAddressesSource get _source => ref.read(remoteAddressesSourceProvider);

  @override
  Future<AddressBook> build() async {
    final userId = ref.watch(authUserProvider.select((u) => u?.id));
    if (userId == null) {
      return const AddressBook();
    }
    return _load();
  }

  Future<AddressBook> _load() async =>
      bookFromRows(await _source.fetch().timeout(_timeout));

  /// Reloads. Keeps the old list if the reload fails and one exists.
  Future<bool> _refresh() async {
    final fresh = await AsyncValue.guard(_load);
    if (fresh.hasValue || !state.hasValue) state = fresh;
    return fresh.hasValue;
  }

  /// Runs one change. Returns null on success, else a message safe to show.
  Future<String?> _run(Future<void> Function() op) async {
    if (_busy) {
      return _busyMessage;
    }
    _busy = true;
    String? error;
    try {
      await op();
    } catch (e) {
      debugPrint('Addresses: change failed (${e.runtimeType})');
      error = friendlyAddressError(e);
    }
    try {
      final reloaded = await _refresh();
      if (!reloaded && error == null) {
        error =
            'Your change may have been saved, but the list could not be '
            'refreshed.';
      }
    } finally {
      _busy = false;
    }
    return error;
  }

  /// Adds and selects an address. The id is replaced by a new UUID.
  Future<String?> add(SavedAddress address) {
    final count = state.hasValue ? state.requireValue.addresses.length : 0;
    if (count >= maxSavedAddresses) {
      return Future.value(addressLimitMessage);
    }
    final id = newUuid();
    return _run(() async {
      await _source.insert(addressToRow(addressWithId(address, id)));
      try {
        await _source.select(id);
      } catch (e) {
        // Saved but not selected: not worth failing the whole save.
        debugPrint(
          'Addresses: could not select new address (${e.runtimeType})',
        );
      }
    });
  }

  Future<String?> updateAddress(SavedAddress address) =>
      _run(() => _source.update(address.id, addressToUpdate(address)));

  Future<String?> delete(String id) => _run(() => _source.delete(id));

  Future<String?> select(String id) => _run(() => _source.select(id));

  /// Copies phone addresses to the account. Only ever called after the user
  /// confirmed. Judged against a fresh read of the server, skips duplicates,
  /// respects the limit, and never changes [local].
  Future<CopyReport> copyLocal(List<SavedAddress> local) async {
    if (_busy) {
      return CopyReport(failed: local.length, firstError: _busyMessage);
    }
    _busy = true;
    try {
      final existing = bookFromRows(await _source.fetch().timeout(_timeout))
          .addresses;
      final plan = planCopy(existing: existing, local: local);
      var copied = 0;
      var failed = 0;
      String? firstError;
      for (final a in plan.toCopy) {
        try {
          await _source.insert(addressToRow(addressWithId(a, newUuid())));
          copied++;
        } catch (e) {
          failed++;
          firstError ??= friendlyAddressError(e);
        }
      }
      await _refresh();
      return CopyReport(
        copied: copied,
        duplicates: plan.duplicates.length,
        overLimit: plan.overLimit.length,
        failed: failed,
        firstError: firstError,
      );
    } catch (e) {
      debugPrint('Addresses: copy failed (${e.runtimeType})');
      return CopyReport(
        failed: local.length,
        firstError: friendlyAddressError(e),
      );
    } finally {
      _busy = false;
    }
  }
}

final remoteAddressesProvider =
    AsyncNotifierProvider<RemoteAddressesNotifier, AddressBook>(
      RemoteAddressesNotifier.new,
      // No automatic background retries; the Retry button asks explicitly.
      retry: (retryCount, error) => null,
    );

/// The addresses the app should use right now.
final activeAddressesProvider = Provider<AddressBook>((ref) {
  if (ref.watch(addressModeProvider) == AddressMode.local) {
    return ref.watch(addressesProvider);
  }
  final remote = ref.watch(remoteAddressesProvider);
  // While loading (also right after the user changes), show nothing rather
  // than the previous user's list.
  if (remote.isLoading) {
    return const AddressBook();
  }
  return remote.hasValue ? remote.requireValue : const AddressBook();
});

final addressesStatusProvider = Provider<AddressesStatus>((ref) {
  if (ref.watch(addressModeProvider) == AddressMode.local) {
    return AddressesStatus.ready;
  }
  final remote = ref.watch(remoteAddressesProvider);
  if (remote.isLoading) {
    return AddressesStatus.loading;
  }
  if (remote.hasError && !remote.hasValue) {
    return AddressesStatus.error;
  }
  return AddressesStatus.ready;
});

/// What the screens call. Each method returns null on success, or a message
/// to show. In phone mode it uses the local store exactly as before.
class AddressActions {
  AddressActions(this._ref);

  final Ref _ref;

  bool get _account => _ref.read(addressModeProvider) == AddressMode.account;

  RemoteAddressesNotifier get _remote =>
      _ref.read(remoteAddressesProvider.notifier);

  AddressesNotifier get _local => _ref.read(addressesProvider.notifier);

  Future<String?> add(SavedAddress a) async {
    if (_account) {
      return _remote.add(a);
    }
    return _local.add(a) ? null : addressLimitMessage;
  }

  Future<String?> update(SavedAddress a) async {
    if (_account) {
      return _remote.updateAddress(a);
    }
    _local.update(a);
    return null;
  }

  Future<String?> delete(String id) async {
    if (_account) {
      return _remote.delete(id);
    }
    _local.delete(id);
    return null;
  }

  Future<String?> select(String id) async {
    if (_account) {
      return _remote.select(id);
    }
    _local.select(id);
    return null;
  }
}

final addressActionsProvider = Provider<AddressActions>(
  (ref) => AddressActions(ref),
);
