import 'dart:async';

import 'package:amole/data/repositories/remote_catalog_repository.dart';
import 'package:amole/data/sample_data.dart';
import 'package:flutter_test/flutter_test.dart';

const Map<String, dynamic> _restaurant = {
  'slug': 'sheger_grill',
  'name': 'Sheger Grill',
  'cuisine': 'Tibs and kitfo',
  'rating': 4.4,
  'eta_min_minutes': 20,
  'eta_max_minutes': 30,
  'delivery_fee_santim': 4500,
};

const Map<String, dynamic> _tibs = {
  'slug': 'tibs',
  'name': 'Tibs',
  'description': 'Sauteed cubes of meat.',
  'price_santim': 33000,
  'rating': 4.4,
  'category': 'grill',
  'has_spice_options': true,
  'image_asset': 'assets/images/foods/tibs.jpg',
  'available': true,
  'restaurants': {'slug': 'sheger_grill'},
};

class _FakeSource implements CatalogRemoteSource {
  _FakeSource({
    this.restaurants = const [],
    this.dishes = const [],
    this.error,
  });

  final List<Map<String, dynamic>> restaurants;
  final List<Map<String, dynamic>> dishes;
  final Object? error;
  int loads = 0;

  @override
  Future<List<Map<String, dynamic>>> restaurantRows() async {
    loads++;
    if (error != null) throw error!;
    return restaurants;
  }

  @override
  Future<List<Map<String, dynamic>>> dishRows() async {
    if (error != null) throw error!;
    return dishes;
  }
}

class _HangingSource implements CatalogRemoteSource {
  @override
  Future<List<Map<String, dynamic>>> restaurantRows() =>
      Completer<List<Map<String, dynamic>>>().future;

  @override
  Future<List<Map<String, dynamic>>> dishRows() =>
      Completer<List<Map<String, dynamic>>>().future;
}

void main() {
  test('rows become models that use the slug as the id', () async {
    final repo = RemoteCatalogRepository(
      _FakeSource(restaurants: [_restaurant], dishes: [_tibs]),
    );
    final r = (await repo.getRestaurants()).single;
    expect(r.id, 'sheger_grill');
    expect(r.deliveryFeeSantim, 4500);
    expect(r.rating, 4.4);

    final d = (await repo.getDishes()).single;
    expect(d.id, 'tibs');
    expect(d.restaurantId, 'sheger_grill');
    expect(d.priceSantim, 33000);
    expect(d.hasSpiceOptions, isTrue);
    expect(d.imageAsset, 'assets/images/foods/tibs.jpg');
  });

  test('a whole-number rating is accepted', () {
    final d = dishFromRow({..._tibs, 'rating': 5});
    expect(d!.rating, 5.0);
  });

  test('a failing backend falls back to the local sample data', () async {
    final repo = RemoteCatalogRepository(
      _FakeSource(error: Exception('offline')),
    );
    expect((await repo.getRestaurants()).length, SampleData.restaurants.length);
    final tibs = (await repo.getDishes()).firstWhere((d) => d.id == 'tibs');
    expect(tibs.priceSantim, 32000);
  });

  test('an empty backend falls back to local data', () async {
    final repo = RemoteCatalogRepository(_FakeSource());
    expect((await repo.getDishes()).length, SampleData.dishes.length);
  });

  test('restaurants and dishes never come from different places', () async {
    final repo = RemoteCatalogRepository(
      _FakeSource(restaurants: [_restaurant], dishes: const []),
    );
    expect((await repo.getRestaurants()).length, SampleData.restaurants.length);
    expect((await repo.getDishes()).length, SampleData.dishes.length);
  });

  test('a hanging backend falls back after the timeout', () async {
    final repo = RemoteCatalogRepository(
      _HangingSource(),
      timeout: const Duration(milliseconds: 20),
    );
    expect((await repo.getDishes()).length, SampleData.dishes.length);
  });

  test('malformed, unavailable and orphan rows are skipped', () async {
    final repo = RemoteCatalogRepository(
      _FakeSource(
        restaurants: [
          _restaurant,
          {'slug': 'broken'},
        ],
        dishes: [
          _tibs,
          {'slug': 'bad'},
          {..._tibs, 'slug': 'sold_out', 'available': false},
          {
            ..._tibs,
            'slug': 'orphan',
            'restaurants': {'slug': 'nowhere'},
          },
          {..._tibs, 'slug': 'free', 'price_santim': 0},
        ],
      ),
    );
    expect((await repo.getRestaurants()).map((r) => r.id), ['sheger_grill']);
    expect((await repo.getDishes()).map((d) => d.id), ['tibs']);
  });

  test('restaurants and dishes share one load', () async {
    final source = _FakeSource(restaurants: [_restaurant], dishes: [_tibs]);
    final repo = RemoteCatalogRepository(source);
    await Future.wait([repo.getRestaurants(), repo.getDishes()]);
    expect(source.loads, 1);
  });

  test('a later call loads again, so a retry can succeed', () async {
    final source = _FakeSource(restaurants: [_restaurant], dishes: [_tibs]);
    final repo = RemoteCatalogRepository(source);
    await repo.getRestaurants();
    await repo.getRestaurants();
    expect(source.loads, 2);
  });

  test('categories always come from the local list', () async {
    final repo = RemoteCatalogRepository(_FakeSource());
    expect((await repo.getCategories()).length, SampleData.categories.length);
  });
}
