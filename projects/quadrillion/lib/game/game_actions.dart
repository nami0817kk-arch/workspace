// ignore_for_file: non_constant_identifier_names
part of 'game.dart';

/// プレイヤーの手（どれも結果の文を返す）
extension GameActions on Game {
  String startBiz(String id, [String? model]) {
    final ind = indm[id]!;
    final c = capexOf(ind);
    if (cash < c) return M('元手が足りません');
    final nt = needT('start');
    if (nt != null) return nt;
    if (biz.any((b) => b.ind == id)) return M('すでにその業種にいます');
    final nb0 = newIndBlock(id);
    if (nb0 != null) return nb0;
    final free = biz.isEmpty && !everBiz;
    cfAdd('capex', -c);
    capSpend(c, profileOf(ind).life);
    useT('start');
    everBiz = true;
    var p = c * newPow;
    if (hasT('genius')) p *= .5 + rnd() * 1.7;
    final early = yr() - ind.b < 3;
    final nb = Biz(id: uid(), ind: id, early: early ? turn + 60 : 0, model: model ?? 'direct', power: p, crew: p * 1.2);
    biz.add(nb);
    // 新しい事業を始めるのは一度きりの山（1か月の上限に数えない）
    presXp('kai', 5, big: true);
    presXp('ei', 2, big: true);
    // 元手で買える分の店・ラインなどを置く（許認可型は許可を待つ。1.1.0+26）
    initUnits(nb, c);
    if (free) chron('first_biz', M('{0}「{1}」を始めた', [M(serial > 0 ? '新しい会社で' : '最初の事業として'), I(id)]));
    calcAll();
    return M('「{0}」を{1}で始めました（元手 {2}）', [I(id), D(MODELN.ja[model ?? 'direct']!), Y(c)]);
  }

  /// 新しい業種に入れない理由（入れるなら null）。始める・業態を変える・部下の提案で同じ決まりを見る（1.1.0+37）
  /// - 株を過半持つ子会社がいる業種は、自社では始めない（1.1.0+36。game_names.dart）
  /// - 資格が要る業種は、資格を持つ人がいるか
  /// - 銀行が経営に口を出している間は、新しい事業を始められない
  /// - 会社を売ったときの「同じ業種に入らない約束」
  String? newIndBlock(String id) {
    final sb = subBlock(id);
    if (sb != null) return sb;
    final lm = licMissing(id);
    if (lm != null) return lm;
    if (bankCtl > 0 && biz.isNotEmpty) return M('銀行が経営に口を出している間は、新しい事業を始められません');
    if (noncomp != null && turn < noncomp!.until && noncomp!.inds.contains(id) && !noncomp!.broken) {
      return M('会社を売ったときの約束で、この業種にはまだ入れません（「株」の画面で約束を破ることもできます）');
    }
    return null;
  }

  double invBase(Biz b) => math.max(capexOf(indm[b.ind]!), b.rev * 3);

  String invest(Biz b, double frac) {
    final cost = math.max(0.0, cash * frac);
    if (cost <= 0) return M('お金がありません');
    final nt = needT('invest');
    if (nt != null) return nt;
    cfAdd('grow', -cost);
    useT('invest');
    final rel = cost / math.max(b.rev + capexOf(indm[b.ind]!), 1);
    var eff = invEff * math.pow(1 - b.share, 2) * clampD(math.pow(rel, -.12).toDouble(), .55, 1.3) * smallBonus(b);
    if (hasT('genius')) eff *= .4 + rnd() * 1.8;
    if (hasT('gambler')) {
      if (rnd() < .2) {
        eff = 0;
      } else if (frac >= .5) {
        eff *= 1.3;
      }
    }
    final p = staffById(b.mgr);
    final kai = p != null ? p.ab['kai']! : pres.ab['kai']!;
    eff *= .7 + kai / 100 * .6;
    final s0 = b.share, r0 = b.rev;
    b.power += cost * eff;
    calcAll();
    return eff == 0 ? M('投資は空振りに終わりました…') : M('{0}を投資しました。シェア {1} → {2}、売上の見込み {3} → {4}', [Y(cost), pct(s0 * 100), pct(b.share * 100), Y(r0), Y(b.rev)]);
  }

  // ===== 国 =====
  List<String> entryModes(Biz b, String c) {
    final cat = indm[b.ind]!.cat;
    // 統計がまだ無い年の国には出られない（ロシアは1991年まで。1.1.0+25）
    if (!ctryOpen(c)) return [];
    // 中国に現地法人があれば、ネットと金融も組む相手なしで入れる（地元の規制の緩み。game_local.dart）
    if (c == 'cn' && (cat == 'net' || cat == 'money')) return extras && hasLocal('cn') ? ['solo', 'jv', 'buy'] : ['jv'];
    if (c == 'ru' && yr() >= 2022.5) return [];
    // 1.1.0+28 から、電気・ネットが足りない国と、外資の決まりのある国（game_trade.dart）
    return tradeModes(b, c) ?? ['solo', 'jv', 'buy'];
  }

  double entryCost(Biz b, String c, String mode) {
    final base = math.max(capexOf(indm[b.ind]!), b.rev * 6) * cw(c, yr()) / math.max(cw(home, yr()), .3) * .8;
    return base *
        (mode == 'jv'
            ? .5
            : mode == 'buy'
                ? 2.5
                : 1);
  }

  void addCtry(Biz b, String c, String mode, double pw) {
    if (c != home && !biz.any((x) => ctryOf(x).contains(c))) {
      chron('abroad', M('{0}に進出した（「{1}」・{2}）', [C(c), I(b.ind), D(ENTRYN.ja[mode]!)]));
    }
    b.ctry = ctryOf(b).toList();
    if (!b.ctry!.contains(c)) {
      b.ctry!.add(c);
      tradeEntered(b, c, mode);
    }
    if (mode == 'jv') {
      b.jv ??= [];
      if (!b.jv!.contains(c)) b.jv!.add(c);
    }
    b.power += pw;
    b.crew = crewOf(b) + pw;
    // 出た国にも店・ラインなどを置く（出るのに使ったお金の分。海外の作り込みは後の段。1.1.0+26）
    if (unitsOn) {
      final u = unitRevNow(b);
      if (u > 0) seedUnits(b, c, math.max(1, (pw / 3 / u * .6).round()));
    }
  }

  String enterCountry(Biz b, String c, String mode) {
    final nt = needT('enter');
    if (nt != null) return nt;
    if (ctryOf(b).contains(c)) return M('すでに出ています');
    if (!entryModes(b, c).contains(mode)) return M('その出方はできません');
    if (b.pipe.any((x) => x.k == 'enter' && x.c == c)) return M('すでに準備中です');
    if (extras && hasLocal(c, b.ind)) return M('その国には現地法人が出ています');
    final cost = entryCost(b, c, mode);
    if (cash < cost) return M('お金が足りません');
    cfAdd('grow', -cost);
    useT('enter');
    presXp('ei', 1.5);
    final pw = cost * 1.1 + b.power * cw(c, yr()) / reachOf(b) * .5;
    if (mode == 'buy') {
      addCtry(b, c, mode, pw);
      calcAll();
      return M('{0}の地元の会社を買い、すぐに「{1}」を始めました', [C(c), I(b.ind)]);
    }
    // 1.1.0+28 から、立ち上げの月は国と年で変わる（会社を作る日数と許可。game_trade.dart）
    final left = tradeOn ? setupMonths(c, mode) : (mode == 'jv' ? 3 : 6);
    b.pipe.add(Pipe(k: 'enter', c: c, mode: mode, cost: cost, pw: pw, left: left));
    calcAll();
    return M('{0}に出る準備を始めました（{1}）。{2}か月後に始まります', [C(c), D(ENTRYN.ja[mode]!), left]);
  }

  // ===== 稼ぎ方 =====
  List<String> modelsFor(String id) => ['direct', ...['fc', 'sub', 'plat'].where((k) => MODELS_BY[k]!.contains(id))];
  double modelMg(Biz b) {
    final m = b.model;
    return m == 'fc'
        ? .45
        : m == 'sub'
            ? .6
            : m == 'plat'
                ? clampD(-.15 + b.share * 10, -.15, 2.2)
                : 1;
  }

  String uw(Biz b) {
    // 1.1.0+26 から、稼ぎの型があれば型で呼ぶ（冷凍食品は工場型なので「工場」。分類の食だからと「店」にしない）
    if (unitsOn) {
      return M(switch (kindB(b)) {
        'shop' => '店',
        'factory' => '工場',
        'people' || 'license' => '拠点',
        _ => '設備',
      });
    }
    final c = indm[b.ind]!.cat;
    return M(c == 'food' || c == 'live' || c == 'fun'
        ? '店'
        : c == 'make' || c == 'ene'
            ? '工場'
            : c == 'link'
                ? '拠点'
                : '設備');
  }

  String changeModel(Biz b, String m) {
    final nt = needT('model');
    if (nt != null) return nt;
    if (b.model == m) return M('すでにその稼ぎ方です');
    useT('model');
    b.model = m;
    b.power *= .85;
    calcAll();
    return M('「{0}」を{1}に切り替えました。切り替えの混乱で、力が少し落ちます', [I(b.ind), D(MODELN.ja[m]!)]);
  }

  // ===== 打ち手 =====
  double pipeEff(Biz b, double cost) {
    final rel = cost / math.max(b.rev * 3 + capexOf(indm[b.ind]!), 1);
    return (b.early > turn ? 1.6 : 1) * invEff * math.pow(1 - b.share, 2) * clampD(math.pow(rel, -.12).toDouble(), .55, 1.3) * smallBonus(b);
  }

