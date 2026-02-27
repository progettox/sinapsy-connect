import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/profile_model.dart';
import '../../data/profile_repository.dart';

final profileControllerProvider =
    StateNotifierProvider<ProfileController, ProfileUiState>((ref) {
      return ProfileController(ref.watch(profileRepositoryProvider));
    });

class ProfileUiState {
  const ProfileUiState({
    this.isLoading = false,
    this.errorMessage,
    this.profile,
  });

  final bool isLoading;
  final String? errorMessage;
  final ProfileModel? profile;

  ProfileUiState copyWith({
    bool? isLoading,
    String? errorMessage,
    ProfileModel? profile,
    bool clearProfile = false,
    bool clearError = false,
  }) {
    return ProfileUiState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      profile: clearProfile ? null : (profile ?? this.profile),
    );
  }
}

class ProfileController extends StateNotifier<ProfileUiState> {
  ProfileController(this._repository) : super(const ProfileUiState());

  final ProfileRepository _repository;
  StreamSubscription<ProfileModel?>? _watchSubscription;
  bool _isWatching = false;

  Future<ProfileModel?> loadMyProfile() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final profile = await _repository.getMyProfile();
      state = state.copyWith(
        isLoading: false,
        profile: profile,
        clearError: true,
      );
      return profile;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Errore caricamento profilo: $error',
      );
      return null;
    }
  }

  Future<ProfileModel?> upsertMyProfile({
    required ProfileRole role,
    required String username,
    required String location,
    String? firstName,
    String? lastName,
    DateTime? birthDate,
    String? bio,
    String? avatarUrl,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final profile = await _repository.upsertMyProfile(
        ProfileUpsertData(
          role: role,
          username: username,
          location: location,
          firstName: firstName,
          lastName: lastName,
          birthDate: birthDate,
          bio: bio,
          avatarUrl: avatarUrl,
        ),
      );
      state = state.copyWith(
        isLoading: false,
        profile: profile,
        clearError: true,
      );
      return profile;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Errore salvataggio profilo: $error',
      );
      return null;
    }
  }

  void watchMyProfile() {
    if (_isWatching) return;
    _isWatching = true;

    _watchSubscription = _repository.watchMyProfile().listen(
      (profile) {
        state = state.copyWith(
          profile: profile,
          clearProfile: profile == null,
          clearError: true,
        );
      },
      onError: (Object error) {
        state = state.copyWith(
          errorMessage: 'Errore aggiornamento realtime profilo: $error',
        );
      },
    );
  }

  Future<ProfileModel?> loadCurrentProfile() => loadMyProfile();

  Future<ProfileModel?> completeProfile({
    required ProfileRole role,
    required String username,
    required String location,
    String? firstName,
    String? lastName,
    DateTime? birthDate,
  }) {
    return upsertMyProfile(
      role: role,
      username: username,
      location: location,
      firstName: firstName,
      lastName: lastName,
      birthDate: birthDate,
    );
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  @override
  void dispose() {
    _watchSubscription?.cancel();
    super.dispose();
  }
}
