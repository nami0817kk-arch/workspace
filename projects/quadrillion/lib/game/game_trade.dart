// ignore_for_file: non_constant_identifier_names
part of 'game.dart';

// ===== 関税・輸送・交通とインフラ・海外の難しさ・供給の網（1.1.0+28 から。企画書「現実に寄せる」の段5） =====
//
// どこに効くか（数字は trade_data.dart）:
// - 関税: 外から買う原料・部品と、自分の国の工場から外へ売る分に、買う国の関税（年と協定と摩擦で変わる）がかかる → 原価
// - 輸送: 距離・手段（船・飛行機・トラックと鉄道）・時代（コンテナ化・運賃の波）と、運ぶ日数の重さで決まる → 物流費
// - 交通とインフラ: 道路と電気が弱い国は、物流費と光熱費が上がり、店や工場の売れる量が落ちる。ネットを使う人が少ない国では
//   ネットの業種の利用者が伸びない。電気が足りない国には重い工場を置けない。道路の網は、都心と郊外・地方への客の広がりを変える
// - 海外の難しさ: 現地の慣れ（言葉と文化の遠さで低く始まり、語学のできる人・海外の経験のある責任者・視察・組む相手で早く育つ）が
//   客の数に効き、現地の人を雇う手間が人件費に乗る。外資の決まり・立ち上げの月・為替の損・送金の制限・税の取り合い・政変と国有化
// - 供給の網: 仕入れ先の国を持ち、その国が災害や紛争で止まると、作れなくなる（部品）か高くつく（相場の品）。分けると高くつくが強い
//
// 値段は実額に物価だけを掛ける（現金や時価総額の割合では決めない）。1ターンは1か月。

/// 止まっている国（災害・紛争・封鎖）
class ActiveStop {
  String c;

  /// 包んだ名前（知らせ用）
  String ja;
  int left;
  double unit, sup;
  ActiveStop({required this.c, required this.ja, required this.left, required this.unit, required this.sup});
  Map<String, dynamic> toJson() => {'c': c, 'ja': ja, 'left': left, 'unit': unit, 'sup': sup};
  factory ActiveStop.fromJson(Map<String, dynamic> j) => ActiveStop(
      c: j['c'].toString(), ja: (j['ja'] ?? '').toString(), left: (j['left'] as num?)?.round() ?? 0, unit: (j['unit'] as num?)?.toDouble() ?? 0, sup: (j['sup'] as num?)?.toDouble() ?? 0);
}

/// 段5の状態（保存する）。[off] はテストで段5を切って比べるためのもので、保存しない
class TradeState {
  /// 事業の番号 → 仕入れ先の国
  Map<int, List<String>> sup = {};

  /// 「事業の番号/国」→ 現地の慣れ（0.5〜1）
  Map<String, double> adapt = {};

  /// 国 → 視察などで分かっている度合い（0〜1）
  Map<String, double> know = {};

  /// 人の番号 → 海外の仕事・留学の月
  Map<int, double> exp = {};

  /// 国 → 送金の制限で国の外へ出せずにたまっているお金
  Map<String, double> trapped = {};
  List<ActiveStop> stops = [];

  /// 国 → [政変の残りの月, 客の落ち込み]
  Map<String, List<double>> shock = {};

  /// これからの年の貿易摩擦 [買う国, 売る国, 終わるターン, 上乗せ%]
  List<List<Object>> fric = [];

  /// 一度だけの知らせを出したか
  Set<String> done = {};

  /// 事業の番号 → 今月の為替の損（得なら負。月の初めに決め、その月の計算に使うので保存する）
  Map<int, double> fx = {};

  // ===== 保存しない（計算のたびに作る） =====

  /// 事業の番号 → 現地の人を雇う手間（人件費に入る）
  Map<int, double> labor = {};

  /// 事業の番号 → 画面の数字（tariff 関税・freight 輸送・input 仕入れの値段の差・export 外へ売る分・infra インフラ・labor・fx）
  Map<int, Map<String, double>> view = {};

  /// 先月の税の取り合い（送るときに取られた分）・送金の制限で止められた分・為替の損の合計（保存する）
  double wht = 0, trap = 0, fxSum = 0;

  /// テストで段5を切る（保存しない）
  bool off = false;

  TradeState();

  Map<String, dynamic> toJson() => {
        'sup': {for (final e in sup.entries) '${e.key}': e.value},
        'adapt': adapt,
        'know': know,
        'exp': {for (final e in exp.entries) '${e.key}': e.value},
        'trapped': trapped,
        'stops': [for (final s in stops) s.toJson()],
        'shock': shock,
        'fric': fric,
        'done': done.toList(),
        'fx': {for (final e in fx.entries) '${e.key}': e.value},
        'last': [wht, trap, fxSum],
      };

