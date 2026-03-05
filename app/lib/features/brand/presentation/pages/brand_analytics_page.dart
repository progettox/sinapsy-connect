import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_client_provider.dart';
import '../../../../core/widgets/luxury_neon_backdrop.dart';
import '../../../../core/widgets/sinapsy_logo_loader.dart';
import '../../../campaigns/data/campaign_model.dart';
import '../../../campaigns/presentation/controllers/create_campaign_controller.dart';

class BrandAnalyticsPage extends ConsumerStatefulWidget {
  const BrandAnalyticsPage({super.key});

  @override
  ConsumerState<BrandAnalyticsPage> createState() => _BrandAnalyticsPageState();
}

enum _AnalyticsRange {
  d10('10 giorni', 10),
  d30('30 giorni', 30),
  y1('1 anno', 365);

  const _AnalyticsRange(this.label, this.days);
  final String label;
  final int days;
}

class _BrandAnalyticsPageState extends ConsumerState<BrandAnalyticsPage> {
  Future<_AnalyticsPayload>? _analyticsFuture;
  String _analyticsCacheKey = '';
  _AnalyticsRange _selectedRange = _AnalyticsRange.d30;
  late final PageController _cardsController;
  int _selectedCardIndex = 0;

  @override
  void initState() {
    super.initState();
    _cardsController = PageController(viewportFraction: 0.94);
    Future<void>.microtask(
      () =>
          ref.read(brandCampaignsControllerProvider.notifier).loadMyCampaigns(),
    );
  }

