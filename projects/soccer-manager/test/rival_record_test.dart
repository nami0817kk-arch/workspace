import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/models/match_result.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
  });
  tearDown(() => Tr.language = AppLanguage.system);

  test('宿敵との今季の戦績は、終わった試合の勝分敗から数える', () async {
    final gs = GameState();
    await gs.startNewGame('テストFC');
    final save = gs.save!;
    final derbies =
        save.league.fixtures.where((f) => gs.isRivalFixture(f)).toList();
    expect(derbies.length, 2); // 総当たり2回戦
    MatchResult res(String h, String a, int hg, int ag) => MatchResult(
        matchday: 1,
        homeTeamId: h,
        awayTeamId: a,
        homeGoals: hg,
        awayGoals: ag,
        events: const []);
    final u = save.userTeamId;
    final first = derbies[0];
    // 自クラブの2得点0失点で勝つ。
    first.result = first.homeTeamId == u
        ? res(first.homeTeamId, first.awayTeamId, 2, 0)
        : res(first.homeTeamId, first.awayTeamId, 0, 2);
    expect(gs.rivalRecordThisSeason, (won: 1, draw: 0, lost: 0));
    final second = derbies[1];
    second.result = res(second.homeTeamId, second.awayTeamId, 1, 1);
    expect(gs.rivalRecordThisSeason, (won: 1, draw: 1, lost: 0));
    expect(gs.rivalRecord, (won: 1, draw: 1, lost: 0));
  });

  test('過去のシーズンの戦績が通算に足され、保存して読み戻せる', () async {
    final gs = GameState();
    await gs.startNewGame('テストFC');
    gs.save!.rivalPast = [3, 2, 1];
    expect(gs.rivalRecord, (won: 3, draw: 2, lost: 1));
    final json = gs.save!.toJson();
    expect(SaveGame.fromJson(json).rivalPast, [3, 2, 1]);
    json.remove('rivalPast');
    expect(SaveGame.fromJson(json).rivalPast, [0, 0, 0]);
  });
}
