import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/widgets/luxury_neon_backdrop.dart';
import '../../../applications/presentation/pages/my_applications_page.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../brand/presentation/widgets/premium_brand_bottom_nav.dart';
import '../../../campaigns/presentation/pages/creator_feed_page.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import 'brand_search_page.dart';

class CreatorHomePage extends ConsumerStatefulWidget {
  const CreatorHomePage({super.key});

  @override
  ConsumerState<CreatorHomePage> createState() => _CreatorHomePageState();
}

class _CreatorHomePageState extends ConsumerState<CreatorHomePage> {
  // 0: Home, 1: Cerca, 2: Profilo, 3: Feed, 4: Candidature.
  int _currentNavIndex = 0;
  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = <Widget>[
      _CreatorHomeDashboardTab(
        onOpenFeed: () => _handleBottomTap(3),
        onOpenApplications: () => _handleBottomTap(4),
      ),
      const BrandSearchPage(),
      const ProfilePage(),
      const CreatorFeedPage(),
      const MyApplicationsPage(),
    ];
    Future<void>.microtask(() async {
      ref.read(profileControllerProvider.notifier).watchMyProfile();
      await ref.read(profileControllerProvider.notifier).loadMyProfile();
    });
  }

  void _handleBottomTap(int index) {
    if (index == _currentNavIndex) return;
    setState(() => _currentNavIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final authUserId = ref.watch(authRepositoryProvider).currentUser?.id.trim();
    final profileState = ref.watch(profileControllerProvider);
    final sameAccountProfile =
        authUserId != null &&
            authUserId.isNotEmpty &&
            profileState.profile?.id.trim() == authUserId
        ? profileState.profile
        : null;
    final username = sameAccountProfile?.username.trim() ?? '';
    final avatar = sameAccountProfile?.avatarUrl?.trim();
    final profileUserId = sameAccountProfile?.id.trim();

    return Scaffold(
      body: IndexedStack(index: _currentNavIndex, children: _tabs),
      extendBody: true,
      bottomNavigationBar: PremiumBrandBottomNav(
        currentIndex: _currentNavIndex,
        profileUserId: (profileUserId?.isNotEmpty ?? false)
            ? profileUserId
            : null,
        profileAvatarUrl: (avatar?.isNotEmpty ?? false) ? avatar : null,
        profileInitial: username.isNotEmpty ? username.substring(0, 1) : null,
        onTap: _handleBottomTap,
      ),
    );
  }
}

class _CreatorHomeDashboardTab extends ConsumerWidget {
  const _CreatorHomeDashboardTab({
    required this.onOpenFeed,
    required this.onOpenApplications,
  });

  final VoidCallback onOpenFeed;
  final VoidCallback onOpenApplications;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileControllerProvider).profile;
    final username = (profile?.username ?? '').trim();
    final roleRaw = profile?.role?.name ?? 'creator';
    final role = roleRaw.isEmpty
        ? 'Creator'
        : '${roleRaw[0].toUpperCase()}${roleRaw.substring(1)}';
    final nameLabel = username.isEmpty ? role : '@$username';

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: LuxuryNeonBackdrop()),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Home',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFEAF3FF),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    nameLabel,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xCCDFEAFF),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Azioni rapide',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFF1F5FF),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 40,
                          child: ElevatedButton.icon(
                            onPressed: onOpenFeed,
                            icon: const Icon(Icons.explore_rounded, size: 18),
                            label: const Text('Vai al Feed'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8D5BFF),
                              foregroundColor: const Color(0xFFF7F2FF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 40,
                          child: OutlinedButton.icon(
                            onPressed: onOpenApplications,
                            icon: const Icon(Icons.list_alt_rounded, size: 18),
                            label: const Text('Le tue candidature'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFEAF3FF),
                              side: BorderSide(
                                color: const Color(
                                  0xFF9FC8F8,
                                ).withValues(alpha: 0.28),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
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

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});

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
          child: Padding(padding: const EdgeInsets.all(14), child: child),
        ),
      ),
    );
  }
}
