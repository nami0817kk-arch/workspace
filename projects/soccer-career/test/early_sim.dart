// ignore_for_file: avoid_print
/// **駆け出しの評価点が、ポジションでどれだけ違うか。**
///
/// `test/onboarding_sim.dart` で、最初の15節の評価点が
/// ST 6.30 / CM 6.27 / CB 6.79（6.0未満が 48% / 46% / 18%）と
/// **0.49 開いている**ことが分かった。キャリア平均は `position_sim` で
/// 7.02〜7.43 に揃えてあるので、**駆け出しの帯でだけ開いている**。
///
/// 疑っているのは難易度の重み（`Formulas.ratingSuccessWeight`）。
/// 振れ幅を ±0.4 で止めてあるので、**成功率が 41.4% を下回ると上限に
/// 張り付いて、そこから先は難しさが採点に返らない**。駆け出しの成功率は
/// 実測で 40.3%（`chance_sim` の18歳）——ちょうどその境目にある。
///
/// キャリアを回すと移籍で環境が変わるので、`MatchEngine` を直に叩いて
/// 能力と相手を固定する（`ceiling_sim` と同じ作り）。
///
///     flutter test test/early_sim.dart
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

Attributes flat(int value) =>
    Attributes.fromDetails({for (final d in Detail.values) d: value});

Player who(int ability, int age, Position position) => Player(
  name: 'P',
  age: age,
  position: position,
  attributes: flat(ability),
  potential: 99,
);

Club club(String id, int strength) =>
    Club(id: id, name: id, strength: strength, tier: 2, countryId: 'yamato');

class Tally {
  int matches = 0;
  int scenarios = 0;
  double chance = 0;

  /// 難易度の重みが上限（±[Formulas.ratingDifficultyLimit]）に張り付いた回数。
  int pinnedHigh = 0;
  int pinnedLow = 0;

  /// 得点に繋がる手を選んだ回数。
  int daring = 0;
  double rating = 0;
  int under6 = 0;
}

void main() {
  test('駆け出しの評価点', () {
    const seasons = 30;

    Tally run({
      required int ability,
      required int age,
      required Position position,
      required int strength,
      Appearance appearance = Appearance.start,
    }) {
      final tally = Tally();
      final engine = MatchEngine(random: Random(11));
      final player = who(ability, age, position);
      for (var season = 0; season < seasons; season++) {
        for (var day = 1; day <= 38; day++) {
          final match = engine.start(
            matchday: day,
            player: player,
            club: club('home', strength),
            opponent: club('away$day', strength),
            home: day.isEven,
            appearance: appearance,
          );
          tally.scenarios += match.scenarios.length;
          while (!match.isFinished) {
            final option = match.pickFor(SimStyle.balanced);
            final chance = match.chanceFor(option);
            tally.chance += chance;
            // 上限に張り付いた＝そこから先は難しさが採点に返っていない。
            if (Formulas.ratingSuccessWeight(chance) >=
                1 + Formulas.ratingDifficultyLimit - 1e-9) {
              tally.pinnedHigh++;
            }
            if (Formulas.ratingSuccessWeight(chance) <=
                1 - Formulas.ratingDifficultyLimit + 1e-9) {
              tally.pinnedLow++;
            }
            if (option.outcome != Outcome.play) tally.daring++;
            match.autoArm(SimStyle.balanced);
            match.choose(option);
          }
          final result = match.finish();
          tally.matches++;
          final r = result.rating ?? 0;
          tally.rating += r;
          if (r < 6.0) tally.under6++;
        }
      }
      return tally;
    }

    String pct(num a, num b) => '${(a * 100 / b).toStringAsFixed(0)}%';

    void show(String name, Tally t) {
      print(
        '  ${name.padRight(18)} '
        '成功率 ${(t.chance / t.scenarios * 100).toStringAsFixed(1)}%  '
        '勝負手 ${pct(t.daring, t.scenarios)}  '
        '上限に張付 高${pct(t.pinnedHigh, t.scenarios)} '
        '低${pct(t.pinnedLow, t.scenarios)}  '
        '評価 ${(t.rating / t.matches).toStringAsFixed(2)}  '
        '6.0未満 ${pct(t.under6, t.matches)}',
      );
    }

    // 駆け出し（18歳・2部下位）を、先発と途中出場で分けて並べる。
    for (final (label, appearance) in [
      ('先発（ふつう2局面・じっくり6）', Appearance.start),
      ('途中出場（ふつう2局面・じっくり4）', Appearance.sub),
    ]) {
      print('== 駆け出し 能力62 / $label ==');
      for (final position in [Position.st, Position.cm, Position.cb]) {
        show(
          position.label,
          run(
            ability: 62,
            age: 18,
            position: position,
            strength: 40,
            appearance: appearance,
          ),
        );
      }
    }
  });
}
