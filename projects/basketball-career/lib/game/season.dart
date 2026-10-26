import 'dart:math';

import 'match.dart';
import 'player.dart';

/// 大会の舞台。段階ごとに味方と相手の強さが違う。
enum League {
  minibasket('ミニバス', 3, 34, 36),
  juniorHigh('中学', 4, 42, 44),
  highSchool('高校', 5, 50, 52),
  university('大学', 6, 56, 58),
  corporate('実業団', 6, 55, 57),
  proDomestic('国内プロ', 6, 62, 64),
  proAbroad('海外プロ', 6, 72, 76),
  national('日本代表', 3, 66, 78);

  const League(this.label, this.rounds, this.teamStrength, this.oppBase);
  final String label;

  /// 勝ち抜きの試合数(国内/海外プロは全試合を戦う)。
  final int rounds;
  final double teamStrength;
  final double oppBase;

  /// 大会の形式。決勝トーナメント(プレーオフ)の各ラウンドの試合数(先に過半数を取ると勝ち抜け)。
  /// 空なら、負けたら終わりの勝ち抜き戦(ミニバス・中学・高校)。
  /// 大学・実業団はリーグ戦(6試合)のあと決勝トーナメント、日本代表は予選グループ(3試合)のあと決勝トーナメント(3回)、
  /// 国内プロは準決勝3戦・決勝5戦、海外の最高峰は準決勝5戦・決勝7戦(先に過半数)。
  List<int> get playoffSeries => switch (this) {
        League.university => const [1, 1, 1],
        League.corporate => const [1, 1],
        League.national => const [1, 1, 1],
        League.proDomestic => const [3, 5],
        League.proAbroad => const [5, 7],
        _ => const [],
      };

  bool get elimination => playoffSeries.isEmpty;

  /// 決勝トーナメントの名前と、予選(リーグ戦)の名前。
  String get playoffName => switch (this) {
        League.proDomestic || League.proAbroad => 'プレーオフ',
        _ => '決勝トーナメント',
      };
  String get regularName => switch (this) {
        League.proDomestic || League.proAbroad => 'レギュラーシーズン',
        League.national => '予選グループ',
        _ => 'リーグ戦',
      };

  /// 相手が強くなる幅。予選(リーグ戦)は1試合ごとに `regularStep`、決勝トーナメントは1ラウンドごとに `playoffStep`。
  /// 勝ち抜き戦は1回戦ごとに +2.5。シリーズ(先に過半数)は1試合ごとの差が積み上がるので、決勝トーナメントの上げ幅は小さめ。
  double get regularStep => switch (this) {
        League.university => 0.9,
        League.corporate => 1.1,
        League.national => 1.5,
        _ => 2.5,
      };
  double get playoffStep => switch (this) {
        League.university => 0.8,
        League.corporate => 2.0,
        League.national => 1.5,
        League.proDomestic => 1.4,
        League.proAbroad => -1.0,
        _ => 2.5,
      };

  /// `round`(0 始まり)の試合の、相手の強さの上乗せ。
  double rampAt(int round) {
    if (round < rounds) return round * regularStep;
    return (rounds - 1) * regularStep + (round - rounds + 1) * playoffStep;
  }

  /// ラウンド `i`(0 始まり)で勝ち抜けるのに要る勝ち数。
  int seriesNeed(int i) => (playoffSeries[i] + 1) ~/ 2;

  /// 点数の規模(高校=1.0)。実際のバスケに近づけるため、段階ごとに1試合の点数が違う:
  /// ミニバス約43点・中学約61点・高校約72点・大学約76点・実業団約78点・国内プロ約84点・代表約83点・海外の最高峰約112点。
  /// 勝率は変えず(強さの差も同じ比率で効く)、点数の見た目と、勝負どころに入る点差の窓だけが変わる。
  double get scoreScale => switch (this) {
        League.minibasket => 0.60,
        League.juniorHigh => 0.85,
        League.highSchool => 1.0,
        League.university => 1.05,
        League.corporate => 1.08,
        League.proDomestic => 1.17,
        League.proAbroad => 1.55,
        League.national => 1.15,
      };

  /// 1クォーターの長さ(分)。ミニバス6・中学8・高校〜国内プロ10・海外の最高峰12(4クォーター)。
  int get quarterMinutes => switch (this) {
        League.minibasket => 6,
        League.juniorHigh => 8,
        League.proAbroad => 12,
        _ => 10,
      };

  /// レギュラーシーズンの後のプレーオフの試合数(プロだけ。準決勝・決勝の2つ)。
  int get playoffRounds => playoffSeries.length;

