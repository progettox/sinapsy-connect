import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../pages/brand_analytics_page.dart';
import '../pages/brand_dashboard_page.dart';
import '../pages/brand_discover_creators_page.dart';
import '../pages/brand_projects_page.dart';
import '../widgets/premium_brand_bottom_nav.dart';

class BrandShell extends ConsumerStatefulWidget {
  const BrandShell({super.key});

  @override
  ConsumerState<BrandShell> createState() => _BrandShellState();
}

class _BrandShellState extends ConsumerState<BrandShell> {
  // Nav index follows the 5-tab order: Home, Creator, Profile, Projects, Analytics.
  int _currentNavIndex = 0;
  late final PageController _pageController;
  final Map<int, Widget> _pageCache = <int, Widget>{};

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentNavIndex);
    Future<void>.microtask(() async {
      ref.read(profileControllerProvider.notifier).watchMyProfile();
      await ref.read(profileControllerProvider.notifier).loadMyProfile();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handleBottomTap(int index) {
    if (index == _currentNavIndex) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 210),
      curve: Curves.easeOutCubic,
    );
  }

  void _handlePageChanged(int index) {
    if (index == _currentNavIndex) return;
    setState(() => _currentNavIndex = index);
  }

  Widget _buildPage(int index) {
    return _pageCache.putIfAbsent(index, () {
      switch (index) {
        case 0:
          return const RepaintBoundary(child: BrandDashboardPage());
        case 1:
          return const RepaintBoundary(child: BrandDiscoverCreatorsPage());
        case 2:
          return const RepaintBoundary(child: ProfilePage());
        case 3:
          return const RepaintBoundary(child: BrandProjectsPage());
        case 4:
        default:
          return const RepaintBoundary(child: BrandAnalyticsPage());
      }
    });
  }

  bool _isTickingPage(int index) {
    // Keep animations active only on the current page and immediate neighbor
    // to reduce frame work during horizontal gestures.
    return (_currentNavIndex - index).abs() <= 1;
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
    final platform = Theme.of(context).platform;
    final pagePhysics = platform == TargetPlatform.iOS
        ? const BouncingScrollPhysics(parent: PageScrollPhysics())
        : const PageScrollPhysics(parent: ClampingScrollPhysics());

    return Scaffold(
      body: PageView.builder(
        controller: _pageController,
        itemCount: 5,
        itemBuilder: (context, index) => TickerMode(
          enabled: _isTickingPage(index),
          child: _buildPage(index),
        ),
        onPageChanged: _handlePageChanged,
        // Android uses clamping for smoother performance; iOS keeps bounce.
        physics: pagePhysics,
        allowImplicitScrolling: false,
      ),
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
