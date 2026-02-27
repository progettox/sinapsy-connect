import 'dart:math' as math;
import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/luxury_neon_backdrop.dart';
import '../../../../core/widgets/sinapsy_confirm_dialog.dart';
import '../../../../core/widgets/sinapsy_logo_loader.dart';
import '../../../applications/presentation/pages/brand_applications_page.dart';
import '../../../home/data/user_search_repository.dart';
import '../../../home/presentation/controllers/home_controller.dart';
import '../../data/campaign_model.dart';
import '../controllers/create_campaign_controller.dart';
import 'create_campaign_page.dart';

enum _MatchingTimeline { lastWeek, lastMonth, sixMonths, lastYear }

extension _MatchingTimelineX on _MatchingTimeline {
  String get label {
    switch (this) {
      case _MatchingTimeline.lastWeek:
        return 'Ultima settimana';
      case _MatchingTimeline.lastMonth:
        return 'Ultimo mese';
      case _MatchingTimeline.sixMonths:
        return 'Ultimi 6 mesi';
      case _MatchingTimeline.lastYear:
        return 'Ultimo anno';
    }
  }

  String get comparisonLabel {
    switch (this) {
      case _MatchingTimeline.lastWeek:
        return 'giorno precedente';
      case _MatchingTimeline.lastMonth:
        return 'settimana precedente';
      case _MatchingTimeline.sixMonths:
      case _MatchingTimeline.lastYear:
        return 'mese precedente';
    }
  }

  String get shortLabel {
    switch (this) {
      case _MatchingTimeline.lastWeek:
        return '7G';
      case _MatchingTimeline.lastMonth:
        return '1M';
      case _MatchingTimeline.sixMonths:
        return '6M';
      case _MatchingTimeline.lastYear:
        return '1A';
    }
  }
}

class BrandHomePage extends ConsumerStatefulWidget {
  const BrandHomePage({super.key});

  @override
  ConsumerState<BrandHomePage> createState() => _BrandHomePageState();
}

class _BrandHomePageState extends ConsumerState<BrandHomePage> {
  _MatchingTimeline _selectedTimeline = _MatchingTimeline.sixMonths;
  List<UserSearchResult> _communityUsers = const <UserSearchResult>[];
  bool _isCommunityUsersLoading = true;
  String? _communityUsersError;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      await ref
          .read(brandCampaignsControllerProvider.notifier)
          .loadMyCampaigns();
      await _loadCommunityUsers();
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

