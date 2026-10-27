import '../../models/dish.dart';
import '../../models/restaurant.dart';

enum SearchMode { dishes, restaurants }

enum SortOption {
  recommended('Recommended'),
  topRated('Top rated'),
  fastest('Fastest delivery'),
  lowestFee('Lowest delivery fee'),
  priceLow('Price: low to high');

  const SortOption(this.label);
  final String label;
}

/// Sort options that make sense for each mode.
List<SortOption> sortOptionsFor(SearchMode mode) => switch (mode) {
  SearchMode.dishes => const [
    SortOption.recommended,
    SortOption.topRated,
    SortOption.priceLow,
  ],
  SearchMode.restaurants => const [
    SortOption.recommended,
    SortOption.topRated,
    SortOption.fastest,
    SortOption.lowestFee,
  ],
};

class SearchResults {
  const SearchResults({required this.dishes, required this.restaurants});

  final List<Dish> dishes;
  final List<Restaurant> restaurants;
}

String _norm(String s) => s.toLowerCase().trim();

int _then(int primary, String a, String b) =>
    primary != 0 ? primary : a.compareTo(b);

/// Pure search/filter/sort logic over the catalog. Kept free of Flutter and
/// Riverpod so it can be unit tested directly.
SearchResults runSearch({
  required List<Dish> dishes,
  required List<Restaurant> restaurants,
  required String text,
  required String categoryId,
  required SortOption sort,
}) {
  final q = _norm(text);
  final restaurantById = {for (final r in restaurants) r.id: r};
  bool inCategory(Dish d) => categoryId == 'all' || d.categoryId == categoryId;

  final matchedDishes = dishes.where((d) {
    if (!inCategory(d)) return false;
    if (q.isEmpty) return true;
    final restaurantName = restaurantById[d.restaurantId]?.name ?? '';
    return _norm(d.name).contains(q) || _norm(restaurantName).contains(q);
  }).toList();

  final matchedRestaurants = restaurants.where((r) {
    final menu = dishes
        .where((d) => d.restaurantId == r.id && inCategory(d))
        .toList();
    if (categoryId != 'all' && menu.isEmpty) return false;
    if (q.isEmpty) return true;
    return _norm(r.name).contains(q) ||
        _norm(r.cuisine).contains(q) ||
        menu.any((d) => _norm(d.name).contains(q));
  }).toList();

  // Recommended keeps the catalog order. Ties are broken by name so results
  // are deterministic.
  if (sort == SortOption.topRated || sort == SortOption.priceLow) {
    matchedDishes.sort(
      (a, b) => _then(
        switch (sort) {
          SortOption.priceLow => a.priceSantim.compareTo(b.priceSantim),
          _ => b.rating.compareTo(a.rating),
        },
        a.name,
        b.name,
      ),
    );
  }
  if (sort == SortOption.topRated ||
      sort == SortOption.fastest ||
      sort == SortOption.lowestFee) {
    matchedRestaurants.sort(
      (a, b) => _then(
        switch (sort) {
          SortOption.fastest => a.etaMinMinutes.compareTo(b.etaMinMinutes),
          SortOption.lowestFee => a.deliveryFeeSantim.compareTo(
            b.deliveryFeeSantim,
          ),
          _ => b.rating.compareTo(a.rating),
        },
        a.name,
        b.name,
      ),
    );
  }

  return SearchResults(dishes: matchedDishes, restaurants: matchedRestaurants);
}
