import 'package:flutter/material.dart';

import '../../gm/player.dart';
import '../../gm/league.dart';
import '../../gm/policy.dart';
import '../gm_controller.dart';
import '../layout.dart';
import 'common.dart';
import 'style.dart';

/// チームの方針。5つの軸を3択で決める。選手の持ち味に合う方針は、強さに最大 +1.5 まで足される。
class PolicyScreen extends StatelessWidget {
  const PolicyScreen({super.key, required this.c});
  final GmController c;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          final car = c.career!;
          final me = car.me;
          final hc = me.coachOf(Staff.coach);
          final fav = hc == null ? null : coachFavorite(hc);
          final top = [...me.healthy]..sort((a, b) => b.ovr.compareTo(a.ovr));
          return Scaffold(
            appBar: AppBar(title: const Text('チームの方針')),
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth(context, phone: 620)),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                            '方針が選手の持ち味に合うほど、チームが強くなる(最大 +1.5)。合わない方針は逆に下げる。「ふつう」は何も変えない。'
                            'ヘッドコーチの得意と同じ選択は、少し上乗せされる。\n今の上乗せ: ${me.policyEffect >= 0 ? '+' : ''}${me.policyEffect.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 12, color: GmColors.sub, height: 1.5)),
                      ),
                      for (final axis in PolicyAxis.values) ...[
                        SectionTitle(axis.label),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              Wrap(spacing: 8, children: [
                                for (var i = 0; i < 3; i++)
                                  ChoiceChip(
                                    label: Text(axis.options[i] + (fav != null && fav[axis.index] == i ? '(HCの得意)' : '')),
                                    selected: me.policy[axis.index] == i,
                                    onSelected: c.busy ? null : (_) => c.setPolicy(axis.index, i),
                                  ),
                              ]),
                              const SizedBox(height: 6),
                              Text(_note(axis, me.policy[axis.index], top),
                                  style: const TextStyle(fontSize: 12, color: GmColors.sub, height: 1.4)),
                            ]),
                          ),
                        ),
                      ],
                      const SectionTitle('選手の合い方'),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 6),
                        child: Text('◎ 合う ○ ふつう △ 合わない(「ふつう」以外を選んだ軸で見る)。', style: TextStyle(fontSize: 12, color: GmColors.sub)),
                      ),
                      for (final p in me.order)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(children: [
                            SizedBox(width: 28, child: Text(fitMark(p, me.policy), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                            Expanded(child: Text('${p.name}(${p.pos.label}・OVR ${shown(p.ovr)})', maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ]),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );

  String _note(PolicyAxis axis, int choice, List top) {
    if (choice == 1) return 'ふつう。強さは変わらない。';
    final fit = teamAxisFit(List.from(top), axis, choice);
    final word = fit >= 0.25 ? '今のメンバーによく合う' : fit <= -0.25 ? '今のメンバーには合わない' : '今のメンバーには、そこそこ';
    return '$word(${fit >= 0 ? '+' : ''}${(fit * 0.3).toStringAsFixed(2)})。';
  }
}
