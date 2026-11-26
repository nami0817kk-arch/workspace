part of 'game.dart';

// ===== 決算書（1.1.0+34） =====
// 損益計算書・貸借対照表・キャッシュフロー計算書と、事業ごとの損益を、月の終わりに記録する。
// 記録するだけで、仕組みの数字には使わない（乱数も使わない）。
//
// 数え方:
// - 現金が動くたびに、種類（[Game.cfTag]）ごとに足す（現金の setter）。キャッシュフローの合計は現金の増減と必ず合う。
// - 損益は、月の締め（nextQuarter のお金の計算）で、売上と経費の内訳をそのまま写す。税・利息もそこで写す。
// - 貸借対照表は、月の終わりの持ち物（現金・売掛金・前払い・海外に留め置かれたお金・設備の帳簿価額・土地・株・子会社）と借金から作る。
//   設備は、払った額（店・工場・設備・IT）で増え、増えた分を除いた減りを減価償却とする。
//   株（子会社を含む）と土地は時価で持ち、払った・受け取った額で説明できない増減を「評価差額」とする。
//   借金は、借りた・返した額で説明できない減りを「借金の減免」（民事再生など）とする。
// - 純資産は、資本金（元手と増資）＋利益剰余金（純利益の積み上げ−配当・自社株買い）＋評価差額。
//   資産−負債と合わない分は 'gap' に残す（隠さない。テストで 0 を確かめる）。
// - 年は暦年（1月〜12月）。会社を売った・倒産して始め直したときは、その差を「入れ替え」として資本金に入れる。

/// 損益の行の鍵（月の締めで写すもの）
const finPlKeys = ['rev', 'cogs', 'labor', 'rent', 'util', 'logi', 'ad', 'insur', 'repair', 'hq', 'subc', 'oth', 'intr', 'tax'];

/// 現金の種類（キャッシュフローの行。'c:' を付けて持つ）
const finCfOp = ['op', 'ar', 'pp', 'trap', 'div', 'nonop', 'intr', 'tax', 'grow', 'misc', 'sp+', 'sp-', 'unc'];
const finCfInv = ['capex', 'land', 'stock', 'bizSale'];
const finCfFin = ['borrow', 'repay', 'equity', 'payout'];

/// 貸借対照表の鍵（'b:' を付けて持つ）
const finBsKeys = ['cash', 'ar', 'pp', 'trap', 'eq', 'land', 'stk', 'sub', 'gw', 'loan', 'bond', 'cap', 're', 'rev', 'gap', 'mcap'];

/// 事業ごとの損益の列（売上・原価・人件費・家賃・広告・ほかの固定費・その他・利益）
const finBizCols = 8;

/// 事業ごとの1年（または1か月）の損益
class FinBiz {
  /// 業種の id（子会社・現地法人は、その会社の1つ目の業種）
  String ind;

  /// 子会社・現地法人の名前（自社の事業は null）
  String? co;

  /// 現地法人なら国
  String? loc;
  List<double> v;
  FinBiz(this.ind, {this.co, this.loc, List<double>? v}) : v = v ?? List<double>.filled(finBizCols, 0);
  bool get sub => co != null;
  double get rev => v[0];
  double get profit => v[7];
  double get gross => v[0] - v[1];
  Map<String, dynamic> toJson() => {'i': ind, if (co != null) 'c': co, if (loc != null) 'l': loc, 'v': [for (final x in v) _fr(x)]};
  factory FinBiz.fromJson(Map<String, dynamic> j) => FinBiz(j['i'] as String,
      co: j['c'] as String?,
      loc: j['l'] as String?,
      v: [for (var i = 0; i < finBizCols; i++) i < (j['v'] as List).length ? ((j['v'] as List)[i] as num).toDouble() : 0.0]);
}

/// 締めた月・年の記録（q は月。年の記録は 0）
class FinRec {
  int y, q;

  /// 記録した月の数（年の途中から記録を始めた年は12より少ない）
  int n;
  Map<String, double> v;
  Map<String, FinBiz> biz;
  FinRec(this.y, this.q, this.n, this.v, [Map<String, FinBiz>? biz]) : biz = biz ?? {};
  double g(String k) => v[k] ?? 0;
  Map<String, dynamic> toJson() => {
        'y': y,
        'q': q,
        'n': n,
        'v': {for (final e in v.entries) if (e.value != 0) e.key: _fr(e.value)},
        if (biz.isNotEmpty) 'b': {for (final e in biz.entries) e.key: e.value.toJson()},
      };
  factory FinRec.fromJson(Map<String, dynamic> j) => FinRec(
        (j['y'] as num).round(),
        (j['q'] as num).round(),
        (j['n'] as num? ?? 1).round(),
        {for (final e in ((j['v'] as Map?) ?? {}).entries) e.key as String: (e.value as num).toDouble()},
        {for (final e in ((j['b'] as Map?) ?? {}).entries) e.key as String: FinBiz.fromJson((e.value as Map).cast<String, dynamic>())},
      );
}

