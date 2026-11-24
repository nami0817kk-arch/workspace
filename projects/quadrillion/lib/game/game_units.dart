// ignore_for_file: non_constant_identifier_names
part of 'game.dart';

// ===== 店・ライン・拠点の数（1.1.0+26 から。企画書「現実に寄せる」の段2） =====
//
// 事業の売上は「客がどれだけ来るか（事業の力とシェア。今までの仕組み）」と「店・ラインなどがどれだけ売れるか（ここ）」の
// 小さい方になる。お金を積んでも、店の数は次の5つで頭打ちになる:
//   1. 上限: 市場の大きさ÷1単位の売上×取れるシェアの上限（寡占の業種ほど大きい）。都市の人口で立地に分ける
//   2. 責任者: 店長・工場長・支店長は1単位に1人。育つまで6〜12か月、同時に育てられる数は店の数で決まる
//   3. 本部: 指導員などは約8単位に1人（型で違う）。足りないと売上が落ち、不祥事が起きやすい
//   4. 物流（店舗型）: 1つの都市圏で20店を超えると配送の拠点が要る（1拠点で300店）。無いと原価が4%上がる
//   5. 時間: 開くまで3〜6か月（型で違う）、売上が育ちきるまで1〜2年。その間も固定費は丸ごとかかる
// 物件（店舗型）は立地ごとに毎月いくつか出て、良い物件は他社と取り合う。

/// 1つの都市圏で、配送の拠点なしで回せる店の数・1拠点で回せる店の数・拠点が無いと上がる原価
const double hubFree = 20, hubCover = 300, hubPenalty = .04;

/// 改装で上げられる1単位の売上の倍の上限と、1回で上がる分
const double upgMax = 1.25, upgStep = .05;

extension GameUnits on Game {
  /// 店などの数で売上に上限をかけるか（試作との一致を見る extras を切った遊びでは使わない）
  bool get unitsOn => extras;

  IndProfile prof(Biz b) => profileOf(indm[b.ind]!);
  String kindB(Biz b) => kindOf(indm[b.ind]!);

  // ===== 立地 =====
  /// 立地の鍵: 「国/都市の番号/立地」。立地は 0 都心・1 郊外・2 地方・n 国全体（都市圏に分けない型）
  List<String> siteKeys(String c, String kind) {
    if (!KIND_ZONED.contains(kind)) return ['$c/-/n'];
    final n = cityList(c).length;
    return [
      for (var i = 0; i < n; i++) ...['$c/$i/0', '$c/$i/1'],
      '$c/-/2',
    ];
  }

  /// その国の都市圏（統計に無い国は、国の大都市を1つ置く）
  List<EconCity> cityList(String c) {
    final l = econData.cities(c);
    if (l.isNotEmpty) return l;
    final ct = cm[c];
    return [EconCity(ct?.cityJa ?? c, ct?.cityJa ?? c, 0)];
  }

  String siteCtry(String s) => s.split('/')[0];
  int siteZone(String s) {
    final z = s.split('/')[2];
    return z == 'n' ? -1 : int.parse(z);
  }

  /// 都市圏の鍵（国/都市の番号。地方は 国/-）
  String areaOf(String s) {
    final p = s.split('/');
    return '${p[0]}/${p[1]}';
  }

  /// その国の今の人口
  double ctryPop(String c) {
    final v = ev(c, 'pop');
    return v.isFinite && v > 0 ? v : 1e7;
  }

  /// 立地の人口（都市の人口は2020年の数を国の人口の伸びで動かす。都心3割・郊外7割、地方は都市圏の外）
  double sitePop(String s) {
    final c = siteCtry(s), p = s.split('/'), z = siteZone(s);
    final pop = ctryPop(c);
    if (z < 0) return pop;
    final base = econData.year(c, 2020).pop ?? pop;
    final k = base > 0 ? pop / base : 1.0;
    final cities = cityList(c);
    if (z == 2) {
      final inCities = cities.fold(0.0, (a, x) => a + (x.pop > 0 ? x.pop : base * .2)) * k;
      return math.max(pop * .1, pop - inCities);
    }
    final i = int.parse(p[1]);
    final cp = (i < cities.length && cities[i].pop > 0 ? cities[i].pop : base * .2) * k;
    return cp * (z == 0 ? .3 : .7);
  }

  /// 立地の名前（今の言語。例: 東京・都心）
  String siteName(String s) {
    final c = siteCtry(s), z = siteZone(s), p = s.split('/');
    if (z < 0) return cm[c]?.n ?? c;
    if (z == 2) return c == home ? tr('地方') : tr('{0}・地方', [cm[c]?.n ?? c]);
    final i = int.parse(p[1]);
    final cities = cityList(c);
    final city = i < cities.length ? (L.en ? cities[i].en : cities[i].ja) : c;
    return tr('{0}・{1}', [city, tr(ZONE_JA[z])]);
  }

  /// 都市圏の名前（物流の拠点の置き場所）
  String areaName(String a) {
    final p = a.split('/');
    if (p[1] == '-') return p[0] == home ? tr('地方') : tr('{0}・地方', [cm[p[0]]?.n ?? p[0]]);
    final i = int.parse(p[1]);
    final cities = cityList(p[0]);
    return i < cities.length ? (L.en ? cities[i].en : cities[i].ja) : p[0];
  }

