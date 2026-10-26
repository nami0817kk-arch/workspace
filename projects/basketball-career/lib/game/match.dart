import 'dart:math';

import 'player.dart';
import 'build.dart';
import 'special.dart';
import 'traits.dart';

/// 勝負どころ(最後の攻防)で選べるプレー。
enum Clutch {
  drive('ドライブ', '切り込んで決める。ドリブルが効く。2点。'),
  threePoint('3P', '外から狙う。成功すれば3点。'),
  pass('パス', '味方に任せる。パス力が効く。2点。'),
  defend('ディフェンス', '最後の相手の攻撃を止める。'),
  drawFoul('ファウルをもらう', '当たって誘い、フリースロー2本を決める。');

  const Clutch(this.label, this.description);
  final String label;
  final String description;

  static Clutch? parse(String? s) {
    for (final c in Clutch.values) {
      if (c.name == s) return c;
    }
    return null;
  }
}

/// 試合の結果。
/// ボックススコア(試合ごとの細かい成績)。シュートの本数・フリースロー・ターンオーバー・出場時間。
/// 得点・3Pの本数と食い違わないように作る(`boxScoreOf`)。古いセーブは 0 のまま(画面に出さない)。
class BoxScore {
  const BoxScore({
    this.fgMade = 0,
    this.fgAttempts = 0,
    this.threeAttempts = 0,
    this.ftMade = 0,
    this.ftAttempts = 0,
    this.turnovers = 0,
    this.minutes = 0,
  });

  /// フィールドゴール(2点・3点)の成功と試投。3Pは3P本数(`MatchResult.threes`)と試投。
  final int fgMade;
  final int fgAttempts;
  final int threeAttempts;
  final int ftMade;
  final int ftAttempts;
  final int turnovers;
  final int minutes;

  bool get isEmpty => fgAttempts == 0 && ftAttempts == 0 && minutes == 0;

  /// 2つのボックススコアを足したもの(大会・年・通算の合計に使う)。3Pの成功は別に数える(`threes`)。
  BoxScore operator +(BoxScore o) => BoxScore(
        fgMade: fgMade + o.fgMade,
        fgAttempts: fgAttempts + o.fgAttempts,
        threeAttempts: threeAttempts + o.threeAttempts,
        ftMade: ftMade + o.ftMade,
        ftAttempts: ftAttempts + o.ftAttempts,
        turnovers: turnovers + o.turnovers,
        minutes: minutes + o.minutes,
      );

  /// 試合の成績の1行(シュート・3P・フリースロー・ターンオーバー・出場時間)。`threes` は3Pの成功本数。
  String line(int threes) =>
      'FG $fgMade/$fgAttempts  3P $threes/$threeAttempts  FT $ftMade/$ftAttempts  ターンオーバー$turnovers  出場$minutes分';

  Map<String, dynamic> toJson() => {
        'fgm': fgMade,
        'fga': fgAttempts,
        'tpa': threeAttempts,
        'ftm': ftMade,
        'fta': ftAttempts,
        'tov': turnovers,
        'min': minutes,
      };

  factory BoxScore.fromJson(Map<String, dynamic>? j) => BoxScore(
        fgMade: (j?['fgm'] as num?)?.toInt() ?? 0,
        fgAttempts: (j?['fga'] as num?)?.toInt() ?? 0,
        threeAttempts: (j?['tpa'] as num?)?.toInt() ?? 0,
        ftMade: (j?['ftm'] as num?)?.toInt() ?? 0,
        ftAttempts: (j?['fta'] as num?)?.toInt() ?? 0,
        turnovers: (j?['tov'] as num?)?.toInt() ?? 0,
        minutes: (j?['min'] as num?)?.toInt() ?? 0,
      );
}

/// 成功率の表示(「47.8%」)。試投が無ければ「-」。
String pctLabel(int made, int attempts, {int digits = 1}) =>
    attempts == 0 ? '-' : '${(made / attempts * 100).toStringAsFixed(digits)}%';

/// シュート成功率の1行(FG・3P・FT)。3Pの成功は `threes`。
String shootingLine(BoxScore b, int threes, {int digits = 1}) =>
    'FG ${pctLabel(b.fgMade, b.fgAttempts, digits: digits)}・3P ${pctLabel(threes, b.threeAttempts, digits: digits)}・FT ${pctLabel(b.ftMade, b.ftAttempts, digits: digits)}';

