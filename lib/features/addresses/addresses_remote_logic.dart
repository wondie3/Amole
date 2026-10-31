import 'dart:math' as math;

import '../../models/saved_address.dart';
import 'addresses_logic.dart';

const String addressLimitMessage =
    'You have reached the limit of saved addresses. Delete one first.';
const String addressNetworkMessage =
    'Could not reach the server. Check your connection and try again.';
const String addressSignInAgainMessage =
    'Please sign in again to change your addresses.';
const String addressRejectedMessage =
    'The server rejected some address details. Check them and try again.';
const String addressMissingMessage = 'That address no longer exists.';
const String addressGenericMessage = 'Something went wrong. Please try again.';

/// A failure reported by the backend, reduced to a code and message.
class AddressSourceException implements Exception {
  const AddressSourceException({this.code, this.message});

  final String? code;
  final String? message;

  @override
  String toString() => 'AddressSourceException(code: $code)';
}

/// Where account addresses are stored. The real one talks to Supabase; tests
/// use a fake.
abstract interface class RemoteAddressesSource {
  Future<List<Map<String, dynamic>>> fetch();
  Future<void> insert(Map<String, Object?> row);
  Future<void> update(String id, Map<String, Object?> values);
  Future<void> delete(String id);
  Future<void> select(String id);
}

/// A message that is safe to show. Never includes server details.
String friendlyAddressError(Object error) {
  if (error is! AddressSourceException) return addressNetworkMessage;
  final text = (error.message ?? '').toLowerCase();
  if (text.contains('address_limit_reached')) return addressLimitMessage;
  if (text.contains('not_found')) return addressMissingMessage;
  switch (error.code) {
    case '42501':
    case 'PGRST301':
      return addressSignInAgainMessage;
    case '23514':
      return addressRejectedMessage;
  }
  return addressGenericMessage;
}

/// Returns null if [row] is not a valid address row.
SavedAddress? addressFromRow(Object? row) {
  if (row is! Map) return null;
  return SavedAddress.tryFromJson({
    'id': row['id'],
    'label': row['label'],
    'name': row['contact_name'],
    'phone': row['phone'],
    'subCity': row['sub_city'],
    'address': row['street'],
    'landmark': row['landmark'],
  });
}

Map<String, Object?> addressToRow(SavedAddress a) {
  final landmark = a.landmark?.trim();
  return {
    'id': a.id,
    'label': a.label.trim(),
    'contact_name': a.name.trim(),
    'phone': a.phone,
    'sub_city': a.subCity,
    'street': a.address.trim(),
    'landmark': (landmark == null || landmark.isEmpty) ? null : landmark,
  };
}

/// Values for an update. Never touches the id, owner or selection.
Map<String, Object?> addressToUpdate(SavedAddress a) =>
    Map<String, Object?>.of(addressToRow(a))..remove('id');

SavedAddress addressWithId(SavedAddress a, String id) => SavedAddress(
  id: id,
  label: a.label,
  name: a.name,
  phone: a.phone,
  subCity: a.subCity,
  address: a.address,
  landmark: a.landmark,
);

/// Builds the address book from server rows. Invalid rows and duplicate ids
/// are skipped, and the book never holds more than the limit.
AddressBook bookFromRows(List<Map<String, dynamic>> rows) {
  final list = <SavedAddress>[];
  final seen = <String>{};
  String? selectedId;
  for (final row in rows) {
    final a = addressFromRow(row);
    if (a == null || !seen.add(a.id) || list.length >= maxSavedAddresses) {
      continue;
    }
    list.add(a);
    if (selectedId == null && row['is_selected'] == true) selectedId = a.id;
  }
  return AddressBook(addresses: list, selectedId: selectedId);
}

String _norm(String? s) =>
    (s ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Two addresses with the same contact, place and landmark are the same
/// address, whatever their label.
String dedupeKey(SavedAddress a) =>
    [a.name, a.phone, a.subCity, a.address, a.landmark].map(_norm).join('|');

class CopyPlan {
  const CopyPlan({
    required this.toCopy,
    required this.duplicates,
    required this.overLimit,
  });

  final List<SavedAddress> toCopy;
  final List<SavedAddress> duplicates;
  final List<SavedAddress> overLimit;
}

/// Decides what a copy would do, without doing it.
CopyPlan planCopy({
  required List<SavedAddress> existing,
  required List<SavedAddress> local,
}) {
  final seen = {for (final a in existing) dedupeKey(a)};
  var capacity = math.max(0, maxSavedAddresses - existing.length);
  final toCopy = <SavedAddress>[];
  final duplicates = <SavedAddress>[];
  final overLimit = <SavedAddress>[];
  for (final a in local) {
    if (!seen.add(dedupeKey(a))) {
      duplicates.add(a);
    } else if (capacity > 0) {
      toCopy.add(a);
      capacity--;
    } else {
      overLimit.add(a);
    }
  }
  return CopyPlan(toCopy: toCopy, duplicates: duplicates, overLimit: overLimit);
}

class CopyReport {
  const CopyReport({
    this.copied = 0,
    this.duplicates = 0,
    this.overLimit = 0,
    this.failed = 0,
    this.firstError,
  });

  final int copied;
  final int duplicates;
  final int overLimit;
  final int failed;
  final String? firstError;
}

/// A random (version 4) UUID, which is what the database uses as an id.
String newUuid([math.Random? random]) {
  final r = random ?? math.Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
  return '${h(0)}${h(1)}${h(2)}${h(3)}-${h(4)}${h(5)}-${h(6)}${h(7)}-'
      '${h(8)}${h(9)}-${h(10)}${h(11)}${h(12)}${h(13)}${h(14)}${h(15)}';
}
