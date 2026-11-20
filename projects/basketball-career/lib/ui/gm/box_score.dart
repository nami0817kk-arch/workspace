import 'package:flutter/material.dart';

import '../../gm/career.dart';
import '../../gm/league.dart';
import '../../gm/player.dart';
import 'common.dart';
import 'gm_table.dart';
import 'style.dart';

/// 1試合のボックススコア。クォーターごとの点・試合の最優秀選手・チームの比べ・両チームの選手の数字。
Future<void> showBoxScore(BuildContext context, GameResult g, int mine) => showGmSheet<void>(
  context,
  builder: (ctx) => SafeArea(
    child: _BoxScore(g: g, mine: mine),
  ),
);

class _BoxScore extends StatelessWidget {
  const _BoxScore({required this.g, required this.mine});
  final GameResult g;
  final int mine;

  /// 横に2列(左: 点・最優秀・チームの比べ、右: 流れ・見立て・終盤)、その下に両チームの選手の表(2026-11-15)。
  @override
  Widget build(BuildContext context) {
    final opp = g.opponentOf(mine);
    final all = [for (final b in g.box) (b, mine), for (final b in g.oppBox) (b, opp)];
    final best = all.isEmpty ? null : all.reduce((a, b) => a.$1.gameScore >= b.$1.gameScore ? a : b);
    // 前の版の保存の試合には、シュートの内訳などが無い
    final detail = g.box.any((b) => b.fga > 0);
    const gap = SizedBox(height: 8);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      g.winner == mine ? '勝ち' : '負け',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: g.winner == mine ? GmColors.good : GmColors.bad),
                    ),
                    const SizedBox(height: 4),
                    _QuarterTable(g: g),
                    if (best != null && detail) ...[gap, _bestCard(best.$1, best.$2)],
                    if (detail && g.oppBox.isNotEmpty) ...[gap, _TeamCompare(mine: mine, opp: opp, a: g.box, b: g.oppBox)],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    if (g.flow.length >= 12) GameFlowCard(g: g, mine: mine),
                    if (g.hasChance) ...[gap, _ChanceCard(g: g, mine: mine)],
                    if (g.plays.isNotEmpty) ...[gap, _PlaysCard(g: g)],
                  ],
                ),
              ),
            ],
          ),
          if (g.box.isNotEmpty) ...[
            gap,
            BoxTable(team: mine, lines: g.box, detail: detail),
            if (g.oppBox.isNotEmpty) ...[gap, BoxTable(team: opp, lines: g.oppBox, detail: detail)],
            if (detail)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('FG・3P・FT は成功-試投、奪: スティール、ブ: ブロック、失: ミス、±: 出ているあいだの点差', style: TextStyle(fontSize: 10, color: GmColors.sub, height: 1.4)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _bestCard(BoxLine b, int team) => Container(
    padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
    decoration: BoxDecoration(
      color: GmColors.gold.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: GmColors.gold.withValues(alpha: 0.6)),
    ),
    child: Row(
      children: [
        const Icon(Icons.star_rounded, color: GmColors.gold, size: 18),
        const SizedBox(width: 6),
        TeamBadge(team: team, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '試合の最優秀選手',
                style: TextStyle(fontSize: 11, color: GmColors.gold, fontWeight: FontWeight.bold),
              ),
              fitText(b.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                '${b.pts}点 ${b.reb}リ ${b.ast}ア・FG ${b.fgm}/${b.fga}${b.tpa > 0 ? '・3P ${b.tpm}/${b.tpa}' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: GmColors.sub),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// 試合前の見立て(両チームの強さと勝つ見込み)と、結果がそれどおりだったか。
class _ChanceCard extends StatelessWidget {
  const _ChanceCard({required this.g, required this.mine});
  final GameResult g;
  final int mine;

  @override
  Widget build(BuildContext context) {
    final opp = g.opponentOf(mine);
    final p = g.chanceOf(mine);
    final won = g.winner == mine;
    final (verdict, color) = switch ((won, p)) {
      (true, < 0.4) => ('番狂わせの勝ち', GmColors.gold),
      (false, > 0.6) => ('取りこぼし', GmColors.bad),
      (true, _) => ('見込みどおりの勝ち', GmColors.good),
      _ => ('見込みどおりの負け', GmColors.sub),
    };
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: GmColors.panelHi, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                '試合前の見立て',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: GmColors.sub),
              ),
              const Spacer(),
              Text(
                verdict,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  '強さ ${g.strOf(mine).toStringAsFixed(1)}${g.home == mine ? '(ホーム)' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: GmColors.ball),
                ),
              ),
              Text('勝つ見込み ${(p * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
              Expanded(
                child: Text(
                  '${g.home == opp ? '(ホーム)' : ''}強さ ${g.strOf(opp).toStringAsFixed(1)}',
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  Expanded(
                    flex: (p * 1000).round().clamp(1, 999),
                    child: Container(color: GmColors.ball),
                  ),
                  Expanded(
                    flex: 1000 - (p * 1000).round().clamp(1, 999),
                    child: Container(color: GmColors.line),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '強さ(けが人を除いた力・ポジション・出場時間・方針・相性・HC、ホーム+1)の差が、シュートの入りやすさとミスに効く。'
            '試合は1回の攻めずつ、コートの5人と打つ人の能力で進め、数字はそこで起きたことをそのまま数えている。',
            style: TextStyle(fontSize: 10, color: GmColors.sub, height: 1.4),
          ),
        ],
      ),
    );
  }
}

String _pct(int m, int a) => a == 0 ? '-' : '${(m * 100 / a).toStringAsFixed(1)}%';

/// 2チームの数字を並べて比べる(良いほうを緑に)。
class _TeamCompare extends StatelessWidget {
  const _TeamCompare({required this.mine, required this.opp, required this.a, required this.b});
  final int mine, opp;
  final List<BoxLine> a, b;

  @override
  Widget build(BuildContext context) {
    int sum(List<BoxLine> l, int Function(BoxLine) f) => l.fold(0, (n, x) => n + f(x));
    double rate(List<BoxLine> l, int Function(BoxLine) m, int Function(BoxLine) at) => sum(l, at) == 0 ? 0 : sum(l, m) / sum(l, at);
    final rows = <(String, String, String, double, double)>[
      for (final (label, m, at) in <(String, int Function(BoxLine), int Function(BoxLine))>[('FG', (x) => x.fgm, (x) => x.fga), ('3P', (x) => x.tpm, (x) => x.tpa), ('FT', (x) => x.ftm, (x) => x.fta)])
        (label, _pct(sum(a, m), sum(a, at)), _pct(sum(b, m), sum(b, at)), rate(a, m, at), rate(b, m, at)),
      for (final (label, f, lowGood) in <(String, int Function(BoxLine), bool)>[
        ('リバウンド', (x) => x.reb, false),
        ('アシスト', (x) => x.ast, false),
        ('スティール', (x) => x.stl, false),
        ('ブロック', (x) => x.blk, false),
        ('ミス', (x) => x.tov, true),
      ])
        (label, '${sum(a, f)}', '${sum(b, f)}', (lowGood ? -1 : 1) * sum(a, f).toDouble(), (lowGood ? -1 : 1) * sum(b, f).toDouble()),
    ];
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: GmColors.panelHi, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: fitText(teamDefs[mine].short, style: const TextStyle(fontWeight: FontWeight.bold, color: GmColors.ball),
                ),
              ),
              const Text('チームの数字', style: TextStyle(fontSize: 11, color: GmColors.sub)),
              Expanded(
                child: fitText(teamDefs[opp].short, textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final (label, x, y, vx, vy) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      x,
                      style: TextStyle(fontWeight: vx > vy ? FontWeight.bold : null, color: vx > vy ? GmColors.good : null),
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, color: GmColors.sub),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      y,
                      textAlign: TextAlign.right,
                      style: TextStyle(fontWeight: vy > vx ? FontWeight.bold : null, color: vy > vx ? GmColors.good : null),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 選手ごとの数字の表(チームごと)。
class BoxTable extends StatelessWidget {
  const BoxTable({super.key, required this.team, required this.lines, this.detail = true});
  final int team;
  final List<BoxLine> lines;

  /// シュートの内訳などを出すか。
  final bool detail;

  @override
  Widget build(BuildContext context) {
    final top = lines.isEmpty ? 0 : lines.map((b) => b.pts).reduce((a, b) => a > b ? a : b);
    GmCol n(String l, [double w = 34]) => GmCol(l, width: w, align: TextAlign.right);
    final cols = [
      const GmCol('位', width: 28),
      const GmCol('選手', flex: 1, align: TextAlign.left),
      n('分'),
      n('点'),
      n('リ'),
      n('ア'),
      if (detail) ...[n('FG', 50), n('FG%', 46), n('3P', 46), n('FT', 46), n('奪', 30), n('ブ', 30), n('失', 30), n('±', 38)],
    ];
    return GmTable(
      title: '${teamDefs[team].city}・${teamDefs[team].nick}',
      rowHeight: 24,
      cols: cols,
      rows: [
        for (final b in lines)
          GmRow([
            Text(b.pos, style: const TextStyle(fontSize: 10, color: GmColors.sub)),
            fitText(b.name, ),
            numCell('${b.min}', color: GmColors.sub),
            numCell('${b.pts}', bold: true, color: b.pts == top ? GmColors.ball : null),
            numCell('${b.reb}'),
            numCell('${b.ast}'),
            if (detail) ...[
              numCell('${b.fgm}-${b.fga}'),
              numCell(_pct(b.fgm, b.fga), color: GmColors.sub),
              numCell('${b.tpm}-${b.tpa}'),
              numCell('${b.ftm}-${b.fta}'),
              numCell('${b.stl}'),
              numCell('${b.blk}'),
              numCell('${b.tov}'),
              numCell(
                b.pm > 0 ? '+${b.pm}' : '${b.pm}',
                color: b.pm > 0
                    ? GmColors.good
                    : b.pm < 0
                    ? GmColors.bad
                    : null,
              ),
            ],
          ], dim: b.min == 0),
      ],
    );
  }
}

/// 選手の最近の試合(この区切りの試合のうち、出たもの。新しい順に5つまで)。
class RecentGames extends StatelessWidget {
  const RecentGames({super.key, required this.car, required this.p});
  final Career car;
  final Player p;

  @override
  Widget build(BuildContext context) {
    final rows = <(BoxLine, int)>[];
    for (final g in car.lastGames.reversed) {
      if (rows.length >= 5) break;
      for (final b in g.box) {
        if (b.name == p.name) rows.add((b, g.opponentOf(car.mine)));
      }
      for (final b in g.oppBox) {
        if (b.name == p.name) rows.add((b, car.mine));
      }
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(color: GmColors.panelHi, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('最近の試合', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          for (final (b, opp) in rows.take(5))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  TeamBadge(team: opp, size: 18),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 70,
                    child: Text('vs ${teamDefs[opp].short}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                  ),
                  Expanded(
                    child: Text(
                      '${b.pts}点 ${b.reb}リ ${b.ast}ア${b.fga > 0 ? '・FG ${b.fgm}/${b.fga}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text('${b.min}分', style: const TextStyle(fontSize: 12, color: GmColors.sub)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _QuarterTable extends StatelessWidget {
  const _QuarterTable({required this.g});
  final GameResult g;

  @override
  Widget build(BuildContext context) {
    final q = g.quarters;
    final ot = g.overtime;
    final n = g.overtimes;
    Widget line(int team, int pts, List<int> qs) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          TeamBadge(team: team, size: 22),
          const SizedBox(width: 6),
          Expanded(
            child: fitText(teamDefs[team].short, style: TextStyle(fontWeight: g.winner == team ? FontWeight.bold : null),
            ),
          ),
          for (final x in qs)
            SizedBox(
              width: 34,
              child: Text(
                '$x',
                textAlign: TextAlign.right,
                style: const TextStyle(color: GmColors.sub),
              ),
            ),
          SizedBox(
            width: 46,
            child: Text(
              '$pts',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: g.winner == team ? GmColors.ball : null),
            ),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: GmColors.panelHi, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(child: SizedBox()),
              for (final h in ['1Q', '2Q', '3Q', '4Q', for (var k = 0; k < n; k++) k == 0 ? '延長' : '延$k'])
                SizedBox(
                  width: 34,
                  child: Text(
                    h,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 11, color: GmColors.sub),
                  ),
                ),
              const SizedBox(
                width: 46,
                child: Text(
                  '計',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 11, color: GmColors.sub),
                ),
              ),
            ],
          ),
          line(g.away, g.awayPts, q.length == 8 ? [...q.sublist(4), for (var k = 0; k < n; k++) ot[k * 2 + 1]] : const []),
          line(g.home, g.homePts, q.length == 8 ? [...q.sublist(0, 4), for (var k = 0; k < n; k++) ot[k * 2]] : const []),
        ],
      ),
    );
  }
}

/// 試合の流れ(1分ごとの点差。上が自分のリード)。リードの入れ替わりと最大リードも出す。
class GameFlowCard extends StatelessWidget {
  const GameFlowCard({super.key, required this.g, required this.mine});
  final GameResult g;
  final int mine;

  @override
  Widget build(BuildContext context) {
    final sign = g.home == mine ? 1 : -1;
    final f = [0, for (final x in g.flow) x * sign];
    final myMax = f.reduce((a, b) => a > b ? a : b);
    final oppMax = -f.reduce((a, b) => a < b ? a : b);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: GmColors.panelHi, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                '試合の流れ',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: GmColors.sub),
              ),
              const Spacer(),
              Text('リードの入れ替わり ${g.leadChanges}回', style: const TextStyle(fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 64,
            child: CustomPaint(painter: _FlowPainter(f), size: Size.infinite),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '${teamDefs[mine].short} 最大${myMax > 0 ? '$myMax点' : 'リードなし'}',
                style: const TextStyle(fontSize: 11, color: GmColors.ball, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text('${teamDefs[g.opponentOf(mine)].short} 最大${oppMax > 0 ? '$oppMax点' : 'リードなし'}', style: const TextStyle(fontSize: 11, color: GmColors.sub)),
            ],
          ),
        ],
      ),
    );
  }
}

class _FlowPainter extends CustomPainter {
  _FlowPainter(this.f);
  final List<int> f;

  @override
  void paint(Canvas canvas, Size size) {
    final maxAbs = f.fold(8, (m, x) => x.abs() > m ? x.abs() : m).toDouble();
    final mid = size.height / 2;
    double x(int i) => size.width * i / (f.length - 1);
    double y(int v) => mid - v / maxAbs * (mid - 4);
    final grid = Paint()
      ..color = GmColors.line
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, mid), Offset(size.width, mid), grid);
    // クォーターの区切り(12分ごと)
    for (var q = 12; q < f.length - 1; q += 12) {
      canvas.drawLine(Offset(x(q), 0), Offset(x(q), size.height), grid..color = GmColors.line.withValues(alpha: 0.5));
    }
    Path area(bool up) {
      final p = Path()..moveTo(0, mid);
      for (var i = 0; i < f.length; i++) {
        final v = up ? (f[i] > 0 ? f[i] : 0) : (f[i] < 0 ? f[i] : 0);
        p.lineTo(x(i), y(v));
      }
      return p
        ..lineTo(size.width, mid)
        ..close();
    }

    canvas.drawPath(area(true), Paint()..color = GmColors.ball.withValues(alpha: 0.55));
    canvas.drawPath(area(false), Paint()..color = GmColors.sub.withValues(alpha: 0.45));
  }

  @override
  bool shouldRepaint(covariant _FlowPainter old) => old.f != f;
}

/// 見せ場(終盤の得点と逆転)。
class _PlaysCard extends StatelessWidget {
  const _PlaysCard({required this.g});
  final GameResult g;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: GmColors.panelHi, borderRadius: BorderRadius.circular(12)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '終盤の流れ',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: GmColors.sub),
        ),
        const SizedBox(height: 4),
        for (final p in g.plays)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1.5),
            child: Text(
              p,
              style: TextStyle(fontSize: 12, fontFeatures: const [FontFeature.tabularFigures()], fontWeight: p.contains('逆転') ? FontWeight.bold : null, color: p.contains('逆転') ? GmColors.gold : null),
            ),
          ),
      ],
    ),
  );
}
