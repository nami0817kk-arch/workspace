import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('項目ごとに変えた難易度だけが効き、ほかは全体の難易度に従う', () async {
    final normal = GameState();
    await normal.startNewGame('標準FC');
    final mixed = GameState();
    await mixed.startNewGame('混合FC', difficultyItems: {
      DifficultyItem.funds: GameDifficulty.easy,
      DifficultyItem.transferPrices: GameDifficulty.hard,
    });
    final s = mixed.save!;
    expect(s.difficulty, GameDifficulty.normal);
    expect(s.difficultyOf(DifficultyItem.funds), GameDifficulty.easy);
    expect(s.difficultyOf(DifficultyItem.boardTarget), GameDifficulty.normal);
    expect(s.difficultyOf(DifficultyItem.transferPrices), GameDifficulty.hard);
    expect(s.budget, greaterThan(normal.save!.budget));

    // 保存して読み戻せる。全体と同じ項目は持たない。
    final back = SaveGame.fromJson(s.toJson());
    expect(back.difficultyOf(DifficultyItem.funds), GameDifficulty.easy);
    expect(back.difficultyItems.length, 2);
  });

  test('移籍金の言い値は、項目の難易度で1割上下する', () async {
    final gs = GameState();
    await gs.startNewGame('値FC');
    final p = gs.save!.league.teams
        .firstWhere((t) => t.id != gs.userTeam.id)
        .players
        .first;
    final base = gs.askingPriceFor(p);
    gs.save!.difficultyItems['transferPrices'] = 'hard';
    expect(gs.askingPriceFor(p), (base * 1.1).round());
    gs.save!.difficultyItems['transferPrices'] = 'easy';
    expect(gs.askingPriceFor(p), (base * 0.9).round());
  });
}
