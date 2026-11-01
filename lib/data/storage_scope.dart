import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_provider.dart';

/// Which saved data the app uses: null for the guest/demo data, or the signed
/// in user's id. Data for each scope is stored under its own key on the phone.
final storageScopeProvider = Provider<String?>(
  (ref) => ref.watch(authUserProvider.select((u) => u?.id)),
);

/// The storage key for [base] in [scope]. The guest scope keeps the original
/// key, so existing saved data is found exactly where it always was.
String scopedKey(String base, String? scope) =>
    scope == null ? base : '$base:u:$scope';
