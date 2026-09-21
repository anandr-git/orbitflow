import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../analytics/study_analytics.dart';
import '../models/study_session.dart';
import '../state/orbit_controller.dart';
import '../theme/design_tokens.dart';
import 'session_editor_screen.dart';
import 'topic_detail_screen.dart';

class SubjectDetailScreen extends StatelessWidget {
  const SubjectDetailScreen({
    super.key,
    required this.controller,
    required this.subjectId,
  });

  final OrbitController controller;
  final String subjectId;

  @override
  Widget build(BuildContext context) {
    final subject = controller.subjectById(subjectId);
    if (subject == null) {
      return const Scaffold(body: Center(child: Text('Subject not found')));
    }
    final theme = Theme.of(context);
    final related = controller.sessions.where((s) => s.subjectId == subjectId && !s.archived).toList();
    final planned = related.where((s) => s.status.countsAsPlanned).fold<int>(0, (a, b) => a + b.plannedMinutes);
    final done = related
        .where((s) => s.status == SessionStatus.completed)
        .fold<int>(0, (a, b) => a + b.effectiveActualMinutes);
    final missed = related.where((s) => s.status == SessionStatus.missed).length;
    final upcoming = related.where((s) => s.status.isOpen).length;
    final rate = controller.subjectProgress(subjectId);
    final daysLeft = subject.examDate?.difference(DateTime.now()).inDays;

    return Scaffold(
      appBar: AppBar(title: Text(subject.name)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final session = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SessionEditorScreen(
                controller: controller,
                initialSubjectId: subject.id,
                initialStart: DateTime.now()
                    .add(const Duration(hours: 1))
                    .copyWith(minute: 0, second: 0),
              ),
            ),
          );
          if (session != null) await controller.upsertSession(session);
        },
        icon: const Icon(Icons.add),
        label: const Text('Plan'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: subject.color.withValues(alpha: 0.2),
                child: Icon(subject.icon, color: subject.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(subject.name, style: theme.textTheme.headlineSmall),
                    if (daysLeft != null)
                      Text(
                        'Target in $daysLeft ${daysLeft == 1 ? 'day' : 'days'}'
                        '${subject.examDate == null ? '' : ' · ${DateFormat.yMMMd().format(subject.examDate!)}'}'
                        '${subject.targetHours == null ? '' : ' · ${(rate * 100).round()}% of ${subject.targetHours!.toStringAsFixed(0)}h'}',
                        style: theme.textTheme.bodySmall,
                      )
                    else if (subject.targetHours != null)
                      Text(
                        '${(rate * 100).round()}% of ${subject.targetHours!.toStringAsFixed(0)}h target',
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              Text('${(rate * 100).round()}%', style: theme.textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: rate, minHeight: 8),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('Studied', StudyAnalytics.formatMinutes(done)),
              _chip('Planned', StudyAnalytics.formatMinutes(planned)),
              _chip('Sessions', '${related.length}'),
              _chip('Missed', '$missed'),
              _chip('Upcoming', '$upcoming'),
              if (subject.targetHours != null)
                _chip('Target', '${subject.targetHours!.toStringAsFixed(0)}h'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Topics', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final topic in subject.topics)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(topic.name),
                subtitle: LinearProgressIndicator(
                  value: controller.topicProgress(subject.id, topic.id),
                  minHeight: 6,
                ),
                trailing: Text(
                  '${(controller.topicProgress(subject.id, topic.id) * 100).round()}%',
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TopicDetailScreen(
                      controller: controller,
                      subjectId: subject.id,
                      topicId: topic.id,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          Text('Recent sessions', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final s in related.take(8))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.title),
              subtitle: Text(
                '${DateFormat('EEE, MMM d · h:mm a').format(s.plannedStart)} · ${s.status.label}',
              ),
              trailing: Text(StudyAnalytics.formatMinutes(s.plannedMinutes)),
            ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Chip(label: Text('$label: $value'));
  }
}
