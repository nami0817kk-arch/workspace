import 'data.dart';

class LogEntry {
  LogEntry(this.t, this.txt, this.kind);
  final String t, txt;

  /// '' / 'good' / 'bad' / 'big'
  final String kind;

  Map<String, dynamic> toJson() => {'t': t, 'x': txt, 'k': kind};
  factory LogEntry.fromJson(Map<String, dynamic> j) =>
      LogEntry(j['t'] as String, j['x'] as String, j['k'] as String);
}

/// 人生の軌跡（グラフ用）。数値はどれも 0〜100。
class HistPoint {
  HistPoint(this.age, this.hp, this.joy, this.chi, this.net);
  final double age, hp, joy, chi, net;

  Map<String, dynamic> toJson() => {
    'a': age,
    'h': hp,
    'j': joy,
    'c': chi,
    'n': net,
  };
  factory HistPoint.fromJson(Map<String, dynamic> j) => HistPoint(
    (j['a'] as num).toDouble(),
    (j['h'] as num).toDouble(),
    (j['j'] as num).toDouble(),
    (j['c'] as num).toDouble(),
    (j['n'] as num).toDouble(),
  );
}

/// 人生で縁のあった人（幼なじみ・師・歴史上の有名人など）。
class Person {
  Person(this.role, this.name, this.bond);

  /// 役割。「幼なじみ」「師」「若殿」など。人生に1人ずつ。
  final String role;
  final String name;

  /// 絆の深さ。0〜100。
  int bond;

  Map<String, dynamic> toJson() => {'r': role, 'n': name, 'b': bond};
  factory Person.fromJson(Map<String, dynamic> j) =>
      Person(j['r'] as String, j['n'] as String, j['b'] as int);
}

class Faction {
  Faction(this.name, this.power, [this.alive = true]);
  final String name;
  double power;
  bool alive;

  Map<String, dynamic> toJson() => {'n': name, 'p': power, 'a': alive};
  factory Faction.fromJson(Map<String, dynamic> j) =>
      Faction(j['n'] as String, (j['p'] as num).toDouble(), j['a'] as bool);
}

/// 一人の人生の状態。
class Life {
  Life({
    required this.name,
    required this.cls,
    required this.clsName,
    required this.female,
    required this.order,
    required this.region,
    required this.home,
    required this.startYear,
    required this.bu,
    required this.chi,
    required this.sei,
    required this.mi,
    required this.un,
    required this.maxhp,
    required this.joy,
    required this.gold,
    required this.birthRank,
    required this.traits,
    required this.rarity,
    required this.sameClass,
  }) : hp = maxhp;

  final String name;
  final ClassDef cls;
  final String clsName;
  final bool female;
  final int order;
  final String region;
  final String home;
  final int startYear;

  /// 経過した半年の数。0歳の春から数える。
  int t = 0;

  int bu, chi, sei, mi, un;
  int hp, maxhp, joy, gold;
  int rank = 0, maxRank = 0;

  /// 十五歳で得る身分。幼少期の出来事で変わることがある。
  int birthRank;
  String? lord;
  int fav = 0, merit = 0, troops = 0, fame = 0, net = 0, kids = 0, conq = 0;
  bool married = false, gun = false, ronin = false;
  final List<String> traits;
  final double rarity, sameClass;
  final List<LogEntry> log = [];
  final List<HistPoint> hist = [];

  /// 後の岐路に効く印。選んだ道が積み重なって立つ（例: 'temple', 'master_lit'）。
  final Set<String> flags = {};

  /// 縁のある人。キーは役割。
  final Map<String, Person> people = {};

  /// 歩んだ道。結果カードに載せる、短い一行ずつ。
  final List<String> path = [];

  /// 過ごし方の選択の回数。次に出る岐路の種類に効く。
  final Map<String, int> focus = {};
  String? dead;

  /// 死に方の種類（`kDeathKinds` のキー）。亡くなったときに決まる。
  String? deathKind;
  String? end;
  bool victory = false;

  bool has(String id) => traits.contains(id);

  Map<String, dynamic> toJson() => {
    'name': name,
    'cls': cls.id,
    'clsName': clsName,
    'female': female,
    'order': order,
    'region': region,
    'home': home,
    'startYear': startYear,
    't': t,
    'bu': bu,
    'chi': chi,
    'sei': sei,
    'mi': mi,
    'un': un,
    'hp': hp,
    'maxhp': maxhp,
    'joy': joy,
    'gold': gold,
    'rank': rank,
    'maxRank': maxRank,
    'birthRank': birthRank,
    'lord': lord,
    'fav': fav,
    'merit': merit,
    'troops': troops,
    'fame': fame,
    'net': net,
    'kids': kids,
    'conq': conq,
    'married': married,
    'gun': gun,
    'ronin': ronin,
    'traits': traits,
    'rarity': rarity,
    'sameClass': sameClass,
    'log': log.take(60).map((e) => e.toJson()).toList(),
    'hist': hist.map((e) => e.toJson()).toList(),
    'flags': flags.toList(),
    'people': people.values.map((e) => e.toJson()).toList(),
    'path': path,
    'focus': focus,
    'dead': dead,
    'deathKind': deathKind,
    'end': end,
    'victory': victory,
  };

  factory Life.fromJson(Map<String, dynamic> j) {
    final l = Life(
      name: j['name'] as String,
      cls: classById(j['cls'] as String),
      clsName: j['clsName'] as String,
      female: j['female'] as bool,
      order: j['order'] as int,
      region: j['region'] as String,
      home: j['home'] as String,
      startYear: j['startYear'] as int,
      bu: j['bu'] as int,
      chi: j['chi'] as int,
      sei: j['sei'] as int,
      mi: j['mi'] as int,
      un: j['un'] as int,
      maxhp: j['maxhp'] as int,
      joy: j['joy'] as int,
      gold: j['gold'] as int,
      birthRank: j['birthRank'] as int,
      traits: (j['traits'] as List).cast<String>().toList(),
      rarity: (j['rarity'] as num).toDouble(),
      sameClass: (j['sameClass'] as num).toDouble(),
    );
    l.t = j['t'] as int;
    l.hp = j['hp'] as int;
    l.rank = j['rank'] as int;
    l.maxRank = j['maxRank'] as int;
    l.lord = j['lord'] as String?;
    l.fav = j['fav'] as int;
    l.merit = j['merit'] as int;
    l.troops = j['troops'] as int;
    l.fame = j['fame'] as int;
    l.net = j['net'] as int;
    l.kids = j['kids'] as int;
    l.conq = j['conq'] as int;
    l.married = j['married'] as bool;
    l.gun = j['gun'] as bool;
    l.ronin = j['ronin'] as bool;
    l.dead = j['dead'] as String?;
    l.deathKind = j['deathKind'] as String?;
    l.end = j['end'] as String?;
    l.victory = j['victory'] as bool;
    l.log.addAll(
      (j['log'] as List).map(
        (e) => LogEntry.fromJson(e as Map<String, dynamic>),
      ),
    );
    l.hist.addAll(
      (j['hist'] as List).map(
        (e) => HistPoint.fromJson(e as Map<String, dynamic>),
      ),
    );
    l.flags.addAll((j['flags'] as List).cast<String>());
    for (final e in (j['people'] as List)) {
      final p = Person.fromJson(e as Map<String, dynamic>);
      l.people[p.role] = p;
    }
    l.path.addAll((j['path'] as List).cast<String>());
    (j['focus'] as Map<String, dynamic>).forEach(
      (k, v) => l.focus[k] = v as int,
    );
    return l;
  }
}
