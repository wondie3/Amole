/// A delivery address saved on this phone. Not linked to any account, and
/// stored unencrypted in local preferences.
class SavedAddress {
  const SavedAddress({
    required this.id,
    required this.label,
    required this.name,
    required this.phone,
    required this.subCity,
    required this.address,
    this.landmark,
  });

  final String id;
  final String label;
  final String name;
  final String phone;
  final String subCity;
  final String address;
  final String? landmark;

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'name': name,
    'phone': phone,
    'subCity': subCity,
    'address': address,
    'landmark': landmark,
  };

  /// Returns null if [json] is not a valid saved address.
  static SavedAddress? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final label = json['label'];
    final name = json['name'];
    final phone = json['phone'];
    final subCity = json['subCity'];
    final address = json['address'];
    final landmark = json['landmark'];
    if (id is! String ||
        id.isEmpty ||
        label is! String ||
        label.trim().isEmpty ||
        name is! String ||
        phone is! String ||
        subCity is! String ||
        address is! String) {
      return null;
    }
    if (landmark != null && landmark is! String) return null;
    return SavedAddress(
      id: id,
      label: label,
      name: name,
      phone: phone,
      subCity: subCity,
      address: address,
      landmark: landmark as String?,
    );
  }
}
