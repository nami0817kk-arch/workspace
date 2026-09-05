import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/logic/board_engine.dart';
import 'package:soccer_manager/logic/match_engine.dart';
import 'package:soccer_manager/logic/season_analysis_engine.dart';
import 'package:soccer_manager/logic/training_engine.dart';
import 'package:soccer_manager/models/attributes.dart';
import 'package:soccer_manager/models/club_vision.dart';
import 'package:soccer_manager/models/league.dart';
import 'package:soccer_manager/models/match_result.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/preseason_camp.dart';
import 'package:soccer_manager/models/team.dart';
import 'package:soccer_manager/state/game_state.dart';

/// FM にあって未実装だった6要素。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Player make({int age = 25, int proneness = 10}) {
    final p = Player(
      id: 'p$age$proneness${identityHashCode(age)}',
      name: 'p',
      age: age,
      position: Position.mc,
      potential: 85,
      matchSharpness: 50,
    );
    for (final k in AttributeKeys.all) {
      p.setAttributeValue(k, 50);
    }
    p.injuryProneness = proneness;
    return p;
  }

  group('1. 怪我のしやすさ', () {
    test('高いほど負傷しやすい', () {
      expect(MatchEngine.injuryPronenessFactor(make(proneness: 20)),
          greaterThan(MatchEngine.injuryPronenessFactor(make(proneness: 1))));
    });

    test('普通(10)なら、ほぼ従来どおりの確率', () {
      expect(MatchEngine.injuryPronenessFactor(make(proneness: 10)),
          closeTo(1.0, 0.05));
    });

    test('3段階の語で表される', () {
      expect(make(proneness: 20).injuryPronenessLabel,
          isNot(make(proneness: 1).injuryPronenessLabel));
    });

    test('旧セーブは「普通」として読む', () {
      final json = make().toJson();
      json.remove('injuryProneness');
      expect(Player.fromJson(json).injuryProneness, 10);
    });
  });

  group('2. シーズン前キャンプ', () {
    test('どのキャンプにも引き換えがある', () {
      for (final camp in PreseasonCamp.values) {
        if (camp == PreseasonCamp.none) continue;
        final gains = camp.sharpnessGain > 0 ||
            camp.familiarityGain > 0 ||
            camp.youthGrowthChance > 0;
        final costs = camp.fatigueCost > 0 || camp.cost > 0;
        expect(gains && costs, isTrue, reason: '${camp.name} に得か損の片方しか無い');
      }
    });

    test('キャンプを張らなければ、何も起きず費用も掛からない', () {
      const camp = PreseasonCamp.none;
      expect(camp.cost, 0);
      expect(camp.sharpnessGain, 0);
      expect(camp.fatigueCost, 0);
    });

    test('実際に選ぶと、実戦感覚と疲労の両方が動く', () async {
      final game = GameState();
      await game.startNewGame('テストFC');
      game.save!.budget = 100000;
      final p = game.userTeam.players.first;
      final sharpBefore = p.matchSharpness;
      final fatigueBefore = p.fatigue;

      expect(await game.choosePreseasonCamp(PreseasonCamp.fitness), isTrue);

      expect(p.matchSharpness, greaterThan(sharpBefore));
      expect(p.fatigue, greaterThan(fatigueBefore));
    });

    test('一度決めたら、そのシーズンは選び直せない', () async {
      final game = GameState();
      await game.startNewGame('テストFC');
      game.save!.budget = 100000;

      expect(await game.choosePreseasonCamp(PreseasonCamp.none), isTrue);
      expect(await game.choosePreseasonCamp(PreseasonCamp.fitness), isFalse);
    });
  });

  group('3. 移籍期限', () {
    test('開幕前は締切が近いものとして扱う', () async {
      final game = GameState();
      await game.startNewGame('テストFC');
      expect(game.isTransferWindowOpen, isTrue);
      expect(game.transferWindowMatchdaysLeft, isNotNull,
          reason: '締切が見えないと、動けるうちに動く判断ができない');
    });

    test('締切の節かどうかが分かる', () async {
      final game = GameState();
      await game.startNewGame('テストFC');
      expect(game.isTransferDeadlineMatchday,
          game.transferWindowMatchdaysLeft == 1);
    });

    test('駆け込みオファーは相場より高い', () {
      // 相場どおりなら締切を意識する理由が無い。
      expect(GameStateTransfer.deadlineDayPremium, greaterThan(1.0));
    });
  });

  group('4. 育成型レンタル', () {
    test('出場を約束させると成長が大きい', () {
      final plain = make(age: 20);
      final guaranteed = make(age: 20)..loanedWithPlayingTime = true;
      // 同じ能力から始めて、同じ回数だけ育成を回す。
      for (int i = 0; i < 30; i++) {
        TrainingEngine.applyLoanDevelopment(plain);
        TrainingEngine.applyLoanDevelopment(guaranteed);
      }
      expect(guaranteed.overall, greaterThanOrEqualTo(plain.overall));
      expect(TrainingEngine.loanPlayingTimeFactor, greaterThan(1.0));
    });

    test('旧セーブは通常のレンタルとして読む', () {
      final json = make().toJson();
      json.remove('loanedWithPlayingTime');
      expect(Player.fromJson(json).loanedWithPlayingTime, isFalse);
    });
  });

  group('5. クラブの方針', () {
    Team teamWith({int youngStarters = 0, TeamMentality? mentality}) {
      final players = [
        for (int i = 0; i < 11; i++)
          make(age: i < youngStarters ? 21 : 29),
      ];
      return Team(
        id: 't',
        name: 'T',
        players: players,
        startingXI: players.map((p) => p.id).toList(),
        mentality: mentality ?? TeamMentality.balanced,
      );
    }

    test('若手育成: 規定人数のスタメンが必要', () {
      expect(
        BoardEngine.isVisionSatisfied(
            vision: ClubVision.developYouth,
            team: teamWith(youngStarters: 0),
            budget: 100),
        isFalse,
      );
      expect(
        BoardEngine.isVisionSatisfied(
            vision: ClubVision.developYouth,
            team: teamWith(
                youngStarters: ClubVisionInfo.youthStartersRequired),
            budget: 100),
        isTrue,
      );
    });

    test('攻撃的なサッカー: 守備的な姿勢は認められない', () {
      expect(
        BoardEngine.isVisionSatisfied(
            vision: ClubVision.attackingFootball,
            team: teamWith(mentality: TeamMentality.defensive),
            budget: 100),
        isFalse,
      );
    });

    test('堅実な経営: 赤字は認められない', () {
      expect(
        BoardEngine.isVisionSatisfied(
            vision: ClubVision.financialProudence,
            team: teamWith(),
            budget: -1),
        isFalse,
      );
    });

    test('破ると、守ったときより大きく評価が動く', () {
      // 守って当たり前のことなので、守っても大きくは褒められない。
      for (final v in ClubVision.values) {
        if (v == ClubVision.none) continue;
        expect(v.violatedPenalty, greaterThan(v.satisfiedBonus));
      }
    });

    test('路線なしなら、信頼度は動かない(従来の挙動)', () {
      expect(
        BoardEngine.confidenceDeltaForVision(
            vision: ClubVision.none, team: teamWith(), budget: -999),
        0,
      );
    });
  });

  group('6. シーズン分析', () {
    League leagueWith(List<Fixture> fixtures) => League(
          teams: [
            Team(id: 'me', name: 'Me', players: const []),
            Team(id: 'opp', name: 'Opp', players: const []),
          ],
          fixtures: fixtures,
        );

    Fixture played({
      required String home,
      required String away,
      required int homeGoals,
      required int awayGoals,
      List<MatchEvent> events = const [],
      int matchday = 1,
    }) =>
        Fixture(
          matchday: matchday,
          homeTeamId: home,
          awayTeamId: away,
          result: MatchResult(
            matchday: matchday,
            homeTeamId: home,
            awayTeamId: away,
            homeGoals: homeGoals,
            awayGoals: awayGoals,
            events: events,
          ),
        );

    test('ホームとアウェイを分けて数える', () {
      final league = leagueWith([
        played(home: 'me', away: 'opp', homeGoals: 2, awayGoals: 0),
        played(
            home: 'opp', away: 'me', homeGoals: 3, awayGoals: 1, matchday: 2),
      ]);

      final home = SeasonAnalysisEngine.record(league, 'me', home: true);
      final away = SeasonAnalysisEngine.record(league, 'me', home: false);

      expect(home.won, 1);
      expect(away.lost, 1);
      expect(away.ga, 3);
    });

    test('時間帯ごとの得失点を数える', () {
      final league = leagueWith([
        played(
          home: 'me',
          away: 'opp',
          homeGoals: 1,
          awayGoals: 2,
          events: [
            MatchEvent(
                minute: 20, teamId: 'me', type: MatchEventType.goal),
            MatchEvent(
                minute: 60, teamId: 'opp', type: MatchEventType.goal),
            MatchEvent(
                minute: 88, teamId: 'opp', type: MatchEventType.goal),
          ],
        ),
      ]);

      final p = SeasonAnalysisEngine.goalsByPeriod(league, 'me');

      expect(p.firstFor, 1);
      expect(p.secondAgainst, 2);
      expect(p.lateAgainst, 1, reason: '88分の失点は終盤に数えるべき');
    });

    test('先制しながら負けた試合を数える', () {
      final league = leagueWith([
        played(
          home: 'me',
          away: 'opp',
          homeGoals: 1,
          awayGoals: 2,
          events: [
            MatchEvent(
                minute: 10, teamId: 'me', type: MatchEventType.goal),
            MatchEvent(
                minute: 50, teamId: 'opp', type: MatchEventType.goal),
            MatchEvent(
                minute: 80, teamId: 'opp', type: MatchEventType.goal),
          ],
        ),
      ]);

      expect(SeasonAnalysisEngine.gamesLostFromAhead(league, 'me'), 1);
    });

    test('先に失点して負けた試合は数えない', () {
      final league = leagueWith([
        played(
          home: 'me',
          away: 'opp',
          homeGoals: 0,
          awayGoals: 1,
          events: [
            MatchEvent(
                minute: 10, teamId: 'opp', type: MatchEventType.goal),
          ],
        ),
      ]);

      expect(SeasonAnalysisEngine.gamesLostFromAhead(league, 'me'), 0);
    });
  });
}
