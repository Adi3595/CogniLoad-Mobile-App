import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/app_usage_model.dart';
import '../models/settings_model.dart';

class AIRecommendationService {
  static const String _anthropicUrl = 'https://api.anthropic.com/v1/messages';

  static const Map<String, Map<String, dynamic>> _categoryDatabase = {
    'short_form_video': {
      'label': 'Short-Form Video',
      'avgDailyMinutes': 89,
      'suggestedLimitMinutes': 30,
      'cognitiveImpact': 'High',
      'researchFinding':
      'Continuous short-form video reduces attention span and increases dopamine dependency. Studies show 30min is the threshold before focus degradation.',
      'keywords': ['tiktok', 'reels', 'shorts', 'mxtakatak', 'josh', 'moj'],
    },
    'social_media': {
      'label': 'Social Media',
      'avgDailyMinutes': 53,
      'suggestedLimitMinutes': 30,
      'cognitiveImpact': 'Moderate-High',
      'researchFinding':
      'Social media use above 30min/day is linked to increased anxiety and reduced self-esteem. Comparison triggers cortisol spikes.',
      'keywords': [
        'instagram', 'facebook', 'twitter', 'snapchat', 'linkedin', 'pinterest', 'tumblr'
      ],
    },
    'streaming': {
      'label': 'Video Streaming',
      'avgDailyMinutes': 72,
      'suggestedLimitMinutes': 60,
      'cognitiveImpact': 'Moderate',
      'researchFinding':
      'Streaming causes passive cognitive drain. Autoplay features extend sessions 20% beyond intended. Avoid 1hr before sleep.',
      'keywords': [
        'youtube', 'netflix', 'hotstar', 'prime', 'hulu',
        'jiocinema', 'sonyliv', 'zee5', 'voot'
      ],
    },
    'messaging': {
      'label': 'Messaging',
      'avgDailyMinutes': 38,
      'suggestedLimitMinutes': 0,
      'cognitiveImpact': 'Low-Moderate',
      'researchFinding':
      'Messaging itself has low cognitive load, but compulsive checking (10+ times/hour) creates anxiety and fragments focus.',
      'keywords': [
        'whatsapp', 'telegram', 'signal', 'messenger', 'viber', 'line', 'discord'
      ],
    },
    'gaming': {
      'label': 'Gaming',
      'avgDailyMinutes': 54,
      'suggestedLimitMinutes': 45,
      'cognitiveImpact': 'High',
      'researchFinding':
      'High-intensity gaming spikes adrenaline and cortisol. Focus degradation occurs after 45min. Performance actually drops with longer sessions.',
      'keywords': [
        'pubg', 'freefire', 'clash', 'game', 'gaming',
        'battleground', 'fortnite', 'minecraft', 'roblox', 'cod'
      ],
    },
    'news': {
      'label': 'News & Information',
      'avgDailyMinutes': 28,
      'suggestedLimitMinutes': 20,
      'cognitiveImpact': 'Moderate',
      'researchFinding':
      'News consumption above 30min/day increases anxiety without improving decision-making. Batch news to one 20min session per day.',
      'keywords': [
        'news', 'inshorts', 'dailyhunt', 'ndtv', 'times', 'reddit', 'flipboard'
      ],
    },
    'browser': {
      'label': 'Web Browser',
      'avgDailyMinutes': 45,
      'suggestedLimitMinutes': 30,
      'cognitiveImpact': 'Moderate',
      'researchFinding':
      'Each open browser tab consumes working memory. Tab switching reduces productivity by up to 40%. Close unused tabs regularly.',
      'keywords': ['chrome', 'firefox', 'safari', 'opera', 'brave', 'browser', 'edge'],
    },
    'email': {
      'label': 'Email',
      'avgDailyMinutes': 32,
      'suggestedLimitMinutes': 0,
      'cognitiveImpact': 'Low',
      'researchFinding':
      'Email has low cognitive load unless checked compulsively. Batch to 2-3 sessions daily for maximum productivity.',
      'keywords': ['gmail', 'outlook', 'mail', 'yahoo', 'proton'],
    },
    'music': {
      'label': 'Music & Audio',
      'avgDailyMinutes': 55,
      'suggestedLimitMinutes': 0,
      'cognitiveImpact': 'Low',
      'researchFinding':
      'Background music has low cognitive load and can improve focus. Active browsing/playlist building is more distracting.',
      'keywords': ['spotify', 'music', 'gaana', 'jiosaavn', 'wynk', 'hungama', 'soundcloud'],
    },
    'utility': {
      'label': 'Utility',
      'avgDailyMinutes': 10,
      'suggestedLimitMinutes': 0,
      'cognitiveImpact': 'Minimal',
      'researchFinding': 'Utility apps have minimal cognitive impact.',
      'keywords': [
        'camera', 'calculator', 'clock', 'calendar',
        'maps', 'files', 'settings', 'gallery', 'photos'
      ],
    },
    'work': {
      'label': 'Work & Productivity',
      'avgDailyMinutes': 90,
      'suggestedLimitMinutes': 0,
      'cognitiveImpact': 'Context-Dependent',
      'researchFinding':
      'Work apps require deep focus. Take breaks every 45min using Pomodoro technique for best cognitive performance.',
      'keywords': [
        'zoom', 'meet', 'teams', 'slack', 'notion',
        'docs', 'sheets', 'drive', 'office', 'word', 'excel'
      ],
    },
  };

