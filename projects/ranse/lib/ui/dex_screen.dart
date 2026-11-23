import 'package:flutter/material.dart';

import '../app/controller.dart';
import '../app/save.dart';
import '../engine/ending.dart';
import '../engine/endings_catalog.dart';
import '../engine/ways.dart';
import 'theme.dart';
import 'widgets.dart';

/// 図鑑の鍵（`hand:<id>`）から手書きの最期を引く表。
final Map<String, EndingDef> _defByKey = {
  for (final d in kHandEndings) 'hand:${d.id}': d,
};

/// 最期の図鑑。見た最期を、歩んだ道ごとに並べて読み返せる。
/// まだ見ていない道は、席だけ見える。希少度ごとに、見た数と全体の数を出す。
class DexScreen extends StatelessWidget {
  const DexScreen(this.c, {super.key});
  final AppController c;

  @override
  Widget build(BuildContext context) {
    final byWay = <String, List<DexEntry>>{};
    for (final e in c.dexEntries.values) {
      byWay.putIfAbsent(e.way, () => []).add(e);
    }
    // 珍しいものを上に。同じ希少度の中では、見た順のまま。
    for (final l in byWay.values) {
      l.sort(
        (a, b) => (_defByKey[b.key]?.tier.index ?? -1).compareTo(
          _defByKey[a.key]?.tier.index ?? -1,
        ),
      );
    }
    final seenTier = {for (final t in Tier.values) t: 0};
    final allTier = {for (final t in Tier.values) t: 0};
    for (final d in kHandEndings) {
      allTier[d.tier] = allTier[d.tier]! + 1;
      if (c.dexEntries.containsKey('hand:${d.id}')) {
        seenTier[d.tier] = seenTier[d.tier]! + 1;
      }
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
                  '見た最期 ${c.dexCount} ／ ${kHandEndings.length}',
                  style: const TextStyle(color: Pal.gold, fontSize: 14),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    for (final t in Tier.values.reversed)
                      Text(
                        '${_tierShort[t]} ${seenTier[t]} ／ ${allTier[t]}',
                        key: ValueKey('dex-tier-${t.name}'),
                        style: TextStyle(color: _tierColor(t), fontSize: 13),
                      ),
                  ],
                ),
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
                    title:
                        '${kWays[w]!.$1}　${byWay[w]?.length ?? 0} ／ ${kHandEndings.where((e) => e.way == w).length}',
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

const _tierShort = {
  Tier.common: 'よくある',
  Tier.uncommon: '珍しい',
  Tier.rare: '稀',
  Tier.phantom: '幻',
};

Color _tierColor(Tier t) => switch (t) {
  Tier.phantom => Pal.gold,
  Tier.rare => Pal.ink,
  _ => Pal.muted,
};

class _DexTile extends StatelessWidget {
  const _DexTile(this.e);
  final DexEntry e;

  @override
  Widget build(BuildContext context) {
    final tier = _defByKey[e.key]?.tier;
    // 色付きの枠の中に置くので、押したときの波紋が見えるよう透明な Material で包む。
    return Material(
      type: MaterialType.transparency,
      child: Theme(
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
            '${tier == null ? '' : '${kTierNames[tier]}　'}${e.name}・${e.age}歳（${e.year}年）${e.count > 1 ? '　ほか${e.count - 1}回' : ''}',
            style: const TextStyle(color: Pal.muted, fontSize: 12),
          ),
          children: [
            Text(e.text, style: const TextStyle(fontSize: 14, height: 1.8)),
          ],
        ),
      ),
    );
  }
}
