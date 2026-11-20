import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/equity_engine.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
  });
  tearDown(() => Tr.language = AppLanguage.system);

  group('持分の計算', () {
    test('売値は割引、買い戻しはプレミアが乗る', () {
      expect(EquityEngine.salePrice(10000, 10), 900);
      expect(EquityEngine.buybackCost(10000, 10), 1100);
    });

    test('持分は51%を割る売却ができない', () {
      expect(EquityEngine.sellable(100), 10);
      expect(EquityEngine.sellable(60), 0);
      expect(EquityEngine.sellable(70), 10);
    });

    test('配当は黒字の半分を外部の持分の割合で分ける。赤字なら無し', () {
      expect(EquityEngine.dividend(ownerShare: 100, seasonProfit: 1000), 0);
      expect(EquityEngine.dividend(ownerShare: 70, seasonProfit: 1000), 150);
      expect(EquityEngine.dividend(ownerShare: 70, seasonProfit: -500), 0);
    });
  });

  group('ゲームの中', () {
    test('売ると資金が増えて持分が減り、買い戻すと逆になる', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      final before = gs.save!.budget;
      expect(gs.ownerShare, 100);
      expect(await gs.sellStake(), isTrue);
      expect(gs.ownerShare, 90);
      expect(gs.save!.budget, greaterThan(before));
      final mid = gs.save!.budget;
      expect(await gs.buyBackStake(), isTrue);
      expect(gs.ownerShare, 100);
      expect(gs.save!.budget, lessThan(mid));
    });

    test('51%までしか売れない', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      for (var i = 0; i < 4; i++) {
        expect(await gs.sellStake(), isTrue);
      }
      expect(gs.ownerShare, 60);
      expect(await gs.sellStake(), isFalse);
      expect(gs.ownerShare, 60);
    });

    test('持分は保存して読み戻せ、無い旧セーブは100%', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      gs.save!.ownerShare = 70;
      final json = gs.save!.toJson();
      expect(SaveGame.fromJson(json).ownerShare, 70);
      json.remove('ownerShare');
      expect(SaveGame.fromJson(json).ownerShare, 100);
    });
  });
}
