class Dish {
  const Dish({
    required this.id,
    required this.name,
    required this.restaurantId,
    required this.categoryId,
    required this.priceSantim,
    required this.rating,
    required this.imageAsset,
    this.description = '',
    this.hasSpiceOptions = false,
    this.remoteId,
  });

  /// Stable app id (the slug), used by favorites, the cart and saved orders.
  final String id;
  final String name;
  final String restaurantId;
  final String categoryId;

  /// Price in santim (1 ETB = 100 santim).
  final int priceSantim;

  /// Sample rating, not real customer data.
  final double rating;
  final String imageAsset;
  final String description;
  final bool hasSpiceOptions;

  /// The database id. Null for the local sample menu, which cannot be ordered
  /// from the server.
  final String? remoteId;
}
