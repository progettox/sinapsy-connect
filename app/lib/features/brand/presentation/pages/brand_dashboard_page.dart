import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/luxury_neon_backdrop.dart';
import '../../../../core/widgets/sinapsy_logo_loader.dart';
import '../../data/brand_creator_feed_repository.dart';
import '../pages/brand_notifications_page.dart';
import '../../../campaigns/presentation/controllers/create_campaign_controller.dart';
import '../../../campaigns/presentation/pages/create_campaign_page.dart';

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
    final canCreateCampaign = !state.isLoading && !state.isRemoving;

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
            child: LayoutBuilder(
              builder: (context, constraints) {
                return RefreshIndicator(
                  onRefresh: () => ref
                      .read(brandCampaignsControllerProvider.notifier)
                      .loadMyCampaigns()
                      .then((_) => _loadRecommendedCreators()),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(14, 34, 14, 16),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight - 30,
                          ),
                          child: IntrinsicHeight(
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
                                      onPressed: canCreateCampaign
                                          ? _openCreateCampaign
                                          : null,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                if (state.isLoading && state.campaigns.isEmpty)
                                  const Expanded(
                                    child: Center(child: SinapsyLogoLoader()),
                                  )
                                else ...[
                                  const Spacer(),
                                  _RecommendedCreatorsSection(
                                    creators: _recommendedCreators,
                                    isLoading: _isLoadingCreators,
                                    errorMessage: _creatorsError,
                                    savingCreatorIds: _savingCreatorIds,
                                    onRetry: _loadRecommendedCreators,
                                    onToggleSaved: _toggleSavedCreator,
                                  ),
                                  const SizedBox(height: 92),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: _PrimaryCreateCampaignButton(
                    enabled: canCreateCampaign,
                    onPressed: _openCreateCampaign,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryCreateCampaignButton extends StatelessWidget {
  const _PrimaryCreateCampaignButton({
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: enabled
                ? [
                    const Color(0xFFAA63FF).withValues(alpha: 0.26),
                    const Color(0xFF6D30DA).withValues(alpha: 0.16),
                  ]
                : [
                    const Color(0xFFAA63FF).withValues(alpha: 0.12),
                    const Color(0xFF6D30DA).withValues(alpha: 0.08),
                  ],
          ),
          border: Border.all(
            color: const Color(
              0xFFB97BFF,
            ).withValues(alpha: enabled ? 0.62 : 0.28),
          ),
        ),
        child: ElevatedButton.icon(
          onPressed: enabled ? onPressed : null,
          icon: const Icon(Icons.add_rounded, size: 19),
          label: const Text(
            'Nuova Campagna',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              fontSize: 15,
            ),
          ),
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: const Color(0xFFE7D7FF),
            disabledForegroundColor: const Color(
              0xFFE7D7FF,
            ).withValues(alpha: 0.55),
            disabledBackgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
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
    _pageController = PageController(viewportFraction: 1);
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
          const SizedBox(height: 360, child: Center(child: SinapsyLogoLoader()))
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
            height: 378,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.creators.length,
              onPageChanged: (index) => setState(() => _pageIndex = index),
              itemBuilder: (context, index) {
                final creator = widget.creators[index];
                return _CreatorRecommendationCard(
                  creator: creator,
                  isSaving: widget.savingCreatorIds.contains(creator.id),
                  onToggleSaved: () {
                    widget.onToggleSaved(creator);
                  },
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        creator.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFEDE4FF),
                        ),
                      ),
                      const SizedBox(height: 4),
                      _CreatorCategoryChip(label: creator.category),
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

class _CreatorCategoryChip extends StatelessWidget {
  const _CreatorCategoryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final normalized =
        label.trim().isEmpty || label.trim().toLowerCase() == 'creator'
        ? 'Creator'
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
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
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
                size: 23,
                color: const Color(
                  0xFFF7F4FF,
                ).withValues(alpha: enabled ? 0.95 : 0.46),
              ),
              Positioned(
                right: 9.5,
                top: 8.5,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(
                      0xFFAF63FF,
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
          width: 46,
          height: 46,
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
            size: 23,
            color: const Color(
              0xFFF9F6FF,
            ).withValues(alpha: isEnabled ? 0.98 : 0.6),
          ),
        ),
      ),
    );
  }
}
