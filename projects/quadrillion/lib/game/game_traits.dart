// ignore_for_file: non_constant_identifier_names
part of 'game.dart';

/// 社員の特性（1.1.0+33。企画書「社員の特性 70種類」2026-11-26）。
///
/// 1人 2〜4個。いちばん上（[Person.trait]）は今までの10種のどれかで、効き目も今までどおり（game.dart・game_turn.dart など）。
/// 残りの1〜3個は新しい60種（traits_data.dart）から引き、効き目はここに集める。
/// 全体の決まり:
///   1. 相性: 社長の特性との相性（[PRES_COMPAT]）と、部下どうしの相性（[STAFF_COMPAT]）でやる気・育ち・揉めごとが変わる
///   2. 扱い方への反応: 昇給・責任者にする/外す・叱る・研修で、受け止め方が特性で変わる
///   3. 出来事: 酒の席の不祥事・使い込み・情報漏れ・ムードメーカーが辞める・派閥の揉めごと・独立・小さな事故 など
///   4. はじめは1つだけ見える。残りは働いた月・話を聞く・出来事で分かる（人たらしの社長・目利きの部下は早い）
///   5. 経験で付いたり消えたりする（修羅場→肝が据わっている、責任者を続ける→面倒見がいい、病気→心配性 など）
///
/// ここの乱数は、ゲームの乱数（[Game.rng]）とは別の並び（[Game.trSeed]）から引く（game_life.dart と同じ考え方）。
/// 足した特性が乱数を使っても、今までの出来事の並びがずれないように。
/// 試作との一致を見る遊び（extras を切る）では、何もしない（特性は今までどおり1つ）。

/// 遊びの外から起きたこと（辞めた・外した）の知らせを、次の月の知らせに回す（保存しない）
final Expando<List<LogEntry>> _trPendX = Expando('trPend');

/// 別の並びの乱数で人を作るための入れ物（[GameTraits.trWideCand]）
class _TrRandom implements math.Random {
  final Game g;
  _TrRandom(this.g);
  @override
  double nextDouble() => g.tr();
  @override
  int nextInt(int max) => (g.tr() * max).floor();
  @override
  bool nextBool() => g.tr() < .5;
}

extension GameTraits on Game {
  bool get trOn => extras;

  /// 別の並びの乱数（0〜1。Park-Miller）
  double tr() {
    if (trSeed <= 0) trSeed = (fcSeed * 48271 % 2147483646).abs() + 1;
    trSeed = trSeed * 16807 % 2147483647;
    if (trSeed <= 0) trSeed += 2147483646;
    return (trSeed - 1) / 2147483646;
  }

  T _tpick<T>(List<T> a) => a[(tr() * a.length).floor().clamp(0, a.length - 1)];

  /// その特性を持つ部下が会社にいるか（休んでいる人は数えない）
  bool anyTr(String id) => trOn && staff.any((p) => p.away == 0 && p.has(id));

  /// その特性を持つ、[p] 以外の部下が会社にいるか
  bool otherTr(Person p, String id) => trOn && staff.any((o) => o != p && o.away == 0 && o.has(id));

  /// 会社が赤字・危機の中か
  bool trCrisis() => pre < 0 || pres.crisis > 0 || bankCtl > 0;

  // ===== 事業の見方（特性の効く場面） =====
  /// 事業の国のうち、海外の割合（0〜1）
  double trFF(Biz b) {
    final cs = ctryOf(b);
    if (cs.isEmpty) return 0;
    return cs.where((c) => c != home).length / cs.length;
  }

  bool _field(Biz b) => const {'shop', 'license'}.contains(kindB(b));
  bool _plant(Biz b) => const {'factory', 'infra'}.contains(kindB(b)) || indm[b.ind]!.cat == 'link';
  bool _dev(Biz b) => indm[b.ind]!.key == 'kai' || const {'net', 'hit'}.contains(kindB(b));
  bool _sales(Biz b) => indm[b.ind]!.key == 'ei';
  bool _newInd(Biz b) => yr() - indm[b.ind]!.b < 15;
  bool _oldInd(Biz b) => yr() - indm[b.ind]!.b > 40;
  bool _rivalIn(Biz b) => cos.any((c) => c.alive && c.rival != null && c.parent != 'player' && c.biz.any((x) => x.ind == b.ind));

  // ===== 見える・見えない =====
  /// その特性が見えているか
  bool trSeen(Person p, String id) => p.tseen.contains(id) || (id == p.trait && p.traitKnown);

  /// 見えている特性（持っている順）
  List<String> trVisible(Person p) => p.traits.where((t) => trSeen(p, t)).toList();

  /// まだ見えていない特性の数
  int trHidden(Person p) => p.traits.where((t) => !trSeen(p, t)).length;

