import 'package:amole/features/orders/orders_remote_logic.dart';
import 'package:amole/models/cart_line.dart';
import 'package:amole/models/dish.dart';
import 'package:amole/models/order.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> serverOrder({
  String id = 'o1',
  String status = 'placed',
  Object? request,
}) => {
  'id': id,
  'status': status,
  'createdAt': '2026-10-28T09:30:00.123456+00:00',
  'restaurantId': 'rest-uuid',
  'restaurantName': 'Sheger Grill',
  'subCity': 'Bole',
  'fulfillment': 'delivery',
  'subtotalSantim': 64000,
  'deliveryFeeSantim': 4500,
  'totalSantim': 68500,
  'estimatedDeliveryFrom': '2026-10-28T09:50:00.123456+00:00',
  'estimatedDeliveryTo': '2026-10-28T10:00:00.123456+00:00',
  'payment': {'method': 'cash_on_delivery', 'status': 'pending'},
  'items': [
    {
      'dishId': 'dish-uuid',
      'name': 'Tibs',
      'quantity': 2,
      'unitPriceSantim': 32000,
      'spice': 'spicy',
    },
  ],
  'cancellationRequest': request,
};

const _tibs = Dish(
  id: 'tibs',
  name: 'Tibs',
  restaurantId: 'sheger_grill',
  categoryId: 'grill',
  priceSantim: 32000,
  rating: 4.4,
  imageAsset: 'x.jpg',
  hasSpiceOptions: true,
  remoteId: 'dish-uuid',
);

