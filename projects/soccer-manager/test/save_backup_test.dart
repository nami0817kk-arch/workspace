import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/state/game_state.dart';

/// 壊れたセーブから控えで戻す仕組みの検査。
///
/// セーブが1つしか無いと、書き込みの途中で中断されたときに積み上げた
/// 何十シーズンがまとめて消える。データを失わないことは、遊びの面白さ以前の
/// 条件なので、壊れた場合の道筋をテストで固定しておく。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const slotKey = 'soccer_manager_save_slot_0';
  const backupKey = 'soccer_manager_save_backup';

  test('読み込めたセーブは控えとして残る', () async {
    final game = GameState();
    await game.startNewGame('控えFC');
    await game.flushPendingSave();

    // 読み込み直すと、その時点の内容が控えになる。
    final reloaded = GameState();
    await reloaded.init();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(backupKey), isNotNull, reason: '控えが作られていない');
    expect(prefs.getInt('soccer_manager_save_backup_slot'), 0);
    expect(reloaded.lastBackupRestoreNotice, isNull,
        reason: '壊れていないのに復元したことになっている');
  });

  test('セーブが壊れていたら控えから戻し、そのことを知らせる', () async {
    final game = GameState();
    await game.startNewGame('復元FC');
    await game.flushPendingSave();

    // 1度読み込んで控えを作る。
    await GameState().init();

    // 本体だけを壊す(書き込み途中で電源が落ちた状態に相当)。
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(slotKey, '{"clubName": "壊れ');

    final restored = GameState();
    await restored.init();

    expect(restored.hasSave, isTrue, reason: '控えがあるのに読み込めていない');
    expect(restored.save!.clubName, '復元FC');
    expect(restored.lastBackupRestoreNotice, isNotNull,
        reason: '黙って古い状態に戻している');
  });

  test('控えも無ければ、壊れたセーブは読み込まない', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(slotKey, 'これはJSONではない');

    final game = GameState();
    await game.init();

    expect(game.hasSave, isFalse);
    expect(game.lastBackupRestoreNotice, isNull);
  });

  test('別スロットの控えは使わない', () async {
    final game = GameState();
    await game.startNewGame('スロット0FC');
    await game.flushPendingSave();
    await GameState().init(); // スロット0の控えができる

    // スロット1のセーブが壊れていても、スロット0の控えで戻してはいけない。
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('soccer_manager_save_slot_1', '{壊れている');

    final other = GameState();
    await other.init();
    await other.loadSlot(1);

    expect(other.hasSave, isFalse, reason: '別のスロットの控えで戻してしまっている');
  });

  test('シーズンの切り替わりで控えを取り直す', () async {
    final game = GameState();
    await game.startNewGame('区切りFC');
    await game.flushPendingSave();
    await game.refreshSaveBackup();

    final prefs = await SharedPreferences.getInstance();
    final backup = jsonDecode(prefs.getString(backupKey)!)
        as Map<String, dynamic>;
    expect(backup['clubName'], '区切りFC');
  });
}
