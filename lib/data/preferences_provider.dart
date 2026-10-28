import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Loaded once in main() and injected, so favorites can be read
/// synchronously and tests can supply their own instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'Override sharedPreferencesProvider in the ProviderScope.',
  ),
);
