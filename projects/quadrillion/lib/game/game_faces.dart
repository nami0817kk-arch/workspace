part of 'game.dart';

/// 人の顔の絵の割り当て（1.0.0+21）。ゲームの乱数は使わない（名前・年齢・使われている顔だけで決まる）。
/// 決めた顔は人（社長・部下・候補・子ども・宿敵の会社）に保存する。月が変わっても変わらず、
/// 替わるのは本人と絵の年の差が12歳を超えたとき（1.0.0+23 から）と、宿敵が代替わりしたときだけ
extension GameFaces on Game {
  /// 子どもに顔の絵を付け始める年齢（いちばん若い絵が22歳なので、それより小さい子には付けない）
  static const kidFaceAge = 16;

  /// 自分の会社の人（社長は別）。同じ人を2度数えない
  Set<Person> _facePeople() => <Person>{...staff, ...kids, ?meet, ...cands};

  /// 顔の重なりの重さ。社長と部下は人タブの同じ画面に並ぶので重く数え、重ねるときは子ども・候補の顔を先に重ねる
  int _faceWeight(Person? p) => p == null || staff.contains(p) ? 2 : 1;

  String _pick(String name, num age, Map<String, int> used, String? prev, {String? home}) =>
      pickFace(name: name, age: age, region: faceRegion(name, home: home), sex: faceSex(name), used: used, prev: prev);

  bool _faceStale(String? face, String name, num age, {String? home}) =>
      faceStale(face, age, region: faceRegion(name, home: home), sex: faceSex(name));

  /// まだ顔の無い人・絵と年や地域が合わなくなった人・代替わりした宿敵に、顔を割り当てる。何度呼んでも同じ結果。
  /// 古いセーブを読んだときも、今の決まりで合っていない顔だけを選び直す
  void ensureFaces() {
    // 自分の会社: 社長 → 相棒 → ほかの部下 → 子ども → 出会った人 → 候補 の順に、ほかの人の顔を避けて決める（目立つ人を先に）
    final used = <String, int>{};
    void take(String? f, int w) {
      if (f != null) used[faceLook(f)] = (used[faceLook(f)] ?? 0) + w;
    }

    void drop(String? f, int w) {
      if (f == null) return;
      final k = faceLook(f);
      used[k] = math.max(0, (used[k] ?? 0) - w);
    }

    final all = _facePeople();
    final people = [...all.where((p) => p.partner), ...all.where((p) => !p.partner)];
    take(pres.face, 2);
    for (final p in people) {
      take(p.face, _faceWeight(p));
    }
    if (_faceStale(pres.face, pres.name, pres.age, home: home)) {
      drop(pres.face, 2);
      pres.face = _pick(pres.name, pres.age, used, pres.face, home: home);
      pres.fb = pres.age.round();
      take(pres.face, 2);
    }
    for (final p in people) {
      if (p.kid && p.age < kidFaceAge) continue;
      if (!_faceStale(p.face, p.name, p.age, home: home)) continue;
      final w = _faceWeight(p);
      drop(p.face, w);
      p.face = _pick(p.name, p.age, used, p.face, home: home);
      p.fb = p.age.round();
      take(p.face, w);
    }
    // 人タブの部下の一覧で同じ顔が並んでいて、もっと重なりの少ない年の合う絵があれば、目立たない人から選び直す
    // （誰かが辞めて絵が空いたとき・同じ年ごろの人が同じ絵に寄ったときなど。並ぶ組が必ず減るときだけ替えるので、替わり続けない）
    final onScreen = <String, int>{};
    for (final f in [pres.face, ...staff.map((p) => p.face)]) {
      if (f != null) onScreen[faceLook(f)] = (onScreen[faceLook(f)] ?? 0) + 1;
    }
    // 1度の呼び出しで落ち着くまで回す（何度呼んでも同じ結果にするため）。替えるたびに並ぶ組が減るので必ず止まる
    for (var changed = true, round = 0; changed && round < 50; round++) {
      changed = false;
      for (final p in [...staff.reversed.where((p) => !p.partner), ...staff.reversed.where((p) => p.partner)]) {
        final face = p.face;
        final n = face == null ? 0 : (onScreen[faceLook(face)] ?? 0);
        if (n < 2) continue;
        final f = faceLeastShared(name: p.name, age: p.age, region: faceRegion(p.name, home: home), sex: faceSex(p.name), shared: onScreen, used: used);
        if (f == null || (onScreen[faceLook(f)] ?? 0) >= n - 1) continue;
        drop(face, 2);
        onScreen[faceLook(face!)] = n - 1;
        p
          ..face = f
          ..fb = p.age;
        take(f, 2);
        onScreen[faceLook(f)] = (onScreen[faceLook(f)] ?? 0) + 1;
        changed = true;
      }
    }
    // 宿敵どうし（と自分の社長）で重ならないようにする
    used.clear();
    take(pres.face, 1);
    final rivals = cos.where((c) => c.rival != null && c.alive).toList();
    for (final c in rivals) {
      if (c.pfn != c.presName) {
        c.pf = null;
        c.pfb = null;
        c.pfn = c.presName;
      }
      take(c.pf, 1);
    }
    for (final c in rivals) {
      if (!_faceStale(c.pf, c.presName, c.presAge)) continue;
      drop(c.pf, 1);
      c.pf = _pick(c.presName, c.presAge, used, c.pf);
      c.pfb = c.presAge.round();
      take(c.pf, 1);
    }
  }

  /// 社長の顔
  String? get presFace {
    if (_faceStale(pres.face, pres.name, pres.age, home: home)) ensureFaces();
    return pres.face;
  }

  /// 部下・候補・子ども・出会った人の顔（15歳までの子どもは null）
  String? faceOf(Person p) {
    if (p.kid && p.age < kidFaceAge) return null;
    if (_faceStale(p.face, p.name, p.age, home: home)) {
      ensureFaces();
      // どの一覧にもいない人（出来事の中だけの人）は、その場で決めて持たせる
      if (_faceStale(p.face, p.name, p.age, home: home)) {
        final used = <String, int>{if (pres.face != null) faceLook(pres.face!): 2};
        for (final o in _facePeople()) {
          if (o.face != null) used[faceLook(o.face!)] = (used[faceLook(o.face!)] ?? 0) + _faceWeight(o);
        }
        p.face = _pick(p.name, p.age, used, p.face, home: home);
        p.fb = p.age.round();
      }
    }
    return p.face;
  }

  /// 会社の社長の顔。宿敵は保存した顔、ほかの会社は名前と年齢からその場で決まる顔
  String coFace(Company c) {
    if (c.rival != null && c.alive && (c.pfn != c.presName || _faceStale(c.pf, c.presName, c.presAge))) ensureFaces();
    if (c.pfn == c.presName && c.pf != null && faceById.containsKey(c.pf)) return c.pf!;
    return _pick(c.presName, c.presAge, const {}, null);
  }
}
