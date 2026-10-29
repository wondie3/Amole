import 'result.dart';

class AuthUser {
  const AuthUser({required this.id, required this.phone, this.name});

  final String id;
  final String phone;
  final String? name;
}

/// Sign-in. See docs/api/auth.md. No backend exists yet, so the only
/// implementation is [NotConnectedAuthRepository].
abstract interface class AuthRepository {
  Future<Result<void>> requestOtp(String phone);
  Future<Result<AuthUser>> verifyOtp(String phone, String code);
  Future<AuthUser?> currentUser();
  Future<Result<void>> signOut();
}

/// Honest stand-in: never signs anyone in and stores nothing.
class NotConnectedAuthRepository implements AuthRepository {
  const NotConnectedAuthRepository();

  static const String message =
      'Sign-in is not available yet. No backend is connected.';

  @override
  Future<Result<void>> requestOtp(String phone) async =>
      const NotAvailable<void>(message);

  @override
  Future<Result<AuthUser>> verifyOtp(String phone, String code) async =>
      const NotAvailable<AuthUser>(message);

  @override
  Future<AuthUser?> currentUser() async => null;

  @override
  Future<Result<void>> signOut() async => const NotAvailable<void>(message);
}
