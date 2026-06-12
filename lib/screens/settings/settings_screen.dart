import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/app_providers.dart';
import '../../models/settings_model.dart';

import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  bool _apiKeyVisible = false;

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final bgRunning = ref.watch(backgroundRunningProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: settingsAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: CogniloadTheme.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (settings) => _buildContent(settings, bgRunning),
      ),
    );
  }

  Widget _buildContent(AppSettings settings, AsyncValue<bool> bgRunning) {
    if (settings.openAiApiKey != null && _apiKeyController.text.isEmpty) {
      _apiKeyController.text = settings.openAiApiKey!;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Animate(
          effects: const [FadeEffect(), SlideEffect(begin: Offset(0, 0.1))],
          child: _buildSection(
            'Tracking Control',
            Icons.track_changes,
            CogniloadTheme.accentGreen,
            [
              _buildTrackingAlwaysOn(),
              const SizedBox(height: 8),
              _buildBgStatusCard(bgRunning),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Animate(
          delay: const Duration(milliseconds: 100),
          effects: const [FadeEffect(), SlideEffect(begin: Offset(0, 0.1))],
          child: _buildSection(
            'Late Night Hours',
            Icons.nightlight,
            CogniloadTheme.secondary,
            [
              _buildTimeRow(
                'Start Time',
                settings.lateNightStartHour,
                    (h) => ref.read(settingsProvider.notifier).save(
                    settings.copyWith(lateNightStartHour: h)),
              ),
              const SizedBox(height: 8),
              _buildTimeRow(
                'End Time',
                settings.lateNightEndHour,
                    (h) => ref.read(settingsProvider.notifier).save(
                    settings.copyWith(lateNightEndHour: h)),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: CogniloadTheme.secondary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: CogniloadTheme.secondary, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Current window: ${_formatHour(settings.lateNightStartHour)} – ${_formatHour(settings.lateNightEndHour)}',
                        style: const TextStyle(
                            color: CogniloadTheme.secondary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Animate(
          delay: const Duration(milliseconds: 200),
          effects: const [FadeEffect(), SlideEffect(begin: Offset(0, 0.1))],
          child: _buildSection(
            'Usage Limits',
            Icons.timer,
            CogniloadTheme.accent,
            [
              _buildSliderRow(
                'Session Alert',
                settings.sessionAlertMinutes.toDouble(),
                15,
                120,
                '${settings.sessionAlertMinutes}min',
                    (v) => ref.read(settingsProvider.notifier).save(
                    settings.copyWith(sessionAlertMinutes: v.round())),
              ),
              const SizedBox(height: 4),
              _buildSliderRow(
                'Daily Limit',
                settings.dailyLimitMinutes.toDouble(),
                30,
                480,
                '${settings.dailyLimitMinutes ~/ 60}h ${settings.dailyLimitMinutes % 60}m',
                    (v) => ref.read(settingsProvider.notifier).save(
                    settings.copyWith(dailyLimitMinutes: v.round())),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Animate(
          delay: const Duration(milliseconds: 300),
          effects: const [FadeEffect(), SlideEffect(begin: Offset(0, 0.1))],
          child: _buildSection(
            'App Tracking',
            Icons.apps,
            CogniloadTheme.primary,
            [
              _buildInfoRow(
                'Include System Apps',
                'System & Google apps are always tracked',
                Icons.check_circle,
                CogniloadTheme.primary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Animate(
          delay: const Duration(milliseconds: 400),
          effects: const [FadeEffect(), SlideEffect(begin: Offset(0, 0.1))],
          child: _buildSection(
            'AI Recommendations',
            Icons.psychology,
            CogniloadTheme.secondary,
            [
              _buildInfoRow(
                'AI Suggestions',
                'AI-powered insights are always enabled',
                Icons.check_circle,
                CogniloadTheme.secondary,
              ),
              const SizedBox(height: 12),
              const Text(
                'Anthropic API Key (optional)',
                style: TextStyle(
                    color: CogniloadTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _apiKeyController,
                obscureText: !_apiKeyVisible,
                style: const TextStyle(
                    color: CogniloadTheme.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'sk-ant-...',
                  hintStyle: const TextStyle(
                      color: CogniloadTheme.textMuted, fontSize: 13),
                  filled: true,
                  fillColor: CogniloadTheme.surfaceHighlight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _apiKeyVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: CogniloadTheme.textMuted,
                      size: 18,
                    ),
                    onPressed: () =>
                        setState(() => _apiKeyVisible = !_apiKeyVisible),
                  ),
                ),
                onChanged: (v) {
                  ref.read(settingsProvider.notifier).save(
                      settings.copyWith(openAiApiKey: v.isEmpty ? null : v));
                },
              ),
              const SizedBox(height: 6),
              const Text(
                'Without an API key, rule-based recommendations are used.',
                style:
                TextStyle(color: CogniloadTheme.textMuted, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Animate(
          delay: const Duration(milliseconds: 500),
          effects: const [FadeEffect()],
          child: _buildSection(
            'Data',
            Icons.storage,
            CogniloadTheme.accentRed,
            [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: CogniloadTheme.accentRed,
                    side: const BorderSide(
                        color: CogniloadTheme.accentRed, width: 1),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Clear All Data'),
                  onPressed: () => _confirmClear(context),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This will permanently delete all usage history, sessions, and snapshots.',
                style:
                TextStyle(color: CogniloadTheme.textMuted, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        const Center(
          child: Text(
            'Cogniload v1.0.0 • Built with ❤️',
            style: TextStyle(
                color: CogniloadTheme.textMuted, fontSize: 11),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSection(
      String title, IconData icon, Color color, List<Widget> children) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, color: color, size: 15),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: const TextStyle(
                      color: CogniloadTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: CogniloadTheme.surfaceHighlight, height: 1),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTrackingAlwaysOn() {
    return _buildInfoRow(
      'Tracking Active',
      'Monitoring app usage in background',
      Icons.check_circle,
      CogniloadTheme.accentGreen,
    );
  }

  Widget _buildInfoRow(
      String title, String subtitle, IconData icon, Color color) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: CogniloadTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              Text(subtitle,
                  style: const TextStyle(
                      color: CogniloadTheme.textMuted, fontSize: 12)),
            ],
          ),
        ),
        Icon(icon, color: color, size: 22),
      ],
    );
  }

  Widget _buildBgStatusCard(AsyncValue<bool> bgRunning) {
    return bgRunning.when(
      data: (running) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: running
              ? CogniloadTheme.accentGreen.withValues(alpha: 0.08)
              : CogniloadTheme.textMuted.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              running ? Icons.check_circle : Icons.pause_circle,
              color: running
                  ? CogniloadTheme.accentGreen
                  : CogniloadTheme.textMuted,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              running
                  ? 'Background service running'
                  : 'Background service stopped',
              style: TextStyle(
                color: running
                    ? CogniloadTheme.accentGreen
                    : CogniloadTheme.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildTimeRow(String label, int hour, Function(int) onChanged) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  color: CogniloadTheme.textSecondary, fontSize: 13)),
        ),
        GestureDetector(
          onTap: () async {
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(hour: hour, minute: 0),
              builder: (context, child) => Theme(
                data: ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: CogniloadTheme.primary,
                    surface: CogniloadTheme.surfaceElevated,
                  ),
                ),
                child: child!,
              ),
            );
            if (time != null) onChanged(time.hour);
          },
          child: Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: CogniloadTheme.surfaceHighlight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _formatHour(hour),
              style: const TextStyle(
                color: CogniloadTheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSliderRow(String label, double value, double min, double max,
      String display, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    color: CogniloadTheme.textSecondary, fontSize: 13)),
            Text(display,
                style: const TextStyle(
                    color: CogniloadTheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: CogniloadTheme.primary,
            inactiveTrackColor: CogniloadTheme.surfaceHighlight,
            trackHeight: 4,
            thumbColor: CogniloadTheme.primary,
            overlayColor: CogniloadTheme.primary.withValues(alpha: 0.1),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: ((max - min) / 15).round(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }



  String _formatHour(int hour) {
    final period = hour < 12 ? 'AM' : 'PM';
    final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$h:00 $period';
  }

  void _confirmClear(BuildContext context) {
    final currentRef = ref;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CogniloadTheme.surfaceElevated,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: CogniloadTheme.accentRed, size: 22),
            SizedBox(width: 8),
            Text('Delete All Data',
                style: TextStyle(color: CogniloadTheme.textPrimary)),
          ],
        ),
        content: const Text(
          'Are you sure you want to permanently delete all data?\n\n'
              '• All usage history\n'
              '• All session records\n'
              '• All cognitive load snapshots\n'
              '• All cached background data\n\n'
              'This action cannot be undone.',
          style: TextStyle(
              color: CogniloadTheme.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: CogniloadTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);

              final prefs = await SharedPreferences.getInstance();

              // Permanently delete all stored data
              await StorageService.clearAllData();
              await prefs.remove('bg_usage_records');
              await prefs.remove('bg_sessions');
              await prefs.remove('bg_session_starts');
              await prefs.remove('last_daily_limit_alert');
              await prefs.remove('last_late_night_alert');
              await prefs.setString('data_clear_timestamp', DateTime.now().toIso8601String());
              await prefs.remove('known_apps');

              // Remove cognitive notification counts for all days
              final keys = prefs.getKeys().toList();
              for (final key in keys) {
                if (key.startsWith('cognitive_notif_count_')) {
                  await prefs.remove(key);
                }
              }

              currentRef.invalidate(appUsageProvider);
              currentRef.invalidate(cognitiveLoadProvider);
              currentRef.invalidate(sessionsProvider);
              currentRef.invalidate(historicalSnapshotsProvider);
              currentRef.invalidate(weeklyUsageProvider);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All data permanently deleted.'),
                    backgroundColor: CogniloadTheme.accentRed,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Delete Permanently',
                style: TextStyle(
                    color: CogniloadTheme.accentRed,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}