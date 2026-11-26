// ignore_for_file: non_constant_identifier_names
part of 'game.dart';

/// 現実に寄せる 段6（1.1.0+30）：残りの要素。
/// 税（減価償却・消費税・相続税）・設備の古び・ブランド・技術の世代・災害と保険・特許・時代ごとのIT・宣伝の手段・
/// 倒産のあとの立て直し・社会の移り変わり・社長の始め方と経歴・私生活・世間の顔。
///
/// ここの乱数は、ゲームの乱数（[Game.rng]）とは別の並び（[LifeState.seed]）から引く。
/// 足した要素が乱数を使っても、今までの出来事の並び（宿敵の動き・人の出入り）がずれないように

/// 減価償却の1口（毎月の額・残りの月）
class Dep {
  double m;
  int left;

  /// どの事業の設備か（事業の番号。null は会社全体のもの＝ITや、1.1.0+38 より前のセーブの口）。事業を手放すと一緒に外れる
  int? b;
  Dep(this.m, this.left, [this.b]);
  Map<String, dynamic> toJson() => {'m': m, 'l': left, if (b != null) 'b': b};
  factory Dep.fromJson(Map<String, dynamic> j) => Dep((j['m'] as num).toDouble(), (j['l'] as num).round(), (j['b'] as num?)?.round());
}

/// 特許（業種・切れる月・他社に使わせているか）
class Patent {
  String ind;
  int until;
  bool lic;
  Patent(this.ind, this.until, {this.lic = false});
  Map<String, dynamic> toJson() => {'i': ind, 'u': until, if (lic) 'l': true};
  factory Patent.fromJson(Map<String, dynamic> j) => Patent(j['i'] as String, (j['u'] as num).round(), lic: j['l'] == true);
}

/// 段6の状態（ゲームに1つ）
class LifeState {
  /// 別の乱数の並び（Park-Miller）
  int seed = 1;
  List<Dep> deps = [];

  /// ブランド（0〜100）・社長の世間の顔（0〜100）
  double brand = 10, fame = 0;

  /// 保険をかけているか
  bool insured = true;

  /// 入れたITの段（0 なし・1 POS・2 社内システム・3 ネット通販・4 スマホ・5 AI）
  int it = 0;
  List<Patent> patents = [];

  /// 事業ごとの設備の古さ（月）・乗っている技術の世代・大学と組んでいる期限の月
  Map<int, int> eqAge = {}, techGen = {}, uni = {};

  /// 社長の私生活（結婚・個人保証）・倒産のあと一度だけ立て直したか
  bool married = false, guarantee = true, restructured = false;

  /// 始め方（grad 大学を出てすぐ・work 会社員を何年かしてから）・勤めた年数と業種の分類
  String start = 'grad';
  int workYears = 0;
  String? workCat;

  /// 社長の経歴（学歴・職歴・細かい能力。段3の人の仕組みで作る）
  Person? bio;

  /// 業界団体の役職の期限（月）・消費税が上がってからの残りの月
  int assocUntil = 0, ctaxLeft = 0;

  /// 一度だけ出す知らせ（社会の流れ・ITの段・技術の世代など）
  Set<String> told = {};

  /// 月に1回までの手を最後に打った月（talk 取材・講演 / donate 寄付 / heard:人の番号 話を聞く → その月の turn。1.1.0+38）
  Map<String, int> did = {};

  LifeState();
  Map<String, dynamic> toJson() => {
        'seed': seed,
        'deps': deps.map((e) => e.toJson()).toList(),
        'brand': brand,
        'fame': fame,
        'ins': insured,
        'it': it,
        'pat': patents.map((e) => e.toJson()).toList(),
        'eq': eqAge.map((k, v) => MapEntry('$k', v)),
        'tg': techGen.map((k, v) => MapEntry('$k', v)),
        'uni': uni.map((k, v) => MapEntry('$k', v)),
        'mar': married,
        'gua': guarantee,
        'res': restructured,
        'start': start,
        'wy': workYears,
        if (workCat != null) 'wc': workCat,
        if (bio != null) 'bio': bio!.toJson(),
        'assoc': assocUntil,
        'ctax': ctaxLeft,
        'told': told.toList(),
        if (did.isNotEmpty) 'did': did,
      };
  static Map<int, int> _mi(Object? o) => {for (final e in ((o as Map?) ?? {}).entries) int.parse('${e.key}'): (e.value as num).round()};
  factory LifeState.fromJson(Map<String, dynamic>? j) {
    final s = LifeState();
    if (j == null) return s;
    s
      ..seed = (j['seed'] as num?)?.round() ?? 1
      ..deps = [for (final e in (j['deps'] as List? ?? [])) Dep.fromJson((e as Map).cast<String, dynamic>())]
      ..brand = (j['brand'] as num?)?.toDouble() ?? 10
      ..fame = (j['fame'] as num?)?.toDouble() ?? 0
      ..insured = j['ins'] != false
      ..it = (j['it'] as num?)?.round() ?? 0
      ..patents = [for (final e in (j['pat'] as List? ?? [])) Patent.fromJson((e as Map).cast<String, dynamic>())]
      ..eqAge = _mi(j['eq'])
      ..techGen = _mi(j['tg'])
      ..uni = _mi(j['uni'])
      ..married = j['mar'] == true
      ..guarantee = j['gua'] != false
      ..restructured = j['res'] == true
      ..start = (j['start'] as String?) ?? 'grad'
      ..workYears = (j['wy'] as num?)?.round() ?? 0
      ..workCat = j['wc'] as String?
      ..bio = j['bio'] == null ? null : Person.fromJson((j['bio'] as Map).cast<String, dynamic>())
      ..assocUntil = (j['assoc'] as num?)?.round() ?? 0
      ..ctaxLeft = (j['ctax'] as num?)?.round() ?? 0
      ..told = {for (final e in (j['told'] as List? ?? [])) e as String}
      ..did = {for (final e in ((j['did'] as Map?) ?? {}).entries) '${e.key}': (e.value as num).round()};
    return s;
  }
}

