import 'package:flutter/material.dart';

/// 夜の体育館の色。暗い紺の下地に、ボールの橙。
class GmColors {
  static const bg = Color(0xFF0E1726);
  static const panel = Color(0xFF172338);
  static const panelHi = Color(0xFF213150);
  static const line = Color(0xFF2E4266);
  static const ball = Color(0xFFFF7A1A);
  static const text = Color(0xFFEFF3FA);
  static const sub = Color(0xFFA9B6CC);
  static const good = Color(0xFF4CD08A);
  static const bad = Color(0xFFFF5C6C);
  static const gold = Color(0xFFFFC53D);

  /// 力の数字の色(高いほど明るい)。
  static Color ovr(int o) => o >= 80
      ? gold
      : o >= 72
          ? ball
          : o >= 64
              ? const Color(0xFF8FD3FF)
              : sub;
}

ThemeData gmTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: GmColors.ball, brightness: Brightness.dark).copyWith(
    primary: GmColors.ball,
    onPrimary: Colors.white,
    surface: GmColors.panel,
    onSurface: GmColors.text,
    surfaceContainer: GmColors.panel,
    surfaceContainerHigh: GmColors.panelHi,
    outlineVariant: GmColors.line,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'NotoSansJP',
    scaffoldBackgroundColor: GmColors.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      scrolledUnderElevation: 0,
      foregroundColor: GmColors.text,
      titleTextStyle: TextStyle(fontFamily: 'NotoSansJP', fontSize: 18, fontWeight: FontWeight.bold, color: GmColors.text),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: GmColors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: GmColors.line),
      ),
    ),
    dialogTheme: const DialogThemeData(backgroundColor: GmColors.panel),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: GmColors.panel),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        textStyle: const TextStyle(fontFamily: 'NotoSansJP', fontSize: 16, fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(46),
        foregroundColor: GmColors.text,
        side: const BorderSide(color: GmColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
