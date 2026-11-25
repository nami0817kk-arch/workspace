// ignore_for_file: non_constant_identifier_names
part of 'game.dart';

// ===== 人（1.1.0+27 から。企画書「人を現実の人材に寄せる」の段3） =====
//
// 人は経歴（学歴・職歴・資格）・細かい能力（16）・人柄（誠実さ・ストレスへの強さ・協調性・挑戦好きか慎重か）・
// 暮らし（家族・健康）・気持ちと市場（やる気・給料の相場・業界での評判）を持つ。
//   生まれる: 採用の市場（新卒・中途・引き抜き）に候補として出る。数と質は景気・業種・会社の評判・場所で決まる
//   働く:     経験で能力が伸び、年をとると衰える。研修・留学でも伸びる。働かせすぎると健康を崩す
//   気持ち:   給料が相場より低い・任されない・社風が合わないとやる気が下がり、引き抜かれたり辞めたりする
//   辞める:   転職（国と時代の慣習で多さが違う）・引き抜き・燃え尽き・定年。辞めた人は「社外」に残り、呼び戻せる
// 給料の相場は、その国の平均賃金の統計（段1）に、能力・年功・資格・評判を掛けて決まる。
// 店長・指導員（段2）は人数で持ち、腕の平均（[Biz.lq]）と、辞めて空いた単位（[Biz.vac]）を持つ。
// 店長は新卒から育てるか、中途で雇う（中途の市場は転職の多い国・時代ほど厚い）。腕の良い店長は責任者に引き上げられる。
// 試作との一致を見る遊び（extras を切る）では、どれも動かさない（乱数も使わない）。

/// 1か月に中途で雇える店長の数を、事業ごとに数える（保存しない。月の初めに戻す）
final Expando<int> _leadHired = Expando('leadHired');

extension GamePeople on Game {
  bool get peopleOn => extras;

  // ===== 働き方の慣習 =====
  /// その国のその年の慣習（1980・2000・2025年の値をならす）
  WorkNorm normOf([String? c]) {
    final g = NORM_GROUP[c ?? home] ?? 'em';
    final t = NORM_TABLE[g]!;
    final y = yr();
    WorkNorm mix(WorkNorm a, WorkNorm b, double f) => WorkNorm(
      a.life + (b.life - a.life) * f,
      a.hop + (b.hop - a.hop) * f,
      a.senior + (b.senior - a.senior) * f,
      a.union + (b.union - a.union) * f,
      (a.retire + (b.retire - a.retire) * f).round(),
    );
    if (y <= 1980) return t[0];
    if (y <= 2000) return mix(t[0], t[1], (y - 1980) / 20);
    if (y <= 2025) return mix(t[1], t[2], (y - 2000) / 25);
    return t[2];
  }

  /// その国の平均賃金（円・年）
  double avgWageYen([String? c]) {
    final v = ev(c ?? home, 'wage_usd') * usdJpy();
    return v.isFinite && v > 0 ? v : 4e6 * nom();
  }

  /// その国の失業率（%）
  double unempOf([String? c]) {
    final v = ev(c ?? home, 'unemp');
    return v.isFinite ? clampD(v, .5, 30) : 5;
  }

  /// 解雇するときに払う、給料の何か月分か（終身雇用が強いほど重い）
  double severanceMonths() => 3 + normOf().life * 21;

  // ===== 会社の評判 =====
  /// 会社の評判（0〜100）。大きさ・上場・順位・年数で上がり、不祥事で下がる。採用の市場の質と数に効く
  double coRep() {
    var r = 25.0 + rep;
    r += 12 * clampD(math.log(math.max(cap, 1) / 1e9) / math.ln10 / 3, 0, 2);
    if (listed) r += 10;
    if (rank > 0 && rank <= 100) r += 8;
    if (rank > 0 && rank <= 10) r += 8;
    r += math.min(10, (yr() - startYear) * .5);
    r -= scandal * 4;
    return clampD(r, 0, 100);
  }

