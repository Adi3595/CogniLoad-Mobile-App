import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_usage_model.dart';
import '../models/settings_model.dart';

class StorageService {
  static const String _usageBox = 'app_usage';
  static const String _sessionsBox = 'sessions';
  static const String _snapshotsBox = 'snapshots';
  static const String _settingsKey = 'app_settings';

  static late Box<AppUsageRecord> _usageRecords;
  static late Box<SessionRecord> _sessionRecords;
  static late Box<CognitiveLoadSnapshot> _snapshots;

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(AppUsageRecordAdapter());
    Hive.registerAdapter(SessionRecordAdapter());
    Hive.registerAdapter(CognitiveLoadSnapshotAdapter());

    _usageRecords = await Hive.openBox<AppUsageRecord>(_usageBox);
    _sessionRecords = await Hive.openBox<SessionRecord>(_sessionsBox);
    _snapshots = await Hive.openBox<CognitiveLoadSnapshot>(_snapshotsBox);
  }

  // App Usage Records
  static Future<void> saveUsageRecord(AppUsageRecord record) async {
    await _usageRecords.add(record);
  }

  static List<AppUsageRecord> getUsageRecords({DateTime? from, DateTime? to}) {
    final records = _usageRecords.values.toList();
    return records.where((r) {
      if (from != null && r.date.isBefore(from)) return false;
      if (to != null && r.date.isAfter(to)) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  static List<AppUsageRecord> getTodayUsage() {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 1));
    return getUsageRecords(from: start, to: end);
  }

  static Future<void> upsertUsageRecord(AppUsageRecord record) async {
    final today = DateTime.now();
    final dayStart = DateTime(today.year, today.month, today.day);
    
    // Find existing record for this app today
    final existing = _usageRecords.values.where((r) =>
        r.packageName == record.packageName &&
        r.date.isAfter(dayStart)).toList();

    if (existing.isNotEmpty) {
      final key = _usageRecords.keyAt(
          _usageRecords.values.toList().indexOf(existing.first));
      await _usageRecords.put(key, record);
    } else {
      await _usageRecords.add(record);
    }
  }

  // Session Records
  static Future<void> saveSession(SessionRecord session) async {
    await _sessionRecords.add(session);
  }

  static Future<void> endSession(String packageName) async {
    final sessions = _sessionRecords.values.toList();
    for (int i = 0; i < sessions.length; i++) {
      if (sessions[i].packageName == packageName && sessions[i].isActive) {
        final updated = sessions[i];
        updated.endTime = DateTime.now();
        await _sessionRecords.putAt(i, updated);
        break;
      }
    }
  }

  static List<SessionRecord> getTodaySessions() {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    return _sessionRecords.values
        .where((s) => s.startTime.isAfter(start))
        .toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  static SessionRecord? getActiveSession(String packageName) {
    try {
      return _sessionRecords.values
          .firstWhere((s) => s.packageName == packageName && s.isActive);
    } catch (_) {
      return null;
    }
  }

  // Cognitive Load Snapshots
  static Future<void> saveSnapshot(CognitiveLoadSnapshot snapshot) async {
    await _snapshots.add(snapshot);
    // Keep only last 30 days
    if (_snapshots.length > 30 * 24) {
      await _snapshots.deleteAt(0);
    }
  }

  static List<CognitiveLoadSnapshot> getSnapshotsLast7Days() {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return _snapshots.values
        .where((s) => s.timestamp.isAfter(cutoff))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  static CognitiveLoadSnapshot? getLatestSnapshot() {
    if (_snapshots.isEmpty) return null;
    return _snapshots.values.reduce((a, b) =>
        a.timestamp.isAfter(b.timestamp) ? a : b);
  }

  // Settings
  static Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_settingsKey);
    if (json == null) return const AppSettings();
    return AppSettings.fromMap(jsonDecode(json));
  }

  static Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toMap()));
  }

  static Future<void> clearAllData() async {
    await _usageRecords.clear();
    await _sessionRecords.clear();
    await _snapshots.clear();
  }
}
