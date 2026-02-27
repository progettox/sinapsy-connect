import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_client_provider.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../chats/data/chat_repository.dart';
import '../../data/application_repository.dart';

final applicationsControllerProvider =
    StateNotifierProvider<ApplicationsController, ApplicationsState>((ref) {
      return ApplicationsController(
        client: ref.watch(supabaseClientProvider),
        authRepository: ref.watch(authRepositoryProvider),
        chatRepository: ref.watch(chatRepositoryProvider),
        applicationRepository: ref.watch(applicationRepositoryProvider),
      );
    });

class ApplicationsState {
  const ApplicationsState({
    this.isLoadingBrand = false,
    this.isLoadingMine = false,
    this.isMutating = false,
    this.activeMutationId,
    this.errorMessage,
    this.brandApplications = const <ApplicationItem>[],
    this.myApplications = const <ApplicationItem>[],
    this.dismissedCancelledWarningCampaignIds = const <String>{},
  });

  final bool isLoadingBrand;
  final bool isLoadingMine;
  final bool isMutating;
  final String? activeMutationId;
  final String? errorMessage;
  final List<ApplicationItem> brandApplications;
  final List<ApplicationItem> myApplications;
  final Set<String> dismissedCancelledWarningCampaignIds;

  ApplicationsState copyWith({
    bool? isLoadingBrand,
    bool? isLoadingMine,
    bool? isMutating,
    String? activeMutationId,
    bool clearActiveMutation = false,
    String? errorMessage,
    bool clearError = false,
    List<ApplicationItem>? brandApplications,
    List<ApplicationItem>? myApplications,
    Set<String>? dismissedCancelledWarningCampaignIds,
    bool clearDismissedCancelledWarnings = false,
  }) {
    return ApplicationsState(
      isLoadingBrand: isLoadingBrand ?? this.isLoadingBrand,
      isLoadingMine: isLoadingMine ?? this.isLoadingMine,
      isMutating: isMutating ?? this.isMutating,
      activeMutationId: clearActiveMutation
          ? null
          : (activeMutationId ?? this.activeMutationId),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      brandApplications: brandApplications ?? this.brandApplications,
      myApplications: myApplications ?? this.myApplications,
      dismissedCancelledWarningCampaignIds: clearDismissedCancelledWarnings
          ? <String>{}
          : Set<String>.from(
              dismissedCancelledWarningCampaignIds ??
                  this.dismissedCancelledWarningCampaignIds,
            ),
    );
  }
}

class ApplicationItem {
  const ApplicationItem({
    required this.id,
    required this.campaignId,
    required this.creatorId,
    required this.brandId,
    required this.status,
    this.createdAt,
    this.creatorUsername,
    this.campaignTitle,
    this.campaignStatus,
    this.chatId,
  });

  final String id;
  final String campaignId;
  final String creatorId;
  final String brandId;
  final String status;
  final DateTime? createdAt;
  final String? creatorUsername;
  final String? campaignTitle;
  final String? campaignStatus;
  final String? chatId;

  bool get isPending => status.toLowerCase() == 'pending';
  bool get isCancelledAfterMatch =>
      status.toLowerCase() == 'accepted' &&
      (campaignStatus ?? '').toLowerCase() == 'cancelled';

  ApplicationItem copyWith({
    String? brandId,
    String? status,
    String? creatorUsername,
    String? campaignTitle,
    String? campaignStatus,
    String? chatId,
    bool clearChatId = false,
  }) {
    return ApplicationItem(
      id: id,
      campaignId: campaignId,
      creatorId: creatorId,
      brandId: brandId ?? this.brandId,
      status: status ?? this.status,
      createdAt: createdAt,
      creatorUsername: creatorUsername ?? this.creatorUsername,
      campaignTitle: campaignTitle ?? this.campaignTitle,
      campaignStatus: campaignStatus ?? this.campaignStatus,
      chatId: clearChatId ? null : (chatId ?? this.chatId),
    );
  }
}

