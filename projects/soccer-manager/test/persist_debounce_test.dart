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

  test('スロットを切り替えても、変更は元のスロットに書き込まれる', () async {
    final game = GameState();
    await game.init();

    await game.loadSlot(0);
    await game.startNewGame('スロット0FC');
    // 保存を予約した直後にスロットを移る。予約が切り替え後に発火すると、
    // スロット1へ書き込まれるか、この変更が失われる。
    game.setPressing(71);
    await game.loadSlot(1);
    await game.startNewGame('スロット1FC');

    final slots = await game.listSaveSlots();
    expect(slots[0].clubName, 'スロット0FC',
        reason: 'スロット0が別の内容で上書きされている');
    expect(slots[1].clubName, 'スロット1FC',
        reason: 'スロット1が別の内容で上書きされている');

    await game.loadSlot(0);
    expect(game.save!.clubName, 'スロット0FC');
    expect(game.userTeam.pressing, 71,
        reason: '切り替え前の変更が書き出されずに失われている');
  });

  test('古いセーブの予約が、後から作ったセーブを上書きしない', () async {
    // CI で実際に起きた形。前のテストが残した予約が、次のテストの
    // セーブを上書きして「期待 スロット0FC / 実際 テストFC」になった。
    // 保存が即時だった頃は、操作が終わった時点で書き終わっていたので
    // 起きなかった。まとめるようにしたことで生まれた壊れ方。
    final old = GameState();
    await old.startNewGame('古いFC');
    old.setPressing(40); // 予約だけ残して放置する

    final fresh = GameState();
    await fresh.init();
    await fresh.loadSlot(0);
    await fresh.startNewGame('新しいFC');

    // 古い予約が発火する時間まで待つ。
    await Future<void>.delayed(
        GameState.persistDebounce + const Duration(milliseconds: 300));

    final slots = await fresh.listSaveSlots();
    expect(slots[0].clubName, '新しいFC',
        reason: '古いインスタンスの予約が、後から作ったセーブを上書きしている');
  });
}
