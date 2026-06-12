import '../models/app_usage_model.dart';
import '../models/settings_model.dart';

class CognitiveLoadCalculator {
  /// Calculate overall cognitive load score (0-100, higher = more stressed)
  static CognitiveLoadResult calculate({
    required List<AppUsageRecord> todayUsage,
    required List<SessionRecord> todaySessions,
    required AppSettings settings,
  }) {
    final appUsageScore = _calculateAppUsageScore(todayUsage, settings);
    final sessionScore = _calculateSessionScore(todaySessions, settings);
    final lateNightScore = _calculateLateNightScore(todayUsage, settings);
    final multitaskingScore = _calculateMultitaskingScore(todaySessions);

    // Weighted average
    final overall = (appUsageScore * 0.35) +
        (sessionScore * 0.30) +
        (lateNightScore * 0.20) +
        (multitaskingScore * 0.15);

    return CognitiveLoadResult(
      overallScore: overall.clamp(0, 100),
      appUsageScore: appUsageScore.clamp(0, 100),
      sessionScore: sessionScore.clamp(0, 100),
      lateNightScore: lateNightScore.clamp(0, 100),
      multitaskingScore: multitaskingScore.clamp(0, 100),
    );
  }

  static double _calculateAppUsageScore(
      List<AppUsageRecord> records, AppSettings settings) {
    if (records.isEmpty) return 0;

    final totalMinutes = records.fold(0, (s, r) => s + r.usageMinutes);
    final limitMinutes = settings.dailyLimitMinutes;

    // Score based on how far over limit
    final ratio = totalMinutes / limitMinutes;
    if (ratio <= 0.5) return ratio * 30; // 0-15
    if (ratio <= 1.0) return 15 + (ratio - 0.5) * 70; // 15-50
    if (ratio <= 2.0) return 50 + (ratio - 1.0) * 30; // 50-80
    return 80 + (ratio - 2.0) * 10; // 80-100
  }

  static double _calculateSessionScore(
      List<SessionRecord> sessions, AppSettings settings) {
    if (sessions.isEmpty) return 0;

    double maxScore = 0;
    for (final session in sessions) {
      final duration = session.durationMinutes;
      final threshold = settings.sessionAlertMinutes;
      final ratio = duration / threshold;

      double score;
      if (ratio <= 0.5) {
        score = ratio * 20;
      } else if (ratio <= 1.0) {
        score = 10 + (ratio - 0.5) * 80;
      } else {
        score = 50 + (ratio - 1.0) * 30;
      }
      if (score > maxScore) maxScore = score;
    }

    // Factor in total number of long sessions
    final longSessions = sessions.where((s) =>
        s.durationMinutes > settings.sessionAlertMinutes).length;

    return (maxScore + longSessions * 5).clamp(0, 100);
  }

  static double _calculateLateNightScore(
      List<AppUsageRecord> records, AppSettings settings) {
    // Check if current time is in late-night window
    final now = DateTime.now();
    final hour = now.hour;

    final isLateNight = settings.lateNightStartHour <= settings.lateNightEndHour
        ? (hour >= settings.lateNightStartHour && hour < settings.lateNightEndHour)
        : (hour >= settings.lateNightStartHour || hour < settings.lateNightEndHour);

    if (!isLateNight) {
      // Still factor in if there was late-night usage recently
      return 0;
    }

    // Late night usage is highly penalized
    final totalMinutes = records.fold(0, (s, r) => s + r.usageMinutes);
    if (totalMinutes == 0) return 20; // Late night + any usage is bad
    if (totalMinutes < 15) return 40;
    if (totalMinutes < 30) return 65;
    if (totalMinutes < 60) return 80;
    return 95;
  }

  static double _calculateMultitaskingScore(List<SessionRecord> sessions) {
    if (sessions.length < 2) return 0;

    // Count app switches in the last hour
    final lastHour = DateTime.now().subtract(const Duration(hours: 1));
    final recentSessions = sessions.where((s) =>
        s.startTime.isAfter(lastHour)).toList();

    final switchCount = recentSessions.length;
    if (switchCount <= 3) return switchCount * 5.0;
    if (switchCount <= 8) return 15 + (switchCount - 3) * 10.0;
    if (switchCount <= 15) return 65 + (switchCount - 8) * 5.0;
    return 100;
  }

  static Map<String, double> getHourlyScores(
      List<CognitiveLoadSnapshot> snapshots) {
    final Map<String, double> hourly = {};
    for (final snapshot in snapshots) {
      final key = '${snapshot.timestamp.hour}:00';
      hourly[key] = snapshot.score;
    }
    return hourly;
  }

  static List<DailyScore> getDailyScores(
      List<CognitiveLoadSnapshot> snapshots) {
    final Map<String, List<double>> daily = {};
    for (final s in snapshots) {
      final key =
          '${s.timestamp.year}-${s.timestamp.month}-${s.timestamp.day}';
      daily.putIfAbsent(key, () => []).add(s.score);
    }
    return daily.entries.map((e) {
      final avg = e.value.reduce((a, b) => a + b) / e.value.length;
      final parts = e.key.split('-');
      return DailyScore(
        date: DateTime(int.parse(parts[0]), int.parse(parts[1]),
            int.parse(parts[2])),
        averageScore: avg,
      );
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }
}

class CognitiveLoadResult {
  final double overallScore;
  final double appUsageScore;
  final double sessionScore;
  final double lateNightScore;
  final double multitaskingScore;

  const CognitiveLoadResult({
    required this.overallScore,
    required this.appUsageScore,
    required this.sessionScore,
    required this.lateNightScore,
    required this.multitaskingScore,
  });
}

class DailyScore {
  final DateTime date;
  final double averageScore;

  DailyScore({required this.date, required this.averageScore});
}