  // ===== 数 =====
  /// 立地ごとの単位の数（育ちきったもの＋育っているもの）
  double unitsAt(Biz b, String s) => (b.sites[s]?.n ?? 0) + b.young.where((y) => y.s == s).fold(0.0, (a, y) => a + y.n);

  /// 全部の単位の数
  double unitTotal(Biz b) => b.sites.values.fold(0.0, (a, x) => a + x.n) + b.young.fold(0.0, (a, y) => a + y.n);

  /// その国の単位の数
  double unitsIn(Biz b, String c) =>
      b.sites.entries.where((e) => siteCtry(e.key) == c).fold(0.0, (a, e) => a + e.value.n) + b.young.where((y) => siteCtry(y.s) == c).fold(0.0, (a, y) => a + y.n);

  /// 開き始めてまだ開いていない単位の数（[s] を渡すとその立地だけ・[c] でその国だけ）
  double pendingUnits(Biz b, {String? s, String? c}) =>
      b.pipe.where((x) => x.k == 'open' && (s == null || x.c == s) && (c == null || siteCtry(x.c ?? '') == c)).fold(0.0, (a, x) => a + (x.pw ?? 0));

  /// 育てている責任者の数
  int trainees(Biz b) => b.pipe.where((x) => x.k == 'train').fold(0, (a, x) => a + (x.pw ?? 0).round());

  /// 1単位の数え方（「120店」「3ライン」など。ネットは利用者の数で言う）
  String unitCount(Biz b, double n) {
    final k = kindB(b);
    if (k == 'net') return tr('{0}万人', [commas(jsRound(n * 10).toDouble())]);
    return tr(KIND_COUNT_JA[k]!, [commas(jsRound(n).toDouble())]);
  }

  /// 包んだ文の中で使う数え方（仕組みの知らせ用）
  String unitCountM(Biz b, double n) {
    final k = kindB(b);
    if (k == 'net') return M('{0}万人', [jsRound(n * 10)]);
    return M(KIND_COUNT_JA[k]!, [jsRound(n)]);
  }

  // ===== お金の実額 =====
  /// 育ちきった1単位の月の売上（物価と改装だけが乗る）
  double unitRevNow(Biz b) => prof(b).unitRev * nom() * b.upg;

  /// 1単位の初期投資（立地で変わる。都心は高く、地方は安い）
  double unitCapexAt(Biz b, String s) {
    final z = siteZone(s);
    final zc = z < 0 ? 1.0 : (KIND_ZONE_COST[kindB(b)]?[z] ?? 1);
    var c = prof(b).unitCapex * nom() * (1 + .5 * (zc - 1));
    if (hasT('careful') && yr() - indm[b.ind]!.b < 10) c *= 1.5;
    return c;
  }

  /// 立地で変わらない、ならした1単位の初期投資
  double unitCapexAvg(Biz b) => prof(b).unitCapex * nom();

  /// 育てる責任者1人の費用（育つまでの給料）
  double leadCost(Biz b) => wageCat(indm[b.ind]!.cat) * 1.4 * (KIND_LEAD_MONTHS[kindB(b)] ?? 6) / 12;

  /// 本部で見る人1人の毎月の給料
  double svPayOne(Biz b) => wageCat(indm[b.ind]!.cat) * 1.5 / 12;

  /// 本部で見る人1人を外から雇う費用（店舗型は店長から上げるので、育てた店長を1人使う）
  double svHireCost(Biz b) => wageCat(indm[b.ind]!.cat) * .5;

  /// 配送の拠点1つの値段と、毎月の運営費
  double hubCost(Biz b) => math.max(prof(b).unitCapex * 25, 5e8) * nom();
  double hubRun(Biz b) => hubCost(b) * .004;

  /// 本部の人の毎月の給料と、物流の拠点の運営費（手の空いた責任者は今ある店で働くので、給料は現場の人件費に入っている）
  double svPay(Biz b) => b.sv * svPayOne(b) + b.hubs.length * hubRun(b);

  // ===== 上限 =====
  /// その国の市場をすべて取ったときに要る単位の数
  double satUnits(Biz b, String c) {
    final ind = indm[b.ind]!;
    final m = mkt(ind) * cw(c, yr()) / 3;
    final u = unitRevNow(b) / b.upg;
    return u > 0 ? m / u : 0;
  }

  /// 1社で取れる市場の割合の上限（寡占の業種ほど大きい）
  double maxShareOf(Biz b) => .22 + .35 * prof(b).conc;

  /// その国で持てる単位の上限（市場の大きさから。今持っている数は下回らない）
  double capUnits(Biz b, [String? c]) {
    final cc = c ?? home;
    final k = kindB(b);
    var v = satUnits(b, cc) * maxShareOf(b);
    if (k == 'net') v = math.min(v, ctryPop(cc) * .6 / 1e5);
    if (k == 'people') v = math.min(v, ctryPop(cc) * .01);
    return math.max(unitsIn(b, cc), v.floorToDouble());
  }

  /// 立地の重み（人口×その立地の置きやすさ）
  double _siteW(Biz b, String s) {
    final z = siteZone(s);
    final d = z < 0 ? 1.0 : (KIND_ZONE_DENSITY[kindB(b)]?[z] ?? 1);
    return sitePop(s) * d;
  }

