import 'todo.dart';

enum ThemePreference { system, light, dark }

enum DefaultView { today, all, upcoming, overdue }

/// How the user primarily intends to use OrbitFlow — personalizes defaults only.
enum UsageFocus { study, work, hybrid, personal }

extension UsageFocusX on UsageFocus {
  String get label => switch (this) {
        UsageFocus.study => 'Study',
        UsageFocus.work => 'Work',
        UsageFocus.hybrid => 'Study + Work',
        UsageFocus.personal => 'Personal',
      };

  String get description => switch (this) {
        UsageFocus.study => 'Subjects, topics, and study sessions',
        UsageFocus.work => 'Tasks, deadlines, and focus blocks',
        UsageFocus.hybrid => 'Study planning plus general tasks',
        UsageFocus.personal => 'Everyday tasks and personal goals',
      };
}

class NotificationSettings {
  const NotificationSettings({
    this.enabled = true,
    this.sessionReminders = true,
    this.startNotifications = true,
    this.missedNotifications = true,
    this.eveningSummary = true,
    this.streakReminders = false,
    this.reminderMinutesBefore = 30,
    this.quietStartHour = 22,
    this.quietStartMinute = 30,
    this.quietEndHour = 7,
    this.quietEndMinute = 0,
    this.eveningHour = 20,
    this.eveningMinute = 0,
    this.permissionAsked = false,
  });

  final bool enabled;
  final bool sessionReminders;
  final bool startNotifications;
  final bool missedNotifications;
  final bool eveningSummary;
  final bool streakReminders;
  final int reminderMinutesBefore;
  final int quietStartHour;
  final int quietStartMinute;
  final int quietEndHour;
  final int quietEndMinute;
  final int eveningHour;
  final int eveningMinute;
  final bool permissionAsked;

  NotificationSettings copyWith({
    bool? enabled,
    bool? sessionReminders,
    bool? startNotifications,
    bool? missedNotifications,
    bool? eveningSummary,
    bool? streakReminders,
    int? reminderMinutesBefore,
    int? quietStartHour,
    int? quietStartMinute,
    int? quietEndHour,
    int? quietEndMinute,
    int? eveningHour,
    int? eveningMinute,
    bool? permissionAsked,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      sessionReminders: sessionReminders ?? this.sessionReminders,
      startNotifications: startNotifications ?? this.startNotifications,
      missedNotifications: missedNotifications ?? this.missedNotifications,
      eveningSummary: eveningSummary ?? this.eveningSummary,
      streakReminders: streakReminders ?? this.streakReminders,
      reminderMinutesBefore: reminderMinutesBefore ?? this.reminderMinutesBefore,
      quietStartHour: quietStartHour ?? this.quietStartHour,
      quietStartMinute: quietStartMinute ?? this.quietStartMinute,
      quietEndHour: quietEndHour ?? this.quietEndHour,
      quietEndMinute: quietEndMinute ?? this.quietEndMinute,
      eveningHour: eveningHour ?? this.eveningHour,
      eveningMinute: eveningMinute ?? this.eveningMinute,
      permissionAsked: permissionAsked ?? this.permissionAsked,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'sessionReminders': sessionReminders,
        'startNotifications': startNotifications,
        'missedNotifications': missedNotifications,
        'eveningSummary': eveningSummary,
        'streakReminders': streakReminders,
        'reminderMinutesBefore': reminderMinutesBefore,
        'quietStartHour': quietStartHour,
        'quietStartMinute': quietStartMinute,
        'quietEndHour': quietEndHour,
        'quietEndMinute': quietEndMinute,
        'eveningHour': eveningHour,
        'eveningMinute': eveningMinute,
        'permissionAsked': permissionAsked,
      };

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      enabled: json['enabled'] as bool? ?? true,
      sessionReminders: json['sessionReminders'] as bool? ?? true,
      startNotifications: json['startNotifications'] as bool? ?? true,
      missedNotifications: json['missedNotifications'] as bool? ?? true,
      eveningSummary: json['eveningSummary'] as bool? ?? true,
      streakReminders: json['streakReminders'] as bool? ?? false,
      reminderMinutesBefore: json['reminderMinutesBefore'] as int? ?? 30,
      quietStartHour: json['quietStartHour'] as int? ?? 22,
      quietStartMinute: json['quietStartMinute'] as int? ?? 30,
      quietEndHour: json['quietEndHour'] as int? ?? 7,
      quietEndMinute: json['quietEndMinute'] as int? ?? 0,
      eveningHour: json['eveningHour'] as int? ?? 20,
      eveningMinute: json['eveningMinute'] as int? ?? 0,
      permissionAsked: json['permissionAsked'] as bool? ?? false,
    );
  }

  /// Returns true if [time] falls inside quiet hours (inclusive start, exclusive end).
  bool isQuietAt(DateTime time) {
    final minutes = time.hour * 60 + time.minute;
    final start = quietStartHour * 60 + quietStartMinute;
    final end = quietEndHour * 60 + quietEndMinute;
    if (start == end) return false;
    if (start < end) {
      return minutes >= start && minutes < end;
    }
    // Wraps midnight, e.g. 22:30 → 07:00
    return minutes >= start || minutes < end;
  }
}

