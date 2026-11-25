/// 動く状態（人・事業・会社など）。どれも JSON に出し入れできる。
library;

import 'dart:collection';

import 'corp_models.dart';

export 'corp_models.dart';

double _d(dynamic x, [double def = 0]) => x == null ? def : (x as num).toDouble();
double? _dn(dynamic x) => x == null ? null : (x as num).toDouble();
int _i(dynamic x, [int def = 0]) => x == null ? def : (x as num).round();
int? _in(dynamic x) => x == null ? null : (x as num).round();
List<String> _sl(dynamic x) => x == null ? <String>[] : (x as List).map((e) => e as String).toList();

const abKeys = ['tou', 'kai', 'ei', 'zai'];

Map<String, int> _abFrom(dynamic x) {
  final m = x as Map;
  return {for (final k in abKeys) k: _i(m[k])};
}

/// 細かい能力（1.1.0+27。企画書「人を現実の人材に寄せる」）。経営・稼ぐ・作る・管理・外との5つの分野に分ける
const skKeys = ['lead', 'judge', 'nego', 'sales', 'mkt', 'ops', 'tech', 'prod', 'fin', 'acct', 'hr', 'law', 'lang', 'nInd', 'nPol', 'nBank'];

/// 今までの4つの能力（統率・開発・営業・財務）が、どの細かい能力から出るか（重み）。
/// 仕組みの多くは今も4つの能力で動くので、細かい能力を持つ人の4つは、ここから求める
const Map<String, Map<String, int>> abFromSk = {
  'tou': {'lead': 2, 'judge': 1, 'hr': 1, 'ops': 1},
  'kai': {'tech': 3, 'prod': 1},
  'ei': {'sales': 2, 'mkt': 1, 'nego': 1},
  'zai': {'fin': 2, 'acct': 1, 'nBank': 1},
};

/// 細かい能力から求めた4つの能力の見え方。書き込むと、その差を元の細かい能力に配る
/// （今までの仕組み（出来事・相棒の作り方・年の衰え）が4つの能力を直接動かしても、細かい能力が一緒に動く）
class AbView extends MapBase<String, int> {
  final Map<String, int> sk;
  AbView(this.sk);

  static int calc(Map<String, int> sk, String k) {
    final w = abFromSk[k];
    if (w == null) return 0;
    var s = 0, n = 0;
    for (final e in w.entries) {
      s += (sk[e.key] ?? 0) * e.value;
      n += e.value;
    }
    return (s / n).round().clamp(1, 99);
  }

  @override
  int? operator [](Object? key) => abFromSk.containsKey(key) ? calc(sk, key as String) : null;

  @override
  void operator []=(String key, int value) {
    final w = abFromSk[key];
    if (w == null) return;
    final d = value - calc(sk, key);
    if (d == 0) return;
    for (final k in w.keys) {
      sk[k] = ((sk[k] ?? 0) + d).clamp(1, 99);
    }
  }

  @override
  void clear() {}

  @override
  Iterable<String> get keys => abKeys;

  @override
  int? remove(Object? key) => null;
}

/// 前に勤めた会社1つ（業種の分類・会社の大きさ・役職・年数・会社の名前）
class Job {
  /// 業種の分類（food など）・業種（分かれば）
  String cat;
  String? ind;

  /// 会社の大きさ（0 小さな会社・1 中くらい・2 大手）・役職（0 担当・1 管理職・2 役員）
  int size, role;
  int years;

  /// 自社で店長などを務めた記録なら true
  bool own;
  Job({required this.cat, this.ind, this.size = 1, this.role = 0, this.years = 1, this.own = false});
  Map<String, dynamic> toJson() => {'cat': cat, if (ind != null) 'ind': ind, 'size': size, 'role': role, 'years': years, if (own) 'own': true};
  factory Job.fromJson(Map<String, dynamic> j) =>
      Job(cat: (j['cat'] as String?) ?? 'live', ind: j['ind'] as String?, size: _i(j['size'], 1), role: _i(j['role']), years: _i(j['years'], 1), own: j['own'] == true);
}

class Person {
  int id;
  String name;
  int age;
  Map<String, int> ab;
  String trait;
  int amb;
  double loy;
  int tenure;
  double salary;
  int w;
  Map<String, double> off;
  bool traitKnown, ambKnown;
  bool partner;
  double stake;
  String? place;
  double? money;
  bool kid;
  bool auto;
  int rej;

  /// 顔の絵（faces.dart の FACES の id。1.0.0+21 から。古いセーブには無く、読み込んだときに割り当てる。15歳までの子どもは null）
  String? face;

  /// 顔を決めたときの年齢（1.0.0+22 までは年代 0〜2 を入れていた）。記録だけで、選び直すかは本人と絵の年の差で決める（faces.dart の faceStale）
  int? fb;

  // ===== 経歴・細かい能力・人柄・暮らし（1.1.0+27。試作との一致を見る遊び（extras を切る）では持たない） =====
  /// 細かい能力（[skKeys]）。持つ人の [ab] は、ここから求めた見え方（[AbView]）になる
  Map<String, int>? sk;

  /// 学歴（0 高校・1 専門と短大・2 大学・3 名門大学・4 大学院）・専攻（econ law eng sci med lit biz info）
  int edu;
  String? major;

  /// 職歴（古い順）
  List<Job> jobs;

