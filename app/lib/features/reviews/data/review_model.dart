class ReviewTarget {
  const ReviewTarget({required this.campaignId, required this.toUserId});

  final String campaignId;
  final String toUserId;
}

class ReviewModel {
  const ReviewModel({
    required this.id,
    required this.campaignId,
    required this.fromUserId,
    required this.toUserId,
    required this.rating,
    this.text,
    this.createdAt,
  });

  final String id;
  final String campaignId;
  final String fromUserId;
  final String toUserId;
  final int rating;
  final String? text;
  final DateTime? createdAt;

  factory ReviewModel.fromMap(Map<String, dynamic> map) {
    return ReviewModel(
      id: (map['id'] ?? '').toString().trim(),
      campaignId: (map['campaign_id'] ?? map['campaignId'] ?? '')
          .toString()
          .trim(),
      fromUserId: (map['from_user_id'] ?? map['fromUserId'] ?? '')
          .toString()
          .trim(),
      toUserId: (map['to_user_id'] ?? map['toUserId'] ?? '').toString().trim(),
      rating: _parseRating(map['rating']),
      text: _nullableString(map['text'] ?? map['message'] ?? map['comment']),
      createdAt: _parseDateTime(map['created_at'] ?? map['createdAt']),
    );
  }

  ReviewModel copyWith({
    String? id,
    String? campaignId,
    String? fromUserId,
    String? toUserId,
    int? rating,
    String? text,
    bool clearText = false,
    DateTime? createdAt,
  }) {
    return ReviewModel(
      id: id ?? this.id,
      campaignId: campaignId ?? this.campaignId,
      fromUserId: fromUserId ?? this.fromUserId,
      toUserId: toUserId ?? this.toUserId,
      rating: rating ?? this.rating,
      text: clearText ? null : (text ?? this.text),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static String? _nullableString(dynamic raw) {
    final value = (raw ?? '').toString().trim();
    if (value.isEmpty) return null;
    return value;
  }

  static DateTime? _parseDateTime(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

  static int _parseRating(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    final parsed = int.tryParse((raw ?? '').toString());
    if (parsed != null) return parsed;
    return 0;
  }
}

class ReviewSummary {
  const ReviewSummary({
    required this.averageRating,
    required this.totalReviews,
  });

  final double averageRating;
  final int totalReviews;
}

String reviewTargetKey({required String campaignId, required String toUserId}) {
  return '${campaignId.trim()}|${toUserId.trim()}';
}