class AppSettings {
  const AppSettings({
    this.themePreference = ThemePreference.system,
    this.colorIndex = 0,
    this.defaultPriority = TaskPriority.medium,
    this.defaultCategory = TaskCategory.personal,
    this.defaultView = DefaultView.today,
    this.dailyGoal = 3,
    this.dailyStudyGoalMinutes = 240,
    this.weeklyStudyGoalMinutes = 1500,
    this.monthlyStudyGoalMinutes = 6000,
    this.defaultSessionMinutes = 60,
    this.weekStartsOnMonday = true,
    this.completionStreak = 0,
    this.studyStreak = 0,
    this.lastCompletionDay,
    this.lastStudyDay,
    this.reduceMotion = false,
    this.showCompletedInToday = false,
    this.onboardingComplete = false,
    this.usageFocus = UsageFocus.hybrid,
    this.notifications = const NotificationSettings(),
  });

  final ThemePreference themePreference;
  final int colorIndex;
  final TaskPriority defaultPriority;
  final TaskCategory defaultCategory;
  final DefaultView defaultView;
  final int dailyGoal;
  final int dailyStudyGoalMinutes;
  final int weeklyStudyGoalMinutes;
  final int monthlyStudyGoalMinutes;
  final int defaultSessionMinutes;
  final bool weekStartsOnMonday;
  final int completionStreak;
  final int studyStreak;
  final String? lastCompletionDay;
  final String? lastStudyDay;
  final bool reduceMotion;
  final bool showCompletedInToday;
  final bool onboardingComplete;
  final UsageFocus usageFocus;
  final NotificationSettings notifications;

  AppSettings copyWith({
    ThemePreference? themePreference,
    int? colorIndex,
    TaskPriority? defaultPriority,
    TaskCategory? defaultCategory,
    DefaultView? defaultView,
    int? dailyGoal,
    int? dailyStudyGoalMinutes,
    int? weeklyStudyGoalMinutes,
    int? monthlyStudyGoalMinutes,
    int? defaultSessionMinutes,
    bool? weekStartsOnMonday,
    int? completionStreak,
    int? studyStreak,
    String? lastCompletionDay,
    String? lastStudyDay,
    bool? reduceMotion,
    bool? showCompletedInToday,
    bool? onboardingComplete,
    UsageFocus? usageFocus,
    NotificationSettings? notifications,
    bool clearLastCompletionDay = false,
    bool clearLastStudyDay = false,
  }) {
    return AppSettings(
      themePreference: themePreference ?? this.themePreference,
      colorIndex: colorIndex ?? this.colorIndex,
      defaultPriority: defaultPriority ?? this.defaultPriority,
      defaultCategory: defaultCategory ?? this.defaultCategory,
      defaultView: defaultView ?? this.defaultView,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      dailyStudyGoalMinutes: dailyStudyGoalMinutes ?? this.dailyStudyGoalMinutes,
      weeklyStudyGoalMinutes: weeklyStudyGoalMinutes ?? this.weeklyStudyGoalMinutes,
      monthlyStudyGoalMinutes: monthlyStudyGoalMinutes ?? this.monthlyStudyGoalMinutes,
      defaultSessionMinutes: defaultSessionMinutes ?? this.defaultSessionMinutes,
      weekStartsOnMonday: weekStartsOnMonday ?? this.weekStartsOnMonday,
      completionStreak: completionStreak ?? this.completionStreak,
      studyStreak: studyStreak ?? this.studyStreak,
      lastCompletionDay:
          clearLastCompletionDay ? null : (lastCompletionDay ?? this.lastCompletionDay),
      lastStudyDay: clearLastStudyDay ? null : (lastStudyDay ?? this.lastStudyDay),
      reduceMotion: reduceMotion ?? this.reduceMotion,
      showCompletedInToday: showCompletedInToday ?? this.showCompletedInToday,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      usageFocus: usageFocus ?? this.usageFocus,
      notifications: notifications ?? this.notifications,
    );
  }

