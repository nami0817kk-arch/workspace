import 'package:flutter/material.dart';

import '../../gm/career.dart';
import '../../gm/profile.dart';
import 'style.dart';

/// GM の名鑑(2026-11-21 の作り込み D-1)。任期ごとの札・育てた名選手の殿堂・名場面の年表。任期をまたいで残る。見返すためだけ。
class LegacyScreen extends StatelessWidget {
  const LegacyScreen({super.key, required this.profile, this.career});
  final Profile profile;
  final Career? career;

  @override
  Widget build(BuildContext context) {
    final c = career;
    if (c != null) profile.recordLegacy(c);
    final all = profile.legacy.entries.toList().reversed.toList();
    const head = TextStyle(fontWeight: FontWeight.bold, fontSize: 15);
    return Scaffold(
      appBar: AppBar(title: const Text('GMの名鑑')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
          children: [
            const Text('これまでの任期・育てた名選手・名場面。クビになっても、始め直しても消えない。', style: TextStyle(fontSize: 12, color: GmColors.sub)),
            if (all.isEmpty) const Padding(padding: EdgeInsets.only(top: 16), child: Text('まだ記録が無い。', style: TextStyle(color: GmColors.sub))),
            for (final (k, e) in all.indexed) ...[
              const SizedBox(height: 14),
              Text(k == 0 && c != null && c.seed == e.key ? 'いまの任期' : '前の任期', style: head),
              for (final t in e.value.tenures)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${t.team}  ${t.from}〜${t.to}年目${t.titles > 0 ? '・優勝${t.titles}回' : ''}・${t.fired ? '解任' : '勇退/続投'}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: t.titles > 0 ? GmColors.gold : GmColors.text)),
                      if (t.wins.isNotEmpty) Text('勝ち数の流れ: ${t.wins.join(' → ')}', style: const TextStyle(fontSize: 12, color: GmColors.sub)),
                    ]),
                  ),
                ),
              if (e.value.legends.isNotEmpty) ...[
                const SizedBox(height: 4),
                const Text('育てた名選手', style: TextStyle(fontSize: 12.5, color: GmColors.sub, fontWeight: FontWeight.bold)),
                for (final l in e.value.legends)
                  Text('${l.name}(${l.pos})  通算${l.pts}点・自分のチームで${l.seasons}季・${l.note}${l.best.isEmpty ? '' : '・いちばんの年 ${l.best}'}',
                      style: const TextStyle(fontSize: 12.5, height: 1.5)),
              ],
              if (e.value.moments.isNotEmpty) ...[
                const SizedBox(height: 4),
                const Text('名場面', style: TextStyle(fontSize: 12.5, color: GmColors.sub, fontWeight: FontWeight.bold)),
                for (final m in e.value.moments) Text('・$m', style: const TextStyle(fontSize: 12.5, height: 1.5)),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