/// 得点 `points`・3P `threes` に合うボックススコアを作る(2点シュート×2＋3P×3＋フリースロー＝得点)。
/// 成功率は能力から決まる(2点は42〜58%・3Pは28〜44%・フリースローは `freeThrowChance`)。
BoxScore boxScoreOf(
  Player p, {
  required int points,
  required int threes,
  required double form,
  required int gameMinutes,
  required bool fouledOut,
  required Random rng,
  bool starter = true,
}) {
  final rem0 = max(0, points - 3 * threes);
  final fta0 = (rem0 * 0.2 / 0.8).round();
  final ftp = freeThrowChance(p, form);
  var ftm = 0;
  for (var i = 0; i < fta0; i++) {
    if (rng.nextDouble() < ftp) ftm++;
  }
  ftm = min(ftm, rem0);
  if ((rem0 - ftm).isOdd) ftm = ftm > 0 ? ftm - 1 : ftm + 1;
  ftm = ftm.clamp(0, rem0);
  final fg2 = max(0, (rem0 - ftm) ~/ 2);
  final inside = (p.effective(Ability.inside) + p.effective(Ability.midRange)) / 2;
  final p2 = (0.40 + inside / 100 * 0.2 + (form - 1) * 0.1).clamp(0.38, 0.62);
  final p3 = (0.27 + p.effective(Ability.threePoint) / 100 * 0.17 + (form - 1) * 0.1)
      .clamp(0.24, 0.46);
  int attempts(int made, double pct) =>
      made == 0 ? (rng.nextDouble() < 0.5 ? 1 : 0) : max(made, (made / pct + (rng.nextDouble() - 0.5) * 1.6).round());
  final a2 = attempts(fg2, p2), a3 = attempts(threes, p3);
  final fta = max(ftm, ftm == 0 ? fta0 : (ftm / ftp).round());
  final handle = (p.effective(Ability.pass) + p.effective(Ability.dribble)) / 2;
  final tov = max(
      0,
      (gameMinutes / 48 * (1.0 + (65 - handle) / 22) + (rng.nextDouble() - 0.5) * 2)
          .round()
          .clamp(0, 9));
  var minutes = (gameMinutes * (0.55 + p.effective(Ability.stamina) / 100 * 0.27)).round();
  if (!starter) minutes = (minutes * 0.55).round(); // 控えは出場時間が短い
  if (fouledOut) minutes = (minutes * 0.8).round();
  return BoxScore(
    fgMade: fg2 + threes,
    fgAttempts: a2 + a3,
    threeAttempts: a3,
    ftMade: ftm,
    ftAttempts: fta,
    turnovers: tov,
    minutes: minutes.clamp(1, gameMinutes + 15),
  );
}

class MatchResult {
  const MatchResult({
    required this.won,
    required this.teamScore,
    required this.oppScore,
    required this.points,
    required this.rebounds,
    required this.assists,
    this.steals = 0,
    this.blocks = 0,
    this.threes = 0,
    this.clutch,
    this.clutchSuccess,
    this.teamQuarters = const [],
    this.oppQuarters = const [],
    this.opponent = '',
    this.vsRival = false,
    this.fouls = 0,
    this.fouledOut = false,
    this.box = const BoxScore(),
    this.overtimes = 0,
    this.tag = '',
    this.starter = true,
  });

  /// 先発で出たか(false なら控え)。古いセーブは先発。
  final bool starter;

  /// 延長戦の回数(0 なら4クォーターで決着)。
  final int overtimes;

  /// 試合の呼び名(プレーオフのシリーズでは「プレーオフ準決勝 第2戦(1勝0敗)」など)。空なら回戦で呼ぶ。
  final String tag;

  final bool won;
  final int teamScore;
  final int oppScore;
  final int points;
  final int rebounds;
  final int assists;
  final int steals;
  final int blocks;

  /// 決めた3Pの本数。
  final int threes;

  /// 勝負どころが訪れたときの選択と成否。訪れなければ null。
  final Clutch? clutch;
  final bool? clutchSuccess;

  /// クォーターごとの得点(4つ)。延長・勝負どころの得点は含まない。
  final List<int> teamQuarters;
  final List<int> oppQuarters;

  /// 相手の名前(ライバルなら本人の名前)。
  final String opponent;
  final bool vsRival;

  /// その試合の個人ファウル数と、5つ目で退場したか。
  final int fouls;
  final bool fouledOut;

  /// シュートの本数・フリースロー・ターンオーバー・出場時間(ボックススコア)。古いセーブは空。
  final BoxScore box;

  int get margin => teamScore - oppScore;

  /// 試合の呼び名(`tag`)を付けた同じ結果。
  MatchResult withTag(String t) => MatchResult(
        won: won,
        teamScore: teamScore,
        oppScore: oppScore,
        points: points,
        rebounds: rebounds,
        assists: assists,
        steals: steals,
        blocks: blocks,
        threes: threes,
        clutch: clutch,
        clutchSuccess: clutchSuccess,
        teamQuarters: teamQuarters,
        oppQuarters: oppQuarters,
        opponent: opponent,
        vsRival: vsRival,
        fouls: fouls,
        fouledOut: fouledOut,
        box: box,
        overtimes: overtimes,
        tag: t,
        starter: starter,
      );

  Map<String, dynamic> toJson() => {
        'won': won,
        'teamScore': teamScore,
        'oppScore': oppScore,
        'points': points,
        'rebounds': rebounds,
        'assists': assists,
        'steals': steals,
        'blocks': blocks,
        'threes': threes,
        'clutch': clutch?.name,
        'clutchSuccess': clutchSuccess,
        'teamQuarters': teamQuarters,
        'oppQuarters': oppQuarters,
        'opponent': opponent,
        'vsRival': vsRival,
        'fouls': fouls,
        'fouledOut': fouledOut,
        'box': box.toJson(),
        'ot': overtimes,
        'tag': tag,
        'starter': starter,
      };

