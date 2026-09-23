/// **殿堂ポイント。** 引退した選手が、次のキャリアに残すもの。
///
/// 参考にした野球のキャリアゲームは「20ptにつき次の選手の才能+1、最大+80」。
/// こちらはポテンシャルの幅が 71〜90 と狭いので、上限を +6 に抑える。
///
/// **宣言は run に形を与えるためのもの。** 挑戦そのものは宣言しなくても
/// 達成でき（引退した記録から静かに判定する）、宣言した場合だけ上乗せが付く。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/models/challenge.dart';
import 'package:soccer_career/models/competition.dart';
import 'package:soccer_career/models/legend.dart';

Legend _legend({
  String name = 'T',
  int appearances = 0,
  int goals = 0,
  int caps = 0,
  int leagueTitles = 0,
  WorldCupStage worldCupBest = WorldCupStage.none,
  List<LegendSpell> spells = const [],
}) => Legend.fromJson({
  'name': name,
  'appearances': appearances,
  'goals': goals,
  'caps': caps,
  'leagueTitles': leagueTitles,
  'worldCupBest': worldCupBest.name,
  'spells': [for (final s in spells) s.toJson()],
});

void main() {
  group('貯まりかた', () {
    test('何もしていない選手でも、点は負にならない', () {
      expect(Hall.pointsFor(_legend()), greaterThanOrEqualTo(0));
    });

    test('積み上げたものが、そのまま点になる', () {
      final plain = Hall.pointsFor(_legend(appearances: 400));
      final more = Hall.pointsFor(_legend(appearances: 400, goals: 100));
      expect(more, greaterThan(plain));
      expect(
        Hall.pointsFor(_legend(appearances: 400, leagueTitles: 3)),
        greaterThan(plain),
      );
      expect(
        Hall.pointsFor(
          _legend(appearances: 400, worldCupBest: WorldCupStage.winner),
        ),
        greaterThan(plain),
      );
    });

    test('宣言して達成すれば、そのぶん重く残る', () {
      final legend = _legend(appearances: 400, goals: 250);
      final plain = Hall.pointsFor(legend);
      final declared = Hall.pointsFor(legend, declared: Challenge.marksman);
      expect(declared - plain, Challenge.marksman.declaredBonus);
    });

    test('宣言しても届かなければ、上乗せは無い', () {
      final legend = _legend(appearances: 400, goals: 10);
      expect(
        Hall.pointsFor(legend, declared: Challenge.marksman),
        Hall.pointsFor(legend),
      );
    });

    test('狙っても届かない挑戦ほど、宣言の上乗せが重い', () {
      // **「普通に遊んだときの到達率」ではなく「狙ったときの到達率」で並ぶ。**
      // 宣言するのは狙う人なので、狙っても届かないものほど重い。
      // 順は `test/challenge_sim.dart` の実測（狙ったときの到達率）:
      // 一途100% > 叩き上げ84% > 大器晩成70% > 鉄人49% > 渡り鳥39%
      // > 点取り屋33% > 無冠17% > 代表の顔14% > 世界一10%
      const easiestFirst = [
        Challenge.oneClub,
        Challenge.fromBelow,
        Challenge.lateBloom,
        Challenge.ironman,
        Challenge.wanderer,
        Challenge.marksman,
        Challenge.uncrowned,
        Challenge.faceOfTheNation,
        Challenge.worldChampion,
      ];
      expect(
        easiestFirst.toSet(),
        Challenge.values.toSet(),
        reason: '挑戦を足したら、この並びにも足す',
      );
      for (var i = 1; i < easiestFirst.length; i++) {
        expect(
          easiestFirst[i].declaredBonus,
          greaterThan(easiestFirst[i - 1].declaredBonus),
          reason:
              '${easiestFirst[i].label} が ${easiestFirst[i - 1].label} '
              'より軽い',
        );
      }
    });
  });

  group('次の選手に乗る', () {
    test('ためた点が伸びしろになる。上限で止まる', () {
      expect(Formulas.legacyPotentialBonus(0), 0);
      expect(Formulas.legacyPotentialBonus(Formulas.legacyPerPotential - 1), 0);
      expect(Formulas.legacyPotentialBonus(Formulas.legacyPerPotential), 1);
      expect(
        Formulas.legacyPotentialBonus(Formulas.legacyPerPotential * 100),
        Formulas.legacyPotentialCap,
      );
    });

    test('点は減らない。引退のたびに積み上がる', () {
      var hall = const Hall();
      hall = hall.add(_legend(name: 'A', appearances: 400), points: 30);
      expect(hall.legacyPoints, 30);
      hall = hall.add(_legend(name: 'B', appearances: 400), points: 25);
      expect(hall.legacyPoints, 55);
    });

    test('貯まった点が、次の選手の伸びしろに乗る', () {
      // 同じ種で作って、持ち越しのぶんだけポテンシャルが上がる。
      int potentialWith(int bonus) =>
          CareerEngine(random: Random(21))
              .startCareer(
                name: 'T',
                position: Position.cm,
                age: 18,
                agent: Agent.pool.first,
                potentialBonus: bonus,
              )
              .player
              .potential;

      expect(potentialWith(3), potentialWith(0) + 3);
    });

    test('実測: 1人ぶんで中央49pt。+1に2人、上限に8人', () {
      // 40キャリアの実測（下位1割29 / 中央49 / 上位1割75 / 最大87）。
      // 線が中央から離れすぎていないことを縛る。
      expect(Formulas.legacyPerPotential, greaterThan(29));
      expect(Formulas.legacyPerPotential, lessThan(75 * 2));
    });

    test('保存を往復しても残り、無い保存データは0', () {
      final hall = const Hall().add(_legend(name: 'A'), points: 42);
      expect(Hall.fromJson(hall.toJson()).legacyPoints, 42);
      expect(
        Hall.fromJson(hall.toJson()..remove('legacyPoints')).legacyPoints,
        0,
      );
    });
  });
}
