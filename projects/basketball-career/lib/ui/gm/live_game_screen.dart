import 'package:flutter/material.dart';

import '../../gm/career.dart';
import '../../gm/game_sim.dart';
import 'live_court.dart';
import 'style.dart';

/// 次の自分の試合を、区切り(1Q・前半・3Q・4Q残り4分)ごとに見ながら采配する。
/// 確定すると、選んだ采配のリストを返す(呼ぶ側でその節を進める)。やめたら null。
Future<List<GameCall?>?> showLiveGame(BuildContext context, Career car) =>
    Navigator.of(context).push<List<GameCall?>>(MaterialPageRoute(builder: (_) => LiveGameScreen(car: car)));

class LiveGameScreen extends StatefulWidget {
  const LiveGameScreen({super.key, required this.car});
  final Career car;

  @override
  State<LiveGameScreen> createState() => _LiveGameScreenState();
}

class _LiveGameScreenState extends State<LiveGameScreen> {
  final calls = List<GameCall?>.filled(liveBreaks.length, null);

  /// いま止まっている区切り(全部終えたら liveBreaks.length)。
  int at = 0;
  GameCall? picked;
  SimResult? res;

  Career get car => widget.car;

  @override
  void initState() {
    super.initState();
    _run();
  }

  void _run() {
    res = car.previewLive(calls, at < liveBreaks.length ? at : null);
  }

  int get _timeoutsLeft => liveTimeouts - calls.where((c) => c == GameCall.timeout).length;

  void _next({bool toEnd = false}) {
    setState(() {
      if (at < liveBreaks.length) calls[at] = picked;
      picked = null;
      at = toEnd ? liveBreaks.length : at + 1;
      _run();
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = car.nextMyGame;
    final r = res;
    if (g == null || r == null) {
      return Scaffold(appBar: AppBar(title: const Text('試合の采配')), body: const Center(child: Text('采配できる試合がない')));
    }
    final home = car.teams[g.$1], away = car.teams[g.$2];
    final mineHome = g.$1 == car.mine;
    final my = mineHome ? r.home : r.away, opp = mineHome ? r.away : r.home;
    final done = r.finished;
    final diff = my.pts - opp.pts;
    return PopScope(
      canPop: at == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(List<GameCall?>.of(calls));
      },
      child: _page(context, home.def.short, away.def.short, r, my, opp, done, diff, g.$1, g.$2, mineHome),
    );
  }

  Widget _page(BuildContext context, String homeName, String awayName, SimResult r, SimTeam my, SimTeam opp, bool done, int diff, int homeId, int awayId, bool mineHome) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$awayName @ $homeName', style: const TextStyle(fontSize: 16)),
        // 1Qを見ただけなら、やめられる。采配を始めたあとに閉じると、残りは任せて進める(結果を見てからやり直せないように)
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: at == 0 ? 'やめる' : '残りを任せて進める',
          onPressed: () => Navigator.of(context).pop(at == 0 ? null : List<GameCall?>.of(calls)),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 8, 8, 14),
                children: [
                  LiveCourt(
                    home: homeId,
                    away: awayId,
                    homeName: homeName,
                    awayName: awayName,
                    result: r,
                    mineHome: mineHome,
                    label: done ? '試合終了' : liveBreaks[r.stoppedAt],
                  ),
                  const SizedBox(height: 10),
                  Text(done ? '試合終了' : '${liveBreaks[r.stoppedAt]}・${diff > 0 ? '$diff点リード' : diff < 0 ? '${-diff}点ビハインド' : '同点'}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: diff > 0 ? GmColors.good : diff < 0 ? GmColors.bad : GmColors.text)),
                  const SizedBox(height: 6),
                  _leaders(my),
                  const SizedBox(height: 8),
                  const Text('最近の得点', style: TextStyle(fontSize: 12, color: GmColors.sub)),
                  for (final p in r.plays.reversed.take(6)) Text(p, style: const TextStyle(fontSize: 12.5, height: 1.5)),
                ],
              ),
            ),
            Expanded(
              flex: 6,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(8, 8, 14, 14),
                children: done ? _finish(diff) : _choices(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 自分のチームの、ここまでの点の多い3人。
  Widget _leaders(SimTeam t) {
    final idx = [for (var i = 0; i < t.order.length; i++) i]..sort((a, b) => ptsAt(t, b).compareTo(ptsAt(t, a)));
    final top = idx.take(3).where((i) => ptsAt(t, i) > 0).map((i) => '${t.order[i].name} ${ptsAt(t, i)}点').join('・');
    return Text(top.isEmpty ? '' : 'ここまで: $top', style: const TextStyle(fontSize: 12.5));
  }

  List<Widget> _choices() {
    final used = [for (var k = 0; k < at; k++) if (calls[k] != null) '${liveBreaks[k]}: ${calls[k]!.label}'];
    return [
      Text('采配(${liveBreaks[at]})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      Text('タイムアウトはあと$_timeoutsLeft回。選ばなければ、そのまま続ける。', style: const TextStyle(fontSize: 12, color: GmColors.sub)),
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final c in GameCall.values)
          ChoiceChip(
            label: Text(c.label, style: const TextStyle(fontSize: 12.5)),
            selected: picked == c,
            onSelected: c == GameCall.timeout && _timeoutsLeft <= 0 ? null : (on) => setState(() => picked = on ? c : null),
          ),
      ]),
      const SizedBox(height: 6),
      Text(picked?.help ?? '', style: const TextStyle(fontSize: 12.5, height: 1.4)),
      if (used.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text('これまでの采配: ${used.join(' / ')}', style: const TextStyle(fontSize: 12, color: GmColors.sub)),
      ],
      const SizedBox(height: 10),
      FilledButton.icon(
        onPressed: () => _next(),
        icon: const Icon(Icons.play_arrow_rounded),
        label: Text(at + 1 < liveBreaks.length ? '${picked == null ? 'そのまま' : picked!.label}で${liveBreaks[at + 1]}まで' : '${picked == null ? 'そのまま' : picked!.label}で最後まで'),
      ),
      TextButton(onPressed: () => _next(toEnd: true), child: const Text('ここからは任せて最後まで')),
    ];
  }

  List<Widget> _finish(int diff) => [
        Text(diff > 0 ? '勝った' : '負けた', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: diff > 0 ? GmColors.good : GmColors.bad)),
        const SizedBox(height: 6),
        Text(
          [for (var k = 0; k < liveBreaks.length; k++) if (calls[k] != null) '${liveBreaks[k]}: ${calls[k]!.label}'].join('\n').ifEmpty('采配はしなかった'),
          style: const TextStyle(fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(List<GameCall?>.of(calls)),
          icon: const Icon(Icons.check_rounded),
          label: const Text('この結果で進める'),
        ),
        const SizedBox(height: 4),
        const Text('進めると、この節のほかの試合も終わる。', style: TextStyle(fontSize: 12, color: GmColors.sub)),
      ];
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}
