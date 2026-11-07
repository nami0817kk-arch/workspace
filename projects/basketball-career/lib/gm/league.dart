import 'dart:math' as math;

import 'player.dart';
import 'rng.dart';

/// チームの決まり。都市は実在、愛称は架空(実在のプロのチームの愛称は使わない)。[color] は絵の色の名前。
class TeamDef {
  const TeamDef(this.city, this.nick, this.east, this.color);
  final String city;
  final String nick;

  /// 東地区か(でなければ西地区)。
  final bool east;
  final String color;

  /// 短い呼び名。同じ都市に2チームあるときは愛称も付ける。
  String get short => teamDefs.where((d) => d.city == city).length > 1 ? '$city・$nick' : city;
}

/// 30チームのリーグ。都市・地区・色は NBA にそろえ、愛称は元のチームを思わせる題材の別の言葉にする
/// (実在の愛称はそのまま使わない。商標と審査 5.2)。0 が自分のチーム。
const teamDefs = <TeamDef>[
  TeamDef('シャーロット', 'スティンガーズ', true, 'teal'),
  TeamDef('アトランタ', 'カイツ', true, 'red'),
  TeamDef('ボストン', 'シャムロックス', true, 'green'),
  TeamDef('ブルックリン', 'ブリッジズ', true, 'navy'),
  TeamDef('シカゴ', 'バイソンズ', true, 'red'),
  TeamDef('クリーブランド', 'ナイツ', true, 'purple'),
  TeamDef('デトロイト', 'モーターズ', true, 'blue'),
  TeamDef('インディアナ', 'スピードスターズ', true, 'yellow'),
  TeamDef('マイアミ', 'ブレイズ', true, 'red'),
  TeamDef('ミルウォーキー', 'スタッグス', true, 'lime'),
  TeamDef('ニューヨーク', 'エンパイアズ', true, 'orange'),
  TeamDef('オーランド', 'スペルズ', true, 'blue'),
  TeamDef('フィラデルフィア', 'ファウンダーズ', true, 'blue'),
  TeamDef('トロント', 'ダイノス', true, 'purple'),
  TeamDef('ワシントン', 'ソーサラーズ', true, 'navy'),
  TeamDef('ダラス', 'アウトローズ', false, 'sky'),
  TeamDef('デンバー', 'プロスペクターズ', false, 'yellow'),
  TeamDef('サンフランシスコ', 'センチネルズ', false, 'yellow'),
  TeamDef('ヒューストン', 'オービッツ', false, 'red'),
  TeamDef('ロサンゼルス', 'スクーナーズ', false, 'blue'),
  TeamDef('ロサンゼルス', 'ショータイム', false, 'purple'),
  TeamDef('メンフィス', 'コディアックス', false, 'sky'),
  TeamDef('ミネソタ', 'ハウラーズ', false, 'green'),
  TeamDef('ニューオーリンズ', 'ヘロンズ', false, 'navy'),
  TeamDef('オクラホマシティ', 'トルネードズ', false, 'sky'),
  TeamDef('フェニックス', 'フレアーズ', false, 'orange'),
  TeamDef('ポートランド', 'パスファインダーズ', false, 'red'),
  TeamDef('サクラメント', 'クラウンズ', false, 'purple'),
  TeamDef('サンアントニオ', 'ラングラーズ', false, 'navy'),
  TeamDef('ユタ', 'リズムズ', false, 'lime'),
];

/// 1シーズンは82試合。4つの区切り(20・21・20・21試合)で進める。
const blockSizes = [20, 21, 20, 21];
const blocksPerSeason = 4;
const gamesPerSeason = 82;

/// [block] 番目の区切りが始まる節(0始まり)。
int blockStart(int block) => blockSizes.take(block).fold(0, (s, n) => s + n);

/// トレードの締め切り(この区切りまで終えたら、シーズン中のトレードはできない)。41試合目のあと。
const tradeDeadlineBlock = 2;

/// 地区ごとに、プレーオフへそのまま進む数と、プレーインに出る数(7〜10位)。
const directSeeds = 6;
const playInSeeds = 10;

/// スタッフ(コーチ陣)。段階が上がるほど効くが、給料も高い。保存は番号なので、足すときは後ろに。
enum Staff {
  coach('ヘッドコーチ', '試合の采配(チームの強さ)'),
  trainer('トレーナー', 'けがの少なさ・治りの早さ'),
  scout('スカウト', 'ドラフトで送れるスカウトの数'),
  development('育成コーチ', '若手の伸び・練習の重点');

