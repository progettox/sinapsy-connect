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
    this.dismissedBrandRejectedApplicationIds = const <String>{},
    this.dismissedBrandViewRejectedApplicationIds = const <String>{},
  });

  final bool isLoadingBrand;
  final bool isLoadingMine;
  final bool isMutating;
  final String? activeMutationId;
  final String? errorMessage;
  final List<ApplicationItem> brandApplications;
  final List<ApplicationItem> myApplications;
  final Set<String> dismissedCancelledWarningCampaignIds;
  final Set<String> dismissedBrandRejectedApplicationIds;
  final Set<String> dismissedBrandViewRejectedApplicationIds;

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
    Set<String>? dismissedBrandRejectedApplicationIds,
    bool clearDismissedBrandRejected = false,
    Set<String>? dismissedBrandViewRejectedApplicationIds,
    bool clearDismissedBrandViewRejected = false,
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
      dismissedBrandRejectedApplicationIds: clearDismissedBrandRejected
          ? <String>{}
          : Set<String>.from(
              dismissedBrandRejectedApplicationIds ??
                  this.dismissedBrandRejectedApplicationIds,
            ),
      dismissedBrandViewRejectedApplicationIds: clearDismissedBrandViewRejected
          ? <String>{}
          : Set<String>.from(
              dismissedBrandViewRejectedApplicationIds ??
                  this.dismissedBrandViewRejectedApplicationIds,
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
    this.creatorRole,
    this.creatorCategory,
    this.campaignTitle,
    this.campaignStatus,
    this.projectStatus,
    this.chatId,
  });

  final String id;
  final String campaignId;
  final String creatorId;
  final String brandId;
  final String status;
  final DateTime? createdAt;
  final String? creatorUsername;
  final String? creatorRole;
  final String? creatorCategory;
  final String? campaignTitle;
  final String? campaignStatus;
  final String? projectStatus;
  final String? chatId;

  bool get isPending => status.toLowerCase() == 'pending';
  bool get isAccepted => status.toLowerCase() == 'accepted';
  bool get isCampaignCompleted =>
      (campaignStatus ?? '').trim().toLowerCase() == 'completed';
  bool get isCancelledAfterMatch =>
      status.toLowerCase() == 'accepted' &&
      (campaignStatus ?? '').toLowerCase() == 'cancelled';

  bool get brandMarkedWorkCompleted =>
      isCampaignCompleted || _completionFlags(projectStatus).brandConfirmed;

  bool get creatorMarkedWorkCompleted =>
      isCampaignCompleted || _completionFlags(projectStatus).creatorConfirmed;

  ApplicationItem copyWith({
    String? brandId,
    String? status,
    String? creatorUsername,
    String? creatorRole,
    String? creatorCategory,
    String? campaignTitle,
    String? campaignStatus,
    String? projectStatus,
    String? chatId,
    bool clearProjectStatus = false,
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
      creatorRole: creatorRole ?? this.creatorRole,
      creatorCategory: creatorCategory ?? this.creatorCategory,
      campaignTitle: campaignTitle ?? this.campaignTitle,
      campaignStatus: campaignStatus ?? this.campaignStatus,
      projectStatus: clearProjectStatus
          ? null
          : (projectStatus ?? this.projectStatus),
      chatId: clearChatId ? null : (chatId ?? this.chatId),
    );
  }

  static _CompletionFlags _completionFlags(String? rawProjectStatus) {
    final normalized = (rawProjectStatus ?? '').trim().toLowerCase();
    switch (normalized) {
      case 'completed':
        return const _CompletionFlags(
          brandConfirmed: true,
          creatorConfirmed: true,
        );
      case 'delivered_brand':
      case 'brand_done':
      case 'brand_completed':
        return const _CompletionFlags(
          brandConfirmed: true,
          creatorConfirmed: false,
        );
      case 'delivered_creator':
      case 'creator_done':
      case 'creator_completed':
      case 'delivered':
        return const _CompletionFlags(
          brandConfirmed: false,
          creatorConfirmed: true,
        );
      default:
        return const _CompletionFlags(
          brandConfirmed: false,
          creatorConfirmed: false,
        );
    }
  }
}

