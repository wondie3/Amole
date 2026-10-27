import 'package:amole/data/sample_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final creditedAssets = SampleData.photoCredits.map((c) => c.asset).toSet();

  test('every dish photo has a credit', () {
    for (final d in SampleData.dishes) {
      expect(creditedAssets, contains(d.imageAsset), reason: d.id);
    }
  });

  test('banner photo has a credit', () {
    expect(creditedAssets, contains(SampleData.bannerAsset));
  });

  test('dishes reference existing restaurants and categories', () {
    final restaurants = SampleData.restaurants.map((r) => r.id).toSet();
    final categories = SampleData.categories.map((c) => c.id).toSet();
    for (final d in SampleData.dishes) {
      expect(restaurants, contains(d.restaurantId), reason: d.id);
      expect(categories, contains(d.categoryId), reason: d.id);
      expect(d.priceSantim, greaterThan(0), reason: d.id);
    }
  });

  test('ids are unique', () {
    final ids = SampleData.dishes.map((d) => d.id).toList();
    expect(ids.toSet().length, ids.length);
  });
}
