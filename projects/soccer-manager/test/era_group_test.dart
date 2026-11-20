import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/logic/era_engine.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('時代は5季ごとに変わり、最初の5季は今の時代', () {
    expect(EraEngine.eraOf(1), Era.present);
    expect(EraEngine.eraOf(5), Era.present);
    expect(EraEngine.eraOf(6), Era.tvBoom);
    expect(EraEngine.eraOf(11), Era.transferInflation);
    expect(EraEngine.eraOf(16), Era.austerity);
    expect(EraEngine.eraOf(21), Era.tvBoom);
  });

  test('時代が変わると、放映権と移籍金の言い値が動く', () async {
    final gs = GameState();
    await gs.startNewGame('時代FC');
    final s = gs.save!;
    final p = s.league.teams
        .firstWhere((t) => t.id != gs.userTeam.id)
        .players
        .first;
    final tv = gs.weeklyBroadcastIncome;
    final price = gs.askingPriceFor(p);
    s.league.season = 6; // 放映権の高騰
    expect(gs.currentEra, Era.tvBoom);
    expect(gs.weeklyBroadcastIncome, greaterThan(tv));
    expect(gs.askingPriceFor(p), greaterThan(price));
  });

  test('私財でほかのクラブを買い、季の損益が入り、売れる。その選手は半額',
      () async {
    final gs = GameState();
    await gs.startNewGame('グループFC');
    final s = gs.save!..ownerWealth = 1 << 30;
    final (club, price) = gs.groupClubCandidates.first;
    final p = club.players.first;
    final before = gs.askingPriceFor(p);
    expect(await gs.buyGroupClub(club.id), isTrue);
    expect(s.ownerWealth, (1 << 30) - price);
    expect(gs.askingPriceFor(p), (before * 0.5).round());
    gs.debugSettleGroupClubs();
    expect(SaveGame.fromJson(s.toJson()).groupClubs[club.id], price);
    expect(await gs.sellGroupClub(club.id), isTrue);
    expect(gs.groupClubsOwned, isEmpty);
  });
}
