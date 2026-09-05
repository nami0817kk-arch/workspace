import 'dart:math';

import '../models/player.dart';
import '../models/team.dart';
import 'training_engine.dart';

/// リザーブ(Bチーム)の試合に出た選手1人の出来。
class ReservePerformance {
  final Player player;
  final int goals;
  final double rating;

  const ReservePerformance({
    required this.player,
    required this.goals,
    required this.rating,
  });
}

/// リザーブの試合結果。
class ReserveMatchResult {
  final String opponentName;
  final int goalsFor;
  final int goalsAgainst;
  final List<ReservePerformance> performances;

  const ReserveMatchResult({
    required this.opponentName,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.performances,
  });

  bool get won => goalsFor > goalsAgainst;
}

/// トップチームに絡めない選手が公式戦に出る場。
///
/// これまで控えの選手にあったのは紅白戦だけで、実戦感覚を保つことしか
/// できなかった。若手を獲っても座っているだけで伸びず、不満が溜まる一方に
/// なる。**獲る・育てる・使うの輪が閉じていなかった。**
///
/// リザーブの試合に出ると、実戦感覚が戻り、経験による成長の機会があり、
/// 出場機会への不満が和らぐ。ただしキープレイヤーとして扱っている選手は
/// 別で、Bチームに落とされること自体が不満になる。
class ReserveMatchEngine {
  static final Random _rng = Random();

  /// リザーブの試合に出るのに必要な最低人数。これを割ると試合は行われない。
  static const int minPlayers = 7;

  /// 実戦感覚の回復量。紅白戦(+6想定)より大きい。公式戦に近いため。
  static const int sharpnessGain = 14;

  /// 試合による疲労。
  static const int fatigueCost = 10;

  /// 経験による成長が起きる確率。紅白戦より高い。
  static const double experienceChance = 0.22;

  /// 出場によって和らぐ不満の量。
  static const int happinessRelief = 3;

  /// キープレイヤー・主力として約束した選手をリザーブに置いたときの不満。
  ///
  /// 出せば必ず良い、という作りにはしない。立場を約束した選手を落とすのは
  /// 本人にとって降格であって、出場機会が増えたこととは別の話になる。
  static const int demotionPenalty = 4;

  /// [team]のリザーブに出られる選手。
  ///
  /// スタメン(トップチームで出場中)・負傷・代表招集・ローン放出中は除く。
  /// 出場停止はリーグ戦の処分なのでリザーブには出られる。
  static List<Player> availablePlayers(Team team) => team.players
      .where((p) =>
          !team.startingXI.contains(p.id) &&
          !p.isInjured &&
          !p.isOnInternationalDuty &&
          !p.isLoanedOut)
      .toList();

  /// リザーブの試合を1試合行う。人数が足りなければ null。
  ///
  /// 相手名は呼び出し側から渡す。ここで既定値を持つと表示文字列が
  /// エンジンに紛れ込み、言語の切り替えから漏れる。
  static ReserveMatchResult? play(
    Team team, {
    required String opponentName,
  }) {
    final squad = availablePlayers(team);
    if (squad.length < minPlayers) return null;

    // 出場は11人まで。総合力の高い順ではなく、実戦感覚の低い順に出す。
    // リザーブは「勝つため」ではなく「試合勘を戻すため」の場なので、
    // 必要としている選手から出す方が理にかなう。
    final lineup = [...squad]
      ..sort((a, b) => a.matchSharpness.compareTo(b.matchSharpness));
    final playing = lineup.take(11).toList();

    final strength =
        playing.fold<int>(0, (s, p) => s + p.overall) / playing.length;
    // 相手は同格のリザーブ。実力差が結果に出るが、大きくは振れない。
    final opponentStrength = strength + _rng.nextInt(11) - 5;

    final performances = <ReservePerformance>[];
    var goalsFor = 0;
    for (final p in playing) {
      p.matchSharpness = (p.matchSharpness + sharpnessGain).clamp(0, 100);
      p.fatigue = (p.fatigue + fatigueCost).clamp(0, 100);
      if (_rng.nextDouble() < experienceChance) {
        TrainingEngine.growFromMatchExperience(p);
      }

      // 出場機会そのものは不満を和らげる。ただし上の立場を約束した選手に
      // とっては、Bチームに置かれること自体が不満になる。
      final promoted = p.squadStatus == SquadStatus.keyPlayer ||
          p.squadStatus == SquadStatus.regular;
      p.happiness = (p.happiness +
              (promoted ? -demotionPenalty : happinessRelief))
          .clamp(0, 100);

      final scored = p.position.group == PositionGroup.att &&
          _rng.nextDouble() < 0.18;
      final goals = scored ? 1 : 0;
      goalsFor += goals;
      performances.add(ReservePerformance(
        player: p,
        goals: goals,
        rating: (5.5 + (p.overall - strength) / 20 + goals * 0.8)
            .clamp(4.0, 9.5),
      ));
    }

    final goalsAgainst =
        ((opponentStrength - strength) / 15 + _rng.nextInt(3)).round().clamp(0, 5);

    return ReserveMatchResult(
      opponentName: opponentName,
      goalsFor: goalsFor,
      goalsAgainst: goalsAgainst,
      performances: performances,
    );
  }
}
