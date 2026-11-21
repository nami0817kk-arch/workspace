import 'combos.dart';
import 'player.dart';

/// 時代の流行(2026-11-21 の作り込み C-3)。数年ごとに移り、流行に合う型の選手は市場で高く、外れた型は安くなる(逆張りができる)。
/// 優勝したチームの型を、ほかのチームが真似して広まる(2〜3年かけて)。
enum Era {
  three('3ポイントの時代', '外の名手と、外も打てる大型の値打ちが上がる', {Role.shooter, Role.stretch}, Pos.sg),
  big('大型の時代', 'ゴール下の番人と、中で点を取る選手の値打ちが上がる', {Role.anchor, Role.scorer}, Pos.c),
  run('走る時代', '切り込み役と司令塔の値打ちが上がる', {Role.slasher, Role.playmaker}, Pos.pg),
  defense('守りの時代', '守りの職人の値打ちが上がる', {Role.stopper}, Pos.sf);

  const Era(this.label, this.text, this.roles, this.pos);
  final String label, text;
  final Set<Role> roles;

  /// その時代に、ドラフトで豊作になりやすいポジション。
  final Pos pos;
}

/// 選手の型が合う時代(無ければ null。点取り屋は大型の時代に少し合う)。
Era? eraOfRole(Role r) => switch (r) {
      Role.shooter || Role.stretch => Era.three,
      Role.anchor || Role.scorer => Era.big,
      Role.slasher || Role.playmaker => Era.run,
      Role.stopper => Era.defense,
    };

/// 流行の重み(4つの時代の割合。合わせて1)から、選手の値打ちの倍率(0.88〜1.15ほど)。
double fashionScale(List<double> weights, Player p) {
  final e = eraOfRole(roleOf(p));
  if (e == null || weights.length != Era.values.length) return 1.0;
  return 1 + (weights[e.index] - 0.25) * 0.6;
}

/// いまの流行(重みがいちばん大きい時代)。
Era currentEra(List<double> weights) {
  var best = 0;
  for (var i = 1; i < weights.length; i++) {
    if (weights[i] > weights[best]) best = i;
  }
  return Era.values[best];
}

/// 季の終わりに、優勝チームの先発の型で流行を動かす(真似して広まる)。2〜3年かけて移るように、少しずつ。
List<double> nextWeights(List<double> w, List<Role> championFive) {
  final add = List<double>.filled(Era.values.length, 0);
  for (final r in championFive) {
    final e = eraOfRole(r);
    if (e != null) add[e.index] += 1;
  }
  final total = add.fold(0.0, (a, b) => a + b);
  final out = [for (var i = 0; i < w.length; i++) w[i] * 0.75 + (total == 0 ? 0.0625 : add[i] / total * 0.25)];
  final s = out.fold(0.0, (a, b) => a + b);
  return [for (final x in out) x / s];
}
