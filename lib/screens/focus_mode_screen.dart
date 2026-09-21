import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../analytics/study_analytics.dart';
import '../models/study_session.dart';
import '../state/orbit_controller.dart';
import '../theme/design_tokens.dart';
import '../utils/responsive.dart';

enum FocusTimerMode { normal, pomodoro }

class FocusModeScreen extends StatefulWidget {
  const FocusModeScreen({
    super.key,
    required this.controller,
    required this.session,
  });

  final OrbitController controller;
  final StudySession session;

  @override
  State<FocusModeScreen> createState() => _FocusModeScreenState();
}

class _FocusModeScreenState extends State<FocusModeScreen> with WidgetsBindingObserver {
  Timer? _ticker;
  FocusTimerMode _mode = FocusTimerMode.normal;
  final int _pomodoroWork = 25;
  final int _pomodoroBreak = 5;
  bool _onBreak = false;
  Duration _pomodoroElapsed = Duration.zero;

  StudySession get _session =>
      widget.controller.sessionById(widget.session.id) ?? widget.session;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_onController);
    _syncTicker();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_onController);
    _ticker?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
      _syncTicker();
    }
  }

  void _onController() {
    if (!mounted) return;
    setState(() {});
    _syncTicker();
  }

  void _syncTicker() {
    final running = _mode == FocusTimerMode.pomodoro
        ? _pomodoroRunning
        : _session.isTimerRunning;
    if (running) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          if (_mode == FocusTimerMode.pomodoro && _pomodoroRunning) {
            _pomodoroElapsed += const Duration(seconds: 1);
            final limit = Duration(minutes: _onBreak ? _pomodoroBreak : _pomodoroWork);
            if (_pomodoroElapsed >= limit) {
              _pomodoroRunning = false;
              _ticker?.cancel();
              _ticker = null;
              HapticFeedback.mediumImpact();
              _onBreak = !_onBreak;
              _pomodoroElapsed = Duration.zero;
            }
          }
        });
      });
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  bool _pomodoroRunning = false;

  Duration get _displayElapsed {
    if (_mode == FocusTimerMode.pomodoro) return _pomodoroElapsed;
    return _session.elapsedFocus();
  }

  Future<void> _start() async {
    HapticFeedback.selectionClick();
    if (_mode == FocusTimerMode.pomodoro) {
      setState(() => _pomodoroRunning = true);
      _syncTicker();
      return;
    }
    final session = _session;
    if (session.isTimerPaused) {
      await widget.controller.resumeFocusTimer(session.id);
    } else if (!session.isTimerRunning) {
      await widget.controller.startFocusTimer(session.id);
    }
  }

  Future<void> _pause() async {
    if (_mode == FocusTimerMode.pomodoro) {
      setState(() => _pomodoroRunning = false);
      _syncTicker();
      return;
    }
    await widget.controller.pauseFocusTimer(_session.id);
  }

  Future<void> _finish() async {
    if (_mode == FocusTimerMode.normal && _session.isTimerRunning) {
      await widget.controller.pauseFocusTimer(_session.id);
    }
    if (_mode == FocusTimerMode.pomodoro) {
      setState(() => _pomodoroRunning = false);
      _syncTicker();
    }
    final minutes = _displayElapsed.inMinutes.clamp(1, 24 * 60);
    final manual = await _confirmMinutes(minutes, showSummary: true);
    if (manual == null || !mounted) return;
    await widget.controller.completeSession(_session.id, actualMinutes: manual, fromTimer: true);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<int?> _confirmMinutes(int suggested, {bool showSummary = false}) async {
    final controller = TextEditingController(text: '$suggested');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(showSummary ? 'Session complete' : 'Save study time'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showSummary) ...[
              Text('Planned: ${StudyAnalytics.formatMinutes(_session.plannedMinutes)}'),
              Text('Actual: ${StudyAnalytics.formatMinutes(suggested)}'),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Actual minutes',
                suffixText: 'min',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text.trim()) ?? suggested),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  String _format(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return h == '00' ? '$m:$s' : '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = _session;
    final subject = widget.controller.subjectById(session.subjectId);
    final topic = widget.controller.topicById(session.subjectId, session.topicId);
    final reduce = widget.controller.settings.reduceMotion;
    final elapsed = _displayElapsed;
    final progress = session.plannedMinutes <= 0
        ? 0.0
        : (elapsed.inSeconds / (session.plannedMinutes * 60)).clamp(0.0, 1.0);

    final isCompleted = session.status == SessionStatus.completed;
    final isMissed = session.status == SessionStatus.missed;
    final isRunning = _mode == FocusTimerMode.pomodoro ? _pomodoroRunning : session.isTimerRunning;
    final isPaused = _mode == FocusTimerMode.normal && session.isTimerPaused;
    final notStarted = session.status == SessionStatus.scheduled ||
        (session.status == SessionStatus.inProgress &&
            session.focusAccumulatedSeconds == 0 &&
            !session.isTimerRunning &&
            _mode == FocusTimerMode.normal);

    String statusLabel;
    if (isCompleted) {
      statusLabel = 'Completed';
    } else if (isMissed) {
      statusLabel = 'Missed';
    } else if (isRunning) {
      statusLabel = _mode == FocusTimerMode.pomodoro
          ? (_onBreak ? 'Break' : 'Focus block')
          : 'In progress';
    } else if (isPaused || (session.status == SessionStatus.inProgress && !notStarted)) {
      statusLabel = 'Paused';
    } else {
      statusLabel = 'Ready to start';
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Focus'),
        backgroundColor: theme.colorScheme.surface,
        actions: [
          if (!isCompleted && !isMissed)
            PopupMenuButton<FocusTimerMode>(
              initialValue: _mode,
              onSelected: (m) => setState(() {
                _mode = m;
                _pomodoroElapsed = Duration.zero;
                _pomodoroRunning = false;
                _onBreak = false;
                _syncTicker();
              }),
              itemBuilder: (_) => const [
                PopupMenuItem(value: FocusTimerMode.normal, child: Text('Normal timer')),
                PopupMenuItem(value: FocusTimerMode.pomodoro, child: Text('Pomodoro 25/5')),
              ],
            ),
        ],
      ),
      body: ConstrainedContent(
        maxWidth: 480,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl),
          child: Column(
            children: [
              Text(subject?.name ?? 'Study', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                topic?.name ?? session.title,
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              if (topic != null) ...[
                const SizedBox(height: 4),
                Text(session.title, style: theme.textTheme.bodyMedium),
              ],
              const SizedBox(height: 8),
              Text(
                statusLabel,
                style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: 220,
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 220,
                      height: 220,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: progress),
                        duration: reduce ? Duration.zero : AppMotion.fast,
                        builder: (context, value, _) => CircularProgressIndicator(
                          value: _mode == FocusTimerMode.normal ? value : null,
                          strokeWidth: 10,
                        ),
                      ),
                    ),
                    Text(
                      isCompleted
                          ? StudyAnalytics.formatMinutes(session.effectiveActualMinutes)
                          : _format(elapsed),
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Planned ${StudyAnalytics.formatMinutes(session.plannedMinutes)}'
                '${elapsed.inSeconds > 0 ? ' · Elapsed ${StudyAnalytics.formatMinutes(elapsed.inMinutes.clamp(0, 24 * 60))}' : ''}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (isCompleted)
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                )
              else if (isMissed)
                Text('This session was missed. Reschedule it from Study home.',
                    textAlign: TextAlign.center, style: theme.textTheme.bodyMedium)
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isRunning ? _pause : _start,
                        icon: Icon(isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded),
                        label: Text(
                          isRunning
                              ? 'Pause'
                              : (notStarted && !isPaused ? 'Start' : 'Resume'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: (isRunning || isPaused || elapsed.inSeconds > 0 || !notStarted)
                            ? _finish
                            : null,
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Finish'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    final minutes = await _confirmMinutes(session.plannedMinutes);
                    if (minutes == null || !mounted) return;
                    await widget.controller.completeSession(session.id, actualMinutes: minutes);
                    if (!mounted) return;
                    navigator.pop();
                  },
                  child: const Text('Complete without timer'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