  factory MatchResult.fromJson(Map<String, dynamic> j) => MatchResult(
        won: (j['won'] as bool?) ?? false,
        teamScore: (j['teamScore'] as num?)?.toInt() ?? 0,
        oppScore: (j['oppScore'] as num?)?.toInt() ?? 0,
        points: (j['points'] as num?)?.toInt() ?? 0,
        rebounds: (j['rebounds'] as num?)?.toInt() ?? 0,
        assists: (j['assists'] as num?)?.toInt() ?? 0,
        steals: (j['steals'] as num?)?.toInt() ?? 0,
        blocks: (j['blocks'] as num?)?.toInt() ?? 0,
        threes: (j['threes'] as num?)?.toInt() ?? 0,
        clutch: Clutch.parse(j['clutch'] as String?),
        clutchSuccess: j['clutchSuccess'] as bool?,
        teamQuarters: [
          for (final v in (j['teamQuarters'] as List?) ?? const [])
            (v as num).toInt()
        ],
        oppQuarters: [
          for (final v in (j['oppQuarters'] as List?) ?? const [])
            (v as num).toInt()
        ],
        opponent: (j['opponent'] as String?) ?? '',
        vsRival: (j['vsRival'] as bool?) ?? false,
        fouls: (j['fouls'] as num?)?.toInt() ?? 0,
        fouledOut: (j['fouledOut'] as bool?) ?? false,
        box: BoxScore.fromJson((j['box'] as Map?)?.cast<String, dynamic>()),
        overtimes: (j['ot'] as num?)?.toInt() ?? 0,
        tag: (j['tag'] as String?) ?? '',
        starter: (j['starter'] as bool?) ?? true,
      );
}

/// 4クォーターが終わった時点の試合。勝負どころが訪れるなら、ここで止まって選ぶ。
class MatchState {
  const MatchState({
    required this.team,
    required this.opp,
    required this.points,
    required this.rebounds,
    required this.assists,
    this.steals = 0,
    this.blocks = 0,
    this.threes = 0,
    required this.teamStrength,
    required this.oppStrength,
    required this.form,
    required this.teamQuarters,
    required this.oppQuarters,
    this.opponent = '',
    this.vsRival = false,
    this.fouls = 0,
    this.fouledOut = false,
    this.timeout = false,
    this.zone = false,
    this.scale = 1.0,
    this.gameMinutes = 40,
    this.starter = true,
  });

  /// その試合の点数の規模(`League.scoreScale`)と、試合時間(分)。
  final double scale;
  final int gameMinutes;

  /// 先発か(控えなら出場時間が短い)。
  final bool starter;

  final int team;
  final int opp;
  final int points;
  final int rebounds;
  final int assists;
  final int steals;
  final int blocks;
  final int threes;
  final double teamStrength;
  final double oppStrength;
  final double form;
  final List<int> teamQuarters;
  final List<int> oppQuarters;
  final String opponent;
  final bool vsRival;

  /// 個人ファウルの数と、5つ目で退場したか。
  final int fouls;
  final bool fouledOut;

  /// タイムアウトを取ったか(最後の攻防の成功率が上がる)。
  final bool timeout;

  /// ゾーン(特殊能力)を使ったか(最後の攻防の成功率が大きく上がる)。
  final bool zone;

  MatchState _copy({bool? timeout, bool? zone}) => MatchState(
        team: team,
        opp: opp,
        points: points,
        rebounds: rebounds,
        assists: assists,
        steals: steals,
        blocks: blocks,
        threes: threes,
        teamStrength: teamStrength,
        oppStrength: oppStrength,
        form: form,
        teamQuarters: teamQuarters,
        oppQuarters: oppQuarters,
        opponent: opponent,
        vsRival: vsRival,
        fouls: fouls,
        fouledOut: fouledOut,
        timeout: timeout ?? this.timeout,
        zone: zone ?? this.zone,
        scale: scale,
        gameMinutes: gameMinutes,
        starter: starter,
      );

  /// タイムアウトを取った状態にした試合。
  MatchState withTimeout() => _copy(timeout: true);

  /// ゾーンに入った状態にした試合。
  MatchState withZone() => _copy(zone: true);

  int get margin => team - opp;

  /// 点差が近く、最後の攻防を選べるか。
  bool get needsClutch => margin.abs() <= clutchWindowOf(scale);

  Map<String, dynamic> toJson() => {
        'team': team,
        'opp': opp,
        'points': points,
        'rebounds': rebounds,
        'assists': assists,
        'steals': steals,
        'blocks': blocks,
        'threes': threes,
        'teamStrength': teamStrength,
        'oppStrength': oppStrength,
        'form': form,
        'teamQuarters': teamQuarters,
        'oppQuarters': oppQuarters,
        'opponent': opponent,
        'vsRival': vsRival,
        'fouls': fouls,
        'fouledOut': fouledOut,
        'timeout': timeout,
        'zone': zone,
        'scale': scale,
        'gameMinutes': gameMinutes,
        'starter': starter,
      };

