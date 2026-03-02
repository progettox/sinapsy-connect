import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  static const List<Widget> _pages = <Widget>[
    BrandDashboardPage(),
    BrandDiscoverCreatorsPage(),
    ProfilePage(),
    BrandProjectsPage(),
    BrandAnalyticsPage(),
  ];

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
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _handlePageChanged(int index) {
    if (index == _currentNavIndex) return;
    setState(() => _currentNavIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileControllerProvider);
    final username = profileState.profile?.username.trim() ?? '';
    final avatar = profileState.profile?.avatarUrl?.trim();

    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _handlePageChanged,
        // Smooth iOS-like feel for manual horizontal swipes.
        physics: const BouncingScrollPhysics(),
        children: _pages,
      ),
      extendBody: true,
      bottomNavigationBar: PremiumBrandBottomNav(
        currentIndex: _currentNavIndex,
        profileAvatarUrl: (avatar?.isNotEmpty ?? false) ? avatar : null,
        profileInitial: username.isNotEmpty ? username.substring(0, 1) : null,
        onTap: _handleBottomTap,
      ),
    );
  }
}
