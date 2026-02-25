import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../chats/presentation/pages/chat_page.dart';
import '../controllers/applications_controller.dart';

class MyApplicationsPage extends ConsumerStatefulWidget {
  const MyApplicationsPage({super.key});

  @override
  ConsumerState<MyApplicationsPage> createState() => _MyApplicationsPageState();
}

class _MyApplicationsPageState extends ConsumerState<MyApplicationsPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() {
    return ref
        .read(applicationsControllerProvider.notifier)
        .loadMyApplications();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
              return const Center(child: CircularProgressIndicator());
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
                  return _MyApplicationCard(item: state.myApplications[index]);
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
  const _MyApplicationCard({required this.item});

  final ApplicationItem item;

  @override
  Widget build(BuildContext context) {
    final hasChat = item.chatId?.trim().isNotEmpty == true;

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
