import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../providers/app_providers.dart';
import '../../models/app_usage_model.dart';
import '../../services/app_usage_service.dart';
import '../../services/ai_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

class SessionsScreen extends ConsumerStatefulWidget {
  const SessionsScreen({super.key});

  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  final Map<String, Uint8List?> _iconCache = {};

  Future<Uint8List?> _getIcon(String pkg) async {
    if (_iconCache.containsKey(pkg)) return _iconCache[pkg];
    final icon = await AppUsageService.getAppIcon(pkg);
    _iconCache[pkg] = icon;
    return icon;
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(sessionsProvider);
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sessions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(sessionsProvider.notifier).refresh(),
          ),
        ],
      ),
      body: sessionsAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: CogniloadTheme.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (sessions) {
          final threshold = settingsAsync.value?.sessionAlertMinutes ?? 45;
          return _buildContent(sessions, threshold);
        },
      ),
    );
  }

  Widget _buildContent(List<SessionRecord> sessions, int threshold) {
    final active = sessions.where((s) => s.isActive).toList();
    final completed = sessions.where((s) => !s.isActive).toList();
    final longSessions = sessions.where((s) => s.durationMinutes >= threshold).toList();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildSessionStats(sessions, threshold),
                const SizedBox(height: 16),
                if (longSessions.isNotEmpty)
                  _buildAlertBanner(longSessions, threshold),
              ],
            ),
          ),
        ),
        if (active.isNotEmpty) ...[
          _buildSectionSliver('Active Sessions', active.length),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Animate(
                  delay: Duration(milliseconds: i * 50),
                  effects: const [FadeEffect()],
                  child: _buildSessionCard(active[i], threshold, isActive: true),
                ),
              ),
              childCount: active.length,
            ),
          ),
        ],
        if (completed.isNotEmpty) ...[
          _buildSectionSliver('Completed Today', completed.length),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Animate(
                  delay: Duration(milliseconds: i * 30),
                  effects: const [FadeEffect()],
                  child: _buildSessionCard(completed[i], threshold, isActive: false),
                ),
              ),
              childCount: completed.length,
            ),
          ),
        ],
        if (sessions.isEmpty)
          SliverFillRemaining(
            child: const EmptyStateWidget(
              icon: Icons.hourglass_empty,
              title: 'No Sessions Yet',
              message:
                  'Sessions will be tracked as you use apps throughout the day.',
            ),
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
      ],
    );
  }

  Widget _buildSessionStats(List<SessionRecord> sessions, int threshold) {
    final totalSessions = sessions.length;
    final longCount = sessions.where((s) => s.durationMinutes >= threshold).length;
    final avgDuration = sessions.isEmpty
        ? 0
        : sessions.fold(0, (s, r) => s + r.durationMinutes) ~/ sessions.length;

    return GlassCard(
      child: Row(
        children: [
          Expanded(
            child: _statBox('$totalSessions', 'Total', CogniloadTheme.primary),
          ),
          Container(width: 1, height: 40, color: CogniloadTheme.surfaceHighlight),
          Expanded(
            child: _statBox('$longCount', 'Long Sessions', CogniloadTheme.accent),
          ),
          Container(width: 1, height: 40, color: CogniloadTheme.surfaceHighlight),
          Expanded(
            child: _statBox('${avgDuration}m', 'Avg Duration', CogniloadTheme.secondary),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String value, String label, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 20, fontWeight: FontWeight.w800)),
        Text(label,
            style:
                const TextStyle(color: CogniloadTheme.textMuted, fontSize: 10)),
      ],
    );
  }

  Widget _buildAlertBanner(List<SessionRecord> longSessions, int threshold) {
    return Animate(
      effects: const [FadeEffect(), SlideEffect(begin: Offset(0, -0.1))],
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: CogniloadTheme.accentRed.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CogniloadTheme.accentRed.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: CogniloadTheme.accentRed, size: 18),
                const SizedBox(width: 8),
                Text(
                  '${longSessions.length} session${longSessions.length > 1 ? 's' : ''} exceeded ${threshold}min',
                  style: const TextStyle(
                    color: CogniloadTheme.accentRed,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              AIRecommendationService.getSessionAdvice(
                  longSessions.first.appName, longSessions.first.durationMinutes),
              style: const TextStyle(
                  color: CogniloadTheme.textSecondary, fontSize: 12, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionSliver(String title, int count) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            Text(title,
                style: const TextStyle(
                    color: CogniloadTheme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: CogniloadTheme.surfaceHighlight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                    color: CogniloadTheme.textSecondary, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(SessionRecord session, int threshold,
      {required bool isActive}) {
    final duration = session.durationMinutes;
    final isLong = duration >= threshold;
    final color = isActive
        ? CogniloadTheme.accentGreen
        : isLong
            ? CogniloadTheme.accentRed
            : CogniloadTheme.textMuted;

    final progress = (duration / threshold).clamp(0.0, 1.5);

    return GlassCard(
      borderColor: isLong
          ? CogniloadTheme.accentRed.withValues(alpha: 0.3)
          : isActive
              ? CogniloadTheme.accentGreen.withValues(alpha: 0.3)
              : null,
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              FutureBuilder<Uint8List?>(
                future: _getIcon(session.packageName),
                builder: (_, snap) => AppIconWidget(
                  iconBytes: snap.data,
                  appName: session.appName,
                  size: 36,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            session.appName,
                            style: const TextStyle(
                              color: CogniloadTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: CogniloadTheme.accentGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle,
                                    size: 6,
                                    color: CogniloadTheme.accentGreen),
                                SizedBox(width: 3),
                                Text('Active',
                                    style: TextStyle(
                                        color: CogniloadTheme.accentGreen,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        if (isLong && !isActive)
                          const Icon(Icons.warning_amber,
                              color: CogniloadTheme.accentRed, size: 16),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${DateFormat('h:mm a').format(session.startTime)}'
                      '${session.endTime != null ? ' → ${DateFormat('h:mm a').format(session.endTime!)}' : ' → now'}',
                      style: const TextStyle(
                          color: CogniloadTheme.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${duration}m',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    isLong ? 'Over limit' : 'In range',
                    style: TextStyle(
                      color: color.withValues(alpha: 0.7),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress > 1.0 ? 1.0 : progress,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0m',
                  style: const TextStyle(
                      color: CogniloadTheme.textMuted, fontSize: 9)),
              Text(
                '${(progress * 100).toInt()}% of ${threshold}min limit',
                style: TextStyle(
                    color: color.withValues(alpha: 0.8),
                    fontSize: 9,
                    fontWeight: FontWeight.w500),
              ),
              Text('${threshold}m',
                  style: const TextStyle(
                      color: CogniloadTheme.textMuted, fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }
}
