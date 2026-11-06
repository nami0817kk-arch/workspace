import 'package:flutter/material.dart';

import '../../deck/cards.dart';
import '../../deck/run.dart';

/// 夜の体育館の色。暗い紺の下地に、ボールの橙。
class DeckColors {
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

  static Color kind(CardKind k) => switch (k) {
        CardKind.shot => const Color(0xFFFF7A1A),
        CardKind.play => const Color(0xFF3BA7F0),
        CardKind.defense => const Color(0xFF2BB39A),
        CardKind.power => const Color(0xFFB06CE0),
        CardKind.status => const Color(0xFF6B7890),
      };

  static Color rarity(Rarity r) => switch (r) {
        Rarity.rare => gold,
        Rarity.uncommon => const Color(0xFF8FD3FF),
        _ => const Color(0xFF8A97AD),
      };
}

IconData nodeIcon(NodeType t) => switch (t) {
      NodeType.game => Icons.sports_basketball_rounded,
      NodeType.elite => Icons.local_fire_department_rounded,
      NodeType.practice => Icons.fitness_center_rounded,
      NodeType.shop => Icons.storefront_rounded,
      NodeType.event => Icons.auto_awesome_rounded,
      NodeType.boss => Icons.emoji_events_rounded,
    };

Color nodeColor(NodeType t) => switch (t) {
      NodeType.game => DeckColors.ball,
      NodeType.elite => DeckColors.bad,
      NodeType.practice => DeckColors.good,
      NodeType.shop => const Color(0xFF3BA7F0),
      NodeType.event => const Color(0xFFB06CE0),
      NodeType.boss => DeckColors.gold,
    };

ThemeData deckTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: DeckColors.ball, brightness: Brightness.dark).copyWith(
    primary: DeckColors.ball,
    onPrimary: Colors.white,
    surface: DeckColors.panel,
    onSurface: DeckColors.text,
    surfaceContainer: DeckColors.panel,
    surfaceContainerHigh: DeckColors.panelHi,
    outlineVariant: DeckColors.line,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'NotoSansJP',
    scaffoldBackgroundColor: DeckColors.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      scrolledUnderElevation: 0,
      foregroundColor: DeckColors.text,
      titleTextStyle: TextStyle(fontFamily: 'NotoSansJP', fontSize: 18, fontWeight: FontWeight.bold, color: DeckColors.text),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: DeckColors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: DeckColors.line),
      ),
    ),
    dialogTheme: const DialogThemeData(backgroundColor: DeckColors.panel),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: DeckColors.panel),
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
        foregroundColor: DeckColors.text,
        side: const BorderSide(color: DeckColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
