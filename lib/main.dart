import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'screens/dashboard/dashboard_screen.dart';
import 'screens/app_usage/app_usage_screen.dart';
import 'screens/sessions/sessions_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'services/storage_service.dart';
import 'services/background_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  await StorageService.init();

  runApp(
    const ProviderScope(
      child: CogniloadApp(),
    ),
  );
}

class CogniloadApp extends StatelessWidget {
  const CogniloadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cogniload',
      debugShowCheckedModeBanner: false,
      theme: CogniloadTheme.darkTheme,
      home: const MainShell(),
    );
  }
}

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    AppUsageScreen(),
    SessionsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Delay all heavy services — let UI fully render first
    Future.delayed(const Duration(seconds: 5), _initializeServices);
  }

  Future<void> _initializeServices() async {
    // Step 1: Notification permission (Android 13+)
    final notifStatus = await Permission.notification.status;
    if (!notifStatus.isGranted) {
      await Permission.notification.request();
    }

    // Step 2: Battery optimization exemption — prevents Android from
    // killing the background service after a few minutes
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }

    // Step 3: Initialise local notifications plugin
    await NotificationService.init();

    // Step 4: Short grace period then start foreground service
    await Future.delayed(const Duration(seconds: 2));

    await BackgroundTrackingService.init();
    final isRunning = await BackgroundTrackingService.isRunning();
    if (!isRunning) {
      await BackgroundTrackingService.startService();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Removed WithForegroundTask wrapper — it was causing binder overflow
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: CogniloadTheme.surface,
        border: Border(
          top: BorderSide(color: CogniloadTheme.surfaceHighlight, width: 1),
        ),
      ),
      child: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: Colors.transparent,
        indicatorColor: CogniloadTheme.primary.withValues(alpha: 0.15),
        height: 65,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Usage',
          ),
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer),
            label: 'Sessions',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}