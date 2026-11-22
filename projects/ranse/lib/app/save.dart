import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../engine/game.dart';
import '../engine/life.dart';

/// 途中経過の保存。選択肢が出ていない区切りでだけ書く
/// （選択肢は関数を抱えているので保存できない）。
class SaveStore {
  static const _kSave = 'ranse.save.v1';
  static const _kBest = 'ranse.best';

  Future<void> save(Game g) async {
    final life = g.life;
    if (life == null) return;
    // 終わった人生は、続きとしては残さない。
    final p = await SharedPreferences.getInstance();
    if (g.finished) {
      await p.remove(_kSave);
      return;
    }
    await p.setString(
      _kSave,
      jsonEncode({
        'life': life.toJson(),
        'world': g.fa.values.map((f) => f.toJson()).toList(),
      }),
    );
  }

  /// 続きがあれば Game に復元して true を返す。壊れていたら捨てて false。
  Future<bool> restoreInto(Game g) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kSave);
    if (raw == null) return false;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final life = Life.fromJson(j['life'] as Map<String, dynamic>);
      final world = {
        for (final e in (j['world'] as List))
          (e as Map<String, dynamic>)['n'] as String: Faction.fromJson(e),
      };
      g.restore(life, world);
      return true;
    } catch (_) {
      await p.remove(_kSave);
      return false;
    }
  }

  Future<bool> hasSave() async {
    final p = await SharedPreferences.getInstance();
    return p.containsKey(_kSave);
  }

  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kSave);
  }

  Future<int> best() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_kBest) ?? 0;
  }

  /// 最高点を更新したら true。
  Future<bool> submitScore(int score) async {
    final p = await SharedPreferences.getInstance();
    if (score > (p.getInt(_kBest) ?? 0)) {
      await p.setInt(_kBest, score);
      return true;
    }
    return false;
  }
}
