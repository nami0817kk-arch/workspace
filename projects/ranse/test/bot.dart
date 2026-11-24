import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/rng.dart';

/// 出世を狙うが、無謀は避ける選び方。
int pickAmbitious(Game g, Prompt p, Rng r) {
  final cs = p.choices;
  if (p.title == '今年の重点') {
    final pref = g.l.rank == 0
        ? ['仕官の口を探す', '奉公先を探す', '武芸を磨く', '学問に励む']
        : (g.l.rank >= 8
              ? ['版図を広げる', '領国を富ませる', '軍備を整える']
              : ['主君に尽くす', '奥向きに尽くす', '戦に備える', '武芸を磨く']);
    if (g.l.hp < g.l.maxhp * .5) {
      final i = cs.indexWhere(
        (c) => c.label.contains('休') || c.label.contains('家族'),
      );
      if (i >= 0) return i;
    }
    if (!g.l.married && g.age >= 20 && r.chance(.3)) {
      final i = cs.indexWhere(
        (c) => c.label.contains('妻') || c.label.contains('嫁'),
      );
      if (i >= 0) return i;
    }
    for (final w in pref) {
      final i = cs.indexWhere((c) => c.label == w);
      if (i >= 0 && r.chance(.75)) return i;
    }
    return r.range(0, cs.length - 1);
  }
  // 岐路: 命を落とすと匂わせる選択肢を避け、手柄・出世を匂わせるものを選ぶ。
  int score(Choice c) {
    final h = c.hint ?? '';
    var s = 0;
    if (RegExp('命はない|討死|命を落と|生きて帰|助からない|死').hasMatch(h)) s -= 3;
    if (RegExp('手柄|出世|名を上げ|覚えがめでた|功|取り立て|道が開').hasMatch(h)) s += 2;
    if (RegExp('身分が得られる|仕官|一城|国').hasMatch(h)) s += 2;
    if (RegExp('何も起きない|何も変わらない').hasMatch(h)) s -= 1;
    return s;
  }

  var best = 0;
  for (var i = 1; i < cs.length; i++) {
    if (score(cs[i]) > score(cs[best])) best = i;
  }
  return best;
}

/// 能力で増えた手（[Choice.via] に [vias] のどれかの字を含む手）があれば、必ずそれを選ぶ選び方。
/// なければ [pickAmbitious]。能力ごとの手の強さを比べる物差し（2026-11-24「気がかりの直し」）。
/// 二つの能力のどちらかで出る手（`知魅` など）は、どちらの字でも当たる。特性・持ち物の名の印は当たらない。
int pickVia(Game g, Prompt p, Rng r, String vias) {
  if (p.title != '今年の重点') {
    for (var i = 0; i < p.choices.length; i++) {
      final v = p.choices[i].via;
      if (v == null || !viaIsAbility(v)) continue;
      if (v.split('').any(vias.contains)) return i;
    }
  }
  return pickAmbitious(g, p, r);
}
