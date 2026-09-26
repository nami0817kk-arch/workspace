/// ノリと、第2の通貨（決定的な仕事）。
///
/// 実測（`test/matters_sim.dart`、24キャリア）で分かっていたこと:
/// **上手くやっても報われない**——最善 74.9/7.07、安全 74.8/7.06、
/// 勝負 74.8/7.06 と、中身の違う3つの遊び方が同じ結果になる。
/// 差が出るのは「わざと最悪」だけで、失敗の罰しかなかった。
/// さらに、期待値に従うと中盤の選手が20年で**9ゴール**しか取らない
/// （何も読まずに押した選手のほうが36ゴール取る）。
///
/// 原因は、**平均評価という単一の通貨がすべての入口**だったこと。
/// 平均は変動を嫌うので、安全な手が構造的に常に正しくなる。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/game/scenarios.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/club.dart';
import 'package:soccer_career/models/player.dart';
import 'package:soccer_career/models/season.dart';

const away = Club(id: 'b', name: 'B', strength: 60, tier: 1);
const home = Club(id: 'a', name: 'A', strength: 60, tier: 1);

MatchResult result({
  required Appearance appearance,
  int goals = 0,
  int assists = 0,
  int conceded = 1,
}) => MatchResult(
  matchday: 1,
  opponentName: 'B',
  home: true,
  scored: 1,
  conceded: conceded,
  appearance: appearance,
  rating: appearance.played ? 6.5 : null,
  goals: goals,
  assists: assists,
);

MatchInProgress match({int seed = 1}) {
  final pool = ScenarioPool.forPosition(Position.st).take(3).toList();
  return MatchInProgress(
    matchday: 1,
    opponent: away,
    home: true,
    appearance: Appearance.start,
    scenarios: pool,
    minutes: const [20, 50, 80],
    player: Player(
      name: 'テスト',
      age: 24,
      position: Position.st,
      attributes: Attributes(
        pace: 70,
        shooting: 70,
        passing: 70,
        dribbling: 70,
        defending: 70,
        physical: 70,
        goalkeeping: 70,
      ),
      potential: 90,
    ),
    club: home,
    teammateGoalMinutes: const [30, 60],
    random: Random(seed),
  );
}

void main() {
  group('ノリ', () {
    test('何もしていなければ、決まる確率は素のまま', () {
      final m = match();
      expect(m.momentum, 0);
      expect(m.momentumFactor, 1.0);
      expect(m.goalConversionNow(), Formulas.goalConversion);
    });

    test('乗るほど決まるようになる。上限がある', () {
      final m = match();
      m.momentum = 1;
      expect(
        m.goalConversionNow(),
        closeTo(
          Formulas.goalConversion * (1 + Formulas.momentumPerStep),
          0.0001,
        ),
      );
      m.momentum = Formulas.momentumMax;
      expect(
        m.momentumFactor,
        1 + Formulas.momentumMax * Formulas.momentumPerStep,
      );
      // 1試合3局面しかないので、段は短く保つ。
      expect(Formulas.momentumMax, lessThanOrEqualTo(2));
    });

    test('効くのは決まる確率だけ。成功率には乗せない', () {
      // 成功率に乗せると「安全な手をひたすら積む」がさらに強くなるだけで、
      // また一本道になる。
      final m = match();
      final option = m.current.options.first;
      final before = m.chanceFor(option);
      m.momentum = Formulas.momentumMax;
      expect(m.chanceFor(option), before);
      expect(
        m.factorsFor(option).where((f) => f.label.contains('ノリ')),
        isEmpty,
      );
    });

    test('難しい手を通したほうが乗る', () {
      // 無難な手を積むだけでは上がりきらない。
      expect(Formulas.momentumFromChance, greaterThan(1));
      expect(
        Formulas.momentumFromChance,
        lessThanOrEqualTo(Formulas.momentumMax),
      );
    });

    test('失敗すると消える', () {
      final m = match(seed: 9);
      m.momentum = Formulas.momentumMax;
      // 通らない手を無理に選ばせるため、成功率の一番低い手を選ぶ。
      final worst = m.current.options.reduce(
        (a, b) => m.chanceFor(a) <= m.chanceFor(b) ? a : b,
      );
      final resolution = m.choose(worst);
      if (!resolution.success) {
        expect(m.momentum, 0);
      } else {
        expect(m.momentum, greaterThan(0));
      }
    });

    test('試合をまたがない', () {
      // 1試合の中の段取りであって、シーズンの波（`Form`）ではない。
      expect(match().momentum, 0);
    });
  });

  group('決定的な仕事', () {
    test('ゴールとアシスト。守る選手は無失点も', () {
      final scored = result(appearance: Appearance.start, goals: 2, assists: 1);
      expect(scored.decisiveFor(Position.st), 3);
      // 守る選手にとっての無失点は、点を取る選手にとってのゴールと同じ仕事。
      final clean = result(appearance: Appearance.start, conceded: 0);
      expect(clean.decisiveFor(Position.cb), 1);
      expect(clean.decisiveFor(Position.gk), 1);
      expect(clean.decisiveFor(Position.st), 0);
    });

    test('出ていない試合は数えない', () {
      final benched = result(appearance: Appearance.benched, conceded: 0);
      expect(benched.decisiveFor(Position.cb), 0);
      final injured = result(appearance: Appearance.injured, goals: 1);
      expect(injured.decisiveFor(Position.st), 0);
    });

    test('決めている選手は、出場機会で下駄を履く', () {
      // 「6.8だが決めている」選手と「7.0だが何もしていない」選手を
      // 区別できていなかった。
      final quiet = [
        for (var i = 0; i < 5; i++) result(appearance: Appearance.start),
      ];
      final scoring = [
        for (var i = 0; i < 5; i++)
          result(appearance: Appearance.start, goals: 1),
      ];
      expect(MatchEngine.decisiveBonus(quiet, Position.st), 0);
      expect(MatchEngine.decisiveBonus(scoring, Position.st), greaterThan(0));
      // 理不尽にはならない（上限がある）。
      final huge = [
        for (var i = 0; i < 20; i++)
          result(appearance: Appearance.start, goals: 3),
      ];
      expect(
        MatchEngine.decisiveBonus(huge, Position.st),
        Formulas.decisiveBonusMax,
      );
    });

    test('直近だけを見る', () {
      // 5年前のゴールで今の序列が決まるのはおかしい。
      final old = [
        result(appearance: Appearance.start, goals: 3),
        for (var i = 0; i < Formulas.formWindow; i++)
          result(appearance: Appearance.start),
      ];
      expect(MatchEngine.decisiveBonus(old, Position.st), 0);
    });
  });
}