  // ===== 人を作る =====
  /// 今までの作り方（[Game.mkPerson]）で決めた4つの能力・特性・野心を芯に、経歴・細かい能力・人柄・暮らしを付ける
  void flesh(Person p, {double qq = 0}) {
    // 学歴（時代が進むほど大学が増える）
    final uni = clampD(.35 + (yr() - 1980) * .008, .3, .7);
    final r = rnd() + qq * .12;
    p.edu = r < (1 - uni) * .55
        ? 0
        : r < 1 - uni
        ? 1
        : r < 1 - uni * .3
        ? 2
        : r < 1 - uni * .08
        ? 3
        : 4;
    p.major = p.edu >= 1 ? pick(MAJOR_JA.keys.toList()) : null;
    // 細かい能力（4つの能力から散らし、専攻で伸ばす）
    final sk = <String, int>{};
    for (final e in SK_OF_AB.entries) {
      for (final k in e.value) {
        sk[k] = clampI((p.ab[e.key]! + (rnd() - .5) * 26).round(), 3, 99);
      }
    }
    final mid = (p.ab['ei']! + p.ab['zai']!) / 2;
    sk['lang'] = clampI((12 + rnd() * 40 + p.edu * 6).round(), 3, 99);
    sk['nInd'] = clampI((mid * .5 + rnd() * 25).round(), 3, 99);
    sk['nPol'] = clampI((5 + rnd() * 25).round(), 3, 99);
    sk['nBank'] = clampI((mid * .5 + rnd() * 20).round(), 3, 99);
    for (final k in MAJOR_SK[p.major] ?? const <String>[]) {
      sk[k] = math.min(99, sk[k]! + 8);
    }
    // 4つの能力は今までの値のまま（細かい能力の重みつきの平均を合わせる）
    final want = {for (final k in abKeys) k: p.ab[k]!};
    p.setSk({for (final k in skKeys) k: sk[k]!});
    final skm = p.sk!;
    for (final k in abKeys) {
      p.ab[k] = want[k]!;
    }
    // 職歴（卒業してからの年数を1〜3社に分ける）
    final gradAge = const [18, 20, 22, 22, 24][p.edu];
    var yrs = math.max(0, p.age - gradAge);
    final cats = <String>[for (final b in biz) indm[b.ind]!.cat];
    final cat0 = cats.isNotEmpty && rnd() < .5 ? pick(cats) : pick(CATN.ja.keys.toList());
    p.jobs = [];
    var nj = yrs <= 0 ? 0 : (yrs < 5 ? 1 : ri(1, 3));
    while (nj > 0 && yrs > 0) {
      final y = nj == 1 ? yrs : math.max(1, (yrs * (.3 + rnd() * .4)).round());
      final ageThen = p.age - yrs + y;
      final role = ageThen >= 45 && rnd() < .35
          ? 2
          : ageThen >= 33 && rnd() < .55
          ? 1
          : 0;
      p.jobs.add(Job(cat: rnd() < .65 ? cat0 : pick(CATN.ja.keys.toList()), size: ri(0, 2), role: role, years: y));
      yrs -= y;
      nj--;
    }
    // 資格
    p.lic = [];
    if (p.major == 'med' && p.edu >= 2 && rnd() < .7) p.lic.add('doctor');
    if (p.major == 'law' && p.edu >= 2 && rnd() < .25) p.lic.add('lawyer');
    if ((p.major == 'econ' || p.major == 'biz') && p.edu >= 2 && rnd() < .15) p.lic.add('cpa');
    if (rnd() < .02) p.lic.add('pilot');
    if (p.lic.contains('cpa')) skm['acct'] = math.max(skm['acct']!, 65);
    if (p.lic.contains('lawyer')) skm['law'] = math.max(skm['law']!, 70);
    // 技術の分野・外国語
    p.tf = switch (p.major) {
      'eng' => rnd() < .5 ? 'mech' : 'elec',
      'sci' => 'chem',
      'med' => 'med',
      'info' => 'soft',
      _ => CAT_TF[p.jobs.isNotEmpty ? p.jobs.last.cat : cat0] ?? 'soft',
    };
    final pools = {...NAMEC.values}..remove(homePool());
    p.lg = skm['lang']! >= 35 ? (rnd() < .65 && homePool() != 'en' ? 'en' : pick(pools.toList())) : null;
    // 人柄（特性と矛盾しないように）
    p.hon = p.trait == 'liar' ? ri(10, 40) : ri(40, 95);
    p.str = p.trait == 'stamina' ? ri(80, 99) : ri(20, 95);
    p.coop = p.trait == 'oneman' ? ri(10, 40) : ri(25, 95);
    p.pot = clampD(.6 + rnd() * .8 + (30 - p.age) / 40, .5, 1.6);
    // 暮らし
    p.married = p.age >= 26 && rnd() < clampD((p.age - 24) / 14, 0, .8);
    p.kidsAge = [];
    if (p.married && rnd() < .7) {
      final n = ri(1, 3);
      for (var i = 0; i < n; i++) {
        p.kidsAge.add(ri(0, math.max(0, p.age - 26)));
      }
      p.kidsAge.sort();
    }
    p.care = p.age >= 48 && rnd() < .12;
    p.health = clampD(62 + rnd() * 38 - math.max(0, p.age - 50) * .8, 30, 100);
    final years = p.jobs.fold(0, (a, j) => a + j.years);
    p.fame = clampI((8 + years * 1.2 + topSkill(p) / 3 + p.jobs.fold(0, (a, j) => a + j.role * 4)).round(), 0, 100);
    for (final k in skKeys) {
      p.off[k] = rnd();
    }
    p.known = [];
    if (hasT('charm')) p.known.add('hon');
    p.src ??= 'mid';
    // 給料は相場で決まる（叩き上げ・二枚舌は今までどおり安く出る）
    p.salary = jsRound(mktPay(p) * (.9 + rnd() * .2)).toDouble() * (p.trait == 'grit' || p.trait == 'liar' ? .85 : 1);
  }

