import 'dart:math';

import 'package:basketball_career/game/advice.dart';
import 'package:basketball_career/game/game.dart';
import 'package:basketball_career/game/life.dart';
import 'package:basketball_career/game/match.dart';
import 'package:basketball_career/game/path.dart';
import 'package:basketball_career/game/player.dart';
import 'package:basketball_career/game/season.dart';
import 'package:basketball_career/ui/art/court.dart';
import 'package:basketball_career/ui/season_card.dart';
import 'package:basketball_career/ui/team_colors.dart';
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

  test('ユニフォームの色は所属チームで決まる(名前の無い古い記録は段階の色、代表は青)', () {
    expect(teamColorOf('紅葉高校', League.highSchool), TeamColor.red);
    expect(teamColorOf('桜台ホークス', League.proDomestic), TeamColor.pink);
    expect(teamColorOf('北嶺大学', League.university), TeamColor.navy);
    // 同じ段階でもチームが違えば色が違う。
    expect(teamColorOf('朝日ホークス', League.proDomestic), isNot(teamColorOf('翠山ホークス', League.proDomestic)));
    expect(teamColorOf('', League.minibasket), TeamColor.yellow);
    expect(teamColorOf('', League.proAbroad), TeamColor.purple);
    expect(teamColorOf('紅葉高校', League.national), TeamColor.blue);
    expect(sceneForLeague(League.university), 'assets/art/scene_university.jpg');
  });

  test('相手の色は名前で決まり、こちらと同じ色にならない', () {
    for (final ours in TeamColor.values) {
      for (final name in ['佐藤', '鈴木', '高橋', '田中', 'リー', 'ミラー']) {
        expect(opponentColor(name, ours), isNot(ours));
        expect(opponentColor(name, ours), opponentColor(name, ours));
      }
    }
  });

  test('画面の差し色は、白い字が読める濃さ', () {
    for (final c in TeamColor.values) {
      final l = c.accent.computeLuminance();
      // 白とのコントラスト比 (1.05)/(l+0.05) が 3 以上。
      expect(1.05 / (l + 0.05), greaterThanOrEqualTo(3.0), reason: c.name);
    }
  });

  test('一生の通しで、記録にその年のチームが残り、自分のチームと同じ名前の相手は出ない', () {
    for (var seed = 0; seed < 12; seed++) {
      final g = Game.start('x', rng: Random(seed), events: false);
      var guard = 0;
      while (g.phase != Phase.retired && guard++ < 600) {
        switch (g.phase) {
          case Phase.season:
            g.choose(recommendedAction(g), recommendedFocus(g.player));
          case Phase.plan:
            g.resolvePlan(bestPlanOf(g.planInfo!));
          case Phase.halftime:
            g.resolveHalftime(bestHalftime(g.player, g.halftimeInfo!));
          case Phase.clutch:
            g.resolveClutch(Clutch.drive);
          case Phase.event:
            g.resolveEvent(0);
          case Phase.path:
            if (!g.chooseRoute(Route.pro) && !g.retired) g.chooseRoute(Route.university);
          case Phase.retired:
            break;
        }
      }
      for (final r in g.records) {
        expect(r.team, isNotEmpty, reason: '$seed ${r.age}歳');
        if (r.league != League.national) {
          expect(r.bestGame.contains('vs ${r.team}'), isFalse, reason: '$seed ${r.age}歳 ${r.bestGame}');
        }
      }
    }
  });

  test('年ごとの記録にチーム名が残り、保存して読み直せる', () {
    const r = YearRecord(age: 17, league: League.highSchool, wins: 1, games: 1, ppg: 1, rpg: 1, apg: 1,
        champion: false, achievement: 0, team: '青葉高校');
    expect(YearRecord.fromJson(r.toJson()).team, '青葉高校');
    expect(YearRecord.fromJson(const {'age': 17, 'league': 'highSchool'}).team, '');
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
