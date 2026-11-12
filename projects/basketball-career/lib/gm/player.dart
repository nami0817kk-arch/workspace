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

/// 背番号(0〜99。選手の id から決まる)。
int jerseyOf(Player p) => (p.id * 37 + 11) % 100;

/// けがの部位。
const injuryParts = ['足首', '膝', 'ふくらはぎ', '太もも', '腰', '肩', '手首', '指', '脳しんとう', '背中'];

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
  Stats({
    this.gp = 0,
    this.pts = 0,
    this.reb = 0,
    this.ast = 0,
    this.min = 0,
    this.fgm = 0,
    this.fga = 0,
    this.tpm = 0,
    this.tpa = 0,
    this.ftm = 0,
    this.fta = 0,
    this.stl = 0,
    this.blk = 0,
    this.tov = 0,
  });
  int gp, pts, reb, ast;

  /// 出場時間・シュートの成功と試投(全体・3ポイント・フリースロー)・スティール・ブロック・ミス(ターンオーバー)。
  int min, fgm, fga, tpm, tpa, ftm, fta, stl, blk, tov;

  double per(int v) => gp == 0 ? 0 : v / gp;
  double get ppg => per(pts);
  double get rpg => per(reb);
  double get apg => per(ast);
  double get mpg => per(min);
  double get spg => per(stl);
  double get bpg => per(blk);
  double get tpg => per(tov);

  /// 成功率(0〜1)。試投が無ければ0。
  double get fgPct => fga == 0 ? 0 : fgm / fga;
  double get tpPct => tpa == 0 ? 0 : tpm / tpa;
  double get ftPct => fta == 0 ? 0 : ftm / fta;

  /// 「18.2点 6.1リバウンド 3.4アシスト」を短く。
  String get line => gp == 0 ? '' : '${ppg.toStringAsFixed(1)}点 ${rpg.toStringAsFixed(1)}リ ${apg.toStringAsFixed(1)}ア';

  List<int> toJson() => [gp, pts, reb, ast, min, fgm, fga, tpm, tpa, ftm, fta, stl, blk, tov];
  static Stats fromJson(Object? j) {
    // 前の版の保存は4つ(試合・点・リバウンド・アシスト)だけ。足りない所は0
    final l = j is List ? j : const [];
    int at(int i) => i < l.length ? l[i] as int : 0;
    return Stats(
      gp: at(0),
      pts: at(1),
      reb: at(2),
      ast: at(3),
      min: at(4),
      fgm: at(5),
      fga: at(6),
      tpm: at(7),
      tpa: at(8),
      ftm: at(9),
      fta: at(10),
      stl: at(11),
      blk: at(12),
      tov: at(13),
    );
  }
}

/// お金の単位は「10万ドル」(10 = 100万ドル)。画面では「4900万ドル」「1.6億ドル」のように見せる([money])。
///
/// 金額は 2026-27 シーズンの公式の値(NBA の発表: 上限 1億6,496万ドル・税 2億43万ドル・第1の壁 2億901万ドル・第2の壁 2億2,168万ドル)。
/// https://pr.nba.com/2026-27-salary-cap/
const salaryCap = 1650;

/// 旧い版(上限 1.4億ドル)の金額を、いまの上限に合わせて直す倍率。収入・チームの作り方など、旧い数字に合わせて調整した値に掛ける。
const capScale = 1650 / 1400;

/// 旧い版の金額(10万ドル)を、いまの上限に合わせて直す。
int capScaled(num legacy) => (legacy * capScale).round();

/// これを超えた分にはぜいたく税がかかり、シーズンの終わりにオーナーの信頼が下がる([luxuryTaxTrust])。
const taxLine = 2004;

/// 第1の壁。これを超えるチームは、トレードで受け取る年俸を出す年俸の110%までにしなければならない。
const firstApron = 2090;

/// 第2の壁。これを超えるチームは、トレードで複数の選手の年俸を合わせて受け取る年俸に当てられない
/// (受け取る年俸は、出す選手のうち最も高い1人の年俸まで)。年俸の合計に固い上限は無い(再契約はいつでもできる)。
const secondApron = 2217;

/// ぜいたく税で下がる信頼。
int luxuryTaxTrust(int payroll) => payroll <= taxLine ? 0 : ((payroll - taxLine) / 10).ceil();

/// 最低年俸。上限を超えていても、最低年俸の契約はいつでも結べる。
const minSalary = 14;

/// 1人の年俸の上限(いちばん高い段階)。実際の上限は在籍年数で変わる([maxSalaryFor])。
const maxSalary = 577;