  /// 資格（doctor 医師・lawyer 弁護士・cpa 会計士・pilot パイロット）
  List<String> lic;

  /// 技術の分野（soft mech elec chem med civil）・話せる外国語（名前の言葉の鍵。無ければ null）
  String? tf, lg;

  /// 人柄: 誠実さ・ストレスへの強さ・協調性（0〜100）。挑戦好きか慎重かは [amb]（今までの野心）を使う
  int hon, str, coop;

  /// 伸びしろ（能力が年に伸びる速さの倍。0.5〜1.5）
  double pot;

  /// 暮らし: 結婚しているか・子どもの年齢・親の介護をしているか
  bool married, care;
  List<int> kidsAge;

  /// 健康（0〜100。働かせすぎると下がり、低いと燃え尽きる）
  double health;

  /// 休んでいる・研修や留学で外に出ている残りの月と、その理由（sick 病気 / baby 育児 / care 介護 / course 研修 / abroad 留学）
  int away;
  String? awayWhy;

  /// 業界での評判（0〜100。相場の給料に効く）
  int fame;

  /// 分かっていること（hon str coop amb fam health の鍵。話を聞くと増える）
  List<String> known;

  /// 採用の候補になった道（grad 新卒 / mid 中途 / poach 引き抜き / lead 自社の店長から / back 出戻り）
  String? src;

  /// 社外の人なら、今どこにいるか（辞めた理由: quit 辞めた / poached 引き抜かれた / fired 解雇 / retired 引退）
  String? left;

  Person({
    required this.id,
    required this.name,
    required this.age,
    required this.ab,
    required this.trait,
    required this.amb,
    required this.loy,
    this.tenure = 0,
    this.salary = 0,
    this.w = 26,
    Map<String, double>? off,
    this.traitKnown = false,
    this.ambKnown = false,
    this.partner = false,
    this.stake = 0,
    this.place,
    this.money,
    this.kid = false,
    this.auto = false,
    this.rej = 0,
    this.face,
    this.fb,
    this.sk,
    this.edu = 2,
    this.major,
    List<Job>? jobs,
    List<String>? lic,
    this.tf,
    this.lg,
    this.hon = 60,
    this.str = 50,
    this.coop = 50,
    this.pot = 1,
    this.married = false,
    this.care = false,
    List<int>? kidsAge,
    this.health = 80,
    this.away = 0,
    this.awayWhy,
    this.fame = 30,
    List<String>? known,
    this.src,
    this.left,
  })  : off = off ?? {},
        jobs = jobs ?? [],
        lic = lic ?? [],
        kidsAge = kidsAge ?? [],
        known = known ?? [];

  /// 細かい能力を持つか（持つ人は経歴・人柄・暮らしも持つ）
  bool get real => sk != null;

  /// 細かい能力を付ける（4つの能力は、これから求める見え方になる）
  void setSk(Map<String, int> m) {
    sk = m;
    ab = AbView(m);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'age': age,
        'ab': {for (final k in abKeys) k: ab[k]},
        if (sk != null) ...{
          'sk': sk,
          'edu': edu,
          'major': major,
          'jobs': jobs.map((e) => e.toJson()).toList(),
          'lic': lic,
          'tf': tf,
          'lg': lg,
          'hon': hon,
          'str': str,
          'coop': coop,
          'pot': pot,
          'married': married,
          'care': care,
          'kidsAge': kidsAge,
          'health': health,
          'away': away,
          'awayWhy': awayWhy,
          'fame': fame,
          'known': known,
        },
        if (src != null) 'src': src,
        if (left != null) 'left': left,
        'trait': trait,
        'amb': amb,
        'loy': loy,
        'tenure': tenure,
        'salary': salary,
        'w': w,
        'off': off,
        'traitKnown': traitKnown,
        'ambKnown': ambKnown,
        'partner': partner,
        'stake': stake,
        'place': place,
        'money': money,
        'kid': kid,
        'auto': auto,
        'rej': rej,
        if (face != null) 'face': face,
        if (fb != null) 'fb': fb,
      };

  factory Person.fromJson(Map<String, dynamic> j) {
    final p = Person._fromJson(j);
    final sk = j['sk'] as Map?;
    if (sk != null) {
      p.setSk({for (final k in skKeys) k: _i(sk[k], 40)});
      p
        ..edu = _i(j['edu'], 2)
        ..major = j['major'] as String?
        ..jobs = (j['jobs'] as List? ?? []).map((e) => Job.fromJson(e as Map<String, dynamic>)).toList()
        ..lic = _sl(j['lic'])
        ..tf = j['tf'] as String?
        ..lg = j['lg'] as String?
        ..hon = _i(j['hon'], 60)
        ..str = _i(j['str'], 50)
        ..coop = _i(j['coop'], 50)
        ..pot = _d(j['pot'], 1)
        ..married = j['married'] == true
        ..care = j['care'] == true
        ..kidsAge = (j['kidsAge'] as List? ?? []).map((e) => _i(e)).toList()
        ..health = _d(j['health'], 80)
        ..away = _i(j['away'])
        ..awayWhy = j['awayWhy'] as String?
        ..fame = _i(j['fame'], 30)
        ..known = _sl(j['known']);
    }
    p
      ..src = j['src'] as String?
      ..left = j['left'] as String?;
    return p;
  }