  factory MatchState.fromJson(Map<String, dynamic> j) => MatchState(
        team: (j['team'] as num?)?.toInt() ?? 0,
        opp: (j['opp'] as num?)?.toInt() ?? 0,
        points: (j['points'] as num?)?.toInt() ?? 0,
        rebounds: (j['rebounds'] as num?)?.toInt() ?? 0,
        assists: (j['assists'] as num?)?.toInt() ?? 0,
        steals: (j['steals'] as num?)?.toInt() ?? 0,
        blocks: (j['blocks'] as num?)?.toInt() ?? 0,
        threes: (j['threes'] as num?)?.toInt() ?? 0,
        teamStrength: (j['teamStrength'] as num?)?.toDouble() ?? 50,
        oppStrength: (j['oppStrength'] as num?)?.toDouble() ?? 50,
        form: (j['form'] as num?)?.toDouble() ?? 1,
        teamQuarters: [
          for (final v in (j['teamQuarters'] as List?) ?? const [])
            (v as num).toInt()
        ],
        oppQuarters: [
          for (final v in (j['oppQuarters'] as List?) ?? const [])
            (v as num).toInt()
        ],
        opponent: (j['opponent'] as String?) ?? '',
        vsRival: (j['vsRival'] as bool?) ?? false,
        fouls: (j['fouls'] as num?)?.toInt() ?? 0,
        fouledOut: (j['fouledOut'] as bool?) ?? false,
        timeout: (j['timeout'] as bool?) ?? false,
        zone: (j['zone'] as bool?) ?? false,
        scale: (j['scale'] as num?)?.toDouble() ?? 1.0,
        gameMinutes: (j['gameMinutes'] as num?)?.toInt() ?? 40,
        starter: (j['starter'] as bool?) ?? true,
      );
}

/// 勝負どころに入る点差(最終クォーター終了時、この点差以内)。
const clutchWindow = 3;

/// 点数の規模に応じた、勝負どころに入る点差(ミニバス2点・高校3点・海外の最高峰5点)。
int clutchWindowOf(double scale) => (clutchWindow * scale).round().clamp(2, 6);

double _noise(Random rng) =>
    (rng.nextDouble() + rng.nextDouble() + rng.nextDouble() - 1.5) / 1.5;

/// ファウルを誘える確率(強く当たる・切り込む力と、相手の守備)。
double foulDrawChance(Player p, double oppDefense) =>
    (0.30 +
            0.35 * ((p.effective(Ability.physical) + p.effective(Ability.dribble)) / 200) -
            0.10 * (oppDefense / 100))
        .clamp(0.1, 0.8);

/// フリースロー1本が入る確率。
double freeThrowChance(Player p, double form) =>
    (0.40 + 0.50 * (p.effective(Ability.freeThrow) / 100) + (form - 1) * 0.1 + clutchBonus(p.traits) * 0.5)
        .clamp(0.2, 0.95);

/// タイムアウトで最後の攻防の成功率が上がる量(5%)。
const timeoutBonus = 0.05;

/// 勝負どころの成功率(0〜1)。`oppDefense` は相手の守備の強さ(0〜100)。
/// ファウルをもらうは「ファウルを誘って、2本とも決める」確率(1本だけでも1点は入る)。
double clutchChance(Player p, Clutch c, double oppDefense, double form,
    {bool timeout = false, bool zone = false, bool vsRival = false}) {
  final opp = oppDefense / 100;
  final double raw = switch (c) {
    Clutch.drive =>
      0.22 + 0.55 * ((p.effective(Ability.inside) + p.effective(Ability.dribble)) / 200) - 0.25 * opp,
    Clutch.threePoint =>
      0.12 + 0.55 * (p.effective(Ability.threePoint) / 100) - 0.20 * opp,
    Clutch.pass =>
      0.28 + 0.45 * (p.effective(Ability.pass) / 100) - 0.12 * opp,
    Clutch.defend =>
      0.25 + 0.50 * (p.effective(Ability.defense) / 100) - 0.15 * opp,
    Clutch.drawFoul => foulDrawChance(p, oppDefense) *
        pow(freeThrowChance(p, form), 2).toDouble(),
  };
  // ポジションの持ち味。
  final perk = switch ((p.position, c)) {
    (Position.shootingGuard, Clutch.threePoint) => 0.08,
    (Position.powerForward, Clutch.drive) => 0.07,
    (Position.center, Clutch.defend) => 0.08,
    _ => 0.0,
  };
  // 得意技の加算。
  final skill = p.skills.fold(0.0, (s, k) => s + k.clutchBonus(c));
  final to = (timeout ? timeoutBonus : 0.0) + (zone ? zoneBonus : 0.0);
  final sp = specialClutchBonus(p.specials) +
      specialClutchPlayBonus(p.specials, c) +
      specialRivalBonus(p.specials, vsRival);
  if (c == Clutch.drawFoul) return (raw + skill + to + sp).clamp(0.03, 0.9);
  return (raw * (0.8 + form * 0.2) +
          clutchBonus(p.traits) +
          clutchPlayBonus(p.traits, c) +
          buildClutchBonus(p, c) +
          perk +
          skill +
          to +
          sp)
      .clamp(0.03, 0.9);
}

/// ハーフタイムの作戦。後半(第3・第4クォーター)の流れが変わる。
enum Halftime {
  keep('このまま続ける', '作戦は変えない。'),
  tempo('ペースを上げる', '走って点を取り合う。追う側向き。'),
  defense('守りを固める', '失点を抑えてロースコアに。リード側向き。'),
  star('エースに任せる', '自分にボールを集める。力のある選手向き。');

  const Halftime(this.label, this.description);
  final String label;
  final String description;

  static Halftime? parse(String? s) {
    for (final h in Halftime.values) {
      if (h.name == s) return h;
    }
    return null;
  }
}

