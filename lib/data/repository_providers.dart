import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'preferences_provider.dart';
import 'repositories/addresses_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/favorites_repository.dart';
import 'repositories/orders_repository.dart';
import 'repositories/payment_repository.dart';

/// The one place that decides which implementation the app uses. Swapping in
/// a remote repository later happens here, not in any screen.
final ordersRepositoryProvider = Provider<OrdersRepository>(
  (ref) => LocalOrdersRepository(ref.watch(sharedPreferencesProvider)),
);

final addressesRepositoryProvider = Provider<AddressesRepository>(
  (ref) => LocalAddressesRepository(ref.watch(sharedPreferencesProvider)),
);

final favoritesRepositoryProvider = Provider<FavoritesRepository>(
  (ref) => LocalFavoritesRepository(ref.watch(sharedPreferencesProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => const NotConnectedAuthRepository(),
);

final paymentRepositoryProvider = Provider<PaymentRepository>(
  (ref) => const NotConnectedPaymentRepository(),
);