  /// 立地の上限（国の上限を人口で分ける）
  double siteCap(Biz b, String s) {
    final c = siteCtry(s);
    final keys = siteKeys(c, kindB(b));
    final tot = keys.fold(0.0, (a, k) => a + _siteW(b, k));
    final v = tot > 0 ? capUnits(b, c) * _siteW(b, s) / tot : 0.0;
    return math.max(unitsAt(b, s), v.floorToDouble());
  }

  // ===== 売れる量 =====
  /// 立地の1単位の売上の倍（立地・同じ立地の自分の店どうしの取り合い）
  double siteSalesF(Biz b, String s) {
    final z = siteZone(s);
    final zs = z < 0 ? 1.0 : (KIND_ZONE_SALES[kindB(b)]?[z] ?? 1);
    final cap = siteCap(b, s);
    final r = cap > 0 ? math.min(1.5, unitsAt(b, s) / cap) : 0.0;
    return zs * (1 - .35 * r * r);
  }

  /// 育ちかけの単位の売上の割合（開いた直後は55%から）
  double rampF(Biz b, int age) {
    final m = KIND_RAMP[kindB(b)] ?? 0;
    return m <= 0 ? 1 : .55 + .45 * math.min(1, age / m);
  }

  /// 本部で見る人が要る数（最初の1人分は社長と本社が見る）
  int svNeed(Biz b) {
    final u = unitTotal(b);
    final r = KIND_SV_RATIO[kindB(b)] ?? 8;
    return math.max(0, (u / r).ceil() - 1);
  }

  /// 本部の目の行き届き方（0〜1）
  double svQ(Biz b) {
    final n = svNeed(b);
    return n == 0 ? 1 : math.min(1, b.sv / n);
  }

  /// 立地の、売れる量（月の売上の上限）
  double siteCapRev(Biz b, String s) {
    final st = b.sites[s];
    var u = st == null ? 0.0 : st.n * st.mul;
    for (final y in b.young) {
      if (y.s == s) u += y.n * y.mul * rampF(b, y.age);
    }
    return u * unitRevNow(b) * siteSalesF(b, s);
  }

  /// 全部の立地を足した、月の売上の上限（本部の目が行き届かないと下がる）
  double capRev(Biz b) {
    if (!unitsOn) return double.infinity;
    final keys = <String>{...b.sites.keys, for (final y in b.young) y.s};
    var v = 0.0;
    for (final s in keys) {
      v += siteCapRev(b, s);
    }
    return v * (.75 + .25 * svQ(b));
  }

  /// 季節の波（月ごとの売上の倍。季節の強い業種ほど大きく揺れる）
  double seasonF(Biz b) {
    final p = prof(b);
    if (p.season <= 0) return 1;
    final ph = b.ind.codeUnits.fold(0, (a, x) => a + x) % 12;
    return 1 + p.season * .12 * math.sin(2 * math.pi * (q + ph) / 12);
  }

  // ===== 固定費 =====
  /// 立地の固定費（家賃・光熱費・物流・保険・修繕。育っていなくても丸ごとかかる）
  double siteFixed(Biz b, String s) {
    final z = siteZone(s);
    final zc = z < 0 ? 1.0 : (KIND_ZONE_COST[kindB(b)]?[z] ?? 1);
    final st = b.sites[s];
    var u = st == null ? 0.0 : st.n * st.rent;
    for (final y in b.young) {
      if (y.s == s) u += y.n * y.rent;
    }
    return u * unitRevNow(b) / b.upg * prof(b).fixed * zc;
  }

  double fixedCost(Biz b) {
    if (!unitsOn) return 0;
    final keys = <String>{...b.sites.keys, for (final y in b.young) y.s};
    return keys.fold(0.0, (a, s) => a + siteFixed(b, s));
  }

  /// 都市圏ごとの店の数
  Map<String, double> areaUnits(Biz b) {
    final m = <String, double>{};
    for (final e in b.sites.entries) {
      m[areaOf(e.key)] = (m[areaOf(e.key)] ?? 0) + e.value.n;
    }
    for (final y in b.young) {
      m[areaOf(y.s)] = (m[areaOf(y.s)] ?? 0) + y.n;
    }
    return m;
  }

  /// 配送の拠点が足りない都市圏と、拠点なしで回している店の数（店舗型だけ）
  Map<String, double> hubShort(Biz b) {
    if (kindB(b) != 'shop' || !unitsOn) return const {};
    final out = <String, double>{};
    for (final e in areaUnits(b).entries) {
      final n = e.value, h = b.hubs.where((x) => x == e.key).length;
      if (n <= hubFree && h == 0) continue;
      final un = n - h * hubCover;
      if (un > 0) out[e.key] = un;
    }
    return out;
  }

  /// 拠点が無いことで上がる原価の割合（売上のうち、拠点なしで回している店の割合×4%）
  double hubPen(Biz b) {
    final sh = hubShort(b);
    if (sh.isEmpty) return 0;
    final u = unitTotal(b);
    return u > 0 ? hubPenalty * sh.values.fold(0.0, (a, x) => a + x) / u : 0;
  }

  /// 物流の拠点が要りそうな都市圏（拠点なしの上限に近いか、超えた所。まだ建てていない所）
  List<String> hubWanted(Biz b) {
    if (kindB(b) != 'shop') return const [];
    final building = {for (final x in b.pipe.where((x) => x.k == 'hub')) x.c};
    final out = <String>[];
    for (final e in areaUnits(b).entries) {
      if (building.contains(e.key)) continue;
      final h = b.hubs.where((x) => x == e.key).length;
      if (e.value >= hubFree * .8 + h * hubCover) out.add(e.key);
    }
    out.ssort((x, y) => (areaUnits(b)[y] ?? 0).compareTo(areaUnits(b)[x] ?? 0));
    return out;
  }

