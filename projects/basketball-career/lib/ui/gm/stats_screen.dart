import 'package:flutter/material.dart';

import '../../gm/player.dart';
import '../gm_controller.dart';
import '../layout.dart';
import 'common.dart';
import 'player_card.dart';
import 'style.dart';

/// 列(見出し・値・見せ方)。
typedef _Col = (String, double Function(Stats), String Function(Stats));

String _f1(double v) => v.toStringAsFixed(1);
String _pct(double v) => (v * 100).toStringAsFixed(1);

final List<_Col> _cols = [
  ('試合', (s) => s.gp.toDouble(), (s) => '${s.gp}'),
  ('分', (s) => s.mpg, (s) => _f1(s.mpg)),
  ('点', (s) => s.ppg, (s) => _f1(s.ppg)),
  ('リ', (s) => s.rpg, (s) => _f1(s.rpg)),
  ('ア', (s) => s.apg, (s) => _f1(s.apg)),
  ('FG%', (s) => s.fgPct, (s) => s.fga == 0 ? '-' : _pct(s.fgPct)),
  ('3P%', (s) => s.tpPct, (s) => s.tpa == 0 ? '-' : _pct(s.tpPct)),
  ('FT%', (s) => s.ftPct, (s) => s.fta == 0 ? '-' : _pct(s.ftPct)),
  ('奪', (s) => s.spg, (s) => _f1(s.spg)),
  ('ブ', (s) => s.bpg, (s) => _f1(s.bpg)),
  ('失', (s) => s.tpg, (s) => _f1(s.tpg)),
];

/// チームの成績。選手ごとの1試合あたりの数字を並べ、見出しを押すとその数字で並べ替える。
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, required this.c});
  final GmController c;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int _sort = 2;

  @override
  Widget build(BuildContext context) {
    final car = widget.c.career!;
    // シーズン前とオフは、今季の成績がまだ前のシーズンのもの
    final players = [...car.me.roster]..sort((a, b) => _cols[_sort].$2(b.stats).compareTo(_cols[_sort].$2(a.stats)));
    final total = Stats();
    for (final p in players) {
      final s = p.stats;
      total
        ..pts += s.pts
        ..reb += s.reb
        ..ast += s.ast
        ..fgm += s.fgm
        ..fga += s.fga
        ..tpm += s.tpm
        ..tpa += s.tpa
        ..ftm += s.ftm
        ..fta += s.fta
        ..stl += s.stl
        ..blk += s.blk
        ..tov += s.tov;
    }
    final games = car.me.wins + car.me.losses;
    total.gp = games;
    const headStyle = TextStyle(fontSize: 11, color: GmColors.sub);
    const style = TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFeatures: [FontFeature.tabularFigures()]);
    double w(int i) => i >= 5 && i <= 7 ? 48 : 40;
    return Scaffold(
      appBar: AppBar(title: Text(car.seasonStarted ? 'チームの成績(今季)' : 'チームの成績(昨季)')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxWidth(context, phone: 620)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
              children: [
                const Text('1試合あたり。数字は横に送るとシュート・スティールなども見られる。見出しを押すと、その数字の順に並ぶ。選手を押すとカードが開く。', style: TextStyle(fontSize: 12, color: GmColors.sub)),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(
                        width: 120,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const SizedBox(height: 30, child: Align(alignment: Alignment.centerLeft, child: Text('選手', style: headStyle))),
                          for (final p in players)
                            InkWell(
                              onTap: () => showPlayerCard(context, car, p, car.mine),
                              child: SizedBox(
                                height: 30,
                                child: Row(children: [
                                  SizedBox(width: 26, child: Text(p.pos.short, style: const TextStyle(fontSize: 10, color: GmColors.sub))),
                                  Expanded(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                                ]),
                              ),
                            ),
                          const SizedBox(height: 30, child: Align(alignment: Alignment.centerLeft, child: Text('チーム', style: TextStyle(color: GmColors.ball, fontWeight: FontWeight.bold)))),
                        ]),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              for (var i = 0; i < _cols.length; i++)
                                InkWell(
                                  onTap: () => setState(() => _sort = i),
                                  child: SizedBox(
                                    width: w(i),
                                    height: 30,
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(_cols[i].$1,
                                          style: headStyle.copyWith(
                                              color: _sort == i ? GmColors.ball : null, fontWeight: _sort == i ? FontWeight.bold : null)),
                                    ),
                                  ),
                                ),
                            ]),
                            for (final p in players)
                              SizedBox(
                                height: 30,
                                child: Row(children: [
                                  for (var i = 0; i < _cols.length; i++)
                                    SizedBox(
                                      width: w(i),
                                      child: Text(p.stats.gp == 0 ? '-' : _cols[i].$3(p.stats),
                                          textAlign: TextAlign.right, style: style.copyWith(color: _sort == i ? GmColors.ball : null)),
                                    ),
                                ]),
                              ),
                            SizedBox(
                              height: 30,
                              child: Row(children: [
                                for (var i = 0; i < _cols.length; i++)
                                  SizedBox(
                                    width: w(i),
                                    child: Text(games == 0 || i == 1 ? '-' : _cols[i].$3(total),
                                        textAlign: TextAlign.right, style: style.copyWith(color: GmColors.ball)),
                                  ),
                              ]),
                            ),
                          ]),
                        ),
                      ),
                    ]),
                  ),
                ),
                const SectionTitle('見出しの意味'),
                const Text('FG%: シュートの成功率・3P%: 3ポイントの成功率・FT%: フリースローの成功率・奪: スティール・ブ: ブロック・失: ミス(ターンオーバー)',
                    style: TextStyle(fontSize: 12, color: GmColors.sub, height: 1.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
