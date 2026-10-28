import 'package:amole/data/preferences_provider.dart';
import 'package:amole/features/favorites/favorites_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferences> _prefs(Map<String, Object> initial) async {
  SharedPreferences.setMockInitialValues(initial);
  return SharedPreferences.getInstance();
}

ProviderContainer _container(SharedPreferences prefs) {
  final c = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('loads saved favorites on start', () async {
    final prefs = await _prefs({
      FavoritesNotifier.storageKey: ['wat_platter'],
    });
    expect(_container(prefs).read(favoritesProvider), {'wat_platter'});
  });

  test('toggle adds then removes', () async {
    final c = _container(await _prefs({}));
    await c.read(favoritesProvider.notifier).toggle('tibs');
    expect(c.read(favoritesProvider), {'tibs'});
    await c.read(favoritesProvider.notifier).toggle('tibs');
    expect(c.read(favoritesProvider), isEmpty);
  });

  test('favorites persist to a new container', () async {
    final prefs = await _prefs({});
    await _container(prefs).read(favoritesProvider.notifier).toggle('kitfo');
    expect(_container(prefs).read(favoritesProvider), {'kitfo'});
  });
}
