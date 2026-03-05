import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_client_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/sinapsy_logo_loader.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../../data/campaign_model.dart';
import '../controllers/creator_feed_controller.dart';

class CreatorFeedPage extends ConsumerStatefulWidget {
  const CreatorFeedPage({super.key});

  @override
  ConsumerState<CreatorFeedPage> createState() => _CreatorFeedPageState();
}

class _CreatorFeedPageState extends ConsumerState<CreatorFeedPage> {
  Map<String, _BrandLiteProfile> _brandsById =
      const <String, _BrandLiteProfile>{};
  int _activeCampaignIndex = 0;
  bool _isLoadingBrands = false;
  String? _feedErrorMessage;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      ref.read(profileControllerProvider.notifier).watchMyProfile();
      await ref.read(profileControllerProvider.notifier).loadMyProfile();
      await ref.read(creatorFeedControllerProvider.notifier).loadFeed();
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _refreshFeed() async {
    await ref.read(creatorFeedControllerProvider.notifier).loadFeed();
  }

  Future<void> _apply(CampaignModel campaign) async {
    final profile = ref.read(profileControllerProvider).profile;
    final ok = await ref
        .read(creatorFeedControllerProvider.notifier)
        .applyToCampaign(campaign: campaign, profile: profile);
    if (!mounted || !ok) return;
    _showSnack('Candidatura inviata con successo.');
  }

  void _skipActiveCampaign(List<CampaignModel> campaigns) {
    if (campaigns.isEmpty) return;
    final safeIndex = _activeCampaignIndex >= campaigns.length
        ? campaigns.length - 1
        : _activeCampaignIndex;
    final campaignId = campaigns[safeIndex].id.trim();
    if (campaignId.isEmpty) return;
    ref.read(creatorFeedControllerProvider.notifier).skipCampaign(campaignId);
    _showSnack('Annuncio saltato.');
  }

  Future<void> _loadBrandProfilesForCampaigns(
    List<CampaignModel> campaigns,
  ) async {
    final brandIds = campaigns
        .map((campaign) => campaign.brandId?.trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (brandIds.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoadingBrands = false;
        _brandsById = const <String, _BrandLiteProfile>{};
      });
      return;
    }

    if (!mounted) return;
    setState(() => _isLoadingBrands = true);