  // ===== 開くのに要るもの =====
  /// 1か月に開き始められる単位の数（ネットは宣伝の伸び、人は採用の市場で決まる。ほかの型は無制限）
  double monthOpenCap(Biz b) => switch (kindB(b)) {
        'net' => 1 + unitTotal(b) * .15,
        'people' => 3 + unitTotal(b) * .05,
        _ => double.infinity,
      };

  /// 同時に進められる開く仕掛かりの数（工場・許認可・作品・インフラ）
  int maxPending(Biz b) {
    final u = unitTotal(b);
    return switch (kindB(b)) {
      'factory' => 1 + (u / 3).floor(),
      'license' => 1 + (u / 10).floor(),
      'hit' => 1 + (u / 6).floor(),
      'infra' => 1 + (u / 8).floor(),
      _ => 1 << 30,
    };
  }

  /// 同時に育てられる責任者の数（今ある単位が研修の場になる）
  int trainSlots(Biz b) => 2 + (unitTotal(b) / 5).floor();

  /// その立地の今月の物件の数
  int offersAt(Biz b, String s) => b.offers.where((o) => o.s == s).length;

  /// 立地に n 単位を開けないときの理由（開けるなら null）。お金と時間も見る
  String? openBlock(Biz b, String s, int n) {
    if (!unitsOn) return M('今はこの手は使えません');
    if (n <= 0) return M('開く数がありません');
    final k = kindB(b);
    if (b.lic > 0) return M('許可がまだ下りていません（あと{0}か月）', [b.lic]);
    final c = siteCtry(s);
    if (!ctryOf(b).contains(c)) return M('その国にはまだ出ていません');
    if (unitsIn(b, c) + pendingUnits(b, c: c) + n > capUnits(b, c) + .01) return M('{0}の上限（約{1}）に届いています', [C(c), unitCountM(b, capUnits(b, c))]);
    if (unitsAt(b, s) + pendingUnits(b, s: s) + n > siteCap(b, s) + .01) return M('その立地はもう上限です。ほかの立地に出しましょう');
    final lead = KIND_LEAD_JA[k];
    if (lead != null && b.leads < n) return M('{0}が足りません（手の空いている人 {1}人・要る人 {2}人）。先に育てましょう', [D(lead), b.leads, n]);
    if (k == 'shop' && offersAt(b, s) < n) return M('この立地に今月出ている物件は{0}件です', [offersAt(b, s)]);
    if (b.opened + n > monthOpenCap(b) + .01) {
      return M(k == 'net' ? '宣伝で一度に集められる利用者には限りがあります（今月はあと{0}）' : '採用の市場で一度に集められる人には限りがあります（今月はあと{0}）',
          [unitCountM(b, math.max(0, monthOpenCap(b) - b.opened).floorToDouble())]);
    }
    final pend = b.pipe.where((x) => x.k == 'open').length;
    if (pend + 1 > maxPending(b)) return M('同時に進められるのは{0}件までです。今の仕掛かりが終わるのを待ちましょう', [maxPending(b)]);
    if (cash < unitCapexAt(b, s) * n) return M('お金が足りません');
    return needT('build');
  }

  /// 立地の物件を良い順に（売上の倍が高く、家賃の倍が低いもの）
  List<Offer> bestOffers(Biz b, String s) => b.offers.where((o) => o.s == s).toList()..ssort((x, y) => (y.mul / y.rent).compareTo(x.mul / x.rent));

  /// 立地に n 単位を開き始める（社長の時間 8時間。他社と取り合う物件は、取られることがある）
  String openUnits(Biz b, String s, int n) {
    final why = openBlock(b, s, n);
    if (why != null) return why;
    useT('build');
    final k = kindB(b);
    var got = n, lost = 0;
    var mul = 0.0, rent = 0.0;
    if (k == 'shop') {
      final os = bestOffers(b, s).take(n).toList();
      got = 0;
      for (final o in os) {
        b.offers.remove(o);
        // 他社も狙っている物件は、先に契約されることがある（1社につき2割5分）
        if (o.riv > 0 && rnd() < math.min(.75, o.riv * .25)) {
          lost++;
          continue;
        }
        got++;
        mul += o.mul;
        rent += o.rent;
      }
      if (got == 0) {
        calcAll();
        return M('狙った物件は、すべて他社に先に契約されました');
      }
      mul /= got;
      rent /= got;
    } else {
      mul = 1;
      rent = 1;
    }
    final cost = unitCapexAt(b, s) * got;
    cash -= cost;
    if (KIND_LEAD_JA[k] != null) b.leads -= got;
    b.opened += got;
    final o = prof(b).open;
    final left = ri(o.$1, o.$2);
    b.pipe.add(Pipe(k: 'open', c: s, cost: cost, pw: got.toDouble(), left: left, mul: mul, rent: rent));
    calcAll();
    final msg = M('{0}に{1}を開き始めました（{2}）。開くのは{3}か月後です', [siteNameM(s), unitCountM(b, got.toDouble()), Y(cost), left]);
    return lost > 0 ? Cat([msg, M('{0}件は他社に先に契約されました', [lost])], ja: '。', en: '. ') : msg;
  }

