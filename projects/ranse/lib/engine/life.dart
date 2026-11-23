import 'dart:collection';

import 'data.dart';

class LogEntry {
  LogEntry(this.t, this.txt, this.kind, {this.cause});
  final String t, txt;

  /// その一行が起きた訳（能力の段を越えた【才】の一行なら能力の字。ほかは null）。画面の札に出るだけ。
  final String? cause;

  /// '' / 'good' / 'bad' / 'big'
  final String kind;

  Map<String, dynamic> toJson() => {'t': t, 'x': txt, 'k': kind, if (cause != null) 'c': cause};
  factory LogEntry.fromJson(Map<String, dynamic> j) =>
      LogEntry(j['t'] as String, j['x'] as String, j['k'] as String, cause: j['c'] as String?);
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

/// 子の行き先（`Kid.fate`）。
class KidFate {
  static const home = 'home'; // 家にいる
  static const wed = 'wed'; // 嫁いだ
  static const adoptedOut = 'adopted_out'; // 養子に出た
  static const temple = 'temple'; // 寺に入った
  static const hostage = 'hostage'; // 人質に出ている
  static const disowned = 'disowned'; // 勘当した
  static const fled = 'fled'; // 出奔した
  static const away = 'away'; // 旅立った・家を出た
  static const service = 'service'; // 奉公に出た
  static const dead = 'dead'; // 亡くなった

  /// 画面に出す言い方（家にいる子は空）。
  static const label = {
    home: '',
    wed: '嫁いだ',
    adoptedOut: '養子に出た',
    temple: '寺に入った',
    hostage: '人質に出ている',
    disowned: '勘当した',
    fled: '出奔した',
    away: '家を出た',
    service: '奉公に出た',
    dead: '亡くなった',
  };
}

/// 子を指す縁の役割。名は子の記録（`Kid.name`）と同じものを指す。
const kKidRoles = [
  '嫡男',
  '娘',
  '子',
  '養子',
  '人質に出した子',
  '旅立った子',
  '勘当した子',
  '出奔した子',
  '寺に入った子',
  '奉公に出た娘',
  '引き取った子',
  '人質の子',
];

/// 子ひとりの記録。
class Kid {
  Kid({
    required this.born,
    required this.female,
    required this.name,
    this.childName,
    this.fate = KidFate.home,
    this.endYear,
    this.adopted = false,
  });

  /// 生まれた年。分からない子（古い保存・数だけ入れた子）は null。
  int? born;
  final bool female;

  /// いまの名（元服で改めたら元服の名。幼名は [childName] に残す）。
  String name;
  String? childName;

  /// 行き先（`KidFate`）。
  String fate;

  /// 家を出た年・亡くなった年。
  int? endYear;

  /// 養子として迎えた子。
  final bool adopted;

  bool get alive => fate != KidFate.dead;
  bool get home => fate == KidFate.home;

  /// その年の歳（年の分からない子は null）。亡くなった子は享年。
  int? ageAt(int year) {
    if (born == null) return null;
    final y = alive ? year : (endYear ?? year);
    return y - born! < 0 ? 0 : y - born!;
  }

  /// 元服などで名を改める（前の名を幼名として残す）。
  void rename(String n) {
    if (n == name) return;
    childName ??= name;
    name = n;
  }

  Map<String, dynamic> toJson() => {
    'b': born,
    'f': female,
    'n': name,
    if (childName != null) 'c': childName,
    's': fate,
    if (endYear != null) 'e': endYear,
    if (adopted) 'a': true,
  };
  factory Kid.fromJson(Map<String, dynamic> j) => Kid(
    born: j['b'] as int?,
    female: j['f'] as bool,
    name: j['n'] as String,
    childName: j['c'] as String?,
    fate: (j['s'] as String?) ?? KidFate.home,
    endYear: j['e'] as int?,
    adopted: (j['a'] as bool?) ?? false,
  );
}

/// 前の持ち方（生まれた年の一覧）の写し。歳の分かる生きている子の年を、記録の順に見せる。
class _KidYears extends ListBase<int> {
  _KidYears(this._l);
  final Life _l;

  List<Kid> get _known =>
      _l.children.where((k) => k.alive && k.born != null).toList();

  @override
  int get length => _known.length;