/// 時代ごとのIT（入る年・名前）。入ってから5年たつと「入れて当たり前」になり、入れていない会社は効率で負ける
const List<(int, String)> itEras = [(1982, 'POSレジ'), (1990, '社内のシステム'), (1998, 'ネット通販'), (2010, 'スマホ'), (2023, 'AI')];

/// 新しいITや宣伝の手段が広まるのが、日本より何年遅いか（文化の近さの組 [CULT_GROUP] ごと。1.1.0+38。前はどの国も日本と同じ年だった）。
/// 国ごとの細かい年は無いので、組ごとの目安（米英などは同じ・欧州と台湾韓国は1年・中国と東南アジア・中南米は3〜4年・インドとアフリカは5〜6年）
int techLag(String c) =>
    const {'jp': 0, 'kr': 1, 'tw': 1, 'cn': 3, 'sg': 0}[c] ??
    const {'an': 0, 'eu': 1, 'ea': 1, 'sea': 4, 'la': 4, 'ru': 4, 'me': 3, 'in': 5, 'af': 6}[CULT_GROUP[c]] ??
    3;

/// 宣伝の手段（時代ごと）。[c] の国では [techLag] だけ遅れて広まる
String adMediaOf(double y, [String c = 'jp']) {
  final yy = y - techLag(c);
  return yy < 1996
      ? 'テレビ・新聞・雑誌'
      : yy < 2008
          ? 'テレビとネット'
          : 'ネットとSNS';
}

/// 社会の移り変わり（名前・始まる年・強くなりきる年・分類ごとの追い風と逆風）。年は日本のもの。ほかの国は [socialLag] だけずらす
const List<(String, int, int, Map<String, double>)> socialTrends = [
  ('女性の社会進出', 1986, 2010, {'food': .06, 'live': .06}),
  ('少子高齢化', 1995, 2025, {'med': .15, 'live': .05, 'fun': -.05}),
  ('環境への関心', 2000, 2030, {'ene': -.08, 'fut': .1, 'make': -.03}),
  ('在宅勤務', 2020, 2024, {'net': .08, 'link': -.03}),
];

/// 社会の移り変わりが、その国では日本より何年遅いか（負は早い）。[i] は [socialTrends] の番号。
/// 文化の近さの組ごとの目安（1.1.0+38）：女性の社会進出は米英・欧州・旧社会主義の国が早く、少子高齢化は欧州が早くアジアの新興国・インド・アフリカは遅い。
/// 在宅勤務（感染症の年）はどの国も同じ
int socialLag(int i, String c) {
  const byCtry = <String, List<int>>{
    'jp': [0, 0, 0, 0],
    'cn': [-15, 15, 10, 0],
    'kr': [5, 10, 0, 0],
    'tw': [3, 8, 0, 0],
    'sg': [0, 10, 0, 0],
    'it': [-8, -5, -5, 0],
    'de': [-12, -5, -10, 0],
  };
  const byGroup = <String, List<int>>{
    'an': [-15, 10, -5, 0],
    'eu': [-10, 0, -5, 0],
    'ru': [-20, 0, 10, 0],
    'ea': [3, 10, 0, 0],
    'sea': [5, 25, 10, 0],
    'la': [5, 25, 10, 0],
    'in': [20, 35, 15, 0],
    'me': [25, 35, 15, 0],
    'af': [10, 40, 15, 0],
  };
  final l = byCtry[c] ?? byGroup[CULT_GROUP[c]] ?? const [0, 0, 0, 0];
  return i < l.length ? l[i] : 0;
}

/// 社会の移り変わりで、その業種の市場が何倍になるか（1 がそのまま）。[c] の国の年のずれを入れる
double socialF(Industry ind, double y, [String c = 'jp']) {
  var f = 1.0;
  for (var i = 0; i < socialTrends.length; i++) {
    final t = socialTrends[i];
    final d = t.$4[ind.cat];
    final s = t.$2 + socialLag(i, c);
    if (d == null || y < s) continue;
    f *= 1 + d * clampD((y - s) / math.max(1, t.$3 - t.$2), 0, 1);
  }
  return f;
}