  /// 立地の名前を包んだ文で（知らせ用）
  String siteNameM(String s) {
    final c = siteCtry(s), z = siteZone(s), p = s.split('/');
    if (z < 0) return C(c);
    if (z == 2) return c == home ? M('地方') : M('{0}・地方', [C(c)]);
    final i = int.parse(p[1]);
    final cities = cityList(c);
    return M('{0}・{1}', [i < cities.length ? M(cities[i].ja) : C(c), M(ZONE_JA[z])]);
  }

  /// 開ける立地を良い順に（物件・上限・売れ行きを見て）。開けない立地は入れない
  List<String> openSites(Biz b, int n) {
    final out = <(String, double)>[];
    for (final c in ctryOf(b)) {
      for (final s in siteKeys(c, kindB(b))) {
        final m = math.min(n, kindB(b) == 'shop' ? offersAt(b, s) : n);
        if (m <= 0) continue;
        final cap = siteCap(b, s);
        final room = cap - unitsAt(b, s) - pendingUnits(b, s: s);
        if (room < 1) continue;
        final best = kindB(b) == 'shop' ? bestOffers(b, s).first : null;
        final z = siteZone(s);
        final zs = z < 0 ? 1.0 : (KIND_ZONE_SALES[kindB(b)]?[z] ?? 1);
        final zc = z < 0 ? 1.0 : (KIND_ZONE_COST[kindB(b)]?[z] ?? 1);
        // 1単位の利益の見込み（売上の倍×粗利 − 固定費）で並べる。取り合いの物件は少し下げる
        final p = prof(b);
        final sc = siteSalesF(b, s) * (best?.mul ?? 1) * (p.mg + p.fixed) - p.fixed * zc * (best?.rent ?? 1) - (best?.riv ?? 0) * .01 + zs * .001;
        out.add((s, sc));
      }
    }
    out.ssort((a, b2) => b2.$2.compareTo(a.$2));
    return [for (final x in out) x.$1];
  }

  /// いちばん良い立地から n 単位まで開く（手の空いた責任者・物件・お金の分だけ。社長の時間は1回分）
  String openBest(Biz b, int n) {
    if (!unitsOn) return M('今はこの手は使えません');
    final sites = openSites(b, n);
    if (sites.isEmpty) {
      final k = kindB(b);
      if (b.lic > 0) return M('許可がまだ下りていません（あと{0}か月）', [b.lic]);
      if (KIND_LEAD_JA[k] != null && b.leads <= 0) return M('{0}が足りません（手の空いている人 {1}人・要る人 {2}人）。先に育てましょう', [D(KIND_LEAD_JA[k]!), b.leads, n]);
      if (k == 'shop' && b.offers.isEmpty) return M('今月は空いている物件がありません');
      return M('{0}の上限（約{1}）に届いています', [C(home), unitCountM(b, capUnits(b))]);
    }
    final s = sites.first;
    var m = n;
    if (kindB(b) == 'shop') m = math.min(m, offersAt(b, s));
    if (KIND_LEAD_JA[kindB(b)] != null) m = math.min(m, b.leads);
    m = math.min(m, (siteCap(b, s) - unitsAt(b, s) - pendingUnits(b, s: s)).floor());
    m = math.min(m, (cash / unitCapexAt(b, s)).floor());
    if (monthOpenCap(b).isFinite) m = math.min(m, (monthOpenCap(b) - b.opened).floor());
    if (m <= 0) return openBlock(b, s, 1) ?? M('お金が足りません');
    return openUnits(b, s, m);
  }

  /// 責任者（店長など）を n 人育て始める（社長の時間 4時間。育つまで6〜12か月）
  String trainLeads(Biz b, int n) {
    final lead = KIND_LEAD_JA[kindB(b)];
    if (lead == null || !unitsOn) return M('この事業には要りません');
    if (n <= 0) return M('育てる人数がありません');
    if (trainees(b) + n > trainSlots(b)) return M('同時に育てられるのは{0}人までです（今 {1}人）', [trainSlots(b), trainees(b)]);
    final cost = leadCost(b) * n;
    if (cash < cost) return M('お金が足りません');
    final nt = spendT('crew');
    if (nt != null) return nt;
    cash -= cost;
    final mo = KIND_LEAD_MONTHS[kindB(b)] ?? 6;
    b.pipe.add(Pipe(k: 'train', cost: cost, pw: n.toDouble(), left: mo));
    calcAll();
    return M('{0}を{1}人育て始めました（{2}）。{3}か月後に店を任せられます', [D(lead), n, Y(cost), mo]);
  }

  /// 本部で見る人（指導員など）を n 人置く。店舗型は育った店長から上げ、ほかの型は外から雇う（社長の時間 2時間）
  String placeSV(Biz b, int n) {
    if (!unitsOn || n <= 0) return M('今はこの手は使えません');
    final k = kindB(b);
    final name = KIND_SV_JA[k]!;
    if (k == 'shop') {
      if (b.leads < n) return M('{0}に上げられる店長がいません（手の空いている店長 {1}人）', [D(name), b.leads]);
    } else if (cash < svHireCost(b) * n) {
      return M('お金が足りません');
    }
    final nt = spendT('hire');
    if (nt != null) return nt;
    if (k == 'shop') {
      b.leads -= n;
    } else {
      cash -= svHireCost(b) * n;
    }
    b.sv += n;
    calcAll();
    return M('{0}を{1}人置きました（毎月の給料 {2}）', [D(name), n, Y(svPayOne(b) * n)]);
  }

