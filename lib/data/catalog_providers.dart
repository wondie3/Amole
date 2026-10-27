import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/dish.dart';
import '../models/food_category.dart';
import '../models/restaurant.dart';
import 'catalog_repository.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => const MockCatalogRepository(),
);

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
