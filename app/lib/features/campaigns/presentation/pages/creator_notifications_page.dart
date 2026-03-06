import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/luxury_neon_backdrop.dart';
import '../../../../core/widgets/sinapsy_logo_loader.dart';
import '../../../applications/presentation/controllers/applications_controller.dart';
import '../../../applications/presentation/pages/my_applications_page.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../chats/data/chat_repository.dart';
import '../../../chats/presentation/pages/chat_page.dart';

class CreatorNotificationsPage extends ConsumerStatefulWidget {
  const CreatorNotificationsPage({super.key});

  @override
  ConsumerState<CreatorNotificationsPage> createState() =>
      _CreatorNotificationsPageState();
}

class _CreatorNotificationsPageState
    extends ConsumerState<CreatorNotificationsPage> {
  bool _isLoadingChatNotifications = false;
  String? _chatNotificationsError;
  List<CreatorChatNotificationItem> _chatNotifications =
      const <CreatorChatNotificationItem>[];

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadData);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadData() async {
    await ref
        .read(applicationsControllerProvider.notifier)
        .loadMyApplications();
    await _loadChatNotifications();
  }

  Future<void> _loadChatNotifications() async {
    final creatorId = ref.read(authRepositoryProvider).currentUser?.id.trim();
    if (creatorId == null || creatorId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoadingChatNotifications = false;
        _chatNotificationsError = null;
        _chatNotifications = const <CreatorChatNotificationItem>[];
      });
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingChatNotifications = true;
        _chatNotificationsError = null;
      });
    }

    try {
      final items = await ref
          .read(chatRepositoryProvider)
          .listCreatorChatNotifications(creatorId: creatorId, limit: 25);
      if (!mounted) return;
      setState(() {
        _isLoadingChatNotifications = false;
        _chatNotificationsError = null;
        _chatNotifications = items;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingChatNotifications = false;
        _chatNotificationsError = 'Errore caricamento notifiche chat: $error';
      });
    }
  }

  Future<void> _openMyApplications() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const MyApplicationsPage()),
    );
    await _loadData();
  }

  Future<void> _openChat({required String chatId, String? title}) async {
    final cleanChatId = chatId.trim();
    if (cleanChatId.isEmpty) {
      _showSnack('Chat non disponibile.');
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ChatPage(chatId: cleanChatId, title: title),
      ),
    );
    await _loadData();
  }

  Future<void> _openChatFromApplication(ApplicationItem item) async {
    final existingChatId = (item.chatId ?? '').trim();
    if (existingChatId.isNotEmpty) {
      await _openChat(chatId: existingChatId, title: item.campaignTitle);
      return;
    }

    final canResolve =
        item.campaignId.trim().isNotEmpty &&
        item.brandId.trim().isNotEmpty &&
        item.creatorId.trim().isNotEmpty;
    if (!canResolve) {
      _showSnack('Collaborazione non ancora disponibile.');
      return;
    }

    try {
      final resolved = await ref
          .read(chatRepositoryProvider)
          .getChatIdForMatch(
            campaignId: item.campaignId,
            brandId: item.brandId,
            creatorId: item.creatorId,
          );
      final chatId = (resolved ?? '').trim();
      if (chatId.isEmpty) {
        _showSnack('Collaborazione non ancora disponibile.');
        return;
      }
      await _openChat(chatId: chatId, title: item.campaignTitle);
    } catch (_) {
      _showSnack('Collaborazione non ancora disponibile.');
    }
  }

  String _formatUpdatedAt(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${local.year} $hh:$min';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(applicationsControllerProvider);
    final acceptedApplications =
        state.myApplications
            .where((item) => item.isAccepted)
            .toList(growable: false)
          ..sort((a, b) {
            final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });

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
                onRefresh: _loadData,
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
                          'Notifiche Creator',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.colorTextPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _CreatorNotificationsStatCard(
                            title: 'Richieste\nAccettate',
                            value: '${acceptedApplications.length}',
                            icon: Icons.check_circle_outline_rounded,
                            iconColor: const Color(0xFF3AF8CA),
                            onTap: _openMyApplications,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _CreatorNotificationsStatCard(
                            title: 'Collaborazioni\nRicevute',
                            value: '${_chatNotifications.length}',
                            icon: Icons.handshake_outlined,
                            iconColor: const Color(0xFF56E7FF),
                            onTap: _loadChatNotifications,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Richieste inviate - aggiornamenti',
                      style: textTheme.titleMedium?.copyWith(
                        color: AppTheme.colorTextPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (state.isLoadingMine && acceptedApplications.isEmpty)
                      const SizedBox(
                        height: 100,
                        child: Center(child: SinapsyLogoLoader()),
                      )
                    else if (acceptedApplications.isEmpty)
                      _CreatorNotificationsEmpty(
                        text: 'Nessuna richiesta accettata al momento.',
                      )
                    else
                      ...acceptedApplications.take(8).map((item) {
                        final title =
                            (item.campaignTitle ?? '').trim().isNotEmpty
                            ? item.campaignTitle!.trim()
                            : item.campaignId;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _CreatorApplicationNotificationTile(
                            title: title,
                            createdAtLabel: _formatUpdatedAt(item.createdAt),
                            onOpenChat: () => _openChatFromApplication(item),
                          ),
                        );
                      }),
                    const SizedBox(height: 18),
                    Text(
                      'Collaborazioni ricevute',
                      style: textTheme.titleMedium?.copyWith(
                        color: AppTheme.colorTextPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_isLoadingChatNotifications &&
                        _chatNotifications.isEmpty)
                      const SizedBox(
                        height: 120,
                        child: Center(child: SinapsyLogoLoader()),
                      )
                    else if (_chatNotificationsError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _chatNotificationsError!,
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppTheme.colorStatusDanger,
                          ),
                        ),
                      )
                    else if (_chatNotifications.isEmpty)
                      _CreatorNotificationsEmpty(
                        text: 'Nessuna collaborazione ricevuta per ora.',
                      )
                    else
                      ..._chatNotifications.take(10).map((item) {
                        final title =
                            (item.campaignTitle ?? '').trim().isNotEmpty
                            ? item.campaignTitle!.trim()
                            : 'Collaborazione';
                        final brand =
                            (item.brandUsername ?? '').trim().isNotEmpty
                            ? '@${item.brandUsername!.trim()}'
                            : 'Brand';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _CreatorChatNotificationTile(
                            title: title,
                            brandLabel: brand,
                            updatedAtLabel: _formatUpdatedAt(item.updatedAt),
                            preview: (item.lastMessage ?? '').trim().isNotEmpty
                                ? item.lastMessage!.trim()
                                : 'Nuova collaborazione disponibile.',
                            onOpenChat: () =>
                                _openChat(chatId: item.chatId, title: title),
                          ),
                        );
                      }),
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

class _CreatorApplicationNotificationTile extends StatelessWidget {
  const _CreatorApplicationNotificationTile({
    required this.title,
    required this.createdAtLabel,
    required this.onOpenChat,
  });

  final String title;
  final String createdAtLabel;
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.colorStrokeSubtle.withValues(alpha: 0.92),
        ),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xCC151C2A), Color(0xC6101623)],
        ),
      ),
      child: ListTile(
        leading: const Icon(
          Icons.mark_email_unread_rounded,
          color: Color(0xFF72E2FF),
        ),
        title: Text(
          'Richiesta accettata',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppTheme.colorTextPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (createdAtLabel.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                createdAtLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.colorTextTertiary,
                ),
              ),
            ],
          ],
        ),
        trailing: OutlinedButton(
          onPressed: onOpenChat,
          child: const Text('Apri'),
        ),
      ),
    );
  }
}

