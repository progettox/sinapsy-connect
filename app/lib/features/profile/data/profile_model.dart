enum ProfileRole { brand, creator }

extension ProfileRoleX on ProfileRole {
  String get value {
    switch (this) {
      case ProfileRole.brand:
        return 'brand';
      case ProfileRole.creator:
        return 'creator';
    }
  }

  String get label {
    switch (this) {
      case ProfileRole.brand:
        return 'Brand';
      case ProfileRole.creator:
        return 'Creator';
    }
  }
}

ProfileRole? profileRoleFromString(String? value) {
  switch ((value ?? '').trim().toLowerCase()) {
    case 'brand':
      return ProfileRole.brand;
    case 'creator':
      return ProfileRole.creator;
    case 'service':
      return ProfileRole.creator;
    default:
      return null;
  }
}

class ProfileModel {
  const ProfileModel({
    required this.id,
    required this.username,
    required this.location,
    this.role,
    this.bio = '',
    this.avatarUrl,
    this.followersCount,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String username;
  final ProfileRole? role;
  final String bio;
  final String location;
  final String? avatarUrl;
  final int? followersCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get userId => id;

  bool get isComplete {
    return role != null &&
        username.trim().isNotEmpty &&
        location.trim().isNotEmpty;
  }

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    return ProfileModel(
      id: (map['id'] ?? map['user_id'] ?? '').toString(),
      username: (map['username'] ?? '').toString(),
      role: profileRoleFromString(map['role']?.toString()),
      bio: (map['bio'] ?? '').toString(),
      location: (map['location'] ?? '').toString(),
      avatarUrl: _normalizeNullableString(map['avatar_url']),
      followersCount: _parseInt(
        map['followers_count'] ?? map['followersCount'],
      ),
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: _parseDateTime(map['updated_at']),
    );
  }

  Map<String, dynamic> toUpsertMap() {
    return <String, dynamic>{
      'id': id,
      'username': username.trim(),
      'role': role?.value,
      'bio': bio.trim().isEmpty ? null : bio.trim(),
      'location': location.trim(),
      'avatar_url': _normalizeNullableString(avatarUrl),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> toUpsertById() => toUpsertMap();

  Map<String, dynamic> toUpsertByUserId() {
    return <String, dynamic>{
      'user_id': id,
      'username': username.trim(),
      'role': role?.value,
      'bio': bio.trim().isEmpty ? null : bio.trim(),
      'location': location.trim(),
      'avatar_url': _normalizeNullableString(avatarUrl),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  ProfileModel copyWith({
    String? id,
    String? username,
    ProfileRole? role,
    bool clearRole = false,
    String? bio,
    String? location,
    String? avatarUrl,
    bool clearAvatar = false,
    int? followersCount,
    bool clearFollowersCount = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      username: username ?? this.username,
      role: clearRole ? null : (role ?? this.role),
      bio: bio ?? this.bio,
      location: location ?? this.location,
      avatarUrl: clearAvatar ? null : (avatarUrl ?? this.avatarUrl),
      followersCount: clearFollowersCount
          ? null
          : (followersCount ?? this.followersCount),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _parseDateTime(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

  static String? _normalizeNullableString(dynamic raw) {
    final value = (raw ?? '').toString().trim();
    if (value.isEmpty) return null;
    return value;
  }

  static int? _parseInt(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString());
  }
}

class ProfileUpsertData {
  const ProfileUpsertData({
    required this.role,
    required this.username,
    required this.location,
    this.bio,
    this.avatarUrl,
  });

  final ProfileRole role;
  final String username;
  final String location;
  final String? bio;
  final String? avatarUrl;
}
