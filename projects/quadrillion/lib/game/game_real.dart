// ignore_for_file: non_constant_identifier_names
part of 'game.dart';

// ===== 現実に寄せる（1.1.0+25 から。企画書「現実に寄せる（2026-11-25 決定）」の段1） =====

/// 社長が1か月にふつうに使える時間と、無理をして使える上限
const double hoursNormal = 200, hoursMax = 300;

/// 行動ごとにかかる社長の時間（時間）。ここに無いものは 'act'
const Map<String, double> hoursOf = {
  'act': 8,
  'start': 40, // 新しい事業を立ち上げる（場所・人・取引先を決める）
  'invest': 8,
  'enter': 50, // 海外に出る（1週間の視察と交渉）
  'model': 16, // 稼ぎ方を変える
  'build': 8, // 現場回り（物件を見て決める）
  'extend': 6,
  'dev': 10, // 商品の会議
  'hire': 2, // 面接
  'crew': 4, // 現場の人の採用を決める
  'ad': 3,
  'war': 6,
  'pivot': 24,
  'sell': 16, // 事業を売る交渉
  'seek': 8, // 相棒を探す
  'work': 60, // 日銭を稼ぐ（受託の仕事）
  'net': 12, // 人脈を作る（会食・会合）
  'scout': 10, // 事業の種を探す
  'bank': 4, // 銀行に会う
  'bond': 8, // 社債を出す
  'vc': 16, // 投資家に会う
  'deal': 6, // 提携の話
  'spin': 16,
  'release': 8,
  'talk': 1, // 部下の話を聞く・研修に出す（1.1.0+27）
  'raise': 1, // 給料を上げる（1.1.0+27）
  'subipo': 24,
  'holding': 16,
  'split': 16,
  'dirty': 6,
  'sellco': 24,
  'own': 4,
  'tob': 24, // 株を買い付ける（TOB）
  'merge': 30, // 合併・株式交換の交渉
  'private': 24,
  'culture': 8,
  'offer': 16,
  'ipo': 40,
  'buyback': 4,
  'knight': 12,
  'dilute': 8,
  'local': 24,
  'rest': 40, // 休む（体力が戻る）
  'inspect': 50, // 海外の視察（1週間。1.1.0+28）
  'supply': 6, // 仕入れ先を足す交渉（1.1.0+28）
  'it': 16, // 新しいITを入れる（1.1.0+30）
  'assoc': 12, // 業界団体の役職（1.1.0+30）
  'media': 10, // 取材・講演
  'donate': 2, // 寄付
};

/// 借金が年の利益の何倍を超えると金利が上がるか（段ごとの上乗せ。年の率）
const List<(double, double)> debtSteps = [(3, .02), (5, .03), (8, .05)];

/// 借りるたびに付く返す期限（月）
const int loanTermDefault = 60;
const List<int> loanTerms = [12, 60, 120];

/// 格付けの名前（A〜D）
const List<String> ratings = ['A', 'B', 'C', 'D'];

/// 経費の内訳の鍵（お金の画面で先月と比べる）
const List<String> expKeys = ['labor', 'rent', 'cogs', 'util', 'logi', 'ad', 'insur', 'repair', 'hq', 'int', 'tax'];

/// 統計が無いときの、日本だけの小さなデータ（アプリが統計を読めなかったとき・仕組みだけのテスト用の最後の砦）
const String _econFallback =
    '{"meta":{"provisional":true,"note":"仮（内蔵の最小データ）"},"countries":{"jp":{"currency":"JPY","cities":[{"name_ja":"東京","name_en":"Tokyo","pop":37000000}],"years":{"1980":{"pop":117000000,"gdp_growth":2.8,"gdp_usd":1.1e12,"cpi":77.6,"rate":7.25,"fx_usd":226.7,"wage_usd":13200,"min_wage":55000,"corp_tax":52,"unemp":2.0},"2024":{"pop":124000000,"gdp_growth":0.5,"gdp_usd":4.03e12,"cpi":108.5,"rate":0.25,"fx_usd":151.4,"wage_usd":30400,"min_wage":180000,"corp_tax":29.7,"unemp":2.5}}}},"events":[]}';