  @override
  void dispose() {
    _cardsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(brandCampaignsControllerProvider);
    final campaigns = state.campaigns;
    final totalViews = campaigns.fold<int>(
      0,
      (total, campaign) => total + campaign.viewsCount,
    );

    final analyticsFuture = _getOrCreateAnalyticsFuture(campaigns);

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: RepaintBoundary(child: LuxuryNeonBackdrop()),
          ),
          SafeArea(
            child: state.isLoading && campaigns.isEmpty
                ? const Center(child: SinapsyLogoLoader())
                : RefreshIndicator(
                    onRefresh: () async {
                      await ref
                          .read(brandCampaignsControllerProvider.notifier)
                          .loadMyCampaigns();
                      setState(() {
                        _analyticsCacheKey = '';
                        _analyticsFuture = null;
                      });
                    },
                    child: FutureBuilder<_AnalyticsPayload>(
                      future: analyticsFuture,
                      builder: (context, snapshot) {
                        final payload =
                            snapshot.data ?? _AnalyticsPayload.empty(campaigns);
                        final points = payload.points.isEmpty
                            ? _fallbackPointsFromCampaigns(campaigns)
                            : payload.points;
                        final last30 = _sliceLastDays(points, 30);
                        final selected = _sliceLastDays(
                          points,
                          _selectedRange.days,
                        );

                        final monthlyMatches = last30.fold<int>(
                          0,
                          (sum, point) => sum + point.matches,
                        );
                        final selectedBudget = selected.fold<double>(
                          0,
                          (sum, point) => sum + point.budgetSpent,
                        );
                        final selectedViews = selected.fold<int>(
                          0,
                          (sum, point) => sum + point.views,
                        );
                        final activeCampaignsCount = _countActiveCampaigns(
                          campaigns,
                        );
                        final monthlyBudgetSpent = last30.fold<double>(
                          0,
                          (sum, point) => sum + point.budgetSpent,
                        );
                        final monthlyBudgetSeries = _normalizeLine(
                          last30
                              .map((point) => point.budgetSpent)
                              .toList(growable: false),
                        );
                        final totalMatches = points.fold<int>(
                          0,
                          (sum, point) => sum + point.matches,
                        );
                        final followerPoints = payload.followerPoints.isEmpty
                            ? _zeroFollowerPoints(30)
                            : payload.followerPoints;
                        final followerLast30 = _sliceFollowerLastDays(
                          followerPoints,
                          30,
                        );
                        final followersThisWeek = _sliceFollowerLastDays(
                          followerPoints,
                          7,
                        ).fold<int>(0, (sum, point) => sum + point.gained);

                        return ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(14, 49, 14, 24),
                          children: [
                            _TotalViewsCard(
                              totalViews: totalViews,
                              monthlyGrowthPercent:
                                  payload.monthlyViews.growthPercent,
                              barSeries: _normalizeBars(
                                last30
                                    .map((point) => point.views.toDouble())
                                    .toList(growable: false),
                                barCount: 7,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 198,
                              child: PageView(
                                controller: _cardsController,
                                onPageChanged: (index) {
                                  setState(() => _selectedCardIndex = index);
                                },
                                children: [
                                  _TrendMetricCard(
                                    title: 'MATCH MENSILI',
                                    value: _formatInt(monthlyMatches),
                                    subtitle: 'Diretti Interactioni',
                                    series: _normalizeLine(
                                      last30
                                          .map(
                                            (point) => point.matches.toDouble(),
                                          )
                                          .toList(growable: false),
                                    ),
                                  ),
                                  _TrendMetricCard(
                                    title: 'BUDGET SPESO',
                                    value: _formatCurrencyCompact(
                                      selectedBudget,
                                    ),
                                    subtitle: 'Ultimi ${_selectedRange.label}',
                                    series: _normalizeLine(
                                      selected
                                          .map((point) => point.budgetSpent)
                                          .toList(growable: false),
                                    ),
                                  ),
                                  _TrendMetricCard(
                                    title: 'VISUALIZZAZIONI',
                                    value: _formatCompactViews(selectedViews),
                                    subtitle: 'Ultimi ${_selectedRange.label}',
                                    series: _normalizeLine(
                                      selected
                                          .map(
                                            (point) => point.views.toDouble(),
                                          )
                                          .toList(growable: false),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            _CardsIndicator(
                              count: 3,
                              activeIndex: _selectedCardIndex,
                            ),
                            const SizedBox(height: 10),
                            _RangeSelector(
                              selected: _selectedRange,
                              onChanged: (range) {
                                if (_selectedRange == range) return;
                                setState(() => _selectedRange = range);
                              },
                            ),
                            const SizedBox(height: 18),
                            _MonthlyMatchesDetailsCard(
                              activeCampaignsCount: activeCampaignsCount,
                              budgetSpent: monthlyBudgetSpent,
                              budgetSeries: monthlyBudgetSeries,
                              totalMatches: totalMatches,
                              followerWeeklyDelta: followersThisWeek,
                              followerSeries: _normalizeZeroBasedLine(
                                followerLast30
                                    .map((point) => point.gained.toDouble())
                                    .toList(growable: false),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<_AnalyticsPayload> _getOrCreateAnalyticsFuture(
    List<CampaignModel> campaigns,
  ) {
    final cacheKey = campaigns
        .map(
          (campaign) =>
              '${campaign.id}:${campaign.viewsCount}:${campaign.status}:${campaign.updatedAt?.toIso8601String() ?? ''}:${campaign.createdAt?.toIso8601String() ?? ''}',
        )
        .join('|');
    if (_analyticsFuture != null && _analyticsCacheKey == cacheKey) {
      return _analyticsFuture!;
    }
    _analyticsCacheKey = cacheKey;
    _analyticsFuture = _fetchAnalyticsPayload();
    return _analyticsFuture!;
  }

  Future<_AnalyticsPayload> _fetchAnalyticsPayload() async {
    try {
      final client = ref.read(supabaseClientProvider);
      final results = await Future.wait<dynamic>([
        client.rpc('get_brand_campaign_views_monthly'),
        client.rpc(
          'get_brand_analytics_timeseries',
          params: <String, dynamic>{'p_days': 365},
        ),
        _fetchFollowerPoints(client: client, days: 30),
      ]);

      final monthlyRows = results[0] is List
          ? results[0] as List<dynamic>
          : <dynamic>[results[0]];
      final monthlyMap = monthlyRows.isEmpty
          ? const <String, dynamic>{}
          : _toMap(monthlyRows.first);

      final seriesRows = results[1] is List
          ? results[1] as List<dynamic>
          : <dynamic>[results[1]];
      final points =
          seriesRows
              .map(_toMap)
              .map(_AnalyticsPoint.fromMap)
              .toList(growable: false)
            ..sort((a, b) => a.day.compareTo(b.day));

      return _AnalyticsPayload(
        monthlyViews: _MonthlyViewsStats(
          currentMonth: _asInt(monthlyMap['current_month']) ?? 0,
          previousMonth: _asInt(monthlyMap['previous_month']) ?? 0,
        ),
        points: points,
        followerPoints: (results[2] as List<_FollowerPoint>),
      );
    } catch (_) {
      return const _AnalyticsPayload();
    }
  }

  Map<String, dynamic> _toMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, entry) => MapEntry('$key', entry));
    }
    return const <String, dynamic>{};
  }

  int? _asInt(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString());
  }

  List<_AnalyticsPoint> _fallbackPointsFromCampaigns(
    List<CampaignModel> campaigns,
  ) {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 364));
    final byDay = <DateTime, _AnalyticsPoint>{};
    for (var i = 0; i < 365; i++) {
      final day = start.add(Duration(days: i));
      byDay[day] = _AnalyticsPoint(day: day);
    }

    for (final campaign in campaigns) {
      final event =
          campaign.updatedAt?.toLocal() ?? campaign.createdAt?.toLocal();
      if (event == null) continue;
      final day = DateTime(event.year, event.month, event.day);
      final existing = byDay[day];
      if (existing == null) continue;

      var next = existing.copyWith(views: existing.views + campaign.viewsCount);
      final status = campaign.status.toLowerCase();
      if (status == 'matched' || status == 'completed') {
        next = next.copyWith(
          matches: next.matches + 1,
          budgetSpent: next.budgetSpent + campaign.budget.toDouble(),
        );
      }
      byDay[day] = next;
    }

    return byDay.values.toList(growable: false)
      ..sort((a, b) => a.day.compareTo(b.day));
  }

  List<_AnalyticsPoint> _sliceLastDays(List<_AnalyticsPoint> points, int days) {
    if (points.isEmpty) return const <_AnalyticsPoint>[];
    final now = DateTime.now();
    final threshold = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: days - 1));
    return points.where((point) => !point.day.isBefore(threshold)).toList();
  }

  List<_FollowerPoint> _sliceFollowerLastDays(
    List<_FollowerPoint> points,
    int days,
  ) {
    if (points.isEmpty) return const <_FollowerPoint>[];
    final now = DateTime.now();
    final threshold = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: days - 1));
    return points.where((point) => !point.day.isBefore(threshold)).toList();
  }

  Future<List<_FollowerPoint>> _fetchFollowerPoints({
    required SupabaseClient client,
    required int days,
  }) async {
    final template = _zeroFollowerPoints(days);
    final currentUserId = client.auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) {
      return template;
    }

    for (final schema in _followSchemasForFollowers) {
      try {
        final raw = await client
            .from(schema.table)
            .select('${schema.followerColumn},${schema.createdAtColumn}')
            .eq(schema.followedColumn, currentUserId)
            .gte(schema.createdAtColumn, template.first.day.toIso8601String());
        final rows = List<Map<String, dynamic>>.from(raw as List);
        if (rows.isEmpty) {
          continue;
        }

        final countsByDay = <DateTime, int>{
          for (final point in template) point.day: 0,
        };
        final seenFollowerIdsByDay = <DateTime, Set<String>>{};

        for (final row in rows) {
          final rawTimestamp = (row[schema.createdAtColumn] ?? '')
              .toString()
              .trim();
          final parsedTimestamp = DateTime.tryParse(rawTimestamp)?.toLocal();
          if (parsedTimestamp == null) continue;

          final day = DateTime(
            parsedTimestamp.year,
            parsedTimestamp.month,
            parsedTimestamp.day,
          );
          if (!countsByDay.containsKey(day)) continue;

          final followerId = (row[schema.followerColumn] ?? '').toString();
          if (followerId.isNotEmpty) {
            final seen = seenFollowerIdsByDay.putIfAbsent(
              day,
              () => <String>{},
            );
            if (!seen.add(followerId)) continue;
          }

          countsByDay[day] = (countsByDay[day] ?? 0) + 1;
        }

        return countsByDay.entries
            .map(
              (entry) => _FollowerPoint(day: entry.key, gained: entry.value),
            )
            .toList(growable: false)
          ..sort((a, b) => a.day.compareTo(b.day));
      } on PostgrestException {
        continue;
      } catch (_) {
        continue;
      }
    }

    return template;
  }
}

class _TotalViewsCard extends StatelessWidget {
  const _TotalViewsCard({
    required this.totalViews,
    required this.monthlyGrowthPercent,
    required this.barSeries,
  });