  /// プレーオフに進める勝ち数(レギュラーシーズンの半分)。
  int get qualifyWins => switch (this) {
        League.university => 4,
        League.national => 2,
        _ => (rounds + 1) ~/ 2,
      };

  /// 大会全体で使えるタイムアウトの数(試合数に応じて。大事な試合を選んで使う)。
  int get timeouts => switch (this) {
        League.minibasket || League.juniorHigh => 1,
        League.highSchool || League.university || League.corporate || League.national => 2,
        League.proDomestic || League.proAbroad => 3,
      };
}

/// 大会(1シーズン)の結果。
class TournamentResult {
  const TournamentResult({
    required this.league,
    required this.matches,
    required this.wins,
    required this.achievement,
    this.seriesWon,
  });

  /// 決勝トーナメント(プレーオフ)で勝ち抜けたラウンドの数。null は古い形(試合の勝ちで数える)。
  final int? seriesWon;

  final League league;
  final List<MatchResult> matches;
  final int wins;

  /// 実績 0〜100。勝ち上がり6割・個人の評価4割。進路の評価に入る。
  final double achievement;

  int get steals => matches.fold(0, (s, m) => s + m.steals);
  int get blocks => matches.fold(0, (s, m) => s + m.blocks);
  int get threes => matches.fold(0, (s, m) => s + m.threes);

  /// 1試合の最多得点。
  int get highPoints =>
      matches.fold(0, (s, m) => m.points > s ? m.points : s);

  /// 個人の評価(得点・リバウンド・アシストから)。
  double get individual => individualRating(ppg / league.scoreScale, rpg, apg);

  /// 大会の個人賞。優勝して個人評価が高ければ最優秀選手、個人評価だけ高ければベスト5。
  String? get award {
    if (games < 2) return null;
    if (champion && individual >= 72) return '最優秀選手';
    if (individual >= 80) return 'ベスト5';
    return null;
  }

  int get games => matches.length;

  /// レギュラーシーズン(プロ以外は大会全体)の勝ち数。
  int get regularWins =>
      matches.take(league.rounds).where((m) => m.won).length;

  /// プレーオフの試合(プロだけ)。
  List<MatchResult> get playoffMatches => matches.skip(league.rounds).toList();
  int get playoffWins => playoffMatches.where((m) => m.won).length;

  /// プレーオフに進んだか。
  bool get reachedPlayoffs => playoffMatches.isNotEmpty;

  /// 優勝。プロはプレーオフ(準決勝・決勝)を勝ち抜いたとき。
  bool get champion => league.playoffRounds == 0
      ? wins == league.rounds
      : (seriesWon != null
          ? seriesWon == league.playoffRounds
          : playoffMatches.length == league.playoffRounds &&
              playoffMatches.every((m) => m.won));
  double get ppg => games == 0 ? 0 : matches.fold(0, (s, m) => s + m.points) / games;
  double get rpg => games == 0 ? 0 : matches.fold(0, (s, m) => s + m.rebounds) / games;
  double get apg => games == 0 ? 0 : matches.fold(0, (s, m) => s + m.assists) / games;
}

/// 回戦の呼び名。
String roundLabelOf(League league, int r) {
  if (league.playoffRounds > 0 && r >= league.rounds) {
    final i = r - league.rounds; // 決勝トーナメントの何番目か
    final fromEnd = league.playoffRounds - 1 - i;
    final name = switch (fromEnd) {
      0 => '決勝',
      1 => '準決勝',
      2 => '準々決勝',
      _ => '${i + 1}回戦',
    };
    return '${league.playoffName}$name';
  }
  return league.playoffRounds > 0 ? '${league.regularName} 第${r + 1}節' : '${r + 1}回戦';
}

/// 個人の評価 0〜100(50 が平均)。得点・リバウンド・アシストの1試合平均から。
double individualRating(double ppg, double rpg, double apg) =>
    (50 + (ppg - 8) * 2.0 + (rpg - 4) * 1.5 + (apg - 2) * 2.0)
        .clamp(0, 100)
        .toDouble();

/// 対戦相手の名前と、ライバルかどうかを決める。
typedef OpponentPicker = ({String name, bool rival, double bonus}) Function(
    int round, bool isFinal);

/// 進行中の大会。試合を1つずつ進め、勝負どころで止まって選択を待てる。
class TournamentRun {
  TournamentRun(this.league,
      {List<MatchResult>? matches,
      this.round = 0,
      this.wins = 0,
      this.streak = 0,
      int? timeouts,
      this.pending,
      this.pendingHalf,
      this.askHalftime = false,
      this.scout = 0,
      this.teamBonus = 0,
      this.zones = 0,
      this.momentumMul = 1.0,
      this.seriesWins = 0,
      this.seriesLosses = 0,
      this.seriesWon = 0,
      this.eliminated = false,
      this.seriesOpp})
      : timeouts = timeouts ?? league.timeouts,
        matches = matches ?? [];

