import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/luxury_neon_backdrop.dart';
import '../../../../core/widgets/sinapsy_logo_loader.dart';
import '../../data/brand_creator_feed_repository.dart';
import '../../../campaigns/presentation/pages/brand_home_page.dart';
import '../pages/brand_notifications_page.dart';
import '../../../campaigns/presentation/controllers/create_campaign_controller.dart';
import '../../../campaigns/presentation/pages/create_campaign_page.dart';
import 'brand_candidatures_page.dart';

class BrandDashboardPage extends ConsumerStatefulWidget {
  const BrandDashboardPage({super.key});

  @override
  ConsumerState<BrandDashboardPage> createState() => _BrandDashboardPageState();
}

class _BrandDashboardPageState extends ConsumerState<BrandDashboardPage> {
  List<CreatorFeedCard> _recommendedCreators = const <CreatorFeedCard>[];
  final Set<String> _savingCreatorIds = <String>{};
  bool _isLoadingCreators = true;
  String? _creatorsError;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      await Future.wait<void>([
        ref.read(brandCampaignsControllerProvider.notifier).loadMyCampaigns(),
        _loadRecommendedCreators(),
      ]);
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openCreateCampaign() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const CreateCampaignPage()),
    );
    if (!mounted || created != true) return;
    await ref.read(brandCampaignsControllerProvider.notifier).loadMyCampaigns();
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const BrandNotificationsPage()),
    );
  }

  Future<void> _openActiveCampaigns() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const ActiveCampaignsPage()),
    );
  }

  Future<void> _openCandidatureRequests() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const BrandCandidaturesPage()),
    );
  }

  Future<void> _loadRecommendedCreators() async {
    if (!mounted) return;
    setState(() {
      _isLoadingCreators = true;
      _creatorsError = null;
    });

    try {
      final creators = await ref
          .read(brandCreatorFeedRepositoryProvider)
          .listCreatorCards(role: 'creator', limit: 200);
      if (!mounted) return;
      setState(() {
        _recommendedCreators = creators;
        _isLoadingCreators = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _recommendedCreators = const <CreatorFeedCard>[];
        _isLoadingCreators = false;
        _creatorsError = 'Errore caricamento creator consigliati: $error';
      });
    }
  }

  Future<void> _toggleSavedCreator(CreatorFeedCard creator) async {
    if (_savingCreatorIds.contains(creator.id)) return;
    final nextIsFollowing = !creator.isFollowing;

    setState(() {
      _savingCreatorIds.add(creator.id);
      _recommendedCreators = _recommendedCreators
          .map(
            (item) => item.id == creator.id
                ? item.copyWith(
                    isSaved: nextIsFollowing,
                    followersCount: _nextFollowerCount(
                      currentCount: item.followersCount,
                      wasFollowing: creator.isFollowing,
                      nextIsFollowing: nextIsFollowing,
                    ),
                  )
                : item,
          )
          .toList(growable: false);
    });

    try {
      await ref
          .read(brandCreatorFeedRepositoryProvider)
          .setFollowing(creatorId: creator.id, isFollowing: nextIsFollowing);
      await _syncCreatorFollowCounters(creator.id);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _recommendedCreators = _recommendedCreators
            .map(
              (item) => item.id == creator.id
                  ? item.copyWith(
                      isSaved: creator.isFollowing,
                      followersCount: creator.followersCount,
                      followingCount: creator.followingCount,
                    )
                  : item,
            )
            .toList(growable: false);
      });
      _showSnack('Impossibile aggiornare follow: $error');
    } finally {
      if (mounted) {
        setState(() => _savingCreatorIds.remove(creator.id));
      }
    }
  }

  Future<void> _syncCreatorFollowCounters(String creatorId) async {
    try {
      final counters = await ref
          .read(brandCreatorFeedRepositoryProvider)
          .getFollowCounters(creatorId: creatorId);
      if (!mounted) return;
      setState(() {
        _recommendedCreators = _recommendedCreators
            .map(
              (item) => item.id == creatorId
                  ? item.copyWith(
                      isSaved: counters.isFollowing,
                      followersCount: counters.followersCount,
                      followingCount: counters.followingCount,
                    )
                  : item,
            )
            .toList(growable: false);
      });
    } catch (_) {
      // Ignore follow count refresh failures to keep follow action responsive.
    }
  }

  int _nextFollowerCount({
    required int? currentCount,
    required bool wasFollowing,
    required bool nextIsFollowing,
  }) {
    final safeCurrent = currentCount ?? 0;
    if (!wasFollowing && nextIsFollowing) return safeCurrent + 1;
    if (wasFollowing && !nextIsFollowing) {
      return safeCurrent > 0 ? safeCurrent - 1 : 0;
    }
    return safeCurrent;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(brandCampaignsControllerProvider);
    final activeCampaigns = state.campaigns
        .where((campaign) => campaign.status.toLowerCase() == 'active')
        .length;
    final candidatureCount = state.campaigns.fold<int>(
      0,
      (total, campaign) => total + campaign.applicantsCount,
    );

    ref.listen<BrandCampaignsState>(brandCampaignsControllerProvider, (
      previous,
      next,
    ) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        _showSnack(next.errorMessage!);
        ref.read(brandCampaignsControllerProvider.notifier).clearError();
      }
    });

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const LuxuryNeonBackdrop(),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () => ref
                  .read(brandCampaignsControllerProvider.notifier)
                  .loadMyCampaigns()
                  .then((_) => _loadRecommendedCreators()),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 18, 14, 22),
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Spacer(),
                              _NotificationActionButton(
                                onPressed: _openNotifications,
                              ),
                              const SizedBox(width: 10),
                              _CreateCampaignActionButton(
                                tooltip: 'Nuova campagna',
                                onPressed: !state.isLoading && !state.isRemoving
                                    ? _openCreateCampaign
                                    : null,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (state.isLoading && state.campaigns.isEmpty) ...[
                            const SizedBox(height: 60),
                            const Center(child: SinapsyLogoLoader()),
                            const SizedBox(height: 60),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: _DashboardStatCard(
                                    title: 'Campagne\nAttive',
                                    value: '$activeCampaigns',
                                    icon: Icons.show_chart_rounded,
                                    iconColor: const Color(0xFF3AF8CA),
                                    onTap: _openActiveCampaigns,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _DashboardStatCard(
                                    title: 'Candidature',
                                    value: '$candidatureCount',
                                    icon: Icons.groups_2_outlined,
                                    iconColor: const Color(0xFF56E7FF),
                                    onTap: _openCandidatureRequests,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              height: 54,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: const LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      Color(0xFF8E47F7),
                                      Color(0xFFB15CFF),
                                    ],
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x6D8E47F7),
                                      blurRadius: 18,
                                      offset: Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton.icon(
                                  onPressed: state.isLoading
                                      ? null
                                      : _openCreateCampaign,
                                  icon: const Icon(Icons.add_rounded, size: 20),
                                  label: const Text(
                                    'Nuova Campagna',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    elevation: 0,
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    disabledForegroundColor: Colors.white70,
                                    disabledBackgroundColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            _RecommendedCreatorsSection(
                              creators: _recommendedCreators,
                              isLoading: _isLoadingCreators,
                              errorMessage: _creatorsError,
                              savingCreatorIds: _savingCreatorIds,
                              onRetry: _loadRecommendedCreators,
                              onToggleSaved: _toggleSavedCreator,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardStatCard extends StatelessWidget {
  const _DashboardStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(16);
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.1,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFD4E2FF),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1,
            ),
          ),
        ],
      ),
    );

    return SizedBox(
      height: 94,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border.all(
              color: AppTheme.colorStrokeSubtle.withValues(alpha: 0.9),
            ),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF161C2B), Color(0xFF101420)],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x70040A14),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: borderRadius,
            onTap: onTap,
            child: content,
          ),
        ),
      ),
    );
  }
}

