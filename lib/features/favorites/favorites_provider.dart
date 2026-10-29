import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/favorites_repository.dart';
import '../../data/repository_providers.dart';

/// Ids of favorite dishes, saved through the favorites repository.
class FavoritesNotifier extends Notifier<Set<String>> {
  static const String storageKey = LocalFavoritesRepository.storageKey;

  @override
  Set<String> build() => ref.watch(favoritesRepositoryProvider).load();

  Future<void> toggle(String dishId) async {
    final next = {...state};
    if (!next.remove(dishId)) next.add(dishId);
    state = next;
    try {
      await ref.read(favoritesRepositoryProvider).save(next);
    } catch (error) {
      // The heart still works for this session; saving failed.
      debugPrint('Could not save favorites: $error');
    }
  }
}

final favoritesProvider = NotifierProvider<FavoritesNotifier, Set<String>>(
  FavoritesNotifier.new,
);