  final League league;

  /// いま戦っている決勝トーナメントのシリーズの、勝ち数・負け数。
  int seriesWins;
  int seriesLosses;

  /// 決勝トーナメントで勝ち抜けたラウンドの数。
  int seriesWon;

  /// 決勝トーナメントで負けて、大会が終わったか。
  bool eliminated;

  /// いまのシリーズの相手(名前・ライバルか・強さの上乗せ・強さ)。シリーズのあいだ同じ相手と戦う。
  Map<String, dynamic>? seriesOpp;

  /// ハーフタイムの作戦を自分で選ぶ大会か(続きの試合でも同じ)。
  final bool askHalftime;

  /// チームワークによる、味方の強さへの上乗せ(−4〜+4くらい)。
  final double teamBonus;

  /// 直前に研究(映像分析)をしたときの、相手との相性への上乗せ(0 か 0.6)。
  final double scout;
  final List<MatchResult> matches;
  int round;
  int wins;

  /// ゾーン(特殊能力)の残り回数(習得していれば大会ごとに1回)。
  int zones;

  /// 勢いの効きの倍率(特殊能力「熱血」で1.5)。
  final double momentumMul;

  /// タイムアウトの残り(大会全体で数回だけ)。大事な試合の最後の攻防で使うと成功率が+5%。
  int timeouts;

  /// 勢い: 連勝なら正の数、連敗なら負の数(試合ごとに数える)。次の試合の味方の強さに効く。
  int streak;

  /// 勢いによる味方の強さへの加算。1試合あたり0.8、3試合分(±2.4)まで。
  double get momentum => streak.clamp(-3, 3) * 0.8 * momentumMul;

  /// 勝負どころで選択を待っている試合。null なら止まっていない。
  MatchState? pending;

  /// ハーフタイムの作戦を選ぶのを待っている試合。null なら止まっていない。
  MatchHalf? pendingHalf;

  bool get finished {
    if (pending != null || pendingHalf != null) return false;
    if (league.playoffRounds == 0) {
      return round >= league.rounds ||
          (league.elimination && matches.isNotEmpty && !matches.last.won);
    }
    // リーグ戦(予選)→(規定の勝ち数に届けば)決勝トーナメント(プレーオフ)。決勝トーナメントはシリーズに負けたら終わり。
    final total = league.rounds + league.playoffRounds;
    if (eliminated || round >= total) return true;
    if (round == league.rounds && seriesWins == 0 && seriesLosses == 0) {
      final regular = matches.take(league.rounds).where((m) => m.won).length;
      return regular < league.qualifyWins;
    }
    return false;
  }

  /// 決勝トーナメントを戦っているか。
  bool get inPlayoffs => league.playoffRounds > 0 && round >= league.rounds && round < league.rounds + league.playoffRounds;

  /// いまのシリーズで勝ち抜けに要る勝ち数(決勝トーナメントでなければ1)。
  int get _need => inPlayoffs ? league.seriesNeed(round - league.rounds) : 1;

  /// 選択を自分で決める試合か。シリーズの途中で、どちらもまだ決着がつかない試合は自動で進む
  /// (7戦まで毎試合止まると多すぎるので、リーチがかかった試合と最終戦だけ選ぶ)。
  bool get _decisive => !inPlayoffs || _need == 1 || seriesWins == _need - 1 || seriesLosses == _need - 1;

  /// いまの試合の呼び名(シリーズなら「プレーオフ準決勝 第2戦(1勝0敗)」。それ以外は空)。
  String get _tag {
    if (!inPlayoffs || league.playoffSeries[round - league.rounds] == 1) return '';
    return '${roundLabel(round)} 第${seriesWins + seriesLosses + 1}戦($seriesWins勝$seriesLosses敗)';
  }

  /// その回戦の呼び名(プロのプレーオフは「プレーオフ準決勝」「プレーオフ決勝」)。
  String roundLabel(int r) => roundLabelOf(league, r);

  /// いまの試合の呼び名。シリーズなら何戦目かと勝敗も付く。
  String get currentLabel => _tag.isNotEmpty ? _tag : roundLabel(round);

  /// 次の試合の対戦相手の名前(待機中はその試合の相手)。
  String? get nextOpponent => pending?.opponent ?? pendingHalf?.opponent;