class WorkCompletionResult {
  const WorkCompletionResult({
    required this.success,
    required this.nowCompleted,
    required this.alreadyCompleted,
  });

  final bool success;
  final bool nowCompleted;
  final bool alreadyCompleted;
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
      final brandRejectedApplicationIds = withChats
          .where((item) => item.status.toLowerCase() == 'rejected')
          .map((item) => item.id)
          .toSet();
      final visibleBrand = withChats.where((item) {
        if (item.status.toLowerCase() != 'rejected') return true;
        return !state.dismissedBrandViewRejectedApplicationIds.contains(
          item.id,
        );
      }).toList();
      final retainedDismissedRejected = state
          .dismissedBrandViewRejectedApplicationIds
          .where(brandRejectedApplicationIds.contains)
          .toSet();

      state = state.copyWith(
        isLoadingBrand: false,
        brandApplications: visibleBrand,
        dismissedBrandViewRejectedApplicationIds: retainedDismissedRejected,
        clearError: true,
      );
      _log(
        'brand_applications.fetch.success campaignId=$campaignId count=${visibleBrand.length}',
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
      final hiddenApplicationIds = _applicationRepository
          .getLocallyWithdrawnApplicationIds();
      final cancelledAfterMatchCampaignIds = withChats
          .where((item) => item.isCancelledAfterMatch)
          .map((item) => item.campaignId)
          .toSet();
      final brandRejectedApplicationIds = withChats
          .where(
            (item) =>
                item.status.toLowerCase() == 'rejected' &&
                !hiddenApplicationIds.contains(item.id),
          )
          .map((item) => item.id)
          .toSet();
      final visibleMine = withChats
          .where((item) {
            if (hiddenApplicationIds.contains(item.id)) return false;
            if (!hiddenCampaignIds.contains(item.campaignId)) return true;
            if (!item.isPending) {
              _applicationRepository.clearLocalWithdrawal(item.campaignId);
              return true;
            }
            return false;
          })
          .where((item) {
            if (!item.isCancelledAfterMatch) return true;
            return !state.dismissedCancelledWarningCampaignIds.contains(
              item.campaignId,
            );
          })
          .where((item) {
            if (item.status.toLowerCase() != 'rejected') return true;
            return !state.dismissedBrandRejectedApplicationIds.contains(
              item.id,
            );
          })
          .toList();
      final retainedDismissedWarnings = state
          .dismissedCancelledWarningCampaignIds
          .where(cancelledAfterMatchCampaignIds.contains)
          .toSet();
      final retainedDismissedRejected = state
          .dismissedBrandRejectedApplicationIds
          .where(brandRejectedApplicationIds.contains)
          .toSet();

      state = state.copyWith(
        isLoadingMine: false,
        myApplications: visibleMine,
        dismissedCancelledWarningCampaignIds: retainedDismissedWarnings,
        dismissedBrandRejectedApplicationIds: retainedDismissedRejected,
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
          errorMessage: 'Questa campagna ha già un creator accettato.',
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
      _applicationRepository.markApplicationLocallyWithdrawn(item.id);
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

  Future<WorkCompletionResult> markWorkCompleted(ApplicationItem item) async {
    if (!item.isAccepted) {
      state = state.copyWith(
        errorMessage: 'Puoi concludere solo lavori con candidatura accepted.',
      );
      return const WorkCompletionResult(
        success: false,
        nowCompleted: false,
        alreadyCompleted: false,
      );
    }

    final currentUserId = _authRepository.currentUser?.id.trim();
    if (currentUserId == null || currentUserId.isEmpty) {
      state = state.copyWith(errorMessage: 'Sessione non valida.');
      return const WorkCompletionResult(
        success: false,
        nowCompleted: false,
        alreadyCompleted: false,
      );
    }

    final creatorId = item.creatorId.trim();
    var brandId = item.brandId.trim();
    if (brandId.isEmpty) {
      brandId = (await _resolveBrandIdForCampaign(item.campaignId) ?? '')
          .trim();
    }

    final isCreatorActor = creatorId.isNotEmpty && creatorId == currentUserId;
    final isBrandActor = brandId.isNotEmpty
        ? brandId == currentUserId
        : (!isCreatorActor && currentUserId.isNotEmpty);
    if (!isCreatorActor && !isBrandActor) {
      state = state.copyWith(
        errorMessage: 'Non sei autorizzato a concludere questo lavoro.',
      );
      return const WorkCompletionResult(
        success: false,
        nowCompleted: false,
        alreadyCompleted: false,
      );
    }

    state = state.copyWith(
      isMutating: true,
      activeMutationId: item.id,
      clearError: true,
    );

    try {
      var projectRecord = await _findProjectRecordForItem(
        campaignId: item.campaignId,
        brandId: brandId,
        creatorId: creatorId,
      );
      if (projectRecord == null &&
          item.campaignId.trim().isNotEmpty &&
          brandId.isNotEmpty &&
          creatorId.isNotEmpty) {
        await _chatRepository.createChatForMatch(
          campaignId: item.campaignId,
          brandId: brandId,
          creatorId: creatorId,
        );
        projectRecord = await _findProjectRecordForItem(
          campaignId: item.campaignId,
          brandId: brandId,
          creatorId: creatorId,
        );
      }

      if (projectRecord == null) {
        throw StateError(
          'Project non trovato per la campagna ${item.campaignId}.',
        );
      }

      final currentProjectStatus = projectRecord.status.trim().toLowerCase();
      final currentFlags = ApplicationItem._completionFlags(
        currentProjectStatus,
      );
      var brandConfirmed = currentFlags.brandConfirmed;
      var creatorConfirmed = currentFlags.creatorConfirmed;

      if (isBrandActor && brandConfirmed) {
        state = state.copyWith(
          isMutating: false,
          clearActiveMutation: true,
          clearError: true,
        );
        return WorkCompletionResult(
          success: true,
          nowCompleted: false,
          alreadyCompleted:
              item.isCampaignCompleted || currentProjectStatus == 'completed',
        );
      }

      if (isCreatorActor && creatorConfirmed) {
        state = state.copyWith(
          isMutating: false,
          clearActiveMutation: true,
          clearError: true,
        );
        return WorkCompletionResult(
          success: true,
          nowCompleted: false,
          alreadyCompleted:
              item.isCampaignCompleted || currentProjectStatus == 'completed',
        );
      }

      if (isBrandActor) {
        brandConfirmed = true;
      } else {
        creatorConfirmed = true;
      }

      final nextProjectStatus = _nextProjectStatus(
        brandConfirmed: brandConfirmed,
        creatorConfirmed: creatorConfirmed,
      );

      if (nextProjectStatus != currentProjectStatus) {
        await _updateProjectStatus(
          projectId: projectRecord.id,
          status: nextProjectStatus,
        );
      }

      final isNowCompleted =
          nextProjectStatus == 'completed' ||
          (item.campaignStatus ?? '').trim().toLowerCase() == 'completed';

      if (isNowCompleted &&
          (item.campaignStatus ?? '').trim().toLowerCase() != 'completed') {
        await _updateCampaignStatus(
          campaignId: item.campaignId,
          status: 'completed',
        );
      }

      _applyWorkCompletionLocally(
        campaignId: item.campaignId,
        projectStatus: nextProjectStatus,
        campaignCompleted: isNowCompleted,
      );

      state = state.copyWith(
        isMutating: false,
        clearActiveMutation: true,
        clearError: true,
      );

      return WorkCompletionResult(
        success: true,
        nowCompleted:
            isNowCompleted &&
            (item.campaignStatus ?? '').trim().toLowerCase() != 'completed',
        alreadyCompleted:
            item.isCampaignCompleted || currentProjectStatus == 'completed',
      );
    } catch (error) {
      _log(
        'application.work_completed.error applicationId=${item.id} error=$error',
      );
      state = state.copyWith(
        isMutating: false,
        clearActiveMutation: true,
        errorMessage: 'Errore chiusura lavoro: $error',
      );
      return const WorkCompletionResult(
        success: false,
        nowCompleted: false,
        alreadyCompleted: false,
      );
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
    final nextMine = state.myApplications
        .where((item) => !(item.campaignId == id && item.isCancelledAfterMatch))
        .toList();
    state = state.copyWith(
      dismissedCancelledWarningCampaignIds: next,
      myApplications: nextMine,
      clearError: true,
    );
  }

  void dismissBrandRejectedApplication(String applicationId) {
    final id = applicationId.trim();
    if (id.isEmpty) return;
    final next = Set<String>.from(state.dismissedBrandRejectedApplicationIds)
      ..add(id);
    final nextMine = state.myApplications
        .where((item) => item.id != id)
        .toList();
    state = state.copyWith(
      dismissedBrandRejectedApplicationIds: next,
      myApplications: nextMine,
      clearError: true,
    );
  }

  void dismissRejectedApplicationForBrandView(String applicationId) {
    final id = applicationId.trim();
    if (id.isEmpty) return;
    final next = Set<String>.from(
      state.dismissedBrandViewRejectedApplicationIds,
    )..add(id);
    final nextBrand = state.brandApplications
        .where((item) => item.id != id)
        .toList();
    state = state.copyWith(
      dismissedBrandViewRejectedApplicationIds: next,
      brandApplications: nextBrand,
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
      projectStatus: _string(map['project_status'] ?? map['projectStatus']),
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

    final creatorMetaById = await _loadCreatorMeta(creatorIds);
    final campaignTitles = await _loadCampaignTitles(campaignIds);
    final campaignOwners = await _loadCampaignOwners(campaignIds);
    final campaignStatuses = await _loadCampaignStatuses(campaignIds);
    final projectStatuses = await _loadProjectStatuses(campaignIds);

    return items
        .map(
          (item) => item.copyWith(
            brandId: campaignOwners[item.campaignId],
            creatorUsername: creatorMetaById[item.creatorId]?.username,
            creatorRole: creatorMetaById[item.creatorId]?.roleLabel,
            creatorCategory: creatorMetaById[item.creatorId]?.categoryLabel,
            campaignTitle: campaignTitles[item.campaignId],
            campaignStatus: campaignStatuses[item.campaignId],
            projectStatus: projectStatuses[item.campaignId],
          ),
        )
        .toList();
  }

  Future<Map<String, _CreatorProfileMeta>> _loadCreatorMeta(
    Set<String> creatorIds,
  ) async {
    if (creatorIds.isEmpty) return const <String, _CreatorProfileMeta>{};

    final canonicalIdRows = await _queryCreatorMetaRows(
      idColumn: 'id',
      creatorIds: creatorIds,
      selectVariants: const <String>[
        'id,username,role,category,bio',
        'id,username,role,bio',
        'id,username,role',
        'id,username',
      ],
    );
    if (canonicalIdRows != null) {
      return _mapCreatorMetaRows(canonicalIdRows, idColumn: 'id');
    }

    final legacyIdRows = await _queryCreatorMetaRows(
      idColumn: 'user_id',
      creatorIds: creatorIds,
      selectVariants: const <String>[
        'user_id,username,role,category,bio',
        'user_id,username,role,bio',
        'user_id,username,role',
        'user_id,username',
      ],
    );
    if (legacyIdRows != null) {
      return _mapCreatorMetaRows(legacyIdRows, idColumn: 'user_id');
    }

    return const <String, _CreatorProfileMeta>{};
  }

  Future<List<Map<String, dynamic>>?> _queryCreatorMetaRows({
    required String idColumn,
    required Set<String> creatorIds,
    required List<String> selectVariants,
  }) async {
    PostgrestException? lastColumnError;
    for (final fields in selectVariants) {
      try {
        final rows = await _client
            .from('profiles')
            .select(fields)
            .inFilter(idColumn, creatorIds.toList());
        return _rowsToMaps(rows);
      } on PostgrestException catch (error) {
        if (!_isColumnError(error)) rethrow;
        lastColumnError = error;
      }
    }
    if (lastColumnError != null) return null;
    return null;
  }

  Map<String, _CreatorProfileMeta> _mapCreatorMetaRows(
    List<Map<String, dynamic>> rows, {
    required String idColumn,
  }) {
    return rows.fold<Map<String, _CreatorProfileMeta>>(
      <String, _CreatorProfileMeta>{},
      (acc, row) {
        final id = _string(row[idColumn]);
        if (id == null) return acc;

        final username = _string(row['username']);
        final rawRole = _string(row['role']) ?? '';
        final normalizedRole = _normalizeRole(rawRole);
        final roleLabel = _roleLabel(normalizedRole, fallback: rawRole);
        final explicitCategory =
            _string(
              row['category'] ??
                  row['creator_category'] ??
                  row['specialization'] ??
                  row['service_type'],
            ) ??
            '';
        final bio = _string(row['bio']) ?? '';
        final categoryLabel = _resolveCategoryLabel(
          explicitCategory: explicitCategory,
          bio: bio,
          normalizedRole: normalizedRole,
        );

        acc[id] = _CreatorProfileMeta(
          username: username,
          roleLabel: roleLabel,
          categoryLabel: categoryLabel,
        );
        return acc;
      },
    );
  }

  String _resolveCategoryLabel({
    required String explicitCategory,
    required String bio,
    required String normalizedRole,
  }) {
    final direct = explicitCategory.trim();
    if (direct.isNotEmpty) return direct;

    final extracted = _extractCategoryFromBio(bio);
    if (extracted.isNotEmpty) return extracted;

    if (normalizedRole == 'brand') return 'Brand';
    return 'Creator';
  }

  String _extractCategoryFromBio(String rawBio) {
    final bio = rawBio.trim();
    if (bio.isEmpty) return '';

    final patterns = <RegExp>[
      RegExp(r'Specializzazione:\s*\n?([^\n]+)', caseSensitive: false),
      RegExp(r'Categoria:\s*\n?([^\n]+)', caseSensitive: false),
      RegExp(r'Tipologia:\s*\n?([^\n]+)', caseSensitive: false),
      RegExp(r'Category:\s*\n?([^\n]+)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(bio);
      final value = match?.group(1)?.trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _normalizeRole(String rawRole) {
    final role = rawRole.trim().toLowerCase();
    if (role.isEmpty) return '';
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
        return cleanFallback.isEmpty ? 'Creator' : cleanFallback;
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

  Future<Map<String, String>> _loadProjectStatuses(
    Set<String> campaignIds,
  ) async {
    if (campaignIds.isEmpty) return const <String, String>{};

    try {
      final rows = await _client
          .from('projects')
          .select('campaign_id,status')
          .inFilter('campaign_id', campaignIds.toList());
      return _rowsToMaps(rows).fold<Map<String, String>>(<String, String>{}, (
        acc,
        row,
      ) {
        final campaignId = _string(row['campaign_id']);
        final status = _string(row['status']);
        if (campaignId != null &&
            status != null &&
            !acc.containsKey(campaignId)) {
          acc[campaignId] = status;
        }
        return acc;
      });
    } on PostgrestException catch (error) {
      if (_isMissingTable(error)) return const <String, String>{};
      if (!_isColumnError(error)) rethrow;
    }

    try {
      final rows = await _client
          .from('projects')
          .select('campaignId,status')
          .inFilter('campaignId', campaignIds.toList());
      return _rowsToMaps(rows).fold<Map<String, String>>(<String, String>{}, (
        acc,
        row,
      ) {
        final campaignId = _string(row['campaignId']);
        final status = _string(row['status']);
        if (campaignId != null &&
            status != null &&
            !acc.containsKey(campaignId)) {
          acc[campaignId] = status;
        }
        return acc;
      });
    } on PostgrestException catch (error) {
      if (_isMissingTable(error)) return const <String, String>{};
      if (!_isColumnError(error)) rethrow;
      return const <String, String>{};
    }
  }

  Future<_ProjectRecord?> _findProjectRecordForItem({
    required String campaignId,
    required String brandId,
    required String creatorId,
  }) async {
    final cleanCampaignId = campaignId.trim();
    final cleanBrandId = brandId.trim();
    final cleanCreatorId = creatorId.trim();
    if (cleanCampaignId.isEmpty) return null;

    try {
      var query = _client
          .from('projects')
          .select('id,status')
          .eq('campaign_id', cleanCampaignId);
      if (cleanBrandId.isNotEmpty) {
        query = query.eq('brand_id', cleanBrandId);
      }
      if (cleanCreatorId.isNotEmpty) {
        query = query.eq('partner_id', cleanCreatorId);
      }
      final row = await query.maybeSingle();
      if (row != null) {
        final map = _toMap(row);
        final id = _string(map['id']);
        if (id != null) {
          return _ProjectRecord(id: id, status: _string(map['status']) ?? '');
        }
      }
    } on PostgrestException catch (error) {
      if (_isMissingTable(error)) return null;
      if (!_isColumnError(error)) rethrow;
    }

    try {
      var query = _client
          .from('projects')
          .select('id,status')
          .eq('campaignId', cleanCampaignId);
      if (cleanBrandId.isNotEmpty) {
        query = query.eq('brandId', cleanBrandId);
      }
      if (cleanCreatorId.isNotEmpty) {
        query = query.eq('partnerId', cleanCreatorId);
      }
      final row = await query.maybeSingle();
      if (row != null) {
        final map = _toMap(row);
        final id = _string(map['id']);
        if (id != null) {
          return _ProjectRecord(id: id, status: _string(map['status']) ?? '');
        }
      }
    } on PostgrestException catch (error) {
      if (_isMissingTable(error)) return null;
      if (!_isColumnError(error)) rethrow;
    }

    try {
      final row = await _client
          .from('projects')
          .select('id,status')
          .eq('campaign_id', cleanCampaignId)
          .maybeSingle();
      if (row != null) {
        final map = _toMap(row);
        final id = _string(map['id']);
        if (id != null) {
          return _ProjectRecord(id: id, status: _string(map['status']) ?? '');
        }
      }
    } on PostgrestException catch (error) {
      if (_isMissingTable(error)) return null;
      if (!_isColumnError(error)) rethrow;
    }

    try {
      final row = await _client
          .from('projects')
          .select('id,status')
          .eq('campaignId', cleanCampaignId)
          .maybeSingle();
      if (row != null) {
        final map = _toMap(row);
        final id = _string(map['id']);
        if (id != null) {
          return _ProjectRecord(id: id, status: _string(map['status']) ?? '');
        }
      }
    } on PostgrestException catch (error) {
      if (_isMissingTable(error)) return null;
      if (!_isColumnError(error)) rethrow;
    }

    return null;
  }

  String _nextProjectStatus({
    required bool brandConfirmed,
    required bool creatorConfirmed,
  }) {
    if (brandConfirmed && creatorConfirmed) return 'completed';
    if (brandConfirmed) return 'delivered_brand';
    if (creatorConfirmed) return 'delivered_creator';
    return 'in_progress';
  }

  Future<void> _updateProjectStatus({
    required String projectId,
    required String status,
  }) async {
    try {
      await _client
          .from('projects')
          .update({'status': status})
          .eq('id', projectId);
      return;
    } on PostgrestException catch (error) {
      if (_isMissingTable(error)) return;
      if (!_isColumnError(error)) rethrow;
    }

    await _client
        .from('projects')
        .update({'status': status})
        .eq('id', projectId);
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

  void _applyWorkCompletionLocally({
    required String campaignId,
    required String projectStatus,
    required bool campaignCompleted,
  }) {
    List<ApplicationItem> patch(List<ApplicationItem> list) {
      return list
          .map((item) {
            if (item.campaignId != campaignId) return item;
            return item.copyWith(
              projectStatus: projectStatus,
              campaignStatus: campaignCompleted
                  ? 'completed'
                  : item.campaignStatus,
            );
          })
          .toList(growable: false);
    }

    state = state.copyWith(
      brandApplications: patch(state.brandApplications),
      myApplications: patch(state.myApplications),
    );
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

  bool _isMissingTable(PostgrestException error) {
    return error.code == '42P01' ||
        error.code == 'PGRST205' ||
        _messageContainsSqlState(error, '42P01') ||
        error.message.toLowerCase().contains('relation') &&
            error.message.toLowerCase().contains('does not exist');
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

class _CreatorProfileMeta {
  const _CreatorProfileMeta({
    required this.username,
    required this.roleLabel,
    required this.categoryLabel,
  });

  final String? username;
  final String roleLabel;
  final String categoryLabel;
}

class _CompletionFlags {
  const _CompletionFlags({
    required this.brandConfirmed,
    required this.creatorConfirmed,
  });

  final bool brandConfirmed;
  final bool creatorConfirmed;
}

class _ProjectRecord {
  const _ProjectRecord({required this.id, required this.status});

  final String id;
  final String status;
}