  final int totalViews;
  final double monthlyGrowthPercent;
  final List<double> barSeries;

  @override
  Widget build(BuildContext context) {
    final growthPrefix = monthlyGrowthPercent >= 0 ? '+' : '';
    final growthLabel =
        '$growthPrefix${monthlyGrowthPercent.toStringAsFixed(1)}% vs mese scorso';

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 0),
      child: Column(
        children: [
          SizedBox(
            height: 108,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VISUALIZZAZIONI TOTALI (Cumulativo)',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: const Color(0xFFD2CAE6),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.35,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatCompactViews(totalViews),
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFF6F0FF),
                              height: 1.02,
                            ),
                      ),
                      const Spacer(),
                      Text(
                        growthLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF8DC3FF),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 92,
                  height: 82,
                  child: _RightBarSpark(series: barSeries),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Container(height: 1, color: const Color(0x44A794D8)),
        ],
      ),
    );
  }
}

class _TrendMetricCard extends StatelessWidget {
  const _TrendMetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.series,
  });

  final String title;
  final String value;
  final String subtitle;
  final List<double> series;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x44957CCD)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF111427), Color(0xFF1E1634), Color(0xFF241842)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFFE0D3FF),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.35,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF9683BC),
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 2),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFFF5ECFF),
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                  ),
                ),
                TextSpan(
                  text: ' $subtitle',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFB7A9D8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _NeonLineChart(series: series)),
        ],
      ),
    );
  }
}

