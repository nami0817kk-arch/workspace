import 'dart:convert';
import 'dart:math';

import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/childhood.dart';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:flutter_test/flutter_test.dart';

/// 幼少期(少年野球)が終わるまで進める。分かれ道は `pick(id, 選択肢の数)` で選ぶ。
Game _kidYears(int seed, int Function(String id, int n) pick,
    {Role role = Role.batter, void Function(Game g)? onKid}) {
  final g = Game.newGame(name: 't', role: role, rng: Random(seed));
  var steps = 0;
  while (g.phase != Phase.retired && g.stage == Stage.youth) {
    if (++steps > 500) fail('終わらない');
    g.autoSpend();
    if (g.phase == Phase.event) {
      final e = g.pendingEvent!;
      if (e.id.startsWith('kid-')) onKid?.call(g);
      g.resolveEvent(pick(e.id, e.choices.length));
    } else {
      g.choose(g.condition.fatigue >= 60 ? Plan.rest : Plan.train,
          abilitiesOf(g.player.role).first);
    }
  }
  return g;
}

void main() {
  test('幼少期の分かれ道は、決まった歳に1回ずつ、7つとも必ず出る', () {
    for (var s = 0; s < 30; s++) {
      final seen = <String, int>{};
      final ages = <String, int>{};
      final g = _kidYears(s, (id, n) => 0, onKid: (g) {
        final id = g.pendingEvent!.id;
        seen[id] = (seen[id] ?? 0) + 1;
        ages[id] = g.player.age;
      });
      expect(g.childhood.length, childhoodSteps.length, reason: 'seed=$s');
      for (final st in childhoodSteps) {
        expect(seen[st.id], 1, reason: '${st.id} seed=$s');
        expect(ages[st.id], st.age, reason: '${st.id} seed=$s');
      }
    }
  });

  test('どの選択肢も、能力・特性・体調・絆のどれかが変わる(選ぶ意味がある)', () {
    for (final st in childhoodSteps) {
      expect(st.notes.length, st.event.choices.length);
      expect(st.event.choices.length, greaterThanOrEqualTo(2));
      for (final role in [Role.batter, Role.pitcher]) {
        final p = Player(
          name: 't',
          role: role,
          age: st.age,
          potential: 50,
          abilities: {for (final a in abilitiesOf(role)) a: 20},
        );
        for (final ch in st.event.choices) {
          final r = ch.apply(p, const Condition(fatigue: 50, morale: 50),
              abilitiesOf(role).first);
          final changed =
              r.player.abilities.toString() != p.abilities.toString() ||
                  r.player.traits.length != p.traits.length ||
                  r.condition.fatigue != 50 ||
                  r.condition.morale != 50 ||
                  ch.onCast != null;
          expect(changed, isTrue, reason: '${st.id} ${ch.label}');
        }
      }
    }
  });

  test('選んだ内容が記録され(育ち)、特性・能力に反映される', () {
    final g =
        _kidYears(3, (id, n) => id == 'kid-idol' ? 0 : 1, role: Role.pitcher);
    expect(g.childhood['kid-idol'], 0);
    expect(g.player.traits.map((t) => t.name), contains('fireballer'));
    final kid = g.lifeLog.where((e) => e.kind == 'childhood').toList();
    expect(kid.length, childhoodSteps.length);
    expect(kid.map((e) => e.age).toList(), [6, 7, 8, 9, 10, 11, 12]);
    // 打者の憧れは打者向けの特性になる
    final b = _kidYears(3, (id, n) => id == 'kid-idol' ? 0 : 1);
    expect(b.player.traits.map((t) => t.name), contains('slugger'));
  });

  test('出来事の最中に保存しても読み直せて、選んだ記録も残る', () {
    final g = Game.newGame(name: 't', role: Role.batter, rng: Random(5));
    var steps = 0;
    while (g.pendingEvent?.id != 'kid-lesson') {
      if (++steps > 300) fail('7歳の分かれ道に着かない');
      g.autoSpend();
      if (g.phase == Phase.event) {
        g.resolveEvent(0);
      } else {
        g.choose(Plan.train, Ability.contact);
      }
    }
    final copy = Game.fromJson(
        (jsonDecode(jsonEncode(g.toJson())) as Map).cast(), Random(1));
    expect(copy.phase, Phase.event);
    expect(copy.pendingEvent!.id, 'kid-lesson');
    copy.resolveEvent(1);
    expect(copy.childhood['kid-lesson'], 1);
    final again = Game.fromJson(
        (jsonDecode(jsonEncode(copy.toJson())) as Map).cast(), Random(1));
    expect(again.childhood, copy.childhood);
  });

  test('古いセーブ(分かれ道の記録なし)でも読める', () {
    final g = Game.newGame(name: 't', role: Role.batter, rng: Random(1));
    final j = (jsonDecode(jsonEncode(g.toJson())) as Map)
        .cast<String, dynamic>()
      ..remove('childhood');
    expect(Game.fromJson(j, Random(1)).childhood, isEmpty);
  });

  test('中学以降では分かれ道は出ない', () {
    final g = Game.newGame(name: 't', role: Role.batter, rng: Random(2));
    var steps = 0;
    while (g.phase != Phase.retired && g.player.age < 20) {
      if (++steps > 800) fail('終わらない');
      g.autoSpend();
      switch (g.phase) {
        case Phase.event:
          if (g.stage != Stage.youth) {
            expect(g.pendingEvent!.id.startsWith('kid-'), isFalse);
          }
          g.resolveEvent(0);
        case Phase.term:
          g.choose(Plan.train, abilitiesOf(g.player.role).first);
        case Phase.pathChoice:
          g.chooseRoute(Course.university);
        case Phase.retired:
          break;
      }
    }
  });
}
