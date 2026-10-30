import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import 'app.dart';
import 'data/preferences_provider.dart';
import 'data/repository_providers.dart';

// Supplied at build time: --dart-define-from-file=env/local.json
// Without them the app runs fully local, with no backend.
const String _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String _supabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  var backendEnabled = false;
  if (_supabaseUrl.isNotEmpty && _supabaseKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: _supabaseUrl,
        publishableKey: _supabaseKey,
      );
      backendEnabled = true;
    } catch (error) {
      debugPrint('Supabase was not initialized: ${error.runtimeType}');
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        backendEnabledProvider.overrideWithValue(backendEnabled),
      ],
      child: const AmoleApp(),
    ),
  );
}
