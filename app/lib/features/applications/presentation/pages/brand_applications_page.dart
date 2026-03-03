import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/luxury_neon_backdrop.dart';
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
    final theme = Theme.of(context);
    final pageTheme = theme.copyWith(
      textTheme: GoogleFonts.plusJakartaSansTextTheme(theme.textTheme),
      primaryTextTheme: GoogleFonts.plusJakartaSansTextTheme(
        theme.primaryTextTheme,
      ),
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        foregroundColor: const Color(0xFFEAF3FF),
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
    );

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

    return Theme(
      data: pageTheme,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          flexibleSpace: const _ApplicationsTopBarBackground(),
          title: Text(
            title,
            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                onPressed: state.isLoadingBrand ? null : _load,
                icon: const Icon(Icons.refresh_rounded),
                style: IconButton.styleFrom(
                  foregroundColor: AppTheme.colorTextPrimary,
                  backgroundColor: AppTheme.colorBgElevated.withValues(
                    alpha: 0.42,
                  ),
                  side: BorderSide(
                    color: AppTheme.colorStrokeSubtle.withValues(alpha: 0.95),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            const Positioned.fill(child: LuxuryNeonBackdrop()),
            SafeArea(
              child: Builder(
                builder: (context) {
                  if (state.isLoadingBrand && state.brandApplications.isEmpty) {
                    return const Center(child: SinapsyLogoLoader());
                  }

                  if (state.brandApplications.isEmpty) {
                    return _EmptyApplicationsState(
                      onReload: _load,
                      isLoading: state.isLoadingBrand,
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
                          (candidate) =>
                              candidate.status.toLowerCase() == 'accepted',
                        );
                        final item = state.brandApplications[index];
                        final isMutating =
                            state.isMutating &&
                            state.activeMutationId == item.id;
                        final canAccept = item.isPending && !hasAcceptedCreator;
                        return _BrandApplicationCard(
                          item: item,
                          isMutating: isMutating,
                          onAccept: canAccept ? () => _accept(item) : null,
                          onReject: item.isPending ? () => _reject(item) : null,
                          onDismissRejected:
                              item.status.toLowerCase() == 'rejected'
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
          ],
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
    final creatorLabel = item.creatorUsername?.trim().isNotEmpty == true
        ? '@${item.creatorUsername!}'
        : item.creatorId;

    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    creatorLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.colorTextPrimary,
                    ),
                  ),
                ),
                _StatusChip(status: item.status),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ApplicationMetaPill(
                  icon: Icons.perm_identity_rounded,
                  text: 'Creator ID ${item.creatorId}',
                ),
                if (item.createdAt != null)
                  _ApplicationMetaPill(
                    icon: Icons.calendar_today_outlined,
                    text: 'Candidato il ${_date(item.createdAt!)}',
                  ),
              ],
            ),
            if (item.chatId != null && item.chatId!.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 38,
                child: OutlinedButton.icon(
                  onPressed: onOpenChat,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 17),
                  label: const Text('Apri chat'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB47BFF),
                    side: BorderSide(
                      color: AppTheme.colorStrokeSubtle.withValues(alpha: 0.95),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: OutlinedButton(
                      onPressed: isMutating ? null : onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE8D6FF),
                        side: BorderSide(
                          color: AppTheme.colorStrokeSubtle.withValues(
                            alpha: 0.95,
                          ),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: const Text('Rifiuta'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.colorAccentPrimary.withValues(alpha: 0.82),
                            const Color(0xFF8E47F7).withValues(alpha: 0.88),
                          ],
                        ),
                        border: Border.all(color: const Color(0x66C89EFF)),
                      ),
                      child: ElevatedButton(
                        onPressed: isMutating ? null : onAccept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: AppTheme.colorTextPrimary,
                          disabledForegroundColor: AppTheme.colorTextSecondary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: isMutating
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: SinapsyLogoLoader(size: 18),
                              )
                            : const Text('Accetta'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (onDismissRejected != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: isMutating ? null : onDismissRejected,
                  tooltip: 'Rimuovi dalla lista',
                  icon: const Icon(Icons.close_rounded),
                  color: AppTheme.colorTextSecondary,
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

class _ApplicationsTopBarBackground extends StatelessWidget {
  const _ApplicationsTopBarBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.colorBgPrimary.withValues(alpha: 0.97),
            AppTheme.colorBgPrimary.withValues(alpha: 0.82),
            Colors.transparent,
          ],
          stops: const [0, 0.62, 1],
        ),
      ),
    );
  }
}

class _EmptyApplicationsState extends StatelessWidget {
  const _EmptyApplicationsState({
    required this.onReload,
    required this.isLoading,
  });

  final Future<void> Function() onReload;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: _GlassCard(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.colorAccentPrimary.withValues(
                        alpha: 0.14,
                      ),
                      border: Border.all(
                        color: AppTheme.colorAccentPrimary.withValues(
                          alpha: 0.42,
                        ),
                      ),
                    ),
                    child: const Icon(
                      Icons.inbox_outlined,
                      color: Color(0xFFBC80FF),
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Nessuna candidatura per questa campagna.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.colorTextPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 40,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.colorAccentPrimary.withValues(alpha: 0.85),
                            const Color(0xFF8E47F7).withValues(alpha: 0.9),
                          ],
                        ),
                        border: Border.all(color: const Color(0x66C89EFF)),
                      ),
                      child: ElevatedButton(
                        onPressed: isLoading ? null : onReload,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: AppTheme.colorTextPrimary,
                          disabledForegroundColor: AppTheme.colorTextSecondary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: SinapsyLogoLoader(size: 18),
                              )
                            : const Text('Ricarica'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ApplicationMetaPill extends StatelessWidget {
  const _ApplicationMetaPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.colorBgElevated.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppTheme.colorStrokeSubtle.withValues(alpha: 0.95),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.colorTextSecondary),
          const SizedBox(width: 5),
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.colorTextSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.colorStrokeSubtle.withValues(alpha: 0.95),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.colorBgSecondary.withValues(alpha: 0.86),
                AppTheme.colorBgCard.withValues(alpha: 0.92),
                AppTheme.colorBgElevated.withValues(alpha: 0.82),
              ],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x5A000000),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
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
    final normalized = status.trim().isEmpty ? 'pending' : status.toLowerCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Text(
        normalized,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          letterSpacing: 0.2,
          height: 1,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return const Color(0xFF58D68D);
      case 'rejected':
        return const Color(0xFFFF7B8E);
      case 'pending':
      default:
        return const Color(0xFFFFC674);
    }
  }
}