  /// 現金の割合で商品を作る（試作の手。extras を切った一致テストと、自動プレイの古い流れが使う）
  String develop(Biz b, double frac) {
    final cost = cash * frac;
    if (cost <= 0) return M('お金がありません');
    final nt = needT('dev');
    if (nt != null) return nt;
    cfAdd('grow', -cost);
    useT('dev');
    final left = ri(3, 6);
    b.pipe.add(Pipe(k: 'dev', cost: cost, left: left));
    presXp('kai', 2);
    calcAll();
    return M('新しい商品の開発を始めました（{0}）。出来上がるのは{1}か月後。当たるかどうかは出てみるまで分かりません', [Y(cost), left]);
  }

  /// 現金の割合で店・工場を増やす（試作の手。extras を切った一致テストと、自動プレイの古い流れが使う）
  String build(Biz b, double frac) {
    final cost = cash * frac;
    if (cost <= 0) return M('お金がありません');
    // 1.1.0+26 から、お金の割合では店を増やせない。今いちばん要る伸ばす手（責任者・本部・拠点・開く）を、その額まで打つ
    if (unitsOn) {
      final o = growOpt(b, cost, want: 10, time: true);
      return o == null ? M('今は店などを増やせません（上限・責任者・物件のどれかが足りません）') : o.run();
    }
    final nt = needT('build');
    if (nt != null) return nt;
    cfAdd('grow', -cost);
    useT('build');
    final left = b.model == 'fc' ? 1 : ri(1, 2);
    b.pipe.add(Pipe(k: 'build', cost: cost, left: left));
    calcAll();
    return M('{0}を増やし始めました（{1}）。{2}か月後に開きます。{3}', [uw(b), Y(cost), left, M(b.model == 'fc' ? '人は加盟店が集めます' : '回すには現場の人が要ります')]);
  }

  // ===== 1単位の手（1.0.0+12。画面と提案はこちらを使う） =====
  /// 「店を3つ」「設備を1式」のような数え方
  String unitsOf(Biz b, int n) {
    final c = indm[b.ind]!.cat;
    final one = n == 1;
    final k = c == 'food' || c == 'live' || c == 'fun'
        ? (one ? '店を1つ' : '店を{0}店舗')
        : c == 'make' || c == 'ene'
            ? (one ? '工場を1つ' : '工場を{0}か所')
            : c == 'link'
                ? (one ? '拠点を1つ' : '拠点を{0}か所')
                : (one ? '設備を1式' : '設備を{0}式');
    return M(k, [n]);
  }

  /// 店・工場をn個増やす値段（1つがその業種の元手）
  double buildCost(Biz b, int n) => unitsOn ? unitCapexAvg(b) * n : capexOf(indm[b.ind]!) * n;

  String buildN(Biz b, int n) {
    // 1.1.0+26 から、いちばん良い立地から n まで開く（物件・責任者・上限の分だけ）
    if (unitsOn) return openBest(b, n);
    final cost = buildCost(b, n);
    if (cash < cost) return M('お金が足りません');
    final nt = needT('build');
    if (nt != null) return nt;
    cfAdd('grow', -cost);
    useT('build');
    final left = b.model == 'fc' ? 1 : ri(1, 2);
    b.pipe.add(Pipe(k: 'build', cost: cost, left: left));
    calcAll();
    return M('{0}増やし始めました（{1}）。{2}か月後に開きます。{3}', [unitsOf(b, n), Y(cost), left, M(b.model == 'fc' ? '人は加盟店が集めます' : '回すには現場の人が要ります')]);
  }

  /// 今ある店・工場を広げる値段（1.0.0+17。その業種の元手の [extendMult] 倍の固定額）。
  /// 最初の事業を始めた直後は、店を1つ（＝元手）増やせるお金がたまるまで数か月、事業に打てる手が無かったので、小さい単位を足した
  double extendCost(Biz b) => unitsOn ? renovateCost(b) : capexOf(indm[b.ind]!) * extendMult;

  /// 今ある店・工場を広げる。仕組みは店・工場を増やすのと同じ（払った額が仕掛かりに入り、開いたときに同じ式で伸びる）
  String extendN(Biz b) {
    final cost = extendCost(b);
    if (unitsOn && b.upg >= upgMax - 1e-9) return M('これ以上は改装しても売上が伸びません');
    if (cash < cost) return M('お金が足りません');
    final nt = needT('extend');
    if (nt != null) return nt;
    cfAdd('grow', -cost);
    useT('extend');
    b.pipe.add(Pipe(k: 'build', cost: cost, left: 1, ext: true));
    calcAll();
    return M('今ある{0}を広げ始めました（{1}）。来月から使えます。{2}', [uw(b), Y(cost), M(b.model == 'fc' ? '人は加盟店が集めます' : '回すには現場の人が要ります')]);
  }

  /// 商品の大きさの名前
  String devName(int sz) => M(sz == 0
      ? '小さな改良'
      : sz == 2
          ? '大型開発'
          : '新しい商品');

  /// 商品を作る値段（元手の1倍・3倍・10倍）
  double devCost(Biz b, int sz) => capexOf(indm[b.ind]!) * devMults[sz];

  String developN(Biz b, int sz) {
    final cost = devCost(b, sz);
    if (cash < cost) return M('お金が足りません');
    final nt = needT('dev');
    if (nt != null) return nt;
    cfAdd('grow', -cost);
    useT('dev');
    final left = ri(devMonths[sz].$1, devMonths[sz].$2);
    b.pipe.add(Pipe(k: 'dev', cost: cost, left: left, sz: sz));
    presXp('kai', (sz + 1) * 2.0);
    calcAll();
    return M('{0}を始めました（{1}）。出来上がるのは{2}か月後。当たるかどうかは出てみるまで分かりません', [devName(sz), Y(cost), left]);
  }

  /// 現場の人1人の年の人件費（業種の分類で決まり、時代の物価だけが乗る）
  /// 1.1.0+25 から、その国の賃金と最低賃金の統計で動く（[GameReal.wageCat]）
  double wageOf(Biz b) => wageCat(indm[b.ind]!.cat);

  /// 現場の人1人の現場の力（3年分の総額1円あたりが、割合の手と同じになるように合わせる）
  double crewPerHead(Biz b) => wageOf(b) * crewPerYen3y * (hireFee + 3);

  /// n人を雇う採用の費用（その場で払う）
  double hireCost(Biz b, int n) => wageOf(b) * hireFee * n;

  /// n人ぶん増える毎月の人件費
  double payPerMonth(Biz b, int n) => wageOf(b) / 12 * n;

  /// 止まっている店や工場をちょうど動かすのに足りない人数（足りていれば 0）
  int crewNeedPeople(Biz b) {
    if (b.model == 'fc' || b.power <= 0) return 0;
    final have = crewEff(b);
    final want = crewWant(b);
    if (have >= want) return 0;
    return ((want - have) / (crewMult(b) * crewPerHead(b)) - 1e-9).ceil();
  }

  /// 現場の人で回したい力。店などの数で売上が頭打ちのときは、売れる分を回せるだけでよい（1.1.0+26）
  double crewWant(Biz b) {
    final k = unitsOn ? (capKOf[b.id] ?? 1) : 1.0;
    return k < .999 ? math.min(b.power, usedPow(b) * k * 1.02) : b.power;
  }

  /// 現場の人をn人雇う
  String hireN(Biz b, int n) {
    if (b.model == 'fc') return M('人は加盟店が集めます');
    if (n <= 0) return M('人は足りています');
    final cost = hireCost(b, n);
    if (cash < cost) return M('お金が足りません');
    final nt = needT('crew');
    if (nt != null) return nt;
    cfAdd('grow', -cost);
    useT('crew');
    _addHeads(b, n);
    presXp('tou', .4);
    calcAll();
    return M('現場の人を{0}人増やしました（採用の費用 {1}）。毎月の人件費が{2}増えます', [n, Y(cost), Y(payPerMonth(b, n))]);
  }

  void _addHeads(Biz b, int n) {
    b.crew = crewOf(b) + crewPerHead(b) * n;
    b.upkeep = b.upkeep + payPerMonth(b, n);
  }

  /// 足りない分だけ現場の人を補う
  String addCrewNeeded(Biz b) => hireN(b, crewNeedPeople(b));

  // ===== まとめての手（1.0.0+18。事業が20〜30ある会社で、同じ手を事業の数だけ繰り返さずに済むように） =====
  /// 現場の人が足りない事業（足りない割合の大きい順）
  List<Biz> crewShort() => biz.where((b) => crewNeedPeople(b) > 0).toList()..ssort((a, b) => (crewEff(a) / crewWant(a)).compareTo(crewEff(b) / crewWant(b)));

  /// [crewShort] のうち、今の手とお金で足りない分を雇える事業（先頭から。払えない事業は飛ばす）
  List<Biz> crewShortDoable() {
    var c = cash;
    final out = <Biz>[];
    for (final b in crewShort()) {
      if (down > 0 || (out.length + 1) * hrs('crew') > hLeft()) break;
      final cost = hireCost(b, crewNeedPeople(b));
      if (cost > c) continue;
      c -= cost;
      out.add(b);
    }
    return out;
  }

  /// 人が足りない事業に、足りない分をまとめて雇う。1つずつ雇うのと同じ値段・同じ手の数（事業1つにつき1手）で、押す回数だけが減る
  String hireShortAll() {
    if (crewShort().isEmpty) return M('人は足りています');
    final list = crewShortDoable();
    if (list.isEmpty) return needT('crew') ?? M('お金が足りません');
    var heads = 0;
    var cost = 0.0, pay = 0.0;
    for (final b in list) {
      final n = crewNeedPeople(b);
      heads += n;
      cost += hireCost(b, n);
      pay += payPerMonth(b, n);
      hireN(b, n);
    }
    return M('{0}つの事業で、現場の人を合わせて{1}人増やしました（採用の費用 {2}）。毎月の人件費が{3}増えます', [list.length, heads, Y(cost), Y(pay)]);
  }

