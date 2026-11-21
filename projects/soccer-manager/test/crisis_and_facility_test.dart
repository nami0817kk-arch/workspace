import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/logic/facility_investment_engine.dart';
import 'package:soccer_manager/models/owner_work.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 経営危機の手(資金がマイナスのときだけ)と、施設予算の効きの時間差。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('経営危機の手', () {
    test('危機の手は3件で、資金がマイナスのときだけ打てる', () async {
      final game = GameState();
      await game.startNewGame('危機FC');
      final crisis = ownerWorks.where((w) => w.onlyInRed).toList();
      expect(crisis.length, 3);

      game.save!.budget = 5000;
      for (final w in crisis) {
        expect(game.canDoOwnerWork(w), isFalse, reason: '黒字では打てない: ${w.id}');
      }
      game.save!.budget = -500;
      for (final w in crisis) {
        expect(game.canDoOwnerWork(w), isTrue, reason: '赤字なら打てる: ${w.id}');
      }
    });

    test('緊急融資を打つと資金が増え、株主の期待が下がる', () async {
      final game = GameState();
      await game.startNewGame('危機FC');
      final save = game.save!;
      save.budget = -1000;
      save.shareholderExpectation = 50;

      expect(await game.doOwnerWork('emergency_loan'), isTrue);
      // 額は部の規模で掛かる(3部から始まる。2026-11-22)。
      expect(save.budget, -1000 + game.scaledMoney(2500));
      expect(save.shareholderExpectation, 45);
      expect(await game.doOwnerWork('emergency_loan'), isFalse,
          reason: '今季は一度だけ');
    });
  });

  group('施設予算の効きの時間差', () {
    test('初期の配分(倍率1.0)のままなら、蓄積も収入の倍率も1.0', () {
      final m = FacilityInvestmentEngine.nextMomentum(momentum: 1.0, ratio: 1.0);
      expect(m, 1.0);
      expect(FacilityInvestmentEngine.gateMultiplier(m), 1.0);
    });

    test('施設を厚くしても、効きは育成より遅い(1年目は4分の1)', () {
      final y1 = FacilityInvestmentEngine.nextMomentum(momentum: 1.0, ratio: 1.8);
      expect(y1, closeTo(1.0 + 0.8 / 4, 1e-9));
    });

    test('厚いまま続けると収入の倍率が上がり、削ると下がる', () {
      var up = 1.0;
      var down = 1.0;
      for (var i = 0; i < 5; i++) {
        up = FacilityInvestmentEngine.nextMomentum(momentum: up, ratio: 1.8);
        down = FacilityInvestmentEngine.nextMomentum(momentum: down, ratio: 0.6);
      }
      expect(FacilityInvestmentEngine.gateMultiplier(up), greaterThan(1.0));
      expect(FacilityInvestmentEngine.gateMultiplier(down), lessThan(1.0));
    });

    test('倍率は範囲に収まる', () {
      expect(FacilityInvestmentEngine.gateMultiplier(99), lessThanOrEqualTo(1.12));
      expect(FacilityInvestmentEngine.gateMultiplier(-99), greaterThanOrEqualTo(0.94));
    });

    test('蓄積は保存して読み戻せ、無い旧セーブは1.0', () async {
      final game = GameState();
      await game.startNewGame('施設FC');
      game.save!.facilityMomentum = 1.25;
      final restored = SaveGame.fromJson(game.save!.toJson());
      expect(restored.facilityMomentum, closeTo(1.25, 1e-9));
      final old =
          SaveGame.fromJson(game.save!.toJson()..remove('facilityMomentum'));
      expect(old.facilityMomentum, 1.0);
    });
  });
}