/// 日本の消費税（上がった年・月・率）。ほかの国は付加価値税が前からあるとして、動きを入れない
const List<(int, int, double)> jpConsumptionTax = [(1989, 4, 3), (1997, 4, 5), (2014, 4, 8), (2019, 10, 10)];

/// 相続税の一番上の率（国と年。日本は1988年まで75%、2003年から50%、2015年から55%）
double inheritRate(String c, double y) {
  if (c == 'jp') {
    return y < 1988
        ? .75
        : y < 2003
            ? .7
            : y < 2015
                ? .5
                : .55;
  }
  return const {'us': .4, 'gb': .4, 'fr': .45, 'de': .3, 'kr': .5}[c] ?? .3;
}

extension GameLife on Game {
  LifeState get lf => life;

  /// 別の並びの乱数（0〜1）
  double lr() {
    lf.seed = lf.seed * 16807 % 2147483647;
    if (lf.seed <= 0) lf.seed += 2147483646;
    return (lf.seed - 1) / 2147483646;
  }

  bool get lifeOn => extras && unitsOn;

  // ===== はじめる =====
  /// 社長の始め方・経歴を作る（ゲームの乱数は使わない）
  void lifeInit(SetupConfig cfg) {
    if (!lifeOn) return;
    lf.seed = (fcSeed % 2147483646) + 1;
    lf.start = cfg.start;
    lf.workYears = cfg.start == 'work' ? clampI(cfg.workYears, 1, 15) : 0;
    lf.workCat = cfg.start == 'work' ? (cfg.workCat ?? 'live') : null;
    // 始めた年にもう当たり前のIT（出てから5年）は、はじめから入れてある（元手のうち。1.1.0+38。前は0から始まり、
    // 2000年に始めると2段・2025年は4段遅れの扱いで、毎月の売上から2〜4%を引かれていた）
    lf.it = itStdCount();
    // 経歴は段3の人の作り方で（乱数は別の並びに差し替えて引く）
    final r0 = rng, u0 = uidCounter;
    rng = _LifeRandom(this);
    try {
      final p = mkPerson(.4);
      p.name = pres.name;
      p.id = -1;
      p.age = 22 + lf.workYears;
      p.edu = math.max(2, p.edu);
      p.jobs = lf.workYears > 0 ? [Job(cat: lf.workCat!, size: 2, role: lf.workYears >= 8 ? 1 : 0, years: lf.workYears)] : [];
      lf.bio = p;
    } finally {
      rng = r0;
      uidCounter = u0;
    }
    if (lf.workYears > 0) {
      pres.age = 22 + lf.workYears;
      // 勤めた業界の腕・貯金・人脈
      final key = const {'food': 'ei', 'live': 'ei', 'make': 'kai', 'ene': 'kai', 'link': 'tou', 'money': 'zai', 'net': 'kai', 'med': 'kai', 'fun': 'ei', 'fut': 'kai'}[lf.workCat] ?? 'tou';
      pres.ab[key] = math.min(85, pres.ab[key]! + lf.workYears * 2);
      pres.ab['tou'] = math.min(80, pres.ab['tou']! + lf.workYears);
      cash += wageCat(lf.workCat!) * lf.workYears * .25;
      net += lf.workYears >= 5 ? 2 : 1;
    }
  }

  /// 社長の経歴が、その業種で効く倍（同じ分類で勤めた年数）
  double presExpF(Industry ind) {
    final p = lf.bio;
    if (!lifeOn || p == null) return 1;
    return 1 + math.min(.15, p.jobs.where((j) => j.cat == ind.cat).fold(0, (a, j) => a + j.years) * .015);
  }

  // ===== 税 =====
  /// 店・工場などにお金を使った（耐用年数で毎月の減価償却に分ける）
  /// [b] はその設備の事業（ITなど会社全体のものは null。1.1.0+38 から、事業を手放すと償却も一緒に外れる）
  void capSpend(double cost, double lifeYears, [Biz? b]) {
    if (!lifeOn || cost <= 0) return;
    final n = math.max(12, (lifeYears * 12).round());
    lf.deps.add(Dep(cost / n, n, b?.id));
    if (lf.deps.length > 400) {
      // 古い小さな口をまとめる（セーブが大きくならないように）。同じ事業の口どうしを先にまとめる
      lf.deps.sort((a, b) => a.left.compareTo(b.left));
      final a = lf.deps.removeAt(0);
      final j = lf.deps.indexWhere((x) => x.b == a.b);
      final c = lf.deps.removeAt(j < 0 ? 0 : j);
      lf.deps.add(Dep(a.m + c.m, math.max(a.left, c.left), a.b == c.b ? a.b : null));
    }
  }

  /// 手放した事業（売った・分社した・閉じた・相手に渡った）の設備の償却と、その業種の特許を外す（1.1.0+38）。
  /// 特許は事業と一緒に相手へ移る扱い（前は売ったあとも20年のあいだ使用料が入り、償却も決算書の設備も残った）。乱数は使わない
  void lifePrune() {
    if (!lifeOn) return;
    final ids = {for (final b in biz) b.id};
    final inds = {for (final b in biz) b.ind};
    lf.deps.removeWhere((d) => d.b != null && !ids.contains(d.b));
    lf.patents.removeWhere((p) => !inds.contains(p.ind));
  }