  /// 担当のない部下を、責任者のいない事業に置く案（事業 → 部下。売上の大きい事業から、その業種に効く能力がいちばん高い人を当てる）。
  /// 社長が直接見られる数（[presCap]）を超えて放置されている事業が先。そうでない事業は、置いたほうが強くなるときだけ
  List<(Biz, Person)> managerPlan() {
    final free = staff.where((p) => !biz.any((b) => b.mgr == p.id)).toList();
    if (free.isEmpty) return const [];
    final open = biz.where((b) => b.mgr == null).toList();
    final cap = presCap();
    // 放置されている事業（社長が見られる数を超えた分）を先に、その中は売上の大きい順
    final list = [
      ...(open.skip(cap).toList()..ssort((a, b) => b.rev.compareTo(a.rev))),
      ...(open.take(cap).toList()..ssort((a, b) => b.rev.compareTo(a.rev))),
    ];
    final out = <(Biz, Person)>[];
    for (final b in list) {
      if (free.isEmpty) break;
      final key = indm[b.ind]!.key;
      // 海外だけの事業には、赴任を断る人を当てない（1.1.0+37）
      final ok = free.where((x) => !postingNo(b, x)).toList();
      if (ok.isEmpty) continue;
      final p = (ok..ssort((x, y) => y.ab[key]!.compareTo(x.ab[key]!))).first;
      final before = mgrMult(b);
      b.mgr = p.id;
      final after = mgrMult(b);
      b.mgr = null;
      if (after <= before) continue;
      free.remove(p);
      out.add((b, p));
    }
    return out;
  }

  /// その人を、この事業の責任者に置けないか（始めた国に出ていない海外だけの事業で、家族の事情で赴任を断る人。1.1.0+37）
  bool postingNo(Biz b, Person p) => !ctryOf(b).contains(home) && refusesPosting(p);

  /// [managerPlan] のとおりに責任者を置く（手は使わない。1人ずつ選ぶ欄で置くのと同じ）
  String placeManagers() {
    final plan = managerPlan();
    if (plan.isEmpty) return M('置ける部下がいません');
    for (final x in plan) {
      x.$1.mgr = x.$2.id;
    }
    presXp('tou', plan.length.toDouble());
    calcAll();
    return M('{0}人を責任者に置きました：{1}', [plan.length, J(plan.map((x) => M('{0}→「{1}」', [Nm(x.$2.name), I(x.$1.ind)])))]);
  }

  /// 現金の割合で現場の人を増やす（試作の手。extras を切った一致テストと、自動プレイの古い流れが使う）
  String addCrew(Biz b, double frac) {
    final cost = cash * frac;
    if (cost <= 0) return M('お金がありません');
    final nt = needT('crew');
    if (nt != null) return nt;
    return _hireCrew(b, cost);
  }

  String _hireCrew(Biz b, double cost) {
    cfAdd('grow', -cost);
    useT('crew');
    b.crew = crewOf(b) + cost * 4;
    b.upkeep = b.upkeep + cost * .008;
    calcAll();
    return M('現場の人を増やしました（{0}）。毎月の人件費が{1}増えます', [Y(cost), Y(cost * .008)]);
  }

  /// 決まった額を払う。手元で足りない分は銀行から借りて払う（借りたときだけ文を返す）
  String? payOut(double a) {
    cfAdd('payout', -a);
    if (cash >= 0) return null;
    final lack = math.min(a, -cash);
    // 1.1.0+25 から、つなぎの融資にする（借りられなければ、月の終わりの資金繰りで手当てする）
    if (!bridgeLoan(lack, null)) return M('足りない{0}は、今月の終わりまでに用意しなければなりません', [Y(lack)]);
    return M('足りない{0}は銀行から借りて払いました', [Y(lack)]);
  }

  /// 株主総会で配当を増やすときの額（年の売上の1%。少なくとも1,000万円）
  double meetingDividend() => math.max(rev * 12 * .01, 1e7 * nom());

  /// 解任動議を配当で乗り切るときの額（年の売上の2%。少なくとも2,000万円）
  double oustDividend() => math.max(rev * 12 * .02, 2e7 * nom());

  /// 臨時の会議で社長が返上する報酬（5,000万円。財産より多くは返せない）
  double presRefund() => math.min(math.max(wealth, 0.0), 5e7 * nom());

  String cancelPipe(Biz b, int i) {
    if (i < 0 || i >= b.pipe.length) return M('取り下げるものがありません');
    final x = b.pipe.removeAt(i);
    cfAdd('grow', x.cost * .5);
    return M('取り下げて、{0}を取り戻しました', [Y(x.cost * .5)]);
  }

  String adv(Biz b) {
    final cost = invBase(b) * .25;
    if (cash < cost) return M('お金が足りません');
    final nt = needT('ad');
    if (nt != null) return nt;
    cfAdd('grow', -cost);
    useT('ad');
    b.ad = 6;
    b.adCost = 0;
    calcAll();
    return M('6か月のあいだ広告を打ちます');
  }

  List<({Company c, double share})> competitors(Biz b) {
    final T = lastT;
    if (T == null || T[b.ind] == null) return [];
    final tot = poolT(b, T) * (reachOf(b) / rEff(b));
    final L = <({Company c, double share})>[];
    final tb = tierOf(b);
    for (final c in cos) {
      if (!c.alive || c.parent == 'player' || c.tier > tb) continue;
      final x = c.biz.where((y) => y.ind == b.ind).firstOrNull;
      if (x != null) L.add((c: c, share: x.power / tot));
    }
    L.ssort((a, b) => b.share.compareTo(a.share));
    return L.take(3).toList();
  }

  String priceWar(Biz b) {
    final cs = competitors(b);
    if (cs.isEmpty) return M('相手がいません');
    final top = cs[0];
    final nt = needT('war');
    if (nt != null) return nt;
    if (b.attack > 0) return M('すでに値下げ合戦の最中です');
    useT('war');
    b.attack = 9;
    b.target = top.c.id;
    top.c.rel -= 15;
    tieRec(top.c, 'g', M('「{0}」で値下げ合戦を仕掛けた', [I(b.ind)]));
    if (inAssoc(b.ind)) {
      deals = deals.where((d) => !(d.type == 'assoc' && d.ind == b.ind)).toList();
      for (final c in cos) {
        if (c.alive && c.biz.any((x) => x.ind == b.ind)) c.rel -= 20;
      }
      log.add(LogEntry(M('抜け駆けの値下げで、「{0}」の業界団体から追い出されました', [I(b.ind)]), 'bad', year, q));
    }
    calcAll();
    return M('{0}に値下げ合戦を仕掛けました。9か月のあいだ、こちらの利益は3割減り、相手の力は毎月3%ずつ削れます', [Nm(top.c.name)]);
  }

  List<Industry> pivotTargets(Biz b) {
    final ind = indm[b.ind]!;
    return liveInds().where((i) => i.cat == ind.cat && i.id != ind.id && !biz.any((x) => x.ind == i.id)).toList();
  }

  String pivot(Biz b, String id) {
    final to = indm[id]!;
    if (biz.any((x) => x.ind == id)) return M('すでにその業種にいます');
    // 始めるときと同じ決まり（子会社のいる業種・資格・銀行の口出し・売ったときの約束。1.1.0+36・+37）
    final sb = newIndBlock(id);
    if (sb != null) return sb;
    final c = capexOf(to);
    if (cash < c) return M('元手が足りません');
    final nt = needT('pivot');
    if (nt != null) return nt;
    cfAdd('grow', -c);
    useT('pivot');
    final from = b.ind;
    final keep = b.power * .5 * (mkt(to) > 0 ? math.min(1, mkt(to) / math.max(mkt(indm[b.ind]!), 1)) : 1) + c * newPow;
    b.crew = crewOf(b) * .5;
    // 前の業態の仕掛かりは、取り下げと同じく半分戻る（1.1.0+37。前は黙って消えていた）
    final back = pipeBack(b);
    b.ind = id;
    b.power = keep;
    // 店などは新しい業態のものに置き直す（客の数から見積もる。1.1.0+26）
    b.sites = {};
    b.young = [];
    b.offers = [];
    b.hubs = [];
    b.leads = 0;
    b.sv = 0;
    b.upg = 1;
    b.lic = 0;
    ensureUnits(b);
    b.age = 0;
    b.price = 'normal';
    b.war = 0;
    b.attack = 0;
    b.prevRev = 0;
    calcAll();
    return withBack(M('「{0}」を「{1}」に業態転換しました。客と人の半分を引き継ぎます', [I(from), I(id)]), back);
  }

  /// 事業を手放す・業態を変えるときの、途中の仕掛かり（店・商品・海外の準備）の扱い（1.1.0+37）。
  /// 取り下げと同じく、払った額の半分が戻る（作りかけの物は半値で引き取ってもらう）。戻った額を返す
  double pipeBack(Biz b) {
    final v = b.pipe.fold(0.0, (s, x) => s + x.cost) * .5;
    b.pipe = [];
    if (v > 0) cfAdd('grow', v);
    return v;
  }

  /// 手の結果の文に、仕掛かりが戻った分を足す（戻らなければ元の文のまま）
  String withBack(String m, double v) => v > 0 ? Cat([m, M('途中の仕掛かりは半分の{0}が戻りました', [Y(v)])], ja: '。', en: '. ') : m;

  List<Synergy> knownSynFor(String id) {
    final own = <String>{for (final b in biz) b.ind};
    return syns.where((s) => (found[s.k] != null || hint[s.k] != null) && ((s.a == id && own.contains(s.b)) || (s.b == id && own.contains(s.a)))).toList();
  }

