import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/logic/youth_investment_engine.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 育成予算の効きの時間差。厚くしても、すぐには効かない。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('初期の配分(倍率1.0)のままなら、蓄積は動かず補正は0', () {
    final m = YouthInvestmentEngine.nextMomentum(momentum: 1.0, ratio: 1.0);
    expect(m, 1.0);
    expect(YouthInvestmentEngine.qualityBonus(m), 0);
  });

  test('育成を倍に厚くしても、1年目は目標の3分の1しか進まない', () {
    final y1 = YouthInvestmentEngine.nextMomentum(momentum: 1.0, ratio: 2.0);
    expect(y1, closeTo(1.0 + 1.0 / 3, 1e-9));
    expect(y1, lessThan(1.5), reason: '1年目はまだ半分も効かない');
  });

  test('厚いまま続けると、3年目には大半が効き、補正も大きくなる', () {
    var m = 1.0;
    final bonuses = <int>[];
    for (var i = 0; i < 4; i++) {
      m = YouthInvestmentEngine.nextMomentum(momentum: m, ratio: 2.0);
      bonuses.add(YouthInvestmentEngine.qualityBonus(m));
    }
    expect(bonuses.first, lessThan(bonuses[2]));
    expect(bonuses[2], lessThan(bonuses.last));
    expect(m, greaterThan(1.7));
  });

  test('削ると、じわじわ弱くなり、補正は負になる', () {
    var m = 1.0;
    for (var i = 0; i < 3; i++) {
      m = YouthInvestmentEngine.nextMomentum(momentum: m, ratio: 0.5);
    }
    expect(m, lessThan(1.0));
    expect(YouthInvestmentEngine.qualityBonus(m), lessThan(0));
  });

  test('蓄積と補正は範囲に収まる', () {
    var m = 1.0;
    for (var i = 0; i < 30; i++) {
      m = YouthInvestmentEngine.nextMomentum(momentum: m, ratio: 99);
    }
    expect(m, lessThanOrEqualTo(YouthInvestmentEngine.maxMomentum));
    expect(YouthInvestmentEngine.qualityBonus(m), lessThanOrEqualTo(8));
    for (var i = 0; i < 30; i++) {
      m = YouthInvestmentEngine.nextMomentum(momentum: m, ratio: 0);
    }
    expect(m, greaterThanOrEqualTo(YouthInvestmentEngine.minMomentum));
    expect(YouthInvestmentEngine.qualityBonus(m), greaterThanOrEqualTo(-4));
  });

  test('蓄積は保存して読み戻せ、無い旧セーブは1.0', () async {
    final game = GameState();
    await game.startNewGame('育成FC');
    game.save!.youthMomentum = 1.4;
    final restored = SaveGame.fromJson(game.save!.toJson());
    expect(restored.youthMomentum, closeTo(1.4, 1e-9));

    final old =
        SaveGame.fromJson(game.save!.toJson()..remove('youthMomentum'));
    expect(old.youthMomentum, 1.0);
  });
}
