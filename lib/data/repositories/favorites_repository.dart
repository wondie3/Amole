import 'package:shared_preferences/shared_preferences.dart';

/// Where favorite dish ids are stored. Today: this phone.
abstract interface class FavoritesRepository {
  Set<String> load();
  Future<void> save(Set<String> dishIds);
}

class LocalFavoritesRepository implements FavoritesRepository {
  const LocalFavoritesRepository(this._prefs, {this.key = storageKey});

  static const String storageKey = 'favorite_dish_ids';

  final SharedPreferences _prefs;

  /// The key to use. Differs per signed-in account.
  final String key;

  @override
  Set<String> load() => (_prefs.getStringList(key) ?? const <String>[]).toSet();

  @override
  Future<void> save(Set<String> dishIds) =>
      _prefs.setStringList(key, dishIds.toList()..sort());
}
