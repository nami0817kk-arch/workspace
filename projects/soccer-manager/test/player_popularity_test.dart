import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/logic/player_popularity.dart';
import 'package:soccer_manager/models/player.dart';

void main() {
  test('力・得点・出場・生え抜きで人気が上がり、0〜100に収まる', () {
    final p = PlayerGenerator.generate(
        position: Position.st, strengthTier: 60, ageOverride: 25);
    p.careerGoals = 0;
    p.careerAppearances = 0;
    p.homegrown = false;
    p.academyGraduate = false;
    final base = PlayerPopularityEngine.popularity(p);
    p.careerGoals = 50;
    final scorer = PlayerPopularityEngine.popularity(p);
    expect(scorer, greaterThan(base));
    p.homegrown = true;
    expect(PlayerPopularityEngine.popularity(p), scorer + 10);
    p.careerGoals = 100000;
    p.careerAppearances = 100000;
    expect(PlayerPopularityEngine.popularity(p), lessThanOrEqualTo(100));
  });

  test('人気の選手を売ると、グッズの上乗せが減る', () {
    final squad = [
      for (var i = 0; i < 11; i++)
        PlayerGenerator.generate(
            position: Position.mc, strengthTier: 50, ageOverride: 24)
          ..careerGoals = 0
          ..careerAppearances = 0
          ..homegrown = false
          ..academyGraduate = false,
    ];
    final star = PlayerGenerator.generate(
        position: Position.st, strengthTier: 75, ageOverride: 27)
      ..careerGoals = 80
      ..careerAppearances = 200
      ..homegrown = true;
    final withStar = PlayerPopularityEngine.weeklyMerchBonus([...squad, star]);
    final without = PlayerPopularityEngine.weeklyMerchBonus(squad);
    expect(withStar, greaterThan(without));
    expect(PlayerPopularityEngine.weeklyMerchBonus(const []), 0);
  });
}
