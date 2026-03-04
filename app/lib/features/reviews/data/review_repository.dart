import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../auth/data/auth_repository.dart';
import 'review_model.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return ReviewRepository(
    client: ref.watch(supabaseClientProvider),
    authRepository: ref.watch(authRepositoryProvider),
  );
});

class ReviewRepository {
  ReviewRepository({
    required SupabaseClient client,
    required AuthRepository authRepository,
  }) : _client = client,
       _authRepository = authRepository;

  final SupabaseClient _client;
  final AuthRepository _authRepository;

  Future<ReviewModel> submitReview({
    required String campaignId,
    required String toUserId,
    required int rating,
    String? text,
  }) async {
    final fromUserId = _authRepository.currentUser?.id;
    if (fromUserId == null || fromUserId.trim().isEmpty) {
      throw const ReviewValidationException(
        'Sessione non valida. Effettua nuovamente il login.',
      );
    }
    final cleanCampaignId = campaignId.trim();
    final cleanToUserId = toUserId.trim();
    if (cleanCampaignId.isEmpty || cleanToUserId.isEmpty) {
      throw const ReviewValidationException(
        'Campagna o destinatario non validi per la review.',
      );
    }
    if (fromUserId.trim() == cleanToUserId) {
      throw const ReviewValidationException(
        'Non puoi lasciare una review a te stesso.',
      );
    }
    if (rating < 1 || rating > 5) {
      throw const ReviewValidationException(
        'La review deve avere un voto da 1 a 5 stelle.',
      );
    }

    final existing = await _findMyReview(
      campaignId: cleanCampaignId,
      fromUserId: fromUserId.trim(),
      toUserId: cleanToUserId,
    );
    if (existing != null) throw const ReviewAlreadySubmittedException();

    final cleanText = (text ?? '').trim();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final payloads = <Map<String, dynamic>>[
      <String, dynamic>{
        'campaign_id': cleanCampaignId,
        'from_user_id': fromUserId.trim(),
        'to_user_id': cleanToUserId,
        'rating': rating,
        'text': cleanText.isEmpty ? null : cleanText,
        'created_at': nowIso,
      },
      <String, dynamic>{
        'campaignId': cleanCampaignId,
        'fromUserId': fromUserId.trim(),
        'toUserId': cleanToUserId,
        'rating': rating,
        'text': cleanText.isEmpty ? null : cleanText,
        'createdAt': nowIso,
      },
      <String, dynamic>{
        'campaign_id': cleanCampaignId,
        'from_user_id': fromUserId.trim(),
        'to_user_id': cleanToUserId,
        'rating': rating,
        'message': cleanText.isEmpty ? null : cleanText,
        'created_at': nowIso,
      },
    ];

    PostgrestException? lastColumnError;
    for (final payload in payloads) {
      try {
        final created = await _client
            .from('reviews')
            .insert(payload)
            .select()
            .single();
        return ReviewModel.fromMap(_toMap(created));
      } on PostgrestException catch (error) {
        if (_isUniqueViolation(error)) {
          throw const ReviewAlreadySubmittedException();
        }
        if (_isMissingTable(error)) {
          throw const ReviewFeatureUnavailableException();
        }
        if (!_isColumnError(error)) rethrow;
        lastColumnError = error;
      }
    }

    if (lastColumnError != null) {
      throw ReviewValidationException(
        'Impossibile salvare la review: ${lastColumnError.message}',
      );
    }
    throw const ReviewValidationException(
      'Impossibile salvare la review in questo momento.',
    );
  }

  Future<Map<String, ReviewModel>> getMyReviewsForTargets(
    List<ReviewTarget> targets,
  ) async {
    final fromUserId = _authRepository.currentUser?.id;
    if (fromUserId == null || fromUserId.trim().isEmpty) {
      return const <String, ReviewModel>{};
    }

    final normalizedTargets = targets
        .map(
          (target) => ReviewTarget(
            campaignId: target.campaignId.trim(),
            toUserId: target.toUserId.trim(),
          ),
        )
        .where(
          (target) =>
              target.campaignId.isNotEmpty && target.toUserId.isNotEmpty,
        )
        .toList(growable: false);
    if (normalizedTargets.isEmpty) return const <String, ReviewModel>{};

    final keySet = normalizedTargets
        .map(
          (target) => reviewTargetKey(
            campaignId: target.campaignId,
            toUserId: target.toUserId,
          ),
        )
        .toSet();
    final campaignIds = normalizedTargets
        .map((target) => target.campaignId)
        .toSet()
        .toList(growable: false);

    final rows = await _loadMyRowsByCampaignIds(
      fromUserId: fromUserId.trim(),
      campaignIds: campaignIds,
    );

    final mapped = <String, ReviewModel>{};
    for (final row in rows) {
      final model = ReviewModel.fromMap(row);
      if (model.campaignId.isEmpty || model.toUserId.isEmpty) continue;
      final key = reviewTargetKey(
        campaignId: model.campaignId,
        toUserId: model.toUserId,
      );
      if (!keySet.contains(key)) continue;

      final previous = mapped[key];
      if (previous == null) {
        mapped[key] = model;
        continue;
      }
      final previousAt =
          previous.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final nextAt = model.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      if (nextAt.isAfter(previousAt)) {
        mapped[key] = model;
      }
    }

    return mapped;
  }

  Future<ReviewSummary> getReceivedSummary({required String userId}) async {
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) {
      return const ReviewSummary(averageRating: 0, totalReviews: 0);
    }