/// 相手チームの持ち味。ハーフタイムの作戦との相性が変わる(`fit`)。
/// 同じチーム名・同じ回戦なら、いつも同じ持ち味(乱数を使わないので保存・再現に影響しない)。
enum OppStyle {
  balanced('バランス型', '目立った特徴はない。作戦の相性は無い。'),
  fastBreak('速攻型', '走って点を取り合うチーム。守りを固めて速い展開を止めると有利、ペースを上げると相手の土俵になる。'),
  inside('高さ型', '大きい選手でゴール下を固める。背が高い選手は有利、低いと苦戦。エースに任せると囲まれる。'),
  outside('外角型', '3Pをよく打つチーム。守りを固めて外を打たせないと有利、ペースを上げても噛み合わない。'),
  stout('堅守型', '守りが堅くロースコアになる。ペースを上げて崩すと有利、守りの勝負は不利。');

  const OppStyle(this.label, this.description);
  final String label;
  final String description;

  static OppStyle? parse(String? s) {
    for (final k in OppStyle.values) {
      if (k.name == s) return k;
    }
    return null;
  }

  /// チーム名と回戦から決める(毎回同じ)。バランス型が3分の1。
  static OppStyle forTeam(String name, int round) {
    final h = name.codeUnits.fold(0, (a, c) => (a * 31 + c) & 0xFFFF) + round * 7;
    const table = [
      OppStyle.balanced,
      OppStyle.fastBreak,
      OppStyle.inside,
      OppStyle.balanced,
      OppStyle.outside,
      OppStyle.stout,
    ];
    return table[h % table.length];
  }

  /// 4クォーター全部での点の出方(両チームに同じだけ足す)。速攻型は多く、堅守型は少ない。
  double get pace => switch (this) {
        OppStyle.fastBreak => 1.5,
        OppStyle.stout => -1.5,
        _ => 0.0,
      };

  /// 後半、こちらのクォーターごとの点への加算(作戦との相性)。
  double fit(Halftime choice, Player p) {
    switch (this) {
      case OppStyle.balanced:
        return 0;
      case OppStyle.fastBreak:
        return switch (choice) {
          Halftime.defense => 1.0,
          Halftime.tempo => -1.0,
          _ => 0,
        };
      case OppStyle.inside:
        final tall = ((p.heightCm - 188) / 12).clamp(-1.0, 1.0).toDouble();
        return tall +
            switch (choice) {
              Halftime.star => -0.7,
              Halftime.tempo => 0.3,
              _ => 0,
            };
      case OppStyle.outside:
        return switch (choice) {
          Halftime.defense => 1.0,
          Halftime.tempo => -0.7,
          _ => 0,
        };
      case OppStyle.stout:
        return switch (choice) {
          Halftime.tempo => 1.0,
          Halftime.defense => -1.0,
          Halftime.star => 0.3,
          _ => 0,
        };
    }
  }
}

/// 前半(第2クォーター)が終わった時点の試合。点差が近ければ、ここで作戦を選ぶ。
class MatchHalf {
  const MatchHalf({
    required this.team,
    required this.opp,
    required this.teamQuarters,
    required this.oppQuarters,
    required this.mine,
    required this.oppStrength,
    required this.form,
    required this.share,
    required this.rebounds,
    required this.assists,
    required this.steals,
    required this.blocks,
    this.opponent = '',
    this.vsRival = false,
    this.style = OppStyle.balanced,
    this.fouls = 0,
    this.scale = 1.0,
    this.gameMinutes = 40,
    this.starter = true,
  });

  /// その試合の点数の規模と試合時間(分)。
  final double scale;
  final int gameMinutes;

  /// 先発か(false なら控え。出場時間と個人の取り分が小さい)。
  final bool starter;

  final int team;
  final int opp;
  final List<int> teamQuarters;
  final List<int> oppQuarters;
  final double mine;
  final double oppStrength;
  final double form;
  final double share;
  final int rebounds;
  final int assists;
  final int steals;
  final int blocks;
  final String opponent;
  final bool vsRival;
  final OppStyle style;

  /// 前半のファウル数。3つ以上はファウルトラブル(後半に5つで退場)。
  final int fouls;

  /// ファウルトラブルか(前半で3つ以上)。
  bool get foulTrouble => fouls >= 3;

  int get margin => team - opp;

  /// 作戦を選ぶ価値がある点差(12点以内)。大差なら自動で進む。
  bool get needsDecision => margin.abs() <= (12 * scale).round();

  Map<String, dynamic> toJson() => {
        'team': team,
        'opp': opp,
        'teamQuarters': teamQuarters,
        'oppQuarters': oppQuarters,
        'mine': mine,
        'oppStrength': oppStrength,
        'form': form,
        'share': share,
        'rebounds': rebounds,
        'assists': assists,
        'steals': steals,
        'blocks': blocks,
        'opponent': opponent,
        'vsRival': vsRival,
        'style': style.name,
        'fouls': fouls,
        'scale': scale,
        'gameMinutes': gameMinutes,
        'starter': starter,
      };

