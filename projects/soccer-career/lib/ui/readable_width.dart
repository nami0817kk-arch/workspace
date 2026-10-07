import 'package:flutter/material.dart';

/// 横に広い画面でも、1行が伸びきらないようにする。
///
/// スマホの縦画面を前提に組んであるので、PC のブラウザで開くと
/// カードが画面幅いっぱいまで広がり、1行が長すぎて読めなくなる。
/// 中身は変えずに、読める幅で中央に置くだけ。
class ReadableWidth extends StatelessWidget {
  const ReadableWidth({super.key, required this.child, this.maxWidth = maxContentWidth});

  /// 本文の最大幅。
  ///
  /// 以前は 520 だった（スマホの縦画面より少しだけ広い値）。iPad 13インチの
  /// 掲載用の絵を撮ったら、**中身が真ん中の細い1列に収まって左右が大きく
  /// 空いた**。崩れてはいないが、13インチの絵として間が持たない。
  ///
  /// `soccer-manager` は同じ役の `ResponsiveBody` を **720** にしていて、
  /// iPad の絵は幅が埋まっている。2026-09-26 にそちらへ揃えた。
  ///
  /// **スマホでは何も変わらない**（画面幅 390〜430 はどちらの値より狭いので、
  /// 常に画面いっぱいになる）。変わるのは iPad と PC のブラウザだけ。
  static const double maxContentWidth = 720;

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );
}