  factory TradeState.fromJson(Map<String, dynamic>? j) {
    final t = TradeState();
    if (j == null) return t;
    Map<String, double> md(Object? o) => {for (final e in ((o as Map?) ?? {}).entries) '${e.key}': (e.value as num).toDouble()};
    t.sup = {for (final e in ((j['sup'] as Map?) ?? {}).entries) int.parse('${e.key}'): [for (final c in (e.value as List)) '$c']};
    t.adapt = md(j['adapt']);
    t.know = md(j['know']);
    t.exp = {for (final e in md(j['exp']).entries) int.parse(e.key): e.value};
    t.trapped = md(j['trapped']);
    t.stops = [for (final s in (j['stops'] as List? ?? [])) ActiveStop.fromJson((s as Map).cast<String, dynamic>())];
    t.shock = {for (final e in ((j['shock'] as Map?) ?? {}).entries) '${e.key}': [for (final v in (e.value as List)) (v as num).toDouble()]};
    t.fric = [for (final f in (j['fric'] as List? ?? [])) List<Object>.from(f as List)];
    t.done = {for (final d in (j['done'] as List? ?? [])) '$d'};
    t.fx = {for (final e in md(j['fx']).entries) int.parse(e.key): e.value};
    final last = [for (final v in (j['last'] as List? ?? const [])) (v as num).toDouble()];
    if (last.length == 3) {
      t.wht = last[0];
      t.trap = last[1];
      t.fxSum = last[2];
    }
    return t;
  }
}

double _lerpY(List<int> ys, List<double> vs, double y) {
  if (y <= ys.first) return vs.first;
  for (var i = 1; i < ys.length; i++) {
    if (y <= ys[i]) return vs[i - 1] + (vs[i] - vs[i - 1]) * (y - ys[i - 1]) / (ys[i] - ys[i - 1]);
  }
  return vs.last;
}

extension GameTrade on Game {
  /// 段5の仕組みを動かすか（試作との一致を見る遊びでは切る。テストは trade.off で切って比べる）
  bool get tradeOn => extras && !trade.off;

  // ===== インフラ =====
  /// 電気（0〜1）
  double powerOf(String c, [double? y]) {
    final v = POWER[c];
    return v == null ? 1 : _lerpY(INFRA_YEARS, v, y ?? yr());
  }

  /// 道路と物流（0〜1）
  double roadOf(String c, [double? y]) {
    final v = ROAD[c];
    return v == null ? .85 : _lerpY(INFRA_YEARS, v, y ?? yr());
  }

  /// ネットを使う人の割合（0〜1。1995年より前は0）
  double teleOf(String c, [double? y]) {
    final yy = y ?? yr();
    if (yy < 1995) return 0;
    final v = TELE[c];
    return v == null ? .5 : _lerpY(TELE_YEARS, v, yy);
  }

  /// 政治の不安定さ（0〜1）
  double polRisk(String c, [double? y]) {
    final v = POLRISK[c];
    return v == null ? .06 : _lerpY(INFRA_YEARS, v, y ?? yr());
  }

  /// 業種をその国に出せないわけ（電気・ネット。出せれば null）
  String? infraBlock(Industry ind, String c) {
    if (!tradeOn) return null;
    final k = kindOf(ind);
    if (k == 'net' && teleOf(c) < .08) return M('{0}ではネットを使う人がまだ少なく、「{1}」は出せません', [C(c), I(ind.id)]);
    const heavy = {'semi', 'semiequip', 'lcd', 'parts', 'datacenter', 'steel', 'chem', 'battery', 'ai', 'cloud', 'quantum'};
    final p = powerOf(c);
    if ((heavy.contains(ind.id) && p < .9) || (k == 'factory' && p < .6)) return M('{0}は電気が止まりやすく、「{1}」は置けません', [C(c), I(ind.id)]);
    return null;
  }

  /// 道路の網が広いほど、郊外と地方まで客が来る（都心・郊外・地方の客の分け方の倍。国の客の数そのものは変えない）
  double zoneReachF(String c, int z) {
    if (!tradeOn || z <= 0) return 1;
    final r = roadOf(c);
    return z == 1 ? .6 + .45 * r : .45 + .6 * r;
  }

  /// 店・工場などの売れる量の倍（道路が弱いと品切れ・電気が弱いと止まる）
  double infraSalesF(Biz b, String c) {
    final k = kindB(b);
    var f = 1.0;
    if (k == 'factory' || k == 'net' || k == 'infra') f *= 1 - .25 * (1 - powerOf(c));
    if (k == 'shop' || k == 'factory') f *= 1 - .3 * math.max(0, .9 - roadOf(c));
    return f;
  }

  // ===== 関税 =====
  /// [to] が [from] から入る物にかける関税（0.05 = 5%）。協定で下がり、摩擦で上がる
  double tariffOf(String to, String from, [String group = 'goods']) {
    if (to == from) return 0;
    final y = yr();
    var t = kp(TARIFF[to] ?? const [(1980, 8.0)], y) / 100 * (GROUPS[group]?.tariffK ?? 1);
    var cut = 0.0;
    for (final f in FTAS) {
      if (y < f.year || y >= f.end || !f.members.contains(to) || !f.members.contains(from)) continue;
      cut = math.max(cut, f.cut * math.min(1, (y - f.year + 1) / f.phase));
    }
    t *= 1 - cut;
    for (final f in FRICTIONS) {
      if (f.to == to && f.from == from && y >= f.y0 + (f.m0 - 1) / 12 && y < f.y1 + 1) t += f.add / 100;
    }
    for (final f in trade.fric) {
      if (f[0] == to && f[1] == from && turn < (f[2] as num)) t += (f[3] as num) / 100;
    }
    return t;
  }

  /// 協定で結ばれている相手（今の年）
  List<Fta> ftasOf(String a, String b) {
    final y = yr();
    return [for (final f in FTAS) if (y >= f.year && y < f.end && f.members.contains(a) && f.members.contains(b)) f];
  }