class _MonthlyMatchesDetailsCard extends StatelessWidget {
  const _MonthlyMatchesDetailsCard({
    required this.activeCampaignsCount,
    required this.budgetSpent,
    required this.budgetSeries,
    required this.totalMatches,
    required this.followerWeeklyDelta,
    required this.followerSeries,
  });

  final int activeCampaignsCount;
  final double budgetSpent;
  final List<double> budgetSeries;
  final int totalMatches;
  final int followerWeeklyDelta;
  final List<double> followerSeries;

  @override
  Widget build(BuildContext context) {
    const sectionSpacing = 16.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
      child: Column(
        children: [
          Row(
            children: [
              const _MetricIconBubble(icon: Icons.campaign_rounded),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CAMPAGNE ATTIVE',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: const Color(0xFFCFC5E2),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatInt(activeCampaignsCount),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: const Color(0xFFF5EEFF),
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: sectionSpacing),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const _MetricIconBubble(icon: Icons.account_balance_wallet_rounded),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'BUDGET SPESO',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: const Color(0xFFCFC5E2),
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatEuroAmount(budgetSpent),
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: const Color(0xFFF5EEFF),
                                  fontWeight: FontWeight.w800,
                                  height: 1.0,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 108,
                      height: 56,
                      child: _BudgetAreaSpark(series: budgetSeries),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: sectionSpacing),
          Row(
            children: [
              const _MetricIconBubble(icon: Icons.forum_rounded),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MATCH TOTALI',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: const Color(0xFFCFC5E2),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatInt(totalMatches),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: const Color(0xFFF5EEFF),
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      height: 1,
                      color: const Color(0x44A794D8),
                    ),
                    const SizedBox(height: 14),
                    _FollowerFloatingSection(
                      weeklyDelta: followerWeeklyDelta,
                      series: followerSeries,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricIconBubble extends StatelessWidget {
  const _MetricIconBubble({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: Icon(
        icon,
        size: 17.5,
        color: const Color(0xFFEADFFF),
        shadows: [
          Shadow(
            color: const Color(0xFFA764FF).withValues(alpha: 0.95),
            blurRadius: 10,
          ),
          Shadow(
            color: const Color(0xFF6B36D6).withValues(alpha: 0.8),
            blurRadius: 22,
          ),
        ],
      ),
    );
  }
}

class _FollowerFloatingSection extends StatelessWidget {
  const _FollowerFloatingSection({
    required this.weeklyDelta,
    required this.series,
  });

  final int weeklyDelta;
  final List<double> series;

  @override
  Widget build(BuildContext context) {
    final isPositive = weeklyDelta >= 0;
    final deltaPrefix = isPositive ? '+' : '-';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FOLLOWER',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: const Color(0xFFCFC5E2),
            fontWeight: FontWeight.w800,
            letterSpacing: 0.35,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Icon(
              isPositive ? Icons.north_rounded : Icons.south_rounded,
              size: 15,
              color: isPositive
                  ? const Color(0xFF6DD8FF)
                  : const Color(0xFFFF8A8A),
            ),
            const SizedBox(width: 2),
            Text(
              '$deltaPrefix${_formatInt(weeklyDelta.abs())} questa settimana',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFFE9DEFF),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 78,
          child: _FollowerMiniChart(series: series),
        ),
      ],
    );
  }
}

class _FollowerMiniChart extends StatelessWidget {
  const _FollowerMiniChart({required this.series});

  final List<double> series;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FollowerMiniChartPainter(series: series),
      child: const SizedBox.expand(),
    );
  }
}

class _FollowerMiniChartPainter extends CustomPainter {
  const _FollowerMiniChartPainter({required this.series});

