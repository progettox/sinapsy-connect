import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/models/auth_user_model.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(supabaseClientProvider));
});

class AuthService {
  AuthService(this._client);

  final SupabaseClient _client;

  Session? get currentSession => _client.auth.currentSession;

  AuthUserModel? get currentUser {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return AuthUserModel.fromSupabase(user);
  }

  Stream<AuthUserModel?> authChanges() {
    return _client.auth.onAuthStateChange.map((event) {
      final user = event.session?.user;
      if (user == null) return null;
      return AuthUserModel.fromSupabase(user);
    });
  }

  Future<void> signInWithGoogle() {
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: _oauthRedirectTo(),
    );
  }

  Future<void> signInWithApple() {
    return _client.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: _oauthRedirectTo(),
    );
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() {
    return _client.auth.signOut();
  }

  String? _oauthRedirectTo() {
    if (kIsWeb) return null;

    final isMobile = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (isMobile) {
      // TODO: Configurare deep link mobile per io.supabase.flutter://login-callback.
      return 'io.supabase.flutter://login-callback';
    }

    return null;
  }
}
