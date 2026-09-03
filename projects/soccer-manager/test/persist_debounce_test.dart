import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/state/game_state.dart';

/// 保存をまとめたことで、保存自体が壊れていないかを固定するテスト。
///
/// セーブは1MBを超える(大半は他ディビジョンの選手データ)。設定を1つ変える
/// たびに丸ごとJSON化していたため1回あたり約26msかかり、スライダーを端から端へ
/// 動かすと1.3秒ぶんの処理が走っていた。60fpsの1フレーム(16.7ms)を超えるので
/// 目に見えて引っかかる。保存をまとめて解消したが、まとめた結果として
/// 「保存されない」ことがあってはならない。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<String?> storedSlot0() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('soccer_manager_save_slot_0');
  }

  test('連続した設定変更は、止まってからまとめて保存される', () async {
    final game = GameState();
    await game.startNewGame('テストFC');

    for (var i = 0; i < 30; i++) {
      game.setPressing(30 + (i % 40));
    }
    game.setPressing(77);

    // まだ書き出されていなくてよい(まとめている最中)。
    // 待てば必ず書き出される。
    await Future<void>.delayed(
        GameState.persistDebounce + const Duration(milliseconds: 300));

    final raw = await storedSlot0();
    expect(raw, isNotNull, reason: '保存されていない');
    expect(raw, contains('"pressing":77'),
        reason: '最後の値が保存されていない');
  });

  test('区切りになる操作は待たずに保存される', () async {
    final game = GameState();
    // startNewGame は即時保存。待たずに読めること。
    await game.startNewGame('テストFC');
    expect(await storedSlot0(), isNotNull,
        reason: '新規作成が即時に保存されていない');
  });

  test('flushPendingSave で、待たずに書き切れる', () async {
    final game = GameState();
    await game.startNewGame('テストFC');

    game.setPressing(64);
    // アプリが背面に回るときに相当する。
    await game.flushPendingSave();

    final raw = await storedSlot0();
    expect(raw, contains('"pressing":64'),
        reason: 'flush しても直近の変更が書き出されていない');
  });

  test('節を進めると即時に保存される', () async {
    final game = GameState();
    await game.startNewGame('テストFC');
    final before = await storedSlot0();

    await game.playNextMatchdayQuickSim();

    final after = await storedSlot0();
    expect(after, isNot(before),
        reason: '節の進行が待たずに保存されていない');
  });
}
