import 'package:flutter/material.dart';

/// 幅が広ければ2列、狭ければ1列で並べるリスト(iPad の横向きなどで使う)。
///
/// 2列のときは、前半を左、後半を右に置く(上から読む順を崩さない)。
/// 見出しと中身が分かれないよう、区切りは[SizedBox]や[Text]の直後を
/// 避けてカードの前に寄せる。
class AutoColumns extends StatelessWidget {
  final List<Widget> children;

  /// これ以上の幅なら2列。
  final double twoColumnWidth;

  const AutoColumns({
    super.key,
    required this.children,
    this.twoColumnWidth = 1000,
  });

  /// 2列に分ける位置(後半の先頭)。真ん中から、カード以外(間隔・見出し)を
  /// 前へ送って、カードの前で切る。
  static int splitIndex(List<Widget> children) {
    var i = (children.length / 2).ceil();
    while (i < children.length &&
        (children[i] is SizedBox || children[i] is Divider)) {
      i++;
    }
    while (i > 0 && i < children.length && children[i - 1] is Text) {
      i--;
    }
    return i.clamp(0, children.length);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        if (c.maxWidth < twoColumnWidth || children.length < 4) {
          return ListView(
              padding: const EdgeInsets.all(16), children: children);
        }
        final split = splitIndex(children);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children.sublist(0, split),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children.sublist(split),
                ),
              ),
            ],
          ),
        );
      });
}
