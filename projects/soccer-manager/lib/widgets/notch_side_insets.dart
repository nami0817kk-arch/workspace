import 'package:flutter/material.dart';

/// 横画面の iPhone で、切り欠き(スピーカーのある側)に値が隠れないよう、
/// 全画面・全ダイアログの左右を端末の安全な幅だけ空ける。
///
/// 画面ごとの SafeArea は左だけ・上だけなど抜けがあり、端末を逆向きに持つと
/// 右端に並ぶ数字が切り欠きの下に入っていた。ここで一度に空けておけば、
/// 新しい画面を足しても漏れない。空けた所は画面の地の色で塗る。
class NotchSideInsets extends StatelessWidget {
  const NotchSideInsets({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.viewPaddingOf(context);
    if (pad.left == 0 && pad.right == 0) return child;
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(top: false, bottom: false, child: child),
    );
  }
}