/// 在籍年数(プロでの年数)ごとの1人の年俸の上限。上限額の25%(6年まで)・30%(7〜9年)・35%(10年から)。
int maxSalaryFor(int exp) => exp >= 10 ? 577 : exp >= 7 ? 495 : 412;

/// 登録できる人数。
const maxRoster = 15;

/// オフ(ドラフト・契約・シーズン前)は、ここまで抱えてよい。シーズンを始めるまでに [maxRoster] 人にする。
const offseasonRoster = 17;

/// 中くらいの例外枠(第1の壁までの間なら、上限を超えていても使える)の年俸の上限。上限額の約9%。
const mleSalary = 150;

/// 自分の選手との再契約・延長で付く、毎年の昇給(%)。
const ownRaisePct = 5;

/// 自分の選手と結べる最長の契約年数(ほかは4年まで)。
const ownMaxYears = 5;

/// 課税者向けの中くらいの例外枠(第1の壁を超えるチーム用)の年俸の上限。上限額の約3.7%。
const taxMleSalary = 61;

/// 2年ごとの例外枠(第1の壁までの間なら使える。前の年に使っていなければ)の年俸の上限。上限額の約3.3%。
const biennialSalary = 54;

/// 2ウェイ契約の選手を抱えられる人数。登録の [maxRoster] 人には数えない。
const twoWayMax = 3;

/// 2ウェイ契約の年俸(上限にも合計にも数えない。オーナーの支出には入る)。
const twoWaySalary = 7;

/// 10日契約の長さ(試合数)と、そのあいだの年俸の合計への数え方(最低年俸の日割り)。
const tenDayRounds = 5;
const tenDaySalary = 3;

/// 2ウェイ契約にできる、リーグでの年数の上限(若手のための契約)。
const twoWayMaxExp = 3;

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
  var s = minSalary + over * over * 0.9 * capScale;
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
    this.injured = 0,
    this.injPart = -1,
    this.injCount = 0,
    this.allStars = 0,
    this.nextSalary,
    this.optionYears = 0,
    this.tenure = 0,
    this.tenDay = 0,
    this.guarantee = 100,
    this.tenDayCount = 0,
    this.raise = 0,
    List<List<int>>? career,
    this.focus,
  })  : career = career ?? [],
        attrs = attrs ?? makeAttrs(pos, _idNoise(id)),
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

  /// けがで休む残りの試合数(0なら出られる)。
  int injured;

  /// 今のけがの部位([injuryParts] の番号。-1 は無し)。
  int injPart;

  /// これまでのけがの回数(繰り返すとけがしがちと言われる)。
  int injCount;

  /// 今のけがの重さ(軽い・中くらい・重い)。
  String get injurySeverity => injured <= 3 ? '軽い' : injured <= 14 ? '中くらい' : '重い';

  /// けがの説明(部位・重さ・残り)。けがをしていなければ空。
  String get injuryText => injured <= 0 || injPart < 0 ? '' : '${injuryParts[injPart % injuryParts.length]}の$injurySeverityけが・あと$injured試合';

  /// オールスターに選ばれた回数。
  int allStars;

  /// 延長した契約の、来季からの年俸(延長していなければ null)。
  int? nextSalary;

  /// 契約の最後の何年がチームの選択権か(1巡目の新人は4年のうち最後の2年。0なら無い)。
  /// 残りの年数がこれと同じになるオフに、チームが次の年を使うか決める。
  int optionYears;

  /// 今のチームで過ごしたシーズン数(移籍・自由契約で取り直すと0。バード権の段階を決める)。
  int tenure;

  /// 10日契約の残りの節の数(0は10日契約ではない)。
  int tenDay;

  /// 契約の2年目以降の保証(%)。100は全額保証。50なら、放したときに2年目以降の年俸は半分だけ残る。
  int guarantee;

  /// 今季に自分のチームと10日契約を結んだ回数(3回目は今季の契約にするしかない)。
  int tenDayCount;

  /// 毎年の昇給(%)。再契約と延長で付く(自分の選手5%)。契約の途中で年俸が上がっていく。
  int raise;

  /// 練習の重点(自分のチームだけ。オフに、この能力が伸びてほかが少し落ちる)。
  Attr? focus;

  /// このリーグでの年ごとの成績([シーズン, チーム, 試合, 得点, リバウンド, アシスト]、古い順)。
  final List<List<int>> career;

  /// 通算の成績。
  Stats get careerTotals => Stats(
        gp: career.fold(0, (n, r) => n + r[2]),
        pts: career.fold(0, (n, r) => n + r[3]),
        reb: career.fold(0, (n, r) => n + r[4]),
        ast: career.fold(0, (n, r) => n + r[5]),
      );

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
        if (injured != 0) 'in': injured,
        if (injPart != -1) 'ip': injPart,
        if (injCount != 0) 'ic': injCount,
        if (allStars != 0) 'as': allStars,
        if (nextSalary != null) 'ns': nextSalary,
        if (optionYears != 0) 'op': optionYears,
        if (tenure != 0) 'tn': tenure,
        if (tenDay != 0) 'td': tenDay,
        if (guarantee != 100) 'gr': guarantee,
        if (tenDayCount != 0) 'tc': tenDayCount,
        if (raise != 0) 'rz': raise,
        if (career.isNotEmpty) 'cr': career,
        if (focus != null) 'fo': focus!.index,
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
        injured: ((j['in'] as int?) ?? 0).clamp(0, 99),
        injPart: ((j['ip'] as int?) ?? -1).clamp(-1, 99),
        injCount: ((j['ic'] as int?) ?? 0).clamp(0, 99),
        allStars: (j['as'] as int?) ?? 0,
        nextSalary: j['ns'] as int?,
        optionYears: ((j['op'] as int?) ?? 0).clamp(0, 4),
        tenure: ((j['tn'] as int?) ?? 0).clamp(0, 30),
        tenDay: ((j['td'] as int?) ?? 0).clamp(0, 20),
        guarantee: ((j['gr'] as int?) ?? 100).clamp(0, 100),
        tenDayCount: ((j['tc'] as int?) ?? 0).clamp(0, 5),
        raise: ((j['rz'] as int?) ?? 0).clamp(0, 8),
        focus: j['fo'] is int && (j['fo'] as int) >= 0 && (j['fo'] as int) < Attr.values.length ? Attr.values[j['fo'] as int] : null,
        career: [
          for (final r in (j['cr'] as List? ?? const []))
            if (r is List && r.length == 6) [for (final x in r) x as int],
        ],
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