  /// 特性を見えるようにする（図鑑にも載る）
  void trSee(Person p, String id) {
    if (!p.has(id)) return;
    if (!p.tseen.contains(id)) p.tseen.add(id);
    if (id == p.trait) p.traitKnown = true;
    if (staff.contains(p) || cands.contains(p)) trFound.add(id);
  }

  /// 特性の良い面と悪い面を1つの文にする（片方しかないものはそれだけ）
  String trDesc(StaffTrait t) {
    if (t.gJa.isEmpty) return D(t.bJa);
    if (t.bJa.isEmpty) return D(t.gJa);
    return Cat([D(t.gJa), D(t.bJa)], ja: '／', en: ' / ');
  }

  /// 隠れた特性を1つ見えるようにする（知らせを出す）。見えたら true
  bool _reveal(Person p, void Function(String, [String])? N) {
    final hid = p.traits.where((t) => !trSeen(p, t)).toList();
    if (hid.isEmpty) return false;
    final id = _tpick(hid);
    trSee(p, id);
    final t = stm[id]!;
    N?.call(M('{0}の特性が分かりました：「{1}」（{2}）', [Nm(p.name), D(t.nJa), trDesc(t)]));
    return true;
  }

  // ===== 人を作る =====
  /// いちばん上の特性を決め直す（「天才肌」はまれ。7割は別の今までの特性に引き直す）
  String trMain(String t) {
    if (t != 'genius' || tr() < .3) return t;
    return _tpick(STRAITS.where((x) => x.id != 'genius').toList()).id;
  }

  /// 新しい特性を [n] 個足す（重みつき・合わない組み合わせは避ける）
  void _addExtras(Person p, int n) {
    final pool = STAFF_TRAITS.where((t) => t.cat != 'old').toList();
    for (var k = 0; k < n && p.traits.length < 4; k++) {
      final ok = pool.where((t) => !p.has(t.id) && !p.traits.any((x) => straitNg(x, t.id))).toList();
      if (ok.isEmpty) return;
      final tot = ok.fold(0.0, (a, t) => a + t.w);
      var r = tr() * tot;
      var pick = ok.last;
      for (final t in ok) {
        r -= t.w;
        if (r <= 0) {
          pick = t;
          break;
        }
      }
      p.traits.add(pick.id);
    }
  }

  /// 残りの特性の数（1〜3。合わせて2〜4個）
  int _extraN() {
    final r = tr();
    return r < .45
        ? 1
        : r < .85
        ? 2
        : 3;
  }

  /// 作った人に残りの特性を付け、はじめに見える1つを決める（人たらしの社長なら1つ多く、目利きの部下がいればさらに1つ見える）
  void trRoll(Person p) {
    if (!trOn) return;
    _addExtras(p, _extraN());
    _firstSeen(p);
  }

  void _firstSeen(Person p) {
    var n = 1 + (hasT('charm') ? 1 : 0) + (anyTr('eye') ? 1 : 0);
    // いちばん上の特性が分かっている（人たらしの社長）なら、それも見える1つに数える
    if (p.traitKnown && !p.tseen.contains(p.trait)) p.tseen.add(p.trait);
    if (p.traitKnown) n--;
    for (var i = 0; i < n; i++) {
      final hid = p.traits.where((t) => !trSeen(p, t)).toList();
      if (hid.isEmpty) break;
      trSee(p, _tpick(hid));
    }
  }

  /// いちばん上の特性を替えたあと、合わない組み合わせを外し、2つに満たなければ足す
  void trFix(Person p) {
    if (!trOn) return;
    final main = p.trait;
    p.traits = [main, ...p.traits.skip(1).where((x) => x != main && !straitNg(main, x))];
    p.tseen.removeWhere((x) => !p.has(x));
    if (p.traits.length < 2) _addExtras(p, 1);
  }

  /// 古いセーブ（特性1つ）の人に、今の1つを残して残りを足す
  void trMigrate() {
    if (!trOn) return;
    for (final p in [...staff, ...cands, ...alumni, ...kids, ?meet]) {
      if (!p.real || p.traits.length > 1) continue;
      _addExtras(p, _extraN());
      if (p.traitKnown) p.tseen = [p.trait];
      if (p.tseen.isEmpty) _firstSeen(p);
      if (staff.contains(p)) {
        for (final t in trVisible(p)) {
          trFound.add(t);
        }
      }
    }
  }