  /// 若いまま会社に入る人（社長の子ども）の経歴を整える（職歴なし・大学を出たて）
  void freshGrad(Person p) {
    if (!p.real) return;
    p.jobs = [];
    p.married = false;
    p.kidsAge = [];
    p.care = false;
    p.lic.remove('pilot');
    p.fame = 5;
    p.src = 'grad';
  }

  // ===== 能力の見え方 =====
  /// いちばん得意な5つの平均（給料の相場・並べ替えに使う）
  double topSkill(Person p) {
    if (!p.real) return Game.totOf(p) / 4;
    final v = [for (final k in skKeys) p.sk![k]!]..sort((a, b) => b - a);
    return v.take(5).fold(0, (a, x) => a + x) / 5;
  }

  /// 細かい能力の幅（面接では幅だけ。働くと縮む。[Game.rangeOf] と同じ考え方）
  List<int> skRange(Person p, String k) {
    final v = p.sk?[k] ?? 0;
    final w = math.max(0, p.w - p.tenure * 2);
    if (w <= 0) return [v, v];
    final lo = clampI((v - w * (p.off[k] ?? .5)).round(), 1, 99);
    return [lo, clampI(lo + w, 1, 99)];
  }

  String showSk(Person p, String k) {
    final r = skRange(p, k);
    return r[0] == r[1] ? '${r[0]}' : '${r[0]}${L.en ? '-' : '〜'}${r[1]}';
  }

  /// 人柄・暮らしが分かっているか（社長の「人たらし」と、話を聞いた回数で分かる）
  bool knows(Person p, String k) => p.known.contains(k) || (k == 'amb' && p.ambKnown) || p.tenure >= 24;

  // ===== 給料の相場 =====
  /// 相場の給料（月）。平均賃金の統計×能力×年功×資格×評判（物価は平均賃金に入っている）
  double mktPay(Person p) {
    final n = normOf();
    final base = avgWageYen() / 12;
    final q = topSkill(p);
    var skillF = .7 + 1.4 * math.pow(q / 100, 2).toDouble();
    skillF = 1 + (skillF - 1) * (1 - .5 * n.senior);
    final ageF = 1 + n.senior * clampD((p.age - 25) / 30, 0, 1) * .6;
    final licF = p.lic.fold(1.0, (a, l) => math.max(a, LIC_PAY[l] ?? 1));
    final fameF = .9 + p.fame / 250;
    return base * .95 * skillF * ageF * licF * fameF;
  }

  /// 今の給料が相場の何倍か（1 なら相場どおり）
  double payRatio(Person p) {
    final m = mktPay(p);
    return m > 0 ? p.salary / m : 1;
  }

  // ===== 注意 =====
  /// 引き抜かれそうか（挑戦好きでやる気が下がっている・給料が相場より低い）
  bool poachRisk(Person p) => p.real && ((p.amb > 60 && p.loy < 60) || (underpaid(p) && p.loy < 70));

  /// 給料が相場より低くて不満のもとになっているか（相棒は株を持っているので、給料の低さでは不満を持たない）
  bool underpaid(Person p) => p.real && !p.partner && payRatio(p) < payLowRatio;

  /// 体を壊しそうか
  bool healthRisk(Person p) => p.real && p.away == 0 && p.health < healthWarn;

  /// 不満がたまっているか
  bool unhappy(Person p) => p.loy < 50 || underpaid(p);

  /// 海外に赴任させると断りがちか（学校に通う子どもがいる・親の介護をしている）
  bool refusesPosting(Person p) => p.real && (p.care || p.kidsAge.any((a) => a >= 6 && a <= 15));

  /// 休んでいる・研修や留学で外にいるか（責任者として働けない）
  bool isAway(Person p) => p.away > 0;

  // ===== 採用の市場 =====
  /// 今月の採用の市場（新卒・中途・引き抜きの人数と、候補の質の上げ下げ）
  ({int grad, int mid, int poach, double q}) hireMarket() {
    final n = normOf();
    final rp = coRep(), un = unempOf();
    var qq = (rp - 40) / 50 + (un - 4) / 12 + net * .1 + (culture == 'merit' ? .3 : 0) + (hasT('noble') ? -.5 : 0);
    // 伸びている業種（ネットと未来の分類が波に乗っている時）は人が集まる
    if (techBoom > 1.05 && biz.any((b) => techCats.contains(indm[b.ind]!.cat))) qq += .2;
    // 景気が良いと人が取り合いになり、質が下がる
    if (econ > 1.03) qq -= .2;
    // 新卒は、一括採用の国（日本・韓国）では4月にまとめて、ほかの国では少しずつ
    // （候補は月の終わりに作り、次の月に並ぶので、次の月で見る）
    final g = NORM_GROUP[home] ?? 'em';
    final nm = q % 12 + 1;
    final grad = g == 'jp' || g == 'kr'
        ? (nm == 4
              ? 3 + (rp / 35).floor()
              : nm == 10
              ? 1
              : 0)
        : (rnd() < .5 ? 1 : 0);
    final mid = clampI((1.5 + n.hop * 14 + (un - 4) * .3 + rp / 50).round(), 2, 6);
    final rivals = cos.where((c) => c.alive && c.parent != 'player').length;
    final poach = rivals == 0 ? 0 : clampI((rnd() * (1 + rp / 60)).floor(), 0, 2);
    return (grad: grad, mid: mid, poach: poach, q: qq);
  }