/// 締めた記録の数は、円の整数に丸めて持つ（セーブを小さくする。数え中の積み上げは丸めない）
num _fr(double v) => !v.isFinite ? 0 : (v.abs() < 9e15 ? v.round() : v);

/// 月の記録を何か月分残すか（今年の各月と直近12か月を出せる分）
const finMonthsKeep = 24;

class FinBooks {
  /// 記録しているか（古いセーブは読み込んだ月から）
  bool on = false;

  /// 記録を始めた年と月
  int fy = 0, fq = 0;

  /// 純資産の内訳（資本金・利益剰余金・評価差額）
  double eCap = 0, eRe = 0, eRev = 0;

  /// 前の締め（月の終わり・入れ替え）のときの持ち物と借金（ar / pp / trap / eq / land / inv / debt）
  Map<String, double> base = {};

  /// 今月の積み上げ・前の締めからの積み上げ（純資産の計算用）・今年の締めた月の積み上げ
  Map<String, double> cur = {}, pend = {}, yAcc = {};

  /// 今年の事業ごとの損益（締めた月の分）・今月の事業ごとの損益
  Map<String, FinBiz> yBiz = {}, mBiz = {};

  /// 今年締めた月の数
  int yN = 0;

  /// 締めた月（直近 [finMonthsKeep] か月）と年（全部）
  List<FinRec> months = [], years = [];

  FinBooks();

  /// 現金の動きを種類ごとに足す（現金の setter から）
  void flow(String tag, double d) {
    if (!on || d == 0 || !d.isFinite) return;
    final k = tag == 'sp' ? (d >= 0 ? 'c:sp+' : 'c:sp-') : 'c:$tag';
    add(k, d);
  }

  /// 今月の積み上げと、前の締めからの積み上げの両方に足す
  void add(String k, double v) {
    if (!on || v == 0 || !v.isFinite) return;
    cur[k] = (cur[k] ?? 0) + v;
    pend[k] = (pend[k] ?? 0) + v;
  }

  /// 現金の種類を付け替える（月の締めで、本業の入りから利息と税を分ける）
  void move(String from, String to, double v) {
    add('c:$from', -v);
    add('c:$to', v);
  }

  Map<String, dynamic> toJson() => {
        'on': on,
        'fy': fy,
        'fq': fq,
        'ec': eCap,
        'er': eRe,
        'ev': eRev,
        'base': base,
        'cur': cur,
        'pend': pend,
        'ya': yAcc,
        'yb': {for (final e in yBiz.entries) e.key: e.value.toJson()},
        'mb': {for (final e in mBiz.entries) e.key: e.value.toJson()},
        'yn': yN,
        'm': [for (final r in months) r.toJson()],
        'y': [for (final r in years) r.toJson()],
      };

  static Map<String, double> _md(Object? o) => {for (final e in ((o as Map?) ?? {}).entries) e.key as String: (e.value as num).toDouble()};
  static Map<String, FinBiz> _mb(Object? o) => {for (final e in ((o as Map?) ?? {}).entries) e.key as String: FinBiz.fromJson((e.value as Map).cast<String, dynamic>())};

  factory FinBooks.fromJson(Map<String, dynamic>? j) {
    final b = FinBooks();
    if (j == null) return b;
    double d(String k) => (j[k] as num? ?? 0).toDouble();
    return b
      ..on = j['on'] == true
      ..fy = (j['fy'] as num? ?? 0).round()
      ..fq = (j['fq'] as num? ?? 0).round()
      ..eCap = d('ec')
      ..eRe = d('er')
      ..eRev = d('ev')
      ..base = _md(j['base'])
      ..cur = _md(j['cur'])
      ..pend = _md(j['pend'])
      ..yAcc = _md(j['ya'])
      ..yBiz = _mb(j['yb'])
      ..mBiz = _mb(j['mb'])
      ..yN = (j['yn'] as num? ?? 0).round()
      ..months = [for (final e in (j['m'] as List? ?? [])) FinRec.fromJson((e as Map).cast<String, dynamic>())]
      ..years = [for (final e in (j['y'] as List? ?? [])) FinRec.fromJson((e as Map).cast<String, dynamic>())];
  }
}