  factory Person._fromJson(Map<String, dynamic> j) => Person(
        id: _i(j['id']),
        name: j['name'] as String,
        age: _i(j['age']),
        ab: _abFrom(j['ab']),
        trait: j['trait'] as String,
        amb: _i(j['amb']),
        loy: _d(j['loy']),
        tenure: _i(j['tenure']),
        salary: _d(j['salary']),
        w: _i(j['w'], 26),
        off: {for (final e in (j['off'] as Map? ?? {}).entries) e.key as String: _d(e.value)},
        traitKnown: j['traitKnown'] == true,
        ambKnown: j['ambKnown'] == true,
        partner: j['partner'] == true,
        stake: _d(j['stake']),
        place: j['place'] as String?,
        money: _dn(j['money']),
        kid: j['kid'] == true,
        auto: j['auto'] == true,
        rej: _i(j['rej']),
        face: j['face'] as String?,
        fb: _in(j['fb']),
      );
}

class President {
  String name;
  int age;
  List<String> traits;
  Map<String, int> ab;

  /// 顔の絵（1.0.0+21 から。古いセーブには無い）
  String? face;

  /// 顔を決めたときの年齢（[Person.fb] と同じ）
  int? fb;

  /// 腕ごとにたまった経験（1.1.0+32。たまると腕が1上がる。古いセーブは0から）
  Map<String, double> xp;

  /// 今月たまった経験（月の終わりに、1か月の上限までを [xp] に移す）
  Map<String, double> pend;

  /// 会社の人数のいちばん多かったとき（人数が増えると統率の経験になる）
  double hd;

  /// 資金繰りの危機の中にいるか（0 いない・1 銀行の管理やつなぎの融資・2 民事再生）。乗り切ると経験が多めにたまる
  int crisis;
  President({required this.name, required this.age, required this.traits, required this.ab, this.face, this.fb, Map<String, double>? xp, Map<String, double>? pend, this.hd = 0, this.crisis = 0})
      : xp = xp ?? {},
        pend = pend ?? {};
  Map<String, dynamic> toJson() => {
        'name': name,
        'age': age,
        'traits': traits,
        'ab': ab,
        if (face != null) 'face': face,
        if (fb != null) 'fb': fb,
        if (xp.isNotEmpty) 'xp': xp,
        if (pend.isNotEmpty) 'pend': pend,
        if (hd > 0) 'hd': hd,
        if (crisis > 0) 'cr': crisis,
      };
  factory President.fromJson(Map<String, dynamic> j) => President(
      name: j['name'] as String,
      age: _i(j['age']),
      traits: _sl(j['traits']),
      ab: _abFrom(j['ab']),
      face: j['face'] as String?,
      fb: _in(j['fb']),
      xp: _dMap(j['xp']),
      pend: _dMap(j['pend']),
      hd: _d(j['hd']),
      crisis: _i(j['cr']));
}

Map<String, double> _dMap(dynamic x) => x == null ? {} : {for (final e in (x as Map).entries) e.key as String: (e.value as num).toDouble()};

/// 仕掛かり中の打ち手（開発・建設・海外進出）
class Pipe {
  String k;
  String? c, mode;
  double cost;
  double? pw;
  int left;
  int? by;

  /// 商品の大きさ（0 小さな改良・1 新商品・2 大型開発）。単位で始めた開発だけが持つ（割合の開発は null）
  int? sz;

  /// 「今ある店・工場を広げる」で始めた仕掛かりか（1.0.0+18。種類は build のままで、見せ方と知らせだけを「増やす」と分ける。古いセーブには無い → false）
  bool ext;

  /// 店などを開く仕掛かり（k = open）の、物件の売上の倍と家賃の倍（1.1.0+26）
  double? mul, rent;
  Pipe({required this.k, this.c, this.mode, required this.cost, this.pw, required this.left, this.by, this.sz, this.ext = false, this.mul, this.rent});
  Map<String, dynamic> toJson() => {
        'k': k,
        'c': c,
        'mode': mode,
        'cost': cost,
        'pw': pw,
        'left': left,
        'by': by,
        if (sz != null) 'sz': sz,
        if (ext) 'ext': true,
        if (mul != null) 'mul': mul,
        if (rent != null) 'rent': rent
      };
  factory Pipe.fromJson(Map<String, dynamic> j) => Pipe(
      mul: _dn(j['mul']),
      rent: _dn(j['rent']),
      k: j['k'] as String,
      c: j['c'] as String?,
      mode: j['mode'] as String?,
      cost: _d(j['cost']),
      pw: _dn(j['pw']),
      left: _i(j['left']),
      by: _in(j['by']),
      sz: _in(j['sz']),
      ext: j['ext'] == true);
}

/// 自社の事業
class Biz {
  int id;
  String ind;
  int early;
  String model;
  double power;
  double? crew;
  double upkeep;
  List<Pipe> pipe;
  int? mgr;
  String price;
  int ad;
  double adCost;
  int war;
  int age;
  double rev, profit, share, prevRev;
  List<String>? ctry;
  List<String>? jv;
  int attack;
  int? target;
  int cartel;

  // ===== 責任者に任せる（1.0.0+20 から。古いセーブでは「自分で動かす」・枠は元手の1倍） =====
  /// 責任者に任せているか（任せると、毎月、責任者が自分で手を打つ。社長の手は使わない）
  bool deleg;