  const Staff(this.label, this.effect);
  final String label;
  final String effect;
}

/// スタッフの段階ごとの1シーズンの給料(10万ドル)。名前のあるコーチを雇っていないチームの分。
const staffCosts = [10, 30, 60];

/// 名前と力のあるコーチ(自分のチームだけが雇う。ほかのチームは段階だけ)。
class Coach {
  const Coach({required this.name, required this.role, required this.rating});
  final String name;
  final Staff role;

  /// 力(40〜99)。80以上が一流、65以上が良い。
  final int rating;

  int get level => rating >= 80
      ? 3
      : rating >= 65
          ? 2
          : 1;

  /// 1シーズンの給料(10万ドル)。力が高いほど、ぐっと高くなる。
  int get salary => math.max(5, ((rating - 45) * (rating - 45) / 30).round());

  Map<String, dynamic> toJson() => {'n': name, 'r': role.index, 'v': rating};
  static Coach fromJson(Map<String, dynamic> j) => Coach(
        name: j['n'] as String,
        role: Staff.values[((j['r'] as int?) ?? 0).clamp(0, Staff.values.length - 1)],
        rating: ((j['v'] as int?) ?? 65).clamp(40, 99),
      );
}

/// 1試合の出場時間の合計(5人×48分)と、1人の上限。[fatigueLine] を超えると疲れる。
const totalMinutes = 240;
const maxMinutes = 44;
const fatigueLine = 36;

/// チームの考え方。トレードで欲しがるものが変わる。
enum TeamMode {
  contend('優勝を狙う', '今すぐ勝てる選手が欲しい'),
  balanced('上を目指す', '力と年俸の釣り合う選手が欲しい'),
  rebuild('立て直し中', '若手とドラフトの指名権が欲しい'),
  cutCost('年俸を減らしたい', '年俸の軽い選手か、契約の短い選手が欲しい');

  const TeamMode(this.label, this.wants);
  final String label;
  final String wants;
}

class Team {
  Team({required this.index, required this.roster, this.wins = 0, this.losses = 0, this.mode = TeamMode.balanced, this.deadCap = 0, List<int>? rotation, List<int>? staff})
      : rotation = rotation ?? [],
        staff = staff ?? [2, 2, 2, 2];

  final int index;
  final List<Player> roster;
  int wins;
  int losses;
  TeamMode mode;

  /// 放出した選手の、今シーズン分の年俸(今季の合計に数える)。
  int deadCap;

  /// スタッフの段階(1〜3)。[Staff] の順(コーチ・トレーナー・スカウト)。
  List<int> staff;

  /// 練習の強さ(0: 軽め、1: ふつう、2: きつい)。自分のチームだけが変える。
  int training = 1;

  /// 雇っているコーチ(自分のチームだけ)。いない役は [staff] の段階で数える。
  List<Coach> coaches = [];

  Coach? coachOf(Staff s) => coaches.where((c) => c.role == s).firstOrNull;

  int staffLevel(Staff s) => coachOf(s)?.level ?? (s.index < staff.length ? staff[s.index] : 2).clamp(1, 3);

  /// スタッフに払う1シーズンの給料(10万ドル)。
  int get staffCost => [for (final s in Staff.values) coachOf(s)?.salary ?? staffCosts[staffLevel(s) - 1]].fold(0, (a, b) => a + b);

  /// ヘッドコーチの采配で足される強さ。名前のあるコーチは力から、ほかは段階から。
  double get coachBonus {
    final c = coachOf(Staff.coach);
    if (c != null) return (c.rating - 70) * 0.03;
    return const [-0.4, 0.0, 0.4][staffLevel(Staff.coach) - 1];
  }

  /// 選手ごとの出場時間(選手の id → 分)。空なら出場の順で自動([minutesByOrder])。
  Map<int, int> minutes = {};

