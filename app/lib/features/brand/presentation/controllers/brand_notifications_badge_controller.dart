import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../campaigns/data/campaign_model.dart';

final brandNotificationsBadgeControllerProvider =
    StateNotifierProvider<
      BrandNotificationsBadgeController,
      BrandNotificationsBadgeState
    >((ref) {
      return BrandNotificationsBadgeController(
        authRepository: ref.watch(authRepositoryProvider),
      );
    });

class BrandNotificationsBadgeState {
  const BrandNotificationsBadgeState({
    this.isReady = false,
    this.seenApplicantsCount = -1,
    this.totalApplicantsCount = 0,
  });

  final bool isReady;
  final int seenApplicantsCount;
  final int totalApplicantsCount;

  int get unreadCount {
    if (!isReady || seenApplicantsCount < 0) return 0;
    return math.max(0, totalApplicantsCount - seenApplicantsCount);
  }

  bool get hasUnread => unreadCount > 0;

  BrandNotificationsBadgeState copyWith({
    bool? isReady,
    int? seenApplicantsCount,
    int? totalApplicantsCount,
  }) {
    return BrandNotificationsBadgeState(
      isReady: isReady ?? this.isReady,
      seenApplicantsCount: seenApplicantsCount ?? this.seenApplicantsCount,
      totalApplicantsCount: totalApplicantsCount ?? this.totalApplicantsCount,
    );
  }
}

class BrandNotificationsBadgeController
    extends StateNotifier<BrandNotificationsBadgeState> {
  BrandNotificationsBadgeController({required AuthRepository authRepository})
    : _authRepository = authRepository,
      super(const BrandNotificationsBadgeState());

  static const String _storageKeyPrefix = 'brand.notifications.seenApplicants';

  final AuthRepository _authRepository;
  String? _userId;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final userId = _authRepository.currentUser?.id;
    _userId = userId;
    if (userId == null) {
      state = state.copyWith(
        isReady: true,
        seenApplicantsCount: 0,
        totalApplicantsCount: 0,
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final storedSeen = prefs.getInt(_storageKeyFor(userId));
    state = state.copyWith(
      isReady: true,
      seenApplicantsCount: storedSeen ?? -1,
      totalApplicantsCount: 0,
    );
  }

  Future<void> syncFromCampaigns(List<CampaignModel> campaigns) async {
    if (!_initialized) await init();
    if (!state.isReady) return;

    final nextTotal = campaigns.fold<int>(
      0,
      (sum, campaign) => sum + campaign.applicantsCount,
    );

    if (state.seenApplicantsCount < 0) {
      state = state.copyWith(
        totalApplicantsCount: nextTotal,
        seenApplicantsCount: nextTotal,
      );
      await _persistSeen(nextTotal);
      return;
    }

    if (state.totalApplicantsCount == nextTotal) return;
    state = state.copyWith(totalApplicantsCount: nextTotal);
  }

  Future<void> markAllSeen() async {
    if (!_initialized) await init();
    if (!state.isReady) return;
    if (state.seenApplicantsCount == state.totalApplicantsCount) return;

    final seen = state.totalApplicantsCount;
    state = state.copyWith(seenApplicantsCount: seen);
    await _persistSeen(seen);
  }

  String _storageKeyFor(String userId) => '$_storageKeyPrefix.$userId';

  Future<void> _persistSeen(int value) async {
    final userId = _userId;
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_storageKeyFor(userId), value);
  }
}