    try {
      final client = ref.read(supabaseClientProvider);
      final rows = await _fetchBrandRows(client: client, brandIds: brandIds);
      if (!mounted) return;

      final map = <String, _BrandLiteProfile>{};
      for (final row in rows) {
        final profile = _BrandLiteProfile.fromMap(row);
        final keys = <String>{
          profile.id.trim(),
          (row['id'] ?? '').toString().trim(),
          (row['user_id'] ?? row['userId'] ?? '').toString().trim(),
        }.where((key) => key.isNotEmpty);
        for (final key in keys) {
          map[key] = profile;
        }
      }

      setState(() {
        _isLoadingBrands = false;
        _brandsById = map;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingBrands = false;
        _brandsById = const <String, _BrandLiteProfile>{};
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchBrandRows({
    required SupabaseClient client,
    required List<String> brandIds,
  }) async {
    const idSelectVariants = <String>[
      'id, username, first_name, last_name, avatar_url',
      'id, username, avatar_url',
      'id, username, firstName, lastName, avatarUrl',
      'id, username, avatarUrl',
    ];
    const userIdSelectVariants = <String>[
      'id, user_id, username, first_name, last_name, avatar_url',
      'id, user_id, username, avatar_url',
      'id, user_id, username, firstName, lastName, avatarUrl',
      'id, user_id, username, avatarUrl',
    ];

    Future<List<Map<String, dynamic>>> loadRows({
      required String column,
      required List<String> selectVariants,
    }) async {
      PostgrestException? lastColumnError;
      for (final fields in selectVariants) {
        try {
          final raw = await client
              .from('profiles')
              .select(fields)
              .inFilter(column, brandIds);
          return List<Map<String, dynamic>>.from(raw as List);
        } on PostgrestException catch (error) {
          if (_isMissingTable(error)) return const <Map<String, dynamic>>[];
          if (!_isColumnError(error)) rethrow;
          lastColumnError = error;
        }
      }
      if (lastColumnError != null) throw lastColumnError;
      return const <Map<String, dynamic>>[];
    }

    final rowsById = await loadRows(
      column: 'id',
      selectVariants: idSelectVariants,
    );
    if (rowsById.isNotEmpty) return rowsById;

    final rowsByUserId = await loadRows(
      column: 'user_id',
      selectVariants: userIdSelectVariants,
    );
    return rowsByUserId;
  }

  bool _isColumnError(PostgrestException error) {
    final message = error.message.toLowerCase();
    return error.code == '42703' ||
        error.code == 'PGRST204' ||
        (message.contains('column') && message.contains('does not exist'));
  }

  bool _isMissingTable(PostgrestException error) {
    final message = error.message.toLowerCase();
    return error.code == '42P01' ||
        error.code == 'PGRST205' ||
        (message.contains('relation') && message.contains('does not exist'));
  }

  bool _didCampaignListChange(
    List<CampaignModel> previous,
    List<CampaignModel> next,
  ) {
    if (identical(previous, next)) return false;
    if (previous.length != next.length) return true;
    for (var i = 0; i < previous.length; i++) {
      if (previous[i].id != next[i].id) return true;
    }
    return false;
  }

  String? _resolveHeroImageUrl(List<CampaignModel> campaigns) {
    if (campaigns.isEmpty) return null;
    final safeIndex = _activeCampaignIndex >= campaigns.length
        ? campaigns.length - 1
        : _activeCampaignIndex;
    final activeCampaign = campaigns[safeIndex];
    final brandId = activeCampaign.brandId?.trim() ?? '';
    final brandAvatar = _brandsById[brandId]?.avatarUrl?.trim();
    if (brandAvatar != null && brandAvatar.isNotEmpty) return brandAvatar;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(creatorFeedControllerProvider);
    final heroImageUrl = _resolveHeroImageUrl(state.campaigns);
    final canRefresh = !state.isLoading;
    final hasCampaigns = state.campaigns.isNotEmpty;

    ref.listen<CreatorFeedState>(creatorFeedControllerProvider, (
      previous,
      next,
    ) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        _showSnack(next.errorMessage!);
        setState(() => _feedErrorMessage = next.errorMessage);
        ref.read(creatorFeedControllerProvider.notifier).clearError();
      }
      if (next.errorMessage == null &&
          !next.isLoading &&
          next.campaigns.isNotEmpty) {
        setState(() => _feedErrorMessage = null);
      }

      final oldCampaigns = previous?.campaigns ?? const <CampaignModel>[];
      if (_didCampaignListChange(oldCampaigns, next.campaigns)) {
        _loadBrandProfilesForCampaigns(next.campaigns);
      }
    });

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _DashboardHeroBackdrop(imageUrl: heroImageUrl),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const bottomNavClearance = 18.0;
                final preferredBlockHeight = (constraints.maxHeight * 0.58)
                    .clamp(280.0, 460.0)
                    .toDouble();
                final maxAllowedBlockHeight =
                    (constraints.maxHeight - bottomNavClearance - 88.0)
                        .clamp(220.0, 460.0)
                        .toDouble();
                final campaignsBlockHeight =
                    preferredBlockHeight > maxAllowedBlockHeight
                    ? maxAllowedBlockHeight
                    : preferredBlockHeight;

                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: SizedBox(
                      height: constraints.maxHeight,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Stack(
                          children: [
                            Positioned(
                              left: 0,
                              right: 0,
                              top: 18,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Row(
                                  children: [
                                    const Spacer(),
                                    _NotificationActionButton(
                                      tooltip: 'Aggiorna annunci',
                                      onPressed: canRefresh
                                          ? _refreshFeed
                                          : null,
                                      showBadge: false,
                                    ),
                                    const SizedBox(width: 10),
                                    _CreateCampaignActionButton(
                                      tooltip: 'Salta annuncio',
                                      onPressed: hasCampaigns
                                          ? () => _skipActiveCampaign(
                                              state.campaigns,
                                            )
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: bottomNavClearance,
                              child: SizedBox(
                                height: campaignsBlockHeight,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const Text(
                                      'Annunci consigliati per te oggi',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFF1E9FF),
                                        height: 1,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Expanded(
                                      child: _RecommendedCampaignsSection(
                                        campaigns: state.campaigns,
                                        brandsById: _brandsById,
                                        isLoading: state.isLoading,
                                        isLoadingBrands: _isLoadingBrands,
                                        errorMessage: _feedErrorMessage,
                                        isApplying: state.isApplying,
                                        applyingCampaignId:
                                            state.applyingCampaignId,
                                        onRetry: _refreshFeed,
                                        onApply: _apply,
                                        onPageChanged: (index) {
                                          if (_activeCampaignIndex == index) {
                                            return;
                                          }
                                          setState(
                                            () => _activeCampaignIndex = index,
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardHeroBackdrop extends StatelessWidget {
  const _DashboardHeroBackdrop({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final hasImage = (imageUrl ?? '').trim().isNotEmpty;

    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SizedBox(
              height: 430,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasImage)
                      Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (_, _, _) => const _HeroFallback(),
                      )
                    else
                      const _HeroFallback(),
                    if (hasImage)
                      ShaderMask(
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (rect) => LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black,
                            Colors.black.withValues(alpha: 0.92),
                            Colors.black.withValues(alpha: 0.38),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.30, 0.68, 0.98],
                        ).createShader(rect),
                        child: ImageFiltered(
                          imageFilter: ImageFilter.blur(
                            sigmaX: 10.0,
                            sigmaY: 10.0,
                          ),
                          child: Image.network(
                            imageUrl!,
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            filterQuality: FilterQuality.medium,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.1),
                            const Color(0xFF0D0916).withValues(alpha: 0.54),
                            const Color(0xFF05040A).withValues(alpha: 0.95),
                          ],
                          stops: const [0.0, 0.5, 0.76, 1.0],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroFallback extends StatelessWidget {
  const _HeroFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF251B33), Color(0xFF130E1E), Color(0xFF08070D)],
        ),
      ),
    );
  }
}

class _RecommendedCampaignsSection extends StatefulWidget {
  const _RecommendedCampaignsSection({
    required this.campaigns,
    required this.brandsById,
    required this.isLoading,
    required this.isLoadingBrands,
    required this.errorMessage,
    required this.isApplying,
    required this.applyingCampaignId,
    required this.onRetry,
    required this.onApply,
    required this.onPageChanged,
  });

  final List<CampaignModel> campaigns;
  final Map<String, _BrandLiteProfile> brandsById;
  final bool isLoading;
  final bool isLoadingBrands;
  final String? errorMessage;
  final bool isApplying;
  final String? applyingCampaignId;
  final Future<void> Function() onRetry;
  final Future<void> Function(CampaignModel campaign) onApply;
  final ValueChanged<int> onPageChanged;

  @override
  State<_RecommendedCampaignsSection> createState() =>
      _RecommendedCampaignsSectionState();
}

class _RecommendedCampaignsSectionState
    extends State<_RecommendedCampaignsSection> {
  late final PageController _pageController;
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1);
  }

  @override
  void didUpdateWidget(covariant _RecommendedCampaignsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final maxIndex = widget.campaigns.length - 1;
    if (maxIndex < 0) {
      if (_pageIndex != 0) {
        setState(() => _pageIndex = 0);
        widget.onPageChanged(0);
      }
      return;
    }
    if (_pageIndex > maxIndex) {
      setState(() => _pageIndex = maxIndex);
      widget.onPageChanged(maxIndex);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasCampaigns = widget.campaigns.isNotEmpty;
        final hasError = (widget.errorMessage ?? '').isNotEmpty;
        final showIndicators = hasCampaigns && !widget.isLoading && !hasError;
        final indicatorsHeight = showIndicators && widget.campaigns.length > 1
            ? 16.0
            : 0.0;
        final boundedHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : 378.0;
        final panelHeight = (boundedHeight - indicatorsHeight).clamp(
          250.0,
          378.0,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.isLoading && !hasCampaigns)
              SizedBox(
                height: panelHeight,
                child: const Center(child: SinapsyLogoLoader()),
              )
            else if (hasError && !hasCampaigns)
              SizedBox(
                height: panelHeight,
                child: _CampaignPanelFrame(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.errorMessage!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: widget.onRetry,
                          child: const Text('Riprova'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (!hasCampaigns)
              SizedBox(
                height: panelHeight,
                child: _CampaignPanelFrame(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Nessun annuncio attivo al momento.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
              )
            else ...[
              SizedBox(
                height: panelHeight,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: widget.campaigns.length,
                  onPageChanged: (index) {
                    setState(() => _pageIndex = index);
                    widget.onPageChanged(index);
                  },
                  itemBuilder: (context, index) {
                    final campaign = widget.campaigns[index];
                    final brandId = campaign.brandId?.trim() ?? '';
                    final brand = widget.brandsById[brandId];
                    return _CampaignRecommendationCard(
                      campaign: campaign,
                      brand: brand,
                      isLoadingBrand:
                          widget.isLoadingBrands &&
                          brandId.isNotEmpty &&
                          brand == null,
                      isApplying:
                          widget.isApplying &&
                          widget.applyingCampaignId == campaign.id,
                      onApply: () {
                        widget.onApply(campaign);
                      },
                    );
                  },
                ),
              ),
              if (widget.campaigns.length > 1) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List<Widget>.generate(widget.campaigns.length, (
                    index,
                  ) {
                    final active = index == _pageIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 170),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: active ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(99),
                        color: active
                            ? const Color(0xFFB468FF)
                            : const Color(0xFF6A5E8F).withValues(alpha: 0.7),
                      ),
                    );
                  }),
                ),
              ],
            ],
          ],
        );
      },
    );
  }
}

class _CampaignPanelFrame extends StatelessWidget {
  const _CampaignPanelFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF6E39D7).withValues(alpha: 0.7),
        ),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B0F35), Color(0xFF140B27)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9B4EFF).withValues(alpha: 0.12),
            blurRadius: 30,
            spreadRadius: -8,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 14,
            spreadRadius: -6,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CampaignRecommendationCard extends StatelessWidget {
  const _CampaignRecommendationCard({
    required this.campaign,
    required this.brand,
    required this.isLoadingBrand,
    required this.isApplying,
    required this.onApply,
  });

  final CampaignModel campaign;
  final _BrandLiteProfile? brand;
  final bool isLoadingBrand;
  final bool isApplying;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final productImageUrl = _resolveProductImageUrl(campaign);
    final brandName = (brand?.displayName.trim().isNotEmpty ?? false)
        ? brand!.displayName.trim()
        : 'Brand';
    final followersRequirement = campaign.minFollowers != null
        ? '${_formatNumberWithCommas(campaign.minFollowers!)} follower min'
        : 'Follower min non richiesti';
    final locationLabel = (campaign.locationRequired ?? '').trim().isNotEmpty
        ? campaign.locationRequired!.trim()
        : 'Location libera';

    return Material(
      color: Colors.transparent,
      child: _CampaignPanelFrame(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _BrandAvatar(brand: brand, isLoading: isLoadingBrand),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          campaign.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFEDE4FF),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          brandName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFCEC1EE),
                          ),
                        ),
                        const SizedBox(height: 5),
                        _CampaignCategoryChip(label: 'brand'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _CampaignApplyButton(isApplying: isApplying, onTap: onApply),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 14,
                runSpacing: 8,
                children: [
                  _CampaignStatChip(
                    icon: Icons.euro_rounded,
                    label: campaign.budgetLabel,
                  ),
                  _CampaignStatChip(
                    icon: Icons.group_outlined,
                    label:
                        '${_formatNumberWithCommas(campaign.applicantsCount)} candidature',
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '$followersRequirement | $locationLabel',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFBEB2DD),
                ),
              ),
              const SizedBox(height: 10),
              Divider(
                color: const Color(0xFF8E47F7).withValues(alpha: 0.45),
                height: 1,
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF2C1F46), Color(0xFF1B142C)],
                      ),
                    ),
                    child: productImageUrl == null
                        ? const Center(
                            child: Icon(
                              Icons.image_outlined,
                              size: 28,
                              color: Color(0xB3D4C6F6),
                            ),
                          )
                        : Image.network(
                            productImageUrl,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.low,
                            errorBuilder: (_, _, _) => const Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                size: 28,
                                color: Color(0xB3D4C6F6),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String? _resolveProductImageUrl(CampaignModel campaign) {
    final cover = (campaign.coverImageUrl ?? '').trim();
    if (cover.isNotEmpty) return cover;
    return null;
  }

  static String _formatNumberWithCommas(int value) {
    final raw = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      final reverseIndex = raw.length - i;
      buffer.write(raw[i]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write(',');
      }
    }
    return buffer.toString();
  }
}

