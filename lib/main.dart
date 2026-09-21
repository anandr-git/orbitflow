import 'package:flutter/material.dart';

import 'models/app_settings.dart';
import 'screens/app_shell.dart';
import 'screens/onboarding_screen.dart';
import 'state/orbit_controller.dart';
import 'theme/app_theme.dart';
import 'theme/design_tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final OrbitController _controller = OrbitController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChange);
    _controller.bootstrap();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onChange);
    _controller.dispose();
    super.dispose();
  }

  ThemeMode get _themeMode => switch (_controller.settings.themePreference) {
        ThemePreference.system => ThemeMode.system,
        ThemePreference.light => ThemeMode.light,
        ThemePreference.dark => ThemeMode.dark,
      };

  @override
  Widget build(BuildContext context) {
    final settings = _controller.settings;
    final accent = AppTheme.themeAccents[
        settings.colorIndex.clamp(0, AppTheme.themeAccents.length - 1)];

    return MaterialApp(
      title: AppTheme.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(accent),
      darkTheme: AppTheme.dark(accent),
      themeMode: _themeMode,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final disableAnimations = settings.reduceMotion;
        return MediaQuery(
          data: mq.copyWith(
            disableAnimations: disableAnimations ? true : mq.disableAnimations,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: !_controller.ready
          ? const _OrbitBootScreen()
          : _controller.lastError != null &&
                  _controller.subjects.isEmpty &&
                  _controller.sessions.isEmpty &&
                  _controller.todos.isEmpty
              ? _OrbitErrorScreen(
                  message: _controller.lastError!,
                  onRetry: _controller.retryBootstrap,
                )
              : !_controller.settings.onboardingComplete
                  ? OnboardingScreen(controller: _controller)
                  : AppShell(controller: _controller),
    );
  }
}

class _OrbitBootScreen extends StatelessWidget {
  const _OrbitBootScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppTheme.appName, style: theme.textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Loading your study plan…',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrbitErrorScreen extends StatelessWidget {
  const _OrbitErrorScreen({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppTheme.appName, style: theme.textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Could not load OrbitFlow.',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}
