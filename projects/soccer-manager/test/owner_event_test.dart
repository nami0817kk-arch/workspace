import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/models/owner_event.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 事件は年に3回、判断を迫る。どの選択も、2つの期待のどちらかを傷つける。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('事件が起きる節は、12節ごとの6・18・30節', () {
    expect(GameStateFinance.isOwnerEventMatchday(6), isTrue);
    expect(GameStateFinance.isOwnerEventMatchday(18), isTrue);
    expect(GameStateFinance.isOwnerEventMatchday(30), isTrue);
    expect(GameStateFinance.isOwnerEventMatchday(1), isFalse);
    expect(GameStateFinance.isOwnerEventMatchday(12), isFalse);
    expect(GameStateFinance.isOwnerEventMatchday(0), isFalse);
  });

  test('どの事件の選択肢も、期待のどちらかを下げる(ただで済む答えは無い)', () {
    for (final kind in OwnerEventKind.values) {
      expect(kind.options, hasLength(2), reason: '$kind');
      for (final o in kind.options) {
        expect(o.supportersDelta < 0 || o.shareholdersDelta < 0, isTrue,
            reason: '$kind / ${o.label}');
      }
    }
  });

  test('その節で事件が積まれ、答えを待っているあいだは新しく積まれない', () async {
    final gs = GameState();
    await gs.startNewGame('テストFC');
    gs.debugRaiseOwnerEvent(5);
    expect(gs.pendingOwnerEvent, isNull);
    gs.debugRaiseOwnerEvent(6);
    final first = gs.pendingOwnerEvent;
    expect(first, isNotNull);
    gs.debugRaiseOwnerEvent(18);
    expect(gs.pendingOwnerEvent, first);
  });

  test('答えると期待と資金に反映され、事件は消える', () async {
    final gs = GameState();
    await gs.startNewGame('テストFC');
    final save = gs.save!;
    save.pendingOwnerEvent = OwnerEventKind.transferDemand;
    save.confidence = 50;
    save.shareholderExpectation = 50;
    final funds = save.budget;

    // 2つ目: 売却を認める(サポーター-6・株主+4・資金+800)
    expect(await gs.resolveOwnerEvent(1), isTrue);
    expect(save.confidence, 44);
    expect(save.shareholderExpectation, 54);
    expect(save.budget, funds + 800);
    expect(gs.pendingOwnerEvent, isNull);
  });

  test('期待は0〜100に収まり、事件が無いときや範囲外の答えは何もしない', () async {
    final gs = GameState();
    await gs.startNewGame('テストFC');
    expect(await gs.resolveOwnerEvent(0), isFalse);

    gs.save!.pendingOwnerEvent = OwnerEventKind.stadiumAging;
    expect(await gs.resolveOwnerEvent(5), isFalse);
    expect(gs.pendingOwnerEvent, OwnerEventKind.stadiumAging);

    gs.save!.confidence = 2;
    expect(await gs.resolveOwnerEvent(1), isTrue); // サポーター-4
    expect(gs.save!.confidence, 0);
  });

  test('判断待ちの事件は保存して読み戻せ、無い旧セーブは事件なしで読める', () async {
    final gs = GameState();
    await gs.startNewGame('テストFC');
    gs.save!.pendingOwnerEvent = OwnerEventKind.sponsorExit;
    final json = gs.save!.toJson();
    expect(SaveGame.fromJson(json).pendingOwnerEvent, OwnerEventKind.sponsorExit);
    json.remove('pendingOwnerEvent');
    expect(SaveGame.fromJson(json).pendingOwnerEvent, isNull);
  });
}
