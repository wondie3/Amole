import 'package:shared_preferences/shared_preferences.dart';

/// Where favorite dish ids are stored. Today: this phone.
abstract interface class FavoritesRepository {
  Set<String> load();
  Future<void> save(Set<String> dishIds);
}

class LocalFavoritesRepository implements FavoritesRepository {
  const LocalFavoritesRepository(this._prefs);

  static const String storageKey = 'favorite_dish_ids';

  final SharedPreferences _prefs;

  @override
  Set<String> load() =>
      (_prefs.getStringList(storageKey) ?? const <String>[]).toSet();

  @override
  Future<void> save(Set<String> dishIds) =>
      _prefs.setStringList(storageKey, dishIds.toList()..sort());
}