  /// 今月の採用の候補を作る（新卒・中途・引き抜き。資格のある人が出る月もある）
  List<Person> rollCands() {
    final m = hireMarket();
    final out = <Person>[];
    for (var i = 0; i < m.grad; i++) {
      final p = mkPerson(m.q - 1.4);
      p.age = ri(22, 24);
      p.src = 'grad';
      freshGrad(p);
      p.src = 'grad';
      // 新卒の給料は相場どおり（腕がまだ低く、年功の国では若いので安い）
      p.salary = jsRound(mktPay(p)).toDouble();
      p.loy = math.min(95, p.loy + normOf().life * 15);
      out.add(p);
    }
    for (var i = 0; i < m.mid; i++) {
      final p = mkPerson(m.q)..src = 'mid';
      out.add(p);
    }
    for (var i = 0; i < m.poach; i++) {
      final p = mkPerson(m.q + 1.3)..src = 'poach';
      final c = pick(cos.where((c) => c.alive && c.parent != 'player').toList());
      final cat = c.biz.isNotEmpty ? indm[c.biz.first.ind]!.cat : c.cat;
      p.jobs.add(Job(cat: cat, ind: c.biz.isNotEmpty ? c.biz.first.ind : null, size: 2, role: 1, years: ri(3, 10)));
      p.fame = math.min(100, p.fame + 15);
      p.salary = jsRound(mktPay(p) * 1.25).toDouble();
      p.loy = math.max(20, p.loy - 10);
      out.add(p);
    }
    // 資格の要る業種のために、資格のある人が中途に出る月がある
    if (rnd() < .35) {
      final l = pick(const ['doctor', 'doctor', 'pilot', 'lawyer', 'cpa']);
      final p = mkPerson(m.q)..src = 'mid';
      // 資格は1つにし、学歴と能力を資格に合わせる
      p.lic = [l];
      switch (l) {
        case 'doctor':
          p.major = 'med';
          p.tf = 'med';
          p.edu = math.max(p.edu, 2);
        case 'lawyer':
          p.major = 'law';
          p.edu = math.max(p.edu, 2);
          p.sk!['law'] = math.max(p.sk!['law']!, 70);
        case 'cpa':
          p.edu = math.max(p.edu, 2);
          p.major ??= 'econ';
          p.sk!['acct'] = math.max(p.sk!['acct']!, 65);
      }
      p.salary = jsRound(mktPay(p)).toDouble();
      out.add(p);
    }
    return out.take(9).toList();
  }

  /// 雇うときに払うお金（新卒は採用の費用、中途は紹介の手数料、引き抜きは高い手数料）
  double hireFeeOf(Person p) {
    if (!p.real) return p.salary * 2;
    return p.salary *
        switch (p.src) {
          'grad' => 1.0,
          'poach' => 5.0,
          'back' => 1.5,
          'lead' => 0.0,
          _ => 2.0,
        };
  }

  /// 資格が無くて始められない業種なら、その理由（始められるなら null）
  String? licMissing(String ind) {
    if (!peopleOn) return null;
    final l = IND_LIC[ind];
    if (l == null) return null;
    if (staff.any((p) => p.real && p.lic.contains(l) && p.away == 0)) return null;
    return M('「{0}」を始めるには{1}が要ります。「人」の画面の採用で、{1}の資格を持つ人を雇いましょう', [I(ind), D(LIC_JA[l]!)]);
  }

