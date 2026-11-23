import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../engine/ending.dart';
import '../engine/game.dart';
import '../engine/life.dart';

/// 途中経過の保存。選択肢が出ていない区切りでだけ書く
/// （選択肢は関数を抱えているので保存できない）。
class SaveStore {
  static const _kSave = 'ranse.save.v1';
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

  static const _kDex = 'ranse.dex.v1';

  /// 今ある手書きの最期の鍵。図鑑はこれだけを数えて並べる
  /// （手書きの最期を入れる前の組み立ての最期や、消した最期の記録は読み飛ばす）。
  static final Set<String> _handKeys = {
    for (final d in kHandEndings) 'hand:${d.id}',
  };

  /// 図鑑（見た最期）。鍵 → 1件。
  Future<Map<String, DexEntry>> dex() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kDex);
    if (raw == null) return {};
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in j.entries)
          if (_handKeys.contains(e.key))
            e.key: DexEntry.fromJson(e.value as Map<String, dynamic>),
      };
    } catch (_) {
      return {};
    }
  }

  /// 終わった人生の結末を図鑑に記す。初めて見た最期なら true。
  Future<bool> recordEnding(Game g) async {
    // 保存を読み込むあいだに次の人生が始まることがあるので、先にこの人生の値を控える。
    final e = buildEnding(g);
    final name = g.l.name, age = g.age, year = g.year;
    final d = await dex();
    final old = d[e.key];
    final isNew = old == null;
    if (old != null) {
      old.count++;
    } else {
      d[e.key] = DexEntry(
        key: e.key,
        title: e.title,
        text: e.text,
        way: e.way,
        kind: e.kind,
        name: name,
        age: age,
        year: year,
      );
    }
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _kDex,
      jsonEncode({for (final x in d.values) x.key: x.toJson()}),
    );
    return isNew;
  }
}

/// 図鑑の1件。初めて見たときの称号・最期の文と、見た回数。
class DexEntry {
  DexEntry({
    required this.key,
    required this.title,
    required this.text,
    required this.way,
    required this.kind,
    required this.name,
    required this.age,
    required this.year,
    this.count = 1,
  });

  final String key, title, text, way, kind, name;
  final int age, year;
  int count;

  Map<String, dynamic> toJson() => {
    'k': key,
    't': title,
    'x': text,
    'w': way,
    'd': kind,
    'n': name,
    'a': age,
    'y': year,
    'c': count,
  };

  factory DexEntry.fromJson(Map<String, dynamic> j) => DexEntry(
    key: j['k'] as String,
    title: j['t'] as String,
    text: j['x'] as String,
    way: j['w'] as String,
    kind: j['d'] as String,
    name: j['n'] as String,
    age: j['a'] as int,
    year: j['y'] as int,
    count: j['c'] as int,
  );
}
