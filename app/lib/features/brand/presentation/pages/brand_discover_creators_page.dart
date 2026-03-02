import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/luxury_neon_backdrop.dart';
import '../../../../core/widgets/sinapsy_logo_loader.dart';
import '../../../home/data/user_search_repository.dart';

enum _DiscoverRoleFilter { all, creator, brand }

class BrandDiscoverCreatorsPage extends ConsumerStatefulWidget {
  const BrandDiscoverCreatorsPage({super.key});

  @override
  ConsumerState<BrandDiscoverCreatorsPage> createState() =>
      _BrandDiscoverCreatorsPageState();
}

class _BrandDiscoverCreatorsPageState
    extends ConsumerState<BrandDiscoverCreatorsPage> {
  final _queryController = TextEditingController();
  List<UserSearchResult> _users = const <UserSearchResult>[];
  bool _isLoading = true;
  String? _errorMessage;
  _DiscoverRoleFilter _selectedRole = _DiscoverRoleFilter.creator;

  @override
  void initState() {
    super.initState();
    _queryController.addListener(() => setState(() {}));
    Future<void>.microtask(_loadUsers);
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final repo = ref.read(userSearchRepositoryProvider);
      final roleFilter = switch (_selectedRole) {
        _DiscoverRoleFilter.all => null,
        _DiscoverRoleFilter.creator => 'creator',
        _DiscoverRoleFilter.brand => 'brand',
      };
      final users = await repo.listUsers(
        excludeUserId: repo.currentUserId,
        role: roleFilter,
        limit: 80,
      );
      if (!mounted) return;
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _users = const <UserSearchResult>[];
        _isLoading = false;
        _errorMessage = 'Errore caricamento creator: $error';
      });
    }
  }

  List<UserSearchResult> get _filteredUsers {
    final query = _queryController.text.trim().toLowerCase();
    if (query.isEmpty) return _users;
    return _users
        .where((user) {
          return user.username.toLowerCase().contains(query) ||
              user.location.toLowerCase().contains(query);
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
                    'Lista profili con filtri manuali',
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
                                      _loadUsers();
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
                                      _loadUsers();
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
                                      _loadUsers();
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
                            child: Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                            ),
                          );
                        }
                        final users = _filteredUsers;
                        if (users.isEmpty) {
                          return const Center(
                            child: Text(
                              'Nessun risultato con i filtri correnti.',
                            ),
                          );
                        }
                        return ListView.separated(
                          itemCount: users.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            return _DiscoverUserTile(user: users[index]);
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

class _DiscoverUserTile extends StatelessWidget {
  const _DiscoverUserTile({required this.user});

  final UserSearchResult user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = user.username.isEmpty
        ? '?'
        : user.username[0].toUpperCase();
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xB0111118),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 2,
            ),
            leading: CircleAvatar(
              radius: 20,
              backgroundImage: user.avatarUrl?.isNotEmpty == true
                  ? NetworkImage(user.avatarUrl!)
                  : null,
              child: user.avatarUrl?.isNotEmpty == true ? null : Text(initials),
            ),
            title: Text('@${user.username}'),
            subtitle: Text(
              user.location.trim().isEmpty
                  ? 'Localita non indicata'
                  : user.location,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.66),
              ),
            ),
            trailing: Text(
              user.roleLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
