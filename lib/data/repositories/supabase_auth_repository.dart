import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, SupabaseClient, User;

import 'auth_repository.dart';
import 'result.dart';

/// Email and password auth through Supabase. Only constructed when the build
/// supplies a Supabase URL and key.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  static const String _generic = 'Something went wrong. Please try again.';
  static const String _network =
      'Could not reach the server. Check your connection and try again.';

  AuthUser? _map(User? u) {
    if (u == null) return null;
    final name = u.userMetadata?['name'];
    return AuthUser(
      id: u.id,
      email: u.email ?? '',
      name: name is String ? name : null,
    );
  }

  String _friendly(String raw) {
    final m = raw.toLowerCase();
    if (m.contains('invalid login') || m.contains('invalid credentials')) {
      return 'Email or password is incorrect.';
    }
    if (m.contains('not confirmed')) {
      return 'Please verify your email first. Check your inbox.';
    }
    if (m.contains('rate limit') || m.contains('too many')) {
      return 'Too many attempts. Wait a moment and try again.';
    }
    if (m.contains('password')) {
      return 'That password was not accepted. Use at least 10 characters.';
    }
    return _generic;
  }

  Future<Result<T>> _guard<T>(Future<Result<T>> Function() body) async {
    try {
      return await body();
    } on AuthException catch (e) {
      return Failure<T>(_friendly(e.message));
    } catch (e) {
      // Log only the type: messages could contain request details.
      debugPrint('Auth request failed: ${e.runtimeType}');
      return Failure<T>(_network);
    }
  }

  @override
  bool get isConnected => true;

  @override
  AuthUser? get currentUser => _map(_client.auth.currentUser);

  @override
  Stream<AuthUser?> get authChanges =>
      _client.auth.onAuthStateChange.map((s) => _map(s.session?.user));

  @override
  Future<Result<AuthUser?>> signUp({
    required String email,
    required String password,
    required String name,
  }) => _guard<AuthUser?>(() async {
    final res = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'name': name.trim()},
    );
    return Ok<AuthUser?>(res.session == null ? null : _map(res.user));
  });

  @override
  Future<Result<AuthUser>> signIn({
    required String email,
    required String password,
  }) => _guard<AuthUser>(() async {
    final res = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    final user = _map(res.user);
    if (user == null) return const Failure<AuthUser>(_generic);
    return Ok<AuthUser>(user);
  });

  @override
  Future<Result<void>> requestPasswordReset({required String email}) =>
      _guard<void>(() async {
        await _client.auth.resetPasswordForEmail(email.trim());
        return const Ok<void>(null);
      });

  @override
  Future<Result<void>> signOut() => _guard<void>(() async {
    await _client.auth.signOut();
    return const Ok<void>(null);
  });
}
