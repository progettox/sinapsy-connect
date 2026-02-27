import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../auth/data/auth_repository.dart';
import '../../campaigns/data/campaign_model.dart';

final applicationRepositoryProvider = Provider<ApplicationRepository>((ref) {
  return ApplicationRepository(
    client: ref.watch(supabaseClientProvider),
    authRepository: ref.watch(authRepositoryProvider),
  );
});

class ApplicationRepository {
  ApplicationRepository({
    required SupabaseClient client,
    required AuthRepository authRepository,
  }) : _client = client,
       _authRepository = authRepository;

  final SupabaseClient _client;
  final AuthRepository _authRepository;

  Future<void> applyToCampaign(CampaignModel campaign) async {
    final creatorId = _authRepository.currentUser?.id;
    if (creatorId == null) {
      throw StateError('Sessione utente non valida.');
    }

    _log('apply.start campaignId=${campaign.id} creatorId=$creatorId');

    final existing = await _findExistingApplication(
      creatorId: creatorId,
      campaignId: campaign.id,
    );
    if (existing != null) {
      final status = _status(existing['status']);
      final existingId = _string(existing['id']);
      if (status == 'accepted') {
        throw StateError(
          'Hai gia inviato una candidatura per questo annuncio.',
        );
      }
      if (status == 'pending') {
        _log(
          'apply.skip_duplicate_pending campaignId=${campaign.id} creatorId=$creatorId',
        );
        return;
      }
      if (existingId != null && existingId.isNotEmpty) {
        final reactivated = await _reactivateApplication(
          applicationId: existingId,
          creatorId: creatorId,
        );
        if (reactivated) {
          await _incrementApplicantsCount(campaign);
          _log(
            'apply.success_reactivated campaignId=${campaign.id} creatorId=$creatorId applicationId=$existingId',
          );
          return;
        }
      }
    }

    await _insertApplication(campaign: campaign, creatorId: creatorId);
    await _incrementApplicantsCount(campaign);
    _log('apply.success campaignId=${campaign.id} creatorId=$creatorId');
  }

  Future<Map<String, dynamic>?> _findExistingApplication({
    required String creatorId,
    required String campaignId,
  }) async {
    try {
      final result = await _client
          .from('applications')
          .select('id,status')
          .eq('campaign_id', campaignId)
          .eq('applicant_id', creatorId)
          .limit(1);
      final rows = _toMaps(result);
      return rows.isEmpty ? null : rows.first;
    } on PostgrestException catch (error) {
      if (!_isColumnError(error)) rethrow;

      final result = await _client
          .from('applications')
          .select('id,status')
          .eq('campaign_id', campaignId)
          .eq('creator_id', creatorId)
          .limit(1);
      final rows = _toMaps(result);
      return rows.isEmpty ? null : rows.first;
    }
  }

  Future<bool> _reactivateApplication({
    required String applicationId,
    required String creatorId,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    try {
      final rows = await _client
          .from('applications')
          .update({'status': 'pending', 'created_at': now})
          .eq('id', applicationId)
          .eq('applicant_id', creatorId)
          .select('id');
      if (_toMaps(rows).isNotEmpty) return true;
    } on PostgrestException catch (error) {
      if (!_isColumnError(error)) rethrow;
    }

    try {
      final rows = await _client
          .from('applications')
          .update({'status': 'pending', 'created_at': now})
          .eq('id', applicationId)
          .eq('creator_id', creatorId)
          .select('id');
      if (_toMaps(rows).isNotEmpty) return true;
    } on PostgrestException catch (error) {
      if (!_isColumnError(error)) rethrow;
    }

    return false;
  }

  Future<void> _insertApplication({
    required CampaignModel campaign,
    required String creatorId,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    _log('apply.insert.before campaignId=${campaign.id} creatorId=$creatorId');
    try {
      await _client.from('applications').insert({
        'campaign_id': campaign.id,
        'applicant_id': creatorId,
        'status': 'pending',
        'proposal_message': null,
        'created_at': now,
      });
    } on PostgrestException catch (error) {
      if (!_isColumnError(error)) rethrow;

      await _client.from('applications').insert({
        'campaign_id': campaign.id,
        'creator_id': creatorId,
        'status': 'pending',
        'created_at': now,
      });
    }
    _log('apply.insert.after campaignId=${campaign.id} creatorId=$creatorId');
  }

  Future<void> _incrementApplicantsCount(CampaignModel campaign) async {
    try {
      await _client.rpc(
        'increment_campaign_applicants_count',
        params: {'campaign_id_input': campaign.id},
      );
      return;
    } on PostgrestException catch (error) {
      if (!_isMissingRpc(error)) rethrow;
    }

    final nextCount = campaign.applicantsCount + 1;

    try {
      await _client
          .from('campaigns')
          .update({'applicants_count': nextCount})
          .eq('id', campaign.id);
    } on PostgrestException catch (error) {
      if (!_isColumnError(error)) rethrow;

      await _client
          .from('campaigns')
          .update({'applicantsCount': nextCount})
          .eq('id', campaign.id);
    }
  }

  List<Map<String, dynamic>> _toMaps(dynamic raw) {
    final rows = raw is List ? raw : const <dynamic>[];
    return rows.whereType<Object>().map(_toMap).toList();
  }

  Map<String, dynamic> _toMap(Object row) {
    if (row is Map<String, dynamic>) return row;
    if (row is Map) {
      return row.map((key, value) => MapEntry('$key', value));
    }
    throw StateError('Formato application non valido.');
  }

  String? _string(dynamic raw) {
    final value = (raw ?? '').toString().trim();
    if (value.isEmpty) return null;
    return value;
  }

  String _status(dynamic raw) {
    return (raw ?? '').toString().trim().toLowerCase();
  }

  bool _isColumnError(PostgrestException error) {
    return error.code == '42703' || error.code == 'PGRST204';
  }

  bool _isMissingRpc(PostgrestException error) {
    return error.code == '42883' ||
        error.message.toLowerCase().contains('function') ||
        error.message.toLowerCase().contains('rpc');
  }

  void _log(String message) {
    if (!kDebugMode) return;
    debugPrint('[ApplicationRepository] $message');
  }
}