  // ===== 輸送 =====
  /// [from] から [to] へ [group] の物を運ぶ、いちばん安い手段と、その費用（値段に対する割合。運ぶ日数の重さを含む）と日数
  ({String mode, double cost, double freight, double days}) shipOf(String from, String to, [String group = 'goods']) {
    final g = GROUPS[group] ?? GROUPS['goods']!;
    if (from == to) {
      final f = .01 * (1.6 - roadOf(to));
      return (mode: 'home', cost: f + 2 * g.timeCost, freight: f, days: 2);
    }
    final y = yr();
    final km = geoKm(from, to);
    final cf = [from, to].any((c) => y < (CONTAINER_YEAR[c] ?? 1980)) ? 1.5 : 1.0;
    final congest = (1 - math.min(roadOf(from), roadOf(to))) * 8;
    final seaKm = km * 1.3;
    final seaF = kp(SEA_BASE, y) * (.3 + .7 * math.min(2.5, seaKm / 10000)) * g.density * cf;
    final seaD = seaKm / 550 + 4 + (cf > 1 ? 6 : 0) + congest;
    var best = (mode: 'sea', cost: seaF + seaD * g.timeCost, freight: seaF, days: seaD);
    if (g.density < 1.5 && group != 'oil') {
      final airF = kp(AIR_BASE, y) * (.6 + .4 * math.min(2, km / 10000)) * g.density;
      final airD = 2 + congest * .3;
      final c = airF + airD * g.timeCost;
      if (c < best.cost) best = (mode: 'air', cost: c, freight: airF, days: airD);
    }
    final ly = LAND['$from/$to'] ?? LAND['$to/$from'];
    if (ly != null && y >= ly) {
      final landKm = km * 1.2;
      final lf = kp(LAND_BASE, y) * landKm / 1000 * g.density * (1.6 - math.min(roadOf(from), roadOf(to)));
      final ld = landKm / 600 + 1 + congest * .5;
      final c = lf + ld * g.timeCost;
      if (c < best.cost) best = (mode: 'land', cost: c, freight: lf, days: ld);
    }
    return best;
  }

  // ===== 仕入れの網 =====
  /// 仕入れの種類（無ければ null）
  (String, double, bool)? inputOf(Biz b) => INPUT_OF[b.ind];

  /// 仕入れ先の国の値段の倍（相場の品はどこでも同じ。ほかは賃金が安い国ほど安い）
  double priceF(String s, String group) {
    if (GROUPS[group]?.commodity ?? false) return 1;
    final us = ev('us', 'wage_usd'), w = ev(s, 'wage_usd');
    return .85 + .2 * clampD(us > 0 ? w / us : 1, 0, 1.1);
  }

  /// その国から仕入れられるか（産地で、もう出られる年。ロシアは2022年から仕入れられない）
  bool srcOk(Biz b, String s) {
    final inp = inputOf(b);
    if (inp == null || !ctryOpen(s)) return false;
    if (s == 'ru' && yr() >= 2022.2 && home != 'ru') return false;
    final g = GROUPS[inp.$1]!;
    if (s == home && !g.commodity) return true;
    return g.sources.any((x) => x.$1 == s && year >= x.$2);
  }

  /// 仕入れられる国
  List<String> srcList(Biz b) => [for (final c in CTRY) if (srcOk(b, c.c)) c.c];

  /// [s] から [c] へ仕入れたときの、基準に対する値段の倍の内訳（値段・関税・輸送）
  ({double price, double tariff, double freight}) landedParts(Biz b, String c, String s, {int n = 1}) {
    final g = inputOf(b)?.$1 ?? 'goods';
    final p = priceF(s, g) * (1 + diversifyPremium * (n - 1));
    return (price: p, tariff: p * tariffOf(c, s, g), freight: p * shipOf(s, c, g).cost);
  }

  /// 仕入れ先（はじめて聞かれたときに、いちばん安い国を1つ選んで決める）
  List<String> supOf(Biz b) {
    final have = trade.sup[b.id];
    if (have != null && have.isNotEmpty) return have;
    final l = srcList(b);
    if (l.isEmpty) return const [];
    double tot(String s) {
      final x = landedParts(b, home, s);
      return x.price + x.tariff + x.freight;
    }

    l.ssort((x, y) => tot(x).compareTo(tot(y)));
    return trade.sup[b.id] = [l.first];
  }

  /// 止まっている国の、現場の落ち込み・仕入れの止まり方（いちばん大きいもの）
  double unitHit(String c) => trade.stops.where((s) => s.c == c).fold(0.0, (a, s) => math.max(a, s.unit));
  double supHit(String c) => trade.stops.where((s) => s.c == c).fold(0.0, (a, s) => math.max(a, s.sup));

  /// 仕入れが止まって作れなくなる倍（部品の業種だけ。相場の品は高くつくだけ）
  double supplyVolF(Biz b) {
    final inp = inputOf(b);
    if (inp == null || !inp.$3 || trade.stops.isEmpty) return 1;
    final l = supOf(b);
    if (l.isEmpty) return 1;
    final loss = l.fold(0.0, (a, s) => a + supHit(s)) / l.length;
    return 1 - loss * math.min(1, inp.$2 * 2);
  }

  // ===== 海外の難しさ =====
  /// 言葉の遠さ（0 同じ〜0.85 まったく違う）
  double langDist(String a, String b) {
    final p = NAMEC[a] ?? 'en', q = NAMEC[b] ?? 'en';
    if (p == q) return 0;
    if (q == 'en') return .6;
    final ga = LANG_GROUP[p], gb = LANG_GROUP[q];
    return ga != null && ga == gb ? .5 : .85;
  }

