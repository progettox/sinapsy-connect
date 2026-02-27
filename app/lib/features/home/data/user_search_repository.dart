import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client_provider.dart';

final userSearchRepositoryProvider = Provider<UserSearchRepository>((ref) {
  return UserSearchRepository(ref.watch(supabaseClientProvider));
});

class UserSearchRepository {
  UserSearchRepository(this._client);

  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<List<UserSearchResult>> searchByUsername(
    String query, {
    String? excludeUserId,
    int limit = 25,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return const <UserSearchResult>[];

    final raw = await _client
        .from('profiles')
        .select('id, username, role, avatar_url, location')
        .ilike('username', '%$cleanQuery%')
        .order('username')
        .limit(limit);

    final rows = List<Map<String, dynamic>>.from(raw);

    final results = <UserSearchResult>[];
    for (final row in rows) {
      final user = UserSearchResult.fromMap(row);
      if (user.username.isEmpty) continue;
      if (excludeUserId != null && excludeUserId == user.id) continue;
      results.add(user);
    }
    return results;
  }

  Future<List<UserSearchResult>> listUsers({
    String? excludeUserId,
    String? role,
    int limit = 20,
  }) async {
    final cleanRole = role?.trim().toLowerCase();
    dynamic queryBuilder = _client
        .from('profiles')
        .select('id, username, role, avatar_url, location')
        .order('username')
        .limit(limit);

    if (cleanRole != null && cleanRole.isNotEmpty) {
      queryBuilder = queryBuilder.eq('role', cleanRole);
    }

    final raw = await queryBuilder;
    final rows = List<Map<String, dynamic>>.from(raw);

    final results = <UserSearchResult>[];
    for (final row in rows) {
      final user = UserSearchResult.fromMap(row);
      if (user.username.isEmpty) continue;
      if (excludeUserId != null && excludeUserId == user.id) continue;
      results.add(user);
    }
    return results;
  }
}

class UserSearchResult {
  const UserSearchResult({
    required this.id,
    required this.username,
    required this.role,
    required this.location,
    this.avatarUrl,
  });

  final String id;
  final String username;
  final String role;
  final String location;
  final String? avatarUrl;

  String get roleLabel {
    switch (role.trim().toLowerCase()) {
      case 'brand':
        return 'Brand';
      case 'creator':
        return 'Creator';
      default:
        return 'Utente';
    }
  }

  factory UserSearchResult.fromMap(Map<String, dynamic> map) {
    final id = (map['id'] ?? map['user_id'] ?? '').toString();
    return UserSearchResult(
      id: id,
      username: (map['username'] ?? '').toString().trim(),
      role: (map['role'] ?? '').toString().trim(),
      location: (map['location'] ?? '').toString(),
      avatarUrl: _nullableString(map['avatar_url']),
    );
  }

  static String? _nullableString(dynamic raw) {
    final value = (raw ?? '').toString().trim();
    if (value.isEmpty) return null;
    return value;
  }
}