  // ===== 事業への効き目 =====
  /// 責任者の特性が事業の力にかける倍（責任者の [Game.mgrMult] にかける）
  double trPowF(Biz b, Person p) {
    if (!trOn || !p.real || p.traits.length < 2) return 1;
    var m = 1.0;
    final ff = trFF(b);
    for (final t in p.traits.skip(1)) {
      switch (t) {
        case 'night':
          if (_dev(b)) {
            m *= 1.05;
          } else if (_field(b)) {
            m *= .95;
          }
        case 'plan':
          if (_plant(b)) m *= 1.06;
        case 'novelty':
          if (_newInd(b) || techCats.contains(indm[b.ind]!.cat)) {
            m *= 1.06;
          } else if (_oldInd(b)) {
            m *= .94;
          }
        case 'precedent':
          if (_oldInd(b)) m *= 1.04;
          if (_newInd(b)) m *= .93;
          m *= 1 - .08 * ff;
        case 'deadline':
          m *= .98;
        case 'gut':
          // 新しい業種では、半年ごとに勘が当たったり外れたりする（0.85〜1.25倍）
          if (_newInd(b)) m *= .85 + .4 * hashOf(p.id * 13 + turn ~/ 6, 11);
        case 'lone':
          if (_dev(b) || _sales(b)) m *= 1.05;
        case 'tongue':
          if (_sales(b)) m *= .92;
        case 'shy':
          m *= 1 - .1 * ff;
        case 'craft':
          if (_dev(b) || _plant(b)) m *= 1.07;
        case 'social':
          if (const {'med', 'ene'}.contains(indm[b.ind]!.cat)) m *= 1.08;
        case 'abroad':
          m *= 1 + .1 * ff;
        case 'local':
          if (ff > .3) m *= .95;
        case 'compete':
          if (_rivalIn(b)) m *= 1.08;
        case 'clutch':
          if (trCrisis()) m *= 1.15;
        case 'steel':
          if (econ < .98) m *= 1.04;
        case 'vain':
          if (_sales(b)) m *= 1.03;
        case 'moody':
          // 月ごとに上下する（0.92〜1.08倍。乱数は使わず、人と月で決まる）
          m *= .92 + .16 * hashOf(p.id * 7 + turn, 9);
        case 'excuse':
          if (b.profit < 0) m *= .96;
        case 'blend':
          m *= 1 + .05 * ff;
      }
    }
    return m;
  }

  /// 責任者の特性が現場の人の働きにかける倍（[Game.crewMult]・[Game.crewEff]）
  double trCrewF(Biz b) {
    if (!trOn) return 1;
    final p = mgrOf(b);
    if (p == null || !p.real || p.traits.length < 2) return 1;
    var m = 1.0;
    if (p.has('field') && _field(b)) m *= 1.08;
    if (p.has('mood')) m *= 1.05;
    if (p.has('charisma')) m *= 1.12;
    if (p.has('lone')) m *= .94;
    if (p.has('late')) m *= _field(b) ? .96 : .99;
    return m;
  }

  /// 責任者の特性が利益率に足す分
  double trMg(Biz b, Person p, Industry ind) {
    if (!trOn || !p.real || p.traits.length < 2) return 0;
    var a = 0.0;
    if (p.has('neat')) a += .006;
    if (p.has('rough')) a -= .006;
    if (p.has('vain')) a -= .004;
    if (p.has('haggle')) a += .004;
    if (trCrisis()) {
      if (p.has('worrier')) a += .01;
      if (p.has('optimist')) a -= .01;
    }
    // 肝が据わっている人は、不況で利益率が落ちる分を半分にする
    if (p.has('steel') && econ < 1) a += ind.mg * (1 - econ) * ind.sens * .5;
    return a;
  }

  /// 本社の経費にかける倍（経費に甘い・見栄っ張りで増え、几帳面で減る。危機に強い人がいると危機の間は減る）
  double trHqF() {
    if (!trOn) return 1;
    var f = 1.0;
    for (final p in staff) {
      if (p.away > 0 || p.traits.length < 2) continue;
      if (p.has('lax')) f += .04;
      if (p.has('vain')) f += .02;
      if (p.has('neat')) f -= .02;
    }
    if (trCrisis() && anyTr('crisis')) f *= .9;
    return clampD(f, .85, 1.25);
  }

  /// 責任者が稼ぎを事業に回すときの効きにかける倍（せっかちは時々空振り・締め切り直前に強い人は普段は遅め）
  double trReinvF(Biz b, Person p) {
    if (!trOn || !p.real || p.traits.length < 2) return 1;
    var f = 1.0;
    if (p.has('deadline')) f *= .9;
    if (p.has('hasty') && tr() < .08) f = 0;
    return f;
  }

  /// 新商品・作品の大当たりの見込みに足す分
  double trHitAdd(Biz b) {
    if (!trOn) return 0;
    var a = 0.0;
    final p = mgrOf(b);
    if (p != null && p.real) {
      if (p.has('perfect')) a += .02;
      if (p.has('idea')) a += .06;
      if (p.has('gut') && _newInd(b)) a += .03;
    }
    if ((p == null || !p.has('idea')) && anyTr('idea')) a += .03;
    return a;
  }

  /// 新商品・作品の外れの見込みに足す分
  double trMissAdd(Biz b) {
    if (!trOn) return 0;
    final p = mgrOf(b);
    if (p == null || !p.real) return 0;
    var a = 0.0;
    if (p.has('hasty')) a += .05;
    if (p.has('gut') && _newInd(b)) a += .05;
    if (p.has('perfect')) a -= .03;
    return a;
  }