  /// 1試合の出場時間([order] の順)。決めた時間の合計が足りない(けが・移籍)ときは上から足し、多いときは下から削る。
  List<int> playMinutes() {
    final o = order;
    // 自動のときも、出られる選手が少ない(けが人が多い)と時間が余るので、上から足して240分にする
    final m = minutes.isEmpty
        ? [for (var i = 0; i < o.length; i++) i < minutesByOrder.length && o[i].injured == 0 ? minutesByOrder[i] : 0]
        : [for (final p in o) p.injured == 0 ? (minutes[p.id] ?? 0).clamp(0, maxMinutes) : 0];
    var total = m.fold(0, (a, b) => a + b);
    for (var i = 0; i < m.length && total < totalMinutes; i++) {
      if (o[i].injured > 0) continue;
      final add = math.min(totalMinutes - total, maxMinutes - m[i]);
      if (add > 0) {
        m[i] += add;
        total += add;
      }
    }
    for (var i = m.length - 1; i >= 0 && total > totalMinutes; i--) {
      final cut = math.min(total - totalMinutes, m[i]);
      m[i] -= cut;
      total -= cut;
    }
    return m;
  }

  /// 出場時間を決めたときの強さの差。時間で重みを付けた力を、自動の時間のときと比べる。
  /// [fatigueLine] を超えた分は、1分ごとに力が0.8落ちたものとして数える。
  double get minutesEffect {
    if (minutes.isEmpty) return 0;
    final o = order.where((p) => p.injured == 0).toList();
    final m = playMinutes();
    double avg(int Function(int) at) {
      var s = 0.0;
      for (var i = 0; i < o.length; i++) {
        final mm = at(i);
        s += (o[i].ovr - math.max(0, mm - fatigueLine) * 0.8) * mm;
      }
      return s / totalMinutes;
    }

    return avg((i) => m[i]) - avg((i) => i < minutesByOrder.length ? minutesByOrder[i] : 0);
  }

  /// けがをしていない選手。
  List<Player> get healthy => [for (final p in roster) if (p.injured == 0) p];

  /// 連勝(+)・連敗(-)。
  int streak = 0;

  /// 先発と控えの順(選手の id)。空なら自動(力の高い順に、ガードとビッグを先発に入れる)。
  List<int> rotation;

  /// 出場の順(先発5人、控えの順)。[rotation] にいない選手は自動の順で後ろに付く。
  /// けがの選手は出られないので、いちばん後ろに回す。
  List<Player> get order {
    final auto = lineup(healthy);
    final hurt = [for (final p in roster) if (p.injured > 0) p];
    if (rotation.isEmpty) return [...auto, ...hurt];
    final byId = {for (final p in healthy) p.id: p};
    final fixed = [for (final id in rotation) if (byId[id] != null) byId[id]!];
    return [...fixed, ...auto.where((p) => !fixed.contains(p)), ...hurt];
  }

  TeamDef get def => teamDefs[index];
  String get city => def.city;
  String get nick => def.nick;
  String get name => '$city・$nick';
  bool get east => def.east;

  int get payroll => roster.fold(0, (s, p) => s + p.salary) + deadCap;
  int get capRoom => salaryCap - payroll;

  double get winPct => wins + losses == 0 ? 0 : wins / (wins + losses);

  /// チームの強さ。力の高い順に9人を重み付きで平均し、ガードとビッグがいなければ下げる。
  /// 自分で順を決めたときは、その順で数える(力の低い選手を先発にすると弱くなる)。
  double get strength =>
      (rotation.isEmpty && minutes.isEmpty ? teamStrength(healthy) : orderStrength(order.where((p) => p.injured == 0).toList())) + minutesEffect + coachBonus;

  Map<String, dynamic> toJson() => {
        'i': index,
        'r': [for (final p in roster) p.toJson()],
        'w': wins,
        'l': losses,
        'm': mode.index,
        if (deadCap != 0) 'dc': deadCap,
        if (rotation.isNotEmpty) 'ro': rotation,
        'sf': staff,
        if (streak != 0) 'sk': streak,
        if (training != 1) 'tr': training,
        if (coaches.isNotEmpty) 'co': [for (final c in coaches) c.toJson()],
        if (minutes.isNotEmpty) 'mn': [for (final e in minutes.entries) [e.key, e.value]],
      };

  static Team fromJson(Map<String, dynamic> j) => _fromJson(j)
    ..streak = (j['sk'] as int?) ?? 0
    ..training = ((j['tr'] as int?) ?? 1).clamp(0, 2)
    ..coaches = [for (final c in (j['co'] as List? ?? const [])) Coach.fromJson(Map<String, dynamic>.from(c as Map))]
    ..minutes = {
      for (final e in (j['mn'] as List? ?? const []))
        if (e is List && e.length == 2) e[0] as int: (e[1] as int).clamp(0, maxMinutes),
    };