// ===== 決算書の数え方（記録の積み上げから） =====
/// 記録の値（無ければ 0）
double fv(Map<String, double> v, String k) => v[k] ?? 0;

/// 販売費及び一般管理費（減価償却を含む）
double finSga(Map<String, double> v) =>
    fv(v, 'labor') +
    fv(v, 'rent') +
    fv(v, 'util') +
    fv(v, 'logi') +
    fv(v, 'ad') +
    fv(v, 'insur') +
    fv(v, 'repair') +
    fv(v, 'hq') +
    fv(v, 'subc') +
    fv(v, 'oth') -
    fv(v, 'c:grow') -
    fv(v, 'c:misc') +
    fv(v, 'dep');

/// 売上総利益（粗利）
double finGross(Map<String, double> v) => fv(v, 'rev') - fv(v, 'cogs');

/// 営業利益
double finOpInc(Map<String, double> v) => finGross(v) - finSga(v);

/// 営業外の損益（子会社からの配当・使用料など−支払利息）
double finNonOp(Map<String, double> v) => fv(v, 'c:div') + fv(v, 'c:nonop') - fv(v, 'intr');

/// 経常利益
double finOrd(Map<String, double> v) => finOpInc(v) + finNonOp(v);

/// 特別利益（事業の売却・借金の減免・そのほか）
double finSpGain(Map<String, double> v) => fv(v, 'c:bizSale') + math.max(0.0, fv(v, 'debtG')) + fv(v, 'c:sp+') + math.max(0.0, fv(v, 'c:unc'));

/// 特別損失（のれんの減損・罰金や災害など。正の数）
double finSpLoss(Map<String, double> v) => fv(v, 'gwImp') - fv(v, 'c:sp-') - math.min(0.0, fv(v, 'debtG')) - math.min(0.0, fv(v, 'c:unc'));

/// 税引前当期純利益
double finPretax(Map<String, double> v) => finOrd(v) + finSpGain(v) - finSpLoss(v);

/// 当期純利益
double finNi(Map<String, double> v) => finPretax(v) - fv(v, 'tax');

/// キャッシュフローの3つ（営業・投資・財務）と、会社の入れ替えの分
double finCfSum(Map<String, double> v, List<String> ks) => ks.fold(0.0, (s, k) => s + fv(v, 'c:$k'));
double finCfOpSum(Map<String, double> v) => finCfSum(v, finCfOp);
double finCfInvSum(Map<String, double> v) => finCfSum(v, finCfInv);
double finCfFinSum(Map<String, double> v) => finCfSum(v, finCfFin);
double finCfAll(Map<String, double> v) => finCfOpSum(v) + finCfInvSum(v) + finCfFinSum(v) + fv(v, 'c:reset');

/// 貸借対照表の合計
double finAssets(Map<String, double> v) => ['cash', 'ar', 'pp', 'trap', 'eq', 'land', 'stk', 'sub'].fold(0.0, (s, k) => s + fv(v, 'b:$k'));
double finLiabs(Map<String, double> v) => fv(v, 'b:loan') + fv(v, 'b:bond');
double finEquity(Map<String, double> v) => fv(v, 'b:cap') + fv(v, 'b:re') + fv(v, 'b:rev');

extension GameFin on Game {
  /// 今の持ち物と借金（決算書の貸借対照表の元）
  Map<String, double> finStocks() {
    var stk = 0.0, sub = 0.0, gw = 0.0;
    for (final c in cos) {
      if (!c.alive) continue;
      final p = pctOf(c);
      if (p <= 0) continue;
      final v = math.max(0.0, c.cap) * p / 100;
      if (c.parent == 'player') {
        sub += v;
        gw += c.fin?.gw ?? 0;
      } else {
        stk += v;
      }
    }
    return {
      'cash': cash,
      'ar': ar,
      'pp': corp.tightAmt,
      'trap': trade.trapped.values.fold(0.0, (s, x) => s + x),
      'eq': lf.deps.fold(0.0, (s, d) => s + d.m * d.left),
      'land': land,
      'stk': stk,
      'sub': sub,
      'gw': math.min(gw, sub),
      'loan': debt - bond,
      'bond': bond,
    };
  }