  Map<String, dynamic> toJson() => {
        'themePreference': themePreference.name,
        'colorIndex': colorIndex,
        'defaultPriority': defaultPriority.name,
        'defaultCategory': defaultCategory.name,
        'defaultView': defaultView.name,
        'dailyGoal': dailyGoal,
        'dailyStudyGoalMinutes': dailyStudyGoalMinutes,
        'weeklyStudyGoalMinutes': weeklyStudyGoalMinutes,
        'monthlyStudyGoalMinutes': monthlyStudyGoalMinutes,
        'defaultSessionMinutes': defaultSessionMinutes,
        'weekStartsOnMonday': weekStartsOnMonday,
        'completionStreak': completionStreak,
        'studyStreak': studyStreak,
        'lastCompletionDay': lastCompletionDay,
        'lastStudyDay': lastStudyDay,
        'reduceMotion': reduceMotion,
        'showCompletedInToday': showCompletedInToday,
        'onboardingComplete': onboardingComplete,
        'usageFocus': usageFocus.name,
        'notifications': notifications.toJson(),
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      themePreference: ThemePreference.values.firstWhere(
        (e) => e.name == json['themePreference'],
        orElse: () => ThemePreference.system,
      ),
      colorIndex: (json['colorIndex'] as int?) ?? 0,
      defaultPriority: TaskPriority.values.firstWhere(
        (e) => e.name == json['defaultPriority'],
        orElse: () => TaskPriority.medium,
      ),
      defaultCategory: TaskCategory.values.firstWhere(
        (e) => e.name == json['defaultCategory'],
        orElse: () => TaskCategory.personal,
      ),
      defaultView: DefaultView.values.firstWhere(
        (e) => e.name == json['defaultView'],
        orElse: () => DefaultView.today,
      ),
      dailyGoal: (json['dailyGoal'] as int?) ?? 3,
      dailyStudyGoalMinutes: (json['dailyStudyGoalMinutes'] as int?) ?? 240,
      weeklyStudyGoalMinutes: (json['weeklyStudyGoalMinutes'] as int?) ?? 1500,
      monthlyStudyGoalMinutes: (json['monthlyStudyGoalMinutes'] as int?) ?? 6000,
      defaultSessionMinutes: (json['defaultSessionMinutes'] as int?) ?? 60,
      weekStartsOnMonday: json['weekStartsOnMonday'] as bool? ?? true,
      completionStreak: (json['completionStreak'] as int?) ?? 0,
      studyStreak: (json['studyStreak'] as int?) ?? 0,
      lastCompletionDay: json['lastCompletionDay'] as String?,
      lastStudyDay: json['lastStudyDay'] as String?,
      reduceMotion: json['reduceMotion'] as bool? ?? false,
      showCompletedInToday: json['showCompletedInToday'] as bool? ?? false,
      onboardingComplete: json['onboardingComplete'] as bool? ?? false,
      usageFocus: UsageFocus.values.firstWhere(
        (e) => e.name == json['usageFocus'],
        orElse: () => UsageFocus.hybrid,
      ),
      notifications: json['notifications'] is Map<String, dynamic>
          ? NotificationSettings.fromJson(json['notifications'] as Map<String, dynamic>)
          : const NotificationSettings(),
    );
  }
}
