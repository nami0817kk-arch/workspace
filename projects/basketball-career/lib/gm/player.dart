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
  });

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
      );
}

/// オフに1年分の成長・衰えを入れる。力の変化を返す。
int ageOneYear(Player p, Rng rng) {
  p.age++;
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
