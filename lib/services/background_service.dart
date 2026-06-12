import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:app_usage/app_usage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../models/settings_model.dart';
import '../models/app_usage_model.dart';
import '../services/notification_service.dart';
import '../services/ai_service.dart';
import '../services/cognitive_load_service.dart';
import '../services/app_usage_service.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(CogniloadTaskHandler());
}

class CogniloadTaskHandler extends TaskHandler {
  static const _port = 'cogniload_bg_port';

  final Map<String, DateTime> _sessionStarts = {};
  final Map<String, List<int>> _alertsFired = {};
  String? _lastForegroundApp;
  DateTime? _lastCheckTime;

  final Set<String> _knownApps = {};
  bool _knownAppsLoaded = false;

  final List<int> _cognitiveThresholds = [60, 75, 90];
  final Map<int, String> _cognitiveAlertsFired = {};

  // Multitasking: track each app-switch timestamp (rolling 1-hr window)
  final List<DateTime> _switchTimestamps = [];

  // Per-app daily overuse: key = '${pkg}_${thresholdMin}_${dateKey}'
  final Set<String> _perAppAlertsFired = {};

  // Per-category cooldown tracking
  final Map<String, DateTime> _categoryCooldowns = {};
  static const int _sessionCooldownMinutes = 5;
  static const int _cognitiveCooldownMinutes = 15;
  static const int _lateNightCooldownMinutes = 60;
  static const int _multitaskingCooldownMinutes = 30;
  static const int _perAppUsageCooldownMinutes = 60;

