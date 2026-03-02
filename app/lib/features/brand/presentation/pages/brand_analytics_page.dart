import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/luxury_neon_backdrop.dart';
import '../../../../core/widgets/sinapsy_logo_loader.dart';
import '../../../campaigns/presentation/controllers/create_campaign_controller.dart';
import '../../../campaigns/presentation/pages/brand_home_page.dart';

class BrandAnalyticsPage extends ConsumerStatefulWidget {
  const BrandAnalyticsPage({super.key});

  @override
  ConsumerState<BrandAnalyticsPage> createState() => _BrandAnalyticsPageState();
}

class _BrandAnalyticsPageState extends ConsumerState<BrandAnalyticsPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () =>
          ref.read(brandCampaignsControllerProvider.notifier).loadMyCampaigns(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(brandCampaignsControllerProvider);
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

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: RepaintBoundary(child: LuxuryNeonBackdrop()),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.isLoading && campaigns.isEmpty)
                    const Expanded(child: Center(child: SinapsyLogoLoader()))
                  else ...[
                    BrandAnalyticsTrendSection(campaigns: campaigns),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView(
                        children: [
                          _AnalyticsMetricRow(
                            label: 'Campagne attive',
                            value: '$activeCampaigns',
                          ),
                          _AnalyticsMetricRow(
                            label: 'Match totali',
                            value: '$matchedCampaigns',
                          ),
                          _AnalyticsMetricRow(
                            label: 'Budget speso',
                            value: _formatBudget(spentBudget),
                          ),
                          const _AnalyticsMetricRow(
                            label: 'Conversazioni aperte',
                            value: '--',
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
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

class _AnalyticsMetricRow extends StatelessWidget {
  const _AnalyticsMetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
