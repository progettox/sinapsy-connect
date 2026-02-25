import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/home_repository.dart';
import '../../data/home_user_model.dart';

final homeControllerProvider =
    StateNotifierProvider<HomeController, HomeUiState>((ref) {
      return HomeController(ref.watch(homeRepositoryProvider));
    });

class HomeUiState {
  const HomeUiState({
    this.isLoading = false,
    this.errorMessage,
    this.user,
  });

  final bool isLoading;
  final String? errorMessage;
  final HomeUserModel? user;

  HomeUiState copyWith({
    bool? isLoading,
    String? errorMessage,
    HomeUserModel? user,
    bool clearError = false,
  }) {
    return HomeUiState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      user: user ?? this.user,
    );
  }
}

class HomeController extends StateNotifier<HomeUiState> {
  HomeController(this._repository)
      : super(
          HomeUiState(user: _repository.currentUser),
        );

  final HomeRepository _repository;

  void refreshCurrentUser() {
    state = state.copyWith(user: _repository.currentUser, clearError: true);
  }

  Future<bool> logout() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.signOut();
      state = state.copyWith(isLoading: false, clearError: true, user: null);
      return true;
    } on AuthException catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.message,
      );
      return false;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Errore logout: $error',
      );
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}
