/// Lifecycle of an order. Statuses only change through simulation until a
/// backend exists.
enum OrderStatus {
  placed('Placed'),
  confirmed('Confirmed'),
  preparing('Preparing'),
  ready('Ready for pickup'),
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

enum CancellationRequestStatus { pending, accepted, declined }

/// A customer's request to cancel an order the restaurant has already
/// accepted. Only restaurant staff decide it (simulated for now).
class CancellationRequest {
  const CancellationRequest({
    required this.status,
    required this.requestedAt,
    this.decidedAt,
    this.decisionReason,
  });

  final CancellationRequestStatus status;
  final DateTime requestedAt;
  final DateTime? decidedAt;
  final String? decisionReason;

  bool get isPending => status == CancellationRequestStatus.pending;

  CancellationRequest copyWith({
    CancellationRequestStatus? status,
    DateTime? decidedAt,
    String? decisionReason,
  }) => CancellationRequest(
    status: status ?? this.status,
    requestedAt: requestedAt,
    decidedAt: decidedAt ?? this.decidedAt,
    decisionReason: decisionReason ?? this.decisionReason,
  );

  Map<String, Object?> toJson() => {
    'status': status.name,
    'requestedAt': requestedAt.toUtc().toIso8601String(),
    'decidedAt': decidedAt?.toUtc().toIso8601String(),
    'reason': decisionReason,
  };

  /// Returns null if [json] is not a valid saved request.
  static CancellationRequest? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final status = CancellationRequestStatus.values
        .where((v) => v.name == json['status'])
        .firstOrNull;
    final requestedRaw = json['requestedAt'];
    if (status == null || requestedRaw is! String) return null;
    final requestedAt = DateTime.tryParse(requestedRaw);
    if (requestedAt == null) return null;
    final decidedRaw = json['decidedAt'];
    final reason = json['reason'];
    return CancellationRequest(
      status: status,
      requestedAt: requestedAt,
      decidedAt: decidedRaw is String ? DateTime.tryParse(decidedRaw) : null,
      decisionReason: reason is String ? reason : null,
    );
  }
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

  Map<String, Object?> toJson() => {
    'dishId': dishId,
    'name': name,
    'unitPriceSantim': unitPriceSantim,
    'quantity': quantity,
    'spice': spiceLabel,
  };

  /// Returns null if [json] is not a valid saved item.
  static OrderItem? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final dishId = json['dishId'];
    final name = json['name'];
    final price = json['unitPriceSantim'];
    final quantity = json['quantity'];
    final spice = json['spice'];
    if (dishId is! String ||
        name is! String ||
        price is! int ||
        price < 0 ||
        quantity is! int ||
        quantity < 1) {
      return null;
    }
    if (spice != null && spice is! String) return null;
    return OrderItem(
      dishId: dishId,
      name: name,
      unitPriceSantim: price,
      quantity: quantity,
      spiceLabel: spice as String?,
    );
  }
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
    this.etaMinMinutes,
    this.etaMaxMinutes,
    this.cancellationRequest,
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

  /// The restaurant's sample delivery estimate, copied at ordering time.
  /// Null for orders saved before this was recorded.
  final int? etaMinMinutes;
  final int? etaMaxMinutes;

  /// Null until the customer asks to cancel a confirmed order.
  final CancellationRequest? cancellationRequest;

  int get subtotalSantim => items.fold(0, (sum, i) => sum + i.lineTotalSantim);
  int get totalSantim => subtotalSantim + deliveryFeeSantim;
  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);

  Order copyWith({
    OrderStatus? status,
    CancellationRequest? cancellationRequest,
    bool clearCancellationRequest = false,
  }) => Order(
    id: id,
    createdAt: createdAt,
    restaurantId: restaurantId,
    restaurantName: restaurantName,
    items: items,
    deliveryFeeSantim: deliveryFeeSantim,
    delivery: delivery,
    payment: payment,
    status: status ?? this.status,
    simulated: simulated,
    etaMinMinutes: etaMinMinutes,
    etaMaxMinutes: etaMaxMinutes,
    cancellationRequest: clearCancellationRequest
        ? null
        : (cancellationRequest ?? this.cancellationRequest),
  );

  /// Saved form. Personal contact details (name, phone, street, landmark) are
  /// deliberately NOT saved; only the sub-city is kept.
  Map<String, Object?> toStorageJson() => {
    'id': id,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'restaurantId': restaurantId,
    'restaurantName': restaurantName,
    'items': [for (final i in items) i.toJson()],
    'deliveryFeeSantim': deliveryFeeSantim,
    'subCity': delivery.subCity,
    'payment': payment.name,
    'status': status.name,
    'simulated': simulated,
    'etaMin': etaMinMinutes,
    'etaMax': etaMaxMinutes,
    'cancellation': cancellationRequest?.toJson(),
  };

  /// Returns null if [json] is not a valid saved order.
  static Order? tryFromStorageJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final createdRaw = json['createdAt'];
    final restaurantId = json['restaurantId'];
    final restaurantName = json['restaurantName'];
    final fee = json['deliveryFeeSantim'];
    final rawItems = json['items'];
    if (id is! String ||
        id.isEmpty ||
        createdRaw is! String ||
        restaurantId is! String ||
        restaurantName is! String ||
        fee is! int ||
        fee < 0 ||
        rawItems is! List ||
        rawItems.isEmpty) {
      return null;
    }
    final createdAt = DateTime.tryParse(createdRaw);
    if (createdAt == null) return null;

    final items = <OrderItem>[];
    for (final raw in rawItems) {
      final item = OrderItem.tryFromJson(raw);
      if (item == null) return null;
      items.add(item);
    }

    final payment = PaymentMethod.values
        .where((v) => v.name == json['payment'])
        .firstOrNull;
    final status = OrderStatus.values
        .where((v) => v.name == json['status'])
        .firstOrNull;
    if (payment == null || status == null) return null;

    // The estimate is optional: older saved orders do not have it.
    final etaMin = json['etaMin'];
    final etaMax = json['etaMax'];
    final validEta =
        etaMin is int && etaMax is int && etaMin >= 0 && etaMax >= etaMin;

    final subCity = json['subCity'];
    return Order(
      id: id,
      createdAt: createdAt,
      restaurantId: restaurantId,
      restaurantName: restaurantName,
      items: items,
      deliveryFeeSantim: fee,
      delivery: DeliveryDetails(
        name: '',
        phone: '',
        subCity: subCity is String ? subCity : '',
        address: '',
      ),
      payment: payment,
      status: status,
      simulated: json['simulated'] is bool ? json['simulated'] as bool : true,
      etaMinMinutes: validEta ? etaMin : null,
      etaMaxMinutes: validEta ? etaMax : null,
      // Optional: older saved orders do not have it, and a malformed one is
      // ignored instead of dropping the whole order.
      cancellationRequest: CancellationRequest.tryFromJson(
        json['cancellation'],
      ),
    );
  }
}