  /// 進められるところまで進める。勝負どころで `chooseClutch` が null を返す(または与えない)
  /// と、`askClutch` が true の場合はそこで止まる([pending])。
  /// `askClutch` が false なら、勝負どころは自動で選ぶ。
  void advance(
    Player p, {
    required double form,
    required Random rng,
    Clutch? Function(int margin)? chooseClutch,
    bool askClutch = false,
    OpponentPicker? pickOpponent,
    Halftime? Function(int margin)? chooseHalftime,
  }) {
    while (pending == null && pendingHalf == null && !finished) {
      final isFinal = round == league.rounds - 1;
      final bool continuing = inPlayoffs && seriesOpp != null;
      final ({String name, bool rival, double bonus})? opp = continuing
          ? (
              name: seriesOpp!['name'] as String,
              rival: seriesOpp!['rival'] as bool,
              bonus: (seriesOpp!['bonus'] as num).toDouble(),
            )
          : pickOpponent?.call(round, isFinal);
      final strength = continuing
          ? (seriesOpp!['strength'] as num).toDouble()
          : league.oppBase +
              league.rampAt(round) +
              (rng.nextDouble() - 0.5) * 8 +
              (opp?.bonus ?? 0);
      if (inPlayoffs && !continuing) {
        seriesOpp = {
          'name': opp?.name ?? '',
          'rival': opp?.rival ?? false,
          'bonus': opp?.bonus ?? 0.0,
          'strength': strength,
        };
      }
      final h = playFirstHalf(
        p,
        scale: league.scoreScale,
        gameMinutes: league.quarterMinutes * 4,
        teamStrength: league.teamStrength + teamBonus + momentum,
        oppStrength: strength,
        form: form,
        rng: rng,
        opponent: opp?.name ?? '',
        vsRival: opp?.rival ?? false,
        style: OppStyle.forTeam(opp?.name ?? '', round),
      );
      Halftime? hc;
      if (h.needsDecision) {
        hc = chooseHalftime?.call(h.margin);
        if (hc == null && askHalftime && _decisive) {
          pendingHalf = h; // 作戦を選ぶまで止まる
          return;
        }
      }
      if (!_secondHalf(p, h, hc ?? bestHalftime(p, h), rng, chooseClutch, askClutch)) {
        return;
      }
    }
  }

  /// 後半を進め、勝負どころなら(選ばせるときは)止まる。試合が終われば true。
  bool _secondHalf(Player p, MatchHalf h, Halftime hc, Random rng,
      Clutch? Function(int margin)? chooseClutch, bool askClutch) {
    final s = playSecondHalf(p, h, hc, rng, scout: scout);
    Clutch? choice;
    if (s.needsClutch) {
      choice = chooseClutch?.call(s.margin);
      if (choice == null && askClutch && _decisive) {
        pending = s;
        return false;
      }
    }
    _finish(p, s, choice, rng);
    return true;
  }

  /// 止まっていたハーフタイムを `choice` で決め、続きを進める。
  void resolveHalftime(
    Player p,
    Halftime choice, {
    required double form,
    required Random rng,
    OpponentPicker? pickOpponent,
    bool askClutch = true,
  }) {
    final h = pendingHalf;
    if (h == null) throw StateError('ハーフタイムで止まっていない');
    pendingHalf = null;
    if (!_secondHalf(p, h, choice, rng, null, askClutch)) return;
    advance(p,
        form: form,
        rng: rng,
        askClutch: askClutch,
        pickOpponent: pickOpponent);
  }

  /// 止まっていた勝負どころを `choice` で決め、続きを進める。
  void resolve(
    Player p,
    Clutch choice, {
    required double form,
    required Random rng,
    OpponentPicker? pickOpponent,
    bool askClutch = true,
  }) {
    final s = pending;
    if (s == null) throw StateError('勝負どころで止まっていない');
    pending = null;
    _finish(p, s, choice, rng);
    advance(p,
        form: form,
        rng: rng,
        askClutch: askClutch,
        pickOpponent: pickOpponent);
  }

  void _finish(Player p, MatchState s, Clutch? choice, Random rng) {
    final tag = _tag;
    var m = finishMatch(p, s, choice, rng);
    if (tag.isNotEmpty) m = m.withTag(tag);
    matches.add(m);
    if (m.won) {
      wins++;
      streak = streak > 0 ? streak + 1 : 1;
    } else {
      streak = streak < 0 ? streak - 1 : -1;
    }
    if (inPlayoffs) {
      // シリーズ: 先に過半数を取れば勝ち抜け、取られれば敗退。
      final need = _need;
      if (m.won) {
        seriesWins++;
      } else {
        seriesLosses++;
      }
      if (seriesWins >= need || seriesLosses >= need) {
        if (seriesWins >= need) {
          seriesWon++;
        } else {
          eliminated = true;
        }
        round++;
        seriesWins = 0;
        seriesLosses = 0;
        seriesOpp = null;
      }
    } else {
      round++;
    }
  }