  /// 今月の減価償却（税の計算で利益から引く）
  double depMonth() => lifeOn ? lf.deps.fold(0.0, (s, d) => s + d.m) : 0;

  /// 今の消費税の率（%）
  double consumptionTax([String? c]) {
    final cc = c ?? home;
    if (cc != 'jp') return 0;
    final y = yr();
    var r = 0.0;
    for (final t in jpConsumptionTax) {
      if (y >= t.$1 + (t.$2 - 1) / 12) r = t.$3;
    }
    return r;
  }

  // ===== 月の動き（nextQuarter から） =====
  void lifeMonthly(void Function(String, [String]) N) {
    if (!lifeOn) return;
    final y = yr();
    // 減価償却の口を進める
    for (final d in lf.deps) {
      d.left--;
    }
    lf.deps.removeWhere((d) => d.left <= 0);
    // 消費税の引き上げ（その月だけ知らせ、半年は一般の客の買い控え）
    if (home == 'jp') {
      for (final t in jpConsumptionTax) {
        if (year == t.$1 && q == t.$2 && lf.told.add('ctax${t.$1}')) {
          lf.ctaxLeft = 6;
          N(M('消費税が{0}%になりました。しばらく一般の客の買い控えが続きます', [jsNum(t.$3)]), 'bad');
          chron('era', M('消費税が{0}%になった', [jsNum(t.$3)]));
        }
      }
    }
    if (lf.ctaxLeft > 0) lf.ctaxLeft--;
    // 社会の移り変わり（始まったときに一度だけ）
    // （1.1.0+38 から、国ごとの年のずれを入れる）
    for (var i = 0; i < socialTrends.length; i++) {
      final t = socialTrends[i];
      final s0 = t.$2 + socialLag(i, home);
      if (y >= s0 && y < s0 + 1 && lf.told.add('soc:${t.$1}')) {
        N(M('世の中の流れ：「{0}」が進み始めました。業種によって追い風と逆風になります', [M(t.$1)]), 'big');
        chron('era', M('「{0}」が進み始めた', [M(t.$1)]));
      }
    }
    // 時代のIT（入ってきたとき・当たり前になったとき。国ごとの広まる年のずれを入れる。1.1.0+38）
    for (var i = 0; i < itEras.length; i++) {
      final e = itEras[i];
      final y0 = itYear(i);
      if (y >= y0 && lf.told.add('it:$i') && y < y0 + 1) N(M('新しいIT「{0}」が出てきました。早く入れた会社から効率が上がります', [M(e.$2)]), 'big');
      if (y >= y0 + 5 && lf.it <= i && y < y0 + 6 && lf.told.add('itStd:$i') && biz.isNotEmpty) {
        N(M('「{0}」はもう当たり前になりました。入れていないと効率で負けます', [M(e.$2)]), 'bad');
      }
    }
    // 設備の古び・技術の世代
    for (final b in biz) {
      lf.eqAge[b.id] = (lf.eqAge[b.id] ?? 0) + 1;
      final ind = indm[b.ind]!;
      final cur = techCur(ind);
      final mine = lf.techGen[b.id] ??= cur;
      if (cur > mine && lf.told.add('tg:${b.id}:$cur')) {
        N(M('「{0}」で新しい世代の技術が出ました。乗り換えないと客が離れていきます', [I(b.ind)]), 'bad');
      }
      if (eqOver(b) > 0 && lf.told.add('eq:${b.id}:${(lf.eqAge[b.id]! / 60).floor()}')) {
        N(M('「{0}」の設備が古くなってきました。修繕の費用が増え、客も離れます', [I(b.ind)]), 'bad');
      }
    }
    lf.eqAge.removeWhere((k, _) => !biz.any((b) => b.id == k));
    lf.techGen.removeWhere((k, _) => !biz.any((b) => b.id == k));
    // ブランド（宣伝・会社の大きさ・世間の顔で上がり、不祥事で下がる。何もしないと少しずつ薄れる）
    final ads = biz.where((b) => b.ad > 0).length;
    final size = clampD(math.log(math.max(rev, 1) / (1e8 * nom())) / math.ln10, 0, 3);
    lf.brand = clampD(lf.brand * .995 + ads * .5 * adMediaF() + size * .12 + lf.fame * .01 - (scandal > 0 ? .6 : 0), 0, 100);
    lf.fame = clampD(lf.fame * .99 + (turn < lf.assocUntil ? .4 : 0), 0, 100);
    // 宣伝の炎上（SNS の時代）
    if (ads > 0 && y >= 2008 && lr() < .004 * ads) {
      lf.brand = math.max(0, lf.brand - 6);
      N(M('SNSの宣伝が炎上し、ブランドに傷がつきました'), 'bad');
    }
    // ITの障害・情報漏れ・乗っ取り（入れているほど起きうる）
    if (lf.it >= 3 && biz.isNotEmpty && lr() < .002 * (lf.it - 2)) {
      final what = ['システムの障害', '顧客情報の漏れ', 'システムの乗っ取り'][(lr() * 3).floor()];
      final loss = math.max(0.0, rev) * .2;
      cfAdd('sp', -loss);
      lf.brand = math.max(0, lf.brand - 5);
      N(M('{0}が起き、{1}の損と信用の傷を負いました', [M(what), Y(loss)]), 'bad');
    }
    // 特許の期限・使用料
    for (final p in lf.patents.toList()) {
      if (turn >= p.until) {
        lf.patents.remove(p);
        N(M('「{0}」の特許が切れました。もう真似を止められません', [I(p.ind)]), 'bad');
      } else if (p.lic) {
        cfAdd('nonop', patentFee(p));
      }
    }
    // 他社の特許に触れて訴えられる（技術の要る業種で、自社の特許が無いとき）
    for (final b in biz) {
      final ind = indm[b.ind]!;
      if (!patentInd(ind) || lf.patents.any((p) => p.ind == b.ind) || b.age < 24) continue;
      if (lr() < .0015 && !events.any((e) => e.title == M('特許で訴えられた'))) events.add(evSued(b));
    }
    // 個人保証（上場するか、借金が無くなると外れる）
    if (lf.guarantee && (listed || debt <= 0) && biz.isNotEmpty && lf.told.add('guar')) {
      lf.guarantee = false;
      N(M('会社の借金への社長の個人保証が外れました'), 'good');
    }
    if (!lf.guarantee && !listed && debt > 0) lf.guarantee = true;
    // 私生活：結婚（年の終わりに）
    if (q == 12 && !lf.married && pres.age >= 25 && pres.age <= 40 && lr() < .2) {
      lf.married = true;
      N(M('{0}が結婚しました', [Nm(pres.name)]), 'good');
      chron('pres', M('{0}が結婚した', [Nm(pres.name)]));
    }
  }

