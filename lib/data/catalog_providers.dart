import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../models/dish.dart';
import '../models/food_category.dart';
import '../models/restaurant.dart';
import 'catalog_repository.dart';
import 'repositories/remote_catalog_repository.dart';
import 'repositories/supabase_catalog_source.dart';
import 'repository_providers.dart' show backendEnabledProvider;

/// With a backend configured, the menu comes from it (falling back to the
/// local sample data if it cannot be reached). Without one, local data only.
final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  if (ref.watch(backendEnabledProvider)) {
    return RemoteCatalogRepository(
      SupabaseCatalogSource(Supabase.instance.client),
    );
  }
  return const MockCatalogRepository();
});

class HomeData {
  const HomeData({
    required this.categories,
    required this.restaurants,
    required this.dishes,
  });

  final List<FoodCategory> categories;
  final List<Restaurant> restaurants;
  final List<Dish> dishes;
}

final homeDataProvider = FutureProvider<HomeData>((ref) async {
  final repo = ref.watch(catalogRepositoryProvider);
  final results = await Future.wait([
    repo.getCategories(),
    repo.getRestaurants(),
    repo.getDishes(),
  ]);
  return HomeData(
    categories: results[0] as List<FoodCategory>,
    restaurants: results[1] as List<Restaurant>,
    dishes: results[2] as List<Dish>,
  );
});