  double _finE(Map<String, double> st) =>
      st['cash']! + st['ar']! + st['pp']! + st['trap']! + st['eq']! + st['land']! + st['stk']! + st['sub']! - st['loan']! - st['bond']!;

  Map<String, double> _finBase(Map<String, double> st) => {
        'ar': st['ar']!,
        'pp': st['pp']!,
        'trap': st['trap']!,
        'eq': st['eq']!,
        'land': st['land']!,
        'inv': st['stk']! + st['sub']!,
        'debt': st['loan']! + st['bond']!,
      };

  /// 記録を始める（はじめの月・古いセーブを読んだ月）。今の純資産を資本金とする
  void finStart() {
    final f = books;
    final st = finStocks();
    f
      ..on = true
      ..fy = year
      ..fq = q
      ..eCap = _finE(st)
      ..eRe = 0
      ..eRev = 0
      ..base = _finBase(st)
      ..cur = {}
      ..pend = {}
      // 年のはじめ（記録を始めたとき）の現金。キャッシュフローの「期首の現金」
      ..yAcc = {'b0:cash': cash}
      ..yBiz = {}
      ..mBiz = {}
      ..yN = 0
      ..months = []
      ..years = [];
  }

  /// 現金を種類つきで動かす（cash += d と同じ計算）
  void cfAdd(String tag, double d) {
    cfTag = tag;
    cash += d;
  }

  /// 前の締めから今までの持ち物の動きを締めて、純資産に入れる（月の終わりと、会社の入れ替えの前）
  void finCut() {
    final f = books;
    if (!f.on) return;
    final st = finStocks();
    final p = f.pend;
    double g(String k) => p[k] ?? 0;
    final b = f.base;
    final inv1 = st['stk']! + st['sub']!, debt1 = st['loan']! + st['bond']!;
    // 設備: 払った額で増え、それを除いた減りが減価償却（資産が無い仕組みのときは、払った額がそのまま償却になる）
    final dep = (b['eq'] ?? 0) - g('c:capex') - st['eq']!;
    // 土地・株: 払った・受け取った額と、借りて買った土地・のれんの減損で説明できない増減が評価差額
    final revL = st['land']! - (b['land'] ?? 0) + g('c:land') - g('landNC');
    final revI = inv1 - (b['inv'] ?? 0) + g('c:stock') + g('gwImp');
    // 借金: 借りた・返した額で説明できない減りが借金の減免
    final debtG = (b['debt'] ?? 0) + g('c:borrow') + g('c:repay') + g('landNC') - debt1;
    f.add('dep', dep);
    f.add('revL', revL);
    f.add('revI', revI);
    f.add('debtG', debtG);
    final ni = finNi(p);
    f.eCap += g('c:equity');
    f.eRe += ni + g('c:payout');
    f.eRev += revL + revI;
    f.base = _finBase(st);
    f.pend = {};
  }

  /// 会社を売った・倒産して始め直したあと：変わった分を「入れ替え」として資本金に入れ、持ち物の基準を今に合わせる
  void finRebase() {
    final f = books;
    if (!f.on) return;
    final st = finStocks();
    final jump = _finE(st) - (f.eCap + f.eRe + f.eRev);
    f.eCap += jump;
    f.cur['rst'] = (f.cur['rst'] ?? 0) + jump;
    f.base = _finBase(st);
    f.pend = {};
  }