  Future<void> _openActiveCampaigns() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const _ActiveCampaignsPage()),
    );
  }

  Future<void> _openMatchedCampaigns() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const _MatchedCampaignsPage()),
    );
  }

  Future<void> _logout() async {
    final ok = await ref.read(homeControllerProvider.notifier).logout();
    if (!mounted || !ok) return;
    context.go(AppRouter.authPath);
  }

  Future<void> _loadCommunityUsers() async {
    if (!mounted) return;
    setState(() {
      _isCommunityUsersLoading = true;
      _communityUsersError = null;
    });
    try {
      final repository = ref.read(userSearchRepositoryProvider);
      final users = await repository.listUsers(
        excludeUserId: repository.currentUserId,
        limit: 20,
      );
      if (!mounted) return;
      setState(() {
        _communityUsers = users;
        _isCommunityUsersLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _communityUsers = const <UserSearchResult>[];
        _isCommunityUsersLoading = false;
        _communityUsersError = 'Errore caricamento utenti: $error';
      });
    }
  }

  List<_TrendPoint> _buildMatchingTrend(
    List<CampaignModel> campaigns,
    _MatchingTimeline timeline,
  ) {
    switch (timeline) {
      case _MatchingTimeline.lastWeek:
        return _buildDailyTrend(campaigns, days: 7);
      case _MatchingTimeline.lastMonth:
        return _buildWeeklyTrend(campaigns, weeks: 4);
      case _MatchingTimeline.sixMonths:
        return _buildMonthlyTrend(campaigns, months: 6);
      case _MatchingTimeline.lastYear:
        return _buildMonthlyTrend(campaigns, months: 12);
    }
  }

  List<_TrendPoint> _buildSpentBudgetTrend(
    List<CampaignModel> campaigns,
    _MatchingTimeline timeline,
  ) {
    switch (timeline) {
      case _MatchingTimeline.lastWeek:
        return _buildDailyBudgetTrend(campaigns, days: 7);
      case _MatchingTimeline.lastMonth:
        return _buildWeeklyBudgetTrend(campaigns, weeks: 4);
      case _MatchingTimeline.sixMonths:
        return _buildMonthlyBudgetTrend(campaigns, months: 6);
      case _MatchingTimeline.lastYear:
        return _buildMonthlyBudgetTrend(campaigns, months: 12);
    }
  }

  List<_TrendPoint> _buildDailyTrend(
    List<CampaignModel> campaigns, {
    required int days,
  }) {
    final today = DateTime.now();
    final dayAnchors = List<DateTime>.generate(
      days,
      (index) =>
          DateTime(today.year, today.month, today.day - (days - 1 - index)),
    );

    return dayAnchors
        .map((dayStart) {
          final dayEnd = dayStart.add(const Duration(days: 1));
          return _TrendPoint(
            label: _weekdayLabel(dayStart),
            value: _countMatchesInRange(campaigns, dayStart, dayEnd).toDouble(),
          );
        })
        .toList(growable: false);
  }

  List<_TrendPoint> _buildWeeklyTrend(
    List<CampaignModel> campaigns, {
    required int weeks,
  }) {
    final now = DateTime.now();
    final endBoundary = DateTime(now.year, now.month, now.day + 1);

    return List<_TrendPoint>.generate(weeks, (index) {
      final offset = weeks - 1 - index;
      final intervalEnd = endBoundary.subtract(Duration(days: offset * 7));
      final intervalStart = intervalEnd.subtract(const Duration(days: 7));
      return _TrendPoint(
        label: _dayMonthLabel(intervalStart),
        value: _countMatchesInRange(
          campaigns,
          intervalStart,
          intervalEnd,
        ).toDouble(),
      );
    });
  }

  List<_TrendPoint> _buildDailyBudgetTrend(
    List<CampaignModel> campaigns, {
    required int days,
  }) {
    final today = DateTime.now();
    final dayAnchors = List<DateTime>.generate(
      days,
      (index) =>
          DateTime(today.year, today.month, today.day - (days - 1 - index)),
    );

    return dayAnchors
        .map((dayStart) {
          final dayEnd = dayStart.add(const Duration(days: 1));
          return _TrendPoint(
            label: _weekdayLabel(dayStart),
            value: _sumSpentBudgetInRange(campaigns, dayStart, dayEnd),
          );
        })
        .toList(growable: false);
  }

  List<_TrendPoint> _buildWeeklyBudgetTrend(
    List<CampaignModel> campaigns, {
    required int weeks,
  }) {
    final now = DateTime.now();
    final endBoundary = DateTime(now.year, now.month, now.day + 1);

    return List<_TrendPoint>.generate(weeks, (index) {
      final offset = weeks - 1 - index;
      final intervalEnd = endBoundary.subtract(Duration(days: offset * 7));
      final intervalStart = intervalEnd.subtract(const Duration(days: 7));
      return _TrendPoint(
        label: _dayMonthLabel(intervalStart),
        value: _sumSpentBudgetInRange(campaigns, intervalStart, intervalEnd),
      );
    });
  }

  List<_TrendPoint> _buildMonthlyTrend(
    List<CampaignModel> campaigns, {
    required int months,
  }) {
    final now = DateTime.now();
    final monthAnchors = List<DateTime>.generate(
      months,
      (index) => DateTime(now.year, now.month - (months - 1 - index), 1),
    );

    return monthAnchors
        .map((monthStart) {
          final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);
          return _TrendPoint(
            label: _monthLabel(monthStart),
            value: _countMatchesInRange(
              campaigns,
              monthStart,
              monthEnd,
            ).toDouble(),
          );
        })
        .toList(growable: false);
  }

  List<_TrendPoint> _buildMonthlyBudgetTrend(
    List<CampaignModel> campaigns, {
    required int months,
  }) {
    final now = DateTime.now();
    final monthAnchors = List<DateTime>.generate(
      months,
      (index) => DateTime(now.year, now.month - (months - 1 - index), 1),
    );

    return monthAnchors
        .map((monthStart) {
          final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);
          return _TrendPoint(
            label: _monthLabel(monthStart),
            value: _sumSpentBudgetInRange(campaigns, monthStart, monthEnd),
          );
        })
        .toList(growable: false);
  }

  int _countMatchesInRange(
    List<CampaignModel> campaigns,
    DateTime start,
    DateTime end,
  ) {
    return campaigns.where((campaign) {
      final createdAt = campaign.createdAt;
      if (createdAt == null) return false;
      final status = campaign.status.toLowerCase();
      if (status != 'matched' && status != 'completed') return false;
      return !createdAt.isBefore(start) && createdAt.isBefore(end);
    }).length;
  }

  double _sumSpentBudgetInRange(
    List<CampaignModel> campaigns,
    DateTime start,
    DateTime end,
  ) {
    return campaigns
        .where((campaign) {
          final createdAt = campaign.createdAt;
          if (createdAt == null) return false;
          final status = campaign.status.toLowerCase();
          if (status != 'matched' && status != 'completed') return false;
          return !createdAt.isBefore(start) && createdAt.isBefore(end);
        })
        .fold<double>(0, (sum, campaign) => sum + campaign.budget.toDouble());
  }

  String _weekdayLabel(DateTime date) {
    const shortWeekdays = <String>[
      'Lun',
      'Mar',
      'Mer',
      'Gio',
      'Ven',
      'Sab',
      'Dom',
    ];
    return shortWeekdays[date.weekday - 1];
  }

  String _monthLabel(DateTime date) {
    const shortMonths = <String>[
      'Gen',
      'Feb',
      'Mar',
      'Apr',
      'Mag',
      'Giu',
      'Lug',
      'Ago',
      'Set',
      'Ott',
      'Nov',
      'Dic',
    ];
    return shortMonths[date.month - 1];
  }

  String _dayMonthLabel(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    return '$dd/$mm';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(brandCampaignsControllerProvider);
    final homeState = ref.watch(homeControllerProvider);
    final theme = Theme.of(context);
    final textTheme = GoogleFonts.plusJakartaSansTextTheme(theme.textTheme);
    final campaigns = state.campaigns;
    final activeCampaigns = campaigns
        .where((campaign) => campaign.status.toLowerCase() == 'active')
        .length;
    final matchedCampaigns = campaigns
        .where((campaign) => campaign.status.toLowerCase() == 'matched')
        .length;
    final spentBudget = campaigns
        .where((campaign) {
          final status = campaign.status.toLowerCase();
          return status == 'matched' || status == 'completed';
        })
        .fold<num>(0, (total, campaign) => total + campaign.budget);
    final matchingTrend = _buildMatchingTrend(campaigns, _selectedTimeline);
    final spentBudgetTrend = _buildSpentBudgetTrend(
      campaigns,
      _selectedTimeline,
    );

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
    ref.listen<HomeUiState>(homeControllerProvider, (previous, next) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        _showSnack(next.errorMessage!);
        ref.read(homeControllerProvider.notifier).clearError();
      }
    });

    return Theme(
      data: theme.copyWith(
        textTheme: textTheme,
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
      ),
      child: Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(child: LuxuryNeonBackdrop()),
            SafeArea(
              child: Builder(
                builder: (context) {
                  if (state.isLoading && campaigns.isEmpty) {
                    return const Center(child: SinapsyLogoLoader());
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      await ref
                          .read(brandCampaignsControllerProvider.notifier)
                          .loadMyCampaigns();
                      await _loadCommunityUsers();
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                      children: [
                        _DashboardHeaderPanel(
                          canCreateCampaign:
                              !state.isLoading &&
                              !state.isRemoving &&
                              !homeState.isLoading,
                          canLogout: !homeState.isLoading,
                          onCreateCampaign: _openCreateCampaign,
                          onLogout: _logout,
                        ),
                        const SizedBox(height: 12),
                        _QuickStatsSection(
                          activeCampaigns: activeCampaigns,
                          spentBudget: spentBudget,
                          matchedCampaigns: matchedCampaigns,
                          matchingTrend: matchingTrend,
                          spentBudgetTrend: spentBudgetTrend,
                          selectedTimeline: _selectedTimeline,
                          onOpenActive: _openActiveCampaigns,
                          onOpenMatched: _openMatchedCampaigns,
                          onTimelineChanged: (timeline) {
                            setState(() => _selectedTimeline = timeline);
                          },
                        ),
                        const SizedBox(height: 18),
                        _UsersMiniFeed(
                          users: _communityUsers,
                          isLoading: _isCommunityUsersLoading,
                          errorMessage: _communityUsersError,
                          onRetry: _loadCommunityUsers,
                        ),
                      ],
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
}

class _DashboardHeaderPanel extends StatelessWidget {
  const _DashboardHeaderPanel({
    required this.canCreateCampaign,
    required this.canLogout,
    required this.onCreateCampaign,
    required this.onLogout,
  });

  final bool canCreateCampaign;
  final bool canLogout;
  final VoidCallback onCreateCampaign;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  const SinapsyLogoLoader(size: 34),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 40,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sinapsy',
                            maxLines: 1,
                            style: GoogleFonts.sora(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFEAF3FF),
                              letterSpacing: -0.2,
                              height: 1,
                            ),
                          ),
                          Transform.translate(
                            offset: const Offset(46, -0.4),
                            child: Text(
                              'Connect',
                              maxLines: 1,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFC9E0FF),
                                letterSpacing: 0.84,
                                height: 1,
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
            _HeaderActionButton(
              icon: Icons.add_rounded,
              tooltip: 'Nuova campagna',
              onPressed: canCreateCampaign ? onCreateCampaign : null,
            ),
            const SizedBox(width: 8),
            _HeaderActionButton(
              icon: Icons.logout_rounded,
              tooltip: 'Logout',
              onPressed: canLogout ? onLogout : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = onPressed != null;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(
                alpha: isEnabled ? 0.16 : 0.08,
              ),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(
                  alpha: isEnabled ? 0.44 : 0.2,
                ),
              ),
            ),
            child: Icon(
              icon,
              size: 18,
              color: const Color(0xFFEAF3FF).withValues(
                alpha: isEnabled ? 1 : 0.45,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickStatsSection extends StatelessWidget {
  const _QuickStatsSection({
    required this.activeCampaigns,
    required this.spentBudget,
    required this.matchedCampaigns,
    required this.matchingTrend,
    required this.spentBudgetTrend,
    required this.selectedTimeline,
    required this.onOpenActive,
    required this.onOpenMatched,
    required this.onTimelineChanged,
  });

  final int activeCampaigns;
  final num spentBudget;
  final int matchedCampaigns;
  final List<_TrendPoint> matchingTrend;
  final List<_TrendPoint> spentBudgetTrend;
  final _MatchingTimeline selectedTimeline;
  final VoidCallback onOpenActive;
  final VoidCallback onOpenMatched;
  final ValueChanged<_MatchingTimeline> onTimelineChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 124,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Campagne attive',
                  value: '$activeCampaigns',
                  icon: Icons.campaign_rounded,
                  onTap: onOpenActive,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  title: 'Budget speso',
                  value: _formatBudget(spentBudget),
                  icon: Icons.euro_rounded,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 260,
          child: _TrendCardsCarousel(
            matchedCampaigns: matchedCampaigns,
            matchingTrendPoints: matchingTrend,
            spentBudget: spentBudget,
            spentBudgetTrendPoints: spentBudgetTrend,
            selectedTimeline: selectedTimeline,
            onTimelineChanged: onTimelineChanged,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed: onOpenMatched,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: const Color(0xFF8EC8FF).withValues(alpha: 0.22),
              foregroundColor: const Color(0xFFEAF3FF),
            ),
            child: const Text(
              'matched',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  String _formatBudget(num value) {
    if (value == value.roundToDouble()) {
      return 'EUR ${value.toInt()}';
    }
    return 'EUR ${value.toStringAsFixed(2)}';
  }
}

class _UsersMiniFeed extends StatelessWidget {
  const _UsersMiniFeed({
    required this.users,
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
  });

  final List<UserSearchResult> users;
  final bool isLoading;
  final String? errorMessage;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            children: [
              Text(
                'Utenti su Sinapsy',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.swipe_rounded,
                size: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (isLoading)
          const _UsersMiniFeedLoading()
        else if (errorMessage != null)
          _UsersMiniFeedError(message: errorMessage!, onRetry: onRetry)
        else if (users.isEmpty)
          const _UsersMiniFeedEmpty()
        else
          SizedBox(
            height: 118,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: users.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) =>
                  _MiniUserCard(user: users[index]),
            ),
          ),
      ],
    );
  }
}

class _UsersMiniFeedLoading extends StatelessWidget {
  const _UsersMiniFeedLoading();

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: const SizedBox(
        height: 118,
        child: Center(child: SinapsyLogoLoader(size: 28)),
      ),
    );
  }
}

class _UsersMiniFeedEmpty extends StatelessWidget {
  const _UsersMiniFeedEmpty();

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: const SizedBox(
        height: 118,
        child: Center(
          child: Text(
            'Nessun creator disponibile al momento.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _UsersMiniFeedError extends StatelessWidget {
  const _UsersMiniFeedError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: SizedBox(
        height: 118,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: const Color(0xFFB6C5D9)),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 30,
                child: OutlinedButton(
                  onPressed: () {
                    onRetry();
                  },
                  child: const Text('Riprova'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniUserCard extends StatelessWidget {
  const _MiniUserCard({required this.user});

  final UserSearchResult user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = user.username.isEmpty
        ? '?'
        : user.username.substring(0, 1).toUpperCase();
    final location = user.location.trim().isEmpty
        ? 'Localita non indicata'
        : user.location.trim();

    return SizedBox(
      width: 156,
      child: _GlassPanel(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundImage: user.avatarUrl?.isNotEmpty == true
                        ? NetworkImage(user.avatarUrl!)
                        : null,
                    child: user.avatarUrl?.isNotEmpty == true
                        ? null
                        : Text(initials, style: theme.textTheme.labelMedium),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '@${user.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _roleColor(user.role).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  user.roleLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: _roleColor(user.role),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                location,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
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

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = _GlassPanel(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 22),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: content,
      ),
    );
  }
}

class _TrendCardsCarousel extends StatefulWidget {
  const _TrendCardsCarousel({
    required this.matchedCampaigns,
    required this.matchingTrendPoints,
    required this.spentBudget,
    required this.spentBudgetTrendPoints,
    required this.selectedTimeline,
    required this.onTimelineChanged,
  });

  final int matchedCampaigns;
  final List<_TrendPoint> matchingTrendPoints;
  final num spentBudget;
  final List<_TrendPoint> spentBudgetTrendPoints;
  final _MatchingTimeline selectedTimeline;
  final ValueChanged<_MatchingTimeline> onTimelineChanged;

  @override
  State<_TrendCardsCarousel> createState() => _TrendCardsCarouselState();
}

class _TrendCardsCarouselState extends State<_TrendCardsCarousel> {
  late final PageController _pageController;
  Timer? _hideArrowsTimer;
  int _pageIndex = 0;
  bool _showScrollArrows = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _hideArrowsTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _showArrowsTemporarily() {
    if (!mounted) return;
    if (!_showScrollArrows) {
      setState(() => _showScrollArrows = true);
    }
    _hideArrowsTimer?.cancel();
    _hideArrowsTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _showScrollArrows = false);
    });
  }

  void _goToBudgetChart() {
    if (_pageIndex != 0) return;
    _showArrowsTemporarily();
    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _goToMatchingChart() {
    if (_pageIndex == 0) return;
    _showArrowsTemporarily();
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Listener(
      onPointerDown: (_) => _showArrowsTemporarily(),
      child: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _pageIndex = index),
            children: [
              _MatchingCard(
                matchedCampaigns: widget.matchedCampaigns,
                trendPoints: widget.matchingTrendPoints,
                selectedTimeline: widget.selectedTimeline,
                onTimelineChanged: widget.onTimelineChanged,
              ),
              _SpentBudgetCard(
                totalSpentBudget: widget.spentBudget,
                trendPoints: widget.spentBudgetTrendPoints,
                selectedTimeline: widget.selectedTimeline,
                onTimelineChanged: widget.onTimelineChanged,
              ),
            ],
          ),
          Positioned(
            left: 8,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              ignoring: !_showScrollArrows || _pageIndex == 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: _showScrollArrows && _pageIndex > 0 ? 1 : 0,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _goToMatchingChart,
                      borderRadius: BorderRadius.circular(999),
                      child: Ink(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.14,
                          ),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.34,
                            ),
                          ),
                        ),
                        child: const Icon(
                          Icons.chevron_left_rounded,
                          size: 18,
                          color: Color(0xFFEAF3FF),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              ignoring: !_showScrollArrows || _pageIndex != 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: _showScrollArrows && _pageIndex == 0 ? 1 : 0,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _goToBudgetChart,
                      borderRadius: BorderRadius.circular(999),
                      child: Ink(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.14,
                          ),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.34,
                            ),
                          ),
                        ),
                        child: const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: Color(0xFFEAF3FF),
                        ),
                      ),
                    ),
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

