import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/state/save_store.dart';

/// セーブの置き場を SharedPreferences からファイルへ移したことの検査。
///
/// 移行で利用者の進みが消えるのが一番まずい。成功・途中で止まった・
/// 読み直しが一致しない・二度目の起動のどれでも、元のセーブが読めることを
/// 固定する。あわせて、書きかけで止まっても元のファイルが残ること、
/// Web(SharedPreferences のまま)の経路も見る。

const _slot0 = 'soccer_manager_save_slot_0';
const _slot1 = 'soccer_manager_save_slot_1';
const _backup = 'soccer_manager_save_backup';
const _backupSlot = 'soccer_manager_save_backup_slot';
const _point0 = 'soccer_manager_restore_point_0';
const _current = 'soccer_manager_current_slot';

/// 書き込みの何件目かで止まる(アプリが落ちたのと同じ)。
class _CrashingStore extends FileSaveStore {
  _CrashingStore(super.dir, this.crashOnWrite);
  final int crashOnWrite;
  int writes = 0;

  @override
  Future<void> write(String key, String value) async {
    writes++;
    if (writes == crashOnWrite) throw const FileSystemException('止まった');
    await super.write(key, value);
  }
}

/// 読み直すと中身が違う(書き込みが化けた端末)。
class _GarblingStore extends FileSaveStore {
  _GarblingStore(super.dir, this.garbleKey);
  final String garbleKey;
  bool garble = true;

  @override
  Future<String?> read(String key) async {
    final v = await super.read(key);
    if (garble && key == garbleKey && v != null) return '${v}x';
    return v;
  }
}