  String sellBiz(Biz b) {
    final nt = needT('sell');
    if (nt != null) return nt;
    final v = sellValue(b);
    cfAdd('bizSale', v);
    useT('sell');
    // 人たらしは情に流されて切るのに手間取る（時間が倍）
    if (hasT('charm')) useT('sell');
    final back = pipeBack(b);
    biz.remove(b);
    presXp('zai', 2);
    calcAll();
    return withBack(M('「{0}」を{1}で売りました', [I(b.ind), Y(v)]), back);
  }

  String hire(Person p) {
    final nt = needT('hire');
    if (nt != null) return nt;
    // 経歴を持つ人は、採用の道で費用が違う（新卒は採用の費用・中途は紹介の手数料・引き抜きは高い手数料。1.1.0+27）
    final sign = hireFeeOf(p);
    if (cash < sign) return M(p.real ? '採用の費用が足りません' : '支度金が足りません');
    cfAdd('grow', -sign);
    useT('hire');
    cands.remove(p);
    staff.add(p);
    presXp('tou', 1.5);
    return M('{0}を雇いました', [Nm(p.name)]);
  }

  /// 責任者を決める（手は使わない）
  void setManager(Biz b, int? id) {
    // 海外だけの事業へは、家族の事情で赴任を断る人を置けない（1.1.0+37。異動の画面と同じ決まり）
    if (id != null && id != b.mgr) {
      final np = staffById(id);
      if (np != null && postingNo(b, np)) return;
    }
    // 責任者を外したら、任せるのもやめる（人を替えただけなら、任せたまま引き継ぐ）。
    // 任せていた責任者が辞めたあとに新しい人を置いたときも、任せ直すまでは自分で動かす
    final was = delegated(b);
    if (id != null && id != b.mgr) presXp('tou', 1);
    // 責任者にした人・外された人の受け止め方（特性で変わる。1.1.0+33）
    if (id != b.mgr) trOnPlace(b, b.mgr, id);
    // 1人が責任者になれる事業は1つ。ほかの事業の責任者だった人を置いたら、前の事業からは外す
    // （1.1.0+37。異動で1人が全事業の責任者になれた。異動は降格ではないので、外された人の受け止め方は見ない）
    if (id != null) {
      for (final x in biz) {
        if (x != b && x.mgr == id) {
          x.mgr = null;
          x.deleg = false;
          x.did = null;
        }
      }
    }
    b.mgr = id;
    if (id == null || !was) {
      b.deleg = false;
      b.did = null;
    }
    calcAll();
  }

  /// 値付けを決める（手は使わない）
  void setPrice(Biz b, String price) {
    b.price = price;
    calcAll();
  }

  String dismiss(Person p) {
    if (p.partner) return partnerOut(p);
    // 経歴を持つ人を解雇すると、国と時代の慣習で決まる手当を払い、終身雇用が強いほどほかの部下のやる気も下がる（1.1.0+27）
    if (p.real && extras) {
      final pay = p.salary * severanceMonths();
      cfAdd('grow', -pay);
      fire(p, 'fired');
      // 仲裁役がいると、ほかの部下の動揺は半分で収まる（1.1.0+33）
      final hit = normOf().life * 8 * (anyTr('mediate') ? .5 : 1);
      for (final o in staff) {
        o.loy -= hit;
      }
      return M('{0}を解雇しました（解雇の手当 {1}）', [Nm(p.name), Y(pay)]);
    }
    fire(p, 'fired');
    return M('{0}を解雇しました', [Nm(p.name)]);
  }

  String kidJoin(Person k) {
    kids.remove(k);
    freshGrad(k);
    k.kid = false;
    k.tenure = 0;
    k.salary = jsRound(3e6 * nom() / 12);
    staff.add(k);
    return M('{0}が入社しました。能力は働かせると見えてきます', [Nm(k.name)]);
  }

  // ===== 社長の行動 =====
  String placeName(String id) => M(id == 'net' ? (yr() < 2008 ? 'ネットの掲示板' : 'SNS') : PLACES.firstWhere((x) => x.id == id).nJa);

  Person mkPartner(String pl) {
    final p = mkPerson(0);
    void add(String k, int v) => p.ab[k] = clampI(p.ab[k]! + v, 5, 99);
    if (pl == 'lab') {
      p.age = ri(22, 27);
      add('kai', 20);
      add('ei', -10);
      p.setMain(pick(const ['tech', 'genius', 'careful']));
    } else if (pl == 'club') {
      p.age = ri(22, 23);
      for (final k in abKeys) {
        add(k, -8);
      }
      p.loy = ri(75, 95).toDouble();
      p.amb = ri(10, 60);
      p.setMain(pick(STRAITS).id);
    } else if (pl == 'baito') {
      p.age = ri(24, 31);
      add('ei', 15);
      add('tou', 10);
      p.setMain(pick(const ['grit', 'stamina', 'charm']));
    } else if (pl == 'meet') {
      p.age = ri(30, 45);
      add('zai', 20);
      p.amb = ri(60, 95);
      p.loy = ri(20, 60).toDouble();
      p.setMain(pick(const ['gambler', 'careful', 'charm', 'liar']));
      p.money = ri(2, 5) * 1e7 * nom();
    } else {
      p.age = ri(20, 35);
      final sw = rnd() < .25 ? 18 : -10;
      for (final k in abKeys) {
        add(k, sw + ri(-8, 8));
      }
      p.setMain(pick(const ['genius', 'liar', 'gambler', 'oneman', 'tech']));
    }
    if (p.trait == 'tech' && pl != 'lab') {
      add('kai', 25);
      add('ei', -20);
    }
    if (p.trait == 'grit' && pl != 'baito') add('zai', -15);
    p.salary = jsRound(3e6 * nom() / 12);
    p.place = pl;
    trFix(p);
    return p;
  }

  List<Person> partners() => staff.where((p) => p.partner).toList();

  double partnerChance(Person p, int x) {
    var c = .1 + x * .025;
    if (hasT('charm')) c += .15;
    if (biz.isNotEmpty) c += .1;
    if (rev > 0) c += math.min(.15, rev / (1e9 * nom()) * .15);
    if (p.amb > 70) c -= .1;
    if (p.place == 'club') c += .15;
    if (p.place == 'meet') c -= .1;
    return clampD(c, .05, .95);
  }

  String recruitPartner(Person p, int x) {
    meet = null;
    if (sh.own - x < 40) return M('持ち株がこれ以上減ると、経営権が危うくなります');
    if (rnd() < partnerChance(p, x)) {
      p.partner = true;
      p.stake = x.toDouble();
      p.w = math.min(p.w, 14);
      sh.own -= x;
      sh.pt = sh.pt + x;
      staff.add(p);
      chron('partner', M('{0}（{1}歳）が相棒になった。株を{2}%渡した', [Nm(p.name), p.age, x]));
      final m = <Object?>[M('{0}が相棒になりました。株を{1}%渡しました', [Nm(p.name), x])];
      if (p.money != null && p.money != 0) {
        cfAdd('equity', p.money!);
        m.add(M('{0}を出資してくれました', [Y(p.money!)]));
      }
      m.add(M('相棒が責任者の事業は力が1割5分上がります'));
      return Cat(m, ja: '。', en: '. ');
    }
    return M('{0}は「もう少し考えたい」と言って去っていきました', [Nm(p.name)]);
  }

  double workIncome() => (3.3e5 + (pres.ab['ei']! + pres.ab['kai']!) * 3.3e3) * nom();

  String scout() {
    final y = yr();
    final up = inds.where((i) => i.b > y && i.b <= y + 8 && seen[i.id] == null).toList();
    if (up.isNotEmpty && rnd() < .45) {
      final i = pick(up);
      seen[i.id] = 1;
      return M('調べてみると、{0}年ごろに「{1}」の市場が生まれそうです。「事業」の下に書き留めました', [i.b, I(i.id)]);
    }
    final own = <String>{for (final b in biz) b.ind};
    final live = <String>{for (final i in liveInds()) i.id};
    final c = syns.where((s) => found[s.k] == null && hint[s.k] == null && live.contains(s.a) && live.contains(s.b)).toList();
    final touch = c.where((s) => own.contains(s.a) || own.contains(s.b)).toList();
    final cheap = c.where((s) => capexOf(indm[s.a]!) <= cash * 3 && capexOf(indm[s.b]!) <= cash * 3).toList();
    if (c.isNotEmpty) {
      final s = touch.isNotEmpty
          ? pick(touch)
          : cheap.isNotEmpty
              ? pick(cheap)
              : pick(c);
      hint[s.k] = 1;
      return M('「{0}」と「{1}」は相性がよさそうです。図鑑に書き留めました', [I(s.a), I(s.b)]);
    }
    return M('今回は目ぼしい話がありませんでした');
  }

  /// 社長の行動。seek は成功すると null（出会いの小窓へ）
  String? presAct(String kind, [String? arg]) {
    if (kind == 'rest') return restAct();
    // 「腕を磨く」は 1.1.0+32 で無くした（腕は事業を進める中で磨かれる）。古い呼び出しは時間を使わずに知らせだけ返す
    if (kind == 'train') return M('社長の腕は、事業を進める中で磨かれます');
    final nt = needT(kind);
    if (nt != null) return nt;
    if (kind == 'seek') {
      if (partners().length >= 2) return M('相棒は2人までです');
      useT('seek');
      meet = mkPartner(arg!);
      return null;
    }
    if (kind == 'work') {
      useT('work');
      final v = workIncome();
      cfAdd('nonop', v);
      calcAll();
      return M('受託の仕事を片付け、{0}を稼ぎました', [Y(v)]);
    }
    if (kind == 'net') {
      if (net >= 5) return M('人脈はもう十分に広がっています');
      useT('net');
      net++;
      return M(NETMSG.ja[net - 1]);
    }
    if (kind == 'scout') {
      useT('scout');
      return scout();
    }
    return null;
  }

  String sellLand() {
    final v = land;
    if (v <= 0) return M('土地を持っていません');
    cfAdd('land', v);
    land = 0;
    calcAll();
    return M('土地を{0}で売りました', [Y(v)]);
  }

