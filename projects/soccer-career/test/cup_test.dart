/// カップ戦を実際に戦えるか。
///
/// これまでカップ戦は `runDomesticCup` / `runContinental` が
/// シーズン末に**結果だけ**を振っていた。到達ラウンドは年俸にも評判にも
/// 記録にも効くのに、プレイヤーは1分もプレーしない。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/cups.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/game/national.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/competition.dart';
import 'package:soccer_career/models/cup.dart';
import 'package:soccer_career/game/world.dart';
import 'package:soccer_career/models/club.dart';
import 'package:soccer_career/models/season.dart';
import 'package:soccer_career/state/career_controller.dart';

class _MemoryRepository implements SaveRepository {
  CareerState? _saved;

  @override
  Future<CareerState?> load() async => _saved;

  @override
  Future<void> save(CareerState state) async => _saved = state;

  @override
  Future<void> clear() async => _saved = null;
}

Future<CareerController> started({int seed = 3}) async {
  final c = CareerController(
    repository: _MemoryRepository(),
    careerEngine: CareerEngine(random: Random(seed)),
    matchEngine: MatchEngine(random: Random(seed)),
    random: Random(seed),
  );
  await c.startCareer(
      name: '検証', position: Position.cm, age: 24, agent: Agent.pool.first);
  return c;
}

MatchResult cupResult({
  required CupKind kind,
  required int scored,
  required int conceded,
}) =>
    MatchResult(
      matchday: 1,
      opponentName: '相手',
      home: true,
      scored: scored,
      conceded: conceded,
      appearance: Appearance.start,
      rating: 7.0,
      goals: 0,
      assists: 0,
      cup: kind,
    );

