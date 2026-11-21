import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../gm/league_base.dart';
import '../../gm/career.dart';
import '../../gm/difficulty.dart';
import '../../gm/league.dart';
import '../../gm/player.dart';
import '../layout.dart';
import 'common.dart';
import 'gm_table.dart';
import 'style.dart';

/// どのチームのGMになるかと、難しさを選ぶ。リーグは [seed] で決まり、選んだあとも同じリーグになる。
/// 選んだチームの番号と難しさを返す(難しさは始めてからは変えられない)。
class TeamPickScreen extends StatefulWidget {
  const TeamPickScreen({super.key, required this.seed});
  final int seed;

  @override
  State<TeamPickScreen> createState() => _TeamPickScreenState();
}

class _TeamPickScreenState extends State<TeamPickScreen> {
  // 始めるたびに違うリーグ(D-3)。気に入らなければ、別のリーグを作り直せる
  late int _seed = widget.seed;
  late Career _league = Career.start(seed: _seed);
  bool _east = true;
  Difficulty _diff = Difficulty.normal;

  @override
  Widget build(BuildContext context) {
    final car = _league;
    final teams = [...car.teams.where((t) => t.east == _east)]..sort((a, b) => car.strengthRank(a.index).compareTo(car.strengthRank(b.index)));
    return Scaffold(
      appBar: AppBar(title: const Text('どのチームを任される?')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxWidth(context)),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Row(children: [
                  Expanded(
                    child: SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: true, label: Text('東地区')),
                        ButtonSegment(value: false, label: Text('西地区')),
                      ],
                      selected: {_east},
                      onSelectionChanged: (v) => setState(() => _east = v.first),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SegmentedButton<Difficulty>(
                      showSelectedIcon: false,
                      segments: [for (final d in Difficulty.values) ButtonSegment(value: d, label: Text(d.label))],
                      selected: {_diff},
                      onSelectionChanged: (v) => setState(() => _diff = v.first),
                    ),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                child: Row(children: [
                  Expanded(
                    child: Text(
                      'このリーグの始める前の10年: ${[for (final (ch, _) in _league.prehistory) _league.teams[ch].def.short].join('→')}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: GmColors.sub),
                    ),
                  ),
                  TextButton.icon(
                    key: const Key('reroll-league'),
                    onPressed: () => setState(() {
                      _seed = math.Random().nextInt(0x7fffffff);
                      _league = Career.start(seed: _seed);
                    }),
                    icon: const Icon(Icons.casino_rounded, size: 16),
                    label: const Text('別のリーグにする'),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
                child: Text('難しさ「${_diff.label}」: ${_diff.text}始めたあとは変えられない。強いチームほどオーナーの期待が高く、弱いチームは指名権と年俸の空きで立て直す。',
                    style: const TextStyle(color: GmColors.sub, fontSize: 12, height: 1.4)),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                  children: [
                    for (final t in teams)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _TeamCard(car: car, team: t, onTap: () => _confirm(context, t)),
                      ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _confirm(BuildContext context, Team t) async {
    final car = _league;
    final rank = car.strengthRank(t.index);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        builder: (ctx, sc) => Column(children: [
          Expanded(
            child: ListView(
              controller: sc,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: [
                Row(children: [
                  TeamBadge(team: t.index, size: 60),
                  const SizedBox(width: 10),
                  Expanded(child: Text(t.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold))),
                ]),
                const SizedBox(height: 6),
                Text('${Outlook.of(rank).label}(戦力 30チーム中${rank + 1}位)', style: const TextStyle(fontWeight: FontWeight.bold, color: GmColors.ball)),
                Text(Outlook.of(rank).text, style: const TextStyle(color: GmColors.sub, height: 1.5)),
                const SizedBox(height: 6),
                // このリーグでのチームの土台と歴史(D-3)
                () {
                  final b = leagueBaseOf(_seed, t.index);
                  final since = _league.yearsSinceTitle(t.index);
                  final rivals = _league.rivalsOf(t.index);
                  return Text(
                    [
                      '${marketLabel(b.market)}(収入${b.market.toStringAsFixed(2)}倍)',
                      'ファンは${b.fans.label}',
                      '施設は${b.facility >= 2 ? '新しい' : '古い'}',
                      since == null ? '10年以上優勝なし' : '最後の優勝は$since年前',
                      if (rivals.isNotEmpty) 'ライバル: ${rivals.map((x) => _league.teams[x].def.short).join('・')}',
                    ].join('・'),
                    style: const TextStyle(fontSize: 12.5, height: 1.5),
                  );
                }(),
                const SizedBox(height: 8),
                PayrollBar(payroll: t.payroll),
                const SizedBox(height: 10),
                for (final p in lineup(t.roster))
                  Padding(padding: const EdgeInsets.only(bottom: 6), child: PlayerRow(p: p, team: t.index)),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.badge_rounded),
                label: Text('${t.def.short}のGMになる'),
              ),
            ),
          ),
        ]),
      ),
    );
    if (ok == true && context.mounted) Navigator.pop(context, (t.index, _diff, _seed));
  }
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({required this.car, required this.team, required this.onTap});
  final Career car;
  final Team team;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = team;
    final rank = car.strengthRank(t.index);
    final star = t.roster.reduce((a, b) => a.ovr >= b.ovr ? a : b);
    final age = t.roster.fold(0, (s, p) => s + p.age) / t.roster.length;
    final o = Outlook.of(rank);
    final color = switch (o) {
      Outlook.contender => GmColors.gold,
      Outlook.playoff => GmColors.good,
      Outlook.bubble => const Color(0xFF8FD3FF),
      Outlook.rebuild => GmColors.bad,
    };
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            TeamBadge(team: t.index, size: 52),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                fitText(t.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 3),
                Wrap(spacing: 6, runSpacing: 3, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Tag(o.label, color: color),
                  Text('戦力${rank + 1}位・平均${age.toStringAsFixed(1)}歳・年俸${money(t.payroll)}', style: const TextStyle(fontSize: 12, color: GmColors.sub)),
                ]),
                const SizedBox(height: 3),
                Text('エース ${star.name}(${star.pos.short}・OVR${shown(star.ovr)})',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: GmColors.sub)),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: GmColors.sub),
          ]),
        ),
      ),
    );
  }
}