  String vcRaise() {
    if (listed) return M('上場後は使えません');
    if (turn - (lastOffer ?? -99) < 12) return M('投資家から集めるのは1年に1回までです');
    final nt = needT('vc');
    if (nt != null) return nt;
    lastOffer = turn;
    if (sh.own <= 40) return M('これ以上持ち株を減らすと経営権が危うくなります');
    final money = cap * .1;
    cfAdd('equity', money);
    sh.own -= 10;
    sh.vc += 10;
    useT('vc');
    presXp('zai', 2);
    final first = vcDeadline == 0;
    if (first) vcDeadline = turn + 36;
    calcAll();
    return M('投資家から{0}を集めました。持ち株は{1}に。{2}', [Y(money), pct(sh.own), first ? M('条件は「3年以内に上場すること」です') : M('上場の約束は{0}年まで', [year + ((vcDeadline - turn + q - 1) / 12).floor()])]);
  }

  // ===== 他社と組む =====
  List<Deal> dealWith(Company c) => deals.where((d) => d.co == c.id).toList();
  bool hasDeal(String type, [String? cat]) => deals.any((d) {
        if (d.type != type) return false;
        final c = coById(d.co);
        return c != null && c.alive && (cat == null || c.biz.any((b) => indm[b.ind]!.cat == cat));
      });
  bool inAssoc(String ind) => deals.any((d) => d.type == 'assoc' && d.ind == ind);
  String dealOk(Company c, String type) {
    if (c.parent == 'player') return M('その会社はもう子会社です');
    if (c.rel < -20) return M('{0}はあなたを警戒していて、話に乗りません', [Nm(c.name)]);
    if (dealWith(c).any((d) => d.type == type)) return M('すでに組んでいます');
    return '';
  }

  String makeDeal(Company c, String type, [String? ind]) {
    final ng = dealOk(c, type);
    if (ng.isNotEmpty) return ng;
    final nt = spendT('deal');
    if (nt != null) return nt;
    deals.add(Deal(co: c.id, type: type, ind: ind, since: year));
    c.rel += 10;
    tieRec(c, 'f', M('「{0}」で組んだ', [D(DEALN.ja[type]!)]));
    calcAll();
    return M('{0}と「{1}」で組みました', [Nm(c.name), D(DEALN.ja[type]!)]);
  }

  /// 事業の画面の「業界団体に入る」
  String joinAssoc(Biz b) {
    final cs = competitors(b);
    if (cs.isEmpty) return M('相手がいません');
    final c = cs[0].c;
    final ng = dealOk(c, 'assoc');
    if (ng.isNotEmpty) return ng;
    return makeDeal(c, 'assoc', b.ind);
  }

  String endDeal(Deal d) {
    deals.remove(d);
    final c = coById(d.co);
    if (c != null) c.rel -= 5;
    calcAll();
    return M('{0}との「{1}」を解消しました', [c != null ? Nm(c.name) : M('相手'), D(DEALN.ja[d.type]!)]);
  }

  String betray(Deal d) {
    final c = coById(d.co);
    deals.remove(d);
    if (c == null) return M('相手がいません');
    final inds = <String>{for (final b in c.biz) b.ind};
    for (final b in biz) {
      if (inds.contains(b.ind)) b.power *= 1.1;
    }
    for (final b in c.biz) {
      if (biz.any((x) => x.ind == b.ind)) b.power *= .9;
    }
    c.rel -= 50;
    tieRec(c, 'g', M('組んでいたのに裏切った'));
    if (c.rival != null) c.rival!.allied = false;
    for (final o in cos) {
      if (o.alive && o != c) o.rel -= 5;
    }
    rep = rep - 10;
    calcAll();
    return M('{0}を裏切り、組んでいた間に知った客を奪いました。{0}は激怒し、業界中の評判も落ちました', [Nm(c.name)]);
  }

  // ===== 会社の形 =====
  static String _cultOfTrait(String? t) => t == 'oneman'
      ? 'sports'
      : t == 'careful'
          ? 'steady'
          : t == 'charm'
              ? 'family'
              : t == 'genius'
                  ? 'free'
                  : 'merit';

  /// 事業を分社する。[name] は子会社の名前（null なら今までどおり仕組みが付ける。1.1.0+36）
  String spinOff(Biz b, {String? name}) {
    final p = staffById(b.mgr);
    if (p == null) return M('先に責任者を置いてください。その人が子会社の社長になります');
    // 相棒は本社に残す（現地法人と同じ。1.1.0+37。前は相棒の持ち株が持ち主なしで残った）
    if (p.partner) return M('相棒は本社に残します。ほかの部下を責任者に置いてから分社してください');
    final n = name?.trim();
    if (n != null) {
      final e = coNameErr(n);
      if (e != null) return e;
    }
    final nt = spendT('spin');
    if (nt != null) return nt;
    final ind = indm[b.ind]!;
    // 名前を決めていても、仕組みの名前を作る乱数は今までどおり引く（並びをずらさない）
    final c = mkCo(tierOf(b), ind.cat, name: n, presName: p.name, fam: 0);
    c.presAge = p.age.toDouble();
    c.parent = 'player';
    c.stakePlayer = 100;
    c.biz.add(CoBiz(ind: b.ind, power: b.power));
    c.g = .008;
    c.rel = 30;
    c.culture = _cultOfTrait(p.trait);
    c.fromStaff = p.trait;
    // 後継ぎに決めていた人が子会社の社長になったら、後継ぎは決め直す（現地法人と同じ。1.1.0+37）
    if (succ == p.id) succ = null;
    staff.remove(p);
    final back = pipeBack(b);
    biz.remove(b);
    calcAll();
    return withBack(M('「{0}」を分社し、{1}を作りました。社長は{2}。これからは{2}が自分の判断で動かします', [I(ind.id), Nm(c.name), Nm(p.name)]), back);
  }

  /// 事業を責任者に渡して独立させる。[name] は新しい会社の名前（null なら今までどおり仕組みが付ける。1.1.0+37）
  String releaseBiz(Biz b, {String? name}) {
    final p = staffById(b.mgr);
    if (p == null) return M('先に責任者を置いてください。その人に事業を渡します');
    final n = name?.trim();
    if (n != null) {
      final e = coNameErr(n);
      if (e != null) return e;
    }
    final nt = spendT('release');
    if (nt != null) return nt;
    final ind = indm[b.ind]!;
    // 名前を決めていても、仕組みの名前を作る乱数は今までどおり引く（並びをずらさない）
    final c = mkCo(tierOf(b), ind.cat, name: n, presName: p.name, fam: 60);
    c.presAge = p.age.toDouble();
    c.biz.add(CoBiz(ind: b.ind, power: b.power));
    c.stakePlayer = 10;
    c.rel = 60;
    c.g = .01;
    // よその会社の社長になった人は、社外の一覧（呼び戻せる人）には入れない（1.1.0+37）
    fire(p, 'indep');
    final back = pipeBack(b);
    biz.remove(b);
    calcAll();
    if (back > 0) {
      return withBack(
          M('「{0}」を{1}に渡し、独立させました。{2}の株を10%持ちます。{1}は恩を忘れないでしょう', [I(ind.id), Nm(p.name), Nm(c.name)]), back);
    }
    return M('「{0}」を{1}に渡し、独立させました。{2}の株を10%持ちます。{1}は恩を忘れないでしょう', [I(ind.id), Nm(p.name), Nm(c.name)]);
  }

  String subIPO(Company c) {
    if (c.parent != 'player' || pctOf(c) < 60) return M('株を60%以上持つ子会社だけです');
    if (c.listed) return M('すでに上場しています');
    final nt = spendT('subipo');
    if (nt != null) return nt;
    final v = c.cap * .3 * .95;
    c.stakePlayer -= 30;
    c.listed = true;
    cfAdd('stock', v);
    calcAll();
    if (c.loc != null) {
      chron('ipo', M('現地法人{0}を{1}の市場に上場させた。{2}が入った', [Nm(c.name), C(c.loc!), Y(v)]));
      return M('現地法人{0}を{1}の市場に上場させ、株を30%売って{2}を得ました。まだ{3}持っています', [Nm(c.name), C(c.loc!), Y(v), pct(pctOf(c))]);
    }
    return M('{0}を上場させ、株を30%売って{1}を得ました。まだ{2}持っています', [Nm(c.name), Y(v), pct(pctOf(c))]);
  }

  String makeHolding() {
    if (holding) return M('すでに持株会社です');
    if (biz.length + subs().length < 5) return M('事業と子会社が合わせて5つ以上になってからです');
    final nt = spendT('holding');
    if (nt != null) return nt;
    holding = true;
    calcAll();
    return M('持株会社になりました。社長が直接見られる事業の上限がなくなります。本社の経費は5割増えます');
  }

  /// 会社を2つに割る。[name] は新しい会社の名前（null なら今までどおり仕組みが付ける。1.1.0+37）
  String splitCompany(String cat, {String? name}) {
    final bs = biz.where((b) => indm[b.ind]!.cat == cat).toList();
    if (bs.isEmpty) return M('その分類の事業がありません');
    if (bs.length == biz.length) return M('全部を切り離すことはできません');
    if (!listed) return M('上場してからです');
    final n = name?.trim();
    if (n != null) {
      final e = coNameErr(n);
      if (e != null) return e;
    }
    final nt = spendT('split');
    if (nt != null) return nt;
    // 名前を決めていても、仕組みの名前を作る乱数は今までどおり引く（並びをずらさない）
    final c = mkCo(bs.map(tierOf).reduce(math.max), cat, name: n, fam: 0);
    c.biz = bs.map((b) => CoBiz(ind: b.ind, power: b.power * 1.1)).toList();
    c.stakePlayer = jsRound(sh.own);
    // 過半を持つなら子会社（1.1.0+37。前は外の会社として、値下げ合戦や CPU の買収の的になった）
    if (pctOf(c) > 50) c.parent = 'player';
    c.listed = true;
    c.g = .008;
    c.rel = 20;
    c.culture = culture;
    var back = 0.0;
    for (final b in bs) {
      back += pipeBack(b);
    }
    biz = biz.where((b) => !bs.contains(b)).toList();
    for (final b in biz) {
      b.power *= 1.1;
    }
    calcAll();
    if (back > 0) {
      return withBack(
          M('「{0}」の事業を{1}として切り離し、別に上場させました。あなたは新しい会社の株を{2}持ちます。身軽になって、両方の評価が上がりました', [D(CATN.ja[cat]!), Nm(c.name), pct(pctOf(c))]), back);
    }
    return M('「{0}」の事業を{1}として切り離し、別に上場させました。あなたは新しい会社の株を{2}持ちます。身軽になって、両方の評価が上がりました', [D(CATN.ja[cat]!), Nm(c.name), pct(pctOf(c))]);
  }

