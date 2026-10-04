import 'package:flutter/material.dart';

/// 総合力の数字。
///
/// **一覧でいちばん見る数字。** 素の文字で置いていた頃は、右端に小さな数字が
/// あるだけで、選手を見比べるときに目が止まらなかった。強さで色が変わる
/// 札にして、桁の揃う等幅の数字で描く。
class OverallBadge extends StatelessWidget {
  final int overall;

  const OverallBadge({super.key, required this.overall});

  /// 強さの段。5部から1部まで通して使うので、刻みは広めに取る。
  static Color colorFor(BuildContext context, int overall) => switch (overall) {
        >= 75 => const Color(0xFF1B7F4B),
        >= 60 => const Color(0xFF2F6FB0),
        >= 45 => const Color(0xFF8A6A1F),
        _ => Theme.of(context).colorScheme.onSurfaceVariant,
      };

  @override
  Widget build(BuildContext context) {
    final color = colorFor(context, overall);
    return Container(
      // **幅を詰める。** 大きくすると、そのぶん本文の幅が減って
      // 「役割 スイーパーキーパー」が折り返した。札は小さくてよい。
      width: 33,
      height: 27,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(
        '$overall',
        style: TextStyle(
          fontFamily: 'NotoSansJP',
          fontSize: 15,
          fontWeight: FontWeight.w800,
          height: 1.0,
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// 「総合 78」のような小さな札。
///
/// 「総合78 潜在82 移籍金1602万」と1行につなげていた頃は、どこが数字で
/// どこが見出しなのか目で切り分ける必要があった。札に分けると、数字だけを
/// 拾って読める。
class StatChip extends StatelessWidget {
  final String label;
  final String value;

  /// 指定すると、その色で描く。省くと控えめな色になる。
  final Color? color;

  const StatChip({
    super.key,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = color ?? scheme.onSurfaceVariant;
    // **入らないときは縮める。** 文字サイズを上げる設定にすると、札の中身が
    // 親の幅を超えてはみ出した(CIのアクセシビリティ検査で落ちた)。
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        // **小さく作る。** 大きいと3つ並べたときに折り返して、1行ぶん
        // 行が伸びる（移籍市場で実際に縦に重なった）。
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 9.5, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(width: 3),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'NotoSansJP',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.1,
                color: tint,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
