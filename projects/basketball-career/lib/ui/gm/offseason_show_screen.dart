import 'package:flutter/material.dart';

import '../../gm/career.dart';
import '../../gm/offseason_show.dart';
import '../../gm/player.dart';
import '../gm_controller.dart';
import 'common.dart';
import 'style.dart';

/// 自由契約を1日進め、その日の動きを見せる。
Future<void> nextFaDayWithReport(BuildContext context, GmController c) {
  final car = c.career!;
  final snap = faSnapshot(car);
  c.nextFaDay();
  if (car.faDay == snap.day) return Future.value();
  return showFaDayReport(Navigator.of(context), c, faDayReport(car, snap));
}

String _pct(double v) => '${(v * 100).round()}%';

/// 自由契約の1日の発表。自分の申し込みの結果・その日の契約・まだ決まっていない大物。
Future<void> showFaDayReport(NavigatorState nav, GmController c, FaDayReport r) {
  final car = c.career!;
  Widget moveLine(FaMove m) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1.5),
        child: Row(children: [
          TeamBadge(team: m.team, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Text('${m.name}(OVR${shown(m.ovr)})', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: m.team == car.mine ? FontWeight.bold : null, color: m.team == car.mine ? GmColors.good : null)),
          ),
          Text('${m.years}年 ${money(m.salary)}', style: const TextStyle(fontSize: 12, color: GmColors.sub)),
        ]),
      );

  Widget bidLine(BidResult b) {
    final (IconData icon, Color color, String text) = switch (b.outcome) {
      BidOutcome.signed => (Icons.check_circle_rounded, GmColors.good, '${b.name}が申し込みを受けた(${b.move!.years}年 ${money(b.move!.salary)})'),
      BidOutcome.lost => (Icons.cancel_rounded, GmColors.bad, '${b.name}は${car.teams[b.move!.team].def.short}を選んだ(${b.move!.years}年 ${money(b.move!.salary)})'),
      BidOutcome.pending => (
          Icons.hourglass_top_rounded,
          GmColors.gold,
          '${b.name}はまだ迷っている。見込み ${_pct(b.chanceBefore)} → ${_pct(b.chanceAfter)}'
              '${b.rivalsAfter > b.rivalsBefore ? '(新しく${b.rivalsAfter - b.rivalsBefore}チームが申し込んだ)' : ''}'
        ),
      BidOutcome.dropped => (Icons.remove_circle_outline_rounded, GmColors.sub, '${b.name}への申し込みは取り消しになった(人数か年俸の枠が足りない)'),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(height: 1.35))),
      ]),
    );
  }

  final quiet = r.mine.isEmpty && r.signed.isEmpty && !r.newSheet;
  return showDialog<void>(
    context: nav.context,
    builder: (ctx) => AlertDialog(
      title: Text('自由契約 ${r.day}日目の動き'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            if (r.newSheet)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: GmColors.panelHi, borderRadius: BorderRadius.circular(8), border: Border.all(color: GmColors.gold)),
                child: Text('${car.sheetPlayer?.name ?? '自分の選手'}にオファーシートが届いた。契約の画面で、残すか見送るかを決める。',
                    style: const TextStyle(color: GmColors.gold, fontWeight: FontWeight.bold, height: 1.4)),
              ),
            if (r.mine.isNotEmpty) ...[
              const Text('自分の申し込み', style: TextStyle(fontWeight: FontWeight.bold, color: GmColors.ball)),
              for (final b in r.mine) bidLine(b),
              const SizedBox(height: 8),
            ],
            if (r.signed.isNotEmpty) ...[
              Text('この日の契約(${r.signed.length}件)', style: const TextStyle(fontWeight: FontWeight.bold, color: GmColors.ball)),
              for (final m in r.signed.take(8)) moveLine(m),
              if (r.signed.length > 8) Text('ほか${r.signed.length - 8}件', style: const TextStyle(color: GmColors.sub, fontSize: 12)),
              const SizedBox(height: 8),
            ],
            if (quiet) const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('この日は大きな動きがなかった。', style: TextStyle(color: GmColors.sub))),
            if (r.open.isNotEmpty && r.daysLeft > 0) ...[
              const Text('まだ決まっていない大物', style: TextStyle(fontWeight: FontWeight.bold, color: GmColors.ball)),
              for (final (p, n) in r.open)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1.5),
                  child: Row(children: [
                    Expanded(child: Text('${p.name}(${p.pos.short}・OVR${shown(p.ovr)})', maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text(n == 0 ? '申し込みなし' : '$nチームが申し込み', style: TextStyle(fontSize: 12, color: n > 0 ? GmColors.gold : GmColors.sub)),
                  ]),
                ),
              const SizedBox(height: 8),
            ],
            Text(r.daysLeft > 0 ? 'あと${r.daysLeft}日。日が進むほど、迷っている選手も決めていく。' : '自由契約の日程は終わった。',
                style: const TextStyle(fontSize: 12, color: GmColors.sub)),
          ]),
        ),
      ),
      actions: [FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('続ける'))],
    ),
  );
}