/// 使う統計（読み込んでいなければ内蔵の最小データ）
EconData get econData => EconData.current ??= loadEcon(_econFallback);

/// 統計の文字を読み、ゲームの国に合わせて使える形にする（データに無い国は作る）
EconData loadEcon(String text) {
  final d = EconData.parse(text, codes: [for (final c in CTRY) c.c], shape: cwShape);
  addDynEn(d.enTexts());
  return d;
}

extension GameReal on Game {
  // ===== 統計を引く =====
  /// 今の月の、その国の数字
  double ev(String c, String key, [double? y]) {
    econData.fcSeed = fcSeed;
    return econData.at(c, y ?? yr(), key);
  }

  /// その年の成長率（%）
  double growthOf(String c, [int? y]) {
    econData.fcSeed = fcSeed;
    final v = econData.year(c, y ?? year).gdpGrowth ?? 2;
    return v.isFinite ? clampD(v, -25, 25) : 2;
  }

  /// 景気の倍率（成長率から。2%で1、マイナス成長で1を下回る）
  double econOf(String c, [int? y]) => clampD(1 + (growthOf(c, y) - 2) * .03, .72, 1.25);

  /// その年の物価の上がり方（%。前の年の物価との比）
  double inflOf(String c, [int? y]) {
    final yy = y ?? year;
    econData.fcSeed = fcSeed;
    final a = econData.year(c, yy - 1).cpi ?? 100, b = econData.year(c, yy).cpi ?? 100;
    return a > 0 ? (b / a - 1) * 100 : 0;
  }

  /// その国の金利（%）。ハイパーインフレ期の極端な値（ブラジル1990年の38,198%など）で計算が壊れないよう、-1〜30% に抑える
  double rateOf(String c) {
    final v = ev(c, 'rate');
    return v.isFinite ? clampD(v, -1, 30) : 5;
  }

  /// 法人税率（0.3 = 30%）
  double corpTaxRate() {
    final v = ev(home, 'corp_tax');
    return v.isFinite ? clampD(v / 100, .1, .6) : .3;
  }

  /// その国が、その年にもう選べる・出られるか（統計がその年からある。ロシアは1991年まで無い）
  bool ctryOpen(String c, [int? y]) => (y ?? year) >= econData.availableFrom(c);

  /// 為替を円で（1ドル何円か）
  double usdJpy() => ev('jp', 'fx_usd');

  /// その国の通貨の、ドルとの値（1ドルが自国の通貨でいくら）
  double fxOf(String c) => ev(c, 'fx_usd');

  /// 3年前と比べた為替の動き（1より大きいと自国の通貨が安くなった）
  double fxMove(String c) {
    final a = ev(c, 'fx_usd', yr() - 3), b = ev(c, 'fx_usd');
    final r = a > 0 ? b / a : 1.0;
    return r.isFinite ? clampD(r, .2, 5) : 1;
  }

  /// 最低賃金を円の年額にした目安（統計は自国の通貨の月額。平均賃金の2倍を上限にする）
  double minWageYen(String c) {
    final v = ev(c, 'min_wage') * 12 / math.max(ev(c, 'fx_usd'), 1e-12) * usdJpy();
    final cap = ev(c, 'wage_usd') * usdJpy() * 2;
    return v.isFinite ? clampD(v, 0, cap) : cap * .2;
  }

  /// 賃金の倍率（2020年の日本の平均を1とした、その国の今の平均賃金。円で比べる）
  double wageIdx(String c) {
    final base = econData.year('jp', 2020);
    final b = (base.wageUsd ?? 40500) * (base.fxUsd ?? 106.8);
    return ev(c, 'wage_usd') * usdJpy() / math.max(b, 1);
  }