  /// 不祥事の見込みにかける倍（完璧主義・几帳面がいると減る）
  double trScandalF() {
    if (!trOn) return 1;
    var f = 1.0;
    if (anyTr('perfect')) f *= .85;
    if (anyTr('neat')) f *= .9;
    return f;
  }

  /// 役所の許可を待つ月・当局の審査で止められる見込みにかける倍（根回し上手がいると 0.6）
  double trBlockF() => anyTr('fixer') ? .6 : 1;

  /// 買う値段にかける倍（交渉の鬼・人たらしの部下）
  double trDealPriceF() {
    if (!trOn) return 1;
    return (anyTr('haggle') ? .9 : 1) * (anyTr('charm') ? .97 : 1);
  }

  /// 大口の客に切られそうなとき、記憶力が抜群の人が半分はつなぎ止める
  bool trKeepClient(Biz b, void Function(String, [String]) N) {
    if (!trOn) return false;
    final p = staff.where((o) => o.away == 0 && o.has('memory')).firstOrNull;
    if (p == null || tr() >= .5) return false;
    trSee(p, 'memory');
    N(M('記憶力が抜群の{0}が客の事情をよく覚えていて、「{1}」の大口の客をつなぎ止めました', [Nm(p.name), I(b.ind)]), 'good');
    return true;
  }

  /// 現地を助ける度合いにかける倍
  double trHelpF(Person p) {
    if (!trOn) return 1;
    var f = 1.0;
    if (p.has('blend')) f *= 1.3;
    if (p.has('abroad')) f *= 1.15;
    if (p.has('shy')) f *= .6;
    if (p.has('local')) f *= .7;
    return f;
  }

  /// 顔が広い人のつてで出る中途の候補（いなければ null。別の乱数の並びで作り、番号もゲームの並びを使わない）
  Person? trWideCand(double q) {
    if (!anyTr('wide')) return null;
    final r0 = rng, u0 = uidCounter;
    rng = _TrRandom(this);
    try {
      final p = mkPerson(q)..src = 'mid';
      p.id = -100000 - (tr() * 1e9).floor();
      return p;
    } finally {
      rng = r0;
      uidCounter = u0;
    }
  }

  // ===== 人への効き目 =====
  /// 健康が落ちるときの倍
  double trHealthF(Person p) {
    if (!trOn) return 1;
    var f = 1.0;
    if (p.has('optimist')) f *= .6;
    if (p.has('worrier')) f *= 1.4;
    if (p.has('fragile') && otherTr(p, 'mood')) f *= .8;
    return f;
  }

  /// 辞める見込みにかける倍
  double trQuitF(Person p, double pr) {
    if (!trOn) return 1;
    var f = 1.0;
    final head = biz.any((b) => b.mgr == p.id);
    if (p.has('devoted')) f *= .3;
    if (p.has('stable') && pr >= .95) f *= .3;
    if (p.has('money') && pr < payLowRatio) f *= 1.6;
    if (p.has('climb') && !head && p.tenure >= 24) f *= 1.3;
    if (p.has('field') && head) f *= 1.3;
    if (p.tenure < 24 && otherTr(p, 'mentor')) f *= .7;
    if (otherTr(p, 'listen')) f *= .8;
    if (otherTr(p, 'charisma')) f *= .8;
    return f;
  }

  /// 研修の伸びの倍（教え上手がいると2倍）
  int trTeachF(Person p) => otherTr(p, 'teacher') ? 2 : 1;

  /// 1年の能力の伸びにかける倍（面倒見のいい先輩がいる若手・手柄を横取りする本人）
  double trGrowF(Person p) {
    if (!trOn) return 1;
    var f = 1.0;
    if (p.age < 35 && otherTr(p, 'mentor')) f *= 1.3;
    if (p.has('credit')) f *= 1.15;
    return f;
  }

  /// 引き抜きの誘いを断るか（会社が好きな人は7割断る）
  bool trDodgePoach(Person p) {
    if (!trOn || !p.has('devoted')) return false;
    if (tr() < .7) {
      trSee(p, 'devoted');
      return true;
    }
    return false;
  }

  /// 話を聞いたとき、隠れた特性が1つ分かる（半分の見込み）
  String? trTalk(Person p) {
    if (!trOn || trHidden(p) == 0 || tr() >= .5) return null;
    final before = trVisible(p).toSet();
    _reveal(p, null);
    final id = trVisible(p).firstWhere((t) => !before.contains(t), orElse: () => '');
    if (id.isEmpty) return null;
    return M('特性が分かりました：「{0}」', [D(stm[id]!.nJa)]);
  }

  /// 病気で休みに入った人は、心配性になることがある
  void trOnSick(Person p, void Function(String, [String]) N) {
    if (!trOn || p.has('optimist') || tr() >= .2) return;
    _gain(p, 'worrier', N);
  }

