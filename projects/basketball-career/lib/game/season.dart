import 'dart:math';

import 'match.dart';
import 'player.dart';

/// 大会の舞台。段階ごとに味方と相手の強さが違う。
enum League {
  minibasket('ミニバス', 3, 34, 36),
  juniorHigh('中学', 4, 42, 44),
  highSchool('高校', 5, 50, 52),
  university('大学', 4, 56, 58),
  corporate('実業団', 4, 55, 57),
  proDomestic('国内プロ', 6, 62, 64),
  proAbroad('海外プロ', 6, 72, 76),
  national('日本代表', 4, 66, 78);

  const League(this.label, this.rounds, this.teamStrength, this.oppBase);
  final String label;

  /// 勝ち抜きの試合数(国内/海外プロは全試合を戦う)。
  final int rounds;
  final double teamStrength;
  final double oppBase;

  bool get elimination => this != proDomestic && this != proAbroad;

  /// レギュラーシーズンの後のプレーオフの試合数(プロだけ。準決勝・決勝の2つ)。
  int get playoffRounds => elimination ? 0 : 2;

  /// プレーオフに進める勝ち数(レギュラーシーズンの半分)。
  int get qualifyWins => (rounds + 1) ~/ 2;
}

/// 大会(1シーズン)の結果。
class TournamentResult {
  const TournamentResult({
    required this.league,
    required this.matches,
    required this.wins,
    required this.achievement,
  });

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
  double get individual => individualRating(ppg, rpg, apg);

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
      : playoffMatches.length == league.playoffRounds &&
          playoffMatches.every((m) => m.won);
  double get ppg => games == 0 ? 0 : matches.fold(0, (s, m) => s + m.points) / games;
  double get rpg => games == 0 ? 0 : matches.fold(0, (s, m) => s + m.rebounds) / games;
  double get apg => games == 0 ? 0 : matches.fold(0, (s, m) => s + m.assists) / games;
}

/// 回戦の呼び名。
String roundLabelOf(League league, int r) {
  if (league.playoffRounds > 0 && r >= league.rounds) {
    return r == league.rounds ? 'プレーオフ準決勝' : 'プレーオフ決勝';
  }
  return '${r + 1}回戦';
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
      this.pending,
      this.pendingHalf,
      this.askHalftime = false,
      this.teamBonus = 0})
      : matches = matches ?? [];

  final League league;

  /// ハーフタイムの作戦を自分で選ぶ大会か(続きの試合でも同じ)。
  final bool askHalftime;

  /// チームワークによる、味方の強さへの上乗せ(−4〜+4くらい)。
  final double teamBonus;
  final List<MatchResult> matches;
  int round;
  int wins;

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
    // プロ: レギュラーシーズン→(半分以上勝てば)プレーオフ。プレーオフは負けたら終わり。
    final total = league.rounds + league.playoffRounds;
    if (round >= total) return true;
    if (round == league.rounds) {
      final regular = matches.where((m) => m.won).length;
      return regular < league.qualifyWins;
    }
    if (round > league.rounds) return !matches.last.won;
    return false;
  }

  /// その回戦の呼び名(プロのプレーオフは「プレーオフ準決勝」「プレーオフ決勝」)。
  String roundLabel(int r) => roundLabelOf(league, r);

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
      final opp = pickOpponent?.call(round, isFinal);
      final strength = league.oppBase +
          round * 2.5 +
          (rng.nextDouble() - 0.5) * 8 +
          (opp?.bonus ?? 0);
      final h = playFirstHalf(
        p,
        teamStrength: league.teamStrength + teamBonus,
        oppStrength: strength,
        form: form,
        rng: rng,
        opponent: opp?.name ?? '',
        vsRival: opp?.rival ?? false,
      );
      Halftime? hc;
      if (h.needsDecision) {
        hc = chooseHalftime?.call(h.margin);
        if (hc == null && askHalftime) {
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
    final s = playSecondHalf(p, h, hc, rng);
    Clutch? choice;
    if (s.needsClutch) {
      choice = chooseClutch?.call(s.margin);
      if (choice == null && askClutch) {
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
    final m = finishMatch(p, s, choice, rng);
    matches.add(m);
    if (m.won) wins++;
    round++;
  }

  TournamentResult result() {
    final n = matches.length;
    final ppg = n == 0 ? 0.0 : matches.fold(0, (s, m) => s + m.points) / n;
    final rpg = n == 0 ? 0.0 : matches.fold(0, (s, m) => s + m.rebounds) / n;
    final apg = n == 0 ? 0.0 : matches.fold(0, (s, m) => s + m.assists) / n;
    final regular = matches.take(league.rounds).where((m) => m.won).length;
    final playoff = matches.skip(league.rounds).where((m) => m.won).length;
    final achievement = regular / league.rounds * 60 +
        individualRating(ppg, rpg, apg) * 0.4 +
        playoff * 6;
    return TournamentResult(
      league: league,
      matches: matches,
      wins: wins,
      achievement: achievement.clamp(0, 100).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'league': league.name,
        'matches': [for (final m in matches) m.toJson()],
        'round': round,
        'wins': wins,
        'teamBonus': teamBonus,
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
        teamBonus: (j['teamBonus'] as num?)?.toDouble() ?? 0,
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
