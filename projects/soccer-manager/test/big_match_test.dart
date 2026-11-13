import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 勝負の試合は年に数回だけ宣言でき、宣言した試合でだけ戦術と先発を自分で決める。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('初めは宣言しておらず、回数は満タン', () async {
    final gs = GameState();
    await gs.startNewGame('テストFC');
    expect(gs.isNextMatchBig, isFalse);
    expect(gs.bigMatchesLeft, GameStateFinance.bigMatchesPerSeason);
  });

  test('宣言すると回数が減り、取り消すと戻る', () async {
    final gs = GameState();
    await gs.startNewGame('テストFC');
    expect(await gs.declareBigMatch(), isTrue);
    expect(gs.isNextMatchBig, isTrue);
    expect(gs.bigMatchesLeft, GameStateFinance.bigMatchesPerSeason - 1);

    // 同じ試合を二重に宣言しても、回数は減らない。
    expect(await gs.declareBigMatch(), isFalse);
    expect(gs.bigMatchesLeft, GameStateFinance.bigMatchesPerSeason - 1);

    await gs.cancelBigMatch();
    expect(gs.isNextMatchBig, isFalse);
    expect(gs.bigMatchesLeft, GameStateFinance.bigMatchesPerSeason);
  });

  test('回数が尽きたら宣言できない', () async {
    final gs = GameState();
    await gs.startNewGame('テストFC');
    final save = gs.save!;
    save.bigMatchSeason = save.league.season;
    save.bigMatchesUsed = GameStateFinance.bigMatchesPerSeason;
    expect(gs.bigMatchesLeft, 0);
    expect(await gs.declareBigMatch(), isFalse);
    expect(gs.isNextMatchBig, isFalse);
  });

  test('シーズンが変わると回数は満タンに戻る', () async {
    final gs = GameState();
    await gs.startNewGame('テストFC');
    final save = gs.save!;
    save.bigMatchSeason = save.league.season - 1;
    save.bigMatchesUsed = GameStateFinance.bigMatchesPerSeason;
    expect(gs.bigMatchesLeft, GameStateFinance.bigMatchesPerSeason);
  });

  test('勝負の試合でない節は、監督が構えを決める(相手との力関係から)', () async {
    final gs = GameState();
    await gs.startNewGame('テストFC');
    await gs.playNextMatchdayQuickSim();
    // 宣言が無いので、2節目以降も宣言は付かない。
    expect(gs.isNextMatchBig, isFalse);
  });

  test('宣言は保存して読み戻せ、無い旧セーブは宣言なしで読める', () async {
    final gs = GameState();
    await gs.startNewGame('テストFC');
    await gs.declareBigMatch();
    final json = gs.save!.toJson();
    final restored = SaveGame.fromJson(json);
    expect(restored.bigMatchesUsed, 1);
    expect(restored.bigMatchDeclaredMatchday, gs.save!.bigMatchDeclaredMatchday);

    json
      ..remove('bigMatchSeason')
      ..remove('bigMatchesUsed')
      ..remove('bigMatchDeclaredMatchday');
    final old = SaveGame.fromJson(json);
    expect(old.bigMatchesUsed, 0);
    expect(old.bigMatchDeclaredMatchday, -1);
  });
}
