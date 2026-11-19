import 'package:flutter/material.dart';

import '../models/player.dart';

/// 選手の表の並べ替え(どの表でも同じ操作にする)。
///
/// 見出しを押すとその列で並び、もう一度押すと逆になる。名前と位置は
/// 小さい順、数字の列は大きい順から始める(見たいのはたいてい上の方)。
class TableSort {
  const TableSort._();

  static bool startsAscending(String key) => key == 'name' || key == 'pos';

  static int _cmp(Player a, Player b, String key) => switch (key) {
        'name' => a.name.compareTo(b.name),
        'pos' => a.position.index.compareTo(b.position.index),
        'age' => a.age.compareTo(b.age),
        'ovr' => a.overall.compareTo(b.overall),
        'pot' => a.potential.compareTo(b.potential),
        'fat' => a.fatigue.compareTo(b.fatigue),
        'term' => a.contractEndYear.compareTo(b.contractEndYear),
        'wage' => a.wage.compareTo(b.wage),
        'fee' => a.marketValue.compareTo(b.marketValue),
        _ => 0,
      };

  /// [key]で並べた写し。[key]が null なら渡された順のまま。
  static List<Player> sort(List<Player> players, String? key, bool asc) {
    if (key == null) return players;
    final out = [...players]..sort((a, b) {
        final c = _cmp(a, b, key);
        return asc ? c : -c;
      });
    return out;
  }

  /// 見出しの文字に、並べ替えの向きの印を付ける。
  static String label(String text, String? key, String? current, bool asc) =>
      key != null && key == current ? '$text${asc ? '^' : 'v'}' : text;

  /// 押せる見出し。
  static Widget header({
    required Widget child,
    required String? key,
    required void Function(String) onSort,
  }) =>
      key == null
          ? child
          : InkWell(onTap: () => onSort(key), child: child);
}
