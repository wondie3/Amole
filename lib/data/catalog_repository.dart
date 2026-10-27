import '../models/dish.dart';
import '../models/food_category.dart';
import '../models/restaurant.dart';
import 'sample_data.dart';

/// The UI depends on this interface, not on sample data, so a real backend
/// can replace the mock later without touching any screen.
abstract interface class CatalogRepository {
  Future<List<FoodCategory>> getCategories();
  Future<List<Restaurant>> getRestaurants();
  Future<List<Dish>> getDishes();
}

class MockCatalogRepository implements CatalogRepository {
  const MockCatalogRepository();

  @override
  Future<List<FoodCategory>> getCategories() async => SampleData.categories;

  @override
  Future<List<Restaurant>> getRestaurants() async => SampleData.restaurants;

  @override
  Future<List<Dish>> getDishes() async => SampleData.dishes;
}
