import 'package:flutter/material.dart';

import 'screen_bar.dart';

/// 画面本体をワイド画面(デスクトップブラウザ等)では中央寄せ・最大幅制限し、
/// スマートフォン等の狭い画面では従来通り全幅で表示するラッパー。
/// PC等の広いウィンドウでリスト・カードが不必要に間延びするのを防ぐ。
class ResponsiveBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveBody({super.key, required this.child, this.maxWidth = 720});

  @override
  Widget build(BuildContext context) {
    // 左メニューに埋め込まれた横画面では、どのページも同じ全幅にそろえる
    // (ページごとに中身の幅が違うと、切り替えるたびに画面がガタつく)。
    if (EmbeddedInShell.of(context)) return child;
    // 横画面(FM風)は、その他メニューから開く画面も全幅にそろえる。
    final size = MediaQuery.sizeOf(context);
    if (size.width > size.height) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