void main() {
  group('日程', () {
    test('1週1試合の刻みを崩さない', () {
      // 代表ウィークとも、もう一方のカップともぶつけない。
      const matches = 38;
      final breaks = National.breakAfterMatchday.toSet();
      final domestic = Cups.weeksFor(
          matches: matches, count: Cups.domesticMatches, taken: breaks);
      final continental = Cups.weeksFor(
        matches: matches,
        count: Cups.continentalMatches,
        taken: {...breaks, ...domestic},
      );

      expect(domestic.length, Cups.domesticMatches);
      expect(continental.length, Cups.continentalMatches);
      for (final week in [...domestic, ...continental]) {
        expect(breaks.contains(week), isFalse, reason: '代表ウィークと重なっている');
      }
      expect(domestic.toSet().intersection(continental.toSet()), isEmpty);
      expect({...domestic}.length, domestic.length, reason: '同じ週が2回ある');
      expect({...continental}.length, continental.length);
    });

    test('短いリーグでもはみ出さない', () {
      // 16クラブの国は30試合。節を決め打ちにすると日程がはみ出す。
      for (final matches in [30, 34, 38, 46]) {
        final weeks = Cups.weeksFor(
            matches: matches, count: Cups.continentalMatches, taken: const {});
        expect(weeks.every((w) => w >= 1 && w < matches), isTrue,
            reason: '$matches試合ではみ出した');
      }
    });

    test('リーグの長さから毎回同じ日程が出る（保存しない）', () async {
      final c = await started();
      final state = c.state!;
      expect(state.domesticCupWeeks, state.domesticCupWeeks);
      expect(state.continentalCupWeeks.toSet()
          .intersection(state.domesticCupWeeks.toSet()), isEmpty);
    });
  });

  group('勝ち上がり', () {
    test('一発勝負は、負ければそこで終わり', () {
      final cups = Cups(random: Random(1));
      final run = CupRun(kind: CupKind.domestic, round: CupRound.round32);
      const tie = CupTie(
        kind: CupKind.domestic,
        round: CupRound.round32,
        opponentName: '相手',
        opponentStrength: 60,
        home: true,
      );
      cups.applyResult(
          run, tie, cupResult(kind: CupKind.domestic, scored: 0, conceded: 1));
      expect(run.eliminated, isTrue);
      expect(run.domesticStage, CupStage.early);
    });

    test('勝てば次のラウンドへ', () {
      final cups = Cups(random: Random(1));
      final run = CupRun(kind: CupKind.domestic, round: CupRound.round32);
      const tie = CupTie(
        kind: CupKind.domestic,
        round: CupRound.round32,
        opponentName: '相手',
        opponentStrength: 60,
        home: true,
      );
      cups.applyResult(
          run, tie, cupResult(kind: CupKind.domestic, scored: 2, conceded: 1));
      expect(run.round, CupRound.round16);
      expect(run.running, isTrue);
    });

    test('決勝に勝てば優勝', () {
      final cups = Cups(random: Random(1));
      final run = CupRun(kind: CupKind.domestic, round: CupRound.finalRound);
      const tie = CupTie(
        kind: CupKind.domestic,
        round: CupRound.finalRound,
        opponentName: '相手',
        opponentStrength: 60,
        home: false,
      );
      cups.applyResult(
          run, tie, cupResult(kind: CupKind.domestic, scored: 1, conceded: 0));
      expect(run.won, isTrue);
      expect(run.domesticStage, CupStage.winner);
      expect(run.domesticStage.qualifiesContinental, isTrue);
    });

    test('決勝に負ければ準優勝', () {
      final cups = Cups(random: Random(1));
      final run = CupRun(kind: CupKind.domestic, round: CupRound.finalRound);
      const tie = CupTie(
        kind: CupKind.domestic,
        round: CupRound.finalRound,
        opponentName: '相手',
        opponentStrength: 60,
        home: false,
      );
      cups.applyResult(
          run, tie, cupResult(kind: CupKind.domestic, scored: 0, conceded: 2));
      expect(run.domesticStage, CupStage.runnerUp);
    });

    test('引き分けはPK戦。決着はつく', () {
      var advanced = 0;
      for (var seed = 0; seed < 40; seed++) {
        final cups = Cups(random: Random(seed));
        // 一発勝負のラウンドで見る（2戦合計は第1戦で決着しない）。
        final run = CupRun(kind: CupKind.domestic, round: CupRound.round32);
        const tie = CupTie(
          kind: CupKind.domestic,
          round: CupRound.round32,
          opponentName: '相手',
          opponentStrength: 60,
          home: true,
        );
        cups.applyResult(run, tie,
            cupResult(kind: CupKind.domestic, scored: 1, conceded: 1));
        if (!run.eliminated) advanced++;
      }
      // 実力ではほとんど決まらない。ここを実力差にすると一発勝負の意味が消える。
      expect(advanced, greaterThan(8));
      expect(advanced, lessThan(32));
    });
  });

  group('2戦合計', () {
    Cups cups() => Cups(random: Random(1));

    CupTie secondLeg(CupRun run, int scored, int conceded) {
      const first = CupTie(
        kind: CupKind.continental,
        round: CupRound.round16,
        opponentName: '相手',
        opponentStrength: 70,
        home: false,
      );
      final next = cups().applyResult(run, first,
          cupResult(kind: CupKind.continental, scored: scored, conceded: conceded));
      return next!;
    }

    test('第1戦の結果を第2戦へ持ち越す', () {
      final run = CupRun(kind: CupKind.continental, round: CupRound.round16);
      final second = secondLeg(run, 1, 2);
      expect(second.leg, 2);
      expect(second.aggregateFor, 1);
      expect(second.aggregateAgainst, 2);
      expect(second.carriesAggregate, isTrue);
      expect(second.aggregateMargin, -1);
      // ホームとアウェイが入れ替わる。
      expect(second.home, isTrue);
      expect(run.running, isTrue, reason: '第1戦で敗退している');
    });

    test('合計で上回れば勝ち上がる', () {
      final run = CupRun(kind: CupKind.continental, round: CupRound.round16);
      final second = secondLeg(run, 1, 2);
      cups().applyResult(run, second,
          cupResult(kind: CupKind.continental, scored: 3, conceded: 1));
      expect(run.round, CupRound.quarter);
      expect(run.running, isTrue);
    });

    test('合計で下回れば敗退', () {
      final run = CupRun(kind: CupKind.continental, round: CupRound.round16);
      final second = secondLeg(run, 0, 2);
      cups().applyResult(run, second,
          cupResult(kind: CupKind.continental, scored: 1, conceded: 0));
      expect(run.eliminated, isTrue);
      expect(run.continentalStage, ContinentalStage.round16);
    });

    test('決勝だけは1試合（中立地）', () {
      expect(CupRound.finalRound.twoLegged, isFalse);
      expect(CupRound.finalRound.neutral, isTrue);
      expect(CupRound.round16.twoLegged, isTrue);
      expect(CupRound.quarter.twoLegged, isTrue);
      expect(CupRound.semi.twoLegged, isTrue);
    });
  });

  group('グループステージ', () {
    test('6試合を戦って、勝ち点で突破が決まる', () {
      CupRun runWith({required int wins, required int draws}) {
        final cups = Cups(random: Random(1));
        final run = CupRun(kind: CupKind.continental, round: CupRound.group);
        for (var i = 0; i < 6; i++) {
          final tie = CupTie(
            kind: CupKind.continental,
            round: CupRound.group,
            opponentName: '相手',
            opponentStrength: 70,
            home: i.isEven,
            groupMatch: i + 1,
          );
          final scored = i < wins ? 2 : (i < wins + draws ? 1 : 0);
          final conceded = i < wins ? 0 : (i < wins + draws ? 1 : 2);
          cups.applyResult(
              run,
              tie,
              cupResult(
                  kind: CupKind.continental,
                  scored: scored,
                  conceded: conceded));
        }
        return run;
      }

      final through = runWith(wins: 3, draws: 0);
      expect(through.groupPlayed, 6);
      expect(through.groupPoints, 9);
      expect(through.round, CupRound.round16);
      expect(through.running, isTrue);

      final out = runWith(wins: 1, draws: 1);
      expect(out.groupPoints, 4);
      expect(out.eliminated, isTrue);
      expect(out.continentalStage, ContinentalStage.group);
    });
  });

  group('大陸カップの出場権', () {
    /// 1部の上位に置く。
    void placeTop(CareerState state) {
      state.club = World.buildLeague('albion', 1).first;
      state.league = World.buildLeague('albion', 1);
      // 名簿を入れ替えたら日程も引き直す（`opponentFor` が引けなくなる）。
      state.fixtures = [
        for (var i = 0; i < (state.league.length - 1) * 2; i++)
          state.league[1 + i % (state.league.length - 1)].id,
      ];
      state.table = [
        for (final c in state.league) TableRow(clubId: c.id, clubName: c.name)
      ];
      for (final row in state.table) {
        row.won = row.clubId == state.club.id ? 30 : 1;
      }
    }

    test('前季の順位で、翌季の大陸カップが用意される', () async {
      final c = await started();
      final state = c.state!;
      placeTop(state);
      state.results = [
        for (var i = 0; i < state.fixtures.length; i++)
          MatchResult(
            matchday: i + 1,
            opponentName: state.opponentFor(i + 1).name,
            home: state.isHome(i + 1),
            scored: 2,
            conceded: 0,
            appearance: Appearance.start,
            rating: 7.5,
            goals: 1,
            assists: 0,
          ),
      ];
      final engine = CareerEngine(random: Random(1));
      expect(engine.inContinental(state), isTrue);
      final next =
          engine.advanceSeason(state, accepted: engine.renewalOffer(state));
      expect(next.continentalCup, isNotNull);
      expect(next.continentalCup!.round, CupRound.group);
      // 国内カップは毎年ある。
      expect(next.domesticCup, isNotNull);
    });

    test('出られない年は用意されない', () async {
      final c = await started();
      final state = c.state!;
      state.results = [
        for (var i = 0; i < state.fixtures.length; i++)
          MatchResult(
            matchday: i + 1,
            opponentName: state.opponentFor(i + 1).name,
            home: state.isHome(i + 1),
            scored: 0,
            conceded: 2,
            appearance: Appearance.start,
            rating: 6.0,
            goals: 0,
            assists: 0,
          ),
      ];
      final engine = CareerEngine(random: Random(1));
      final next =
          engine.advanceSeason(state, accepted: engine.renewalOffer(state));
      expect(next.continentalCup, isNull);
    });

    test('グループから決勝まで、実際に戦って辿り着ける', () async {
      // 6試合 + 2戦×3 + 決勝 = 13試合。
      final c = await started();
      final state = c.state!;
      placeTop(state);
      state.continentalCup =
          CupRun(kind: CupKind.continental, round: CupRound.group);
      final cups = Cups(random: Random(4));
      final run = state.continentalCup!;
      var played = 0;
      while (run.running && played < Cups.continentalMatches) {
        final tie = run.next ?? cups.drawTie(state, run);
        run.next = cups.applyResult(run, tie,
            cupResult(kind: CupKind.continental, scored: 3, conceded: 0));
        played++;
      }
      expect(run.won, isTrue, reason: '全勝しても優勝に辿り着けない');
      expect(played, Cups.continentalMatches);
      expect(run.continentalStage, ContinentalStage.winner);
    });
  });

  group('若手の出番', () {
    test('早いラウンドは、普段出られない選手にも回ってくる', () {
      expect(Cups.selectionBonus(CupRound.round32), greaterThan(0));
      expect(Cups.selectionBonus(CupRound.group), greaterThan(0));
      // 準々決勝から先はベストメンバー。
      expect(Cups.selectionBonus(CupRound.quarter), 0);
      expect(Cups.selectionBonus(CupRound.finalRound), 0);
      expect(Cups.rotatesIn(CupRound.finalRound), isFalse);
    });
  });

  group('リーグと混ぜない', () {
    test('カップ戦は節を進めず、順位表にも平均評価にも入らない', () async {
      final c = await started();
      final state = c.state!;
      final matchday = state.matchday;
      final table = state.sortedTable.first.points;

      state.pendingCup = const CupTie(
        kind: CupKind.domestic,
        round: CupRound.round32,
        opponentName: '相手',
        opponentStrength: 55,
        home: true,
      );
      c.startCupMatch();
      final result = await c.simulateMatch();

      expect(result!.cup, CupKind.domestic);
      expect(result.isLeague, isFalse);
      expect(state.matchday, matchday, reason: 'カップ戦で節が進んでいる');
      expect(state.seasonStats.appearances, 0, reason: '成績に混ざっている');
      expect(state.sortedTable.first.points, table, reason: '順位表が動いている');
      expect(state.cupResults.length, 1);
    });

    test('カップ戦の週は練習ができない', () async {
      // 連戦のぶんまで練習まで積めると、カップは「強くなるだけ」の装置になる。
      final c = await started();
      final state = c.state!;
      state.pendingCup = const CupTie(
        kind: CupKind.domestic,
        round: CupRound.round32,
        opponentName: '相手',
        opponentStrength: 55,
        home: true,
      );
      c.startCupMatch();
      await c.simulateMatch();
      expect(c.lastWeek.outcome, isNull, reason: '練習の手応えが出ている');
      expect(c.lastWeek.trained, isNull);
      expect(c.lastWeek.cup, isNotNull);
    });

    test('カップ戦でも消耗はする', () async {
      final c = await started();
      final state = c.state!;
      final before = state.player.condition;
      state.pendingCup = const CupTie(
        kind: CupKind.domestic,
        round: CupRound.round32,
        opponentName: '相手',
        opponentStrength: 55,
        home: true,
      );
      c.startCupMatch();
      await c.simulateMatch();
      expect(state.player.condition, lessThan(before));
    });
  });

  group('シーズンと保存', () {
    test('国内カップは毎年、開幕から用意されている', () async {
      final c = await started();
      expect(c.state!.domesticCup, isNotNull);
      expect(c.state!.domesticCup!.round, CupRound.round32);
      // 前季が無いので、大陸カップには出られない。
      expect(c.state!.continentalCup, isNull);
    });

    test('到達ラウンドは、戦った結果から決まる', () async {
      final c = await started();
      final state = c.state!;
      state.domesticCup = CupRun(
        kind: CupKind.domestic,
        round: CupRound.semi,
        eliminated: true,
      );
      CareerEngine(random: Random(1)).resolveSeasonEnd(state);
      expect(state.cupStage, CupStage.semi);
    });

    test('カップ戦を知らない保存データでも読める', () async {
      final c = await started();
      final json = c.state!.toJson()
        ..remove('domesticCup')
        ..remove('continentalCup')
        ..remove('pendingCup');
      final back = CareerState.fromJson(json);
      expect(back.domesticCup, isNull);
      expect(back.pendingCup, isNull);
      // 古い保存データは、これまでどおりその場で振って埋める。
      CareerEngine(random: Random(1)).resolveSeasonEnd(back);
      expect(back.cupStage.participated, isTrue);
    });

    test('戦っている途中は保存に乗る', () async {
      final c = await started();
      final state = c.state!;
      state.domesticCup = CupRun(
          kind: CupKind.domestic, round: CupRound.quarter, groupPoints: 0);
      state.pendingCup = const CupTie(
        kind: CupKind.domestic,
        round: CupRound.quarter,
        opponentName: '相手',
        opponentStrength: 66,
        home: true,
        leg: 2,
        aggregateFor: 1,
        aggregateAgainst: 1,
      );
      final back = CareerState.fromJson(state.toJson());
      expect(back.domesticCup!.round, CupRound.quarter);
      expect(back.pendingCup!.aggregateFor, 1);
      expect(back.pendingCup!.leg, 2);
    });
  });
}