class ApplicationsController extends StateNotifier<ApplicationsState> {
  ApplicationsController({
    required SupabaseClient client,
    required AuthRepository authRepository,
    required ChatRepository chatRepository,
    required ApplicationRepository applicationRepository,
  }) : _client = client,
       _authRepository = authRepository,
       _chatRepository = chatRepository,
       _applicationRepository = applicationRepository,
       super(const ApplicationsState());

  final SupabaseClient _client;
  final AuthRepository _authRepository;
  final ChatRepository _chatRepository;
  final ApplicationRepository _applicationRepository;

  Future<void> loadBrandApplications({required String campaignId}) async {
    final brandId = _authRepository.currentUser?.id;
    if (brandId == null) {
      state = state.copyWith(errorMessage: 'Sessione non valida.');
      return;
    }

    _log(
      'brand_applications.fetch.start campaignId=$campaignId brandId=$brandId',
    );
    state = state.copyWith(isLoadingBrand: true, clearError: true);
    try {
      final rows = await _queryBrandApplications(campaignId: campaignId);
      final items = rows.map(_applicationFromMap).toList();
      final hydrated = await _hydrateApplications(items);
      final withChats = await _attachChatIds(hydrated);

      state = state.copyWith(
        isLoadingBrand: false,
        brandApplications: withChats,
        clearError: true,
      );
      _log(
        'brand_applications.fetch.success campaignId=$campaignId count=${withChats.length}',
      );
    } catch (error) {
      _log(
        'brand_applications.fetch.error campaignId=$campaignId error=$error',
      );
      state = state.copyWith(
        isLoadingBrand: false,
        errorMessage: 'Errore caricamento candidature: $error',
      );
    }
  }

  Future<void> loadMyApplications() async {
    final creatorId = _authRepository.currentUser?.id;
    if (creatorId == null) {
      state = state.copyWith(errorMessage: 'Sessione non valida.');
      return;
    }

    _log('my_applications.fetch.start creatorId=$creatorId');
    state = state.copyWith(isLoadingMine: true, clearError: true);
    try {
      final rows = await _queryMyApplications(creatorId: creatorId);
      final items = rows.map(_applicationFromMap).toList();
      final hydrated = await _hydrateApplications(items);
      final withChats = await _attachChatIds(hydrated);
      final hiddenCampaignIds = _applicationRepository
          .getLocallyWithdrawnCampaignIds();
      final visibleMine = withChats.where((item) {
        if (!hiddenCampaignIds.contains(item.campaignId)) return true;
        if (!item.isPending) {
          _applicationRepository.clearLocalWithdrawal(item.campaignId);
          return true;
        }
        return false;
      }).toList();
      final cancelledWarningCampaignIds = visibleMine
          .where((item) => item.isCancelledAfterMatch)
          .map((item) => item.campaignId)
          .toSet();
      final retainedDismissedWarnings = state.dismissedCancelledWarningCampaignIds
          .where(cancelledWarningCampaignIds.contains)
          .toSet();

      state = state.copyWith(
        isLoadingMine: false,
        myApplications: visibleMine,
        dismissedCancelledWarningCampaignIds: retainedDismissedWarnings,
        clearError: true,
      );
      _log(
        'my_applications.fetch.success creatorId=$creatorId count=${visibleMine.length}',
      );
    } catch (error) {
      _log('my_applications.fetch.error creatorId=$creatorId error=$error');
      state = state.copyWith(
        isLoadingMine: false,
        errorMessage: 'Errore caricamento candidature: $error',
      );
    }
  }