  static Team _fromJson(Map<String, dynamic> j) => Team(
        index: j['i'] as int,
        roster: [for (final p in j['r'] as List) Player.fromJson(Map<String, dynamic>.from(p as Map))],
        wins: j['w'] as int,
        losses: j['l'] as int,
        mode: TeamMode.values[((j['m'] as int?) ?? 1).clamp(0, TeamMode.values.length - 1)],
        deadCap: (j['dc'] as int?) ?? 0,
        rotation: [for (final x in (j['ro'] as List? ?? const [])) x as int],
        // 前の版の保存は3役(育成コーチが無い)。足りない役はふつう
        staff: j['sf'] is List && (j['sf'] as List).isNotEmpty
            ? [for (var i = 0; i < Staff.values.length; i++) i < (j['sf'] as List).length ? ((j['sf'] as List)[i] as int).clamp(1, 3) : 2]
            : null,
      );
}

/// 首位とのゲーム差。
double gamesBehind(Team leader, Team t) => ((leader.wins - t.wins) + (t.losses - leader.losses)) / 2;

String streakLabel(int s) => s == 0 ? '-' : s > 0 ? '$s連勝' : '${-s}連敗';

/// 勝ち数の見せ方。
String record(Team t) => '${t.wins}勝${t.losses}敗';

const _weights = [1.0, 1.0, 0.95, 0.9, 0.85, 0.6, 0.45, 0.35, 0.2];

double teamStrength(List<Player> roster) {
  final sorted = [...roster]..sort((a, b) => b.ovr.compareTo(a.ovr));
  var sum = 0.0, wsum = 0.0;
  for (var i = 0; i < _weights.length; i++) {
    final o = i < sorted.length ? sorted[i].ovr : 38;
    sum += o * _weights[i];
    wsum += _weights[i];
  }
  var s = sum / wsum;
  final top = sorted.take(5);
  if (!top.any((p) => p.pos.guard)) s -= 2.5;
  if (!top.any((p) => p.pos.big)) s -= 2.5;
  return s;
}

/// 決めた順のままの強さ(上から重みを付ける)。先発にガードとビッグがいなければ下げる。
double orderStrength(List<Player> order) {
  var sum = 0.0, wsum = 0.0;
  for (var i = 0; i < _weights.length; i++) {
    final o = i < order.length ? order[i].ovr : 38;
    sum += o * _weights[i];
    wsum += _weights[i];
  }
  var s = sum / wsum;
  final top = order.take(5);
  if (!top.any((p) => p.pos.guard)) s -= 2.5;
  if (!top.any((p) => p.pos.big)) s -= 2.5;
  return s;
}

/// 先発の5人(ポジションが偏らないように選ぶ)と、控え。
List<Player> lineup(List<Player> roster) {
  final sorted = [...roster]..sort((a, b) => b.ovr.compareTo(a.ovr));
  final starters = <Player>[];
  void take(bool Function(Player) f) {
    for (final p in sorted) {
      if (!starters.contains(p) && f(p)) {
        starters.add(p);
        return;
      }
    }
  }

  take((p) => p.pos.guard);
  take((p) => p.pos.big);
  while (starters.length < 5 && starters.length < sorted.length) {
    take((_) => true);
  }
  return [...starters, ...sorted.where((p) => !starters.contains(p))];
}

/// 1試合の結果。
/// ボックススコアの1行(自分のチームの試合だけ残す)。
class BoxLine {
  const BoxLine(this.name, this.pos, this.min, this.pts, this.reb, this.ast,
      {this.fgm = 0, this.fga = 0, this.tpm = 0, this.tpa = 0, this.ftm = 0, this.fta = 0, this.stl = 0, this.blk = 0, this.tov = 0, this.pm = 0});
  final String name;
  final String pos;
  final int min, pts, reb, ast;
  final int fgm, fga, tpm, tpa, ftm, fta, stl, blk, tov;

  /// 出ているあいだの点差(プラスマイナス)。
  final int pm;

  /// 試合の働き(ゲームスコア。点・シュート・リバウンド・アシスト・スティール・ブロック・ミスから)。試合の最優秀選手を選ぶのに使う。
  double get gameScore => pts + 0.4 * fgm - 0.7 * fga - 0.4 * (fta - ftm) + 0.5 * reb + stl + 0.7 * ast + 0.7 * blk - tov;

