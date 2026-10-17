import 'dart:convert';
import 'dart:math';

import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/exp.dart';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/snapshot.dart';
import 'package:baseball_manager/game/traits.dart';
import 'package:flutter_test/flutter_test.dart';

/// ランダムな操作(練習・重点・出来事・進路・転向・引退・管理者の書き換え・保存と読み直し)で
/// 何人も最後まで遊ばせ、毎ターン「壊れていないこと」を検査する。
void _checkInvariants(Game g, String where) {
  final p = g.player;
  for (final a in abilitiesOf(p.role)) {
    expect(p.of(a), inInclusiveRange(0, 99), reason: '$where: ${a.name}');
  }
  expect(abilitiesOf(p.role).toSet(), p.abilities.keys.toSet(),
      reason: '$where: 能力の種類');
  expect(p.potential, inInclusiveRange(0, 100), reason: where);
  expect(g.condition.fatigue, inInclusiveRange(0, 100), reason: '$where: 疲労');
  expect(g.condition.morale, inInclusiveRange(0, 100), reason: '$where: 気持ち');
  expect(g.condition.injuredTerms, greaterThanOrEqualTo(0), reason: where);
  for (final c in Category.values) {
    expect(g.exp.of(c), greaterThanOrEqualTo(0), reason: '$where: 経験点');
  }
  // 引退後は stage が retired になり、ターン数の数え方が変わるので見ない。
  if (g.phase != Phase.retired) {
    expect(g.slot, inInclusiveRange(0, g.slotsInYear - 1),
        reason: '$where: ターン');
  }
  expect(p.age, inInclusiveRange(startAge, maxProAge + 1), reason: where);
  expect(g.overallHistory.length, p.age - startAge + 1,
      reason: '$where: 評価の推移');
  expect(g.cast.rival, isNotNull, reason: where);
  for (final m in g.cast.members) {
    expect(m.bond, inInclusiveRange(0, 100), reason: '$where: 絆 ${m.name}');
  }
  for (final r in g.records) {
    expect(r.age, inInclusiveRange(startAge, maxProAge + 1), reason: where);
    expect(r.line.hits, lessThanOrEqualTo(r.line.atBats), reason: where);
    expect(r.line.outs, lessThanOrEqualTo(r.line.faced), reason: where);
    if (r.isLeague) expect(r.teamWins + r.teamLosses, 143, reason: where);
  }
  if (g.phase == Phase.event) expect(g.pendingEvent, isNotNull, reason: where);
  if (g.phase == Phase.retired) expect(g.ending, isNotNull, reason: where);
  if (g.phase != Phase.retired) {
    expect(g.goal, isNotNull, reason: '$where: 今年の目標');
  }
  // 段階と年齢の対応
  if (g.phase != Phase.retired) {
    expect(g.stage, stageOf(p.age, turnedPro: g.turnedPro),
        reason: '$where: 段階');
  }
}

