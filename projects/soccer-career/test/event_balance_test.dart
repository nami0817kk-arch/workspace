/// **出来事の三択に、全項目で劣る選択肢を置かない。**
///
/// 効きは画面に出る（`LifeEffect.summary`）ので、全部の項目で劣る手は
/// **読めば絶対に選ばない**。三択のうち1つが死んでいれば、それは二択。
/// 実測（2026-09-24）では **48件中11件**にそれがあった。
///
/// 重みは付けない。通貨の違うもの（気持ちと金と疲労）を足して比べると、
/// 重みの付け方しだいでどうにでもなる。**全部の項目で劣るか**だけを見る。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/life_events.dart';
import 'package:soccer_career/models/life_event.dart';

/// 効きを項目ごとに並べる。重みは付けない（通貨が違うものを足すと嘘になる）。
/// 値が大きいほど良い向きに揃える。
Map<String, num> _axes(LifeEffect e) => {
  'morale': e.morale,
  'fame': e.fame,
  'manager': e.manager,
  'teammates': e.teammates,
  'money': e.money,
  'condition': e.condition,
  'fatigue': -e.fatigue,
  'confidence': e.confidence,
  'ambition': e.ambition,
  'professionalism': e.professionalism,
  'temper': -e.temper,
  // **伸びる能力は、能力ごとに別の軸にする。**
  // まとめて「伸び1」にすると、違う能力を伸ばす手が同じに見えて、
  // 片方が「同じ伸びで疲れるだけ」に化ける。
  if (e.train != null) 'train:${e.train!.name}': e.trainAmount,
  if (e.insight != null) 'insight:${e.insight!.name}': 1,
  if (e.special != LifeSpecial.none) 'special:${e.special.name}': 1,
};

/// a は b に全項目で劣る（少なくとも1項目は厳密に劣る）か。
bool _dominatedBy(LifeEffect a, LifeEffect b) {
  final x = _axes(a);
  final y = _axes(b);
  final keys = {...x.keys, ...y.keys};
  var strict = false;
  for (final k in keys) {
    final xv = x[k] ?? 0;
    final yv = y[k] ?? 0;
    if (xv > yv) return false;
    if (xv < yv) strict = true;
  }
  return strict;
}

void main() {
  test('全項目で劣る選択肢が無い', () {
    final dead = <String>[];
    for (final event in LifeEvents.catalogue) {
      if (event.choices.length < 2) continue;
      for (final a in event.choices) {
        for (final b in event.choices) {
          if (identical(a, b)) continue;
          if (_dominatedBy(a.effect, b.effect)) {
            dead.add('${event.id}: 「${a.label}」は「${b.label}」に全項目で劣る');
            break;
          }
        }
      }
    }
    expect(dead, isEmpty, reason: dead.join('\n'));
  });

  test('効きの数字は小さいままにする', () {
    // ここが大きいと、試合でも練習でもなく「出来事の引き」でキャリアが決まる。
    for (final event in LifeEvents.catalogue) {
      for (final choice in event.choices) {
        final e = choice.effect;
        expect(e.trainAmount, lessThanOrEqualTo(2), reason: event.id);
        expect(e.confidence.abs(), lessThanOrEqualTo(2), reason: event.id);
        expect(e.ambition.abs(), lessThanOrEqualTo(2), reason: event.id);
        expect(e.professionalism.abs(), lessThanOrEqualTo(2), reason: event.id);
        expect(e.temper.abs(), lessThanOrEqualTo(2), reason: event.id);
      }
    }
  });
}