  List<Object> toJson() => [name, pos, min, pts, reb, ast, fgm, fga, tpm, tpa, ftm, fta, stl, blk, tov, pm];
  static BoxLine fromJson(List j) {
    // 前の版の保存は6つだけ
    int at(int i) => i < j.length ? j[i] as int : 0;
    return BoxLine(j[0] as String, j[1] as String, at(2), at(3), at(4), at(5),
        fgm: at(6), fga: at(7), tpm: at(8), tpa: at(9), ftm: at(10), fta: at(11), stl: at(12), blk: at(13), tov: at(14), pm: at(15));
  }
}

/// 点から、シュートの内訳(成功と試投)を決める。点の合計は変えない。外のシュートが高いほど3ポイントが多く、よく入る。
({int fgm, int fga, int tpm, int tpa, int ftm, int fta}) shootingOf(Player p, int pts, Rng r) {
  final out = p.attr(Attr.outside), ins = p.attr(Attr.inside);
  final share3 = ((out - 55) / 90 + (p.pos.guard ? 0.12 : p.pos == Pos.c ? -0.15 : 0)).clamp(0.0, 0.42);
  var tpm = (pts * share3 / 3 * (0.7 + r.nextInt(60) / 100)).round();
  tpm = math.min(tpm, pts ~/ 3);
  final ftShare = (0.12 + (ins - 60) / 400).clamp(0.06, 0.25);
  var ftm = math.min((pts * ftShare * (0.6 + r.nextInt(80) / 100)).round(), pts - 3 * tpm);
  var rest = pts - 3 * tpm - ftm;
  if (rest.isOdd) {
    ftm++;
    rest--;
  }
  final twom = rest ~/ 2;
  final p2 = (0.46 + (ins - 70) / 250).clamp(0.38, 0.62);
  final p3 = (0.34 + (out - 70) / 250).clamp(0.22, 0.45);
  final pft = (0.74 + (out - 70) / 200).clamp(0.5, 0.92);
  final twoA = twom == 0 ? r.nextInt(3) : math.max(twom, (twom / p2 * (0.9 + r.nextInt(20) / 100)).round());
  final tpa = tpm == 0 ? (share3 > 0.1 ? r.nextInt(3) : 0) : math.max(tpm, (tpm / p3 * (0.9 + r.nextInt(20) / 100)).round());
  final fta = ftm == 0 ? 0 : math.max(ftm, (ftm / pft).round());
  return (fgm: twom + tpm, fga: twoA + tpa, tpm: tpm, tpa: tpa, ftm: ftm, fta: fta);
}

/// 試合の点を4つのクォーターに分ける(合計は変えない)。
List<int> splitQuarters(int pts, Rng rng) {
  final w = [for (var i = 0; i < 4; i++) 80 + rng.nextInt(40)];
  final sum = w.fold(0, (a, b) => a + b);
  final q = [for (final x in w) pts * x ~/ sum];
  q[3] += pts - q.fold(0, (a, b) => a + b);
  return q;
}

class GameResult {
  GameResult({
    required this.home,
    required this.away,
    required this.homePts,
    required this.awayPts,
    this.topName,
    this.topPts = 0,
    this.quarters = const [],
    this.box = const [],
    this.oppBox = const [],
  });

  /// 相手のチームのボックススコア(自分のチームの試合だけ)。
  final List<BoxLine> oppBox;

  /// クォーターごとの点(ホームの4つ、アウェーの4つ)。自分のチームの試合だけ。
  final List<int> quarters;

  /// 自分のチームのボックススコア(出場した選手)。
  final List<BoxLine> box;

  final int home;
  final int away;
  final int homePts;
  final int awayPts;

  /// 自分のチームの試合だけ: いちばん点を取った選手。
  final String? topName;
  final int topPts;

  int get winner => homePts > awayPts ? home : away;
  bool involves(int t) => home == t || away == t;
  int ptsOf(int t) => t == home ? homePts : awayPts;
  int ptsAgainst(int t) => t == home ? awayPts : homePts;
  int opponentOf(int t) => t == home ? away : home;

  Map<String, dynamic> toJson() => {
        'h': home,
        'a': away,
        'hp': homePts,
        'ap': awayPts,
        if (topName != null) 'tn': topName,
        if (topPts != 0) 'tp': topPts,
        if (quarters.isNotEmpty) 'q': quarters,
        if (box.isNotEmpty) 'bx': [for (final b in box) b.toJson()],
        if (oppBox.isNotEmpty) 'ob': [for (final b in oppBox) b.toJson()],
      };

