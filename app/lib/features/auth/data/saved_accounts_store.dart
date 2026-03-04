import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final savedAccountsStoreProvider = Provider<SavedAccountsStore>((ref) {
  return SavedAccountsStore();
});

class SavedAccountsStore {
  static const String _storageKey = 'sinapsy.saved_accounts.v1';

  Future<List<SavedAccount>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) return const <SavedAccount>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <SavedAccount>[];

      final parsed =
          decoded
              .whereType<Object>()
              .map((item) {
                if (item is Map<String, dynamic>) {
                  return SavedAccount.fromMap(item);
                }
                if (item is Map) {
                  return SavedAccount.fromMap(
                    item.map((key, value) => MapEntry('$key', value)),
                  );
                }
                return null;
              })
              .whereType<SavedAccount>()
              .where(
                (account) =>
                    account.userId.trim().isNotEmpty &&
                    account.refreshToken.trim().isNotEmpty,
              )
              .toList(growable: false)
            ..sort((a, b) => b.updatedAtUtcMs.compareTo(a.updatedAtUtcMs));
      return parsed;
    } catch (_) {
      return const <SavedAccount>[];
    }
  }

  Future<List<SavedAccount>> upsert(SavedAccount account) async {
    final current = await load();
    final next = <SavedAccount>[
      account.copyWith(
        updatedAtUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
      ),
      ...current.where((item) => item.userId != account.userId),
    ].take(12).toList(growable: false);
    await _save(next);
    return next;
  }

  Future<List<SavedAccount>> removeByUserId(String userId) async {
    final current = await load();
    final next = current
        .where((item) => item.userId.trim() != userId.trim())
        .toList(growable: false);
    await _save(next);
    return next;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  Future<void> _save(List<SavedAccount> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      accounts.map((account) => account.toMap()).toList(),
    );
    await prefs.setString(_storageKey, encoded);
  }
}

class SavedAccount {
  const SavedAccount({
    required this.userId,
    required this.refreshToken,
    this.email,
    this.username,
    this.role,
    this.avatarUrl,
    this.location,
    required this.updatedAtUtcMs,
  });

  final String userId;
  final String refreshToken;
  final String? email;
  final String? username;
  final String? role;
  final String? avatarUrl;
  final String? location;
  final int updatedAtUtcMs;

  String get roleLabel {
    final normalized = (role ?? '').trim().toLowerCase();
    switch (normalized) {
      case 'brand':
        return 'Brand';
      case 'creator':
        return 'Creator';
      default:
        return 'Utente';
    }
  }

  SavedAccount copyWith({
    String? userId,
    String? refreshToken,
    String? email,
    String? username,
    String? role,
    String? avatarUrl,
    String? location,
    int? updatedAtUtcMs,
  }) {
    return SavedAccount(
      userId: userId ?? this.userId,
      refreshToken: refreshToken ?? this.refreshToken,
      email: email ?? this.email,
      username: username ?? this.username,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      location: location ?? this.location,
      updatedAtUtcMs: updatedAtUtcMs ?? this.updatedAtUtcMs,
    );
  }

  factory SavedAccount.fromMap(Map<String, dynamic> map) {
    return SavedAccount(
      userId: (map['user_id'] ?? map['userId'] ?? '').toString().trim(),
      refreshToken: (map['refresh_token'] ?? map['refreshToken'] ?? '')
          .toString()
          .trim(),
      email: _nullableString(map['email']),
      username: _nullableString(map['username']),
      role: _nullableString(map['role']),
      avatarUrl: _nullableString(map['avatar_url'] ?? map['avatarUrl']),
      location: _nullableString(map['location']),
      updatedAtUtcMs: _parseMs(map['updated_at_ms'] ?? map['updatedAtUtcMs']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'user_id': userId,
      'refresh_token': refreshToken,
      'email': email,
      'username': username,
      'role': role,
      'avatar_url': avatarUrl,
      'location': location,
      'updated_at_ms': updatedAtUtcMs,
    };
  }

  static String? _nullableString(dynamic raw) {
    final value = (raw ?? '').toString().trim();
    if (value.isEmpty) return null;
    return value;
  }

  static int _parseMs(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    final parsed = int.tryParse((raw ?? '').toString());
    if (parsed != null) return parsed;
    return DateTime.now().toUtc().millisecondsSinceEpoch;
  }
}