class _BrandAvatar extends StatelessWidget {
  const _BrandAvatar({required this.brand, required this.isLoading});

  final _BrandLiteProfile? brand;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return CircleAvatar(
        radius: 28,
        backgroundColor: AppTheme.colorBgElevated,
        child: const SinapsyLogoLoader(size: 18),
      );
    }

    final imageUrl = (brand?.avatarUrl ?? '').trim();
    final displayName = (brand?.displayName ?? '').trim();

    return CircleAvatar(
      radius: 28,
      backgroundColor: AppTheme.colorBgElevated,
      backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
      child: imageUrl.isNotEmpty
          ? null
          : Text(
              displayName.isEmpty ? '?' : displayName[0].toUpperCase(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
    );
  }
}

class _CampaignCategoryChip extends StatelessWidget {
  const _CampaignCategoryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final normalized =
        label.trim().isEmpty || label.trim().toLowerCase() == 'general'
        ? 'Annuncio'
        : label.trim();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFAA63FF).withValues(alpha: 0.22),
            const Color(0xFF6D30DA).withValues(alpha: 0.14),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFB97BFF).withValues(alpha: 0.6),
        ),
      ),
      child: Text(
        normalized,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFFE7D7FF),
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

class _CampaignApplyButton extends StatelessWidget {
  const _CampaignApplyButton({required this.isApplying, required this.onTap});