  static GameResult fromJson(Map<String, dynamic> j) => GameResult(
        home: j['h'] as int,
        away: j['a'] as int,
        homePts: j['hp'] as int,
        awayPts: j['ap'] as int,
        topName: j['tn'] as String?,
        topPts: (j['tp'] as int?) ?? 0,
        quarters: [for (final x in (j['q'] as List? ?? const [])) x as int],
        box: [for (final x in (j['bx'] as List? ?? const [])) BoxLine.fromJson(x as List)],
        oppBox: [for (final x in (j['ob'] as List? ?? const [])) BoxLine.fromJson(x as List)],
      );
}

/// 強さの差から、ホームが勝つ見込み。
double winChance(double home, double away) => 1 / (1 + math.exp(-(home - away + 1.0) / 3.6));

/// リバウンドとアシストの、ポジションごとの取りやすさ(ビッグはリバウンド、ガードはアシスト)。
const _rebPos = {Pos.pg: 0.5, Pos.sg: 0.6, Pos.sf: 0.9, Pos.pf: 1.2, Pos.c: 1.35};
const _astPos = {Pos.pg: 2.2, Pos.sg: 1.1, Pos.sf: 0.8, Pos.pf: 0.55, Pos.c: 0.45};

/// この区切りで起きたけが(チームの番号と選手)。区切りを進める側が読んで空にする。
final injuries = <(int, Player)>[];

/// 出場時間の配分(先発から順に、分)。
const minutesByOrder = [34, 33, 32, 30, 28, 22, 18, 14, 10, 8, 6, 3, 2, 0, 0];

