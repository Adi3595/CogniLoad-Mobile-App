import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Trigger auto-refresh setup
    ref.read(autoRefreshProvider);
  }

  @override
  Widget build(BuildContext context) {
    final cognitiveLoadAsync = ref.watch(cognitiveLoadProvider);
    final historicalAsync = ref.watch(historicalSnapshotsProvider);
    final bgRunning = ref.watch(backgroundRunningProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(bgRunning),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 8),
                cognitiveLoadAsync.when(
                  loading: () => _buildLoadingCard(),
                  error: (e, _) => _buildErrorCard(e.toString()),
                  data: (snapshot) => snapshot != null
                      ? _buildMainScore(snapshot)
                      : _buildNoDataCard(),
                ),
                const SizedBox(height: 16),
                cognitiveLoadAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (snapshot) => snapshot != null
                      ? _buildFactorBreakdown(snapshot)
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),
                historicalAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (snapshots) => _buildTrendChart(snapshots),
                ),
                const SizedBox(height: 16),
                cognitiveLoadAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (snapshot) => snapshot != null
                      ? _buildRecommendations(snapshot.recommendations)
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(AsyncValue<bool> bgRunning) {
    return SliverAppBar(
      floating: true,
      backgroundColor: CogniloadTheme.background,
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [CogniloadTheme.primary, CogniloadTheme.secondary],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.psychology, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Text('Cogniload',
              style: TextStyle(
                color: CogniloadTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              )),
        ],
      ),
      actions: [
        bgRunning.when(
          data: (running) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: running
                    ? CogniloadTheme.accentGreen.withValues(alpha: 0.15)
                    : CogniloadTheme.textMuted.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: running
                      ? CogniloadTheme.accentGreen.withValues(alpha: 0.4)
                      : CogniloadTheme.textMuted.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: running
                          ? CogniloadTheme.accentGreen
                          : CogniloadTheme.textMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    running ? 'Live' : 'Paused',
                    style: TextStyle(
                      color: running
                          ? CogniloadTheme.accentGreen
                          : CogniloadTheme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: CogniloadTheme.textSecondary),
          onPressed: () {
            ref.invalidate(appUsageProvider);
            ref.invalidate(sessionsProvider);
            ref.invalidate(cognitiveLoadProvider);
            ref.invalidate(historicalSnapshotsProvider);
          },
        ),
      ],
    );
  }

  Widget _buildMainScore(snapshot) {
    final score = snapshot.score as double;
    final color = CogniloadTheme.scoreColor(score);

    return Animate(
      effects: const [FadeEffect(duration: Duration(milliseconds: 600))],
      child: GlassCard(
        borderColor: color.withValues(alpha: 0.3),
        borderWidth: 1.5,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cognitive Load Score',
                        style: TextStyle(
                          color: CogniloadTheme.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        CogniloadTheme.scoreLabel(score),
                        style: TextStyle(
                          color: color,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Updated ${DateFormat('h:mm a').format(snapshot.timestamp)}',
                        style: const TextStyle(
                          color: CogniloadTheme.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                ScoreBadge(score: score, size: 110),
              ],
            ),
            if (score > 70) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: CogniloadTheme.accentRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: CogniloadTheme.accentRed.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: CogniloadTheme.accentRed, size: 16),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'High cognitive load detected. Consider taking a break.',
                        style: TextStyle(
                          color: CogniloadTheme.accentRed,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFactorBreakdown(snapshot) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Load Breakdown',
            subtitle: 'Contributing factors',
          ),
          FactorBar(
            label: 'App Usage',
            score: snapshot.appUsageScore as double,
            icon: Icons.apps,
            delay: 0,
          ),
          FactorBar(
            label: 'Session Length',
            score: snapshot.sessionScore as double,
            icon: Icons.timer,
            delay: 100,
          ),
          FactorBar(
            label: 'Late Night',
            score: snapshot.lateNightScore as double,
            icon: Icons.nightlight,
            delay: 200,
          ),
          FactorBar(
            label: 'Multitasking',
            score: snapshot.multitaskingScore as double,
            icon: Icons.swap_horiz,
            delay: 300,
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChart(List snapshots) {
    if (snapshots.isEmpty) return const SizedBox.shrink();

    final spots = <FlSpot>[];
    for (int i = 0; i < snapshots.length && i < 50; i++) {
      spots.add(FlSpot(i.toDouble(), (snapshots[i].score as double).clamp(0, 100)));
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: '7-Day Trend',
            subtitle: 'Cognitive load over time',
          ),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: CogniloadTheme.surfaceHighlight,
                    strokeWidth: 1,
                  ),
                  drawVerticalLine: false,
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 25,
                      getTitlesWidget: (v, _) => Text(
                        v.toInt().toString(),
                        style: const TextStyle(
                            color: CogniloadTheme.textMuted, fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minY: 0,
                maxY: 100,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: CogniloadTheme.primary,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: CogniloadTheme.primary.withValues(alpha: 0.08),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendations(List<String> recommendations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: '🧠 AI Insights',
          subtitle: 'Personalized recommendations',
        ),
        ...recommendations.asMap().entries.map((e) =>
            RecommendationCard(recommendation: e.value, index: e.key)),
      ],
    );
  }

  Widget _buildLoadingCard() {
    return GlassCard(
      child: Column(
        children: [
          const SizedBox(height: 20),
          const CircularProgressIndicator(
            color: CogniloadTheme.primary,
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            'Analyzing your cognitive load...',
            style: TextStyle(color: CogniloadTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return GlassCard(
      borderColor: CogniloadTheme.accentRed.withValues(alpha: 0.3),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: CogniloadTheme.accentRed),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Could not load data',
                    style: TextStyle(
                        color: CogniloadTheme.textPrimary,
                        fontWeight: FontWeight.w600)),
                Text(
                  'Grant Usage Access permission in Settings',
                  style: TextStyle(
                      color: CogniloadTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataCard() {
    return const GlassCard(
      child: EmptyStateWidget(
        icon: Icons.analytics_outlined,
        title: 'No Data Yet',
        message: 'Start using your phone and check back in a bit!',
      ),
    );
  }
}
