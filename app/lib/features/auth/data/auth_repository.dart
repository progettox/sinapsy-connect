import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/auth_user_model.dart';
import 'auth_service.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(authServiceProvider));
});

class AuthRepository {
  AuthRepository(this._service);

  final AuthService _service;

  Session? get currentSession => _service.currentSession;

  AuthUserModel? get currentUser => _service.currentUser;

  Stream<AuthUserModel?> authChanges() => _service.authChanges();

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _service.signInWithEmail(email: email, password: password);
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) {
    return _service.signUpWithEmail(email: email, password: password);
  }

  Future<void> signOut() => _service.signOut();
}
