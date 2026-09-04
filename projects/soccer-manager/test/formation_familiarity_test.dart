import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/models/formation.dart';
import 'package:soccer_manager/models/team.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 布陣の習熟度。
///
/// これが無いと、戦術を毎試合変えても損が無い。新しい布陣がその日から
/// 完成品として機能してしまい、布陣を選ぶことに重みが生まれない。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Team makeTeam({Formation formation = Formation.f442}) => Team(
        id: 't',
        name: 'T',
        formation: formation,
        players: const [],
        retainedOverall: 60,
      );

  group('習熟度の増減', () {
    test('開始時は、いま使っている布陣だけ仕込まれている', () {
      final team = makeTeam();
      expect(team.currentFamiliarity, Team.familiarityStartForCurrent);
      expect(team.formationFamiliarity[Formation.f433] ?? 0, 0,
          reason: '使っていない布陣は0のはず');
    });

    test('週を重ねると、いま使っている布陣に馴染んでいく', () {
      final team = makeTeam();
      final before = team.currentFamiliarity;
      team.advanceFamiliarity();
      expect(team.currentFamiliarity, greaterThan(before));
    });

    test('良いヘッドコーチほど早く馴染む', () {
      final poor = makeTeam()..advanceFamiliarity(coachingBonus: 1);
      final good = makeTeam()..advanceFamiliarity(coachingBonus: 8);
      expect(good.currentFamiliarity, greaterThan(poor.currentFamiliarity));
    });

    test('100を超えない', () {
      final team = makeTeam();
      for (int i = 0; i < 50; i++) {
        team.advanceFamiliarity(coachingBonus: 8);
      }
      expect(team.currentFamiliarity, 100);
    });

    test('使っていない布陣は少しずつ薄れる', () {
      final team = makeTeam();
      team.formationFamiliarity[Formation.f433] = 50;
      team.advanceFamiliarity();
      expect(team.formationFamiliarity[Formation.f433], 49);
    });

    test('薄れても0より下にはならない', () {
      final team = makeTeam();
      team.formationFamiliarity[Formation.f433] = 0;
      team.advanceFamiliarity();
      expect(team.formationFamiliarity[Formation.f433], 0);
    });
  });

  group('チーム力への効き方', () {
    test('馴染んでいない布陣はチーム力が下がる', () {
      final fresh = makeTeam()..formationFamiliarity[Formation.f442] = 0;
      final settled = makeTeam()..formationFamiliarity[Formation.f442] = 100;

      expect(fresh.familiarityFactor, Team.familiarityFloorFactor);
      expect(settled.familiarityFactor, 1.0);
      expect(settled.familiarityFactor,
          greaterThan(fresh.familiarityFactor));
    });

    test('差は 12% に収まる(戦術変更が不可能にならない範囲)', () {
      final fresh = makeTeam()..formationFamiliarity[Formation.f442] = 0;
      final settled = makeTeam()..formationFamiliarity[Formation.f442] = 100;
      final gap = settled.familiarityFactor - fresh.familiarityFactor;
      expect(gap, closeTo(0.12, 0.001));
    });
  });

  group('布陣の変更', () {
    test('別の布陣に変えると、その布陣の習熟度で戦うことになる', () {
      final team = makeTeam();
      expect(team.currentFamiliarity, Team.familiarityStartForCurrent);

      team.formation = Formation.f352;

      expect(team.currentFamiliarity, 0,
          reason: '初めて使う布陣は馴染んでいないはず');
      expect(team.familiarityFactor, lessThan(1.0));
    });

    test('元の布陣に戻せば、積み上げた習熟度は残っている', () {
      final team = makeTeam();
      final original = team.currentFamiliarity;
      team.formation = Formation.f352;
      team.formation = Formation.f442;
      expect(team.currentFamiliarity, original);
    });
  });

  group('保存と旧セーブ', () {
    test('習熟度が保存され、読み直しても変わらない', () {
      final team = makeTeam();
      team.formationFamiliarity[Formation.f433] = 42;

      final restored = Team.fromJson(team.toJson());

      expect(restored.currentFamiliarity, team.currentFamiliarity);
      expect(restored.formationFamiliarity[Formation.f433], 42);
    });

    test('習熟度を持たない旧セーブは、いまの布陣を仕込み済みとして読む', () {
      // ここを0で読むと、読み込んだ途端に全チームの戦術が機能しなくなる。
      final json = makeTeam(formation: Formation.f4231).toJson();
      json.remove('formationFamiliarity');

      final restored = Team.fromJson(json);

      expect(restored.formation, Formation.f4231);
      expect(restored.currentFamiliarity, Team.familiarityStartForCurrent);
    });
  });

  test('週次トレーニングを回すと習熟度が上がる', () async {
    final game = GameState();
    await game.startNewGame('テストFC');
    final before = game.userTeam.currentFamiliarity;

    await game.runWeeklyTraining();

    expect(game.userTeam.currentFamiliarity, greaterThan(before));
  });
}
