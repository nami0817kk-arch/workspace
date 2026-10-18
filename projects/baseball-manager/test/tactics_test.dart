import 'dart:convert';
import 'dart:math';

import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/season.dart';
import 'package:baseball_manager/game/tactics.dart';
import 'package:flutter_test/flutter_test.dart';

Player _p(Role r, [int v = 60]) => Player(
      name: 't',
      role: r,
      age: 17,
      potential: 50,
      abilities: {for (final a in abilitiesOf(r)) a: v},
    );

void main() {
  test('作戦で能力が変わるのはその大会だけ。元の選手は変えない', () {
    final p = _p(Role.batter);
    final a = tacticAdjusted(p, Tactic.aggressive);
    expect(a.of(Ability.power), 70);
    expect(a.of(Ability.contact), 54);
    expect(p.of(Ability.power), 60); // 元は変わらない
    expect(tacticAdjusted(p, Tactic.scout).abilities, p.abilities);
    expect(tacticTeamBonus(Tactic.scout), greaterThan(0));
    expect(tacticTeamBonus(Tactic.steady), 0);
  });

  test('能力は0〜99を超えない', () {
    final hi = tacticAdjusted(_p(Role.batter, 99), Tactic.aggressive);
    expect(hi.of(Ability.power), 99);
    final lo = tacticAdjusted(_p(Role.batter, 0), Tactic.aggressive);
    expect(lo.of(Ability.contact), 0);
  });

  test('強気は本塁打が増えて打率が下がり、堅実は打率が上がる(平均)', () {
    double hr(Tactic t) =>
        _avg((s) => playLeagueSeason(tacticAdjusted(_p(Role.batter), t),
                teamLevel: 65, opponents: const [60, 66], rng: Random(s))
            .line
            .homeRuns
            .toDouble());
    double ba(Tactic t) =>
        _avg((s) => playLeagueSeason(tacticAdjusted(_p(Role.batter), t),
                teamLevel: 65, opponents: const [60, 66], rng: Random(s))
            .line
            .battingAverage!);
    expect(hr(Tactic.aggressive), greaterThan(hr(Tactic.steady)));
    expect(ba(Tactic.steady), greaterThan(ba(Tactic.aggressive)));
  });

  test('投手でも、強気は球威、堅実は制球に効く', () {
    final a = tacticAdjusted(_p(Role.pitcher), Tactic.aggressive);
    final s = tacticAdjusted(_p(Role.pitcher), Tactic.steady);
    expect(a.of(Ability.stuff), greaterThan(s.of(Ability.stuff)));
    expect(s.of(Ability.control), greaterThan(a.of(Ability.control)));
  });

  test('研究はチーム力が上がり、大会で勝ち上がりやすい(平均)', () {
    double rounds(int bonus) => _avg((s) => playTournament(_p(Role.batter),
            teamLevel: 50 + bonus,
            opponents: const [45, 50, 55, 60, 65],
            rng: Random(s))
        .roundsWon
        .toDouble());
    expect(rounds(tacticTeamBonus(Tactic.scout)), greaterThan(rounds(0)));
  });

  group('ゲームの中', () {
    Game start() => Game.newGame(
        name: 't', role: Role.batter, rng: Random(2), potential: 70);

    test('作戦を選べるのは、大会の月とその前の月だけ', () {
      final g = start(); // 少年野球は季節。大会は夏(slot 1)
      expect(g.slot, 0);
      expect(g.tacticRelevant, isTrue); // 春(大会の前の季節)
      g.choose(Plan.rest);
      if (g.phase == Phase.event) g.resolveEvent(0);
      expect(g.slotName, '夏');
      expect(g.tacticRelevant, isTrue);
      g.choose(Plan.rest); // 大会が行われる
      if (g.phase == Phase.event) g.resolveEvent(0);
      expect(g.slotName, '秋');
      expect(g.tacticRelevant, isFalse);
    });

    test('作戦は大会のあとに堅実へ戻る', () {
      final g = start();
      g.setTactic(Tactic.aggressive);
      g.choose(Plan.rest);
      if (g.phase == Phase.event) g.resolveEvent(0);
      expect(g.tactic, Tactic.aggressive); // 大会の前の季節では、まだ
      g.choose(Plan.rest); // 夏: 大会
      if (g.phase == Phase.event) g.resolveEvent(0);
      expect(g.tactic, Tactic.steady);
      expect(g.records, hasLength(1));
    });

    test('作戦は保存して読み直せる。古いセーブは堅実', () {
      final g = start()..setTactic(Tactic.scout);
      final q = Game.fromJson(
          jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>,
          Random(1));
      expect(q.tactic, Tactic.scout);
      expect(Game.fromJson({}, Random(1)).tactic, Tactic.steady);
    });

    test('プロは10月(シーズン最終月)とその前の月が対象', () {
      Game? pro;
      for (var s = 0; s < 60 && pro == null; s++) {
        final g = Game.newGame(
            name: 't', role: Role.batter, rng: Random(s), potential: 100);
        var steps = 0;
        while (g.phase != Phase.retired &&
            !(g.stage == Stage.pro && g.phase == Phase.term)) {
          if (++steps > 3000) fail('終わらない');
          g.autoSpend();
          switch (g.phase) {
            case Phase.term:
              g.choose(g.condition.fatigue >= 60 ? Plan.rest : Plan.train,
                  Ability.contact);
            case Phase.event:
              g.resolveEvent(0);
            case Phase.pathChoice:
              g.chooseRoute(Course.university);
            case Phase.retired:
              break;
          }
        }
        if (g.stage == Stage.pro) pro = g;
      }
      final g = pro!;
      final relevant = <String>[];
      var guard = 0;
      while (g.slot < g.slotsInYear - 1 && guard++ < 40) {
        if (g.tacticRelevant &&
            g.phase == Phase.term &&
            (relevant.isEmpty || relevant.last != g.slotName)) {
          relevant.add(g.slotName);
        }
        g.phase == Phase.event
            ? g.resolveEvent(0)
            : g.choose(Plan.rest, Ability.contact);
      }
      expect(relevant, ['9月', '10月']);
    });
  });
}

double _avg(double Function(int seed) f, {int n = 60}) {
  var t = 0.0;
  for (var s = 0; s < n; s++) {
    t += f(s);
  }
  return t / n;
}
