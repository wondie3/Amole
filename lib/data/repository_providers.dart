import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import 'preferences_provider.dart';
import 'repositories/addresses_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/favorites_repository.dart';
import 'repositories/orders_repository.dart';
import 'repositories/payment_repository.dart';
import 'repositories/supabase_auth_repository.dart';
import 'storage_scope.dart';

/// True only when main() initialized Supabase from the build's config.
final backendEnabledProvider = Provider<bool>((ref) => false);

/// The one place that decides which implementation the app uses. Swapping in
/// a remote repository happens here, not in any screen.
///
/// Orders and favorites are stored per signed-in account (and separately for
/// the guest), so one account never sees another's data.
final ordersRepositoryProvider = Provider<OrdersRepository>(
  (ref) => LocalOrdersRepository(
    ref.watch(sharedPreferencesProvider),
    key: scopedKey(
      LocalOrdersRepository.storageKey,
      ref.watch(storageScopeProvider),
    ),
  ),
);

/// Phone addresses are the guest/demo copy only. Account addresses live on the
/// server (see addresses_active.dart).
final addressesRepositoryProvider = Provider<AddressesRepository>(
  (ref) => LocalAddressesRepository(ref.watch(sharedPreferencesProvider)),
);

final favoritesRepositoryProvider = Provider<FavoritesRepository>(
  (ref) => LocalFavoritesRepository(
    ref.watch(sharedPreferencesProvider),
    key: scopedKey(
      LocalFavoritesRepository.storageKey,
      ref.watch(storageScopeProvider),
    ),
  ),
);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (ref.watch(backendEnabledProvider)) {
    return SupabaseAuthRepository(Supabase.instance.client);
  }
  return const NotConnectedAuthRepository();
});

final paymentRepositoryProvider = Provider<PaymentRepository>(
  (ref) => const NotConnectedPaymentRepository(),
);