  // ===== 汚い手 =====
  double dirtyRisk(String kind, Company? c) {
    var r = const {'poach': .2, 'spy': .25, 'lobby': .2, 'cook': .3, 'cartel': .25}[kind]! * (1 + .15 * dirty);
    if (culture == 'steady') r *= .7;
    if (culture == 'sports') r *= 1.3;
    if (staff.any((p) => p.trait == 'liar')) r *= 1.3;
    if (hasT('liar')) r *= .8;
    if (c != null && c.rel < -30) r *= 1.3;
    return clampD(r, .05, .9);
  }

  /// 裏の手の値段。extras のときは手ごとの固定額（時代の物価だけ乗る）。切ると試作と同じ時価総額の割合
  double dirtyCost(String kind) => extras
      ? dirtyPrice[kind]! * nom()
      : math.max(3e6 * nom(), cap * const {'poach': .005, 'spy': .008, 'lobby': .015, 'cook': .002, 'cartel': .004}[kind]!);

  Biz? cartelBiz(Company c) {
    final a = biz.where((b) => c.biz.any((x) => x.ind == b.ind)).toList()..ssort((a, b) => b.rev.compareTo(a.rev));
    if (a.isNotEmpty) return a[0];
    final all = biz.toList()..ssort((a, b) => b.rev.compareTo(a.rev));
    return all.firstOrNull;
  }

  String doDirty(String kind, Company c) {
    final nt = needT('dirty');
    if (nt != null) return nt;
    final cost = dirtyCost(kind);
    if (cash < cost) return M('お金が足りません');
    cfAdd('misc', -cost);
    useT('dirty');
    final caught = rnd() < dirtyRisk(kind, c);
    dirty++;
    const dirtyWhat = {'poach': '裏の手で腕利きを引き抜いた', 'spy': '裏の手で開発の中身を盗んだ', 'lobby': '裏の手で規制をかけさせた'};
    if (dirtyWhat[kind] != null) tieRec(c, 'g', M(dirtyWhat[kind]!));
    var m = <Object?>[];
    if (kind == 'poach') {
      final p = mkPerson(1.3);
      p.salary *= 1.8;
      staff.add(p);
      for (final x in c.biz) {
        x.power *= .93;
      }
      c.rel -= 20;
      m = [M('{0}の腕利き、{1}を引き抜きました', [Nm(c.name), Nm(p.name)])];
      if (caught) {
        final pay = math.max(c.cap * .005, cost * 2);
        cfAdd('sp', -pay);
        scandal = math.max(scandal, 6);
        m.add(M('しかし訴えられ、賠償金{0}を払いました', [Y(pay)]));
      }
    }
    if (kind == 'spy') {
      final inds = <String>{for (final x in c.biz) x.ind};
      for (final x in biz) {
        if (inds.contains(x.ind)) x.power *= 1.12;
      }
      for (final x in c.biz) {
        if (biz.any((y) => y.ind == x.ind)) x.power *= .95;
      }
      m = [M('{0}の開発の中身を盗み出しました', [Nm(c.name)])];
      if (caught) {
        scandal = 12;
        for (final k in abKeys) {
          pres.ab[k] = math.max(5, pres.ab[k]! - 8);
        }
        rest = 1;
        c.rel -= 40;
        m.add(M('ところが発覚して刑事事件になり、社長は取り調べを受けました。信用も能力も落ちました'));
      }
    }
    if (kind == 'lobby') {
      for (final x in c.biz) {
        x.power *= .9;
      }
      m = [M('政治家を動かし、{0}の業種に規制がかかりました', [Nm(c.name)])];
      if (caught) {
        scandal = 12;
        for (final x in biz) {
          x.power *= .92;
        }
        m.add(M('しかし汚職事件として報じられ、株価が暴落しました'));
      }
    }
    if (kind == 'cook') {
      cooked = 12;
      m = [M('決算の数字を飾りました。1年のあいだ、会社は実際より良く見えます')];
      if (caught) {
        cooked = 0;
        scandal = 24;
        final wl = listed;
        if (wl) {
          listed = false;
          sh.vc += sh.float;
          sh.float = 0;
        }
        m = [M(wl ? '粉飾がすぐに発覚しました。上場廃止となり、信用は地に落ちました' : '粉飾がすぐに発覚しました。信用は地に落ちました')];
      }
    }
    if (kind == 'cartel') {
      final b = cartelBiz(c);
      if (b == null) return M('事業がありません');
      b.cartel = 24;
      m = [M('「{0}」で、同業者と値段を決め合いました。2年のあいだ利益が増えます', [I(b.ind)])];
      if (caught) {
        b.cartel = 0;
        final fine = b.rev * 12 * .15;
        cfAdd('sp', -fine);
        scandal = math.max(scandal, 12);
        m.add(M('しかし当局に見つかり、罰金{0}を払いました', [Y(fine)]));
      }
    }
    calcAll();
    return Cat(m, ja: '。', en: '. ');
  }

  // ===== 売り抜け =====
  List<Company> buyers() {
    final l = cos.where((c) => c.alive && c.parent != 'player' && c.cap > cap * 1.2).toList()..ssort((a, b) => b.cap.compareTo(a.cap));
    return l.take(4).toList();
  }

  double salePrice(bool nc) => cap * (nc ? 1.3 : 1.05) * sh.own / 100;

  /// 会社を丸ごと売る。[newName] は新しく立ち上げる会社の名前（null なら名前なし。前の会社は今の名前のまま残る。1.1.0+37）
  String sellCompany(Company c, bool nc, {String? newName}) {
    final nt = needT('sellco');
    if (nt != null) return nt;
    if (biz.isEmpty) return M('売る事業がありません');
    final nn = newName?.trim();
    if (nn != null) {
      final e = myNameErr(nn, selling: true);
      if (e != null) return e;
    }
    useT('sellco');
    finCut();
    final price = salePrice(nc);
    // 前の会社は、自社の名前があればその名前のまま残る（1.1.0+37。無ければ今までどおり「〇〇グループ」）
    final oldName = myCo.isNotEmpty ? myCo : '${Game.famOf(pres.name)}グループ';
    final old = mkCo(0, 'link', name: oldName, presName: nm(), fam: 0);
    old.biz = biz.map((b) => CoBiz(ind: b.ind, power: b.power)).toList();
    old.rel = nc ? 20 : -20;
    old.g = .006;
    old.cash = cash * .5;
    old.formerMine = true;
    c.rel += 10;
    storyEnd(c, 'boughtBy');
    final inds = biz.map((b) => b.ind).toList();
    chron('sold', M('会社を{0}に{1}で売った。前の会社は「{2}」として残る', [Nm(c.name), Y(price), Nm(old.name)]));
    noncomp = nc ? Noncomp(inds: inds, until: turn + ri(36, 120), buyer: c.id, price: price) : null;
    final keep = staff.where((p) => p.partner && p.loy >= 60).toList();
    for (final p in keep) {
      p.stake = math.min(p.stake, 10);
    }
    final pt = keep.fold(0.0, (s, p) => s + p.stake);
    for (final x in cos) {
      x.stakePlayer = 0;
      if (x.parent == 'player') x.parent = null;
    }
    biz = [];
    staff = keep;
    sh = Shares(own: 100 - pt, pt: pt);
    listed = false;
    // 借金は買い手が引き継ぐ
    loans = [];
    bankCtl = 0;
    missed = 0;
    vcDeadline = 0;
    tie = null;
    deals = [];
    // 上場の準備と、途中の買収の話は前の会社のもの（1.1.0+37。前は新しい会社に残った）
    corp.ipo = null;
    corp.deals.clear();
    corp.clients.clear();
    myCo = nn ?? '';
    holding = false;
    cooked = 0;
    everBiz = false;
    serial++;
    wealth = wealth + price * .5;
    cfTag = 'reset';
    cash = price * .5;
    calcAll();
    // 決算書：前の会社との差を「入れ替え」にする（1.1.0+34）
    finRebase();
    return Cat([
      M('会社を{0}に{1}で売りました。半分を自分の財産に、半分を元手に、新しい会社を立ち上げます', [Nm(c.name), Y(price)]),
      if (nc) M('{0}年間は同じ業種に入らない約束です', [jsNum(jsRound((noncomp!.until - turn) / 12))]),
      if (keep.isNotEmpty) M('相棒の{0}がついてきてくれました', [J(keep.map((p) => Nm(p.name)))]),
      M('前の会社は「{0}」として残ります', [Nm(old.name)]),
      if (myCo.isNotEmpty) M('新しい会社の名前は「{0}」です', [Nm(myCo)]),
    ], ja: '。', en: '. ');
  }

  String breakNoncomp() {
    if (noncomp == null) return M('約束はありません');
    noncomp!.broken = true;
    suits.add(Suit(at: turn + 24, against: true, amt: noncomp!.price * .2));
    scandal = math.max(scandal, 6);
    return M('約束を破ることにしました。2年後に裁判で賠償を求められます');
  }

