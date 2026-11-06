import 'dart:math' as math;

import 'rng.dart';

/// ポジション。ガード(PG・SG)、ウイング(SF)、ビッグ(PF・C)。
enum Pos {
  pg('PG', 'ポイントガード'),
  sg('SG', 'シューティングガード'),
  sf('SF', 'スモールフォワード'),
  pf('PF', 'パワーフォワード'),
  c('C', 'センター');

  const Pos(this.short, this.label);
  final String short;
  final String label;

  bool get guard => this == pg || this == sg;
  bool get big => this == pf || this == c;
}

/// 能力の内訳(6つ)。表示する値は「力＋ずれ」([Player.attr])。
enum Attr {
  outside('外のシュート'),
  inside('中の得点'),
  passing('パス'),
  rebound('リバウンド'),
  defense('守り'),
  athletic('運動能力');

  const Attr(this.label);
  final String label;
}

/// ポジションごとの能力のずれ(外・中・パス・リバウンド・守り・運動)。
const _posProfile = <Pos, List<int>>{
  Pos.pg: [4, -3, 9, -9, 0, 3],
  Pos.sg: [8, 0, 2, -6, 0, 2],
  Pos.sf: [2, 2, 0, 0, 2, 2],
  Pos.pf: [-4, 5, -3, 6, 2, 0],
  Pos.c: [-9, 7, -5, 9, 4, -2],
};

/// 能力のずれを作る。[noise] は 0〜10 の数を6つ返す関数(種から決まる乱数)。
List<int> makeAttrs(Pos pos, int Function() noise) => [for (final b in _posProfile[pos]!) b + noise() - 5];

/// 1シーズンの個人成績(合計)。
class Stats {
  Stats({this.gp = 0, this.pts = 0, this.reb = 0, this.ast = 0});
  int gp, pts, reb, ast;

  double per(int v) => gp == 0 ? 0 : v / gp;
  double get ppg => per(pts);
  double get rpg => per(reb);
  double get apg => per(ast);

  /// 「18.2点 6.1リバウンド 3.4アシスト」を短く。
  String get line => gp == 0 ? '' : '${ppg.toStringAsFixed(1)}点 ${rpg.toStringAsFixed(1)}リ ${apg.toStringAsFixed(1)}ア';

  List<int> toJson() => [gp, pts, reb, ast];
  static Stats fromJson(Object? j) {
    final l = j is List ? j : const [];
    int at(int i) => i < l.length ? l[i] as int : 0;
    return Stats(gp: at(0), pts: at(1), reb: at(2), ast: at(3));
  }
}

/// お金の単位は「10万ドル」(10 = 100万ドル)。画面では「4900万ドル」「1.4億ドル」のように見せる([money])。
const salaryCap = 1400;

/// これを超える年俸の合計にはできない(再契約・トレードでも)。
const hardCap = 1890;

/// これを超えた分にはぜいたく税がかかり、シーズンの終わりにオーナーの信頼が下がる([luxuryTaxTrust])。
const taxLine = 1700;

/// ぜいたく税で下がる信頼。
int luxuryTaxTrust(int payroll) => payroll <= taxLine ? 0 : ((payroll - taxLine) / 10).ceil();

/// 最低年俸。上限を超えていても、最低年俸の契約はいつでも結べる。
const minSalary = 12;

/// 1人の年俸の上限。
const maxSalary = 490;

/// 登録できる人数。
const maxRoster = 15;

/// シーズンを始めるのに要る人数。
const minRoster = 10;

/// 10万ドルを「4900万ドル」「1.4億ドル」のように見せる。
String money(int m) {
  if (m.abs() >= 1000) {
    final oku = m / 1000;
    final s = (oku * 10).round() % 10 == 0 ? oku.toStringAsFixed(0) : oku.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');
    return '$s億ドル';
  }
  return '${m * 10}万ドル';
}

/// 力の数字から見た、ふつうの年俸。
int fairSalary(int ovr, int age) {
  final over = math.max(0, ovr - 58);
  var s = minSalary + over * over * 0.9;
  if (age >= 31) s *= 0.85;
  if (age >= 34) s *= 0.8;
  return s.round().clamp(minSalary, maxSalary);
}

/// 伸びしろの大きさ(今の力との差)を、字で見せる。
String potentialGrade(int ovr, int pot, int age) {
  final room = age >= 28 ? 0 : pot - ovr;
  if (room >= 20) return 'S';
  if (room >= 13) return 'A';
  if (room >= 7) return 'B';
  if (room >= 3) return 'C';
  return '-';
}

class Player {
  Player({
    required this.id,
    required this.name,
    required this.pos,
    required this.age,
    required this.ovr,
    required this.pot,
    required this.salary,
    required this.years,
    this.drafted,
    this.lastDelta = 0,
    List<int>? attrs,
    Stats? stats,
    Stats? prev,
    this.exp = 0,
    this.morale = 60,
  })  : attrs = attrs ?? makeAttrs(pos, _idNoise(id)),
        stats = stats ?? Stats(),
        prev = prev ?? Stats();