  // ===== 扱い方への反応 =====
  /// 責任者を替えたとき（新しく置いた人・外された人の受け止め方）
  void trOnPlace(Biz b, int? oldId, int? newId) {
    if (!trOn) return;
    final np = staffById(newId), op = staffById(oldId);
    if (np != null && np.real) {
      final moved = biz.any((x) => x != b && x.mgr == np.id);
      final ff = trFF(b);
      if (np.has('climb')) {
        np.loy = math.min(99, np.loy + 10);
        trSee(np, 'climb');
      }
      if (np.has('craft') && !_dev(b) && !_plant(b)) np.loy -= 5;
      if (np.has('field') && !_field(b)) np.loy -= 5;
      if (np.has('stable') && (moved || ff > .3)) {
        np.loy -= 8;
        trSee(np, 'stable');
      }
      if (np.has('local') && ff > .3) {
        np.loy -= 15;
        trSee(np, 'local');
      }
      if (np.has('family') && ff > .3) np.loy -= 8;
      if (np.has('abroad') && ff > 0) {
        np.loy = math.min(99, np.loy + 8);
        trSee(np, 'abroad');
      }
    }
    if (op != null && op.real && op != np) {
      if (op.has('grudge')) {
        op.grudge = true;
        trSee(op, 'grudge');
      }
      if (op.has('climb')) op.loy -= 8;
      if (op.has('proud')) op.loy -= 6;
    }
  }

  /// 叱る（社長の時間 1時間）。ふつうはやる気が少し下がり、気が引き締まる（責任者なら事業の力が少し上がる。1年に1度まで）。
  /// 打たれ弱い人は大きく落ち込み、プライドが高い人は辞めることがあり、根に持つ人はやる気が戻らなくなり、部下を守る人は受け流す
  String scold(Person p) {
    if (!p.real || !staff.contains(p)) return M('今はこの手は使えません');
    if (p.away > 0) return M('{0}は今、会社にいません', [Nm(p.name)]);
    final nt = spendT('talk');
    if (nt != null) return nt;
    final job = biz.where((b) => b.mgr == p.id).firstOrNull;
    if (p.has('protect')) {
      trSee(p, 'protect');
      return M('{0}を叱りましたが、「部下のためにやったことです」と受け流されました', [Nm(p.name)]);
    }
    if (p.has('proud') && !p.partner && tr() < .5) {
      trSee(p, 'proud');
      fire(p, 'quit');
      calcAll();
      return M('プライドの高い{0}は、叱られたことに腹を立てて会社を辞めました', [Nm(p.name)]);
    }
    final parts = <String>[M('{0}を叱りました。やる気は少し下がりましたが、気が引き締まりました', [Nm(p.name)])];
    var drop = 4.0;
    if (p.has('fragile')) {
      drop = 15;
      p.health = math.max(0, p.health - 15);
      trSee(p, 'fragile');
      parts.add(M('{0}はひどく落ち込み、体の調子も崩しています', [Nm(p.name)]));
    } else if (p.has('bounce')) {
      drop = 1.5;
      trSee(p, 'bounce');
      parts.add(M('{0}はすぐに気持ちを切り替えました', [Nm(p.name)]));
    }
    if (p.has('grudge')) {
      p.grudge = true;
      trSee(p, 'grudge');
      parts.add(M('{0}は黙っていましたが、根に持ったようです', [Nm(p.name)]));
    }
    if (p.has('proud')) p.loy -= 6;
    p.loy -= drop;
    p.w = math.max(0, p.w - 2);
    if (job != null && !p.has('fragile') && lf.told.add('scold:${p.id}:$year')) job.power *= 1.02;
    calcAll();
    return Cat(parts, ja: '。', en: '. ');
  }

  /// 辞めた・外に出た人のあと（ムードメーカーが辞めて士気が下がる・派閥の人がついて出る）
  void trOnLeave(Person p, String why) {
    if (!trOn || !p.real) return;
    final pend = _trPendX[this] ??= [];
    for (final o in staff) {
      if (o.fac == p.id) o.fac = null;
    }
    if (why == 'retired') return;
    if (p.has('mood')) {
      for (final o in staff) {
        o.loy -= anyTr('mediate') ? 3 : 6;
      }
      pend.add(LogEntry(M('ムードメーカーの{0}が辞め、社内の士気が下がりました', [Nm(p.name)]), 'bad'));
    }
    if (p.has('faction') && (why == 'quit' || why == 'poached')) {
      final follow = <Person>[];
      for (final o in staff.toList()) {
        if (!o.real || o.partner || o.loy >= 70) continue;
        if (follow.length < 3 && o.away == 0 && tr() < .3 + (o.amb > 60 ? .2 : 0)) follow.add(o);
      }
      // （派閥の人はもう [Person.fac] を外したので、ここではやる気の低い人がついて出る）
      for (final o in follow) {
        fire(o, 'quit');
      }
      if (follow.isNotEmpty) {
        pend.add(LogEntry(M('{0}が会社を去り、{1}もついて出ていきました', [Nm(p.name), J(follow.map((o) => Nm(o.name)))]), 'bad'));
      }
    }
  }