  /// 業種の分類ごとの、現場の人1人の年の人件費（円）。店の仕事（食・暮らし・娯楽）は最低賃金にも引っぱられる
  double wageCat(String cat) {
    final base = (wageByCat[cat] ?? 4e6) * wageIdx(home);
    if (cat == 'food' || cat == 'live' || cat == 'fun') return .5 * base + .5 * minWageYen(home) * 1.35;
    return base;
  }

  // ===== 社長の時間と体力 =====
  /// 会社が大きいほど毎月取られる会議と決めごとの時間（任せた事業は少なく、持株会社は半分）
  double hMeet() {
    final own = biz.where((b) => !b.deleg).length, dl = biz.length - own;
    var h = 10.0 + own * 6 + dl * 2 + staff.length * 2 + subs().length * 3 + (listed ? 10 : 0) + (bankCtl > 0 ? 12 : 0);
    if (holding) h = 10 + (h - 10) * .5;
    return h;
  }

  /// 今月まだ使える時間（無理をして使える上限までの残り）
  double hLeft() => down > 0 ? 0 : math.max(0, hoursMax - hMeet() - hUsed);

  /// 今月ふつうに使える残り（これを超えると無理になり、体力が減る）
  double hNormalLeft() => down > 0 ? 0 : math.max(0, hoursNormal - hMeet() - hUsed);

  /// 行動にかかる時間
  double hrs(String k) => hoursOf[k] ?? hoursOf['act']!;

  /// その行動の時間が残っているか
  bool canT(String k) => down == 0 && hLeft() >= hrs(k);

  /// 時間が足りないときの文（足りれば null）
  String? needT(String k) {
    if (freeTime) return null;
    if (down > 0) return M('社長は倒れて休んでいます（あと{0}か月）', [down]);
    if (hLeft() < hrs(k)) return M('今月の社長の時間が足りません（{0}時間かかります・残り{1}時間）', [jsRound(hrs(k)), jsRound(hLeft())]);
    return null;
  }

  /// 時間を使う
  void useT(String k) {
    if (!freeTime) hUsed += hrs(k);
  }

  /// 時間が足りなければ文を返し、足りれば使って null を返す
  String? spendT(String k) {
    final m = needT(k);
    if (m == null) useT(k);
    return m;
  }

  /// 月の終わりに、使った時間で体力を動かし、倒れたら数か月休む。新しい月の時間を戻す
  void monthHours(void Function(String, [String]) N) {
    final total = hMeet() + hUsed;
    if (down > 0) {
      down--;
      stamina = math.min(100, stamina + 20);
      if (down == 0) N(M('社長が仕事に戻りました'), 'good');
    } else {
      final over = math.max(0.0, total - hoursNormal);
      if (over > 0) {
        stamina -= over * .3 * (hasT('stamina') ? .5 : 1) * (pres.age >= 55 ? 1.3 : 1);
      } else {
        stamina += (8 + (hoursNormal - total) / 12) * (pres.age >= 60 ? .7 : 1);
      }
      stamina = clampD(stamina, -50, 100);
      if (stamina <= 0) {
        down = ri(2, 4);
        stamina = 40;
        N(M('社長が働きすぎで倒れました。{0}か月は仕事ができません（任せた事業と会議は部下が回します）', [down]), 'bad');
        chron('board', M('社長が働きすぎで倒れ、{0}か月休んだ', [down]));
      } else if (stamina < 25 && over > 0) {
        N(M('社長の体力が残り{0}です。無理が続くと倒れます', [jsRound(stamina)]), 'bad');
      }
    }
    lastHours = total;
    hUsed = rest != 0 ? 100 : 0;
  }

  /// 休む（時間を使って体力を戻す）
  String restAct() {
    final m = spendT('rest');
    if (m != null) return m;
    final s0 = stamina;
    stamina = math.min(100, stamina + 25);
    return M('休みを取りました。体力 {0} → {1}', [jsRound(s0), jsRound(stamina)]);
  }

  // ===== 借金と銀行 =====
  double get debt => loans.fold(0.0, (s, l) => s + l.amt);
  double get bond => loans.where((l) => l.lender == 'bond').fold(0.0, (s, l) => s + l.amt);

