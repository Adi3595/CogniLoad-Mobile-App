import 'dart:typed_data';
import 'package:app_usage/app_usage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_usage_model.dart';
import '../models/settings_model.dart';

class AppUsageService {
  static const Set<String> _systemPrefixes = {
    'com.android.',
    'com.google.android.',
    'android.',
    'com.miui.',
    'com.samsung.',
    'com.sec.',
    'com.oneplus.',
    'com.oppo.',
    'com.vivo.',
    'com.coloros.',
    'com.oplus.',
  };

  /// Known package → friendly display name mapping for popular apps
  static const Map<String, String> _knownAppNames = {
    'com.instagram.android': 'Instagram',
    'com.facebook.katana': 'Facebook',
    'com.facebook.lite': 'Facebook Lite',
    'com.facebook.orca': 'Messenger',
    'com.whatsapp': 'WhatsApp',
    'com.whatsapp.w4b': 'WhatsApp Business',
    'org.telegram.messenger': 'Telegram',
    'com.twitter.android': 'Twitter',
    'com.twitter.android.lite': 'Twitter Lite',
    'com.snapchat.android': 'Snapchat',
    'com.linkedin.android': 'LinkedIn',
    'com.pinterest': 'Pinterest',
    'com.tumblr': 'Tumblr',
    'com.reddit.frontpage': 'Reddit',
    'com.zhiliaoapp.musically': 'TikTok',
    'com.ss.android.ugc.trill': 'TikTok',
    'com.google.android.youtube': 'YouTube',
    'com.netflix.mediaclient': 'Netflix',
    'com.amazon.avod.thirdpartyclient': 'Prime Video',
    'in.startv.hotstar': 'Hotstar',
    'com.jio.media.jiobeats': 'JioCinema',
    'com.sonyliv': 'SonyLIV',
    'com.graymatrix.did': 'Zee5',
    'com.spotify.music': 'Spotify',
    'com.gaana': 'Gaana',
    'com.jio.media.ondemand': 'JioSaavn',
    'in.amazon.mShop.android.shopping': 'Amazon',
    'com.flipkart.android': 'Flipkart',
    'com.myntra.android': 'Myntra',
    'com.android.chrome': 'Chrome',
    'org.mozilla.firefox': 'Firefox',
    'com.opera.browser': 'Opera',
    'com.brave.browser': 'Brave',
    'com.microsoft.emmx': 'Edge',
    'com.google.android.gm': 'Gmail',
    'com.microsoft.office.outlook': 'Outlook',
    'com.yahoo.mobile.client.android.mail': 'Yahoo Mail',
    'com.google.android.apps.maps': 'Google Maps',
    'com.ubercab': 'Uber',
    'com.olacabs.customer': 'Ola',
    'com.discord': 'Discord',
    'com.viber.voip': 'Viber',
    'jp.naver.line.android': 'LINE',
    'com.supercell.clashofclans': 'Clash of Clans',
    'com.supercell.clashroyale': 'Clash Royale',
    'com.tencent.ig': 'PUBG Mobile',
    'com.dts.freefireth': 'Free Fire',
    'com.mojang.minecraftpe': 'Minecraft',
    'com.roblox.client': 'Roblox',
    'com.activision.callofduty.shooter': 'Call of Duty Mobile',
    'com.google.android.apps.docs': 'Google Docs',
    'com.google.android.apps.docs.editors.sheets': 'Google Sheets',
    'com.google.android.apps.docs.editors.slides': 'Google Slides',
    'com.microsoft.office.word': 'Microsoft Word',
    'com.microsoft.office.excel': 'Microsoft Excel',
    'us.zoom.videomeetings': 'Zoom',
    'com.google.android.apps.meetings': 'Google Meet',
    'com.microsoft.teams': 'Microsoft Teams',
    'com.Slack': 'Slack',
    'com.notion.id': 'Notion',
    'com.swiggy.android': 'Swiggy',
    'com.application.zomato': 'Zomato',
    'com.phonepe.app': 'PhonePe',
    'net.one97.paytm': 'Paytm',
    'com.google.android.apps.nbu.paisa.user': 'Google Pay',
  };

  static bool isSystemApp(String packageName) {
    for (final prefix in _systemPrefixes) {
      if (packageName.startsWith(prefix)) return true;
    }
    return false;
  }