  /// 短くすると、うしろの子から年を忘れる（子は減らない）。
  @override
  set length(int n) {
    final ks = _known;
    for (var i = ks.length - 1; i >= n && i >= 0; i--) {
      ks[i].born = null;
    }
  }

  @override
  int operator [](int i) => _known[i].born!;

  @override
  void operator []=(int i, int v) => _known[i].born = v;

  /// 年の分からない子に年を入れる（いなければ何もしない）。
  @override
  void add(int element) {
    final k = _l.children
        .where((k) => k.alive && k.born == null)
        .firstOrNull;
    if (k != null) k.born = element;
  }

  @override
  void clear() => length = 0;
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
  int fav = 0, merit = 0, troops = 0, fame = 0, net = 0, conq = 0;
  bool married = false, gun = false, ronin = false;
  final List<String> traits;
  final double rarity, sameClass;

  /// 子の記録（生まれた順に足す。亡くなった子・家を出た子も残す）。子についての正はここ。
  /// 年の分からない子（`born == null`。この持ち方より前の保存や、数だけを入れた子）は
  /// いちばん上の側にいるとみなし、子の歳で出し分ける岐路は今までどおり親の歳で見る。
  final List<Kid> children = [];

  /// 生きている子（家を出た子も含む）。
  Iterable<Kid> get livingKids => children.where((k) => k.alive);

  /// 生きている子の数（嫁いだ・寺に入ったなど、家を出た子も数える。亡くなった子は数えない）。
  /// 子の記録から数えるので、記録と食い違わない。
  int get kids => livingKids.length;

  /// 数だけを置く（テストと古い呼び出しのため）。増やす分は年の分からない子を足し、
  /// 減らす分は上の子から記録ごと外す（その子を指す縁の役割も外す）。
  set kids(int n) {
    var cur = kids;
    while (cur > n) {
      final k = livingKids.first;
      children.remove(k);
      _dropKidRoles(k.name);
      cur--;
    }
    while (cur < n) {
      _newKid(null);
      cur++;
    }
  }

  /// 生きて家にいる子の数。
  int get kidsHome => children.where((k) => k.home).length;

  /// 歳の分かる生きている子の生まれた年（記録の順）。前の持ち方（年の一覧）の写しで、
  /// `clear()` は年を忘れさせ、`add(年)` は年の分からない子に年を入れる。
  late final List<int> kidYears = _KidYears(this);

  /// 名と生年と順から決まる数（子の性別と名に使う。人生の乱数は動かさない）。
  int _kidSeed(int i, int? born) {
    var h = 7;
    for (final c in name.codeUnits) {
      h = (h * 31 + c) & 0x3fffffff;
    }
    h = (h * 31 + startYear) & 0x3fffffff;
    h = (h * 31 + i * 7 + 3) & 0x3fffffff;
    h = (h * 31 + (born ?? 0)) & 0x3fffffff;
    for (var n = 0; n < 3; n++) {
      h = (h * 1103 + 12345) & 0x3fffffff;
    }
    return h >> 4;
  }

  /// まだ使っていない名を選ぶ（兄弟姉妹・縁のある人・自分の名と重ねない）。
  String _kidName(bool girl, int seed) {
    final used = {
      for (final k in children) k.name,
      for (final k in children)
        if (k.childName != null) k.childName!,
      for (final p in people.values) p.name,
    };
    bool free(String n) => !used.contains(n) && !name.endsWith(n);
    final high = rank >= 5;
    final pools = girl
        ? [if (high) kHimeNames, kGivenF]
        : [if (high) kHeirNames, kGivenM];
    for (final pool in pools) {
      final ok = pool.where(free).toList();
      if (ok.isNotEmpty) return ok[seed % ok.length];
    }
    final last = pools.last;
    return last[seed % last.length];
  }

  Kid _newKid(int? born, {bool? female, String? name, bool adopted = false}) {
    final i = children.length;
    final seed = _kidSeed(i, born);
    // 年の分からない子は、上から交互に（男の子と女の子のどちらもいる家になりやすい）。
    final unknownBefore = children.where((k) => k.born == null).length;
    final girl =
        female ??
        (born == null
            ? (_kidSeed(0, null) + unknownBefore).isOdd
            : seed % 100 < 49);
    final k = Kid(
      born: born,
      female: girl,
      name: name ?? _kidName(girl, seed ~/ 100),
      adopted: adopted,
    );
    if (born == null) {
      children.insert(unknownBefore, k);
    } else {
      children.add(k);
    }
    return k;
  }

