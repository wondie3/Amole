import 'dart:convert';

import '../../models/saved_address.dart';

const int maxSavedAddresses = 10;

class AddressBook {
  const AddressBook({this.addresses = const [], this.selectedId});

  final List<SavedAddress> addresses;
  final String? selectedId;

  /// The address used for delivery. If nothing valid is selected, the first
  /// saved address is used. Null only when the book is empty.
  SavedAddress? get selected {
    if (addresses.isEmpty) return null;
    return addresses.where((a) => a.id == selectedId).firstOrNull ??
        addresses.first;
  }
}

/// Adds and selects [address]. Returns [book] unchanged (the same object) if
/// the limit is reached or the id already exists.
AddressBook addAddress(AddressBook book, SavedAddress address) {
  if (book.addresses.length >= maxSavedAddresses) return book;
  if (book.addresses.any((a) => a.id == address.id)) return book;
  return AddressBook(
    addresses: [...book.addresses, address],
    selectedId: address.id,
  );
}

AddressBook updateAddress(AddressBook book, SavedAddress address) =>
    AddressBook(
      addresses: [
        for (final a in book.addresses) a.id == address.id ? address : a,
      ],
      selectedId: book.selectedId,
    );

AddressBook deleteAddress(AddressBook book, String id) => AddressBook(
  addresses: book.addresses.where((a) => a.id != id).toList(),
  selectedId: book.selectedId == id ? null : book.selectedId,
);

AddressBook selectAddress(AddressBook book, String id) =>
    book.addresses.any((a) => a.id == id)
    ? AddressBook(addresses: book.addresses, selectedId: id)
    : book;

String? validateLabel(String? value) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return 'Give this address a name, like Home';
  if (v.length > 20) return 'Name is too long';
  return null;
}

String encodeAddressBook(AddressBook book) => jsonEncode({
  'selected': book.selected?.id,
  'items': [for (final a in book.addresses.take(maxSavedAddresses)) a.toJson()],
});

/// Reads a saved address book. Anything malformed is skipped, so bad saved
/// data can never crash the app.
AddressBook decodeAddressBook(String? raw) {
  if (raw == null || raw.isEmpty) return const AddressBook();
  try {
    final data = jsonDecode(raw);
    if (data is! Map) return const AddressBook();
    final items = data['items'];
    if (items is! List) return const AddressBook();
    final list = <SavedAddress>[];
    final seen = <String>{};
    for (final item in items) {
      final a = SavedAddress.tryFromJson(item);
      if (a != null && seen.add(a.id) && list.length < maxSavedAddresses) {
        list.add(a);
      }
    }
    final selected = data['selected'];
    return AddressBook(
      addresses: list,
      selectedId: selected is String ? selected : null,
    );
  } on FormatException {
    return const AddressBook();
  }
}