  /// 任せたときに責任者が月に使えるお金の段（delegMults の番号。0 は使わせない）
  int budget;

  /// 任せた責任者が今月やったことの1行（包んだ文。何もしなかった月は理由。任せていなければ null）
  String? did;

  // ===== 店・ライン・拠点の数（1.1.0+26 から。game_units.dart） =====
  /// 立地（国/都市の番号/都心・郊外・地方）ごとの、育ちきった単位の数と平均の売上の倍・家賃の倍
  Map<String, Site> sites;

  /// 開いてまだ育ちきっていない単位（立地・数・開いてからの月）
  List<Cohort> young;

  /// 手の空いている責任者（店長・工場長・支店長）の数・本部で見る人（指導員など）の数
  int leads, sv;

  /// 物流の拠点のある地域（国/都市の番号）
  List<String> hubs;

  /// 許可が下りるまでの残りの月（許認可型だけ。0 は下りている）
  int lic;

  /// 今月出ている物件（店舗型など。月ごとに入れ替わる。保存する）
  List<Offer> offers;

  /// 改装で上げた1単位の売上の倍（1〜1.3）
  double upg;

  /// 今月開き始めた単位の数（月ごとの上限に使う）
  int opened;

  /// 店長など（責任者・本部の人）の腕の平均（0〜100。1.1.0+27。採用の市場の質と、育てる人の腕で決まる）
  double lq;

  /// 店長などが辞めて、責任者のいない単位の数（1.1.0+27。手の空いた店長がいれば翌月に埋まる）
  double vac;

  /// 直近13か月の売上（古い順。前年比に使う）
  List<double> rh;

  Biz({
    required this.id,
    required this.ind,
    this.early = 0,
    this.model = 'direct',
    required this.power,
    this.crew,
    this.upkeep = 0,
    List<Pipe>? pipe,
    this.mgr,
    this.price = 'normal',
    this.ad = 0,
    this.adCost = 0,
    this.war = 0,
    this.age = 0,
    this.rev = 0,
    this.profit = 0,
    this.share = 0,
    this.prevRev = 0,
    this.ctry,
    this.jv,
    this.attack = 0,
    this.target,
    this.cartel = 0,
    this.deleg = false,
    this.budget = 1,
    this.did,
    Map<String, Site>? sites,
    List<Cohort>? young,
    this.leads = 0,
    this.sv = 0,
    List<String>? hubs,
    this.lic = 0,
    List<Offer>? offers,
    this.upg = 1,
    this.opened = 0,
    this.lq = 50,
    this.vac = 0,
    List<double>? rh,
  })  : pipe = pipe ?? [],
        rh = rh ?? [],
        sites = sites ?? {},
        young = young ?? [],
        hubs = hubs ?? [],
        offers = offers ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'ind': ind,
        'early': early,
        'model': model,
        'power': power,
        'crew': crew,
        'upkeep': upkeep,
        'pipe': pipe.map((e) => e.toJson()).toList(),
        'mgr': mgr,
        'price': price,
        'ad': ad,
        'adCost': adCost,
        'war': war,
        'age': age,
        'rev': rev,
        'profit': profit,
        'share': share,
        'prevRev': prevRev,
        'ctry': ctry,
        'jv': jv,
        'attack': attack,
        'target': target,
        'cartel': cartel,
        if (deleg) 'deleg': true,
        if (budget != 1) 'budget': budget,
        if (did != null) 'did': did,
        'sites': {for (final e in sites.entries) e.key: e.value.toJson()},
        'young': young.map((e) => e.toJson()).toList(),
        'leads': leads,
        'sv': sv,
        'hubs': hubs,
        'lic': lic,
        'offers': offers.map((e) => e.toJson()).toList(),
        'upg': upg,
        'opened': opened,
        'lq': lq,
        'vac': vac,
        'rh': rh,
      };

  factory Biz.fromJson(Map<String, dynamic> j) => Biz(
        id: _i(j['id']),
        ind: j['ind'] as String,
        early: _i(j['early']),
        model: (j['model'] as String?) ?? 'direct',
        power: _d(j['power']),
        crew: _dn(j['crew']),
        upkeep: _d(j['upkeep']),
        pipe: (j['pipe'] as List? ?? []).map((e) => Pipe.fromJson(e as Map<String, dynamic>)).toList(),
        mgr: _in(j['mgr']),
        price: (j['price'] as String?) ?? 'normal',
        ad: _i(j['ad']),
        adCost: _d(j['adCost']),
        war: _i(j['war']),
        age: _i(j['age']),
        rev: _d(j['rev']),
        profit: _d(j['profit']),
        share: _d(j['share']),
        prevRev: _d(j['prevRev']),
        ctry: j['ctry'] == null ? null : _sl(j['ctry']),
        jv: j['jv'] == null ? null : _sl(j['jv']),
        attack: _i(j['attack']),
        target: _in(j['target']),
        cartel: _i(j['cartel']),
        deleg: j['deleg'] == true,
        budget: _i(j['budget'], 1).clamp(0, 3),
        did: j['did'] as String?,
        sites: {for (final e in (j['sites'] as Map? ?? {}).entries) e.key as String: Site.fromJson(e.value as Map<String, dynamic>)},
        young: (j['young'] as List? ?? []).map((e) => Cohort.fromJson(e as Map<String, dynamic>)).toList(),
        leads: _i(j['leads']),
        sv: _i(j['sv']),
        hubs: _sl(j['hubs']),
        lic: _i(j['lic']),
        offers: (j['offers'] as List? ?? []).map((e) => Offer.fromJson(e as Map<String, dynamic>)).toList(),
        upg: _d(j['upg'], 1),
        opened: _i(j['opened']),
        lq: _d(j['lq'], 50),
        vac: _d(j['vac']),
        rh: (j['rh'] as List? ?? []).map((e) => _d(e)).toList(),
      );
}

