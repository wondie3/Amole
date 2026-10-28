import '../../models/cart_line.dart';
import '../../models/dish.dart';
import '../../models/order.dart';
import '../../models/restaurant.dart';

/// Sub-cities of Addis Ababa, plus a catch-all.
const List<String> addisSubCities = [
  'Addis Ketema',
  'Akaky Kaliti',
  'Arada',
  'Bole',
  'Gullele',
  'Kirkos',
  'Kolfe Keranio',
  'Lemi Kura',
  'Lideta',
  'Nifas Silk-Lafto',
  'Yeka',
  'Other area',
];

final RegExp _mobile = RegExp(r'^(?:\+251|251|0)([79]\d{8})$');

/// Returns +251XXXXXXXXX for a valid Ethiopian mobile number, else null.
/// Spaces, dashes, dots and brackets are ignored.
String? normalizePhone(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[\s\-().]'), '');
  final match = _mobile.firstMatch(cleaned);
  return match == null ? null : '+251${match.group(1)}';
}

String? validateName(String? value) {
  final v = (value ?? '').trim();
  if (v.length < 2) return 'Enter your full name';
  if (v.length > 60) return 'Name is too long';
  return null;
}

String? validatePhone(String? value) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return 'Enter your phone number';
  if (normalizePhone(v) == null) {
    return 'Enter a mobile number like 0911 22 33 44';
  }
  return null;
}

String? validateSubCity(String? value) =>
    (value == null || value.isEmpty) ? 'Choose your sub-city' : null;

String? validateAddress(String? value) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return 'Enter your street or area';
  if (v.length < 5) return 'Add a little more detail';
  if (v.length > 120) return 'Address is too long';
  return null;
}

String? validateLandmark(String? value) {
  final v = (value ?? '').trim();
  if (v.length > 80) return 'Landmark is too long';
  return null;
}

class OrderBuild {
  const OrderBuild.success(Order o) : order = o, error = null;
  const OrderBuild.failure(String message) : order = null, error = message;

  final Order? order;
  final String? error;
}

/// Builds an order from the cart, or explains why it cannot. Pure logic, so
/// it can be tested without any UI. A real backend must repeat these checks
/// on the server; the client is never trusted for prices or availability.
OrderBuild buildOrder({
  required List<CartLine> lines,
  required Map<String, Dish> dishesById,
  required Map<String, Restaurant> restaurantsById,
  required DeliveryDetails delivery,
  required PaymentMethod payment,
  required String id,
  required DateTime createdAt,
}) {
  if (lines.isEmpty) return const OrderBuild.failure('Your cart is empty.');
  if (!payment.available) {
    return OrderBuild.failure('${payment.label} is not available yet.');
  }

  final items = <OrderItem>[];
  String? restaurantId;
  for (final l in lines) {
    final dish = dishesById[l.dishId];
    if (dish == null) {
      return const OrderBuild.failure(
        'Some items in your cart are no longer available. Remove them and '
        'try again.',
      );
    }
    if (restaurantId != null && restaurantId != dish.restaurantId) {
      return const OrderBuild.failure(
        'Your cart has items from more than one restaurant.',
      );
    }
    restaurantId = dish.restaurantId;
    items.add(
      OrderItem(
        dishId: dish.id,
        name: dish.name,
        unitPriceSantim: dish.priceSantim,
        quantity: l.quantity,
        spiceLabel: l.spice?.label,
      ),
    );
  }

  final restaurant = restaurantsById[restaurantId];
  if (restaurant == null) {
    return const OrderBuild.failure('This restaurant is no longer available.');
  }

  return OrderBuild.success(
    Order(
      id: id,
      createdAt: createdAt,
      restaurantId: restaurant.id,
      restaurantName: restaurant.name,
      items: items,
      deliveryFeeSantim: restaurant.deliveryFeeSantim,
      delivery: delivery,
      payment: payment,
    ),
  );
}
