// ignore_for_file: non_constant_identifier_names, constant_identifier_names
/// ゲームの仕組み（試作 prototype.html の `<script id="logic">` を写したもの）。
/// Flutter に依存しない。乱数は注入した [Random] だけを使う。
library;

import 'dart:math' as math;

import '../l10n/l10n.dart';
import 'data.dart';
import 'format.dart';
import 'models.dart';
import 'models_static.dart';

export '../l10n/l10n.dart';
export 'data.dart';
export 'format.dart';
export 'models.dart';
export 'models_static.dart';

part 'game_turn.dart';
part 'game_actions.dart';
part 'game_view.dart';
part 'game_story.dart';

// ===== データ =====
const double invEff = .9, newPow = 1.5, cpuReinv = .12;
const List<double> oths = [.5, .7, .85];
const Set<String> techCats = {'net', 'fut'};
final Map<String, Industry> indm = {for (final i in IND) i.id: i};
final Map<String, Country> cm = {for (final x in CTRY) x.c: x};
const Set<String> eastPools = {'zh', 'ko', 'vi'};

/// 社史に残す世界ランキングの節目（小さい順。一度に越えたら一番上の節目だけ残す）
const List<int> rankMarks = [1, 3, 10, 50, 100, 200, 500];

/// JS の sort と同じく、同じ値の並びを崩さない並べ替え
extension StableSort<T> on List<T> {
  void ssort(int Function(T a, T b) cmp) {
    final copy = toList();
    final idx = List<int>.generate(length, (i) => i);
    idx.sort((x, y) {
      final c = cmp(copy[x], copy[y]);
      return c != 0 ? c : x - y;
    });
    for (var i = 0; i < length; i++) {
      this[i] = copy[idx[i]];
    }
  }
}

double clampD(double v, double a, double b) => math.max(a, math.min(b, v));
int clampI(int v, int a, int b) => math.max(a, math.min(b, v));
double nomOf(double y) => math.pow(1.015, y - 2020).toDouble();

List<double> regFor(double y) => [1, 3 + 3 * clampD((y - 1990) / 35, 0, 1), 10 + 15 * clampD((y - 1995) / 30, 0, 1)];

double eraF(Industry ind, double y) {
  if (y < ind.b) return 0;
  final x = (y - ind.b) / math.max(1, ind.p - ind.b);
  var f = x >= 1 ? 1.0 : .06 + .94 * (x * x * (3 - 2 * x));
  if (ind.f != 0 && y > ind.f) {
    final d = math.min(1.0, (y - ind.f) / 15);
    f *= 1 - .7 * d;
  }
  return f;
}

/// 国の市場の大きさ（日本を1とした比べの元）
double cw(String c, double y) {
  final C = cm[c]!;
  return C.a + (C.b - C.a) / (1 + math.exp(-(y - C.m) / C.k));
}

/// 難しさ（ふつうは試作と同じ数字）。g は宿敵と CPU の会社の伸び、r は利益の再投資、t は宿敵が株を買い進める確率にかける
class Difficulty {
  final String id, nJa, dJa;
  final double g, r, t;
  const Difficulty(this.id, this.nJa, this.dJa, this.g, this.r, this.t);
  String get n => de(nJa);
  String get d => de(dJa);
}

const List<Difficulty> DIFFS = [
  Difficulty('easy', 'やさしい', 'ライバルの伸びがゆるやか。乗っ取られにくい', .5, .5, .5),
  Difficulty('normal', 'ふつう', 'ふつうの手ごたえ', 1, 1, 1),
  Difficulty('hard', 'むずかしい', 'ライバルがよく伸び、株を狙ってくる', 1.5, 1.6, 1.8),
];
Difficulty diffOf(String id) => DIFFS.firstWhere((d) => d.id == id, orElse: () => DIFFS[1]);

/// はじめるときの選択
class SetupConfig {
  String mode;
  int year;
  List<String> traits;
  String home;
  String? name;
  String diff;
  SetupConfig({this.mode = 'world', this.year = 1980, List<String>? traits, this.home = 'jp', this.name, this.diff = 'normal'}) : traits = traits ?? [];
}

/// 世界の企業ランキングの1行
class RankRow {
  final String name;
  final double cap;
  final bool me;
  final Company? c;
  RankRow(this.name, this.cap, {this.me = false, this.c});
}

/// 経営会議の提案
class Proposal {
  String k;
  int w;
  double cost;
  String l, d;
  String? ind;
  int by = 0, bid = 0;
  Proposal({required this.k, required this.w, required this.cost, required this.l, required this.d});
  Proposal copy() => Proposal(k: k, w: w, cost: cost, l: l, d: d)
    ..ind = ind
    ..by = by
    ..bid = bid;
}

class Game {
  math.Random rng;
  Game(this.rng);

  // ===== 乱数の小道具 =====
  double rnd() => rng.nextDouble();
  int ri(int a, int b) => a + (rnd() * (b - a + 1)).floor();
  T pick<T>(List<T> a) => a[(rnd() * a.length).floor()];

