class Restaurant {
  const Restaurant({
    required this.id,
    required this.name,
    required this.cuisine,
    required this.rating,
    required this.etaMinMinutes,
    required this.etaMaxMinutes,
    required this.deliveryFeeSantim,
  });

  final String id;
  final String name;
  final String cuisine;

  /// Sample values, not real data.
  final double rating;
  final int etaMinMinutes;
  final int etaMaxMinutes;
  final int deliveryFeeSantim;
}
