import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/logic/country_coefficient.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('係数は5季まで足し、順位で出場枠が決まる', () {
    var h = <double>[];
    for (var i = 0; i < 7; i++) {
      h = CountryCoefficientEngine.push(h, i.toDouble());
    }
    expect(h, [2, 3, 4, 5, 6]);
    expect(CountryCoefficientEngine.total(h), 20);
    // 2026-11-22 に実在の数へ(1・2位5、3・4位4、5位3)。
    expect(CountryCoefficientEngine.spotsForRank(1), 5);
    expect(CountryCoefficientEngine.spotsForRank(3), 4);
    expect(CountryCoefficientEngine.spotsForRank(5), 3);
    expect(
        CountryCoefficientEngine.seasonPoints(wins: 3, draws: 1, roundsWon: 2),
        9);
  });

  test('季の締めで各国の係数が増え、大陸大会の相手は他国の1部のクラブ', () async {
    final gs = GameState();
    await gs.startNewGame('係数FC');
    final s = gs.save!;
    gs.debugUpdateCountryCoefficients();
    expect(s.countryCoefficients.length, gs.countryCoefficientRanking.length);
    expect(gs.continentalSpots, inInclusiveRange(3, 5));

    final opp = gs.debugContinentalOpponents();
    expect(opp.length, 7);
    final foreignIds = {
      for (final l in s.foreignLeagues.values)
        for (final t in l.teams) t.id,
    };
    for (final t in opp) {
      expect(foreignIds, contains(t.id));
      expect(t.players, isNotEmpty);
    }

    final back = SaveGame.fromJson(s.toJson());
    expect(back.countryCoefficients.keys, s.countryCoefficients.keys);
  });
}