  // ===== 計算（calcAll から） =====
  /// 事業の力にかける倍（ブランド・設備の古び・技術の世代・消費税の買い控え・特許・宣伝の手段・社長の経歴）
  double lifePowF(Biz b) {
    if (!lifeOn) return 1;
    final ind = indm[b.ind]!;
    final b2c = profileOf(ind).cust == 'b2c';
    var f = 1.0;
    if (b2c) f *= .92 + lf.brand / 600;
    f *= 1 - .12 * math.min(1, eqOver(b));
    final behind = techBehind(b);
    if (behind > 0) f *= math.pow(.88, math.min(3, behind)).toDouble();
    if (b2c && lf.ctaxLeft > 0) f *= 1 - .05 * lf.ctaxLeft / 6;
    if (lf.patents.any((p) => p.ind == b.ind && !p.lic)) f *= 1.06;
    if (b.ad > 0 && !b2c) f *= adMediaF(b2b: true);
    if (mgrOf(b) == null) f *= presExpF(ind);
    return f;
  }

  /// 利益から引く分（設備の古びの修繕・ITの遅れ・保険をかけないなら保険料が浮く）
  double lifeCost(Biz b) {
    if (!lifeOn) return 0;
    var c = 0.0;
    final fx = fixOf[b.id];
    if (fx != null) {
      c += fx[4] * 1.5 * math.min(2, eqOver(b));
      if (!lf.insured) c -= fx[3];
    }
    c += b.rev * .01 * itBehind();
    return c;
  }

  // ===== 設備の古び =====
  /// 設備が寿命の7割を過ぎた割合（0 はまだ新しい・1 で寿命の1.7倍）
  double eqOver(Biz b) {
    if (!lifeOn) return 0;
    final life = profileOf(indm[b.ind]!).life * 12;
    return math.max(0.0, (lf.eqAge[b.id] ?? 0) / life - .7);
  }

  /// 新しく開いた分だけ、設備の平均の古さが若くなる
  void eqMix(Biz b, double added) {
    if (!lifeOn) return;
    final n = unitTotal(b);
    if (n <= 0) return;
    lf.eqAge[b.id] = ((lf.eqAge[b.id] ?? 0) * math.max(0, n - added) / n).round();
  }

  double renewCost(Biz b) => math.max(unitTotal(b), 1) * unitCapexAvg(b) * .35;

  /// 設備を新しくできないわけ（耐用年数の半分を過ぎるまでは、払っても古さが少し戻るだけなので押せない。1.1.0+38）。できれば null
  String? renewWhy(Biz b) {
    final life = profileOf(indm[b.ind]!).life;
    final age = lf.eqAge[b.id] ?? 0;
    if (age < life * 12 * .5) return M('設備はまだ新しいです（古さ{0}年・耐用{1}年の半分を過ぎてから）', [(age / 12).floor(), jsNum(jsRound(life))]);
    return null;
  }