/// 1つの立地の、育ちきった単位（数は小数も持つ。ネットの利用者や作品は少しずつ減るため）
class Site {
  double n;

  /// 平均の売上の倍（物件の良し悪し・当たり外れ）・家賃の倍
  double mul, rent;
  Site({this.n = 0, this.mul = 1, this.rent = 1});
  Map<String, dynamic> toJson() => {'n': n, 'mul': mul, 'rent': rent};
  factory Site.fromJson(Map<String, dynamic> j) => Site(n: _d(j['n']), mul: _d(j['mul'], 1), rent: _d(j['rent'], 1));
}

/// 開いてまだ育ちきっていない単位のまとまり
class Cohort {
  String s;
  double n;
  int age;
  double mul, rent;
  Cohort({required this.s, required this.n, this.age = 0, this.mul = 1, this.rent = 1});
  Map<String, dynamic> toJson() => {'s': s, 'n': n, 'age': age, 'mul': mul, 'rent': rent};
  factory Cohort.fromJson(Map<String, dynamic> j) => Cohort(s: j['s'] as String, n: _d(j['n']), age: _i(j['age']), mul: _d(j['mul'], 1), rent: _d(j['rent'], 1));
}

/// 今月出ている物件1件（立地・家賃の倍・売上の倍・狙っている他社の数）
class Offer {
  String s;
  double rent, mul;
  int riv;
  Offer({required this.s, this.rent = 1, this.mul = 1, this.riv = 0});
  Map<String, dynamic> toJson() => {'s': s, 'rent': rent, 'mul': mul, 'riv': riv};
  factory Offer.fromJson(Map<String, dynamic> j) => Offer(s: j['s'] as String, rent: _d(j['rent'], 1), mul: _d(j['mul'], 1), riv: _i(j['riv']));
}

/// CPU の会社の事業
class CoBiz {
  String ind;
  double power, w, rev;

  /// 店・工場などの数（育ちきった分・育ちかけの分）と、客の数で決まる売上（店の数で抑える前。1.1.0+29 から。自社と同じ決まり）
  double u, uy, dem;
  CoBiz({required this.ind, required this.power, this.w = 0, this.rev = 0, this.u = 0, this.uy = 0, this.dem = 0});
  Map<String, dynamic> toJson() => {'ind': ind, 'power': power, 'w': w, 'rev': rev, if (u != 0) 'u': u, if (uy != 0) 'uy': uy};
  factory CoBiz.fromJson(Map<String, dynamic> j) =>
      CoBiz(ind: j['ind'] as String, power: _d(j['power']), w: _d(j['w']), rev: _d(j['rev']), u: _d(j['u']), uy: _d(j['uy']));
}

/// 宿敵（会社ごとに持つ。試作では定数を共有していた）
class Rival {
  /// [pres] は初代の社長の名前（代替わりしても変わらない）。場面の文に出す名前は、今の社長の [Company.presName]（1.0.0+23 から）
  String k, pres, co, type;
  String? label;
  int tier;
  String col;
  bool gone;

  // ===== 宿敵の物語（1.0.0+7 から。古いセーブでは空から） =====
  /// 段: 0 まだ出会っていない / 1 張り合う / 2 決着
  int st;

  /// 恨み（あなたが相手にしたこと）・恩（助けた・組んだ）・相手からされたこと
  int grudge, favor, hurt;

  /// 因縁の記録（包んだ文。新しいものを後ろに、最大6つ）
  List<String> ties;

  /// 友好が続いている起点の月（-1 は続いていない）・組んでいる起点の月
  int friendSince, allySince;

  /// 提携の申し出を受けて組んでいる
  bool allied;

  /// 張り合う場面を出したか
  bool vexed;

  /// 決着: bought（買収した）/ boughtBy（買収された）/ peace（和解）/ ally（組んだ）
  String? end;
  int endY;

  /// 戻ってきた一族なら、前に倒された会社の名前
  String? from;

  Rival({
    required this.k,
    required this.pres,
    required this.co,
    required this.type,
    this.label,
    required this.tier,
    required this.col,
    this.gone = false,
    this.st = 0,
    this.grudge = 0,
    this.favor = 0,
    this.hurt = 0,
    List<String>? ties,
    this.friendSince = -1,
    this.allySince = -1,
    this.allied = false,
    this.vexed = false,
    this.end,
    this.endY = 0,
    this.from,
  }) : ties = ties ?? [];

  /// せりふの型（RTYPE の鍵）
  String get kind => label ?? type;

