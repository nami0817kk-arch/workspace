// 行動の連携(2026-10-28 ユーザー「育成時のコマンドでやりがいを増やしたい」)。
import 'dart:convert';
import 'dart:math';

import 'package:baseball_manager/game/combo.dart';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:flutter_test/flutter_test.dart';

/// 出来事が出ていたら先頭を選んで、行動を選べる状態に戻す。
void _settle(Game g) {
  while (g.phase == Phase.event) {
    g.resolveEvent(0);
  }
}

/// `first` のあとに `second` を選ぶ。1つ目で怪我をしない種を探す。
Game _pair(Plan first, Plan second,
    {Ability f1 = Ability.contact, Ability f2 = Ability.contact}) {
  for (var s = 1; s < 200; s++) {
    final g = Game.newGame(
        name: 'れ', role: Role.batter, rng: Random(s), potential: 60);
    g.choose(first, f1);
    _settle(g);
    if (g.condition.injured || g.phase != Phase.term) continue;
    g.choose(second, f2);
    return g;
  }
  throw StateError('怪我をしない種が見つからない');
}

void main() {
  test('連携は行動の組み合わせで決まり、同じ行動の繰り返しでは起きない', () {
    expect(comboOf(Plan.study, Plan.train), Combo.insight);
    expect(comboOf(Plan.study, Plan.special), Combo.insight);
    expect(
        comboOf(Plan.lesson, Plan.train,
            prevFocus: Ability.power, focus: Ability.power),
        Combo.drill);
    expect(
        comboOf(Plan.lesson, Plan.train,
            prevFocus: Ability.power, focus: Ability.contact),
        isNull,
        reason: '教わった能力と違う能力の練習では起きない');
    expect(comboOf(Plan.special, Plan.rest), Combo.recovery);
    expect(comboOf(Plan.match, Plan.study), Combo.homework);
    expect(comboOf(Plan.social, Plan.special), Combo.cheer);
    for (final p in Plan.values) {
      expect(comboOf(p, p, prevFocus: Ability.contact, focus: Ability.contact),
          isNull,
          reason: '${p.name} の繰り返し');
    }
    expect(comboOf(Plan.rest, Plan.train), isNull, reason: '練習と休養だけでは起きない');
    expect(comboOf(null, Plan.train), isNull);
  });

  test('失敗の倍率0なら、練習の出来は失敗にならない(乱数の使い方は同じ)', () {
    final a = Random(3), b = Random(3);
    for (var i = 0; i < 2000; i++) {
      final o = rollOutcome(Plan.special, a, const {}, 0.0);
      expect(o, isNot(Outcome.bad));
      rollOutcome(Plan.special, b);
    }
    expect(a.nextInt(1 << 30), b.nextInt(1 << 30));
  });

  test('研究のあとの練習は「研究の成果」で経験点が増え、ログと回数に残る', () {
    final g = _pair(Plan.study, Plan.train);
    expect(g.lastCombo, Combo.insight);
    expect(g.log.any((l) => l.startsWith('連携「研究の成果」')), isTrue);
    expect(g.comboCount, 1);
    expect(g.comboTotal, 1);
  });

  test('特訓のあとの休養は「超回復」で、特訓した能力の経験点が入る', () {
    final g = _pair(Plan.special, Plan.rest, f1: Ability.power);
    expect(g.lastCombo, Combo.recovery);
    expect(g.log.any((l) => l.contains('超回復') && l.contains('パワー')), isTrue);
  });

  test('前の行動は保存され、読み直しても連携が続く', () {
    final g = _pair(Plan.study, Plan.rest);
    _settle(g);
    final back = Game.fromJson(
        jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>, Random(1));
    expect(back.lastPlan, Plan.rest);
    expect(back.comboTotal, g.comboTotal);
    expect(back.combosNow(Ability.contact), isEmpty, reason: '休養のあとは連携なし');
    final old = (jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>)
      ..remove('lastPlan')
      ..remove('comboTotal');
    final legacy = Game.fromJson(old, Random(1));
    expect(legacy.lastPlan, isNull);
    expect(legacy.comboTotal, 0);
  });

  test('いま連携できる行動の一覧(画面の印)', () {
    final g = _pair(Plan.rest, Plan.study);
    _settle(g);
    if (g.phase != Phase.term || g.condition.injured) return;
    final now = g.combosNow(Ability.contact);
    expect(now.keys, unorderedEquals([Plan.train, Plan.special]));
  });
}