  /// 設備を新しくする
  String renewEquip(Biz b) {
    final why = renewWhy(b);
    if (why != null) return why;
    final cost = renewCost(b);
    if (cash < cost) return M('お金が足りません');
    final nt = spendT('build');
    if (nt != null) return nt;
    cfAdd('capex', -cost);
    capSpend(cost, profileOf(indm[b.ind]!).life, b);
    lf.eqAge[b.id] = 0;
    presXp('kai', 2);
    calcAll();
    return M('「{0}」の設備を新しくしました（{1}）', [I(b.ind), Y(cost)]);
  }

  // ===== 小さな知らせ =====
  /// 選ばれないまま月が替わった小さな知らせを、断る・見送る方で片付ける（その結果の文を返す）
  List<String> settleSmall() {
    final out = <String>[];
    for (final e in events.where((e) => e.small).toList()) {
      events.remove(e);
      final ch = e.choices.where((c) => RegExp('却下|断る|見送').hasMatch(msgKey(c.l))).firstOrNull ?? e.choices.last;
      out.add(ch.f());
    }
    return out;
  }

  // ===== 赤字の店などを閉める =====
  /// 閉める費用（解約金と原状回復。1単位で家賃などの固定費の4か月分）
  double closeCost(Biz b, String s, int n) {
    final st = b.sites[s];
    if (st == null || st.n <= 0) return 0;
    return siteFixed(b, s) / st.n * 4 * n;
  }

  /// その立地の育ちきった店などを n 単位閉める（赤字の店を減らして、残りの店の取り合いも和らげる）
  String closeUnits(Biz b, String s, int n) {
    final st = b.sites[s];
    if (st == null || st.n < n || n <= 0) return M('閉める店などがありません');
    if (unitTotal(b) - n < 1) return M('最後の1つは閉められません（事業ごと売ってください）');
    final cost = closeCost(b, s, n);
    final nt = spendT('build');
    if (nt != null) return nt;
    cfAdd('sp', -cost);
    st.n -= n;
    if (st.n <= 0) b.sites.remove(s);
    calcAll();
    return M('{0}の{1}を閉めました（解約金と原状回復 {2}）', [siteNameM(s), unitCountM(b, n.toDouble()), Y(cost)]);
  }

  /// 赤字の立地（育ちきった店などがあり、1単位の月の利益がマイナス）。悪い順
  List<String> losingSites(Biz b) => (b.sites.keys.where((s) => (b.sites[s]?.n ?? 0) >= 1 && siteUnitProfit(b, s) < 0).toList()
    ..ssort((x, y) => siteUnitProfit(b, x).compareTo(siteUnitProfit(b, y))));

  // ===== 技術の世代 =====
  /// 技術の世代が変わる業種か（技術の寿命が12年以下）
  bool techInd(Industry ind) => profileOf(ind).techLife <= 12;

  /// 今の世代の番号
  int techCur(Industry ind) => techInd(ind) ? math.max(0, ((yr() - ind.b) / profileOf(ind).techLife).floor()) : 0;

  int techBehind(Biz b) => lifeOn ? math.max(0, techCur(indm[b.ind]!) - (lf.techGen[b.id] ?? techCur(indm[b.ind]!))) : 0;

  double techCost(Biz b) => (math.max(unitTotal(b), 1) * unitCapexAvg(b) * .25 + capexOf(indm[b.ind]!) * .5) * (anyTr('novelty') ? .8 : 1);

  /// 新しい世代の技術に乗り換える
  String upgradeTech(Biz b) {
    if (techBehind(b) <= 0) return M('今の世代の技術に乗っています');
    final cost = techCost(b);
    if (cash < cost) return M('お金が足りません');
    final nt = spendT('dev');
    if (nt != null) return nt;
    cfAdd('capex', -cost);
    capSpend(cost, profileOf(indm[b.ind]!).techLife, b);
    lf.techGen[b.id] = techCur(indm[b.ind]!);
    presXp('kai', 4);
    calcAll();
    return M('「{0}」を新しい世代の技術に乗り換えました（{1}）', [I(b.ind), Y(cost)]);
  }

  // ===== IT =====
  /// 今出ているITの段
  int itAvail() => [for (var i = 0; i < itEras.length; i++) i].where((i) => yr() >= itYear(i)).length;

  /// その段のITが、自分の国に出てくる年（日本の年＋[techLag]。1.1.0+38）
  int itYear(int i) => itEras[i].$1 + techLag(home);

  /// 今の年に、もう当たり前（出てから5年）になっている段の数
  int itStdCount() => [for (var i = 0; i < itEras.length; i++) i].where((i) => yr() >= itYear(i) + 5).length;

  /// 当たり前になったのに入れていない段の数
  int itBehind() => lifeOn && biz.isNotEmpty ? math.max(0, itStdCount() - lf.it) : 0;

  double itCost() => ((2e7 * (1 + biz.length) + 0) * nom() + math.max(0.0, rev) * .6) * (anyTr('novelty') ? .8 : 1);