  /// 空のときは null（試作の pick は undefined を返していた）
  T? pickOr<T>(List<T> a) {
    final i = (rnd() * a.length).floor();
    return a.isEmpty ? null : a[i];
  }

  /// 並べ替えを乱数で決める（後ろから入れ替える。試作の sort(()=>R()-.5) の代わり）
  void shuffle<T>(List<T> a) {
    for (var i = a.length - 1; i > 0; i--) {
      final j = (rnd() * (i + 1)).floor();
      final t = a[i];
      a[i] = a[j];
      a[j] = t;
    }
  }

  // ===== 状態（試作の S） =====
  int uidCounter = 1;
  int uid() => uidCounter++;
  List<double> reg = [1, 3, 10];
  Map<String, double> indM = {};
  Map<String, List<double>>? lastT;

  String mode = 'world';

  /// 難しさ（easy / normal / hard）。古いセーブはふつう
  String diff = 'normal';
  Difficulty get dif => diffOf(diff);
  int startYear = 1980, year = 1980, q = 1;
  double cash = 0, debt = 0;
  bool listed = false;
  int region = 0;
  Shares sh = Shares();
  List<Biz> biz = [];
  List<Person> staff = [], cands = [], kids = [];
  Map<String, int> found = {}, big = {};
  List<LogEntry> log = [];
  List<HistEntry> hist = [];
  List<Company> cos = [];
  double econ = 1, perMul = 1, techBoom = 1;
  int ap = 3, apMax = 3;
  String? over, won;
  int turn = 0;
  List<GameEvent> events = [];
  List<Cycle> cycles = [];
  Map<String, int> reported = {};
  int scandal = 0;
  int? succ;
  List<LogEntry> lastNews = [];
  int peakRank = 999, rank = 0;
  String home = 'jp';
  late President pres;
  int net = 0;
  Map<String, int> seen = {}, hint = {};
  Person? meet;
  String culture = 'merit';
  String? cultNext;
  int cultLeft = 0;
  double pre = 0, interest = 0, hq = 0, subP = 0, rev = 0, cap = 1, g = 0, lastTax = 0;
  double wealth = 0, land = 0, bond = 0;
  int bondDue = 0;
  bool holding = false;
  int cooked = 0, dirty = 0, rep = 0, rest = 0, gen = 1, serial = 0;
  int? lastOffer;
  int vcDeadline = 0;
  bool everBiz = false, ruDone = false;
  List<int> buried = [];
  List<Suit> suits = [];
  List<Return> ret = [];
  List<Deal> deals = [];
  Tie? tie;
  Noncomp? noncomp;

  /// 初めて遊ぶ人への案内の進み（仕組みの数字には使わない）。'start' があれば案内を出す
  Map<String, int> guide = {};

  /// 試作のあとに足した仕組み（取締役会・宿敵の物語）を動かすか。ふだんは有効。
  /// 試作との一致テストでは切る（切ると乱数の使い方も試作と同じになる）。保存しない
  bool extras = true;

  /// 使う業種・シナジー・大シナジー。extras を切ると試作にある分だけ（112業種）
  List<Industry> get inds => extras ? IND : IND_BASE;
  List<Synergy> get syns => extras ? SYN : SYN_BASE;
  List<BigSynergy> get bigs => extras ? BIG : BIG_BASE;

  /// 古いセーブを読んだとき、まだ CPU の会社がいない足した業種（次の月に知らせなしで会社を置く）
  Set<String> lateInds = {};

  /// 取締役会: 今年の売上・利益の積み上げ（rev / pre / n）、去年の振り返り（rev / pre / cap / rank）
  Map<String, double> yAcc = {};
  Map<String, double>? yPrev;

  /// 取締役会との改革の約束（due: 期限の月 / target: 戻す年の利益 / y: 期限の年）
  Map<String, double>? vow;

  /// 社史（古い順に積む。乱数は使わず、記録だけ足す）
  List<Chron> history = [];

  /// これまでの時価総額と財産の最大（終わったときのまとめに使う）
  double maxCap = 0, maxWealth = 0;

  /// 社史に1行足す（乱数を使わない）
  void chron(String k, String m) {
    history.add(Chron(year, q, k, m));
    if (history.length > 400) history.removeAt(0);
  }

  /// 時価総額・財産の最大を更新する
  void trackPeaks() {
    if (cap > maxCap) maxCap = cap;
    if (wealth > maxWealth) maxWealth = wealth;
  }

  double yr() => year + (q - 1) / 12;
  double nom() => nomOf(yr());
  bool hasT(String id) => pres.traits.contains(id);

  // ===== 名前 =====
  String homePool() => NAMEC[home] ?? 'jp';
  String nm() {
    final k = homePool();
    if (k == 'jp' || rnd() < .12) return '${pick(SEI)} ${pick(MEI)}';
    if (eastPools.contains(k)) return '${pick(NAMEP[k]![0])} ${pick(NAMEP[k]![1])}';
    return '${pick(NAMEP[k]![1])}・${pick(NAMEP[k]![0])}';
  }

  static String famOf(String n) => n.contains('・') ? n.split('・').last : n.split(' ')[0];
  static String givenOf(String n) {
    if (n.contains('・')) return n.split('・')[0];
    final p = n.split(' ');
    return p.length > 1 && p[1].isNotEmpty ? p[1] : n;
  }