class _RecommendedCreatorsSection extends StatefulWidget {
  const _RecommendedCreatorsSection({
    required this.creators,
    required this.isLoading,
    required this.errorMessage,
    required this.savingCreatorIds,
    required this.onRetry,
    required this.onToggleSaved,
  });

  final List<CreatorFeedCard> creators;
  final bool isLoading;
  final String? errorMessage;
  final Set<String> savingCreatorIds;
  final Future<void> Function() onRetry;
  final Future<void> Function(CreatorFeedCard creator) onToggleSaved;

  @override
  State<_RecommendedCreatorsSection> createState() =>
      _RecommendedCreatorsSectionState();
}

class _RecommendedCreatorsSectionState
    extends State<_RecommendedCreatorsSection> {
  late final PageController _pageController;
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.965);
  }

  @override
  void didUpdateWidget(covariant _RecommendedCreatorsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final maxIndex = widget.creators.length - 1;
    if (maxIndex < 0) {
      if (_pageIndex != 0) setState(() => _pageIndex = 0);
      return;
    }
    if (_pageIndex > maxIndex) {
      setState(() => _pageIndex = maxIndex);
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Creator consigliati per te oggi',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.96),
          ),
        ),
        const SizedBox(height: 10),
        if (widget.isLoading)
          const SizedBox(height: 320, child: Center(child: SinapsyLogoLoader()))
        else if ((widget.errorMessage ?? '').isNotEmpty)
          _CreatorPanelFrame(
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
          )
        else if (widget.creators.isEmpty)
          _CreatorPanelFrame(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Nessun creator disponibile al momento.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          )
        else ...[
          SizedBox(
            height: 340,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.creators.length,
              onPageChanged: (index) => setState(() => _pageIndex = index),
              itemBuilder: (context, index) {
                final creator = widget.creators[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _CreatorRecommendationCard(
                    creator: creator,
                    isSaving: widget.savingCreatorIds.contains(creator.id),
                    onToggleSaved: () {
                      widget.onToggleSaved(creator);
                    },
                  ),
                );
              },
            ),
          ),
          if (widget.creators.length > 1) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(widget.creators.length, (index) {
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
  }
}