  static const Map<String, List<String>> _appSessionAdvice = {
    'instagram': [
      'You\'ve been scrolling Instagram for {duration}min. The algorithm is designed to keep you here — you\'ve likely seen everything new. Close it and do something intentional.',
      'Instagram for {duration}min is draining your dopamine reserves. Try writing down 3 things you\'re grateful for instead.',
      'After {duration}min on Instagram, ask yourself: did you feel better or worse after opening it? Put it down for at least 30 minutes.',
    ],
    'facebook': [
      '{duration}min on Facebook is enough to catch up. Continued scrolling rarely adds value — it mostly adds anxiety.',
      'You\'ve spent {duration}min on Facebook. Step away and do a 2-minute breathing exercise before your next task.',
      'Facebook for {duration}min increases cortisol levels. Take a walk or drink water before returning.',
    ],
    'twitter': [
      '{duration}min on Twitter/X is cognitively exhausting due to high information density. Your brain needs a break.',
      'After {duration}min of Twitter, your working memory is likely saturated. Step away for 10 minutes before any focused work.',
      'Twitter for {duration}min exposes you to many conflicting opinions. Ground yourself with 5 deep breaths.',
    ],
    'tiktok': [
      'TikTok for {duration}min rewires your attention span. Try watching one long-form video instead to reset focus.',
      '{duration}min of TikTok is equivalent to hundreds of micro-interruptions to your brain. Take a 15-minute screen-free break.',
      'You\'ve been on TikTok for {duration}min. Short-form video reduces your ability to focus on longer tasks. Step away now.',
    ],
    'snapchat': [
      '{duration}min on Snapchat — you\'ve likely caught up. The FOMO feeling is artificial. Close it.',
      'Snapchat for {duration}min is enough. Constant checking increases anxiety — try setting specific times to check it.',
    ],
    'linkedin': [
      '{duration}min on LinkedIn can trigger comparison anxiety. Remember: people only post highlights. Step away.',
      'After {duration}min on LinkedIn, take a break. Career comparison is draining — focus on your own progress.',
    ],
    'youtube': [
      'You\'ve watched YouTube for {duration}min. If it\'s educational, take notes to retain what you learned. If it\'s entertainment, consider stopping at a natural break point.',
      '{duration}min of YouTube — autoplay is keeping you here. Decide intentionally: is the next video worth your time?',
      'After {duration}min on YouTube, your eyes need rest. Apply the 20-20-20 rule: look at something 20 feet away for 20 seconds.',
    ],
    'netflix': [
      '{duration}min of Netflix — decide consciously if you want another episode, don\'t just let it autoplay.',
      'After {duration}min of streaming, take a 10-minute break. Stand up, stretch, get water before the next episode.',
      '{duration}min of Netflix before sleep significantly impacts sleep quality. Consider stopping now for better rest.',
    ],
    'hotstar': [
      '{duration}min of streaming — take a break, stretch, and hydrate before continuing.',
      'You\'ve been watching for {duration}min. Your eyes need rest — look away for 20 seconds at a distant object.',
    ],
    'prime': [
      '{duration}min of Prime Video — take a conscious break before the next episode starts automatically.',
      'After {duration}min of streaming, stand up and move around for 5 minutes. Your body needs it.',
    ],
    'whatsapp': [
      '{duration}min on WhatsApp likely means you\'re checking constantly. Try batching replies — check every 2 hours instead.',
      'After {duration}min on WhatsApp, step away. Constant availability increases stress. It\'s okay to respond later.',
      '{duration}min of WhatsApp — if you\'ve replied to everything urgent, put it away. The rest can wait.',
    ],
    'telegram': [
      '{duration}min on Telegram — consider muting non-essential groups and checking on a schedule.',
      'After {duration}min, you\'ve likely caught up on Telegram. Close it and return to your main task.',
    ],
    'messenger': [
      '{duration}min on Messenger is enough. Try batching your conversations rather than checking constantly.',
    ],
    'chrome': [
      '{duration}min of browsing — if you\'re researching, write down your key findings before continuing. If you\'re leisure browsing, take a 10-minute break.',
      'After {duration}min of Chrome, close unnecessary tabs. Tab overload increases cognitive load significantly.',
      '{duration}min of browsing — are you still on your original task or have you drifted? Refocus or take a break.',
    ],
    'firefox': [
      '{duration}min of browsing — close tabs you\'re done with. Each open tab is a small mental burden.',
      'After {duration}min, take a break from the browser. Your brain needs to consolidate what you\'ve read.',
    ],
    'game': [
      '{duration}min of gaming — take a break to prevent eye strain and mental fatigue. A 10-minute walk will reset you.',
      'After {duration}min of gaming, your reflexes and focus will start declining. A short break actually improves performance.',
      '{duration}min of gaming is a good session. Rest now to retain the skills you\'ve practiced.',
    ],
    'pubg': [
      '{duration}min of PUBG — high-intensity gaming drains adrenaline. Take a break to avoid frustration in the next match.',
      'After {duration}min, step away from PUBG. Playing while mentally fatigued leads to poor decisions and frustration.',
    ],
    'gmail': [
      '{duration}min on Gmail — if you\'ve processed the urgent emails, close it. Constant email checking fragments focus.',
      'After {duration}min of email, take a break. Try batching email to 2-3 times per day for better productivity.',
    ],
    'outlook': [
      '{duration}min on Outlook is enough to handle urgent items. Close it and batch the rest for later.',
    ],
    'spotify': [
      '{duration}min of Spotify — if you\'re using it as background music for focus, that\'s fine. If you\'re actively browsing, it\'s becoming a distraction.',
    ],
    'default': [
      'You\'ve been on this app for {duration}min. Take a short break to reset your focus and reduce cognitive load.',
      'After {duration}min, step away for 5 minutes. Even a brief pause significantly improves focus and retention.',
      '{duration}min is a good session length. Take a break, hydrate, and return with fresh eyes.',
    ],
  };