  /// 毎月の利息
  double loanInterest() => loans.fold(0.0, (s, l) => s + l.interest) * (hasT('careful') ? .9 : 1);

  /// 今月返す元本
  double loanPrincipal() => loans.fold(0.0, (s, l) => s + l.principal);

  /// 直近12か月の利益（記録が12か月に満たないときは、ある分をならして12倍）
  double annualProfit() {
    final h = hist;
    if (h.isEmpty) return pre * 12;
    final n = math.min(12, h.length);
    var s = 0.0;
    for (var i = h.length - n; i < h.length; i++) {
      s += h[i].pre;
    }
    return s / n * 12;
  }

  /// 担保の値打ち（店・工場・土地。現金は入れない）
  /// 1.1.0+26 から、店・ライン・設備などは、持っている数×初期投資の6割（建物と設備の値打ち）で見る
  double collateral() => biz.fold(0.0, (s, b) => s + math.min(unitsOn ? unitTotal(b) * unitCapexAvg(b) * .6 : b.power * .6, sellValue(b))) + land;

  /// 借金が年の利益の何倍か（利益が無ければ大きな数）
  double debtMultiple() {
    final a = annualProfit();
    if (debt <= 0) return 0;
    return a > 0 ? debt / a : 99;
  }

  /// 格付け（0=A〜3=D）。借金が利益の何倍か、赤字か、返せなかったことがあるかで決まる
  int ratingIdx() {
    if (debt <= 0 && missed == 0) return 0;
    final x = debtMultiple();
    var r = x < 3
        ? 0
        : x < 5
            ? 1
            : x < 8
                ? 2
                : 3;
    // 赤字のときは担保で見る（1.1.0+30 から、担保の4分の1までの借金なら B・半分までなら C。
    // 前は利益の倍が 99 になって必ず D になり、赤字の月につなぎの融資を少し受けただけで仕入れ先に支払いを早められ、倒れていた）
    if (annualProfit() <= 0) {
      final c = collateral();
      r = debt <= c * .25
          ? 1
          : debt <= c * .5
              ? 2
              : 3;
    }
    if (missed > 0) r = math.min(3, r + 1);
    if (bankCtl > 0) r = 3;
    return r;
  }

  String rating() => ratings[ratingIdx()];

  /// 借りられる上限（稼ぐ力×倍率＋担保の半分＋小さな会社でも借りられる分）。現金は入れない
  double borrowLimit() {
    final a = math.max(0.0, annualProfit());
    // 1.1.0+26 から、店などの数で利益の伸びが遅くなったので、稼ぐ力の倍率を3倍から2.5倍にした（5年で返す借金が利益を超えないように）
    final mult = (unitsOn ? 2.5 : 3.0) * (econ > 1.05 ? 1.25 : econ < .95 ? .8 : 1) * (1 + .1 * net) * (culture == 'steady' ? 1.1 : 1) * (hasT('noble') ? 1.5 : 1) * (cooked > 0 ? 1.3 : 1);
    // 事業がまだ1つも無い会社には、決まった枠では貸さない（1.1.0+26。何もしていない会社に貸す銀行は無い）
    final base = unitsOn && biz.isEmpty ? 0.0 : 2e7 * nom() * (1 + .2 * net) * (hasT('noble') ? 2 : 1);
    return a * mult + collateral() * .4 + base;
  }

  /// あといくら借りられるか（格付けが C なら残りの半分、D なら貸さない）
  double borrowRoom() {
    final r = ratingIdx();
    if (r >= 3 || bankCtl > 0) return 0;
    final room = math.max(0.0, borrowLimit() - debt);
    return r == 2 ? room * .5 : room;
  }

  /// 新しく借りるときの金利（その国のその年の金利＋上乗せ。借金が利益の3倍・5倍・8倍を超えるごとに上がる）
  double loanRate([double extra = 0]) {
    final after = annualProfit() > 0 ? (debt + extra) / annualProfit() : 99.0;
    var r = math.max(0.0, rateOf(home)) / 100 + .02;
    for (final s in debtSteps) {
      if (after > s.$1) r += s.$2;
    }
    if (hasT('noble')) r -= .003;
    return math.max(.005, r);
  }