class _CreatorPanelFrame extends StatelessWidget {
  const _CreatorPanelFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF6C31D6).withValues(alpha: 0.9),
        ),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A0933), Color(0xFF120621)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x73370E86),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CreatorRecommendationCard extends StatelessWidget {
  const _CreatorRecommendationCard({
    required this.creator,
    required this.isSaving,
    required this.onToggleSaved,
  });

  final CreatorFeedCard creator;
  final bool isSaving;
  final VoidCallback onToggleSaved;

  @override
  Widget build(BuildContext context) {
    final mediaUrls = _collectMediaUrls(creator);
    final followers = creator.followersCount ?? 0;
    final following = creator.followingCount ?? 0;
    final completedWorks =
        creator.completedWorksCount ??
        creator.portfolioThumbUrls.length +
            (creator.heroImageUrl?.isNotEmpty == true ? 1 : 0);

    return _CreatorPanelFrame(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.colorBgElevated,
                  backgroundImage: (creator.avatarUrl ?? '').isNotEmpty
                      ? NetworkImage(creator.avatarUrl!)
                      : null,
                  child: (creator.avatarUrl ?? '').isNotEmpty
                      ? null
                      : Text(
                          creator.displayName.isEmpty
                              ? '?'
                              : creator.displayName[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          creator.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFEDE4FF),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.verified_rounded,
                        size: 18,
                        color: Color(0xFF31D89D),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _CreatorFavoriteButton(
                  isFollowing: creator.isFollowing,
                  isSaving: isSaving,
                  onTap: onToggleSaved,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              runSpacing: 8,
              children: [
                _CreatorStatChip(
                  icon: Icons.person_outline_rounded,
                  label: '${_formatCompactNumber(followers)} follower',
                ),
                _CreatorStatChip(
                  icon: Icons.group_outlined,
                  label: 'segue ${_formatCompactNumber(following)}',
                ),
                _CreatorStatChip(
                  icon: Icons.work_outline_rounded,
                  label: '$completedWorks lavori completati',
                ),
              ],
            ),
            const SizedBox(height: 10),
            Divider(
              color: const Color(0xFF8E47F7).withValues(alpha: 0.45),
              height: 1,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 6,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  childAspectRatio: 1.12,
                ),
                itemBuilder: (context, index) {
                  final url = index < mediaUrls.length
                      ? mediaUrls[index]
                      : null;
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF2C1F46), Color(0xFF1B142C)],
                        ),
                      ),
                      child: url == null
                          ? const Icon(
                              Icons.image_outlined,
                              size: 18,
                              color: Color(0xB3D4C6F6),
                            )
                          : Image.network(
                              url,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.low,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.broken_image_outlined,
                                size: 18,
                                color: Color(0xB3D4C6F6),
                              ),
                            ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static List<String> _collectMediaUrls(CreatorFeedCard creator) {
    final urls = <String>[
      if ((creator.heroImageUrl ?? '').isNotEmpty) creator.heroImageUrl!,
      ...creator.portfolioThumbUrls.where((url) => url.trim().isNotEmpty),
      if ((creator.avatarUrl ?? '').isNotEmpty) creator.avatarUrl!,
    ];
    final unique = <String>{};
    final output = <String>[];
    for (final url in urls) {
      final clean = url.trim();
      if (clean.isEmpty || unique.contains(clean)) continue;
      unique.add(clean);
      output.add(clean);
      if (output.length == 6) break;
    }
    return output;
  }

  static String _formatCompactNumber(int value) {
    if (value <= 0) return '0';
    if (value >= 1000000) {
      final v = value / 1000000;
      return '${v.toStringAsFixed(v >= 10 ? 0 : 1)}M'.replaceAll('.0M', 'M');
    }
    if (value >= 1000) {
      final v = value / 1000;
      return '${v.toStringAsFixed(v >= 10 ? 0 : 1)}k'.replaceAll('.0k', 'k');
    }
    return '$value';
  }
}