  /// 文化の遠さ（0〜0.75）
  double cultDist(String a, String b) {
    if (a == b) return 0;
    final ga = CULT_GROUP[a], gb = CULT_GROUP[b];
    if (ga != null && ga == gb) return .25;
    const far = {'in', 'me', 'af', 'ru'};
    return far.contains(ga) || far.contains(gb) ? .75 : .6;
  }

  /// 出た直後の現地の慣れ（言葉と文化が遠いほど低い。組む・買うと地元の人が助ける。視察で上がる）
  double adapt0(String c, String mode) {
    var a = 1 - .3 * langDist(home, c) - .15 * cultDist(home, c) + .1 * (trade.know[c] ?? 0);
    if (mode == 'jv') a += .15;
    if (mode == 'buy') a += .25;
    return clampD(a, .5, 1);
  }

  /// 現地の慣れ（0.5〜1。自分の国は1）
  double adaptOf(Biz b, String c) {
    if (c == home) return 1;
    return trade.adapt['${b.id}/$c'] ?? adapt0(c, (b.jv ?? const []).contains(c) ? 'jv' : 'solo');
  }

  /// その国の客の数の倍（現地の慣れ・止まっている・政変）。仕組みの reachOf が使う
  double ctryReachF(Biz b, String c) {
    if (!tradeOn || c == home) return 1;
    final sh = trade.shock[c];
    return adaptOf(b, c) * (1 - .5 * unitHit(c)) * (sh == null ? 1 : 1 - sh[1]);
  }

  /// 立地の売れる量の倍（止まっている国・仕入れ・インフラ）。仕組みの siteCapRev が使う
  double siteTradeF(Biz b, String s) {
    if (!tradeOn) return 1;
    final c = siteCtry(s);
    return (1 - unitHit(c)) * supplyVolF(b) * infraSalesF(b, c);
  }

  /// 人が [c] の言葉でどれだけ助けになるか（0〜1）
  double langHelp(Person p, String c) {
    final pool = NAMEC[c] ?? 'en';
    if (pool == homePool()) return 1;
    if (p.lg == pool) return 1;
    final l = (p.sk?['lang'] ?? 30) / 100;
    return pool == 'en' ? l : l * .4;
  }

  /// 現地を助ける人（いちばん助けになる人の度合い 0〜1 と、その人）。責任者は赴任するので重く、ほかの部下は軽く数える。
  /// 学校に通う子どもや介護のある責任者は赴任を断りがち
  (double, Person?) helperOf(Biz b, String c) {
    var best = 0.0;
    Person? who;
    for (final p in staff) {
      if (!p.real || p.away > 0) continue;
      final ex = .5 + .5 * math.min(1, (trade.exp[p.id] ?? 0) / 36);
      final mgr = b.mgr == p.id;
      final w = (mgr ? (refusesPosting(p) ? .3 : 1.0) : .45) * trHelpF(p);
      final v = langHelp(p, c) * ex * w;
      if (v > best) {
        best = v;
        who = p;
      }
    }
    return (best, who);
  }

  /// 現地の人を雇う難しさ（0.2〜1。失業が少ない国ほど難しい）
  double hireDiff(String c) => clampD(.5 + (6 - ev(c, 'unemp')) / 10, .2, 1);

  /// 外資の決まり（出られる出方。決まりが無ければ null。[] は出られない）
  List<String>? fdiModes(Biz b, String c) {
    final ind = indm[b.ind]!;
    final y = yr();
    final k = kindOf(ind);
    final retail = k == 'shop', fin = ind.cat == 'money';
    switch (c) {
      case 'cn':
        if (y < 1992) return ['jv'];
        if (retail && y < 2004) return ['jv'];
        if ((ind.id == 'auto' || ind.id == 'ev') && y < 2022) return ['jv'];
        if (fin && y < 2020) return ['jv'];
      case 'in':
        if (y < 1991) return ['jv'];
        if (ind.id == 'ec') return [];
        if (retail && y < 2006) return [];
        if (retail && y < 2012) return ['jv'];
        if (fin && y < 2021) return ['jv'];
      case 'id':
        if (retail && y < 1998) return [];
        if (y < 2007) return ['jv'];
      case 'th':
        if (retail || k == 'people' || fin) return ['jv'];
      case 'ph':
        if (retail && y < 2000) return [];
        if (retail) return ['jv'];
      case 'vn':
        if (y < 2007 && k != 'factory') return ['jv'];
        if (retail && y < 2009) return ['jv'];
      case 'kr':
        if (y < 1998 && (retail || fin)) return ['jv'];
      case 'mx':
        if (y < 1994) return ['jv'];
      case 'br':
        if (y < 1992 && (ind.cat == 'net' || const {'pc', 'kaden', 'semi', 'parts', 'handset'}.contains(ind.id))) return [];
      case 'sa':
        if (y < 2000) return ['jv'];
        if (retail && y < 2016) return ['jv'];
      case 'ru':
        if (y >= 2008 && (ind.cat == 'ene' || const {'tv', 'radio', 'newspaper'}.contains(ind.id))) return ['jv'];
      case 'ng':
        if (y < 1995) return ['jv'];
      case 'us' || 'au':
        if (home == 'cn' && y >= 2018) return ['solo', 'jv'];
      case 'tw':
        if (home == 'cn') return [];
    }
    return null;
  }

