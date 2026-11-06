import 'package:flutter/material.dart';

import '../../gm/league.dart';
import '../../gm/player.dart';
import '../gm_controller.dart';
import '../layout.dart';
import 'common.dart';
import 'style.dart';

/// 先発と控えの順を決める。上から順に出場時間が長い。力の低い選手を先発にするとチームは弱くなり、
/// 出番の減った選手は気持ちが下がる。
class RotationScreen extends StatefulWidget {
  const RotationScreen({super.key, required this.c});
  final GmController c;

  @override
  State<RotationScreen> createState() => _RotationScreenState();
}

class _RotationScreenState extends State<RotationScreen> {
  late final List<Player> _order = [...widget.c.career!.me.order];

  @override
  Widget build(BuildContext context) {
    final car = widget.c.career!;
    final now = orderStrength(_order);
    final auto = teamStrength(car.me.roster);
    return Scaffold(
      appBar: AppBar(title: const Text('先発と控えの順')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxWidth(context, phone: 620)),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('長押しして上下に動かす。上の5人が先発。上ほど出場時間が長い。',
                      style: TextStyle(color: GmColors.sub, height: 1.4)),
                  const SizedBox(height: 6),
                  Text('この順の戦力 ${now.toStringAsFixed(1)}(自動なら ${auto.toStringAsFixed(1)})',
                      style: TextStyle(fontWeight: FontWeight.bold, color: now + 0.05 >= auto ? GmColors.good : GmColors.gold)),
                ]),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  itemCount: _order.length,
                  onReorderItem: (from, to) => setState(() => _order.insert(to, _order.removeAt(from))),
                  itemBuilder: (context, i) {
                    final p = _order[i];
                    final mins = i < minutesByOrder.length ? minutesByOrder[i] : 0;
                    return Padding(
                      key: ValueKey(p.id),
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(children: [
                        SizedBox(
                          width: 44,
                          child: Column(children: [
                            Text(i < 5 ? '先発' : '控え', style: TextStyle(fontSize: 11, color: i < 5 ? GmColors.ball : GmColors.sub)),
                            Text('$mins分', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ]),
                        ),
                        Expanded(child: PlayerRow(p: p, team: car.mine, showMorale: true)),
                      ]),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        widget.c.setRotation(const []);
                        Navigator.pop(context);
                      },
                      child: const Text('自動に戻す'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        widget.c.setRotation([for (final p in _order) p.id]);
                        Navigator.pop(context);
                      },
                      child: const Text('この順にする'),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
