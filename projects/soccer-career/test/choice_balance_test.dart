/// **どの選択表にも、全項目で劣る選択肢を置かない。**
///
/// 効きは画面に出るので、全部の項目で劣る手は読めば絶対に選ばない。
/// 3つ並べても1つが死んでいれば、それは2択。
///
/// **重みは付けない。** 通貨の違うもの（伸びと怪我と消耗）を足すと、
/// 重みの付け方しだいでどうにでもなる。全部の項目で劣るかだけを見る。
///
/// この検査が効くには、**選択肢の値打ちがその選択肢に書いてある**必要がある。
/// 2026-09-24 に2件見つかった:
/// - `TrainingMenu.rest` の疲労抜けが `CareerController` の名指し比較にあり、
///   表の上では「休養」が「リカバリー」に全項目で劣って見えていた。
/// - `TrainingCompanion` の呼吸・プロ意識・立場が
///   `_applyCompanion` の switch にあり、「相方と組む」が
///   「メンターに付く」に劣って見えていた。
/// どちらも enum に持たせ直した（`fatigueRelief` / `synergyGain` /
/// `professionalismChance` / `teammatesGain`）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/entourage.dart';
import 'package:soccer_career/models/life.dart';
import 'package:soccer_career/models/promise.dart';
import 'package:soccer_career/models/training.dart';

/// 重み無しの支配関係。全項目で劣る（少なくとも1つは厳密に劣る）か。
bool dom(Map<String, num> a, Map<String, num> b) {
  var strict = false;
  for (final k in {...a.keys, ...b.keys}) {
    final x = a[k] ?? 0;
    final y = b[k] ?? 0;
    if (x > y) return false;
    if (x < y) strict = true;
  }
  return strict;
}

void check<T>(
  String name,
  List<T> items,
  String Function(T) label,
  Map<String, num> Function(T) axes,
) {
  final dead = <String>[];
  for (final a in items) {
    for (final b in items) {
      if (a == b) continue;
      if (dom(axes(a), axes(b))) {
        dead.add('${label(a)} < ${label(b)}');
        break;
      }
    }
  }
  expect(dead, isEmpty, reason: '$name: ${dead.join(' / ')}');
}

void main() {
  test('選択表に、全項目で劣る選択肢が無い', () {
    check<Offseason>(
      'Offseason',
      Offseason.values,
      (o) => o.label,
      (o) => {
        'condition': o.condition,
        'fatigue': -o.fatigue,
        'growth': o.growthFactor,
        'injury': -o.injuryFactor,
        'fame': o.fame,
      },
    );
    check<TrainingEffort>(
      'TrainingEffort',
      TrainingEffort.values,
      (e) => e.label,
      (e) => {
        'great': e.great,
        'flat': -e.flat,
        'cost': -e.cost,
        'injury': -e.injury,
        'strain': -e.strain,
      },
    );
    check<TrainingMenu>(
      'TrainingMenu',
      TrainingMenu.values,
      (m) => m.label,
      (m) => {
        'cost': -m.conditionCost,
        'recovery': m.recovery,
        'fatigue': m.fatigueRelief,
        'injury': -m.injuryFactor,
        'weakFoot': m.weakFoot ? 1 : 0,
        for (final k in m.keys) 'grow:${k.name}': m.growthFactor,
      },
    );
    check<TrainingCompanion>(
      'TrainingCompanion',
      TrainingCompanion.values,
      (c) => c.label,
      (c) => {
        'great': c.greatBonus,
        'flat': c.flatRelief,
        'strain': -c.strainShift,
        'cost': -c.cost,
        'injury': -c.injury,
        'synergy': c.synergyGain,
        'professionalism': c.professionalismChance,
        'teammates': c.teammatesGain,
      },
    );
    check<PromiseWeight>(
      'PromiseWeight',
      PromiseWeight.values,
      (p) => p.label,
      (p) => {
        'trustKept': p.trustKept,
        'trustBroken': p.trustBroken,
        'salaryKept': p.salaryKept,
        'salaryBroken': p.salaryBroken,
      },
    );
    check<RehabPlan>(
      'RehabPlan',
      RehabPlan.values,
      (r) => r.label,
      (r) => {
        'length': -r.lengthFactor,
        'relapse': -r.relapseFactor,
        'damage': -r.damageFactor,
        'decline': -r.declineYears,
      },
    );
    check<Directive>(
      'Directive',
      Directive.values,
      (d) => d.label,
      (d) => {
        'growth': d.growthFactor,
        'appearance': d.appearanceBonus,
        'salary': d.salaryFactor,
        'synergy': d.synergyFactor,
        'reachBonus': d.reachBonus,
      },
    );
    check<Agent>(
      'Agent',
      Agent.pool,
      (a) => a.name,
      (a) => {
        'reach': a.reach,
        'negotiation': a.negotiation,
        'fee': -a.feePercent,
      },
    );
  });
}