  static String detectCategory(String packageName, String appName) {
    final combined = '${packageName.toLowerCase()} ${appName.toLowerCase()}';
    final utilityKeys = _categoryDatabase['utility']!['keywords'] as List;
    for (final k in utilityKeys) {
      if (combined.contains(k as String)) return 'utility';
    }
    for (final entry in _categoryDatabase.entries) {
      if (entry.key == 'utility') continue;
      final keywords = entry.value['keywords'] as List;
      for (final k in keywords) {
        if (combined.contains(k as String)) return entry.key;
      }
    }
    return 'unknown';
  }

  static Map<String, dynamic>? getNewAppInsight(
      String packageName, String appName) {
    final category = detectCategory(packageName, appName);
    if (category == 'utility' || category == 'unknown') return null;
    final data = _categoryDatabase[category]!;
    final avg = data['avgDailyMinutes'] as int;
    final limit = data['suggestedLimitMinutes'] as int;
    final impact = data['cognitiveImpact'] as String;
    final research = data['researchFinding'] as String;
    final label = data['label'] as String;
    return {
      'category': label,
      'cognitiveImpact': impact,
      'avgDailyMinutes': avg,
      'suggestedLimitMinutes': limit,
      'notificationTitle': '📲 New App Detected — $appName',
      'notificationBody': limit > 0
          ? 'People spend avg ${avg}min/day on $label apps. $research We\'ve flagged a ${limit}min session limit for you.'
          : 'People spend avg ${avg}min/day on $label apps. $research We\'ll monitor your usage pattern.',
      'dashboardInsight':
      '$appName is a $label app (Cognitive Impact: $impact). $research',
    };
  }