void main() {
  late Directory tmp;
  late Directory dir;
  late String saveJson;
  late String saveJson2;

  setUpAll(() async {
    // 本物のセーブの中身を1度だけ作る(1件ごとに作ると遅い)。
    SharedPreferences.setMockInitialValues({});
    SaveStore.debugReset();
    final game = GameState();
    await game.startNewGame('移行FC');
    saveJson = game.exportSaveJson()!;
    await game.startNewGame('二番FC');
    saveJson2 = game.exportSaveJson()!;
    game.dispose();
  });

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('sm_save_store_');
    dir = Directory('${tmp.path}${Platform.pathSeparator}saves');
    SaveStore.debugReset();
  });

  tearDown(() async {
    SaveStore.debugReset();
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  String pointJson(String save) => jsonEncode({
        'takenAt': DateTime(2026, 11, 23).toIso8601String(),
        'clubName': '移行FC',
        'season': 1,
        'matchday': 1,
        'save': jsonDecode(save),
      });

  Map<String, Object> oldPrefs() => {
        _slot0: saveJson,
        _slot1: saveJson2,
        _backup: saveJson,
        _backupSlot: 0,
        _point0: pointJson(saveJson),
        _current: 0,
      };

  group('移行', () {
    test('成功: ファイルへ写し、一致を確かめてから元のキーを消す', () async {
      SharedPreferences.setMockInitialValues(oldPrefs());
      final files = FileSaveStore(dir);
      final store = await SaveStore.openWithFiles(
        files,
        GameState.saveStoreKeys,
      );
      expect(store, same(files), reason: '移行に成功したのにファイルを使っていない');

      final prefs = await SharedPreferences.getInstance();
      for (final k in [_slot0, _slot1, _backup, _point0]) {
        expect(prefs.containsKey(k), isFalse, reason: '$k が元に残っている');
      }
      // 小さな数は SharedPreferences のまま。
      expect(prefs.getInt(_backupSlot), 0);
      expect(prefs.getInt(_current), 0);

      expect(await files.read(_slot0), saveJson);
      expect(await files.read(_slot1), saveJson2);
      expect(await files.read(_backup), saveJson);
      expect(await files.read(_point0), pointJson(saveJson));
      expect(File('${dir.path}/$_slot0.json').existsSync(), isTrue);

      // 移した後のセーブで遊べる(スロット一覧・読み込み・控え)。
      SaveStore.debugOverride = store;
      final game = GameState();
      await game.init();
      expect(game.save?.clubName, '移行FC');
      final slots = await game.listSaveSlots();
      expect(slots[0].clubName, '移行FC');
      expect(slots[1].clubName, '二番FC');
      expect(slots[2].hasSave, isFalse);
      expect((await game.restorePointInfo())?.clubName, '移行FC');
      game.dispose();
    });

    test('二度目は何もしない(中身はそのまま)', () async {
      SharedPreferences.setMockInitialValues(oldPrefs());
      final files = FileSaveStore(dir);
      await SaveStore.openWithFiles(files, GameState.saveStoreKeys);
      // 移した後に遊んで書いた内容が、二度目の移行で戻されない。
      await files.write(_slot0, saveJson2);

      final again = await SaveStore.openWithFiles(
        FileSaveStore(dir),
        GameState.saveStoreKeys,
      );
      expect(again, isA<FileSaveStore>());
      expect(await again.read(_slot0), saveJson2);
      expect(await again.read(_slot1), saveJson2);
      expect(await again.read(_backup), saveJson);
    });

    test('写している途中で止まったら、元は残り、次の起動で移し直す', () async {
      SharedPreferences.setMockInitialValues(oldPrefs());
      final crashing = _CrashingStore(dir, 2);
      final store = await SaveStore.openWithFiles(
        crashing,
        GameState.saveStoreKeys,
      );
      expect(store, isA<PrefsFirstSaveStore>());
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_slot0), saveJson, reason: '止まったのに元を消した');
      expect(prefs.getString(_slot1), saveJson2);
      expect(prefs.getString(_point0), isNotNull);

      // この起動でも元のセーブで遊べる。
      SaveStore.debugOverride = store;
      final game = GameState();
      await game.init();
      expect(game.save?.clubName, '移行FC');
      game.dispose();
      SaveStore.debugReset();

      // 次の起動で移し直せる。
      final next = await SaveStore.openWithFiles(
        FileSaveStore(dir),
        GameState.saveStoreKeys,
      );
      expect(next, isA<FileSaveStore>());
      expect(await next.read(_slot0), saveJson);
      expect(await next.read(_slot1), saveJson2);
      expect(prefs.containsKey(_slot0), isFalse);
    });

    test('元を消している途中で止まっても、残り・消した分の両方が読める', () async {
      // 消し終えたキーはファイルだけに、まだのキーは両方にある状態。
      SharedPreferences.setMockInitialValues({_slot1: saveJson2, _current: 0});
      final files = FileSaveStore(dir);
      await files.write(_slot0, saveJson);
      await files.write(_slot1, saveJson2);

      final store = await SaveStore.openWithFiles(
        FileSaveStore(dir),
        GameState.saveStoreKeys,
      );
      expect(store, isA<FileSaveStore>());
      expect(await store.read(_slot0), saveJson);
      expect(await store.read(_slot1), saveJson2);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(_slot1), isFalse);
    });

    test('読み直しが一致しなければ元を消さず、元を使い続ける', () async {
      SharedPreferences.setMockInitialValues(oldPrefs());
      final garbling = _GarblingStore(dir, _slot0);
      final store = await SaveStore.openWithFiles(
        garbling,
        GameState.saveStoreKeys,
      );
      expect(store, isA<PrefsFirstSaveStore>());
      final prefs = await SharedPreferences.getInstance();
      for (final k in [_slot0, _slot1, _backup, _point0]) {
        expect(prefs.containsKey(k), isTrue, reason: '一致しないのに $k を消した');
      }
      // 化けたファイルではなく元を読む。
      expect(await store.read(_slot0), saveJson);

      SaveStore.debugOverride = store;
      final game = GameState();
      await game.init();
      expect(game.save?.clubName, '移行FC');
      expect(game.lastBackupRestoreNotice, isNull);

      // この起動で書いた内容は元へ入り、次の移行でファイルへ移る。
      await game.startNewGame('後から作ったFC');
      await game.flushPendingSave();
      expect(prefs.getString(_slot0), contains('後から作ったFC'));

      // 消したスロットは、ファイル側からも消える(次の起動で戻らない)。
      await game.deleteSlot(1);
      expect(prefs.containsKey(_slot1), isFalse);
      expect(await garbling.read(_slot1), isNull, reason: '消したスロットがファイルに残る');
      game.dispose();
      SaveStore.debugReset();

      final next = await SaveStore.openWithFiles(
        FileSaveStore(dir),
        GameState.saveStoreKeys,
      );
      expect(next, isA<FileSaveStore>());
      expect(await next.read(_slot0), contains('後から作ったFC'));
      expect(await next.read(_slot1), isNull);
    });

    test('旧バージョンの単一セーブも移り、スロット0になる', () async {
      SharedPreferences.setMockInitialValues({
        'soccer_manager_save_v1': saveJson,
      });
      final store = await SaveStore.openWithFiles(
        FileSaveStore(dir),
        GameState.saveStoreKeys,
      );
      SaveStore.debugOverride = store;
      final game = GameState();
      await game.init();
      expect(game.save?.clubName, '移行FC');
      expect(await store.read(_slot0), saveJson);
      expect(await store.read('soccer_manager_save_v1'), isNull);
      game.dispose();
    });
  });

  group('ファイルへの書き込み', () {
    test('書きかけで止まっても、前の内容が残る', () async {
      final files = FileSaveStore(dir);
      await files.write(_slot0, saveJson);
      files.debugBeforeRename =
          (_) async => throw const FileSystemException('止まった');
      await expectLater(files.write(_slot0, saveJson2), throwsA(anything));
      expect(await files.read(_slot0), saveJson, reason: '書きかけで元が壊れた');

      // 一時ファイルが残っていても次の書き込みは通る。
      files.debugBeforeRename = null;
      await files.write(_slot0, saveJson2);
      expect(await files.read(_slot0), saveJson2);
      await files.remove(_slot0);
      expect(await files.read(_slot0), isNull);
      expect(dir.listSync(), isEmpty, reason: '消した後に一時ファイルが残る');
    });

    test('待たずに続けて書いても、後から呼んだ内容が残る', () async {
      final files = FileSaveStore(dir);
      final gate = Completer<void>();
      var first = true;
      files.debugBeforeRename = (_) async {
        // 先に呼んだ書き込みを遅らせる。並べていなければ後の書き込みが
        // 先に終わり、先の古い内容が後から付け替わる。
        if (first) {
          first = false;
          await gate.future;
        }
      };
      final a = files.write(_slot0, saveJson);
      final b = files.write(_slot0, saveJson2);
      final r = files.read(_slot0);
      gate.complete();
      await Future.wait([a, b]);
      expect(await r, saveJson2);
      expect(await files.read(_slot0), saveJson2);
    });

    test('壊れた本体から控えで戻す・消す・控えに戻す(ファイルの置き場)', () async {
      SharedPreferences.setMockInitialValues({});
      final files = FileSaveStore(dir);
      SaveStore.debugOverride = files;

      final game = GameState();
      await game.startNewGame('ファイルFC');
      await game.flushPendingSave();
      expect(await files.read(_slot0), contains('ファイルFC'));
      expect(await game.saveRestorePoint(), isTrue);
      game.dispose();

      // 読み直すと控えができる。
      final reloaded = GameState();
      await reloaded.init();
      expect(reloaded.save?.clubName, 'ファイルFC');
      expect(await files.read(_backup), isNotNull);
      reloaded.dispose();

      // 本体が書きかけで壊れていても、一覧では続きから・読むと控えから戻る。
      await files.fileFor(_slot0).writeAsString('{壊れている');
      final broken = GameState();
      final slots = await broken.listSaveSlots();
      expect(slots[0].clubName, 'ファイルFC');
      await broken.init();
      expect(broken.save?.clubName, 'ファイルFC');
      expect(broken.lastBackupRestoreNotice, isNotNull);
      expect(await files.read(_slot0), contains('ファイルFC'),
          reason: '本体へ書き戻していない');

      expect(await broken.restoreFromRestorePoint(), isTrue);
      expect(broken.save?.clubName, 'ファイルFC');

      await broken.deleteSlot(0);
      expect(await files.read(_slot0), isNull);
      expect(await files.read(_point0), isNull);
      expect(await files.read(_backup), isNull);
      broken.dispose();
    });
  });

  group('Web の経路(SharedPreferences のまま)', () {
    test('読み書き・消すが SharedPreferences に入る', () async {
      SharedPreferences.setMockInitialValues({});
      final store = PrefsSaveStore();
      await store.write(_slot0, saveJson);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_slot0), saveJson);
      expect(await store.read(_slot0), saveJson);
      await store.remove(_slot0);
      expect(prefs.containsKey(_slot0), isFalse);
      expect(await store.read(_slot0), isNull);
    });

    test('差し替えていなければ SharedPreferences を使い、移行もしない', () async {
      SharedPreferences.setMockInitialValues({_slot0: saveJson});
      final store = await SaveStore.instance(GameState.saveStoreKeys);
      expect(store, isA<PrefsSaveStore>());
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_slot0), saveJson);

      final game = GameState();
      await game.init();
      expect(game.save?.clubName, '移行FC');
      game.dispose();
    });
  });
}