  Map<String, dynamic> toJson() => {
        'k': k,
        'pres': pres,
        'co': co,
        'type': type,
        'label': label,
        'tier': tier,
        'col': col,
        'gone': gone,
        'st': st,
        'grudge': grudge,
        'favor': favor,
        'hurt': hurt,
        'ties': ties,
        'friendSince': friendSince,
        'allySince': allySince,
        'allied': allied,
        'vexed': vexed,
        'end': end,
        'endY': endY,
        'from': from,
      };
  factory Rival.fromJson(Map<String, dynamic> j) => Rival(
      k: j['k'] as String,
      pres: j['pres'] as String,
      co: j['co'] as String,
      type: j['type'] as String,
      label: j['label'] as String?,
      tier: _i(j['tier']),
      col: j['col'] as String,
      gone: j['gone'] == true,
      st: _i(j['st']),
      grudge: _i(j['grudge']),
      favor: _i(j['favor']),
      hurt: _i(j['hurt']),
      ties: _sl(j['ties']),
      friendSince: _i(j['friendSince'], -1),
      allySince: _i(j['allySince'], -1),
      allied: j['allied'] == true,
      vexed: j['vexed'] == true,
      end: j['end'] as String?,
      endY: _i(j['endY']),
      from: j['from'] as String?);
}

class Company {
  int id;
  String name, cat;
  int tier;
  List<CoBiz> biz;
  double cash, fam;

  /// 試作の c.stakes.player
  double stakePlayer;
  double rev, prev;
  List<double> revHist;
  double profit, cap;
  bool alive;

  /// 'player' なら自分の子会社
  String? parent;
  double eff, g;
  String presName;
  double presAge;
  Rival? rival;
  int rel;
  int founded;
  bool listed;
  String? culture, fromStaff;
  bool formerMine;

  // ===== 現地法人（1.0.0+9 から。古いセーブでは無し） =====
  /// 現地法人ならその国（事業のその国の分を分けた子会社）
  String? loc;

  /// 上場した現地法人の株を買い集めている宿敵の会社と、その割合
  int? locRiv;
  double locRivPct;

  // ===== 社長の顔の絵（1.0.0+21 から。宿敵の会社だけが持つ。古いセーブには無い） =====
  /// 顔の絵と、それを割り当てたときの社長の名前（代替わりで名前が変わったら割り当て直す）
  String? pf, pfn;

  /// 顔を決めたときの社長の年齢（[Person.fb] と同じ）
  int? pfb;

  /// 借金・資金繰り・隠れた問題・統合（1.1.0+29 から。古いセーブでは無し）
  CoFin? fin;

  Company({
    required this.id,
    required this.name,
    required this.cat,
    required this.tier,
    List<CoBiz>? biz,
    this.cash = 0,
    required this.fam,
    this.stakePlayer = 0,
    this.rev = 0,
    this.prev = 0,
    List<double>? revHist,
    this.profit = 0,
    this.cap = 0,
    this.alive = true,
    this.parent,
    required this.eff,
    required this.g,
    required this.presName,
    required this.presAge,
    this.rival,
    this.rel = 0,
    required this.founded,
    this.listed = false,
    this.culture,
    this.fromStaff,
    this.formerMine = false,
    this.loc,
    this.locRiv,
    this.locRivPct = 0,
    this.pf,
    this.pfn,
    this.pfb,
    this.fin,
  })  : biz = biz ?? [],
        revHist = revHist ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'cat': cat,
        'tier': tier,
        'biz': biz.map((e) => e.toJson()).toList(),
        'cash': cash,
        'fam': fam,
        'stakePlayer': stakePlayer,
        'rev': rev,
        'prev': prev,
        'revHist': revHist,
        'profit': profit,
        'cap': cap,
        'alive': alive,
        'parent': parent,
        'eff': eff,
        'g': g,
        'presName': presName,
        'presAge': presAge,
        'rival': rival?.toJson(),
        'rel': rel,
        'founded': founded,
        'listed': listed,
        'culture': culture,
        'fromStaff': fromStaff,
        'formerMine': formerMine,
        'loc': loc,
        'locRiv': locRiv,
        'locRivPct': locRivPct,
        if (pf != null) 'pf': pf,
        if (pfn != null) 'pfn': pfn,
        if (pfb != null) 'pfb': pfb,
        if (fin != null) 'fin': fin!.toJson(),
      };

  factory Company.fromJson(Map<String, dynamic> j) => Company(
        id: _i(j['id']),
        name: j['name'] as String,
        cat: j['cat'] as String,
        tier: _i(j['tier']),
        biz: (j['biz'] as List).map((e) => CoBiz.fromJson(e as Map<String, dynamic>)).toList(),
        cash: _d(j['cash']),
        fam: _d(j['fam']),
        stakePlayer: _d(j['stakePlayer']),
        rev: _d(j['rev']),
        prev: _d(j['prev']),
        revHist: (j['revHist'] as List? ?? []).map((e) => _d(e)).toList(),
        profit: _d(j['profit']),
        cap: _d(j['cap']),
        alive: j['alive'] != false,
        parent: j['parent'] as String?,
        eff: _d(j['eff'], 1),
        g: _d(j['g']),
        presName: j['presName'] as String,
        presAge: _d(j['presAge']),
        rival: j['rival'] == null ? null : Rival.fromJson(j['rival'] as Map<String, dynamic>),
        rel: _i(j['rel']),
        founded: _i(j['founded']),
        listed: j['listed'] == true,
        culture: j['culture'] as String?,
        fromStaff: j['fromStaff'] as String?,
        formerMine: j['formerMine'] == true,
        loc: j['loc'] as String?,
        locRiv: _in(j['locRiv']),
        locRivPct: _d(j['locRivPct']),
        pf: j['pf'] as String?,
        pfn: j['pfn'] as String?,
        pfb: _in(j['pfb']),
        fin: j['fin'] == null ? null : CoFin.fromJson(j['fin'] as Map<String, dynamic>),
      );
}

