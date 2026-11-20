import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/project_engine.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
  });
  tearDown(() => Tr.language = AppLanguage.system);

  group('案件の計算', () {
    test('建設を進めると完成し、稼働中になる', () {
      final m = <String, int>{ClubProject.partnerClub.name: 2};
      expect(ProjectEngine.tick(m), isEmpty);
      expect(ProjectEngine.isActive(m, ClubProject.partnerClub), isFalse);
      expect(ProjectEngine.tick(m), [ClubProject.partnerClub]);
      expect(ProjectEngine.isActive(m, ClubProject.partnerClub), isTrue);
      expect(ProjectEngine.tick(m), isEmpty);
    });

    test('グッズ収入の上乗せは、完成した案件だけ', () {
      final m = <String, int>{
        ClubProject.fanApp.name: 0,
        ClubProject.clubShop.name: 1, // 建設中
      };
      expect(ProjectEngine.weeklyMerchandiseBonus(m, 80), 25);
      m[ClubProject.clubShop.name] = 0;
      expect(ProjectEngine.weeklyMerchandiseBonus(m, 80), 25 + 20);
    });
  });

  group('ゲームの中', () {
    test('着手すると費用が引かれ、同じ案件は二重に着手できない', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      final save = gs.save!;
      save.budget = 100000;
      expect(await gs.startProject(ClubProject.fanApp), isTrue);
      expect(save.budget, 100000 - ClubProject.fanApp.cost);
      expect(await gs.startProject(ClubProject.fanApp), isFalse);
    });

    test('資金が足りないと着手できない', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      gs.save!.budget = 10;
      expect(await gs.startProject(ClubProject.clubShop), isFalse);
    });

    test('完成したファンアプリは週収入を増やす', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      final save = gs.save!;
      final before = gs.weeklyIncomeFor(save.userTeamId);
      save.projects[ClubProject.fanApp.name] = 0;
      expect(gs.weeklyIncomeFor(save.userTeamId), greaterThan(before));
    });

    test('保存して読み戻せ、無い旧セーブは空', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      gs.save!.projects[ClubProject.partnerClub.name] = 1;
      final json = gs.save!.toJson();
      expect(SaveGame.fromJson(json).projects, {ClubProject.partnerClub.name: 1});
      json.remove('projects');
      expect(SaveGame.fromJson(json).projects, isEmpty);
    });
  });
}
