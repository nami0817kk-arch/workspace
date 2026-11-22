import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/league_rules.dart';
import 'package:soccer_manager/models/league_theme.dart';
import 'package:soccer_manager/models/ledger.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

SeasonLedger _season(int s, {required int income, required int cost}) =>
    SeasonLedger(s)
      ..add(LedgerCategory.gate, income)
      ..add(LedgerCategory.playerWages, -cost);

/// 国ごとの財務規則(2026-11-22 に実際の制度へ寄せた)。
///
/// 以前のこのテストは「イタリア=日本式(3季連続赤字で勝ち点-6)」
/// 「フランス=米国式(贅沢税)」を固定していた。実際の制度と別物だった
/// ので、イタリアは流動性の指標・フランスは DNCG の形に直した。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
  });
  tearDown(() => Tr.language = AppLanguage.system);

  group('イングランド式(3季の損失の上限)', () {
    test('上限は部の規模で決まる(1部はプレミアの£105m 相当の200億)', () {
      expect(RulesEngine.lossLimitForTier(1), 2000000);
      expect(RulesEngine.lossLimitForTier(2), lessThan(2000000));
      expect(RulesEngine.lossLimitForTier(3),
          lessThan(RulesEngine.lossLimitForTier(2)));
    });

    test('3季の損失の合計が上限以内なら罰は無く、超えると勝ち点を引かれる', () {
      final limit = RulesEngine.lossLimitForTier(3);
      RuleReport r(int lossPerSeason) => RulesEngine.evaluate(
            ruleSet: RuleSet.britain,
            tier: 3,
            ledgers: [
              for (var s = 1; s <= 3; s++)
                _season(s, income: 100000, cost: 100000 + lossPerSeason),
            ],
            budget: 5000,
          );
      expect(r(limit ~/ 4).penalty, isNull);
      expect(r(limit * 3 ~/ 10).statuses.single.level, 1); // 上限の90%
      final p = r(limit ~/ 2).penalty!;
      expect(p.pointsDeduction, inInclusiveRange(4, 10));
      expect(p.fine, 0, reason: '実際の収支規則に罰金は無い');
    });

    test('数える季は直近3季だけ。古い大赤字は忘れられる', () {
      final r = RulesEngine.evaluate(
        ruleSet: RuleSet.britain,
        tier: 3,
        ledgers: [
          _season(1, income: 1000, cost: 900000),
          _season(2, income: 1000, cost: 900),
          _season(3, income: 1000, cost: 900),
          _season(4, income: 1000, cost: 900),
        ],
        budget: 5000,
      );
      expect(r.penalty, isNull);
    });

    test('施設・アカデミーへの投資は損失に数えない。移籍金は償却で数える', () {
      final limit = RulesEngine.lossLimitForTier(3);
      final l = _season(1, income: 1000, cost: 1000)
        ..add(LedgerCategory.infrastructure, -limit * 3)
        ..add(LedgerCategory.transferFees, -limit * 3)
        ..add(LedgerCategory.amortization, -limit ~/ 2);
      final r = RulesEngine.evaluate(
          ruleSet: RuleSet.britain, tier: 3, ledgers: [l], budget: 0);
      expect(r.penalty, isNull, reason: '数えるのは償却の分だけ');
      expect(l.ruleProfit, -limit ~/ 2);
    });
  });

  group('スペイン式(人件費の上限)', () {
    const snap = ClubFinanceSnapshot(projectedIncome: 100000, squadCost: 60000);
    test('上限は収入の見込みの70%(下の部ほどゆるい)', () {
      expect(RulesEngine.squadCostLimit(100000, 1), 70000);
      expect(RulesEngine.squadCostLimit(100000, 3), greaterThan(70000));
    });

    test('上限を超える補強は登録できない(罰は無く、獲得を止める)', () {
      expect(
          RulesEngine.signingBlock(
              ruleSet: RuleSet.spain,
              tier: 1,
              snapshot: snap,
              addedSquadCost: 5000),
          isNull);
      expect(
          RulesEngine.signingBlock(
              ruleSet: RuleSet.spain,
              tier: 1,
              snapshot: snap,
              addedSquadCost: 20000),
          contains('登録できません'));
      final r = RulesEngine.evaluate(
          ruleSet: RuleSet.spain,
          ledgers: [_season(1, income: 1000, cost: 5000)],
          budget: 0,
          snapshot: const ClubFinanceSnapshot(
              projectedIncome: 100000, squadCost: 90000));
      expect(r.statuses.single.level, 2);
      expect(r.penalty, isNull);
    });
  });

  group('ドイツ式(ライセンスの審査)', () {
    test('資金と自己資本がプラスなら問題なし', () {
      final r = RulesEngine.evaluate(
          ruleSet: RuleSet.germany,
          ledgers: [_season(1, income: 1000, cost: 2000)],
          budget: 100,
          snapshot: const ClubFinanceSnapshot(equity: 500));
      expect(r.penalty, isNull);
    });

    test('資金がマイナスで3点、自己資本もマイナスなら6点を引かれる', () {
      final one = RulesEngine.evaluate(
          ruleSet: RuleSet.germany,
          ledgers: [_season(1, income: 1000, cost: 900)],
          budget: -1,
          snapshot: const ClubFinanceSnapshot(equity: 500));
      expect(one.penalty!.pointsDeduction, 3);
      expect(one.penalty!.banSeasons, 0);
      final two = RulesEngine.evaluate(
          ruleSet: RuleSet.germany,
          ledgers: [_season(1, income: 1000, cost: 900)],
          budget: -1,
          snapshot: const ClubFinanceSnapshot(equity: -1));
      expect(two.penalty!.pointsDeduction, 6);
    });
  });

  group('イタリア式(流動性の指標)', () {
    test('指標が基準を下回ると移籍市場で獲得できない。罰は無い', () {
      expect(
          RulesEngine.signingBlock(
              ruleSet: RuleSet.italy,
              tier: 1,
              snapshot: const ClubFinanceSnapshot(liquidity: 0.8)),
          isNull);
      expect(
          RulesEngine.signingBlock(
              ruleSet: RuleSet.italy,
              tier: 1,
              snapshot: const ClubFinanceSnapshot(liquidity: 0.5)),
          contains('流動性の指標'));
      final r = RulesEngine.evaluate(
          ruleSet: RuleSet.italy,
          ledgers: [
            _season(1, income: 1000, cost: 1100),
            _season(2, income: 1000, cost: 1100),
            _season(3, income: 1000, cost: 1100),
          ],
          budget: -100,
          snapshot: const ClubFinanceSnapshot(liquidity: 0.5));
      expect(r.penalty, isNull, reason: '3季連続の赤字でも勝ち点は引かれない');
      expect(r.statuses.single.level, 2);
    });
  });

  group('フランス式(DNCG)', () {
    RuleReport fr(
            {required int loss,
            int debt = 0,
            int budget = 100,
            int tier = 1}) =>
        RulesEngine.evaluate(
          ruleSet: RuleSet.france,
          tier: tier,
          ledgers: [_season(1, income: 1000, cost: 1000 + loss)],
          budget: budget,
          snapshot: ClubFinanceSnapshot(debt: debt),
        );

    test('赤字が小さく借りも少なければ問題なし', () {
      expect(fr(loss: 100).penalty, isNull);
    });

    test('赤字が収入の15%を超えるか、借りが50%を超えると人件費の上限', () {
      expect(fr(loss: 200).penalty!.wageFreezeSeasons, 1);
      expect(fr(loss: 0, debt: 600).penalty!.wageFreezeSeasons, 1);
      expect(fr(loss: 200).penalty!.banSeasons, 0);
    });

    test('資金がマイナスなら補強禁止、大赤字も重なれば降格処分', () {
      expect(fr(loss: 100, budget: -1).penalty!.banSeasons, 1);
      expect(fr(loss: 100, budget: -1).penalty!.adminRelegation, isFalse);
      expect(fr(loss: 400, budget: -1).penalty!.adminRelegation, isTrue);
      // 一番下の部では降格できないので、勝ち点の剥奪に替える。
      final bottom = fr(loss: 400, budget: -1, tier: 3).penalty!;
      expect(bottom.adminRelegation, isFalse);
      expect(bottom.pointsDeduction, greaterThan(0));
    });
  });

  group('UEFA の人件費比率(大陸大会に出たクラブ)', () {
    test('選手の人件費と償却が収入の70%を超えると罰金。出ていなければ見ない', () {
      final l = _season(1, income: 1000, cost: 700)
        ..add(LedgerCategory.amortization, -100);
      final out = RulesEngine.evaluate(
          ruleSet: RuleSet.britain, tier: 1, ledgers: [l], budget: 100);
      expect(out.statuses.length, 1);
      final inCup = RulesEngine.evaluate(
          ruleSet: RuleSet.britain,
          tier: 1,
          ledgers: [l],
          budget: 100,
          snapshot: const ClubFinanceSnapshot(inContinental: true));
      expect(inCup.statuses.length, 2);
      expect(inCup.penalty!.fine, 20); // 超過100の2割
      expect(inCup.penalty!.pointsDeduction, 0);
    });
  });

  group('ゲームの中', () {
    test('補強が禁止されている間は、どの補強も通らず理由が残る', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      gs.save!.transferBanSeasons = 1;
      expect(gs.isTransferBanned, isTrue);
      expect(gs.debugAllowsSigning(1), isFalse);
      expect(gs.lastSigningBlockReason, contains('補強が禁止'));
    });

    test('フランス式の人件費の上限の間は、年俸の総額を増やす補強が止まる', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      gs.save!
        ..wageBudget = 99999999
        ..wageFreezeSeasons = 1
        ..wageFreezeCap = gs.weeklyWageBill;
      expect(gs.debugAllowsSigning(1000), isFalse);
      expect(gs.lastSigningBlockReason, contains('人件費に上限'));
    });

    test('勝ち点の剥奪は順位表に効く', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      final id = gs.save!.userTeamId;
      final before = gs.save!.league.computeStandings()[id]!.points;
      gs.save!.league.pointsAdjustments[id] = -6;
      expect(gs.save!.league.computeStandings()[id]!.points, before - 6);
    });

    test('規則と罰は保存して読み戻せ、旧セーブの名前(japan・usa)も読める', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      gs.save!
        ..ruleSet = RuleSet.italy
        ..transferBanSeasons = 2
        ..pendingPointsDeduction = 4
        ..wageFreezeSeasons = 1
        ..wageFreezeCap = 123
        ..adminRelegation = true;
      gs.save!.league.pointsAdjustments[gs.save!.userTeamId] = -3;
      final json = gs.save!.toJson();
      final back = SaveGame.fromJson(json);
      expect(back.ruleSet, RuleSet.italy);
      expect(back.transferBanSeasons, 2);
      expect(back.pendingPointsDeduction, 4);
      expect(back.wageFreezeSeasons, 1);
      expect(back.wageFreezeCap, 123);
      expect(back.adminRelegation, isTrue);
      expect(back.league.pointsAdjustments[back.userTeamId], -3);

      expect(SaveGame.fromJson({...json, 'ruleSet': 'japan'}).ruleSet,
          RuleSet.italy);
      expect(SaveGame.fromJson({...json, 'ruleSet': 'usa'}).ruleSet,
          RuleSet.france);

      json
        ..remove('ruleSet')
        ..remove('transferBanSeasons')
        ..remove('pendingPointsDeduction')
        ..remove('wageFreezeSeasons')
        ..remove('wageFreezeCap')
        ..remove('adminRelegation');
      final old = SaveGame.fromJson(json);
      expect(old.ruleSet, RuleSet.britain);
      expect(old.transferBanSeasons, 0);
      expect(old.wageFreezeSeasons, 0);
      expect(old.adminRelegation, isFalse);
    });

    test('罰を科すと、信頼度が下がり、勝ち点の剥奪が来季に残り、ニュースに残る', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      final save = gs.save!;
      save.league.season = 2; // 最初のシーズンは猶予
      save.ruleSet = RuleSet.germany;
      save.budget = -100; // 流動性がマイナス
      save.confidence = 50;
      final newsBefore = save.newsLog.length;
      gs.debugEnforceLeagueRules();
      expect(save.pendingPointsDeduction, greaterThanOrEqualTo(3));
      expect(save.confidence, lessThan(50));
      expect(save.newsLog.length, newsBefore + 1);
    });

    test('フランス式の罰で、人件費の上限と降格処分が付く', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      final save = gs.save!;
      save.league.season = 2;
      save.ruleSet = RuleSet.france;
      save.budget = -100;
      gs.debugEnforceLeagueRules();
      expect(save.transferBanSeasons, 1);
      expect(save.wageFreezeSeasons, 1);
      expect(save.wageFreezeCap, greaterThan(0));
    });

    test('最初のシーズンは猶予され、罰は科されず、警告のニュースだけ残る', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      final save = gs.save!;
      expect(save.league.season, 1);
      save.ruleSet = RuleSet.germany;
      save.budget = -100;
      save.confidence = 50;
      final news = save.newsLog.length;
      gs.debugEnforceLeagueRules();
      expect(save.pendingPointsDeduction, 0);
      expect(save.confidence, 50);
      expect(save.newsLog.length, news + 1);
    });

    test('罰の補強禁止と人件費の上限は、季が進むと解ける', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      final save = gs.save!;
      save.ruleSet = RuleSet.britain;
      save.budget = 5000;
      save.transferBanSeasons = 1;
      save.wageFreezeSeasons = 1;
      save.wageFreezeCap = 10;
      gs.debugEnforceLeagueRules();
      expect(save.transferBanSeasons, 0);
      expect(save.wageFreezeSeasons, 0);
      expect(save.wageFreezeCap, 0);
    });
  });

  group('国ごとの規則', () {
    test('国風のテーマから規則の式が決まる', () {
      expect(RuleSet.forTheme(LeagueTheme.england), RuleSet.britain);
      expect(RuleSet.forTheme(LeagueTheme.germany), RuleSet.germany);
      expect(RuleSet.forTheme(LeagueTheme.spain), RuleSet.spain);
      expect(RuleSet.forTheme(LeagueTheme.italy), RuleSet.italy);
      expect(RuleSet.forTheme(LeagueTheme.france), RuleSet.france);
    });
  });
}
