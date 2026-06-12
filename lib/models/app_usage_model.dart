import 'package:hive/hive.dart';

part 'app_usage_model.g.dart';

@HiveType(typeId: 0)
class AppUsageRecord extends HiveObject {
  @HiveField(0)
  final String packageName;

  @HiveField(1)
  final String appName;

  @HiveField(2)
  final int usageMinutes;

  @HiveField(3)
  final DateTime date;

  @HiveField(4)
  final int launchCount;

  @HiveField(5)
  final String? category;

  AppUsageRecord({
    required this.packageName,
    required this.appName,
    required this.usageMinutes,
    required this.date,
    required this.launchCount,
    this.category,
  });
}

@HiveType(typeId: 1)
class SessionRecord extends HiveObject {
  @HiveField(0)
  final String packageName;

  @HiveField(1)
  final String appName;

  @HiveField(2)
  final DateTime startTime;

  @HiveField(3)
  DateTime? endTime;

  @HiveField(4)
  bool alertSent;

  SessionRecord({
    required this.packageName,
    required this.appName,
    required this.startTime,
    this.endTime,
    this.alertSent = false,
  });

  int get durationMinutes {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime).inMinutes;
  }

  bool get isActive => endTime == null;
}

@HiveType(typeId: 2)
class CognitiveLoadSnapshot extends HiveObject {
  @HiveField(0)
  final double score;

  @HiveField(1)
  final DateTime timestamp;

  @HiveField(2)
  final double appUsageScore;

  @HiveField(3)
  final double sessionScore;

  @HiveField(4)
  final double lateNightScore;

  @HiveField(5)
  final double multitaskingScore;

  @HiveField(6)
  final List<String> recommendations;

  CognitiveLoadSnapshot({
    required this.score,
    required this.timestamp,
    required this.appUsageScore,
    required this.sessionScore,
    required this.lateNightScore,
    required this.multitaskingScore,
    required this.recommendations,
  });
}

class AppInfo {
  final String packageName;
  final String appName;
  final String? category;
  bool isSystemApp;

  AppInfo({
    required this.packageName,
    required this.appName,
    this.category,
    this.isSystemApp = false,
  });
}