/// 選手の型(能力の偏りとポジションから決まる)。
String archetypeOf(Player p) {
  int a(Attr x) => p.attrs[x.index];
  final out = a(Attr.outside), ins = a(Attr.inside), pas = a(Attr.passing), reb = a(Attr.rebound), def = a(Attr.defense), ath = a(Attr.athletic);
  if (p.pos.big) {
    if (out >= -3 && out >= ins - 6) return 'ストレッチビッグ';
    if (pas >= -1) return 'プレーメイクビッグ';
    if (def + reb >= ins * 2 + 4) return 'リムプロテクター';
    return 'ポストスコアラー';
  }
  if (p.pos == Pos.pg && pas >= out) return 'プレーメーカー';
  if (def >= 2 && out >= 3) return '3&D';
  if (ath >= 4 && ins >= out - 2) return 'スラッシャー';
  if (out >= 6) return 'シューター';
  if (def >= 3) return 'ディフェンダー';
  return p.pos == Pos.sf ? 'ツーウェイ' : 'スコアラー';
}

/// 特性のバッジ。能力の値が高いほど、銅・銀・金・殿堂と上がる。
const badgeNames = {
  Attr.outside: 'シューター',
  Attr.inside: 'フィニッシャー',
  Attr.passing: '司令塔',
  Attr.rebound: 'リバウンダー',
  Attr.defense: '鉄壁',
  Attr.athletic: '身体能力',
};

const badgeTiers = ['銅', '銀', '金', '殿堂'];

/// 選手の持つバッジ(名前と段階0〜3)。段階の高い順。
List<(String, int)> badgesOf(Player p) {
  final out = <(String, int)>[];
  for (final a in Attr.values) {
    final v = p.attr(a);
    final tier = v >= 96
        ? 3
        : v >= 90
            ? 2
            : v >= 84
                ? 1
                : v >= 78
                    ? 0
                    : -1;
    if (tier >= 0) out.add((badgeNames[a]!, tier));
  }
  out.sort((x, y) => y.$2.compareTo(x.$2));
  return out;
}

/// 画面に見せる力の数字(2K のような幅: 控えは70前後、主力は80台、スターは90台)。
/// 試合や年俸の計算は、もとの数字([Player.ovr] など)で行う。
int shown(int v) => (39 + v * 0.62).round().clamp(40, 99);

/// 細かい能力(画面に見せるだけ。試合の計算は大きな分類 [Attr] で行う)。
/// [tweak] はポジションごとのずれ(PG・SG・SF・PF・C の順)。
class SubRating {
  const SubRating(this.label, this.attr, this.tweak);
  final String label;
  final Attr attr;
  final List<int> tweak;
}