  /// 子が生まれた（養子を迎えたときは、その子の生まれた年を入れる）。
  /// 性別と名は、決めて渡さなければ名と生年から決まる。
  Kid addKid(int year, {bool? female, String? name, bool adopted = false}) =>
      _newKid(year, female: female, name: name, adopted: adopted);

  /// 子の役割（縁のある人）のうち、その名を指しているものを外す。
  void _dropKidRoles(String kidName) {
    people.removeWhere((r, p) => kKidRoles.contains(r) && p.name == kidName);
  }

  /// その子が亡くなった（記録に残し、その子を指す縁の役割を外す）。
  void kidDied(Kid k, [int? year]) {
    k.fate = KidFate.dead;
    k.endYear = year;
    _dropKidRoles(k.name);
  }

  /// その子が家を出た（嫁いだ・寺に入った・人質・勘当・出奔・旅立ち など）。
  void kidLeft(Kid k, String fate, [int? year]) {
    if (!k.alive) return;
    k.fate = fate;
    k.endYear = year;
  }

  /// その子が家に戻った。
  void kidBack(Kid k) {
    if (!k.alive) return;
    k.fate = KidFate.home;
    k.endYear = null;
  }

  /// 子を一人亡くす。`year` があれば、歳が [lo]〜[hi] の子のうち下の子から
  /// （家にいる子を先に）。当てはまる子がいなければ、年の分からない子を、いなければいちばん下の子を。
  /// 亡くした子を返す（子がいなければ null）。
  Kid? loseKid([int? year, int lo = 0, int hi = 999]) {
    final alive = livingKids.toList();
    if (alive.isEmpty) return null;
    Kid? hit;
    if (year != null) {
      for (final homeOnly in const [true, false]) {
        for (final k in alive.reversed) {
          if (k.born == null || (homeOnly && !k.home)) continue;
          final a = year - k.born!;
          if (a >= lo && a <= hi && (hit == null || k.born! > hit.born!)) {
            hit = k;
          }
        }
        if (hit != null) break;
      }
    }
    hit ??= alive.where((k) => k.born == null && k.home).firstOrNull;
    hit ??= alive.where((k) => k.born == null).firstOrNull;
    hit ??= _sorted(alive.where((k) => k.home)).lastOrNull;
    hit ??= _sorted(alive).last;
    kidDied(hit, year);
    return hit;
  }

  /// 上の子から（年の分からない子がいちばん上）。同じ年なら記録の順。
  List<Kid> _sorted(Iterable<Kid> ks) {
    final l = ks.toList();
    final at = {for (var i = 0; i < children.length; i++) children[i]: i};
    l.sort((a, b) {
      final c = (a.born ?? -99999).compareTo(b.born ?? -99999);
      return c != 0 ? c : at[a]!.compareTo(at[b]!);
    });
    return l;
  }

  /// すべての子を上から（亡くなった子・家を出た子も）。画面の家族の欄に使う。
  List<Kid> get kidsInOrder => _sorted(children);

  /// 歳が [lo]〜[hi] の生きている子を上から。年の分からない子は当てはまるとみなす。
  /// [female] で性別を、[home]（既定は真）で家にいる子だけに絞る。
  List<Kid> kidsAged(
    int year,
    int lo, [
    int hi = 999,
    bool? female,
    bool home = true,
  ]) => _sorted(
    livingKids.where(
      (k) =>
          (!home || k.home) &&
          (female == null || k.female == female) &&
          (k.born == null || (year - k.born! >= lo && year - k.born! <= hi)),
    ),
  );

  /// 歳が [lo]〜[hi] で家にいる息子（いちばん上）。
  Kid? sonAged(int year, int lo, [int hi = 999]) =>
      kidsAged(year, lo, hi, false).firstOrNull;

  /// 歳が [lo]〜[hi] で家にいる娘（いちばん上）。
  Kid? daughterAged(int year, int lo, [int hi = 999]) =>
      kidsAged(year, lo, hi, true).firstOrNull;

  /// 歳が [lo]〜[hi] で家にいる子（いちばん上。性別を問わない）。
  Kid? kidAged(int year, int lo, [int hi = 999]) =>
      kidsAged(year, lo, hi).firstOrNull;

