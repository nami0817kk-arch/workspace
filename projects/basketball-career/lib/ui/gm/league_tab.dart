import 'package:flutter/material.dart';

import '../../gm/codex.dart';

import '../../gm/career.dart';
import '../../gm/draft.dart';
import '../../gm/league.dart';
import '../../gm/player.dart';
import '../gm_controller.dart';
import 'codex_screen.dart';
import 'common.dart';
import 'draft_board_view.dart';
import 'rankings_view.dart';
import 'gm_table.dart';
import 'history_screen.dart';
import 'player_card.dart';
import 'style.dart';

/// リーグのタブ。順位・各チームの考え・これまでの成績。
/// リーグの画面。上の切り替えで、順位・ランキング(2026-11-16、ユーザー「リーグ内でのランキングがない」)。
class LeagueTab extends StatefulWidget {
  const LeagueTab({super.key, required this.c});
  final GmController c;

  @override
  State<LeagueTab> createState() => _LeagueTabState();
}

class _LeagueTabState extends State<LeagueTab> {
  int _view = 0;

  @override
  Widget build(BuildContext context) {
    final car = widget.c.career!;
    const views = ['順位', 'ランキング', 'ドラフト'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          child: Row(
            children: [
              for (final (i, v) in views.indexed)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    visualDensity: const VisualDensity(vertical: -3),
                    showCheckmark: false,
                    label: Text(v, style: const TextStyle(fontSize: 12)),
                    selected: _view == i,
                    onSelected: (_) => setState(() => _view = i),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: switch (_view) {
            1 => Padding(padding: const EdgeInsets.fromLTRB(14, 6, 14, 8), child: RankingsView(car: car)),
            2 => Padding(padding: const EdgeInsets.fromLTRB(14, 6, 14, 8), child: DraftBoardView(car: car)),
            _ => _Standings(c: widget.c),
          },
        ),
      ],
    );
  }
}

