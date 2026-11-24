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
      final m = <String, int>{ClubProject.museum.name: 2};
      expect(ProjectEngine.tick(m), isEmpty);
      expect(ProjectEngine.isActive(m, ClubProject.museum), isFalse);
      expect(ProjectEngine.tick(m), [ClubProject.museum]);
      expect(ProjectEngine.isActive(m, ClubProject.museum), isTrue);
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
      // 費用は部の規模で掛かる(3部から始まる。2026-11-22)。
      save.budget = 10000000;
      expect(await gs.startProject(ClubProject.fanApp), isTrue);
      expect(save.budget, 10000000 - gs.scaledMoney(ClubProject.fanApp.cost));
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

    test('古いセーブの「提携クラブ」は博物館として読み、2回読んでも動かない', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      final json = gs.save!.toJson();
      json['projects'] = {'partnerClub': 1, 'fanApp': 0, 'unknown': 3};
      final once = SaveGame.fromJson(json);
      expect(once.projects, {ClubProject.museum.name: 1, ClubProject.fanApp.name: 0});
      final twice = SaveGame.fromJson(once.toJson());
      expect(twice.projects, once.projects);
    });

    test('事業の毎月の収入は、始めたら増える額で、博物館は0', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      final before = Map<String, int>.of(gs.save!.projects);
      final monthly = gs.businessMonthlyIncome(ClubProject.fanApp);
      expect(monthly, greaterThan(0));
      expect(gs.businessMonthlyIncome(ClubProject.museum), 0);
      // 測っても事業の状態は変わらない。
      expect(gs.save!.projects, before);
      expect(ProjectEngine.paybackMonths(1200, 100), 12);
      expect(ProjectEngine.paybackMonths(1201, 100), 13);
      expect(ProjectEngine.paybackMonths(100, 0), isNull);
    });

    test('保存して読み戻せ、無い旧セーブは空', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      gs.save!.projects[ClubProject.museum.name] = 1;
      final json = gs.save!.toJson();
      expect(SaveGame.fromJson(json).projects, {ClubProject.museum.name: 1});
      json.remove('projects');
      expect(SaveGame.fromJson(json).projects, isEmpty);
    });
  });
}
