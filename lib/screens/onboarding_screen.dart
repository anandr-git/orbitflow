import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/subject.dart';
import '../models/todo.dart';
import '../state/orbit_controller.dart';
import '../theme/app_theme.dart';
import '../theme/design_tokens.dart';
import '../utils/responsive.dart';

/// Short first-run flow. Personalizes defaults; never invents fake history.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.controller});

  final OrbitController controller;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  UsageFocus _focus = UsageFocus.hybrid;
  int _dailyGoalMinutes = 240;
  final _subjectCtrl = TextEditingController();

  @override
  void dispose() {
    _subjectCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish({bool skip = false}) async {
    var settings = widget.controller.settings.copyWith(
      onboardingComplete: true,
      usageFocus: skip ? UsageFocus.hybrid : _focus,
    );
    if (!skip) {
      settings = settings.copyWith(
        dailyStudyGoalMinutes: _dailyGoalMinutes,
        defaultCategory: switch (_focus) {
          UsageFocus.study => TaskCategory.study,
          UsageFocus.work => TaskCategory.work,
          UsageFocus.hybrid => TaskCategory.study,
          UsageFocus.personal => TaskCategory.personal,
        },
      );
      final name = _subjectCtrl.text.trim();
      if (name.isNotEmpty &&
          (_focus == UsageFocus.study || _focus == UsageFocus.hybrid)) {
        await widget.controller.upsertSubject(
          Subject(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            name: name,
            topics: [
              Topic(
                id: '${DateTime.now().microsecondsSinceEpoch}_t',
                name: 'Getting started',
              ),
            ],
          ),
        );
      }
    }
    await widget.controller.updateSettings(settings);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ConstrainedContent(
          maxWidth: AppContentWidth.form,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _finish(skip: true),
                    child: const Text('Skip'),
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: widget.controller.settings.reduceMotion
                        ? Duration.zero
                        : AppMotion.normal,
                    child: _step == 0
                        ? _WelcomeStep(key: const ValueKey(0), theme: theme)
                        : _step == 1
                            ? _FocusStep(
                                key: const ValueKey(1),
                                theme: theme,
                                selected: _focus,
                                onSelect: (f) => setState(() => _focus = f),
                              )
                            : _SetupStep(
                                key: const ValueKey(2),
                                theme: theme,
                                focus: _focus,
                                subjectCtrl: _subjectCtrl,
                                dailyGoalMinutes: _dailyGoalMinutes,
                                onGoal: (m) => setState(() => _dailyGoalMinutes = m),
                              ),
                  ),
                ),
                Row(
                  children: [
                    if (_step > 0)
                      TextButton(
                        onPressed: () => setState(() => _step--),
                        child: const Text('Back'),
                      ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () async {
                        if (_step < 2) {
                          setState(() => _step++);
                        } else {
                          await _finish();
                        }
                      },
                      child: Text(_step < 2 ? 'Continue' : 'Start using OrbitFlow'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({super.key, required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.public_rounded, size: 56, color: theme.colorScheme.primary),
        const SizedBox(height: AppSpacing.md),
        Text('Welcome to ${AppTheme.appName}', style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Plan your work. Focus when it matters. See your progress.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Use OrbitFlow for study, projects, deadlines, or everyday tasks — in one place.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _FocusStep extends StatelessWidget {
  const _FocusStep({
    super.key,
    required this.theme,
    required this.selected,
    required this.onSelect,
  });

  final ThemeData theme;
  final UsageFocus selected;
  final ValueChanged<UsageFocus> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Text('How will you use OrbitFlow?', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'This only sets helpful defaults. You can change anything later.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final f in UsageFocus.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: selected == f
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerLowest,
              borderRadius: AppRadius.mdAll,
              child: InkWell(
                borderRadius: AppRadius.mdAll,
                onTap: () => onSelect(f),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Icon(
                        selected == f ? Icons.check_circle : Icons.circle_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(f.label, style: theme.textTheme.titleMedium),
                            Text(f.description, style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SetupStep extends StatelessWidget {
  const _SetupStep({
    super.key,
    required this.theme,
    required this.focus,
    required this.subjectCtrl,
    required this.dailyGoalMinutes,
    required this.onGoal,
  });

  final ThemeData theme;
  final UsageFocus focus;
  final TextEditingController subjectCtrl;
  final int dailyGoalMinutes;
  final ValueChanged<int> onGoal;

  @override
  Widget build(BuildContext context) {
    final showSubject = focus == UsageFocus.study || focus == UsageFocus.hybrid;
    return ListView(
      children: [
        Text("Let's get you started", style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Optional — you can skip any field and set this up later.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (showSubject) ...[
          Text(
            focus == UsageFocus.study ? 'Add your first subject' : 'Optional first subject',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: subjectCtrl,
            decoration: const InputDecoration(
              hintText: 'e.g. Operating Systems or Certification prep',
              labelText: 'Subject or learning area',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Text('Daily focus goal', style: theme.textTheme.titleSmall),
        Text(
          'How much focused time you want today.',
          style: theme.textTheme.bodySmall,
        ),
        Slider(
          value: dailyGoalMinutes.toDouble().clamp(30, 480),
          min: 30,
          max: 480,
          divisions: 15,
          label: '${dailyGoalMinutes ~/ 60}h ${dailyGoalMinutes % 60}m',
          onChanged: (v) => onGoal((v / 30).round() * 30),
        ),
        Text(
          '${dailyGoalMinutes ~/ 60}h ${dailyGoalMinutes % 60}m per day',
          style: theme.textTheme.labelLarge,
        ),
      ],
    );
  }
}