  /// 月のお金の計算（nextQuarter）で、損益の内訳と事業ごとの損益を写す。[p0] はその月の税引前の利益（利息を引いたあと）
  void finPl(double p0) {
    final f = books;
    if (!f.on) return;
    final ex = expenses();
    final sb = subs();
    final subsRev = sb.fold(0.0, (s, c) => s + c.rev * pctOf(c) / 100);
    final v = <String, double>{
      'rev': rev,
      'cogs': ex['cogs']!,
      'labor': ex['labor']!,
      'rent': ex['rent']!,
      'util': ex['util']!,
      'logi': ex['logi']!,
      'ad': ex['ad']!,
      'insur': ex['insur']!,
      'repair': ex['repair']!,
      'hq': hq,
      'subc': subsRev - subP,
      'intr': interest,
    };
    // 関税・輸送・現地の手間・設備の古びの修繕・IT など、上の区分に入らない事業の費用（売上−利益−上の区分の残り）
    final known = finPlKeys.where((k) => k != 'rev' && k != 'oth' && k != 'intr' && k != 'tax').fold(0.0, (s, k) => s + (v[k] ?? 0));
    v['oth'] = rev - p0 - interest - known;
    for (final e in v.entries) {
      f.add(e.key, e.value);
    }
    // 事業ごと（自社の事業・子会社・現地法人）
    for (final b in biz) {
      final x = fixOf[b.id];
      final labor = b.upkeep + (unitsOn ? b.sv * svPayOne(b) : 0) + (tradeOn ? trade.labor[b.id] ?? 0 : 0);
      final cogs = cogsOf[b.id] ?? math.max(0.0, b.rev - b.profit - b.upkeep);
      final rent = x == null ? 0.0 : x[0];
      final fixO = x == null ? 0.0 : x[1] + x[2] + x[3] + x[4];
      final ad = b.ad > 0 ? b.adCost : 0.0;
      final oth = b.rev - b.profit - cogs - labor - rent - fixO - ad;
      final r = f.mBiz['b${b.id}'] ??= FinBiz(b.ind);
      final add = [b.rev, cogs, labor, rent, ad, fixO, oth, b.profit];
      for (var i = 0; i < finBizCols; i++) {
        r.v[i] += add[i];
      }
    }
    for (final c in sb) {
      final k = pctOf(c) / 100;
      final r = f.mBiz['s${c.id}'] ??= FinBiz(c.biz.isEmpty ? '' : c.biz.first.ind, co: c.name, loc: c.loc);
      final rv = c.rev * k, pr = c.profit * k;
      r.v[0] += rv;
      r.v[6] += rv - pr;
      r.v[7] += pr;
    }
  }

  /// 月の終わりの締め（nextQuarter の最後）。[y] [m] は締めた月
  void finClose(int y, int m) {
    final f = books;
    if (!f.on) return;
    finCut();
    final st = finStocks();
    final v = Map<String, double>.of(f.cur);
    for (final e in st.entries) {
      v['b:${e.key}'] = e.value;
    }
    v['b:cap'] = f.eCap;
    v['b:re'] = f.eRe;
    v['b:rev'] = f.eRev;
    v['b:gap'] = _finE(st) - (f.eCap + f.eRe + f.eRev);
    v['b:mcap'] = cap;
    final rec = FinRec(y, m, 1, {for (final e in v.entries) e.key: _fr(e.value).toDouble()}, {for (final e in f.mBiz.entries) e.key: FinBiz.fromJson(e.value.toJson())});
    f.months.add(rec);
    if (f.months.length > finMonthsKeep) f.months.removeRange(0, f.months.length - finMonthsKeep);
    // 今年の積み上げ（流れは足し、持ち物は月の終わりの値に置き換える）
    for (final e in f.cur.entries) {
      f.yAcc[e.key] = (f.yAcc[e.key] ?? 0) + e.value;
    }
    for (final e in v.entries) {
      if (e.key.startsWith('b:')) f.yAcc[e.key] = e.value;
    }
    for (final e in f.mBiz.entries) {
      final r = f.yBiz[e.key] ??= FinBiz(e.value.ind, co: e.value.co, loc: e.value.loc);
      for (var i = 0; i < finBizCols; i++) {
        r.v[i] += e.value.v[i];
      }
    }
    f.yN++;
    f.cur = {};
    f.mBiz = {};
    if (m == 12) {
      f.years.add(FinRec(y, 0, f.yN, {for (final e in f.yAcc.entries) e.key: _fr(e.value).toDouble()},
          {for (final e in f.yBiz.entries) e.key: FinBiz(e.value.ind, co: e.value.co, loc: e.value.loc, v: [for (final x in e.value.v) _fr(x).toDouble()])}));
      f.yAcc = {'b0:cash': st['cash']!};
      f.yBiz = {};
      f.yN = 0;
    }
  }

  /// 今年（締めた月の分）の記録。まだ締めた月が無ければ null
  FinRec? finThisYear() {
    final f = books;
    if (f.yN == 0) return null;
    final y = f.months.isNotEmpty ? f.months.last.y : year;
    return FinRec(y, 0, f.yN, Map.of(f.yAcc), {for (final e in f.yBiz.entries) e.key: e.value});
  }

  /// [y] 年の記録（締めた年か、今年の途中）。無ければ null
  FinRec? finYear(int y) {
    for (final r in books.years) {
      if (r.y == y) return r;
    }
    final t = finThisYear();
    return t != null && t.y == y ? t : null;
  }

  /// 決算書を見られる年（古い順。今年の途中を含む）
  List<int> finYears() => [for (final r in books.years) r.y, if (finThisYear() case final t?) t.y];
}