/// 借りたお金の1口（1.1.0+25 から）。借りるたびに1口ずつ増え、毎月少しずつ返す
class Loan {
  int id;

  /// 相手（main メインバンク / second 二番手の銀行 / local 地元の信用金庫 / bridge つなぎの融資 / bond 社債）
  String lender;

  /// 残り・借りたときの額
  double amt, orig;

  /// 年の金利（0.05 = 5%）。借りたときに決まり、返し終わるまで変わらない
  double rate;

  /// 返し終わるまでの月数（残り）・借りたときの月数
  int left, term;

  /// 社債は最後にまとめて返す（それまでは利息だけ）
  bool bullet;

  /// 借りた月（turn）
  int at;
  Loan({required this.id, required this.lender, required this.amt, required this.orig, required this.rate, required this.left, required this.term, this.bullet = false, this.at = 0});

  /// 今月返す元本（社債は最後の月にまとめて）
  double get principal => bullet ? (left <= 1 ? amt : 0) : (left <= 1 ? amt : amt / left);

  /// 今月の利息
  double get interest => amt * rate / 12;

  Map<String, dynamic> toJson() => {'id': id, 'lender': lender, 'amt': amt, 'orig': orig, 'rate': rate, 'left': left, 'term': term, if (bullet) 'bullet': true, 'at': at};
  factory Loan.fromJson(Map<String, dynamic> j) => Loan(
      id: _i(j['id']),
      lender: (j['lender'] as String?) ?? 'main',
      amt: _d(j['amt']),
      orig: _d(j['orig']),
      rate: _d(j['rate']),
      left: _i(j['left'], 1),
      term: _i(j['term'], 1),
      bullet: j['bullet'] == true,
      at: _i(j['at']));
}

/// 時代の大事件
class Cycle {
  String name, news;
  int s, e;
  double econ, per, tech;
  bool shown;
  Cycle({required this.name, required this.s, required this.e, required this.econ, required this.per, required this.tech, required this.news, required this.shown});
  Map<String, dynamic> toJson() => {'name': name, 's': s, 'e': e, 'econ': econ, 'per': per, 'tech': tech, 'news': news, 'shown': shown};
  factory Cycle.fromJson(Map<String, dynamic> j) => Cycle(
      name: j['name'] as String,
      s: _i(j['s']),
      e: _i(j['e']),
      econ: _d(j['econ']),
      per: _d(j['per']),
      tech: _d(j['tech']),
      news: j['news'] as String,
      shown: j['shown'] == true);
}

class Deal {
  int co;
  String type;
  String? ind;
  int since;
  Deal({required this.co, required this.type, this.ind, required this.since});
  Map<String, dynamic> toJson() => {'co': co, 'type': type, 'ind': ind, 'since': since};
  factory Deal.fromJson(Map<String, dynamic> j) => Deal(co: _i(j['co']), type: j['type'] as String, ind: j['ind'] as String?, since: _i(j['since']));
}

/// 取引先の出資の縛り
class Tie {
  int co;
  List<String> inds, cats;
  Tie({required this.co, required this.inds, required this.cats});
  Map<String, dynamic> toJson() => {'co': co, 'inds': inds, 'cats': cats};
  factory Tie.fromJson(Map<String, dynamic> j) => Tie(co: _i(j['co']), inds: _sl(j['inds']), cats: _sl(j['cats']));
}

/// 会社を売ったときの「同じ業種に入らない」約束
class Noncomp {
  List<String> inds;
  int until;
  int buyer;
  double price;
  bool broken;
  Noncomp({required this.inds, required this.until, required this.buyer, required this.price, this.broken = false});
  Map<String, dynamic> toJson() => {'inds': inds, 'until': until, 'buyer': buyer, 'price': price, 'broken': broken};
  factory Noncomp.fromJson(Map<String, dynamic> j) =>
      Noncomp(inds: _sl(j['inds']), until: _i(j['until']), buyer: _i(j['buyer']), price: _d(j['price']), broken: j['broken'] == true);
}

class Suit {
  int at;
  int? co;
  double amt;
  bool against;
  Suit({required this.at, this.co, required this.amt, this.against = false});
  Map<String, dynamic> toJson() => {'at': at, 'co': co, 'amt': amt, 'against': against};
  factory Suit.fromJson(Map<String, dynamic> j) => Suit(at: _i(j['at']), co: _in(j['co']), amt: _d(j['amt']), against: j['against'] == true);
}

/// 倒した宿敵の一族の帰還
class Return {
  int at;
  String fam, col, from;
  bool west;

