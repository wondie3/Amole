import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/repository_providers.dart';

/// The signed-in user, or null. Follows the repository's auth changes.
class AuthNotifier extends Notifier<AuthUser?> {
  @override
  AuthUser? build() {
    final repo = ref.watch(authRepositoryProvider);
    final sub = repo.authChanges.listen((user) => state = user);
    ref.onDispose(sub.cancel);
    return repo.currentUser;
  }
}

final authUserProvider = NotifierProvider<AuthNotifier, AuthUser?>(
  AuthNotifier.new,
);
