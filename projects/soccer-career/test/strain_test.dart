/// 身体の消耗と、性格の落ち着き先。
///
/// 実測（40キャリア×3条件）で、**毎週の選択が選択になっていなかった**。
/// 「流す」は上振れが一つも無く（ピーク 73.0/74.7/75.1、平均評価
/// 6.91/6.99/6.99、コツ 3%/88%/98%）、見返りは怪我が年 0.22回減ることだけ。
/// 「一人でやる」も全指標で最下位だった。20年で760回ある選択が、
/// 「追い込む＋誰かと組む」を押し続ける作業になっていた。
///
/// さらに、**性格が40キャリア全部でプロ意識 20（上限）**に張り付いていた。
/// 生活イベントも `evolve` も足し算だけで、下げるものが無かった。
/// 練習効率も衰え始めの年齢も、20年やれば誰でも同じになる。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/life_events.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/models/development.dart';
import 'package:soccer_career/models/personality.dart';
import 'package:soccer_career/models/training.dart';

/// その踏み込み方をn週続けたときの消耗。
double after(TrainingEffort effort, TrainingCompanion companion, int weeks) {
  var strain = Formulas.strainNeutral;
  for (var i = 0; i < weeks; i++) {
    strain = Formulas.driftStrain(
      strain,
      (effort.strain + companion.strainShift).clamp(0.0, 100.0),
    );
  }
  return strain;
}