  int _loanId() => ++loanSeq;

  String _lenderFor() {
    final banks = loans.where((l) => l.lender != 'bond' && l.lender != 'bridge').map((l) => l.lender).toSet();
    if (!banks.contains('main')) return 'main';
    if (debt > borrowLimit() * .4 && !banks.contains('second')) return 'second';
    if (home == 'jp' && !banks.contains('local') && rnd() < .3) return 'local';
    return 'main';
  }

  /// 借りる（銀行に会う社長の時間がかかる）。[term] は返す期限（月）
  String borrow(double a, [int term = loanTermDefault]) {
    if (a <= 0) return M('借りる額がありません');
    if (bankCtl > 0) return M('銀行が経営に口を出している間は、新しく借りられません');
    if (ratingIdx() >= 3) return M('格付けが低く、銀行に断られました');
    if (a > borrowRoom() + 1) return M('銀行がこれ以上は貸してくれません');
    final m = spendT('bank');
    if (m != null) return m;
    final r = loanRate(a);
    loans.add(Loan(id: _loanId(), lender: _lenderFor(), amt: a, orig: a, rate: r, left: term, term: term, at: turn));
    cfAdd('borrow', a);
    presXp('zai', 2);
    calcAll();
    return M('{0}を借りました（年{1}%・{2}年で返す・毎月の返済 約{3}）', [Y(a), pctD(r * 100), (term / 12).round(), Y(a / term + a * r / 12)]);
  }

  /// 返す（期限の近いものから。前倒しで返すのに時間はかからない）
  String repay(double a) {
    a = math.min(a, math.min(debt, cash));
    if (a <= 0) return M('返すお金がありません');
    // 借金の1割以上をまとめて返したときだけ、財務の経験になる
    if (a >= debt * .1) presXp('zai', 1.5);
    var left = a;
    final order = loans.toList()..ssort((x, y) => x.left.compareTo(y.left));
    for (final l in order) {
      if (left <= 0) break;
      final p = math.min(l.amt, left);
      l.amt -= p;
      left -= p;
    }
    loans.removeWhere((l) => l.amt <= 1);
    cfAdd('repay', -a);
    calcAll();
    return M('{0}を返しました', [Y(a)]);
  }

  /// 社債を出す（格付けが A・B で、売上が大きい会社だけ。最後にまとめて返す）
  bool canBond() => rev * 12 >= 5e9 * nom() && ratingIdx() <= 1 && bond <= 0 && bankCtl == 0;
  double bondSize() => math.max(0.0, math.min(rev * 12 * .2, borrowRoom()));

  String issueBond() {
    if (!canBond()) return M('今は社債を出せません');
    final a = bondSize();
    if (a <= 0) return M('今は社債を出せません');
    final m = spendT('bond');
    if (m != null) return m;
    final r = math.max(.004, loanRate(a) - .005);
    loans.add(Loan(id: _loanId(), lender: 'bond', amt: a, orig: a, rate: r, left: 60, term: 60, bullet: true, at: turn));
    cfAdd('borrow', a);
    presXp('zai', 2);
    calcAll();
    return M('社債で{0}を集めました（年{1}%・5年後にまとめて返す）', [Y(a), pctD(r * 100)]);
  }

  /// 足りない分を借りて払う（社長の時間はかからない。つなぎの融資で金利は高め・1年で返す）。借りられなければ false
  bool bridgeLoan(double a, void Function(String, [String])? N) {
    if (a <= 0) return true;
    if (bankCtl > 0 || ratingIdx() >= 3 || borrowRoom() < a) return false;
    final r = loanRate(a) + .02;
    loans.add(Loan(id: _loanId(), lender: 'bridge', amt: a, orig: a, rate: r, left: 12, term: 12, at: turn));
    cfAdd('borrow', a);
    N?.call(M('資金が足りず、銀行からつなぎの融資{0}を受けました（年{1}%・1年で返す）', [Y(a), pctD(r * 100)]), 'bad');
    return true;
  }

