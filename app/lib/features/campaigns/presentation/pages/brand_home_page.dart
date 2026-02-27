import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/sinapsy_logo_loader.dart';
import '../../../applications/presentation/pages/brand_applications_page.dart';
import '../../../home/presentation/controllers/home_controller.dart';
import '../../data/campaign_model.dart';
import '../controllers/create_campaign_controller.dart';
import 'create_campaign_page.dart';

class BrandHomePage extends ConsumerStatefulWidget {
  const BrandHomePage({super.key});

  @override
  ConsumerState<BrandHomePage> createState() => _BrandHomePageState();
}

class _BrandHomePageState extends ConsumerState<BrandHomePage> {
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

  Future<void> _openCreateCampaign() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const CreateCampaignPage()),
    );
    if (!mounted || created != true) return;
    await ref.read(brandCampaignsControllerProvider.notifier).loadMyCampaigns();
  }

  Future<void> _logout() async {
    final ok = await ref.read(homeControllerProvider.notifier).logout();
    if (!mounted || !ok) return;
    context.go(AppRouter.authPath);
  }

  Future<void> _confirmRemoveCampaign(CampaignModel campaign) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminare annuncio?'),
          content: Text(
            'Stai per rimuovere "${campaign.title}".\n'
            'L\'annuncio non sara piu visibile nel feed, anche se e gia in match.\n'
            'Vuoi continuare?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Elimina'),
            ),
          ],
        );
      },
    );
    if (shouldRemove != true || !mounted) return;

    final ok = await ref
        .read(brandCampaignsControllerProvider.notifier)
        .removeCampaign(campaignId: campaign.id);
    if (!mounted) return;
    if (ok) {
      _showSnack('Annuncio eliminato.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(brandCampaignsControllerProvider);
    final homeState = ref.watch(homeControllerProvider);

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Brand Dashboard'),
        actions: [
          IconButton(
            onPressed:
                state.isLoading || state.isRemoving || homeState.isLoading
                ? null
                : _openCreateCampaign,
            icon: const Icon(Icons.add),
            tooltip: 'Nuova campagna',
          ),
          IconButton(
            onPressed: homeState.isLoading ? null : _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            if (state.isLoading && state.campaigns.isEmpty) {
              return const Center(child: SinapsyLogoLoader());
            }

            if (state.campaigns.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Non hai ancora campagne attive/matched/completed.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _openCreateCampaign,
                        icon: const Icon(Icons.add),
                        label: const Text('Crea campagna'),
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
                padding: const EdgeInsets.all(16),
                itemCount: state.campaigns.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final campaign = state.campaigns[index];
                  final isRemoving =
                      state.isRemoving &&
                      state.removingCampaignId == campaign.id;
                  return _CampaignTile(
                    campaign: campaign,
                    isRemoving: isRemoving,
                    onRemove: () => _confirmRemoveCampaign(campaign),
                  );
                },
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: state.isLoading || state.isRemoving
            ? null
            : _openCreateCampaign,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _CampaignTile extends StatelessWidget {
  const _CampaignTile({
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
    final statusColor = _statusColor(campaign.status, theme.colorScheme);

    return Card(
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
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    campaign.status,
                    style: TextStyle(
                      color: statusColor,
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
                  child: OutlinedButton.icon(
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

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd';
  }

  Color _statusColor(String status, ColorScheme scheme) {
    switch (status.toLowerCase()) {
      case 'active':
        return scheme.primary;
      case 'matched':
        return Colors.orange.shade700;
      case 'completed':
        return Colors.green.shade700;
      default:
        return scheme.outline;
    }
  }
}