  String sellOwn(double x) {
    if (!listed) return M('上場してからです');
    x = math.min(x, sh.own - 1);
    if (x <= 0) return M('売れる株がありません');
    final v = cap * x / 100 * .9;
    wealth = wealth + v;
    sh.own -= x;
    sh.float += x;
    calcAll();
    return M('持ち株を{0}売り、{1}を自分の財産にしました', [pct(x), Y(v)]);
  }

  String goPrivate() {
    if (!listed) return M('上場していません');
    final out = sh.float + sh.rivSum;
    final cost = cap * out / 100 * 1.3;
    if (cash < cost) return M('お金が足りません（{0} 必要）', [Y(cost)]);
    final nt = spendT('private');
    if (nt != null) return nt;
    cfAdd('payout', -cost);
    sh.own += out;
    sh.float = 0;
    for (final i in sh.riv.keys.toList()) {
      final c = coById(i);
      if (c != null) c.cash += cap * sh.riv[i]! / 100 * 1.3;
      sh.riv[i] = 0;
    }
    listed = false;
    calcAll();
    return M('市場の株をすべて買い戻し、非上場に戻しました。乗っ取られる心配はなくなります');
  }

  void rivalDefeated(Company c) {
    if (c.rival == null || c.rival!.gone) return;
    c.rival!.gone = true;
    ret.add(Return(at: turn + ri(24, 72), fam: Game.famOf(c.presName), west: c.presName.contains('・'), col: c.rival!.col, from: c.name));
    if (extras) {
      ret.last.end = 'bought';
      ret.last.grudge = c.rival!.grudge;
      storyEnd(c, 'bought');
    }
  }

  // ===== 社風 =====
  String changeCulture(String x) {
    if (cultLeft > 0) return M('社風を切り替えている途中です');
    if (culture == x) return M('すでにその社風です');
    final nt = spendT('culture');
    if (nt != null) return nt;
    cultNext = x;
    cultLeft = 24;
    return M('社風を「{0}」に切り替え始めました。変わるまで2年かかり、その間は人が辞めやすくなります', [D(CULT[x]!.nJa)]);
  }

  String cultureOf(Company c) {
    c.culture ??= pick(CULT.keys.toList());
    return c.culture!;
  }

  // ===== 上場・増資 =====
  void _dilute(double k) {
    // 新しい株を出した分だけ、株の数が増える（株価＝時価総額÷株の数。1.1.0+29）
    if (k > 0) corp.nSh /= k;
    sh.own *= k;
    sh.vc *= k;
    sh.ally *= k;
    sh.pt = sh.pt * k;
    for (final i in sh.riv.keys.toList()) {
      sh.riv[i] = sh.riv[i]! * k;
    }
  }

  String publicOffer() {
    if (!listed) return M('上場してから使えます');
    if (turn - (lastOffer ?? -99) < 12) return M('増資は1年に1回までです');
    final nt = spendT('offer');
    if (nt != null) return nt;
    lastOffer = turn;
    final money = cap * .1 * .95;
    const k = 100 / 110;
    _dilute(k);
    sh.float = sh.float * k + 10 * k;
    cfAdd('equity', money);
    presXp('zai', 2);
    calcAll();
    return M('新しい株を市場に出し、{0}を集めました。持ち株は{1}に下がりました', [Y(money), pct(sh.own)]);
  }

  /// 1.1.0+29 から、上場は2〜3年の準備（監査・社内の決まり）のあと（game_corp.dart）
  bool canIPO() => unitsOn ? ipoReady() : !listed && pre * 12 >= 3e8 * nom() && turn >= 24;
  String ipo() {
    if (unitsOn) return ipoList();
    if (!canIPO()) return M('上場の条件を満たしていません');
    final nt = spendT('ipo');
    if (nt != null) return nt;
    final money = cap * .25;
    cfAdd('equity', money);
    const k = 100 / 120;
    _dilute(k);
    sh.float = sh.float * k + 20 * k;
    sh.float += sh.vc;
    sh.vc = 0;
    listed = true;
    vcDeadline = 0;
    presXp('zai', 6, big: true);
    calcAll();
    chron('ipo', M('株式を上場した。{0}が入った（時価総額 {1}）', [Y(money), Y(cap)]));
    return M('上場しました！{0}が入り、ここからは誰でもあなたの株を買えます', [Y(money)]);
  }

  void normSh() {
    final t = sh.own + sh.vc + sh.ally + sh.pt + sh.float + sh.rivSum;
    final k = 100 / t;
    sh.own *= k;
    sh.pt = sh.pt * k;
    sh.vc *= k;
    sh.ally *= k;
    sh.float *= k;
    for (final i in sh.riv.keys.toList()) {
      sh.riv[i] = sh.riv[i]! * k;
    }
  }

  String doBuyback(double x) {
    x = math.min(x, sh.float);
    final cost = cap * x / 100 * 1.15;
    if (cash < cost) return M('お金が足りません');
    cfAdd('payout', -cost);
    sh.float -= x;
    normSh();
    liarCheck();
    return M('自社株を{0}買い戻しました', [pct(x)]);
  }

  /// 株の画面の「自社株買い 5%」（手を1つ使う）
  String buybackAct() {
    final nt = spendT('buyback');
    if (nt != null) return nt;
    return doBuyback(math.min(sh.float, 5));
  }

  /// 株の画面の「ホワイトナイトを頼む」（社長の時間を使う）
  String whiteKnightAct() {
    final nt = spendT('knight');
    if (nt != null) return nt;
    return doWhiteKnight();
  }

  String doWhiteKnight() {
    final l = cos.where((c) => c.alive && c.rival == null && c.parent != 'player' && c.tier == 0).toList()..ssort((a, b) => b.cap.compareTo(a.cap));
    final ally = l.firstOrNull;
    if (ally == null) return M('頼める相手がいません');
    final cost = ally.cap * .05;
    if (cash < cost) return M('{0}の株を買うお金が足りません', [Nm(ally.name)]);
    cfAdd('stock', -cost);
    ally.stakePlayer = ally.stakePlayer + 5;
    final x = math.min(10.0, sh.float);
    sh.float -= x;
    sh.ally += x;
    liarCheck();
    return M('{0}がホワイトナイトになり、株を{1}持ってくれました', [Nm(ally.name), pct(x)]);
  }

  String doDilute() {
    cfAdd('equity', cap * .15 * .9);
    sh.ally += 15;
    normSh();
    liarCheck();
    calcAll();
    return M('新しい株を味方に渡し、相手の割合を薄めました');
  }

  void liarCheck() {
    if (hasT('liar') && rnd() < .15) {
      scandal = 12;
      // 味方が持っている分までしか市場に戻らない（5%未満のときに5%を足すと合計が100%を超える）。
      // extras を切ったときは試作と同じ数字のまま
      final back = extras ? math.min(5.0, sh.ally) : 5.0;
      sh.ally = math.max(0, sh.ally - 5);
      sh.float += back;
      log.add(LogEntry(M('株の裏工作がばれ、信用を失いました'), 'bad', year, q));
    }
  }

  // 地域ごとの進出（試作では画面から外してある。仕組みだけ残す）
  double expandCost() => region == 0 ? 2e10 * nom() : 5e11 * nom();
  double expandNeed() => (region == 0 ? 1e11 : 2e12) * nom();
  bool canExpand() => region < 2 && rev * 12 >= expandNeed();
  String expand() {
    if (!canExpand()) return M('まだ売上が足りません');
    final nt = needT('enter');
    if (nt != null) return nt;
    final c = expandCost();
    if (cash < c) return M('お金が足りません');
    cfAdd('grow', -c);
    region++;
    for (final b in biz) {
      b.power *= 1.2;
    }
    useT('enter');
    calcAll();
    chron('abroad', M('{0}に進出した', [D(REGN.ja[region])]));
    return M('{0}に進出しました！市場が大きくなり、海外の会社とも競います', [D(REGN.ja[region])]);
  }

  // ===== 株の攻め =====
  /// 市場に出ている株。現地法人で宿敵が買い集めた分（[Company.locRivPct]）は、もう市場には無い
  /// （1.0.0+18。引いていなかったので、あなた70%・宿敵30%の現地法人で「市場の株30%」と出て、さらに5%買えて合計が100%を超えた）
  double floatOf(Company c) => math.max(0, 100 - c.fam - c.stakePlayer - c.locRivPct);

  /// 市場であと何%買えるか（3分の1まで。1.1.0+37）。
  /// もう子会社（審査を通して過半を持った会社）なら、合併に向けて市場で買い増せる
  double mktRoom(Company c) {
    if (c.parent == 'player') return floatOf(c);
    final r = GameCorp.blockPct - pctOf(c);
    return r < .01 ? 0 : r;
  }

  String buyStake(Company c, double x) {
    // 市場で買えるのは3分の1まで。それより上は買い付けの申し入れ（TOB）で、上乗せ・当局の審査を通す（1.1.0+37。現実の3分の1ルール）
    if (unitsOn && c.parent != 'player' && mktRoom(c) == 0) return M('市場で買えるのは株の3分の1までです。それより上は「買う話を始める」（TOB）で買います');
    final nt = needT('own');
    if (nt != null) return nt;
    x = math.min(x, floatOf(c));
    if (x <= 0) return M('市場に株が残っていません');
    if (unitsOn) x = math.min(x, mktRoom(c));
    final cost = c.cap * x / 100 * 1.05;
    if (cash < cost) return M('お金が足りません');
    final before = pctOf(c);
    cfAdd('stock', -cost);
    c.stakePlayer = before + x;
    useT('own');
    presXp('zai', 1.5);
    liarCheck();
    final msg = <Object?>[M('{0}の株を{1}買いました（{2}）。持ち株は{3}', [Nm(c.name), pct(x), Y(cost), pct(c.stakePlayer)])];
    if (before < 5 && c.stakePlayer >= 5) {
      msg.add(M('相手に気づかれました'));
      c.rel -= 20;
      tieRec(c, 'g', M('株を買い集めた'));
      if (c.rival != null && (c.rival!.type == 'zaibatsu' || c.rival!.type == 'state')) {
        c.fam = math.min(70, c.fam + 8);
        msg.add(M('{0}は守りを固めています', [Nm(c.presName)]));
      }
    }
    afterStake(c);
    return Cat(msg, ja: '。', en: '. ');
  }