  /// 物流の拠点を作る（社長の時間 8時間。できるまで6〜9か月）
  String buildHub(Biz b, String area) {
    if (kindB(b) != 'shop' || !unitsOn) return M('この事業には要りません');
    final cost = hubCost(b);
    if (cash < cost) return M('お金が足りません');
    final nt = spendT('build');
    if (nt != null) return nt;
    cash -= cost;
    final left = ri(6, 9);
    b.pipe.add(Pipe(k: 'hub', c: area, cost: cost, left: left));
    calcAll();
    return M('{0}に配送の拠点を作り始めました（{1}）。できるのは{2}か月後です', [areaNameM(area), Y(cost), left]);
  }

  String areaNameM(String a) {
    final p = a.split('/');
    if (p[1] == '-') return p[0] == home ? M('地方') : M('{0}・地方', [C(p[0])]);
    final i = int.parse(p[1]);
    final cities = cityList(p[0]);
    return i < cities.length ? M(cities[i].ja) : C(p[0]);
  }

  /// 改装（今ある全部の単位の売上を5%上げる。上限1.25倍）
  double renovateCost(Biz b) => unitCapexAvg(b) * math.max(1, unitTotal(b)) * .08;

  // ===== 仕掛かりが終わったとき =====
  /// 開く・育てる・拠点の仕掛かりが終わった（終わっていなければ false）
  bool finishUnitPipe(Biz b, Pipe x, void Function(String, [String]) N) {
    final name = I(b.ind);
    switch (x.k) {
      case 'open':
        final n = x.pw ?? 1;
        var mul = x.mul ?? 1;
        String? hit;
        if (kindB(b) == 'hit') {
          // 作品ごとの賭け：外れ（3割）・ふつう・大当たり（担当の開発の腕で当たりやすく）
          final p = staffById(b.mgr);
          final kai = p != null ? p.ab['kai']! : pres.ab['kai']!;
          final r = rnd();
          final hp = .12 + kai / 1000 + (hasT('genius') ? .06 : 0);
          if (r < hp) {
            mul = 3 + rnd() * 3;
            hit = M('大当たり！「{0}」の新しい作品が大ヒットしました', [name]);
          } else if (r < hp + .3) {
            mul = .3;
            hit = M('「{0}」の新しい作品は外れました', [name]);
          } else {
            mul = .8 + rnd() * .5;
          }
        }
        b.young.add(Cohort(s: x.c!, n: n, mul: mul, rent: x.rent ?? 1));
        // 新しい単位は客を呼ぶ（事業の力が、その単位が育ちきったときの売上に見合う分だけ増える）
        b.power += n * unitRevNow(b) * 3 * mul * math.pow(1 - b.share, 2).toDouble();
        N(hit ?? M('「{0}」の{1}に、新しく{2}が開きました', [name, siteNameM(x.c!), unitCountM(b, n)]), hit != null && mul < 1 ? 'bad' : 'good');
        return true;
      case 'train':
        final n = (x.pw ?? 1).round();
        b.leads += n;
        N(M('「{0}」の{1}が{2}人育ちました', [name, D(KIND_LEAD_JA[kindB(b)] ?? '店長'), n]), 'good');
        return true;
      case 'hub':
        b.hubs.add(x.c!);
        N(M('「{0}」の配送の拠点が{1}にできました', [name, areaNameM(x.c!)]), 'good');
        return true;
    }
    return false;
  }

  // ===== 始めるとき =====
  /// 新しい事業の最初の単位（元手で買える分。許認可型は許可を待つ）
  void initUnits(Biz b, double capex) {
    if (!unitsOn) return;
    final k = kindB(b);
    if (k == 'license') {
      b.lic = ri(10, 30);
      return;
    }
    final n = math.max(1, (capex * .95 / unitCapexAvg(b)).round());
    seedUnits(b, home, n, started: true);
    if (KIND_LEAD_JA[k] != null) b.leads = 1;
    // 最初の客は、開いた店などが育ちきったときに売れる量より少し多いくらい（元手を全部、客の力にしない）
    final want = unitTotal(b) * unitRevNow(b) * 3 * 1.25;
    if (want > 0 && b.power > want) {
      b.crew = crewOf(b) * want / b.power;
      b.power = want;
    }
  }

  /// 国に n 単位を置く（人口の多い立地から。始めたときは半分育った状態にする）
  void seedUnits(Biz b, String c, int n, {bool started = false}) {
    final keys = siteKeys(c, kindB(b));
    final w = {for (final s in keys) s: _siteW(b, s)};
    final tot = w.values.fold(0.0, (a, x) => a + x);
    var left = math.min(n.toDouble(), math.max(1.0, capUnits(b, c) - unitsIn(b, c)));
    final order = keys.toList()..ssort((x, y) => w[y]!.compareTo(w[x]!));
    final age = ((KIND_RAMP[kindB(b)] ?? 0) * (started ? .6 : .5)).round();
    for (final s in order) {
      if (left <= 0) break;
      final m = math.max(1.0, (n * w[s]! / math.max(tot, 1)).roundToDouble());
      final put = math.min(left, m);
      b.young.add(Cohort(s: s, n: put, age: age));
      left -= put;
    }
  }

