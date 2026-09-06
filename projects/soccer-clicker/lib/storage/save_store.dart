/// セーブの読み書き。
///
/// 実体（shared_preferences）をインターフェースの裏に隠してあるのは、
/// テストでプラグインを動かさずに済ませるため。テストは [InMemorySaveStore]
/// を使い、アプリは [PrefsSaveStore] を使う。
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../game/models.dart';

abstract class SaveStore {
  Future<GameState?> load();
  Future<void> save(GameState state);
  Future<void> clear();
}

/// テスト用。プロセス内にだけ保持する。
class InMemorySaveStore implements SaveStore {
  String? _raw;

  /// 壊れたセーブの復旧を検証するために、生の文字列を直接置く。
  void seedRaw(String raw) => _raw = raw;

  @override
  Future<GameState?> load() async =>
      _raw == null ? null : _decode(_raw!);

  @override
  Future<void> save(GameState state) async {
    _raw = jsonEncode(state.toJson());
  }

  @override
  Future<void> clear() async {
    _raw = null;
  }
}

class PrefsSaveStore implements SaveStore {
  static const _key = 'soccer_clicker.save.v1';

  @override
  Future<GameState?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    return _decode(raw);
  }

  @override
  Future<void> save(GameState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.toJson()));
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

/// 壊れたセーブでアプリが起動しなくなるのは最悪なので、
/// 読めなければ null を返して新規開始に倒す。
GameState? _decode(String raw) {
  try {
    return GameState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
}