  final List<double> series;

  @override
  void paint(Canvas canvas, Size size) {
    final values = series.isEmpty
        ? const <double>[0, 0, 0, 0, 0, 0, 0]
        : series;
    if (values.isEmpty) return;

    final topInset = size.height * 0.08;
    final bottomInset = size.height * 0.14;
    final drawableHeight = math.max(1.0, size.height - topInset - bottomInset);
    final baselineY = topInset + drawableHeight;

    final guidePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x1FA794D8);

    canvas.drawLine(Offset(0, baselineY), Offset(size.width, baselineY), guidePaint);

    final markerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x22BFA9E6);
    for (final ratio in <double>[0.52, 0.70, 0.84, 0.94]) {
      final x = size.width * ratio;
      _drawDashedLine(
        canvas: canvas,
        paint: markerPaint,
        start: Offset(x, topInset + 2),
        end: Offset(x, baselineY),
        dash: 3.5,
        gap: 3.5,
      );
    }

    final points = <Offset>[];
    final stepX = values.length == 1 ? 0.0 : size.width / (values.length - 1);
    for (var i = 0; i < values.length; i++) {
      final value = values[i].clamp(0.0, 1.0);
      final x = stepX * i;
      final y = topInset + ((1 - value) * drawableHeight);
      points.add(Offset(x, y));
    }
    if (points.isEmpty) return;

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final controlX = (previous.dx + current.dx) / 2;
      linePath.cubicTo(
        controlX,
        previous.dy,
        controlX,
        current.dy,
        current.dx,
        current.dy,
      );
    }

    final areaPath = Path.from(linePath)
      ..lineTo(points.last.dx, baselineY)
      ..lineTo(points.first.dx, baselineY)
      ..close();

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x4D955BFF), Color(0x00955BFF)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(areaPath, fillPaint);

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..color = const Color(0x70935DFF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.6);
    canvas.drawPath(linePath, glow);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = const Color(0xFFC9B2FF)
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, stroke);

    if (points.length > 3) {
      final markerIndexes = <int>{
        (points.length * 0.70).floor(),
        (points.length * 0.86).floor(),
        points.length - 1,
      };
      for (final index in markerIndexes) {
        if (index < 0 || index >= points.length) continue;
        final point = points[index];
        canvas.drawCircle(
          point,
          2.6,
          Paint()..color = const Color(0xFFE1CCFF),
        );
      }
    }
  }

  void _drawDashedLine({
    required Canvas canvas,
    required Paint paint,
    required Offset start,
    required Offset end,
    required double dash,
    required double gap,
  }) {
    final distance = (end - start).distance;
    if (distance <= 0) return;

    final direction = (end - start) / distance;
    var drawn = 0.0;
    while (drawn < distance) {
      final segmentStart = start + (direction * drawn);
      final segmentEnd = start +
          (direction * math.min(distance, drawn + dash));
      canvas.drawLine(segmentStart, segmentEnd, paint);
      drawn += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _FollowerMiniChartPainter oldDelegate) {
    return oldDelegate.series != series;
  }
}

