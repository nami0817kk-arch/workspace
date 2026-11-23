// セーブ(スロット・自動の控え・手で取った控え)の置き場。
//
// 以前は全部を SharedPreferences に入れていた。合わせると最大で約16MBになり、
// Android は1回書くたびに設定ファイル全体を書き直すので、節ごとに十数MBを
// 書いていた。iOS・Android ではスロットごとのファイルへ移す。
//
// Web にはファイルが無いので、これまでどおり SharedPreferences(localStorage)
// に置く。IndexedDB なら上限は広がるが、新しいパッケージと、localStorage
// からの移行がもう1つ要る。Web 版は試しに遊ぶ入口で長く続ける人が少ないため、
// 今回は見送った。
//
// GameState はここだけを呼ぶ。小さな数(今のスロット・控えのスロット)は
// これまでどおり SharedPreferences に置く(書いても小さいので重くない)。

import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// セーブの文字列を名前(キー)で読み書きする置き場。
abstract class SaveStore {
  /// 無ければ null。
  Future<String?> read(String key);
  Future<void> write(String key, String value);

  /// 無くても失敗しない。
  Future<void> remove(String key);

  /// テスト用: 置き場を差し替える(一時フォルダのファイルやメモリ)。
  @visibleForTesting
  static SaveStore? debugOverride;

  static Future<SaveStore>? _opened;

  /// テスト用: 開いた置き場を忘れる(次の [instance] で開き直す)。
  @visibleForTesting
  static void debugReset() {
    _opened = null;
    debugOverride = null;
  }

  /// 使う置き場。初めて呼んだときに開き、iOS・Android では移行も済ませる。
  ///
  /// [migrateKeys] は SharedPreferences からファイルへ移すキー。
  static Future<SaveStore> instance(List<String> migrateKeys) {
    final override = debugOverride;
    if (override != null) return Future.value(override);
    // テストでは開いた Future を覚えておかない。widget テストは1件ごとに
    // 別の偽の時間の中で動くので、前のテストで作った Future を次のテストで
    // 待つと、続きが前のテストの(もう進まない)時間に積まれて止まる
    // (CI で widget テストが10分で打ち切られた)。
    if (!kIsWeb && _underTest) return Future.value(PrefsSaveStore());
    return _opened ??= _open(migrateKeys);
  }

  static bool get _underTest {
    if (kIsWeb) return false;
    try {
      return io.Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  static Future<SaveStore> _open(List<String> migrateKeys) async {
    // Web はファイルが無い。テストは既定ではこれまでどおり SharedPreferences
    // (差し替えは [debugOverride])。
    if (kIsWeb || _underTest) return PrefsSaveStore();
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = io.Directory('${docs.path}${io.Platform.pathSeparator}saves');
      return await openWithFiles(FileSaveStore(dir), migrateKeys);
    } catch (_) {
      // 書類フォルダが取れない端末では、これまでどおりの置き場で続ける。
      return PrefsSaveStore();
    }
  }

  /// [files] を使う置き場を、SharedPreferences からの移行を済ませて返す。
  ///
  /// 移行を確かめ終えられなかったときは、SharedPreferences を優先して読む
  /// 置き場([PrefsFirstSaveStore])を返す(元は消していないので、そちらが正)。
  /// 次の起動でもう一度移行する。
  static Future<SaveStore> openWithFiles(
    FileSaveStore files,
    List<String> migrateKeys,
  ) async {
    final ok = await migratePrefsToFiles(files, migrateKeys);
    return ok ? files : PrefsFirstSaveStore(files);
  }
}

/// SharedPreferences に置く(Web と、テストの既定)。
class PrefsSaveStore implements SaveStore {
  // テストは1件ごとに SharedPreferences を作り直すので、毎回取り直す。
  @override
  Future<String?> read(String key) async =>
      (await SharedPreferences.getInstance()).getString(key);

  @override
  Future<void> write(String key, String value) async {
    final ok = await (await SharedPreferences.getInstance()).setString(
      key,
      value,
    );
    // localStorage の上限を超えると false が返る(例外ではない)。
    if (!ok) throw StateError('save write failed: $key');
  }

