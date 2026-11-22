import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/logic/ai_transfer_engine.dart';
import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/logic/transfer_terms_engine.dart';
import 'package:soccer_manager/models/ledger.dart';
import 'package:soccer_manager/models/league_theme.dart';
import 'package:soccer_manager/models/owner_event.dart';
import 'package:soccer_manager/models/pre_contract.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/models/sponsor.dart';
import 'package:soccer_manager/models/team.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 2026-11-23: 移籍・お金のつじつまが合わなかった7件を直した挙動を固定する
/// (降格の条項と年俸の水準は club_finance_reality_test.dart)。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<GameState> start({LeagueTheme? theme}) async {
    final gs = GameState();
    if (theme == null) {
      await gs.startNewGame('修正FC');
    } else {
      await gs.startNewGame('修正FC', theme: theme);
    }
    return gs;
  }

  List<Team> clubs(int n, int seed) => [
        for (var i = 0; i < n; i++)
          PlayerGenerator.generateSquad(
              id: 'c$i', name: 'C$i', strengthTier: 40 + (i * 7 + seed) % 30),
      ];

  group('1. CPU の移籍は、仮契約を結んだ選手を動かさない', () {
    test('runWeek: reserved の選手は買われも売られもしない', () {
      for (var seed = 0; seed < 8; seed++) {
        final teams = clubs(16, seed);
        final reserved = {
          for (final t in teams.take(8))
            for (final p in t.players) p.id,
        };
        final rng = Random(seed);
        var movedOthers = 0;
        for (var week = 0; week < 6; week++) {
          final moves = AiTransferEngine.runWeek(teams, 'user', rng,
              budgetOf: (_) => 1 << 30, reserved: reserved);
          for (final m in moves) {
            expect(reserved, isNot(contains(m.player.id)),
                reason: 'seed $seed: ${m.player.name}');
          }
          movedOthers += moves.length;
        }
        // 他の選手は動く(止めたのは仮契約の選手だけ)。
        expect(movedOthers, greaterThan(0), reason: 'seed $seed');
      }
    });

    test('再現: reserved を渡さないと、同じ選手が動く', () {
      var movedReserved = 0;
      for (var seed = 0; seed < 8; seed++) {
        final teams = clubs(16, seed);
        final ids = {
          for (final t in teams.take(8))
            for (final p in t.players) p.id,
        };
        final rng = Random(seed);
        for (var week = 0; week < 6; week++) {
          movedReserved += AiTransferEngine.runWeek(teams, 'user', rng,
                  budgetOf: (_) => 1 << 30)
              .where((m) => ids.contains(m.player.id))
              .length;
        }
      }
      expect(movedReserved, greaterThan(0));
    });

    test('ゲームの中: 仮契約の選手は窓のあいだ元のクラブに残る', () async {
      for (var round = 0; round < 3; round++) {
        final gs = await start();
        final s = gs.save!;
        final cpu = s.league.teams.where((t) => t.id != s.userTeamId);
        final home = <String, String>{};
        for (final t in cpu) {
          for (final p in t.players) {
            home[p.id] = t.id;
            s.preContracts.add(PreContract(
              playerId: p.id,
              playerName: p.name,
              fromClubId: t.id,
              fromClubName: t.name,
              toClubId: s.userTeamId,
              toClubName: s.clubName,
              wage: p.wage,
              endYear: 2030,
              option: false,
              signedOn: gs.today,
            ));
          }
        }
        for (var week = 0; week < 6; week++) {
          gs.debugAdvanceAiTransfers();
        }
        for (final t in s.league.teams.where((t) => t.id != s.userTeamId)) {
          for (final p in t.players) {
            if (home.containsKey(p.id)) expect(home[p.id], t.id);
          }
        }
        expect(home.keys.every((id) {
          return s.league.teams.any((t) => t.players.any((p) => p.id == id));
        }), isTrue);
      }
    });
  });

  group('2. リリース条項での売却も、売却条項を払う', () {
    test('条項の額で売れたら、元のクラブへ売却条項の分を払う', () async {
      var checked = 0;
      for (var round = 0; round < 3; round++) {
        final gs = await start();
        final s = gs.save!;
        gs.rivalsEnabled = false;
        final byName = {for (final p in gs.userTeam.players) p.name: p};
        final clauses = <String, int>{};
        for (final p in gs.userTeam.players) {
          // 市場価値以下の条項は必ず払われ、不満な選手は同意しやすい。
          p.releaseClause = clauses[p.id] = max(1, p.marketValue);
          p.happiness = 0;
          s.sellOnClauses[p.id] = 20;
        }
        List<String> sold = const [];
        var transfersBefore = 0;
        for (var i = 0; i < 3000 && sold.isEmpty; i++) {
          s.incomingOffers.clear();
          transfersBefore = gs.currentLedger.of(LedgerCategory.transfers);
          sold = gs.debugAdvanceIncomingOffers();
        }
        expect(sold, isNotEmpty);
        final p = byName[sold.first]!;
        // 移った先で条項は外れるので、付けた額(市場価値)で数える。
        final pay = TransferTermsEngine.sellOnPayment(
            salePrice: clauses[p.id]!, percent: 20);
        expect(pay, greaterThan(0));
        expect(s.sellOnClauses.containsKey(p.id), isFalse);
        // 売却条項(と連帯貢献金)が、移籍の支払いに入る。
        expect(gs.currentLedger.of(LedgerCategory.transfers),
            lessThanOrEqualTo(transfersBefore - pay));
        expect(
            s.newsLog.any((n) =>
                n.text.contains(p.name) &&
                (n.text.contains('売却条項') || n.text.contains('sell-on'))),
            isTrue);
        checked++;
      }
      expect(checked, 3);
    });
  });

  group('3. 降格の条項は club_finance_reality_test.dart', () {});

  group('4. クラブを買い直すと、前のクラブの収入・契約は持ち越さない', () {
    void fill(SaveGame s) {
      s.sponsorDeal =
          SponsorDeal(name: '胸', weeklyIncome: 900, yearsRemaining: 3);
      s.namingDeal =
          SponsorDeal(name: '命名', weeklyIncome: 700, yearsRemaining: 5);
      s.pendingNamingOffers = [
        SponsorDeal(name: '候補', weeklyIncome: 500, yearsRemaining: 4),
      ];
      s.slotSponsors = {
        'sleeve': SponsorDeal(name: '袖', weeklyIncome: 300, yearsRemaining: 2),
      };
      s.slotSponsorOffers = {
        'training':
            SponsorDeal(name: '練習着', weeklyIncome: 200, yearsRemaining: 2),
      };
      s.parachuteFromTier = 1;
      s.parachuteSeasonsLeft = 2;
      s.tvHolidaySeasons = 2;
      s.seasonTicketShare = 30;
      s.seasonTicketSeason = s.league.season;
      s.sellOnClauses = {'x': 20};
      s.buyBacks = {
        'y': [100, 2030],
      };
      s.stadiumSubsidyPct = 20;
    }

    void expectCleared(GameState gs) {
      final s = gs.save!;
      expect(s.sponsorDeal, isNull);
      expect(s.namingDeal, isNull);
      expect(s.pendingNamingOffers, isEmpty);
      expect(s.slotSponsors, isEmpty);
      expect(s.slotSponsorOffers, isEmpty);
      expect(s.parachuteFromTier, 0);
      expect(s.parachuteSeasonsLeft, 0);
      expect(gs.parachuteAnnual, 0);
      expect(s.tvHolidaySeasons, 0);
      expect(s.seasonTicketShare, 0);
      expect(s.sellOnClauses, isEmpty);
      expect(s.buyBacks, isEmpty);
      expect(s.pendingInstallments, isEmpty);
      expect(s.incomingOffers, isEmpty);
      expect(s.stadiumSubsidyPct, 0);
      expect(gs.slotSponsorWeeklyIncome, 0);
    }

    test('同じ国のクラブを買い直す', () async {
      final gs = await start();
      fill(gs.save!);
      gs.save!.confidence = 0;
      expect(await gs.buyClub(gs.buyoutCandidates.first.id), isTrue);
      expectCleared(gs);
    });

    test('別の国でクラブを立ち上げる', () async {
      final gs = await start();
      fill(gs.save!);
      gs.save!.confidence = 0;
      final other =
          LeagueTheme.values.firstWhere((t) => t != gs.currentLeagueTheme);
      expect(await gs.buyClubInCountry(other), isTrue);
      expectCleared(gs);
    });
  });

  group('5. 収支の見込みは、運営費と今の放映権の式で数える', () {
    test('1節の収支 = 収入(放映権は配分式の見込み) − 人件費 − 運営費 − …', () async {
      for (final theme in LeagueTheme.values) {
        final gs = await start(theme: theme);
        final s = gs.save!;
        final md = gs.matchdaysPerSeason;
        final p = gs.weeklyIncomeParts(s.userTeamId);
        expect(gs.matchdayRunningCost, greaterThan(0));
        expect(gs.matchdayRunningCost, (gs.annualRunningCost / md).round());
        expect(gs.projectedMatchdayBroadcast,
            ((gs.projectedBroadcastTotal + gs.parachuteAnnual) / md).round());
        final installments = s.pendingInstallments
            .where((i) => !i.annual)
            .fold<int>(0, (t, i) => t + i.weeklyAmount);
        final loans =
            gs.bankLoans.fold<int>(0, (t, l) => t + l.weeklyRepayment);
        final wages = gs.matchdayPlayerWageCost + gs.matchdayStaffWageCost;
        expect(
            gs.weeklyNet,
            p.gate +
                p.sponsor +
                p.merchandise +
                gs.projectedMatchdayBroadcast -
                wages -
                gs.matchdayRunningCost -
                installments -
                loans,
            reason: theme.name);
        // 再現: 以前の式(古い放映権・運営費なし)とは運営費のぶん以上ずれる。
        final old =
            gs.weeklyIncomeFor(s.userTeamId) - wages - installments - loans;
        expect(
            old - gs.weeklyNet,
            p.broadcast -
                gs.projectedMatchdayBroadcast +
                gs.matchdayRunningCost);
      }
    });

    test('前払いの精算が残る季は、季末の上乗せを見込まない', () async {
      final gs = await start();
      final md = gs.matchdaysPerSeason;
      gs.save!.tvHolidaySeasons = 1;
      expect(gs.projectedMatchdayBroadcast,
          ((gs.guaranteedBroadcastAnnual + gs.parachuteAnnual) / md).round());
    });

    test('1年の運営費の見込みは、記帳される年額とほぼ同じ', () async {
      final gs = await start();
      final md = gs.matchdaysPerSeason;
      expect((gs.matchdayRunningCost * md - gs.annualRunningCost).abs(),
          lessThanOrEqualTo(md));
      expect((gs.monthlyRunningCost * 12 - gs.annualRunningCost).abs(),
          lessThanOrEqualTo(12));
    });
  });

  group('6. オーナーの事件で「エースを売る」も、売却の決まりを通す', () {
    test('簿価の償却・「売らない」の約束・売却条項が通る', () async {
      for (var round = 0; round < 3; round++) {
        final gs = await start();
        final s = gs.save!;
        final ace = ([
          ...gs.userTeam.players.where((p) => !p.isLoan && !p.isLoanedOut),
        ]..sort((a, b) => b.marketValue.compareTo(a.marketValue)))
            .first;
        final fee = ace.marketValue;
        s.playerBook[ace.id] = [1000, 2030, 4, 0];
        s.rumorDenied[ace.id] = s.league.season;
        s.sellOnClauses[ace.id] = 10;
        s.recordSaleFee = 0;
        final amort = gs.currentLedger.of(LedgerCategory.amortization);
        final sales = gs.currentLedger.of(LedgerCategory.playerSales);
        s.pendingOwnerEvent = OwnerEventKind.transferDemand;
        expect(await gs.resolveOwnerEvent(1), isTrue);
        expect(gs.userTeam.players.any((p) => p.id == ace.id), isFalse);
        // 売値は一度だけ記帳される(_onPlayerSold は売値を記帳しない)。
        expect(gs.currentLedger.of(LedgerCategory.playerSales), sales + fee);
        // 簿価の残りが費用になり、簿価から外れる。
        expect(s.playerBook.containsKey(ace.id), isFalse);
        expect(gs.currentLedger.of(LedgerCategory.amortization), amort - 1000);
        // 「売らない」と言った約束が確かめられる。
        expect(s.rumorDenied.containsKey(ace.id), isFalse);
        expect(s.sellOnClauses.containsKey(ace.id), isFalse);
        if (fee >= gs.scaledMoney(GameStateMoments.recordMinimum)) {
          expect(s.recordSaleFee, fee);
        }
      }
    });
  });

  group('7. CPU の移籍の「この窓で動いた選手」は保存される', () {
    test('SaveGame の toJson / fromJson を通っても残る', () async {
      final gs = await start();
      final s = gs.save!;
      for (var i = 0; i < 10 && s.aiMovedThisWindow.isEmpty; i++) {
        gs.debugAdvanceAiTransfers();
      }
      expect(s.aiMovedThisWindow, isNotEmpty);
      expect(s.aiMovedWindowOpens, isNotNull);
      final back = SaveGame.fromJson(
          jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
      expect(back.aiMovedThisWindow, s.aiMovedThisWindow);
      expect(back.aiMovedWindowOpens, s.aiMovedWindowOpens);
    });

    test('古いセーブ(項目なし)は空で読む', () async {
      final gs = await start();
      final json =
          jsonDecode(jsonEncode(gs.save!.toJson())) as Map<String, dynamic>
            ..remove('aiMovedThisWindow')
            ..remove('aiMovedWindowOpens');
      final back = SaveGame.fromJson(json);
      expect(back.aiMovedThisWindow, isEmpty);
      expect(back.aiMovedWindowOpens, isNull);
    });

    test('同じ窓のうちは、保存した選手を二度動かさない', () async {
      final gs = await start();
      final s = gs.save!;
      for (var i = 0; i < 10 && s.aiMovedThisWindow.isEmpty; i++) {
        gs.debugAdvanceAiTransfers();
      }
      final first = {...s.aiMovedThisWindow};
      expect(first, isNotEmpty);
      // 別の GameState に読み込み直す(以前は覚えが GameState の中だけで、
      // 読み込み直すと同じ窓で同じ選手がまた動けた)。
      final gs2 = GameState();
      expect(await gs2.importSaveJson(jsonEncode(s.toJson())), isTrue);
      final s2 = gs2.save!;
      expect(s2.aiMovedThisWindow, first);
      final clubOf = <String, String>{
        for (final t in s2.league.teams)
          for (final p in t.players) p.id: t.id,
      };
      for (var i = 0; i < 6; i++) {
        gs2.debugAdvanceAiTransfers();
      }
      for (final t in s2.league.teams) {
        for (final p in t.players) {
          if (first.contains(p.id)) expect(t.id, clubOf[p.id]);
        }
      }
    });
  });
}