  Future<bool> acceptApplication(ApplicationItem item) async {
    if (!item.isPending) return false;
    _log('application.accept.start applicationId=${item.id}');

    state = state.copyWith(
      isMutating: true,
      activeMutationId: item.id,
      clearError: true,
    );

    try {
      final alreadyMatched = await _hasAcceptedApplicationForCampaign(
        campaignId: item.campaignId,
        excludeApplicationId: item.id,
      );
      if (alreadyMatched) {
        state = state.copyWith(
          isMutating: false,
          clearActiveMutation: true,
          errorMessage: 'Questa campagna ha gia un creator accettato.',
        );
        return false;
      }

      final brandId = item.brandId.isNotEmpty
          ? item.brandId
          : (await _resolveBrandIdForCampaign(item.campaignId));
      if (brandId == null || brandId.isEmpty) {
        throw StateError(
          'Brand id non disponibile per la campagna ${item.campaignId}.',
        );
      }

      await _updateApplicationStatus(
        applicationId: item.id,
        status: 'accepted',
      );
      await _updateCampaignStatus(
        campaignId: item.campaignId,
        status: 'matched',
      );
      await _rejectOtherPendingApplications(
        campaignId: item.campaignId,
        acceptedApplicationId: item.id,
      );
      String? chatId;
      try {
        chatId = await _chatRepository.createChatForMatch(
          campaignId: item.campaignId,
          brandId: brandId,
          creatorId: item.creatorId,
        );
      } on PostgrestException catch (error) {
        if (!_isPermissionDenied(error)) rethrow;
        _log(
          'application.accept.chat_permission_denied campaignId=${item.campaignId} applicationId=${item.id} code=${error.code}',
        );
      }

      _applySingleMatchLocally(
        campaignId: item.campaignId,
        acceptedApplicationId: item.id,
        chatId: chatId,
        brandId: brandId,
      );

      state = state.copyWith(
        isMutating: false,
        clearActiveMutation: true,
        clearError: true,
      );
      _log(
        'application.accept.success applicationId=${item.id} campaignId=${item.campaignId} chatId=$chatId',
      );
      return true;
    } catch (error) {
      _log('application.accept.error applicationId=${item.id} error=$error');
      state = state.copyWith(
        isMutating: false,
        clearActiveMutation: true,
        errorMessage: 'Errore match: $error',
      );
      return false;
    }
  }

  Future<bool> rejectApplication(ApplicationItem item) async {
    if (!item.isPending) return false;

    state = state.copyWith(
      isMutating: true,
      activeMutationId: item.id,
      clearError: true,
    );

    try {
      _log('application.reject.start applicationId=${item.id}');
      await _updateApplicationStatus(
        applicationId: item.id,
        status: 'rejected',
      );
      _replaceApplicationLocally(item.id, status: 'rejected');

      state = state.copyWith(
        isMutating: false,
        clearActiveMutation: true,
        clearError: true,
      );
      _log('application.reject.success applicationId=${item.id}');
      return true;
    } catch (error) {
      _log('application.reject.error applicationId=${item.id} error=$error');
      state = state.copyWith(
        isMutating: false,
        clearActiveMutation: true,
        errorMessage: 'Errore aggiornamento candidatura: $error',
      );
      return false;
    }
  }