  /// その名の子（生きている子を先に）。
  Kid? kidNamed(String? n) {
    if (n == null) return null;
    return livingKids.where((k) => k.name == n).firstOrNull ??
        children.where((k) => k.name == n).firstOrNull;
  }

  /// 縁の役割（嫡男・娘・子 など）が指している子。
  Kid? kidOfRole(String role) => kidNamed(people[role]?.name);

  /// 年の分からない子がいるか。
  bool get kidAgeUnknown => livingKids.any((k) => k.born == null);

  /// いちばん上の子の歳。子がいないか、年の分からない子がいれば null。
  int? eldestKidAge(int year) {
    if (kids <= 0 || kidAgeUnknown) return null;
    return year - _sorted(livingKids).first.born!;
  }

  /// いちばん下の子の歳。歳の分かる子がいなければ null。
  int? youngestKidAge(int year) {
    final ks = _sorted(livingKids.where((k) => k.born != null));
    return ks.isEmpty ? null : year - ks.last.born!;
  }

  /// 歳が [lo]〜[hi] の家にいる子がいるか。年の分からない子がいれば真とみなす（親の歳で見る）。
  bool hasKidAged(int year, int lo, [int hi = 999]) =>
      kidsAged(year, lo, hi).isNotEmpty;

  /// 歳が [lo]〜[hi] の生きている子がいるか（嫁いだ子・家を出た子も含む。孫の話などに）。
  bool hasLivingKidAged(int year, int lo, [int hi = 999]) =>
      kidsAged(year, lo, hi, null, false).isNotEmpty;

  /// [min] 歳以上の家にいる子の数。年の分からない子は数に入れる。
  int kidsAtLeast(int year, int min) => kidsAged(year, min).length;

  /// 「長男」「次女」など（同じ性別の子のうち何番目か。亡くなった子も数える）。
  String kidOrdinal(Kid k) {
    const ord = ['長', '次', '三', '四', '五', '六', '七', '八', '九', '十'];
    final i = kidsInOrder.where((x) => x.female == k.female).toList().indexOf(k);
    final o = i >= 0 && i < ord.length ? ord[i] : '末';
    return '$o${k.female ? '女' : '男'}';
  }

  /// 家族の欄の呼び名。嫡男（縁の役割が指す子）・養子・長男・次女 など。
  String kidLabel(Kid k) {
    if (k.alive && people['嫡男']?.name == k.name) return '嫡男';
    if (k.adopted) return k.female ? '養女' : '養子';
    return kidOrdinal(k);
  }

  /// 人物のタブの「家族」の欄。連れ合いと子を一行ずつ（呼び名・中身・薄く出すか）。
  /// 子は上から。亡くなった子は「（◯歳で亡くなった）」と薄く。
  List<(String, String, bool)> familyRows(int year) {
    final rows = <(String, String, bool)>[];
    final sp = people['伴侶'];
    if (sp != null) {
      rows.add((
        '連れ合い',
        married ? sp.name : '${sp.name}（いまは共にいない）',
        !married,
      ));
    }
    for (final k in kidsInOrder) {
      final a = k.ageAt(year);
      if (!k.alive) {
        rows.add((
          kidLabel(k),
          '${k.name}（${a == null ? '' : '$a歳で'}亡くなった）',
          true,
        ));
        continue;
      }
      final where = KidFate.label[k.fate] ?? '';
      rows.add((
        kidLabel(k),
        [k.name, if (a != null) '$a歳', if (where.isNotEmpty) where].join('・'),
        false,
      ));
    }
    return rows;
  }

  /// [pool] のうち、子・縁のある人・自分の名と重ならない名（すべて重なるなら [pool] のまま）。
  List<String> freeNames(List<String> pool) {
    final used = {
      for (final k in children) k.name,
      for (final k in children)
        if (k.childName != null) k.childName!,
      for (final p in people.values) p.name,
    };
    final ok = pool
        .where((n) => !used.contains(n) && !name.endsWith(n))
        .toList();
    return ok.isEmpty ? pool : ok;
  }

  /// 子の名を改める（元服など）。その子を指す縁の役割の名も合わせる。
  void renameKid(Kid k, String n) {
    if (n == k.name) return;
    for (final r in kKidRoles) {
      final p = people[r];
      if (p != null && p.name == k.name) people[r] = Person(r, n, p.bond);
    }
    k.rename(n);
  }

