import 'package:flutter/material.dart';

/// アプリのテーマ。**1か所から出す。**
///
/// 以前は `main.dart` の中だけに書いてあり、撮影（`test/shots.dart`）と
/// ウィジェットテストは自前で `ThemeData` を組んでいた。そのため
/// **カードの影を足しても、書き出した絵には出なかった**——
/// 「撮っていない画面は、崩れていないのではなく見ていないだけ」と同じ穴が、
/// テーマそのものに開いていた。
ThemeData appTheme(Color seed, Brightness brightness, {String? fontFamily}) {
  final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: fontFamily,
    // **カードを紙として浮かせる。** M3 の既定（elevation 1・影は淡い）だと
    // 地とカードの境が色の差だけになり、画面ぜんぶが1枚の板に見える。
    // 影の色はクラブの色から作る——真っ黒を落とすと、クラブの色で染めた
    // 画面に1つだけ無彩色のものが混ざる。
    cardTheme: CardThemeData(
      elevation: 2,
      // **紙を白く、地を沈める。** 影だけで浮かせようとすると、
      // 小さい画面では影が輪郭線に見える（実際そうなった）。
      // 面の明るさで前後を分けて、影はその裏付けに留める。
      color: brightness == Brightness.light
          ? scheme.surfaceContainerLowest
          : scheme.surfaceContainerHigh,
      shadowColor: Color.alphaBlend(
        scheme.primary.withValues(alpha: 0.35),
        Colors.black,
      ),
    ),
    scaffoldBackgroundColor: brightness == Brightness.light
        ? scheme.surfaceContainer
        : scheme.surfaceContainerLowest,
  );
}
