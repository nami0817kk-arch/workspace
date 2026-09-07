import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/career.dart';

/// キャリアの保存と読み込み。
///
/// 保存は端末ごとに独立していて、クラウド同期はしない。
class SaveRepository {
  static const String _key = 'career_v1';

  Future<CareerState?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return CareerState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // 保存形式を変えたあとの古いデータなど。読めないものは無かったことにする。
      // ここで例外を投げると、一度壊れたユーザーがアプリを開けなくなる。
      await prefs.remove(_key);
      return null;
    }
  }

  Future<void> save(CareerState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.toJson()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
