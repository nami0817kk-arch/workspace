import 'package:flutter/material.dart';

/// アプリのテーマ。**1か所から出す。**
///
/// 以前は `main.dart` の中だけに書いてあり、撮影（`test/shots.dart`）と
/// ウィジェットテストは自前で `ThemeData` を組んでいた。そのため
/// **カードの影を足しても、書き出した絵には出なかった**——
/// 「撮っていない画面は、崩れていないのではなく見ていないだけ」と同じ穴が、
/// テーマそのものに開いていた。
ThemeData appTheme(Color seed, Brightness brightness, {String? fontFamily}) {
  final light = brightness == Brightness.light;
  // 差し色はクラブの色から作る。**移籍すれば色が変わる**という前提は
  // ここで守られている（primary / secondary / tertiary と、その container）。
  final seeded = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
  // **面はニュートラルに戻す。**
  //
  // `ColorScheme.fromSeed` は地・紙・札・文字まで種の色相で染める。
  // 実測すると、拠点の画面は無彩色が 43.7% しかなく、残りのほぼ全部が
  // 同じ緑（色相 60〜90度）だった——**1色相で塗り潰された画面**は、
  // 質感をどれだけ足しても「既定のまま作った画面」に見える。
  // 面を紙と墨に戻して、クラブの色は差し色として残す。
  final scheme = seeded.copyWith(
    surface: light ? const Color(0xFFFAF9F5) : const Color(0xFF121210),
    surfaceContainerLowest: light
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF0B0B09),
    surfaceContainerLow: light
        ? const Color(0xFFF6F5F0)
        : const Color(0xFF171714),
    surfaceContainer: light ? const Color(0xFFF0EEE8) : const Color(0xFF1C1C19),
    surfaceContainerHigh: light
        ? const Color(0xFFE9E7E0)
        : const Color(0xFF24241F),
    surfaceContainerHighest: light
        ? const Color(0xFFE1DFD6)
        : const Color(0xFF2D2D27),
    onSurface: light ? const Color(0xFF1A1A17) : const Color(0xFFECEAE3),
    onSurfaceVariant: light ? const Color(0xFF5B5951) : const Color(0xFFA9A69C),
    outline: light ? const Color(0xFF8C8A80) : const Color(0xFF6E6C63),
    outlineVariant: light ? const Color(0xFFD3D0C6) : const Color(0xFF3A392F),
  );

  // **文字に段差を付ける。** 数字と見出しと添え書きがほとんど同じ大きさ・
  // 同じ太さで並んでいると、何を先に読めばいいのか決まらない。
  // 数字は等幅の桁（`tabularFigures`）にする——並べたときに桁が揺れると、
  // 表が手書きに見える。
  //
  // **`textTheme` を明示すると `fontFamily` はそこに適用されない。**
  // `ThemeData(fontFamily: ...)` は既定の書体表にだけ効くので、
  // 自前で組んだ表を渡すと全部が既定の書体に落ちる——同梱フォントに
  // 乗らず、日本語が**まるごと豆腐（□）になる**（実際になった）。
  // `font_test` は「その文字がフォントにあるか」を見るので、この
  // 壊れ方は拾えない。**書き出して目で見て初めて分かる。**
  // 最後に `apply(fontFamily:)` で書体を塗り直す。
  const figures = [FontFeature.tabularFigures()];
  final base = (light ? ThemeData.light() : ThemeData.dark()).textTheme;
  final text = base
      .copyWith(
        displaySmall: base.displaySmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -1.0,
          fontFeatures: figures,
        ),
        headlineMedium: base.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
          fontFeatures: figures,
        ),
        headlineSmall: base.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
          fontFeatures: figures,
        ),
        titleLarge: base.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          fontFeatures: figures,
        ),
        titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        bodyMedium: base.bodyMedium?.copyWith(height: 1.45),
        bodySmall: base.bodySmall?.copyWith(height: 1.4),
        // 添え書きは小さく、字間を開ける。見出しとの差が付いて、
        // 「読むもの」と「添えるもの」が一目で分かれる。
        labelSmall: base.labelSmall?.copyWith(
          letterSpacing: 0.6,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: base.labelMedium?.copyWith(letterSpacing: 0.3),
      )
      .apply(fontFamily: fontFamily);

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: fontFamily,
    textTheme: text,
    scaffoldBackgroundColor: scheme.surface,
    // **カードを紙として浮かせる。** M3 の既定（elevation 1・影は淡い）だと
    // 地とカードの境が色の差だけになり、画面ぜんぶが1枚の板に見える。
    // 面の明るさで前後を分けて、影はその裏付けに留める——影だけで浮かせ
    // ようとすると、2倍の PNG では輪郭線に見える（実際そうなって戻した）。
    cardTheme: CardThemeData(
      elevation: light ? 2 : 1,
      color: light ? scheme.surfaceContainerLowest : scheme.surfaceContainerLow,
      shadowColor: light ? const Color(0xFF2A2A22) : Colors.black,
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
  );
}
