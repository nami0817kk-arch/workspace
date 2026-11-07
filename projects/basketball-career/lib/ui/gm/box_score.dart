import 'package:flutter/material.dart';

import '../../gm/league.dart';
import 'common.dart';
import 'style.dart';

/// 1試合のボックススコア(クォーターごとの点と、自分のチームの選手の数字)。
Future<void> showBoxScore(BuildContext context, GameResult g, int mine) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(g.winner == mine ? '勝ち' : '負け',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: g.winner == mine ? GmColors.good : GmColors.bad)),
            const SizedBox(height: 6),
            _QuarterTable(g: g),
            if (g.box.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('${teamDefs[mine].short}の選手', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              _row(const ['選手', '分', '点', 'リ', 'ア'], head: true),
              for (final b in g.box) _row([b.name, '${b.min}', '${b.pts}', '${b.reb}', '${b.ast}'], pos: b.pos),
            ],
          ]),
        ),
      ),
    );

Widget _row(List<String> cells, {bool head = false, String? pos}) {
  final style = TextStyle(
    fontSize: 13,
    color: head ? GmColors.sub : GmColors.text,
    fontWeight: head ? FontWeight.normal : FontWeight.bold,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      if (pos != null) SizedBox(width: 30, child: Text(pos, style: const TextStyle(fontSize: 11, color: GmColors.sub))) else const SizedBox(width: 30),
      Expanded(child: Text(cells[0], maxLines: 1, overflow: TextOverflow.ellipsis, style: style.copyWith(fontWeight: FontWeight.normal))),
      for (final c in cells.skip(1)) SizedBox(width: 38, child: Text(c, textAlign: TextAlign.right, style: style)),
    ]),
  );
}

class _QuarterTable extends StatelessWidget {
  const _QuarterTable({required this.g});
  final GameResult g;

  @override
  Widget build(BuildContext context) {
    final q = g.quarters;
    Widget line(int team, int pts, List<int> qs) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            TeamBadge(team: team, size: 22),
            const SizedBox(width: 6),
            Expanded(child: Text(teamDefs[team].short, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: g.winner == team ? FontWeight.bold : null))),
            for (final x in qs) SizedBox(width: 34, child: Text('$x', textAlign: TextAlign.right, style: const TextStyle(color: GmColors.sub))),
            SizedBox(
              width: 46,
              child: Text('$pts', textAlign: TextAlign.right, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: g.winner == team ? GmColors.ball : null)),
            ),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: GmColors.panelHi, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Row(children: [
          const Expanded(child: SizedBox()),
          for (final h in ['1Q', '2Q', '3Q', '4Q']) SizedBox(width: 34, child: Text(h, textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: GmColors.sub))),
          const SizedBox(width: 46, child: Text('計', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: GmColors.sub))),
        ]),
        line(g.away, g.awayPts, q.length == 8 ? q.sublist(4) : const []),
        line(g.home, g.homePts, q.length == 8 ? q.sublist(0, 4) : const []),
      ]),
    );
  }
}