  String given() {
    final k = homePool();
    return k == 'jp' ? pick(MEI) : pick(NAMEP[k]![1]);
  }

  String kidName(String n) => n.contains('・') ? '${given()}・${famOf(n)}' : '${famOf(n)} ${given()}';
  String heirName(String n, String k) {
    if (n.contains('・')) return '${pick(NAMEP[k == 'volkova' ? 'ru' : 'en']![1])}・${famOf(n)}';
    return '${famOf(n)} ${k == 'li' ? pick(NAMEP['zh']![1]) : pick(MEI)}';
  }

  // ===== 市場 =====
  double econFor(Industry ind) => 1 + (econ - 1) * ind.sens;
  double mkt(Industry ind) {
    final y = yr();
    return ind.size / 4 * eraF(ind, y) * nomOf(y) * econFor(ind) * (ind.cat == 'net' || ind.cat == 'fut' ? techBoom : 1);
  }

  double capexOf(Industry ind) {
    var c = ind.capex * nom();
    if (hasT('careful') && yr() - ind.b < 10) c *= 1.5;
    return c;
  }

  List<Industry> liveInds() => inds.where((i) => eraF(i, yr()) > 0).toList();

  // ===== 人 =====
  Person mkPerson([double qq = 0]) {
    int base() => clampI(jsRound(30 + rnd() * 45 + qq * 10 + (rnd() - .5) * 20).toInt(), 5, 99);
    final id = uid();
    final name = nm();
    final age = ri(24, 48);
    final ab = <String, int>{'tou': base(), 'kai': base(), 'ei': base(), 'zai': base()};
    final trait = pick(STRAITS).id;
    final amb = ri(10, 95);
    final loy = ri(20, 90).toDouble();
    final p = Person(id: id, name: name, age: age, ab: ab, trait: trait, amb: amb, loy: loy);
    if (p.trait == 'tech') {
      p.ab['kai'] = clampI(p.ab['kai']! + 25, 5, 99);
      p.ab['ei'] = clampI(p.ab['ei']! - 20, 5, 99);
    }
    if (p.trait == 'grit') p.ab['zai'] = clampI(p.ab['zai']! - 15, 5, 99);
    final t = totOf(p);
    p.salary = jsRound((4e6 + t * t * 90) * nom() / 12) * (p.trait == 'grit' || p.trait == 'liar' ? .75 : 1);
    p.w = hasT('charm') ? 12 : 26;
    for (final k in abKeys) {
      p.off[k] = rnd();
    }
    p.traitKnown = hasT('charm');
    p.ambKnown = false;
    return p;
  }

  static int totOf(Person p) => p.ab['tou']! + p.ab['kai']! + p.ab['ei']! + p.ab['zai']!;

  List<int> rangeOf(Person p, String k) {
    final w = math.max(0, p.w - p.tenure * 2);
    if (w <= 0) return [p.ab[k]!, p.ab[k]!];
    var lo = jsRound(p.ab[k]! - w * (p.off[k] ?? 0)).toInt();
    lo = clampI(lo, 1, 99);
    return [lo, clampI(lo + w, 1, 99)];
  }

  String showAb(Person p, String k) {
    final r = rangeOf(p, k);
    return r[0] == r[1] ? '${r[0]}' : '${r[0]}${L.en ? '-' : '〜'}${r[1]}';
  }

  // ===== 会社（CPU） =====
  String coName(int tier, String cat) {
    if (tier == 2) return '${pick(CO_F)}・${CO_FSUF[cat]}';
    if (tier == 1) return '${pick(CO_C)}${CO_SUF[cat]}';
    return '${pick(CO_A)}${CO_SUF[cat]}';
  }

  Company mkCo(int tier, String cat, {String? name, String? presName, Rival? rival, double? fam}) {
    final used = cos.map((c) => c.name).toSet();
    var n = '';
    for (var i = 0; i < 20; i++) {
      n = coName(tier, cat);
      if (!used.contains(n)) break;
    }
    final f = fam ?? ri(20, 45).toDouble();
    final eff = .8 + rnd() * .4;
    final gg = .004 + rnd() * .006;
    final pn = presName ?? nm();
    final pa = ri(40, 66).toDouble();
    final c = Company(
        id: uid(), name: name ?? n, cat: cat, tier: tier, fam: f, eff: eff, g: gg, presName: pn, presAge: pa, rival: rival, founded: year);
    cos.add(c);
    return c;
  }

  static Rival rivalOf(RivalDef r) => Rival(k: r.k, pres: r.pres, co: r.co, type: r.type, label: r.label, tier: r.tier, col: r.col);

  // ===== はじめる =====
  static Game newGame(SetupConfig cfg, {math.Random? rng, bool extras = true}) {
    final s = Game(rng ?? math.Random())..extras = extras;
    s._init(cfg);
    return s;
  }

