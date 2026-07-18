# 🧠 Cogniload — Cognitive Load Monitor

A fully functional Flutter app for monitoring cognitive load through intelligent app usage tracking, session analysis, and AI-powered recommendations.

---

## Features

### Dashboard
- Real-time Cognitive Load Score (0–100) with color-coded status
- Load breakdown by: App Usage, Session Length, Late Night, Multitasking
- 7-day trend line chart
- AI-generated personalized recommendations

### App Usage
- Today and 7-day usage views
- Per-app time tracking with icons, names, usage bars
- Category pie chart (Social Media, Entertainment, etc.)
- Total screen time summary

### Sessions
- Active session tracking with live timers
- Session threshold alerts
- Completed sessions log with duration progress bars
- AI advice for long sessions

### Settings
- Pause/Resume background tracking toggle
- Configurable late-night hours (default: 12 AM – 6 AM)
- Session alert threshold (default: 45 min)
- Daily usage limit (default: 3 hours)
- Include/exclude system apps
- Anthropic API key for AI recommendations
- Clear all data

---

## Setup Instructions

### Prerequisites
- Flutter 3.x SDK
- Android Studio / VS Code
- Android device/emulator with API 26+ (Android 8+)

### 1. Clone / Open Project
```bash
cd cogniload
flutter pub get
```

### 2. Configure Android
Make sure `local.properties` contains your Flutter SDK path:
```
flutter.sdk=/path/to/flutter
sdk.dir=/path/to/android/sdk
```

### 3. Run the App
```bash
flutter run
```

### 4. Grant Permissions (Critical!)
On first launch, the app will prompt for:

**a) Usage Access Permission** (required for app tracking)
- Settings → Apps → Special App Access → Usage Access → Cogniload → Enable

**b) Battery Optimization Exemption** (required for background service)
- Settings → Battery → Battery Optimization → Cogniload → Don't Optimize

**c) Notification Permission** (Android 13+)
- Grant when prompted

---

## Architecture

```
lib/
├── main.dart                    # App entry point + navigation
├── theme/
│   └── app_theme.dart           # Color palette, dark theme
├── models/
│   ├── app_usage_model.dart     # Hive data models
│   └── settings_model.dart      # App settings
├── services/
│   ├── storage_service.dart     # Hive + SharedPreferences
│   ├── background_service.dart  # flutter_foreground_task
│   ├── app_usage_service.dart   # AppUsage + DeviceApps
│   ├── cognitive_load_service.dart # Score calculation logic
│   ├── ai_service.dart          # Anthropic API + rule-based AI
│   └── notification_service.dart # Local notifications
├── providers/
│   └── app_providers.dart       # Riverpod providers
├── screens/
│   ├── dashboard/               # Main score + recommendations
│   ├── app_usage/               # Usage list + charts
│   ├── sessions/                # Session tracker
│   └── settings/                # Configuration
├── widgets/
│   └── shared_widgets.dart      # Reusable UI components
└── utils/
    └── permission_helper.dart   # Permission dialogs
```

---

## Cognitive Load Score Algorithm

| Factor | Weight | Description |
|--------|--------|-------------|
| App Usage | 35% | Total screen time vs daily limit |
| Session Length | 30% | Longest continuous session vs threshold |
| Late Night | 20% | Usage during configured night hours |
| Multitasking | 15% | App switch frequency per hour |

**Score Ranges:**
- 0–29: 🟢 Optimal
- 30–59: 🟡 Moderate  
- 60–79: 🟠 High Load
- 80–100: 🔴 Critical

---

## AI Recommendations

**Without API key:** Intelligent rule-based recommendations analyze the highest-scoring factors and provide specific, actionable advice.

**With Anthropic API key:** Claude 3 Haiku generates personalized recommendations based on actual usage patterns.

Add your key in Settings → AI Recommendations → Anthropic API Key

---

## Packages Used

| Package | Purpose |
|---------|---------|
| `flutter_foreground_task` | Background service (survives app kill) |
| `app_usage` | Android UsageStats API |
| `device_apps` | App icons + metadata |
| `fl_chart` | Line & pie charts |
| `hive_flutter` | Local data persistence |
| `flutter_riverpod` | State management |
| `flutter_local_notifications` | Foreground + background alerts |
| `flutter_animate` | Smooth animations |
| `http` | Anthropic API calls |
| `shared_preferences` | Settings storage |
| `permission_handler` | Runtime permissions |

---

## Background Service

Uses `flutter_foreground_task` which:
- Shows a persistent notification (required by Android)
- Survives app being removed from recents
- Auto-restarts after device reboot
- Polls every 30 seconds for usage data
- Checks late-night window and session thresholds

---

## Customization

### Change Polling Interval
In `background_service.dart`:
```dart
ForegroundTaskEventAction.repeat(30000) // 30 seconds
```

### Add New Cognitive Factors
In `cognitive_load_service.dart`, add a new `_calculate*Score()` method and include it in the weighted average.

### Customize Colors
All theme values are in `theme/app_theme.dart`.

---

## Contributors

Atharva Ghule        
Aditya Gawali