  /// 古いセーブ・ほかの手で作った事業で、単位がまだ無いもの（売上から数を見積もって置く）
  void ensureUnits(Biz b) {
    if (!unitsOn || b.lic > 0 || unitTotal(b) > 0 || b.pipe.any((x) => x.k == 'open')) return;
    final u = unitRevNow(b);
    final n = u > 0 ? math.max(1, (math.max(b.rev, b.power / 3) / u).ceil()) : 1;
    for (final c in ctryOf(b)) {
      seedUnits(b, c, c == home ? n : math.max(1, (n * cw(c, yr()) * .3).round()));
    }
    if (KIND_LEAD_JA[kindB(b)] != null && b.leads == 0) b.leads = 1;
  }

  // ===== 毎月 =====
  /// 月の初め：育ち・解約と古くなり・許可・物件・本部の目の行き届き
  void monthUnits(void Function(String, [String]) N) {
    if (!unitsOn) return;
    for (final b in biz) {
      final k = kindB(b);
      final p = prof(b);
      b.opened = 0;
      // 許可
      if (b.lic > 0) {
        b.lic--;
        if (b.lic == 0) {
          seedUnits(b, home, math.max(1, (capexOf(indm[b.ind]!) * .9 / unitCapexAvg(b)).floor()), started: true);
          b.leads = math.max(b.leads, 1);
          N(M('「{0}」の許可が下りました。営業を始めます', [I(b.ind)]), 'good');
        }
      }
      // 育ち（育ちきったら立地のまとまりへ）
      final ramp = KIND_RAMP[k] ?? 0;
      for (final y in b.young.toList()) {
        y.age++;
        if (y.age >= ramp) {
          final st = b.sites[y.s] ??= Site(n: 0);
          final tot = st.n + y.n;
          if (tot > 0) {
            st.mul = (st.mul * st.n + y.mul * y.n) / tot;
            st.rent = (st.rent * st.n + y.rent * y.n) / tot;
          }
          st.n = tot;
          b.young.remove(y);
        }
      }
      // ネットは解約で、作品は古くなって減る
      final loss = k == 'net' ? p.churn : (k == 'hit' ? .025 : 0.0);
      if (loss > 0) {
        for (final st in b.sites.values) {
          st.n *= 1 - loss;
        }
        b.sites.removeWhere((_, st) => st.n < .05);
      }
      // 物件（店舗型。立地ごとに毎月いくつか。人口が多く、まだ店が少ない立地ほど多い）
      if (k == 'shop') {
        b.offers = [];
        for (final c in ctryOf(b)) {
          for (final s in siteKeys(c, k)) {
            final cap = siteCap(b, s);
            if (cap < 1) continue;
            final room = 1 - math.min(1, (unitsAt(b, s) + pendingUnits(b, s: s)) / cap);
            if (room <= 0) continue;
            final ex = clampD(sitePop(s) / 1.5e6, .2, 4) * room * (c == home ? 1 : .6);
            final n = (ex + rnd()).floor();
            for (var i = 0; i < n && b.offers.length < 24; i++) {
              final good = rnd();
              b.offers.add(Offer(
                  s: s, rent: .75 + rnd() * .5, mul: .85 + good * .35, riv: good > .6 ? ri(1, 3) : (rnd() < .2 ? 1 : 0)));
            }
          }
        }
      }
      // 本部の目が行き届かないと、不祥事や客離れ
      final q0 = svQ(b);
      if (q0 < .8 && rnd() < (1 - q0) * .06) {
        b.power *= .96;
        scandal = math.max(scandal, 3);
        N(M('{0}が足りず、「{1}」で不祥事が起き、客が離れました', [D(KIND_SV_JA[k]!), I(b.ind)]), 'bad');
      }
    }
  }

  /// 売掛金（売上のうち、まだ入っていない分）。代金をもらうまでの月が長い業種ほど多い
  double receivables() => unitsOn ? biz.fold(0.0, (a, b) => a + math.max(0.0, b.rev) * prof(b).payLag) : 0;

