// Design tokens. The same values are documented in docs/DESIGN.md.
import 'package:flutter/material.dart';

class LudoPalette {
  LudoPalette._();
  static const red = Color(0xFFFF3B30);
  static const green = Color(0xFF34C759);
  static const yellow = Color(0xFFFFCC00);
  static const blue = Color(0xFF007AFF);
  static const purple = Color(0xFFAF52DE);
  static const orange = Color(0xFFFF9500);

  static const all = [red, green, yellow, blue, purple, orange];
  static const names = ['Red', 'Green', 'Yellow', 'Blue', 'Purple', 'Orange'];

  static Color of(int index) => all[index % all.length];

  /// Lighten (positive) or darken (negative) a colour.
  static Color shade(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0).toDouble()).toColor();
  }

  static const inactive = Color(0xFFB8BEC9);
  static const gold = Color(0xFFFFD60A);
}

class SurfaceTokens {
  const SurfaceTokens({
    required this.background,
    required this.surface,
    required this.raised,
    required this.boardPlate,
    required this.tile,
    required this.tileBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.shadowLight,
    required this.shadowDark,
  });

  final Color background;
  final Color surface;
  final Color raised;
  final Color boardPlate;
  final Color tile;
  final Color tileBorder;
  final Color textPrimary;
  final Color textSecondary;
  final Color shadowLight;
  final Color shadowDark;

  static const dark = SurfaceTokens(
    background: Color(0xFF151923),
    surface: Color(0xFF1D2330),
    raised: Color(0xFF252C3B),
    boardPlate: Color(0xFF2B3346),
    tile: Color(0xFFF4F6FA),
    tileBorder: Color(0xFFD5DAE3),
    textPrimary: Color(0xFFF5F7FB),
    textSecondary: Color(0xFF9AA4B8),
    shadowLight: Color(0x14FFFFFF),
    shadowDark: Color(0x8C000000),
  );

  static const light = SurfaceTokens(
    background: Color(0xFFE9EDF3),
    surface: Color(0xFFEFF2F7),
    raised: Color(0xFFF7F9FC),
    boardPlate: Color(0xFFDDE3EC),
    tile: Color(0xFFFFFFFF),
    tileBorder: Color(0xFFD3D9E3),
    textPrimary: Color(0xFF1B2130),
    textSecondary: Color(0xFF647086),
    shadowLight: Color(0xFFFFFFFF),
    shadowDark: Color(0x33536480),
  );

  static SurfaceTokens of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

class Space {
  Space._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

class Radii {
  Radii._();
  static const sm = 10.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const pill = 999.0;
}

class Motion {
  Motion._();
  static const tokenStep = Duration(milliseconds: 170);
  static const tokenStepFast = Duration(milliseconds: 105);
  static const diceRoll = Duration(milliseconds: 620);
  static const emojiFloat = Duration(milliseconds: 1900);
  static const shake = Duration(milliseconds: 420);
  static const press = Duration(milliseconds: 110);
}

const avatarChoices = ['🦁', '🐯', '🦊', '🐼', '🐸', '🐙', '🦄', '🐧', '🐨', '🐵', '🤖', '👾'];
