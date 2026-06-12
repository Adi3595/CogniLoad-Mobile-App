import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class PermissionHelper {
  static const _channel = MethodChannel('com.cogniload.app/usage_stats');

  static Future<bool> hasUsageStatsPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasUsageStatsPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openUsageStatsSettings() async {
    try {
      await _channel.invokeMethod('openUsageStatsSettings');
    } catch (_) {}
  }

  static Future<void> openBatteryOptimizationSettings() async {
    try {
      await _channel.invokeMethod('openBatteryOptimizationSettings');
    } catch (_) {}
  }

  static Future<void> showPermissionDialog(BuildContext context) async {
    final hasPermission = await hasUsageStatsPermission();
    if (hasPermission) return;

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: CogniloadTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: CogniloadTheme.accent),
            SizedBox(width: 10),
            Text('Permission Required',
                style: TextStyle(color: CogniloadTheme.textPrimary, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Cogniload needs Usage Access permission to track your app usage and calculate cognitive load.\n\n'
          'Please enable it for Cogniload in the next screen.',
          style: TextStyle(color: CogniloadTheme.textSecondary, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later',
                style: TextStyle(color: CogniloadTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: CogniloadTheme.primary,
              foregroundColor: CogniloadTheme.background,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              openUsageStatsSettings();
            },
            child: const Text('Grant Access',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