  static String getContextualInsight({
    required String trigger,
    required double score,
    String? appName,
    int? durationMinutes,
    int? hour,
  }) {
    switch (trigger) {
      case 'late_night':
        final app = appName ?? 'your phone';
        final time = hour != null ? _formatHour(hour) : 'late night';
        final duration = durationMinutes ?? 0;
        if (duration > 60) {
          return 'You\'ve been on $app for ${duration}min at $time. '
              'This level of late-night use delays sleep onset by up to 90 minutes '
              'and will raise tomorrow\'s cognitive load score significantly.';
        } else if (duration > 30) {
          return 'Using $app at $time suppresses melatonin production. '
              'Even 30 minutes of screen time this late pushes your sleep cycle back. '
              'Put it down now for better rest and lower cognitive load tomorrow.';
        }
        return 'Screen use at $time affects sleep quality even in short bursts. '
            'Your brain needs darkness to prepare for rest. '
            'Close $app and try a non-screen wind-down routine.';

      case 'cognitive_load':
        if (score >= 90) {
          return 'Your cognitive load has reached ${score.toStringAsFixed(0)}/100 — critical territory. '
              'Your brain\'s working memory is severely overloaded. '
              'Stop all screen activity for at least 1 hour to allow recovery.';
        } else if (score >= 75) {
          final app = appName ?? 'multiple apps';
          return 'Cognitive load at ${score.toStringAsFixed(0)}/100. '
              'Heavy use of $app combined with frequent switching is draining your focus. '
              'A 20-minute screen break now will restore 60% of your focus capacity.';
        }
        return 'Your cognitive load is at ${score.toStringAsFixed(0)}/100 and rising. '
            'Take a short break before it reaches the high zone. '
            'Even 10 minutes away from screens makes a measurable difference.';

      case 'session':
        final app = appName ?? 'this app';
        final duration = durationMinutes ?? 0;
        return getSessionAdvice(app, duration);

      default:
        return 'Take a break to reduce your cognitive load.';
    }
  }

  static String getSessionAdvice(String appName, int durationMinutes) {
    final appLower = appName.toLowerCase();
    List<String>? adviceList;
    for (final key in _appSessionAdvice.keys) {
      if (appLower.contains(key)) {
        adviceList = _appSessionAdvice[key];
        break;
      }
    }
    adviceList ??= _appSessionAdvice['default']!;
    int index = 0;
    if (durationMinutes > 120) {
      index = adviceList.length - 1;
    } else if (durationMinutes > 60) {
      index = (adviceList.length / 2).floor();
    }
    index = index.clamp(0, adviceList.length - 1);
    return adviceList[index].replaceAll('{duration}', '$durationMinutes');
  }

  static String getSessionAlertTitle(String appName, int durationMinutes) {
    if (durationMinutes > 120) return '🔴 Extended Session — $appName';
    if (durationMinutes > 60) return '🟠 Long Session — $appName';
    return '⏱️ Session Alert — $appName';
  }

  static Future<List<String>> generateRecommendations({
    required double cognitiveLoadScore,
    required List<AppUsageRecord> usageRecords,
    required double appUsageScore,
    required double sessionScore,
    required double lateNightScore,
    required double multitaskingScore,
    required AppSettings settings,
    String? apiKey,
  }) async {
    if (apiKey == null || apiKey.isEmpty) {
      return _ruleBasedRecommendations(
        cognitiveLoadScore: cognitiveLoadScore,
        appUsageScore: appUsageScore,
        sessionScore: sessionScore,
        lateNightScore: lateNightScore,
        multitaskingScore: multitaskingScore,
        usageRecords: usageRecords,
        settings: settings,
      );
    }
    try {
      return await _aiBasedRecommendations(
        cognitiveLoadScore: cognitiveLoadScore,
        usageRecords: usageRecords,
        appUsageScore: appUsageScore,
        sessionScore: sessionScore,
        lateNightScore: lateNightScore,
        multitaskingScore: multitaskingScore,
        apiKey: apiKey,
      );
    } catch (e) {
      return _ruleBasedRecommendations(
        cognitiveLoadScore: cognitiveLoadScore,
        appUsageScore: appUsageScore,
        sessionScore: sessionScore,
        lateNightScore: lateNightScore,
        multitaskingScore: multitaskingScore,
        usageRecords: usageRecords,
        settings: settings,
      );
    }
  }