  factory MatchHalf.fromJson(Map<String, dynamic> j) => MatchHalf(
        team: (j['team'] as num?)?.toInt() ?? 0,
        opp: (j['opp'] as num?)?.toInt() ?? 0,
        teamQuarters: [
          for (final v in (j['teamQuarters'] as List?) ?? const [])
            (v as num).toInt()
        ],
        oppQuarters: [
          for (final v in (j['oppQuarters'] as List?) ?? const [])
            (v as num).toInt()
        ],
        mine: (j['mine'] as num?)?.toDouble() ?? 50,
        oppStrength: (j['oppStrength'] as num?)?.toDouble() ?? 50,
        form: (j['form'] as num?)?.toDouble() ?? 1,
        share: (j['share'] as num?)?.toDouble() ?? 0.15,
        rebounds: (j['rebounds'] as num?)?.toInt() ?? 0,
        assists: (j['assists'] as num?)?.toInt() ?? 0,
        steals: (j['steals'] as num?)?.toInt() ?? 0,
        blocks: (j['blocks'] as num?)?.toInt() ?? 0,
        opponent: (j['opponent'] as String?) ?? '',
        vsRival: (j['vsRival'] as bool?) ?? false,
        style: OppStyle.parse(j['style'] as String?) ?? OppStyle.balanced,
        fouls: (j['fouls'] as num?)?.toInt() ?? 0,
        scale: (j['scale'] as num?)?.toDouble() ?? 1.0,
        gameMinutes: (j['gameMinutes'] as num?)?.toInt() ?? 40,
        starter: (j['starter'] as bool?) ?? true,
      );
}

/// 前半(第1・第2クォーター)を進める。
///
/// - `teamStrength` は味方(本人を除く)、`oppStrength` は相手の強さ(0〜100、50が平均)。
/// - `form` は体調(`Condition.form`)。
MatchHalf playFirstHalf(
  Player p, {
  required double teamStrength,
  required double oppStrength,
  required double form,
  required Random rng,
  String opponent = '',
  bool vsRival = false,
  OppStyle style = OppStyle.balanced,
  double scale = 1.0,
  int gameMinutes = 40,
  double? benchBelow,
}) {
  // 総合が控えの線より低ければ、ベンチスタート(出場時間と個人の取り分が小さい)。
  final starter = benchBelow == null || p.overall >= benchBelow;
  final cut = starter ? 1.0 : 0.55;
  final mine = teamStrength * 0.6 + p.overall * form * 0.4;
  var team = 0, opp = 0;
  final tq = <int>[], oq = <int>[];
  for (var q = 0; q < 2; q++) {
    final t = max(
        (8 * scale).round(),
        (scale * (18 + (mine - 50) * 0.12 + style.pace + _noise(rng) * 5))
            .round());
    final o = max(
        (8 * scale).round(),
        (scale *
                (18 + (oppStrength - 50) * 0.12 + style.pace + _noise(rng) * 5))
            .round());
    tq.add(t);
    oq.add(o);
    team += t;
    opp += o;
  }
  // 個人成績の素(得点の取り分・リバウンド・アシスト・スティール・ブロック)。
  final offense = (p.effective(Ability.threePoint) +
          p.effective(Ability.midRange) +
          p.effective(Ability.inside)) /
      3;
  final share =
      (0.10 + (offense - 30) / 300 + _noise(rng) * 0.03).clamp(0.04, 0.45) * cut;
  return MatchHalf(
    team: team,
    opp: opp,
    teamQuarters: tq,
    oppQuarters: oq,
    mine: mine,
    oppStrength: oppStrength,
    form: form,
    share: share,
    starter: starter,
    rebounds: max(
        0,
        ((p.effective(Ability.rebound) /
                    8 *
                    form *
                    (p.position == Position.center ? 1.2 : 1.0) +
                _noise(rng) * 2) * cut)
            .round()),
    assists:
        max(0, ((p.effective(Ability.pass) / 14 * form + _noise(rng)) * cut).round()),
    steals: max(
        0,
        (((p.effective(Ability.defense) + p.effective(Ability.speed)) / 2) /
                    45 *
                    form *
                    stealMultiplier(p.traits) *
                    buildStealMultiplier(p) +
                _noise(rng) * 0.8)
            .round()
            .clamp(0, 6)),
    blocks: max(
        0,
        ((p.effective(Ability.defense) / 70) *
                    (0.2 + max(0.0, p.heightCm - 180) / 35) *
                    form *
                    blockMultiplier(p.traits) *
                    buildBlockMultiplier(p) +
                _noise(rng) * 0.6)
            .round()
            .clamp(0, 6)),
    opponent: opponent,
    vsRival: vsRival,
    style: style,
    fouls: foulsOf(p, 2, starter ? 1.0 : 0.6, rng),
    scale: scale,
    gameMinutes: gameMinutes,
  );
}

/// ファウルの数。守りが強く体が強い選手ほど、強く当たってファウルが増える。
/// `quarters` クォーター分、`mul` は後半の作戦による倍率(守りを固めると増える)。
int foulsOf(Player p, int quarters, double mul, Random rng) {
  final aggressive = 0.8 +
      (p.effective(Ability.defense) - 50) / 100 +
      (p.effective(Ability.physical) - 50) / 200;
  final lambda = 0.45 *
      quarters *
      aggressive.clamp(0.4, 1.6) *
      mul *
      specialFoulMultiplier(p.specials);
  return _poisson(lambda, rng).clamp(0, 5);
}

/// 平均 `lambda` 回の起こる回数(ポアソン分布)。ファウルのように、ときどき多く起きる数に使う。
int _poisson(double lambda, Random rng) {
  final limit = exp(-lambda);
  var k = 0;
  var prod = rng.nextDouble();
  while (prod > limit && k < 20) {
    k++;
    prod *= rng.nextDouble();
  }
  return k;
}

/// 作戦の効きの強さ(エースに任せる)。スタミナと総合力があるほど大きい。
double starPower(Player p) =>
    ((p.effective(Ability.stamina) / 70) * 0.6 + (p.overall / 70) * 0.4)
        .clamp(0.4, 1.4);