  /// 話の中で銀行から借りる（会議や出来事の選択。時間はかからない。期限は5年）
  void loanFromEvent(double a, {String lender = 'main'}) {
    if (a <= 0) return;
    loans.add(Loan(id: _loanId(), lender: lender, amt: a, orig: a, rate: loanRate(a), left: loanTermDefault, term: loanTermDefault, at: turn));
  }

  /// 毎月の返済（元本）。払えなければ、つなぎの融資→事業を売る→銀行が口を出す→倒産の順
  void monthLoans(void Function(String, [String]) N) {
    if (missed > 0) missed--;
    if (bankCtl > 0) {
      bankCtl--;
      if (bankCtl == 0) N(M('銀行の管理が終わりました。また自分で借りられます'), 'good');
    }
    var due = 0.0;
    for (final l in loans) {
      final p = l.principal;
      due += p;
      l.amt -= p;
      l.left--;
    }
    loans.removeWhere((l) => l.amt <= 1 || l.left <= 0);
    cfAdd('repay', -due);
    lastPrincipal = due;
  }

  /// 不況の年の初めに、格付けの低い会社へ一部の返済を迫る
  void recessionCall(void Function(String, [String]) N) {
    if (q != 1 || growthOf(home) >= 0) return;
    N(M('【景気後退】{0}の今年の成長率は{1}%の見込みです', [C(home), pctD(growthOf(home))]), 'bad');
    // 格付けが C・D なら借金の2割、B でも借金が上限を超えていれば1割を、すぐ返すよう迫られる（不況で担保の値打ちと利益が落ちると、上限も下がる）
    final r = ratingIdx();
    // 1.1.0+30 から、借金が利益の4倍を超える会社（B でも）には、上限を超えていなくても1割5分を迫る（借りまくって不況を迎えると苦しくなるように）
    final k = r >= 2
        ? .25
        : r == 1 && (debt > borrowLimit() || debtMultiple() > 4)
            ? .15
            : 0.0;
    if (k == 0) return;
    final bank = loans.where((l) => l.lender != 'bond').toList();
    final owe = bank.fold(0.0, (s, l) => s + l.amt) * k;
    if (owe <= 0) return;
    for (final l in bank) {
      l.amt -= l.amt * k;
    }
    loans.removeWhere((l) => l.amt <= 1);
    cfAdd('repay', -owe);
    N(M('不況で銀行が貸しはがしに来ました。格付け{0}のため、借金の{1}割（{2}）をすぐ返すよう求められ、返しました', [rating(), jsRound(k * 10), Y(owe)]), 'bad');
    missed = math.max(missed, 6);
  }

  /// 現金が足りないときの手当て（つなぎの融資 → いちばん弱い事業を売る → 銀行が経営に口を出す → 倒産）
  void coverShort(void Function(String, [String]) N) {
    if (cash >= 0) return;
    if (bridgeLoan(-cash, N)) return;
    missed = math.max(missed, 12);
    while (cash < 0 && biz.length > 1) {
      final w = (biz.toList()..ssort((a, b) => a.profit.compareTo(b.profit)))[0];
      final v = sellValue(w);
      cfAdd('bizSale', v);
      biz.remove(w);
      N(M('返すお金が足りず、「{0}」を{1}で手放しました', [I(w.ind), Y(v)]), 'bad');
    }
    if (cash >= 0) return;
    if (bankCtl == 0 && loans.isNotEmpty && !bankDone) {
      // 銀行が経営に口を出す：返す期限を2年のばし、足りない分を貸すかわりに、2年のあいだ新しく借りられず、会議にも時間を取られる
      bankDone = true;
      bankCtl = 24;
      for (final l in loans) {
        l.left += 24;
        l.rate += .01;
      }
      final a = -cash;
      loans.add(Loan(id: _loanId(), lender: 'main', amt: a, orig: a, rate: loanRate() + .02, left: 36, term: 36, at: turn));
      cfTag = 'borrow';
      cash = 0;
      N(M('資金が尽きかけ、メインバンクが経営に口を出してきました。返す期限はのびましたが、2年のあいだ新しく借りられません'), 'bad');
      chron('board', M('資金繰りに行き詰まり、メインバンクの管理下に入った'));
      return;
    }
    // 一度だけ、民事再生で立て直す（1.1.0+30。game_life.dart）
    if (restructure(N)) return;
    if (mode == 'endless') {
      N(M('会社は倒産しました。残った人脈で、もう一度ゼロから始めます'), 'bad');
      rebirth();
    } else {
      over = M('資金が尽きて、会社は倒産しました');
    }
  }