  void _init(SetupConfig cfg) {
    uidCounter = 1;
    mode = cfg.mode;
    diff = cfg.diff;
    startYear = cfg.year;
    year = cfg.year;
    q = 1;
    reg = regFor(cfg.year.toDouble());
    home = cfg.home;
    pres = President(name: 'x', age: 22, traits: cfg.traits.toList(), ab: {});
    pres.name = cfg.name ?? nm();
    pres.ab = {'tou': ri(35, 55), 'kai': ri(35, 55), 'ei': ri(35, 55), 'zai': ri(35, 55)};
    net = 0;
    seen = {};
    hint = {};
    meet = null;
    culture = hasT('oneman')
        ? 'sports'
        : hasT('careful')
            ? 'steady'
            : hasT('charm')
                ? 'family'
                : hasT('genius')
                    ? 'free'
                    : 'merit';
    if (hasT('tech')) {
      pres.ab['kai'] = pres.ab['kai']! + 25;
      pres.ab['ei'] = pres.ab['ei']! - 10;
      pres.ab['zai'] = pres.ab['zai']! - 10;
    }
    cash = 4e7 * nomOf(cfg.year.toDouble()) * (hasT('noble') ? 4 : 1);
    // 時代の大事件（史実をもとにぶれる）
    int j(int a) => a + ri(-2, 2);
    double m() => .6 + rnd() * .8;
    void add(String name, int s, int e, double ec, double per, double tech, String news) {
      // 名前と知らせは「鍵と引数」で持つ（見せるときに言語を選ぶ）
      var nw = M(news);
      if (home != 'jp' && RegExp('バブル景気|バブル崩壊').hasMatch(name)) {
        ec = 1 + (ec - 1) * .3;
        per = 1 + (per - 1) * .3;
        nw = M('日本の{0}', [nw]);
      }
      if (e >= cfg.year) cycles.add(Cycle(name: M(name), s: s, e: e, econ: ec, per: per, tech: tech, news: nw, shown: s < cfg.year));
    }

    final b0 = j(1986);
    add('バブル景気', b0, b0 + ri(3, 5), 1 + .25 * m(), 1 + .9 * m(), 1, '土地と株が上がり続けています。銀行がいくらでも貸してくれる時代です');
    final bc = b0 + ri(4, 6);
    add('バブル崩壊', bc, bc + ri(3, 6), 1 - .2 * m(), 1 - .35 * m(), 1, '株と土地の値段が崩れ始めました。借金の多い会社から倒れていきます');
    final n0 = j(1996);
    add('インターネットの到来', n0, n0 + ri(3, 5), 1, 1 + .3 * m(), 1 + .6 * m(), 'ネットの会社に投資家のお金が殺到しています');
    final nc = n0 + ri(4, 5);
    add('ネットバブル崩壊', nc, nc + ri(1, 3), .95, 1 - .25 * m(), 1 - .3 * m(), 'ネットの会社の株が暴落しています');
    final fc = j(2008);
    add('世界金融危機', fc, fc + ri(1, 3), 1 - .2 * m(), 1 - .35 * m(), .9, '世界中で銀行が傾き、株が暴落しています');
    final sm = j(2009);
    add('スマホの時代', sm, sm + ri(5, 8), 1, 1.05, 1 + .25 * m(), 'スマホが一気に広まり、アプリの会社が急成長しています');
    final ai = j(2023);
    add('AIブーム', ai, ai + ri(4, 8), 1.03, 1 + .3 * m(), 1 + .5 * m(), 'AIに世界中のお金が集まっています');
    final fu = j(2034);
    add('未来の不況', fu, fu + ri(2, 3), 1 - .15 * m(), 1 - .3 * m(), .9, '景気が急に冷え込みました');
    // CPU の会社をつくる
    final live = liveInds();
    for (final ind in live) {
      for (var t = 0; t < 3; t++) {
        final n = t == 0 ? ri(2, 4) : ri(1, 3);
        for (var k = 0; k < n; k++) {
          final pool = cos.where((c) => c.tier == t && c.cat == ind.cat && c.rival == null && !c.biz.any((b) => b.ind == ind.id) && c.biz.length < 4).toList();
          final c = pool.isNotEmpty && rnd() < .35 ? pick(pool) : mkCo(t, ind.cat);
          c.biz.add(CoBiz(ind: ind.id, power: 0, w: .3 + rnd() * 1.7));
        }
      }
    }
    final picked = [...RIVALS];
    shuffle(picked);
    for (final r in picked.take(4)) {
      final isBig = r.type == 'zaibatsu' || r.type == 'state';
      final fam = (isBig ? ri(40, 55) : ri(25, 40)).toDouble();
      final c = mkCo(r.tier, 'link', name: r.co, presName: r.pres, rival: rivalOf(r), fam: fam);
      c.presAge = (r.type == 'genius'
              ? ri(22, 28)
              : r.type == 'peer'
                  ? pres.age
                  : ri(45, 62))
          .toDouble();
      c.g = r.type == 'genius'
          ? .03
          : r.type == 'peer'
              ? .015
              : r.type == 'state'
                  ? .012
                  : r.type == 'zaibatsu'
                      ? .008
                      : .006;
      final n = isBig
          ? ri(4, 6)
          : r.type == 'fund'
              ? ri(2, 4)
              : 1;
      final pool = r.type == 'genius' ? live.where((i) => i.capex * nom() < 2e8).toList() : live;
      final ss = <String>{};
      while (ss.length < n) {
        ss.add(pick(pool).id);
      }
      for (final id in ss) {
        c.biz.add(CoBiz(
            ind: id,
            power: 0,
            w: isBig
                ? 4 + rnd() * 4
                : r.type == 'fund'
                    ? 2
                    : .15));
      }
    }
    // 各業種の力を市場の大きさに合わせる
    indM = {for (final i in inds) i.id: 0};
    normalizeAll(true);
    for (var i = 0; i < 3; i++) {
      cands.add(mkPerson(0));
    }
    hist = [];
    reg = regFor(yr());
    calcAll();
    log.add(LogEntry(M('{0}年、{1}は{2}会社を立ち上げた。手元の資金は{3}。', [year, Nm(pres.name), M(hasT('noble') ? '親の援助を受けて' : 'わずかな元手で'), Y(cash)]), 'big'));
    history = [];
    chron('found', M('{0}（{1}歳）が{2}で会社を立ち上げた。元手は{3}', [Nm(pres.name), pres.age, C(home), Y(cash)]));
    trackPeaks();
  }