  Future<bool> withdrawMyApplication(ApplicationItem item) async {
    if (!item.isPending) {
      state = state.copyWith(
        errorMessage: 'Puoi abbandonare solo candidature pending.',
      );
      return false;
    }

    final creatorId = _authRepository.currentUser?.id;
    if (creatorId == null) {
      state = state.copyWith(errorMessage: 'Sessione non valida.');
      return false;
    }

    _log(
      'application.withdraw.start applicationId=${item.id} campaignId=${item.campaignId} creatorId=$creatorId',
    );
    state = state.copyWith(
      isMutating: true,
      activeMutationId: item.id,
      clearError: true,
    );

    try {
      Object? deleteError;
      Object? updateError;

      try {
        await _deleteMyApplication(
          applicationId: item.id,
          creatorId: creatorId,
        );
      } catch (error) {
        deleteError = error;
      }

      try {
        await _markMyApplicationRejected(
          applicationId: item.id,
          creatorId: creatorId,
        );
      } catch (error) {
        updateError = error;
      }

      if (deleteError != null && updateError != null) {
        throw StateError('Annullamento non riuscito: $updateError');
      }
      _applicationRepository.markCampaignLocallyWithdrawn(item.campaignId);
      await _decrementCampaignApplicantsCount(campaignId: item.campaignId);
      _removeApplicationLocally(item.id);

      state = state.copyWith(
        isMutating: false,
        clearActiveMutation: true,
        clearError: true,
      );
      _log('application.withdraw.success applicationId=${item.id}');
      return true;
    } catch (error) {
      _log('application.withdraw.error applicationId=${item.id} error=$error');
      state = state.copyWith(
        isMutating: false,
        clearActiveMutation: true,
        errorMessage: 'Errore annullamento candidatura: $error',
      );
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void dismissCancelledMatchWarning(String campaignId) {
    final id = campaignId.trim();
    if (id.isEmpty) return;
    final next = Set<String>.from(state.dismissedCancelledWarningCampaignIds)
      ..add(id);
    state = state.copyWith(
      dismissedCancelledWarningCampaignIds: next,
      clearError: true,
    );
  }

  Future<List<Map<String, dynamic>>> _queryBrandApplications({
    required String campaignId,
  }) async {
    try {
      final rows = await _client
          .from('applications')
          .select('id,campaign_id,applicant_id,status,created_at')
          .eq('campaign_id', campaignId)
          .order('created_at', ascending: false);
      return _rowsToMaps(rows);
    } on PostgrestException catch (error) {
      if (!_isColumnError(error)) rethrow;

      final rows = await _client
          .from('applications')
          .select('id,campaign_id,creator_id,status,created_at')
          .eq('campaign_id', campaignId)
          .order('created_at', ascending: false);
      return _rowsToMaps(rows);
    }
  }

  Future<List<Map<String, dynamic>>> _queryMyApplications({
    required String creatorId,
  }) async {
    try {
      final rows = await _client
          .from('applications')
          .select('id,campaign_id,applicant_id,status,created_at')
          .eq('applicant_id', creatorId)
          .inFilter('status', const ['pending', 'accepted', 'rejected'])
          .order('created_at', ascending: false);
      return _rowsToMaps(rows);
    } on PostgrestException catch (error) {
      if (!_isColumnError(error)) rethrow;

      final rows = await _client
          .from('applications')
          .select('id,campaign_id,creator_id,status,created_at')
          .eq('creator_id', creatorId)
          .inFilter('status', const ['pending', 'accepted', 'rejected'])
          .order('created_at', ascending: false);
      return _rowsToMaps(rows);
    }
  }

  ApplicationItem _applicationFromMap(Map<String, dynamic> map) {
    return ApplicationItem(
      id: _string(map['id']) ?? '',
      campaignId: _string(map['campaign_id'] ?? map['campaignId']) ?? '',
      creatorId:
          _string(
            map['applicant_id'] ?? map['creator_id'] ?? map['creatorId'],
          ) ??
          '',
      brandId: _string(map['brand_id'] ?? map['brandId']) ?? '',
      status: _string(map['status']) ?? 'pending',
      createdAt: _dateTime(map['created_at'] ?? map['createdAt']),
      campaignStatus: _string(map['campaign_status'] ?? map['campaignStatus']),
    );
  }

  Future<List<ApplicationItem>> _hydrateApplications(
    List<ApplicationItem> items,
  ) async {
    if (items.isEmpty) return items;

    final creatorIds = items
        .map((e) => e.creatorId)
        .where((e) => e.isNotEmpty)
        .toSet();
    final campaignIds = items
        .map((e) => e.campaignId)
        .where((e) => e.isNotEmpty)
        .toSet();

    final usernames = await _loadCreatorUsernames(creatorIds);
    final campaignTitles = await _loadCampaignTitles(campaignIds);
    final campaignOwners = await _loadCampaignOwners(campaignIds);
    final campaignStatuses = await _loadCampaignStatuses(campaignIds);

    return items
        .map(
          (item) => item.copyWith(
            brandId: campaignOwners[item.campaignId],
            creatorUsername: usernames[item.creatorId],
            campaignTitle: campaignTitles[item.campaignId],
            campaignStatus: campaignStatuses[item.campaignId],
          ),
        )
        .toList();
  }

  Future<Map<String, String>> _loadCreatorUsernames(
    Set<String> creatorIds,
  ) async {
    if (creatorIds.isEmpty) return const <String, String>{};

    try {
      final rows = await _client
          .from('profiles')
          .select('id,username')
          .inFilter('id', creatorIds.toList());
      return _rowsToMaps(rows).fold<Map<String, String>>(<String, String>{}, (
        acc,
        row,
      ) {
        final id = _string(row['id']);
        final username = _string(row['username']);
        if (id != null && username != null) {
          acc[id] = username;
        }
        return acc;
      });
    } on PostgrestException catch (error) {
      if (!_isColumnError(error)) rethrow;

      final rows = await _client
          .from('profiles')
          .select('user_id,username')
          .inFilter('user_id', creatorIds.toList());
      return _rowsToMaps(rows).fold<Map<String, String>>(<String, String>{}, (
        acc,
        row,
      ) {
        final id = _string(row['user_id']);
        final username = _string(row['username']);
        if (id != null && username != null) {
          acc[id] = username;
        }
        return acc;
      });
    }
  }

  Future<Map<String, String>> _loadCampaignTitles(
    Set<String> campaignIds,
  ) async {
    if (campaignIds.isEmpty) return const <String, String>{};

    List<Map<String, dynamic>> rows;
    try {
      final result = await _client
          .from('campaigns')
          .select('id,title')
          .inFilter('id', campaignIds.toList());
      rows = _rowsToMaps(result);
    } on PostgrestException catch (error) {
      if (!_isColumnError(error)) rethrow;
      try {
        final result = await _client
            .from('campaigns')
            .select('id,name')
            .inFilter('id', campaignIds.toList());
        rows = _rowsToMaps(result);
      } on PostgrestException catch (innerError) {
        if (!_isColumnError(innerError)) rethrow;
        final result = await _client
            .from('campaigns')
            .select('id,headline')
            .inFilter('id', campaignIds.toList());
        rows = _rowsToMaps(result);
      }
    }

    return rows.fold<Map<String, String>>(<String, String>{}, (acc, row) {
      final id = _string(row['id']);
      final title =
          _string(row['title']) ??
          _string(row['name']) ??
          _string(row['headline']);
      if (id != null && title != null) {
        acc[id] = title;
      }
      return acc;
    });
  }

  Future<Map<String, String>> _loadCampaignOwners(
    Set<String> campaignIds,
  ) async {
    if (campaignIds.isEmpty) return const <String, String>{};

    try {
      final rows = await _client
          .from('campaigns')
          .select('id,brand_id')
          .inFilter('id', campaignIds.toList());
      return _rowsToMaps(rows).fold<Map<String, String>>(<String, String>{}, (
        acc,
        row,
      ) {
        final id = _string(row['id']);
        final brandId = _string(row['brand_id']);
        if (id != null && brandId != null) {
          acc[id] = brandId;
        }
        return acc;
      });
    } on PostgrestException catch (error) {
      if (!_isColumnError(error)) rethrow;

      final rows = await _client
          .from('campaigns')
          .select('id,brandId')
          .inFilter('id', campaignIds.toList());
      return _rowsToMaps(rows).fold<Map<String, String>>(<String, String>{}, (
        acc,
        row,
      ) {
        final id = _string(row['id']);
        final brandId = _string(row['brandId']);
        if (id != null && brandId != null) {
          acc[id] = brandId;
        }
        return acc;
      });
    }
  }

  Future<Map<String, String>> _loadCampaignStatuses(
    Set<String> campaignIds,
  ) async {
    if (campaignIds.isEmpty) return const <String, String>{};

    try {
      final rows = await _client
          .from('campaigns')
          .select('id,status')
          .inFilter('id', campaignIds.toList());
      return _rowsToMaps(rows).fold<Map<String, String>>(<String, String>{}, (
        acc,
        row,
      ) {
        final id = _string(row['id']);
        final status = _string(row['status']);
        if (id != null && status != null) {
          acc[id] = status;
        }
        return acc;
      });
    } on PostgrestException catch (error) {
      if (!_isColumnError(error)) rethrow;

      final rows = await _client
          .from('campaigns')
          .select('campaignId,status')
          .inFilter('campaignId', campaignIds.toList());
      return _rowsToMaps(rows).fold<Map<String, String>>(<String, String>{}, (
        acc,
        row,
      ) {
        final id = _string(row['campaignId']);
        final status = _string(row['status']);
        if (id != null && status != null) {
          acc[id] = status;
        }
        return acc;
      });
    }
  }

  Future<void> _updateApplicationStatus({
    required String applicationId,
    required String status,
  }) async {
    try {
      await _client
          .from('applications')
          .update({'status': status})
          .eq('id', applicationId);
    } on PostgrestException catch (error) {
      if (!_isColumnError(error)) rethrow;

      await _client
          .from('applications')
          .update({'status': status})
          .eq('id', applicationId);
    }
  }

  Future<void> _updateCampaignStatus({
    required String campaignId,
    required String status,
  }) async {
    try {
      await _client
          .from('campaigns')
          .update({'status': status})
          .eq('id', campaignId);
    } on PostgrestException catch (error) {
      if (!_isColumnError(error)) rethrow;

      await _client
          .from('campaigns')
          .update({'status': status})
          .eq('id', campaignId);
    }
  }

  Future<bool> _hasAcceptedApplicationForCampaign({
    required String campaignId,
    required String excludeApplicationId,
  }) async {
    try {
      final rows = await _client
          .from('applications')
          .select('id')
          .eq('campaign_id', campaignId)
          .eq('status', 'accepted')
          .neq('id', excludeApplicationId)
          .limit(1);
      return _rowsToMaps(rows).isNotEmpty;
    } on PostgrestException catch (error) {
      if (!_isColumnError(error)) rethrow;
    }

    final rows = await _client
        .from('applications')
        .select('id')
        .eq('campaignId', campaignId)
        .eq('status', 'accepted')
        .neq('id', excludeApplicationId)
        .limit(1);
    return _rowsToMaps(rows).isNotEmpty;
  }

  Future<void> _rejectOtherPendingApplications({
    required String campaignId,
    required String acceptedApplicationId,
  }) async {
    try {
      await _client
          .from('applications')
          .update({'status': 'rejected'})
          .eq('campaign_id', campaignId)
          .eq('status', 'pending')
          .neq('id', acceptedApplicationId);
      return;
    } on PostgrestException catch (error) {
      if (!_isColumnError(error)) rethrow;
    }

    await _client
        .from('applications')
        .update({'status': 'rejected'})
        .eq('campaignId', campaignId)
        .eq('status', 'pending')
        .neq('id', acceptedApplicationId);
  }

  Future<void> _deleteMyApplication({
    required String applicationId,
    required String creatorId,
  }) async {
    try {
      await _client
          .from('applications')
          .delete()
          .eq('id', applicationId)
          .eq('applicant_id', creatorId)
          .eq('status', 'pending');
    } on PostgrestException catch (error) {
      if (!_isColumnError(error)) rethrow;
    }

    try {
      await _client
          .from('applications')
          .delete()
          .eq('id', applicationId)
          .eq('creator_id', creatorId)
          .eq('status', 'pending');
    } on PostgrestException catch (error) {
      if (!_isColumnError(error)) rethrow;
    }
  }

  Future<void> _markMyApplicationRejected({
    required String applicationId,
    required String creatorId,
  }) async {
    try {
      await _client
          .from('applications')
          .update({'status': 'rejected'})
          .eq('id', applicationId)
          .eq('applicant_id', creatorId)
          .eq('status', 'pending');
    } on PostgrestException catch (error) {
      if (!_isColumnError(error)) rethrow;
    }

    try {
      await _client
          .from('applications')
          .update({'status': 'rejected'})
          .eq('id', applicationId)
          .eq('creator_id', creatorId)
          .eq('status', 'pending');
    } on PostgrestException catch (error) {
      if (!_isColumnError(error)) rethrow;
    }
  }

  Future<void> _decrementCampaignApplicantsCount({
    required String campaignId,
  }) async {
    try {
      await _client.rpc(
        'decrement_campaign_applicants_count',
        params: {'campaign_id_input': campaignId},
      );
      return;
    } on PostgrestException catch (error) {
      if (!_isMissingRpc(error) && !_isColumnError(error)) {
        _log(
          'campaign.decrement.rpc.error campaignId=$campaignId error=$error',
        );
      }
    } catch (error) {
      _log('campaign.decrement.rpc.error campaignId=$campaignId error=$error');
    }

    try {
      final row = await _client
          .from('campaigns')
          .select('applicants_count')
          .eq('id', campaignId)
          .maybeSingle();
      if (row != null) {
        final map = _toMap(row);
        final current = _int(map['applicants_count']) ?? 0;
        final next = current > 0 ? current - 1 : 0;
        await _client
            .from('campaigns')
            .update({'applicants_count': next})
            .eq('id', campaignId);
        return;
      }
    } on PostgrestException catch (error) {
      if (!_isColumnError(error)) {
        _log(
          'campaign.decrement.column.error campaignId=$campaignId error=$error',
        );
        return;
      }
    } catch (error) {
      _log(
        'campaign.decrement.column.error campaignId=$campaignId error=$error',
      );
      return;
    }

    try {
      final row = await _client
          .from('campaigns')
          .select('applicantsCount')
          .eq('id', campaignId)
          .maybeSingle();
      if (row != null) {
        final map = _toMap(row);
        final current = _int(map['applicantsCount']) ?? 0;
        final next = current > 0 ? current - 1 : 0;
        await _client
            .from('campaigns')
            .update({'applicantsCount': next})
            .eq('id', campaignId);
      }
    } catch (error) {
      _log(
        'campaign.decrement.fallback.error campaignId=$campaignId error=$error',
      );
    }
  }

  void _replaceApplicationLocally(
    String applicationId, {
    required String status,
    String? chatId,
    String? brandId,
  }) {
    List<ApplicationItem> patch(List<ApplicationItem> list) {
      return list.map((item) {
        if (item.id != applicationId) return item;
        return item.copyWith(status: status, chatId: chatId, brandId: brandId);
      }).toList();
    }

    state = state.copyWith(
      brandApplications: patch(state.brandApplications),
      myApplications: patch(state.myApplications),
    );
  }

  void _applySingleMatchLocally({
    required String campaignId,
    required String acceptedApplicationId,
    String? chatId,
    required String brandId,
  }) {
    List<ApplicationItem> patch(List<ApplicationItem> list) {
      return list.map((item) {
        if (item.campaignId != campaignId) return item;
        if (item.id == acceptedApplicationId) {
          final nextChatId = chatId?.trim();
          if (nextChatId != null && nextChatId.isNotEmpty) {
            return item.copyWith(
              status: 'accepted',
              chatId: nextChatId,
              brandId: brandId,
            );
          }
          return item.copyWith(
            status: 'accepted',
            clearChatId: true,
            brandId: brandId,
          );
        }
        if (item.isPending) {
          return item.copyWith(status: 'rejected', clearChatId: true);
        }
        return item;
      }).toList();
    }

    state = state.copyWith(
      brandApplications: patch(state.brandApplications),
      myApplications: patch(state.myApplications),
    );
  }

  void _removeApplicationLocally(String applicationId) {
    List<ApplicationItem> remove(List<ApplicationItem> list) {
      return list.where((item) => item.id != applicationId).toList();
    }

    state = state.copyWith(
      brandApplications: remove(state.brandApplications),
      myApplications: remove(state.myApplications),
    );
  }

  Future<List<ApplicationItem>> _attachChatIds(
    List<ApplicationItem> items,
  ) async {
    if (items.isEmpty) return items;

    final next = <ApplicationItem>[];
    for (final item in items) {
      if (item.status.toLowerCase() != 'accepted' ||
          item.chatId?.trim().isNotEmpty == true ||
          item.brandId.trim().isEmpty ||
          item.creatorId.trim().isEmpty ||
          item.campaignId.trim().isEmpty) {
        next.add(item);
        continue;
      }

      try {
        final chatId = await _chatRepository.getChatIdForMatch(
          campaignId: item.campaignId,
          brandId: item.brandId,
          creatorId: item.creatorId,
        );
        next.add(item.copyWith(chatId: chatId));
      } catch (_) {
        next.add(item);
      }
    }
    return next;
  }

  Future<String?> _resolveBrandIdForCampaign(String campaignId) async {
    try {
      final row = await _client
          .from('campaigns')
          .select('brand_id')
          .eq('id', campaignId)
          .maybeSingle();
      if (row != null) {
        final map = _toMap(row);
        return _string(map['brand_id']);
      }
    } on PostgrestException catch (error) {
      if (!_isColumnError(error)) rethrow;
      final row = await _client
          .from('campaigns')
          .select('brandId')
          .eq('id', campaignId)
          .maybeSingle();
      if (row != null) {
        final map = _toMap(row);
        return _string(map['brandId']);
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _rowsToMaps(dynamic rows) {
    final raw = rows is List ? rows : const <dynamic>[];
    return raw.whereType<Object>().map(_toMap).toList();
  }

  Map<String, dynamic> _toMap(Object row) {
    if (row is Map<String, dynamic>) return row;
    if (row is Map) {
      return row.map((key, value) => MapEntry('$key', value));
    }
    throw StateError('Formato record non valido.');
  }

  String? _string(dynamic value) {
    final text = (value ?? '').toString().trim();
    if (text.isEmpty) return null;
    return text;
  }

  int? _int(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  DateTime? _dateTime(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  bool _isColumnError(PostgrestException error) {
    return error.code == '42703' ||
        error.code == 'PGRST204' ||
        _messageContainsSqlState(error, '42703') ||
        error.message.toLowerCase().contains('does not exist') ||
        error.message.toLowerCase().contains('column');
  }

  bool _isMissingRpc(PostgrestException error) {
    return error.code == '42883' ||
        error.message.toLowerCase().contains('function') ||
        error.message.toLowerCase().contains('rpc');
  }

  bool _isPermissionDenied(PostgrestException error) {
    final message = error.message.toLowerCase();
    return error.code == '42501' ||
        _messageContainsSqlState(error, '42501') ||
        message.contains('row-level security') ||
        message.contains('forbidden') ||
        message.contains('permission denied');
  }

  bool _messageContainsSqlState(PostgrestException error, String sqlState) {
    final message = error.message;
    return message.contains('"code":"$sqlState"') ||
        message.contains('"code": "$sqlState"');
  }

  void _log(String message) {
    if (!kDebugMode) return;
    debugPrint('[ApplicationsController] $message');
  }
}