class _MatchingCard extends StatelessWidget {
  const _MatchingCard({
    required this.matchedCampaigns,
    required this.trendPoints,
    required this.selectedTimeline,
    required this.onTimelineChanged,
  });

  final int matchedCampaigns;
  final List<_TrendPoint> trendPoints;
  final _MatchingTimeline selectedTimeline;
  final ValueChanged<_MatchingTimeline> onTimelineChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastMonthValue = trendPoints.isNotEmpty
        ? trendPoints.last.value.toInt()
        : 0;
    final previousMonthValue = trendPoints.length > 1
        ? trendPoints[trendPoints.length - 2].value.toInt()
        : 0;
    final delta = lastMonthValue - previousMonthValue;
    final deltaLabel = delta == 0
        ? 'stabile vs ${selectedTimeline.comparisonLabel}'
        : '${delta > 0 ? '+' : ''}$delta vs ${selectedTimeline.comparisonLabel}';

    return _GlassPanel(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Matching creator',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _TimelineMenuButton(
                  selectedTimeline: selectedTimeline,
                  onTimelineChanged: onTimelineChanged,
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '$matchedCampaigns campagne in matching ora',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Ultimo periodo: $lastMonthValue ($deltaLabel)',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: _MatchingChart(points: trendPoints)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: _LegendChip(
                color: theme.colorScheme.primary,
                label: 'Trend match/completed',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpentBudgetCard extends StatelessWidget {
  const _SpentBudgetCard({
    required this.totalSpentBudget,
    required this.trendPoints,
    required this.selectedTimeline,
    required this.onTimelineChanged,
  });

  final num totalSpentBudget;
  final List<_TrendPoint> trendPoints;
  final _MatchingTimeline selectedTimeline;
  final ValueChanged<_MatchingTimeline> onTimelineChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastPeriodSpent = trendPoints.isNotEmpty ? trendPoints.last.value : 0;
    final previousPeriodSpent = trendPoints.length > 1
        ? trendPoints[trendPoints.length - 2].value
        : 0;
    final delta = lastPeriodSpent - previousPeriodSpent;
    final deltaLabel = delta == 0
        ? 'stabile vs ${selectedTimeline.comparisonLabel}'
        : '${delta > 0 ? '+' : '-'}${_formatBudget(delta.abs())} vs ${selectedTimeline.comparisonLabel}';

    return _GlassPanel(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Budget speso',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _TimelineMenuButton(
                  selectedTimeline: selectedTimeline,
                  onTimelineChanged: onTimelineChanged,
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Totale speso: ${_formatBudget(totalSpentBudget)}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Ultimo periodo: ${_formatBudget(lastPeriodSpent)} ($deltaLabel)',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: _MatchingChart(points: trendPoints)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: _LegendChip(
                color: theme.colorScheme.primary,
                label: 'Trend budget speso',
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatBudget(num value) {
    if (value == value.roundToDouble()) {
      return 'EUR ${value.toInt()}';
    }
    return 'EUR ${value.toStringAsFixed(2)}';
  }
}

class _MatchingChart extends StatelessWidget {
  const _MatchingChart({required this.points});

  final List<_TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final values = points.map((point) => point.value).toList(growable: false);
    return Column(
      children: [
        Expanded(
          child: CustomPaint(
            painter: _PremiumLineChartPainter(
              values: values,
              lineColor: theme.colorScheme.primary,
              gridColor: theme.colorScheme.outline.withValues(alpha: 0.28),
              dotColor: const Color(0xFFEAF3FF),
              fillTopColor: theme.colorScheme.primary.withValues(alpha: 0.35),
              fillBottomColor: theme.colorScheme.primary.withValues(
                alpha: 0.02,
              ),
            ),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < points.length; i++)
              Expanded(
                child: Text(
                  _labelForIndex(i),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: theme.textTheme.labelSmall,
                ),
              ),
          ],
        ),
      ],
    );
  }

  String _labelForIndex(int index) {
    if (points.length <= 6) return points[index].label;
    if (index.isEven) return points[index].label;
    return '';
  }
}

class _TrendPoint {
  const _TrendPoint({required this.label, required this.value});

