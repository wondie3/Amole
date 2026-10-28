import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/preferences_provider.dart';

/// Ids of favorite dishes, saved on this phone only.
class FavoritesNotifier extends Notifier<Set<String>> {
  static const String storageKey = 'favorite_dish_ids';

  @override
  Set<String> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return (prefs.getStringList(storageKey) ?? const <String>[]).toSet();
  }

  Future<void> toggle(String dishId) async {
    final next = {...state};
    if (!next.remove(dishId)) next.add(dishId);
    state = next;
    try {
      final list = next.toList()..sort();
      await ref.read(sharedPreferencesProvider).setStringList(storageKey, list);
    } catch (error) {
      // The heart still works for this session; saving failed.
      debugPrint('Could not save favorites: $error');
    }
  }
}

final favoritesProvider = NotifierProvider<FavoritesNotifier, Set<String>>(
  FavoritesNotifier.new,
);
