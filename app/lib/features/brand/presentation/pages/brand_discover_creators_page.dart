import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/luxury_neon_backdrop.dart';
import '../../../../core/widgets/sinapsy_logo_loader.dart';
import '../../data/brand_creator_feed_repository.dart';

enum _DiscoverRoleFilter { all, creator, brand, saved }

class BrandDiscoverCreatorsPage extends ConsumerStatefulWidget {
  const BrandDiscoverCreatorsPage({super.key});

  @override
  ConsumerState<BrandDiscoverCreatorsPage> createState() =>
      _BrandDiscoverCreatorsPageState();
}

class _BrandDiscoverCreatorsPageState
    extends ConsumerState<BrandDiscoverCreatorsPage> {
  final _queryController = TextEditingController();

  List<CreatorFeedCard> _cards = const <CreatorFeedCard>[];
  bool _isLoading = true;
  String? _errorMessage;
  _DiscoverRoleFilter _selectedRole = _DiscoverRoleFilter.creator;
  final Set<String> _savingIds = <String>{};

  @override
  void initState() {
    super.initState();
    _queryController.addListener(() => setState(() {}));
    Future<void>.microtask(_loadCreators);
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadCreators() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(brandCreatorFeedRepositoryProvider);
      final roleFilter = switch (_selectedRole) {
        _DiscoverRoleFilter.all => null,
        _DiscoverRoleFilter.creator => 'creator',
        _DiscoverRoleFilter.brand => 'brand',
        _DiscoverRoleFilter.saved => null,
      };

      final cards = await repo.listCreatorCards(role: roleFilter, limit: 80);
      if (!mounted) return;

      setState(() {
        _cards = cards;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _cards = const <CreatorFeedCard>[];
        _isLoading = false;
        _errorMessage = 'Errore caricamento creator: $error';
      });
    }
  }

  Future<void> _toggleSaved(CreatorFeedCard card) async {
    if (_savingIds.contains(card.id)) return;

    final nextSaved = !card.isSaved;
    setState(() {
      _savingIds.add(card.id);
      _cards = _cards
          .map(
            (item) => item.id == card.id
                ? item.copyWith(
                    isSaved: nextSaved,
                    followersCount: _nextFollowerCount(
                      currentCount: item.followersCount,
                      wasFollowing: card.isSaved,
                      nextIsFollowing: nextSaved,
                    ),
                  )
                : item,
          )
          .toList(growable: false);
    });

    try {
      final repo = ref.read(brandCreatorFeedRepositoryProvider);
      await repo.setFollowing(creatorId: card.id, isFollowing: nextSaved);
      await _syncCardFollowCounters(card.id);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _cards = _cards
            .map(
              (item) => item.id == card.id
                  ? item.copyWith(
                      isSaved: card.isSaved,
                      followersCount: card.followersCount,
                      followingCount: card.followingCount,
                    )
                  : item,
            )
            .toList(growable: false);
      });
      _showSnack('Impossibile aggiornare follow: $error');
    } finally {
      if (mounted) {
        setState(() => _savingIds.remove(card.id));
      }
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

  Future<void> _syncCardFollowCounters(String creatorId) async {
    try {
      final counters = await ref
          .read(brandCreatorFeedRepositoryProvider)
          .getFollowCounters(creatorId: creatorId);
      if (!mounted) return;
      setState(() {
        _cards = _cards
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
      // Keep optimistic UI if a follow stats refresh fails.
    }
  }

  List<CreatorFeedCard> get _filteredCards {
    final baseCards = _selectedRole == _DiscoverRoleFilter.saved
        ? _cards.where((card) => card.isSaved).toList(growable: false)
        : _cards;

    final query = _queryController.text.trim().toLowerCase();
    if (query.isEmpty) return baseCards;

    return baseCards
        .where((card) {
          return card.username.toLowerCase().contains(query) ||
              card.displayName.toLowerCase().contains(query) ||
              card.location.toLowerCase().contains(query) ||
              card.category.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: RepaintBoundary(child: LuxuryNeonBackdrop()),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 6),
                  _AdaptiveGlass(
                    borderRadius: BorderRadius.circular(24),
                    sigma: 8,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.colorBgSecondary.withValues(alpha: 0.95),
                            AppTheme.colorBgCard.withValues(alpha: 0.92),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppTheme.colorStrokeSubtle.withValues(
                            alpha: 0.92,
                          ),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x48000000),
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _RoleChip(
                                  label: 'Creator',
                                  selected:
                                      _selectedRole ==
                                      _DiscoverRoleFilter.creator,
                                  onTap: () {
                                    if (_selectedRole ==
                                        _DiscoverRoleFilter.creator) {
                                      return;
                                    }
                                    setState(() {
                                      _selectedRole =
                                          _DiscoverRoleFilter.creator;
                                    });
                                    _loadCreators();
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _RoleChip(
                                  label: 'Brand',
                                  selected:
                                      _selectedRole ==
                                      _DiscoverRoleFilter.brand,
                                  onTap: () {
                                    if (_selectedRole ==
                                        _DiscoverRoleFilter.brand) {
                                      return;
                                    }
                                    setState(() {
                                      _selectedRole = _DiscoverRoleFilter.brand;
                                    });
                                    _loadCreators();
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _RoleChip(
                                  label: 'Tutti',
                                  selected:
                                      _selectedRole == _DiscoverRoleFilter.all,
                                  onTap: () {
                                    if (_selectedRole ==
                                        _DiscoverRoleFilter.all) {
                                      return;
                                    }
                                    setState(() {
                                      _selectedRole = _DiscoverRoleFilter.all;
                                    });
                                    _loadCreators();
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _RoleChip(
                                  label: 'Seguiti',
                                  selected:
                                      _selectedRole ==
                                      _DiscoverRoleFilter.saved,
                                  onTap: () {
                                    if (_selectedRole ==
                                        _DiscoverRoleFilter.saved) {
                                      return;
                                    }
                                    setState(() {
                                      _selectedRole = _DiscoverRoleFilter.saved;
                                    });
                                    _loadCreators();
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _queryController,
                            decoration: InputDecoration(
                              isDense: true,
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: AppTheme.colorTextSecondary,
                              ),
                              hintText: 'Filtro manuale username/localita',
                              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                                color: AppTheme.colorTextSecondary,
                              ),
                              filled: true,
                              fillColor: AppTheme.colorBgPrimary,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: AppTheme.colorStrokeSubtle.withValues(
                                    alpha: 0.95,
                                  ),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: AppTheme.colorStrokeSubtle.withValues(
                                    alpha: 0.95,
                                  ),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: AppTheme.colorAccentPrimary.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        if (_isLoading) {
                          return const Center(child: SinapsyLogoLoader());
                        }

                        if (_errorMessage != null) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _errorMessage!,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 10),
                                  OutlinedButton(
                                    onPressed: _loadCreators,
                                    child: const Text('Riprova'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final cards = _filteredCards;
                        if (cards.isEmpty) {
                          return const Center(
                            child: Text(
                              'Nessun risultato con i filtri correnti.',
                            ),
                          );
                        }

                        return ListView.separated(
                          cacheExtent: 320,
                          padding: const EdgeInsets.only(top: 16, bottom: 110),
                          itemCount: cards.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 18),
                          itemBuilder: (context, index) {
                            final card = cards[index];
                            final duration = 220 + (index * 22).clamp(0, 220);
                            return TweenAnimationBuilder<double>(
                              duration: Duration(milliseconds: duration),
                              curve: Curves.easeOutCubic,
                              tween: Tween<double>(begin: 0, end: 1),
                              builder: (context, value, child) {
                                return Opacity(
                                  opacity: value,
                                  child: Transform.translate(
                                    offset: Offset(0, (1 - value) * 16),
                                    child: child,
                                  ),
                                );
                              },
                              child: RepaintBoundary(
                                child: _CreatorFeedCardTile(
                                  card: card,
                                  isSaving: _savingIds.contains(card.id),
                                  onToggleSaved: () => _toggleSaved(card),
                                ),
                              ),
                            );
                          },
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
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: selected
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.colorAccentPrimary.withValues(alpha: 0.32),
                  AppTheme.colorAccentSecondary.withValues(alpha: 0.24),
                ],
              )
            : null,
        color: selected
            ? null
            : AppTheme.colorBgElevated.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected
              ? AppTheme.colorAccentPrimary.withValues(alpha: 0.65)
              : AppTheme.colorStrokeSubtle.withValues(alpha: 0.95),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: selected
                  ? AppTheme.colorTextPrimary
                  : AppTheme.colorTextSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _CreatorFeedCardTile extends StatelessWidget {
  const _CreatorFeedCardTile({
    required this.card,
    required this.isSaving,
    required this.onToggleSaved,
  });

  final CreatorFeedCard card;
  final bool isSaving;
  final VoidCallback onToggleSaved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = card.location.trim().isEmpty
        ? 'Localita non indicata'
        : card.location.trim();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.colorBgCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.colorStrokeSubtle.withValues(alpha: 0.92),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x59000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _HeroImage(imageUrl: card.heroImageUrl),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00000000), Color(0xB3000000)],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _SavedButton(
                      isSaved: card.isSaved,
                      isSaving: isSaving,
                      onTap: onToggleSaved,
                    ),
                  ),
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.42),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Text(
                        card.role.trim().isEmpty ? 'Creator' : card.role,
                        style: const TextStyle(
                          color: AppTheme.colorTextPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _PortfolioThumbs(urls: card.portfolioThumbUrls),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppTheme.colorBgElevated,
                    backgroundImage: card.avatarUrl?.isNotEmpty == true
                        ? NetworkImage(card.avatarUrl!)
                        : null,
                    child: card.avatarUrl?.isNotEmpty == true
                        ? null
                        : Text(
                            card.username.isEmpty
                                ? '?'
                                : card.username[0].toUpperCase(),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.colorTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '@${card.username}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.colorTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _InfoPill(
                              icon: Icons.person_outline_rounded,
                              text:
                                  '${_formatCompactNumber(card.followersCount ?? 0)} follower',
                            ),
                            _InfoPill(
                              icon: Icons.group_outlined,
                              text:
                                  'segue ${_formatCompactNumber(card.followingCount ?? 0)}',
                            ),
                            _InfoPill(
                              icon: Icons.category_rounded,
                              text: card.category,
                            ),
                            _InfoPill(
                              icon: Icons.location_on_outlined,
                              text: location,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl?.isNotEmpty == true) {
      return Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, _, _) => const _HeroPlaceholder(),
      );
    }
    return const _HeroPlaceholder();
  }
}

class _HeroPlaceholder extends StatelessWidget {
  const _HeroPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.colorBgSecondary,
            AppTheme.colorBgCard,
            AppTheme.colorBgElevated,
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          size: 34,
          color: AppTheme.colorTextSecondary,
        ),
      ),
    );
  }
}

class _PortfolioThumbs extends StatelessWidget {
  const _PortfolioThumbs({required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    final thumbs = urls.take(6).toList(growable: false);
    if (thumbs.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 70,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        scrollDirection: Axis.horizontal,
        itemCount: thumbs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 70,
              height: 70,
              child: Image.network(
                thumbs[index],
                fit: BoxFit.cover,
                filterQuality: FilterQuality.low,
                errorBuilder: (_, _, _) => Container(
                  color: AppTheme.colorBgSecondary,
                  child: const Icon(
                    Icons.broken_image_outlined,
                    size: 18,
                    color: AppTheme.colorTextSecondary,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AdaptiveGlass extends StatelessWidget {
  const _AdaptiveGlass({
    required this.borderRadius,
    required this.child,
    this.sigma = 10,
  });

  final BorderRadius borderRadius;
  final Widget child;
  final double sigma;

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final useRealBlur =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

    // Android prefers fake glass (gradient + border) to avoid blur jank.
    if (!useRealBlur) {
      return child;
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: child,
      ),
    );
  }
}

class _SavedButton extends StatelessWidget {
  const _SavedButton({
    required this.isSaved,
    required this.isSaving,
    required this.onTap,
  });

  final bool isSaved;
  final bool isSaving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isSaved ? 'Non seguire più' : 'Segui creator',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isSaving ? null : onTap,
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
            child: isSaving
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    isSaved
                        ? Icons.person_remove_alt_1_rounded
                        : Icons.person_add_alt_1_rounded,
                    size: 21,
                    color: isSaved
                        ? AppTheme.colorAccentPrimary
                        : AppTheme.colorTextPrimary,
                  ),
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.colorBgElevated.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppTheme.colorStrokeSubtle.withValues(alpha: 0.95),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }
}
