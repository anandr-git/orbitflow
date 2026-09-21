import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_settings.dart';
import '../models/todo.dart';
import '../services/notification_service.dart';
import '../state/orbit_controller.dart';
import '../storage/todo_repository.dart';
import '../theme/app_theme.dart';
import '../theme/design_tokens.dart';
import '../utils/responsive.dart';
import '../analytics/study_analytics.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
    required this.onClearCompleted,
    required this.todos,
    required this.onImportTodos,
    required this.onExport,
    this.controller,
  });

  final AppSettings settings;
  final ValueChanged<AppSettings> onSettingsChanged;
  final VoidCallback onClearCompleted;
  final List<Todo> todos;
  final Future<void> Function(List<Todo> imported) onImportTodos;
  final Future<String> Function() onExport;
  final OrbitController? controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppSettings _settings;
  final _repository = TodoRepository();
  bool _notifBusy = false;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _settings = widget.settings;
  }

  void _update(AppSettings next) {
    setState(() => _settings = next);
    widget.onSettingsChanged(next);
  }

  Future<void> _export() async {
    final json = await widget.onExport();
    await Clipboard.setData(ClipboardData(text: json));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup JSON copied to clipboard')),
      );
    }
  }

  Future<void> _import() async {
    final controller = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import backup'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: controller,
            maxLines: 8,
            decoration: const InputDecoration(hintText: 'Paste OrbitFlow backup JSON…'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    final text = raw;
    controller.dispose();
    if (text == null || text.trim().isEmpty) return;

    try {
      if (widget.controller != null) {
        await widget.controller!.importBackup(text);
      } else {
        final imported = await _repository.importTodosJson(text);
        await widget.onImportTodos(imported);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup imported')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  Future<void> _enableNotifications() async {
    setState(() => _notifBusy = true);
    final service = NotificationService.instance;
    await service.initialize();
    final granted = await service.requestPermissions();
    _update(
      _settings.copyWith(
        notifications: _settings.notifications.copyWith(
          enabled: granted,
          permissionAsked: true,
        ),
      ),
    );
    if (granted) {
      await service.showTestNotification();
      await service.scheduleVerificationPing(seconds: 20);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission granted. Test notification sent; scheduled ping in ~20s.'),
          ),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification permission denied')),
      );
    }
    setState(() => _notifBusy = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final n = _settings.notifications;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ConstrainedContent(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          children: [
            _section(theme, 'APPEARANCE'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: SegmentedButton<ThemePreference>(
                segments: const [
                  ButtonSegment(value: ThemePreference.system, label: Text('System')),
                  ButtonSegment(value: ThemePreference.light, label: Text('Light')),
                  ButtonSegment(value: ThemePreference.dark, label: Text('Dark')),
                ],
                selected: {_settings.themePreference},
                onSelectionChanged: (s) =>
                    _update(_settings.copyWith(themePreference: s.first)),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
              child: Wrap(
                spacing: 12,
                children: [
                  for (int i = 0; i < AppTheme.themeAccents.length; i++)
                    InkWell(
                      onTap: () => _update(_settings.copyWith(colorIndex: i)),
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.themeAccents[i],
                          shape: BoxShape.circle,
                          border: Border.all(
                            width: 3,
                            color: _settings.colorIndex == i
                                ? theme.colorScheme.onSurface
                                : Colors.transparent,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.animation_rounded),
              title: const Text('Reduce motion'),
              subtitle: const Text('Prefer simpler transitions'),
              value: _settings.reduceMotion,
              onChanged: (v) => _update(_settings.copyWith(reduceMotion: v)),
            ),
            const Divider(height: 32),
            _section(theme, 'GOALS & SESSIONS'),
            ListTile(
              leading: const Icon(Icons.flag_circle_outlined),
              title: const Text('Daily goal'),
              subtitle: Text(
                '${StudyAnalytics.formatMinutes(_settings.dailyStudyGoalMinutes)} — how much focused time you want today',
              ),
            ),
            Slider(
              value: _settings.dailyStudyGoalMinutes.toDouble().clamp(30, 600),
              min: 30,
              max: 600,
              divisions: 19,
              label: StudyAnalytics.formatMinutes(_settings.dailyStudyGoalMinutes),
              onChanged: (v) =>
                  _update(_settings.copyWith(dailyStudyGoalMinutes: (v / 30).round() * 30)),
            ),
            ListTile(
              leading: const Icon(Icons.view_week_outlined),
              title: const Text('Weekly goal'),
              subtitle: Text(
                '${StudyAnalytics.formatMinutes(_settings.weeklyStudyGoalMinutes)} — your target for the week',
              ),
            ),
            Slider(
              value: _settings.weeklyStudyGoalMinutes.toDouble().clamp(300, 3000),
              min: 300,
              max: 3000,
              divisions: 27,
              label: StudyAnalytics.formatMinutes(_settings.weeklyStudyGoalMinutes),
              onChanged: (v) =>
                  _update(_settings.copyWith(weeklyStudyGoalMinutes: (v / 60).round() * 60)),
            ),
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('Default session length'),
              subtitle: const Text('Suggested duration when planning a session'),
              trailing: DropdownButton<int>(
                value: _settings.defaultSessionMinutes,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 25, child: Text('25m')),
                  DropdownMenuItem(value: 45, child: Text('45m')),
                  DropdownMenuItem(value: 60, child: Text('60m')),
                  DropdownMenuItem(value: 90, child: Text('90m')),
                ],
                onChanged: (v) {
                  if (v != null) _update(_settings.copyWith(defaultSessionMinutes: v));
                },
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.calendar_view_week),
              title: const Text('Week starts on Monday'),
              subtitle: const Text('Affects Week planner and Insights'),
              value: _settings.weekStartsOnMonday,
              onChanged: (v) => _update(_settings.copyWith(weekStartsOnMonday: v)),
            ),
            const Divider(height: 32),
            _section(theme, 'NOTIFICATIONS'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'OrbitFlow can remind you before sessions, notify you when one starts, and let you know if a planned session was missed.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.notifications_active_outlined),
              title: const Text('Enable notifications'),
              subtitle: Text(n.permissionAsked
                  ? (n.enabled ? 'Permission granted' : 'Permission denied or disabled')
                  : 'Ask the system for permission when you turn this on'),
              value: n.enabled,
              onChanged: (v) async {
                if (v) {
                  await _enableNotifications();
                } else {
                  _update(_settings.copyWith(
                    notifications: n.copyWith(enabled: false),
                  ));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.notification_add_outlined),
              title: const Text('Send test notification'),
              subtitle: const Text('Confirm reminders work on this device'),
              enabled: !_notifBusy,
              onTap: _enableNotifications,
            ),
            SwitchListTile(
              title: const Text('Session reminders'),
              subtitle: const Text('Before a session begins'),
              value: n.sessionReminders,
              onChanged: (v) => _update(_settings.copyWith(
                notifications: n.copyWith(sessionReminders: v),
              )),
            ),
            SwitchListTile(
              title: const Text('Start-time alerts'),
              subtitle: const Text('When a session starts'),
              value: n.startNotifications,
              onChanged: (v) => _update(_settings.copyWith(
                notifications: n.copyWith(startNotifications: v),
              )),
            ),
            SwitchListTile(
              title: const Text('Missed session alerts'),
              subtitle: const Text('When a planned session ends incomplete'),
              value: n.missedNotifications,
              onChanged: (v) => _update(_settings.copyWith(
                notifications: n.copyWith(missedNotifications: v),
              )),
            ),
            SwitchListTile(
              title: const Text('Evening summary'),
              subtitle: const Text("Review today's planned vs completed work"),
              value: n.eveningSummary,
              onChanged: (v) => _update(_settings.copyWith(
                notifications: n.copyWith(eveningSummary: v),
              )),
            ),
            ListTile(
              title: const Text('Default reminder'),
              subtitle: const Text('How early to notify before a session'),
              trailing: DropdownButton<int>(
                value: n.reminderMinutesBefore,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 10, child: Text('10 min')),
                  DropdownMenuItem(value: 15, child: Text('15 min')),
                  DropdownMenuItem(value: 30, child: Text('30 min')),
                  DropdownMenuItem(value: 60, child: Text('60 min')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    _update(_settings.copyWith(
                      notifications: n.copyWith(reminderMinutesBefore: v),
                    ));
                  }
                },
              ),
            ),
            ListTile(
              title: const Text('Quiet hours'),
              subtitle: Text(
                '${n.quietStartHour.toString().padLeft(2, '0')}:${n.quietStartMinute.toString().padLeft(2, '0')}'
                ' → '
                '${n.quietEndHour.toString().padLeft(2, '0')}:${n.quietEndMinute.toString().padLeft(2, '0')}'
                ' · non-critical reminders are paused',
              ),
            ),
            const Divider(height: 32),
            _section(theme, 'DATA'),
            ListTile(
              leading: const Icon(Icons.cleaning_services_outlined),
              title: const Text('Clear completed tasks'),
              subtitle: const Text('Removes finished tasks from your list'),
              onTap: widget.onClearCompleted,
            ),
            ListTile(
              leading: const Icon(Icons.upload_outlined),
              title: const Text('Export backup'),
              subtitle: const Text('Copy a JSON backup to the clipboard'),
              onTap: _export,
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Import backup'),
              subtitle: const Text('Replace local data from a backup JSON'),
              onTap: _import,
            ),
            if (widget.controller != null)
              ListTile(
                leading: const Icon(Icons.science_outlined),
                title: const Text('Load sample preview data'),
                subtitle: const Text(
                  'Fills OrbitFlow with example sessions for UI review — not real history',
                ),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Load preview data?'),
                      content: const Text(
                        'This replaces subjects and study sessions with sample data so you can explore the UI. It is not real study history.',
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Load preview')),
                      ],
                    ),
                  );
                  if (ok != true) return;
                  await widget.controller!.seedDemoData(force: true);
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Sample preview data loaded')),
                  );
                },
              ),
            const Divider(height: 32),
            _section(theme, 'ABOUT'),
            const ListTile(
              leading: Icon(Icons.public_rounded),
              title: Text(AppTheme.appName),
              subtitle: Text('${AppTheme.appTagline}\nVersion 3.1.0'),
              isThreeLine: true,
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacy'),
              subtitle: Text(
                'Offline-first. ${widget.todos.length} tasks on this device.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(ThemeData theme, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}