  double tobChance(Company c, double target) {
    var p = .55 + (pres.ab['zai']! - 50) / 200;
    if (hasT('charm')) p += .15;
    if (hasT('gambler')) p += .2;
    // 二枚舌・人たらしの部下は株の攻防と交渉に強い（1.1.0+33）
    if (anyTr('liar')) p += .03;
    if (anyTr('charm')) p += .02;
    if (c.rival != null) {
      p -= c.rival!.type == 'state'
          ? .35
          : c.rival!.type == 'zaibatsu'
              ? .2
              : .1;
    }
    if (c.fam > 50) p -= .3;
    if (target > 60) p -= .1;
    return clampD(p, .05, .95);
  }

  double tobCost(Company c, double target) => c.cap * math.max(0, target - pctOf(c)) / 100 * 1.3;

  String tob(Company c, double target) {
    // 1.1.0+29 から、TOB は申し入れ→相手の返事→当局の審査→手続きと月をまたいで進む（game_corp.dart）
    if (unitsOn) return maStart(c, dd: false, target: target);
    final nt = needT('tob');
    if (nt != null) return nt;
    final cost = tobCost(c, target);
    if (cash < cost) return M('お金が足りません（{0} 必要）', [Y(cost)]);
    useT('tob');
    liarCheck();
    tieRec(c, 'g', M('TOBを仕掛けた'));
    if (rnd() < tobChance(c, target)) {
      cfAdd('stock', -cost);
      final need = target - pctOf(c);
      final fromFloat = math.min(need, floatOf(c));
      c.fam -= math.max(0, need - fromFloat);
      c.stakePlayer = target;
      c.rel -= 30;
      afterStake(c);
      return M('TOB成功！{0}の株を{1}まで買い取りました', [Nm(c.name), pct(target)]);
    }
    cfAdd('misc', -(cost * .03));
    c.rel -= 20;
    return M('TOBは失敗しました。株主が応じてくれませんでした（手数料 {0}）', [Y(cost * .03)]);
  }

  void afterStake(Company c) {
    if (pctOf(c) > 50 && c.parent != 'player') {
      c.parent = 'player';
      joinedGroup(c);
      rivalDefeated(c);
      log.add(LogEntry(M('{0}を子会社にしました', [Nm(c.name)]), 'big', year, q));
      chron('buy', M(c.rival != null ? '{0}（宿敵）の株を{1}握り、子会社にした' : '{0}の株を{1}握り、子会社にした', [Nm(c.name), pct(pctOf(c))]));
    }
    calcAll();
  }

  String sellStake(Company c) {
    final x = pctOf(c);
    final v = c.cap * x / 100 * .95;
    cfAdd('stock', v);
    c.stakePlayer = 0;
    if (c.parent == 'player') c.parent = null;
    calcAll();
    return M('{0}の株を手放し、{1}を得ました', [Nm(c.name), Y(v)]);
  }

  /// 現地法人は合併できない（その国の分を本社に戻す仕組みは持たない）
  bool canMerge(Company c) => pctOf(c) >= 66.7 && sh.rivMax < 33.4 && c.loc == null;

  /// 合併すると、会社を売ったときの「同じ業種に入らない約束」を破る業種が入るか（入るなら理由。1.1.0+37）
  String? mergeBlock(Company c) {
    final nc = noncomp;
    if (nc == null || nc.broken || turn >= nc.until) return null;
    final hit = c.biz.where((b) => nc.inds.contains(b.ind)).firstOrNull;
    if (hit == null) return null;
    return M('{0}には「{1}」の事業があり、会社を売ったときの約束で、まだ自社には入れられません', [Nm(c.name), I(hit.ind)]);
  }

  String merge(Company c, {bool viaSwap = false}) {
    if (!canMerge(c)) return M('合併の条件を満たしていません');
    final mb = mergeBlock(c);
    if (mb != null) return mb;
    // 株式交換から来たときは、時間はそちらで使った
    if (!viaSwap) {
      final nt = needT('merge');
      if (nt != null) return nt;
    }
    final rest0 = c.cap * (100 - pctOf(c)) / 100;
    final n = rest0 / (cap + rest0);
    if (listed) {
      final k = 1 - n;
      _dilute(k);
      sh.float = sh.float * k + n * 100;
    } else {
      if (n < 1) corp.nSh /= 1 - n;
      sh.own *= 1 - n;
      sh.pt = sh.pt * (1 - n);
      sh.vc += n * 100;
    }
    if (!viaSwap) useT('merge');
    for (final b in c.biz) {
      final ex = biz.where((x) => x.ind == b.ind).firstOrNull;
      if (ex != null) {
        ex.power += b.power;
        ex.crew = crewOf(ex) + b.power * 1.2;
        // 買った会社の店なども引き継ぐ（1.1.0+26）
        if (unitsOn && unitRevNow(ex) > 0) seedUnits(ex, home, math.max(1, (b.rev / unitRevNow(ex)).round()));
      } else {
        final nb = Biz(id: uid(), ind: b.ind, power: b.power, crew: b.power * 1.2);
        biz.add(nb);
        ensureUnits(nb);
      }
    }
    if (cultureOf(c) != culture) {
      for (final qq in staff) {
        qq.loy -= 10;
      }
      for (final b in biz) {
        if (c.biz.any((x) => x.ind == b.ind)) b.power *= .92;
      }
      log.add(LogEntry(M('{0}は「{1}」の会社でした。社風がぶつかり、社内が揺れています', [Nm(c.name), D(CULT[cultureOf(c)]!.nJa)]), 'bad', year, q));
    }
    rivalDefeated(c);
    cash += c.cash;
    c.alive = false;
    final p = mkPerson(.4);
    p.name = c.presName;
    p.age = jsRound(c.presAge).toInt();
    // 宿敵の社長だった人は、同じ顔のまま部下になる
    if (c.pfn == c.presName) {
      p.face = c.pf;
      p.fb = c.pfb;
    }
    staff.add(p);
    if (sh.riv.containsKey(c.id)) {
      sh.float += sh.riv[c.id]!;
      sh.riv.remove(c.id);
    }
    joinedGroup(c);
    // 大口の客だった会社を合併したら、その客はもう社内（次の月に新しい客を見る。1.1.0+37）
    corp.clients.removeWhere((_, cl) => cl.co == c.id);
    presXp('zai', 4, big: true);
    presXp('tou', 2, big: true);
    calcAll();
    if (viaSwap) {
      chron('swap', M(c.rival != null ? '株式交換で{0}（宿敵）を丸ごと買い、合併した。持ち株は{1}に' : '株式交換で{0}を丸ごと買い、合併した。持ち株は{1}に', [Nm(c.name), pct(sh.own)]));
    } else {
      chron('merge', M(c.rival != null ? '{0}（宿敵）を合併した' : '{0}を合併した', [Nm(c.name)]));
    }
    return M('{0}を合併しました。事業はすべてあなたのものです。{1}が部下に加わりました', [Nm(c.name), Nm(p.name)]);
  }

  double swapChance(Company c) => clampD(tobChance(c, 100) + (c.rel > 20 ? .15 : 0) - (c.cap > cap * .5 ? .15 : 0), .05, .9);

  String shareSwap(Company c) {
    if (!listed) return M('上場してからです');
    if (c.parent == 'player' && pctOf(c) >= 66.7) return M('そのまま合併できます');
    if (c.cap > cap) return M('自分より大きな会社は、株式交換では買えません');
    if (sh.rivMax >= 33.4) return M('宿敵に株を33.4%以上握られていて、株式交換を止められます');
    final mb = mergeBlock(c);
    if (mb != null) return mb;
    if (unitsOn) return maStart(c, dd: false, target: 100, pay: 'swap');
    final nt = spendT('merge');
    if (nt != null) return nt;
    if (rnd() > swapChance(c)) {
      c.rel -= 15;
      return M('{0}の経営陣が反対し、株式交換は流れました', [Nm(c.name)]);
    }
    final rest0 = c.cap * (100 - pctOf(c)) / 100;
    final n = rest0 / (cap + rest0);
    final k = 1 - n;
    _dilute(k);
    sh.float = sh.float * k + n * 100;
    c.stakePlayer = 100;
    final m = merge(c, viaSwap: true);
    return Cat([M('株式交換で{0}を丸ごと買いました。あなたの持ち株は{1}に下がりました', [Nm(c.name), pct(sh.own)]), m], ja: '。', en: '. ');
  }

  List<RankRow> rankList() {
    final L = cos.where((c) => c.alive && c.parent != 'player').map((c) => RankRow(c.name, c.cap, c: c)).toList();
    L.add(RankRow(myLabel(), cap + wealth, me: true));
    L.ssort((a, b) => b.cap.compareTo(a.cap));
    return L;
  }

  String choosePresSucc(int? id) {
    succ = id;
    return M('後継ぎを決めました');
  }

  String retire() {
    Person? s;
    if (succ != null) s = staffById(succ) ?? kids.where((k) => k.id == succ).firstOrNull;
    if (s == null) return M('先に後継ぎを決めてください');
    final old = pres.name;
    takeOver(s);
    calcAll();
    return M('{0}が引退し、{1}が社長になりました', [Nm(old), Nm(s.name)]);
  }
}