  /// 出方の決まり（インフラと外資の決まり。決まりが無ければ null）。仕組みの entryModes が使う
  List<String>? tradeModes(Biz b, String c) {
    if (!tradeOn || c == home) return null;
    if (infraBlock(indm[b.ind]!, c) != null) return [];
    return fdiModes(b, c);
  }

  /// 出られない・組む相手が要るわけ（画面用。無ければ null）
  String? entryNote(Biz b, String c) {
    if (!tradeOn || c == home) return null;
    final ib = infraBlock(indm[b.ind]!, c);
    if (ib != null) return ib;
    final f = fdiModes(b, c);
    if (f == null) return null;
    if (f.isEmpty) return M('{0}は外国の会社に「{1}」を開いていません', [C(c), I(b.ind)]);
    if (!f.contains('solo')) return M('{0}では、外国の会社は地元の会社と組まないと「{1}」を始められません', [C(c), I(b.ind)]);
    if (!f.contains('buy')) return M('{0}では、地元の会社を買うことが認められていません', [C(c)]);
    return null;
  }

  /// 現地法人を立ち上げるまでの月（会社を作る日数と、許可・人・場所を決める月）
  int setupMonths(String c, String mode) {
    final d = STARTDAYS[c] ?? const [40.0, 30.0, 10.0];
    final y = yr();
    var days = _lerpY(const [2004, 2010, 2020], d, y);
    if (y < 1995) days *= 1.5;
    final m = clampD(4 + days / 20, 3, 14).round();
    return mode == 'jv' ? math.max(2, (m * .5).round()) : m;
  }

  /// 送金の制限（利益のうち国の外へ出せない割合）
  double capCtl(String c) {
    if (c == home) return 0;
    for (final x in CAPCTL) {
      if (x.$1 == c && year >= x.$2 && year <= x.$3) return x.$4;
    }
    return 0;
  }

  /// 税の取り決めがあるか（無ければ、国の外へ送るときに1割を取られる）
  bool treaty(String c) => year >= math.max(TREATY_YEAR[c] ?? 0, TREATY_YEAR[home] ?? 0);

  /// その国の売上の割合（客の数の倍で重みを付ける）
  double revShare(Biz b, String c) {
    final r = reachOf(b);
    return r > 0 ? cw(c, yr()) * ctryReachF(b, c) / r : 0;
  }

  // ===== 計算のたびに（calcAll から） =====
  /// 事業の利益から、関税・輸送・インフラ・現地の人の手間・為替の損を引き、経費の内訳に足す
  void tradeCalc(Biz b) {
    if (!tradeOn || !unitsOn) return;
    final rev = math.max(0.0, b.rev);
    final pf = prof(b);
    final inp = inputOf(b);
    var cogsAdd = 0.0, logiAdd = 0.0, utilAdd = 0.0, labor = 0.0, tariff = 0.0, freight = 0.0, inputD = 0.0, expo = 0.0, exT = 0.0;
    final cs = ctryOf(b);
    final shares = {for (final c in cs) c: revShare(b, c)};
    final factory = kindB(b) == 'factory';
    // 1. 仕入れ（作る国・売る国ごとに、仕入れ先から運んだ値段を基準と比べる）
    if (inp != null && rev > 0) {
      final ib = (cogsOf[b.id] ?? 0) * inp.$2;
      final l = supOf(b);
      if (ib > 0 && l.isNotEmpty) {
        final ut = unitTotal(b);
        for (final c in cs) {
          final w = factory && ut > 0 ? unitsIn(b, c) / ut : shares[c]!;
          if (w <= 0) continue;
          var pr = 0.0, ta = 0.0, fr = 0.0;
          for (final s in l) {
            final x = landedParts(b, c, s, n: l.length);
            pr += x.price / l.length;
            ta += x.tariff / l.length;
            fr += x.freight / l.length;
          }
          final dP = ib * w * (pr - landedRef) / landedRef, dT = ib * w * ta / landedRef, dF = ib * w * fr / landedRef;
          inputD += dP;
          tariff += dT;
          freight += dF;
          cogsAdd += dP + dT;
          logiAdd += dF;
        }
        // 止まった国の相場の品は、ほかで買い直すので高くつく（3割）
        if (!inp.$3) {
          final st = l.fold(0.0, (a, s) => a + supHit(s)) / l.length;
          if (st > 0) {
            cogsAdd += ib * st * .3;
            inputD += ib * st * .3;
          }
        }
      }
    }
    // 2. 工場の品を外へ売る分（その国で作れない分は、作っている国から関税と運賃を払って運ぶ）
    if (factory && cs.length > 1 && rev > 0) {
      final g = inp?.$1 ?? 'goods';
      final cap = <String, double>{};
      for (final s in <String>{...b.sites.keys, for (final y in b.young) y.s}) {
        final c = siteCtry(s);
        cap[c] = (cap[c] ?? 0) + siteCapRev(b, s);
      }
      final sales = {for (final c in cs) c: rev * shares[c]!};
      final local = {for (final c in cs) c: math.min(sales[c]!, cap[c] ?? 0)};
      final surplus = {for (final e in cap.entries) e.key: math.max(0.0, e.value - (local[e.key] ?? 0))};
      final ts = surplus.values.fold(0.0, (a, x) => a + x);
      for (final c in cs) {
        final need = sales[c]! - local[c]!;
        if (need <= 0) continue;
        expo += need;
        final from = ts > 0 ? surplus : {home: 1.0};
        final tsum = ts > 0 ? ts : 1.0;
        for (final e in from.entries) {
          if (e.value <= 0 || e.key == c) continue;
          final part = need * e.value / tsum * .7;
          final t = part * tariffOf(c, e.key, g), f = part * shipOf(e.key, c, g).cost;
          tariff += t;
          exT += t;
          freight += f;
          cogsAdd += t;
          logiAdd += f;
        }
      }
    }
    // 3. インフラ（道路と電気が弱い国の物流費と光熱費）
    final split = KIND_FIX_SPLIT[pf.kind]!;
    var infra = 0.0;
    for (final s in <String>{...b.sites.keys, for (final y in b.young) y.s}) {
      final c = siteCtry(s);
      final base = siteFixed(b, s);
      final u = base * split[1] * .8 * (1 - powerOf(c)), lg = base * split[2] * 1.5 * math.max(0, .9 - roadOf(c));
      utilAdd += u;
      logiAdd += lg;
      infra += u + lg;
    }
    // 4. 現地の人を雇う手間（慣れていないほど・人の取り合いが激しい国ほど）
    for (final c in cs) {
      if (c == home) continue;
      labor += rev * shares[c]! * .12 * hireDiff(c) * (1 - adaptOf(b, c)) / .45;
    }
    // 5. 為替の損（毎月の初めに決めた分）
    final fx = trade.fx[b.id] ?? 0;
    cogsAdd += fx;
    b.profit -= cogsAdd + logiAdd + utilAdd + labor;
    if (cogsOf.containsKey(b.id)) cogsOf[b.id] = math.max(0.0, cogsOf[b.id]! + cogsAdd);
    final fo = fixOf[b.id];
    if (fo != null) {
      fo[1] += utilAdd;
      fo[2] += logiAdd;
    }
    trade.labor[b.id] = labor;
    trade.view[b.id] = {'tariff': tariff, 'freight': freight, 'input': inputD, 'export': expo, 'exTariff': exT, 'infra': infra, 'labor': labor, 'fx': fx};
  }

