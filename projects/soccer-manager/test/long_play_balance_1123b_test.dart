// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/board_engine.dart';
import 'package:soccer_manager/logic/division_strength.dart';
import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/logic/retirement_engine.dart';
import 'package:soccer_manager/models/league.dart';
import 'package:soccer_manager/models/league_theme.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/season_record.dart';
import 'package:soccer_manager/models/team.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 長く遊んだときの釣り合いの続き(2026-11-23)。
///
/// 英・西・独で4つの方針を10季ずつ回したところ、
/// - 部の間の差が年々縮み(1部の先発の水準 89→84、3部 71→75)、
///   1部の強めのクラブを持つと毎季のように優勝した。
/// - 上手に経営しても3部の水準が上がり続け、なかなか抜けられなかった。
/// - 何もしないオーナーは、戦力が最下位なら目標も最下位で、手放すまで
///   8〜10季かかった。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
  });
  tearDown(() => Tr.language = AppLanguage.system);

  Player player(String id, int overall) {
    final p = PlayerGenerator.generate(
        position: Position.mc, strengthTier: overall, ageOverride: 26);
    return p;
  }

  group('1 理事会の目標の下限', () {
    test('降格のある部は降格圏の外、いちばん下の部は下位4分の1の上', () {
      expect(BoardEngine.targetRankFloor(teamCount: 20, relegationZone: 3), 17);
      expect(BoardEngine.targetRankFloor(teamCount: 24, relegationZone: 4), 20);
      expect(BoardEngine.targetRankFloor(teamCount: 24, relegationZone: 0), 18);
      expect(BoardEngine.targetRankFloor(teamCount: 20, relegationZone: 0), 15);
    });

    test('戦力が最下位でも、目標は下限より下にならない', () {
      final teams = [
        for (var i = 0; i < 20; i++)
          Team(
            id: 't$i',
            name: 'T$i',
            players: [for (var k = 0; k < 3; k++) player('t$i-$k', 80 - i)],
          ),
      ];
      final league = League(teams: teams, fixtures: const [], season: 1);
      final sorted = [...teams]
        ..sort((a, b) => b.overallRating.compareTo(a.overallRating));
      final weakest = sorted.last.id;
      expect(BoardEngine.estimateTargetRank(league, weakest), 15);
      expect(BoardEngine.estimateTargetRank(league, weakest, relegationZone: 3),
          17);
      // 下限より上のクラブは、これまでどおり戦力の順位+2(並びの同点は
      // どちらが先でもよい)。
      expect(BoardEngine.estimateTargetRank(league, sorted.first.id),
          lessThanOrEqualTo(2 + BoardEngine.targetRankCushion));
    });

    test('月末のまとめに、順位そのもの(下位4分の1なら -1)を混ぜる', () {
      expect(BoardEngine.monthlyPositionPart(rank: 18, teamCount: 24), 0);
      expect(BoardEngine.monthlyPositionPart(rank: 19, teamCount: 24), -1);
      expect(BoardEngine.monthlyPositionPart(rank: 15, teamCount: 20), 0);
      expect(BoardEngine.monthlyPositionPart(rank: 16, teamCount: 20), -1);
      // 最下位で目標(下限)との差が -6・勝点も取れない月。
      expect(
          BoardEngine.monthlyResultDelta(
              rank: 24, targetRank: 18, points: 1, games: 4, teamCount: 24),
          -5);
      // クラブ数を渡さなければ、これまでどおり。
      expect(
          BoardEngine.monthlyResultDelta(
              rank: 24, targetRank: 18, points: 1, games: 4),
          -4);
    });

    test('ゲームの目標も、自クラブの部の降格圏から下限を取る', () async {
      final gs = GameState();
      await gs.startNewGame('下限FC');
      expect(gs.ownRelegationZone, 0, reason: '3部(いちばん下)');
      final n = gs.save!.league.teams.length;
      expect(gs.save!.boardTargetRank, lessThanOrEqualTo(n - n ~/ 4));
      gs.save!.currentDivisionTier = 1;
      expect(gs.ownRelegationZone,
          gs.currentLeagueTheme.rulesBelow(1).relegationZone);
    });
  });

  group('2 CPU の補充の強さ', () {
    test('部の水準の目安は 1部82・2部72・3部65', () {
      expect(divisionTypicalSquadLevel(1), 82);
      expect(divisionTypicalSquadLevel(2), 72);
      expect(divisionTypicalSquadLevel(3), 65);
    });

    Team squadAt(int overall) => Team(
          id: 'c',
          name: 'C',
          players: [for (var k = 0; k < 5; k++) player('c$k', overall)],
        );

    test('主力が抜けたら、平均とその選手の間の強さで埋める(上の部ほど)', () {
      final team = squadAt(70);
      final level = team.overallRating;
      final base = RetirementEngine.cpuRecruitStrength(team);
      expect(base, level + RetirementEngine.cpuRecruitStrengthBias);
      final star = RetirementEngine.cpuRecruitStrength(team,
          replacedOverall: level + 20);
      expect(star, base + 10);
      // 平均より弱い選手が抜けても、下げない。
      expect(
          RetirementEngine.cpuRecruitStrength(team,
              replacedOverall: level - 20),
          base);
      expect(RetirementEngine.replaceShareFor(1), 0.5);
      expect(RetirementEngine.replaceShareFor(2), 0.25);
      expect(RetirementEngine.replaceShareFor(3), 0);
    });

    test('部の水準へ半分寄せる(昇格したクラブは強く、降格したクラブは弱く)', () {
      // 1部の水準(82)より10低いクラブと、3部の水準(65)より10高いクラブ。
      final up = squadAt(72);
      final upLevel = up.overallRating;
      expect(
          RetirementEngine.cpuRecruitStrength(up, tier: 1),
          closeTo(
              RetirementEngine.cpuRecruitStrength(up) +
                  (divisionTypicalSquadLevel(1) - upLevel) / 2,
              1));
      final down = squadAt(75);
      final downLevel = down.overallRating;
      expect(
          RetirementEngine.cpuRecruitStrength(down,
              tier: 3, replacedOverall: downLevel + 20),
          closeTo(
              RetirementEngine.cpuRecruitStrength(down) +
                  (divisionTypicalSquadLevel(3) - downLevel) / 2,
              1),
          reason: '3部では主力の穴を主力級では埋めない');
    });
  });

  group('3 1部の王者には相手が向かってくる', () {
    SeasonRecord champion(GameState gs,
            {bool won = true, int tier = 1, int ago = 1}) =>
        SeasonRecord(
          season: gs.save!.league.season - ago,
          clubName: gs.save!.clubName,
          leagueName: gs.save!.leagueName,
          divisionTier: tier,
          finalRank: won ? 1 : 2,
          teamCount: 20,
          played: 38,
          won: 28,
          draw: 5,
          lost: 5,
          goalsFor: 80,
          goalsAgainst: 30,
          wonLeague: won,
          promoted: false,
          relegated: false,
        );

    test('前の季に1部で優勝し、いまも1部にいるときだけ', () async {
      final gs = GameState();
      await gs.startNewGame('王者FC');
      final s = gs.save!;
      expect(gs.isReigningTopChampion, isFalse);
      s.league.season = 2;
      s.seasonHistory.add(champion(gs));
      expect(gs.isReigningTopChampion, isFalse, reason: 'いまは3部');
      s.currentDivisionTier = 1;
      expect(gs.isReigningTopChampion, isTrue);
      s.seasonHistory
        ..clear()
        ..add(champion(gs, won: false));
      expect(gs.isReigningTopChampion, isFalse, reason: '2位');
      s.seasonHistory
        ..clear()
        ..add(champion(gs, tier: 2));
      expect(gs.isReigningTopChampion, isFalse, reason: '2部の優勝');
    });

    test('王者のホームの利は減り、敵地では相手の利が増える', () async {
      final gs = GameState();
      await gs.startNewGame('王者FC');
      final s = gs.save!;
      final me = s.userTeamId;
      final opp = s.league.teams.firstWhere((t) => t.id != me).id;
      final homeBefore = gs.debugHomeAdvantageFor(me, awayTeamId: opp);
      final awayBefore = gs.debugHomeAdvantageFor(opp, awayTeamId: me);
      s.league.season = 2;
      s.currentDivisionTier = 1;
      s.seasonHistory.add(champion(gs));
      expect(gs.debugHomeAdvantageFor(me, awayTeamId: opp),
          closeTo(homeBefore - GameStateMatch.championPressure, 1e-9));
      expect(gs.debugHomeAdvantageFor(opp, awayTeamId: me),
          closeTo(awayBefore + GameStateMatch.championPressure, 1e-9));
      // 自クラブの出ない試合は変わらない。
      final other = s.league.teams.lastWhere((t) => t.id != me && t.id != opp);
      expect(gs.debugHomeAdvantageFor(opp, awayTeamId: other.id), awayBefore);
      // カップ戦(相手を渡さない所)には掛けない。
      expect(gs.debugHomeAdvantageFor(me), homeBefore);
    });

    test('連覇が続くほど強まり、3連覇で頭打ち', () async {
      final gs = GameState();
      await gs.startNewGame('王者FC');
      final s = gs.save!;
      final me = s.userTeamId;
      final opp = s.league.teams.firstWhere((t) => t.id != me).id;
      final base = gs.debugHomeAdvantageFor(opp, awayTeamId: me);
      s.league.season = 6;
      s.currentDivisionTier = 1;
      for (var ago = 5; ago >= 1; ago--) {
        s.seasonHistory.add(champion(gs, ago: ago, won: ago != 5));
      }
      expect(gs.reigningTitleStreak, 4);
      expect(gs.debugHomeAdvantageFor(opp, awayTeamId: me),
          closeTo(base + 3 * GameStateMatch.championPressure, 1e-9));
      s.seasonHistory.removeLast();
      s.seasonHistory.add(champion(gs, won: false));
      expect(gs.reigningTitleStreak, 0, reason: '前の季は2位');
    });
  });
}
