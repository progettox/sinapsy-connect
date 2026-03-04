import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/luxury_neon_backdrop.dart';
import '../../../../core/widgets/sinapsy_logo_loader.dart';
import '../../../chats/presentation/pages/chat_page.dart';
import '../../../reviews/data/review_model.dart';
import '../../../reviews/data/review_repository.dart';
import '../../../reviews/presentation/widgets/review_composer_dialog.dart';
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
        .loadBrandApplications(campaignId: widget.campaignId);
    await _loadMyReviews();
  }

  Future<void> _loadMyReviews() async {
    final items = ref.read(applicationsControllerProvider).brandApplications;
    final targets = items
        .where((item) => item.creatorId.trim().isNotEmpty)
        .map(
          (item) => ReviewTarget(
            campaignId: item.campaignId,
            toUserId: item.creatorId,
          ),
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
    final targetId = item.creatorId.trim();
    if (targetId.isEmpty) {
      _showSnack('Creator non disponibile per questa review.');
      return;
    }

    final result = await showReviewComposerDialog(
      context: context,
      title: 'Review collaborazione',
      message:
          'Assegna una valutazione da 1 a 5 stelle al creator per il lavoro completato.',
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
                        final reviewKey = reviewTargetKey(
                          campaignId: item.campaignId,
                          toUserId: item.creatorId,
                        );
                        final myReview = _myReviewsByTarget[reviewKey];
                        final requiresMandatoryReview =
                            item.isAccepted &&
                            item.isCampaignCompleted &&
                            item.creatorId.trim().isNotEmpty &&
                            myReview == null;
                        final isMutating =
                            state.isMutating &&
                            state.activeMutationId == item.id;
                        final canAccept = item.isPending && !hasAcceptedCreator;
                        return _BrandApplicationCard(
                          item: item,
                          isMutating: isMutating,
                          isLoadingReview: _isLoadingMyReviews,
                          myReview: myReview,
                          requiresMandatoryReview: requiresMandatoryReview,
                          onAccept: canAccept ? () => _accept(item) : null,
                          onReject: item.isPending ? () => _reject(item) : null,
                          onDismissRejected:
                              item.status.toLowerCase() == 'rejected'
                              ? () => _dismissRejected(item)
                              : null,
                          onMarkWorkCompleted: item.isAccepted
                              ? () => _markWorkCompleted(item)
                              : null,
                          onLeaveReview: requiresMandatoryReview
                              ? () => _leaveReview(item, mandatory: true)
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
    required this.isLoadingReview,
    required this.myReview,
    required this.requiresMandatoryReview,
    required this.onAccept,
    required this.onReject,
    required this.onDismissRejected,
    required this.onMarkWorkCompleted,
    required this.onLeaveReview,
    required this.onOpenChat,
  });

  final ApplicationItem item;
  final bool isMutating;
  final bool isLoadingReview;
  final ReviewModel? myReview;
  final bool requiresMandatoryReview;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onDismissRejected;
  final VoidCallback? onMarkWorkCompleted;
  final VoidCallback? onLeaveReview;
  final VoidCallback? onOpenChat;

  @override
  Widget build(BuildContext context) {
    final creatorLabel = item.creatorUsername?.trim().isNotEmpty == true
        ? '@${item.creatorUsername!}'
        : 'Creator';
    final creatorTag = item.creatorCategory?.trim().isNotEmpty == true
        ? item.creatorCategory!.trim()
        : (item.creatorRole?.trim().isNotEmpty == true
              ? item.creatorRole!.trim()
              : 'Creator');

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
                  icon: Icons.category_rounded,
                  text: creatorTag,
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
                  onPressed:
                      isMutating ||
                          item.brandMarkedWorkCompleted ||
                          item.isCampaignCompleted
                      ? null
                      : onMarkWorkCompleted,
                  icon: Icon(
                    item.brandMarkedWorkCompleted || item.isCampaignCompleted
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                  ),
                  label: Text(
                    item.brandMarkedWorkCompleted || item.isCampaignCompleted
                        ? 'Lavoro concluso (confermato)'
                        : 'Segna lavoro concluso',
                  ),
                ),
              ),
            ] else ...[
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
                              AppTheme.colorAccentPrimary.withValues(
                                alpha: 0.82,
                              ),
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
                            disabledForegroundColor:
                                AppTheme.colorTextSecondary,
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
    final color = done ? const Color(0xFF58D68D) : const Color(0xFFFFC674);
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
