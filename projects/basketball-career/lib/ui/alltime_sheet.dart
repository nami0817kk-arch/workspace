import 'package:flutter/material.dart';

import '../game/alltime.dart';
import '../game/game.dart';
import '../game/money.dart';

/// 歴代記録の表を下から出す(種目ごとのタブ。自分の行に色を付ける)。
void showAllTimeSheet(BuildContext context, Game game) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => AllTimeSheet(game: game),
  );
}

class AllTimeSheet extends StatelessWidget {
  const AllTimeSheet({super.key, required this.game});
  final Game game;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mine = game.allTimeValues;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: DefaultTabController(
          length: AllTimeStat.values.length,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text('歴代記録', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text('伝説の名選手たちの通算記録。抜くたびに順位が上がる。',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ),
              TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [for (final s in AllTimeStat.values) Tab(text: s.label)],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    for (final s in AllTimeStat.values)
                      _Table(stat: s, rows: allTimeTable(s, mine[s]!, game.player.name)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.stat, required this.rows});
  final AllTimeStat stat;
  final List<AllTimeRow> rows;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final me = rows.firstWhere((r) => r.me);
    final next = nextLegend(stat, me.value);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        Text(
          next == null
              ? 'あなたが歴代1位。'
              : 'いま歴代${me.rank}位。${next.name}まで あと${withComma(next.value - me.value + 1)}${stat.unit}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        for (final r in rows)
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: r.me ? cs.primaryContainer : cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: r.me ? Border.all(color: cs.primary, width: 1.5) : null,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text('${r.rank}位',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: r.rank <= 3 ? const Color(0xFFB26A00) : null)),
                ),
                Expanded(
                  child: Text(r.me ? '${r.name}(あなた)' : r.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: r.me ? FontWeight.bold : FontWeight.normal)),
                ),
                Text('${withComma(r.value)}${stat.unit}',
                    style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
              ],
            ),
          ),
      ],
    );
  }
}