  final String label;
  final double value;
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

class _TimelineMenuButton extends StatelessWidget {
  const _TimelineMenuButton({
    required this.selectedTimeline,
    required this.onTimelineChanged,
  });

  final _MatchingTimeline selectedTimeline;
  final ValueChanged<_MatchingTimeline> onTimelineChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        highlightColor: Colors.transparent,
        splashColor: const Color(0xFF8EC8FF).withValues(alpha: 0.1),
        popupMenuTheme: theme.popupMenuTheme.copyWith(
          color: const Color(0xF0162233),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: const Color(0xFF9FC8F8).withValues(alpha: 0.22),
            ),
          ),
          textStyle: theme.textTheme.bodyMedium?.copyWith(
            color: const Color(0xFFEAF3FF),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: PopupMenuButton<_MatchingTimeline>(
        tooltip: 'Cambia timeline',
        onSelected: onTimelineChanged,
        offset: const Offset(0, 8),
        position: PopupMenuPosition.under,
        itemBuilder: (context) => _MatchingTimeline.values
            .map(
              (timeline) => PopupMenuItem<_MatchingTimeline>(
                value: timeline,
                height: 42,
                child: Text(
                  timeline.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: timeline == selectedTimeline
                        ? const Color(0xFFB7D8FF)
                        : const Color(0xFFEAF3FF),
                    fontWeight: timeline == selectedTimeline
                        ? FontWeight.w700
                        : FontWeight.w600,
                  ),
                ),
              ),
            )
            .toList(growable: false),
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.schedule_rounded, size: 13),
              const SizedBox(width: 5),
              Text(
                selectedTimeline.shortLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ],
    );
  }
}