class _BudgetAreaSpark extends StatelessWidget {
  const _BudgetAreaSpark({required this.series});

  final List<double> series;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x221F1538), Color(0x11100A22)],
          ),
        ),
        child: CustomPaint(
          painter: _BudgetAreaSparkPainter(series: series),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _BudgetAreaSparkPainter extends CustomPainter {
  const _BudgetAreaSparkPainter({required this.series});

  final List<double> series;

  @override
  void paint(Canvas canvas, Size size) {
    final values = series.isEmpty
        ? const <double>[0, 0, 0, 0, 0, 0, 0]
        : series;
    if (values.isEmpty) return;

    final points = <Offset>[];
    final stepX = values.length == 1 ? 0.0 : size.width / (values.length - 1);
    final topInset = size.height * 0.08;
    final drawableHeight = math.max(1.0, size.height - topInset);
    for (var i = 0; i < values.length; i++) {
      final value = values[i].clamp(0.0, 1.0);
      final x = stepX * i;
      final y = topInset + ((1 - value) * drawableHeight);
      points.add(Offset(x, y));
    }
    if (points.isEmpty) return;

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final controlX = (previous.dx + current.dx) / 2;
      path.cubicTo(
        controlX,
        previous.dy,
        controlX,
        current.dy,
        current.dx,
        current.dy,
      );
    }

    final area = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    final fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xCCB99DFF), Color(0x238665D0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(area, fill);

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..color = const Color(0x779E80F0)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2);
    canvas.drawPath(path, glow);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0xFFD7C8FF)
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _BudgetAreaSparkPainter oldDelegate) {
    return oldDelegate.series != series;
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.selected, required this.onChanged});

  final _AnalyticsRange selected;
  final ValueChanged<_AnalyticsRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: _AnalyticsRange.values
          .map((range) {
            final isSelected = range == selected;
            return InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onChanged(range),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFF8E56F5), Color(0xFF6C3BC9)],
                        )
                      : const LinearGradient(
                          colors: [Color(0x301E1634), Color(0x20191631)],
                        ),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0x88CBA8FF)
                        : const Color(0x503A3058),
                  ),
                ),
                child: Text(
                  range.label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: isSelected
                        ? const Color(0xFFF4ECFF)
                        : const Color(0xC6C9BBE8),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class _CardsIndicator extends StatelessWidget {
  const _CardsIndicator({required this.count, required this.activeIndex});

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final selected = index == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: selected ? 20 : 7,
          height: 7,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: selected ? const Color(0xFF9F74FF) : const Color(0x55493B6E),
          ),
        );
      }),
    );
  }
}

class _RightBarSpark extends StatelessWidget {
  const _RightBarSpark({required this.series});

  final List<double> series;

  @override
  Widget build(BuildContext context) {
    final values = series.isEmpty
        ? const <double>[0, 0, 0, 0, 0, 0, 0]
        : series;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: values
          .map(
            (value) => Container(
              width: 9,
              height: 4 + (66 * value.clamp(0.0, 1.0)),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                gradient: const LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xFF6D4AAC), Color(0xFFD68CFF)],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66432780),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _NeonLineChart extends StatelessWidget {
  const _NeonLineChart({required this.series});

  final List<double> series;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _NeonLineChartPainter(series: series),
      child: const SizedBox.expand(),
    );
  }
}

class _NeonLineChartPainter extends CustomPainter {
  const _NeonLineChartPainter({required this.series});

  final List<double> series;

