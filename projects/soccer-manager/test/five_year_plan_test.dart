import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/logic/owner_history_engine.dart';
import 'package:soccer_manager/models/owner_legacy.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 5か年計画・オーナーの経歴・歴代オーナーの順位の検査。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('計画の目標は、今から野心の分だけ上(部は1部より上にはならない)', () async {
    final gs = GameState();
    await gs.startNewGame('計画FC');
    final s = gs.save!;
    final tier = s.currentDivisionTier;
    final value = gs.clubValue.total;
    expect(await gs.startFiveYearPlan(PlanAmbition.standard), isTrue);
    expect(s.planTargetTier, (tier - 2).clamp(1, 5));
    expect(s.planTargetValue, (value * 1.6).round());
    expect(gs.planSeasonsLeft, OwnerHistoryEngine.planSeasons);
    expect(await gs.startFiveYearPlan(PlanAmbition.bold), isFalse,
        reason: '計画は1つずつ');
  });

  test('結果の採点: 3つで+15、0で-12', () {
    expect(OwnerHistoryEngine.planResultDelta(3), 15);
    expect(OwnerHistoryEngine.planResultDelta(2), 5);
    expect(OwnerHistoryEngine.planResultDelta(1), -5);
    expect(OwnerHistoryEngine.planResultDelta(0), -12);
  });

  test('オーナーの点と順位表', () {
    const l = OwnerLegacy(
        clubName: 'A',
        seasons: 10,
        leagueTitles: 2,
        cupTitles: 1,
        bestRank: 1,
        reason: SaleReason.supporters);
    expect(OwnerHistoryEngine.score(l), 2 * 30 + 10 + 10 * 2 + 10);
    final t = OwnerHistoryEngine.table(1000);
    expect(t.first.isYou, isTrue);
    final low = OwnerHistoryEngine.table(0);
    expect(low.last.isYou, isTrue);
  });

  test('経歴には今のクラブが入る', () async {
    final gs = GameState();
    await gs.startNewGame('計画FC');
    expect(gs.ownerCareer.last.clubName, gs.save!.clubName);
  });

  test('計画は保存して読み戻せる', () async {
    final gs = GameState();
    await gs.startNewGame('計画FC');
    await gs.startFiveYearPlan(PlanAmbition.steady);
    final c = SaveGame.fromJson(gs.save!.toJson());
    expect(c.planStartSeason, gs.save!.planStartSeason);
    expect(c.planTargetValue, gs.save!.planTargetValue);
    expect(c.planTargetStadium, gs.save!.planTargetStadium);
  });
}
