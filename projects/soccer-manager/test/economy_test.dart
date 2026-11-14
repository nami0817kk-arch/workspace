import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/economy_engine.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
  });
  tearDown(() => Tr.language = AppLanguage.system);

  group('景気の移り変わり', () {
    test('平常からは、好況・平常・不況へ 2:6:2 で動く', () {
      expect(EconomyEngine.next(EconomyPhase.normal, 0.0), EconomyPhase.boom);
      expect(EconomyEngine.next(EconomyPhase.normal, 0.19), EconomyPhase.boom);
      expect(EconomyEngine.next(EconomyPhase.normal, 0.20), EconomyPhase.normal);
      expect(EconomyEngine.next(EconomyPhase.normal, 0.79), EconomyPhase.normal);
      expect(EconomyEngine.next(EconomyPhase.normal, 0.80), EconomyPhase.slump);
    });

    test('好況・不況は居座りやすく、逆の極端へはまず動かない', () {
      var jumps = 0;
      const n = 1000;
      for (var i = 0; i < n; i++) {
        final roll = i / n;
        if (EconomyEngine.next(EconomyPhase.boom, roll) == EconomyPhase.slump) {
          jumps++;
        }
        if (EconomyEngine.next(EconomyPhase.slump, roll) == EconomyPhase.boom) {
          jumps++;
        }
      }
      // 好況→不況 10%、不況→好況 10%。
      expect(jumps, 200);
      expect(EconomyEngine.next(EconomyPhase.boom, 0.39), EconomyPhase.boom);
      expect(EconomyEngine.next(EconomyPhase.slump, 0.5), EconomyPhase.normal);
    });

    test('収入の倍率は、好況で増え、不況で減る', () {
      expect(EconomyPhase.boom.incomeMultiplier, greaterThan(1));
      expect(EconomyPhase.normal.incomeMultiplier, 1);
      expect(EconomyPhase.slump.incomeMultiplier, lessThan(1));
    });
  });

  group('ゲームの中', () {
    test('最初のシーズンは平常で、収入に影響しない', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      expect(gs.economyPhase, EconomyPhase.normal);
    });

    test('景気で週収入が変わる(好況>平常>不況)', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      final id = gs.save!.userTeamId;
      gs.save!.economyPhase = EconomyPhase.normal;
      final normal = gs.weeklyIncomeFor(id);
      gs.save!.economyPhase = EconomyPhase.boom;
      final boom = gs.weeklyIncomeFor(id);
      gs.save!.economyPhase = EconomyPhase.slump;
      final slump = gs.weeklyIncomeFor(id);
      expect(boom, greaterThan(normal));
      expect(slump, lessThan(normal));
    });

    test('景気を進めると、予報が今季になり、次の予報が引かれ、ニュースに残る', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      final save = gs.save!;
      save.economyNext = EconomyPhase.slump;
      final news = save.newsLog.length;
      gs.debugAdvanceEconomy(0.0); // 不況のあとの 0.0 は好況
      expect(save.economyPhase, EconomyPhase.slump);
      expect(save.economyNext, EconomyPhase.boom);
      expect(save.newsLog.length, news + 1);
    });

    test('週収入の内訳の合計は、景気があっても週収入と一致する', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      gs.save!.economyPhase = EconomyPhase.slump;
      final id = gs.save!.userTeamId;
      final p = gs.weeklyIncomeParts(id);
      expect(p.gate + p.sponsor + p.merchandise, gs.weeklyIncomeFor(id));
    });

    test('景気は保存して読み戻せ、無い旧セーブは平常で読める', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      gs.save!.economyPhase = EconomyPhase.slump;
      gs.save!.economyNext = EconomyPhase.boom;
      final json = gs.save!.toJson();
      final back = SaveGame.fromJson(json);
      expect(back.economyPhase, EconomyPhase.slump);
      expect(back.economyNext, EconomyPhase.boom);
      json
        ..remove('economyPhase')
        ..remove('economyNext');
      final old = SaveGame.fromJson(json);
      expect(old.economyPhase, EconomyPhase.normal);
      expect(old.economyNext, EconomyPhase.normal);
    });
  });
}