  // ===== 税金 =====
  /// 今月の税金（今年の利益の積み上げに国の法人税率をかけ、まだ払っていない分。赤字の月は払った分から戻る）
  double monthTax(double p0) {
    if (q == 1) {
      ytdPre = 0;
      ytdTax = 0;
    }
    // 1.1.0+30 から、店・工場などに使ったお金は耐用年数で減価償却し、税の計算で利益から引く
    ytdPre += p0 - depMonth();
    final want = math.max(0.0, ytdPre) * corpTaxRate();
    final t = want - ytdTax;
    ytdTax = want;
    return t;
  }

  // ===== 経費の内訳 =====
  /// 今月の経費の内訳（11種。1.1.0+26 から）：人件費（現場・部下・本部）・家賃・原価・光熱費・物流費・広告費・保険料・修繕と更新・本社・利息・税金
  Map<String, double> expenses() {
    final f = List<double>.filled(5, 0);
    var cogs = 0.0, labor = salaries();
    for (final b in biz) {
      labor += b.upkeep;
      if (unitsOn) labor += b.sv * svPayOne(b);
      if (tradeOn) labor += trade.labor[b.id] ?? 0;
      cogs += cogsOf[b.id] ?? math.max(0.0, b.rev - b.profit - b.upkeep);
      final x = fixOf[b.id];
      if (x != null) {
        for (var i = 0; i < 5; i++) {
          f[i] += x[i];
        }
      }
    }
    return {
      'labor': labor,
      'rent': f[0],
      'cogs': cogs,
      'util': f[1],
      'logi': f[2],
      'ad': biz.fold(0.0, (s, b) => s + (b.ad > 0 ? b.adCost : 0)),
      'insur': f[3],
      'repair': f[4],
      'hq': hq,
      'int': interest,
      'tax': math.max(0.0, lastTax),
    };
  }

  /// この先6か月の資金繰りの見込み（入る・出る・残り）。今の月の売上と経費が続き、返済の予定どおりに返すとして数える
  List<({double inflow, double out, double cash})> cashPlan([int n = 6]) {
    final out = <({double inflow, double out, double cash})>[];
    var c = cash;
    final ls = [for (final l in loans) (amt: l.amt, left: l.left, rate: l.rate, bullet: l.bullet)];
    // 子会社の売上と利益の持ち分は現金にならない。入るのは配当だけ（1.1.0+35）
    final profitBeforeInt = pre - subP + interest;
    final inflow = math.max(0.0, rev - subR) + subDivs();
    final costs = math.max(0.0, rev - subR - profitBeforeInt);
    final taxRate = corpTaxRate();
    for (var i = 0; i < n; i++) {
      var intr = 0.0, prin = 0.0;
      for (var k = 0; k < ls.length; k++) {
        final l = ls[k];
        if (l.left <= 0 || l.amt <= 0) continue;
        intr += l.amt * l.rate / 12;
        final p = l.bullet ? (l.left <= 1 ? l.amt : 0.0) : (l.left <= 1 ? l.amt : l.amt / l.left);
        prin += p;
        ls[k] = (amt: l.amt - p, left: l.left - 1, rate: l.rate, bullet: l.bullet);
      }
      final tax = math.max(0.0, profitBeforeInt - intr) * taxRate;
      final o = costs + intr + prin + tax;
      c += inflow - o;
      out.add((inflow: inflow, out: o, cash: c));
    }
    return out;
  }

