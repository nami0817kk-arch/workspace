import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/logic/ledger_engine.dart';
import 'package:soccer_manager/logic/loan_engine.dart';
import 'package:soccer_manager/models/ledger.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 収支の記録。資金が動いたら、必ずどこかの項目に入っている。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('項目と合計', () {
    test('損益は融資・預金の元本を含めず、資金の増減は含める', () {
      final l = SeasonLedger(1)
        ..add(LedgerCategory.gate, 500)
        ..add(LedgerCategory.playerWages, -200)
        ..add(LedgerCategory.financing, 1000);
      expect(l.profit, 300);
      expect(l.cashChange, 1300);
    });

    test('営業収入には売却益を含めず、人件費は出場手当まで含む', () {
      final l = SeasonLedger(1)
        ..add(LedgerCategory.gate, 400)
        ..add(LedgerCategory.sponsor, 100)
        ..add(LedgerCategory.playerSales, 900)
        ..add(LedgerCategory.playerWages, -300)
        ..add(LedgerCategory.staffWages, -50)
        ..add(LedgerCategory.appearanceFees, -50);
      expect(l.operatingIncome, 500);
      expect(l.wageCost, 400);
      expect(l.wageRatio, closeTo(0.8, 1e-9));
    });

    test('営業収入が無いときの人件費率は 0(割り算で落ちない)', () {
      expect(SeasonLedger(1).wageRatio, 0);
    });

    test('保存して読み戻せる', () {
      final l = SeasonLedger(3)
        ..add(LedgerCategory.prize, 700)
        ..add(LedgerCategory.transfers, -250);
      final back = SeasonLedger.fromJson(l.toJson());
      expect(back.season, 3);
      expect(back.of(LedgerCategory.prize), 700);
      expect(back.of(LedgerCategory.transfers), -250);
      expect(back.of(LedgerCategory.gate), 0);
    });
  });

  group('見通しと健全度', () {
    test('毎節の収支が黒字なら資金は尽きない', () {
      expect(LedgerEngine.runwayWeeks(budget: 1000, weeklyNet: 0), isNull);
      expect(LedgerEngine.runwayWeeks(budget: 1000, weeklyNet: 50), isNull);
    });

    test('赤字なら、資金が尽きるまでの節数を出す。資金が負なら 0', () {
      expect(LedgerEngine.runwayWeeks(budget: 1000, weeklyNet: -100), 10);
      expect(LedgerEngine.runwayWeeks(budget: 950, weeklyNet: -100), 9);
      expect(LedgerEngine.runwayWeeks(budget: -1, weeklyNet: -100), 0);
    });

    test('人件費率は 70% 超で注意、85% 超で危険', () {
      expect(LedgerEngine.wageRatioLevel(0.70), 0);
      expect(LedgerEngine.wageRatioLevel(0.71), 1);
      expect(LedgerEngine.wageRatioLevel(0.85), 1);
      expect(LedgerEngine.wageRatioLevel(0.86), 2);
    });
  });

  group('ゲームの中の記録', () {
    test('週収入の内訳は、合計が週収入と一致する', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      final id = gs.save!.userTeamId;
      final p = gs.weeklyIncomeParts(id);
      expect(p.gate + p.sponsor + p.merchandise, gs.weeklyIncomeFor(id));
      expect(p.gate, greaterThan(0));
      expect(p.merchandise, greaterThan(0));
    });

    test('節を進めても、資金の増減は記録の合計とぴったり合う', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      final before = gs.save!.budget;
      for (var i = 0; i < 4; i++) {
        await gs.playNextMatchdayQuickSim();
      }
      final ledger = gs.currentLedger;
      // 項目に入れずに資金だけ動かした場所があると、ここがずれる。
      expect(gs.save!.budget - before, ledger.cashChange);
      expect(ledger.of(LedgerCategory.gate), greaterThan(0));
      expect(ledger.of(LedgerCategory.playerWages), lessThan(0));
    });

    test('融資を受けても、損益は動かない(元本は融資・預金の項目)', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      final profitBefore = gs.currentLedger.profit;
      final cashBefore = gs.save!.budget;
      final amount = gs.maxLoanAmount;
      expect(await gs.takeLoan(amount, LoanEngine.terms.first), isTrue);
      expect(gs.save!.budget - cashBefore, amount);
      expect(gs.currentLedger.profit, profitBefore);
      expect(gs.currentLedger.of(LedgerCategory.financing), amount);
    });

    test('給与の支払いは、選手とスタッフに分けて記録される', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      await gs.playNextMatchdayQuickSim();
      final l = gs.currentLedger;
      expect(l.of(LedgerCategory.playerWages), lessThan(0));
      expect(-(l.of(LedgerCategory.playerWages) + l.of(LedgerCategory.staffWages)),
          gs.weeklyWageBill);
    });

    test('今の収支が赤字なら、資金が尽きるまでの節数が出る', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      // 週の収支を赤字にするため、資金を少なくして人件費を重くする。
      for (final p in gs.userTeam.players) {
        p.wage = p.wage * 20;
      }
      gs.save!.budget = 500;
      expect(gs.weeklyNet, lessThan(0));
      final weeks = gs.runwayWeeks;
      expect(weeks, isNotNull);
      expect(weeks, 500 ~/ -gs.weeklyNet);
    });

    test('収支の記録は保存して読み戻せ、無い旧セーブは空で読める', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      await gs.playNextMatchdayQuickSim();
      final json = gs.save!.toJson();
      final restored = SaveGame.fromJson(json);
      expect(restored.ledgers.length, gs.save!.ledgers.length);
      expect(
          restored.ledgerFor(restored.league.season).of(LedgerCategory.gate),
          gs.currentLedger.of(LedgerCategory.gate));

      json.remove('ledgers');
      final old = SaveGame.fromJson(json);
      expect(old.ledgers, isEmpty);
    });

    test('記録は直近の数シーズン分だけ残る', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      final save = gs.save!;
      save.ledgers.clear();
      for (var s = 1; s <= SaveGame.maxLedgerSeasons + 3; s++) {
        save.ledgerFor(s).add(LedgerCategory.gate, s);
      }
      expect(save.ledgers.length, SaveGame.maxLedgerSeasons);
      expect(save.ledgers.first.season, 4);
    });
  });
}
