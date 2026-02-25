import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import 'profile_model.dart';

final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService(ref.watch(supabaseClientProvider));
});

class ProfileService {
  ProfileService(this._client);

  final SupabaseClient _client;

  Future<Map<String, dynamic>?> fetchProfile({
    required String userId,
  }) async {
    final profilesData = await _fetchFromTable(
      table: 'profiles',
      userId: userId,
    );
    if (profilesData != null) return profilesData;

    return _fetchFromTable(
      table: 'users',
      userId: userId,
    );
  }

  Future<Map<String, dynamic>> upsertProfile(ProfileModel profile) async {
    final attempts = <Future<Map<String, dynamic>?>>[
      _upsertToTable(
        table: 'profiles',
        payload: profile.toUpsertById(),
        onConflict: 'id',
      ),
      _upsertToTable(
        table: 'profiles',
        payload: profile.toUpsertByUserId(),
        onConflict: 'user_id',
      ),
      _upsertToTable(
        table: 'users',
        payload: profile.toUpsertById(),
        onConflict: 'id',
      ),
      _upsertToTable(
        table: 'users',
        payload: profile.toUpsertByUserId(),
        onConflict: 'user_id',
      ),
    ];

    for (final attempt in attempts) {
      final result = await attempt;
      if (result != null) return result;
    }

    throw StateError('Nessuna tabella valida trovata per il profilo utente.');
  }

  Future<Map<String, dynamic>?> _fetchFromTable({
    required String table,
    required String userId,
  }) async {
    final byId = await _maybeSelect(
      () => _client.from(table).select().eq('id', userId).maybeSingle(),
    );
    if (byId != null) return byId;

    return _maybeSelect(
      () => _client.from(table).select().eq('user_id', userId).maybeSingle(),
    );
  }

  Future<Map<String, dynamic>?> _upsertToTable({
    required String table,
    required Map<String, dynamic> payload,
    required String onConflict,
  }) async {
    try {
      final data = await _client
          .from(table)
          .upsert(payload, onConflict: onConflict)
          .select()
          .single();
      return _asMap(data);
    } on PostgrestException catch (error) {
      if (_isSchemaError(error)) return null;
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _maybeSelect(
    Future<dynamic> Function() request,
  ) async {
    try {
      final data = await request();
      return _asMap(data);
    } on PostgrestException catch (error) {
      if (_isSchemaError(error)) return null;
      rethrow;
    }
  }

  bool _isSchemaError(PostgrestException error) {
    return error.code == '42P01' || error.code == '42703';
  }

  Map<String, dynamic>? _asMap(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return raw.map((key, value) => MapEntry('$key', value));
    return null;
  }
}