  static Future<List<String>> _aiBasedRecommendations({
    required double cognitiveLoadScore,
    required List<AppUsageRecord> usageRecords,
    required double appUsageScore,
    required double sessionScore,
    required double lateNightScore,
    required double multitaskingScore,
    required String apiKey,
  }) async {
    final topApps = usageRecords
        .take(5)
        .map((r) => '${r.appName}: ${r.usageMinutes}min')
        .join(', ');

    final prompt = '''
Analyze this user's cognitive load data and provide 4 specific, actionable recommendations:

Cognitive Load Score: ${cognitiveLoadScore.toStringAsFixed(0)}/100
App Usage Score: ${appUsageScore.toStringAsFixed(0)}/100
Session Length Score: ${sessionScore.toStringAsFixed(0)}/100
Late Night Usage Score: ${lateNightScore.toStringAsFixed(0)}/100
Multitasking Score: ${multitaskingScore.toStringAsFixed(0)}/100
Top Apps Today: $topApps

Rules:
- Be specific to the apps mentioned
- Give actionable, practical advice
- Focus on the worst scoring areas
- Keep each recommendation under 2 sentences
- Return ONLY a JSON array of 4 strings, no other text

Example format: ["rec1", "rec2", "rec3", "rec4"]
''';

    final response = await http.post(
      Uri.parse(_anthropicUrl),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': 'claude-3-haiku-20240307',
        'max_tokens': 512,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final text = data['content'][0]['text'] as String;
      final jsonStart = text.indexOf('[');
      final jsonEnd = text.lastIndexOf(']') + 1;
      if (jsonStart >= 0 && jsonEnd > jsonStart) {
        final List<dynamic> recs =
        jsonDecode(text.substring(jsonStart, jsonEnd));
        return recs.cast<String>();
      }
    }
    throw Exception('AI request failed');
  }

  static List<String> _ruleBasedRecommendations({
    required double cognitiveLoadScore,
    required double appUsageScore,
    required double sessionScore,
    required double lateNightScore,
    required double multitaskingScore,
    required List<AppUsageRecord> usageRecords,
    required AppSettings settings,
  }) {
    final List<String> recs = [];

    if (cognitiveLoadScore > 80) {
      recs.add(
        '🔴 Critical cognitive overload detected. Schedule at least 2 hours completely device-free today to allow mental recovery.',
      );
    }

    if (usageRecords.isNotEmpty) {
      final top = usageRecords.first;
      recs.add(_getAppSpecificRec(top.appName, top.usageMinutes));
    }

    final factors = [
      ('session', sessionScore),
      ('late_night', lateNightScore),
      ('multitasking', multitaskingScore),
      ('app_usage', appUsageScore),
    ]..sort((a, b) => b.$2.compareTo(a.$2));

    for (final factor in factors) {
      if (recs.length >= 5) break;
      switch (factor.$1) {
        case 'session':
          if (factor.$2 > 50) {
            recs.add(
              'Long uninterrupted sessions detected. Use the Pomodoro technique: 25 minutes focused, 5 minutes break. Reduces cognitive fatigue by up to 40%.',
            );
          }
          break;
        case 'late_night':
          if (factor.$2 > 40) {
            recs.add(
              'Late-night screen use suppresses melatonin for up to 3 hours. Set a hard stop at ${_formatHour(settings.lateNightStartHour)} and use Night Mode 1 hour before.',
            );
          }
          break;
        case 'multitasking':
          if (factor.$2 > 50) {
            recs.add(
              'Frequent app switching reduces focus by up to 40% and takes 23 minutes to fully recover. Try single-tasking: finish one thing before opening another app.',
            );
          }
          break;
        case 'app_usage':
          if (factor.$2 > 60) {
            final total = usageRecords.fold(0, (s, r) => s + r.usageMinutes);
            recs.add(
              'Total screen time today: ${total ~/ 60}h ${total % 60}m. Try the 20-20-20 rule every 20 minutes to reduce eye strain and mental fatigue.',
            );
          }
          break;
      }
    }

    if (cognitiveLoadScore < 30 && recs.isEmpty) {
      recs.add('✅ Excellent cognitive balance today! Keep up these healthy digital habits.');
      recs.add('Your screen time patterns are healthy. Maintain consistent break schedules to sustain this.');
    }

    return recs.take(5).toList();
  }

  static String _getAppSpecificRec(String appName, int minutes) {
    final app = appName.toLowerCase();
    if (app.contains('instagram') || app.contains('tiktok') || app.contains('facebook')) {
      return '${minutes}min on $appName today. Social media algorithms maximize your time — set a daily limit of 30 minutes and stick to it.';
    }
    if (app.contains('youtube') || app.contains('netflix')) {
      return '${minutes}min of video streaming today. Passive consumption drains cognitive energy — try active watching by taking notes.';
    }
    if (app.contains('whatsapp') || app.contains('telegram')) {
      return '${minutes}min on $appName. Constant messaging fragments deep focus. Batch your replies to 3 specific times per day.';
    }
    if (app.contains('chrome') || app.contains('browser')) {
      return '${minutes}min of browsing. Close all unused tabs — each open tab consumes working memory. Try using one tab at a time.';
    }
    return '${minutes}min on $appName today. Consider setting a session limit to manage cognitive load from this app.';
  }

  static String _formatHour(int hour) {
    final period = hour < 12 ? 'AM' : 'PM';
    final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$h:00 $period';
  }
}