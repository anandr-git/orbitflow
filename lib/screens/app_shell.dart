import 'package:flutter/material.dart';

import '../state/orbit_controller.dart';
import '../storage/todo_repository.dart';
import 'home_screen.dart';
import 'insights_screen.dart';
import 'session_editor_screen.dart';
import 'settings_screen.dart';
import 'study_home_screen.dart';
import 'subjects_screen.dart';
import 'week_screen.dart';
import '../utils/responsive.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});

  final OrbitController controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  int _tasksEpoch = 0;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final controller = widget.controller;

    final pages = [
      StudyHomeScreen(controller: controller),
      HomeScreen(
        key: ValueKey('tasks-$_tasksEpoch'),
        settings: controller.settings,
        onSettingsChanged: controller.updateSettings,
        initialTodos: controller.todos,
        onTodosChanged: controller.saveTodos,
      ),
      WeekScreen(controller: controller),
      InsightsScreen(controller: controller),
      SettingsScreen(
        settings: controller.settings,
        onSettingsChanged: controller.updateSettings,
        onClearCompleted: () async {
          final repo = TodoRepository();
          final todos = await repo.loadTodos();
          final kept = todos.where((t) => !t.done || t.archived).toList();
          await repo.saveTodos(kept);
          await controller.saveTodos(kept);
          if (mounted) setState(() => _tasksEpoch++);
        },
        todos: controller.todos,
        onImportTodos: controller.saveTodos,
        onExport: controller.exportBackup,
        controller: controller,
      ),
    ];

    if (responsive.useTwoPane) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              extended: responsive.width >= 1100,
              labelType: responsive.width >= 1100
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.auto_stories_outlined),
                  selectedIcon: Icon(Icons.auto_stories),
                  label: Text('Study'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.checklist_outlined),
                  selectedIcon: Icon(Icons.checklist),
                  label: Text('Tasks'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.view_week_outlined),
                  selectedIcon: Icon(Icons.view_week),
                  label: Text('Week'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.insights_outlined),
                  selectedIcon: Icon(Icons.insights),
                  label: Text('Insights'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Settings'),
                ),
              ],
              trailing: FloatingActionButton.small(
                tooltip: 'Plan a focus session',
                onPressed: () => _planSession(context),
                child: const Icon(Icons.add),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: pages[_index]),
          ],
        ),
      );
    }

    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _index, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories),
            label: 'Study',
            tooltip: 'Daily plan and focus sessions',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: 'Tasks',
            tooltip: 'Work and personal to-dos',
          ),
          NavigationDestination(
            icon: Icon(Icons.view_week_outlined),
            selectedIcon: Icon(Icons.view_week),
            label: 'Week',
            tooltip: 'Plan across the week',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Insights',
            tooltip: 'Progress and review',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
            tooltip: 'Theme, goals, notifications',
          ),
        ],
      ),
      floatingActionButton: _index == 0
          ? FloatingActionButton.extended(
              tooltip: 'Plan a focus session',
              onPressed: () => _planSession(context),
              icon: const Icon(Icons.add),
              label: const Text('Plan'),
            )
          : null,
    );
  }

  Future<void> _planSession(BuildContext context) async {
    final controller = widget.controller;
    if (controller.subjects.where((s) => !s.archived).isEmpty) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SubjectsScreen(controller: controller)),
      );
      return;
    }
    final session = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SessionEditorScreen(controller: controller)),
    );
    if (session != null) {
      await controller.upsertSession(session);
    }
  }
}