  // ===== 毎月 =====
  /// 名前のある部下の1か月（休み・健康・家族・給料への不満・辞める・不祥事）
  void monthPeople(void Function(String, [String]) N) {
    if (!peopleOn) return;
    final n = normOf();
    for (final p in staff.toList()) {
      if (!p.real) continue;
      final job = biz.where((b) => b.mgr == p.id).firstOrNull;
      // 休み・研修・留学
      if (p.away > 0) {
        p.away--;
        if (p.awayWhy == 'sick') p.health = math.min(100, p.health + 12);
        if (p.away == 0) {
          final why = p.awayWhy;
          p.awayWhy = null;
          if (why != null && why.startsWith('course:')) {
            final g = int.tryParse(why.substring(7)) ?? 0;
            for (final k in SK_GROUPS[clampI(g, 0, SK_GROUPS.length - 1)].$2) {
              p.sk![k] = math.min(99, p.sk![k]! + ri(3, 6));
            }
            N(M('{0}が研修から戻りました。{1}が伸びました', [Nm(p.name), D(SK_GROUPS[clampI(g, 0, SK_GROUPS.length - 1)].$1)]), 'good');
          } else if (why == 'abroad') {
            p.sk!['lang'] = math.min(99, p.sk!['lang']! + 18);
            for (final k in const ['judge', 'fin', 'mkt']) {
              p.sk![k] = math.min(99, p.sk![k]! + ri(4, 8));
            }
            p.lg ??= 'en';
            p.fame = math.min(100, p.fame + 10);
            p.amb = math.min(99, p.amb + 5);
            N(M('{0}が留学から戻りました。語学と経営の力が伸び、業界でも名が知られました（引き抜きに注意）', [Nm(p.name)]), 'good');
          } else {
            N(M('{0}が仕事に戻りました', [Nm(p.name)]));
          }
        }
        continue;
      }
      // 健康（責任者として大きな事業を見るほど、社風が体育会系なほど疲れる）
      var load = .3;
      if (job != null) load = .42 + .33 * math.min(1, unitTotal(job) / 60) + (job.war > 0 ? .1 : 0);
      if (culture == 'sports') load += .12;
      if (hasT('stamina')) load += .08;
      if (p.trait == 'stamina') load -= .2;
      p.health = clampD(p.health + (.55 - load) * (1.6 - p.str / 100) * 5 - (p.age > 55 ? .3 : 0), 0, 100);
      if (p.health < healthBreak && rnd() < .3) {
        if (p.amb > 70 && rnd() < .35) {
          fire(p, 'quit');
          N(M('{0}が燃え尽きて会社を辞めました', [Nm(p.name)]), 'bad');
          continue;
        }
        p.away = ri(2, 5);
        p.awayWhy = 'sick';
        N(M('{0}が体を壊して休みに入りました（{1}か月）。そのあいだ責任者の仕事はできません', [Nm(p.name), p.away]), 'bad');
        continue;
      }
      // 給料が相場より低いとやる気が下がる。高ければ少し上がる（相棒は株を持っているので下がらない）
      final pr = p.partner ? 1.0 : payRatio(p);
      if (pr < payLowRatio) {
        p.loy -= (payLowRatio - pr) * 6;
      } else if (pr > 1.1) {
        p.loy = math.min(99, p.loy + .2);
      }
      // 任される範囲（挑戦好きは任されるとやる気が出る）
      if (job != null && job.deleg && p.amb > 50) p.loy = math.min(99, p.loy + .15);
      // 家族
      if (!p.married && p.age >= 25 && p.age <= 40 && rnd() < .06 / 12) p.married = true;
      if (p.married && p.age < 45 && p.kidsAge.length < 3 && rnd() < .1 / 12) {
        p.kidsAge.insert(0, 0);
        final leave = clampD((year - 1995) / 40, 0, .5) + ((NORM_GROUP[home] ?? 'em') == 'eu' ? .2 : 0);
        if (rnd() < leave) {
          p.away = ri(1, 3);
          p.awayWhy = 'baby';
          N(M('{0}に子どもが生まれ、育児の休みに入りました（{1}か月）', [Nm(p.name), p.away]));
          continue;
        }
      }
      if (!p.care && p.age >= 45 && p.age <= 62 && rnd() < .02 / 12) {
        p.care = true;
        if (rnd() < .3) {
          p.away = ri(1, 2);
          p.awayWhy = 'care';
          N(M('{0}が親の介護で休みに入りました（{1}か月）', [Nm(p.name), p.away]));
          continue;
        }
      } else if (p.care && rnd() < .05 / 12) {
        p.care = false;
      }
      // 誠実さが低い責任者は不祥事を起こしやすい
      if (job != null && p.hon < 30 && rnd() < (30 - p.hon) / 30 * .004) {
        scandal = math.max(scandal, 3);
        job.power *= .97;
        if (!p.known.contains('hon')) p.known.add('hon');
        N(M('{0}が責任者の「{1}」で不祥事。誠実さに欠ける人でした', [Nm(p.name), I(job.ind)]), 'bad');
      }
      // 転職（国と時代の慣習。やる気が低いほど、給料が相場より低いほど辞めやすい）
      if (!p.partner && !events.any((e) => e.poach == p.id)) {
        var pq = n.hop / 12 * (p.loy >= 60 ? .5 : 1 + (60 - p.loy) / 30) * (pr < payLowRatio ? 1.8 : 1);
        if (p.tenure < 6) pq *= .3;
        if (rnd() < pq) {
          fire(p, 'quit');
          N(M('{0}が転職のため会社を辞めました', [Nm(p.name)]), 'bad');
        }
      }
    }
    if (q == 12) {
      for (final p in [...staff, ...alumni]) {
        if (!p.real) continue;
        for (var i = 0; i < p.kidsAge.length; i++) {
          p.kidsAge[i]++;
        }
      }
    }
  }