  String adoptIT() {
    final a = itAvail();
    if (a <= lf.it) return M('今出ているITはもう入れています');
    final cost = itCost();
    if (cash < cost) return M('お金が足りません');
    final nt = spendT('it');
    if (nt != null) return nt;
    cfAdd('capex', -cost);
    capSpend(cost, 5);
    lf.it = a;
    presXp('kai', 3);
    calcAll();
    return M('「{0}」を入れました（{1}）', [M(itEras[a - 1].$2), Y(cost)]);
  }

  // ===== 宣伝の手段 =====
  /// 今の時代の宣伝の効き（一般の客には今の手段がよく効き、会社の客にはテレビの時代は効きにくい）
  double adMediaF({bool b2b = false}) {
    // 国ごとの広まる年のずれを入れる（1.1.0+38）
    final y = yr() - techLag(home);
    if (b2b) return y < 1996 ? .85 : 1;
    return y < 1996
        ? 1
        : y < 2008
            ? 1.05
            : 1.1;
  }

  // ===== 災害と保険 =====
  /// 災害で店や工場が傷んだ（保険をかけていれば8割が戻る）
  void disasterHit(String c, double unitLoss, void Function(String, [String]) N) {
    if (!lifeOn) return;
    var dmg = 0.0;
    for (final b in biz) {
      dmg += unitsIn(b, c) * unitCapexAvg(b) * unitLoss * 1.5;
    }
    if (dmg <= 0) return;
    // 危機に強い人がいると、立て直しが早く痛手が小さい（1.1.0+33）
    if (anyTr('crisis')) dmg *= .5;
    final pay = lf.insured ? dmg * .2 : dmg;
    cfAdd('sp', -pay);
    N(M(lf.insured ? '店や工場の修理に{0}かかり、保険で8割が戻りました（自社の負担 {1}）' : '店や工場の修理に{0}かかりました。保険をかけていないので全部自社の負担です', [Y(dmg), Y(pay)]), lf.insured ? '' : 'bad');
  }

  String setInsured(bool on) {
    lf.insured = on;
    calcAll();
    return M(on ? '保険をかけました。保険料がかかる代わりに、災害の修理の8割が戻ります' : '保険をやめました。保険料が浮く代わりに、災害の修理は全部自社の負担です');
  }

  // ===== 特許 =====
  /// 特許が取れる業種（技術で勝負する分類）
  bool patentInd(Industry ind) => const {'make', 'med', 'net', 'fut', 'ene', 'link'}.contains(ind.cat);

  /// 新商品が大当たりしたとき、技術の業種なら特許が取れる（20年）
  void patentOnHit(Biz b, void Function(String, [String]) N) {
    if (!lifeOn || !patentInd(indm[b.ind]!) || lf.patents.where((p) => p.ind == b.ind).length >= 3) return;
    lf.patents.add(Patent(b.ind, turn + 240));
    N(M('「{0}」の新商品で特許を取りました。20年のあいだ真似されません', [I(b.ind)]), 'good');
  }

  /// 他社に特許を使わせたときの毎月の使用料
  double patentFee(Patent p) => mkt(indm[p.ind]!) * .0004;

  String licensePatent(Patent p) {
    p.lic = !p.lic;
    calcAll();
    return M(p.lic ? '「{0}」の特許を他社に使わせ、毎月{1}の使用料を受け取ります（真似を止める力はなくなります）' : '「{0}」の特許を他社に使わせるのをやめました', [I(p.ind), Y(patentFee(p))]);
  }

  /// 大学や研究所と組む（3年のあいだ、新商品の当たりやすさが上がる）
  double uniCost() => 3e7 * nom();
  String uniLab(Biz b) {
    final cost = uniCost();
    if (cash < cost) return M('お金が足りません');
    final nt = spendT('deal');
    if (nt != null) return nt;
    cfAdd('grow', -cost);
    lf.uni[b.id] = turn + 36;
    return M('「{0}」で大学と組みました（3年・{1}）。新商品が当たりやすくなります', [I(b.ind), Y(cost)]);
  }

  double uniBonus(Biz b) => lifeOn && (lf.uni[b.id] ?? 0) > turn ? .06 : 0;

  GameEvent evSued(Biz b) {
    final settle = math.max(0.0, b.rev) * 2;
    return tagEv(_evSued(b, settle), 'sued', {'b': b.id});
  }

  GameEvent _evSued(Biz b, double settle) {
    return GameEvent(title: M('特許で訴えられた'), text: M('「{0}」が他社の特許に触れていると訴えられました。', [I(b.ind)]), choices: [
      Choice(M('和解する'), M('{0}を払って終わらせる', [Y(settle)]), () {
        cfAdd('sp', -settle);
        return M('和解しました');
      }),
      Choice(M('争う'), M('勝てば何も払わない。負けると和解の倍を払う'), () {
        if (lr() < .5) return M('裁判に勝ちました');
        cfAdd('sp', -(settle * 2));
        return M('裁判に負け、{0}を払いました', [Y(settle * 2)]);
      }),
    ]);
  }

  // ===== 世間の顔 =====
  String takeIndustryPost() {
    if (turn < lf.assocUntil) return M('もう業界団体の役職に就いています');
    final nt = spendT('assoc');
    if (nt != null) return nt;
    lf.assocUntil = turn + 24;
    net += 1;
    lf.fame = math.min(100, lf.fame + 5);
    return M('業界団体の役職に就きました（2年）。人脈と評判が広がります');
  }

