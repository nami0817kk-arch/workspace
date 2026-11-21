import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/models/owner_work.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

/// オーナーの仕事30件。資金と2つの期待を動かす手で、1シーズンに1回ずつ。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('仕事は33件(通常30+危機3)で、IDが重複せず、名前と説明が全部ある', () {
    expect(ownerWorks.length, 33);
    expect(ownerWorks.where((w) => !w.onlyInRed).length, 30);
    expect(ownerWorks.map((w) => w.id).toSet().length, 33);
    for (final w in ownerWorks) {
      expect(w.title, isNotEmpty, reason: w.id);
      expect(w.description, isNotEmpty, reason: w.id);
    }
  });

  test('ただで済む手は無い(何かを得て、何かを払う)', () {
    for (final w in ownerWorks) {
      final gains = [w.funds, w.supporters, w.shareholders].where((v) => v > 0);
      final losses = [w.funds, w.supporters, w.shareholders].where((v) => v < 0);
      // 資金を使って期待を買う手、または期待を削って資金を得る手のどちらか。
      // 命名権の打診のように、どれかが0でも、得と失いの両方がある。
      expect(gains.isNotEmpty, isTrue, reason: '${w.id} に得る物が無い');
      expect(losses.isNotEmpty || w.funds == 0, isTrue,
          reason: '${w.id} に払う物が無い');
    }
  });

  test('打つと資金と2つの期待に反映され、同じシーズンには二度打てない', () async {
    final game = GameState();
    await game.startNewGame('仕事FC');
    final save = game.save!;
    // 額は部の規模で掛かる(3部から始まる。2026-11-22)。
    save.budget = 500000;
    save.confidence = 50;
    save.shareholderExpectation = 50;
    final work = ownerWorks.firstWhere((w) => w.id == 'fan_thanks');

    expect(game.canDoOwnerWork(work), isTrue);
    expect(await game.doOwnerWork(work.id), isTrue);
    expect(save.budget, 500000 + game.scaledMoney(work.funds));
    expect(save.confidence, 50 + work.supporters);
    expect(save.shareholderExpectation, 50 + work.shareholders);

    expect(game.ownerWorkDoneThisSeason(work), isTrue);
    expect(game.canDoOwnerWork(work), isFalse);
    expect(await game.doOwnerWork(work.id), isFalse);
    expect(save.budget, 500000 + game.scaledMoney(work.funds),
        reason: '二度目は何も起きない');
  });

  test('資金が足りない手は打てない', () async {
    final game = GameState();
    await game.startNewGame('仕事FC');
    game.save!.budget = 10;
    final work = ownerWorks.firstWhere((w) => w.id == 'asia_tour');
    expect(game.canDoOwnerWork(work), isFalse);
    expect(await game.doOwnerWork(work.id), isFalse);
    expect(game.save!.budget, 10);
  });

  test('期待は0〜100に収まる', () async {
    final game = GameState();
    await game.startNewGame('仕事FC');
    final save = game.save!;
    save.budget = 500000;
    save.confidence = 98;
    await game.doOwnerWork('fan_thanks');
    expect(save.confidence, 100);
  });

  test('知らないIDは何も起こさない', () async {
    final game = GameState();
    await game.startNewGame('仕事FC');
    final before = game.save!.budget;
    expect(await game.doOwnerWork('nothing'), isFalse);
    expect(game.save!.budget, before);
  });

  test('今季やった記録は保存して読み戻せ、無い旧セーブは空', () async {
    final game = GameState();
    await game.startNewGame('仕事FC');
    game.save!.budget = 5000;
    await game.doOwnerWork('school_visit');

    final restored = SaveGame.fromJson(game.save!.toJson());
    expect(restored.ownerWorkDoneSeason['school_visit'],
        game.save!.league.season);

    final old = SaveGame.fromJson(
        game.save!.toJson()..remove('ownerWorkDoneSeason'));
    expect(old.ownerWorkDoneSeason, isEmpty);
  });
}