  // ===== 経験で付く・消える =====
  /// 特性が付く（4つあれば付かない。合わないものがあれば、それと入れ替わる）
  bool _gain(Person p, String id, void Function(String, [String])? N) {
    if (p.has(id)) return false;
    final ng = p.traits.skip(1).where((x) => straitNg(x, id)).toList();
    if (straitNg(p.trait, id)) return false;
    for (final x in ng) {
      p.traits.remove(x);
      p.tseen.remove(x);
    }
    if (p.traits.length >= 4) return false;
    p.traits.add(id);
    trSee(p, id);
    N?.call(M('{0}が経験を重ねて「{1}」を身につけました', [Nm(p.name), D(stm[id]!.nJa)]), 'good');
    return true;
  }

  /// 特性が消える（いちばん上の今までの特性は消えない）
  void _lose(Person p, String id, void Function(String, [String])? N) {
    if (id == p.trait || !p.has(id)) return;
    final was = trSeen(p, id);
    p.traits.remove(id);
    p.tseen.remove(id);
    if (was) N?.call(M('{0}から「{1}」が抜けました', [Nm(p.name), D(stm[id]!.nJa)]), 'good');
  }

  // ===== 毎月 =====
  /// 社員の特性の1か月
  void trMonth(void Function(String, [String]) N) {
    if (!trOn) return;
    final pend = _trPendX[this];
    if (pend != null && pend.isNotEmpty) {
      for (final e in pend) {
        N(e.m, e.t);
      }
      pend.clear();
    }
    final crisis = trCrisis();
    if (crisis) trCrisisM++;
    for (final p in staff.toList()) {
      if (!p.real || !staff.contains(p)) continue;
      final head = biz.where((b) => b.mgr == p.id).firstOrNull;
      p.headM = head != null ? p.headM + 1 : 0;
      // 4. 見えてくる（働いた月で。人たらしの社長は早い）
      final every = hasT('charm') ? 5 : 8;
      if (p.tenure > 0 && p.tenure % every == 0) _reveal(p, N);
      if (p.away > 0) continue;
      // 1. 部下どうしの相性・周りの人から受ける影響
      var d = 0.0;
      for (final o in staff) {
        if (o == p || o.away > 0 || !o.real || o.traits.length < 2 && o.trait != 'genius') continue;
        if (o.has('mood')) d += .12;
        if (o.has('charisma')) d += biz.any((b) => b.mgr == o.id) ? .2 : .1;
        if (o.has('genius')) d -= .04;
        if (o.has('credit')) d -= p.has('protect') ? .16 : .06;
        if (o.has('protect')) d += p.has('credit') ? -.1 : .06;
        if (o.has('gossip')) d += (tr() - .6) * .5;
        if (o.has('mentor') && p.tenure < 24) d += .1;
      }
      final fl = staffById(p.fac);
      if (p.fac != null && (fl == null || !fl.has('faction'))) p.fac = null;
      if (p.fac != null) d += .15;
      // 2. 本人の価値観（任されているか・会社の大きさ・海外か）
      if (p.has('climb')) d += head != null ? .05 : (p.tenure >= 24 ? -.2 : 0);
      if (p.has('family') && head != null && unitTotal(head) >= 40) d -= .15;
      if (p.has('craft') && head != null && !_dev(head) && !_plant(head)) d -= .15;
      if (p.has('field') && head != null && (!_field(head) || unitTotal(head) >= 60)) d -= .2;
      if (p.has('honor')) d += listed || turn < lf.assocUntil ? .15 : (staff.length < 6 ? -.12 : 0);
      if (p.has('abroad')) d += head != null && trFF(head) > 0 ? .1 : -.1;
      if (p.has('local') && head != null && trFF(head) > .3) d -= .8;
      if (p.has('proud') && pres.age < p.age) d -= .08;
      if (p.has('bounce') && p.loy < 60) d += .3;
      // 社長との相性
      for (final c in PRES_COMPAT) {
        if (hasT(c.$1) && p.has(c.$2)) d += c.$3;
      }
      // 聞き上手がいると、不満をためた人に早く気づいて声をかける
      if (p.loy < 50 && otherTr(p, 'listen')) {
        d += .2;
        final l = staff.firstWhere((o) => o != p && o.away == 0 && o.has('listen'));
        if (lf.told.add('trw:${p.id}:$year')) {
          trSee(l, 'listen');
          N(M('聞き上手の{0}によると、{1}が不満をためているようです（辞める前に手を打てます）', [Nm(l.name), Nm(p.name)]), 'bad');
        }
      }
      if (p.has('fragile') && otherTr(p, 'mood')) p.health = math.min(100, p.health + .3);
      p.loy += d;
      if (p.grudge) p.loy = math.min(p.loy, 50);
      // 3. 特性から起きる出来事
      if (p.has('drunk') && tr() < .005) {
        scandal = math.max(scandal, 4);
        if (lifeOn) lf.brand = math.max(0, lf.brand - 3);
        p.loy -= 5;
        trSee(p, 'drunk');
        N(M('{0}が酒の席で騒ぎを起こし、週刊誌に載りました。会社の評判とブランドが下がりました', [Nm(p.name)]), 'bad');
        if (tr() < .3) _lose(p, 'drunk', N);
      }
      if (p.has('betting') && tr() < .003) {
        final x = p.salary * 6;
        cfAdd('sp', -x);
        scandal = math.max(scandal, 3);
        p.loy -= 10;
        trSee(p, 'betting');
        N(M('賭け事で借金を作った{0}が、会社のお金{1}を使い込んでいました', [Nm(p.name), Y(x)]), 'bad');
      }
      if (p.has('climb') && !p.partner && p.loy < 35 && p.tenure >= 24 && tr() < .02) {
        trSee(p, 'climb');
        fire(p, 'quit');
        N(M('出世欲の強い{0}が、自分の会社を作ると言って独立しました', [Nm(p.name)]), 'bad');
        continue;
      }
      if (p.has('local') && !p.partner && head != null && trFF(head) > .3 && p.loy < 30 && tr() < .1) {
        trSee(p, 'local');
        fire(p, 'quit');
        N(M('地元を離れたくない{0}が、海外の仕事を嫌って辞めました', [Nm(p.name)]), 'bad');
        continue;
      }
      if (p.has('money') && !p.partner && underpaid(p) && p.loy < 60 && tr() < .01) {
        trSee(p, 'money');
        fire(p, 'poached');
        N(M('お金で動く{0}が、よその会社の高い給料に釣られて移っていきました', [Nm(p.name)]), 'bad');
        continue;
      }
      if (p.has('social') && !p.partner && scandal >= 3 && lf.told.add('soc:${p.id}:$year') && tr() < .3) {
        trSee(p, 'social');
        fire(p, 'quit');
        N(M('会社の不祥事に嫌気がさし、{0}が辞めました', [Nm(p.name)]), 'bad');
        continue;
      }
      if (head != null && p.has('rough') && tr() < .01) {
        head.power *= .98;
        trSee(p, 'rough');
        N(M('大ざっぱな{0}のもとで、「{1}」で小さな事故が起きました', [Nm(p.name), I(head.ind)]), 'bad');
      }
      if (p.has('worrier') && crisis && lf.told.add('trwr:$year')) {
        trSee(p, 'worrier');
        N(M('心配性の{0}が、お金が危ないと早めに知らせてきました（経費を見直す手が早く打てます）', [Nm(p.name)]));
      }
      // 手の早さ（仕事が速い・せっかち・大ざっぱは早く、完璧主義の商品は遅い）
      for (final hb in biz.where((b) => b.mgr == p.id)) {
        for (final x in hb.pipe) {
          if (p.has('quick') && x.left > 1 && tr() < .3) x.left--;
          if ((p.has('hasty') || p.has('rough')) && const {'open', 'build', 'enter'}.contains(x.k) && x.left > 1 && tr() < .3) x.left--;
          if (p.has('perfect') && x.k == 'dev' && tr() < .25) x.left++;
        }
      }
      // 5. 経験で付く・消える（責任者を3年続けると面倒見がよくなることがある）
      if (p.headM >= 36 && p.headM % 12 == 0 && tr() < .3) _gain(p, 'mentor', N);
      if (q == 12) {
        if (p.has('late') && p.tenure >= 60 && tr() < .2) _lose(p, 'late', N);
        if (p.has('betting') && p.age > 55 && tr() < .15) _lose(p, 'betting', N);
      }
    }
    // 派閥: 頭のまわりに人が集まり、頭が2人いると揉める
    final leaders = staff.where((p) => p.real && p.away == 0 && p.has('faction')).toList();
    for (final l in leaders) {
      for (final o in staff) {
        if (o == l || !o.real || o.fac != null || o.has('faction') || o.partner) continue;
        if (tr() < .03) o.fac = l.id;
      }
    }
    if (leaders.length >= 2 && !events.any((e) => e.title == _quarrelTitle) && tr() < .025 * (anyTr('charisma') ? .5 : 1) * (anyTr('mediate') ? .5 : 1)) {
      final a = _tpick(leaders);
      final b = _tpick(leaders.where((x) => x != a).toList());
      events.add(_quarrel(a, b));
    }
    // 口が軽い人がいると、買収や新商品の話が漏れる
    final leak = staff.where((p) => p.away == 0 && p.has('leaky')).firstOrNull;
    if (leak != null && tr() < .012 * (anyTr('liar') ? 2 : 1)) _leak(leak, N);
    // 修羅場を越えると、肝が据わる（打たれ弱さが抜ける）
    if (q == 12) {
      if (trCrisisM >= 3) {
        for (final p in staff) {
          if (!p.real || tr() >= .3) continue;
          if (p.has('fragile')) _lose(p, 'fragile', N);
          _gain(p, 'steel', N);
        }
      }
      trCrisisM = 0;
    }
    for (final p in staff) {
      for (final t in trVisible(p)) {
        trFound.add(t);
      }
    }
  }

