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
  proAbroad('海外プロ', 6, 72, 76);

  const League(this.label, this.rounds, this.teamStrength, this.oppBase);
  final String label;

  /// 勝ち抜きの試合数(国内/海外プロは全試合を戦う)。
  final int rounds;
  final double teamStrength;
  final double oppBase;

  bool get elimination => this != proDomestic && this != proAbroad;
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
  bool get champion => wins == league.rounds;
  double get ppg => games == 0 ? 0 : matches.fold(0, (s, m) => s + m.points) / games;
  double get rpg => games == 0 ? 0 : matches.fold(0, (s, m) => s + m.rebounds) / games;
  double get apg => games == 0 ? 0 : matches.fold(0, (s, m) => s + m.assists) / games;
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
      this.teamBonus = 0})
      : matches = matches ?? [];

  final League league;

  /// チームワークによる、味方の強さへの上乗せ(−4〜+4くらい)。
  final double teamBonus;
  final List<MatchResult> matches;
  int round;
  int wins;

  /// 勝負どころで選択を待っている試合。null なら止まっていない。
  MatchState? pending;

  bool get finished =>
      pending == null &&
      (round >= league.rounds ||
          (league.elimination && matches.isNotEmpty && !matches.last.won));

  /// 次の試合の対戦相手の名前(待機中はその試合の相手)。
  String? get nextOpponent => pending?.opponent;

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
  }) {
    while (pending == null && !finished) {
      final isFinal = round == league.rounds - 1;
      final opp = pickOpponent?.call(round, isFinal);
      final strength = league.oppBase +
          round * 2.5 +
          (rng.nextDouble() - 0.5) * 8 +
          (opp?.bonus ?? 0);
      final s = playQuarters(
        p,
        teamStrength: league.teamStrength + teamBonus,
        oppStrength: strength,
        form: form,
        rng: rng,
        opponent: opp?.name ?? '',
        vsRival: opp?.rival ?? false,
      );
      Clutch? choice;
      if (s.needsClutch) {
        choice = chooseClutch?.call(s.margin);
        if (choice == null && askClutch) {
          pending = s;
          return;
        }
      }
      _finish(p, s, choice, rng);
    }
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
        form: form, rng: rng, askClutch: askClutch, pickOpponent: pickOpponent);
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
    final achievement =
        wins / league.rounds * 60 + individualRating(ppg, rpg, apg) * 0.4;
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
        pending: j['pending'] == null
            ? null
            : MatchState.fromJson((j['pending'] as Map).cast<String, dynamic>()),
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
