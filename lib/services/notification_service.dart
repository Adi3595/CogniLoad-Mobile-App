import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const int _sessionAlertId = 1000;
  static const int _lateNightAlertId = 1001;
  static const int _dailyLimitId = 1002;
  static const int _cognitiveLoadId = 1003;
  static const int _newAppId = 1004;
  static const int _multitaskingAlertId = 2000;
  static const int _perAppUsageAlertId = 3000;

  static Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
    _initialized = true;
  }

  static void _onNotificationTap(NotificationResponse response) {}

  static Future<void> showSessionAlert({
    required String appName,
    required int durationMinutes,
    required String advice,
    String? title,
    int? thresholdMinutes,
  }) async {
    final alertTitle = title ?? '⏱️ Session Alert — $appName';
    // Use unique ID per threshold so notifications stack instead of replacing
    final notifId = _sessionAlertId + (thresholdMinutes ?? durationMinutes);
    await _plugin.show(
      notifId,
      alertTitle,
      advice,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'session_alerts',
          'Session Alerts',
          channelDescription: 'Smart alerts when you exceed session time limits',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(
            advice,
            contentTitle: alertTitle,
          ),
        ),
      ),
    );
  }

  static Future<void> showLateNightAlert({String? customMessage}) async {
    final message = customMessage ??
        'Using your phone now suppresses melatonin for up to 3 hours. '
            'Put it down and get proper rest — your brain consolidates memories during sleep.';
    await _plugin.show(
      _lateNightAlertId,
      '🌙 Late Night Screen Time',
      message,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'late_night',
          'Late Night Alerts',
          channelDescription: 'Alerts for late-night screen usage',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(
            message,
            contentTitle: '🌙 Late Night Screen Time',
          ),
        ),
      ),
    );
  }

  static Future<void> showDailyLimitAlert({
    required int minutesUsed,
    required int limitMinutes,
  }) async {
    final hours = minutesUsed ~/ 60;
    final mins = minutesUsed % 60;
    final message =
        'You\'ve reached your daily limit of ${limitMinutes ~/ 60}h. '
        'Total today: ${hours}h ${mins}m. '
        'Consider a screen-free activity for the next hour.';
    await _plugin.show(
      _dailyLimitId,
      '📊 Daily Screen Limit Reached',
      message,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_limits',
          'Daily Limit Alerts',
          channelDescription: 'Alerts when daily usage limits are reached',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          styleInformation: BigTextStyleInformation(
            message,
            contentTitle: '📊 Daily Screen Limit Reached',
          ),
        ),
      ),
    );
  }

  static Future<void> showCognitiveLoadAlert({
    required double score,
    required String insight,
    int? threshold,
  }) async {
    String title;
    if (score >= 90) {
      title = '🔴 Critical Cognitive Load — ${score.toStringAsFixed(0)}/100';
    } else if (score >= 75) {
      title = '🟠 High Cognitive Load — ${score.toStringAsFixed(0)}/100';
    } else {
      title = '🟡 Cognitive Load Rising — ${score.toStringAsFixed(0)}/100';
    }
    // Unique ID per threshold level so each alert stacks
    final notifId = _cognitiveLoadId + (threshold ?? score.toInt());
    await _plugin.show(
      notifId,
      title,
      insight,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'cognitive_load',
          'Cognitive Load Alerts',
          channelDescription: 'Proactive alerts when cognitive load rises',
          importance:
          score >= 90 ? Importance.high : Importance.defaultImportance,
          priority: score >= 90 ? Priority.high : Priority.defaultPriority,
          styleInformation: BigTextStyleInformation(
            insight,
            contentTitle: title,
          ),
        ),
      ),
    );
  }

  /// Dedicated AI suggestion notification that pops up at cognitive thresholds
  static Future<void> showAISuggestionNotification({
    required String suggestion,
    required double cognitiveScore,
  }) async {
    const notifId = 1005;
    final title = '🧠 AI Suggestion — Score ${cognitiveScore.toStringAsFixed(0)}/100';
    await _plugin.show(
      notifId + cognitiveScore.toInt(),
      title,
      suggestion,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'ai_suggestions',
          'AI Suggestions',
          channelDescription: 'Smart AI-powered suggestions based on your usage',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(
            suggestion,
            contentTitle: title,
          ),
        ),
      ),
    );
  }

  static Future<void> showNewAppDetectedNotification({
    required String appName,
    required String title,
    required String body,
  }) async {
    await _plugin.show(
      _newAppId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'new_app_detected',
          'New App Insights',
          channelDescription:
          'Cognitive impact insights when you use a new app',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          styleInformation: BigTextStyleInformation(
            body,
            contentTitle: title,
          ),
        ),
      ),
    );
  }

  /// Fires when the user switches apps too frequently in the last hour.
  static Future<void> showMultitaskingAlert({
    required int switchCount,
    required String insight,
  }) async {
    final title = switchCount >= 15
        ? '⚡ Extreme Multitasking — $switchCount app switches/hr'
        : '⚡ High Multitasking — $switchCount app switches/hr';
    await _plugin.show(
      _multitaskingAlertId,
      title,
      insight,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'multitasking_alerts',
          'Multitasking Alerts',
          channelDescription:
              'Alerts when you switch apps too frequently, increasing cognitive strain',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(
            insight,
            contentTitle: title,
          ),
        ),
      ),
    );
  }

  /// Fires when a single app accumulates excessive usage in one day.
  static Future<void> showPerAppUsageAlert({
    required String appName,
    required int usageMinutes,
    required String insight,
  }) async {
    final hours = usageMinutes ~/ 60;
    final mins = usageMinutes % 60;
    final durationStr = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';
    final title = '📱 App Overuse — $appName ($durationStr today)';
    // Unique ID per app so multiple apps can stack simultaneously
    final notifId = _perAppUsageAlertId + (appName.hashCode.abs() % 900);
    await _plugin.show(
      notifId,
      title,
      insight,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'app_overuse',
          'App Overuse Alerts',
          channelDescription:
              'Alerts when you spend too long on a single app today',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(
            insight,
            contentTitle: title,
          ),
        ),
      ),
    );
  }

  /// Fires once when the background service starts — confirms the full
  /// notification pipeline (permission + channels + plugin) is working.
  static Future<void> showServiceStartedNotification() async {
    await _plugin.show(
      9999,
      '✅ Cogniload is Active',
      'Background tracking started. You\'ll receive alerts when thresholds are reached.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'service_status',
          'Service Status',
          channelDescription: 'Background service status updates',
          importance: Importance.low,
          priority: Priority.low,
          autoCancel: true,
        ),
      ),
    );
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}