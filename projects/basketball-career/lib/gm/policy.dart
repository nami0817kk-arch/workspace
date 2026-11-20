import 'league.dart';
import 'player.dart';

/// チームの方針の軸(5つ)。どれも3択で、真ん中(1)は「ふつう」(強さを変えない)。
enum PolicyAxis {
  pace('展開の速さ', ['じっくり', 'ふつう', '速攻'], [Attr.inside, Attr.passing], [Attr.athletic, Attr.outside]),
  focus('攻めの重点', ['外のシュート', 'バランス', '中の得点'], [Attr.outside], [Attr.inside]),
  defense('守り方', ['中を固める', 'ふつう', '前から当たる'], [Attr.rebound, Attr.defense], [Attr.athletic, Attr.defense]),
  passing('ボールの回し方', ['エース任せ', 'ふつう', 'パス回し'], [Attr.outside, Attr.inside], [Attr.passing]),
  depth('起用の幅', ['主力集中', 'ふつう', '広く使う'], [], []);

  const PolicyAxis(this.label, this.options, this.low, this.high);
  final String label;
  final List<String> options;

  /// 選択肢0(左)が合う選手の能力。
  final List<Attr> low;

  /// 選択肢2(右)が合う選手の能力。
  final List<Attr> high;
}

/// 方針の既定(どれも「ふつう」)。
List<int> defaultPolicy() => List.filled(PolicyAxis.values.length, 1);

/// 1人の選手が、ある軸の選択に合う度合い(-1〜1。真ん中の選択は0)。能力のずれ(`Player.attrs`)から決める。
double playerAxisFit(Player p, PolicyAxis axis, int choice) {
  if (choice == 1 || axis == PolicyAxis.depth) return 0;
  final attrs = choice == 0 ? axis.low : axis.high;
  final dev = attrs.fold(0.0, (s, a) => s + p.attrs[a.index]) / attrs.length;
  return (dev / 8).clamp(-1.0, 1.0);
}

/// 出場時間の重み(力の高い順の9人)。
const _w = [1.0, 1.0, 0.95, 0.9, 0.85, 0.6, 0.45, 0.35, 0.2];

/// 方針に合う度合い(-1〜1)。主力ほど重く数える。[top] は力の高い順の選手。
double teamAxisFit(List<Player> top, PolicyAxis axis, int choice) {
  if (choice == 1) return 0;
  if (axis == PolicyAxis.depth) {
    if (top.length < 8) return 0;
    // 主力と控えの力の差が小さいほど「広く使う」に合い、大きいほど「主力集中」に合う
    final star = (top[0].ovr + top[1].ovr + top[2].ovr) / 3;
    final bench = (top[5].ovr + top[6].ovr + top[7].ovr) / 3;
    final gap = ((star - bench - 12) / 8).clamp(-1.0, 1.0); // 差が大きいと正
    return choice == 0 ? gap : -gap;
  }
  var sum = 0.0, ws = 0.0;
  for (var i = 0; i < _w.length && i < top.length; i++) {
    sum += playerAxisFit(top[i], axis, choice) * _w[i];
    ws += _w[i];
  }
  return ws == 0 ? 0 : sum / ws;
}

/// ヘッドコーチの得意な方針(軸ごとの選択)。名前から決める(同じコーチなら同じ)。
List<int> coachFavorite(Coach hc) {
  var h = 7;
  for (final u in hc.name.codeUnits) {
    h = (h * 31 + u) & 0x7fffffff;
  }
  return [for (var i = 0; i < PolicyAxis.values.length; i++) (h ~/ (i * 3 + 1)) % 3];
}

/// 方針が強さに足す値(-1.5〜+1.5)。合う方針は最大 +0.3×軸の数、ヘッドコーチの得意と同じ選択には +0.1。
double policyBonus(List<Player> top, List<int> policy, Coach? hc) {
  var b = 0.0;
  final fav = hc == null ? null : coachFavorite(hc);
  for (final axis in PolicyAxis.values) {
    final c = policy[axis.index].clamp(0, 2);
    b += 0.3 * teamAxisFit(top, axis, c);
    if (fav != null && c != 1 && fav[axis.index] == c) b += 0.1;
  }
  return b.clamp(-1.5, 1.5);
}

/// 選手の方針への合い方の札(◎ 合う・○ ふつう・△ 合わない)。ふつう以外を選んだ軸だけで見る。
String fitMark(Player p, List<int> policy) {
  var sum = 0.0, n = 0;
  for (final axis in PolicyAxis.values) {
    final c = policy[axis.index].clamp(0, 2);
    if (c == 1 || axis == PolicyAxis.depth) continue;
    sum += playerAxisFit(p, axis, c);
    n++;
  }
  if (n == 0) return '○';
  final v = sum / n;
  return v >= 0.25 ? '◎' : v <= -0.25 ? '△' : '○';
}
