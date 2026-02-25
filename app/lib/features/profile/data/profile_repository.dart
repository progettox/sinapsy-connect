import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../auth/data/auth_repository.dart';
import 'profile_model.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(
    client: ref.watch(supabaseClientProvider),
    authRepository: ref.watch(authRepositoryProvider),
  );
});

class ProfileRepository {
  ProfileRepository({
    required SupabaseClient client,
    required AuthRepository authRepository,
  })  : _client = client,
        _authRepository = authRepository;

  static const String _profilesTable = 'profiles';

  final SupabaseClient _client;
  final AuthRepository _authRepository;

  Future<ProfileModel?> getMyProfile() async {
    final userId = _authRepository.currentUser?.id;
    if (userId == null) return null;

    final raw = await _client
        .from(_profilesTable)
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (raw == null) return null;
    return ProfileModel.fromMap(_toMap(raw));
  }

  Future<ProfileModel> upsertMyProfile(ProfileUpsertData data) async {
    final userId = _authRepository.currentUser?.id;
    if (userId == null) {
      throw StateError('Sessione non valida: impossibile salvare il profilo.');
    }

    final payload = ProfileModel(
      id: userId,
      username: data.username,
      role: data.role,
      bio: data.bio ?? '',
      location: data.location,
      avatarUrl: data.avatarUrl,
    ).toUpsertMap();

    final saved = await _client
        .from(_profilesTable)
        .upsert(payload, onConflict: 'id')
        .select()
        .single();
    return ProfileModel.fromMap(_toMap(saved));
  }

  Stream<ProfileModel?> watchMyProfile() {
    final userId = _authRepository.currentUser?.id;
    if (userId == null) return Stream<ProfileModel?>.value(null);

    return _client
        .from(_profilesTable)
        .stream(primaryKey: const ['id'])
        .eq('id', userId)
        .map((rows) {
          if (rows.isEmpty) return null;
          return ProfileModel.fromMap(_toMap(rows.first));
        });
  }

  Future<ProfileModel?> getCurrentProfile() => getMyProfile();

  Future<ProfileModel> completeCurrentProfile({
    required ProfileRole role,
    required String username,
    required String location,
  }) {
    return upsertMyProfile(
      ProfileUpsertData(
        role: role,
        username: username,
        location: location,
      ),
    );
  }

  Map<String, dynamic> _toMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry('$key', value));
    }
    throw StateError('Formato risposta profilo non valido.');
  }
}
