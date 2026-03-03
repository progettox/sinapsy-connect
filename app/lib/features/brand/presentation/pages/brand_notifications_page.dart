import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/luxury_neon_backdrop.dart';
import '../../../../core/widgets/sinapsy_logo_loader.dart';
import '../../../campaigns/presentation/controllers/create_campaign_controller.dart';
import '../controllers/brand_notifications_badge_controller.dart';
import '../../../campaigns/presentation/pages/brand_home_page.dart';
import 'brand_candidatures_page.dart';

class BrandNotificationsPage extends ConsumerStatefulWidget {
  const BrandNotificationsPage({super.key});

  @override
  ConsumerState<BrandNotificationsPage> createState() =>
      _BrandNotificationsPageState();
}

class _BrandNotificationsPageState
    extends ConsumerState<BrandNotificationsPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      await ref.read(brandNotificationsBadgeControllerProvider.notifier).init();
      await ref
          .read(brandNotificationsBadgeControllerProvider.notifier)
          .markAllSeen();
      await ref
          .read(brandCampaignsControllerProvider.notifier)
          .loadMyCampaigns();
    });
  }

  Future<void> _openActiveCampaigns() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const ActiveCampaignsPage()),
    );
  }

  Future<void> _openCandidatureRequests() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const BrandCandidaturesPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(brandCampaignsControllerProvider);
    final activeCampaigns = state.campaigns
        .where((campaign) => campaign.status.toLowerCase() == 'active')
        .length;
    final candidatureCount = state.campaigns.fold<int>(
      0,
      (total, campaign) => total + campaign.applicantsCount,
    );
    final theme = Theme.of(context);
    final textTheme = GoogleFonts.interTextTheme(theme.textTheme);

    return Theme(
      data: theme.copyWith(textTheme: textTheme),
      child: Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(child: LuxuryNeonBackdrop()),
            SafeArea(
              child: RefreshIndicator(
                onRefresh: () => ref
                    .read(brandCampaignsControllerProvider.notifier)
                    .loadMyCampaigns(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Centro notifiche',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.colorTextPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (state.isLoading && state.campaigns.isEmpty)
                      const SizedBox(
                        height: 110,
                        child: Center(child: SinapsyLogoLoader()),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: _NotificationsStatCard(
                              title: 'Campagne\nAttive',
                              value: '$activeCampaigns',
                              icon: Icons.show_chart_rounded,
                              iconColor: const Color(0xFF3AF8CA),
                              onTap: _openActiveCampaigns,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _NotificationsStatCard(
                              title: 'Candidature',
                              value: '$candidatureCount',
                              icon: Icons.groups_2_outlined,
                              iconColor: const Color(0xFF56E7FF),
                              onTap: _openCandidatureRequests,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 22),
                    if (state.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Text(
                          state.errorMessage!,
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppTheme.colorStatusDanger,
                          ),
                        ),
                      ),
                    SizedBox(
                      height: 260,
                      child: Center(
                        child: Text(
                          'Nessuna notifica per ora',
                          style: textTheme.bodyLarge?.copyWith(
                            color: AppTheme.colorTextSecondary,
                          ),
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

class _NotificationsStatCard extends StatelessWidget {
  const _NotificationsStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(16);
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.1,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFD4E2FF),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1,
            ),
          ),
        ],
      ),
    );

    return SizedBox(
      height: 94,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border.all(
              color: AppTheme.colorStrokeSubtle.withValues(alpha: 0.9),
            ),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF161C2B), Color(0xFF101420)],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x70040A14),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: borderRadius,
            onTap: onTap,
            child: content,
          ),
        ),
      ),
    );
  }
}