  final bool isApplying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Candidati',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isApplying ? null : onTap,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.32),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppTheme.colorStrokeMedium.withValues(alpha: 0.9),
              ),
            ),
            child: isApplying
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: Center(child: SinapsyLogoLoader(size: 14)),
                  )
                : const Icon(
                    Icons.send_rounded,
                    size: 19,
                    color: AppTheme.colorTextPrimary,
                  ),
          ),
        ),
      ),
    );
  }
}

class _CampaignStatChip extends StatelessWidget {
  const _CampaignStatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFFB97BFF)),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFFD8CBF8),
          ),
        ),
      ],
    );
  }
}

class _NotificationActionButton extends StatelessWidget {
  const _NotificationActionButton({
    required this.tooltip,
    this.onPressed,
    this.showBadge = false,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: enabled
                  ? [const Color(0xFF1B1B2B), const Color(0xFF0E1020)]
                  : [
                      const Color(0xFF1B1B2B).withValues(alpha: 0.42),
                      const Color(0xFF0E1020).withValues(alpha: 0.4),
                    ],
            ),
            border: Border.all(
              color: const Color(
                0x6A625A84,
              ).withValues(alpha: enabled ? 1 : 0.35),
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: const Color(0xFF8B4CFF).withValues(alpha: 0.18),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.26),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.notifications_none_rounded,
                size: 21,
                color: const Color(
                  0xFFF7F4FF,
                ).withValues(alpha: enabled ? 0.95 : 0.46),
              ),
              if (showBadge)
                Positioned(
                  right: 7,
                  top: 6,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(
                        0xFFFF4D6D,
                      ).withValues(alpha: enabled ? 1 : 0.5),
                      border: Border.all(
                        color: const Color(0xFF151626),
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateCampaignActionButton extends StatelessWidget {
  const _CreateCampaignActionButton({required this.tooltip, this.onPressed});

  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isEnabled
                  ? const [Color(0xFFB26BFF), Color(0xFF7D47F1)]
                  : [
                      const Color(0xFFB26BFF).withValues(alpha: 0.4),
                      const Color(0xFF7D47F1).withValues(alpha: 0.4),
                    ],
            ),
            border: Border.all(
              color: const Color(
                0xFFE4D4FF,
              ).withValues(alpha: isEnabled ? 0.24 : 0.12),
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.add_rounded,
            size: 24,
            color: const Color(
              0xFFF9F6FF,
            ).withValues(alpha: isEnabled ? 0.98 : 0.6),
          ),
        ),
      ),
    );
  }
}

class _BrandLiteProfile {
  const _BrandLiteProfile({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
  });

  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;

  factory _BrandLiteProfile.fromMap(Map<String, dynamic> map) {
    final username = (map['username'] ?? '').toString().trim();
    final firstName = (map['first_name'] ?? map['firstName'] ?? '')
        .toString()
        .trim();
    final lastName = (map['last_name'] ?? map['lastName'] ?? '')
        .toString()
        .trim();
    final fullName = [
      firstName,
      lastName,
    ].where((part) => part.isNotEmpty).join(' ').trim();
    final avatar = _nullableString(map['avatar_url'] ?? map['avatarUrl']);

    return _BrandLiteProfile(
      id: (map['id'] ?? map['user_id'] ?? '').toString().trim(),
      username: username,
      displayName: fullName.isNotEmpty
          ? fullName
          : (username.isNotEmpty ? username : 'Brand'),
      avatarUrl: avatar,
    );
  }

  static String? _nullableString(dynamic raw) {
    final value = (raw ?? '').toString().trim();
    if (value.isEmpty) return null;
    return value;
  }
}