  static final String _quarrelTitle = M('派閥の揉めごと');

  /// 派閥の人（頭と、その派閥に入っている人）
  List<Person> _members(Person l) => staff.where((o) => o.fac == l.id).toList();

  GameEvent _quarrel(Person a, Person b) {
    final h = anyTr('mediate') ? .5 : 1.0;
    void side(Person w, Person l) {
      w.loy = math.min(99, w.loy + 5);
      for (final o in _members(w)) {
        o.loy = math.min(99, o.loy + 3);
      }
      l.loy -= 15 * h;
      for (final o in _members(l)) {
        o.loy -= 8 * h;
      }
    }

    trSee(a, 'faction');
    trSee(b, 'faction');
    final med = staff.where((o) => o.away == 0 && o.has('mediate')).firstOrNull;
    return GameEvent(
      title: _quarrelTitle,
      small: true,
      text: Cat([
        M('{0}の派閥と{1}の派閥が、社内で揉めています。', [Nm(a.name), Nm(b.name)]),
        if (med != null) M('仲裁役の{0}が間に入っているので、痛手は半分で済みそうです。', [Nm(med.name)]),
      ]),
      choices: [
        Choice(M('{0}の肩を持つ', [Nm(a.name)]), M('{0}の派閥はやる気が上がり、{1}の派閥は大きく下がる', [Nm(a.name), Nm(b.name)]), () {
          side(a, b);
          return M('{0}の肩を持ちました', [Nm(a.name)]);
        }),
        Choice(M('{0}の肩を持つ', [Nm(b.name)]), M('{0}の派閥はやる気が上がり、{1}の派閥は大きく下がる', [Nm(b.name), Nm(a.name)]), () {
          side(b, a);
          return M('{0}の肩を持ちました', [Nm(b.name)]);
        }),
        Choice(M('口を出さずに見送る'), M('両方の派閥のやる気が少し下がり、二人が率いる事業の力も少し落ちる'), () {
          for (final x in [a, b, ..._members(a), ..._members(b)]) {
            x.loy -= 4 * h;
          }
          for (final bz in biz) {
            if (bz.mgr == a.id || bz.mgr == b.id) bz.power *= 1 - .03 * h;
          }
          return M('揉めごとは長引きました');
        }),
      ],
    );
  }

