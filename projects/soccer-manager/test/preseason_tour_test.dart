import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/models/ledger.dart';
import 'package:soccer_manager/models/preseason_camp.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 開幕前の海外ツアーの検査。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('海外ツアーは費用が掛からず収入が入るが、疲れを残す', () async {
    final gs = GameState();
    await gs.startNewGame('遠征FC');
    final s = gs.save!..preseasonCampPending = true;
    final p = gs.userTeam.players.first..fatigue = 0;
    final merch = gs.currentLedger.of(LedgerCategory.merchandise);
    expect(await gs.choosePreseasonCamp(PreseasonCamp.overseasTour), isTrue);
    expect(gs.currentLedger.of(LedgerCategory.merchandise) - merch,
        gs.scaledMoney(PreseasonCamp.overseasTour.revenue));
    expect(p.fatigue, PreseasonCamp.overseasTour.fatigueCost);
    expect(s.preseasonCampPending, isFalse);
  });

  test('ツアーはほかのキャンプより疲れが重く、戦術は進まない', () {
    expect(PreseasonCamp.overseasTour.fatigueCost,
        greaterThan(PreseasonCamp.fitness.fatigueCost));
    expect(PreseasonCamp.overseasTour.familiarityGain, 0);
    expect(PreseasonCamp.overseasTour.cost, 0);
  });
}
