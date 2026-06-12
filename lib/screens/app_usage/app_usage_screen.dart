import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../providers/app_providers.dart';
import '../../models/app_usage_model.dart';
import '../../services/app_usage_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

class AppUsageScreen extends ConsumerStatefulWidget {
  const AppUsageScreen({super.key});

  @override
  ConsumerState<AppUsageScreen> createState() => _AppUsageScreenState();
}

class _AppUsageScreenState extends ConsumerState<AppUsageScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<String, Uint8List?> _iconCache = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<Uint8List?> _getIcon(String packageName) async {
    if (_iconCache.containsKey(packageName)) return _iconCache[packageName];
    final icon = await AppUsageService.getAppIcon(packageName);
    _iconCache[packageName] = icon;
    return icon;
  }

  @override
  Widget build(BuildContext context) {
    final usageAsync = ref.watch(appUsageProvider);
    final weeklyAsync = ref.watch(weeklyUsageProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Usage'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(appUsageProvider.notifier).refresh(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: CogniloadTheme.primary,
          labelColor: CogniloadTheme.primary,
          unselectedLabelColor: CogniloadTheme.textMuted,
          tabs: const [
            Tab(text: 'Today'),
            Tab(text: 'This Week'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          usageAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: CogniloadTheme.primary)),
            error: (e, _) => _buildPermissionError(),
            data: (records) => _buildUsageList(records),
          ),
          weeklyAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: CogniloadTheme.primary)),
            error: (e, _) => _buildPermissionError(),
            data: (records) => _buildWeeklyView(records),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageList(List<AppUsageRecord> records) {
    if (records.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.phone_android,
        title: 'No Usage Data',
        message:
            'Start using apps and come back. Make sure Usage Access is granted.',
      );
    }

    final totalMinutes = records.fold(0, (s, r) => s + r.usageMinutes);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildTodaySummary(records, totalMinutes),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _buildCategoryChart(records),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'All Apps — ${records.length} tracked',
              style: const TextStyle(
                color: CogniloadTheme.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final record = records[index];
              return Animate(
                delay: Duration(milliseconds: index * 30),
                effects: const [FadeEffect(), SlideEffect(begin: Offset(0, 0.1))],
                child: _buildAppTile(record, totalMinutes, index),
              );
            },
            childCount: records.length,
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
      ],
    );
  }

  Widget _buildTodaySummary(List<AppUsageRecord> records, int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    final topApp = records.isNotEmpty ? records.first : null;

    return GlassCard(
      child: Row(
        children: [
          Expanded(
            child: _statItem(
              '${hours}h ${mins}m',
              'Total Screen Time',
              Icons.access_time,
              CogniloadTheme.primary,
            ),
          ),
          Container(
            width: 1,
            height: 50,
            color: CogniloadTheme.surfaceHighlight,
          ),
          Expanded(
            child: _statItem(
              '${records.length}',
              'Apps Used',
              Icons.apps,
              CogniloadTheme.secondary,
            ),
          ),
          Container(
            width: 1,
            height: 50,
            color: CogniloadTheme.surfaceHighlight,
          ),
          Expanded(
            child: _statItem(
              topApp != null
                  ? AppUsageService.formatDuration(topApp.usageMinutes)
                  : '—',
              topApp?.appName ?? 'Top App',
              Icons.star,
              CogniloadTheme.accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: CogniloadTheme.textMuted, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChart(List<AppUsageRecord> records) {
    // Group by category
    final Map<String, int> categories = {};
    for (final r in records) {
      final cat = AppUsageService.getAppCategory(r.packageName);
      categories[cat] = (categories[cat] ?? 0) + r.usageMinutes;
    }

    final sorted = categories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5 = sorted.take(5).toList();

    if (top5.isEmpty) return const SizedBox.shrink();

    final colors = [
      CogniloadTheme.primary,
      CogniloadTheme.secondary,
      CogniloadTheme.accent,
      CogniloadTheme.accentGreen,
      CogniloadTheme.accentRed,
    ];

    final total = top5.fold(0, (s, e) => s + e.value);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'By Category'),
          Row(
            children: [
              SizedBox(
                height: 120,
                width: 120,
                child: PieChart(
                  PieChartData(
                    sections: top5.asMap().entries.map((e) {
                      return PieChartSectionData(
                        value: e.value.value.toDouble(),
                        color: colors[e.key % colors.length],
                        radius: 40,
                        showTitle: false,
                      );
                    }).toList(),
                    centerSpaceRadius: 30,
                    sectionsSpace: 2,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: top5.asMap().entries.map((e) {
                    final pct = (e.value.value / total * 100).toStringAsFixed(0);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: colors[e.key % colors.length],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(e.value.key,
                                style: const TextStyle(
                                    color: CogniloadTheme.textSecondary,
                                    fontSize: 11)),
                          ),
                          Text('$pct%',
                              style: TextStyle(
                                  color: colors[e.key % colors.length],
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppTile(AppUsageRecord record, int totalMinutes, int index) {
    final pct = totalMinutes > 0
        ? record.usageMinutes / totalMinutes
        : 0.0;
    final color = _colorForPercentage(pct);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            FutureBuilder<Uint8List?>(
              future: _getIcon(record.packageName),
              builder: (_, snap) => AppIconWidget(
                iconBytes: snap.data,
                appName: record.appName,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.appName,
                    style: const TextStyle(
                      color: CogniloadTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppUsageService.getAppCategory(record.packageName),
                    style: const TextStyle(
                      color: CogniloadTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct.clamp(0.0, 1.0),
                      backgroundColor: color.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  AppUsageService.formatDuration(record.usageMinutes),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${(pct * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: CogniloadTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _colorForPercentage(double pct) {
    if (pct > 0.3) return CogniloadTheme.accentRed;
    if (pct > 0.15) return CogniloadTheme.accent;
    if (pct > 0.05) return CogniloadTheme.primary;
    return CogniloadTheme.accentGreen;
  }

  Widget _buildWeeklyView(List<AppUsageRecord> records) {
    if (records.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.bar_chart,
        title: 'No Weekly Data',
        message: 'Data will appear after using your device for a day.',
      );
    }

    final totalMinutes = records.fold(0, (s, r) => s + r.usageMinutes);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Weekly Summary'),
              Row(
                children: [
                  Expanded(
                    child: _statItem(
                      '${totalMinutes ~/ 60}h ${totalMinutes % 60}m',
                      'Total This Week',
                      Icons.calendar_today,
                      CogniloadTheme.primary,
                    ),
                  ),
                  Expanded(
                    child: _statItem(
                      '${(totalMinutes / 7).round()}m',
                      'Daily Average',
                      Icons.trending_up,
                      CogniloadTheme.secondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...records.take(20).toList().asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Animate(
                delay: Duration(milliseconds: e.key * 30),
                effects: const [FadeEffect()],
                child: _buildAppTile(e.value, totalMinutes, e.key),
              ),
            )),
      ],
    );
  }

  Widget _buildPermissionError() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline,
              size: 64, color: CogniloadTheme.accent),
          const SizedBox(height: 16),
          const Text(
            'Usage Access Required',
            style: TextStyle(
              color: CogniloadTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'To track app usage, please grant Usage Access permission.\n\nGo to Settings → Apps → Special App Access → Usage Access → Cogniload',
            textAlign: TextAlign.center,
            style: TextStyle(color: CogniloadTheme.textSecondary, fontSize: 14, height: 1.6),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: CogniloadTheme.primary,
              foregroundColor: CogniloadTheme.background,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              // In production, this would open usage access settings
              // openAppSettings();
            },
            child: const Text('Open Settings',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
