import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
  });
  tearDown(() => Tr.language = AppLanguage.system);

  test('殿堂の選手を永久欠番にすると、サポーターの期待が上がり、一度だけ', () async {
    final gs = GameState();
    await gs.startNewGame('テストFC');
    final save = gs.save!;
    final legend = save.league.teams.first.players.first;
    save.retiredLegends.add(legend);
    save.confidence = 50;
    expect(gs.isNumberRetired(legend.id), isFalse);
    expect(await gs.retireNumber(legend.id), isTrue);
    expect(gs.isNumberRetired(legend.id), isTrue);
    expect(save.confidence, 53);
    expect(await gs.retireNumber(legend.id), isFalse);
    expect(save.confidence, 53);
  });

  test('殿堂にいない選手は永久欠番にできない', () async {
    final gs = GameState();
    await gs.startNewGame('テストFC');
    expect(await gs.retireNumber('nobody'), isFalse);
  });

  test('保存して読み戻せ、無い旧セーブは空', () async {
    final gs = GameState();
    await gs.startNewGame('テストFC');
    gs.save!.retiredNumberIds.add('p1');
    final json = gs.save!.toJson();
    expect(SaveGame.fromJson(json).retiredNumberIds, ['p1']);
    json.remove('retiredNumberIds');
    expect(SaveGame.fromJson(json).retiredNumberIds, isEmpty);
  });
}