  /// 家を出たことを表す縁の役割 → 行き先。
  static const _roleFate = {
    '人質に出した子': KidFate.hostage,
    '人質の子': KidFate.hostage,
    '旅立った子': KidFate.away,
    '勘当した子': KidFate.disowned,
    '出奔した子': KidFate.fled,
    '寺に入った子': KidFate.temple,
    '奉公に出た娘': KidFate.service,
  };

  /// 子を指す縁の役割が付いたとき（`Game.meet`）、その名の子の記録と結ぶ。
  /// 同じ名の子がいなければ、合う子（役割の性別・家にいる子・上の子の順）の名をその名に改める。
  /// 家を出る役割（人質・旅立ち・勘当・出奔・寺・奉公）なら、行き先も記す。
  void bindKidRole(String role, [int? year]) {
    final p = people[role];
    if (p == null || !kKidRoles.contains(role)) return;
    var k = livingKids.where((x) => x.name == p.name).firstOrNull;
    if (k == null) {
      final bool? girl = role == '嫡男'
          ? false
          : (role == '娘' || role == '奉公に出た娘')
          ? true
          : (kGivenF.contains(p.name) || kHimeNames.contains(p.name))
          ? true
          : (kGivenM.contains(p.name) || kHeirNames.contains(p.name))
          ? false
          : null;
      final bound = {
        for (final r in kKidRoles)
          if (r != role && people[r] != null) people[r]!.name,
      };
      final cands = _sorted(
        livingKids.where(
          (x) => !bound.contains(x.name) && (girl == null || x.female == girl),
        ),
      );
      k = cands.where((x) => x.home).firstOrNull ?? cands.firstOrNull;
      if (k == null) return;
      k.rename(p.name);
    }
    final fate = _roleFate[role];
    if (fate != null && k.home) kidLeft(k, fate, year);
  }

  /// 古い保存（子の数と生まれた年だけ）から子の記録を作る。縁の役割に名のある子は、その名で。
  void _kidsFromOldSave(int n, List<int> years) {
    final ys = years.length > n ? years.sublist(years.length - n) : years;
    final slots = <int?>[for (var i = ys.length; i < n; i++) null, ...ys];
    final wed = path.any(
      (p) => p.contains('嫁がせた') || p.contains('縁組に出した'),
    );
    bool girlName(String s) => kGivenF.contains(s) || kHimeNames.contains(s);
    // 役割 → （性別〔null は名で見る〕, 行き先）
    final roles = <String, (bool?, String)>{
      '嫡男': (false, KidFate.home),
      '養子': (null, KidFate.home),
      '子': (null, KidFate.home),
      '娘': (true, wed ? KidFate.wed : KidFate.home),
      '人質に出した子': (null, KidFate.hostage),
      '人質の子': (null, KidFate.hostage),
      '旅立った子': (null, KidFate.away),
      '勘当した子': (null, KidFate.disowned),
      '出奔した子': (null, KidFate.fled),
      '寺に入った子': (null, KidFate.temple),
      '奉公に出た娘': (true, KidFate.service),
      '引き取った子': (null, KidFate.home),
    };
    var i = 0;
    final seen = <String>{};
    for (final e in roles.entries) {
      final p = people[e.key];
      if (p == null) continue;
      if (seen.contains(p.name)) continue;
      if (i >= slots.length) {
        // 子の数より多い役割は、亡くした子を指したまま残っていたもの。
        people.remove(e.key);
        continue;
      }
      seen.add(p.name);
      final k = _newKid(
        slots[i++],
        female: e.value.$1 ?? girlName(p.name),
        name: p.name,
        adopted: e.key == '養子',
      );
      k.fate = e.value.$2;
    }
    for (; i < slots.length; i++) {
      _newKid(slots[i]);
    }
  }

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
    'kidYears': kidYears.toList(),
    'children': children.map((e) => e.toJson()).toList(),
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
    // 子の記録。無い古い保存（数と生まれた年だけ）は、縁のある人の名と合わせて補う。
    final cs = j['children'] as List?;
    if (cs != null) {
      l.children.addAll(cs.map((e) => Kid.fromJson(e as Map<String, dynamic>)));
    } else {
      l._kidsFromOldSave(
        j['kids'] as int,
        ((j['kidYears'] as List?) ?? const []).cast<int>(),
      );
    }
    return l;
  }
}
