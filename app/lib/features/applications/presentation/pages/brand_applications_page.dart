import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/sinapsy_logo_loader.dart';
import '../../../chats/presentation/pages/chat_page.dart';
import '../controllers/applications_controller.dart';

class BrandApplicationsPage extends ConsumerStatefulWidget {
  const BrandApplicationsPage({
    required this.campaignId,
    this.campaignTitle,
    super.key,
  });

  final String campaignId;
  final String? campaignTitle;

  @override
  ConsumerState<BrandApplicationsPage> createState() =>
      _BrandApplicationsPageState();
}

class _BrandApplicationsPageState extends ConsumerState<BrandApplicationsPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() {
    return ref
        .read(applicationsControllerProvider.notifier)
        .loadBrandApplications(campaignId: widget.campaignId);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _accept(ApplicationItem item) async {
    final ok = await ref
        .read(applicationsControllerProvider.notifier)
        .acceptApplication(item);
    if (!mounted) return;
    if (ok) {
      _showSnack('Application accepted. Match created.');
    }
  }

  Future<void> _reject(ApplicationItem item) async {
    final ok = await ref
        .read(applicationsControllerProvider.notifier)
        .rejectApplication(item);
    if (!mounted) return;
    if (ok) {
      _showSnack('Application rejected.');
    }
  }

  void _dismissRejected(ApplicationItem item) {
    ref
        .read(applicationsControllerProvider.notifier)
        .dismissRejectedApplicationForBrandView(item.id);
  }

  Future<void> _openChat(ApplicationItem item) async {
    final chatId = item.chatId?.trim();
    if (chatId == null || chatId.isEmpty) {
      _showSnack('Chat non ancora disponibile per questa candidatura.');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatPage(
          chatId: chatId,
          title: item.creatorUsername?.trim().isNotEmpty == true
              ? item.creatorUsername!
              : 'Chat',
        ),
      ),
    );
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

    final title = widget.campaignTitle?.trim().isNotEmpty == true
        ? widget.campaignTitle!
        : 'Campaign applications';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            onPressed: state.isLoadingBrand ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            if (state.isLoadingBrand && state.brandApplications.isEmpty) {
              return const Center(child: SinapsyLogoLoader());
            }

            if (state.brandApplications.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Nessuna candidatura per questa campagna.',
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
                itemCount: state.brandApplications.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final hasAcceptedCreator = state.brandApplications.any(
                    (candidate) => candidate.status.toLowerCase() == 'accepted',
                  );
                  final item = state.brandApplications[index];
                  final isMutating =
                      state.isMutating && state.activeMutationId == item.id;
                  final canAccept = item.isPending && !hasAcceptedCreator;
                  return _BrandApplicationCard(
                    item: item,
                    isMutating: isMutating,
                    onAccept: canAccept ? () => _accept(item) : null,
                    onReject: item.isPending ? () => _reject(item) : null,
                    onDismissRejected: item.status.toLowerCase() == 'rejected'
                        ? () => _dismissRejected(item)
                        : null,
                    onOpenChat: item.chatId?.trim().isNotEmpty == true
                        ? () => _openChat(item)
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

class _BrandApplicationCard extends StatelessWidget {
  const _BrandApplicationCard({
    required this.item,
    required this.isMutating,
    required this.onAccept,
    required this.onReject,
    required this.onDismissRejected,
    required this.onOpenChat,
  });

  final ApplicationItem item;
  final bool isMutating;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onDismissRejected;
  final VoidCallback? onOpenChat;

  @override
  Widget build(BuildContext context) {
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
                    item.creatorUsername?.trim().isNotEmpty == true
                        ? item.creatorUsername!
                        : item.creatorId,
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
            Text('Creator ID: ${item.creatorId}'),
            if (item.createdAt != null) ...[
              const SizedBox(height: 4),
              Text('Applied: ${_date(item.createdAt!)}'),
            ],
            if (item.chatId != null && item.chatId!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Chat ID: ${item.chatId}'),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onOpenChat,
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Open chat'),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isMutating ? null : onReject,
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isMutating ? null : onAccept,
                    child: isMutating
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: SinapsyLogoLoader(size: 18),
                          )
                        : const Text('Accept'),
                  ),
                ),
              ],
            ),
            if (onDismissRejected != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: onDismissRejected,
                  tooltip: 'Rimuovi dalla lista',
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
