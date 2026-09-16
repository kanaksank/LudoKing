import 'package:flutter/material.dart';

import 'app_tokens.dart';

class AppTheme {
  AppTheme._();

  static ThemeData dark() => _build(Brightness.dark, SurfaceTokens.dark);
  static ThemeData light() => _build(Brightness.light, SurfaceTokens.light);

  static ThemeData _build(Brightness b, SurfaceTokens t) {
    final scheme = ColorScheme.fromSeed(
      seedColor: LudoPalette.blue,
      brightness: b,
    ).copyWith(surface: t.surface, onSurface: t.textPrimary);
    final base = ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: t.background,
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: t.textPrimary,
        displayColor: t.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: t.background,
        foregroundColor: t.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      drawerTheme: DrawerThemeData(backgroundColor: t.surface),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? LudoPalette.green : null,
        ),
      ),
    );
  }
}
