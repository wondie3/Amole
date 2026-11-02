import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import 'remote_catalog_repository.dart';

/// Reads the public menu. The database's row level security allows reading
/// restaurants and dishes without signing in.
class SupabaseCatalogSource implements CatalogRemoteSource {
  SupabaseCatalogSource(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Map<String, dynamic>>> restaurantRows() async {
    final rows = await _client
        .from('restaurants')
        .select(
          'id, slug, name, cuisine, rating, eta_min_minutes, eta_max_minutes, '
          'delivery_fee_santim',
        )
        .order('sort_order');
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<List<Map<String, dynamic>>> dishRows() async {
    final rows = await _client
        .from('dishes')
        .select(
          'id, slug, name, description, price_santim, rating, category, '
          'has_spice_options, image_asset, available, restaurants!inner(slug)',
        )
        .order('sort_order');
    return List<Map<String, dynamic>>.from(rows);
  }
}