  /// 前の決着（bought など）と、そのときの恨み。一族はこれを覚えて戻ってくる（古いセーブでは無し）
  String? end;
  int grudge;
  Return({required this.at, required this.fam, required this.west, required this.col, required this.from, this.end, this.grudge = 0});
  Map<String, dynamic> toJson() => {'at': at, 'fam': fam, 'west': west, 'col': col, 'from': from, 'end': end, 'grudge': grudge};
  factory Return.fromJson(Map<String, dynamic> j) => Return(
      at: _i(j['at']),
      fam: j['fam'] as String,
      west: j['west'] == true,
      col: j['col'] as String,
      from: j['from'] as String,
      end: j['end'] as String?,
      grudge: _i(j['grudge']));
}

/// ニュース・記録の1行。t は '' / 'big' / 'good' / 'bad'
class LogEntry {
  String m, t;
  int? y, q;
  LogEntry(this.m, [this.t = '', this.y, this.q]);
  Map<String, dynamic> toJson() => {'m': m, 't': t, 'y': y, 'q': q};
  factory LogEntry.fromJson(Map<String, dynamic> j) => LogEntry(j['m'] as String, (j['t'] as String?) ?? '', _in(j['y']), _in(j['q']));
}

class HistEntry {
  String t;
  double cap, rev, cash, pre;
  HistEntry({required this.t, required this.cap, required this.rev, required this.cash, required this.pre});
  Map<String, dynamic> toJson() => {'t': t, 'cap': cap, 'rev': rev, 'cash': cash, 'pre': pre};
  factory HistEntry.fromJson(Map<String, dynamic> j) =>
      HistEntry(t: j['t'] as String, cap: _d(j['cap']), rev: _d(j['rev']), cash: _d(j['cash']), pre: _d(j['pre']));
}

/// 社史の1行（いつ・何の種類の節目か・文）。仕組みの数字には使わない
class Chron {
  int y, q;

  /// 種類: found / partner / partner_out / first_biz / ipo / abroad / buy / merge / swap / sold / pres / era / rank / won / over / rebirth / rival / board / local
  String k;
  String m;
  Chron(this.y, this.q, this.k, this.m);
  Map<String, dynamic> toJson() => {'y': y, 'q': q, 'k': k, 'm': m};
  factory Chron.fromJson(Map<String, dynamic> j) => Chron(_i(j['y']), _i(j['q'], 1), (j['k'] as String?) ?? '', (j['m'] as String?) ?? '');
}

/// 自社の株主
class Shares {
  double own, vc, float, ally, pt;
  Map<int, double> riv;
  Shares({this.own = 100, this.vc = 0, this.float = 0, this.ally = 0, this.pt = 0, Map<int, double>? riv}) : riv = riv ?? {};
  double get rivSum => riv.values.fold(0.0, (a, b) => a + b);
  double get rivMax => riv.values.fold(0.0, (a, b) => a > b ? a : b);
  Map<String, dynamic> toJson() => {'own': own, 'vc': vc, 'float': float, 'ally': ally, 'pt': pt, 'riv': {for (final e in riv.entries) '${e.key}': e.value}};
  factory Shares.fromJson(Map<String, dynamic> j) => Shares(
      own: _d(j['own']),
      vc: _d(j['vc']),
      float: _d(j['float']),
      ally: _d(j['ally']),
      pt: _d(j['pt']),
      riv: {for (final e in (j['riv'] as Map? ?? {}).entries) int.parse(e.key as String): _d(e.value)});
}

/// 選ぶ出来事の選択肢。f は結果の文を返す
class Choice {
  final String l, s;
  final String Function() f;
  Choice(this.l, this.s, this.f);
}

/// 会議で話す1人（画面では、顔の丸と肩書きつきの吹き出し1つになる）
class Voice {
  /// 話す人の名前（部下・相棒のとき。顔の丸に名前の頭文字を出す）。株主の代表・銀行・取締役は null
  final String? name;

  /// 呼び名と肩書き（包んだ文）
  final String who, role;

  /// 話す人の種類（partner / staff / holder / bank / board）。顔の丸の印に使う
  final String kind;

  /// 言ったこと（包んだ文）
  final String say;
  const Voice({this.name, required this.who, required this.role, required this.kind, required this.say});
}

/// 選ぶ出来事（保存しない）
class GameEvent {
  final String title, text;
  final List<Choice> choices;
  Company? who;
  String? face;
  Person? person;
  int? poach, pl, subco;
  bool vc, rivfund;

  /// 臨時の会議ならそのきっかけ（takeover / scandal / cash）
  String? em;

  /// 会議の場面の見せ方。[voices] があれば、[lead]（状況の説明・地の文）のあとに、話す人ごとの吹き出しを並べる。
  /// [text] は今までどおり全部をつないだ文（記録・自動プレイ・古い見せ方のため）
  final String? lead;
  final List<Voice> voices;

  /// 吹き出しのあとに続ける地の文（取締役会の解任動議など）
  final String? tail;

  /// 小さな知らせ（1.1.0+30。企画書「会議と出来事」）。月の終わりに小窓で手を止めず、「今月やること」に入れる。
  /// 選ばないまま次の月へ進むと、断る・見送る方で片付く
  bool small;
  GameEvent(
      {required this.title,
      this.small = false,
      required this.text,
      required this.choices,
      this.who,
      this.face,
      this.person,
      this.poach,
      this.pl,
      this.subco,
      this.vc = false,
      this.rivfund = false,
      this.em,
      this.lead,
      this.voices = const [],
      this.tail});
}
