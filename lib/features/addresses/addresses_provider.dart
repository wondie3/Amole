import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/addresses_repository.dart';
import '../../data/repository_providers.dart';
import '../../models/saved_address.dart';
import 'addresses_logic.dart';

/// Saved delivery addresses, stored through the addresses repository.
class AddressesNotifier extends Notifier<AddressBook> {
  static const String storageKey = LocalAddressesRepository.storageKey;

  @override
  AddressBook build() => ref.watch(addressesRepositoryProvider).load();

  void _set(AddressBook next) {
    state = next;
    _save(next);
  }

  Future<void> _save(AddressBook book) async {
    try {
      await ref.read(addressesRepositoryProvider).save(book);
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
