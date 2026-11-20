import 'dart:convert';
import 'dart:math';

import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/tryout.dart';
import 'package:flutter_test/flutter_test.dart';

/// プロ入りして、総合評価を戦力外の基準より下げて、戦力外の年まで進める。
Game _released(int seed) {
  final g = Game.newGame(
      name: 't', role: Role.batter, rng: Random(seed), potential: 95);
  var guard = 0;
  // まず、プロに入るまで進める。
  while (!g.turnedPro && g.phase != Phase.retired && guard++ < 3000) {
    g.autoSpend();
    switch (g.phase) {
      case Phase.term:
        g.choose(Plan.train, Ability.contact);
      case Phase.event:
        g.resolveEvent(0);
      case Phase.pathChoice:
        g.giveUp();
      case Phase.retired:
        break;
    }
  }
  // 能力を落として(管理者の書き換え)、戦力外が続くようにする。
  for (final a in abilitiesOf(g.player.role)) {
    g.adminSetAbility(a, 10);
  }
  guard = 0;
  while (g.phase != Phase.retired &&
      g.pendingEvent?.id != tryoutEventId &&
      guard++ < 3000) {
    switch (g.phase) {
      case Phase.term:
        for (final a in abilitiesOf(g.player.role)) {
          g.adminSetAbility(a, 10);
        }
        g.choose(Plan.rest, Ability.contact);
      case Phase.event:
        g.resolveEvent(0);
      case Phase.pathChoice:
        g.giveUp();
      case Phase.retired:
        break;
    }
  }
  return g;
}

/// トライアウトの出来事が出た状態の選手(最初に見つかったもの)。
Game _firstReleased() {
  for (var s = 0; s < 80; s++) {
    final g = _released(s);
    if (g.pendingEvent?.id == tryoutEventId) return g;
  }
  fail('戦力外になった例が無い');
}

void main() {
  test('契約を勝ち取れる確率は、評価が高く若いほど高い', () {
    Player p(int v, int age) => Player(
        name: 't',
        role: Role.batter,
        age: age,
        potential: 50,
        abilities: {for (final a in batterAbilities) a: v});
    expect(tryoutChance(p(40, 25)), greaterThan(tryoutChance(p(20, 25))));
    expect(tryoutChance(p(30, 25)), greaterThan(tryoutChance(p(30, 33))));
    expect(tryoutChance(p(30, 33)), greaterThan(tryoutChance(p(30, 37))));
    for (final v in [0, 30, 60, 99]) {
      for (final age in [20, 30, 38]) {
        expect(tryoutChance(p(v, age)), inInclusiveRange(0.10, 0.75));
      }
    }
  });

  test('トライアウトは一生に一度・40歳以上は選べない', () {
    expect(canTryout(age: 30, used: false), isTrue);
    expect(canTryout(age: 30, used: true), isFalse);
    expect(canTryout(age: tryoutMaxAge, used: false), isTrue);
    expect(canTryout(age: tryoutMaxAge + 1, used: false), isFalse);
  });

  test('戦力外になると、トライアウトを選ぶ出来事が出る(受ける/引退する)', () {
    final g = _firstReleased();
    expect(g.phase, Phase.event);
    expect(g.pendingEvent!.id, tryoutEventId);
    expect(
        g.pendingEvent!.choices.map((c) => c.label), ['トライアウトを受ける', '現役を引退する']);
    // 選ぶ途中で保存しても、同じ選択肢が出る
    final back = Game.fromJson(
        jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>, Random(1));
    expect(back.pendingEvent?.id, tryoutEventId);
    expect(back.phase, Phase.event);
  });

  test('「現役を引退する」を選ぶと引退する', () {
    final g = _firstReleased();
    g.resolveEvent(1);
    expect(g.phase, Phase.retired);
    expect(g.ending!.madePro, isTrue);
    expect(g.tryoutUsed, isFalse); // 受けていない
  });

  test('受けると、契約を勝ち取って続けるか、声がかからず引退する。どちらも使用済みになる', () {
    var ok = 0, fail = 0;
    for (var s = 0; s < 60; s++) {
      final g = _released(s);
      if (g.pendingEvent?.id != tryoutEventId) continue;
      final oldTeam = g.proTeam;
      g.resolveEvent(0);
      expect(g.tryoutUsed, isTrue);
      if (g.phase == Phase.retired) {
        fail++;
        expect(g.log.any((l) => l.contains('声がかからなかった')), isTrue);
      } else {
        ok++;
        expect(g.lowYears, 0);
        expect(g.proTeam, isNot(oldTeam));
        expect(g.log.any((l) => l.contains('契約を勝ち取った')), isTrue);
        expect(g.lifeLog.any((e) => e.text.contains('トライアウトで')), isTrue);
        expect(g.phase, Phase.term);
      }
    }
    expect(ok, greaterThan(0));
    expect(fail, greaterThan(0));
  });

  test('2度目の戦力外では、トライアウトは出ずにそのまま引退する', () {
    for (var s = 0; s < 80; s++) {
      final g = _released(s);
      if (g.pendingEvent?.id != tryoutEventId) continue;
      g.resolveEvent(0);
      if (g.phase == Phase.retired) continue; // 契約が取れなかった例は飛ばす
      // 続きを、また戦力外になるまで進める(能力は低いまま)
      var guard = 0;
      while (g.phase != Phase.retired && guard++ < 3000) {
        switch (g.phase) {
          case Phase.term:
            for (final a in abilitiesOf(g.player.role)) {
              g.adminSetAbility(a, 10);
            }
            g.choose(Plan.rest, Ability.contact);
          case Phase.event:
            expect(g.pendingEvent!.id, isNot(tryoutEventId));
            g.resolveEvent(0);
          default:
            break;
        }
      }
      expect(g.phase, Phase.retired);
      return;
    }
    fail('契約を取れた例が無い');
  });
}
