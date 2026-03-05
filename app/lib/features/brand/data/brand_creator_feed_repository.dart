import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client_provider.dart';

final brandCreatorFeedRepositoryProvider = Provider<BrandCreatorFeedRepository>(
  (ref) {
    return BrandCreatorFeedRepository(ref.watch(supabaseClientProvider));
  },
);

class CreatorFeedCard {
  const CreatorFeedCard({
    required this.id,
    required this.username,
    required this.displayName,
    required this.role,
    required this.location,
    required this.category,
    required this.avatarUrl,
    required this.heroImageUrl,
    required this.portfolioThumbUrls,
    required this.isSaved,
    this.followersCount,
    this.followingCount,
    this.completedWorksCount,
  });

  final String id;
  final String username;
  final String displayName;
  final String role;
  final String location;
  final String category;
  final String? avatarUrl;
  final String? heroImageUrl;
  final List<String> portfolioThumbUrls;
  final bool isSaved;
  final int? followersCount;
  final int? followingCount;
  final int? completedWorksCount;
  bool get isFollowing => isSaved;

  CreatorFeedCard copyWith({
    bool? isSaved,
    List<String>? portfolioThumbUrls,
    String? heroImageUrl,
    int? followersCount,
    int? followingCount,
    int? completedWorksCount,
  }) {
    return CreatorFeedCard(
      id: id,
      username: username,
      displayName: displayName,
      role: role,
      location: location,
      category: category,
      avatarUrl: avatarUrl,
      heroImageUrl: heroImageUrl ?? this.heroImageUrl,
      portfolioThumbUrls: portfolioThumbUrls ?? this.portfolioThumbUrls,
      isSaved: isSaved ?? this.isSaved,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      completedWorksCount: completedWorksCount ?? this.completedWorksCount,
    );
  }
}

class CreatorFollowCounters {
  const CreatorFollowCounters({
    required this.isFollowing,
    required this.followersCount,
    required this.followingCount,
  });

  final bool isFollowing;
  final int followersCount;
  final int followingCount;
}

class BrandCreatorFeedRepository {
  BrandCreatorFeedRepository(this._client);

  final SupabaseClient _client;
  static const List<_FollowStorageSchema> _followStorageCandidates =
      <_FollowStorageSchema>[
        _FollowStorageSchema(
          table: 'profile_followers',
          followerColumn: 'follower_id',
          followedColumn: 'followed_id',
        ),
        _FollowStorageSchema(
          table: 'user_follows',
          followerColumn: 'follower_id',
          followedColumn: 'following_id',
        ),
        _FollowStorageSchema(
          table: 'creator_followers',
          followerColumn: 'follower_id',
          followedColumn: 'creator_id',
        ),
        _FollowStorageSchema(
          table: 'brand_saved_creators',
          followerColumn: 'brand_id',
          followedColumn: 'creator_id',
        ),
      ];

