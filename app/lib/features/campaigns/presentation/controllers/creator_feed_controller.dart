import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/profile/data/profile_model.dart';
import '../../../applications/data/application_repository.dart';
import '../../data/campaign_model.dart';
import '../../data/campaign_repository.dart';

final creatorFeedControllerProvider =
    StateNotifierProvider<CreatorFeedController, CreatorFeedState>((ref) {
      return CreatorFeedController(
        campaignRepository: ref.watch(campaignRepositoryProvider),
        applicationRepository: ref.watch(applicationRepositoryProvider),
      );
    });

class CreatorFeedState {
  const CreatorFeedState({
    this.isLoading = false,
    this.isApplying = false,
    this.applyingCampaignId,
    this.errorMessage,
    this.campaigns = const <CampaignModel>[],
  });

  final bool isLoading;
  final bool isApplying;
  final String? applyingCampaignId;
  final String? errorMessage;
  final List<CampaignModel> campaigns;

  CreatorFeedState copyWith({
    bool? isLoading,
    bool? isApplying,
    String? applyingCampaignId,
    bool clearApplyingCampaign = false,
    String? errorMessage,
    bool clearError = false,
    List<CampaignModel>? campaigns,
  }) {
    return CreatorFeedState(
      isLoading: isLoading ?? this.isLoading,
      isApplying: isApplying ?? this.isApplying,
      applyingCampaignId: clearApplyingCampaign
          ? null
          : (applyingCampaignId ?? this.applyingCampaignId),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      campaigns: campaigns ?? this.campaigns,
    );
  }
}

class CreatorFeedController extends StateNotifier<CreatorFeedState> {
  CreatorFeedController({
    required CampaignRepository campaignRepository,
    required ApplicationRepository applicationRepository,
  }) : _campaignRepository = campaignRepository,
       _applicationRepository = applicationRepository,
       super(const CreatorFeedState());

  final CampaignRepository _campaignRepository;
  final ApplicationRepository _applicationRepository;

  Future<void> loadFeed() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final campaigns = await _campaignRepository.getActiveCampaigns();
      state = state.copyWith(
        isLoading: false,
        campaigns: campaigns,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Errore caricamento annunci: $error',
      );
    }
  }

  void skipCampaign(String campaignId) {
    final nextCampaigns = state.campaigns
        .where((campaign) => campaign.id != campaignId)
        .toList();
    state = state.copyWith(campaigns: nextCampaigns, clearError: true);
  }

  Future<bool> applyToCampaign({
    required CampaignModel campaign,
    required ProfileModel? profile,
  }) async {
    final blockReason = _validateRequirements(
      campaign: campaign,
      profile: profile,
    );
    if (blockReason != null) {
      state = state.copyWith(errorMessage: blockReason);
      return false;
    }

    state = state.copyWith(
      isApplying: true,
      applyingCampaignId: campaign.id,
      clearError: true,
    );

    try {
      await _applicationRepository.applyToCampaign(campaign);
      final nextCampaigns = state.campaigns
          .where((item) => item.id != campaign.id)
          .toList();
      state = state.copyWith(
        isApplying: false,
        clearApplyingCampaign: true,
        campaigns: nextCampaigns,
        clearError: true,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        isApplying: false,
        clearApplyingCampaign: true,
        errorMessage: 'Candidatura non inviata: $error',
      );
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  String? _validateRequirements({
    required CampaignModel campaign,
    required ProfileModel? profile,
  }) {
    if (profile == null) {
      return 'Completa il profilo prima di candidarti.';
    }

    final campaignLocation = (campaign.locationRequired ?? '').trim();
    final profileLocation = profile.location.trim();
    if (campaignLocation.isNotEmpty &&
        profileLocation.toLowerCase() != campaignLocation.toLowerCase()) {
      return 'Requisito location non soddisfatto per questo annuncio.';
    }

    final requiredFollowers = campaign.minFollowers;
    final profileFollowers = _readFollowers(profile);
    if (requiredFollowers != null &&
        profileFollowers != null &&
        profileFollowers < requiredFollowers) {
      return 'Richiesti almeno $requiredFollowers follower.';
    }

    return null;
  }

  int? _readFollowers(ProfileModel profile) {
    return profile.followersCount;
  }
}
