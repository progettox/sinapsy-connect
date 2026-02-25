class CampaignModel {
  const CampaignModel({
    required this.id,
    required this.title,
    required this.budget,
    required this.category,
    required this.status,
    this.description,
    this.minFollowers,
    this.locationRequired,
    this.coverImageUrl,
    this.applicantsCount = 0,
    this.brandId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String? description;
  final num budget;
  final String category;
  final int? minFollowers;
  final String? locationRequired;
  final String? coverImageUrl;
  final String status;
  final int applicantsCount;
  final String? brandId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory CampaignModel.fromMap(Map<String, dynamic> map) {
    final title =
        _string(map['title']) ??
        _string(map['name']) ??
        _string(map['headline']) ??
        'Untitled campaign';

    return CampaignModel(
      id: _string(map['id']) ?? '',
      title: title,
      description: _string(map['description']),
      budget:
          _num(
            map['cash_offer'] ??
                map['cashOffer'] ??
                map['budget'] ??
                map['cashOfferAmount'],
          ) ??
          0,
      category: _string(map['category']) ?? 'general',
      minFollowers: _int(map['min_followers'] ?? map['minFollowers']),
      locationRequired: _string(
        map['location_required'] ??
            map['locationRequired'] ??
            map['location_required_city'] ??
            map['locationRequiredCity'],
      ),
      coverImageUrl: _string(map['cover_image_url'] ?? map['coverImageUrl']),
      status: _string(map['status']) ?? 'active',
      applicantsCount:
          _int(map['applicants_count'] ?? map['applicantsCount']) ?? 0,
      brandId: _string(map['brand_id'] ?? map['brandId']),
      createdAt: _dateTime(map['created_at'] ?? map['createdAt']),
      updatedAt: _dateTime(map['updated_at'] ?? map['updatedAt']),
    );
  }

  String get budgetLabel {
    if (budget == budget.roundToDouble()) {
      return 'EUR ${budget.toInt()}';
    }
    return 'EUR ${budget.toStringAsFixed(2)}';
  }

  CampaignModel copyWith({
    String? id,
    String? title,
    String? description,
    num? budget,
    String? category,
    int? minFollowers,
    bool clearMinFollowers = false,
    String? locationRequired,
    bool clearLocationRequired = false,
    String? coverImageUrl,
    bool clearCoverImage = false,
    String? status,
    int? applicantsCount,
    String? brandId,
    bool clearBrandId = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CampaignModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      budget: budget ?? this.budget,
      category: category ?? this.category,
      minFollowers: clearMinFollowers
          ? null
          : (minFollowers ?? this.minFollowers),
      locationRequired: clearLocationRequired
          ? null
          : (locationRequired ?? this.locationRequired),
      coverImageUrl: clearCoverImage
          ? null
          : (coverImageUrl ?? this.coverImageUrl),
      status: status ?? this.status,
      applicantsCount: applicantsCount ?? this.applicantsCount,
      brandId: clearBrandId ? null : (brandId ?? this.brandId),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String? _string(dynamic raw) {
    final value = (raw ?? '').toString().trim();
    if (value.isEmpty) return null;
    return value;
  }

  static int? _int(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString());
  }

  static num? _num(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) return raw;
    return num.tryParse(raw.toString());
  }

  static DateTime? _dateTime(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }
}
