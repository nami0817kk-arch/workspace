import 'package:flutter/material.dart';

import '../../gm/career.dart';
import '../../gm/league.dart';
import '../../gm/player.dart';
import '../gm_controller.dart';
import '../layout.dart';
import 'common.dart';
import 'style.dart';

/// 段階の言葉。
const coachLevelLabels = ['並', '良い', '一流'];

/// コーチ陣。役ごとの今のコーチと、雇える候補。入れ替えはシーズン前とオフの契約のときだけ。
class CoachesScreen extends StatelessWidget {
  const CoachesScreen({super.key, required this.c});
  final GmController c;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          final car = c.career!;
          final me = car.me;
          return Scaffold(
            appBar: AppBar(title: const Text('コーチ陣')),
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth(context, phone: 620)),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 4),
                        child: Text(
                            '給料の合計 1シーズン ${money(me.staffCost)}(収支の支出に入る)。'
                            '${car.canChangeStaff ? '替えると、今のコーチに給料の半年分を払う。' : '入れ替えはシーズン前とオフの契約のときだけ。'}',
                            style: const TextStyle(fontSize: 12, color: GmColors.sub, height: 1.4)),
                      ),
                      for (final s in Staff.values) ...[
                        SectionTitle('${s.label}・${s.effect}'),
                        _current(me, s),
                        if (car.canChangeStaff)
                          for (var i = 0; i < car.coachPool.length; i++)
                            if (car.coachPool[i].role == s) _candidate(context, car, i),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );

  Widget _current(Team me, Staff s) {
    final k = me.coachOf(s);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: k == null
            ? Text('${coachLevelLabels[me.staffLevel(s) - 1]}(${money(staffCosts[me.staffLevel(s) - 1])})')
            : Row(children: [
                _rating(k.rating),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(k.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('${coachLevelLabels[k.level - 1]}・${_effect(s, k)}・${money(k.salary)}',
                        maxLines: 2, style: const TextStyle(fontSize: 12, color: GmColors.sub)),
                  ]),
                ),
              ]),
      ),
    );
  }

  Widget _candidate(BuildContext context, Career car, int i) {
    final k = car.coachPool[i];
    final now = car.me.coachOf(k.role);
    final better = now == null || k.rating > now.rating;
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 4),
      child: Row(children: [
        const Icon(Icons.subdirectory_arrow_right_rounded, size: 18, color: GmColors.sub),
        const SizedBox(width: 4),
        _rating(k.rating, size: 30),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(k.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            Text('${coachLevelLabels[k.level - 1]}・${money(k.salary)}', style: TextStyle(fontSize: 12, color: better ? GmColors.good : GmColors.sub)),
          ]),
        ),
        TextButton(
          onPressed: c.busy ? null : () => _hire(context, car, i),
          child: const Text('雇う'),
        ),
      ]),
    );
  }

  Future<void> _hire(BuildContext context, Career car, int i) async {
    final k = car.coachPool[i];
    final now = car.me.coachOf(k.role);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${k.name}を${k.role.label}に?'),
        content: Text('力 ${k.rating}・1シーズン ${money(k.salary)}。'
            '${now == null ? '' : '\n今の${now.name}は辞め、違約金 ${money(car.buyoutOf(k.role))}を払う。'}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('やめる')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('雇う')),
        ],
      ),
    );
    if (ok == true) c.hireCoach(i);
  }

  /// 役ごとの効き目を、力に合わせて言う。
  String _effect(Staff s, Coach k) => switch (s) {
        Staff.coach => '戦力 ${k.rating >= 70 ? '+' : ''}${((k.rating - 70) * 0.03).toStringAsFixed(2)}',
        Staff.trainer => k.level == 3 ? 'けががかなり少ない' : k.level == 2 ? 'けがはふつう' : 'けがが多め',
        Staff.scout => 'スカウト ${1 + k.level}回',
        Staff.development => k.level == 3 ? '若手がよく伸び、重点は+3' : k.level == 2 ? '若手の伸びはふつう' : '若手が伸びにくい',
      };

  Widget _rating(int v, {double size = 40}) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: GmColors.panelHi, borderRadius: BorderRadius.circular(size / 4)),
        child: Text('$v',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: size * 0.42,
                color: v >= 80
                    ? GmColors.gold
                    : v >= 65
                        ? GmColors.ball
                        : GmColors.sub)),
      );
}