  @override
  void paint(Canvas canvas, Size size) {
    final values = series.isEmpty
        ? const <double>[0, 0, 0, 0, 0, 0, 0]
        : series;
    if (values.isEmpty) return;

    final points = <Offset>[];
    final stepX = values.length == 1 ? 0.0 : size.width / (values.length - 1);
    final topInset = size.height * 0.04;
    final drawableHeight = math.max(1.0, size.height - topInset);
    for (var i = 0; i < values.length; i++) {
      final value = values[i].clamp(0.0, 1.0);
      final x = stepX * i;
      final y = topInset + ((1 - value) * drawableHeight);
      points.add(Offset(x, y));
    }

    if (points.isEmpty) return;

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final controlX = (previous.dx + current.dx) / 2;
      linePath.cubicTo(
        controlX,
        previous.dy,
        controlX,
        current.dy,
        current.dx,
        current.dy,
      );
    }

    final areaPath = Path.from(linePath)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    final fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x889866FF), Color(0x119866FF)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(areaPath, fill);

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..color = const Color(0x809A6BFF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
    canvas.drawPath(linePath, glow);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF9F73FF)
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, stroke);

    if (points.length > 4) {
      for (final point in [
        points[points.length ~/ 2],
        points[points.length - 2],
      ]) {
        canvas.drawCircle(point, 3, Paint()..color = const Color(0xFFD7C1FF));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _NeonLineChartPainter oldDelegate) {
    return oldDelegate.series != series;
  }
}

class _AnalyticsPayload {
  const _AnalyticsPayload({
    this.monthlyViews = const _MonthlyViewsStats(),
    this.points = const <_AnalyticsPoint>[],
    this.followerPoints = const <_FollowerPoint>[],
  });

  final _MonthlyViewsStats monthlyViews;
  final List<_AnalyticsPoint> points;
  final List<_FollowerPoint> followerPoints;

  factory _AnalyticsPayload.empty(List<CampaignModel> campaigns) {
    final fallbackPoints = <_AnalyticsPoint>[];
    final now = DateTime.now();
    for (var i = 29; i >= 0; i--) {
      final day = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: i));
      fallbackPoints.add(_AnalyticsPoint(day: day));
    }
    return _AnalyticsPayload(
      monthlyViews: const _MonthlyViewsStats(),
      points: fallbackPoints,
      followerPoints: _zeroFollowerPoints(30),
    );
  }
}

class _FollowerPoint {
  const _FollowerPoint({required this.day, this.gained = 0});

  final DateTime day;
  final int gained;
}

class _AnalyticsPoint {
  const _AnalyticsPoint({
    required this.day,
    this.views = 0,
    this.budgetSpent = 0,
    this.matches = 0,
  });

  final DateTime day;
  final int views;
  final double budgetSpent;
  final int matches;

  factory _AnalyticsPoint.fromMap(Map<String, dynamic> map) {
    final rawDay = (map['bucket_date'] ?? map['day'] ?? '').toString().trim();
    final day = DateTime.tryParse(rawDay);
    final views = _toInt(map['views_count']) ?? 0;
    final matches = _toInt(map['matches_count']) ?? 0;
    final budgetSpent = _toDouble(map['budget_spent']) ?? 0;

    return _AnalyticsPoint(
      day: day ?? DateTime.now(),
      views: views,
      budgetSpent: budgetSpent,
      matches: matches,
    );
  }

  _AnalyticsPoint copyWith({
    DateTime? day,
    int? views,
    double? budgetSpent,
    int? matches,
  }) {
    return _AnalyticsPoint(
      day: day ?? this.day,
      views: views ?? this.views,
      budgetSpent: budgetSpent ?? this.budgetSpent,
      matches: matches ?? this.matches,
    );
  }
}

class _MonthlyViewsStats {
  const _MonthlyViewsStats({this.currentMonth = 0, this.previousMonth = 0});

  final int currentMonth;
  final int previousMonth;

  double get growthPercent {
    if (previousMonth <= 0) {
      return currentMonth > 0 ? 100 : 0;
    }
    return ((currentMonth - previousMonth) / previousMonth) * 100;
  }
}

int? _toInt(dynamic raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw.toString());
}

double? _toDouble(dynamic raw) {
  if (raw == null) return null;
  if (raw is double) return raw;
  if (raw is int) return raw.toDouble();
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw.toString());
}

