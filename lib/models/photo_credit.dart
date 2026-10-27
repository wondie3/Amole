class PhotoCredit {
  const PhotoCredit({
    required this.asset,
    required this.subject,
    required this.author,
    required this.license,
    required this.licenseUrl,
    required this.sourceUrl,
  });

  /// Asset path, e.g. assets/images/foods/tibs.jpg
  final String asset;
  final String subject;
  final String author;
  final String license;
  final String licenseUrl;
  final String sourceUrl;
}