  @override
  Future<void> remove(String key) async {
    await (await SharedPreferences.getInstance()).remove(key);
  }
}

/// フォルダの中に、キーごとに1つのファイルで置く(iOS・Android)。
///
/// 書くときは一時ファイルに書き切ってから名前を付け替える。書いている途中で
/// アプリが止まっても、元のファイルは前の内容のまま残る(付け替えは一度に
/// 起きる)。
///
/// 同じキーへの読み書きは、呼ばれた順に1つずつ行う。SharedPreferences は
/// 呼んだ時点で中身が替わったので、後から呼んだ書き込みが必ず勝っていた。
/// ファイルは書き終わるまで時間がかかるので、並べないと先に呼んだ古い内容が
/// 後から付け替わることがある(書き出しの順番札の前提が崩れる)。
class FileSaveStore implements SaveStore {
  FileSaveStore(this.dir);

  final io.Directory dir;

  final Map<String, Future<void>> _tails = {};

  /// テスト用: 一時ファイルを書き終えて、付け替える前に呼ぶ。投げると
  /// 「書きかけで止まった」ことになる。
  @visibleForTesting
  Future<void> Function(String key)? debugBeforeRename;

  io.File fileFor(String key) =>
      io.File('${dir.path}${io.Platform.pathSeparator}$key.json');

  io.File _tempFor(String key) =>
      io.File('${dir.path}${io.Platform.pathSeparator}$key.json.tmp');

  Future<T> _serial<T>(String key, Future<T> Function() op) {
    final prev = _tails[key] ?? Future<void>.value();
    final result = prev.then((_) => op());
    _tails[key] = result.then((_) {}, onError: (_) {});
    return result;
  }

  @override
  Future<String?> read(String key) => _serial(key, () async {
        final f = fileFor(key);
        if (!await f.exists()) return null;
        final bytes = await f.readAsBytes();
        // 壊れた中身でも例外にせず返す(読めなければ控えから戻す側で扱う)。
        return utf8.decode(bytes, allowMalformed: true);
      });

  @override
  Future<void> write(String key, String value) => _serial(key, () async {
        if (!await dir.exists()) await dir.create(recursive: true);
        final tmp = _tempFor(key);
        await tmp.writeAsString(value, flush: true);
        await debugBeforeRename?.call(key);
        await tmp.rename(fileFor(key).path);
      });

  @override
  Future<void> remove(String key) => _serial(key, () async {
        for (final f in [fileFor(key), _tempFor(key)]) {
          if (await f.exists()) await f.delete();
        }
      });
}

/// 移行を確かめ終えられなかった起動で使う置き場。
///
/// SharedPreferences にあるキーはそちらが正(移行は元を消すまで済んでいない)。
/// 無いキーは移行済みなのでファイルから読む。書くのは SharedPreferences
/// (次の起動の移行でファイルへ移る)。消すときは両方から消す(ファイルだけ
/// 残すと、次の起動で消したセーブが戻る)。
class PrefsFirstSaveStore implements SaveStore {
  PrefsFirstSaveStore(this.files);

  final FileSaveStore files;
  final PrefsSaveStore _prefs = PrefsSaveStore();

  @override
  Future<String?> read(String key) async =>
      await _prefs.read(key) ?? await files.read(key);

  @override
  Future<void> write(String key, String value) => _prefs.write(key, value);

  @override
  Future<void> remove(String key) async {
    await _prefs.remove(key);
    await files.remove(key);
  }
}

/// SharedPreferences にあるセーブを [files] へ移す。移し終えて元を消せたら true。
///
/// 1. 全部のキーをファイルへ書き、読み直して中身が一致するか確かめる。
/// 2. 全部一致したときだけ、元のキーを消す。
///
/// どこで止まっても進みは消えない。1の途中なら元が全部残っている(次の起動で
/// 書き直す)。2の途中なら、消したキーはファイルに、残ったキーは両方にある
/// (中身は同じ)。二度目は移すものが無いので何もしない。
Future<bool> migratePrefsToFiles(
  FileSaveStore files,
  List<String> keys,
) async {
  final SharedPreferences prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (_) {
    return false;
  }
  final pending = <String>[
    for (final k in keys)
      if (prefs.get(k) is String) k,
  ];
  if (pending.isEmpty) return true;

  for (final k in pending) {
    final value = prefs.getString(k)!;
    try {
      await files.write(k, value);
      final back = await files.read(k);
      if (back != value) return false;
    } catch (_) {
      return false;
    }
  }
  try {
    for (final k in pending) {
      await prefs.remove(k);
    }
  } catch (_) {
    return false;
  }
  return true;
}
