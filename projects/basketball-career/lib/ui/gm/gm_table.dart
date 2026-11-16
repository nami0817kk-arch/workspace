import 'package:flutter/material.dart';

import 'style.dart';

/// 表の列。[width] があれば固定の幅、なければ [flex] で残りを分ける。
class GmCol {
  const GmCol(this.label, {this.width, this.flex = 1, this.align = TextAlign.center, this.onTap, this.sorted = false});
  final String label;
  final double? width;
  final int flex;
  final TextAlign align;

  /// 見出しを押したとき(並べ替えなど)。
  final VoidCallback? onTap;

  /// この列で並んでいるか(見出しに印)。
  final bool sorted;
}

/// 表の1行。[cells] は列と同じ数。
class GmRow {
  const GmRow(this.cells, {this.onTap, this.onLongPress, this.highlight = false, this.dim = false, this.divider = false});
  final List<Widget> cells;
  final VoidCallback? onTap;

  /// 長押し(選手のカードを開くなど)。
  final VoidCallback? onLongPress;

  /// 自分のチーム・選んでいる行(橙の下地)。
  final bool highlight;

  /// 薄く見せる(けが人・試合に出ない選手など)。
  final bool dim;

  /// この行の上に太めの区切り(先発と控えの間など)。
  final bool divider;
}

/// 詰めた表(2026-11-14、ユーザー「もう少し文字小さくても良いので、質を上げる」)。
/// 見出しは小さく、行は細く、1行おきに少し色を変える。
class GmTable extends StatelessWidget {
  const GmTable({super.key, required this.cols, required this.rows, this.rowHeight = 28, this.title, this.trailing});
  final List<GmCol> cols;
  final List<GmRow> rows;
  final double rowHeight;
  final String? title;
  final Widget? trailing;

  Widget _cell(GmCol c, Widget child) {
    final aligned = Align(
      alignment: switch (c.align) {
        TextAlign.left || TextAlign.start => Alignment.centerLeft,
        TextAlign.right || TextAlign.end => Alignment.centerRight,
        _ => Alignment.center,
      },
      child: child,
    );
    final padded = Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: aligned);
    return c.width != null ? SizedBox(width: c.width, child: padded) : Expanded(flex: c.flex, child: padded);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: GmColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: GmColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Container(
              padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
              color: GmColors.panelHi,
              child: Row(
                children: [
                  Expanded(
                    child: Text(title!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          Container(
            height: 22,
            color: GmColors.bg.withValues(alpha: 0.6),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                for (final c in cols)
                  _cell(
                    c,
                    InkWell(
                      onTap: c.onTap,
                      child: Text(
                        c.sorted ? '${c.label}▼' : c.label,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: c.sorted ? GmColors.ball : GmColors.sub, letterSpacing: 0.2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (final (i, r) in rows.indexed)
            // 選んだ行の下地は、すっと色が移る(2026-11-15)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              color: r.highlight
                  ? GmColors.ball.withValues(alpha: 0.16)
                  : i.isOdd
                  ? GmColors.panelHi.withValues(alpha: 0.45)
                  : GmColors.panel.withValues(alpha: 0),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: r.onTap,
                  onLongPress: r.onLongPress,
                  child: Container(
                    height: rowHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: r.divider
                        ? const BoxDecoration(
                            border: Border(top: BorderSide(color: GmColors.line, width: 1.5)),
                          )
                        : null,
                    child: Opacity(
                      opacity: r.dim ? 0.5 : 1,
                      child: DefaultTextStyle.merge(
                        style: const TextStyle(fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]),
                        child: Row(children: [for (var k = 0; k < cols.length; k++) _cell(cols[k], r.cells[k])]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 表の行に収まる小さなボタン(高さ22)。[filled] で橙の塗り。
Widget miniButton(String label, VoidCallback? onPressed, {bool filled = false}) {
  const pad = EdgeInsets.symmetric(horizontal: 8);
  const size = Size(0, 22);
  const text = TextStyle(fontFamily: 'NotoSansJP', fontSize: 11, fontWeight: FontWeight.bold);
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(6));
  return filled
      ? FilledButton(
          style: FilledButton.styleFrom(minimumSize: size, padding: pad, textStyle: text, shape: shape, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          onPressed: onPressed,
          child: Text(label),
        )
      : OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: size, padding: pad, textStyle: text, shape: shape, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          onPressed: onPressed,
          child: Text(label),
        );
}

/// 表の中の数字(色つき)。
Widget numCell(String s, {Color? color, bool bold = false}) => Text(
  s,
  maxLines: 1,
  style: TextStyle(color: color, fontWeight: bold ? FontWeight.bold : null),
);