  /// その国に出ているか、そこから仕入れているか
  bool exposed(String c) => biz.any((b) => ctryOf(b).contains(c) || (inputOf(b) != null && supOf(b).contains(c)));

  // ===== 毎月 =====
  void monthTrade(void Function(String, [String]) N) {
    if (!tradeOn || !unitsOn) return;
    final y = yr();
    trade.fx = {};
    // 年の初め：分かっていることは少しずつ古くなる。協定・WTO の知らせ
    if (q == 1) {
      for (final c in trade.know.keys.toList()) {
        trade.know[c] = trade.know[c]! * .95;
      }
      for (final f in FTAS) {
        if (f.year != year || !f.members.contains(home)) continue;
        final k = 'fta:${f.ja}:${f.year}';
        if (trade.done.add(k)) N(M('{0}が始まりました。加盟国どうしの関税が{1}年かけて下がります', [D(f.ja), f.phase]), 'good');
      }
      for (final e in WTO_YEAR.entries) {
        if (e.value == year && e.key != home && exposed(e.key) && trade.done.add('wto:${e.key}')) {
          N(M('{0}がWTOに入りました。関税が下がり、外資の決まりが緩みます', [C(e.key)]), 'good');
        }
      }
    }
    // 貿易摩擦の始まり
    for (final f in FRICTIONS) {
      if (f.y0 == year && f.m0 == q && (f.to == home || f.from == home || exposed(f.to)) && trade.done.add('fric:${f.to}:${f.from}:${f.y0}')) {
        N(M('{0}：{1}は{2}から入る物に関税を{3}%上乗せしました', [D(f.ja), C(f.to), C(f.from), f.add.round()]), 'bad');
      }
    }
    // これからの年の貿易摩擦（データの最後の年より先）
    trade.fric.removeWhere((f) => turn >= (f[2] as num));
    if (year > econData.lastYear && rnd() < .003) {
      const big = ['us', 'cn', 'de', 'jp', 'in', 'kr', 'uk', 'mx', 'ca'];
      final a = pick(big);
      final bb = pick(big.where((x) => x != a).toList());
      final add = ri(10, 25);
      final until = turn + ri(24, 48);
      trade.fric.add([a, bb, until, add]);
      trade.fric.add([bb, a, until, add]);
      if (a == home || bb == home || exposed(a) || exposed(bb)) N(M('{0}と{1}の貿易摩擦が始まり、互いの関税が{2}%上がりました', [C(a), C(bb), add]), 'bad');
    }
    // 止まっている国：減らす・終わる
    for (final s in trade.stops.toList()) {
      s.left--;
      if (s.left <= 0) {
        trade.stops.remove(s);
        if (exposed(s.c)) N(M('{0}の{1}から立ち直り、仕入れと現場が戻りました', [C(s.c), s.ja]), 'good');
      }
    }
    // 実際に起きた出来事
    for (final d in STOPS) {
      if (d.y == year && d.m == q && trade.done.add('stop:${d.c}:${d.y}:${d.m}')) {
        trade.stops.add(ActiveStop(c: d.c, ja: M(d.ja), left: d.months, unit: d.unit, sup: d.sup));
        if (exposed(d.c)) N(M('{0}で{1}。現場と仕入れが止まっています（{2}か月ほど）', [C(d.c), M(d.ja), d.months]), 'bad');
        // 店や工場の修理と保険（1.1.0+30）
        if (d.unit > 0) disasterHit(d.c, d.unit, N);
      }
    }
    // 自社が関わる国の、思いがけない災害（地震・台風・洪水・大きな事故）
    final ex = [for (final c in CTRY) if (ctryOpen(c.c) && exposed(c.c)) c.c];
    for (final c in ex) {
      if (trade.stops.any((s) => s.c == c)) continue;
      if (rnd() < .0025 * (HAZARD[c] ?? 1)) {
        final kinds = ['大きな地震', '台風', '洪水', '港の事故', '港のストライキ'];
        final ja = pick(kinds);
        final st = ActiveStop(c: c, ja: M(ja), left: ri(1, 3), unit: .03 + rnd() * .07, sup: .2 + rnd() * .3);
        trade.stops.add(st);
        N(M('{0}で{1}。現場と仕入れが止まっています（{2}か月ほど）', [C(c), M(ja), st.left]), 'bad');
        // 港の事故・ストライキは運べなくなるだけで、店や工場は傷まない（1.1.0+30）
        if (kinds.indexOf(ja) < 3) disasterHit(c, st.unit, N);
      }
    }
    // 仕入れ先が使えなくなった国を外す（ロシアなど）。全部だめなら選び直す
    for (final b in biz) {
      if (inputOf(b) == null) continue;
      final l = supOf(b);
      final ok = l.where((s) => srcOk(b, s)).toList();
      if (ok.length != l.length) {
        if (ok.isEmpty) {
          trade.sup.remove(b.id);
          supOf(b);
        } else {
          trade.sup[b.id] = ok;
        }
        N(M('「{0}」は仕入れ先を変えました（{1}）', [I(b.ind), J([for (final s in supOf(b)) C(s)])]), 'bad');
      }
    }
    // 海外の国ごと
    var trap = 0.0, wht = 0.0, fxSum = 0.0;
    final shocked = <String>{};
    for (final b in biz.toList()) {
      for (final c in ctryOf(b).toList()) {
        if (c == home) continue;
        final share = revShare(b, c);
        // 現地の慣れが育つ
        final key = '${b.id}/$c';
        final a = adaptOf(b, c);
        final h = helperOf(b, c).$1;
        trade.adapt[key] = math.min(1, a + (1 - a) * (.02 + .05 * h + .02 * (trade.know[c] ?? 0)));
        // 文化の違いによる失敗（慣れていないほど起きやすい。その国の客が離れ、慣れは少し上がる＝失敗から学ぶ）
        if (rnd() < .004 * (1 - a) / .3) {
          b.power *= 1 - .3 * share;
          trade.adapt[key] = math.min(1, trade.adapt[key]! + .03);
          N(M(pick(const ['{0}で「{1}」の広告が現地の習慣に合わず、反発を受けました', '{0}で「{1}」の商品が現地の好みに合わず、売れ残りました', '{0}で「{1}」が祝日や宗教の決まりを知らずに営業し、評判を落としました']), [C(c), I(b.ind)]), 'bad');
        }
        // 為替の損（現地にある売掛と在庫の値打ちが、通貨の動きで増減する）
        final r0 = ev(home, 'fx_usd', y - 1 / 12) / math.max(ev(c, 'fx_usd', y - 1 / 12), 1e-12);
        final r1 = ev(home, 'fx_usd', y) / math.max(ev(c, 'fx_usd', y), 1e-12);
        final ratio = r0 > 0 && r1.isFinite ? clampD(r1 / r0, .3, 3) : 1.0;
        final wc = math.max(0.0, b.rev) * share * 1.5;
        final loss = wc * (1 - ratio);
        trade.fx[b.id] = (trade.fx[b.id] ?? 0) + loss;
        fxSum += loss;
        if (ratio < .85 && trade.done.add('fx:$c:$year:$q')) {
          N(M('{0}の通貨が急に下がり、現地にあるお金の値打ちが減りました（為替の損 {1}）', [C(c), Y(loss)]), 'bad');
        }
        // 送金の制限と税の取り合い（現地の利益を国へ戻すとき）
        final pc = math.max(0.0, b.profit) * share;
        final cc = capCtl(c);
        final held = pc * cc;
        if (held > 0) {
          cash -= held;
          trade.trapped[c] = (trade.trapped[c] ?? 0) + held;
          trap += held;
        }
        if (!treaty(c)) {
          final w = (pc - held) * .1;
          cash -= w;
          wht += w;
        }
        // 政変と国有化（政治が不安定な国ほど）
        final risk = polRisk(c);
        if (!trade.shock.containsKey(c) && !shocked.contains(c) && rnd() < .0015 * risk) {
          shocked.add(c);
          trade.shock[c] = [ri(3, 9).toDouble(), .1 + rnd() * .2];
          N(M('{0}で政変が起き、外国の会社の客が離れました（{1}か月ほど続きます）', [C(c), trade.shock[c]![0].round()]), 'bad');
        }
        if (risk >= .5 && rnd() < .00025 * risk) nationalize(b, c, N);
      }
    }
    // 出せないお金は、制限が緩むと少しずつ戻る（出ていない国のものも）
    for (final c in trade.trapped.keys.toList()) {
      final v = trade.trapped[c]!;
      final rel = v * (capCtl(c) < .05 ? .2 : .02);
      if (rel > 0 && !(c == 'ru' && capCtl(c) > .5)) {
        trade.trapped[c] = v - rel;
        cash += rel;
      }
      if (trade.trapped[c]! < 1) trade.trapped.remove(c);
    }
    // 政変の残り
    for (final c in trade.shock.keys.toList()) {
      if (shocked.contains(c)) continue;
      final s = trade.shock[c]!;
      s[0] -= 1;
      if (s[0] <= 0) trade.shock.remove(c);
    }
    // 海外の経験（海外に出ている事業の責任者・留学している人）
    for (final p in staff) {
      if (!p.real) continue;
      final abroad = (p.away > 0 && p.awayWhy == 'abroad') ||
          (p.away == 0 && !refusesPosting(p) && biz.any((b) => b.mgr == p.id && ctryOf(b).any((c) => c != home)));
      // どこでも溶け込む人は、3倍の早さで現地に慣れる（1.1.0+33）
      if (abroad) trade.exp[p.id] = (trade.exp[p.id] ?? 0) + (p.has('blend') ? 3 : 1);
    }
    trade.trap = trap;
    trade.wht = wht;
    trade.fxSum = fxSum;
  }

