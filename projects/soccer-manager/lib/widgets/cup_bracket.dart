import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../theme/semantic_colors.dart';

/// トーナメント表の1つの組(2クラブ)。
class BracketTie {
  const BracketTie({
    this.teamA,
    this.teamB,
    this.scoreA,
    this.scoreB,
    this.winnerId,
    this.note,
  });

  /// まだ決まっていなければ null(「未定」と出す)。
  final String? teamA;
  final String? teamB;

  /// 得点(2試合制は合計)。まだなら null。
  final int? scoreA;
  final int? scoreB;
  final String? winnerId;

  /// 添え書き(「PK」「延長」「不戦勝」)。
  final String? note;

  bool involves(String id) => teamA == id || teamB == id;
}

/// トーナメントの山の形の表(FM のカップ戦の表)。左から回戦の順に並べ、
/// 次の回戦の組は前の回戦の2組の間に置く。
///
/// 前の2組の勝者がそのまま次の組で当たるとき(山がつながっているとき)だけ
/// 線を引く。国内カップは回戦ごとに抽選し直すので、線は引かない回戦もある
/// (そのときも、組は前の回戦の真ん中にそろえて置く)。
///
/// 回戦が多い大会(1回戦が32組など)は、上の数回戦を [maxTiesInFirstColumn]
/// で切って、そこから先だけを山にする(切った回戦は呼ぶ側が一覧で出す)。
class CupBracket extends StatelessWidget {
  const CupBracket({
    super.key,
    required this.rounds,
    required this.roundLabels,
    required this.nameOf,
    required this.userId,
  });

  /// 回戦ごとの組(1回戦から順に)。まだ組まれていない回戦は「未定」の組で
  /// 埋めて渡す。
  final List<List<BracketTie>> rounds;
  final List<String> roundLabels;
  final String Function(String) nameOf;
  final String userId;

  static const double boxWidth = 176;
  static const double boxHeight = 50;
  static const double gapX = 28;
  static const double slotHeight = 60;
  static const double headerHeight = 22;

  /// 決勝から逆にたどって、[firstCount]組の回戦の後ろに何回戦あるかを数え、
  /// まだ組まれていない回戦の「未定」の組を足す。
  static List<List<BracketTie>> withPlaceholders(
      List<List<BracketTie>> played, int totalRounds) {
    final out = [...played];
    while (out.length < totalRounds) {
      final prev = out.isEmpty ? 1 : out.last.length;
      final n = (prev / 2).ceil().clamp(1, 1 << 10);
      out.add([for (var i = 0; i < n; i++) const BracketTie()]);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    if (rounds.isEmpty) return const SizedBox.shrink();
    final first = rounds.first.length.clamp(1, 1 << 10);
    final height = headerHeight + first * slotHeight;
    final width = rounds.length * (boxWidth + gapX);
    final centers = <List<double>>[
      for (final r in rounds)
        [
          for (var i = 0; i < r.length; i++)
            headerHeight + (i + 0.5) * (first * slotHeight / r.length),
        ],
    ];
    final links = <(Offset, Offset)>[];
    for (var r = 0; r + 1 < rounds.length; r++) {
      final cur = rounds[r], next = rounds[r + 1];
      for (var j = 0; j < next.length; j++) {
        final a = 2 * j, b = 2 * j + 1;
        if (b >= cur.length) continue;
        final wa = cur[a].winnerId, wb = cur[b].winnerId;
        // 山がつながっている(前の2組の勝者が、この組の2クラブ)ときだけ。
        final joined = wa != null &&
            wb != null &&
            next[j].involves(wa) &&
            next[j].involves(wb);
        if (!joined) continue;
        final x0 = r * (boxWidth + gapX) + boxWidth;
        final x1 = (r + 1) * (boxWidth + gapX);
        links
          ..add((Offset(x0, centers[r][a]), Offset(x1, centers[r + 1][j])))
          ..add((Offset(x0, centers[r][b]), Offset(x1, centers[r + 1][j])));
      }
    }
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _LinkPainter(links, scheme.outline),
              ),
            ),
            for (var r = 0; r < rounds.length; r++) ...[
              Positioned(
                left: r * (boxWidth + gapX),
                top: 0,
                width: boxWidth,
                height: headerHeight,
                child: Text(
                  r < roundLabels.length ? roundLabels[r] : '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              for (var i = 0; i < rounds[r].length; i++)
                Positioned(
                  left: r * (boxWidth + gapX),
                  top: centers[r][i] - boxHeight / 2,
                  width: boxWidth,
                  height: boxHeight,
                  child: _TieBox(
                    tie: rounds[r][i],
                    nameOf: nameOf,
                    userId: userId,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LinkPainter extends CustomPainter {
  _LinkPainter(this.links, this.color);

  final List<(Offset, Offset)> links;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (final (a, b) in links) {
      final midX = (a.dx + b.dx) / 2;
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(midX, a.dy)
        ..lineTo(midX, b.dy)
        ..lineTo(b.dx, b.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_LinkPainter old) =>
      old.links.length != links.length || old.color != color;
}

class _TieBox extends StatelessWidget {
  const _TieBox({
    required this.tie,
    required this.nameOf,
    required this.userId,
  });

  final BracketTie tie;
  final String Function(String) nameOf;
  final String userId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mine = tie.involves(userId);
    Widget line(String? id, int? score) {
      final won = id != null && tie.winnerId == id;
      final lost = id != null && tie.winnerId != null && tie.winnerId != id;
      return SizedBox(
        height: 20,
        child: Row(
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  id == null ? Tr.pick('未定', 'TBD') : nameOf(id),
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: id == userId || won
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: id == null || lost
                        ? SemanticColors.subtleText(context)
                        : null,
                  ),
                ),
              ),
            ),
            // 添え書き(PK・延長・不戦勝)は勝った側の行に。
            if (won && tie.note != null)
              Padding(
                padding: const EdgeInsets.only(left: 3, right: 3),
                child: Text(tie.note!,
                    style: TextStyle(
                        fontSize: 9,
                        color: SemanticColors.subtleText(context))),
              ),
            if (score != null)
              Text('$score',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: won ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      );
    }

    final box = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: mine ? scheme.primaryContainer : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: mine ? scheme.primary : scheme.outlineVariant,
            width: mine ? 1.5 : 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [line(tie.teamA, tie.scoreA), line(tie.teamB, tie.scoreB)],
      ),
    );
    if (!mine) return box;
    return Semantics(
      label: Tr.pick('自クラブの組', 'Your tie'),
      child: box,
    );
  }
}
