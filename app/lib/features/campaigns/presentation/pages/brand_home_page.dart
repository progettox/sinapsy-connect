import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/luxury_neon_backdrop.dart';
import '../../../../core/widgets/sinapsy_logo_loader.dart';
import '../../../applications/presentation/pages/brand_applications_page.dart';
import '../../../home/presentation/controllers/home_controller.dart';
import '../../data/campaign_model.dart';
import '../controllers/create_campaign_controller.dart';
import 'create_campaign_page.dart';

enum _MatchingTimeline { lastWeek, lastMonth, sixMonths, lastYear }

extension _MatchingTimelineX on _MatchingTimeline {
  String get label {
    switch (this) {
      case _MatchingTimeline.lastWeek:
        return 'Ultima settimana';
      case _MatchingTimeline.lastMonth:
        return 'Ultimo mese';
      case _MatchingTimeline.sixMonths:
        return 'Ultimi 6 mesi';
      case _MatchingTimeline.lastYear:
        return 'Ultimo anno';
    }
  }

  String get comparisonLabel {
    switch (this) {
      case _MatchingTimeline.lastWeek:
        return 'giorno precedente';
      case _MatchingTimeline.lastMonth:
        return 'settimana precedente';
      case _MatchingTimeline.sixMonths:
      case _MatchingTimeline.lastYear:
        return 'mese precedente';
    }
  }

  String get shortLabel {
    switch (this) {
      case _MatchingTimeline.lastWeek:
        return '7G';
      case _MatchingTimeline.lastMonth:
        return '1M';
      case _MatchingTimeline.sixMonths:
        return '6M';
      case _MatchingTimeline.lastYear:
        return '1A';
    }
  }
}

class BrandHomePage extends ConsumerStatefulWidget {
  const BrandHomePage({super.key});

  @override
  ConsumerState<BrandHomePage> createState() => _BrandHomePageState();
}

class _BrandHomePageState extends ConsumerState<BrandHomePage> {
  _MatchingTimeline _selectedTimeline = _MatchingTimeline.sixMonths;

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

  List<_TrendPoint> _buildMatchingTrend(
    List<CampaignModel> campaigns,
    _MatchingTimeline timeline,
  ) {
    switch (timeline) {
      case _MatchingTimeline.lastWeek:
        return _buildDailyTrend(campaigns, days: 7);
      case _MatchingTimeline.lastMonth:
        return _buildWeeklyTrend(campaigns, weeks: 4);
      case _MatchingTimeline.sixMonths:
        return _buildMonthlyTrend(campaigns, months: 6);
      case _MatchingTimeline.lastYear:
        return _buildMonthlyTrend(campaigns, months: 12);
    }
  }

  List<_TrendPoint> _buildDailyTrend(
    List<CampaignModel> campaigns, {
    required int days,
  }) {
    final today = DateTime.now();
    final dayAnchors = List<DateTime>.generate(
      days,
      (index) =>
          DateTime(today.year, today.month, today.day - (days - 1 - index)),
    );

    return dayAnchors
        .map((dayStart) {
          final dayEnd = dayStart.add(const Duration(days: 1));
          return _TrendPoint(
            label: _weekdayLabel(dayStart),
            value: _countMatchesInRange(campaigns, dayStart, dayEnd).toDouble(),
          );
        })
        .toList(growable: false);
  }

  List<_TrendPoint> _buildWeeklyTrend(
    List<CampaignModel> campaigns, {
    required int weeks,
  }) {
    final now = DateTime.now();
    final endBoundary = DateTime(now.year, now.month, now.day + 1);

    return List<_TrendPoint>.generate(weeks, (index) {
      final offset = weeks - 1 - index;
      final intervalEnd = endBoundary.subtract(Duration(days: offset * 7));
      final intervalStart = intervalEnd.subtract(const Duration(days: 7));
      return _TrendPoint(
        label: _dayMonthLabel(intervalStart),
        value: _countMatchesInRange(
          campaigns,
          intervalStart,
          intervalEnd,
        ).toDouble(),
      );
    });
  }