  /// 名前のある部下の1年（経験で伸び、年で衰える）。[Game] の年の初めに呼ぶ（年齢はもう1つ上がっている）
  void yearPerson(Person p) {
    if (!p.real) return;
    final sk = p.sk!;
    final job = biz.where((b) => b.mgr == p.id).firstOrNull;
    var g = p.age < 30
        ? 2.2
        : p.age < 40
        ? 1.5
        : p.age < 50
        ? .8
        : p.age < 56
        ? .3
        : 0.0;
    g *=
        p.pot *
        (culture == 'merit'
            ? 1.2
            : culture == 'family'
            ? .8
            : 1);
    for (final k in skKeys) {
      if (rnd() < .5) sk[k] = math.min(99, sk[k]! + (g * rnd() * 2).round());
    }
    if (job != null) {
      final ind = indm[job.ind]!;
      for (final k in SK_OF_AB[ind.key]!) {
        sk[k] = math.min(99, sk[k]! + ri(1, 3));
      }
      if (KIND_LEAD_JA[kindB(job)] != null) sk['ops'] = math.min(99, sk['ops']! + 1);
      sk['nInd'] = math.min(99, sk['nInd']! + 1);
      if (ctryOf(job).length > 1) sk['lang'] = math.min(99, sk['lang']! + 2);
      p.fame = math.min(100, p.fame + 1 + (job.rev > 0 && job.rh.isNotEmpty && job.rev > job.rh.first ? 1 : 0));
      // 同じ業界の経験として、職歴にこの会社での年を足す
      final own = p.jobs.where((j) => j.own && j.ind == job.ind).firstOrNull;
      if (own != null) {
        own.years++;
      } else {
        p.jobs.add(Job(cat: ind.cat, ind: job.ind, size: biz.length > 3 ? 2 : 1, role: 2, years: 1, own: true));
      }
    }
    if (p.age > 58 && p.trait != 'stamina') {
      for (final k in skKeys) {
        sk[k] = math.max(5, sk[k]! - ri(0, 2));
      }
    }
    // 毎年の給料の見直し: 世の中の賃金の伸び（統計）に合わせ、年功の強い国と時代は年の分も上がる
    // （相場より15%以上高い人は据え置く。出来事で上げた分が年ごとに積み上がらないように）
    final m = mktPay(p);
    // 腕が上がって相場より低くなった分は自動では上がらない（社長が「昇給」で埋める。埋めないと、やる気が下がり引き抜かれる）
    if (p.salary < m * 1.15) p.salary *= wageGrowth() * (p.age < 55 ? 1 + normOf().senior * .01 : 1);
  }

  /// 去年から今年への平均賃金（円）の伸び（年の給料の見直しに使う。為替で円の額が跳ねる年があるので、-10%〜+12% に抑える）
  double wageGrowth() {
    // 相場（[mktPay]）と同じく、その国の平均賃金（ドル）を円にした額で比べる
    double at(double y) => ev(home, 'wage_usd', y) * ev('jp', 'fx_usd', y);
    final a = at(yr() - 1), b = at(yr());
    return a > 0 && b.isFinite ? clampD(b / a, .9, 1.12) : 1;
  }

  /// 定年（国と時代の慣習。古い人の作り方でも同じ線を使う）
  int retireAge() => normOf().retire;

  // ===== 社長が人に打つ手 =====
  /// 給料を相場まで上げる（社長の時間 1時間）
  String raisePay(Person p) {
    if (!p.real) return M('今はこの手は使えません');
    final m = mktPay(p) * 1.02;
    if (p.salary >= m) return M('{0}の給料はもう相場を超えています', [Nm(p.name)]);
    final nt = spendT('raise');
    if (nt != null) return nt;
    final up = m / p.salary - 1;
    final add = m - p.salary;
    p.salary = jsRound(m).toDouble();
    p.loy = math.min(99, p.loy + clampD(up * 60, 3, 20));
    return M('{0}の給料を相場まで上げました（毎月 {1} 増える）。やる気が上がりました', [Nm(p.name), Y(add)]);
  }

  /// 話を聞く（社長の時間 1時間）。隠れた人柄・暮らしが1つ分かり、能力の幅が少し縮み、やる気が少し上がる。困っていることを話してくれる
  String talkTo(Person p) {
    final nt = spendT('talk');
    if (nt != null) return nt;
    final parts = <String>[];
    if (p.real) {
      final order = ['amb', 'hon', 'fam', 'str', 'coop', 'health'];
      final k = order.where((k) => !knows(p, k)).firstOrNull;
      if (k != null) {
        p.known.add(k);
        if (k == 'amb') p.ambKnown = true;
        parts.add(
          M('{0}が分かりました', [
            D(const {'amb': '挑戦好きか慎重か', 'hon': '誠実さ', 'fam': '家族のこと', 'str': 'ストレスへの強さ', 'coop': '協調性', 'health': '体の調子'}[k]!),
          ]),
        );
      }
      p.w = math.max(0, p.w - 4);
      if (p.loy < 70) p.loy += 2;
      if (payRatio(p) < payLowRatio) {
        parts.add(M('「給料が相場より低いと感じています（相場は月{0}）」', [Y(mktPay(p))]));
      } else if (p.health < healthWarn) {
        parts.add(M('「正直、疲れがたまっています」'));
      } else if (p.care) {
        parts.add(M('「親の介護で、家のことが大変です」'));
      } else if (p.kidsAge.any((a) => a < 3)) {
        parts.add(M('「子どもが小さくて、家のことも気になります」'));
      } else if (p.amb > 70 && !biz.any((b) => b.mgr == p.id)) {
        parts.add(M('「もっと大きな仕事を任せてほしい」'));
      } else {
        parts.add(M('「今の仕事に満足しています」'));
      }
    } else {
      p.w = math.max(0, p.w - 4);
      parts.add(M('「今の仕事に満足しています」'));
    }
    return Cat(
      [
        M('{0}と話しました', [Nm(p.name)]),
        ...parts,
      ],
      ja: '。',
      en: '. ',
    );
  }