List<double> _normalizeBars(List<double> values, {required int barCount}) {
  if (values.isEmpty) {
    return List<double>.filled(barCount, 0.0);
  }

  final buckets = List<double>.filled(barCount, 0);
  final window = math.max(1, (values.length / barCount).ceil());
  for (var i = 0; i < barCount; i++) {
    final start = i * window;
    final end = math.min(values.length, start + window);
    if (start >= end) continue;
    var sum = 0.0;
    for (var cursor = start; cursor < end; cursor++) {
      sum += values[cursor];
    }
    buckets[i] = sum / (end - start);
  }

  final maxValue = buckets.reduce((a, b) => a > b ? a : b);
  if (maxValue <= 0) {
    return List<double>.filled(barCount, 0.0);
  }
  return buckets
      .map((value) => (value / maxValue).clamp(0.0, 1.0))
      .toList(growable: false);
}

List<double> _normalizeLine(List<double> values) {
  if (values.isEmpty) {
    return const <double>[0, 0, 0, 0, 0, 0, 0];
  }
  final minValue = values.reduce((a, b) => a < b ? a : b);
  final maxValue = values.reduce((a, b) => a > b ? a : b);
  if (maxValue <= 0) {
    return List<double>.filled(values.length, 0.0);
  }
  final spread = maxValue - minValue;
  if (spread <= 0) {
    return List<double>.filled(values.length, 0.6);
  }
  return values
      .map((value) => ((value - minValue) / spread).clamp(0.0, 1.0))
      .toList(growable: false);
}

List<double> _normalizeZeroBasedLine(List<double> values) {
  if (values.isEmpty) {
    return const <double>[0, 0, 0, 0, 0, 0, 0];
  }
  final maxValue = values.reduce((a, b) => a > b ? a : b);
  if (maxValue <= 0) {
    return List<double>.filled(values.length, 0.0);
  }
  return values
      .map((value) => (value / maxValue).clamp(0.0, 1.0))
      .toList(growable: false);
}

List<_FollowerPoint> _zeroFollowerPoints(int days) {
  final now = DateTime.now();
  final start = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(Duration(days: days - 1));
  return List<_FollowerPoint>.generate(days, (index) {
    final day = start.add(Duration(days: index));
    return _FollowerPoint(day: day, gained: 0);
  });
}

const List<_FollowSchemaForFollowers> _followSchemasForFollowers =
    <_FollowSchemaForFollowers>[
      _FollowSchemaForFollowers(
        table: 'profile_followers',
        followerColumn: 'follower_id',
        followedColumn: 'followed_id',
      ),
      _FollowSchemaForFollowers(
        table: 'user_follows',
        followerColumn: 'follower_id',
        followedColumn: 'following_id',
      ),
      _FollowSchemaForFollowers(
        table: 'creator_followers',
        followerColumn: 'follower_id',
        followedColumn: 'creator_id',
      ),
    ];

class _FollowSchemaForFollowers {
  const _FollowSchemaForFollowers({
    required this.table,
    required this.followerColumn,
    required this.followedColumn,
  });

  final String table;
  final String followerColumn;
  final String followedColumn;
  final String createdAtColumn = 'created_at';
}

int _countActiveCampaigns(List<CampaignModel> campaigns) {
  return campaigns
      .where((campaign) => campaign.status.trim().toLowerCase() == 'active')
      .length;
}

String _formatCompactViews(int value) {
  if (value >= 1000000) {
    final millions = value / 1000000;
    final formatted = millions >= 100
        ? millions.toStringAsFixed(0)
        : millions.toStringAsFixed(1);
    return '${formatted}M';
  }
  if (value >= 1000) {
    final thousands = value / 1000;
    final formatted = thousands >= 100
        ? thousands.toStringAsFixed(0)
        : thousands.toStringAsFixed(1);
    return '${formatted}K';
  }
  return value.toString();
}

String _formatCurrencyCompact(double value) {
  final rounded = value.round();
  return 'EUR ${_formatInt(rounded)}';
}

String _formatEuroAmount(double value) {
  final rounded = value.round();
  return '\u20AC${_formatInt(rounded)}';
}

String _formatInt(int value) {
  final sign = value < 0 ? '-' : '';
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '$sign$buffer';
}


