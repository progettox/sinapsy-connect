import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
            (item) =>
                item.id == card.id ? item.copyWith(isSaved: nextSaved) : item,
          )
          .toList(growable: false);
    });

    try {
      final repo = ref.read(brandCreatorFeedRepositoryProvider);
      await repo.setSaved(creatorId: card.id, isSaved: nextSaved);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _cards = _cards
            .map(
              (item) => item.id == card.id
                  ? item.copyWith(isSaved: !nextSaved)
                  : item,
            )
            .toList(growable: false);
      });
      _showSnack('Impossibile aggiornare wishlist: $error');
    } finally {
      if (mounted) {
        setState(() => _savingIds.remove(card.id));
      }
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
          const Positioned.fill(child: LuxuryNeonBackdrop()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Scopri Creator',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Feed creator con hero, portfolio e wishlist',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.66,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xA5101018),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
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
                                        _selectedRole =
                                            _DiscoverRoleFilter.brand;
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
                                        _selectedRole ==
                                        _DiscoverRoleFilter.all,
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
                                    label: 'Salvati',
                                    selected:
                                        _selectedRole ==
                                        _DiscoverRoleFilter.saved,
                                    onTap: () {
                                      if (_selectedRole ==
                                          _DiscoverRoleFilter.saved) {
                                        return;
                                      }
                                      setState(() {
                                        _selectedRole =
                                            _DiscoverRoleFilter.saved;
                                      });
                                      _loadCreators();
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _queryController,
                              decoration: InputDecoration(
                                isDense: true,
                                prefixIcon: const Icon(Icons.search_rounded),
                                hintText: 'Filtro manuale username/localita',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
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
                          itemCount: cards.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final card = cards[index];
                            return _CreatorFeedCardTile(
                              card: card,
                              isSaving: _savingIds.contains(card.id),
                              onToggleSaved: () => _toggleSaved(card),
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
        color: selected
            ? theme.colorScheme.primary.withValues(alpha: 0.22)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.42)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: selected
                  ? const Color(0xFFEFF0FF)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.72),
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xB0111119),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _HeroImage(imageUrl: card.heroImageUrl),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: _SavedButton(
                        isSaved: card.isSaved,
                        isSaving: isSaving,
                        onTap: onToggleSaved,
                      ),
                    ),
                    Positioned(
                      left: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          card.role.trim().isEmpty ? 'Creator' : card.role,
                          style: const TextStyle(
                            color: Color(0xFFEFF2FF),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _PortfolioThumbs(urls: card.portfolioThumbUrls),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: card.avatarUrl?.isNotEmpty == true
                          ? NetworkImage(card.avatarUrl!)
                          : null,
                      child: card.avatarUrl?.isNotEmpty == true
                          ? null
                          : Text(
                              card.username.isEmpty
                                  ? '?'
                                  : card.username[0].toUpperCase(),
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            card.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '@${card.username}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.72,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
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
      ),
    );
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
          colors: [Color(0xFF1A2235), Color(0xFF141A29), Color(0xFF1E2535)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.image_outlined, size: 34, color: Color(0x99EAF3FF)),
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
      height: 58,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: thumbs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 58,
              height: 58,
              child: Image.network(
                thumbs[index],
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: const Color(0xFF1B2232),
                  child: const Icon(
                    Icons.broken_image_outlined,
                    size: 18,
                    color: Color(0x88EAF3FF),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isSaving ? null : onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
          ),
          child: isSaving
              ? const Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  isSaved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  size: 19,
                  color: isSaved
                      ? const Color(0xFF8EC8FF)
                      : const Color(0xFFEAF3FF),
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
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
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
