import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../analytics/study_analytics.dart';
import '../models/study_session.dart';
import '../state/orbit_controller.dart';
import '../theme/design_tokens.dart';
import 'focus_mode_screen.dart';
import 'session_editor_screen.dart';

class TopicDetailScreen extends StatelessWidget {
  const TopicDetailScreen({
    super.key,
    required this.controller,
    required this.subjectId,
    required this.topicId,
  });

  final OrbitController controller;
  final String subjectId;
  final String topicId;

  @override
  Widget build(BuildContext context) {
    final subject = controller.subjectById(subjectId);
    final topic = controller.topicById(subjectId, topicId);
    if (subject == null || topic == null) {
      return const Scaffold(body: Center(child: Text('Topic not found')));
    }
    final related = controller.sessions
        .where((s) => s.subjectId == subjectId && s.topicId == topicId && !s.archived)
        .toList()
      ..sort((a, b) => b.plannedStart.compareTo(a.plannedStart));
    final done = related.where((s) => s.status == SessionStatus.completed).toList();
    final missed = related.where((s) => s.status == SessionStatus.missed).length;
    final studied = done.fold<int>(0, (a, b) => a + b.effectiveActualMinutes);
    final progress = controller.topicProgress(subjectId, topicId);
    final last = done.isEmpty ? null : (done.first.completedAt ?? done.first.plannedStart);
    final upcoming = related.where((s) => s.status.isOpen).toList();

    return Scaffold(
      appBar: AppBar(title: Text(topic.name)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(subject.name, style: Theme.of(context).textTheme.labelLarge),
          Text(topic.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text('${(progress * 100).round()}% of planned topic time'),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: progress, minHeight: 8),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text('Study time ${StudyAnalytics.formatMinutes(studied)}')),
              Chip(label: Text(StudyAnalytics.countLabel(related.length, 'session'))),
              Chip(label: Text('${done.length} completed')),
              Chip(label: Text(StudyAnalytics.countLabel(missed, 'missed session'))),
            ],
          ),
          const SizedBox(height: 12),
          if (last != null)
            Text('Last studied ${DateFormat('EEE, MMM d').format(last)}'),
          if (upcoming.isNotEmpty)
            Text(
              'Upcoming ${DateFormat('EEE h:mm a').format(upcoming.first.plannedStart)}',
            ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              if (upcoming.isNotEmpty)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FocusModeScreen(
                          controller: controller,
                          session: upcoming.first,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start session'),
                  ),
                ),
              if (upcoming.isNotEmpty) const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final created = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SessionEditorScreen(
                          controller: controller,
                          initialSubjectId: subjectId,
                          initialTopicId: topicId,
                        ),
                      ),
                    );
                    if (created != null) await controller.upsertSession(created);
                  },
                  icon: const Icon(Icons.edit_calendar_outlined),
                  label: const Text('Plan session'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('History', style: Theme.of(context).textTheme.titleMedium),
          if (related.isEmpty)
            Text(
              'Complete a study session to start building your history.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            )
          else
            for (final s in related)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s.title),
                subtitle: Text(
                  '${DateFormat('MMM d · h:mm a').format(s.plannedStart)} · ${s.status.label}'
                  '${s.actualMinutes == null ? '' : ' · actual ${s.actualMinutes}m'}',
                ),
              ),
        ],
      ),
    );
  }
}
