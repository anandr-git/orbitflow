import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/study_session.dart';
import '../models/subject.dart';
import '../models/todo.dart';
import '../theme/app_theme.dart';

class TodoRepository {
  static const schemaVersion = 3;
  static const _todosKey = 'todos_v2';
  static const _darkModeKey = 'dark_mode';
  static const _themeColorKey = 'theme_color_index';
  static const _settingsKey = 'app_settings_v1';
  static const _subjectsKey = 'subjects_v1';
  static const _sessionsKey = 'study_sessions_v1';
  static const _schemaKey = 'orbit_schema_version';

  Future<void> ensureMigrated() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_schemaKey) ?? 1;
    if (current < schemaVersion) {
      await prefs.setInt(_schemaKey, schemaVersion);
    }
  }

  Future<List<Todo>> loadTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_todosKey) ?? [];
    return stored.map((s) => Todo.fromJson(jsonDecode(s) as Map<String, dynamic>)).toList();
  }

  Future<void> saveTodos(List<Todo> todos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_todosKey, todos.map((t) => jsonEncode(t.toJson())).toList());
  }

  Future<List<Subject>> loadSubjects() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_subjectsKey) ?? [];
    return stored.map((s) => Subject.fromJson(jsonDecode(s) as Map<String, dynamic>)).toList();
  }

  Future<void> saveSubjects(List<Subject> subjects) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _subjectsKey,
      subjects.map((s) => jsonEncode(s.toJson())).toList(),
    );
  }

  Future<List<StudySession>> loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_sessionsKey) ?? [];
    return stored
        .map((s) => StudySession.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveSessions(List<StudySession> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _sessionsKey,
      sessions.map((s) => jsonEncode(s.toJson())).toList(),
    );
  }

  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsKey);
    if (raw != null) {
      try {
        return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }

    final legacyDark = prefs.getBool(_darkModeKey);
    final color = prefs.getInt(_themeColorKey) ?? 0;
    return AppSettings(
      themePreference: legacyDark == null
          ? ThemePreference.system
          : (legacyDark ? ThemePreference.dark : ThemePreference.light),
      colorIndex: color.clamp(0, AppTheme.themeAccents.length - 1),
    );
  }

  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
    await prefs.setBool(_darkModeKey, settings.themePreference == ThemePreference.dark);
    await prefs.setInt(_themeColorKey, settings.colorIndex);
  }

  Future<String> exportAll({
    required List<Todo> todos,
    required List<Subject> subjects,
    required List<StudySession> sessions,
    required AppSettings settings,
  }) async {
    final payload = {
      'app': AppTheme.appName,
      'schemaVersion': schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'todos': todos.map((t) => t.toJson()).toList(),
      'subjects': subjects.map((s) => s.toJson()).toList(),
      'sessions': sessions.map((s) => s.toJson()).toList(),
      'settings': settings.toJson(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<Map<String, dynamic>> importAll(String raw) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Backup is empty');
    }
    if (trimmed.length > 8 * 1024 * 1024) {
      throw const FormatException('Backup is too large (max 8 MB)');
    }

    late final dynamic decoded;
    try {
      decoded = jsonDecode(trimmed);
    } on FormatException {
      throw const FormatException('Backup is not valid JSON');
    }

    // Legacy: root-level todos array.
    if (decoded is List) {
      final todos = <Todo>[];
      for (final e in decoded) {
        if (e is! Map) continue;
        try {
          todos.add(Todo.fromJson(Map<String, dynamic>.from(e)));
        } catch (_) {}
      }
      return {'todos': todos, 'subjects': <Subject>[], 'sessions': <StudySession>[], 'settings': null};
    }

    if (decoded is! Map) {
      throw const FormatException('Unrecognized backup format');
    }
    final map = Map<String, dynamic>.from(decoded);

    final schema = map['schemaVersion'];
    if (schema != null && schema is! int && schema is! num) {
      throw const FormatException('Invalid schemaVersion');
    }
    final schemaInt = schema == null ? schemaVersion : (schema as num).toInt();
    if (schemaInt > schemaVersion + 2) {
      throw FormatException(
        'Backup schema v$schemaInt is newer than this app (v$schemaVersion). Update OrbitFlow and try again.',
      );
    }

    List<Todo> todos = [];
    if (map['todos'] is List) {
      for (final e in map['todos'] as List) {
        if (e is! Map) continue;
        try {
          todos.add(Todo.fromJson(Map<String, dynamic>.from(e)));
        } catch (_) {}
      }
    }

    List<Subject> subjects = [];
    if (map['subjects'] is List) {
      for (final e in map['subjects'] as List) {
        if (e is! Map) continue;
        try {
          subjects.add(Subject.fromJson(Map<String, dynamic>.from(e)));
        } catch (_) {}
      }
    }

    List<StudySession> sessions = [];
    if (map['sessions'] is List) {
      for (final e in map['sessions'] as List) {
        if (e is! Map) continue;
        final row = Map<String, dynamic>.from(e);
        if (row['id'] is! String || (row['id'] as String).trim().isEmpty) continue;
        if (row['plannedStart'] is! String) continue;
        try {
          sessions.add(StudySession.fromJson(row));
        } catch (_) {}
      }
    }

    AppSettings? settings;
    if (map['settings'] is Map) {
      try {
        settings = AppSettings.fromJson(Map<String, dynamic>.from(map['settings'] as Map));
        // Imported data should land in the main app, not re-trigger onboarding.
        settings = settings.copyWith(onboardingComplete: true);
      } catch (_) {
        settings = null;
      }
    }

    if (todos.isEmpty && subjects.isEmpty && sessions.isEmpty && settings == null) {
      throw const FormatException('Backup contained no recognizable OrbitFlow data');
    }

    return {
      'todos': todos,
      'subjects': subjects,
      'sessions': sessions,
      'settings': settings,
    };
  }

  Future<List<Todo>> importTodosJson(String raw) async {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic> && decoded['todos'] is List) {
      return (decoded['todos'] as List)
          .map((e) => Todo.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (decoded is List) {
      return decoded.map((e) => Todo.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw const FormatException('Unrecognized backup format');
  }

  Future<String> exportTodosJson(List<Todo> todos) async {
    return exportAll(
      todos: todos,
      subjects: const [],
      sessions: const [],
      settings: const AppSettings(),
    );
  }

  @Deprecated('Use loadSettings')
  Future<bool> loadDarkMode() async {
    final settings = await loadSettings();
    return settings.themePreference == ThemePreference.dark;
  }

  @Deprecated('Use saveSettings')
  Future<void> saveDarkMode(bool value) async {
    final settings = await loadSettings();
    await saveSettings(
      settings.copyWith(
        themePreference: value ? ThemePreference.dark : ThemePreference.light,
      ),
    );
  }

  @Deprecated('Use loadSettings')
  Future<int> loadThemeColorIndex() async {
    final settings = await loadSettings();
    return settings.colorIndex;
  }

  @Deprecated('Use saveSettings')
  Future<void> saveThemeColorIndex(int index) async {
    final settings = await loadSettings();
    await saveSettings(settings.copyWith(colorIndex: index));
  }
}