/// オフを終えたときのまとめ。入った・出た選手、強さの順位の変化、リーグの大きな移籍。
class OffSummaryScreen extends StatelessWidget {
  const OffSummaryScreen({super.key, required this.c});
  final GmController c;

  @override
  Widget build(BuildContext context) {
    final car = c.career!;
    final s = offSummary(car);
    Widget changeLine(OffChange x, {required bool arrived}) {
      final p = x.p;
      return Container(
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: GmColors.panel, borderRadius: BorderRadius.circular(10), border: Border.all(color: GmColors.line)),
        child: Row(children: [
          Icon(arrived ? Icons.login_rounded : Icons.logout_rounded, size: 20, color: arrived ? GmColors.good : GmColors.bad),
          const SizedBox(width: 8),
          Expanded(
            child: Text('${p.name}(${p.pos.short}・${p.age}歳・OVR${shown(p.ovr)})',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 6),
          Text(x.how, style: const TextStyle(fontSize: 12, color: GmColors.sub)),
        ]),
      );
    }

    final up = s.rankBefore < 0 ? 0 : s.rankBefore - s.rankAfter;
    return Scaffold(
      appBar: AppBar(title: Text('${car.season}年目に向けたオフのまとめ'), automaticallyImplyLeading: false),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 左: 自分のチームの強さと出入り
                Expanded(
                  child: ListView(padding: const EdgeInsets.fromLTRB(14, 8, 4, 16), children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    const Icon(Icons.leaderboard_rounded, color: GmColors.gold),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('チームの強さ(リーグの順位)', style: TextStyle(color: GmColors.sub, fontSize: 12)),
                        Text(
                          s.rankBefore < 0 ? '${s.rankAfter + 1}位' : 'オフの前 ${s.rankBefore + 1}位 → いま ${s.rankAfter + 1}位',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ]),
                    ),
                    if (s.rankBefore >= 0)
                      Text(
                        up > 0 ? '$upつ上がった' : up < 0 ? '${-up}つ下がった' : '変わらず',
                        style: TextStyle(fontWeight: FontWeight.bold, color: up > 0 ? GmColors.good : up < 0 ? GmColors.bad : GmColors.sub),
                      ),
                  ]),
                ),
              ),
              SectionTitle('入った選手(${s.arrived.length}人)'),
              if (s.arrived.isEmpty) const Text('いない', style: TextStyle(color: GmColors.sub)),
              for (final x in s.arrived) changeLine(x, arrived: true),
              SectionTitle('出た選手(${s.left.length}人)'),
              if (s.left.isEmpty) const Text('いない', style: TextStyle(color: GmColors.sub)),
              for (final x in s.left) changeLine(x, arrived: false),
                  ]),
                ),
                // 右: リーグ全体のオフの成長と、来季の強さ予想・大きな移籍(2026-11-16)
                Expanded(
                  child: ListView(padding: const EdgeInsets.fromLTRB(4, 0, 14, 16), children: [
              if (car.leagueGrowth.isNotEmpty) ...[
                const SectionTitle('リーグのオフの成長'),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: _GrowthList(car: car, title: '大きく伸びた', list: car.leagueRisers(), up: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _GrowthList(car: car, title: '大きく落ちた', list: car.leagueFallers(), up: false)),
                ]),
              ],
              const SectionTitle('来季の強さ予想'),
              _PowerRanking(car: car),
              if (s.bigMoves.isNotEmpty) ...[
                const SectionTitle('リーグの大きな移籍'),
                for (final m in s.bigMoves)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      TeamBadge(team: m.team, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${m.name}(OVR${shown(m.ovr)})が${car.teams[m.team].def.short}へ',
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: m.team == car.mine ? GmColors.good : null)),
                      ),
                      Text('${m.years}年 ${money(m.salary)}', style: const TextStyle(fontSize: 12, color: GmColors.sub)),
                    ]),
                  ),
              ],
                  ]),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('シーズン前へ')),
            ),
          ),
        ]),
      ),
    );
  }
}

