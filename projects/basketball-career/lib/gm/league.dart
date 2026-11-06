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
  Team({required this.index, required this.roster, this.wins = 0, this.losses = 0, this.mode = TeamMode.balanced, this.deadCap = 0});

  final int index;
  final List<Player> roster;
  int wins;
  int losses;
  TeamMode mode;

  /// 放出した選手の、今シーズン分の年俸(今季の合計に数える)。
  int deadCap;

  TeamDef get def => teamDefs[index];
  String get city => def.city;
  String get nick => def.nick;
  String get name => '$city・$nick';
  bool get east => def.east;

  int get payroll => roster.fold(0, (s, p) => s + p.salary) + deadCap;
  int get capRoom => salaryCap - payroll;

  double get winPct => wins + losses == 0 ? 0 : wins / (wins + losses);

  /// チームの強さ。力の高い順に9人を重み付きで平均し、ガードとビッグがいなければ下げる。
  double get strength => teamStrength(roster);

  Map<String, dynamic> toJson() => {
        'i': index,
        'r': [for (final p in roster) p.toJson()],
        'w': wins,
        'l': losses,
        'm': mode.index,
        if (deadCap != 0) 'dc': deadCap,
      };

  static Team fromJson(Map<String, dynamic> j) => Team(
        index: j['i'] as int,
        roster: [for (final p in j['r'] as List) Player.fromJson(Map<String, dynamic>.from(p as Map))],
        wins: j['w'] as int,
        losses: j['l'] as int,
        mode: TeamMode.values[((j['m'] as int?) ?? 1).clamp(0, TeamMode.values.length - 1)],
        deadCap: (j['dc'] as int?) ?? 0,
      );
}

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
class GameResult {
  GameResult({required this.home, required this.away, required this.homePts, required this.awayPts, this.topName, this.topPts = 0});

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

  Map<String, dynamic> toJson() => {'h': home, 'a': away, 'hp': homePts, 'ap': awayPts, if (topName != null) 'tn': topName, if (topPts != 0) 'tp': topPts};

  static GameResult fromJson(Map<String, dynamic> j) => GameResult(
        home: j['h'] as int,
        away: j['a'] as int,
        homePts: j['hp'] as int,
        awayPts: j['ap'] as int,
        topName: j['tn'] as String?,
        topPts: (j['tp'] as int?) ?? 0,
      );
}

/// 強さの差から、ホームが勝つ見込み。
double winChance(double home, double away) => 1 / (1 + math.exp(-(home - away + 1.0) / 3.6));

/// リバウンドとアシストの、ポジションごとの取りやすさ(ビッグはリバウンド、ガードはアシスト)。
const _rebPos = {Pos.pg: 0.5, Pos.sg: 0.6, Pos.sf: 0.9, Pos.pf: 1.2, Pos.c: 1.35};
const _astPos = {Pos.pg: 2.2, Pos.sg: 1.1, Pos.sf: 0.8, Pos.pf: 0.55, Pos.c: 0.45};

/// 出場時間の配分(先発から順に、分)。
const minutesByOrder = [34, 33, 32, 30, 28, 22, 18, 14, 10, 8, 6, 3, 2, 0, 0];

/// 1試合の個人の数字を配る。点はチームの得点を、外と中の得点の力と出場時間で分ける。
/// リバウンドとアシストも同じように配る。[count] なら個人成績に足す(プレーオフは足さない)。
/// いちばん点を取った選手と、その点を返す。
(Player?, int) boxScore(Team t, int teamPts, Rng rng, {bool count = true}) {
  final order = lineup(t.roster);
  if (order.isEmpty) return (null, 0);
  final mins = [for (var i = 0; i < order.length; i++) i < minutesByOrder.length ? minutesByOrder[i] : 0];
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
  var top = 0;
  for (var i = 0; i < order.length; i++) {
    if (pts[i] > pts[top]) top = i;
    if (count && mins[i] > 0) {
      order[i].stats
        ..gp += 1
        ..pts += pts[i]
        ..reb += reb[i]
        ..ast += ast[i];
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
  final (hTop, hTopPts) = boxScore(home, hp, rng, count: count);
  final (aTop, aTopPts) = boxScore(away, ap, rng, count: count);
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
  );
  if (homeWins) {
    home.wins++;
    away.losses++;
  } else {
    away.wins++;
    home.losses++;
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