void main() {
  group('reading server orders', () {
    test('a server order becomes an app order', () {
      final o = orderFromServerJson(serverOrder())!;
      expect(o.id, 'o1');
      expect(o.status, OrderStatus.placed);
      expect(o.simulated, isFalse);
      expect(o.restaurantName, 'Sheger Grill');
      expect(o.delivery.subCity, 'Bole');
      expect(o.delivery.name, isEmpty);
      expect(o.items.single.name, 'Tibs');
      expect(o.items.single.spiceLabel, 'Spicy');
      expect(o.subtotalSantim, 64000);
      expect(o.totalSantim, 68500);
      expect(o.payment, PaymentMethod.cashOnDelivery);
      expect(o.etaMinMinutes, 20);
      expect(o.etaMaxMinutes, 30);
      expect(o.cancellationRequest, isNull);
    });

    test('every server status the app knows is mapped', () {
      const map = {
        'placed': OrderStatus.placed,
        'confirmed': OrderStatus.confirmed,
        'preparing': OrderStatus.preparing,
        'ready': OrderStatus.ready,
        'out_for_delivery': OrderStatus.outForDelivery,
        'delivered': OrderStatus.delivered,
        'cancelled': OrderStatus.cancelled,
      };
      map.forEach((raw, expected) {
        expect(orderFromServerJson(serverOrder(status: raw))!.status, expected);
      });
    });

    test('a status the app cannot show yet is skipped', () {
      expect(
        orderFromServerJson(serverOrder(status: 'awaiting_payment')),
        isNull,
      );
      expect(orderFromServerJson(serverOrder(status: 'mystery')), isNull);
    });

    test('a cancellation request is read', () {
      final o = orderFromServerJson(
        serverOrder(
          status: 'preparing',
          request: {
            'status': 'declined',
            'requestedAt': '2026-10-28T09:35:00+00:00',
            'decidedAt': '2026-10-28T09:36:00+00:00',
            'decisionReason': 'Already cooking',
            'escalatedAt': null,
          },
        ),
      )!;
      expect(o.cancellationRequest!.status, CancellationRequestStatus.declined);
      expect(o.cancellationRequest!.decisionReason, 'Already cooking');
      expect(o.status, OrderStatus.preparing);
    });

    test('bad orders are skipped, good ones kept', () {
      final list = ordersFromServerList([
        serverOrder(id: 'a'),
        {'id': 'bad'},
        5,
        {...serverOrder(id: 'c'), 'items': <dynamic>[]},
        serverOrder(id: 'd'),
      ]);
      expect(list.map((o) => o.id), ['a', 'd']);
      expect(ordersFromServerList('nope'), isEmpty);
      expect(ordersFromServerList(null), isEmpty);
    });

    test('a missing estimate is allowed', () {
      final json = serverOrder()
        ..['estimatedDeliveryFrom'] = null
        ..['estimatedDeliveryTo'] = null;
      final o = orderFromServerJson(json)!;
      expect(o.etaMinMinutes, isNull);
    });
  });

  group('building the order lines', () {
    test('only database ids, quantities and spice are sent', () {
      final lines = buildPlaceLines(
        const [CartLine(dishId: 'tibs', quantity: 2, spice: SpiceLevel.spicy)],
        {'tibs': _tibs},
      )!;
      expect(lines, [
        {'dishId': 'dish-uuid', 'quantity': 2, 'spice': 'spicy'},
      ]);
      expect(lines.single.containsKey('price'), isFalse);
    });

    test('a dish without a database id blocks the order', () {
      const offline = Dish(
        id: 'tibs',
        name: 'Tibs',
        restaurantId: 'r',
        categoryId: 'grill',
        priceSantim: 32000,
        rating: 4.4,
        imageAsset: 'x.jpg',
      );
      expect(
        buildPlaceLines(
          const [CartLine(dishId: 'tibs', quantity: 1)],
          {'tibs': offline},
        ),
        isNull,
      );
      expect(
        buildPlaceLines(
          const [CartLine(dishId: 'ghost', quantity: 1)],
          {'tibs': _tibs},
        ),
        isNull,
      );
    });

    test('the signature ignores line order and changes with the cart', () {
      const a = CartLine(dishId: 'tibs', quantity: 1);
      const b = CartLine(dishId: 'kitfo', quantity: 2);
      expect(
        placeSignature(const [a, b], 'addr', 100),
        placeSignature(const [b, a], 'addr', 100),
      );
      expect(
        placeSignature(const [a], 'addr', 100),
        isNot(placeSignature(const [a, b], 'addr', 100)),
      );
      expect(
        placeSignature(const [a], 'addr', 100),
        isNot(placeSignature(const [a], 'other', 100)),
      );
    });
  });

  group('errors', () {
    test('place_order errors become results', () {
      PlaceOrderResult r(String m, {String? d}) => placeOrderErrorToResult(
        OrderSourceException(code: 'P0001', message: m, details: d),
      );
      final changed = r('cart_invalid', d: 'total_changed:70000');
      expect(changed, isA<PlaceOrderTotalChanged>());
      expect((changed as PlaceOrderTotalChanged).newTotalSantim, 70000);
      expect(r('cart_invalid', d: 'unavailable'), isA<PlaceOrderFailed>());
      expect(
        (r('cart_invalid', d: 'mixed_restaurants') as PlaceOrderFailed).message,
        contains('more than one restaurant'),
      );
      expect(
        (r('restaurant_closed') as PlaceOrderFailed).message,
        contains('closed'),
      );
      expect(
        (r('address_not_found') as PlaceOrderFailed).message,
        contains('address'),
      );
      expect(r('something_else'), isA<PlaceOrderFailed>());
    });

    test('a network error never claims the order was lost or placed', () {
      final r = placeOrderErrorToResult(Exception('socket'));
      expect((r as PlaceOrderFailed).message, placeNetworkMessage);
    });

    test('cancellation errors are friendly', () {
      String f(String m, {String? code}) =>
          friendlyOrderError(OrderSourceException(code: code, message: m));
      expect(f('not_cancellable'), orderNotCancellableMessage);
      expect(f('request_already_decided'), orderRequestDecidedMessage);
      expect(f('refund_required'), orderRefundMessage);
      expect(f('not_found'), orderNotFoundMessage);
      expect(f('x', code: '42501'), orderSignInAgainMessage);
      expect(f('x', code: '99999'), orderGenericMessage);
      expect(friendlyOrderError(Exception('socket')), orderNetworkMessage);
    });
  });
}
