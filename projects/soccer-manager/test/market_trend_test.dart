import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/logic/economy_engine.dart';
import 'package:soccer_manager/logic/market_trend.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('好況は上がり、不況は下がり、幅は 70〜180 に収まる', () {
    expect(MarketTrendEngine.next(100, EconomyPhase.boom, 0), 106);
    expect(MarketTrendEngine.next(100, EconomyPhase.boom, 1), 115);
    expect(MarketTrendEngine.next(100, EconomyPhase.normal, 0), 100);
    expect(MarketTrendEngine.next(100, EconomyPhase.slump, 0), 88);
    expect(MarketTrendEngine.next(178, EconomyPhase.boom, 1), 180);
    expect(MarketTrendEngine.next(72, EconomyPhase.slump, 0), 70);
    expect(MarketTrendEngine.apply(1000, 120), 1200);
  });

  test('相場が上がると、移籍金の言い値も上がる', () async {
    final gs = GameState();
    await gs.startNewGame('相場FC');
    final s = gs.save!;
    final p = s.league.teams
        .firstWhere((t) => t.id != gs.userTeam.id)
        .players
        .first;
    final base = gs.askingPriceFor(p);
    s.economyPhase = EconomyPhase.boom;
    gs.debugAdvanceEconomy(0.5, marketRoll: 1);
    expect(gs.marketIndex, 115);
    expect(gs.askingPriceFor(p), greaterThan(base));

    final back = SaveGame.fromJson(s.toJson());
    expect(back.marketIndex, 115);
  });
}