  /// 研修の費用（分野1つ・1か月）・留学の費用（1年）
  double courseCost() => 6e5 * nom();
  double abroadCost() => 1.2e7 * nom();

  /// 研修（1か月、分野 [g] の能力が伸びる）か留学（[g] が -1。1年、語学と経営が伸び、名が知られる）に出す（社長の時間 1時間）
  String sendTraining(Person p, int g) {
    if (!p.real) return M('今はこの手は使えません');
    if (p.away > 0) return M('{0}は今、会社にいません', [Nm(p.name)]);
    final cost = g < 0 ? abroadCost() : courseCost();
    if (cash < cost) return M('お金が足りません');
    final nt = spendT('talk');
    if (nt != null) return nt;
    cash -= cost;
    p.away = g < 0 ? 12 : 1;
    p.awayWhy = g < 0 ? 'abroad' : 'course:$g';
    calcAll();
    return g < 0 ? M('{0}を1年の留学に出しました（{1}）。戻ると語学と経営の力が伸びます', [Nm(p.name), Y(cost)]) : M('{0}を{1}の研修に出しました（{2}・1か月）', [Nm(p.name), D(SK_GROUPS[g].$1), Y(cost)]);
  }

  /// 社外の人（前に辞めた人）を呼び戻す
  String rehire(Person p) {
    if (!alumni.contains(p)) return M('今はこの手は使えません');
    if (p.left == 'fired') return M('{0}は解雇した人なので、戻ってくれません', [Nm(p.name)]);
    if (p.age >= retireAge()) return M('{0}はもう引退しています', [Nm(p.name)]);
    p.src = 'back';
    p.salary = jsRound(mktPay(p) * 1.05).toDouble();
    final fee = hireFeeOf(p);
    if (cash < fee) return M('お金が足りません');
    final nt = spendT('hire');
    if (nt != null) return nt;
    cash -= fee;
    alumni.remove(p);
    p.left = null;
    p.tenure = math.max(p.tenure, 12);
    p.loy = math.max(p.loy, 60);
    staff.add(p);
    return M('{0}を呼び戻しました（毎月の給料 {1}）', [Nm(p.name), Y(p.salary)]);
  }

  /// 辞めた人を「社外」に残す（新しい順に8人まで）
  void toAlumni(Person p, String why) {
    if (!p.real || p.kid) return;
    p.left = why;
    p.away = 0;
    p.awayWhy = null;
    alumni.remove(p);
    alumni.insert(0, p);
    if (alumni.length > 8) alumni.removeLast();
  }

  // ===== 店長・指導員（段2の人数を、人の仕組みにつなぐ） =====
  /// 店長などの腕が売上に効く倍（腕が平均の50なら1。責任者のいない単位は売上が3割落ちる）
  double leadQF(Biz b) {
    if (!peopleOn) return 1;
    final m = headQF(b);
    if (KIND_LEAD_JA[kindB(b)] == null) return m;
    final u = unitTotal(b);
    final v = u > 0 ? clampD(b.vac / u, 0, 1) : 0.0;
    return m * (1 - .3 * v) * (.92 + b.lq / 625);
  }

  /// 事業の責任者の現場の腕（店舗運営・統率・生産管理のうち、その型に効くもの）が、店などの売れる量に効く倍（0.9〜1.1。腕50で1）。
  /// 責任者のいない事業は 1（客の数の側で、今までどおり弱くなる）
  double headQF(Biz b) {
    final p = mgrOf(b);
    if (p != null && p.real) {
      final k = kindB(b);
      final v = switch (k) {
        'shop' || 'license' => (p.sk!['ops']! + p.sk!['lead']!) / 2,
        'factory' || 'infra' => (p.sk!['prod']! + p.sk!['lead']!) / 2,
        'net' || 'hit' => (p.sk!['tech']! + p.sk!['mkt']!) / 2,
        _ => (p.sk!['lead']! + p.sk!['hr']!) / 2,
      };
      return 1 + (clampD(v, 0, 100) - 50) / 500;
    }
    return 1;
  }

  /// 中途で店長などを1か月に雇える数（転職の多い国・時代、失業の多い時、評判の良い会社ほど多い）
  int midLeadCap(Biz b) {
    final n = normOf();
    final popF = math.sqrt(clampD(ctryPop(home) / 1.2e8, .3, 3));
    final unF = clampD(unempOf() / 4, .5, 2.5);
    final repF = .6 + coRep() / 100;
    return math.max(0, (n.hop * 25 * popF * unF * repF).floor());
  }

  /// 今月まだ中途で雇える数
  int midLeadLeft(Biz b) => math.max(0, midLeadCap(b) - (_leadHired[b] ?? 0));