class _CreatorChatNotificationTile extends StatelessWidget {
  const _CreatorChatNotificationTile({
    required this.title,
    required this.brandLabel,
    required this.updatedAtLabel,
    required this.preview,
    required this.onOpenChat,
  });

  final String title;
  final String brandLabel;
  final String updatedAtLabel;
  final String preview;
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.colorStrokeSubtle.withValues(alpha: 0.92),
        ),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xCC151C2A), Color(0xC6101623)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$title - $brandLabel',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppTheme.colorTextPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.colorTextSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (updatedAtLabel.isNotEmpty)
                  Expanded(
                    child: Text(
                      updatedAtLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.colorTextTertiary,
                      ),
                    ),
                  )
                else
                  const Spacer(),
                OutlinedButton.icon(
                  onPressed: onOpenChat,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: const Text('Apri chat'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CreatorNotificationsEmpty extends StatelessWidget {
  const _CreatorNotificationsEmpty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.colorStrokeSubtle),
        color: const Color(0x22131B2A),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppTheme.colorTextSecondary),
      ),
    );
  }
}

class _CreatorNotificationsStatCard extends StatelessWidget {
  const _CreatorNotificationsStatCard({
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.colorStrokeSubtle.withValues(alpha: 0.92),
          ),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xCC151C2A), Color(0xC6101623)],
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.colorTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppTheme.colorTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
