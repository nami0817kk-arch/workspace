import 'package:flutter/material.dart';

import '../../gm/career.dart';
import '../../gm/league.dart';
import '../../gm/player.dart';
import 'common.dart';
import 'gm_table.dart';
import 'player_card.dart';
import 'style.dart';

/// 個人ランキングの項目。
enum _Cat {
  pts('得点'),
  reb('リバウンド'),
  ast('アシスト'),
  stl('スティール'),
  blk('ブロック'),
  fg('FG%'),
  tp('3P成功'),
  ovr('OVR');

  const _Cat(this.label);
  final String label;
}

/// リーグのランキング(2026-11-16、ユーザー「リーグ内でのランキングがない」)。
/// 左に個人の上位(項目を選ぶ)、右にチームの順(戦力・得点・年俸など)。
class RankingsView extends StatefulWidget {
  const RankingsView({super.key, required this.car});
  final Career car;

  @override
  State<RankingsView> createState() => _RankingsViewState();
}

class _RankingsViewState extends State<RankingsView> {
  _Cat _cat = _Cat.pts;
  int _teamSort = 0;

  Career get car => widget.car;

  /// 項目の値(並べ替えと表示)。
  double _value(Player p, _Cat c) {
    final s = p.stats;
    return switch (c) {
      _Cat.pts => s.ppg,
      _Cat.reb => s.rpg,
      _Cat.ast => s.apg,
      _Cat.stl => s.spg,
      _Cat.blk => s.bpg,
      _Cat.fg => s.fga == 0 ? 0 : s.fgm / s.fga * 100,
      _Cat.tp => s.per(s.tpm),
      _Cat.ovr => shown(p.ovr).toDouble(),
    };
  }

  String _fmt(double v, _Cat c) => c == _Cat.ovr
      ? v.round().toString()
      : c == _Cat.fg
      ? '${v.toStringAsFixed(1)}%'
      : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final all = [
      for (final t in car.teams)
        for (final p in t.roster) (p, t.index),
    ];
    // 1試合あたりの数字は、試合の半分以上に出た選手だけ(FG% は1試合5本以上も)
    final games = all.fold(0, (n, x) => x.$1.stats.gp > n ? x.$1.stats.gp : n);
    final minGp = (games * 0.5).ceil().clamp(1, 99);
    final noStats = games == 0;
    final cat = noStats ? _Cat.ovr : _cat;
    final list = [
      for (final x in all)
        if (cat == _Cat.ovr || (x.$1.stats.gp >= minGp && (cat != _Cat.fg || x.$1.stats.per(x.$1.stats.fga) >= 5))) x,
    ]..sort((a, b) => _value(b.$1, cat).compareTo(_value(a.$1, cat)));
    final top = list.take(25).toList();
    final mineBest = list.indexWhere((x) => x.$2 == car.mine);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 6,
          child: ListView(
            children: [
              if (!noStats)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final c in _Cat.values)
                        ChoiceChip(
                          visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          showCheckmark: false,
                          label: Text(c.label, style: const TextStyle(fontSize: 11)),
                          selected: _cat == c,
                          onSelected: (_) => setState(() => _cat = c),
                        ),
                    ],
                  ),
                ),
              GmTable(
                title: noStats ? '個人ランキング(OVR。シーズンが始まると成績で並ぶ)' : '個人ランキング($minGp試合以上)',
                rowHeight: 26,
                cols: [
                  const GmCol('#', width: 26),
                  const GmCol('', width: 22),
                  const GmCol('選手', flex: 1, align: TextAlign.left),
                  const GmCol('位', width: 26),
                  const GmCol('歳', width: 24),
                  const GmCol('試', width: 26),
                  GmCol(cat.label, width: 64, align: TextAlign.right, sorted: true),
                ],
                rows: [
                  for (final (i, (p, t)) in top.indexed)
                    GmRow(
                      [
                        numCell('${i + 1}', color: i < 3 ? GmColors.gold : GmColors.sub, bold: i < 3),
                        TeamBadge(team: t, size: 16),
                        fitText(p.name, style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(p.pos.short, style: const TextStyle(fontSize: 10, color: GmColors.sub)),
                        numCell('${p.age}'),
                        numCell('${p.stats.gp}', color: GmColors.sub),
                        numCell(_fmt(_value(p, cat), cat), bold: true, color: GmColors.ball),
                      ],
                      highlight: t == car.mine,
                      onTap: () => showPlayerCard(context, car, p, t),
                    ),
                ],
              ),
              if (mineBest >= 25)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '自分のチームの最上位: ${list[mineBest].$1.name}(${mineBest + 1}位・${_fmt(_value(list[mineBest].$1, cat), cat)})',
                    style: const TextStyle(fontSize: 11, color: GmColors.ball),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(flex: 5, child: ListView(children: [_teamTable(context)])),
      ],
    );
  }

  /// チームの順(戦力・平均得点・勝率・平均年齢・年俸)。見出しで並べ替える。
  Widget _teamTable(BuildContext context) {
    double pts(Team t) {
      final g = t.wins + t.losses;
      return g == 0 ? 0 : t.roster.fold(0, (n, p) => n + p.stats.pts) / g;
    }

    double age(Team t) => t.roster.isEmpty ? 0 : t.roster.fold(0, (n, p) => n + p.age) / t.roster.length;
    final keys = <double Function(Team)>[(t) => t.strength, (t) => t.winPct, pts, (t) => -age(t), (t) => t.payroll.toDouble()];
    final rows = [...car.teams]..sort((a, b) => keys[_teamSort](b).compareTo(keys[_teamSort](a)));
    GmCol col(String l, int k, double w) => GmCol(l, width: w, sorted: _teamSort == k, onTap: () => setState(() => _teamSort = k));
    return GmTable(
      title: 'チームの順',
      rowHeight: 24,
      cols: [
        const GmCol('#', width: 24),
        const GmCol('チーム', flex: 1, align: TextAlign.left),
        col('戦力', 0, 40),
        col('勝率', 1, 42),
        col('得点', 2, 42),
        col('若さ', 3, 36),
        col('年俸', 4, 72),
      ],
      rows: [
        for (final (i, t) in rows.indexed)
          GmRow([
            numCell('${i + 1}', color: i < 3 ? GmColors.gold : GmColors.sub),
            Row(
              children: [
                TeamBadge(team: t.index, size: 16),
                const SizedBox(width: 4),
                Expanded(child: Text(t.def.short, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
            numCell('${car.strengthRank(t.index) + 1}位', color: GmColors.sub),
            numCell(
              t.wins + t.losses == 0
                  ? '-'
                  : t.winPct >= 1
                  ? '1.000'
                  : t.winPct.toStringAsFixed(3).substring(1),
            ),
            numCell(pts(t) == 0 ? '-' : pts(t).toStringAsFixed(1)),
            numCell(age(t).toStringAsFixed(1), color: GmColors.sub),
            numCell(money(t.payroll), color: GmColors.sub),
          ], highlight: t.index == car.mine),
      ],
    );
  }
}