/// 1試合の個人の数字を配る。点はチームの得点を、外と中の得点の力と出場時間で分ける。
/// リバウンドとアシストも同じように配る。[count] なら個人成績に足す(プレーオフは足さない)。
/// いちばん点を取った選手と、その点を返す。
(Player?, int) boxScore(Team t, int teamPts, Rng rng, {bool count = true, List<BoxLine>? lines, int oppPts = 0}) {
  final order = t.order;
  if (order.isEmpty) return (null, 0);
  final mins = t.playMinutes();
  List<int> share(int total, double Function(Player) skill) {
    final w = [for (var i = 0; i < order.length; i++) mins[i] * skill(order[i]) * (0.75 + rng.nextInt(50) / 100)];
    final sum = w.fold(0.0, (a, b) => a + b);
    if (sum <= 0) return List.filled(order.length, 0);
    final out = [for (final x in w) (total * x / sum).floor()];
    // 端数は、いちばん多く配られた選手へ
    var left = total - out.fold(0, (a, b) => a + b);
    var k = 0;
    while (left > 0) {
      out[k % out.length]++;
      left--;
      k++;
    }
    return out;
  }

  double pow(num x, double e) => math.pow(math.max(1, x), e).toDouble();
  final pts = share(teamPts, (p) => pow((p.attr(Attr.outside) + p.attr(Attr.inside)) / 2 - 40, 1.7));
  final reb = share(38 + rng.nextInt(8), (p) => pow(p.attr(Attr.rebound) - 35, 1.3) * _rebPos[p.pos]!);
  final ast = share(20 + rng.nextInt(10), (p) => pow(p.attr(Attr.passing) - 35, 1.3) * _astPos[p.pos]!);
  // けがの残りを1試合ぶん減らし、出た選手はけがの抽選(トレーナーが良いほど少なく、治りも早い)
  final trainer = t.staffLevel(Staff.trainer);
  // 練習がきついほど、けがが増える
  final chance = const [0.0075, 0.005, 0.003][trainer - 1] * const [0.8, 1.0, 1.35][t.training.clamp(0, 2)];
  final speed = const [1.25, 1.0, 0.75][trainer - 1];
  for (var i = 0; i < order.length; i++) {
    final p = order[i];
    if (p.injured > 0) {
      p.injured--;
    } else if (count && mins[i] > 0 && rng.nextInt(100000) < (chance * mins[i] / 30 * (1 + math.max(0, mins[i] - fatigueLine) * 0.1) * 100000).round()) {
      final r = rng.nextInt(100);
      final games = r < 80 ? 1 + rng.nextInt(6) : r < 97 ? 8 + rng.nextInt(15) : 30 + rng.nextInt(30);
      p.injured = math.max(1, (games * speed).round());
      injuries.add((t.index, p));
    }
  }
  // 細かい数字(シュートの内訳・スティール・ブロック・ミス・点差)は、試合の乱数とは別の乱数で決める(リーグの勝ち負けを変えない)
  final r = Rng(teamPts * 1000003 + oppPts * 7919 + order.first.id * 31 + t.wins * 131 + t.losses * 17 + t.index);
  List<int> split(int total, double Function(Player) w) {
    final ws = [for (var i = 0; i < order.length; i++) mins[i] * math.max(0.05, w(order[i])) * (0.6 + r.nextInt(80) / 100)];
    final sum = ws.fold(0.0, (a, b) => a + b);
    if (sum <= 0) return List.filled(order.length, 0);
    final out = [for (final x in ws) (total * x / sum).floor()];
    var left = total - out.fold(0, (a, b) => a + b);
    for (var k = 0; left > 0; k++) {
      if (mins[k % out.length] > 0) {
        out[k % out.length]++;
        left--;
      }
    }
    return out;
  }

  final stl = split(5 + r.nextInt(6), (p) => pow(p.attr(Attr.defense) - 35, 1.2) * (p.pos.guard ? 1.3 : 0.8));
  final blk = split(2 + r.nextInt(6), (p) => pow(p.attr(Attr.defense) - 35, 1.2) * const {Pos.pg: 0.25, Pos.sg: 0.35, Pos.sf: 0.7, Pos.pf: 1.3, Pos.c: 1.8}[p.pos]!);
  final tov = split(10 + r.nextInt(7), (p) => 0.6 + p.attr(Attr.passing) / 100 * (p.pos == Pos.pg ? 1.4 : 1.0));
  final margin = teamPts - oppPts;
  var top = 0;
  for (var i = 0; i < order.length; i++) {
    if (pts[i] > pts[top]) top = i;
    if (mins[i] <= 0) continue;
    final sh = shootingOf(order[i], pts[i], r);
    final pm = ((margin + r.nextInt(9) - 4) * mins[i] / 48).round();
    lines?.add(BoxLine(order[i].name, order[i].pos.short, mins[i], pts[i], reb[i], ast[i],
        fgm: sh.fgm, fga: sh.fga, tpm: sh.tpm, tpa: sh.tpa, ftm: sh.ftm, fta: sh.fta, stl: stl[i], blk: blk[i], tov: tov[i], pm: pm));
    if (count) {
      order[i].stats
        ..gp += 1
        ..pts += pts[i]
        ..reb += reb[i]
        ..ast += ast[i]
        ..min += mins[i]
        ..fgm += sh.fgm
        ..fga += sh.fga
        ..tpm += sh.tpm
        ..tpa += sh.tpa
        ..ftm += sh.ftm
        ..fta += sh.fta
        ..stl += stl[i]
        ..blk += blk[i]
        ..tov += tov[i];
    }
  }
  return (order[top], pts[top]);
}

/// 1試合を進める。どちらのチームにも個人の数字を配る([count] ならシーズンの成績に足す)。
/// [mine] のチームの試合なら、いちばん点を取った選手を結果に残す。
GameResult playGame(Team home, Team away, Rng rng, {int? mine, bool count = true}) {
  final p = winChance(home.strength, away.strength);
  final homeWins = rng.nextInt(10000) < (p * 10000).round();
  final base = 92 + rng.nextInt(28);
  final margin = 1 + rng.nextInt(rng.chance(0.3) ? 24 : 12);
  final w = base + margin, l = base;
  final hp = homeWins ? w : l, ap = homeWins ? l : w;
  final myBox = <BoxLine>[], oppBox = <BoxLine>[];
  final isMine = mine == home.index || mine == away.index;
  final (hTop, hTopPts) = boxScore(home, hp, rng, count: count, oppPts: ap, lines: !isMine ? null : mine == home.index ? myBox : oppBox);
  final (aTop, aTopPts) = boxScore(away, ap, rng, count: count, oppPts: hp, lines: !isMine ? null : mine == away.index ? myBox : oppBox);
  String? topName;
  var topPts = 0;
  if (mine == home.index) {
    topName = hTop?.name;
    topPts = hTopPts;
  } else if (mine == away.index) {
    topName = aTop?.name;
    topPts = aTopPts;
  }
  final r = GameResult(
    home: home.index,
    away: away.index,
    homePts: hp,
    awayPts: ap,
    topName: topName,
    topPts: topPts,
    quarters: isMine ? [...splitQuarters(hp, rng), ...splitQuarters(ap, rng)] : const [],
    box: myBox,
    oppBox: oppBox,
  );
  if (homeWins) {
    home.wins++;
    away.losses++;
  } else {
    away.wins++;
    home.losses++;
  }
  if (count) {
    // 連勝・連敗(+なら連勝、-なら連敗)
    final (w, l) = homeWins ? (home, away) : (away, home);
    w.streak = w.streak > 0 ? w.streak + 1 : 1;
    l.streak = l.streak < 0 ? l.streak - 1 : -1;
  }
  return r;
}

