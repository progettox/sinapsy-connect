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
  }) : _client = client,
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
    final normalizedUsername = data.username.trim();
    if (normalizedUsername.isEmpty) {
      throw const ProfileValidationException(
        'Username obbligatorio. Inseriscine uno valido.',
      );
    }

    await _assertUsernameAvailable(
      userId: userId,
      username: normalizedUsername,
    );

    final payload = ProfileModel(
      id: userId,
      username: normalizedUsername,
      role: data.role,
      firstName: data.firstName,
      lastName: data.lastName,
      birthDate: data.birthDate,
      bio: data.bio ?? '',
      location: data.location,
      avatarUrl: data.avatarUrl,
    ).toUpsertMap();

    try {
      final saved = await _client
          .from(_profilesTable)
          .upsert(payload, onConflict: 'id')
          .select()
          .single();
      return ProfileModel.fromMap(_toMap(saved));
    } on PostgrestException catch (error) {
      if (_isUsernameConflict(error)) {
        throw const ProfileUsernameAlreadyInUseException();
      }
      rethrow;
    }
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
    String? firstName,
    String? lastName,
    DateTime? birthDate,
  }) {
    return upsertMyProfile(
      ProfileUpsertData(
        role: role,
        username: username,
        location: location,
        firstName: firstName,
        lastName: lastName,
        birthDate: birthDate,
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

  Future<void> _assertUsernameAvailable({
    required String userId,
    required String username,
  }) async {
    final normalized = username.trim().toLowerCase();
    final rows = await _client
        .from(_profilesTable)
        .select('id,username')
        .neq('id', userId)
        .ilike('username', username)
        .limit(20);

    final candidates = (rows as List)
        .whereType<Object>()
        .map(_toMap)
        .where((row) {
          final existing = (row['username'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          return existing == normalized;
        })
        .toList(growable: false);

    if (candidates.isNotEmpty) {
      throw const ProfileUsernameAlreadyInUseException();
    }
  }

  bool _isUsernameConflict(PostgrestException error) {
    final message = error.message.toLowerCase();
    final details = (error.details ?? '').toString().toLowerCase();
    return error.code == '23505' &&
        (message.contains('username') || details.contains('username'));
  }
}

class ProfileUsernameAlreadyInUseException implements Exception {
  const ProfileUsernameAlreadyInUseException();

  String get message => 'Username gia esistente. Scegline uno diverso.';

  @override
  String toString() => message;
}

class ProfileValidationException implements Exception {
  const ProfileValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}