class _CreatorFavoriteButton extends StatelessWidget {
  const _CreatorFavoriteButton({
    required this.isFollowing,
    required this.isSaving,
    required this.onTap,
  });

  final bool isFollowing;
  final bool isSaving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isSaving ? null : onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          width: 100,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF6D2BDA).withValues(alpha: 0.95),
                const Color(0xFF9B4EFF).withValues(alpha: 0.9),
              ],
            ),
            border: Border.all(
              color: const Color(0xFFC89EFF).withValues(alpha: 0.55),
            ),
          ),
          child: isSaving
              ? const Padding(
                  padding: EdgeInsets.all(8),
                  child: Center(child: SinapsyLogoLoader(size: 14)),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isFollowing
                          ? Icons.person_remove_alt_1_rounded
                          : Icons.person_add_alt_1_rounded,
                      size: 18,
                      color: const Color(0xFFEBD9FF),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isFollowing ? 'Seguito' : 'Segui',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFEBD9FF),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _CreatorStatChip extends StatelessWidget {
  const _CreatorStatChip({required this.icon, required this.label});

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
  const _NotificationActionButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Tooltip(
      message: 'Centro notifiche',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            width: 34,
            height: 34,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.notifications_none_rounded,
                  size: 21,
                  color: Colors.white.withValues(alpha: enabled ? 0.92 : 0.45),
                ),
                Positioned(
                  right: 6.5,
                  top: 6.0,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(
                        0xFFB35AFF,
                      ).withValues(alpha: enabled ? 1 : 0.5),
                      border: Border.all(color: const Color(0xFF090A12)),
                    ),
                  ),
                ),
              ],
            ),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isEnabled
                    ? const [Color(0xFFAA63FF), Color(0xFF934DFF)]
                    : [
                        const Color(0xFFAA63FF).withValues(alpha: 0.4),
                        const Color(0xFF934DFF).withValues(alpha: 0.4),
                      ],
              ),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: const Color(
                  0xFFCBA3FF,
                ).withValues(alpha: isEnabled ? 0.5 : 0.2),
              ),
              boxShadow: isEnabled
                  ? [
                      BoxShadow(
                        color: const Color(0xFF9B4EFF).withValues(alpha: 0.34),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              Icons.add_rounded,
              size: 20,
              color: Colors.white.withValues(alpha: isEnabled ? 0.98 : 0.6),
            ),
          ),
        ),
      ),
    );
  }
}
