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

  CreatorFeedCard copyWith({
    bool? isSaved,
    List<String>? portfolioThumbUrls,
    String? heroImageUrl,
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
    );
  }
}

class BrandCreatorFeedRepository {
  BrandCreatorFeedRepository(this._client);

  final SupabaseClient _client;

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
    final savedCreatorIds = await _loadSavedCreatorIds(profileIds);

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

      final media = mediaByCreator[id] ?? const <_CreatorMedia>[];
      final featuredMedia = media.where((item) => item.isFeatured).toList();
      final heroImageUrl = featuredMedia.isNotEmpty
          ? featuredMedia.first.imageUrl
          : media.isNotEmpty
          ? media.first.imageUrl
          : avatarUrl;

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
          isSaved: savedCreatorIds.contains(id),
        ),
      );
    }

    return cards;
  }

  Future<List<Map<String, dynamic>>> _fetchProfilesRows({
    required String? cleanRole,
    required int limit,
  }) async {
    // Some environments may not have `first_name/last_name` yet.
    // Try richer select first, then gracefully fallback.
    const selectVariants = <String>[
      'id, username, role, avatar_url, location, first_name, last_name, bio',
      'id, username, role, avatar_url, location, bio',
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
    final brandId = currentUserId;
    if (brandId == null || brandId.isEmpty) {
      throw StateError('Sessione non valida: impossibile salvare creator.');
    }

    if (isSaved) {
      await _client.from('brand_saved_creators').upsert({
        'brand_id': brandId,
        'creator_id': creatorId,
      }, onConflict: 'brand_id,creator_id');
      return;
    }

    await _client
        .from('brand_saved_creators')
        .delete()
        .eq('brand_id', brandId)
        .eq('creator_id', creatorId);
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

  Future<Set<String>> _loadSavedCreatorIds(List<String> creatorIds) async {
    final brandId = currentUserId;
    if (brandId == null || brandId.isEmpty || creatorIds.isEmpty) {
      return <String>{};
    }

    dynamic raw;
    try {
      raw = await _client
          .from('brand_saved_creators')
          .select('creator_id')
          .eq('brand_id', brandId)
          .inFilter('creator_id', creatorIds);
    } on PostgrestException catch (error) {
      if (_isMissingTable(error) || _isColumnError(error)) {
        return <String>{};
      }
      rethrow;
    }

    final rows = List<Map<String, dynamic>>.from(raw as List);
    return rows
        .map((row) => (row['creator_id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet();
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