  /// 払えなくなる線（毎月の決まった支払い：経費の半月分＋今月の返済）。残りがこれを下回る月に印を付ける
  double dangerLine() => math.max(0.0, rev - subR - (pre - subP) - interest) * .5 + loanPrincipal();

  /// 子会社が今月払う配当の総額（株主みんなへ。利益の4割。子会社の手元の現金を超えては払えない。1.1.0+35）
  double subPayout(Company c) => c.profit > 0 ? math.min(c.profit * .4, math.max(0.0, c.cash)) : 0.0;

  /// 今月、子会社から受け取る配当（持ち分の分）
  double subDivs() => subs().fold(0.0, (s, c) => s + subPayout(c) * pctOf(c) / 100);

  /// 月の利益のうち現金になる分（自社の事業の利益＋子会社の配当。税の前）。
  /// [pre] は子会社の利益の持ち分を含むが、それは決算上の数で現金にはならない（1.1.0+35）
  double cashPre() => pre - subP + subDivs();

  // ===== 景気と出来事 =====
  /// 統計の大きな出来事を、時代の波（株価と景気の揺れ）にする。自分の国か、世界中に響くものだけ
  void eventCycles(int fromYear) {
    for (final e in econData.events) {
      if (e.year + 3 < fromYear) continue;
      if (!(e.global || e.countries.contains(home))) continue;
      final boom = e.gdpHit >= 0;
      final dur = boom ? 3 : 2;
      final double per = boom ? 1.5 : 1 + math.max(-.45, e.gdpHit * .08);
      final tech = e.kind.contains('tech') || e.kind.contains('dot') ? (boom ? 1.4 : .7) : 1.0;
      final s = e.year + ((e.month ?? 1) - 1) / 12;
      cycles.add(Cycle(
          name: M(e.ja),
          s: s.floor(),
          e: s.floor() + dur - 1,
          econ: 1,
          per: per,
          tech: tech,
          news: e.noteJa.isNotEmpty ? M(e.noteJa) : M(boom ? '景気が大きく上向いています' : '景気が大きく崩れています'),
          shown: e.year < fromYear));
    }
  }

  /// 月の初めの経済の動き（景気の倍率・人件費の物価への追従・年の初めの知らせ）
  void monthEcon(void Function(String, [String]) N) {
    econ = econOf(home);
    // 現場の人件費を、賃金と最低賃金の動きに合わせる（分類ごとの倍率の比）
    final now = <String, double>{};
    for (final b in biz) {
      final cat = indm[b.ind]!.cat;
      final w = now[cat] ??= wageCat(cat);
      final was = wiLast[cat];
      if (was != null && was > 0 && b.upkeep > 0) b.upkeep *= w / was;
    }
    wiLast.addAll(now);
    for (final cat in wageByCat.keys) {
      wiLast[cat] = wageCat(cat);
    }
    if (q == 1) {
      N(M('{0}年の{1}の経済：成長率 {2}%・物価 {3}%・金利 {4}%・1ドル {5}', [year, C(home), pctD(growthOf(home)), pctD(inflOf(home)), pctD(rateOf(home)), fxText(home)]));
    }
  }

  /// 1ドルがいくらかの文（円の国は円、ほかは通貨の名前）
  String fxText(String c) {
    final cur = econData.countries[c]?.currency ?? 'USD';
    final v = fxOf(c);
    if (cur == 'USD') return '1 USD';
    if (cur == 'JPY') return M('{0}円', [jsNum(jsRound(v))]);
    return '${v >= 100 ? jsNum(jsRound(v)) : v.toStringAsFixed(2)} $cur';
  }
}

/// 小数1けたまでの％の数（-0.0 は 0）
String pctD(double v) {
  final r = (v * 10).round() / 10;
  return r == 0 ? '0' : (r == r.roundToDouble() ? r.round().toString() : r.toStringAsFixed(1));
}