  static Future<List<AppUsageRecord>> getTodayUsage(AppSettings settings) async {
    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      return await _getUsage(start, now, settings);
    } catch (e) {
      return [];
    }
  }

  static Future<List<AppUsageRecord>> getWeeklyUsage(AppSettings settings) async {
    try {
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 7));
      return await _getUsage(start, now, settings);
    } catch (e) {
      return [];
    }
  }

  static Future<List<AppUsageRecord>> _getUsage(
      DateTime start, DateTime end, AppSettings settings) async {

    // Data hiding via clear timestamp
    // When user clears data, a timestamp is saved. Any usage before that
    // timestamp is hidden — looks deleted to the user but OS data is intact.
    // Removing the timestamp (Restore) makes everything visible again.
    final prefs = await SharedPreferences.getInstance();
    final clearTimestamp = prefs.getString('data_clear_timestamp');
    if (clearTimestamp != null) {
      final clearTime = DateTime.parse(clearTimestamp);
      if (start.isBefore(clearTime)) {
        start = clearTime;
      }
      if (end.isBefore(clearTime)) {
        return [];
      }
    }

    final stats = await AppUsage().getAppUsage(start, end);
    final List<AppUsageRecord> records = [];

    for (final stat in stats) {
      if (!settings.includeSystemApps && isSystemApp(stat.packageName)) continue;
      if (settings.ignoredPackages.contains(stat.packageName)) continue;
      if (stat.usage.inMinutes < 1) continue;

      final appName = resolveAppName(stat.packageName, stat.appName);

      records.add(AppUsageRecord(
        packageName: stat.packageName,
        appName: appName,
        usageMinutes: stat.usage.inMinutes,
        date: end,
        launchCount: 1,
      ));
    }

    records.sort((a, b) => b.usageMinutes.compareTo(a.usageMinutes));
    return records;
  }

  static Future<Uint8List?> getAppIcon(String packageName) async {
    return null;
  }

  static String _cleanPackageName(String packageName) {
    // Check known names first
    if (_knownAppNames.containsKey(packageName)) {
      return _knownAppNames[packageName]!;
    }

    final parts = packageName.split('.');
    if (parts.isEmpty) return packageName;

    // Skip generic/meaningless segments
    const skipSegments = {
      'android', 'app', 'mobile', 'lite', 'client', 'application',
      'com', 'org', 'net', 'io', 'in', 'me', 'co', 'main',
    };

    // Find the most meaningful segment (walk backwards, skip generic ones)
    for (int i = parts.length - 1; i >= 0; i--) {
      final segment = parts[i].toLowerCase();
      if (segment.isEmpty || skipSegments.contains(segment)) continue;
      final name = parts[i];
      return name[0].toUpperCase() + name.substring(1);
    }

    // Fallback: capitalize last segment
    final last = parts.last;
    if (last.isEmpty) return packageName;
    return last[0].toUpperCase() + last.substring(1);
  }

  /// Public accessor so other services can resolve names too
  static String resolveAppName(String packageName, String rawAppName) {
    if (_knownAppNames.containsKey(packageName)) {
      return _knownAppNames[packageName]!;
    }
    if (rawAppName.isNotEmpty) {
      // Check if the raw name is a generic segment like "Android"
      final lower = rawAppName.toLowerCase();
      if (lower == 'android' || lower == 'app' || lower == 'mobile') {
        return _cleanPackageName(packageName);
      }
      return rawAppName;
    }
    return _cleanPackageName(packageName);
  }

  static String formatDuration(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  static String getAppCategory(String packageName) {
    final pkg = packageName.toLowerCase();
    if (pkg.contains('youtube') || pkg.contains('netflix') ||
        pkg.contains('prime') || pkg.contains('hulu') ||
        pkg.contains('hotstar') || pkg.contains('jiocinema')) return 'Entertainment';
    if (pkg.contains('instagram') || pkg.contains('facebook') ||
        pkg.contains('twitter') || pkg.contains('tiktok') ||
        pkg.contains('snapchat') || pkg.contains('linkedin')) return 'Social Media';
    if (pkg.contains('gmail') || pkg.contains('outlook') ||
        pkg.contains('mail')) return 'Email';
    if (pkg.contains('chrome') || pkg.contains('firefox') ||
        pkg.contains('browser') || pkg.contains('opera')) return 'Browser';
    if (pkg.contains('spotify') || pkg.contains('music') ||
        pkg.contains('gaana') || pkg.contains('jiosaavn')) return 'Music';
    if (pkg.contains('game') || pkg.contains('pubg') ||
        pkg.contains('freefire') || pkg.contains('clash')) return 'Gaming';
    if (pkg.contains('whatsapp') || pkg.contains('telegram') ||
        pkg.contains('signal') || pkg.contains('messenger')) return 'Messaging';
    if (pkg.contains('maps') || pkg.contains('navigation') ||
        pkg.contains('uber') || pkg.contains('ola')) return 'Navigation';
    if (pkg.contains('camera') || pkg.contains('gallery') ||
        pkg.contains('photo')) return 'Photos';
    return 'Other';
  }
}