void main() {
  test('ランダムな操作で200人遊ばせても、毎ターン不変条件が守られ、必ず終わる', () {
    for (var seed = 0; seed < 200; seed++) {
      final rng = Random(seed * 7 + 1);
      final role = Role.values[rng.nextInt(2)];
      var g = Game.newGame(
          name: 'f$seed',
          role: role,
          rng: Random(seed),
          potential: rng.nextInt(101));
      var steps = 0;
      while (g.phase != Phase.retired) {
        if (++steps > 4000) fail('終わらない seed=$seed');
        final where =
            'seed=$seed step=$steps ${g.phase.name} age=${g.player.age} slot=${g.slot}';
        // ときどき: 保存して読み直す(続きが同じになること)。
        if (rng.nextInt(25) == 0) {
          final saved = jsonEncode(g.toJson());
          final reloaded = Game.fromJson(
              jsonDecode(saved) as Map<String, dynamic>, Random(seed + steps));
          expect(jsonEncode(reloaded.toJson()), saved, reason: '$where: 保存の往復');
          g = reloaded;
        }
        // ときどき: 管理者の書き換え(極端な値でも壊れない)。
        if (g.phase != Phase.retired && rng.nextInt(40) == 0) {
          switch (rng.nextInt(6)) {
            case 0:
              g.adminSetPotential(rng.nextInt(301) - 100);
            case 1:
              g.adminSetTraits({
                for (final t in Trait.values)
                  if (rng.nextBool()) t
              });
            case 2:
              g.adminSetAbility(
                  abilitiesOf(g.player.role)[
                      rng.nextInt(abilitiesOf(g.player.role).length)],
                  rng.nextInt(400) - 100);
            case 3:
              g.adminAddExp(rng.nextInt(6000) - 2000);
            case 4:
              g.adminSetCoachTeaches(rng.nextBool()
                  ? null
                  : Trait.values[rng.nextInt(Trait.values.length)]);
            case 5:
              g.adminSetCoachTips(rng.nextInt(8) - 2);
          }
        }
        switch (g.phase) {
          case Phase.term:
            if (g.stage == Stage.pro && rng.nextInt(30) == 0) {
              g.retire();
            } else if (g.stage == Stage.pro && rng.nextInt(12) == 0) {
              g.changeRole(Role.values[rng.nextInt(3)]);
            } else {
              if (rng.nextInt(3) == 0) g.autoSpend();
              if (rng.nextInt(4) == 0) {
                g.spend(abilitiesOf(g.player.role)[
                    rng.nextInt(abilitiesOf(g.player.role).length)]);
              }
              final abilities = abilitiesOf(g.player.role);
              g.choose(Plan.values[rng.nextInt(Plan.values.length)],
                  abilities[rng.nextInt(abilities.length)]);
            }
          case Phase.event:
            g.resolveEvent(rng.nextInt(g.pendingEvent!.choices.length));
          case Phase.pathChoice:
            if (rng.nextInt(6) == 0) {
              g.giveUp();
            } else {
              g.chooseRoute(Course.values[rng.nextInt(2)]);
            }
          case Phase.retired:
            break;
        }
        _checkInvariants(g, where);
      }
      // 終わった後の写しも作れて、保存して読み直せる。
      final snap = PlayerSnapshot.fromGame(g);
      expect(jsonEncode(PlayerSnapshot.fromJson(snap.toJson()).toJson()),
          jsonEncode(snap.toJson()));
      expect(g.lifeLog.last.kind, 'retire', reason: 'seed=$seed');
    }
  });

  test('段階に合わない操作は、どの状態でも StateError か ArgumentError になり、状態を壊さない', () {
    for (var seed = 0; seed < 30; seed++) {
      final g = Game.newGame(
          name: 'e', role: Role.batter, rng: Random(seed), potential: 50);
      for (var i = 0; i < 12 && g.phase != Phase.retired; i++) {
        final before = jsonEncode(g.toJson());
        final bad = <void Function()>[
          if (g.phase != Phase.event) () => g.resolveEvent(0),
          if (g.phase != Phase.pathChoice)
            () => g.chooseRoute(Course.university),
          if (g.phase != Phase.pathChoice) () => g.giveUp(),
          if (g.phase != Phase.term || g.stage != Stage.pro) () => g.retire(),
          if (g.phase != Phase.term || g.stage != Stage.pro)
            () => g.changeRole(Role.twoWay),
          if (g.phase != Phase.term)
            () => g.choose(Plan.train, Ability.contact),
        ];
        for (final f in bad) {
          expect(f, throwsA(anyOf(isA<StateError>(), isA<ArgumentError>())));
        }
        expect(jsonEncode(g.toJson()), before, reason: '失敗した操作で状態が変わった');
        g.phase == Phase.event
            ? g.resolveEvent(0)
            : g.choose(Plan.rest, Ability.contact);
      }
    }
  });
}
