import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_usage_model.dart';
import '../models/settings_model.dart';
import '../services/storage_service.dart';
import '../services/app_usage_service.dart';
import '../services/cognitive_load_service.dart';
import '../services/ai_service.dart';
import '../services/background_service.dart';

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    return await StorageService.loadSettings();
  }

  Future<void> save(AppSettings settings) async {
    state = AsyncData(settings);
    await StorageService.saveSettings(settings);
  }

  Future<void> toggleTracking() async {
    final current = state.value ?? const AppSettings();
    final updated = current.copyWith(trackingEnabled: !current.trackingEnabled);
    await save(updated);
    if (updated.trackingEnabled) {
      await BackgroundTrackingService.startService();
    } else {
      await BackgroundTrackingService.stopService();
    }
  }
}

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

class AppUsageNotifier extends AsyncNotifier<List<AppUsageRecord>> {
  @override
  Future<List<AppUsageRecord>> build() async {
    return _fetchUsage();
  }

  Future<List<AppUsageRecord>> _fetchUsage() async {
    final settings = await ref.read(settingsProvider.future);
    return AppUsageService.getTodayUsage(settings);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchUsage);
  }
}

final appUsageProvider =
AsyncNotifierProvider<AppUsageNotifier, List<AppUsageRecord>>(
  AppUsageNotifier.new,
);

final weeklyUsageProvider =
FutureProvider.autoDispose<List<AppUsageRecord>>((ref) async {
  final settings = await ref.watch(settingsProvider.future);
  return AppUsageService.getWeeklyUsage(settings);
});

class SessionsNotifier extends AsyncNotifier<List<SessionRecord>> {
  @override
  Future<List<SessionRecord>> build() async {
    return StorageService.getTodaySessions();
  }

  Future<void> refresh() async {
    state = AsyncData(StorageService.getTodaySessions());
  }

  Future<void> startSession(String packageName, String appName) async {
    final existing = StorageService.getActiveSession(packageName);
    if (existing != null) return;
    final session = SessionRecord(
      packageName: packageName,
      appName: appName,
      startTime: DateTime.now(),
    );
    await StorageService.saveSession(session);
    await refresh();
  }

  Future<void> endSession(String packageName) async {
    await StorageService.endSession(packageName);
    await refresh();
  }
}

final sessionsProvider =
AsyncNotifierProvider<SessionsNotifier, List<SessionRecord>>(
  SessionsNotifier.new,
);

class CognitiveLoadNotifier extends AsyncNotifier<CognitiveLoadSnapshot?> {
  @override
  Future<CognitiveLoadSnapshot?> build() async {
    // Watch dependent providers so this auto-rebuilds when they change
    final usage = await ref.watch(appUsageProvider.future);
    final sessions = await ref.watch(sessionsProvider.future);
    final settings = await ref.watch(settingsProvider.future);
    return _calculateScore(usage, sessions, settings);
  }

  Future<CognitiveLoadSnapshot?> _calculateScore(
    List<AppUsageRecord> usage,
    List<SessionRecord> sessions,
    AppSettings settings,
  ) async {
    final result = CognitiveLoadCalculator.calculate(
      todayUsage: usage,
      todaySessions: sessions,
      settings: settings,
    );

    final recs = await AIRecommendationService.generateRecommendations(
      cognitiveLoadScore: result.overallScore,
      usageRecords: usage,
      appUsageScore: result.appUsageScore,
      sessionScore: result.sessionScore,
      lateNightScore: result.lateNightScore,
      multitaskingScore: result.multitaskingScore,
      settings: settings,
      apiKey: settings.openAiApiKey,
    );

    final snapshot = CognitiveLoadSnapshot(
      score: result.overallScore,
      timestamp: DateTime.now(),
      appUsageScore: result.appUsageScore,
      sessionScore: result.sessionScore,
      lateNightScore: result.lateNightScore,
      multitaskingScore: result.multitaskingScore,
      recommendations: recs,
    );

    await StorageService.saveSnapshot(snapshot);
    return snapshot;
  }

  Future<void> refresh() async {
    // Invalidate upstream providers to force fresh data fetches
    ref.invalidate(appUsageProvider);
    ref.invalidate(sessionsProvider);
    // Invalidate self to rebuild with the fresh upstream data
    ref.invalidate(cognitiveLoadProvider);
  }
}

final cognitiveLoadProvider =
AsyncNotifierProvider<CognitiveLoadNotifier, CognitiveLoadSnapshot?>(
  CognitiveLoadNotifier.new,
);

final historicalSnapshotsProvider =
FutureProvider.autoDispose<List<CognitiveLoadSnapshot>>((ref) async {
  return StorageService.getSnapshotsLast7Days();
});

final backgroundRunningProvider = StreamProvider<bool>((ref) async* {
  while (true) {
    await Future.delayed(const Duration(seconds: 5));
    yield await BackgroundTrackingService.isRunning();
  }
});

final autoRefreshProvider = Provider<void>((ref) {
  final timer = Timer.periodic(const Duration(minutes: 5), (_) {
    ref.invalidate(appUsageProvider);
    ref.invalidate(sessionsProvider);
    // cognitiveLoadProvider will auto-rebuild because it watches appUsageProvider
  });
  ref.onDispose(timer.cancel);
});