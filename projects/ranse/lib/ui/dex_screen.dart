import 'package:flutter/material.dart';

import '../app/controller.dart';
import '../app/save.dart';
import '../engine/ways.dart';
import 'theme.dart';
import 'widgets.dart';

/// 最期の図鑑。見た最期を、歩んだ道ごとに並べて読み返せる。
/// まだ見ていない道は、席だけ見える。
class DexScreen extends StatelessWidget {
  const DexScreen(this.c, {super.key});
  final AppController c;

  @override
  Widget build(BuildContext context) {
    final byWay = <String, List<DexEntry>>{};
    for (final e in c.dexEntries.values) {
      byWay.putIfAbsent(e.way, () => []).add(e);
    }
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: c.toTitle,
                  icon: const Icon(Icons.arrow_back, color: Pal.ink),
                ),
                const Text(
                  '最期の図鑑',
                  style: TextStyle(fontSize: 20, letterSpacing: 4),
                ),
                const Spacer(),
                Text(
                  '見た最期 ${c.dexCount} 種',
                  style: const TextStyle(color: Pal.gold, fontSize: 14),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (c.dexEntries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      'まだ一つの最期も見ていない。\n籤を引き、一つの生を生き切ると、その最期がここに記される。',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Pal.muted, height: 1.8),
                    ),
                  ),
                for (final w in kWays.keys) ...[
                  const SizedBox(height: 10),
                  Panel(
                    title: '${kWays[w]!.$1}　${byWay[w]?.length ?? 0}',
                    child: (byWay[w] ?? []).isEmpty
                        ? const Text(
                            '？？？　まだ見ていない',
                            style: TextStyle(color: Pal.muted),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [for (final e in byWay[w]!) _DexTile(e)],
                          ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DexTile extends StatelessWidget {
  const _DexTile(this.e);
  final DexEntry e;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 10),
        iconColor: Pal.gold,
        collapsedIconColor: Pal.muted,
        title: Text(
          e.title,
          style: const TextStyle(color: Pal.gold, fontSize: 15, height: 1.4),
        ),
        subtitle: Text(
          '${e.name}・${e.age}歳（${e.year}年）${e.count > 1 ? '　ほか${e.count - 1}回' : ''}',
          style: const TextStyle(color: Pal.muted, fontSize: 12),
        ),
        children: [
          Text(e.text, style: const TextStyle(fontSize: 14, height: 1.8)),
        ],
      ),
    );
  }
}
