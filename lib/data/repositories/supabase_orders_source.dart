import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException, SupabaseClient;

import '../../features/orders/orders_remote_logic.dart';

/// Account orders through Supabase functions. The server computes every price,
/// fee and total; this class never sends one except the expected total, which
/// is only a check.
class SupabaseOrdersSource implements RemoteOrdersSource {
  SupabaseOrdersSource(this._client);

  final SupabaseClient _client;

  Future<T> _wrap<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on PostgrestException catch (e) {
      throw OrderSourceException(
        code: e.code,
        message: e.message,
        details: e.details?.toString(),
      );
    }
  }

  @override
  Future<List<dynamic>> fetchOrders() => _wrap(() async {
    final res = await _client.rpc('my_orders');
    return res is List ? res : const <dynamic>[];
  });

  @override
  Future<Object?> placeOrder({
    required String idempotencyKey,
    required List<Map<String, Object?>> lines,
    required String addressId,
    required int expectedTotalSantim,
  }) => _wrap<Object?>(
    () async => _client.rpc(
      'place_order',
      params: {
        'p_idempotency_key': idempotencyKey,
        'p_lines': lines,
        'p_address_id': addressId,
        'p_payment_method': 'cash_on_delivery',
        'p_expected_total_santim': expectedTotalSantim,
      },
    ),
  );

  @override
  Future<Object?> requestCancellation(String orderId) => _wrap<Object?>(
    () async => _client.rpc(
      'request_order_cancellation',
      params: {'p_order_id': orderId},
    ),
  );

  @override
  Future<Object?> withdrawCancellation(String orderId) => _wrap<Object?>(
    () async => _client.rpc(
      'withdraw_order_cancellation',
      params: {'p_order_id': orderId},
    ),
  );
}
