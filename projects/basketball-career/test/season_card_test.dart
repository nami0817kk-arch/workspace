import 'dart:math';

import 'package:basketball_career/game/game.dart';
import 'package:basketball_career/game/player.dart';
import 'package:basketball_career/game/season.dart';
import 'package:basketball_career/ui/art/court.dart';
import 'package:basketball_career/ui/season_card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('成績カードの数字: 同じ年の夏と冬をまとめ、試合数で重みをつけて平均する', () {
    final g = Game(
      eventsEnabled: false,
      player: Player(name: 'x', age: 18, potential: 60, heightCm: 185, heightGenes: 0.5,
          abilities: {for (final a in Ability.values) a: 60}),
      rng: Random(1),
    );
    g.records.add(YearRecord(age: 17, league: League.highSchool, wins: 5, games: 5, ppg: 20, rpg: 5, apg: 2, champion: true, achievement: 80, honors: const ['ベスト5']));
    g.records.add(YearRecord(age: 17, league: League.highSchool, wins: 1, games: 2, ppg: 6, rpg: 5, apg: 2, champion: false, achievement: 40, winter: true));
    g.growthLog.addAll([const GrowthPoint(16, 55, 180), const GrowthPoint(17, 61, 184)]);
    final s = seasonOf(g, 17)!;
    expect(s.games, 7);
    expect(s.ppg, closeTo((20 * 5 + 6 * 2) / 7, 1e-9));
    expect(s.titles, 1);
    expect(s.honors, ['ベスト5']);
    expect(s.overallFrom, 55);
    expect(s.overallTo, 61);
    expect(seasonOf(g, 10), isNull);
  });

  test('過去の年の絵は、その年の舞台の色で描く', () {
    expect(spriteColorForLeague(League.minibasket), 'yellow');
    expect(spriteColorForLeague(League.highSchool), 'red');
    expect(spriteColorForLeague(League.proAbroad), 'purple');
    expect(sceneForLeague(League.university), 'assets/art/scene_university.jpg');
  });

  test('ポーズの選び方: 重点・勝負どころ・作戦', () {
    expect(poseForFocus(Ability.threePoint), Pose.shoot);
    expect(poseForFocus(Ability.defense), Pose.defense);
    expect(poseForFocus(Ability.inside), Pose.dunk);
    expect(poseForFocus(Ability.pass), Pose.dribble);
    expect(poseFile(Pose.dunk, kid: true), 'kid_jump');
    expect(poseFile(Pose.dribble, kid: false), 'adult');
  });
}
