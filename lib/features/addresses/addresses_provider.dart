import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/preferences_provider.dart';
import '../../models/saved_address.dart';
import 'addresses_logic.dart';

/// Saved delivery addresses, kept on this phone only (unencrypted).
class AddressesNotifier extends Notifier<AddressBook> {
  static const String storageKey = 'saved_addresses_v1';

  @override
  AddressBook build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return decodeAddressBook(prefs.getString(storageKey));
  }

  void _set(AddressBook next) {
    state = next;
    _save(next);
  }

  Future<void> _save(AddressBook book) async {
    try {
      await ref
          .read(sharedPreferencesProvider)
          .setString(storageKey, encodeAddressBook(book));
    } catch (error) {
      // Addresses still work for this session; saving failed.
      debugPrint('Could not save addresses: $error');
    }
  }

  /// Adds and selects an address. Returns false if the limit is reached.
  bool add(SavedAddress address) {
    final next = addAddress(state, address);
    if (identical(next, state)) return false;
    _set(next);
    return true;
  }

  void update(SavedAddress address) => _set(updateAddress(state, address));

  void delete(String id) => _set(deleteAddress(state, id));

  void select(String id) => _set(selectAddress(state, id));

  void clearAll() => _set(const AddressBook());
}

final addressesProvider = NotifierProvider<AddressesNotifier, AddressBook>(
  AddressesNotifier.new,
);
