import 'package:flutter/material.dart';

import '../models/subject.dart';
import '../state/orbit_controller.dart';
import '../widgets/empty_state.dart';
import 'subject_detail_screen.dart';

class SubjectsScreen extends StatelessWidget {
  const SubjectsScreen({super.key, required this.controller});

  final OrbitController controller;

  @override
  Widget build(BuildContext context) {
    final subjects = controller.subjects.where((s) => !s.archived).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Subjects')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context),
        icon: const Icon(Icons.add),
        label: const Text('Add subject'),
      ),
      body: subjects.isEmpty
          ? EmptyState(
              icon: Icons.menu_book_outlined,
              title: 'No subjects yet',
              message:
                  'Subjects group related topics so you can plan sessions and track progress — for courses, certifications, or learning goals.',
              actionLabel: 'Add subject',
              onAction: () => _edit(context),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: subjects.length,
              itemBuilder: (context, index) {
                final s = subjects[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: s.color.withValues(alpha: 0.2),
                      child: Icon(s.icon, color: s.color),
                    ),
                    title: Text(s.name),
                    subtitle: Text(
                      '${s.topics.length} topics${s.targetHours == null ? '' : ' · target ${s.targetHours}h'}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _edit(context, existing: s),
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SubjectDetailScreen(
                          controller: controller,
                          subjectId: s.id,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _edit(BuildContext context, {Subject? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final topicCtrl = TextEditingController();
    var color = existing?.colorValue ?? 0xFF4F46E5;
    final topics = existing?.topics.map((t) => t.copyWith()).toList() ?? <Topic>[];
    final colors = [
      0xFF4F46E5,
      0xFF0284C7,
      0xFF0D9488,
      0xFFEA580C,
      0xFFDB2777,
      0xFF16A34A,
    ];

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    existing == null ? 'New subject' : 'Edit subject',
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Subject name'),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    children: [
                      for (final c in colors)
                        GestureDetector(
                          onTap: () => setModal(() => color = c),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Color(c),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: color == c ? Colors.black : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Topics', style: Theme.of(ctx).textTheme.titleSmall),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: topicCtrl,
                          decoration: const InputDecoration(hintText: 'Add topic'),
                          onSubmitted: (_) {
                            final t = topicCtrl.text.trim();
                            if (t.isEmpty) return;
                            setModal(() {
                              topics.add(Topic(
                                id: DateTime.now().microsecondsSinceEpoch.toString(),
                                name: t,
                              ));
                              topicCtrl.clear();
                            });
                          },
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          final t = topicCtrl.text.trim();
                          if (t.isEmpty) return;
                          setModal(() {
                            topics.add(Topic(
                              id: DateTime.now().microsecondsSinceEpoch.toString(),
                              name: t,
                            ));
                            topicCtrl.clear();
                          });
                        },
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  for (final t in topics)
                    ListTile(
                      dense: true,
                      title: Text(t.name),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setModal(() => topics.remove(t)),
                      ),
                    ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      if (nameCtrl.text.trim().isEmpty) return;
                      Navigator.pop(ctx, true);
                    },
                    child: const Text('Save'),
                  ),
                  if (existing != null)
                    TextButton(
                      onPressed: () async {
                        await controller.archiveSubject(existing.id);
                        if (ctx.mounted) Navigator.pop(ctx, false);
                      },
                      child: const Text('Archive subject'),
                    ),
                ],
              ),
            );
          },
        );
      },
    );

    if (saved == true) {
      final subject = existing == null
          ? Subject(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              name: nameCtrl.text.trim(),
              colorValue: color,
              topics: topics,
            )
          : existing.copyWith(
              name: nameCtrl.text.trim(),
              colorValue: color,
              topics: topics,
            );
      await controller.upsertSubject(subject);
    }
    nameCtrl.dispose();
    topicCtrl.dispose();
  }
}