/// 後半(第3・第4クォーター)を進め、4クォーター終了時点にする。
/// `scout` は直前に研究(映像分析)をしていたときの上乗せ。相性が良い作戦にだけ足す。
MatchState playSecondHalf(Player p, MatchHalf h, Halftime choice, Random rng,
    {double scout = 0}) {
  var shift = 0.0, noiseMul = 1.0, boost = 0.0, shareAdd = 0.0;
  switch (choice) {
    case Halftime.keep:
      break;
    case Halftime.tempo:
      shift = 2.5;
      noiseMul = 1.5;
    case Halftime.defense:
      shift = -2.5;
      noiseMul = 0.7;
    case Halftime.star:
      final k = starPower(p);
      boost = ((p.overall - 50) * 0.05 + 1.0) * k - 0.8;
      shareAdd = 0.08 * k;
  }
  var fit = h.style.fit(choice, p) *
      halftimeFitMultiplier(p.traits) *
      specialFitMultiplier(p.specials);
  if (fit > 0) fit += scout;
  var team = h.team, opp = h.opp;
  final tq = [...h.teamQuarters], oq = [...h.oppQuarters];
  for (var q = 0; q < 2; q++) {
    final sc = h.scale;
    final t = max(
        (8 * sc).round(),
        (sc *
                (18 +
                    (h.mine - 50) * 0.12 +
                    shift +
                    boost +
                    fit +
                    h.style.pace +
                    _noise(rng) * 5 * noiseMul))
            .round());
    final o = max(
        (8 * sc).round(),
        (sc *
                (18 +
                    (h.oppStrength - 50) * 0.12 +
                    shift +
                    h.style.pace +
                    _noise(rng) * 5 * noiseMul))
            .round());
    tq.add(t);
    oq.add(o);
    team += t;
    opp += o;
  }
  // ファウル: 守りを固めると増える。前半と合わせて5つで退場(最後のクォーターに出られない)。
  final foulMul = switch (choice) {
    Halftime.defense => 1.5,
    Halftime.tempo => 1.2,
    Halftime.star => 1.1,
    Halftime.keep => 1.0,
  };
  final fouls = min(5, h.fouls + foulsOf(p, 2, foulMul, rng));
  final fouledOut = fouls >= 5;
  if (fouledOut) team = max(0, team - (3 * h.scale).round()); // 最後のクォーターに主力がいない
  var pts = (team * (h.share + shareAdd).clamp(0.04, 0.55) * h.form).round();
  if (fouledOut) {
    pts = (pts * 0.8).round();
  } else if (fouls == 4) {
    pts = (pts * 0.94).round(); // 4つ目からは慎重に守る
  }
  // 3Pの本数: 得点のうち外から決める割合(3P、ミドル、ゴール下の比)。
  final tp = p.effective(Ability.threePoint);
  final mid = p.effective(Ability.midRange);
  final ins = p.effective(Ability.inside);
  final threeShare = tp / (tp + mid + ins + 1);
  final threes =
      max(0, (pts * threeShare * 0.55 / 3 + _noise(rng) * 0.6).round());
  return MatchState(
    team: team,
    opp: opp,
    points: pts,
    steals: h.steals,
    blocks: h.blocks,
    threes: threes,
    rebounds: h.rebounds,
    assists: h.assists,
    teamStrength: h.mine,
    oppStrength: h.oppStrength,
    form: h.form,
    teamQuarters: tq,
    oppQuarters: oq,
    opponent: h.opponent,
    vsRival: h.vsRival,
    fouls: fouls,
    fouledOut: fouledOut,
    scale: h.scale,
    gameMinutes: h.gameMinutes,
    starter: h.starter,
  );
}

/// 自動で選ぶ作戦。追っていればペース、リードしていれば守り、僅差でエースが強ければエース。
/// 相手の持ち味との相性(`OppStyle.fit`)も足して、いちばん点が取れる作戦を選ぶ。
Halftime bestHalftime(Player p, MatchHalf h) {
  final m = h.margin / h.scale; // 点数の規模が違っても、同じ感覚で判断する
  Halftime base;
  if (m <= -4) {
    base = Halftime.tempo;
  } else if (m >= 6) {
    base = Halftime.defense;
  } else if (m <= 2 && starPower(p) >= 1.0 && p.overall >= 60) {
    base = Halftime.star;
  } else {
    base = Halftime.keep;
  }
  // ファウルトラブル(前半で3つ以上)なら、ファウルが増える守り・エースは避ける。
  if (h.foulTrouble && (base == Halftime.defense || base == Halftime.star)) {
    base = Halftime.keep;
  }
  if (h.style == OppStyle.balanced) return base;
  var best = base;
  var bestScore = -99.0;
  for (final c in Halftime.values) {
    final trouble = h.foulTrouble && (c == Halftime.defense || c == Halftime.star) ? 1.0 : 0.0;
    final score =
        (c == base ? 0.6 : (c == Halftime.keep ? 0.3 : 0.0)) + h.style.fit(c, p) - trouble;
    if (score > bestScore) {
      best = c;
      bestScore = score;
    }
  }
  return best;
}

