import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../auth/domain/models/auth_user_model.dart';
import '../../data/profile_model.dart';
import '../../data/profile_repository.dart';

final profileControllerProvider =
    StateNotifierProvider<ProfileController, ProfileUiState>((ref) {
      return ProfileController(
        ref.watch(profileRepositoryProvider),
        ref.watch(authRepositoryProvider),
      );
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
  ProfileController(this._repository, this._authRepository)
    : super(const ProfileUiState()) {
    _handleAuthUserChanged(_authRepository.currentUser);
    _authSubscription = _authRepository.authChanges().listen(
      _handleAuthUserChanged,
      onError: (_) {},
    );
  }

  final ProfileRepository _repository;
  final AuthRepository _authRepository;
  StreamSubscription<AuthUserModel?>? _authSubscription;
  StreamSubscription<ProfileModel?>? _watchSubscription;
  String? _watchedUserId;

  void _handleAuthUserChanged(AuthUserModel? user) {
    final nextUserId = user?.id;

    if (nextUserId == null) {
      _watchSubscription?.cancel();
      _watchSubscription = null;
      _watchedUserId = null;
      if (state.profile != null ||
          state.errorMessage != null ||
          state.isLoading) {
        state = const ProfileUiState();
      }
      return;
    }

    final currentProfileId = state.profile?.id;
    final needsRebind =
        _watchedUserId != nextUserId ||
        (currentProfileId != null && currentProfileId != nextUserId);
    if (!needsRebind) return;

    _watchSubscription?.cancel();
    _watchSubscription = null;
    _watchedUserId = null;
    state = state.copyWith(
      isLoading: false,
      clearProfile: true,
      clearError: true,
    );

    watchMyProfile();
    unawaited(loadMyProfile());
  }

  Future<ProfileModel?> loadMyProfile() async {
    final userId = _repository.currentUserId;
    if (userId == null) {
      state = state.copyWith(
        isLoading: false,
        clearProfile: true,
        clearError: true,
      );
      return null;
    }

    final currentProfileUserId = state.profile?.id;
    if (currentProfileUserId != null && currentProfileUserId != userId) {
      // Prevent briefly showing another account's avatar/data during account switch.
      state = state.copyWith(clearProfile: true, clearError: true);
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final profile = await _repository.getMyProfile();
      state = state.copyWith(
        isLoading: false,
        profile: profile,
        clearProfile: profile == null,
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
    String? instagramUrl,
    String? tiktokUrl,
    String? websiteUrl,
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
          instagramUrl: instagramUrl,
          tiktokUrl: tiktokUrl,
          websiteUrl: websiteUrl,
        ),
      );
      state = state.copyWith(
        isLoading: false,
        profile: profile,
        clearError: true,
      );
      return profile;
    } on ProfileUsernameAlreadyInUseException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
      return null;
    } on ProfileValidationException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
      return null;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Errore salvataggio profilo: $error',
      );
      return null;
    }
  }

  void watchMyProfile() {
    final userId = _repository.currentUserId;
    if (userId == null) {
      _watchSubscription?.cancel();
      _watchSubscription = null;
      _watchedUserId = null;
      state = state.copyWith(clearProfile: true, clearError: true);
      return;
    }

    if (_watchSubscription != null && _watchedUserId == userId) return;

    _watchSubscription?.cancel();
    _watchedUserId = userId;

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
    String? instagramUrl,
    String? tiktokUrl,
    String? websiteUrl,
  }) {
    return upsertMyProfile(
      role: role,
      username: username,
      location: location,
      firstName: firstName,
      lastName: lastName,
      birthDate: birthDate,
      instagramUrl: instagramUrl,
      tiktokUrl: tiktokUrl,
      websiteUrl: websiteUrl,
    );
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void reset() {
    _watchSubscription?.cancel();
    _watchSubscription = null;
    _watchedUserId = null;
    state = const ProfileUiState();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _watchSubscription?.cancel();
    super.dispose();
  }
}
