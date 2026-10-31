import 'dart:math';

import 'package:amole/features/addresses/addresses_logic.dart';
import 'package:amole/features/addresses/addresses_remote_logic.dart';
import 'package:amole/models/saved_address.dart';
import 'package:flutter_test/flutter_test.dart';

SavedAddress _a(
  String id, {
  String label = 'Home',
  String street = 'Near Edna Mall',
  String subCity = 'Bole',
  String? landmark,
}) => SavedAddress(
  id: id,
  label: label,
  name: 'Abebe Kebede',
  phone: '+251911223344',
  subCity: subCity,
  address: street,
  landmark: landmark,
);

Map<String, dynamic> _row(
  String id, {
  bool selected = false,
  String label = 'Home',
}) => {
  'id': id,
  'label': label,
  'contact_name': 'Abebe Kebede',
  'phone': '+251911223344',
  'sub_city': 'Bole',
  'street': 'Near Edna Mall',
  'landmark': null,
  'is_selected': selected,
};

void main() {
  group('rows', () {
    test('a row becomes an address', () {
      final a = addressFromRow(_row('a'))!;
      expect(a.name, 'Abebe Kebede');
      expect(a.address, 'Near Edna Mall');
      expect(a.subCity, 'Bole');
      expect(a.landmark, isNull);
    });

    test('bad rows are rejected', () {
      expect(addressFromRow({'id': 'x'}), isNull);
      expect(addressFromRow(5), isNull);
      expect(addressFromRow(null), isNull);
    });

    test('an address becomes a row with database column names', () {
      final row = addressToRow(_a('a', landmark: '  Blue gate '));
      expect(row['contact_name'], 'Abebe Kebede');
      expect(row['sub_city'], 'Bole');
      expect(row['street'], 'Near Edna Mall');
      expect(row['landmark'], 'Blue gate');
      expect(row.containsKey('user_id'), isFalse);
      expect(row.containsKey('is_selected'), isFalse);
    });

    test('an empty landmark is stored as null', () {
      expect(addressToRow(_a('a', landmark: '  '))['landmark'], isNull);
    });

    test('an update never carries the id', () {
      expect(addressToUpdate(_a('a')).containsKey('id'), isFalse);
    });
  });

  group('books from rows', () {
    test('the selected row wins, bad and duplicate rows are skipped', () {
      final book = bookFromRows([
        _row('a'),
        {'id': 'bad'},
        _row('b', selected: true, label: 'Work'),
        _row('a'),
      ]);
      expect(book.addresses.map((x) => x.id), ['a', 'b']);
      expect(book.selected?.id, 'b');
    });

    test('with no selected row the first address is used', () {
      final book = bookFromRows([_row('a'), _row('b')]);
      expect(book.selected?.id, 'a');
    });

    test('an empty result is an empty book', () {
      expect(bookFromRows(const []).addresses, isEmpty);
    });

    test('the limit is respected', () {
      final rows = [for (var i = 0; i < 14; i++) _row('id$i')];
      expect(bookFromRows(rows).addresses.length, maxSavedAddresses);
    });
  });

  group('copy planning', () {
    test('the duplicate key ignores case, spacing and the label', () {
      expect(
        dedupeKey(_a('a', street: 'Near  Edna   Mall')),
        dedupeKey(_a('b', label: 'Work', street: ' near edna mall ')),
      );
      expect(dedupeKey(_a('a')), isNot(dedupeKey(_a('b', subCity: 'Kirkos'))));
    });

    test('new addresses are copied, duplicates are skipped', () {
      final plan = planCopy(
        existing: [_a('s1')],
        local: [
          _a('l1'),
          _a('l2', street: 'Meskel Square area'),
        ],
      );
      expect(plan.toCopy.map((x) => x.id), ['l2']);
      expect(plan.duplicates.map((x) => x.id), ['l1']);
      expect(plan.overLimit, isEmpty);
    });

    test('duplicates inside the phone list are copied once', () {
      final plan = planCopy(
        existing: const [],
        local: [
          _a('l1'),
          _a('l2', label: 'Copy'),
        ],
      );
      expect(plan.toCopy.length, 1);
      expect(plan.duplicates.length, 1);
    });

    test('the account limit caps the copy', () {
      final existing = [
        for (var i = 0; i < 9; i++) _a('s$i', street: 'Street number $i'),
      ];
      final plan = planCopy(
        existing: existing,
        local: [
          _a('l1', street: 'Other one'),
          _a('l2', street: 'Another'),
        ],
      );
      expect(plan.toCopy.length, 1);
      expect(plan.overLimit.length, 1);
    });
  });

  test('new ids are valid version 4 UUIDs and differ', () {
    final shape = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    final ids = {for (var i = 0; i < 50; i++) newUuid()};
    expect(ids.length, 50);
    for (final id in ids) {
      expect(shape.hasMatch(id), isTrue, reason: id);
    }
    expect(newUuid(Random(1)), newUuid(Random(1)));
  });

  test('errors become friendly messages without server details', () {
    expect(
      friendlyAddressError(
        const AddressSourceException(
          code: '23514',
          message: 'address_limit_reached',
        ),
      ),
      addressLimitMessage,
    );
    expect(
      friendlyAddressError(const AddressSourceException(code: '23514')),
      addressRejectedMessage,
    );
    expect(
      friendlyAddressError(const AddressSourceException(code: '42501')),
      addressSignInAgainMessage,
    );
    expect(
      friendlyAddressError(const AddressSourceException(message: 'not_found')),
      addressMissingMessage,
    );
    expect(
      friendlyAddressError(const AddressSourceException(code: '99999')),
      addressGenericMessage,
    );
    expect(friendlyAddressError(Exception('socket')), addressNetworkMessage);
  });
}
