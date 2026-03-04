import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/sinapsy_confirm_dialog.dart';
import '../../../../core/widgets/sinapsy_logo_loader.dart';
import '../../../chats/presentation/pages/chat_page.dart';
import '../controllers/applications_controller.dart';
import '../../../reviews/data/review_model.dart';
import '../../../reviews/data/review_repository.dart';
import '../../../reviews/presentation/widgets/review_composer_dialog.dart';

class MyApplicationsPage extends ConsumerStatefulWidget {
  const MyApplicationsPage({super.key});

  @override
  ConsumerState<MyApplicationsPage> createState() => _MyApplicationsPageState();
}

class _MyApplicationsPageState extends ConsumerState<MyApplicationsPage> {
  bool _isLoadingMyReviews = false;
  Map<String, ReviewModel> _myReviewsByTarget = const <String, ReviewModel>{};

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    await ref
        .read(applicationsControllerProvider.notifier)
        .loadMyApplications();
    await _loadMyReviews();
  }

  Future<void> _loadMyReviews() async {
    final items = ref.read(applicationsControllerProvider).myApplications;
    final targets = items
        .where((item) => item.brandId.trim().isNotEmpty)
        .map(
          (item) =>
              ReviewTarget(campaignId: item.campaignId, toUserId: item.brandId),
        )
        .toList(growable: false);

    if (targets.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoadingMyReviews = false;
        _myReviewsByTarget = const <String, ReviewModel>{};
      });
      return;
    }

    if (mounted) {
      setState(() => _isLoadingMyReviews = true);
    }
    try {
      final map = await ref
          .read(reviewRepositoryProvider)
          .getMyReviewsForTargets(targets);
      if (!mounted) return;
      setState(() {
        _isLoadingMyReviews = false;
        _myReviewsByTarget = map;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMyReviews = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _withdraw(ApplicationItem item) async {
    final confirm = await showSinapsyConfirmDialog(
      context: context,
      title: 'Abbandonare candidatura?',
      message:
          'Questa candidatura verra rimossa e non sara piu visibile al brand.',
      confirmLabel: 'Conferma',
      destructive: true,
      icon: Icons.warning_amber_rounded,
    );
    if (!confirm || !mounted) return;

    final ok = await ref
        .read(applicationsControllerProvider.notifier)
        .withdrawMyApplication(item);
    if (!mounted) return;
    _showSnack(ok ? 'Candidatura abbandonata.' : 'Operazione fallita.');
  }

  Future<void> _markWorkCompleted(ApplicationItem item) async {
    final result = await ref
        .read(applicationsControllerProvider.notifier)
        .markWorkCompleted(item);
    if (!mounted || !result.success) return;

    if (result.nowCompleted) {
      _showSnack('Lavoro completato: entrambe le conferme ricevute.');
    } else if (result.alreadyCompleted) {
      _showSnack('Questo lavoro risulta gia completato.');
    } else {
      _showSnack('Conferma salvata. In attesa anche dell\'altra parte.');
    }

    await _load();
  }

  Future<void> _leaveReview(
    ApplicationItem item, {
    bool mandatory = false,
  }) async {
    final targetId = item.brandId.trim();
    if (targetId.isEmpty) {
      _showSnack('Brand non disponibile per questa review.');
      return;
    }

    final result = await showReviewComposerDialog(
      context: context,
      title: 'Review collaborazione',
      message:
          'Assegna una valutazione da 1 a 5 stelle al brand per il lavoro completato.',
      mandatory: mandatory,
    );
    if (!mounted || result == null) return;

    try {
      await ref
          .read(reviewRepositoryProvider)
          .submitReview(
            campaignId: item.campaignId,
            toUserId: targetId,
            rating: result.rating,
            text: result.text,
          );
      if (!mounted) return;
      _showSnack('Review inviata.');
      await _loadMyReviews();
    } catch (error) {
      if (!mounted) return;
      _showSnack('Errore invio review: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(applicationsControllerProvider);

    ref.listen<ApplicationsState>(applicationsControllerProvider, (
      previous,
      next,
    ) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        _showSnack(next.errorMessage!);
        ref.read(applicationsControllerProvider.notifier).clearError();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Applications'),
        actions: [
          IconButton(
            onPressed: state.isLoadingMine ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            if (state.isLoadingMine && state.myApplications.isEmpty) {
              return const Center(child: SinapsyLogoLoader());
            }

            if (state.myApplications.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Non hai ancora candidature.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _load,
                        child: const Text('Ricarica'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: state.myApplications.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = state.myApplications[index];
                  final isMutating =
                      state.isMutating && state.activeMutationId == item.id;
                  final reviewKey = reviewTargetKey(
                    campaignId: item.campaignId,
                    toUserId: item.brandId,
                  );
                  final myReview = _myReviewsByTarget[reviewKey];
                  final requiresMandatoryReview =
                      item.isAccepted &&
                      item.isCampaignCompleted &&
                      item.brandId.trim().isNotEmpty &&
                      myReview == null;
                  final showCancelledWarning =
                      item.isCancelledAfterMatch &&
                      !state.dismissedCancelledWarningCampaignIds.contains(
                        item.campaignId,
                      );
                  final showDismissRejectedByBrand =
                      item.status.toLowerCase() == 'rejected' &&
                      !state.dismissedBrandRejectedApplicationIds.contains(
                        item.id,
                      );
                  return _MyApplicationCard(
                    item: item,
                    isMutating: isMutating,
                    isLoadingReview: _isLoadingMyReviews,
                    myReview: myReview,
                    requiresMandatoryReview: requiresMandatoryReview,
                    onWithdraw: item.isPending ? () => _withdraw(item) : null,
                    onMarkWorkCompleted: item.isAccepted
                        ? () => _markWorkCompleted(item)
                        : null,
                    onLeaveReview: requiresMandatoryReview
                        ? () => _leaveReview(item, mandatory: true)
                        : null,
                    onDismissCancelledWarning: showCancelledWarning
                        ? () => ref
                              .read(applicationsControllerProvider.notifier)
                              .dismissCancelledMatchWarning(item.campaignId)
                        : null,
                    onDismissRejectedByBrand: showDismissRejectedByBrand
                        ? () => ref
                              .read(applicationsControllerProvider.notifier)
                              .dismissBrandRejectedApplication(item.id)
                        : null,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MyApplicationCard extends StatelessWidget {
  const _MyApplicationCard({
    required this.item,
    required this.isMutating,
    required this.isLoadingReview,
    required this.myReview,
    required this.requiresMandatoryReview,
    required this.onMarkWorkCompleted,
    required this.onLeaveReview,
    required this.onWithdraw,
    required this.onDismissCancelledWarning,
    required this.onDismissRejectedByBrand,
  });

  final ApplicationItem item;
  final bool isMutating;
  final bool isLoadingReview;
  final ReviewModel? myReview;
  final bool requiresMandatoryReview;
  final VoidCallback? onMarkWorkCompleted;
  final VoidCallback? onLeaveReview;
  final VoidCallback? onWithdraw;
  final VoidCallback? onDismissCancelledWarning;
  final VoidCallback? onDismissRejectedByBrand;

  @override
  Widget build(BuildContext context) {
    final hasChat = item.chatId?.trim().isNotEmpty == true;
    final canMarkCreatorCompletion =
        onMarkWorkCompleted != null &&
        !item.creatorMarkedWorkCompleted &&
        !item.isCampaignCompleted;

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
                    item.campaignTitle?.trim().isNotEmpty == true
                        ? item.campaignTitle!
                        : item.campaignId,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _StatusChip(status: item.status),
              ],
            ),
            const SizedBox(height: 8),
            Text('Campaign ID: ${item.campaignId}'),
            Text('Brand ID: ${item.brandId}'),
            if (item.createdAt != null) ...[
              const SizedBox(height: 4),
              Text('Applied: ${_date(item.createdAt!)}'),
            ],
            if (item.isAccepted) ...[
              const SizedBox(height: 12),
              _WorkCompletionRow(
                brandDone: item.brandMarkedWorkCompleted,
                creatorDone: item.creatorMarkedWorkCompleted,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isMutating || !canMarkCreatorCompletion
                      ? null
                      : onMarkWorkCompleted,
                  icon: Icon(
                    item.creatorMarkedWorkCompleted || item.isCampaignCompleted
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                  ),
                  label: Text(
                    item.creatorMarkedWorkCompleted || item.isCampaignCompleted
                        ? 'Lavoro concluso (confermato)'
                        : 'Segna lavoro concluso',
                  ),
                ),
              ),
            ],
            if (item.isAccepted && item.isCampaignCompleted) ...[
              const SizedBox(height: 10),
              if (isLoadingReview)
                const SizedBox(
                  height: 20,
                  width: 20,
                  child: SinapsyLogoLoader(size: 20),
                )
              else if (myReview != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    'Review inviata: ${myReview!.rating}/5',
                    style: TextStyle(
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else if (onLeaveReview != null)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: isMutating ? null : onLeaveReview,
                    icon: const Icon(Icons.star_rate_rounded),
                    label: Text(
                      requiresMandatoryReview
                          ? 'Lascia review obbligatoria'
                          : 'Lascia review',
                    ),
                  ),
                ),
            ],
            if (onDismissCancelledWarning != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Avvertenza: il brand ha annullato il match per questo annuncio.',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onDismissCancelledWarning,
                      tooltip: 'Chiudi avviso',
                      icon: const Icon(Icons.close),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ],
            if (hasChat) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  final chatId = item.chatId;
                  if (chatId == null) return;
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          ChatPage(chatId: chatId, title: item.campaignTitle),
                    ),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Open chat'),
              ),
            ],
            if (onWithdraw != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: isMutating ? null : onWithdraw,
                  icon: isMutating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: SinapsyLogoLoader(size: 14),
                        )
                      : const Icon(Icons.close),
                  label: const Text('Abbandona richiesta'),
                ),
              ),
            ],
            if (onDismissRejectedByBrand != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: onDismissRejectedByBrand,
                  tooltip: 'Rimuovi richiesta',
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _date(DateTime date) {
    final local = date.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd';
  }
}

class _WorkCompletionRow extends StatelessWidget {
  const _WorkCompletionRow({
    required this.brandDone,
    required this.creatorDone,
  });

  final bool brandDone;
  final bool creatorDone;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _CompletionPill(label: 'Brand', done: brandDone),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _CompletionPill(label: 'Creator', done: creatorDone),
        ),
      ],
    );
  }
}

class _CompletionPill extends StatelessWidget {
  const _CompletionPill({required this.label, required this.done});

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final color = done ? Colors.green.shade700 : Colors.orange.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            '$label ${done ? 'ok' : 'attesa'}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Colors.green.shade700;
      case 'rejected':
        return Colors.red.shade700;
      case 'pending':
      default:
        return Colors.orange.shade700;
    }
  }
}