  /// 中途で雇う店長などの腕（市場の質）
  double midLeadQ() => clampD(45 + coRep() / 6 + (unempOf() - 4) * 1.5, 30, 80);

  /// 育てる店長などの腕（責任者の人事と統率の腕で上がる）
  double trainLeadQ(Biz b) {
    final p = staffById(b.mgr);
    final t = p != null && p.real ? (p.sk!['hr']! + p.sk!['lead']!) / 2 : (pres.ab['tou'] ?? 50).toDouble();
    return clampD(38 + t * .3 + (culture == 'merit' ? 4 : 0), 30, 85);
  }

  /// 中途で店長などを1人雇う費用（給料の上乗せと紹介の手数料）
  double midLeadCost(Biz b) => leadCost(b) / (KIND_LEAD_MONTHS[kindB(b)] ?? 6) * 4;

  /// 中途で店長などを n 人雇う（社長の時間 4時間。来月から店を任せられる）
  String hireLeads(Biz b, int n) {
    final lead = KIND_LEAD_JA[kindB(b)];
    if (lead == null || !unitsOn) return M('この事業には要りません');
    if (n <= 0) return M('雇う人数がありません');
    final left = midLeadLeft(b);
    if (left <= 0) return M('今月、中途で雇える{0}はもういません（終身雇用が強い国・時代は、中途の市場が薄い）', [D(lead)]);
    final m = math.min(n, left);
    final cost = midLeadCost(b) * m;
    if (cash < cost) return M('お金が足りません');
    final nt = spendT('crew');
    if (nt != null) return nt;
    cash -= cost;
    _leadHired[b] = (_leadHired[b] ?? 0) + m;
    b.pipe.add(Pipe(k: 'train', cost: cost, pw: m.toDouble(), left: 1, mul: midLeadQ()));
    presXp('tou', .6);
    calcAll();
    return M('{0}を中途で{1}人雇いました（{2}）。来月から店を任せられます', [D(lead), m, Y(cost)]);
  }

  /// 手の空いた店長などを1人、名前のある部下（責任者の候補）に引き上げる（社長の時間 2時間）
  String promoteLead(Biz b) {
    final lead = KIND_LEAD_JA[kindB(b)];
    if (lead == null || !unitsOn || !peopleOn) return M('この事業には要りません');
    if (b.leads < 1) return M('手の空いている{0}がいません', [D(lead)]);
    final nt = spendT('hire');
    if (nt != null) return nt;
    final p = mkPerson((b.lq - 50) / 20);
    p.age = ri(28, 45);
    p.src = 'lead';
    final ind = indm[b.ind]!;
    p.jobs = [Job(cat: ind.cat, ind: b.ind, size: biz.length > 3 ? 2 : 1, role: 1, years: ri(3, 10), own: true)];
    for (final k in const ['ops', 'lead', 'hr']) {
      p.sk![k] = math.min(99, p.sk![k]! + 10);
    }
    p.tenure = 12;
    p.w = math.max(0, p.w - 12);
    p.loy = math.max(p.loy, 72);
    p.salary = jsRound(mktPay(p)).toDouble();
    b.leads--;
    staff.add(p);
    ensureFaces();
    calcAll();
    return M('「{0}」の{1}から{2}を引き上げました（毎月の給料 {3}）。責任者や幹部に置けます', [I(b.ind), D(lead), Nm(p.name), Y(p.salary)]);
  }

  /// 店長など・本部の人が辞める（国と時代の慣習）。空いた単位は、手の空いた店長で埋める
  void monthLeads(Biz b, void Function(String, [String]) N) {
    if (!peopleOn) return;
    _leadHired[b] = 0;
    final n = normOf();
    final rate = n.hop / 12 * (1.3 - b.lq / 200) * (culture == 'family' ? .8 : 1) * (econ > 1.02 ? 1.2 : 1);
    // 本部の人
    if (b.sv > 0) {
      final ls = (b.sv * rate + rnd()).floor();
      if (ls > 0) b.sv = math.max(0, b.sv - ls);
    }
    if (KIND_LEAD_JA[kindB(b)] == null) return;
    final u = unitTotal(b);
    final staffed = math.max(0.0, u - b.vac);
    final lost = (staffed * rate + rnd()).floor();
    if (lost > 0) b.vac += lost;
    b.vac = clampD(b.vac, 0, u);
    final fill = math.min(b.vac, b.leads.toDouble()).floor();
    if (fill > 0) {
      b.vac -= fill;
      b.leads -= fill;
    }
    if (lost > 0 && b.vac >= 1) {
      N(M('「{0}」で{1}が{2}人辞め、{3}は責任者のいないまま回っています（売上が落ちます）', [I(b.ind), D(KIND_LEAD_JA[kindB(b)]!), lost, unitCountM(b, b.vac)]), 'bad');
    }
  }

  /// 育った・雇った店長などの腕を、今の平均に混ぜる
  void mixLeadQ(Biz b, int n, double q) {
    final have = math.max(0.0, unitTotal(b) - b.vac) + b.leads;
    final t = have + n;
    if (t > 0) b.lq = (b.lq * have + q * n) / t;
  }
}
