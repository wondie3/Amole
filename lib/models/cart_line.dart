enum SpiceLevel {
  mild('Mild'),
  medium('Medium'),
  spicy('Spicy');

  const SpiceLevel(this.label);
  final String label;
}

/// One line in the cart. The same dish with a different spice level is a
/// different line.
class CartLine {
  const CartLine({required this.dishId, required this.quantity, this.spice});

  final String dishId;
  final int quantity;
  final SpiceLevel? spice;

  String get key => '$dishId|${spice?.name ?? '-'}';

  CartLine copyWith({int? quantity}) => CartLine(
    dishId: dishId,
    quantity: quantity ?? this.quantity,
    spice: spice,
  );
}
