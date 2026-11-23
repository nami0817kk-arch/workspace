import 'package:flutter/material.dart';

/// 和紙と墨と朱。戦国の書状の色（2026-11-23、ユーザー「画面暗すぎ」で墨色の暗い画面から変えた）。
class Pal {
  static const bg = Color(0xFFF2E8D5);
  static const panel = Color(0xFFFAF5EA);
  static const panel2 = Color(0xFFE8DCC6);
  static const ink = Color(0xFF2A2420);
  static const muted = Color(0xFF75675A);
  static const accent = Color(0xFFB23A2B);
  static const gold = Color(0xFF9A6B12);
  static const line = Color(0xFFD3C3A8);
  static const good = Color(0xFF3F7A2E);
  static const bad = Color(0xFFB23A2B);
  static const blue = Color(0xFF2D6699);
  static const purple = Color(0xFF7A4A9E);

  /// 朱の釦の上の文字。
  static const onAccent = Color(0xFFFFF8EC);

  /// 棒グラフ・升の空いている所。
  static const track = Color(0xFFDCCEB5);
}

const _serif = ['Hiragino Mincho ProN', 'Yu Mincho', 'Noto Serif JP', 'serif'];

ThemeData buildTheme() {
  final base = ThemeData(
    brightness: Brightness.light,
    useMaterial3: true,
    scaffoldBackgroundColor: Pal.bg,
    colorScheme: const ColorScheme.light(
      primary: Pal.accent,
      secondary: Pal.gold,
      surface: Pal.panel,
      onSurface: Pal.ink,
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: Pal.ink,
      displayColor: Pal.ink,
      fontFamilyFallback: _serif,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Pal.panel,
      indicatorColor: Pal.accent.withValues(alpha: .18),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 12, color: Pal.ink, fontFamilyFallback: _serif),
      ),
    ),
  );
}