class _PremiumLineChartPainter extends CustomPainter {
  const _PremiumLineChartPainter({
    required this.values,
    required this.lineColor,
    required this.gridColor,
    required this.dotColor,
    required this.fillTopColor,
    required this.fillBottomColor,
  });

  final List<double> values;
  final Color lineColor;
  final Color gridColor;
  final Color dotColor;
  final Color fillTopColor;
  final Color fillBottomColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || size.width <= 0 || size.height <= 0) return;

    const leftInset = 10.0;
    const rightInset = 10.0;
    const topInset = 8.0;
    const bottomInset = 12.0;
    final chartRect = Rect.fromLTWH(
      leftInset,
      topInset,
      size.width - leftInset - rightInset,
      size.height - topInset - bottomInset,
    );

    final maxValue = math.max(1.0, values.reduce(math.max));
    const gridLines = 4;
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (var i = 0; i <= gridLines; i++) {
      final y = chartRect.top + (chartRect.height / gridLines) * i;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
    }

    final stepX = values.length == 1
        ? 0.0
        : chartRect.width / (values.length - 1);
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final normalized = values[i] / maxValue;
      final y = chartRect.bottom - (chartRect.height * normalized);
      final x = chartRect.left + (stepX * i);
      points.add(Offset(x, y));
    }

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final current = points[i];
      final c1 = Offset((prev.dx + current.dx) / 2, prev.dy);
      final c2 = Offset((prev.dx + current.dx) / 2, current.dy);
      linePath.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, current.dx, current.dy);
    }

    final areaPath = Path.from(linePath)
      ..lineTo(points.last.dx, chartRect.bottom)
      ..lineTo(points.first.dx, chartRect.bottom)
      ..close();

    final areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [fillTopColor, fillBottomColor],
      ).createShader(chartRect);
    canvas.drawPath(areaPath, areaPaint);

    final glowPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.drawPath(linePath, glowPaint);

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, linePaint);

    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      canvas.drawCircle(point, 5.5, Paint()..color = dotColor);
      canvas.drawCircle(point, 3.2, Paint()..color = lineColor);

      final valueLabel = values[i].toInt().toString();
      final textPainter = TextPainter(
        text: TextSpan(
          text: valueLabel,
          style: TextStyle(
            color: dotColor.withValues(alpha: 0.95),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();

      final dx = point.dx - (textPainter.width / 2);
      final dy = point.dy - 18;
      textPainter.paint(canvas, Offset(dx, dy));
    }
  }

  @override
  bool shouldRepaint(covariant _PremiumLineChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.dotColor != dotColor ||
        oldDelegate.fillTopColor != fillTopColor ||
        oldDelegate.fillBottomColor != fillBottomColor;
  }
}

