import 'package:flutter/material.dart';

/// 縦長の画面では区切り線(または何も出さない)、横長の画面では左右の境目に
/// なる印。[TwoPane] がこの位置で子を左右に分ける。
class PaneBreak extends StatelessWidget {
  /// 縦長で区切り線を出すか。出さないときは、縦長の見た目を変えない。
  final bool divider;

  const PaneBreak({super.key, this.divider = true});

  @override
  Widget build(BuildContext context) =>
      divider ? const Divider(height: 32) : const SizedBox.shrink();
}

/// 縦長では1本のリスト、横長では[PaneBreak]で左右に分けた2本のリスト。
/// 横画面は高さが 400 ほどしかなく、設定やカードを一覧の上に積むと、
/// 目当てに届くまでに何画面も送ることになる。
class TwoPane extends StatelessWidget {
  final bool wide;
  final List<Widget> children;

  const TwoPane({super.key, required this.wide, required this.children});

  @override
  Widget build(BuildContext context) {
    const padding = EdgeInsets.all(16);
    final split = children.indexWhere((w) => w is PaneBreak);
    if (!wide || split < 0) {
      return ListView(padding: padding, children: children);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: ListView(
              padding: padding, children: children.sublist(0, split)),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 6,
          child: ListView(
              padding: padding, children: children.sublist(split + 1)),
        ),
      ],
    );
  }
}