/// オフに大きく伸びた(落ちた)選手の一覧。自分の選手は橙。
class _GrowthList extends StatelessWidget {
  const _GrowthList({required this.car, required this.title, required this.list, required this.up});
  final Career car;
  final String title;
  final List<GrowthLine> list;
  final bool up;

  @override
  Widget build(BuildContext context) {
    final color = up ? GmColors.good : GmColors.bad;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(color: GmColors.panel, borderRadius: BorderRadius.circular(8), border: Border.all(color: GmColors.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        if (list.isEmpty) const Text('いない', style: TextStyle(fontSize: 12, color: GmColors.sub)),
        for (final (i, g) in list.indexed)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 300 + 80 * i),
            builder: (context, t, child) {
              final k = ((t * (300 + 80 * i) - 80 * i) / 300).clamp(0.0, 1.0);
              return Opacity(opacity: k, child: child);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                if (g.team >= 0) TeamBadge(team: g.team, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${g.name}(${g.age}歳)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, fontWeight: g.team == car.mine ? FontWeight.bold : null, color: g.team == car.mine ? GmColors.ball : null),
                  ),
                ),
                Text('${shown(g.before)}→${shown(g.after)}', style: const TextStyle(fontSize: 11, color: GmColors.sub)),
                const SizedBox(width: 6),
                SizedBox(
                  width: 30,
                  child: Text(
                    '${up ? '+' : ''}${shown(g.after) - shown(g.before)}',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                  ),
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}

/// 来季の強さ予想。上位10チームと、自分のチーム(10位より下なら最後に)。
class _PowerRanking extends StatelessWidget {
  const _PowerRanking({required this.car});
  final Career car;

  @override
  Widget build(BuildContext context) {
    final order = car.powerRanking();
    final myRank = order.indexOf(car.mine);
    final shownRows = [for (var i = 0; i < 10 && i < order.length; i++) i, if (myRank >= 10) myRank];
    final top = car.teams[order.first].strength;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(color: GmColors.panel, borderRadius: BorderRadius.circular(8), border: Border.all(color: GmColors.line)),
      child: Column(children: [
        for (final i in shownRows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              SizedBox(width: 26, child: Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.bold, color: i < 3 ? GmColors.gold : GmColors.sub))),
              TeamBadge(team: order[i], size: 18),
              const SizedBox(width: 6),
              SizedBox(
                width: 190,
                child: Text(
                  car.teams[order[i]].name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: order[i] == car.mine ? FontWeight.bold : null, color: order[i] == car.mine ? GmColors.ball : null),
                ),
              ),
              // 1位との差を帯で
              Expanded(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: (1 - (top - car.teams[order[i]].strength) / 12).clamp(0.05, 1.0)),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => LinearProgressIndicator(
                    value: v,
                    minHeight: 6,
                    color: order[i] == car.mine ? GmColors.ball : GmColors.sub,
                    backgroundColor: GmColors.line,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}