  /// 保存に能力が無かったとき用: id から決まる揺らぎ。
  static int Function() _idNoise(int id) {
    var x = (id * 2654435761) & 0xFFFFFFFF;
    return () {
      x = (x * 1103515245 + 12345) & 0x7FFFFFFF;
      return (x >> 8) % 11;
    };
  }

  final int id;
  final String name;
  final Pos pos;
  int age;

  /// 今の力(40〜99)。
  int ovr;

  /// 伸びきったときの力。画面には [potentialGrade] でだけ見せる。
  int pot;

  /// 年俸(百万円)。
  int salary;

  /// 契約の残り年数(今のシーズンを含む)。0 は契約切れ。
  int years;

  /// ドラフトで指名したチームの名前(自分のチームの生え抜きを見せるため)。
  String? drafted;

  /// 前のオフに力がいくつ動いたか。
  int lastDelta;

  /// 能力のずれ([Attr] の順)。
  final List<int> attrs;

  /// 今シーズンと前のシーズンの個人成績。
  Stats stats;
  Stats prev;

  /// リーグでの年数(新人は0)。
  int exp;

  /// 気持ち(0〜100)。出場時間が期待より少ない・チームが負けると下がる。低いと再契約で高く求め、20を切ると残らない。
  int morale;

  String get moraleLabel => morale >= 70
      ? '満足'
      : morale >= 45
          ? 'ふつう'
          : morale >= 20
              ? '不満'
              : '移籍したい';

  /// 能力の値(25〜99)。
  int attr(Attr a) => (ovr + attrs[a.index]).clamp(25, 99);

  String get grade => potentialGrade(ovr, pot, age);

  /// 何年か先の見込みの力。
  int get future {
    final f = age <= 21
        ? 0.85
        : age <= 23
            ? 0.65
            : age <= 25
                ? 0.4
                : age <= 27
                    ? 0.15
                    : 0.0;
    var v = ovr + ((pot - ovr) * f).round();
    if (age >= 31) v -= (age - 30) * 2;
    return v;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'n': name,
        'p': pos.index,
        'a': age,
        'o': ovr,
        'pt': pot,
        's': salary,
        'y': years,
        if (drafted != null) 'd': drafted,
        if (lastDelta != 0) 'ld': lastDelta,
        'at': attrs,
        if (stats.gp > 0) 'st': stats.toJson(),
        if (prev.gp > 0) 'pv': prev.toJson(),
        if (exp != 0) 'ex': exp,
        if (morale != 60) 'mo': morale,
      };

  static Player fromJson(Map<String, dynamic> j) => Player(
        id: j['id'] as int,
        name: j['n'] as String,
        pos: Pos.values[(j['p'] as int).clamp(0, Pos.values.length - 1)],
        age: j['a'] as int,
        ovr: j['o'] as int,
        pot: j['pt'] as int,
        salary: j['s'] as int,
        years: j['y'] as int,
        drafted: j['d'] as String?,
        lastDelta: (j['ld'] as int?) ?? 0,
        attrs: j['at'] is List && (j['at'] as List).length == Attr.values.length ? [for (final x in j['at'] as List) x as int] : null,
        stats: Stats.fromJson(j['st']),
        prev: Stats.fromJson(j['pv']),
        exp: (j['ex'] as int?) ?? 0,
        morale: ((j['mo'] as int?) ?? 60).clamp(0, 100),
      );
}

/// オフに1年分の成長・衰えを入れる。力の変化を返す。
int ageOneYear(Player p, Rng rng) {
  p.age++;
  p.exp++;
  final before = p.ovr;
  int d;
  if (p.age <= 22) {
    d = 2 + rng.nextInt(6);
  } else if (p.age <= 25) {
    d = 1 + rng.nextInt(4);
  } else if (p.age <= 28) {
    d = rng.nextInt(3) - 1;
  } else if (p.age <= 31) {
    d = -rng.nextInt(4);
  } else if (p.age <= 33) {
    d = -1 - rng.nextInt(4);
  } else {
    d = -3 - rng.nextInt(5);
  }
  if (d > 0) {
    // 伸びしろに近いほど伸びにくい
    final room = p.pot - p.ovr;
    if (room <= 0) {
      d = rng.chance(0.2) ? 1 : 0;
    } else if (d > room) {
      d = room;
    }
  }
  p.ovr = (p.ovr + d).clamp(35, 99);
  if (p.pot < p.ovr) p.pot = p.ovr;
  p.lastDelta = p.ovr - before;
  return p.lastDelta;
}

/// 引退するか(力が落ちたベテラン)。
bool retires(Player p, Rng rng) {
  if (p.age >= 38) return true;
  if (p.age >= 35 && p.ovr < 66) return true;
  if (p.age >= 33 && p.ovr < 55) return rng.chance(0.6);
  return false;
}