class _SubPageTopBarBackground extends StatelessWidget {
  const _SubPageTopBarBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xF20B1322), Color(0xC40A1321), Color(0x9E0A1220)],
        ),
        border: Border(
          bottom: BorderSide(color: Color(0x309FC8F8), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x66040A14),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
    );
  }
}

class _ActiveCampaignsPage extends ConsumerStatefulWidget {
  const _ActiveCampaignsPage();

  @override
  ConsumerState<_ActiveCampaignsPage> createState() =>
      _ActiveCampaignsPageState();
}

class _ActiveCampaignsPageState extends ConsumerState<_ActiveCampaignsPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () =>
          ref.read(brandCampaignsControllerProvider.notifier).loadMyCampaigns(),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmRemoveCampaign(CampaignModel campaign) async {
    final shouldRemove = await showSinapsyConfirmDialog(
      context: context,
      title: 'Eliminare campagna?',
      message:
          'Stai per eliminare "${campaign.title}".\n'
          'La campagna non sara piu visibile nell\'app.\n'
          'Vuoi continuare?',
      confirmLabel: 'Elimina',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!shouldRemove || !mounted) return;

    final ok = await ref
        .read(brandCampaignsControllerProvider.notifier)
        .removeCampaign(campaignId: campaign.id);
    if (!mounted) return;
    if (ok) {
      _showSnack('Campagna eliminata.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(brandCampaignsControllerProvider);
    final activeCampaigns = state.campaigns
        .where((campaign) => campaign.status.toLowerCase() == 'active')
        .toList(growable: false);
    final theme = Theme.of(context);
    final topContentPadding =
        MediaQuery.paddingOf(context).top + kToolbarHeight + 14;

    return Theme(
      data: theme.copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        appBarTheme: theme.appBarTheme.copyWith(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.transparent,
          scrolledUnderElevation: 0,
          foregroundColor: const Color(0xFFEAF3FF),
          systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
        ),
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          flexibleSpace: const _SubPageTopBarBackground(),
          title: Text(
            'Campagne attive',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
          ),
        ),
        body: Stack(
          children: [
            const Positioned.fill(child: LuxuryNeonBackdrop()),
            SafeArea(
              top: false,
              child: Builder(
                builder: (context) {
                  if (state.isLoading && state.campaigns.isEmpty) {
                    return const Center(child: SinapsyLogoLoader());
                  }

                  return RefreshIndicator(
                    onRefresh: () => ref
                        .read(brandCampaignsControllerProvider.notifier)
                        .loadMyCampaigns(),
                    child: activeCampaigns.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              16,
                              topContentPadding,
                              16,
                              16,
                            ),
                            children: const [_ActiveCampaignsEmptyState()],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              16,
                              topContentPadding,
                              16,
                              16,
                            ),
                            itemCount: activeCampaigns.length,
                            separatorBuilder: (_, index) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final campaign = activeCampaigns[index];
                              return _ActiveCampaignTile(
                                campaign: campaign,
                                isRemoving:
                                    state.isRemoving &&
                                    state.removingCampaignId == campaign.id,
                                onRemove: () =>
                                    _confirmRemoveCampaign(campaign),
                              );
                            },
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
}

class _ActiveCampaignsEmptyState extends StatelessWidget {
  const _ActiveCampaignsEmptyState();

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.campaign_rounded,
              size: 30,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 10),
            const Text(
              'Non ci sono campagne attive.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveCampaignTile extends StatelessWidget {
  const _ActiveCampaignTile({
    required this.campaign,
    required this.isRemoving,
    required this.onRemove,
  });

  final CampaignModel campaign;
  final bool isRemoving;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _GlassPanel(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    campaign.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'active',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Budget: ${campaign.budgetLabel}'),
            Text('Categoria: ${campaign.category}'),
            Text('Applicants: ${campaign.applicantsCount}'),
            if (campaign.createdAt != null)
              Text('Creata: ${_formatDate(campaign.createdAt!)}'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isRemoving
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => BrandApplicationsPage(
                                  campaignId: campaign.id,
                                  campaignTitle: campaign.title,
                                ),
                              ),
                            );
                          },
                    icon: const Icon(Icons.people_outline),
                    label: const Text('Applications'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(
                        0xFF8EC8FF,
                      ).withValues(alpha: 0.22),
                      foregroundColor: const Color(0xFFEAF3FF),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: isRemoving ? null : onRemove,
                  icon: isRemoving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: SinapsyLogoLoader(size: 14),
                        )
                      : const Icon(Icons.delete_outline),
                  label: const Text('Elimina'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd';
  }
}

class _MatchedCampaignsPage extends ConsumerStatefulWidget {
  const _MatchedCampaignsPage();

  @override
  ConsumerState<_MatchedCampaignsPage> createState() =>
      _MatchedCampaignsPageState();
}

class _MatchedCampaignsPageState extends ConsumerState<_MatchedCampaignsPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () =>
          ref.read(brandCampaignsControllerProvider.notifier).loadMyCampaigns(),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmRemoveCampaign(CampaignModel campaign) async {
    final shouldRemove = await showSinapsyConfirmDialog(
      context: context,
      title: 'Eliminare campagna?',
      message:
          'Stai per eliminare "${campaign.title}".\n'
          'Anche se gia in match, non sara piu visibile nell\'app.\n'
          'Vuoi continuare?',
      confirmLabel: 'Elimina',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!shouldRemove || !mounted) return;

    final ok = await ref
        .read(brandCampaignsControllerProvider.notifier)
        .removeCampaign(campaignId: campaign.id);
    if (!mounted) return;
    if (ok) {
      _showSnack('Campagna eliminata.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(brandCampaignsControllerProvider);
    final matchedCampaigns = state.campaigns
        .where((campaign) => campaign.status.toLowerCase() == 'matched')
        .toList(growable: false);
    final theme = Theme.of(context);
    final topContentPadding =
        MediaQuery.paddingOf(context).top + kToolbarHeight + 14;

    return Theme(
      data: theme.copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        appBarTheme: theme.appBarTheme.copyWith(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.transparent,
          scrolledUnderElevation: 0,
          foregroundColor: const Color(0xFFEAF3FF),
          systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
        ),
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          flexibleSpace: const _SubPageTopBarBackground(),
          title: Text(
            'Campagne matched',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
          ),
        ),
        body: Stack(
          children: [
            const Positioned.fill(child: LuxuryNeonBackdrop()),
            SafeArea(
              top: false,
              child: Builder(
                builder: (context) {
                  if (state.isLoading && state.campaigns.isEmpty) {
                    return const Center(child: SinapsyLogoLoader());
                  }

                  return RefreshIndicator(
                    onRefresh: () => ref
                        .read(brandCampaignsControllerProvider.notifier)
                        .loadMyCampaigns(),
                    child: matchedCampaigns.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              16,
                              topContentPadding,
                              16,
                              16,
                            ),
                            children: const [_MatchedCampaignsEmptyState()],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              16,
                              topContentPadding,
                              16,
                              16,
                            ),
                            itemCount: matchedCampaigns.length,
                            separatorBuilder: (_, index) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final campaign = matchedCampaigns[index];
                              return _MatchedCampaignTile(
                                campaign: campaign,
                                isRemoving:
                                    state.isRemoving &&
                                    state.removingCampaignId == campaign.id,
                                onRemove: () =>
                                    _confirmRemoveCampaign(campaign),
                              );
                            },
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
}

class _MatchedCampaignsEmptyState extends StatelessWidget {
  const _MatchedCampaignsEmptyState();

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.handshake_rounded,
              size: 30,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 10),
            const Text(
              'Non ci sono ancora campagne matchate.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchedCampaignTile extends StatelessWidget {
  const _MatchedCampaignTile({
    required this.campaign,
    required this.isRemoving,
    required this.onRemove,
  });

  final CampaignModel campaign;
  final bool isRemoving;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _GlassPanel(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    campaign.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade700.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'matched',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Budget: ${campaign.budgetLabel}'),
            Text('Categoria: ${campaign.category}'),
            Text('Applicants: ${campaign.applicantsCount}'),
            if (campaign.createdAt != null)
              Text('Creata: ${_formatDate(campaign.createdAt!)}'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isRemoving
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => BrandApplicationsPage(
                                  campaignId: campaign.id,
                                  campaignTitle: campaign.title,
                                ),
                              ),
                            );
                          },
                    icon: const Icon(Icons.people_outline),
                    label: const Text('Applications'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(
                        0xFF8EC8FF,
                      ).withValues(alpha: 0.22),
                      foregroundColor: const Color(0xFFEAF3FF),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: isRemoving ? null : onRemove,
                  icon: isRemoving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: SinapsyLogoLoader(size: 14),
                        )
                      : const Icon(Icons.delete_outline),
                  label: const Text('Elimina'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd';
  }
}
