class AppSettings {
  final bool trackingEnabled;
  final int lateNightStartHour; // 0-23
  final int lateNightEndHour; // 0-23
  final int sessionAlertMinutes; // minutes before alerting long session
  final int dailyLimitMinutes; // total daily usage limit
  final bool includeSystemApps;
  final bool aiSuggestionsEnabled;
  final String? openAiApiKey;
  final List<String> ignoredPackages;

  const AppSettings({
    this.trackingEnabled = true,   // always on
    this.lateNightStartHour = 0,   // 12 AM
    this.lateNightEndHour = 6,     // 6 AM
    this.sessionAlertMinutes = 45,
    this.dailyLimitMinutes = 180,  // 3 hours
    this.includeSystemApps = true, // always on
    this.aiSuggestionsEnabled = true, // always on
    this.openAiApiKey,
    this.ignoredPackages = const [],
  });

  AppSettings copyWith({
    bool? trackingEnabled,
    int? lateNightStartHour,
    int? lateNightEndHour,
    int? sessionAlertMinutes,
    int? dailyLimitMinutes,
    bool? includeSystemApps,
    bool? aiSuggestionsEnabled,
    String? openAiApiKey,
    List<String>? ignoredPackages,
  }) {
    return AppSettings(
      trackingEnabled: true,       // always on — not user-configurable
      lateNightStartHour: lateNightStartHour ?? this.lateNightStartHour,
      lateNightEndHour: lateNightEndHour ?? this.lateNightEndHour,
      sessionAlertMinutes: sessionAlertMinutes ?? this.sessionAlertMinutes,
      dailyLimitMinutes: dailyLimitMinutes ?? this.dailyLimitMinutes,
      includeSystemApps: true,     // always on — not user-configurable
      aiSuggestionsEnabled: true,  // always on — not user-configurable
      openAiApiKey: openAiApiKey ?? this.openAiApiKey,
      ignoredPackages: ignoredPackages ?? this.ignoredPackages,
    );
  }

  Map<String, dynamic> toMap() => {
        'trackingEnabled': trackingEnabled,
        'lateNightStartHour': lateNightStartHour,
        'lateNightEndHour': lateNightEndHour,
        'sessionAlertMinutes': sessionAlertMinutes,
        'dailyLimitMinutes': dailyLimitMinutes,
        'includeSystemApps': includeSystemApps,
        'aiSuggestionsEnabled': aiSuggestionsEnabled,
        'openAiApiKey': openAiApiKey,
        'ignoredPackages': ignoredPackages,
      };

  factory AppSettings.fromMap(Map<String, dynamic> map) => AppSettings(
        trackingEnabled: true,       // always on — ignore stored value
        lateNightStartHour: map['lateNightStartHour'] ?? 0,
        lateNightEndHour: map['lateNightEndHour'] ?? 6,
        sessionAlertMinutes: map['sessionAlertMinutes'] ?? 45,
        dailyLimitMinutes: map['dailyLimitMinutes'] ?? 180,
        includeSystemApps: true,     // always on — ignore stored value
        aiSuggestionsEnabled: true,  // always on — ignore stored value
        openAiApiKey: map['openAiApiKey'],
        ignoredPackages: List<String>.from(map['ignoredPackages'] ?? []),
      );
}
