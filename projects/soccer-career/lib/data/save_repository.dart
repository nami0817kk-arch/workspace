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

  /// 引き継ぎコードの頭。形式を変えたときに、古いコードを弾くために付ける。
  static const String codePrefix = 'SC1:';

  /// 今のキャリアを1本の文字列にする。
  ///
  /// セーブは端末ごとに独立しているので、機種を変えたりPCとスマホを
  /// 行き来すると続きから遊べない。クラウドに置く代わりに、
  /// 自分でコピーして持ち運べる形にしておく。
  static String encode(CareerState state) =>
      codePrefix + base64Url.encode(utf8.encode(jsonEncode(state.toJson())));

  /// 引き継ぎコードを読む。読めなければ null。
  ///
  /// **読めないコードで今のキャリアを消さない。** 復元できたときだけ
  /// 上書きする（呼び出し側の責任にすると、いつか消える）。
  static CareerState? decode(String code) {
    final trimmed = code.trim();
    if (!trimmed.startsWith(codePrefix)) return null;
    try {
      final json = utf8.decode(base64Url.decode(trimmed.substring(codePrefix.length)));
      return CareerState.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
