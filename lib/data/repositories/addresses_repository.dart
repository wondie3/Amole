import 'package:shared_preferences/shared_preferences.dart';

import '../../features/addresses/addresses_logic.dart';

/// Where saved addresses are stored. Today: this phone, unencrypted.
abstract interface class AddressesRepository {
  AddressBook load();
  Future<void> save(AddressBook book);
}

class LocalAddressesRepository implements AddressesRepository {
  const LocalAddressesRepository(this._prefs);

  static const String storageKey = 'saved_addresses_v1';

  final SharedPreferences _prefs;

  @override
  AddressBook load() => decodeAddressBook(_prefs.getString(storageKey));

  @override
  Future<void> save(AddressBook book) =>
      _prefs.setString(storageKey, encodeAddressBook(book));
}
