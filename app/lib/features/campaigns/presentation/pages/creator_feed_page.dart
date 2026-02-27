import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/sinapsy_logo_loader.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../../data/campaign_model.dart';
import '../controllers/creator_feed_controller.dart';

class CreatorFeedPage extends ConsumerStatefulWidget {
  const CreatorFeedPage({super.key});

  @override
  ConsumerState<CreatorFeedPage> createState() => _CreatorFeedPageState();
}

class _CreatorFeedPageState extends ConsumerState<CreatorFeedPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      ref.read(profileControllerProvider.notifier).watchMyProfile();
      await ref.read(profileControllerProvider.notifier).loadMyProfile();
      await ref.read(creatorFeedControllerProvider.notifier).loadFeed();
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _apply(CampaignModel campaign) async {
    final profile = ref.read(profileControllerProvider).profile;
    final ok = await ref
        .read(creatorFeedControllerProvider.notifier)
        .applyToCampaign(campaign: campaign, profile: profile);
    if (!mounted || !ok) return;
    _showSnack('Candidatura inviata con successo.');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(creatorFeedControllerProvider);

    ref.listen<CreatorFeedState>(creatorFeedControllerProvider, (
      previous,
      next,
    ) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        _showSnack(next.errorMessage!);
        ref.read(creatorFeedControllerProvider.notifier).clearError();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Creator Feed'),
        actions: [
          IconButton(
            onPressed: state.isLoading
                ? null
                : () => ref
                      .read(creatorFeedControllerProvider.notifier)
                      .loadFeed(),
            icon: const Icon(Icons.refresh),
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
                        'Nessun annuncio attivo al momento.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => ref
                            .read(creatorFeedControllerProvider.notifier)
                            .loadFeed(),
                        child: const Text('Ricarica'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: state.campaigns.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final campaign = state.campaigns[index];
                return _CampaignCard(
                  campaign: campaign,
                  isApplying:
                      state.isApplying &&
                      state.applyingCampaignId == campaign.id,
                  onApply: () => _apply(campaign),
                  onSkip: () => ref
                      .read(creatorFeedControllerProvider.notifier)
                      .skipCampaign(campaign.id),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  const _CampaignCard({
    required this.campaign,
    required this.isApplying,
    required this.onApply,
    required this.onSkip,
  });

  final CampaignModel campaign;
  final bool isApplying;
  final VoidCallback onApply;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 180,
            child: _CampaignCoverImage(url: campaign.coverImageUrl),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  campaign.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Budget: ${campaign.budgetLabel}',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  _requirementsLabel(campaign),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isApplying ? null : onSkip,
                        child: const Text('Skip'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isApplying ? null : onApply,
                        child: isApplying
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: SinapsyLogoLoader(size: 18),
                              )
                            : const Text('Apply'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _requirementsLabel(CampaignModel campaign) {
    final minFollowersLabel = campaign.minFollowers != null
        ? '${campaign.minFollowers}+ followers'
        : 'followers non specificati';
    final locationLabel = campaign.locationRequired?.trim().isNotEmpty == true
        ? 'location preferita: ${campaign.locationRequired!}'
        : 'location libera';
    return 'Req: $minFollowersLabel | $locationLabel | ${campaign.category}';
  }
}

class _CampaignCoverImage extends StatelessWidget {
  const _CampaignCoverImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return Container(
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: const Icon(Icons.image_outlined, size: 40),
      );
    }

    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey.shade200,
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_outlined, size: 40),
        );
      },
    );
  }
}
