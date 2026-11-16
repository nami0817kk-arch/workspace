import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/models/owner_directive.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/models/team.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 監督への一言の指示: 勝負の試合でなくても、次の節の構えだけは伝えられる。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<GameState> newGame() async {
    final game = GameState();
    await game.startNewGame('指示FC');
    return game;
  }

  test('指示は4種類で、構えが重複せず、名前と説明がある', () {
    expect(OwnerDirective.values.length, 4);
    expect(OwnerDirective.values.map((d) => d.mentality).toSet().length, 4);
    for (final d in OwnerDirective.values) {
      expect(d.label, isNotEmpty, reason: '$d');
      expect(d.description, isNotEmpty, reason: '$d');
    }
    expect(OwnerDirective.attack.mentality, TeamMentality.attacking);
    expect(OwnerDirective.parkTheBus.mentality, TeamMentality.veryDefensive);
  });

  test('出す・上書き・取り下げができる', () async {
    final game = await newGame();
    expect(game.ownerDirective, isNull);
    await game.setOwnerDirective(OwnerDirective.attack);
    expect(game.ownerDirective, OwnerDirective.attack);
    await game.setOwnerDirective(OwnerDirective.defend);
    expect(game.ownerDirective, OwnerDirective.defend);
    await game.clearOwnerDirective();
    expect(game.ownerDirective, isNull);
  });

  test('次の節の準備で構えが指示どおりになり、指示は使い切る', () async {
    final game = await newGame();
    final next = game.save!.league.nextUnplayedFixture!;
    expect(game.isNextMatchBig, isFalse);
    game.userTeam.mentality = TeamMentality.balanced;

    await game.setOwnerDirective(OwnerDirective.allOut);
    game.debugManagerPreparesMatch(next);

    expect(game.userTeam.mentality, TeamMentality.veryAttacking);
    expect(game.ownerDirective, isNull, reason: '節を終えたら使い切る');
  });

  test('勝負の試合では自分で決めるので、指示は構えを変えず流れる', () async {
    final game = await newGame();
    final next = game.save!.league.nextUnplayedFixture!;
    expect(await game.declareBigMatch(), isTrue);
    game.userTeam.mentality = TeamMentality.balanced;

    await game.setOwnerDirective(OwnerDirective.parkTheBus);
    game.debugManagerPreparesMatch(next);

    expect(game.userTeam.mentality, TeamMentality.balanced);
    expect(game.ownerDirective, isNull);
  });

  test('指示は保存して読み戻せ、無い旧セーブは指示なし', () async {
    final game = await newGame();
    await game.setOwnerDirective(OwnerDirective.defend);
    final restored = SaveGame.fromJson(game.save!.toJson());
    expect(restored.ownerDirectiveName, OwnerDirective.defend.name);

    final old =
        SaveGame.fromJson(game.save!.toJson()..remove('ownerDirectiveName'));
    expect(old.ownerDirectiveName, isNull);
  });
}
