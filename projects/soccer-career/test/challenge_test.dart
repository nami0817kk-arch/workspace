/// **キャリアを跨ぐ挑戦。**
///
/// 称号も歴代の記録も「多いほど良い」ものしかなく、同じ遊び方を
/// 繰り返すほど伸びた。挑戦は逆に、形の違うキャリアでしか届かない。
///
/// 到達率は `test/tmp_challenge_sim.dart` ではなく
/// `test/reach_sim.dart` と同じ考え方で測ってある（CLAUDE.md 参照）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/models/challenge.dart';
import 'package:soccer_career/models/competition.dart';
import 'package:soccer_career/models/legend.dart';

Legend _legend({
  String name = 'T',
  int appearances = 0,
  int goals = 0,
  int caps = 0,
  int peakOverall = 0,
  int leagueTitles = 0,
  int cupTitles = 0,
  int continentalTitles = 0,
  int firstTier = 0,
  int peakAge = 0,
  WorldCupStage worldCupBest = WorldCupStage.none,
  List<LegendSpell> spells = const [],
}) => Legend.fromJson({
  'name': name,
  'appearances': appearances,
  'goals': goals,
  'caps': caps,
  'peakOverall': peakOverall,
  'leagueTitles': leagueTitles,
  'cupTitles': cupTitles,
  'continentalTitles': continentalTitles,
  'firstTier': firstTier,
  'peakAge': peakAge,
  'worldCupBest': worldCupBest.name,
  'spells': [for (final s in spells) s.toJson()],
});

void main() {
  group('達成の判定', () {
    test('一途は、1つのクラブで長くやった選手だけ', () {
      const one = LegendSpell(clubName: 'A', seasons: 12, tier: 1);
      const two = LegendSpell(clubName: 'B', seasons: 4, tier: 1);
      expect(
        Challenge.oneClub.clearedBy(_legend(appearances: 400, spells: [one])),
        isTrue,
      );
      // 試合数が足りなければ、1クラブでも届かない。
      expect(
        Challenge.oneClub.clearedBy(_legend(appearances: 120, spells: [one])),
        isFalse,
      );
      // 移籍していれば届かない。
      expect(
        Challenge.oneClub.clearedBy(
          _legend(appearances: 400, spells: [one, two]),
        ),
        isFalse,
      );
    });

    test('渡り鳥は国の数で見る。国を持たない古い記録は数えない', () {
      List<LegendSpell> spells(List<String> countries) => [
        for (final c in countries)
          LegendSpell(clubName: c, seasons: 2, tier: 1, countryId: c),
      ];
      expect(
        Challenge.wanderer.clearedBy(
          _legend(spells: spells(['a', 'b', 'c', 'd'])),
        ),
        isTrue,
      );
      // 同じ国のクラブを渡り歩いても、国は増えない。
      expect(
        Challenge.wanderer.clearedBy(
          _legend(spells: spells(['a', 'a', 'a', 'a'])),
        ),
        isFalse,
      );
      // 国を持たせる前に引退した選手は、空のまま数に入らない。
      expect(
        Challenge.wanderer.clearedBy(
          _legend(
            spells: const [
              LegendSpell(clubName: 'A', seasons: 2, tier: 1),
              LegendSpell(clubName: 'B', seasons: 2, tier: 1),
              LegendSpell(clubName: 'C', seasons: 2, tier: 1),
              LegendSpell(clubName: 'D', seasons: 2, tier: 1),
            ],
          ),
        ),
        isFalse,
      );
    });

    test('叩き上げは、最初のクラブと一緒に上がった選手だけ', () {
      // 2部で始めて、そのクラブで1部まで行った。
      expect(
        Challenge.fromBelow.clearedBy(
          _legend(
            firstTier: 2,
            spells: const [LegendSpell(clubName: 'A', seasons: 5, tier: 1)],
          ),
        ),
        isTrue,
      );
      // 移籍して1部へ行ったのは、叩き上げではない。
      expect(
        Challenge.fromBelow.clearedBy(
          _legend(
            firstTier: 2,
            spells: const [
              LegendSpell(clubName: 'A', seasons: 3, tier: 2),
              LegendSpell(clubName: 'B', seasons: 8, tier: 1),
            ],
          ),
        ),
        isFalse,
      );
      // 最初から1部なら、上がりようがない。
      expect(
        Challenge.fromBelow.clearedBy(
          _legend(
            firstTier: 1,
            spells: const [LegendSpell(clubName: 'A', seasons: 5, tier: 1)],
          ),
        ),
        isFalse,
      );
    });

    test('無冠の名手は、1つも獲っていないことが条件', () {
      expect(Challenge.uncrowned.clearedBy(_legend(peakOverall: 82)), isTrue);
      expect(
        Challenge.uncrowned.clearedBy(_legend(peakOverall: 82, cupTitles: 1)),
        isFalse,
      );
    });

    test('数で決まるものは、線のとおりに切れる', () {
      expect(Challenge.marksman.clearedBy(_legend(goals: 200)), isTrue);
      expect(Challenge.marksman.clearedBy(_legend(goals: 199)), isFalse);
      expect(Challenge.ironman.clearedBy(_legend(appearances: 600)), isTrue);
      expect(Challenge.ironman.clearedBy(_legend(appearances: 599)), isFalse);
      expect(Challenge.faceOfTheNation.clearedBy(_legend(caps: 60)), isTrue);
      expect(Challenge.faceOfTheNation.clearedBy(_legend(caps: 59)), isFalse);
      expect(Challenge.lateBloom.clearedBy(_legend(peakAge: 30)), isTrue);
      expect(Challenge.lateBloom.clearedBy(_legend(peakAge: 29)), isFalse);
      expect(
        Challenge.worldChampion.clearedBy(
          _legend(worldCupBest: WorldCupStage.winner),
        ),
        isTrue,
      );
    });
  });

  group('殿堂に残る', () {
    test('達成は、選手が押し出されても消えない', () {
      var hall = const Hall();
      hall = hall.add(_legend(name: '点取り屋', goals: 250));
      expect(hall.isCleared(Challenge.marksman), isTrue);

      // 40人を超えて押し出しても、達成は残る。
      for (var i = 0; i < Hall.keep + 2; i++) {
        hall = hall.add(_legend(name: '$i'));
      }
      expect(hall.legends.any((l) => l.name == '点取り屋'), isFalse);
      expect(hall.isCleared(Challenge.marksman), isTrue);
    });

    test('「初めて達成した」は1度だけ', () {
      var hall = const Hall();
      final first = _legend(name: 'A', goals: 250);
      expect(hall.firstTimeFor(first), contains(Challenge.marksman));
      hall = hall.add(first);
      // 2人目が同じことをしても、初めてではない。
      expect(hall.firstTimeFor(_legend(name: 'B', goals: 300)), isEmpty);
    });

    test('挑戦を持たせる前の殿堂も、残っている選手から読み直す', () {
      final json = {
        'legends': [_legend(name: '鉄人', appearances: 700).toJson()],
      };
      final hall = Hall.fromJson(json);
      expect(hall.isCleared(Challenge.ironman), isTrue);
    });

    test('保存を往復しても達成が残る', () {
      final hall = const Hall().add(_legend(name: 'A', goals: 250));
      final back = Hall.fromJson(hall.toJson());
      expect(back.isCleared(Challenge.marksman), isTrue);
    });
  });
}
