import 'result.dart';

class AuthUser {
  const AuthUser({required this.id, required this.email, this.name});

  final String id;
  final String email;
  final String? name;
}

/// Email and password accounts. See docs/api/auth.md. Passwords are only
/// passed through to the backend; the app never stores them.
abstract interface class AuthRepository {
  /// False when no backend is configured in this build.
  bool get isConnected;

  AuthUser? get currentUser;

  /// Emits the signed-in user, or null after sign-out.
  Stream<AuthUser?> get authChanges;

  /// Ok(user) if signed in at once, Ok(null) if email verification is needed.
  Future<Result<AuthUser?>> signUp({
    required String email,
    required String password,
    required String name,
  });

  Future<Result<AuthUser>> signIn({
    required String email,
    required String password,
  });

  /// Always looks the same to the caller, whether or not the account exists.
  Future<Result<void>> requestPasswordReset({required String email});

  Future<Result<void>> signOut();
}

/// Honest stand-in: never signs anyone in and stores nothing.
class NotConnectedAuthRepository implements AuthRepository {
  const NotConnectedAuthRepository();

  static const String message =
      'Sign-in is not available in this build. No backend is connected.';

  @override
  bool get isConnected => false;

  @override
  AuthUser? get currentUser => null;

  @override
  Stream<AuthUser?> get authChanges => Stream<AuthUser?>.empty();

  @override
  Future<Result<AuthUser?>> signUp({
    required String email,
    required String password,
    required String name,
  }) async => const NotAvailable<AuthUser?>(message);

  @override
  Future<Result<AuthUser>> signIn({
    required String email,
    required String password,
  }) async => const NotAvailable<AuthUser>(message);

  @override
  Future<Result<void>> requestPasswordReset({required String email}) async =>
      const NotAvailable<void>(message);

  @override
  Future<Result<void>> signOut() async => const NotAvailable<void>(message);
}
