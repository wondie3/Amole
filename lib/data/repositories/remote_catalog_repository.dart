// ignore_for_file: prefer_initializing_formals
import 'package:flutter/foundation.dart' show debugPrint;

import '../../models/dish.dart';
import '../../models/food_category.dart';
import '../../models/restaurant.dart';
import '../catalog_repository.dart';

/// Where raw catalog rows come from. The real one talks to Supabase; tests
/// use a fake.
abstract interface class CatalogRemoteSource {
  Future<List<Map<String, dynamic>>> restaurantRows();
  Future<List<Map<String, dynamic>>> dishRows();
}

String? _str(Object? v) => v is String && v.trim().isNotEmpty ? v : null;

/// Returns null if [row] is not a valid restaurant row. The model id is the
/// row's slug, which matches the ids the app already uses.
Restaurant? restaurantFromRow(Object? row) {
  if (row is! Map) return null;
  final slug = _str(row['slug']);
  final name = _str(row['name']);
  final cuisine = _str(row['cuisine']);
  final rating = row['rating'];
  final etaMin = row['eta_min_minutes'];
  final etaMax = row['eta_max_minutes'];
  final fee = row['delivery_fee_santim'];
  if (slug == null ||
      name == null ||
      cuisine == null ||
      rating is! num ||
      etaMin is! int ||
      etaMax is! int ||
      etaMax < etaMin ||
      fee is! int ||
      fee < 0) {
    return null;
  }
  return Restaurant(
    id: slug,
    remoteId: _str(row['id']),
    name: name,
    cuisine: cuisine,
    rating: rating.toDouble(),
    etaMinMinutes: etaMin,
    etaMaxMinutes: etaMax,
    deliveryFeeSantim: fee,
  );
}

/// Returns null if [row] is not a valid, available dish row.
Dish? dishFromRow(Object? row) {
  if (row is! Map) return null;
  final slug = _str(row['slug']);
  final name = _str(row['name']);
  final category = _str(row['category']);
  final price = row['price_santim'];
  final rating = row['rating'];
  var parent = row['restaurants'];
  if (parent is List && parent.isNotEmpty) parent = parent.first;
  final restaurantSlug = parent is Map ? _str(parent['slug']) : null;
  if (slug == null ||
      name == null ||
      category == null ||
      restaurantSlug == null ||
      price is! int ||
      price <= 0 ||
      rating is! num ||
      row['available'] == false) {
    return null;
  }
  final description = row['description'];
  final image = row['image_asset'];
  return Dish(
    id: slug,
    remoteId: _str(row['id']),
    name: name,
    restaurantId: restaurantSlug,
    categoryId: category,
    priceSantim: price,
    rating: rating.toDouble(),
    imageAsset: image is String ? image : '',
    description: description is String ? description : '',
    hasSpiceOptions: row['has_spice_options'] == true,
  );
}

class _Snapshot {
  const _Snapshot(this.restaurants, this.dishes);

  final List<Restaurant> restaurants;
  final List<Dish> dishes;
}

/// Reads the menu from a backend. On any failure, timeout or empty result it
/// uses [fallback] for restaurants AND dishes together, so the two lists
/// never come from different places. Categories always come from [fallback].
class RemoteCatalogRepository implements CatalogRepository {
  RemoteCatalogRepository(
    this._source, {
    CatalogRepository fallback = const MockCatalogRepository(),
    Duration timeout = const Duration(seconds: 8),
  }) : _fallback = fallback,
       _timeout = timeout;

  final CatalogRemoteSource _source;
  final CatalogRepository _fallback;
  final Duration _timeout;

  // Calls made at the same moment (restaurants and dishes) share one load.
  // It is cleared when finished, so a later retry loads again.
  Future<_Snapshot>? _inflight;

  Future<_Snapshot> _snapshot() =>
      _inflight ??= _load().whenComplete(() => _inflight = null);

  Future<_Snapshot> _load() async {
    try {
      final restaurantRows = await _source.restaurantRows().timeout(_timeout);
      final dishRows = await _source.dishRows().timeout(_timeout);

      final restaurants = <Restaurant>[];
      for (final row in restaurantRows) {
        final r = restaurantFromRow(row);
        if (r != null) restaurants.add(r);
      }
      final ids = {for (final r in restaurants) r.id};
      final dishes = <Dish>[];
      for (final row in dishRows) {
        final d = dishFromRow(row);
        if (d != null && ids.contains(d.restaurantId)) dishes.add(d);
      }
      if (restaurants.isEmpty || dishes.isEmpty) {
        debugPrint(
          'Catalog: backend returned no usable menu; using local data',
        );
        return await _local();
      }
      return _Snapshot(restaurants, dishes);
    } catch (error) {
      debugPrint('Catalog: using local sample data (${error.runtimeType})');
      return await _local();
    }
  }

  Future<_Snapshot> _local() async =>
      _Snapshot(await _fallback.getRestaurants(), await _fallback.getDishes());

  @override
  Future<List<FoodCategory>> getCategories() => _fallback.getCategories();

  @override
  Future<List<Restaurant>> getRestaurants() async =>
      (await _snapshot()).restaurants;

  @override
  Future<List<Dish>> getDishes() async => (await _snapshot()).dishes;
}