  /// 月に1回までの手を、今月もう打ったか（1.1.0+38）
  bool didThisMonth(String k) => lf.did[k] == turn;

  /// 評判・ブランドを上げる手の効き目。高くなるほど上がりにくい（100に近いほど0に近づく。1.1.0+38。前は同じ月に何度でも打てて、1か月で100まで届いた）
  double _gain(double now, double add) => math.min(100, now + add * math.max(0.0, 1 - now / 100));

  String giveTalk() {
    if (didThisMonth('talk')) return M('取材・講演は月に1回までです。来月また受けられます');
    final nt = spendT('media');
    if (nt != null) return nt;
    lf.did['talk'] = turn;
    lf.fame = _gain(lf.fame, 4);
    lf.brand = _gain(lf.brand, 2);
    if (lr() < .05) {
      lf.brand = math.max(0, lf.brand - 10);
      scandal = math.max(scandal, 3);
      return M('取材で失言し、会社の評判ごと落ちました');
    }
    return M('取材と講演で名前が知られました');
  }

  double donateCost() => math.max(1e7 * nom(), cap * .001);
  String donate() {
    if (didThisMonth('donate')) return M('寄付は月に1回までです。来月また寄付できます');
    final cost = donateCost();
    if (cash < cost) return M('お金が足りません');
    final nt = spendT('donate');
    if (nt != null) return nt;
    lf.did['donate'] = turn;
    cfAdd('misc', -cost);
    lf.fame = _gain(lf.fame, 6);
    lf.brand = _gain(lf.brand, 3);
    return M('{0}を寄付しました。評判が上がりました', [Y(cost)]);
  }

  // ===== 相続税 =====
  /// 子どもが継ぐと、社長の持ち株に相続税がかかり、払うために株の一部を手放す（事業を継ぐための軽減で半分にする）
  void inheritTax(Person heir, void Function(String, [String])? N) {
    if (!lifeOn || !heir.kid || sh.own <= 0) return;
    final r = inheritRate(home, yr());
    final sold = sh.own * r * .5;
    final value = cap * sold / 100;
    sh.own -= sold;
    if (listed) {
      sh.float += sold;
    } else {
      sh.vc += sold;
    }
    final m = M('相続税（最高{0}%）を払うため、{1}が株を{2}手放しました（{3}）', [jsNum(jsRound(r * 100)), Nm(heir.name), pct(sold), Y(value)]);
    N?.call(m, 'bad');
    chron('pres', m);
  }

  // ===== 倒産のあとの立て直し =====
  /// 資金が尽きたとき、一度だけ民事再生で立て直す（借金の6割を減らし、社長は退く。株主の取り分は大きく減り、個人保証で社長の財産も失う）
  bool restructure(void Function(String, [String]) N) {
    if (!lifeOn || lf.restructured || biz.isEmpty) return false;
    lf.restructured = true;
    for (final l in loans) {
      l.amt *= .4;
      l.left = math.max(l.left, 60);
    }
    final shortNow = -math.min(0.0, cash);
    // 決算書：足りない分を借りて埋めた（借金の6割の減免は、借金の動きから「借金の減免」に入る。1.1.0+34）
    cfTag = 'borrow';
    cash = 0;
    if (shortNow > 0) loans.add(Loan(id: ++loanSeq, lender: 'main', amt: shortNow, orig: shortNow, rate: loanRate() + .02, left: 60, term: 60, at: turn));
    // 支援する会社が、減った分の株を持つ
    final lost = sh.own * .6;
    sh.own -= lost;
    if (listed) {
      sh.float += lost;
    } else {
      sh.vc += lost;
    }
    if (lf.guarantee) spendWealth(wealth);
    bankCtl = 36;
    bankDone = true;
    missed = 12;
    final heir = (staff.where((p) => p.age < 65).toList()..ssort((a, b) => Game.totOf(b) - Game.totOf(a))).firstOrNull;
    final old = pres.name;
    if (heir != null) takeOver(heir);
    // 立て直しを乗り切ると、社長の腕が多めに伸びる（1.1.0+32。game_pres.dart）
    pres.crisis = 2;
    N(M('資金が尽き、民事再生で立て直すことになりました。借金の6割が減らされ、株主の取り分は大きく減りました'), 'bad');
    if (heir != null) N(M('{0}は責任を取って退き、{1}が社長になりました', [Nm(old), Nm(heir.name)]), 'bad');
    chron('board', M('資金が尽き、民事再生で立て直した（借金の6割を減らした）'));
    return true;
  }
}

/// 段6の乱数を、人を作る仕組み（mkPerson）に一時的に渡すための包み
class _LifeRandom implements math.Random {
  final Game g;
  _LifeRandom(this.g);
  @override
  double nextDouble() => g.lr();
  @override
  int nextInt(int max) => (g.lr() * max).floor();
  @override
  bool nextBool() => g.lr() < .5;
}
