part of 'game.dart';

/// 人の顔の絵の割り当て（1.0.0+21）。ゲームの乱数は使わない（名前・年齢・使われている顔だけで決まる）。
/// 決めた顔は人（社長・部下・候補・子ども・宿敵の会社）に保存する。月が変わっても変わらず、
/// 替わるのは年代をまたいだとき（35歳・55歳）と、宿敵が代替わりしたときだけ
extension GameFaces on Game {
  /// 子どもに顔の絵を付け始める年齢（いちばん若い絵が22歳なので、それより小さい子には付けない）
  static const kidFaceAge = 16;

  /// 自分の会社の人（社長は別）。同じ人を2度数えない
  Set<Person> _facePeople() => <Person>{...staff, ...kids, ?meet, ...cands};

  String _pick(String name, num age, Map<String, int> used, String? prev, {String? home}) =>
      pickFace(name: name, age: age, region: faceRegion(name, home: home), sex: faceSex(name), used: used, prev: prev);

  /// まだ顔の無い人・年代をまたいだ人・代替わりした宿敵に、顔を割り当てる。何度呼んでも同じ結果
  void ensureFaces() {
    // 自分の会社: 社長 → 部下 → 子ども → 出会った人 → 候補 の順に、ほかの人の顔を避けて決める
    final used = <String, int>{};
    void take(String? f) {
      if (f != null) used[f] = (used[f] ?? 0) + 1;
    }

    void drop(String? f) {
      if (f != null && (used[f] ?? 0) > 0) used[f] = used[f]! - 1;
    }

    final people = _facePeople();
    take(pres.face);
    for (final p in people) {
      take(p.face);
    }
    if (faceStale(pres.face, pres.fb, pres.age) || !faceFits(pres.face, faceRegion(pres.name, home: home))) {
      drop(pres.face);
      pres.face = _pick(pres.name, pres.age, used, pres.face, home: home);
      pres.fb = ageBand(pres.age);
      take(pres.face);
    }
    for (final p in people) {
      if (p.kid && p.age < kidFaceAge) continue;
      // 年代をまたいだ人と、地域の合わない絵（1.0.0+22 で東アジアに直した we_4・we_5 を持っている欧米の人など）を選び直す
      if (!faceStale(p.face, p.fb, p.age) && faceFits(p.face, faceRegion(p.name, home: home))) continue;
      drop(p.face);
      p.face = _pick(p.name, p.age, used, p.face, home: home);
      p.fb = ageBand(p.age);
      take(p.face);
    }
    // 宿敵どうし（と自分の社長）で重ならないようにする
    used.clear();
    take(pres.face);
    final rivals = cos.where((c) => c.rival != null && c.alive).toList();
    for (final c in rivals) {
      if (c.pfn != c.presName) {
        c.pf = null;
        c.pfb = null;
        c.pfn = c.presName;
      }
      take(c.pf);
    }
    for (final c in rivals) {
      if (!faceStale(c.pf, c.pfb, c.presAge) && faceFits(c.pf, faceRegion(c.presName))) continue;
      drop(c.pf);
      c.pf = _pick(c.presName, c.presAge, used, c.pf);
      c.pfb = ageBand(c.presAge);
      take(c.pf);
    }
  }

  /// 社長の顔
  String? get presFace {
    if (faceStale(pres.face, pres.fb, pres.age)) ensureFaces();
    return pres.face;
  }

  /// 部下・候補・子ども・出会った人の顔（15歳までの子どもは null）
  String? faceOf(Person p) {
    if (p.kid && p.age < kidFaceAge) return null;
    if (faceStale(p.face, p.fb, p.age)) {
      ensureFaces();
      // どの一覧にもいない人（出来事の中だけの人）は、その場で決めて持たせる
      if (faceStale(p.face, p.fb, p.age)) {
        final used = <String, int>{if (pres.face != null) pres.face!: 1};
        for (final o in _facePeople()) {
          if (o.face != null) used[o.face!] = (used[o.face!] ?? 0) + 1;
        }
        p.face = _pick(p.name, p.age, used, p.face, home: home);
        p.fb = ageBand(p.age);
      }
    }
    return p.face;
  }

  /// 会社の社長の顔。宿敵は保存した顔、ほかの会社は名前と年齢からその場で決まる顔
  String coFace(Company c) {
    if (c.rival != null && c.alive && (c.pfn != c.presName || faceStale(c.pf, c.pfb, c.presAge))) ensureFaces();
    if (c.pfn == c.presName && c.pf != null && faceById.containsKey(c.pf)) return c.pf!;
    return _pick(c.presName, c.presAge, const {}, null);
  }
}
