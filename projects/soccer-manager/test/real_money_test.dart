import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/logic/board_engine.dart';
import 'package:soccer_manager/logic/economy_scale.dart';
import 'package:soccer_manager/logic/investment_engine.dart';
import 'package:soccer_manager/logic/loan_engine.dart';
import 'package:soccer_manager/logic/transfer_terms_engine.dart';
import 'package:soccer_manager/models/incoming_offer.dart';
import 'package:soccer_manager/models/installment.dart';
import 'package:soccer_manager/models/league_theme.dart';
import 'package:soccer_manager/models/ledger.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

import 'support/legacy_market.dart';

/// お金と規則を実際のサッカーに近づけた(2026-11-22)ときの挙動の固定。
///
/// - 利率: 融資は年5〜8%、預金は年2〜4%。利息は損益に入る。
/// - 移籍金: 払った季に全額費用にせず、契約の年数で割って毎季費用にする。
/// - 放映権: 国で額が違う(イングランドが飛び抜け、フランスが小さい)。
/// - パラシュート: 国で季数と割合が違う(ドイツは無い)。
/// - 分割払い: 頭金3割 + 残りを契約の年数(2〜5年)で毎年。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<GameState> newGame([LeagueTheme theme = LeagueTheme.england]) async {
    final gs = GameState();
    await gs.startNewGame('実際FC', theme: theme);
    gs.save!
      ..budget = 10000000
      ..wageBudget = 99999999;
    return gs;
  }

  /// 市場から、いま買える選手を1人買う。買えた選手を返す。
  Future<Player> buyOne(GameState gs, {bool installments = false}) async {
    for (final p in [...legacyMarket(gs)]) {
      final ok = installments
          ? await gs.buyPlayerOnInstallments(p.id)
          : await gs.buyPlayer(p.id);
      if (ok) return gs.userTeam.players.firstWhere((x) => x.id == p.id);
    }
    fail('買える選手がいない: ${gs.lastSigningBlockReason}');
  }

  group('利率', () {
    test('融資は年5〜8%、預金は年2〜4%(以前は年20〜35%)', () {
      for (final t in LoanEngine.terms) {
        expect(t.annualRatePercent, inInclusiveRange(5, 8),
            reason: '${t.weeks}週');
      }
      for (final t in InvestmentEngine.terms) {
        expect(t.annualRatePercent, inInclusiveRange(2, 4),
            reason: '${t.weeks}週');
      }
    });

    test('週の返済の元本の分を全週足すと、元本ちょうど', () {
      for (final t in LoanEngine.terms) {
        for (final principal in [1, 7, 1000, 123457]) {
          var sum = 0;
          for (var w = 0; w < t.weeks; w++) {
            sum += LoanEngine.principalPartOfWeek(principal, t.weeks, w);
          }
          expect(sum, principal);
        }
      }
    });

    test('融資の利息は損益の支出、元本は損益に入らない', () async {
      final gs = await newGame();
      final term = LoanEngine.terms.last;
      final amount = gs.maxLoanAmount;
      expect(amount, greaterThan(1000));
      expect(await gs.takeLoan(amount, term), isTrue);
      final financingBefore = gs.currentLedger.of(LedgerCategory.financing);
      await gs.playNextMatchdayQuickSim();
      final weekly = LoanEngine.weeklyRepaymentFor(amount, term);
      final interest = -gs.currentLedger.of(LedgerCategory.interest);
      final principalPart =
          financingBefore - gs.currentLedger.of(LedgerCategory.financing);
      expect(interest + principalPart, weekly);
      expect(interest, greaterThan(0));
      expect(interest, lessThan(weekly ~/ 10), reason: '年7%なら1週の利息は小さい');
    });

    test('預金の満期: 元本は融資・預金、利息は損益の収入', () async {
      final gs = await newGame();
      final term = InvestmentEngine.terms.first;
      expect(await gs.openFixedDeposit(100000, term), isTrue);
      final d = gs.fixedDeposits.first..weeksRemaining = 1;
      await gs.playNextMatchdayQuickSim();
      expect(gs.fixedDeposits, isEmpty);
      expect(gs.currentLedger.of(LedgerCategory.interest),
          d.maturityValue - d.principal);
      expect(gs.currentLedger.of(LedgerCategory.financing), 0,
          reason: '預けた -10億 と戻った +10億 で差し引き0');
    });
  });

  group('移籍金の償却', () {
    // 2026-11-22: 代理人手数料も移籍の資産(簿価)に入れる(実際の会計と同じ)。
    // 以前は「代理人手数料だけが費用」で、簿価は移籍金だけだった。
    test('買った季は移籍金と代理人手数料を資産として払い、損益には入れない', () async {
      final gs = await newGame();
      final cash = gs.save!.budget;
      final p = await buyOne(gs);
      final fee = p.marketValue;
      final agent = TransferTermsEngine.agentFee(fee);
      final l = gs.currentLedger;
      expect(l.of(LedgerCategory.transferFees), -(fee + agent));
      expect(l.of(LedgerCategory.amortization), 0);
      expect(l.of(LedgerCategory.transfers), 0, reason: '代理人手数料を費用にした');
      expect(gs.save!.playerBook[p.id], hasLength(4));
      expect(gs.bookValueOf(p.id), fee + agent);
      expect(cash - gs.save!.budget, l.cashChange.abs(), reason: '資金は払ったときに減る');
    });

    test('季の締めに、残りの簿価を契約の残りの年数で割った額を費用にする。資金は動かない', () async {
      final gs = await newGame();
      final p = await buyOne(gs);
      // 簿価は移籍金と代理人手数料の合計(2026-11-22)。
      final fee = gs.bookValueOf(p.id);
      final years = p.contractEndYear - Player.contractClockYear + 1;
      final cash = gs.save!.budget;
      gs.debugAmortizeTransferFees();
      final charge = (fee + years - 1) ~/ years;
      expect(gs.currentLedger.of(LedgerCategory.amortization), -charge);
      expect(gs.save!.budget, cash, reason: '償却は資金を動かさない');
      expect(gs.bookValueOf(p.id), fee - charge);
      // 契約の最後の季までに、ちょうど全額が費用になる。
      var total = charge;
      for (var y = 1; y < years; y++) {
        Player.contractClockYear += 1;
        final before = gs.currentLedger.of(LedgerCategory.amortization);
        gs.debugAmortizeTransferFees();
        total += before - gs.currentLedger.of(LedgerCategory.amortization);
      }
      expect(total, fee);
      expect(gs.bookValueOf(p.id), 0);
    });

    test('売ると残りの簿価を費用にし、損益には売値と簿価の差が残る', () async {
      final gs = await newGame();
      final p = await buyOne(gs);
      final book = gs.bookValueOf(p.id);
      final s = gs.save!;
      s.incomingOffers.add(IncomingOffer(
          id: 'z',
          playerId: p.id,
          playerName: p.name,
          buyerClubName:
              s.league.teams.firstWhere((t) => t.id != s.userTeamId).name,
          amount: book + 5000));
      expect(await gs.acceptIncomingOffer('z'), isTrue);
      expect(s.playerBook.containsKey(p.id), isFalse);
      expect(gs.currentLedger.of(LedgerCategory.amortization), -book);
    });

    test('いなくなった選手(放出・満了)の残りの簿価は、季の締めに費用にする', () async {
      final gs = await newGame();
      final p = await buyOne(gs);
      final book = gs.bookValueOf(p.id);
      gs.userTeam.players.removeWhere((x) => x.id == p.id);
      gs.debugAmortizeTransferFees();
      expect(gs.currentLedger.of(LedgerCategory.amortization), -book);
      expect(gs.save!.playerBook.containsKey(p.id), isFalse);
    });

    test('旧セーブの簿価(3つの値)は、払った季に費用にしてあるので償却しない', () async {
      final gs = await newGame();
      final p = gs.userTeam.players.firstWhere((x) => !x.isLoan);
      gs.save!.playerBook[p.id] = [4000, Player.contractClockYear, 4];
      gs.debugAmortizeTransferFees();
      expect(gs.currentLedger.of(LedgerCategory.amortization), 0);
      expect(gs.bookValueOf(p.id), 4000);
    });

    test('規則の判定は償却後の損益で、施設への投資は赤字に数えない', () {
      final l = SeasonLedger(1)
        ..add(LedgerCategory.gate, 1000)
        ..add(LedgerCategory.transferFees, -5000)
        ..add(LedgerCategory.amortization, -1000)
        ..add(LedgerCategory.infrastructure, -300);
      expect(l.profit, -300);
      expect(l.ruleProfit, 0);
      expect(l.cashChange, 1000 - 5000 - 300);
    });
  });

  group('分割払い', () {
    test('頭金3割、残りは契約の年数(2〜5年)で毎年同じ額。季の締めに払う', () async {
      final gs = await newGame();
      final cash = gs.save!.budget;
      final p = await buyOne(gs, installments: true);
      final total = p.marketValue;
      final down = (total * 0.3).round();
      final inst = gs.save!.pendingInstallments.single;
      final years =
          (p.contractEndYear - Player.contractClockYear + 1).clamp(2, 5);
      expect(inst.annual, isTrue);
      expect(inst.capitalized, isTrue);
      expect(inst.weeksRemaining, years);
      expect(inst.weeklyAmount, ((total - down) / years).ceil());
      // 簿価は総額と代理人手数料。資産の支払いは頭金と代理人手数料
      // (2026-11-22 に代理人手数料を簿価に入れた)。
      final agent = TransferTermsEngine.agentFee(total);
      expect(gs.bookValueOf(p.id), total + agent, reason: '簿価は総額');
      expect(gs.currentLedger.of(LedgerCategory.transferFees), -(down + agent));
      final afterBuy = gs.save!.budget;
      expect(cash - afterBuy, greaterThanOrEqualTo(down));

      // 節を進めても年払いの分は引かれない。
      final weeks = inst.weeksRemaining;
      await gs.playNextMatchdayQuickSim();
      expect(inst.weeksRemaining, weeks);

      // 季の締めに1年分。
      final before = gs.save!.budget;
      gs.debugPayAnnualInstallments();
      expect(before - gs.save!.budget, inst.weeklyAmount);
      expect(inst.weeksRemaining, weeks - 1);
    });

    test('旧セーブの分割払い(4週の形)は、そのまま毎週払い終わる', () async {
      final gs = await newGame();
      final json =
          Installment(description: 'x', weeklyAmount: 100, weeksRemaining: 2)
              .toJson();
      final old = Installment.fromJson(json);
      expect(old.annual, isFalse);
      expect(old.capitalized, isFalse);
      gs.save!.pendingInstallments.add(old);
      await gs.playNextMatchdayQuickSim();
      expect(old.weeksRemaining, 1);
      expect(gs.currentLedger.of(LedgerCategory.transfers),
          lessThanOrEqualTo(-100));
      gs.debugPayAnnualInstallments();
      expect(old.weeksRemaining, 1, reason: '季の締めでは払わない');
    });

    test('年払いの分割払いは保存して読み戻せる', () {
      final i = Installment(
          description: 'y',
          weeklyAmount: 300,
          weeksRemaining: 4,
          playerId: 'p',
          annual: true,
          capitalized: true);
      final back = Installment.fromJson(i.toJson());
      expect(back.annual, isTrue);
      expect(back.capitalized, isTrue);
      expect(back.outstanding, 1200);
    });
  });

  group('放映権の国差', () {
    test('1部はイングランドが飛び抜け、フランスが一番小さい(1.0/0.6/0.55/0.5/0.3)', () {
      final e = annualBroadcast(1, LeagueTheme.england);
      expect(annualBroadcast(1, LeagueTheme.spain), (e * 0.6).round());
      expect(annualBroadcast(1, LeagueTheme.germany), (e * 0.55).round());
      expect(annualBroadcast(1, LeagueTheme.italy), (e * 0.5).round());
      expect(annualBroadcast(1, LeagueTheme.france), (e * 0.3).round());
    });

    test('どの部でもイングランドが一番大きく、フランスが一番小さい。上の部ほど大きい', () {
      for (var tier = 1; tier <= 3; tier++) {
        final all = {
          for (final t in LeagueTheme.values) t: annualBroadcast(tier, t)
        };
        for (final t in LeagueTheme.values) {
          expect(all[LeagueTheme.england]!, greaterThanOrEqualTo(all[t]!));
          expect(all[LeagueTheme.france]!, lessThanOrEqualTo(all[t]!));
          if (tier < 3) {
            expect(annualBroadcast(tier, t),
                greaterThan(annualBroadcast(tier + 1, t)));
          }
        }
      }
      // イングランドの2部は、他国の2部より大きい(チャンピオンシップ)。
      expect(annualBroadcast(2, LeagueTheme.england),
          greaterThan(annualBroadcast(2, LeagueTheme.germany) * 1.5));
    });

    test('年収の目安と理事会の給与の枠は、国で違う', () {
      expect(typicalAnnualIncome(1, LeagueTheme.england),
          greaterThan(typicalAnnualIncome(1, LeagueTheme.france)));
      expect(
          BoardEngine.wageBudgetBaseForTier(1, LeagueTheme.england),
          greaterThan(
              BoardEngine.wageBudgetBaseForTier(1, LeagueTheme.france)));
      expect(GameState.initialBudgetFor(3, LeagueTheme.england),
          greaterThan(GameState.initialBudgetFor(3, LeagueTheme.france)));
    });

    test('ゲームの放映権の入金も国で違う', () async {
      final en = await newGame(LeagueTheme.england);
      final fr = await newGame(LeagueTheme.france);
      expect(en.weeklyBroadcastIncome * en.matchdaysPerSeason,
          greaterThan(fr.weeklyBroadcastIncome * fr.matchdaysPerSeason));
    });
  });

  group('パラシュート', () {
    Future<GameState> relegatedIn(LeagueTheme theme) async {
      final gs = await newGame(theme);
      final s = gs.save!;
      // 2部で戦って3部へ落ちた形にする。
      s.currentDivisionTier = 2;
      gs.debugUpdateParachute(playedTier: 2, newTier: 3);
      s.currentDivisionTier = 3;
      return gs;
    }

    test('国ごとの季数: イングランド3・スペイン2・フランス2・イタリア1・ドイツ無し', () async {
      expect(
          (await relegatedIn(LeagueTheme.england)).save!.parachuteSeasonsLeft,
          3);
      expect(
          (await relegatedIn(LeagueTheme.spain)).save!.parachuteSeasonsLeft, 2);
      expect((await relegatedIn(LeagueTheme.france)).save!.parachuteSeasonsLeft,
          2);
      expect(
          (await relegatedIn(LeagueTheme.italy)).save!.parachuteSeasonsLeft, 1);
      final de = await relegatedIn(LeagueTheme.germany);
      expect(de.save!.parachuteSeasonsLeft, 0);
      expect(de.parachuteAnnual, 0);
    });

    test('イングランドは1年目が大きく、減っていく', () async {
      final gs = await relegatedIn(LeagueTheme.england);
      final amounts = <int>[];
      for (var i = 0; i < 3; i++) {
        amounts.add(gs.parachuteAnnual);
        gs.debugUpdateParachute(playedTier: 3, newTier: 3);
      }
      expect(amounts[0], greaterThan(amounts[1]));
      expect(amounts[1], greaterThan(amounts[2]));
      expect(amounts[2], greaterThan(0));
      expect(gs.parachuteAnnual, 0, reason: '3季で終わる');
    });

    test('旧セーブ(どの国も2季)を読んでも、表の外にはみ出さない', () async {
      final gs = await newGame(LeagueTheme.italy);
      gs.save!
        ..parachuteFromTier = 2
        ..parachuteSeasonsLeft = 2;
      expect(gs.parachuteShare, 0.4);
      final back = SaveGame.fromJson(gs.save!.toJson());
      expect(back.parachuteSeasonsLeft, 2);
    });
  });
}
