import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/widgets/luxury_neon_backdrop.dart';
import '../../../../core/widgets/sinapsy_logo_loader.dart';
import '../../data/user_search_repository.dart';

class BrandSearchPage extends ConsumerStatefulWidget {
  const BrandSearchPage({super.key});

  @override
  ConsumerState<BrandSearchPage> createState() => _BrandSearchPageState();
}

class _BrandSearchPageState extends ConsumerState<BrandSearchPage> {
  final TextEditingController _queryController = TextEditingController();
  Timer? _searchDebounce;
  List<UserSearchResult> _results = const <UserSearchResult>[];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _queryController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _queryController
      ..removeListener(_onQueryChanged)
      ..dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _searchDebounce?.cancel();
    final query = _queryController.text.trim();
    _searchDebounce = Timer(
      const Duration(milliseconds: 320),
      () => _searchByUsername(query),
    );
  }

  Future<void> _searchByUsername(String query) async {
    if (!mounted) return;
    if (query.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = null;
        _results = const <UserSearchResult>[];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final currentUserId = ref
          .read(userSearchRepositoryProvider)
          .currentUserId;
      final items = await ref
          .read(userSearchRepositoryProvider)
          .searchByUsername(query, excludeUserId: currentUserId);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _results = items;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _results = const <UserSearchResult>[];
        _errorMessage = 'Errore ricerca utenti: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _queryController.text.trim();
    final theme = Theme.of(context);
    final pageTheme = theme.copyWith(
      textTheme: GoogleFonts.plusJakartaSansTextTheme(theme.textTheme),
      primaryTextTheme: GoogleFonts.plusJakartaSansTextTheme(
        theme.primaryTextTheme,
      ),
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFFEAF3FF),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xC0162030),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: const Color(0xFF9FC8F8).withValues(alpha: 0.16),
          ),
        ),
      ),
    );

    return Theme(
      data: pageTheme,
      child: Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(child: LuxuryNeonBackdrop()),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: Column(
                  children: [
                    _SearchHeaderPanel(
                      controller: _queryController,
                      query: query,
                      onSubmitted: (value) => _searchByUsername(value.trim()),
                      onClear: () {
                        _queryController.clear();
                        _searchByUsername('');
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: Builder(
                          builder: (context) {
                            if (query.isEmpty) {
                              return const SizedBox.expand(
                                key: ValueKey('search_idle'),
                              );
                            }

                            if (_isLoading) {
                              return const Center(
                                key: ValueKey('search_loading'),
                                child: SinapsyLogoLoader(),
                              );
                            }

                            if (_errorMessage != null) {
                              return _SearchStateMessage(
                                key: const ValueKey('search_error'),
                                icon: Icons.error_outline_rounded,
                                title: 'Ricerca non disponibile',
                                message: _errorMessage!,
                              );
                            }

                            if (_results.isEmpty) {
                              return _SearchStateMessage(
                                key: const ValueKey('search_empty'),
                                icon: Icons.person_search_rounded,
                                title: 'Nessun risultato',
                                message: 'Nessun utente trovato per "$query".',
                              );
                            }

                            return ListView.separated(
                              key: const ValueKey('search_results'),
                              physics: const BouncingScrollPhysics(),
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: const EdgeInsets.only(bottom: 4),
                              itemCount: _results.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final item = _results[index];
                                return _UserResultTile(item: item);
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchHeaderPanel extends StatelessWidget {
  const _SearchHeaderPanel({
    required this.controller,
    required this.query,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _GlassPanel(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Cerca',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Trova creator e brand in tempo reale',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.66),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: const Color(0xFF9FC8F8).withValues(alpha: 0.35),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      textInputAction: TextInputAction.search,
                      onSubmitted: onSubmitted,
                      cursorColor: theme.colorScheme.primary,
                      style: theme.textTheme.bodyLarge,
                      decoration: InputDecoration(
                        hintText: 'Cerca per username',
                        hintStyle: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.58,
                          ),
                        ),
                        isDense: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: query.isEmpty
                        ? const SizedBox(width: 34, height: 34)
                        : IconButton(
                            key: const ValueKey('clear_search'),
                            onPressed: onClear,
                            tooltip: 'Pulisci ricerca',
                            icon: const Icon(Icons.close_rounded),
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
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF9FC8F8).withValues(alpha: 0.18),
            ),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0x8A1B2638), Color(0x7A111A2A), Color(0x63202A3A)],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x88040A14),
                blurRadius: 22,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _UserResultTile extends StatelessWidget {
  const _UserResultTile({required this.item});

  final UserSearchResult item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = item.username.isEmpty
        ? '?'
        : item.username.substring(0, 1).toUpperCase();
    final subtitle = item.location.trim().isEmpty
        ? item.roleLabel
        : '${item.roleLabel} - ${item.location.trim()}';

    return _GlassPanel(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: _roleColor(item.role).withValues(alpha: 0.2),
              backgroundImage: item.avatarUrl?.isNotEmpty == true
                  ? NetworkImage(item.avatarUrl!)
                  : null,
              child: item.avatarUrl?.isNotEmpty == true
                  ? null
                  : Text(
                      initials,
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '@${item.username}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _roleColor(item.role).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          item.roleLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: _roleColor(item.role),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.place_rounded,
                        size: 14,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.62,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.72,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _roleColor(String rawRole) {
    switch (rawRole.trim().toLowerCase()) {
      case 'brand':
        return const Color(0xFFFFB762);
      case 'creator':
        return const Color(0xFF8EC8FF);
      default:
        return const Color(0xFFB6C5D9);
    }
  }
}

class _SearchStateMessage extends StatelessWidget {
  const _SearchStateMessage({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.search_rounded,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: _GlassPanel(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: theme.colorScheme.primary),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.74),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
