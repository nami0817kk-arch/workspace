import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/logic/country_coefficient.dart';
import 'package:soccer_manager/logic/season_tickets.dart';
import 'package:soccer_manager/models/ledger.dart';
import 'package:soccer_manager/models/league_theme.dart';
import 'package:soccer_manager/models/owner_event.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/state/game_state.dart';

/// お金・大会・その他の「ゲームの中でつじつまが合わない」ものを直した
/// 挙動を固定する(2026-11-22)。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<GameState> start() async {
    final gs = GameState();
    await gs.startNewGame('テストFC');
    return gs;
  }

  /// 自国の係数を他国より大きくして、出場枠を最大(5)にする。
  void topCoefficient(GameState gs) {
    gs.save!.countryCoefficients[gs.currentLeagueTheme.name] =
        List<double>.filled(5, 1000);
  }

  group('1. 大陸大会の出場枠は、印・文言・予想も判定と同じ数', () {
    // 2026-11-22: CL の枠を実在の数(1・2位5、3・4位4、5位3)にした。
    // 出場は季の締めで大会を組むときに決まる(qualifiedForContinentalCup は
    // 「今季、大陸大会に出ているか」)。前季の順位を入れて組み直して確かめる。
    test('係数で枠が5になると、前季5位でも出場資格がある', () async {
      final gs = await start();
      topCoefficient(gs);
      expect(gs.continentalSpots, CountryCoefficientEngine.spotsForRank(1));
      expect(gs.continentalSpots, 5);
      final s = gs.save!;
      final me = s.league.teams.firstWhere((t) => t.id == s.userTeamId);
      void finishAt(int rank) {
        final order = [...s.otherDivisionLeagues[0]!.teams]
          ..insert(rank - 1, me);
        gs.debugSetUpContinentalCups(order);
      }

      finishAt(5);
      expect(gs.qualifiedForContinentalCup, isTrue);
      expect(gs.continentalCup!.level, 1, reason: '5位はチャンピオンズカップ');
      finishAt(6);
      expect(gs.continentalCup!.level, 2, reason: '6位はヨーロッパカップ');
      finishAt(8);
      expect(gs.qualifiedForContinentalCup, isFalse);
    });

    test('順位予想の「大陸カップ出場」は、枠の数(5)だけのクラブに配られる', () async {
      final gs = await start();
      topCoefficient(gs);
      gs.save!.currentDivisionTier = 1;
      final total = gs.seasonProjection.fold<double>(
        0,
        (s, p) => s + p.continentalProbability,
      );
      // どの試行でも上位 continentalSpots クラブが出場するので、確率の
      // 合計は枠の数と同じになる(以前は 2 で固定)。
      expect(total, closeTo(gs.continentalSpots.toDouble(), 0.01));
    });

    test('2部以下では、予想に大陸カップ出場は出ない', () async {
      final gs = await start();
      topCoefficient(gs);
      final total = gs.seasonProjection.fold<double>(
        0,
        (s, p) => s + p.continentalProbability,
      );
      expect(total, 0);
    });
  });

  group('2. 貸し出しのレンタル料', () {
    test('ふつうに貸し出すと、市場価値の決まった割合が選手の売却の区分に入る', () async {
      final gs = await start();
      expect(gs.isTransferWindowOpen, isTrue);
      final p = gs.userTeam.players.firstWhere((p) => !p.isLoan);
      final fee =
          (p.marketValue * GameStateTransfer.standardLoanFeePercent / 100)
              .round();
      expect(fee, greaterThan(0));
      expect(gs.loanOutFeeFor(p), fee);
      final budget = gs.save!.budget;
      final sales = gs.currentLedger.of(LedgerCategory.playerSales);
      expect(await gs.loanOutPlayer(p.id), isTrue);
      expect(gs.save!.budget, budget + fee);
      expect(gs.currentLedger.of(LedgerCategory.playerSales), sales + fee);
    });

    test('貸すときと借りるときは同じ割合(市場価値の2割)', () {
      expect(
        GameStateTransfer.standardLoanFeePercent,
        GameState.loanFeeRatioPercent,
      );
    });

    test('出場機会を約束させると、レンタル料は入らない', () async {
      final gs = await start();
      final p = gs.userTeam.players.firstWhere((p) => !p.isLoan);
      expect(gs.loanOutFeeFor(p, guaranteePlayingTime: true), 0);
      final budget = gs.save!.budget;
      expect(await gs.loanOutPlayer(p.id, guaranteePlayingTime: true), isTrue);
      expect(gs.save!.budget, budget);
    });
  });

  group('3. 年間シートを売ったあとの、お金の予定の試合収入', () {
    test('先に受け取ったぶん、予定の試合収入が減る', () async {
      final gs = await start();
      final s = gs.save!;
      final md = s.league.fixtures
          .map((f) => f.matchday)
          .firstWhere((m) => gs.holidayOfMatchday(m) == null);
      final before = gs.expectedMatchdayIncome(md);
      final gate = gs.weeklyIncomeParts(s.userTeamId).gate;
      expect(gate, greaterThan(0));
      expect(await gs.sellSeasonTickets(50), isTrue);
      final after = gs.expectedMatchdayIncome(md);
      expect(
        after,
        before - (gate - SeasonTicketEngine.remainingGate(gate, 50)),
      );
      expect(after, lessThan(before));
      // お金の予定の一覧にも、減った額が出る。
      final row = gs
          .upcomingMoneyDates(count: 200)
          .where((r) => r.date == gs.dateOfMatchday(md))
          .where((r) => r.amount == after);
      expect(row, isNotEmpty);
    });
  });

  group('4. オーナーの本業の収入は、クラブの部で変わらない', () {
    test('3部でも1部でも、毎月同じ額が入る', () async {
      Future<int> gainAt(int tier) async {
        final gs = await start();
        gs.save!.currentDivisionTier = tier;
        final w = gs.ownerWealth;
        final d = gs.today;
        gs.debugAdvanceTodayTo(DateTime(d.year, d.month + 1, 2));
        return gs.ownerWealth - w;
      }

      final low = await gainAt(3);
      final top = await gainAt(1);
      expect(low, GameStateOwner.monthlyIncome);
      expect(top, GameStateOwner.monthlyIncome);
    });
  });

  group('5. 観客動員の表示はホームの試合だけ', () {
    test('アウェイの節では、前のホームの試合の人数のまま', () async {
      final gs = await start();
      final s = gs.save!;
      final uid = s.userTeamId;
      var checkedAway = false;
      var checkedHome = false;
      for (var i = 0; i < 6 && !(checkedAway && checkedHome); i++) {
        final next = s.league.fixtures
            .where(
              (f) =>
                  f.result == null &&
                  (f.homeTeamId == uid || f.awayTeamId == uid),
            )
            .reduce((a, b) => a.matchday <= b.matchday ? a : b);
        final home = next.homeTeamId == uid;
        gs.lastMatchAttendance = 12345;
        expect(await gs.playNextMatchdayQuickSim(), isNotNull);
        if (home) {
          expect(gs.lastMatchAttendance, isNot(12345));
          checkedHome = true;
        } else {
          expect(
            gs.lastMatchAttendance,
            12345,
            reason: 'アウェイで自分のスタジアムの人数を出さない',
          );
          checkedAway = true;
        }
      }
      expect(checkedAway, isTrue);
      expect(checkedHome, isTrue);
    });
  });

  group('7. クラブを替えると、クラブの記録は新しくなる', () {
    void fillRecords(GameState gs) {
      final s = gs.save!;
      s.clubApps['x'] = 120;
      s.clubGoals['x'] = 40;
      s.clubRecordNames['x'] = '昔の英雄';
      s.biggestWin = '1季 7-0 どこか';
      s.biggestWinMargin = 7;
    }

    void expectEmpty(GameState gs) {
      final s = gs.save!;
      expect(s.clubApps, isEmpty);
      expect(s.clubGoals, isEmpty);
      expect(s.clubRecordNames, isEmpty);
      expect(s.biggestWin, isNull);
      expect(s.biggestWinMargin, 0);
      expect(gs.clubAppsLeaders(), isEmpty);
    }

    test('同じ国のクラブを買い直すと、記録は空から。殿堂は残る', () async {
      final gs = await start();
      fillRecords(gs);
      gs.save!
        ..confidence = 0
        ..supporterUltimatumUntil = DateTime(2000);
      expect(await gs.buyClub(gs.buyoutCandidates.first.id), isTrue);
      expectEmpty(gs);
      expect(gs.save!.ownerLegacies, hasLength(1));
    });

    test('別の国でクラブを立ち上げても、記録は空から。殿堂は残る', () async {
      final gs = await start();
      fillRecords(gs);
      gs.save!
        ..confidence = 0
        ..supporterUltimatumUntil = DateTime(2000);
      final other = LeagueTheme.values.firstWhere(
        (t) => t != gs.currentLeagueTheme,
      );
      expect(await gs.buyClubInCountry(other), isTrue);
      expectEmpty(gs);
      expect(gs.save!.ownerLegacies, hasLength(1));
    });
  });

  group('8. オーナーの事件は、本文が言っていることを実際に起こす', () {
    test('「売却を認める」と、いちばん価値の高い選手が売れて移籍金が入る', () async {
      final gs = await start();
      final s = gs.save!;
      final ace = ([
        ...gs.userTeam.players.where((p) => !p.isLoan),
      ]..sort((a, b) => b.marketValue.compareTo(a.marketValue)))
          .first;
      s.pendingOwnerEvent = OwnerEventKind.transferDemand;
      final budget = s.budget;
      final sales = gs.currentLedger.of(LedgerCategory.playerSales);
      expect(
        gs.ownerEventOptionEffect(OwnerEventKind.transferDemand, 1),
        contains(ace.name),
      );
      expect(await gs.resolveOwnerEvent(1), isTrue);
      expect(gs.userTeam.players.any((p) => p.id == ace.id), isFalse);
      expect(
        gs.currentLedger.of(LedgerCategory.playerSales),
        sales + ace.marketValue,
      );
      // 売却益の連帯貢献金などが引かれることはあっても、移籍金ぶんは増える。
      expect(s.budget, greaterThan(budget));
    });

    test('「慰留して残す(昇給を約束)」と、エースは残り給与が上がる', () async {
      final gs = await start();
      final s = gs.save!;
      final ace = ([
        ...gs.userTeam.players.where((p) => !p.isLoan),
      ]..sort((a, b) => b.marketValue.compareTo(a.marketValue)))
          .first;
      final wage = ace.wage;
      s.pendingOwnerEvent = OwnerEventKind.transferDemand;
      expect(await gs.resolveOwnerEvent(0), isTrue);
      expect(gs.userTeam.players.any((p) => p.id == ace.id), isTrue);
      expect(ace.wage, (wage * GameStateFinance.ownerEventAceRaise).round());
    });

    test('「主力が長期離脱」が起きると、主力が実際に長期の怪我をする', () async {
      final gs = await start();
      final s = gs.save!;
      var found = false;
      for (var season = 1; season < 400 && !found; season++) {
        s.league.season = season;
        s.pendingOwnerEvent = null;
        for (final p in gs.userTeam.players) {
          p.injuryWeeks = 0;
        }
        final best = ([
          ...gs.userTeam.players.where((p) => !p.isLoanedOut),
        ]..sort((a, b) => b.overall.compareTo(a.overall)))
            .first;
        gs.debugRaiseOwnerEvent(6);
        if (gs.pendingOwnerEvent != OwnerEventKind.injuryCrisis) continue;
        found = true;
        expect(best.injuryWeeks, GameStateFinance.ownerEventInjuryWeeks);
        expect(best.injuryType, InjuryType.ligament);
        expect(gs.userTeam.startingXI, isNot(contains(best.id)));
      }
      expect(found, isTrue);
    });

    test('首位のときは「成績への不満でスポンサー撤退」は起きない', () async {
      final gs = await start();
      final s = gs.save!;
      s.league.pointsAdjustments[s.userTeamId] = 100;
      expect(gs.ownerEventCanHappen(OwnerEventKind.sponsorExit), isFalse);
      for (var season = 1; season < 300; season++) {
        s.league.season = season;
        s.pendingOwnerEvent = null;
        gs.debugRaiseOwnerEvent(6);
        expect(gs.pendingOwnerEvent, isNot(OwnerEventKind.sponsorExit));
      }
      s.league.pointsAdjustments[s.userTeamId] = -100;
      expect(gs.ownerEventCanHappen(OwnerEventKind.sponsorExit), isTrue);
    });

    test('ユースがいなければ「ユースの逸材に引き抜き」は起きず、送り出すと実際に抜ける', () async {
      final gs = await start();
      final s = gs.save!;
      final saved = [...s.youthProspects];
      s.youthProspects.clear();
      expect(gs.ownerEventCanHappen(OwnerEventKind.youthPoach), isFalse);
      if (saved.isEmpty) return;
      s.youthProspects.addAll(saved);
      final best = ([
        ...saved,
      ]..sort((a, b) => b.potential.compareTo(a.potential)))
          .first;
      s.pendingOwnerEvent = OwnerEventKind.youthPoach;
      expect(await gs.resolveOwnerEvent(0), isTrue);
      expect(s.youthProspects.any((p) => p.id == best.id), isFalse);
    });
  });
}