  /// Generate dynamic alert thresholds based on user's session limit setting
  List<int> _buildAlertThresholds(int sessionAlertMinutes) {
    // Create thresholds at: limit, 1.5x, 2x, 3x of user's setting
    final t = sessionAlertMinutes;
    return [
      t,
      (t * 1.5).round(),
      t * 2,
      t * 3,
    ];
  }

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await NotificationService.init();
    await _loadKnownApps();
    await _loadPersistedSessions();
    // Startup ping — confirms the notification pipeline is fully working
    await NotificationService.showServiceStartedNotification();
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    try {
      await _trackSessions();
    } catch (e) {
      // ignore: avoid_print
      print('[Cogniload] _trackSessions error: $e');
    }
    try {
      await _checkLateNight();
    } catch (e) {
      // ignore: avoid_print
      print('[Cogniload] _checkLateNight error: $e');
    }
    try {
      await _checkCognitiveLoad();
    } catch (e) {
      // ignore: avoid_print
      print('[Cogniload] _checkCognitiveLoad error: $e');
    }
    try {
      await _checkMultitasking();
    } catch (e) {
      // ignore: avoid_print
      print('[Cogniload] _checkMultitasking error: $e');
    }
    try {
      await _checkForNewApps();
    } catch (e) {
      // ignore: avoid_print
      print('[Cogniload] _checkForNewApps error: $e');
    }
    _sendDataToUI();
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    _sessionStarts.clear();
    _alertsFired.clear();
  }

  @override
  void onReceiveData(Object data) {
    if (data is Map && data['action'] == 'get_status') {
      _sendDataToUI();
    }
  }

  /// Adjust [start] forward if a data_clear_timestamp exists so cleared data
  /// is never processed by the background service.
  Future<DateTime> _adjustStartForClearTimestamp(
      DateTime start, SharedPreferences prefs) async {
    final clearTimestamp = prefs.getString('data_clear_timestamp');
    if (clearTimestamp != null) {
      final clearTime = DateTime.parse(clearTimestamp);
      if (start.isBefore(clearTime)) {
        return clearTime;
      }
    }
    return start;
  }

  bool _canNotify({bool highPriority = false, String category = 'general'}) {
    if (highPriority) return true;
    final lastTime = _categoryCooldowns[category];
    if (lastTime == null) return true;
    final diff = DateTime.now().difference(lastTime).inMinutes;
    int cooldown;
    switch (category) {
      case 'session':
        cooldown = _sessionCooldownMinutes;
        break;
      case 'cognitive':
        cooldown = _cognitiveCooldownMinutes;
        break;
      case 'late_night':
        cooldown = _lateNightCooldownMinutes;
        break;
      case 'multitasking':
        cooldown = _multitaskingCooldownMinutes;
        break;
      case 'per_app_usage':
        cooldown = _perAppUsageCooldownMinutes;
        break;
      default:
        cooldown = _sessionCooldownMinutes;
    }
    return diff >= cooldown;
  }

  void _recordNotification({String category = 'general'}) {
    _categoryCooldowns[category] = DateTime.now();
  }

  Future<void> _trackSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString('app_settings');
    final settings = settingsJson != null
        ? AppSettings.fromMap(jsonDecode(settingsJson))
        : const AppSettings();

    final now = DateTime.now();
    var checkFrom =
        _lastCheckTime ?? DateTime(now.year, now.month, now.day);
    _lastCheckTime = now;

    // Respect data_clear_timestamp so cleared data stays hidden
    checkFrom = await _adjustStartForClearTimestamp(checkFrom, prefs);
    if (checkFrom.isAfter(now)) return;

    final usageStats = await AppUsage().getAppUsage(checkFrom, now);
    if (usageStats.isEmpty) return;

    usageStats.sort((a, b) => b.usage.compareTo(a.usage));
    final currentApp = usageStats.first;
    final pkg = currentApp.packageName;

    if (_isSystemApp(pkg) && !settings.includeSystemApps) return;
    if (settings.ignoredPackages.contains(pkg)) return;
    if (currentApp.usage.inSeconds < 10) return;

    if (!_sessionStarts.containsKey(pkg)) {
      _sessionStarts[pkg] = now;
      _alertsFired[pkg] = [];
      await _persistSessions();
    }

    if (_lastForegroundApp != null &&
        _lastForegroundApp != pkg &&
        _sessionStarts.containsKey(_lastForegroundApp)) {
      await _saveSessionData(
        _lastForegroundApp!,
        _sessionStarts[_lastForegroundApp]!,
        now,
        AppUsageService.resolveAppName(pkg, currentApp.appName),
      );
      _sessionStarts.remove(_lastForegroundApp);
      _alertsFired.remove(_lastForegroundApp);
      await _persistSessions();
      // Record this switch for multitasking detection
      _switchTimestamps.add(now);
    }

    _lastForegroundApp = pkg;

    final sessionStart = _sessionStarts[pkg]!;
    final sessionMinutes = now.difference(sessionStart).inMinutes;
    final firedAlerts = _alertsFired[pkg] ?? [];

    // Dynamic thresholds from user settings
    final alertThresholds = _buildAlertThresholds(settings.sessionAlertMinutes);

    for (final threshold in alertThresholds) {
      if (sessionMinutes >= threshold && !firedAlerts.contains(threshold)) {
        _alertsFired[pkg]!.add(threshold);

        final appName = AppUsageService.resolveAppName(pkg, currentApp.appName);
        final hour = now.hour;
        final isLateNight = _isInLateNightWindow(
            hour, settings.lateNightStartHour, settings.lateNightEndHour);

        String advice;
        String title;

        if (isLateNight) {
          advice = AIRecommendationService.getContextualInsight(
            trigger: 'late_night',
            score: 0,
            appName: appName,
            durationMinutes: sessionMinutes,
            hour: hour,
          );
          title = '🌙 Late Night Session — $appName';
        } else {
          advice = AIRecommendationService.getContextualInsight(
            trigger: 'session',
            score: 0,
            appName: appName,
            durationMinutes: sessionMinutes,
          );
          title = AIRecommendationService.getSessionAlertTitle(
              appName, sessionMinutes);
        }

        if (_canNotify(category: 'session')) {
          await NotificationService.showSessionAlert(
            appName: appName,
            durationMinutes: sessionMinutes,
            advice: advice,
            title: title,
            thresholdMinutes: threshold,
          );
          _recordNotification(category: 'session');
        }
      }
    }

    await _checkDailyLimit(usageStats, settings);
    await _checkPerAppUsage(usageStats, settings);
    await _saveUsageData(usageStats, settings);
  }

  /// Fires when the user switches apps >= 8 times within any rolling 60-min window.
  Future<void> _checkMultitasking() async {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(hours: 1));

    // Keep only the last hour of switch timestamps
    _switchTimestamps.removeWhere((t) => t.isBefore(cutoff));

    final switchCount = _switchTimestamps.length;
    if (switchCount < 8) return; // below threshold
    if (!_canNotify(category: 'multitasking')) return;

    final String insight;
    if (switchCount >= 15) {
      insight = 'You\'ve switched apps $switchCount times in the last hour — '
          'extreme context-switching reduces focus and productivity by up to 40%, '
          'and significantly increases mental fatigue. '
          'Try single-tasking: finish one thing before moving on.';
    } else {
      insight = 'You\'ve switched apps $switchCount times in the last hour. '
          'Frequent context-switching drains cognitive resources and breaks deep focus. '
          'Consider batching similar tasks and minimising interruptions.';
    }

    await NotificationService.showMultitaskingAlert(
      switchCount: switchCount,
      insight: insight,
    );
    _recordNotification(category: 'multitasking');
  }

  /// Fires when a single app\'s total usage today exceeds 60 / 120 / 180 minutes.
  Future<void> _checkPerAppUsage(
      List<AppUsageInfo> usageStats, AppSettings settings) async {
    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month}-${now.day}';
    const thresholds = [60, 120, 180]; // minutes

    for (final stat in usageStats) {
      final pkg = stat.packageName;
      if (_isSystemApp(pkg) && !settings.includeSystemApps) continue;
      if (settings.ignoredPackages.contains(pkg)) continue;

      final usageMin = stat.usage.inMinutes;
      if (usageMin < 60) continue; // skip under 1 hour

      // Fire for each threshold milestone exactly once per day per app
      for (final threshold in thresholds) {
        if (usageMin < threshold) break; // list is ascending — no higher threshold possible
        final alertKey = '${pkg}_${threshold}_$todayKey';
        if (_perAppAlertsFired.contains(alertKey)) continue;
        if (!_canNotify(category: 'per_app_usage')) continue;

        _perAppAlertsFired.add(alertKey);
        final appName = AppUsageService.resolveAppName(pkg, stat.appName);
        final hours = usageMin ~/ 60;
        final mins = usageMin % 60;
        final durationStr = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';

        final String insight;
        if (threshold >= 180) {
          insight = 'You\'ve spent $durationStr on $appName today — '
              'this level of single-app usage is severely impacting your cognitive load. '
              'Take a significant break and consider a digital detox for the rest of the day.';
        } else if (threshold >= 120) {
          insight = 'You\'ve spent $durationStr on $appName today. '
              'Extended single-app sessions elevate stress hormones and reduce creative thinking. '
              'Consider a 15-minute break every hour.';
        } else {
          insight = 'You\'ve spent $durationStr on $appName today. '
              'Mindful usage helps — try setting a soft limit and taking breaks '
              'to protect your attention span.';
        }

        await NotificationService.showPerAppUsageAlert(
          appName: appName,
          usageMinutes: usageMin,
          insight: insight,
        );
        _recordNotification(category: 'per_app_usage');
        break; // Only alert the highest reached threshold this cycle; next cycle picks up the next one
      }
    }
  }

  Future<void> _checkLateNight() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString('app_settings');
    final settings = settingsJson != null
        ? AppSettings.fromMap(jsonDecode(settingsJson))
        : const AppSettings();

    final now = DateTime.now();
    final hour = now.hour;

    if (!_isInLateNightWindow(
        hour, settings.lateNightStartHour, settings.lateNightEndHour)) {
      return;
    }

    final lastAlert = prefs.getString('last_late_night_alert');
    if (lastAlert != null &&
        now.difference(DateTime.parse(lastAlert)).inHours < 1) {
      return;
    }

    if (!_canNotify(category: 'late_night')) return;

    final appName = _lastForegroundApp != null
        ? AppUsageService.resolveAppName(_lastForegroundApp!, '')
        : null;
    final currentSessionMins = _lastForegroundApp != null &&
        _sessionStarts.containsKey(_lastForegroundApp)
        ? now.difference(_sessionStarts[_lastForegroundApp]!).inMinutes
        : 0;

    final advice = AIRecommendationService.getContextualInsight(
      trigger: 'late_night',
      score: 0,
      appName: appName,
      durationMinutes: currentSessionMins,
      hour: hour,
    );

    await NotificationService.showLateNightAlert(customMessage: advice);
    await prefs.setString('last_late_night_alert', now.toIso8601String());
    _recordNotification(category: 'late_night');
  }

  Future<void> _checkCognitiveLoad() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString('app_settings');
    final settings = settingsJson != null
        ? AppSettings.fromMap(jsonDecode(settingsJson))
        : const AppSettings();

    final now = DateTime.now();
    var todayStart = DateTime(now.year, now.month, now.day);
    todayStart = await _adjustStartForClearTimestamp(todayStart, prefs);
    if (todayStart.isAfter(now)) return;
    final usageStats = await AppUsage().getAppUsage(todayStart, now);

    final records = usageStats
        .where((s) => !_isSystemApp(s.packageName) && s.usage.inMinutes >= 1)
        .map((s) => AppUsageRecord(
              packageName: s.packageName,
              appName: s.appName,
              usageMinutes: s.usage.inMinutes,
              date: now,
              launchCount: 1,
            ))
        .toList();

    if (records.isEmpty) return;

    final result = CognitiveLoadCalculator.calculate(
      todayUsage: records,
      todaySessions: [],
      settings: settings,
    );

    final score = result.overallScore;
    final todayKey = '${now.year}-${now.month}-${now.day}';

    for (final threshold in _cognitiveThresholds) {
      if (score >= threshold) {
        final lastFiredDate = _cognitiveAlertsFired[threshold];
        if (lastFiredDate == todayKey) continue;

        final dailyCount = int.tryParse(
                prefs.getString('cognitive_notif_count_$todayKey') ?? '0') ??
            0;
        if (threshold >= 90 && dailyCount >= 5) continue;
        if (threshold < 90 && dailyCount >= 3) continue;

        final isHighPriority = threshold >= 90;
        if (!_canNotify(highPriority: isHighPriority, category: 'cognitive'))
          continue;

        final appName = _lastForegroundApp != null
            ? AppUsageService.resolveAppName(_lastForegroundApp!, '')
            : null;

        final insight = AIRecommendationService.getContextualInsight(
          trigger: 'cognitive_load',
          score: score,
          appName: appName,
        );

        await NotificationService.showCognitiveLoadAlert(
          score: score,
          insight: insight,
          threshold: threshold,
        );

        // Dedicated AI suggestion notification
        final aiSuggestion = AIRecommendationService.getContextualInsight(
          trigger: 'cognitive_load',
          score: score,
          appName: appName,
        );
        await NotificationService.showAISuggestionNotification(
          suggestion: aiSuggestion,
          cognitiveScore: score,
        );

        _cognitiveAlertsFired[threshold] = todayKey;
        await prefs.setString(
            'cognitive_notif_count_$todayKey', '${dailyCount + 1}');

        if (!isHighPriority) _recordNotification(category: 'cognitive');
      }
    }
  }

  Future<void> _loadKnownApps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final known = prefs.getStringList('known_apps') ?? [];
      _knownApps.addAll(known);
      _knownAppsLoaded = true;
    } catch (_) {
      _knownAppsLoaded = true;
    }
  }

  Future<void> _checkForNewApps() async {
    if (!_knownAppsLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      var todayStart = DateTime(now.year, now.month, now.day);
      todayStart = await _adjustStartForClearTimestamp(todayStart, prefs);
      if (todayStart.isAfter(now)) return;
      final usageStats = await AppUsage().getAppUsage(todayStart, now);

      final List<String> newlyDiscovered = [];

      for (final usage in usageStats) {
        final pkg = usage.packageName;
        if (_isSystemApp(pkg)) continue;
        if (usage.usage.inMinutes < 1) continue;
        if (_knownApps.contains(pkg)) continue;

        _knownApps.add(pkg);
        newlyDiscovered.add(pkg);

        final insight =
        AIRecommendationService.getNewAppInsight(pkg, usage.appName);

        if (insight != null && _canNotify()) {
          await NotificationService.showNewAppDetectedNotification(
            appName: usage.appName.isNotEmpty
                ? usage.appName
                : _cleanPackageName(pkg),
            title: insight['notificationTitle'] as String,
            body: insight['notificationBody'] as String,
          );
          _recordNotification();
          break;
        }
      }

      if (newlyDiscovered.isNotEmpty) {
        await prefs.setStringList('known_apps', _knownApps.toList());
      }
    } catch (_) {}
  }

  bool _isInLateNightWindow(int hour, int start, int end) {
    if (start <= end) {
      return hour >= start && hour < end;
    } else {
      return hour >= start || hour < end;
    }
  }

  Future<void> _saveSessionData(
      String packageName,
      DateTime start,
      DateTime end,
      String appName,
      ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessions = prefs.getStringList('bg_sessions') ?? [];
      sessions.add(jsonEncode({
        'packageName': packageName,
        'appName': appName,
        'startTime': start.toIso8601String(),
        'endTime': end.toIso8601String(),
        'durationMinutes': end.difference(start).inMinutes,
      }));
      if (sessions.length > 100) {
        sessions.removeRange(0, sessions.length - 100);
      }
      await prefs.setStringList('bg_sessions', sessions);
    } catch (_) {}
  }

  Future<void> _saveUsageData(
      List<AppUsageInfo> stats, AppSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final records = prefs.getStringList('bg_usage_records') ?? [];
      for (final usage in stats) {
        if (_isSystemApp(usage.packageName) && !settings.includeSystemApps) {
          continue;
        }
        if (usage.usage.inMinutes < 1) continue;
        records.add(jsonEncode({
          'packageName': usage.packageName,
          'appName': usage.appName,
          'usageMinutes': usage.usage.inMinutes,
          'timestamp': DateTime.now().toIso8601String(),
        }));
      }
      if (records.length > 200) {
        records.removeRange(0, records.length - 200);
      }
      await prefs.setStringList('bg_usage_records', records);
    } catch (_) {}
  }

  Future<void> _checkDailyLimit(
      List<AppUsageInfo> stats, AppSettings settings) async {
    final totalMinutes = stats.fold(0, (s, u) => s + u.usage.inMinutes);
    if (totalMinutes >= settings.dailyLimitMinutes) {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final today = '${now.year}-${now.month}-${now.day}';
      final lastAlert = prefs.getString('last_daily_limit_alert');
      if (lastAlert != today && _canNotify()) {
        await prefs.setString('last_daily_limit_alert', today);
        await NotificationService.showDailyLimitAlert(
          minutesUsed: totalMinutes,
          limitMinutes: settings.dailyLimitMinutes,
        );
        _recordNotification();
      }
    }
  }

  bool _isSystemApp(String packageName) {
    const systemPrefixes = [
      'com.android.',
      'com.google.android.',
      'android.',
      'com.miui.',
      'com.samsung.',
      'com.coloros.',
      'com.oplus.',
    ];
    for (final prefix in systemPrefixes) {
      if (packageName.startsWith(prefix)) return true;
    }
    return false;
  }

  String _cleanPackageName(String packageName) {
    return AppUsageService.resolveAppName(packageName, '');
  }

  /// Persist session starts to SharedPreferences so they survive service restarts
  Future<void> _persistSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, String> data = {};
      _sessionStarts.forEach((pkg, time) {
        data[pkg] = time.toIso8601String();
      });
      await prefs.setString('bg_session_starts', jsonEncode(data));
    } catch (_) {}
  }

  /// Load persisted session starts on service restart
  Future<void> _loadPersistedSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('bg_session_starts');
      if (raw == null) return;
      final Map<String, dynamic> data = jsonDecode(raw);
      data.forEach((pkg, timeStr) {
        final time = DateTime.tryParse(timeStr as String);
        if (time != null) {
          // Only restore sessions from today
          final now = DateTime.now();
          if (time.year == now.year && time.month == now.month && time.day == now.day) {
            _sessionStarts[pkg] = time;
            _alertsFired[pkg] = [];
          }
        }
      });
    } catch (_) {}
  }

  void _sendDataToUI() {
    final SendPort? send = IsolateNameServer.lookupPortByName(_port);
    send?.send({
      'status': 'running',
      'activeSessions': _sessionStarts.length,
      'currentApp': _lastForegroundApp,
    });
  }
}

class BackgroundTrackingService {
  static Future<void> init() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'cogniload_service',
        channelName: 'Cogniload Tracking',
        channelDescription: 'Monitors app usage for cognitive load analysis',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(30000), // 30 s
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  static Future<bool> startService() async {
    if (await FlutterForegroundTask.isRunningService) return true;
    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'Cogniload Active',
      notificationText: 'Monitoring your cognitive load...',
      callback: startCallback,
    );
    return await FlutterForegroundTask.isRunningService;
  }

  static Future<bool> stopService() async {
    await FlutterForegroundTask.stopService();
    return !(await FlutterForegroundTask.isRunningService);
  }

  static Future<bool> isRunning() async {
    return await FlutterForegroundTask.isRunningService;
  }

  static Future<void> updateNotification(String text) async {
    await FlutterForegroundTask.updateService(
      notificationTitle: 'Cogniload Active',
      notificationText: text,
    );
  }
}