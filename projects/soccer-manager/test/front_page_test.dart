import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/front_page_engine.dart';
import 'package:soccer_manager/models/manager_profile.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 新聞の一面と、監督の試合後の一言の検査。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => Tr.language = AppLanguage.system);

  String h({int gf = 1, int ga = 0, bool derby = false, int rank = 5,
          List<String> m = const []}) =>
      FrontPageEngine.headline(
          club: 'A',
          opponent: 'B',
          goalsFor: gf,
          goalsAgainst: ga,
          derby: derby,
          rank: rank,
          milestones: m);

  test('いちばん大きな話を選ぶ: 記録 → ダービー → 大勝・大敗 → 首位 → 結果', () {
    Tr.language = AppLanguage.japanese;
    expect(h(m: ['Xがハットトリック達成']), contains('ハットトリック'));
    expect(h(derby: true), contains('ダービー'));
    expect(h(gf: 4, ga: 0), contains('大勝'));
    expect(h(gf: 0, ga: 4), contains('大敗'));
    expect(h(rank: 1), contains('首位'));
    expect(h(gf: 2, ga: 1), contains('勝利'));
    expect(h(gf: 1, ga: 1), contains('分ける'));
  });

  test('監督の一言は、結果と考え方で変わる', () {
    Tr.language = AppLanguage.japanese;
    final a = FrontPageEngine.managerQuote(
        goalsFor: 2, goalsAgainst: 0, style: ManagerStyle.attacking);
    final d = FrontPageEngine.managerQuote(
        goalsFor: 2, goalsAgainst: 0, style: ManagerStyle.defensive);
    expect(a, isNot(d));
    final loss = FrontPageEngine.managerQuote(
        goalsFor: 0, goalsAgainst: 2, style: ManagerStyle.attacking);
    expect(loss, isNot(a));
  });

  test('リーグ戦を1節すすめると一面が出て、保存して読み戻せる', () async {
    final gs = GameState();
    await gs.startNewGame('新聞FC');
    expect(gs.save!.frontPageHeadline, isNull);
    await gs.playNextMatchdayQuickSim();
    expect(gs.save!.frontPageHeadline, isNotNull);
    expect(gs.save!.frontPageQuote, isNotNull);
    final c = SaveGame.fromJson(gs.save!.toJson());
    expect(c.frontPageHeadline, gs.save!.frontPageHeadline);
  });
}
