import 'package:flutter/material.dart';

/// 墨と朱と金。戦国の暗い紙の色。
class Pal {
  static const bg = Color(0xFF14110F);
  static const panel = Color(0xFF201B17);
  static const panel2 = Color(0xFF2A231E);
  static const ink = Color(0xFFECE2D1);
  static const muted = Color(0xFFA09484);
  static const accent = Color(0xFFC8402F);
  static const gold = Color(0xFFD6A84A);
  static const line = Color(0xFF3A312A);
  static const good = Color(0xFF7FB069);
  static const bad = Color(0xFFE0745F);
  static const blue = Color(0xFF6FA8DC);
  static const purple = Color(0xFFB57EDC);
}

const _serif = ['Hiragino Mincho ProN', 'Yu Mincho', 'Noto Serif JP', 'serif'];

ThemeData buildTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: Pal.bg,
    colorScheme: const ColorScheme.dark(
      primary: Pal.accent,
      secondary: Pal.gold,
      surface: Pal.panel,
      onSurface: Pal.ink,
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme
        .apply(bodyColor: Pal.ink, displayColor: Pal.ink, fontFamilyFallback: _serif),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Pal.panel,
      indicatorColor: Pal.accent.withValues(alpha: .35),
      labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 12, color: Pal.ink, fontFamilyFallback: _serif)),
    ),
  );
}