  // ===== 伸ばす手の見立て（自動プレイ・任せた責任者・会議の提案が使う） =====
  /// 今いちばん要る伸ばす手を1つ（[room] に収まるもの。無ければ null）。[want] は開きたい数
  ({String k, double cost, String l, String Function() run})? growOpt(Biz b, double room, {int want = 3, bool time = false}) {
    if (!unitsOn || b.lic > 0) return null;
    final k = kindB(b);
    // 1. 本部の目
    final svShort = svNeed(b) - b.sv;
    if (svShort > 0) {
      final n = svShort;
      if (k == 'shop' && b.leads >= 1) {
        final m = math.min(n, math.max(1, b.leads ~/ 2));
        return (
          k: 'sv',
          cost: 0,
          l: M('「{0}」で店長を{1}に上げたい', [I(b.ind), D(KIND_SV_JA[k]!)]),
          run: () => _noTime(time, () => placeSV(b, m)),
        );
      }
      if (k != 'shop' && svHireCost(b) * n <= room) {
        return (k: 'sv', cost: svHireCost(b) * n, l: M('「{0}」の本部を強くしたい', [I(b.ind)]), run: () => _noTime(time, () => placeSV(b, n)));
      }
    }
    // 2. 物流の拠点
    final hw = hubWanted(b);
    if (hw.isNotEmpty && hubCost(b) <= room) {
      final a = hw.first;
      return (k: 'hub', cost: hubCost(b), l: M('「{0}」の配送の拠点を作りたい', [I(b.ind)]), run: () => _noTime(time, () => buildHub(b, a)));
    }
    // 客が足りずに今の店などが売れ残っているあいだは、増やさない（増やすほど1店あたりが減り、固定費で赤字になる）
    final soldOut = (capKOf[b.id] ?? 1) < .97;
    // 3. 開く
    final sites = soldOut ? openSites(b, want) : const <String>[];
    if (sites.isNotEmpty) {
      final s = sites.first;
      var m = want;
      if (k == 'shop') m = math.min(m, offersAt(b, s));
      if (KIND_LEAD_JA[k] != null) m = math.min(m, b.leads);
      m = math.min(m, (siteCap(b, s) - unitsAt(b, s) - pendingUnits(b, s: s)).floor());
      m = math.min(m, (room / unitCapexAt(b, s)).floor());
      if (monthOpenCap(b).isFinite) m = math.min(m, (monthOpenCap(b) - b.opened).floor());
      final pend = b.pipe.where((x) => x.k == 'open').length;
      if (m > 0 && pend < maxPending(b)) {
        final n = m;
        return (
          k: 'build',
          cost: unitCapexAt(b, s) * n,
          l: M('「{0}」で{1}を開きたい', [I(b.ind), unitCountM(b, n.toDouble())]),
          run: () => _noTime(time, () => openUnits(b, s, n)),
        );
      }
    }
    // 4. 責任者を育てる
    final lead = KIND_LEAD_JA[k];
    if (soldOut && lead != null && b.leads < want && unitTotal(b) + pendingUnits(b) < capUnits(b) - 1) {
      final slot = trainSlots(b) - trainees(b);
      // 育ったあとに開くお金も残しておく
      final n = math.min(slot, (room / (leadCost(b) + unitCapexAvg(b))).floor());
      if (n > 0) {
        return (k: 'train', cost: leadCost(b) * n, l: M('「{0}」の{1}を{2}人育てたい', [I(b.ind), D(lead), n]), run: () => _noTime(time, () => trainLeads(b, n)));
      }
    }
    return null;
  }

  /// 時間を使わずに手を打つ（任せた責任者・会議で通した提案は社長の時間を使わない）
  String _noTime(bool time, String Function() f) {
    if (time) return f();
    final was = freeTime;
    freeTime = true;
    try {
      return f();
    } finally {
      freeTime = was;
    }
  }

  // ===== 画面と報告の数字 =====
  /// 立地ごとの1単位の月の売上（実際の売上を、売れる量の割合で分けた数）
  double siteUnitSales(Biz b, String s) {
    final n = unitsAt(b, s);
    final cr = capRev(b);
    if (n <= 0 || cr <= 0 || !cr.isFinite) return 0;
    return b.rev * siteCapRev(b, s) * (.75 + .25 * svQ(b)) / cr / n;
  }

  /// 立地ごとの1単位の月の利益（売上×粗利 − 固定費 − 人件費・本部の分け前）
  double siteUnitProfit(Biz b, String s) {
    final n = unitsAt(b, s);
    if (n <= 0) return 0;
    final u = unitTotal(b);
    // 事業全体の粗利（拠点が無いことで上がった原価は、立地ごとに引き直すので足し戻す）
    final gm = (b.rev > 0 ? (b.profit + fixedCost(b) + b.upkeep + svPay(b) + (b.ad > 0 ? b.adCost : 0)) / b.rev + hubPen(b) : prof(b).mg + prof(b).fixed);
    final pen = areaPenaltyAt(b, s);
    return siteUnitSales(b, s) * (gm - pen) - siteFixed(b, s) / n - (b.upkeep + svPay(b)) / math.max(u, 1);
  }

  /// その立地の都市圏が拠点なしで回っていれば、上がる原価の割合
  double areaPenaltyAt(Biz b, String s) {
    final sh = hubShort(b)[areaOf(s)];
    if (sh == null) return 0;
    final n = areaUnits(b)[areaOf(s)] ?? 1;
    return hubPenalty * sh / n;
  }

  /// 育ちきった1単位が、初期投資1円あたり毎月いくら稼ぐか（利益率×回転。開く先を選ぶ目安）
  double unitRoi(Biz b) {
    final p = prof(b);
    return p.unitCapex > 0 ? p.mg * p.unitRev / p.unitCapex : 0;
  }

  /// 売上がいま何で頭打ちになっているか（demand 客の数 / cap 店などの数）
  String limitOf(Biz b) => (capKOf[b.id] ?? 1) < .999 ? 'cap' : 'demand';

  /// 前年比（12か月前の売上と比べる。記録が足りなければ null）
  double? yoy(Biz b) => b.rh.length >= 13 && b.rh.first > 0 ? b.rev / b.rh.first - 1 : null;

  /// ネット型の課金率と、払う人1人の月の額（2020年の円で1,000円）
  double arpu() => 1000 * nom();
  double payRate(Biz b) => clampD(unitRevNow(b) / (1e5 * arpu()), 0, 1);

  /// 稼働率（実際の売上 ÷ 売れる量）
  double utilization(Biz b) {
    final c = capRev(b) * seasonF(b);
    return c > 0 && c.isFinite ? math.min(1, b.rev / c) : 0;
  }
}
