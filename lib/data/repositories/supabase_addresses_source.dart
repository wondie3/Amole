import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException, SupabaseClient;

import '../../features/addresses/addresses_remote_logic.dart';

/// Account addresses in Supabase. Row level security limits every call to the
/// signed-in user's own rows; this class never sends a user id.
class SupabaseAddressesSource implements RemoteAddressesSource {
  SupabaseAddressesSource(this._client);

  final SupabaseClient _client;

  Future<T> _wrap<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on PostgrestException catch (e) {
      throw AddressSourceException(code: e.code, message: e.message);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetch() => _wrap(() async {
    final rows = await _client
        .from('addresses')
        .select(
          'id, label, contact_name, phone, sub_city, street, landmark, '
          'is_selected',
        )
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  });

  @override
  Future<void> insert(Map<String, Object?> row) =>
      _wrap(() async => _client.from('addresses').insert(row));

  @override
  Future<void> update(String id, Map<String, Object?> values) =>
      _wrap(() async => _client.from('addresses').update(values).eq('id', id));

  @override
  Future<void> delete(String id) =>
      _wrap(() async => _client.from('addresses').delete().eq('id', id));

  @override
  Future<void> select(String id) =>
      _wrap(() async => _client.rpc('select_address', params: {'p_id': id}));
}
