import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/advisor_engine.dart';
import 'package:soccer_manager/logic/economy_scale.dart';
import 'package:soccer_manager/logic/league_rules.dart';
import 'package:soccer_manager/logic/staff_terms.dart';
import 'package:soccer_manager/logic/todo_advisor.dart';
import 'package:soccer_manager/models/club_infrastructure.dart';
import 'package:soccer_manager/models/ledger.dart';
import 'package:soccer_manager/state/game_state.dart';

SeasonLedger _season(int s, {required int income, required int cost}) =>
    SeasonLedger(s)
      ..add(LedgerCategory.gate, income)
      ..add(LedgerCategory.playerWages, -cost);

/// 画面の直し 第7段(経営)の決まり。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
  });
  tearDown(() => Tr.language = AppLanguage.system);

  group('財務規則: 今・上限・あといくら', () {
    test('イングランド式は、超えていれば外れるまでの額、超えていなければ余裕を出す', () {
      final limit = RulesEngine.lossLimitForTier(3);
      RuleStatus st(int loss) => RulesEngine.evaluate(
            ruleSet: RuleSet.britain,
            tier: 3,
            ledgers: [_season(1, income: 100000, cost: 100000 + loss)],
            budget: 5000,
          ).statuses.single;
      final ok = st(limit ~/ 2);
      expect(ok.now, formatMoney(limit ~/ 2));
      expect(ok.limit, formatMoney(limit));
      expect(ok.gap, '余裕 ${formatMoney(limit - limit ~/ 2)}');
      final bad = st(limit + 300);
      expect(bad.level, 2);
      expect(bad.gap, contains(formatMoney(300)));
      expect(bad.gap, contains('外れます'));
    });

    test('スペイン式は人件費をいくら減らせば外れるかを出す', () {
      final r = RulesEngine.evaluate(
        ruleSet: RuleSet.spain,
        tier: 1,
        ledgers: const [],
        budget: 0,
        snapshot: const ClubFinanceSnapshot(
            projectedIncome: 1000, squadCost: 900),
      ).statuses.single;
      final limit = RulesEngine.squadCostLimit(1000, 1);
      expect(r.level, 2);
      expect(r.gap, contains(formatMoney(900 - limit)));
    });

    test('イタリア式は、基準に戻すのに要る資金を出す', () {
      final r = RulesEngine.evaluate(
        ruleSet: RuleSet.italy,
        tier: 1,
        ledgers: const [],
        budget: 0,
        snapshot: const ClubFinanceSnapshot(liquidity: 0.5, dueWithinYear: 1000),
      ).statuses.single;
      expect(r.level, 2);
      expect(r.gap, contains(formatMoney(200)));
    });

    test('大陸大会の比率は、季の途中は1年の見込みで注意どまり、季末は帳簿で違反', () {
      final l = _season(1, income: 100, cost: 300); // 季の途中の帳簿では300%
      RuleReport r({required bool over}) => RulesEngine.evaluate(
            ruleSet: RuleSet.britain,
            tier: 1,
            ledgers: [l],
            budget: 100,
            snapshot: ClubFinanceSnapshot(
                inContinental: true,
                projectedIncome: 1000,
                squadCost: 600,
                seasonOver: over),
          );
      final mid = r(over: false);
      final st = mid.statuses.last;
      expect(st.label, contains('見込み'));
      expect(st.now, '60%'); // 600 / 1000
      expect(st.level, lessThan(2));
      expect(mid.penalty, isNull);
      // 見込みでも超えるなら注意(罰は出さない)。
      final heavy = RulesEngine.evaluate(
        ruleSet: RuleSet.britain,
        tier: 1,
        ledgers: [l],
        budget: 100,
        snapshot: const ClubFinanceSnapshot(
            inContinental: true,
            projectedIncome: 1000,
            squadCost: 900,
            seasonOver: false),
      );
      expect(heavy.statuses.last.level, 1);
      expect(heavy.statuses.last.gap, contains('季末'));
      expect(heavy.penalty, isNull);
      // 季末は今季の帳簿で判定する。
      final end = r(over: true);
      expect(end.statuses.last.level, 2);
      expect(end.penalty, isNotNull);
    });

    test('大陸大会に出ていないクラブには、大陸大会の規則を出さない', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      for (var i = 0; i < 3; i++) {
        await gs.playNextMatchdayQuickSim();
        if (gs.pendingOwnerEvent != null) await gs.resolveOwnerEvent(0);
      }
      final s = gs.save!;
      final cup = s.continentalCup;
      expect(cup == null || !cup.groups.any((g) => g.contains(s.userTeamId)),
          isTrue, reason: '3部から始めるので出ていない');
      expect(gs.userInContinental, isFalse);
      expect(gs.ruleReport.statuses.map((x) => x.label).join(),
          isNot(contains('大陸大会')));
      final items = TodoAdvisor.build(gs, hasSigningProposals: false);
      expect(items.map((t) => t.title).join(), isNot(contains('大陸大会')));
    });

    test('どの国にも、判定の時期と違反したときの罰の説明がある', () {
      for (final r in RuleSet.values) {
        expect(r.checkTiming, isNotEmpty);
        expect(r.consequence, isNotEmpty);
      }
      expect(RulesEngine.uefaConsequence, contains('罰金'));
    });
  });

  group('違反は状況の必須の「やること」へ', () {
    test('財務規則の違反は必須で、行き先は事業と規則(最初の季は猶予でおすすめ)',
        () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      gs.save!.ruleSet = RuleSet.germany;
      gs.save!.budget = -500;
      TodoItem? breach() => TodoAdvisor.build(gs, hasSigningProposals: false)
          .where((t) => t.kind == TodoKind.ruleBreach)
          .firstOrNull;
      expect(breach()?.level, TodoLevel.recommended);
      expect(breach()!.note, contains('猶予'));
      gs.save!.league.season = RulesEngine.graceSeasons + 1;
      final b = breach();
      expect(b, isNotNull);
      expect(b!.level, TodoLevel.must);
      expect(b.place, TodoPlaces.financeRules);
      expect(b.note, contains('外れます'));
    });

    test('違反が無ければ出さない', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      gs.save!.ruleSet = RuleSet.britain;
      final items = TodoAdvisor.build(gs, hasSigningProposals: false);
      expect(items.where((t) => t.kind == TodoKind.ruleBreach), isEmpty);
    });

    test('理事会の給与予算を超えると必須に出る', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      gs.save!.wageBudget = 1;
      final items = TodoAdvisor.build(gs, hasSigningProposals: false);
      final over =
          items.where((t) => t.kind == TodoKind.wageBudgetOver).firstOrNull;
      expect(over?.level, TodoLevel.must);
    });

    test('開幕前は、予算の配り方を決められる知らせがおすすめに出る', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      expect(gs.isOffseason, isTrue);
      final items = TodoAdvisor.build(gs, hasSigningProposals: false);
      expect(items.where((t) => t.kind == TodoKind.budgetPlan).single.level,
          TodoLevel.recommended);
    });
  });

  group('経営アドバイザー', () {
    test('財務顧問の増える収入は、レベルとともに増える', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      final g1 = gs.advisorFinanceGain(1);
      expect(g1, greaterThan(0));
      expect(gs.advisorFinanceGain(3), greaterThan(g1));
      expect(gs.advisorFinanceGain(0), 0);
      // 今のレベルを変えても、各レベルの見込みは変わらない(雇わないとき
      // からの差で測る)。
      await gs.setAdvisorLevel(Advisor.finance, 2);
      expect((gs.advisorFinanceGain(1) - g1).abs(), lessThanOrEqualTo(1));
      expect(gs.advisorFee(2), gs.scaledMoney(AdvisorEngine.salary(2)));
    });
  });

  group('スタッフの交渉(第6段の残り)', () {
    test('年俸の低い人でも、1つ下げただけでは年俸の低さで断らない', () {
      for (final ask in [2, 4, 5, 9]) {
        expect(StaffTermsEngine.minWage(ask), ask - 1, reason: '要求 $ask');
      }
      // 10以上は今までどおり9割。
      expect(StaffTermsEngine.minWage(20), 18);
      expect(StaffTermsEngine.minWage(1), 1);
      const ask = StaffTerms(
          role: StaffRole.scout, weeklyWage: 4, years: 2, signingBonus: 32);
      final lower = ask.copyWith(weeklyWage: 3);
      expect(StaffTermsEngine.reply(ask, lower).kind,
          isNot(StaffReplyKind.wageLow));
      // サイン料で埋めれば合意する。
      final traded = lower.copyWith(signingBonus: 32 + 52 * 2);
      expect(StaffTermsEngine.reply(ask, traded).accepted, isTrue);
      expect(StaffTermsEngine.reply(ask, ask.copyWith(weeklyWage: 2)).kind,
          StaffReplyKind.wageLow);
    });
  });

  group('上の帯の資金', () {
    test('英語は「 yen」を付けない短い形(単位は見出しの側)', () {
      Tr.language = AppLanguage.english;
      expect(formatMoneyCompact(81080), '810.8m');
      expect(formatMoneyCompact(150000), '1.5bn');
      expect(formatMoneyCompact(-50), '-500k');
      expect(formatMoneyCompact(0), '0');
      Tr.language = AppLanguage.japanese;
      expect(formatMoneyCompact(81080), formatMoney(81080));
    });
  });
}
