import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../brand/presentation/pages/brand_projects_page.dart';
import '../../../brand/presentation/widgets/premium_brand_bottom_nav.dart';
import '../../../brand/presentation/widgets/profile_linked_accounts_sheet.dart';
import '../../../campaigns/presentation/pages/creator_feed_page.dart';
import '../../../profile/data/profile_model.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import 'creator_analytics_page.dart';
import 'brand_search_page.dart';

class CreatorHomePage extends ConsumerStatefulWidget {
  const CreatorHomePage({super.key});

  @override
  ConsumerState<CreatorHomePage> createState() => _CreatorHomePageState();
}

class _CreatorHomePageState extends ConsumerState<CreatorHomePage> {
  // Nav index order: Home, Cerca, Profilo, Chat, Analytics.
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

  Future<void> _openAccountsSheet(ProfileModel? profile) async {
    if (profile == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Carica il profilo prima di aprire la gestione account.',
            ),
          ),
        );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.56),
      builder: (_) => ProfileLinkedAccountsSheet(activeProfile: profile),
    );
  }

  Widget _buildPage(int index) {
    return _pageCache.putIfAbsent(index, () {
      switch (index) {
        case 0:
          return const RepaintBoundary(child: CreatorFeedPage());
        case 1:
          return const RepaintBoundary(child: BrandSearchPage());
        case 2:
          return const RepaintBoundary(child: ProfilePage());
        case 3:
          return const RepaintBoundary(
            child: BrandProjectsPage(creatorMode: true),
          );
        case 4:
        default:
          return const RepaintBoundary(child: CreatorAnalyticsPage());
      }
    });
  }

  bool _isTickingPage(int index) {
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
        onProfileLongPress: () => _openAccountsSheet(sameAccountProfile),
        onTap: _handleBottomTap,
      ),
    );
  }
}
