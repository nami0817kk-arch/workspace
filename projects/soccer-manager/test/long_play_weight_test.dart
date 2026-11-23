import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/logic/ai_transfer_engine.dart';
import 'package:soccer_manager/logic/awards_engine.dart';
import 'package:soccer_manager/logic/big_moment.dart';
import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/logic/pre_contract_engine.dart';
import 'package:soccer_manager/models/league.dart';
import 'package:soccer_manager/models/league_theme.dart';
import 'package:soccer_manager/models/match_result.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/pre_contract.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/models/team.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 長く遊ぶと重く・大きくなる所の検査(2026-11-23)。
///
/// 10季回して測ると、AI 同士の仮契約で選手が世界中で純増し(1季に約100人、
/// 最大148人のクラブ)、セーブの3分の1が他のクラブの試合の出来事だった。
/// 直したあとも、人数の上限・誕生日の結果・古い試合の読み込みが崩れない
/// ことを確かめる。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Player make(String id, {int age = 25, int endYear = 2030, int tier = 60}) {
    final p = PlayerGenerator.generate(
        position: Position.mc, strengthTier: tier, ageOverride: age);
    return Player.fromJson({...p.toJson(), 'id': id})
      ..contractEndYear = endYear
      ..contractOption = false;
  }

  group('1. AI 同士の仮契約で人数が上限を超えない', () {
    setUp(() => Player.contractClockYear = 2027);

    test('上限の人数のクラブは行き先にならない', () {
      final from = Team(id: 'a', name: 'A', players: [
        for (var i = 0; i < 6; i++) make('a$i', endYear: 2027),
      ]);
      final full = Team(id: 'full', name: 'Full', players: [
        for (var i = 0; i < AiTransferEngine.maxSquadSize; i++) make('f$i'),
      ]);
      final made = PreContractEngine.openSeasonForAi(
        [from, full],
        'user',
        _FixedRandom(0.99, preContract: 0.0),
        today: DateTime(2027, 1, 1),
        maxSquad: AiTransferEngine.maxSquadSize,
      );
      expect(made, isEmpty, reason: '行き先が上限ならどこにも行かない');
    });

    test('結んだ仮契約の数も数えて、上限で止める', () {
      final from = Team(id: 'a', name: 'A', players: [
        for (var i = 0; i < 8; i++) make('a$i', endYear: 2027),
      ]);
      final near = Team(id: 'near', name: 'Near', players: [
        for (var i = 0; i < AiTransferEngine.maxSquadSize - 2; i++) make('n$i'),
      ]);
      final made = PreContractEngine.openSeasonForAi(
        [from, near],
        'user',
        _FixedRandom(0.99, preContract: 0.0),
        today: DateTime(2027, 1, 1),
        maxSquad: AiTransferEngine.maxSquadSize,
      );
      expect(made.length, 2, reason: '空きは2人ぶん');
      // すでに向かっている仮契約も数える。
      final again = PreContractEngine.openDomesticForAi(
        [from, near],
        'user',
        _FixedRandom(0.0),
        country: _anyCountry,
        countryOf: (_) => _anyCountry,
        today: DateTime(2027, 6, 1),
        alreadyTaken: {for (final c in made) c.playerId},
        maxSquad: AiTransferEngine.maxSquadSize,
        incoming: {'near': made.length},
      );
      expect(again, isEmpty);
    });

    test('季の切り替え: 受け入れ側は上限を超えず、出した側は最低人数を割るときだけ若手で埋める', () async {
      final game = GameState();
      await game.startNewGame('人数FC');
      final s = game.save!;
      final cpus = s.league.teams.where((t) => t.id != s.userTeamId).toList();
      final to = cpus[0];
      final from = cpus[1];
      // 受け入れ側を上限ちょうどにする。足す選手は弱くしておく(強いと、
      // 3部の仮契約の選手のほうが一番弱くなり、押し出されてしまう)。
      while (to.players.length < AiTransferEngine.maxSquadSize) {
        to.players.add(make('pad${to.players.length}', tier: 20));
      }
      final clock = Player.contractClockYear;
      // 移るのは出す側の強い3人(弱い選手だと、上限に合わせて押し出す
      // 「一番弱い選手」に当たることがある。CI で起きた)。
      final movers = ([...from.players.where((p) => !p.isLoan)]
            ..sort((a, b) => b.overall.compareTo(a.overall)))
          .take(3)
          .toList();
      for (final p in movers) {
        s.preContracts.add(PreContract(
          playerId: p.id,
          playerName: p.name,
          fromClubId: from.id,
          fromClubName: from.name,
          toClubId: to.id,
          toClubName: to.name,
          wage: p.wage,
          endYear: clock + 3,
          option: false,
          signedOn: DateTime(clock, 1, 1),
        ));
      }
      final fromBefore = from.players.length;
      game.debugSettleContractsAtSeasonStart();
      expect(
          to.players.length, lessThanOrEqualTo(AiTransferEngine.maxSquadSize));
      for (final p in movers) {
        expect(to.players.any((x) => x.id == p.id), isTrue,
            reason: '仮契約の選手は移る(押し出されるのは一番弱い選手)');
      }
      if (fromBefore - movers.length >= minSquadSize) {
        expect(
            from.players.length, lessThanOrEqualTo(fromBefore - movers.length),
            reason: '最低人数を割らないなら若手は足さない');
      }
      expect(from.players.length, greaterThanOrEqualTo(minSquadSize));
    });

    test('古いセーブで膨らんだ CPU のクラブは、季の切り替えで上限まで減る(自クラブは除く)', () async {
      final game = GameState();
      await game.startNewGame('膨張FC');
      final s = game.save!;
      final cpu = s.league.teams.firstWhere((t) => t.id != s.userTeamId);
      final foreign = s.foreignLeagues.values.first.teams.first;
      for (var i = 0; i < 60; i++) {
        cpu.players.add(make('big$i', tier: 30));
        foreign.players.add(make('fbig$i', tier: 30));
      }
      final strongest =
          cpu.players.reduce((a, b) => a.overall >= b.overall ? a : b);
      final userBefore = game.userTeam.players.length;
      game.debugSettleContractsAtSeasonStart();
      expect(
          cpu.players.length, lessThanOrEqualTo(AiTransferEngine.maxSquadSize));
      expect(foreign.players.length,
          lessThanOrEqualTo(AiTransferEngine.maxSquadSize));
      expect(cpu.players.contains(strongest), isTrue, reason: '外すのは弱い選手から');
      for (final id in cpu.startingXI) {
        expect(cpu.players.any((p) => p.id == id), isTrue, reason: '先発の参照切れ');
      }
      expect(game.userTeam.players.length, lessThanOrEqualTo(userBefore));
    });

    test('3季回しても、どの CPU のクラブも上限を超えない', () async {
      final game = GameState();
      await game.startNewGame('三季FC');
      for (var season = 0; season < 3; season++) {
        var guard = 0;
        while (!game.save!.league.isSeasonComplete && guard++ < 60) {
          await game.simulateAheadMatchdays(10);
        }
        await game.startNextSeason();
        final s = game.save!;
        for (final t in [
          ...s.allTeams,
          for (final l in s.foreignLeagues.values) ...l.teams,
        ]) {
          if (t.id == s.userTeamId) continue;
          expect(t.players.length,
              lessThanOrEqualTo(AiTransferEngine.maxSquadSize),
              reason: '${t.name} S${season + 1}');
        }
      }
    }, timeout: const Timeout(Duration(minutes: 15)));
  });

  group('2. 誕生日', () {
    int reference(Player p, DateTime before, DateTime after) {
      if (!after.isAfter(before)) return 0;
      var n = 0;
      for (var y = before.year; y <= after.year; y++) {
        final b = DateTime(y, p.birthMonth, p.birthDay);
        if (b.isAfter(before) && !b.isAfter(after)) n++;
      }
      return n;
    }

    test('整数で比べても、前の数え方と同じ結果になる', () {
      final rng = Random(7);
      final players = [for (var i = 0; i < 300; i++) make('b$i')];
      for (var k = 0; k < 3000; k++) {
        final p = players[rng.nextInt(players.length)];
        final before = DateTime(2025 + rng.nextInt(3), 1 + rng.nextInt(12),
            1 + rng.nextInt(28), rng.nextInt(2) * 13);
        final after = before.add(Duration(days: rng.nextInt(800) - 30));
        expect(p.birthdaysBetween(before, after), reference(p, before, after),
            reason: '${p.id} $before → $after');
      }
      // 誕生日の当日・前日の端。
      for (final p in players.take(50)) {
        final b = DateTime(2026, p.birthMonth, p.birthDay);
        final prev = b.subtract(const Duration(days: 1));
        expect(p.birthdaysBetween(prev, b), reference(p, prev, b));
        expect(p.birthdaysBetween(b, b.add(const Duration(days: 1))),
            reference(p, b, b.add(const Duration(days: 1))));
      }
    });

    test('日を送ったとき、誰が歳を取るかは前と同じ', () async {
      final game = GameState();
      await game.startNewGame('誕生FC');
      final s = game.save!;
      final start = game.today;
      final players = s.allPlayers.toList();
      final legends = s.retiredLegends.toSet();
      final ages = {for (final p in players) p: p.age};
      var day = start;
      final end = start.add(const Duration(days: 400));
      final rng = Random(3);
      while (day.isBefore(end)) {
        day = day.add(Duration(days: 1 + rng.nextInt(9)));
        game.debugAdvanceTodayTo(day);
      }
      for (final p in players) {
        if (legends.contains(p)) continue;
        if (!s.allPlayers.contains(p)) continue; // 引退・入れ替わり
        expect(p.age, ages[p]! + reference(p, start, game.today),
            reason: p.name);
      }
    }, timeout: const Timeout(Duration(minutes: 5)));
  });

  group('4. 他のクラブの試合は出来事を絞って残す', () {
    MatchResult full() => MatchResult(
          matchday: 3,
          homeTeamId: 'h',
          awayTeamId: 'a',
          homeGoals: 2,
          awayGoals: 1,
          events: [
            MatchEvent(
                minute: 5,
                teamId: 'h',
                scorerId: 'h1',
                scorerName: 'H1',
                type: MatchEventType.chance),
            MatchEvent(
                minute: 12,
                teamId: 'h',
                scorerId: 'h1',
                scorerName: 'H1',
                assistId: 'h2',
                assistName: 'H2'),
            MatchEvent(
                minute: 30,
                teamId: 'a',
                scorerId: 'a1',
                scorerName: 'A1',
                type: MatchEventType.yellowCard),
            MatchEvent(
                minute: 46,
                teamId: 'a',
                scorerId: 'a9',
                scorerName: 'A9',
                assistId: 'a3',
                assistName: 'A3',
                type: MatchEventType.substitution),
            MatchEvent(
                minute: 60,
                teamId: 'a',
                scorerId: 'a1',
                scorerName: 'A1',
                setPiece: SetPieceKind.penalty),
            MatchEvent(
                minute: 77,
                teamId: 'h',
                scorerId: 'h5',
                scorerName: 'H5',
                type: MatchEventType.redCard),
            MatchEvent(
                minute: 88, teamId: 'h', scorerId: 'h1', scorerName: 'H1'),
          ],
          playerRatings: {'h1': 8.5, 'h2': 7.0, 'a1': 6.5, 'agk': 6.0},
          homePossession: 55,
          awayPossession: 45,
          homeShots: 12,
          awayShots: 7,
          homeShotsOnTarget: 5,
          awayShotsOnTarget: 3,
        );

    test('得点・警告・退場・スコア・統計・採点は残り、決定機と交代は消える', () {
      final r = full();
      final a = r.archived();
      expect(a.events.map((e) => e.type), [
        MatchEventType.goal,
        MatchEventType.yellowCard,
        MatchEventType.goal,
        MatchEventType.redCard,
        MatchEventType.goal,
      ]);
      expect(a.events[0].assistId, 'h2');
      expect(a.events[2].setPiece, SetPieceKind.penalty);
      expect(a.homeGoals, 2);
      expect(a.homeShots, 12);
      expect(a.awayShotsOnTarget, 3);
      expect(a.manOfTheMatchId, r.manOfTheMatchId);
      expect(a.playerRatings, r.playerRatings);
      expect(identical(a.archived(), a), isTrue, reason: '二度目は何もしない');
    });

    test('賞(得点王・アシスト・MVP・無失点)は、絞った試合でも同じに出る', () {
      Team side(String id, List<String> ids, {String? gk}) => Team(
            id: id,
            name: id,
            players: [
              for (final pid in ids) make(pid),
              if (gk != null)
                Player.fromJson({
                  ...PlayerGenerator.generate(
                          position: Position.gk, strengthTier: 60)
                      .toJson(),
                  'id': gk,
                }),
            ],
          );
      final home = side('h', ['h1', 'h2', 'h5']);
      final away = side('a', ['a1', 'a3', 'a9'], gk: 'agk');
      final cleanSheet = MatchResult(
        matchday: 4,
        homeTeamId: 'a',
        awayTeamId: 'h',
        homeGoals: 1,
        awayGoals: 0,
        events: [
          MatchEvent(
              minute: 3,
              teamId: 'a',
              scorerId: 'a1',
              scorerName: 'A1',
              type: MatchEventType.chance),
          MatchEvent(minute: 9, teamId: 'a', scorerId: 'a1', scorerName: 'A1'),
        ],
        playerRatings: {'agk': 7.0, 'a1': 7.5},
      );
      League league(List<MatchResult> rs) => League(teams: [
            home,
            away
          ], fixtures: [
            for (final r in rs)
              Fixture(
                  matchday: r.matchday,
                  homeTeamId: r.homeTeamId,
                  awayTeamId: r.awayTeamId,
                  result: r),
          ]);
      final before = league([full(), cleanSheet]);
      final after = league([full().archived(), cleanSheet.archived()]);
      final a1 = AwardsEngine.computeAwards(before, 1);
      final a2 = AwardsEngine.computeAwards(after, 1);
      expect(a2.topScorerId, a1.topScorerId);
      expect(a2.topScorerGoals, a1.topScorerGoals);
      expect(a2.mvpId, a1.mvpId);
      expect(a2.goldenGloveId, a1.goldenGloveId);
      expect(a2.goldenGloveCleanSheets, a1.goldenGloveCleanSheets);
      expect(AwardsEngine.assistRanking(after).map((e) => e.playerId),
          AwardsEngine.assistRanking(before).map((e) => e.playerId));
      expect(AwardsEngine.goalRanking(after).map((e) => e.count),
          AwardsEngine.goalRanking(before).map((e) => e.count));
    });

    test('古いセーブ(全部の出来事を持つ)を読める。読むと他のクラブの試合は絞られ、自クラブの試合は残る', () async {
      final game = GameState();
      await game.startNewGame('旧形式FC');
      final s = game.save!;
      final userId = s.userTeamId;
      final other = s.league.fixtures
          .firstWhere((f) => f.homeTeamId != userId && f.awayTeamId != userId);
      final mine = s.league.fixtures
          .firstWhere((f) => f.homeTeamId == userId || f.awayTeamId == userId);
      MatchResult forFixture(Fixture f) {
        final r = full();
        return MatchResult(
          matchday: f.matchday,
          homeTeamId: f.homeTeamId,
          awayTeamId: f.awayTeamId,
          homeGoals: r.homeGoals,
          awayGoals: r.awayGoals,
          events: r.events,
          playerRatings: r.playerRatings,
        );
      }

      other.result = forFixture(other);
      mine.result = forFixture(mine);
      // 前の形の書き出し(null の項目も全部書く)。
      final json = jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>;
      final fixtures = ((json['league'] as Map)['fixtures'] as List)
          .cast<Map<String, dynamic>>();
      for (final f in fixtures) {
        final r = f['result'] as Map<String, dynamic>?;
        if (r == null) continue;
        for (final k in [
          'homePossession',
          'awayPossession',
          'homeShots',
          'awayShots',
          'homeShotsOnTarget',
          'awayShotsOnTarget',
        ]) {
          r.putIfAbsent(k, () => null);
        }
      }
      final restored = SaveGame.fromJson(json);
      final ro = restored.league.fixtures.firstWhere((f) =>
          f.matchday == other.matchday && f.homeTeamId == other.homeTeamId);
      final rm = restored.league.fixtures.firstWhere((f) =>
          f.matchday == mine.matchday && f.homeTeamId == mine.homeTeamId);
      expect(ro.result!.events.any((e) => e.type == MatchEventType.chance),
          isFalse);
      expect(
          ro.result!.events.where((e) => e.type == MatchEventType.goal).length,
          3);
      expect(rm.result!.events.length, full().events.length,
          reason: '自クラブの試合は全部残す');
    });

    test('節を進めると、他のクラブの試合は絞られ、自クラブの試合は全部残る', () async {
      final game = GameState();
      await game.startNewGame('節FC');
      await game.simulateAheadMatchdays(3);
      final s = game.save!;
      final userId = s.userTeamId;
      var mineHasChances = false;
      for (final f in s.league.fixtures) {
        final r = f.result;
        if (r == null) continue;
        final isMine = f.homeTeamId == userId || f.awayTeamId == userId;
        if (isMine) {
          if (r.events.any((e) => e.type == MatchEventType.chance)) {
            mineHasChances = true;
          }
        } else {
          expect(
              r.events.any((e) =>
                  e.type == MatchEventType.chance ||
                  e.type == MatchEventType.substitution),
              isFalse);
        }
      }
      expect(mineHasChances, isTrue);
      // 選手の今季の成績(画面)も、絞った試合から出せる。
      final scorer = s.league.fixtures
          .where((f) => f.result != null)
          .expand((f) => f.result!.events)
          .firstWhere(
              (e) => e.type == MatchEventType.goal && e.scorerId != null);
      expect(game.seasonStatsFor(scorer.scorerId!).goals, greaterThan(0));
    }, timeout: const Timeout(Duration(minutes: 5)));
  });

  group('3. まとめて進めるときの保存', () {
    test('simulateAheadMatchdays は最後に1回だけ書く。1節ずつなら節ごとに書く', () async {
      final game = GameState();
      await game.startNewGame('保存FC');
      final before = game.debugSaveWriteCount;
      await game.simulateAheadMatchdays(4);
      expect(game.debugSaveWriteCount - before, 1);
      final prefs = await SharedPreferences.getInstance();
      final saved = SaveGame.fromJson(jsonDecode(
              prefs.getString('soccer_manager_save_slot_${game.currentSlot}')!)
          as Map<String, dynamic>);
      expect(saved.league.fixtures.where((f) => f.result != null).length,
          game.save!.league.fixtures.where((f) => f.result != null).length,
          reason: '最後の1回に全部が載っている');

      final mid = game.debugSaveWriteCount;
      await game.playNextMatchday();
      expect(game.debugSaveWriteCount - mid, 1, reason: '1節ずつなら前半のあとも書く');
      await game.playSecondHalf();
      expect(game.debugSaveWriteCount - mid, 2);
    }, timeout: const Timeout(Duration(minutes: 5)));
  });

  group('5. CPU の不満度の更新', () {
    test('順位表は1回だけ作る(結果は同じ)', () async {
      final game = GameState();
      await game.startNewGame('順位FC');
      await game.simulateAheadMatchdays(3);
      final league = game.save!.league;
      final rankOf = game.debugStandingRanks(league);
      final rows = league.sortedStandings;
      for (var i = 0; i < rows.length; i++) {
        expect(rankOf[rows[i].teamId], i + 1);
      }
    }, timeout: const Timeout(Duration(minutes: 5)));
  });

  group('7. 大事な場面の待ち行列', () {
    test('上限を超えたら古いものから捨てる', () async {
      final game = GameState();
      await game.startNewGame('場面FC');
      final s = game.save!;
      for (var i = 0; i < 50; i++) {
        game.debugQueueMoment(BigMomentKind.recordSigning, 'k$i', 't$i', 'b$i');
      }
      expect(s.pendingMoments.length, GameState.maxPendingMoments);
      expect(s.pendingMoments.last[1], 't49');
      expect(s.pendingMoments.first[1], 't${50 - GameState.maxPendingMoments}');
    });
  });
}

/// AI 同士の仮契約の国(テストではどこでもよい。1月1日に国内とも結べる国)。
const _anyCountry = LeagueTheme.spain;

/// 1回目(更新するか)は[renew]、2回目(仮契約を結ぶか)は[preContract]、
/// 行き先のくじは0を返す。
class _FixedRandom implements Random {
  final double renew;
  final double preContract;
  int _calls = 0;
  _FixedRandom(this.renew, {double? preContract})
      : preContract = preContract ?? renew;
  @override
  double nextDouble() => (_calls++ % 2 == 0) ? renew : preContract;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
}