void main() {
  group('身体の消耗', () {
    test('踏み込み方の落ち着き先へ寄っていく', () {
      // 1シーズン（38週）でほぼ着く。切り替えたその年に効き始める。
      expect(
        after(TrainingEffort.hard, TrainingCompanion.alone, 38),
        greaterThan(75),
      );
      expect(
        after(TrainingEffort.easy, TrainingCompanion.alone, 38),
        lessThan(30),
      );
      expect(
        after(TrainingEffort.normal, TrainingCompanion.alone, 38),
        closeTo(50, 6),
      );
    });

    test('累積ではないので、途中で引けば戻る', () {
      // 累積にすると若い頃の1年で残りが決まり、30歳で流し始めても
      // 何も起きない。「歳を取ったら引く」が手にならなくなる。
      var strain = after(TrainingEffort.hard, TrainingCompanion.alone, 200);
      final burnt = strain;
      for (var i = 0; i < 76; i++) {
        strain = Formulas.driftStrain(strain, TrainingEffort.easy.strain);
      }
      expect(strain, lessThan(burnt - 30));
    });

    test('組む相手も動かす。張り合えば重く、年長者に付けば軽い', () {
      final rival = after(TrainingEffort.normal, TrainingCompanion.rival, 100);
      final mentor = after(
        TrainingEffort.normal,
        TrainingCompanion.mentor,
        100,
      );
      final alone = after(TrainingEffort.normal, TrainingCompanion.alone, 100);
      expect(rival, greaterThan(alone));
      expect(mentor, lessThan(alone));
    });

    test('消耗が軽いほど、衰え始めが遅い', () {
      expect(Formulas.declineOffsetForStrain(20), 2);
      expect(Formulas.declineOffsetForStrain(Formulas.strainNeutral), 0);
      expect(Formulas.declineOffsetForStrain(60), -2);
      // 真ん中は「普通で来た選手が実際に着く値」で取る。
      // 書いてある落ち着き先（50）で取ると、普通に遊んだ選手に代償が付く。
      expect(
        after(TrainingEffort.normal, TrainingCompanion.alone, 200),
        greaterThan(Formulas.strainEased),
      );
    });

    test('消耗が重いほど、同じ怪我でも重いほうを引く', () {
      expect(
        MatchEngine.severeShareFor(0, strain: 60),
        greaterThan(MatchEngine.severeShareFor(0, strain: 22)),
      );
      expect(
        MatchEngine.severeShareFor(0, strain: Formulas.strainNeutral),
        Formulas.severeInjuryShare,
      );
      // 理不尽にはしない。
      expect(Formulas.severeFactorForStrain(100), lessThanOrEqualTo(1.5));
      expect(Formulas.severeFactorForStrain(0), greaterThanOrEqualTo(0.6));
    });

    test('保存に乗る。知らない保存データは真ん中で読む', () {
      const development = Development(strain: 71);
      expect(Development.fromJson(development.toJson()).strain, 71);
      expect(Development.fromJson(const {}).strain, Formulas.strainNeutral);
      expect(const Development().strainLabel, isNotEmpty);
    });
  });

  group('一人でやる', () {
    test('大成功は出ないが、空回りもしない', () {
      // 全指標で最下位だった。誰とも組まない週に固有の見返りが無かった。
      double flat(TrainingCompanion c) => MatchEngine.outcomeOdds(
        effort: TrainingEffort.normal,
        companion: c,
        condition: Formulas.conditionBaseline,
        professionalism: 10,
      ).flat;
      double great(TrainingCompanion c) => MatchEngine.outcomeOdds(
        effort: TrainingEffort.normal,
        companion: c,
        condition: Formulas.conditionBaseline,
        professionalism: 10,
      ).great;
      for (final other in [
        TrainingCompanion.partner,
        TrainingCompanion.mentor,
        TrainingCompanion.rival,
      ]) {
        expect(
          flat(TrainingCompanion.alone),
          lessThan(flat(other)),
          reason: other.label,
        );
        expect(
          great(TrainingCompanion.alone),
          lessThan(great(other)),
          reason: other.label,
        );
      }
    });
  });

  group('性格', () {
    test('生まれ持った値を覚えている', () {
      final born = Personality.roll(Random(3));
      final moved = born.bump(PersonalityAxis.professionalism, 1);
      expect(moved.born.professionalism, born.professionalism);
      // 入れ子は1段だけ。
      expect(moved.born.origin, isNull);
      final again = moved.bump(PersonalityAxis.professionalism, 1);
      expect(again.born.professionalism, born.professionalism);
    });

    test('落ち着き先へ寄る。行き過ぎない', () {
      const p = Personality(
        confidence: 10,
        ambition: 10,
        professionalism: 10,
        temper: 10,
      );
      var next = p;
      for (var i = 0; i < 20; i++) {
        next = next.settleToward(PersonalityAxis.professionalism, 14);
      }
      expect(next.professionalism, 14);
      for (var i = 0; i < 20; i++) {
        next = next.settleToward(PersonalityAxis.professionalism, 8);
      }
      expect(next.professionalism, 8);
    });

    test('生活イベントでは天井まで行けない', () {
      // 生活イベントの「+1 プロ意識」が19か所あって、下げるものが1つも
      // 無かった。20年やれば誰でも上限に着き、性格の差が消えていた。
      var p = const Personality(
        confidence: 10,
        ambition: 10,
        professionalism: 10,
        temper: 10,
      );
      for (var i = 0; i < 100; i++) {
        p = p.bump(PersonalityAxis.professionalism, 1);
      }
      expect(p.professionalism, Personality.driftMax);
      expect(p.professionalism, lessThan(Personality.max));

      for (var i = 0; i < 200; i++) {
        p = p.bump(PersonalityAxis.professionalism, -1);
      }
      expect(p.professionalism, Personality.driftMin);
      expect(p.professionalism, greaterThan(Personality.min));
    });

    test('生まれつき極端な選手は、そのまま始める', () {
      // 生まれ持った値まで動きを止めると、極端な性格が作れなくなる。
      const p = Personality(
        confidence: 18,
        ambition: 2,
        professionalism: 19,
        temper: 10,
      );
      expect(p.bump(PersonalityAxis.professionalism, 1).professionalism, 19);
      expect(p.bump(PersonalityAxis.confidence, 1).confidence, 18);
      // 真ん中へ戻る向きは止めない。
      expect(p.bump(PersonalityAxis.professionalism, -1).professionalism, 18);
      expect(p.bump(PersonalityAxis.ambition, 1).ambition, 3);
    });

    test('生活イベントで性格が動くのは、転機だけ', () {
      // ふつうの選択に「+1 プロ意識」を配ると、数だけで天井に着く。
      var moves = 0;
      for (final event in LifeEvents.catalogue) {
        for (final choice in event.choices) {
          final e = choice.effect;
          if (e.professionalism != 0) moves++;
        }
      }
      expect(moves, lessThanOrEqualTo(4), reason: '$moves か所で動いている');
    });

    test('プロ意識が練習の効きを変える', () {
      const low = Personality(
        confidence: 10,
        ambition: 10,
        professionalism: 5,
        temper: 10,
      );
      const high = Personality(
        confidence: 10,
        ambition: 10,
        professionalism: 16,
        temper: 10,
      );
      expect(high.trainingFactor, greaterThan(low.trainingFactor));
      // 天井に張り付いていた頃の値（1.30）を真ん中に置いてある。
      const mid = Personality(
        confidence: 10,
        ambition: 10,
        professionalism: 13,
        temper: 10,
      );
      expect(mid.trainingFactor, closeTo(1.31, 0.05));
    });
  });
}