  void normalizeAll(bool init) {
    for (final ind in inds) {
      final M = mkt(ind);
      if (M <= 0) continue;
      for (var t = 0; t < 3; t++) {
        final list = <CoBiz>[];
        for (final c in cos) {
          if (c.alive && c.tier == t) {
            for (final b in c.biz) {
              if (b.ind == ind.id) list.add(b);
            }
          }
        }
        final want = M * (reg[t] - (t > 0 ? reg[t - 1] : 0)) * (1 - othOf(ind)[t]);
        final sum = list.fold(0.0, (s, b) => s + (b.power != 0 ? b.power : b.w));
        if (init) {
          for (final b in list) {
            b.power = want * b.w / math.max(sum, 1e-9);
          }
        }
      }
      indM[ind.id] = M;
    }
  }

  // ===== 力と売上 =====
  Map<String, double> synMult() {
    final own = <String>{for (final b in biz) b.ind};
    for (final c in subs()) {
      for (final b in c.biz) {
        own.add(b.ind);
      }
    }
    final m = <String, double>{};
    for (final s in syns) {
      if (own.contains(s.a) && own.contains(s.b)) {
        m[s.a] = (m[s.a] ?? 1) * 1.2;
        m[s.b] = (m[s.b] ?? 1) * 1.2;
      }
    }
    for (final g in bigs) {
      if (g.set.every(own.contains)) {
        for (final x in g.set) {
          m[x] = (m[x] ?? 1) * 1.4;
        }
      }
    }
    return m;
  }

  List<Company> subs() => cos.where((c) => c.alive && c.parent == 'player').toList();
  Person? staffById(int? id) {
    if (id == null) return null;
    for (final p in staff) {
      if (p.id == id) return p;
    }
    return null;
  }

  Company? coById(int? id) {
    if (id == null) return null;
    for (final c in cos) {
      if (c.id == id) return c;
    }
    return null;
  }

  int presCap() => holding
      ? 99
      : hasT('oneman')
          ? 3
          : 2;

  double mgrMult(Biz b) {
    final ind = indm[b.ind]!;
    if (b.mgr != null) {
      final p = staffById(b.mgr);
      if (p != null) {
        var m = .7 + p.ab[ind.key]! / 100 * .8;
        if (p.partner) m *= 1.15;
        if (p.trait == 'oneman') m *= 1.25;
        if (p.trait == 'charm') m *= 1.1;
        if (hasT('oneman')) m *= .85;
        return m;
      }
    }
    final self = biz.where((x) => x.mgr == null).toList().indexOf(b);
    if (self >= 0 && self < presCap()) {
      var m = .8 + pres.ab[ind.key]! / 100 * .6;
      if (hasT('oneman')) m *= 1.35;
      return m;
    }
    return .6;
  }

  double crewOf(Biz b) => b.crew ?? b.power * 1.2;
  double crewEff(Biz b) {
    final p = staffById(b.mgr);
    final tou = p != null ? p.ab['tou']! : pres.ab['tou']!;
    return crewOf(b) *
        (.8 + tou / 250) *
        (b.model == 'fc' ? 3 : 1) *
        (culture == 'sports' ? 1.25 : 1) *
        (culture == 'sports' && hasT('oneman') ? 1.1 : 1);
  }

  double usedPow(Biz b) {
    final c = crewEff(b);
    return math.min(b.power, c) + math.max(0, b.power - c) * .2;
  }

  double effPow(Biz b, Map<String, double> sm) {
    var p = usedPow(b) * (sm[b.ind] ?? 1) * mgrMult(b);
    final pl = b.model == 'plat';
    final cat = indm[b.ind]!.cat;
    if (b.model == 'sub') p *= 1.25;
    if (b.price == 'cut') p *= pl ? 1.8 : 1.5;
    if (b.price == 'premium') p *= .75;
    if (b.ad > 0) p *= (hasT('frugal') ? 1.2 : 1.4) * (pl ? 1.2 : 1) * (culture == 'steady' ? .85 : 1);
    if (tie != null && tie!.cats.contains(cat)) p *= 1.08;
    if (hasDeal('sales', cat)) p *= 1.06;
    if (b.war > 0) p *= .85;
    return p;
  }

