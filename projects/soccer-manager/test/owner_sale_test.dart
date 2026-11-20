import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/models/owner_legacy.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 期待が尽きたら売却を迫られ、実績を殿堂に残して別のクラブを買い直す。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('期待が残っているあいだは、売却を迫られない', () async {
    final gs = GameState();
    await gs.startNewGame('テストFC');
    expect(gs.isSaleForced, isFalse);
    expect(gs.saleReason, isNull);
  });

  test('サポーターが尽きるとサポーター、株主が尽きると株主が理由になる', () async {
    final gs = GameState();
    await gs.startNewGame('テストFC');
    gs.save!.shareholderExpectation = 0;
    expect(gs.saleReason, SaleReason.shareholders);
    gs.save!.confidence = 0;
    expect(gs.saleReason, SaleReason.supporters);
  });

  test('買い直すと、実績が殿堂に残り、期待と資金が初期に戻る', () async {
    final gs = GameState();
    await gs.startNewGame('テストFC');
    gs.save!.shareholderExpectation = 0;
    gs.save!.budget = -5000;
    final oldId = gs.save!.userTeamId;

    final candidates = gs.buyoutCandidates;
    expect(candidates, isNotEmpty);
    expect(candidates.length, lessThanOrEqualTo(3));
    expect(candidates.any((t) => t.id == oldId), isFalse);

    final target = candidates.first;
    expect(await gs.buyClub(target.id), isTrue);

    final save = gs.save!;
    expect(save.userTeamId, target.id);
    expect(save.clubName, target.name);
    expect(save.confidence, 60);
    expect(save.shareholderExpectation, 60);
    expect(save.budget, greaterThan(0));
    expect(gs.isSaleForced, isFalse);
    expect(save.ownerLegacies, hasLength(1));
    expect(save.ownerLegacies.single.clubName, 'テストFC');
    expect(save.ownerLegacies.single.reason, SaleReason.shareholders);
  });

  test('売却を迫られていないときは買い直せない', () async {
    final gs = GameState();
    await gs.startNewGame('テストFC');
    final target = gs.buyoutCandidates.first;
    expect(await gs.buyClub(target.id), isFalse);
    expect(gs.save!.userTeamId, isNot(target.id));
  });

  test('殿堂は保存して読み戻せ、無い旧セーブは空で読める', () async {
    final gs = GameState();
    await gs.startNewGame('テストFC');
    gs.save!.ownerLegacies.add(const OwnerLegacy(
      clubName: 'A',
      seasons: 4,
      leagueTitles: 1,
      cupTitles: 2,
      bestRank: 1,
      reason: SaleReason.supporters,
    ));
    final json = gs.save!.toJson();
    final restored = SaveGame.fromJson(json);
    expect(restored.ownerLegacies.single.cupTitles, 2);
    expect(restored.ownerLegacies.single.reason, SaleReason.supporters);

    json.remove('ownerLegacies');
    expect(SaveGame.fromJson(json).ownerLegacies, isEmpty);
  });
}