    List<Map<String, dynamic>> rows;
    try {
      final result = await _client
          .from('reviews')
          .select('rating')
          .eq('to_user_id', cleanUserId);
      rows = _toMaps(result);
    } on PostgrestException catch (error) {
      if (_isMissingTable(error)) {
        return const ReviewSummary(averageRating: 0, totalReviews: 0);
      }
      if (!_isColumnError(error)) rethrow;
      try {
        final result = await _client
            .from('reviews')
            .select('rating')
            .eq('toUserId', cleanUserId);
        rows = _toMaps(result);
      } on PostgrestException catch (innerError) {
        if (_isMissingTable(innerError)) {
          return const ReviewSummary(averageRating: 0, totalReviews: 0);
        }
        if (!_isColumnError(innerError)) rethrow;
        rows = const <Map<String, dynamic>>[];
      }
    }

    if (rows.isEmpty) {
      return const ReviewSummary(averageRating: 0, totalReviews: 0);
    }
    final ratings = rows
        .map((row) => _int(row['rating']))
        .whereType<int>()
        .where((rating) => rating >= 1 && rating <= 5)
        .toList(growable: false);
    if (ratings.isEmpty) {
      return const ReviewSummary(averageRating: 0, totalReviews: 0);
    }
    final sum = ratings.fold<int>(0, (acc, item) => acc + item);
    final average = sum / ratings.length;
    return ReviewSummary(averageRating: average, totalReviews: ratings.length);
  }

  Future<ReviewModel?> _findMyReview({
    required String campaignId,
    required String fromUserId,
    required String toUserId,
  }) async {
    try {
      final row = await _client
          .from('reviews')
          .select(
            'id,campaign_id,from_user_id,to_user_id,rating,text,created_at',
          )
          .eq('campaign_id', campaignId)
          .eq('from_user_id', fromUserId)
          .eq('to_user_id', toUserId)
          .maybeSingle();
      if (row == null) return null;
      return ReviewModel.fromMap(_toMap(row));
    } on PostgrestException catch (error) {
      if (_isMissingTable(error)) {
        throw const ReviewFeatureUnavailableException();
      }
      if (!_isColumnError(error)) rethrow;
    }

    try {
      final row = await _client
          .from('reviews')
          .select('id,campaignId,fromUserId,toUserId,rating,text,createdAt')
          .eq('campaignId', campaignId)
          .eq('fromUserId', fromUserId)
          .eq('toUserId', toUserId)
          .maybeSingle();
      if (row == null) return null;
      return ReviewModel.fromMap(_toMap(row));
    } on PostgrestException catch (error) {
      if (_isMissingTable(error)) {
        throw const ReviewFeatureUnavailableException();
      }
      if (!_isColumnError(error)) rethrow;
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _loadMyRowsByCampaignIds({
    required String fromUserId,
    required List<String> campaignIds,
  }) async {
    if (campaignIds.isEmpty) return const <Map<String, dynamic>>[];

    try {
      final rows = await _client
          .from('reviews')
          .select(
            'id,campaign_id,from_user_id,to_user_id,rating,text,created_at',
          )
          .eq('from_user_id', fromUserId)
          .inFilter('campaign_id', campaignIds);
      return _toMaps(rows);
    } on PostgrestException catch (error) {
      if (_isMissingTable(error)) return const <Map<String, dynamic>>[];
      if (!_isColumnError(error)) rethrow;
    }

    try {
      final rows = await _client
          .from('reviews')
          .select('id,campaignId,fromUserId,toUserId,rating,text,createdAt')
          .eq('fromUserId', fromUserId)
          .inFilter('campaignId', campaignIds);
      return _toMaps(rows);
    } on PostgrestException catch (error) {
      if (_isMissingTable(error)) return const <Map<String, dynamic>>[];
      if (!_isColumnError(error)) rethrow;
      return const <Map<String, dynamic>>[];
    }
  }

  List<Map<String, dynamic>> _toMaps(dynamic rows) {
    final list = rows is List ? rows : const <dynamic>[];
    return list.whereType<Object>().map(_toMap).toList(growable: false);
  }

  Map<String, dynamic> _toMap(Object row) {
    if (row is Map<String, dynamic>) return row;
    if (row is Map) {
      return row.map((key, value) => MapEntry('$key', value));
    }
    throw StateError('Formato review non valido.');
  }

  int? _int(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString());
  }

  bool _isColumnError(PostgrestException error) {
    return error.code == '42703' ||
        error.code == 'PGRST204' ||
        _messageContainsSqlState(error, '42703') ||
        error.message.toLowerCase().contains('column') ||
        error.message.toLowerCase().contains('does not exist');
  }

  bool _isMissingTable(PostgrestException error) {
    return error.code == '42P01' ||
        error.code == 'PGRST205' ||
        _messageContainsSqlState(error, '42P01') ||
        error.message.toLowerCase().contains('relation') &&
            error.message.toLowerCase().contains('does not exist');
  }

  bool _isUniqueViolation(PostgrestException error) {
    return error.code == '23505' || _messageContainsSqlState(error, '23505');
  }

  bool _messageContainsSqlState(PostgrestException error, String sqlState) {
    final message = error.message;
    return message.contains('"code":"$sqlState"') ||
        message.contains('"code": "$sqlState"');
  }
}

class ReviewValidationException implements Exception {
  const ReviewValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ReviewAlreadySubmittedException implements Exception {
  const ReviewAlreadySubmittedException();

  String get message => 'Hai gia inviato una review per questa collaborazione.';

  @override
  String toString() => message;
}

class ReviewFeatureUnavailableException implements Exception {
  const ReviewFeatureUnavailableException();

  String get message =>
      'Feature review non disponibile: verifica la tabella reviews nel database.';

  @override
  String toString() => message;
}
