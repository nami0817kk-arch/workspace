/// 動く状態（人・事業・会社など）。どれも JSON に出し入れできる。
library;

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
  }) : off = off ?? {};

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'age': age,
        'ab': ab,
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
      };

  factory Person.fromJson(Map<String, dynamic> j) => Person(
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
      );
}

class President {
  String name;
  int age;
  List<String> traits;
  Map<String, int> ab;
  President({required this.name, required this.age, required this.traits, required this.ab});
  Map<String, dynamic> toJson() => {'name': name, 'age': age, 'traits': traits, 'ab': ab};
  factory President.fromJson(Map<String, dynamic> j) =>
      President(name: j['name'] as String, age: _i(j['age']), traits: _sl(j['traits']), ab: _abFrom(j['ab']));
}

/// 仕掛かり中の打ち手（開発・建設・海外進出）
class Pipe {
  String k;
  String? c, mode;
  double cost;
  double? pw;
  int left;
  int? by;
  Pipe({required this.k, this.c, this.mode, required this.cost, this.pw, required this.left, this.by});
  Map<String, dynamic> toJson() => {'k': k, 'c': c, 'mode': mode, 'cost': cost, 'pw': pw, 'left': left, 'by': by};
  factory Pipe.fromJson(Map<String, dynamic> j) => Pipe(
      k: j['k'] as String,
      c: j['c'] as String?,
      mode: j['mode'] as String?,
      cost: _d(j['cost']),
      pw: _dn(j['pw']),
      left: _i(j['left']),
      by: _in(j['by']));
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
  }) : pipe = pipe ?? [];

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
      );
}

/// CPU の会社の事業
class CoBiz {
  String ind;
  double power, w, rev;
  CoBiz({required this.ind, required this.power, this.w = 0, this.rev = 0});
  Map<String, dynamic> toJson() => {'ind': ind, 'power': power, 'w': w, 'rev': rev};
  factory CoBiz.fromJson(Map<String, dynamic> j) =>
      CoBiz(ind: j['ind'] as String, power: _d(j['power']), w: _d(j['w']), rev: _d(j['rev']));
}

/// 宿敵（会社ごとに持つ。試作では定数を共有していた）
class Rival {
  String k, pres, co, type;
  String? label;
  int tier;
  String col;
  bool gone;
  Rival({required this.k, required this.pres, required this.co, required this.type, this.label, required this.tier, required this.col, this.gone = false});
  Map<String, dynamic> toJson() => {'k': k, 'pres': pres, 'co': co, 'type': type, 'label': label, 'tier': tier, 'col': col, 'gone': gone};
  factory Rival.fromJson(Map<String, dynamic> j) => Rival(
      k: j['k'] as String,
      pres: j['pres'] as String,
      co: j['co'] as String,
      type: j['type'] as String,
      label: j['label'] as String?,
      tier: _i(j['tier']),
      col: j['col'] as String,
      gone: j['gone'] == true);
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
      );
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
  Return({required this.at, required this.fam, required this.west, required this.col, required this.from});
  Map<String, dynamic> toJson() => {'at': at, 'fam': fam, 'west': west, 'col': col, 'from': from};
  factory Return.fromJson(Map<String, dynamic> j) =>
      Return(at: _i(j['at']), fam: j['fam'] as String, west: j['west'] == true, col: j['col'] as String, from: j['from'] as String);
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

/// 選ぶ出来事（保存しない）
class GameEvent {
  final String title, text;
  final List<Choice> choices;
  Company? who;
  String? face;
  Person? person;
  int? poach, pl, subco;
  bool vc, rivfund;
  GameEvent({required this.title, required this.text, required this.choices, this.who, this.face, this.person, this.poach, this.pl, this.subco, this.vc = false, this.rivfund = false});
}
