import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/auth_repository.dart';
import '../../domain/models/auth_user_model.dart';

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthUiState>((ref) {
      return AuthController(ref.watch(authRepositoryProvider));
    });

final authChangesProvider = StreamProvider<AuthUserModel?>((ref) {
  return ref.watch(authRepositoryProvider).authChanges();
});

class AuthUiState {
  const AuthUiState({this.isLoading = false, this.errorMessage});

  final bool isLoading;
  final String? errorMessage;

  AuthUiState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthUiState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AuthController extends StateNotifier<AuthUiState> {
  AuthController(this._repository) : super(const AuthUiState());

  final AuthRepository _repository;

  Future<bool> signInWithGoogle() => _run(_repository.signInWithGoogle);

  Future<bool> signInWithApple() => _run(_repository.signInWithApple);

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _run(
      () => _repository.signInWithEmail(email: email, password: password),
    );
  }

  Future<bool> signUpWithEmail({
    required String email,
    required String password,
  }) {
    return _run(
      () => _repository.signUpWithEmail(email: email, password: password),
    );
  }

  Future<bool> signOut() => _run(_repository.signOut);

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  Future<bool> _run(Future<void> Function() action) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await action();
      final session = _repository.currentSession;
      _log(
        'auth.success session=${session != null} userId=${session?.user.id}',
      );
      state = state.copyWith(isLoading: false, clearError: true);
      return true;
    } on AuthException catch (error) {
      _log('auth.error.auth_exception message=${error.message}');
      state = state.copyWith(isLoading: false, errorMessage: error.message);
      return false;
    } catch (error) {
      _log('auth.error.generic error=$error');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Errore inatteso: $error',
      );
      return false;
    }
  }

  void _log(String message) {
    if (!kDebugMode) return;
    debugPrint('[AuthController] $message');
  }
}