  /// 国有化：その国の店・工場などを取り上げられ、値打ちの3割だけが戻る
  void nationalize(Biz b, String c, void Function(String, [String]) N) {
    final n = unitsIn(b, c);
    final back = n * unitCapexAvg(b) * .3;
    b.sites.removeWhere((k, _) => siteCtry(k) == c);
    b.young.removeWhere((y) => siteCtry(y.s) == c);
    b.pipe.removeWhere((x) => x.k == 'open' && siteCtry(x.c ?? '') == c);
    b.ctry = ctryOf(b).where((x) => x != c).toList();
    b.jv?.remove(c);
    trade.adapt.remove('${b.id}/$c');
    cash += back;
    N(M('{0}の政府が「{1}」を国有化しました。戻ったのは{2}だけです', [C(c), I(b.ind), Y(back)]), 'bad');
    calcAll();
  }

  /// 海外に出たとき（仕組みの addCtry から）：出方に合わせて現地の慣れを決める
  void tradeEntered(Biz b, String c, String mode) {
    if (!tradeOn || c == home) return;
    trade.adapt['${b.id}/$c'] = adapt0(c, mode);
  }

  // ===== 手 =====
  /// 視察の費用（1週間の出張）
  double inspectCost(String c) => (3e6 + geoKm(home, c) * 300) * nom();

