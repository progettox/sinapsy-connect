import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/luxury_neon_backdrop.dart';
import '../../../../core/widgets/sinapsy_logo_loader.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../campaigns/presentation/controllers/create_campaign_controller.dart';
import '../../../chats/data/chat_repository.dart';
import '../../../chats/presentation/pages/chat_page.dart';
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
  bool _isLoadingChatNotifications = false;
  String? _chatNotificationsError;
  List<BrandChatNotificationItem> _chatNotifications =
      const <BrandChatNotificationItem>[];

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadData);
  }

  Future<void> _loadData() async {
    await ref.read(brandNotificationsBadgeControllerProvider.notifier).init();
    await ref.read(brandCampaignsControllerProvider.notifier).loadMyCampaigns();
    await _loadChatNotifications();
    await ref
        .read(brandNotificationsBadgeControllerProvider.notifier)
        .markAllSeen();
  }

  Future<void> _loadChatNotifications() async {
    final brandId = ref.read(authRepositoryProvider).currentUser?.id.trim();
    if (brandId == null || brandId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoadingChatNotifications = false;
        _chatNotificationsError = null;
        _chatNotifications = const <BrandChatNotificationItem>[];
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
          .listBrandChatNotifications(brandId: brandId, limit: 25);
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

  Future<void> _openChatFromNotification(BrandChatNotificationItem item) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ChatPage(
          chatId: item.chatId,
          title: item.creatorUsername?.trim().isNotEmpty == true
              ? item.creatorUsername!
              : (item.campaignTitle?.trim().isNotEmpty == true
                    ? item.campaignTitle!
                    : 'Chat'),
        ),
      ),
    );
  }

  String _formatUpdatedAt(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$dd/$mm ${local.year} • $hh:$min';
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
                    Text(
                      'Notifiche recenti',
                      style: textTheme.titleMedium?.copyWith(
                        color: AppTheme.colorTextPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_isLoadingChatNotifications &&
                        _chatNotifications.isEmpty) ...[
                      const SizedBox(
                        height: 120,
                        child: Center(child: SinapsyLogoLoader()),
                      ),
                    ] else if (_chatNotificationsError != null) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          _chatNotificationsError!,
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppTheme.colorStatusDanger,
                          ),
                        ),
                      ),
                    ] else if (_chatNotifications.isEmpty) ...[
                      SizedBox(
                        height: 220,
                        child: Center(
                          child: Text(
                            'Nessuna notifica per ora',
                            style: textTheme.bodyLarge?.copyWith(
                              color: AppTheme.colorTextSecondary,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      ..._chatNotifications.take(10).map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _BrandChatNotificationTile(
                            campaignTitle: item.campaignTitle,
                            creatorUsername: item.creatorUsername,
                            lastMessage: item.lastMessage,
                            updatedAtLabel: _formatUpdatedAt(item.updatedAt),
                            onOpenChat: () => _openChatFromNotification(item),
                          ),
                        );
                      }),
                    ],
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

class _BrandChatNotificationTile extends StatelessWidget {
  const _BrandChatNotificationTile({
    required this.campaignTitle,
    required this.creatorUsername,
    required this.lastMessage,
    required this.updatedAtLabel,
    required this.onOpenChat,
  });

  final String? campaignTitle;
  final String? creatorUsername;
  final String? lastMessage;
  final String updatedAtLabel;
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) {
    final title = campaignTitle?.trim().isNotEmpty == true
        ? campaignTitle!.trim()
        : 'Campagna';
    final creator = creatorUsername?.trim().isNotEmpty == true
        ? '@${creatorUsername!.trim()}'
        : 'Creator';
    final preview = lastMessage?.trim().isNotEmpty == true
        ? lastMessage!.trim()
        : 'La chat e pronta: apri conversazione.';

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
            Row(
              children: [
                const Icon(
                  Icons.mark_email_unread_rounded,
                  size: 17,
                  color: Color(0xFF72E2FF),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Candidatura accettata • Apri chat',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.colorTextPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$title • $creator',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.colorTextSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
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
