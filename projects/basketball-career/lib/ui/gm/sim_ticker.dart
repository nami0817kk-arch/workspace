import 'dart:async';

import 'package:flutter/material.dart';

import '../../gm/block_report.dart';
import '../../gm/calendar.dart';
import '../../gm/league.dart';
import '../gm_controller.dart';
import 'common.dart';
import 'style.dart';

/// まとめて進めるあいだ、1試合ずつ結果を流して見せる(2026-11-19、ユーザー「試合と日付の進め方について、品質を上げたい」)。
/// [n] 節を進め、終わったら(止まったら)区切りの報告を返す。「一気に進める」で待たずに最後まで、「止める」でその節で止まる。
Future<BlockReport?> runSimTicker(BuildContext context, GmController c, int n, String title, {bool stops = true}) async {
  if (n <= 1) return c.simRounds(n, stops: stops);
  return showDialog<BlockReport?>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _SimTicker(c: c, n: n, title: title, stops: stops),
  );
}

class _SimTicker extends StatefulWidget {
  const _SimTicker({required this.c, required this.n, required this.title, required this.stops});
  final GmController c;
  final int n;
  final String title;
  final bool stops;

  @override
  State<_SimTicker> createState() => _SimTickerState();
}

class _SimTickerState extends State<_SimTicker> {
  /// 流した結果(新しい順): (節, 相手, ホームか, 自分の点, 相手の点)。
  final lines = <(int, int, bool, int, int)>[];
  int done = 0;
  bool fast = false;

  /// 1試合ごとの間(合わせて2.5秒ほどで流れきるように)。
  Duration get _gap => fast ? Duration.zero : Duration(milliseconds: (2500 / widget.n).clamp(25, 110).round());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _go());
  }

  Future<void> _go() async {
    final c = widget.c;
    final report = await c.simRounds(widget.n, stops: widget.stops, onRound: (games) async {
      final car = c.career!;
      for (final g in games) {
        lines.insert(0, (car.roundAt - 1, g.opponentOf(car.mine), g.home == car.mine, g.ptsOf(car.mine), g.ptsAgainst(car.mine)));
      }
      done++;
      if (mounted) setState(() {});
      if (_gap > Duration.zero) await Future<void>.delayed(_gap);
    });
    if (mounted) Navigator.of(context).pop(report);
  }

  @override
  Widget build(BuildContext context) {
    final car = widget.c.career!;
    final w = lines.where((l) => l.$4 > l.$5).length;
    final l = lines.length - w;
    final now = car.roundAt.clamp(0, gamesPerSeason - 1);
    return AlertDialog(
      key: const Key('sim-ticker'),
      title: Row(children: [
        // 進めているあいだ回る(画面が止まっていないことを示す)
        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5)),
        const SizedBox(width: 10),
        Expanded(child: Text(widget.title)),
        Text(dateLabel(roundDate(car.season, now)), style: const TextStyle(fontSize: 14, color: GmColors.gold)),
      ]),
      content: SizedBox(
        width: 480,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          LinearProgressIndicator(value: done / widget.n, minHeight: 6, borderRadius: BorderRadius.circular(3)),
          const SizedBox(height: 8),
          Text('$done/${widget.n}試合  この間 $w勝$l敗(通算 ${car.me.wins}勝${car.me.losses}敗)',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          SizedBox(
            height: 150,
            child: ListView(children: [
              for (final (r, opp, home, mine, theirs) in lines.take(12))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    SizedBox(width: 48, child: Text(dateShort(roundDate(car.season, r)), style: const TextStyle(fontSize: 12, color: GmColors.sub))),
                    SizedBox(width: 22, child: Text(home ? 'vs' : '@', style: const TextStyle(fontSize: 12, color: GmColors.sub))),
                    TeamBadge(team: opp, size: 18),
                    const SizedBox(width: 6),
                    Expanded(child: Text(car.teams[opp].def.short, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                    Text('${mine > theirs ? '勝' : '負'} $mine-$theirs',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: mine > theirs ? GmColors.good : GmColors.bad)),
                  ]),
                ),
            ]),
          ),
        ]),
      ),
      actions: [
        TextButton(key: const Key('sim-ticker-stop'), onPressed: () => widget.c.simCancel = true, child: const Text('ここで止める')),
        FilledButton(key: const Key('sim-ticker-fast'), onPressed: fast ? null : () => setState(() => fast = true), child: const Text('一気に進める')),
      ],
    );
  }
}
