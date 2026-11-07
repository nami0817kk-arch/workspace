import 'package:flutter/material.dart';

import '../../gm/career.dart';
import '../../gm/player.dart';
import '../gm_controller.dart';
import '../layout.dart';
import 'common.dart';
import 'style.dart';

/// 練習。チームの練習の強さと、選手ごとの重点(オフに伸ばす能力)を決める。
class TrainingScreen extends StatelessWidget {
  const TrainingScreen({super.key, required this.c});
  final GmController c;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          final car = c.career!;
          final me = car.me;
          return Scaffold(
            appBar: AppBar(title: const Text('練習')),
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth(context, phone: 620)),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                    children: [
                      const SectionTitle('練習の強さ'),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Wrap(spacing: 8, children: [
                              for (var i = 0; i < trainingLabels.length; i++)
                                ChoiceChip(
                                  label: Text(trainingLabels[i]),
                                  selected: me.training == i,
                                  onSelected: c.busy ? null : (_) => c.setTraining(i),
                                ),
                            ]),
                            const SizedBox(height: 8),
                            Text(me.training == 1 ? 'けがと伸びは、ふだんどおり。' : trainingNotes[me.training],
                                style: const TextStyle(color: GmColors.sub, height: 1.4)),
                          ]),
                        ),
                      ),
                      const SectionTitle('選手ごとの重点'),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text('オフに、重点の能力が伸びる(ほかの能力が1つ少し落ちる)。OVR は変わらず、試合の数字とバッジに効く。',
                            style: TextStyle(fontSize: 12, color: GmColors.sub, height: 1.4)),
                      ),
                      for (final p in me.order) _row(car, p),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );

  Widget _row(Career car, Player p) => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(children: [
            OvrBadge(p.ovr),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${p.pos.short}・${p.age}歳・${p.focus == null ? '得意 ${_best(p).label}' : '${p.focus!.label} ${shown(p.attr(p.focus!))}'}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: GmColors.sub)),
              ]),
            ),
            DropdownButton<int>(
              value: p.focus?.index ?? -1,
              underline: const SizedBox.shrink(),
              items: [
                const DropdownMenuItem(value: -1, child: Text('重点なし')),
                for (final a in Attr.values) DropdownMenuItem(value: a.index, child: Text(a.label)),
              ],
              onChanged: c.busy ? null : (v) => c.setFocus(p.id, v == null || v < 0 ? null : Attr.values[v]),
            ),
          ]),
        ),
      );

  Attr _best(Player p) => Attr.values.reduce((a, b) => p.attr(a) >= p.attr(b) ? a : b);
}
