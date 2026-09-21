import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design_tokens.dart';

class AppTheme {
  static const String appName = 'OrbitFlow';
  static const String appTagline = 'Personal Productivity & Study OS';

  static const List<Color> themeAccents = [
    Color(0xFF4F46E5), // Indigo Pulse
    Color(0xFF0284C7), // Horizon Blue
    Color(0xFF0D9488), // Aurora Teal
    Color(0xFFEA580C), // Solar Orange
    Color(0xFFDB2777), // Magenta Signal
    Color(0xFF16A34A), // Verdant
  ];

  static const List<String> themeAccentNames = [
    'Indigo',
    'Horizon',
    'Aurora',
    'Solar',
    'Magenta',
    'Verdant',
  ];

  // Dark surface ladder (not pure black).
  static const Color _darkBg = Color(0xFF12141A);
  static const Color _darkSurface = Color(0xFF1A1D26);
  static const Color _darkElevated = Color(0xFF222632);
  static const Color _darkBorder = Color(0xFF2E3444);

  static const Color _lightBg = Color(0xFFF4F6FA);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightBorder = Color(0xFFE6E9F0);

  static ThemeData light([Color seedColor = const Color(0xFF4F46E5)]) {
    final base = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );
    final scheme = base.copyWith(
      surface: _lightBg,
      onSurface: const Color(0xFF1A1C22),
      onSurfaceVariant: const Color(0xFF5C6370),
      surfaceContainerLowest: _lightSurface,
      surfaceContainerLow: const Color(0xFFF8F9FC),
      surfaceContainer: const Color(0xFFEEF1F7),
      surfaceContainerHigh: const Color(0xFFE8ECF4),
      surfaceContainerHighest: const Color(0xFFE2E6EF),
      outlineVariant: _lightBorder,
      primaryContainer: seedColor.withValues(alpha: 0.12),
      onPrimaryContainer: seedColor,
    );
    return _build(scheme, seedColor, Brightness.light);
  }

  static ThemeData dark([Color seedColor = const Color(0xFF4F46E5)]) {
    final base = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    );
    final softPrimary = Color.lerp(seedColor, Colors.white, 0.18)!;
    final scheme = base.copyWith(
      primary: softPrimary,
      onPrimary: const Color(0xFF0E1016),
      surface: _darkBg,
      onSurface: const Color(0xFFE8EAF2),
      onSurfaceVariant: const Color(0xFFA8B0C0),
      surfaceContainerLowest: _darkSurface,
      surfaceContainerLow: _darkSurface,
      surfaceContainer: _darkElevated,
      surfaceContainerHigh: const Color(0xFF2A2F3C),
      surfaceContainerHighest: const Color(0xFF323846),
      outlineVariant: _darkBorder,
      primaryContainer: softPrimary.withValues(alpha: 0.18),
      onPrimaryContainer: const Color(0xFFD8DCFF),
      error: const Color(0xFFFF8A80),
      onError: const Color(0xFF3B0505),
      tertiary: const Color(0xFF7DCEA0),
    );
    return _build(scheme, softPrimary, Brightness.dark);
  }

  static ThemeData _build(ColorScheme scheme, Color seed, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
    );

    final textTheme = base.textTheme
        .apply(
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
        )
        .copyWith(
          displaySmall: base.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
          headlineMedium: base.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
          headlineSmall: base.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
          titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          titleSmall: base.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          labelLarge: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          bodySmall: base.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        );

    final cardColor = isDark ? _darkSurface : _lightSurface;
    final cardBorder = isDark ? _darkBorder : _lightBorder;

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: AppElevation.low,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: AppElevation.none,
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdAll,
          side: BorderSide(color: cardBorder.withValues(alpha: isDark ? 0.9 : 1)),
        ),
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? _darkElevated : scheme.surfaceContainerLow,
        selectedColor: scheme.primaryContainer,
        disabledColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
        labelStyle: textTheme.labelMedium,
        secondaryLabelStyle: textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        showCheckmark: false,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: isDark ? AppElevation.low : AppElevation.medium,
        highlightElevation: AppElevation.medium,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? _darkElevated : const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        labelStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: AppRadius.smAll,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.smAll,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.smAll,
          borderSide: BorderSide(color: seed, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.smAll,
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return scheme.primaryContainer;
            }
            return isDark ? _darkElevated : scheme.surfaceContainerLowest;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return scheme.onPrimaryContainer;
            }
            return scheme.onSurface;
          }),
          side: WidgetStatePropertyAll(
            BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.8)),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppRadius.smAll),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? _darkElevated : null,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? _darkSurface : _lightSurface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? _darkSurface : _lightSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        ),
        showDragHandle: true,
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: AppSpacing.xs,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        iconColor: scheme.onSurfaceVariant,
        subtitleTextStyle: textTheme.bodySmall,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: isDark ? 0.55 : 0.6),
        space: 1,
        thickness: 1,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return scheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary.withValues(alpha: 0.35);
          }
          return scheme.surfaceContainerHighest;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.surfaceContainerHighest,
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.12),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: scheme.surfaceContainerHighest,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? _darkSurface : scheme.surface,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
        elevation: 0,
        height: 72,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: isDark ? _darkSurface : scheme.surface,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.primary),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(color: scheme.primary),
        unselectedLabelTextStyle:
            textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
        indicatorShape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
        labelType: NavigationRailLabelType.all,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(AppTouchTarget.min, AppTouchTarget.min),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(AppTouchTarget.min, AppTouchTarget.min),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(AppTouchTarget.min, 40),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
