class Restaurant {
  const Restaurant({
    required this.id,
    required this.name,
    required this.cuisine,
    required this.rating,
    required this.etaMinMinutes,
    required this.etaMaxMinutes,
    required this.deliveryFeeSantim,
    this.remoteId,
  });

  /// Stable app id (the slug).
  final String id;
  final String name;
  final String cuisine;

  /// Sample values, not real data.
  final double rating;
  final int etaMinMinutes;
  final int etaMaxMinutes;
  final int deliveryFeeSantim;

  /// The database id. Null for the local sample menu.
  final String? remoteId;
}
