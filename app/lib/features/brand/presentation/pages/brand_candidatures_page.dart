import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/luxury_neon_backdrop.dart';
import '../../../../core/widgets/sinapsy_logo_loader.dart';
import '../../../applications/presentation/pages/brand_applications_page.dart';
import '../../../campaigns/data/campaign_model.dart';
import '../../../campaigns/presentation/controllers/create_campaign_controller.dart';

class BrandCandidaturesPage extends ConsumerStatefulWidget {
  const BrandCandidaturesPage({super.key});

  @override
  ConsumerState<BrandCandidaturesPage> createState() =>
      _BrandCandidaturesPageState();
}

class _BrandCandidaturesPageState extends ConsumerState<BrandCandidaturesPage> {
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

  Future<void> _openCampaignApplications(CampaignModel campaign) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BrandApplicationsPage(
          campaignId: campaign.id,
          campaignTitle: campaign.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(brandCampaignsControllerProvider);
    final campaignsWithRequests =
        state.campaigns
            .where(
              (campaign) =>
                  campaign.id.trim().isNotEmpty &&
                  campaign.applicantsCount > 0 &&
                  campaign.status.toLowerCase() != 'cancelled',
            )
            .toList(growable: false)
          ..sort((a, b) {
            final byApplicants = b.applicantsCount.compareTo(a.applicantsCount);
            if (byApplicants != 0) return byApplicants;
            if (a.createdAt == null && b.createdAt == null) return 0;
            if (a.createdAt == null) return 1;
            if (b.createdAt == null) return -1;
            return b.createdAt!.compareTo(a.createdAt!);
          });

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

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Richieste candidature'),
          actions: [
            IconButton(
              onPressed: state.isLoading
                  ? null
                  : () => ref
                        .read(brandCampaignsControllerProvider.notifier)
                        .loadMyCampaigns(),
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Ricarica',
            ),
          ],
        ),
        body: Stack(
          children: [
            const Positioned.fill(child: LuxuryNeonBackdrop()),
            SafeArea(
              top: false,
              child: Builder(
                builder: (context) {
                  if (state.isLoading && campaignsWithRequests.isEmpty) {
                    return const Center(child: SinapsyLogoLoader());
                  }

                  if (campaignsWithRequests.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.people_outline_rounded,
                              size: 34,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Nessuna richiesta creator al momento.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () => ref
                        .read(brandCampaignsControllerProvider.notifier)
                        .loadMyCampaigns(),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                      itemCount: campaignsWithRequests.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final campaign = campaignsWithRequests[index];
                        return _CandidatureCampaignTile(
                          campaign: campaign,
                          onOpen: () => _openCampaignApplications(campaign),
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

class _CandidatureCampaignTile extends StatelessWidget {
  const _CandidatureCampaignTile({
    required this.campaign,
    required this.onOpen,
  });

  final CampaignModel campaign;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.colorStrokeSubtle.withValues(alpha: 0.95),
        ),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xCC151C2A), Color(0xC6101623)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x70040A14),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    campaign.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.colorAccentPrimary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${campaign.applicantsCount} candidature',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Categoria: ${campaign.category}',
              style: TextStyle(
                color: AppTheme.colorTextSecondary.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Budget: ${campaign.budgetLabel}',
              style: TextStyle(
                color: AppTheme.colorTextSecondary.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.people_outline_rounded),
                label: const Text('Apri richieste'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.colorAccentPrimary.withValues(
                    alpha: 0.2,
                  ),
                  foregroundColor: AppTheme.colorTextPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