  List<double> othOf(Industry ind) => techCats.contains(ind.cat) ? const [.45, .55, .65] : oths;

  ({Map<String, List<double>> T, Map<String, double> sm}) totals() {
    final sm = synMult();
    final T = <String, List<double>>{};
    for (final ind in inds) {
      final M = mkt(ind), o = othOf(ind);
      T[ind.id] = [M * reg[0] * o[0], M * reg[1] * o[1], M * reg[2] * o[2]];
    }
    for (final c in cos) {
      if (!c.alive) continue;
      for (final b in c.biz) {
        final e = b.power * (c.parent == 'player' ? (sm[b.ind] ?? 1) : 1);
        for (var t = c.tier; t < 3; t++) {
          T[b.ind]![t] += e;
        }
      }
    }
    for (final b in biz) {
      final e = effPow(b, sm);
      for (var t = 0; t < 3; t++) {
        T[b.ind]![t] += e;
      }
    }
    return (T: T, sm: sm);
  }

  void calcAll() {
    final tt = totals();
    final T = tt.T, sm = tt.sm;
    lastT = T;
    final y = yr();
    for (final b in biz) {
      final ind = indm[b.ind]!;
      final r = reachOf(b), x = rEff(b);
      final M = mkt(ind) * r;
      final e = effPow(b, sm);
      final tot = poolT(b, T) * (r / x);
      b.share = tot > 0 ? e / tot : 0;
      b.rev = M * b.share / 3;
      var mg = ind.mg *
          (b.price == 'cut'
              ? .55
              : b.price == 'premium'
                  ? 1.35
                  : 1) *
          (econ < 1 ? 1 - (1 - econ) * ind.sens * (b.model == 'sub' ? .5 : 1) : 1) *
          modelMg(b);
      if (b.cartel > 0) mg *= 1.3;
      final nc = ctryOf(b).length;
      if (nc >= 5) mg *= 1 + math.min(.5, (nc - 4) * .06);
      if (b.jv != null && b.jv!.isNotEmpty) {
        final fr = b.jv!.fold(0.0, (s, c) => s + cw(c, y)) / r;
        mg *= 1 - .5 * fr;
      }
      final p = staffById(b.mgr);
      if (p != null) {
        mg += (p.ab['tou']! - 50) / 2000;
        if (p.trait == 'frugal') mg += .02;
        if (p.trait == 'grit') mg += .01;
      } else {
        mg += (pres.ab['tou']! - 50) / 2000;
      }
      if (b.war > 0) mg *= .8;
      if (b.attack > 0) mg *= .7;
      b.profit = b.rev * mg - (b.ad > 0 ? b.adCost : 0) - b.upkeep * (['make', 'food'].contains(ind.cat) && hasDeal('outsrc') ? .7 : 1);
    }
    for (final c in cos) {
      if (!c.alive) continue;
      var rv = 0.0, pr = 0.0;
      for (final b in c.biz) {
        final ind = indm[b.ind]!;
        final M = mkt(ind) * reg[c.tier];
        final e = b.power * (c.parent == 'player' ? (sm[b.ind] ?? 1) : 1);
        final tot = T[b.ind]![c.tier];
        final r = tot > 0 ? M * e / tot / 3 : 0.0;
        b.rev = r;
        rv += r;
        pr += r * ind.mg * c.eff * (econ < 1 ? 1 - (1 - econ) * ind.sens : 1);
      }
      c.rev = rv;
      c.profit = pr;
      final h = c.revHist;
      final gg = h.length >= 12 && h[h.length - 12] > 0 ? rv / h[h.length - 12] - 1 : 0.0;
      final ts = rv > 0 ? c.biz.fold(0.0, (s, b) => s + (techCats.contains(indm[b.ind]!.cat) ? b.rev : 0)) / rv : 0.0;
      c.cap = math.max(0, pr * 12) * per(gg) * (1 + .6 * ts) + math.max(0, c.cash) + rv * .3;
    }
    groupCalc();
  }

  double per(double gg) => clampD(15 * perMul * (1 + clampD(gg, -.3, .5)), 5, 70);
  double salaries() => staff.fold(0.0, (s, p) => s + p.salary) * (hasT('frugal') ? .7 : 1);
  double pctOf(Company c) => c.stakePlayer;

