/// Lifecycle of an order. Only [placed] is used until Milestone 8.
enum OrderStatus {
  placed('Placed'),
  confirmed('Confirmed'),
  preparing('Preparing'),
  outForDelivery('Out for delivery'),
  delivered('Delivered'),
  cancelled('Cancelled');

  const OrderStatus(this.label);
  final String label;
}

enum PaymentMethod {
  cashOnDelivery('Cash on delivery', true, ''),
  telebirr('Telebirr', false, 'Mobile money (not connected)'),
  cbeBirr('CBE Birr', false, 'Mobile money (not connected)');

  const PaymentMethod(this.label, this.available, this.note);
  final String label;

  /// False for methods that need a real payment provider integration.
  final bool available;
  final String note;
}

/// A copy of a cart line taken at the moment of ordering.
class OrderItem {
  const OrderItem({
    required this.dishId,
    required this.name,
    required this.unitPriceSantim,
    required this.quantity,
    this.spiceLabel,
  });

  final String dishId;
  final String name;
  final int unitPriceSantim;
  final int quantity;
  final String? spiceLabel;

  int get lineTotalSantim => unitPriceSantim * quantity;
}

class DeliveryDetails {
  const DeliveryDetails({
    required this.name,
    required this.phone,
    required this.subCity,
    required this.address,
    this.landmark,
  });

  final String name;
  final String phone;
  final String subCity;
  final String address;
  final String? landmark;
}

class Order {
  const Order({
    required this.id,
    required this.createdAt,
    required this.restaurantId,
    required this.restaurantName,
    required this.items,
    required this.deliveryFeeSantim,
    required this.delivery,
    required this.payment,
    this.status = OrderStatus.placed,
    this.simulated = true,
  });

  final String id;
  final DateTime createdAt;
  final String restaurantId;
  final String restaurantName;
  final List<OrderItem> items;
  final int deliveryFeeSantim;
  final DeliveryDetails delivery;
  final PaymentMethod payment;
  final OrderStatus status;

  /// True until a real backend creates and validates orders.
  final bool simulated;

  int get subtotalSantim => items.fold(0, (sum, i) => sum + i.lineTotalSantim);
  int get totalSantim => subtotalSantim + deliveryFeeSantim;
}
