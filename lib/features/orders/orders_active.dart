import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../data/catalog_providers.dart';
import '../../data/repositories/supabase_orders_source.dart';
import '../../data/repository_providers.dart' show backendEnabledProvider;
import '../../models/order.dart';
import '../addresses/addresses_remote_logic.dart' show newUuid;
import '../auth/auth_provider.dart';
import '../cart/cart_logic.dart';
import '../cart/cart_provider.dart';
import 'orders_provider.dart';
import 'orders_remote_logic.dart';

enum OrdersStatus { ready, loading, error }

final remoteOrdersSourceProvider = Provider<RemoteOrdersSource>(
  (ref) => SupabaseOrdersSource(Supabase.instance.client),
);

/// Server orders only when a backend is configured AND someone is signed in.
/// Otherwise the demo orders on this phone are used. The two are never mixed.
final useServerOrdersProvider = Provider<bool>((ref) {
  final backend = ref.watch(backendEnabledProvider);
  final userId = ref.watch(authUserProvider.select((u) => u?.id));
  return backend && userId != null;
});

/// The signed-in user's orders on the server. Reloads when the user changes.
class RemoteOrdersNotifier extends AsyncNotifier<List<Order>> {
  static const Duration _timeout = Duration(seconds: 12);
  static const String _busyMessage =
      'Another change is still in progress. Try again in a moment.';

  bool _busy = false;
  String? _pendingSignature;
  String? _pendingKey;

  RemoteOrdersSource get _source => ref.read(remoteOrdersSourceProvider);

  @override
  Future<List<Order>> build() async {
    final userId = ref.watch(authUserProvider.select((u) => u?.id));
    if (userId == null) return const [];
    return _load();
  }

  Future<List<Order>> _load() async =>
      ordersFromServerList(await _source.fetchOrders().timeout(_timeout));

  /// Reloads. Keeps the old list if the reload fails and one exists.
  Future<bool> _refresh() async {
    final fresh = await AsyncValue.guard(_load);
    if (fresh.hasValue || !state.hasValue) {
      state = fresh;
    }
    return fresh.hasValue;
  }

  String _keyFor(String signature) {
    final existing = _pendingKey;
    if (_pendingSignature == signature && existing != null) {
      return existing;
    }
    _pendingSignature = signature;
    return _pendingKey = newUuid();
  }

  void _forgetKey() {
    _pendingSignature = null;
    _pendingKey = null;
  }

  /// Places the cart as a server order. The cart is cleared only after the
  /// server confirms. The expected total comes from the catalog the customer
  /// saw.
  Future<PlaceOrderResult> placeOrder({
    required HomeData data,
    required String addressId,
  }) async {
    if (_busy) {
      return const PlaceOrderFailed(_busyMessage);
    }
    _busy = true;
    try {
      final lines = ref.read(cartProvider);
      if (lines.isEmpty) {
        return const PlaceOrderFailed(placeEmptyCartMessage);
      }
      final dishes = {for (final d in data.dishes) d.id: d};
      final restaurants = {for (final r in data.restaurants) r.id: r};
      final payload = buildPlaceLines(lines, dishes);
      if (payload == null) {
        return const PlaceOrderFailed(placeMenuOfflineMessage);
      }
      final expected = computeTotals(lines, dishes, restaurants).totalSantim;
      final key = _keyFor(placeSignature(lines, addressId, expected));

      final Object? json;
      try {
        json = await _source
            .placeOrder(
              idempotencyKey: key,
              lines: payload,
              addressId: addressId,
              expectedTotalSantim: expected,
            )
            .timeout(_timeout);
      } catch (e) {
        debugPrint('Orders: place failed (${e.runtimeType})');
        return placeOrderErrorToResult(e);
      }

      // The server accepted the order: from here on it exists.
      _forgetKey();
      ref.read(cartProvider.notifier).clear();
      final order = orderFromServerJson(json);
      final reloaded = await _refresh();
      if (order == null) {
        return const PlaceOrderFailed(placeUnreadableMessage);
      }
      if (!reloaded && state.hasValue) {
        final current = state.requireValue;
        if (!current.any((o) => o.id == order.id)) {
          state = AsyncData([order, ...current]);
        }
      }
      return PlaceOrderOk(order);
    } finally {
      _busy = false;
    }
  }

  /// Runs one change. Returns null on success, else a message safe to show.
  Future<String?> _run(Future<void> Function() op) async {
    if (_busy) {
      return _busyMessage;
    }
    _busy = true;
    String? error;
    try {
      await op().timeout(_timeout);
    } catch (e) {
      debugPrint('Orders: change failed (${e.runtimeType})');
      error = friendlyOrderError(e);
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

  /// Cancels a placed order at once, or sends a cancellation request for a
  /// confirmed, preparing or ready one. The server decides which applies.
  Future<String?> requestCancellation(String orderId) =>
      _run(() => _source.requestCancellation(orderId));

  Future<String?> withdrawCancellation(String orderId) =>
      _run(() => _source.withdrawCancellation(orderId));
}

final remoteOrdersProvider =
    AsyncNotifierProvider<RemoteOrdersNotifier, List<Order>>(
      RemoteOrdersNotifier.new,
      // No automatic background retries; a Retry button asks explicitly.
      retry: (retryCount, error) => null,
    );

/// The orders the app should show right now.
final activeOrdersProvider = Provider<List<Order>>((ref) {
  if (!ref.watch(useServerOrdersProvider)) {
    return ref.watch(ordersProvider);
  }
  final remote = ref.watch(remoteOrdersProvider);
  if (remote.isLoading) return const [];
  return remote.hasValue ? remote.requireValue : const [];
});

final ordersStatusProvider = Provider<OrdersStatus>((ref) {
  if (!ref.watch(useServerOrdersProvider)) return OrdersStatus.ready;
  final remote = ref.watch(remoteOrdersProvider);
  if (remote.isLoading) return OrdersStatus.loading;
  if (remote.hasError && !remote.hasValue) return OrdersStatus.error;
  return OrdersStatus.ready;
});
