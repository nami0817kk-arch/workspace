import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/models/matchday_promo.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 試合日のイベント: 次の節だけ、観客収入とサポーターの期待を動かす。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<GameState> newGame() async {
    final game = GameState();
    await game.startNewGame('イベントFC');
    return game;
  }

  test('4種類あり、IDが重複せず、名前と説明が全部ある', () {
    // 2026-11-25 に8種類から減らし、「続ける」の設定にした。
    expect(matchdayPromos.length, 4);
    expect(matchdayPromos.map((p) => p.id).toSet().length, 4);
    for (final p in matchdayPromos) {
      expect(p.title, isNotEmpty, reason: p.id);
      expect(p.description, isNotEmpty, reason: p.id);
      expect(p.gateMultiplier, inInclusiveRange(0.8, 1.3), reason: p.id);
    }
  });

  test('決めると費用が引かれ、取り消すと全額戻る', () async {
    final game = await newGame();
    final save = game.save!;
    save.budget = 500000;

    // 費用は部の規模で掛かる(3部から始まる。2026-11-22)。
    expect(await game.setMatchdayPromo('light_up'), isTrue);
    expect(save.budget, 500000 - game.scaledMoney(150));
    expect(game.activeMatchdayPromo?.id, 'light_up');

    expect(await game.cancelMatchdayPromo(), isTrue);
    expect(save.budget, 500000);
    expect(game.activeMatchdayPromo, isNull);
  });

  test('1節に1つだけで、決めている間は別のを決められない', () async {
    final game = await newGame();
    game.save!.budget = 5000;
    expect(await game.setMatchdayPromo('family_day'), isTrue);
    expect(await game.setMatchdayPromo('light_up'), isFalse);
    expect(game.activeMatchdayPromo?.id, 'family_day');
  });

  test('資金が足りない・知らないIDは決められない', () async {
    final game = await newGame();
    game.save!.budget = 10;
    expect(await game.setMatchdayPromo('light_up'), isFalse);
    expect(await game.setMatchdayPromo('nothing'), isFalse);
    expect(game.save!.budget, 10);
    expect(game.activeMatchdayPromo, isNull);
  });

  test('割引デーは費用が0で、資金が0でも決められる', () async {
    final game = await newGame();
    game.save!.budget = 0;
    expect(await game.setMatchdayPromo('discount_day'), isTrue);
  });

  test('観客収入は、イベントを決めた節だけ変わる', () async {
    final game = await newGame();
    game.save!.budget = 5000;
    final id = game.save!.userTeamId;
    final base = game.weeklyIncomeParts(id).gate;

    await game.setMatchdayPromo('light_up');
    final withPromo = game.weeklyIncomeParts(id).gate;
    expect(withPromo, greaterThan(base));

    game.debugConsumeMatchdayPromo();
    // 倍率は外れる。サポーターの期待が+1動くぶん、観客数がわずかに動くので、
    // 完全一致ではなく近さで見る(イベントの+15%よりずっと小さい)。
    expect(game.weeklyIncomeParts(id).gate, closeTo(base, base * 0.03),
        reason: '節を終えたら元に戻る');
  });

  test('節を終えると、サポーターと株主の期待に反映されて使い切る', () async {
    final game = await newGame();
    final save = game.save!;
    save.budget = 5000;
    save.confidence = 50;
    save.shareholderExpectation = 50;
    await game.setMatchdayPromo('charity_collect');

    game.debugConsumeMatchdayPromo();

    expect(save.confidence, 52);
    expect(save.shareholderExpectation, 51);
    expect(game.activeMatchdayPromo, isNull);
  });

  test('決めたイベントは保存して読み戻せ、無い旧セーブは何も無い', () async {
    final game = await newGame();
    game.save!.budget = 5000;
    await game.setMatchdayPromo('family_day');
    final restored = SaveGame.fromJson(game.save!.toJson());
    expect(restored.matchdayPromoId, 'family_day');

    final old =
        SaveGame.fromJson(game.save!.toJson()..remove('matchdayPromoId'));
    expect(old.matchdayPromoId, isNull);
  });
  test('「続ける」に決めると、節を終えるたびに同じイベントが決まる', () async {
    // 節ごとに選び直す手間を無くした(2026-11-25)。
    final game = await newGame();
    final save = game.save!;
    save.budget = 500000;
    expect(await game.setMatchdayPromoKeep('family_day'), isTrue);
    expect(game.activeMatchdayPromo?.id, 'family_day');
    expect(save.budget, 500000 - game.scaledMoney(80));

    game.debugConsumeMatchdayPromo();
    expect(game.activeMatchdayPromo?.id, 'family_day', reason: '次の節も続ける');
    expect(save.budget, 500000 - 2 * game.scaledMoney(80));

    // 別のものに替えると、決めてあった次の節のぶんは費用が戻る。
    expect(await game.setMatchdayPromoKeep('light_up'), isTrue);
    expect(game.activeMatchdayPromo?.id, 'light_up');
    expect(save.budget,
        500000 - 2 * game.scaledMoney(80) + game.scaledMoney(80) - game.scaledMoney(150));

    // やめると、決めてある次の節のぶんは残り、その次からは決まらない。
    expect(await game.setMatchdayPromoKeep(null), isTrue);
    game.debugConsumeMatchdayPromo();
    expect(game.activeMatchdayPromo, isNull);
  });

  test('「続ける」でも、資金が足りない節は打たず、設定は残る', () async {
    final game = await newGame();
    final save = game.save!;
    save.budget = 0;
    expect(await game.setMatchdayPromoKeep('light_up'), isTrue);
    expect(game.activeMatchdayPromo, isNull);
    expect(game.matchdayPromoKeep?.id, 'light_up');
    expect(save.budget, 0);
    save.budget = 500000;
    game.debugConsumeMatchdayPromo();
    expect(game.activeMatchdayPromo?.id, 'light_up', reason: '資金が戻れば打つ');
  });

  test('「続ける」の設定は保存して読み戻せ、無い旧セーブは何も無い', () async {
    final game = await newGame();
    game.save!.budget = 5000;
    await game.setMatchdayPromoKeep('discount_day');
    final restored = SaveGame.fromJson(game.save!.toJson());
    expect(restored.matchdayPromoKeepId, 'discount_day');
    final old = SaveGame.fromJson(
        game.save!.toJson()..remove('matchdayPromoKeepId'));
    expect(old.matchdayPromoKeepId, isNull);
  });
}