  void groupCalc() {
    final own = biz.fold(0.0, (s, b) => s + b.profit);
    final sb = subs();
    final sp = sb.fold(0.0, (s, c) => s + c.profit * pctOf(c) / 100);
    final it = debt * (hasT('careful') ? .002 : .0033) + bond * .0025;
    final h0 = (biz.length * 1e5 + 3.3e4) * nom() * (holding ? 1.5 : 1);
    final p = own + sp - salaries() - it - h0;
    pre = p;
    interest = it;
    hq = h0;
    subP = sp;
    rev = biz.fold(0.0, (s, b) => s + b.rev) + sb.fold(0.0, (s, c) => s + c.rev * pctOf(c) / 100);
    final h = hist;
    final gg = h.length >= 13 && h[h.length - 13].rev > 0 ? h[h.length - 1].rev / h[h.length - 13].rev - 1 : 0.0;
    final stakes = cos.where((c) => c.alive && c.parent != 'player').fold(0.0, (s, c) => s + pctOf(c) / 100 * c.cap);
    final assets = biz.fold(0.0, (s, b) => s + b.rev * .4) + sb.fold(0.0, (s, c) => s + c.rev * .3 * pctOf(c) / 100);
    final ts = rev > 0 ? biz.fold(0.0, (s, b) => s + (techCats.contains(indm[b.ind]!.cat) ? b.rev : 0)) / rev : 0.0;
    var cp = math.max(0, p * .9 * 12) * per(gg) * (1 + .6 * ts) * (listed ? 1 : .6) + assets + cash - debt - bond + stakes + land;
    if (scandal > 0) cp *= .8;
    if (cooked > 0) cp *= 1.3;
    cap = math.max(cp, 1);
    g = gg;
  }

  // ===== 国 =====
  List<String> ctryOf(Biz b) => b.ctry != null && b.ctry!.isNotEmpty ? b.ctry! : [home];
  double reachOf(Biz b) {
    final y = yr();
    return ctryOf(b).fold(0.0, (s, c) => s + cw(c, y));
  }

  double rEff(Biz b) => reg[0] + math.max(0, reachOf(b) - cw(home, yr()));
  int tierOf(Biz b) {
    final x = rEff(b);
    return x <= reg[0] + .01
        ? 0
        : x <= reg[1]
            ? 1
            : 2;
  }

  double poolT(Biz b, Map<String, List<double>> T) {
    final x = rEff(b), t = T[b.ind]!;
    if (x <= reg[0]) return t[0];
    if (x <= reg[1]) return t[0] + (t[1] - t[0]) * (x - reg[0]) / (reg[1] - reg[0]);
    return t[1] + (t[2] - t[1]) * math.min(1, (x - reg[1]) / (reg[2] - reg[1]));
  }

  // ===== 保存 =====
  /// 試作の save と同じく、選ぶ出来事（関数を持つ）は保存しない
  Map<String, dynamic> toJson() => {
        'v': 1,
        'uid': uidCounter,
        'mode': mode,
        'diff': diff,
        'startYear': startYear,
        'year': year,
        'q': q,
        'cash': cash,
        'debt': debt,
        'listed': listed,
        'region': region,
        'sh': sh.toJson(),
        'biz': biz.map((e) => e.toJson()).toList(),
        'staff': staff.map((e) => e.toJson()).toList(),
        'cands': cands.map((e) => e.toJson()).toList(),
        'kids': kids.map((e) => e.toJson()).toList(),
        'found': found,
        'big': big,
        'log': log.map((e) => e.toJson()).toList(),
        'hist': hist.map((e) => e.toJson()).toList(),
        'cos': cos.map((e) => e.toJson()).toList(),
        'econ': econ,
        'perMul': perMul,
        'techBoom': techBoom,
        'ap': ap,
        'apMax': apMax,
        'over': over,
        'won': won,
        'turn': turn,
        'cycles': cycles.map((e) => e.toJson()).toList(),
        'reported': reported,
        'scandal': scandal,
        'succ': succ,
        'lastNews': lastNews.map((e) => e.toJson()).toList(),
        'peakRank': peakRank,
        'rank': rank,
        'home': home,
        'pres': pres.toJson(),
        'net': net,
        'seen': seen,
        'hint': hint,
        'meet': meet?.toJson(),
        'culture': culture,
        'cultNext': cultNext,
        'cultLeft': cultLeft,
        'lastTax': lastTax,
        'wealth': wealth,
        'land': land,
        'bond': bond,
        'bondDue': bondDue,
        'holding': holding,
        'cooked': cooked,
        'dirty': dirty,
        'rep': rep,
        'rest': rest,
        'gen': gen,
        'serial': serial,
        'lastOffer': lastOffer,
        'vcDeadline': vcDeadline,
        'everBiz': everBiz,
        'ruDone': ruDone,
        'buried': buried,
        'suits': suits.map((e) => e.toJson()).toList(),
        'ret': ret.map((e) => e.toJson()).toList(),
        'deals': deals.map((e) => e.toJson()).toList(),
        'tie': tie?.toJson(),
        'noncomp': noncomp?.toJson(),
        // 試作は保存せず読み込みで作り直していた（月の途中の値になり、続きが少しずれる）。ずれないように持つ
        'indM': indM,
        'guide': guide,
        'history': history.map((e) => e.toJson()).toList(),
        'maxCap': maxCap,
        'maxWealth': maxWealth,
        'yAcc': yAcc,
        'yPrev': yPrev,
        'vow': vow,
      };