  /// 視察する（社長の時間 1週間）。関税・物流・政治・伸びている業種が詳しく分かり、出たあとの慣れも早くなる
  String inspect(String c) {
    if (c == home) return M('自分の国は視察しなくても分かります');
    if (!ctryOpen(c)) return M('この年はまだ入れません');
    final cost = inspectCost(c);
    if (cash < cost) return M('お金が足りません');
    final nt = spendT('inspect');
    if (nt != null) return nt;
    cash -= cost;
    trade.know[c] = math.min(1, (trade.know[c] ?? 0) + .6);
    calcAll();
    return M('{0}を1週間視察しました（{1}）。関税・物流・政治・伸びている業種が詳しく分かりました', [C(c), Y(cost)]);
  }

  /// 詳しく分かっているか（自分の国と、視察した国）
  bool knowsCtry(String c) => c == home || (trade.know[c] ?? 0) >= .3;

  /// 仕入れ先を足す費用（取引の条件と品質を合わせる手間）
  double supplierCost(Biz b) => math.max(5e6 * nom(), (cogsOf[b.id] ?? 0) * .1);

  /// 仕入れ先を足す（社長の時間 6時間）
  String addSupplier(Biz b, String s) {
    if (inputOf(b) == null) return M('この事業は仕入れの網を持ちません');
    final l = supOf(b);
    if (l.contains(s)) return M('すでにその国から仕入れています');
    if (l.length >= maxSuppliers) return M('仕入れ先は{0}か国までです', [maxSuppliers]);
    if (!srcOk(b, s)) return M('{0}からは仕入れられません', [C(s)]);
    final cost = supplierCost(b);
    if (cash < cost) return M('お金が足りません');
    final nt = spendT('supply');
    if (nt != null) return nt;
    cash -= cost;
    trade.sup[b.id] = [...l, s];
    calcAll();
    return M('「{0}」の仕入れ先に{1}を足しました（{2}）。1か国が止まっても作り続けやすくなりますが、まとめ買いの値引きが減ります', [I(b.ind), C(s), Y(cost)]);
  }

  /// 仕入れ先を外す（時間はかからない）
  String dropSupplier(Biz b, String s) {
    final l = supOf(b);
    if (!l.contains(s)) return M('その国からは仕入れていません');
    if (l.length <= 1) return M('仕入れ先が1か国だけのときは外せません');
    trade.sup[b.id] = l.where((x) => x != s).toList();
    calcAll();
    return M('「{0}」の仕入れ先から{1}を外しました', [I(b.ind), C(s)]);
  }

  /// その国で伸びている業種（3年前と比べた市場の伸び。出せない業種は除く）
  List<Industry> growingIn(String c) {
    final y = yr();
    final l = liveInds().where((i) => infraBlock(i, c) == null && eraF(i, y - 3) > 0).toList()
      ..ssort((a, b) => (eraF(b, y) / eraF(b, y - 3)).compareTo(eraF(a, y) / eraF(a, y - 3)));
    return l.take(3).toList();
  }
}