/// 総当たり1周(n-1節)の組み合わせ。[cycle] ごとにホームとアウェーを入れ替える(円形の組み方)。
List<List<(int, int)>> roundRobin(int n, int cycle) {
  final ids = List<int>.generate(n, (i) => i);
  final rounds = <List<(int, int)>>[];
  for (var r = 0; r < n - 1; r++) {
    final games = <(int, int)>[];
    for (var i = 0; i < n ~/ 2; i++) {
      var a = ids[i], b = ids[n - 1 - i];
      if ((r + i + cycle).isOdd) (a, b) = (b, a);
      games.add((a, b));
    }
    rounds.add(games);
    // 先頭を固定して回す
    ids.insert(1, ids.removeLast());
  }
  return rounds;
}

/// 1シーズン82節の組み合わせ(総当たりを2周と、3周目の24節)。どのチームも1節に1試合。
List<List<(int, int)>> seasonSchedule(int n) => [
      for (var c = 0; c < 3; c++) ...roundRobin(n, c),
    ].take(gamesPerSeason).toList();

/// 順位(勝ち数 → 負け数 → 番号の順)。[east] を渡すと、その地区だけ。
List<Team> standings(List<Team> teams, {bool? east}) => [...teams.where((t) => east == null || t.east == east)]
  ..sort((a, b) {
    final c = b.wins.compareTo(a.wins);
    if (c != 0) return c;
    return a.losses.compareTo(b.losses) != 0 ? a.losses.compareTo(b.losses) : a.index.compareTo(b.index);
  });

/// プレーオフの1カード(何勝先取か)。
class Series {
  Series({required this.high, required this.low, required this.need, this.round = 1, this.highWins = 0, this.lowWins = 0, List<GameResult>? games})
      : games = games ?? [];

  /// 0: プレーイン、1: 1回戦、2: 2回戦、3: 地区決勝、4: ファイナル。
  final int round;

  String get label => const ['プレーイン', '1回戦', '2回戦', '地区決勝', 'ファイナル'][round];

  final int high;
  final int low;
  final int need;
  int highWins;
  int lowWins;
  final List<GameResult> games;

  bool get over => highWins >= need || lowWins >= need;
  int get winner => highWins >= need ? high : low;
  int get loser => winner == high ? low : high;

  void play(List<Team> teams, Rng rng, int mine) {
    while (!over) {
      final n = highWins + lowWins;
      // 上位のチームが1・2・5・7試合目をホームで
      final highHome = n == 0 || n == 1 || n == 4 || n == 6;
      final h = teams[highHome ? high : low], a = teams[highHome ? low : high];
      final w0 = h.wins, l0 = h.losses, w1 = a.wins, l1 = a.losses;
      final g = playGame(h, a, rng, mine: mine, count: false);
      // プレーオフはシーズンの勝敗に数えない
      h.wins = w0;
      h.losses = l0;
      a.wins = w1;
      a.losses = l1;
      games.add(g);
      if (g.winner == high) {
        highWins++;
      } else {
        lowWins++;
      }
    }
  }

  Map<String, dynamic> toJson() => {'h': high, 'l': low, 'n': need, 'rd': round, 'hw': highWins, 'lw': lowWins, 'g': [for (final g in games) g.toJson()]};

  static Series fromJson(Map<String, dynamic> j) => Series(
        high: j['h'] as int,
        low: j['l'] as int,
        need: j['n'] as int,
        round: (j['rd'] as int?) ?? 1,
        highWins: j['hw'] as int,
        lowWins: j['lw'] as int,
        games: [for (final g in j['g'] as List) GameResult.fromJson(Map<String, dynamic>.from(g as Map))],
      );
}
