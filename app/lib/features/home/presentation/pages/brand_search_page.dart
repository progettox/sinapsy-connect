import 'dart:async';

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
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Color(0x77161F2E),
      ),
    );

    return Theme(
      data: pageTheme,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Cerca',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
          ),
        ),
        body: Stack(
          children: [
            const Positioned.fill(child: LuxuryNeonBackdrop()),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _queryController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (value) => _searchByUsername(value.trim()),
                      decoration: InputDecoration(
                        hintText: 'Cerca per username',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _queryController.clear();
                                  _searchByUsername('');
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          if (query.isEmpty) {
                            return const _SearchStateMessage(
                              title: 'Cerca utenti reali',
                              message:
                                  'Scrivi uno username e vedrai i profili dal database.',
                            );
                          }

                          if (_isLoading) {
                            return const Center(child: SinapsyLogoLoader());
                          }

                          if (_errorMessage != null) {
                            return _SearchStateMessage(
                              title: 'Ricerca non disponibile',
                              message: _errorMessage!,
                            );
                          }

                          if (_results.isEmpty) {
                            return _SearchStateMessage(
                              title: 'Nessun risultato',
                              message: 'Nessun utente trovato per "$query".',
                            );
                          }

                          return ListView.separated(
                            itemCount: _results.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = _results[index];
                              return _UserResultTile(item: item);
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
      ),
    );
  }
}

class _UserResultTile extends StatelessWidget {
  const _UserResultTile({required this.item});

  final UserSearchResult item;

  @override
  Widget build(BuildContext context) {
    final initials = item.username.isEmpty
        ? '?'
        : item.username.substring(0, 1).toUpperCase();
    final subtitle = item.location.trim().isEmpty
        ? item.roleLabel
        : '${item.roleLabel} - ${item.location.trim()}';

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: item.avatarUrl?.isNotEmpty == true
              ? NetworkImage(item.avatarUrl!)
              : null,
          child: item.avatarUrl?.isNotEmpty == true ? null : Text(initials),
        ),
        title: Text('@${item.username}'),
        subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _SearchStateMessage extends StatelessWidget {
  const _SearchStateMessage({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