  List<_FollowStorageSchema>? _cachedFollowSchemas;

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<List<CreatorFeedCard>> listCreatorCards({
    String? role,
    int limit = 60,
  }) async {
    final cleanRole = role?.trim().toLowerCase();
    final profileRows = await _fetchProfilesRows(
      cleanRole: cleanRole,
      limit: limit,
    );

    final profileIds = profileRows
        .map((row) => (row['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);

    final mediaByCreator = await _loadMediaByCreator(profileIds);
    final followSnapshot = await _loadFollowSnapshot(profileIds);

    final cards = <CreatorFeedCard>[];
    for (final row in profileRows) {
      final id = (row['id'] ?? '').toString();
      if (id.isEmpty) continue;

      final username = (row['username'] ?? '').toString().trim();
      if (username.isEmpty) continue;

      final firstName = (row['first_name'] ?? '').toString().trim();
      final lastName = (row['last_name'] ?? '').toString().trim();
      final displayName = [
        firstName,
        lastName,
      ].where((part) => part.isNotEmpty).join(' ');
      final roleValue = (row['role'] ?? '').toString().trim();
      final normalizedRole = _normalizeRole(roleValue);
      if (cleanRole != null && cleanRole.isNotEmpty) {
        if (normalizedRole != cleanRole) continue;
      }
      final location = (row['location'] ?? '').toString().trim();
      final avatarUrl = _nullableString(row['avatar_url']);
      final bio = (row['bio'] ?? '').toString();
      final category = _extractCategoryFromBio(
        bio,
        normalizedRole: normalizedRole,
      );
      final followersCount = _parseInt(
        row['followers_count'] ?? row['followersCount'],
      );
      final followingCount = _parseInt(
        row['following_count'] ?? row['followingCount'],
      );

      final media = mediaByCreator[id] ?? const <_CreatorMedia>[];
      final heroImageUrl = avatarUrl;

      final thumbUrls = media
          .map((item) => item.imageUrl)
          .where((url) => url.isNotEmpty && url != heroImageUrl)
          .take(6)
          .toList(growable: false);

      cards.add(
        CreatorFeedCard(
          id: id,
          username: username,
          displayName: displayName.isEmpty ? username : displayName,
          role: _roleLabel(normalizedRole, fallback: roleValue),
          location: location,
          category: category,
          avatarUrl: avatarUrl,
          heroImageUrl: heroImageUrl,
          portfolioThumbUrls: thumbUrls,
          isSaved: followSnapshot.followedCreatorIds.contains(id),
          followersCount: _bestAvailableCount(
            profileCount: followersCount,
            runtimeCount: followSnapshot.followerCountsByCreatorId[id],
          ),
          followingCount: _bestAvailableCount(
            profileCount: followingCount,
            runtimeCount: followSnapshot.followingCountsByCreatorId[id],
          ),
          completedWorksCount:
              _parseInt(
                row['completed_works_count'] ??
                    row['completed_works'] ??
                    row['completedWorksCount'] ??
                    row['completedWorks'],
              ) ??
              media.length,
        ),
      );
    }

    return cards;
  }

  Future<List<Map<String, dynamic>>> _fetchProfilesRows({
    required String? cleanRole,
    required int limit,
  }) async {
    // Some environments may not have all profile columns yet.
    // Try richer select first, then gracefully fallback.
    const selectVariants = <String>[
      'id, username, role, avatar_url, location, first_name, last_name, bio, followers_count, following_count, completed_works_count',
      'id, username, role, avatar_url, location, first_name, last_name, bio, followers_count, following_count',
      'id, username, role, avatar_url, location, bio, followers_count, following_count',
      'id, username, role, avatar_url, location',
    ];

    PostgrestException? lastColumnError;
    for (final fields in selectVariants) {
      try {
        dynamic query = _client.from('profiles').select(fields);
        if (cleanRole != null && cleanRole.isNotEmpty) {
          query = query.eq('role', cleanRole);
        }
        final raw = await query.order('username').limit(limit);
        return List<Map<String, dynamic>>.from(raw as List);
      } on PostgrestException catch (error) {
        if (!_isColumnError(error)) rethrow;
        lastColumnError = error;
      }
    }

    if (lastColumnError != null) throw lastColumnError;
    return const <Map<String, dynamic>>[];
  }

  Future<void> setSaved({
    required String creatorId,
    required bool isSaved,
  }) async {
    return setFollowing(creatorId: creatorId, isFollowing: isSaved);
  }

  Future<void> setFollowing({
    required String creatorId,
    required bool isFollowing,
  }) async {
    final followerId = currentUserId;
    if (followerId == null || followerId.isEmpty) {
      throw StateError('Sessione non valida: impossibile seguire creator.');
    }

    final schemas = await _resolveFollowSchemas();
    if (schemas.isEmpty) {
      throw StateError('Nessuna tabella follow disponibile.');
    }

    final wasFollowing = await _isFollowingCreator(
      followerId: followerId,
      creatorId: creatorId,
      schemas: schemas,
    );

    if (isFollowing) {
      var handled = false;
      for (final schema in schemas) {
        try {
          await _client.from(schema.table).insert({
            schema.followerColumn: followerId,
            schema.followedColumn: creatorId,
          });
          handled = true;
          break;
        } on PostgrestException catch (error) {
          if (_isDuplicateError(error)) {
            handled = true;
            break;
          }
          if (_isMissingTable(error) ||
              _isColumnError(error) ||
              _isPermissionDenied(error)) {
            continue;
          }
          rethrow;
        }
      }
      if (!handled) {
        throw StateError('Impossibile salvare il follow sul database.');
      }
    } else {
      for (final schema in schemas) {
        try {
          await _client
              .from(schema.table)
              .delete()
              .eq(schema.followerColumn, followerId)
              .eq(schema.followedColumn, creatorId);
        } on PostgrestException catch (error) {
          if (_isMissingTable(error) ||
              _isColumnError(error) ||
              _isPermissionDenied(error)) {
            continue;
          }
          rethrow;
        }
      }
    }

    final isFollowingNow = await _isFollowingCreator(
      followerId: followerId,
      creatorId: creatorId,
      schemas: schemas,
    );

    if (isFollowing && !isFollowingNow) {
      throw StateError('Follow non completato.');
    }
    if (!isFollowing && isFollowingNow) {
      throw StateError('Unfollow non completato.');
    }

    final delta = (isFollowingNow ? 1 : 0) - (wasFollowing ? 1 : 0);
    if (delta != 0) {
      await _adjustProfileFollowCounts(
        followedProfileId: creatorId,
        followerProfileId: followerId,
        delta: delta,
      );
    }
  }

  Future<CreatorFollowCounters> getFollowCounters({
    required String creatorId,
  }) async {
    final snapshot = await _loadFollowSnapshot(<String>[creatorId]);
    final profileCounts = await _loadProfileFollowCounts(creatorId);
    return CreatorFollowCounters(
      isFollowing: snapshot.followedCreatorIds.contains(creatorId),
      followersCount:
          _bestAvailableCount(
            profileCount: profileCounts.followersCount,
            runtimeCount: snapshot.followerCountsByCreatorId[creatorId],
          ) ??
          0,
      followingCount:
          _bestAvailableCount(
            profileCount: profileCounts.followingCount,
            runtimeCount: snapshot.followingCountsByCreatorId[creatorId],
          ) ??
          0,
    );
  }

  Future<Map<String, List<_CreatorMedia>>> _loadMediaByCreator(
    List<String> creatorIds,
  ) async {
    if (creatorIds.isEmpty) return const <String, List<_CreatorMedia>>{};

    dynamic raw;
    try {
      raw = await _client
          .from('creator_media')
          .select('creator_id, image_url, sort_order, is_featured, created_at')
          .inFilter('creator_id', creatorIds)
          .order('sort_order')
          .order('created_at');
    } on PostgrestException catch (error) {
      if (_isMissingTable(error) || _isColumnError(error)) {
        return const <String, List<_CreatorMedia>>{};
      }
      rethrow;
    }

    final rows = List<Map<String, dynamic>>.from(raw as List);
    final map = <String, List<_CreatorMedia>>{};

    for (final row in rows) {
      final creatorId = (row['creator_id'] ?? '').toString();
      final imageUrl = (row['image_url'] ?? '').toString().trim();
      if (creatorId.isEmpty || imageUrl.isEmpty) continue;
      map
          .putIfAbsent(creatorId, () => <_CreatorMedia>[])
          .add(
            _CreatorMedia(
              imageUrl: imageUrl,
              sortOrder: _parseInt(row['sort_order']) ?? 0,
              isFeatured: row['is_featured'] == true,
            ),
          );
    }

    for (final entry in map.entries) {
      entry.value.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    return map;
  }

  Future<_FollowSnapshot> _loadFollowSnapshot(List<String> creatorIds) async {
    if (creatorIds.isEmpty) return const _FollowSnapshot();

    final schemas = await _resolveFollowSchemas();
    if (schemas.isEmpty) return const _FollowSnapshot();

    final currentFollowerId = currentUserId;
    final followedCreatorIds = <String>{};
    final followerSetsByCreatorId = <String, Set<String>>{};
    final followingSetsByCreatorId = <String, Set<String>>{};
    final creatorIdSet = creatorIds.toSet();

    for (final schema in schemas) {
      if (currentFollowerId != null && currentFollowerId.isNotEmpty) {
        try {
          final followedRaw = await _client
              .from(schema.table)
              .select(schema.followedColumn)
              .eq(schema.followerColumn, currentFollowerId)
              .inFilter(schema.followedColumn, creatorIds);
          final followedRows = List<Map<String, dynamic>>.from(
            followedRaw as List,
          );
          for (final row in followedRows) {
            final followedId = (row[schema.followedColumn] ?? '').toString();
            if (followedId.isNotEmpty) {
              followedCreatorIds.add(followedId);
            }
          }
        } on PostgrestException catch (error) {
          if (_isMissingTable(error) ||
              _isColumnError(error) ||
              _isPermissionDenied(error)) {
            continue;
          }
          rethrow;
        }
      }

      try {
        final followersRaw = await _client
            .from(schema.table)
            .select('${schema.followerColumn},${schema.followedColumn}')
            .inFilter(schema.followedColumn, creatorIds);
        final followerRows = List<Map<String, dynamic>>.from(
          followersRaw as List,
        );
        for (final row in followerRows) {
          final followedId = (row[schema.followedColumn] ?? '').toString();
          final rowFollowerId = (row[schema.followerColumn] ?? '').toString();
          if (followedId.isEmpty ||
              rowFollowerId.isEmpty ||
              !creatorIdSet.contains(followedId)) {
            continue;
          }
          followerSetsByCreatorId
              .putIfAbsent(followedId, () => <String>{})
              .add(rowFollowerId);
        }
      } on PostgrestException catch (error) {
        if (_isMissingTable(error) ||
            _isColumnError(error) ||
            _isPermissionDenied(error)) {
          continue;
        }
        rethrow;
      }

      try {
        final followingRaw = await _client
            .from(schema.table)
            .select('${schema.followerColumn},${schema.followedColumn}')
            .inFilter(schema.followerColumn, creatorIds);
        final followingRows = List<Map<String, dynamic>>.from(
          followingRaw as List,
        );
        for (final row in followingRows) {
          final rowFollowerId = (row[schema.followerColumn] ?? '').toString();
          final followedId = (row[schema.followedColumn] ?? '').toString();
          if (rowFollowerId.isEmpty ||
              followedId.isEmpty ||
              !creatorIdSet.contains(rowFollowerId)) {
            continue;
          }
          followingSetsByCreatorId
              .putIfAbsent(rowFollowerId, () => <String>{})
              .add(followedId);
        }
      } on PostgrestException catch (error) {
        if (_isMissingTable(error) ||
            _isColumnError(error) ||
            _isPermissionDenied(error)) {
          continue;
        }
        rethrow;
      }
    }

    final followerCountsByCreatorId = <String, int>{};
    for (final entry in followerSetsByCreatorId.entries) {
      followerCountsByCreatorId[entry.key] = entry.value.length;
    }

    final followingCountsByCreatorId = <String, int>{};
    for (final entry in followingSetsByCreatorId.entries) {
      followingCountsByCreatorId[entry.key] = entry.value.length;
    }

    return _FollowSnapshot(
      followedCreatorIds: followedCreatorIds,
      followerCountsByCreatorId: followerCountsByCreatorId,
      followingCountsByCreatorId: followingCountsByCreatorId,
    );
  }

  Future<List<_FollowStorageSchema>> _resolveFollowSchemas() async {
    final cached = _cachedFollowSchemas;
    if (cached != null) return cached;

    final resolved = <_FollowStorageSchema>[];
    for (final schema in _followStorageCandidates) {
      try {
        await _client
            .from(schema.table)
            .select('${schema.followerColumn},${schema.followedColumn}')
            .limit(1);
        resolved.add(schema);
      } on PostgrestException catch (error) {
        if (_isMissingTable(error) || _isColumnError(error)) {
          continue;
        }
        if (_isPermissionDenied(error)) {
          resolved.add(schema);
          continue;
        }
        rethrow;
      }
    }

    _cachedFollowSchemas = resolved;
    return resolved;
  }

  Future<bool> _isFollowingCreator({
    required String followerId,
    required String creatorId,
    required List<_FollowStorageSchema> schemas,
  }) async {
    for (final schema in schemas) {
      try {
        final raw = await _client
            .from(schema.table)
            .select(schema.followedColumn)
            .eq(schema.followerColumn, followerId)
            .eq(schema.followedColumn, creatorId)
            .limit(1);
        final rows = List<Map<String, dynamic>>.from(raw as List);
        if (rows.isNotEmpty) return true;
      } on PostgrestException catch (error) {
        if (_isMissingTable(error) ||
            _isColumnError(error) ||
            _isPermissionDenied(error)) {
          continue;
        }
        rethrow;
      }
    }
    return false;
  }

  Future<void> _adjustProfileFollowCounts({
    required String followedProfileId,
    required String followerProfileId,
    required int delta,
  }) async {
    if (delta == 0) return;

    await _adjustProfileCount(
      profileId: followedProfileId,
      column: 'followers_count',
      delta: delta,
    );
    await _adjustProfileCount(
      profileId: followerProfileId,
      column: 'following_count',
      delta: delta,
    );
  }

  Future<void> _adjustProfileCount({
    required String profileId,
    required String column,
    required int delta,
  }) async {
    try {
      final current = await _loadSingleProfileCount(
        profileId: profileId,
        column: column,
      );
      final next = ((current ?? 0) + delta).clamp(0, 1 << 30);
      await _client.from('profiles').update({column: next}).eq('id', profileId);
    } on PostgrestException catch (error) {
      if (_isMissingTable(error) ||
          _isColumnError(error) ||
          _isPermissionDenied(error)) {
        return;
      }
      rethrow;
    }
  }

  Future<_ProfileFollowCounts> _loadProfileFollowCounts(
    String profileId,
  ) async {
    try {
      final raw = await _client
          .from('profiles')
          .select('followers_count,following_count')
          .eq('id', profileId)
          .maybeSingle();
      if (raw == null) return const _ProfileFollowCounts();
      final row = Map<String, dynamic>.from(raw as Map);
      return _ProfileFollowCounts(
        followersCount: _parseInt(
          row['followers_count'] ?? row['followersCount'],
        ),
        followingCount: _parseInt(
          row['following_count'] ?? row['followingCount'],
        ),
      );
    } on PostgrestException catch (error) {
      if (_isMissingTable(error) ||
          _isColumnError(error) ||
          _isPermissionDenied(error)) {
        return const _ProfileFollowCounts();
      }
      rethrow;
    }
  }

  Future<int?> _loadSingleProfileCount({
    required String profileId,
    required String column,
  }) async {
    final raw = await _client
        .from('profiles')
        .select(column)
        .eq('id', profileId)
        .maybeSingle();
    if (raw == null) return null;
    final row = Map<String, dynamic>.from(raw as Map);
    return _parseInt(row[column]);
  }

  int? _bestAvailableCount({int? profileCount, int? runtimeCount}) {
    if (runtimeCount != null) return runtimeCount;
    return profileCount;
  }

  String _extractCategoryFromBio(
    String rawBio, {
    required String normalizedRole,
  }) {
    final bio = rawBio.trim();
    if (bio.isEmpty) return normalizedRole == 'brand' ? 'Brand' : 'Creator';

    final brandType = RegExp(
      r'Tipologia:\s*\n?([^\n]+)',
      caseSensitive: false,
    ).firstMatch(bio);
    if (brandType != null) {
      final value = brandType.group(1)?.trim() ?? '';
      if (value.isNotEmpty) return value;
    }

    final specialization = RegExp(
      r'Specializzazione:\s*\n?([^\n]+)',
      caseSensitive: false,
    ).firstMatch(bio);
    if (specialization != null) {
      final value = specialization.group(1)?.trim() ?? '';
      if (value.isNotEmpty) return value;
    }

    return normalizedRole == 'brand' ? 'Brand' : 'Creator';
  }

  String? _nullableString(dynamic raw) {
    final value = (raw ?? '').toString().trim();
    if (value.isEmpty) return null;
    return value;
  }

  int? _parseInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse((raw ?? '').toString());
  }

  bool _isColumnError(PostgrestException error) {
    final message = error.message.toLowerCase();
    return error.code == '42703' ||
        error.code == 'PGRST204' ||
        message.contains('column') && message.contains('does not exist');
  }

  bool _isMissingTable(PostgrestException error) {
    final message = error.message.toLowerCase();
    return error.code == '42P01' ||
        error.code == 'PGRST205' ||
        message.contains('relation') && message.contains('does not exist');
  }

  bool _isDuplicateError(PostgrestException error) {
    final message = error.message.toLowerCase();
    return error.code == '23505' || message.contains('duplicate key');
  }

  bool _isPermissionDenied(PostgrestException error) {
    final message = error.message.toLowerCase();
    return error.code == '42501' ||
        message.contains('permission denied') ||
        message.contains('row-level security') ||
        message.contains('forbidden');
  }

  String _normalizeRole(String rawRole) {
    final role = rawRole.trim().toLowerCase();
    if (role == 'service') return 'creator';
    if (role.contains('creator')) return 'creator';
    if (role.contains('brand')) return 'brand';
    return role;
  }

  String _roleLabel(String normalizedRole, {required String fallback}) {
    switch (normalizedRole) {
      case 'creator':
        return 'Creator';
      case 'brand':
        return 'Brand';
      default:
        final cleanFallback = fallback.trim();
        return cleanFallback.isEmpty ? 'Utente' : cleanFallback;
    }
  }
}

class _CreatorMedia {
  const _CreatorMedia({
    required this.imageUrl,
    required this.sortOrder,
    required this.isFeatured,
  });

  final String imageUrl;
  final int sortOrder;
  final bool isFeatured;
}

class _FollowStorageSchema {
  const _FollowStorageSchema({
    required this.table,
    required this.followerColumn,
    required this.followedColumn,
  });

  final String table;
  final String followerColumn;
  final String followedColumn;
}

class _FollowSnapshot {
  const _FollowSnapshot({
    this.followedCreatorIds = const <String>{},
    this.followerCountsByCreatorId = const <String, int>{},
    this.followingCountsByCreatorId = const <String, int>{},
  });

  final Set<String> followedCreatorIds;
  final Map<String, int> followerCountsByCreatorId;
  final Map<String, int> followingCountsByCreatorId;
}

class _ProfileFollowCounts {
  const _ProfileFollowCounts({this.followersCount, this.followingCount});

  final int? followersCount;
  final int? followingCount;
}
