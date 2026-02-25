import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import 'campaign_model.dart';

final campaignRepositoryProvider = Provider<CampaignRepository>((ref) {
  return CampaignRepository(ref.watch(supabaseClientProvider));
});

class CampaignRepository {
  CampaignRepository(this._client);

  final SupabaseClient _client;

  Future<List<CampaignModel>> getActiveCampaigns() async {
    _log('campaigns.fetch_active.start');
    try {
      final rows = await _client
          .from('campaigns')
          .select()
          .eq('status', 'active')
          .order('created_at', ascending: false);
      final mapped = _mapCampaignList(rows);
      _log('campaigns.fetch_active.success count=${mapped.length}');
      return mapped;
    } on PostgrestException catch (error) {
      if (!_isColumnError(error)) rethrow;

      final rows = await _client
          .from('campaigns')
          .select()
          .eq('status', 'active')
          .order('createdAt', ascending: false);
      final mapped = _mapCampaignList(rows);
      _log('campaigns.fetch_active.fallback_success count=${mapped.length}');
      return mapped;
    }
  }

  List<CampaignModel> _mapCampaignList(dynamic rows) {
    final data = rows is List ? rows : const <dynamic>[];
    return data
        .whereType<Object>()
        .map((item) => _toMap(item))
        .map(CampaignModel.fromMap)
        .where((campaign) => campaign.id.isNotEmpty)
        .toList();
  }

  Map<String, dynamic> _toMap(Object row) {
    if (row is Map<String, dynamic>) return row;
    if (row is Map) {
      return row.map((key, value) => MapEntry('$key', value));
    }
    throw StateError('Formato campaign non valido.');
  }

  bool _isColumnError(PostgrestException error) {
    return error.code == '42703' || error.code == 'PGRST204';
  }

  void _log(String message) {
    if (!kDebugMode) return;
    debugPrint('[CampaignRepository] $message');
  }
}
