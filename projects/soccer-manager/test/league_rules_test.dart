import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/league_rules.dart';
import 'package:soccer_manager/models/ledger.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

SeasonLedger _season(int s, {required int income, required int cost}) =>
    SeasonLedger(s)
      ..add(LedgerCategory.gate, income)
      ..add(LedgerCategory.playerWages, -cost);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
  });
  tearDown(() => Tr.language = AppLanguage.system);

  group('英国式(収支規則)', () {
    test('累積赤字が上限(営業収入の25%)以内なら罰は無い', () {
      final r = RulesEngine.evaluate(
        ruleSet: RuleSet.britain,
        // 収入1000の上限は下限の300。累積赤字は200に収まっている。
        ledgers: [
          _season(1, income: 1000, cost: 1070),
          _season(2, income: 1000, cost: 1070),
          _season(3, income: 1000, cost: 1060),
        ],
        budget: 5000,
      );
      expect(r.penalty, isNull);
    });

    test('上限に近づくと注意、超えると罰金と勝ち点の剥奪', () {
      final warn = RulesEngine.evaluate(
        ruleSet: RuleSet.britain,
        ledgers: [
          // 収入2000なら上限は500。累積赤字450は上限の90%で、注意。
          _season(1, income: 2000, cost: 2000),
          _season(2, income: 2000, cost: 2200),
          _season(3, income: 2000, cost: 2250),
        ],
        budget: 5000,
      );
      expect(warn.statuses.single.level, 1);
      expect(warn.penalty, isNull);

      final breach = RulesEngine.evaluate(
        ruleSet: RuleSet.britain,
        ledgers: [
          _season(1, income: 1000, cost: 1200),
          _season(2, income: 1000, cost: 1200),
          _season(3, income: 1000, cost: 1200),
        ],
        budget: 5000,
      );
      final p = breach.penalty!;
      expect(breach.statuses.single.level, 2);
      expect(p.fine, greaterThan(0));
      expect(p.pointsDeduction, greaterThanOrEqualTo(3));
      expect(p.pointsDeduction, lessThanOrEqualTo(12));
      expect(p.trustLoss, greaterThan(0));
    });

    test('数える季は直近3季だけ。古い大赤字は忘れられる', () {
      final r = RulesEngine.evaluate(
        ruleSet: RuleSet.britain,
        ledgers: [
          _season(1, income: 1000, cost: 5000),
          _season(2, income: 1000, cost: 900),
          _season(3, income: 1000, cost: 900),
          _season(4, income: 1000, cost: 900),
        ],
        budget: 5000,
      );
      expect(r.penalty, isNull);
    });

    test('収入が小さくても、上限は下限(300万円)を割らない', () {
      expect(RulesEngine.lossLimitFor([_season(1, income: 100, cost: 0)]),
          RulesEngine.lossLimitFloor);
      expect(RulesEngine.lossLimitFor([]), RulesEngine.lossLimitFloor);
    });
  });

  group('日本式(クラブライセンス)', () {
    test('債務超過だと、補強が1季禁止され、勝ち点は引かれない', () {
      final r = RulesEngine.evaluate(
        ruleSet: RuleSet.japan,
        ledgers: [_season(1, income: 1000, cost: 900)],
        budget: -1,
      );
      expect(r.penalty!.banSeasons, 1);
      expect(r.penalty!.pointsDeduction, 0);
    });

    test('3季連続の赤字で勝ち点を引かれる。2季なら注意まで', () {
      final two = RulesEngine.evaluate(
        ruleSet: RuleSet.japan,
        ledgers: [
          _season(1, income: 1000, cost: 900),
          _season(2, income: 1000, cost: 1100),
          _season(3, income: 1000, cost: 1100),
        ],
        budget: 100,
      );
      expect(two.penalty, isNull);
      expect(two.statuses.last.level, 1);

      final three = RulesEngine.evaluate(
        ruleSet: RuleSet.japan,
        ledgers: [
          _season(1, income: 1000, cost: 1100),
          _season(2, income: 1000, cost: 1100),
          _season(3, income: 1000, cost: 1100),
        ],
        budget: 100,
      );
      expect(three.penalty!.pointsDeduction, 6);
    });

    test('黒字の季が挟まれば、連続は数え直し', () {
      final r = RulesEngine.evaluate(
        ruleSet: RuleSet.japan,
        ledgers: [
          _season(1, income: 1000, cost: 1100),
          _season(2, income: 1000, cost: 1100),
          _season(3, income: 1000, cost: 900),
          _season(4, income: 1000, cost: 1100),
        ],
        budget: 100,
      );
      expect(r.penalty, isNull);
    });

    test('債務超過と連続赤字が重なると、罰が合わさる', () {
      final r = RulesEngine.evaluate(
        ruleSet: RuleSet.japan,
        ledgers: [
          _season(1, income: 1000, cost: 1100),
          _season(2, income: 1000, cost: 1100),
          _season(3, income: 1000, cost: 1100),
        ],
        budget: -50,
      );
      expect(r.penalty!.banSeasons, 1);
      expect(r.penalty!.pointsDeduction, 6);
      expect(r.penalty!.trustLoss, 20);
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

    test('勝ち点の剥奪は順位表に効く', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      final id = gs.save!.userTeamId;
      final before = gs.save!.league.computeStandings()[id]!.points;
      gs.save!.league.pointsAdjustments[id] = -6;
      expect(gs.save!.league.computeStandings()[id]!.points, before - 6);
    });

    test('規則と罰は保存して読み戻せ、無い旧セーブは英国式で読める', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      gs.save!.ruleSet = RuleSet.japan;
      gs.save!.transferBanSeasons = 2;
      gs.save!.pendingPointsDeduction = 4;
      gs.save!.league.pointsAdjustments[gs.save!.userTeamId] = -3;
      final json = gs.save!.toJson();
      final back = SaveGame.fromJson(json);
      expect(back.ruleSet, RuleSet.japan);
      expect(back.transferBanSeasons, 2);
      expect(back.pendingPointsDeduction, 4);
      expect(back.league.pointsAdjustments[back.userTeamId], -3);

      json
        ..remove('ruleSet')
        ..remove('transferBanSeasons')
        ..remove('pendingPointsDeduction');
      final old = SaveGame.fromJson(json);
      expect(old.ruleSet, RuleSet.britain);
      expect(old.transferBanSeasons, 0);
    });

    test('罰を科すと、信頼度が下がり、補強が禁止され、ニュースに残る', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      final save = gs.save!;
      save.ruleSet = RuleSet.japan;
      save.budget = -100; // 債務超過
      save.confidence = 50;
      final newsBefore = save.newsLog.length;
      gs.debugEnforceLeagueRules();
      expect(save.transferBanSeasons, 1);
      expect(save.confidence, 40);
      expect(save.newsLog.length, newsBefore + 1);
    });

    test('罰の補強禁止は、季が進むと解ける', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      final save = gs.save!;
      save.ruleSet = RuleSet.japan;
      save.budget = 5000;
      save.transferBanSeasons = 1;
      gs.debugEnforceLeagueRules();
      expect(save.transferBanSeasons, 0);
    });
  });
}