  TournamentResult result() {
    final n = matches.length;
    final ppg = n == 0 ? 0.0 : matches.fold(0, (s, m) => s + m.points) / n;
    final rpg = n == 0 ? 0.0 : matches.fold(0, (s, m) => s + m.rebounds) / n;
    final apg = n == 0 ? 0.0 : matches.fold(0, (s, m) => s + m.assists) / n;
    final regular = matches.take(league.rounds).where((m) => m.won).length;
    // 勝ち上がり6割: 勝ち抜き戦は勝った回戦の割合、リーグ戦＋決勝トーナメントは 予選の勝率(20)と突破したラウンドの割合(62)。以前の勝ち抜き戦と同じ水準にそろえた。
    final winScore = league.playoffRounds > 0
        ? regular / league.rounds * 20 + seriesWon / league.playoffRounds * 62
        : regular / league.rounds * 60;
    final achievement =
        winScore + individualRating(ppg / league.scoreScale, rpg, apg) * 0.4;
    return TournamentResult(
      league: league,
      matches: matches,
      wins: wins,
      achievement: achievement.clamp(0, 100).toDouble(),
      seriesWon: league.playoffRounds > 0 ? seriesWon : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'league': league.name,
        'matches': [for (final m in matches) m.toJson()],
        'round': round,
        'wins': wins,
        'streak': streak,
        'timeouts': timeouts,
        'zones': zones,
        'momentumMul': momentumMul,
        'seriesWins': seriesWins,
        'seriesLosses': seriesLosses,
        'seriesWon': seriesWon,
        'eliminated': eliminated,
        'seriesOpp': seriesOpp,
        'teamBonus': teamBonus,
        'scout': scout,
        'pending': pending?.toJson(),
        'pendingHalf': pendingHalf?.toJson(),
        'askHalftime': askHalftime,
      };

  factory TournamentRun.fromJson(Map<String, dynamic> j) => TournamentRun(
        League.values.firstWhere(
          (l) => l.name == j['league'],
          orElse: () => League.minibasket,
        ),
        matches: [
          for (final m in (j['matches'] as List?) ?? const [])
            MatchResult.fromJson((m as Map).cast<String, dynamic>()),
        ],
        round: (j['round'] as num?)?.toInt() ?? 0,
        wins: (j['wins'] as num?)?.toInt() ?? 0,
        streak: (j['streak'] as num?)?.toInt() ?? 0,
        timeouts: (j['timeouts'] as num?)?.toInt(),
        zones: (j['zones'] as num?)?.toInt() ?? 0,
        momentumMul: (j['momentumMul'] as num?)?.toDouble() ?? 1.0,
        seriesWins: (j['seriesWins'] as num?)?.toInt() ?? 0,
        seriesLosses: (j['seriesLosses'] as num?)?.toInt() ?? 0,
        seriesWon: (j['seriesWon'] as num?)?.toInt() ?? 0,
        eliminated: (j['eliminated'] as bool?) ?? false,
        seriesOpp: (j['seriesOpp'] as Map?)?.cast<String, dynamic>(),
        teamBonus: (j['teamBonus'] as num?)?.toDouble() ?? 0,
        scout: (j['scout'] as num?)?.toDouble() ?? 0,
        askHalftime: (j['askHalftime'] as bool?) ?? false,
        pending: j['pending'] == null
            ? null
            : MatchState.fromJson((j['pending'] as Map).cast<String, dynamic>()),
        pendingHalf: j['pendingHalf'] == null
            ? null
            : MatchHalf.fromJson(
                (j['pendingHalf'] as Map).cast<String, dynamic>()),
      );
}

/// 大会を戦う。勝ち抜きは負けたら終わり。
/// `chooseClutch` が null なら勝負どころは自動で選ぶ。
TournamentResult playTournament(
  Player p,
  League league, {
  required double form,
  required Random rng,
  Clutch Function(int margin)? chooseClutch,
  OpponentPicker? pickOpponent,
}) {
  final run = TournamentRun(league);
  run.advance(p,
      form: form,
      rng: rng,
      chooseClutch: chooseClutch,
      pickOpponent: pickOpponent);
  return run.result();
}
