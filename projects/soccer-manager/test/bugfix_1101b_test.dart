import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/logic/fixture_generator.dart';
import 'package:soccer_manager/logic/lineup_utils.dart';
import 'package:soccer_manager/logic/loan_engine.dart';
import 'package:soccer_manager/logic/match_engine.dart';
import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/models/club_infrastructure.dart';
import 'package:soccer_manager/models/cup.dart';
import 'package:soccer_manager/models/formation.dart';
import 'package:soccer_manager/models/incoming_offer.dart';
import 'package:soccer_manager/models/live_match_progress.dart';
import 'package:soccer_manager/models/match_result.dart';
import 'package:soccer_manager/models/staff_member.dart';
import 'package:soccer_manager/models/team.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 2026-11-01 に見つかった不具合(4〜7e)の再現テスト。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<GameState> newGame([String name = '検査FC']) async {
    final g = GameState();
    await g.startNewGame(name);
    return g;
  }

  Future<GameState> restart() async {
    final g = GameState();
    await g.init();
    return g;
  }

  group('4. 試合の途中でアプリが終わっても週の処理を二重にかけない', () {
    test('再起動して同じ節を始めても、資金と負傷の週の処理はかからない', () async {
      final game = await newGame();
      final injured = game.userTeam.players
          .firstWhere((p) => !game.userTeam.startingXI.contains(p.id));
      injured.injuryWeeks = 5;

      final first = await game.playNextMatchday(interactive: true);
      expect(first, isNotNull, reason: '自クラブの試合が始まっていない');
      final budgetAfterWeek = game.save!.budget;
      expect(injured.injuryWeeks, 4);
      await game.flushPendingSave();

      // 試合の途中でアプリが終わった。
      final again = await restart();
      expect(again.save!.budget, budgetAfterWeek);
      final half = await again.playNextMatchday(interactive: true);
      expect(half, isNotNull, reason: '再開したのに試合が始まらない');
      expect(again.save!.budget, budgetAfterWeek,
          reason: '週の処理(収入・週給など)が二重にかかっている');
      final reloadedInjured =
          again.userTeam.players.firstWhere((p) => p.id == injured.id);
      expect(reloadedInjured.injuryWeeks, 4,
          reason: '負傷回復が二重にかかっている');

      // 試合を終えれば、次の節は普通に週の処理がかかる。
      while (again.pendingChanceDecision != null) {
        await again.resolveChanceDecision(ChanceDecision.shoot);
      }
      final result = await again.playSecondHalf();
      expect(result, isNotNull);
      expect(again.save!.liveMatchProgress, isNull,
          reason: '試合が終わったのに途中経過が残っている');
    });

    test('再開しても、確定していた得点は残る(落として引き直せない)', () async {
      final game = await newGame();
      await game.playNextMatchday();
      final fixture = game.liveFixture!;
      final userIsHome = fixture.homeTeamId == game.userTeam.id;
      // 前半を0-3で終えた状態を作る。
      game.save!.liveMatchProgress = LiveMatchProgress(
        season: game.save!.league.season,
        matchday: fixture.matchday,
        resumeMinute: 46,
        substitutionsUsed: 2,
        firstHalf: HalfTally(
          homeGoals: userIsHome ? 0 : 3,
          awayGoals: userIsHome ? 3 : 0,
          events: [
            for (final m in [10, 20, 30])
              MatchEvent(
                minute: m,
                teamId: userIsHome ? fixture.awayTeamId : fixture.homeTeamId,
              ),
          ],
          chanceCount: 3,
          possessionShareSum: 1.5,
        ),
        secondHalf: const HalfTally(),
      );
      // その状態で保存されていたことにする。
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'soccer_manager_save_slot_0', jsonEncode(game.save!.toJson()));

      final again = await restart();
      final half = await again.playNextMatchday();
      expect(half, isNotNull);
      final opponentGoals = userIsHome ? half!.awayGoals : half!.homeGoals;
      expect(opponentGoals, 3, reason: '前半の失点が消えて、引き直しになっている');
      expect(again.substitutionsUsed, 2, reason: '交代枠が戻っている');

      final result = await again.playSecondHalf();
      final finalOpponent = userIsHome ? result!.awayGoals : result!.homeGoals;
      expect(finalOpponent, greaterThanOrEqualTo(3));
    });
  });

  test('5. 残り1年の選手を買っても、次の切り替わりで退団しない', () async {
    final game = await newGame();
    final target = game.transferMarket.first;
    target.contractYearsRemaining = 1;
    target.age = 33;
    game.save!.budget = target.marketValue + 100;
    game.save!.wageBudget = 999999;

    expect(await game.buyPlayer(target.id), isTrue);
    expect(target.contractYearsRemaining, greaterThanOrEqualTo(2),
        reason: '買ったシーズンの終わりに契約が切れる');
  });

  test('6a. ローン満了で先発が抜けたら、空いた枠を埋めて11人で戦う', () async {
    final game = await newGame();
    final team = game.userTeam;
    final slots = team.formation.slots.length;
    expect(team.startingXI.length, slots);
    final leaving = team.players.firstWhere((p) => p.id == team.startingXI[3]);
    leaving.isLoan = true;
    leaving.loanWeeksRemaining = 1;
    final stay = team.startingXI.where((id) => id != leaving.id).toList();

    await game.playNextMatchday();

    expect(team.players.any((p) => p.id == leaving.id), isFalse);
    expect(team.startingXI.length, slots, reason: '抜けた枠が空いたまま');
    // 代表召集が重なると全体を組み直すことがあるので、残った先発の
    // 顔ぶれは下の fillVacancies 単体の検査で見る。
    expect(stay, isNotEmpty);
  });

  test('6a. fillVacancies は残っている先発を動かさない', () async {
    final team = PlayerGenerator.generateSquad(
        id: 't', name: 'T', strengthTier: 60);
    LineupUtils.autoFill(team);
    final removed = team.startingXI.removeAt(0);
    final kept = [...team.startingXI];
    LineupUtils.fillVacancies(team);
    expect(team.startingXI.length, team.formation.slots.length);
    expect(team.startingXI, containsAll(kept));
    expect(team.startingXI.where((id) => id == removed).length,
        lessThanOrEqualTo(1));
  });

  test('6b. ローン放出の人数判定に、放出中の選手を数えない', () async {
    final game = await newGame();
    final team = game.userTeam;
    // 手元に居る人数がちょうど最低人数になるまで貸し出し済みにする。
    final extra = team.players.length - minSquadSize;
    expect(extra, greaterThan(0));
    for (final p in team.players.take(extra)) {
      p.loanedOutWeeksRemaining = 5;
      p.loanedOutToClubName = 'どこか';
    }
    final candidate = team.players.firstWhere((p) => !p.isLoanedOut);

    final ok = await game.loanOutPlayer(candidate.id, 8);

    expect(ok, isFalse, reason: '試合に出せる人数が最低人数を割り込む');
  });

  test('6c. 保存した総合力に合うスカッドを作る(作り直すたびに弱くならない)', () {
    for (final target in [40, 55, 70, 85]) {
      final squad = PlayerGenerator.generateSquadWithOverall(
          id: 'x', name: 'X', targetOverall: target);
      expect((squad.overallRating - target).abs(), lessThanOrEqualTo(3),
          reason: '目標$targetに対して${squad.overallRating}');
    }
  });

  test('6d. 別ディビジョンの相手とのスーパーカップでも、相手に選手が居る', () async {
    final game = await newGame();
    await game.flushPendingSave();
    final again = await restart();
    final save = again.save!;
    final other = save.otherDivisionLeagues.firstWhere((l) => l != null)!;
    final opponent = other.teams.first;
    expect(opponent.players, isEmpty,
        reason: '前提: 別ディビジョンは再起動後に選手を持たない');
    save.pendingSuperCup = CupMatch(
      round: 1,
      homeTeamId: again.userTeam.id,
      awayTeamId: opponent.id,
    );

    final result = await again.playSuperCup();

    expect(result, isNotNull);
    expect(opponent.players, isNotEmpty, reason: '相手が0人のまま試合をしている');
  });

  test('6e. スタッフの入れ替えは、辞める人の週俸を引いて予算を見る', () async {
    final game = await newGame();
    final save = game.save!;
    final current = StaffMember(
      id: 'cur',
      name: '前任',
      age: 50,
      role: StaffRole.scout,
      attributes: const {StaffAttribute.judging: 5},
      wage: 50,
    );
    save.infrastructure.staff[StaffRole.scout] = current;
    final candidate = StaffMember(
      id: 'new',
      name: '後任',
      age: 45,
      role: StaffRole.scout,
      attributes: const {StaffAttribute.judging: 10},
      wage: 60,
    );
    save.staffCandidates.add(candidate);
    // 入れ替えると週俸は10増えるだけ。60を丸ごと足すと上限を超える。
    save.wageBudget = game.weeklyWageBill + 20;

    final ok = await game.hireStaff('new');

    expect(ok, isTrue, reason: game.lastSigningBlockReason ?? '');
  });

  test('7a. 小さな融資でも週の返済は0にならない', () {
    for (final term in LoanEngine.terms) {
      for (final principal in [1, 5, 10, 30]) {
        final weekly = LoanEngine.weeklyRepaymentFor(principal, term);
        expect(weekly, greaterThanOrEqualTo(1));
        expect(LoanEngine.totalRepaymentFor(principal, term),
            greaterThanOrEqualTo(principal),
            reason: '$principal万円を借りて、返す総額が元本を下回る');
      }
    }
    // 割り切れる額は余計に切り上げない(小数の誤差を拾わない)。
    expect(LoanEngine.weeklyRepaymentFor(100, LoanEngine.terms.first), 9);
  });

  test('7c. オファーで売った選手は、買ったクラブへ移る', () async {
    final game = await newGame();
    final target = game.userTeam.players
        .firstWhere((p) => !game.userTeam.startingXI.contains(p.id));
    final buyer = game.save!.league.teams
        .firstWhere((t) => t.id != game.userTeam.id);
    game.save!.incomingOffers.add(IncomingOffer(
      id: 'o1',
      playerId: target.id,
      playerName: target.name,
      buyerClubName: buyer.name,
      amount: 500,
    ));

    expect(await game.acceptIncomingOffer('o1'), isTrue);

    expect(buyer.players.any((p) => p.id == target.id), isTrue,
        reason: '売った選手がゲームから消えている');
    expect(game.userTeam.players.any((p) => p.id == target.id), isFalse);
  });

  test('7d. 1年目の自クラブもホームとアウェイが交互に近い', () {
    final teams = [
      for (var i = 0; i < teamsPerLeague; i++)
        Team(id: 't$i', name: 'T$i', players: const []),
    ];
    final fixtures = FixtureGenerator.generateDoubleRoundRobin(teams);
    final rounds = teamsPerLeague - 1;
    for (final t in teams) {
      final mine = fixtures
          .where((f) => f.homeTeamId == t.id || f.awayTeamId == t.id)
          .toList()
        ..sort((a, b) => a.matchday.compareTo(b.matchday));
      expect(mine.length, rounds * 2);
      final firstHalfHome = mine
          .where((f) => f.matchday <= rounds && f.homeTeamId == t.id)
          .length;
      expect(firstHalfHome, inInclusiveRange(rounds ~/ 2 - 1, rounds ~/ 2 + 1),
          reason: '${t.id} の前半戦のホームが$firstHalfHome試合');
      var run = 1;
      var longest = 1;
      for (var i = 1; i < mine.length; i++) {
        final prevHome = mine[i - 1].homeTeamId == t.id;
        final home = mine[i].homeTeamId == t.id;
        run = home == prevHome ? run + 1 : 1;
        if (run > longest) longest = run;
      }
      expect(longest, lessThanOrEqualTo(3),
          reason: '${t.id} は同じ側が$longest節続く');
    }
  });

  test('7e. スロットを消すと、壊れたとき用の控えも消える', () async {
    final game = await newGame('消すFC');
    await game.flushPendingSave();
    final again = await restart(); // 読み込みで控えが作られる
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('soccer_manager_save_backup'), isNotNull);

    await again.deleteSlot(0);

    expect(prefs.getString('soccer_manager_save_backup'), isNull,
        reason: '同じ枠の新しいセーブが壊れると、消したクラブに戻る');
  });
}