/// 4クォーターを通して進める(作戦は `halftime`、省略すると自動)。点差が近ければ [MatchState.needsClutch]。
MatchState playQuarters(
  Player p, {
  required double teamStrength,
  required double oppStrength,
  required double form,
  required Random rng,
  String opponent = '',
  bool vsRival = false,
  Halftime? halftime,
  OppStyle style = OppStyle.balanced,
}) {
  final h = playFirstHalf(p,
      teamStrength: teamStrength,
      oppStrength: oppStrength,
      form: form,
      rng: rng,
      opponent: opponent,
      vsRival: vsRival,
      style: style);
  return playSecondHalf(p, h, halftime ?? bestHalftime(p, h), rng);
}

/// 試合を締める。勝負どころなら `choice`(null なら成功率の高いプレーを自動で選ぶ)で決める。
MatchResult finishMatch(Player p, MatchState s, Clutch? choice, Random rng) {
  var team = s.team, opp = s.opp, points = s.points, assists = s.assists;
  Clutch? used;
  bool? ok;
  if (s.needsClutch) {
    final c = choice ?? bestClutch(p, s.oppStrength, s.form);
    used = c;
    var success = rng.nextDouble() <
        clutchChance(p, c, s.oppStrength, s.form,
            timeout: s.timeout, zone: s.zone, vsRival: s.vsRival);
    if (c == Clutch.drawFoul) {
      // ファウルを誘えたか→フリースロー2本。入った本数だけ得点(2本とも入れば成功)。
      var made = 0;
      if (rng.nextDouble() < foulDrawChance(p, s.oppStrength)) {
        final ft = freeThrowChance(p, s.form);
        for (var i = 0; i < 2; i++) {
          if (rng.nextDouble() < ft) made++;
        }
      }
      team += made;
      points += made;
      success = made == 2;
    }
    ok = success;
    switch (c) {
      case Clutch.drive:
        if (success) {
          team += 2;
          points += 2;
        }
      case Clutch.threePoint:
        if (success) {
          team += 3;
          points += 3;
        }
      case Clutch.pass:
        if (success) {
          team += 2;
          assists += 1;
        }
      case Clutch.defend:
        // 守れなければ、相手が最後に決める。
        if (!success) opp += 2;
      case Clutch.drawFoul:
        break; // 得点は上で加算済み
    }
  }

  // 同点なら延長戦(5分。1クォーターの半分ほどの得点)。決着がつくまで、最大3回。
  var overtimes = 0;
  while (team == opp && overtimes < 3) {
    overtimes++;
    final share = s.team == 0 ? 0.15 : (points / max(1, s.team)).clamp(0.04, 0.55);
    final t = max(
        (4 * s.scale).round(),
        (s.scale * (9 + (s.teamStrength - 50) * 0.06 + _noise(rng) * 3)).round());
    final o = max(
        (4 * s.scale).round(),
        (s.scale * (9 + (s.oppStrength - 50) * 0.06 + _noise(rng) * 3)).round());
    team += t;
    opp += o;
    points += (t * share).round();
  }
  final bool won;
  if (team == opp) {
    // 3回延長しても同点なら、最後の1本で決まる。
    won = rng.nextDouble() < 0.5 + (s.teamStrength - s.oppStrength) / 200;
    if (won) {
      team += 2;
    } else {
      opp += 2;
    }
  } else {
    won = team > opp;
  }

  return MatchResult(
    won: won,
    teamScore: team,
    oppScore: opp,
    points: points,
    rebounds: s.rebounds,
    assists: assists,
    steals: s.steals,
    blocks: s.blocks,
    threes: s.threes + (used == Clutch.threePoint && ok == true ? 1 : 0),
    clutch: used,
    clutchSuccess: ok,
    teamQuarters: s.teamQuarters,
    oppQuarters: s.oppQuarters,
    opponent: s.opponent,
    vsRival: s.vsRival,
    fouls: s.fouls,
    fouledOut: s.fouledOut,
    overtimes: overtimes,
    starter: s.starter,
    box: boxScoreOf(p,
        starter: s.starter,
        points: points,
        threes: s.threes + (used == Clutch.threePoint && ok == true ? 1 : 0),
        form: s.form,
        gameMinutes: s.gameMinutes + 5 * overtimes,
        fouledOut: s.fouledOut,
        rng: rng),
  );
}

/// 1試合を通して進める(勝負どころは `chooseClutch` が選ぶ。null なら自動)。
MatchResult simulateMatch(
  Player p, {
  required double teamStrength,
  required double oppStrength,
  required double form,
  required Random rng,
  Clutch Function(int margin)? chooseClutch,
  String opponent = '',
  bool vsRival = false,
}) {
  final s = playQuarters(p,
      teamStrength: teamStrength,
      oppStrength: oppStrength,
      form: form,
      rng: rng,
      opponent: opponent,
      vsRival: vsRival);
  final choice = s.needsClutch ? chooseClutch?.call(s.margin) : null;
  return finishMatch(p, s, choice, rng);
}

/// 期待値がいちばん高いプレー。3P は成功率が低くても点が大きいので重みを付ける。
Clutch bestClutch(Player p, double oppStrength, double form) {
  Clutch best = Clutch.drive;
  var bestScore = -1.0;
  for (final c in Clutch.values) {
    // 期待値(2点を1とする)。ファウルは1本でも点になるので、成功率ではなく期待本数で比べる。
    final value = c == Clutch.drawFoul
        ? foulDrawChance(p, oppStrength) * freeThrowChance(p, form)
        : clutchChance(p, c, oppStrength, form) *
            (c == Clutch.threePoint ? 1.5 : 1.0);
    if (value > bestScore) {
      bestScore = value;
      best = c;
    }
  }
  return best;
}