  List<_TrendPoint> _buildMonthlyTrend(
    List<CampaignModel> campaigns, {
    required int months,
  }) {
    final now = DateTime.now();
    final monthAnchors = List<DateTime>.generate(
      months,
      (index) => DateTime(now.year, now.month - (months - 1 - index), 1),
    );

    return monthAnchors
        .map((monthStart) {
          final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);
          return _TrendPoint(
            label: _monthLabel(monthStart),
            value: _countMatchesInRange(
              campaigns,
              monthStart,
              monthEnd,
            ).toDouble(),
          );
        })
        .toList(growable: false);
  }

  int _countMatchesInRange(
    List<CampaignModel> campaigns,
    DateTime start,
    DateTime end,
  ) {
    return campaigns.where((campaign) {
      final createdAt = campaign.createdAt;
      if (createdAt == null) return false;
      final status = campaign.status.toLowerCase();
      if (status != 'matched' && status != 'completed') return false;
      return !createdAt.isBefore(start) && createdAt.isBefore(end);
    }).length;
  }

  String _weekdayLabel(DateTime date) {
    const shortWeekdays = <String>[
      'Lun',
      'Mar',
      'Mer',
      'Gio',
      'Ven',
      'Sab',
      'Dom',
    ];
    return shortWeekdays[date.weekday - 1];
  }

  String _monthLabel(DateTime date) {
    const shortMonths = <String>[
      'Gen',
      'Feb',
      'Mar',
      'Apr',
      'Mag',
      'Giu',
      'Lug',
      'Ago',
      'Set',
      'Ott',
      'Nov',
      'Dic',
    ];
    return shortMonths[date.month - 1];
  }

  String _dayMonthLabel(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    return '$dd/$mm';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(brandCampaignsControllerProvider);
    final homeState = ref.watch(homeControllerProvider);
    final theme = Theme.of(context);
    final textTheme = GoogleFonts.plusJakartaSansTextTheme(theme.textTheme);
    final campaigns = state.campaigns;
    final activeCampaigns = campaigns
        .where((campaign) => campaign.status.toLowerCase() == 'active')
        .length;
    final matchedCampaigns = campaigns
        .where((campaign) => campaign.status.toLowerCase() == 'matched')
        .length;
    final spentBudget = campaigns
        .where((campaign) {
          final status = campaign.status.toLowerCase();
          return status == 'matched' || status == 'completed';
        })
        .fold<num>(0, (total, campaign) => total + campaign.budget);
    final matchingTrend = _buildMatchingTrend(campaigns, _selectedTimeline);

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

    return Theme(
      data: theme.copyWith(
        textTheme: textTheme,
        primaryTextTheme: GoogleFonts.plusJakartaSansTextTheme(
          theme.primaryTextTheme,
        ),
        scaffoldBackgroundColor: Colors.transparent,
        appBarTheme: theme.appBarTheme.copyWith(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          foregroundColor: const Color(0xFFEAF3FF),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xC0162030),
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: const Color(0xFF9FC8F8).withValues(alpha: 0.16),
            ),
          ),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Brand Dashboard',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
          ),
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
        body: Stack(
          children: [
            const Positioned.fill(child: LuxuryNeonBackdrop()),
            SafeArea(
              child: Builder(
                builder: (context) {
                  if (state.isLoading && campaigns.isEmpty) {
                    return const Center(child: SinapsyLogoLoader());
                  }

                  return RefreshIndicator(
                    onRefresh: () => ref
                        .read(brandCampaignsControllerProvider.notifier)
                        .loadMyCampaigns(),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [
                        _QuickStatsSection(
                          activeCampaigns: activeCampaigns,
                          spentBudget: spentBudget,
                          matchedCampaigns: matchedCampaigns,
                          matchingTrend: matchingTrend,
                          selectedTimeline: _selectedTimeline,
                          onTimelineChanged: (timeline) {
                            setState(() => _selectedTimeline = timeline);
                          },
                        ),
                        const SizedBox(height: 16),
                        if (campaigns.isEmpty)
                          _EmptyCampaignState(
                            onCreateCampaign: _openCreateCampaign,
                          )
                        else
                          for (
                            var index = 0;
                            index < campaigns.length;
                            index++
                          ) ...[
                            _CampaignTile(
                              campaign: campaigns[index],
                              isRemoving:
                                  state.isRemoving &&
                                  state.removingCampaignId == campaigns[index].id,
                              onRemove: () =>
                                  _confirmRemoveCampaign(campaigns[index]),
                            ),
                            if (index != campaigns.length - 1)
                              const SizedBox(height: 10),
                          ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: state.isLoading || state.isRemoving
              ? null
              : _openCreateCampaign,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class _QuickStatsSection extends StatelessWidget {
  const _QuickStatsSection({
    required this.activeCampaigns,
    required this.spentBudget,
    required this.matchedCampaigns,
    required this.matchingTrend,
    required this.selectedTimeline,
    required this.onTimelineChanged,
  });

  final int activeCampaigns;
  final num spentBudget;
  final int matchedCampaigns;
  final List<_TrendPoint> matchingTrend;
  final _MatchingTimeline selectedTimeline;
  final ValueChanged<_MatchingTimeline> onTimelineChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Campagne attive',
                    value: '$activeCampaigns',
                    icon: Icons.campaign_rounded,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: _StatCard(
                    title: 'Budget speso',
                    value: _formatBudget(spentBudget),
                    icon: Icons.euro_rounded,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 6,
            child: _MatchingCard(
              matchedCampaigns: matchedCampaigns,
              trendPoints: matchingTrend,
              selectedTimeline: selectedTimeline,
              onTimelineChanged: onTimelineChanged,
            ),
          ),
        ],
      ),
    );
  }

  String _formatBudget(num value) {
    if (value == value.roundToDouble()) {
      return 'EUR ${value.toInt()}';
    }
    return 'EUR ${value.toStringAsFixed(2)}';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 22),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchingCard extends StatelessWidget {
  const _MatchingCard({
    required this.matchedCampaigns,
    required this.trendPoints,
    required this.selectedTimeline,
    required this.onTimelineChanged,
  });

  final int matchedCampaigns;
  final List<_TrendPoint> trendPoints;
  final _MatchingTimeline selectedTimeline;
  final ValueChanged<_MatchingTimeline> onTimelineChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastMonthValue = trendPoints.isNotEmpty
        ? trendPoints.last.value.toInt()
        : 0;
    final previousMonthValue = trendPoints.length > 1
        ? trendPoints[trendPoints.length - 2].value.toInt()
        : 0;
    final delta = lastMonthValue - previousMonthValue;
    final deltaLabel = delta == 0
        ? 'stabile vs ${selectedTimeline.comparisonLabel}'
        : '${delta > 0 ? '+' : ''}$delta vs ${selectedTimeline.comparisonLabel}';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Matching creator',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _TimelineMenuButton(
                  selectedTimeline: selectedTimeline,
                  onTimelineChanged: onTimelineChanged,
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '$matchedCampaigns campagne in matching ora',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Ultimo periodo: $lastMonthValue ($deltaLabel)',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: _MatchingChart(points: trendPoints)),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 6,
              children: [
                _LegendChip(
                  color: theme.colorScheme.primary,
                  label:
                      'Trend match/completed (${selectedTimeline.label.toLowerCase()})',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchingChart extends StatelessWidget {
  const _MatchingChart({required this.points});

  final List<_TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final values = points.map((point) => point.value).toList(growable: false);
    return Column(
      children: [
        Expanded(
          child: CustomPaint(
            painter: _PremiumLineChartPainter(
              values: values,
              lineColor: theme.colorScheme.primary,
              gridColor: theme.colorScheme.outline.withValues(alpha: 0.28),
              dotColor: const Color(0xFFEAF3FF),
              fillTopColor: theme.colorScheme.primary.withValues(alpha: 0.35),
              fillBottomColor: theme.colorScheme.primary.withValues(
                alpha: 0.02,
              ),
            ),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < points.length; i++)
              Expanded(
                child: Text(
                  _labelForIndex(i),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall,
                ),
              ),
          ],
        ),
      ],
    );
  }

  String _labelForIndex(int index) {
    if (points.length <= 6) return points[index].label;
    if (index.isEven) return points[index].label;
    return '';
  }
}

class _TrendPoint {
  const _TrendPoint({required this.label, required this.value});

  final String label;
  final double value;
}

class _TimelineMenuButton extends StatelessWidget {
  const _TimelineMenuButton({
    required this.selectedTimeline,
    required this.onTimelineChanged,
  });

  final _MatchingTimeline selectedTimeline;
  final ValueChanged<_MatchingTimeline> onTimelineChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<_MatchingTimeline>(
      tooltip: 'Cambia timeline',
      initialValue: selectedTimeline,
      onSelected: onTimelineChanged,
      itemBuilder: (context) => _MatchingTimeline.values
          .map(
            (timeline) => PopupMenuItem<_MatchingTimeline>(
              value: timeline,
              child: Text(timeline.label),
            ),
          )
          .toList(growable: false),
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.schedule_rounded, size: 13),
            const SizedBox(width: 5),
            Text(
              selectedTimeline.shortLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 14),
          ],
        ),
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _PremiumLineChartPainter extends CustomPainter {
  const _PremiumLineChartPainter({
    required this.values,
    required this.lineColor,
    required this.gridColor,
    required this.dotColor,
    required this.fillTopColor,
    required this.fillBottomColor,
  });

  final List<double> values;
  final Color lineColor;
  final Color gridColor;
  final Color dotColor;
  final Color fillTopColor;
  final Color fillBottomColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || size.width <= 0 || size.height <= 0) return;

    const leftInset = 10.0;
    const rightInset = 10.0;
    const topInset = 8.0;
    const bottomInset = 12.0;
    final chartRect = Rect.fromLTWH(
      leftInset,
      topInset,
      size.width - leftInset - rightInset,
      size.height - topInset - bottomInset,
    );

    final maxValue = math.max(1.0, values.reduce(math.max));
    const gridLines = 4;
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (var i = 0; i <= gridLines; i++) {
      final y = chartRect.top + (chartRect.height / gridLines) * i;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
    }

    final stepX = values.length == 1
        ? 0.0
        : chartRect.width / (values.length - 1);
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final normalized = values[i] / maxValue;
      final y = chartRect.bottom - (chartRect.height * normalized);
      final x = chartRect.left + (stepX * i);
      points.add(Offset(x, y));
    }

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final current = points[i];
      final c1 = Offset((prev.dx + current.dx) / 2, prev.dy);
      final c2 = Offset((prev.dx + current.dx) / 2, current.dy);
      linePath.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, current.dx, current.dy);
    }

    final areaPath = Path.from(linePath)
      ..lineTo(points.last.dx, chartRect.bottom)
      ..lineTo(points.first.dx, chartRect.bottom)
      ..close();

    final areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [fillTopColor, fillBottomColor],
      ).createShader(chartRect);
    canvas.drawPath(areaPath, areaPaint);

    final glowPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.drawPath(linePath, glowPaint);

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, linePaint);

    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      canvas.drawCircle(point, 5.5, Paint()..color = dotColor);
      canvas.drawCircle(point, 3.2, Paint()..color = lineColor);

      final valueLabel = values[i].toInt().toString();
      final textPainter = TextPainter(
        text: TextSpan(
          text: valueLabel,
          style: TextStyle(
            color: dotColor.withValues(alpha: 0.95),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();

      final dx = point.dx - (textPainter.width / 2);
      final dy = point.dy - 18;
      textPainter.paint(canvas, Offset(dx, dy));
    }
  }

  @override
  bool shouldRepaint(covariant _PremiumLineChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.dotColor != dotColor ||
        oldDelegate.fillTopColor != fillTopColor ||
        oldDelegate.fillBottomColor != fillBottomColor;
  }
}

class _EmptyCampaignState extends StatelessWidget {
  const _EmptyCampaignState({required this.onCreateCampaign});

  final VoidCallback onCreateCampaign;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Non hai ancora campagne attive, matched o completed.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onCreateCampaign,
              icon: const Icon(Icons.add),
              label: const Text('Crea campagna'),
            ),
          ],
        ),
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