  /// 情報漏れ（買う話があれば相手の株が買われて値が上がり、なければ新商品を宿敵に先回りされる）
  void _leak(Person p, void Function(String, [String]) N) {
    trSee(p, 'leaky');
    if (corp.deals.isNotEmpty) {
      final d = corp.deals.first;
      final c = coById(d.co);
      if (c == null) return;
      d.prem += .1;
      N(M('口の軽い{0}から買収の話が漏れ、{1}の株が買われて値が上がりました', [Nm(p.name), Nm(c.name)]), 'bad');
      return;
    }
    final bs = biz.where((b) => b.pipe.any((x) => x.k == 'dev' || x.k == 'open')).toList();
    if (bs.isEmpty) return;
    final b = _tpick(bs);
    final foes = cos.where((c) => c.alive && c.parent != 'player' && c.biz.any((x) => x.ind == b.ind)).toList();
    if (foes.isEmpty) return;
    final c = foes.firstWhere((x) => x.rival != null, orElse: () => _tpick(foes));
    for (final x in c.biz) {
      if (x.ind == b.ind) x.power *= 1.06;
    }
    N(M('口の軽い{0}から「{1}」の新商品の話が漏れ、{2}に先を越されました', [Nm(p.name), I(b.ind), Nm(c.name)]), 'bad');
  }

  // ===== 画面のための小道具 =====
  /// その人に関わる相性の文（社長との相性・部下どうしの相性。見えている特性の分だけ）
  List<String> trCompat(Person p) {
    final out = <String>[];
    final vis = trVisible(p);
    for (final c in PRES_COMPAT) {
      if (hasT(c.$1) && vis.contains(c.$2)) out.add(M(c.$4));
    }
    for (final c in STAFF_COMPAT) {
      if (c.$2 == 'new') {
        if (vis.contains(c.$1) || (p.tenure < 24 && staff.contains(p) && staff.any((o) => o != p && trVisible(o).contains(c.$1)))) out.add(M(c.$3));
        continue;
      }
      final mine = vis.contains(c.$1) ? c.$2 : (vis.contains(c.$2) ? c.$1 : null);
      if (mine == null) continue;
      if (staff.any((o) => o != p && trVisible(o).contains(mine))) out.add(M(c.$3));
    }
    return out;
  }
}