const subRatings = <SubRating>[
  SubRating('3ポイント', Attr.outside, [2, 3, 0, -2, -6]),
  SubRating('ミドルレンジ', Attr.outside, [0, 2, 1, 0, -3]),
  SubRating('フリースロー', Attr.outside, [3, 3, 0, -2, -6]),
  SubRating('シュートの安定', Attr.outside, [0, 0, 0, 0, 0]),
  SubRating('レイアップ', Attr.inside, [2, 1, 1, -1, -3]),
  SubRating('ダンク', Attr.inside, [-10, -5, 0, 4, 6]),
  SubRating('ポストの技', Attr.inside, [-8, -5, 0, 4, 6]),
  SubRating('ゴール下', Attr.inside, [-4, -2, 0, 3, 5]),
  SubRating('パスの正確さ', Attr.passing, [2, 0, 0, 0, -2]),
  SubRating('ボール運び', Attr.passing, [4, 2, 0, -6, -10]),
  SubRating('ドリブルの速さ', Attr.passing, [4, 2, 0, -5, -9]),
  SubRating('視野', Attr.passing, [2, 0, 0, 0, 0]),
  SubRating('攻めのリバウンド', Attr.rebound, [-3, -2, 0, 2, 3]),
  SubRating('守りのリバウンド', Attr.rebound, [-2, -1, 0, 2, 4]),
  SubRating('外の守り', Attr.defense, [4, 3, 2, -3, -8]),
  SubRating('中の守り', Attr.defense, [-8, -5, 0, 4, 8]),
  SubRating('スティール', Attr.defense, [4, 3, 1, -2, -5]),
  SubRating('ブロック', Attr.defense, [-10, -6, 0, 5, 9]),
  SubRating('守りの判断', Attr.defense, [0, 0, 0, 0, 0]),
  SubRating('スピード', Attr.athletic, [5, 3, 0, -4, -8]),
  SubRating('加速', Attr.athletic, [5, 3, 0, -4, -7]),
  SubRating('跳躍', Attr.athletic, [0, 1, 1, 0, -1]),
  SubRating('力強さ', Attr.athletic, [-8, -5, 0, 5, 9]),
  SubRating('スタミナ', Attr.athletic, [2, 1, 0, -1, -2]),
  // 2026-11-12: 35項目にそろえるための追加(見せる数字だけ。試合の強さは6つの能力から)
  SubRating('キャッチ&シュート', Attr.outside, [2, 2, 1, -1, -4]),
  SubRating('ドリブルからのシュート', Attr.outside, [3, 2, 0, -3, -6]),
  SubRating('フィンガーロール', Attr.inside, [1, 1, 0, 0, -1]),
  SubRating('ファウルのもらいやすさ', Attr.inside, [2, 2, 0, 1, 2]),
  SubRating('ターンオーバーの少なさ', Attr.passing, [3, 2, 0, -2, -5]),
  SubRating('セカンドチャンス', Attr.rebound, [-3, -1, 0, 2, 4]),
  SubRating('ボックスアウト', Attr.rebound, [-5, -3, 0, 3, 6]),
  SubRating('ポストでの守り', Attr.defense, [-9, -6, 0, 5, 9]),
  SubRating('ピック&ロールの守り', Attr.defense, [0, 1, 1, 0, -1]),
  SubRating('ヘルプの守り', Attr.defense, [-4, -2, 0, 3, 5]),
  SubRating('ハッスル', Attr.athletic, [1, 1, 1, 1, 1]),
];

/// 細かい能力の値(画面に見せる数字)。選手ごとに id から決まる揺らぎが付く。
int subRating(Player p, SubRating s) {
  final i = subRatings.indexOf(s);
  final x = ((p.id * 2654435761 + i * 40503) & 0xFFFFFFFF) >> 13;
  final noise = x % 11 - 5;
  return shown((p.attr(s.attr) + s.tweak[p.pos.index] + noise).clamp(25, 99));
}

/// 身長(cm)・体重(kg)・ウイングスパン(cm)。ポジションと id から決まる。
(int, int, int) physicalOf(Player p) {
  const base = {Pos.pg: 187, Pos.sg: 193, Pos.sf: 201, Pos.pf: 206, Pos.c: 211};
  final x = (p.id * 2246822519) & 0xFFFFFFFF;
  final h = base[p.pos]! + (x % 9) - 3;
  final w = (h - 100) + ((x >> 8) % 14) - 4;
  final span = h + ((x >> 16) % 13) - 2;
  return (h, w, span);
}

/// 伸びきったときの見込みの数字(5刻みの幅)。
(int, int) potentialRange(Player p) {
  final v = shown(p.pot);
  final lo = v ~/ 5 * 5;
  return (lo, (lo + 5).clamp(0, 99));
}
