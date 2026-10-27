import 'package:amole/features/search/search_logic.dart';
import 'package:amole/models/dish.dart';
import 'package:amole/models/restaurant.dart';
import 'package:flutter_test/flutter_test.dart';

const _r1 = Restaurant(
  id: 'r1',
  name: 'Alpha Grill',
  cuisine: 'Grill',
  rating: 4.0,
  etaMinMinutes: 10,
  etaMaxMinutes: 20,
  deliveryFeeSantim: 5000,
);
const _r2 = Restaurant(
  id: 'r2',
  name: 'Beta Kitchen',
  cuisine: 'Stews',
  rating: 4.8,
  etaMinMinutes: 30,
  etaMaxMinutes: 40,
  deliveryFeeSantim: 3000,
);
const _r3 = Restaurant(
  id: 'r3',
  name: 'Gamma Cafe',
  cuisine: 'Coffee',
  rating: 4.2,
  etaMinMinutes: 20,
  etaMaxMinutes: 30,
  deliveryFeeSantim: 2000,
);

const _d1 = Dish(
  id: 'd1',
  name: 'Tibs',
  restaurantId: 'r1',
  categoryId: 'grill',
  priceSantim: 30000,
  rating: 4.5,
  imageAsset: 'x.jpg',
);
const _d2 = Dish(
  id: 'd2',
  name: 'Doro wat',
  restaurantId: 'r2',
  categoryId: 'stew',
  priceSantim: 25000,
  rating: 4.9,
  imageAsset: 'x.jpg',
);
const _d3 = Dish(
  id: 'd3',
  name: 'Shiro',
  restaurantId: 'r2',
  categoryId: 'fasting',
  priceSantim: 15000,
  rating: 4.1,
  imageAsset: 'x.jpg',
);

const _dishes = [_d1, _d2, _d3];
const _restaurants = [_r1, _r2, _r3];

SearchResults _run({
  String text = '',
  String category = 'all',
  SortOption sort = SortOption.recommended,
}) => runSearch(
  dishes: _dishes,
  restaurants: _restaurants,
  text: text,
  categoryId: category,
  sort: sort,
);

List<String> _dishIds(SearchResults r) => r.dishes.map((d) => d.id).toList();
List<String> _restaurantIds(SearchResults r) =>
    r.restaurants.map((x) => x.id).toList();

void main() {
  test('empty query returns everything in catalog order', () {
    final r = _run();
    expect(_dishIds(r), ['d1', 'd2', 'd3']);
    expect(_restaurantIds(r), ['r1', 'r2', 'r3']);
  });

  test('text match ignores case and surrounding spaces', () {
    final r = _run(text: '  TIBS ');
    expect(_dishIds(r), ['d1']);
    expect(_restaurantIds(r), ['r1']);
  });

  test('restaurant name matches its dishes and itself', () {
    final r = _run(text: 'beta');
    expect(_dishIds(r), ['d2', 'd3']);
    expect(_restaurantIds(r), ['r2']);
  });

  test('cuisine matches restaurants', () {
    final r = _run(text: 'coffee');
    expect(_dishIds(r), isEmpty);
    expect(_restaurantIds(r), ['r3']);
  });

  test('category filter applies to dishes and restaurants', () {
    final r = _run(category: 'stew');
    expect(_dishIds(r), ['d2']);
    expect(_restaurantIds(r), ['r2']);
  });

  test('text and category combine', () {
    final r = _run(text: 'shiro', category: 'stew');
    expect(_dishIds(r), isEmpty);
    expect(_restaurantIds(r), isEmpty);
  });

  test('no match returns empty lists', () {
    final r = _run(text: 'zzz');
    expect(_dishIds(r), isEmpty);
    expect(_restaurantIds(r), isEmpty);
  });

  test('dish sorting', () {
    expect(_dishIds(_run(sort: SortOption.topRated)), ['d2', 'd1', 'd3']);
    expect(_dishIds(_run(sort: SortOption.priceLow)), ['d3', 'd2', 'd1']);
  });

  test('restaurant sorting', () {
    expect(_restaurantIds(_run(sort: SortOption.topRated)), ['r2', 'r3', 'r1']);
    expect(_restaurantIds(_run(sort: SortOption.fastest)), ['r1', 'r3', 'r2']);
    expect(_restaurantIds(_run(sort: SortOption.lowestFee)), [
      'r3',
      'r2',
      'r1',
    ]);
  });

  test('a sort that does not apply to dishes keeps catalog order', () {
    expect(_dishIds(_run(sort: SortOption.fastest)), ['d1', 'd2', 'd3']);
  });
}
