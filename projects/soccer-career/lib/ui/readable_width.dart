import 'package:flutter/material.dart';

/// 横に広い画面でも、1行が伸びきらないようにする。
///
/// スマホの縦画面を前提に組んであるので、PC のブラウザで開くと
/// カードが画面幅いっぱいまで広がり、1行が長すぎて読めなくなる。
/// 中身は変えずに、読める幅で中央に置くだけ。
class ReadableWidth extends StatelessWidget {
  const ReadableWidth({super.key, required this.child, this.maxWidth = maxContentWidth});

  /// 本文の最大幅。スマホの縦画面（390〜430px）より少しだけ広くしてある。
  /// 広げすぎると、そもそも縦に積む前提の配置が間延びする。
  static const double maxContentWidth = 520;

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
