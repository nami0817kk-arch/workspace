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

  test('ほかのクラブを持つ機能は外した。古いセーブの持ち分は買値で私財に戻して読む',
      () async {
    final gs = GameState();
    await gs.startNewGame('グループFC');
    final s = gs.save!..ownerWealth = 1000;
    final json = s.toJson();
    expect(json.containsKey('groupClubs'), isFalse);
    final other = s.foreignLeagues.values.first.teams.first;
    json['groupClubs'] = {other.id: 300, 'gone-club': 200};
    final back = SaveGame.fromJson(json);
    expect(back.ownerWealth, 1500);
    expect(back.toJson().containsKey('groupClubs'), isFalse,
        reason: '読み捨てて、次の保存では書かない');
    // 私財がまだ決まっていない(-1)古いセーブはそのまま。
    json['ownerWealth'] = -1;
    expect(SaveGame.fromJson(json).ownerWealth, -1);
  });
}
