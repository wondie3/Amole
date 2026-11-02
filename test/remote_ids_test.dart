import 'package:amole/data/repositories/remote_catalog_repository.dart';
import 'package:amole/data/sample_data.dart';
import 'package:flutter_test/flutter_test.dart';

const String _restaurantUuid = '10000000-0000-0000-0000-000000000003';
const String _dishUuid = '20000000-0000-0000-0000-000000000003';

const Map<String, dynamic> _restaurant = {
  'id': _restaurantUuid,
  'slug': 'sheger_grill',
  'name': 'Sheger Grill',
  'cuisine': 'Tibs and kitfo',
  'rating': 4.4,
  'eta_min_minutes': 20,
  'eta_max_minutes': 30,
  'delivery_fee_santim': 4500,
};

const Map<String, dynamic> _dish = {
  'id': _dishUuid,
  'slug': 'tibs',
  'name': 'Tibs',
  'price_santim': 32000,
  'rating': 4.4,
  'category': 'grill',
  'restaurants': {'slug': 'sheger_grill'},
};

void main() {
  test('remote rows keep the slug as id and the UUID as remoteId', () {
    final r = restaurantFromRow(_restaurant)!;
    expect(r.id, 'sheger_grill');
    expect(r.remoteId, _restaurantUuid);
    final d = dishFromRow(_dish)!;
    expect(d.id, 'tibs');
    expect(d.remoteId, _dishUuid);
  });

  test('a row without an id still loads, with no remoteId', () {
    expect(restaurantFromRow({..._restaurant}..remove('id'))!.remoteId, isNull);
    expect(dishFromRow({..._dish}..remove('id'))!.remoteId, isNull);
  });

  test('the local sample menu has no remote ids', () {
    expect(SampleData.dishes.every((d) => d.remoteId == null), isTrue);
    expect(SampleData.restaurants.every((r) => r.remoteId == null), isTrue);
  });
}
