import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../logic/scout_knowledge.dart';
import '../models/team.dart';
import '../theme/semantic_colors.dart';

/// スカウトの見立てを星で見せる(FM の星。2026-11-25)。
///
/// 総合力・伸びしろは、他のクラブの選手では本当の値ではなく見立ての幅。
/// 数字の幅(「76〜79」)だけだと見立てだと分かりにくかったので、星で
/// 見せる。幅の下の端までを濃く、上の端までを薄く塗る(薄い所が
/// 「まだ見えていない」分)。星は自クラブの先発の平均を3つにした比べ。
class EstimateStars extends StatelessWidget {
  const EstimateStars({
    super.key,
    required this.range,
    required this.reference,
    this.size = 12,
    this.showNumbers = false,
  });

  /// 見立ての幅。null なら見えていない(「?」を出す)。
  final (int, int)? range;

  /// 星3つにあたる総合力(自クラブの先発の平均。[referenceOf])。
  final int reference;
  final double size;

  /// 星の下に幅の数字も出すか。
  final bool showNumbers;

  /// 1つ分の星にあたる総合力の差。
  static const int pointsPerStar = 6;

  /// [value]の星の数(0.5 刻み・0.5〜5)。[reference]で3つ。
  static double starsFor(int value, int reference) {
    final raw = 3 + (value - reference) / pointsPerStar;
    return ((raw * 2).round() / 2).clamp(0.5, 5.0);
  }

  /// 星3つにあたる総合力(自クラブの先発の平均。先発がいなければ全員)。
  static int referenceOf(Team team) {
    final starters = [
      for (final p in team.players)
        if (team.startingXI.contains(p.id)) p.overall
    ];
    final values = starters.isNotEmpty
        ? starters
        : [for (final p in team.players) p.overall];
    if (values.isEmpty) return 60;
    return (values.reduce((a, b) => a + b) / values.length).round();
  }

  /// 読み上げ・説明に使う字(「星3〜4(76〜79)」)。
  static String describe((int, int)? range, int reference) {
    if (range == null) return Tr.pick('まだ見えていない', 'Not scouted yet');
    final lo = starsFor(range.$1, reference);
    final hi = starsFor(range.$2, reference);
    String s(double v) =>
        v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    final stars = lo == hi
        ? Tr.pick('星${s(lo)}', '${s(lo)} stars')
        : Tr.pick('星${s(lo)}〜${s(hi)}', '${s(lo)}-${s(hi)} stars');
    return '$stars (${ScoutKnowledge.label(range)})';
  }

  @override
  Widget build(BuildContext context) {
    final r = range;
    final subtle = SemanticColors.subtleText(context);
    if (r == null) {
      return Tooltip(
        message: describe(null, reference),
        child: Text('?',
            style: TextStyle(
                fontSize: size, fontWeight: FontWeight.bold, color: subtle)),
      );
    }
    final lo = starsFor(r.$1, reference);
    final hi = starsFor(r.$2, reference);
    final solid = SemanticColors.ink(context, Colors.orange.shade800, min: 3);
    final faded = solid.withValues(alpha: 0.45);
    final empty = subtle.withValues(alpha: 0.5);
    Widget slot(int i) {
      Widget icon(IconData d, Color c) => Icon(d, size: size, color: c);
      if (lo >= i + 1) return icon(Icons.star, solid);
      if (lo >= i + 0.5) {
        return Stack(children: [
          icon(hi >= i + 1 ? Icons.star : Icons.star_border,
              hi >= i + 1 ? faded : empty),
          icon(Icons.star_half, solid),
        ]);
      }
      if (hi >= i + 1) return icon(Icons.star, faded);
      if (hi >= i + 0.5) {
        return Stack(children: [
          icon(Icons.star_border, empty),
          icon(Icons.star_half, faded),
        ]);
      }
      return icon(Icons.star_border, empty);
    }

    final stars = Row(
      mainAxisSize: MainAxisSize.min,
      children: [for (var i = 0; i < 5; i++) slot(i)],
    );
    return Semantics(
      label: describe(r, reference),
      child: Tooltip(
        message: describe(r, reference),
        child: showNumbers
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  stars,
                  Text(ScoutKnowledge.label(r),
                      style: TextStyle(
                          fontSize: size * 0.85 < 10 ? 10 : size * 0.85,
                          height: 1.1,
                          color: subtle)),
                ],
              )
            : stars,
      ),
    );
  }
}