/// 東西の順位・MVP争い・オールスター・くじの見込みなど。
class _Standings extends StatelessWidget {
  const _Standings({required this.c});
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
        // 東西の順位を横に並べた表(2026-11-14、詰めた表に)
        LayoutBuilder(builder: (context, cons) {
          final tables = [for (final east in confs) _standingsTable(context, car, east, started)];
          if (cons.maxWidth < 640) return Column(children: [for (final t in tables) Padding(padding: const EdgeInsets.only(bottom: 8), child: t)]);
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: tables[0]),
            const SizedBox(width: 8),
            Expanded(child: tables[1]),
          ]);
        }),
        const SizedBox(height: 4),
        Text(
          started ? '1〜6位はプレーオフ(金)、7〜10位はプレーイン(橙)。チームを押すと選手が見られる。' : 'シーズン前は戦力の順。チームを押すと選手が見られる。',
          style: const TextStyle(fontSize: 11, color: GmColors.sub),
        ),
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
                            child: fitText(p.name, style: TextStyle(color: team == car.mine ? GmColors.ball : null),
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
                            TeamBadge(team: sr.over ? sr.winner : sr.high, size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                sr.over
                                    ? '${teamDefs[sr.winner].short} ${sr.winner == sr.high ? sr.highWins : sr.lowWins}-${sr.winner == sr.high ? sr.lowWins : sr.highWins} ${teamDefs[sr.loser].short}'
                                    : '${teamDefs[sr.high].short} ${sr.highWins}-${sr.lowWins} ${teamDefs[sr.low].short}(戦っている途中)',
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
                  for (final (label, key) in <(String, double Function(Stats))>[
                    ('得点', (s) => s.ppg),
                    ('リバウンド', (s) => s.rpg),
                    ('アシスト', (s) => s.apg),
                    ('スティール', (s) => s.spg),
                    ('ブロック', (s) => s.bpg),
                    // 成功率は、1試合に5本(3ポイントは2本)以上打った選手だけ
                    ('FG%', (s) => s.gp > 0 && s.fga / s.gp >= 5 ? s.fgPct * 100 : 0),
                    ('3P%', (s) => s.gp > 0 && s.tpa / s.gp >= 2 ? s.tpPct * 100 : 0),
                  ]) ...[
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
                              child: fitText(p.name, style: TextStyle(color: team == car.mine ? GmColors.ball : null, fontSize: 13),
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
        if (car.monthly.any((a) => a.season == car.season)) ...[
          const SectionTitle('月間MVP'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final a in car.monthly.where((a) => a.season == car.season).toList().reversed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      SizedBox(
                        width: 74,
                        child: Text('${a.block}区切り目・${teamDefs[a.team].east ? '東' : '西'}', style: const TextStyle(fontSize: 12, color: GmColors.sub)),
                      ),
                      TeamBadge(team: a.team, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('${a.name}  ${a.line}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: a.team == car.mine ? GmColors.gold : null)),
                      ),
                    ]),
                  ),
              ]),
            ),
          ),
        ],
        if (started && car.teams.any((t) => t.roster.any((p) => p.injured > 0))) ...[
          const SectionTitle('けが人'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final (t, p) in [
                  for (final t in [car.me, ...car.teams.where((t) => t.index != car.mine)])
                    for (final p in t.roster)
                      if (p.injured > 0 && (t.index == car.mine || p.ovr >= 70)) (t, p),
                ].take(14))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      TeamBadge(team: t.index, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('${p.name}(${p.pos.short}・OVR ${shown(p.ovr)})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: t.index == car.mine ? GmColors.ball : null)),
                      ),
                      Text('あと${p.injured}試合', style: const TextStyle(fontSize: 12, color: GmColors.bad, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('自分のチームの全員と、ほかのチームの主力(OVR 82以上)。', style: TextStyle(fontSize: 11, color: GmColors.sub)),
                ),
              ]),
            ),
          ),
        ],
        const SectionTitle('リーグの歴史'),
        Card(
          child: ListTile(
            key: const Key('codex'),
            leading: const Icon(Icons.menu_book_rounded, color: GmColors.gold),
            title: const Text('図鑑', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('見つけたもの ${c.profile.codex.length} / ${codexEntries.length}(組み合わせ・相性・伸び方の型・隠れた特性・ドラフトの年)',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CodexScreen(profile: c.profile, career: car))),
          ),
        ),
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

  /// 地区の順位の表。
  Widget _standingsTable(BuildContext context, Career car, bool east, bool started) {
    final list = started ? standings(car.teams, east: east) : ([...car.teams.where((t) => t.east == east)]..sort((a, b) => b.strength.compareTo(a.strength)));
    final leader = list.first;
    final byStr = [...car.teams]..sort((a, b) => b.strength.compareTo(a.strength));
    return GmTable(
      title: '${east ? '東' : '西'}地区 ${started ? '順位' : '戦力の順(シーズン前)'}',
      cols: const [
        GmCol('#', width: 28),
        GmCol('チーム', flex: 5, align: TextAlign.left),
        GmCol('勝', width: 28),
        GmCol('敗', width: 28),
        GmCol('勝率', width: 40),
        GmCol('差', width: 32),
        GmCol('連', width: 34),
        GmCol('戦力', width: 34),
      ],
      rows: [
        for (final (i, t) in list.indexed)
          GmRow(
            [
              numCell('${i + 1}',
                  bold: true,
                  color: !started
                      ? GmColors.sub
                      : i < directSeeds
                          ? GmColors.gold
                          : i < playInSeeds
                              ? GmColors.ball
                              : GmColors.sub),
              Row(children: [
                TeamBadge(team: t.index, size: 18),
                const SizedBox(width: 5),
                Flexible(
                  flex: 3,
                  child: fitText(t.def.short, style: TextStyle(fontWeight: FontWeight.bold, color: t.index == car.mine ? GmColors.ball : null)),
                ),
                if (t.index != car.mine) ...[
                  const SizedBox(width: 4),
                  Flexible(flex: 2, child: Text(t.mode.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, color: GmColors.sub))),
                ],
              ]),
              numCell('${t.wins}'),
              numCell('${t.losses}'),
              numCell(t.wins + t.losses == 0 ? '-' : t.winPct.toStringAsFixed(3).replaceFirst('0.', '.')),
              numCell(() {
                final gb = gamesBehind(leader, t);
                return !started || gb == 0 ? '-' : gb.toStringAsFixed(gb == gb.roundToDouble() ? 0 : 1);
              }()),
              numCell(t.streak == 0 ? '-' : t.streak > 0 ? '${t.streak}勝' : '${-t.streak}敗',
                  color: t.streak >= 3
                      ? GmColors.good
                      : t.streak <= -3
                          ? GmColors.bad
                          : GmColors.sub),
              numCell('${byStr.indexOf(t) + 1}', color: GmColors.sub),
            ],
            highlight: t.index == car.mine,
            divider: started && (i == directSeeds || i == playInSeeds),
            onTap: () => _showTeam(context, car, t),
          ),
      ],
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