  static Game fromJson(Map<String, dynamic> j, {math.Random? rng}) {
    double d(String k, [double def = 0]) => j[k] == null ? def : (j[k] as num).toDouble();
    int i(String k, [int def = 0]) => j[k] == null ? def : (j[k] as num).round();
    Map<String, int> mi(String k) => {for (final e in (j[k] as Map? ?? {}).entries) e.key as String: (e.value as num).round()};
    Map<String, double>? md(String k) => j[k] == null ? null : {for (final e in (j[k] as Map).entries) e.key as String: (e.value as num).toDouble()};
    List<T> l<T>(String k, T Function(Map<String, dynamic>) f) => (j[k] as List? ?? []).map((e) => f(e as Map<String, dynamic>)).toList();
    final s = Game(rng ?? math.Random())
      ..uidCounter = i('uid', 1)
      ..mode = j['mode'] as String
      ..diff = (j['diff'] as String?) ?? 'normal'
      ..startYear = i('startYear')
      ..year = i('year')
      ..q = i('q', 1)
      ..cash = d('cash')
      ..debt = d('debt')
      ..listed = j['listed'] == true
      ..region = i('region')
      ..sh = Shares.fromJson(j['sh'] as Map<String, dynamic>)
      ..biz = l('biz', Biz.fromJson)
      ..staff = l('staff', Person.fromJson)
      ..cands = l('cands', Person.fromJson)
      ..kids = l('kids', Person.fromJson)
      ..found = mi('found')
      ..big = mi('big')
      ..log = l('log', LogEntry.fromJson)
      ..hist = l('hist', HistEntry.fromJson)
      ..cos = l('cos', Company.fromJson)
      ..econ = d('econ', 1)
      ..perMul = d('perMul', 1)
      ..techBoom = d('techBoom', 1)
      ..ap = i('ap')
      ..apMax = i('apMax', 3)
      ..over = j['over'] as String?
      ..won = j['won'] as String?
      ..turn = i('turn')
      ..cycles = l('cycles', Cycle.fromJson)
      ..reported = mi('reported')
      ..scandal = i('scandal')
      ..succ = j['succ'] == null ? null : (j['succ'] as num).round()
      ..lastNews = l('lastNews', LogEntry.fromJson)
      ..peakRank = i('peakRank', 999)
      ..rank = i('rank')
      ..home = (j['home'] as String?) ?? 'jp'
      ..pres = President.fromJson(j['pres'] as Map<String, dynamic>)
      ..net = i('net')
      ..seen = mi('seen')
      ..hint = mi('hint')
      ..meet = j['meet'] == null ? null : Person.fromJson(j['meet'] as Map<String, dynamic>)
      ..culture = (j['culture'] as String?) ?? 'merit'
      ..cultNext = j['cultNext'] as String?
      ..cultLeft = i('cultLeft')
      ..lastTax = d('lastTax')
      ..wealth = d('wealth')
      ..land = d('land')
      ..bond = d('bond')
      ..bondDue = i('bondDue')
      ..holding = j['holding'] == true
      ..cooked = i('cooked')
      ..dirty = i('dirty')
      ..rep = i('rep')
      ..rest = i('rest')
      ..gen = i('gen', 1)
      ..serial = i('serial')
      ..lastOffer = j['lastOffer'] == null ? null : (j['lastOffer'] as num).round()
      ..vcDeadline = i('vcDeadline')
      ..everBiz = j['everBiz'] == true
      ..ruDone = j['ruDone'] == true
      ..buried = (j['buried'] as List? ?? []).map((e) => (e as num).round()).toList()
      ..suits = l('suits', Suit.fromJson)
      ..ret = l('ret', Return.fromJson)
      ..deals = l('deals', Deal.fromJson)
      ..tie = j['tie'] == null ? null : Tie.fromJson(j['tie'] as Map<String, dynamic>)
      ..noncomp = j['noncomp'] == null ? null : Noncomp.fromJson(j['noncomp'] as Map<String, dynamic>)
      ..guide = mi('guide')
      // 社史と最大値は 1.0.0+3 から。古いセーブでは空から始める
      ..history = l('history', Chron.fromJson)
      ..maxCap = d('maxCap')
      ..maxWealth = d('maxWealth')
      // 取締役会は 1.0.0+7 から。古いセーブでは空から始める
      ..yAcc = md('yAcc') ?? {}
      ..yPrev = md('yPrev')
      ..vow = md('vow');
    s.events = [];
    s.reg = regFor(s.yr());
    final saved = j['indM'] as Map?;
    s.indM = {for (final ind in s.inds) ind.id: saved != null && saved[ind.id] != null ? (saved[ind.id] as num).toDouble() : s.mkt(ind)};
    // 1.0.0+7 までのセーブには足した業種がない。生まれたことにして、次の月に CPU の会社を置く（知らせは出さない）
    if (saved != null) {
      for (final ind in s.inds) {
        if (saved[ind.id] == null && s.mkt(ind) > 0) {
          s.indM[ind.id] = 0;
          s.lateInds.add(ind.id);
        }
      }
    }
    s.calcAll();
    // 古いセーブには最大値がないので、残っている推移から埋める
    for (final h in s.hist) {
      if (h.cap > s.maxCap) s.maxCap = h.cap;
    }
    s.trackPeaks();
    return s;
  }
}
