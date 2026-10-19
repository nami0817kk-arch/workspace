import 'package:flutter/material.dart';

import '../game/characters.dart';
import '../game/game.dart';
import 'labels.dart';

/// 画面をまたいで使う小さな部品。

/// 能力のランク(G〜S)の丸いバッジ。
class RankBadge extends StatelessWidget {
  const RankBadge({super.key, required this.value});
  final int value;

  @override
  Widget build(BuildContext context) {
    final r = rankOf(value);
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: rankColor(r), shape: BoxShape.circle),
      child: Text(r,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }
}

class CastCard extends StatelessWidget {
  const CastCard({super.key, required this.game, this.expanded = false});
  final Game game;

  /// 最初から開いておく(関係タブ)。
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final cast = game.cast;
    final rows = <Character>[
      if (cast.rival != null) cast.rival!,
      if (cast.lover != null) cast.lover!,
      if (cast.family != null) cast.family!,
      if (cast.coach != null) cast.coach!,
      ...cast.teammates,
    ];
    return Card(
      child: ExpansionTile(
        initiallyExpanded: expanded,
        shape: const Border(),
        collapsedShape: const Border(),
        title: const Text('まわりの人たち'),
        children: [
          for (final m in rows)
            ListTile(
              dense: true,
              title: Text('${m.name}  (${m.kind.label})'),
              subtitle: Text(_sub(m)),
              trailing: SizedBox(
                width: 80,
                child: LinearProgressIndicator(
                    value: m.kind == Kind.coach
                        ? (m.tips / tipsNeeded).clamp(0.0, 1.0)
                        : m.bond / 100),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('ライバルとの対戦: ${cast.rivalWins}勝 ${cast.rivalLosses}敗'),
          ),
        ],
      ),
    );
  }

  String _sub(Character m) => switch (m.kind) {
        Kind.teammate =>
          '得意: ${m.specialty == null ? '-' : abilityLabel(m.specialty!)}',
        Kind.coach => m.teaches == null
            ? 'コツ ${m.tips}/$tipsNeeded'
            : 'コツ ${m.tips}/$tipsNeeded → ${m.teaches!.label}',
        Kind.rival => '強さの目安 ${rivalLevel(m, game.player.age).round()}',
        _ => '絆 ${m.bond}',
      };
}
