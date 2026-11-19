import 'package:flutter/material.dart';

import '../../gm/calendar.dart';
import '../../gm/career.dart';
import '../../gm/league.dart';
import '../gm_controller.dart';
import 'common.dart';
import 'style.dart';

/// 今季の日程表(82試合)。区切りごとに並べ、終わった試合は勝ち負けと点、次の試合は枠で示す。
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key, required this.c});
  final GmController c;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          final car = c.career!;
          final games = <(int, bool)>[
            for (final round in seasonSchedule(car.teams.length))
              for (final (h, a) in round)
                if (h == car.mine)
                  (a, true)
                else if (a == car.mine)
                  (h, false),
          ];
          final log = car.seasonLog;
          final homeW = log.where((r) => r[1] == 1 && r[2] > r[3]).length, homeL = log.where((r) => r[1] == 1 && r[2] < r[3]).length;
          final awayW = log.where((r) => r[1] == 0 && r[2] > r[3]).length, awayL = log.where((r) => r[1] == 0 && r[2] < r[3]).length;
          return Scaffold(
            appBar: AppBar(
                title: Text(car.phase == Phase.season ? '日程表(これからの試合を押すと、その手前まで進められる)' : '日程表', style: const TextStyle(fontSize: 16)),
                toolbarHeight: 40),
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                children: [
                  Wrap(spacing: 14, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Text('${car.me.wins}勝${car.me.losses}敗', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('ホーム $homeW勝$homeL敗・アウェー $awayW勝$awayL敗', style: const TextStyle(fontSize: 12.5, color: GmColors.sub)),
                    if (car.phase == Phase.season)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Switch(key: const Key('rest-settled'), value: car.restWhenSettled, onChanged: c.busy ? null : c.setRestWhenSettled),
                        Text(
                          '順位が決まったら主力を休ませる${car.restWhenSettled && car.standingSettled ? '(いま休ませている)' : ''}',
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ]),
                  ]),
                  for (final (month, rounds) in _byMonth(car.season, games.length)) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 4),
                      child: Text(
                        '$month月(${rounds.length}試合)'
                        '${deadlineDate(car.season).month == month ? '・${dateLabel(deadlineDate(car.season))}にトレードの締め切りとカップ戦、${dateLabel(allStarDate(car.season))}にオールスター' : ''}'
                        '${rounds.last == gamesPerSeason - 1 ? '・最終戦のあとプレーオフ' : ''}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    Wrap(spacing: 4, runSpacing: 4, children: [
                      for (final i in rounds) _cell(context, car, i, games[i], i < log.length ? log[i] : null),
                    ]),
                  ],
                ],
              ),
            ),
          );
        },
      );

  /// 節を月ごとにまとめる((月, 節の番号の一覧)、古い順)。
  static List<(int, List<int>)> _byMonth(int season, int n) {
    final out = <(int, List<int>)>[];
    for (var i = 0; i < n; i++) {
      final m = roundDate(season, i).month;
      if (out.isEmpty || out.last.$1 != m) out.add((m, <int>[]));
      out.last.$2.add(i);
    }
    return out;
  }

  /// これからの試合を押したら、その試合の手前まで進めるかを聞き、進めるなら節の番号を返して閉じる。
  Future<void> _ask(BuildContext context, Career car, int i, int opp, bool home) async {
    final n = car.roundsUntil(i);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${dateLabel(roundDate(car.season, i))}の${home ? 'ホーム' : 'アウェー'}・${car.teams[opp].def.short}戦の前まで進める?'),
        content: Text('$n試合を進める。止まる場面(申し込み・けがなど)があれば、そこで止まる。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('やめる')),
          FilledButton(key: const Key('calendar-go'), onPressed: () => Navigator.pop(ctx, true), child: Text('$n試合進める')),
        ],
      ),
    );
    if (ok == true && context.mounted) Navigator.of(context).pop(i);
  }

  Widget _cell(BuildContext context, Career car, int i, (int, bool) g, List<int>? r) {
    final (opp, home) = g;
    final next = r == null && i == car.roundAt && car.phase == Phase.season;
    final pickable = car.phase == Phase.season && r == null && i > car.roundAt && !c.busy;
    return GestureDetector(
      key: Key('calendar-cell-$i'),
      onTap: pickable ? () => _ask(context, car, i, opp, home) : null,
      child: _cellBox(car, i, opp, home, r, next),
    );
  }

  Widget _cellBox(Career car, int i, int opp, bool home, List<int>? r, bool next) {
    final win = r != null && r[2] > r[3];
    final color = r == null ? (next ? GmColors.gold : GmColors.line) : (win ? GmColors.good : GmColors.bad);
    return Container(
      width: 58,
      padding: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: r == null ? GmColors.panel : color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: next ? 2 : 1),
      ),
      child: Column(children: [
        Text('${dateShort(roundDate(car.season, i))}${home ? '' : ' @'}', style: const TextStyle(fontSize: 10, color: GmColors.sub)),
        TeamBadge(team: opp, size: 20),
        Text(
          r == null ? (home ? 'ホーム' : 'アウェー') : '${win ? '勝' : '負'} ${r[2]}-${r[3]}',
          maxLines: 1,
          style: TextStyle(fontSize: 10, fontWeight: r == null ? null : FontWeight.bold, color: r == null ? GmColors.sub : color),
        ),
      ]),
    );
  }
}
