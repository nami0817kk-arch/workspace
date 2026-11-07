import 'package:flutter/material.dart';

import '../../gm/league.dart';
import '../../gm/player.dart';
import '../gm_controller.dart';
import '../layout.dart';
import 'common.dart';
import 'style.dart';

/// 出場時間を選手ごとに決める。合計は240分(5人×48分)。36分を超えると疲れて力が落ち、けがもしやすい。
/// 期待より少ない選手は気持ちが下がる。
class MinutesScreen extends StatefulWidget {
  const MinutesScreen({super.key, required this.c});
  final GmController c;

  @override
  State<MinutesScreen> createState() => _MinutesScreenState();
}

class _MinutesScreenState extends State<MinutesScreen> {
  late final List<Player> _order = widget.c.career!.me.order;
  late final Map<int, int> _m = () {
    final now = widget.c.career!.me.playMinutes();
    return {for (var i = 0; i < _order.length; i++) _order[i].id: now[i]};
  }();

  int get _total => _m.values.fold(0, (a, b) => a + b);

  /// この時間にしたときの戦力(チームの時間を一時的に入れ替えて数える)。
  double _strengthWith(Team t, Map<int, int> m) {
    final old = t.minutes;
    t.minutes = m;
    final s = t.strength;
    t.minutes = old;
    return s;
  }

  void _add(Player p, int d) => setState(() => _m[p.id] = ((_m[p.id] ?? 0) + d).clamp(0, maxMinutes));

  @override
  Widget build(BuildContext context) {
    final car = widget.c.career!;
    final me = car.me;
    final total = _total;
    final now = _strengthWith(me, Map.of(_m));
    final auto = _strengthWith(me, const {});
    return Scaffold(
      appBar: AppBar(title: const Text('出場時間')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxWidth(context, phone: 620)),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('合計は240分(5人×48分)。$fatigueLine分を超えると疲れて力が落ち、けがもしやすい。期待より少ない選手は気持ちが下がる。',
                      style: TextStyle(color: GmColors.sub, height: 1.4)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Text('合計 $total / $totalMinutes分',
                        style: TextStyle(fontWeight: FontWeight.bold, color: total == totalMinutes ? GmColors.good : GmColors.bad)),
                    const Spacer(),
                    Text('戦力 ${now.toStringAsFixed(1)}(自動 ${auto.toStringAsFixed(1)})',
                        style: TextStyle(fontWeight: FontWeight.bold, color: now + 0.05 >= auto ? GmColors.good : GmColors.gold)),
                  ]),
                ]),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  children: [
                    for (var i = 0; i < _order.length; i++) _row(car.expectedMinutes(_order[i]), _order[i], i < 5),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        widget.c.setMinutes(const {});
                        Navigator.pop(context);
                      },
                      child: const Text('自動に戻す'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: total != totalMinutes
                          ? null
                          : () {
                              widget.c.setMinutes(Map.of(_m));
                              Navigator.pop(context);
                            },
                      child: Text(total == totalMinutes
                          ? 'この時間にする'
                          : total < totalMinutes
                              ? 'あと${totalMinutes - total}分'
                              : '${total - totalMinutes}分多い'),
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

  Widget _row(int expected, Player p, bool starter) {
    final m = _m[p.id] ?? 0;
    final tired = m > fatigueLine;
    final short = m <= expected - 6 && expected >= 8;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
        child: Row(children: [
          OvrBadge(p.ovr, size: 36),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(
                p.injured > 0
                    ? 'けがで出られない'
                    : '${starter ? '先発' : '控え'}・${p.pos.short}・期待 $expected分${tired ? '・疲れる' : short ? '・不満が出る' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: tired || short ? GmColors.bad : GmColors.sub),
              ),
            ]),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: m <= 0 || p.injured > 0 ? null : () => _add(p, -2),
            icon: const Icon(Icons.remove_circle_outline_rounded),
          ),
          SizedBox(
            width: 40,
            child: Text('$m分',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: tired ? GmColors.bad : null)),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: m >= maxMinutes || p.injured > 0 ? null : () => _add(p, 2),
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ]),
      ),
    );
  }
}
