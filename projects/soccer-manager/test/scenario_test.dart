import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/models/club_infrastructure.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/models/start_scenario.dart';
import 'package:soccer_manager/state/game_state.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
  });
  tearDown(() => Tr.language = AppLanguage.system);

  Future<GameState> start(StartScenario s) async {
    final gs = GameState();
    await gs.startNewGame('テストFC', scenario: s);
    return gs;
  }

  test('標準の開始は年表に1行だけ残る', () async {
    final gs = await start(StartScenario.standard);
    expect(gs.save!.scenario, StartScenario.standard);
    expect(gs.save!.timeline.length, 1);
  });

  test('債務のシナリオは資金がマイナスで、株主の期待が低い', () async {
    final std = await start(StartScenario.standard);
    final gs = await start(StartScenario.debt);
    expect(gs.save!.budget, -1500);
    expect(gs.save!.shareholderExpectation,
        lessThan(std.save!.shareholderExpectation));
  });

  test('資産家のシナリオは資金が増え、期待が高い', () async {
    final std = await start(StartScenario.standard);
    final gs = await start(StartScenario.patron);
    expect(gs.save!.budget, greaterThan(std.save!.budget));
    expect(gs.save!.shareholderExpectation,
        greaterThan(std.save!.shareholderExpectation));
  });

  test('育成の名門は、ユースとトレーニング施設が育っていて資金が少ない', () async {
    final std = await start(StartScenario.standard);
    final gs = await start(StartScenario.academy);
    final infra = gs.save!.infrastructure;
    expect(infra.facilityLevel(FacilityType.youthFacility), 3);
    expect(infra.facilityLevel(FacilityType.trainingGround), 2);
    expect(gs.save!.budget, lessThan(std.save!.budget));
  });

  test('年表は200行までで、保存して読み戻せ、無い旧セーブは標準', () async {
    final gs = await start(StartScenario.patron);
    final save = gs.save!;
    for (var i = 0; i < 250; i++) {
      save.timeline.add(TimelineEntry(season: 1, text: 'x$i'));
    }
    final json = save.toJson();
    final back = SaveGame.fromJson(json);
    expect(back.scenario, StartScenario.patron);
    expect(back.timeline.length, save.timeline.length);
    json
      ..remove('scenario')
      ..remove('timeline');
    final old = SaveGame.fromJson(json);
    expect(old.scenario, StartScenario.standard);
    expect(old.timeline, isEmpty);
  });
}
