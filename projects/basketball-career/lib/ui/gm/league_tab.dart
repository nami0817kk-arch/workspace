import 'package:flutter/material.dart';

import '../../gm/career.dart';
import '../../gm/draft.dart';
import '../../gm/league.dart';
import '../../gm/player.dart';
import '../gm_controller.dart';
import 'common.dart';
import 'history_screen.dart';
import 'player_card.dart';
import 'style.dart';

/// リーグのタブ。順位・各チームの考え・これまでの成績。
class LeagueTab extends StatelessWidget {
  const LeagueTab({super.key, required this.c});
  final GmController c;

  @override
  Widget build(BuildContext context) {
    final car = c.career!;
    final started = car.phase == Phase.season || car.phase == Phase.playoffs || car.phase == Phase.seasonEnd;
    // 自分の地区を先に
    final confs = [car.me.east, !car.me.east];
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
      children: [
        for (final east in confs) ...[
          SectionTitle('${east ? '東' : '西'}地区 ${started ? '順位' : '戦力の順(シーズン前)'}'),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Builder(
                builder: (context) {
                  final list = started
                      ? standings(car.teams, east: east)
                      : ([...car.teams.where((t) => t.east == east)]..sort((a, b) => b.strength.compareTo(a.strength)));
                  return Column(
                    children: [for (var i = 0; i < list.length; i++) _teamRow(context, car, list[i], i + 1, started, leader: started ? list.first : null)],
                  );
                },
              ),
            ),
          ),
        ],
        if (car.phase == Phase.season && car.mvpRace().isNotEmpty) ...[
          const SectionTitle('MVP争い'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  for (final (i, (p, team)) in car.mvpRace().indexed)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 22,
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(color: GmColors.gold, fontWeight: FontWeight.bold),
                            ),
                          ),
                          TeamBadge(team: team, size: 20),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: team == car.mine ? GmColors.ball : null),
                            ),
                          ),
                          Text(p.stats.line, style: const TextStyle(fontSize: 12, color: GmColors.sub)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
        if (car.allStarIds.isNotEmpty) ...[
          const SectionTitle('オールスター'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final east in [true, false]) ...[
                    Text(
                      east ? '東' : '西',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: GmColors.ball),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        for (final t in car.teams.where((t) => t.east == east))
                          for (final p in t.roster)
                            if (car.allStarIds.contains(p.id)) '${p.name}(${t.def.short})',
                      ].join('、'),
                      style: const TextStyle(fontSize: 13, height: 1.5),
                    ),
                    const SizedBox(height: 6),
                  ],
                ],
              ),
            ),
          ),
        ],
        if (car.phase == Phase.season || car.phase == Phase.playoffs) ...[
          const SectionTitle('ドラフトのくじ(今の順位なら)'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  for (final e in (lotteryOdds(car.teams).entries.toList()..sort((a, b) => b.value.compareTo(a.value))))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          TeamBadge(team: e.key, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              () {
                                final pk = car.picks.where((p) => p.season == car.season && p.round == 1 && p.from == e.key).firstOrNull;
                                final owner = pk == null || pk.owner == e.key ? '' : ' → ${teamDefs[pk.owner].short}が持つ';
                                return '${teamDefs[e.key].short}$owner';
                              }(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: e.key == car.mine ? GmColors.ball : null),
                            ),
                          ),
                          Text('1位 ${(e.value * 100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('プレーオフに出ない14チームのくじで、上位4つの順番が決まる。成績が悪いほど見込みが高い。', style: TextStyle(fontSize: 12, color: GmColors.sub)),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SectionTitle('指名権'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '持っている',
                  style: TextStyle(fontWeight: FontWeight.bold, color: GmColors.good),
                ),
                for (final i in car.picksOf(car.mine)..sort((a, b) => car.picks[a].season.compareTo(car.picks[b].season)))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Text('・${car.picks[i].label(car.teams, car.season)}', style: const TextStyle(fontSize: 13)),
                  ),
                if (car.picksOwedBy(car.mine).isNotEmpty) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'ほかのチームに渡した',
                    style: TextStyle(fontWeight: FontWeight.bold, color: GmColors.bad),
                  ),
                  for (final i in car.picksOwedBy(car.mine))
                    Text('・${car.picks[i].label(car.teams, car.season)} → ${teamDefs[car.picks[i].owner].short}', style: const TextStyle(fontSize: 13)),
                ],
              ],
            ),
          ),
        ),
        if (car.finals != null) ...[
          const SectionTitle('プレーオフの山'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var round = 0; round <= 4; round++) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 2),
                      child: Text(
                        const ['プレーイン', '1回戦', '2回戦', '地区決勝', 'ファイナル'][round],
                        style: const TextStyle(fontWeight: FontWeight.bold, color: GmColors.ball),
                      ),
                    ),
                    for (final sr in car.playoffs.where((x) => x.round == round))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            TeamBadge(team: sr.winner, size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${teamDefs[sr.winner].short} ${sr.winner == sr.high ? sr.highWins : sr.lowWins}-${sr.winner == sr.high ? sr.lowWins : sr.highWins} ${teamDefs[sr.loser].short}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: sr.high == car.mine || sr.low == car.mine ? FontWeight.bold : null,
                                  color: sr.high == car.mine || sr.low == car.mine ? GmColors.ball : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
        if (car.leaders((s) => s.ppg).isNotEmpty) ...[
          const SectionTitle('個人成績の上位(1試合あたり)'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (label, key) in <(String, double Function(Stats))>[('得点', (s) => s.ppg), ('リバウンド', (s) => s.rpg), ('アシスト', (s) => s.apg)]) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 2),
                      child: Text(
                        label,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: GmColors.ball),
                      ),
                    ),
                    for (final (p, team) in car.leaders(key))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            TeamBadge(team: team, size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                p.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: team == car.mine ? GmColors.ball : null, fontSize: 13),
                              ),
                            ),
                            Text(key(p.stats).toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
        const SectionTitle('リーグの歴史'),
        Card(
          child: ListTile(
            leading: const Icon(Icons.account_balance_rounded, color: GmColors.gold),
            title: const Text('歴代の優勝・表彰・殿堂', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              '優勝 ${car.champs.length}回分・殿堂 ${car.hall.length}人${car.awards.isEmpty ? '' : '・最新のMVP ${car.awards.lastWhere((a) => a.kind == AwardKind.mvp, orElse: () => car.awards.last).name}'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => HistoryScreen(c: c))),
          ),
        ),
        if (car.log.isNotEmpty) ...[
          const SectionTitle('リーグのニュース'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final n in car.log.take(20))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(n, style: const TextStyle(fontSize: 13, height: 1.4)),
                    ),
                ],
              ),
            ),
          ),
        ],
        if (car.history.isNotEmpty) ...[
          const SectionTitle('これまでの成績'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  for (final h in car.history.reversed)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 52,
                            child: Text('${h.season}年目', style: const TextStyle(color: GmColors.sub)),
                          ),
                          SizedBox(width: 78, child: Text('${h.wins}勝${h.losses}敗')),
                          SizedBox(
                            width: 36,
                            child: Text('${h.rank}位', style: const TextStyle(color: GmColors.sub)),
                          ),
                          Expanded(
                            child: Text(
                              h.resultLabel,
                              style: TextStyle(color: h.champion ? GmColors.gold : null, fontWeight: h.champion ? FontWeight.bold : null),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _teamRow(BuildContext context, Career car, Team t, int n, bool started, {Team? leader}) {
    final mine = t.index == car.mine;
    final gb = leader == null ? 0.0 : gamesBehind(leader, t);
    return InkWell(
      onTap: () => _showTeam(context, car, t),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '$n',
                style: TextStyle(
                  color: n <= directSeeds
                      ? GmColors.gold
                      : n <= playInSeeds
                      ? GmColors.ball
                      : GmColors.sub,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TeamBadge(team: t.index, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.bold, color: mine ? GmColors.ball : null),
                  ),
                  if (!mine) Text(t.mode.label, style: const TextStyle(fontSize: 11, color: GmColors.sub)),
                ],
              ),
            ),
            if (started)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(record(t), style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    '${gb == 0 ? '-' : '${gb.toStringAsFixed(gb == gb.roundToDouble() ? 0 : 1)}差'}・${streakLabel(t.streak)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: t.streak >= 3
                          ? GmColors.good
                          : t.streak <= -3
                          ? GmColors.bad
                          : GmColors.sub,
                    ),
                  ),
                ],
              )
            else
              Text('戦力 ${t.strength.toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Future<void> _showTeam(BuildContext context, Career car, Team t) => showGmSheet<void>(
    context,
    builder: (ctx) => ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      children: [
        Row(
          children: [
            TeamBadge(team: t.index, size: 56),
            const SizedBox(width: 10),
            Expanded(
              child: Text(t.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (t.index != car.mine) Text('${t.mode.label}: ${t.mode.wants}', style: const TextStyle(color: GmColors.sub)),
        const SizedBox(height: 8),
        PayrollBar(payroll: t.payroll),
        const SizedBox(height: 10),
        for (final p in lineup(t.roster))
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: PlayerRow(p: p, team: t.index, onTap: () => showPlayerCard(context, car, p, t.index)),
          ),
      ],
    ),
  );
}
