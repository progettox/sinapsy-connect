import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/widgets/sinapsy_logo_loader.dart';
import '../../data/profile_model.dart';

enum FollowAccountsMode { followers, following }

Future<void> showFollowAccountsSheet({
  required BuildContext context,
  required SupabaseClient client,
  required String profileId,
  required FollowAccountsMode mode,
  required String ownerLabel,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF0E091B),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _FollowAccountsSheet(
      client: client,
      profileId: profileId,
      mode: mode,
      ownerLabel: ownerLabel,
    ),
  );
}

class _FollowAccountsSheet extends StatefulWidget {
  const _FollowAccountsSheet({
    required this.client,
    required this.profileId,
    required this.mode,
    required this.ownerLabel,
  });

  final SupabaseClient client;
  final String profileId;
  final FollowAccountsMode mode;
  final String ownerLabel;

  @override
  State<_FollowAccountsSheet> createState() => _FollowAccountsSheetState();
}

class _FollowAccountsSheetState extends State<_FollowAccountsSheet> {
  bool _isLoading = true;
  String? _errorMessage;
  List<_FollowAccountItem> _items = const <_FollowAccountItem>[];

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final ids = await _fetchFollowAccountIds();
      if (ids.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _items = const <_FollowAccountItem>[];
        });
        return;
      }

      final profilesById = await _fetchProfilesById(ids);
      final items = ids
          .map((id) {
            final row = profilesById[id];
            final username = _asString(row?['username']) ?? '@utente';
            final firstName =
                _asString(row?['first_name'] ?? row?['firstName']) ?? '';
            final lastName =
                _asString(row?['last_name'] ?? row?['lastName']) ?? '';
            final fullName = [
              firstName,
              lastName,
            ].where((part) => part.isNotEmpty).join(' ').trim();
            final displayName = fullName.isNotEmpty ? fullName : username;
            final role = profileRoleFromString(_asString(row?['role']))?.label;
            final avatarUrl = _asString(
              row?['avatar_url'] ?? row?['avatarUrl'],
            );
            return _FollowAccountItem(
              id: id,
              username: username,
              displayName: displayName,
              roleLabel: role,
              avatarUrl: avatarUrl,
            );
          })
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _items = items;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Errore caricamento elenco: $error';
      });
    }
  }

  Future<List<String>> _fetchFollowAccountIds() async {
    final ids = <String>{};
    final cleanProfileId = widget.profileId.trim();
    if (cleanProfileId.isEmpty) return const <String>[];

    for (final schema in _followStorageCandidates) {
      final lookupColumn = widget.mode == FollowAccountsMode.followers
          ? schema.followedColumn
          : schema.followerColumn;
      final resultColumn = widget.mode == FollowAccountsMode.followers
          ? schema.followerColumn
          : schema.followedColumn;
      try {
        final raw = await widget.client
            .from(schema.table)
            .select(resultColumn)
            .eq(lookupColumn, cleanProfileId)
            .limit(500);
        final rows = _toMaps(raw);
        for (final row in rows) {
          final id = _asString(row[resultColumn]);
          if (id == null || id == cleanProfileId) continue;
          ids.add(id);
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

    final ordered = ids.toList(growable: false)..sort();
    return ordered;
  }

  Future<Map<String, Map<String, dynamic>>> _fetchProfilesById(
    List<String> ids,
  ) async {
    final variants = <String>[
      'id, username, role, first_name, last_name, avatar_url',
      'id, username, role, avatar_url',
      'id, username, role, firstName, lastName, avatarUrl',
      'id, username, role, avatarUrl',
    ];

    dynamic raw;
    PostgrestException? lastColumnError;

    for (final fields in variants) {
      try {
        raw = await widget.client
            .from('profiles')
            .select(fields)
            .inFilter('id', ids);
        final map = <String, Map<String, dynamic>>{};
        for (final row in _toMaps(raw)) {
          final id = _asString(row['id'] ?? row['user_id']);
          if (id == null || id.isEmpty) continue;
          map[id] = row;
        }
        return map;
      } on PostgrestException catch (error) {
        if (!_isColumnError(error)) rethrow;
        lastColumnError = error;
      }
    }

    if (lastColumnError != null) throw lastColumnError;
    return const <String, Map<String, dynamic>>{};
  }

  List<Map<String, dynamic>> _toMaps(dynamic raw) {
    final rows = raw is List ? raw : const <dynamic>[];
    return rows.whereType<Object>().map(_toMap).toList(growable: false);
  }

  Map<String, dynamic> _toMap(Object row) {
    if (row is Map<String, dynamic>) return row;
    if (row is Map) {
      return row.map((key, value) => MapEntry('$key', value));
    }
    return const <String, dynamic>{};
  }

  String? _asString(dynamic raw) {
    final value = (raw ?? '').toString().trim();
    if (value.isEmpty) return null;
    return value;
  }

  bool _isColumnError(PostgrestException error) {
    final message = error.message.toLowerCase();
    return error.code == '42703' ||
        error.code == 'PGRST204' ||
        (message.contains('column') && message.contains('does not exist'));
  }

  bool _isMissingTable(PostgrestException error) {
    final message = error.message.toLowerCase();
    return error.code == '42P01' ||
        error.code == 'PGRST205' ||
        (message.contains('relation') && message.contains('does not exist'));
  }

  bool _isPermissionDenied(PostgrestException error) {
    final message = error.message.toLowerCase();
    return error.code == '42501' ||
        message.contains('permission denied') ||
        message.contains('forbidden') ||
        message.contains('row-level security');
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.mode == FollowAccountsMode.followers
        ? 'Follower'
        : 'Seguiti';
    final emptyText = widget.mode == FollowAccountsMode.followers
        ? 'Nessun follower al momento.'
        : 'Nessun seguito al momento.';

    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8E7AAF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '$title di ${widget.ownerLabel}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFF1E8FF),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _isLoading
                    ? const Center(child: SinapsyLogoLoader())
                    : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFFE3D2FF)),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton(
                              onPressed: _load,
                              child: const Text('Riprova'),
                            ),
                          ],
                        ),
                      )
                    : _items.isEmpty
                    ? Center(
                        child: Text(
                          emptyText,
                          style: const TextStyle(color: Color(0xFFD0BEEA)),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return _AccountTile(item: item);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.item});

  final _FollowAccountItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF6E47AF).withValues(alpha: 0.4),
        ),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xB2171128), Color(0xA40C0918)],
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF1B1430),
            backgroundImage: (item.avatarUrl ?? '').isNotEmpty
                ? NetworkImage(item.avatarUrl!)
                : null,
            child: (item.avatarUrl ?? '').isNotEmpty
                ? null
                : Text(
                    item.username.isEmpty
                        ? '?'
                        : item.username[0].toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFFF1E8FF),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF0E7FF),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.roleLabel ?? 'Utente',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFC9B8E6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FollowAccountItem {
  const _FollowAccountItem({
    required this.id,
    required this.username,
    required this.displayName,
    required this.roleLabel,
    required this.avatarUrl,
  });

  final String id;
  final String username;
  final String displayName;
  final String? roleLabel;
  final String? avatarUrl;
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

const List<_FollowStorageSchema> _followStorageCandidates =
    <_FollowStorageSchema>[
      _FollowStorageSchema(
        table: 'profile_followers',
        followerColumn: 'follower_id',
        followedColumn: 'followed_id',
      ),
    ];
