import '../../models/order.dart';
import 'result.dart';

enum PaymentStatus { pending, paid, failed, refunded }

/// Online payments. See docs/api/payments.md. Success must be decided by a
/// verified provider callback on a server, never by the app. No provider is
/// connected, so the only implementation is [NotConnectedPaymentRepository].
abstract interface class PaymentRepository {
  Future<Result<PaymentStatus>> startPayment({
    required String orderId,
    required PaymentMethod method,
    required int amountSantim,
  });

  Future<Result<PaymentStatus>> paymentStatus(String orderId);
}

/// Honest stand-in: never reports a payment as started or paid.
class NotConnectedPaymentRepository implements PaymentRepository {
  const NotConnectedPaymentRepository();

  static const String message =
      'Online payment is not available yet. No payment provider is connected.';

  @override
  Future<Result<PaymentStatus>> startPayment({
    required String orderId,
    required PaymentMethod method,
    required int amountSantim,
  }) async => const NotAvailable<PaymentStatus>(message);

  @override
  Future<Result<PaymentStatus>> paymentStatus(String orderId) async =>
      const NotAvailable<PaymentStatus>(message);
}
