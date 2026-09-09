import 'dart:math';

import '../models/career.dart';
import '../models/development.dart';
import '../models/objective.dart';
import '../models/season.dart';
import '../models/training.dart';
import '../models/traits.dart';
import 'formulas.dart';
import 'match_engine.dart';

/// 今週やることの重み。上ほど先に出す。
enum WeekFocus {
  /// 離脱中。試合も練習もできない。
  injured,

  /// 疲れが残っている。休むほうが試合に効く。
  rest,

  /// 相手の戦い方が、自分の手を潰しにくる。
  matchup,

  /// 監督の期待に届いていない。
  objective,

  /// 特にどうということはない。積み上げる週。
  steady,
}

/// 「今週なにをするか」を、次の相手・監督の期待・体の状態から1つに絞る。
///
/// 練習は育成タブ、相手はクラブタブ、監督の期待は試合タブと、
/// 判断に要るものが3か所に散っていた。決めるのは1つなので、
/// 決める場所に材料を集める。
class WeekPlan {
  const WeekPlan({
    required this.focus,
    required this.headline,
    required this.reason,
    this.suggested,
  });

  final WeekFocus focus;

  /// 一言。「疲れが残っている」など。
  final String headline;

  /// なぜそう言えるのか。数字で書く。
  final String reason;

  /// 一手で切り替えられる練習。無ければ null。
  final TrainingMenu? suggested;

  /// これ以下のコンディションなら、練習より休養を勧める。
  static const int tiredCondition = 48;

  static WeekPlan of(CareerState state) {
    if (state.suspended) {
      return WeekPlan(
        focus: WeekFocus.injured,
        headline: '出場停止',
        reason: 'あと${state.suspension}試合は出られない。'
            '練習はできるので、戻ったときのために積んでおく。',
      );
    }
    if (state.injured) {
      final injury = state.injury!;
      return WeekPlan(
        focus: WeekFocus.injured,
        headline: '離脱中',
        reason: '${injury.name}。あと${injury.matchesOut}試合は戻れない。',
      );
    }

    final condition = state.player.condition;
    if (condition <= tiredCondition) {
      final loss = (Formulas.conditionBaseline - condition) *
          Formulas.conditionChanceSlope *
          100;
      return WeekPlan(
        focus: WeekFocus.rest,
        headline: '疲れが残っている',
        reason: 'コンディション$condition。'
            'このまま出ると、どの手も ${loss.toStringAsFixed(1)}% 通りにくい。',
        suggested: TrainingMenu.lightWork,
      );
    }

    // 次の相手が潰しにくる能力。慣れているぶんは戻る。
    if (!state.seasonFinished) {
      final opponent = state.opponentFor(state.matchday);
      final style = ClubStyle.of(opponent);
      final penalty = (-0.05 +
              state.development.adaptationFor(style,
                  factor: state.player.traits.adaptationFactor)) *
          100;
      final menu = TrainingMenu.forKey(style.hardFor);
      return WeekPlan(
        focus: WeekFocus.matchup,
        headline: '${opponent.name}は${style.label}',
        reason: '${style.description}。'
            '${style.hardFor.label}の局面が ${penalty.toStringAsFixed(1)}% 通りにくい'
            '（${state.development.faced[style] ?? 0}回戦って慣れてきたぶんを含む）。',
        suggested: menu.availableFor(state.player.position) ? menu : null,
      );
    }

    final objective = state.objective;
    if (objective != null) {
      final stats = state.seasonStats;
      if (!objective.achieved(stats)) {
        return WeekPlan(
          focus: WeekFocus.objective,
          headline: '監督の期待に届いていない',
          reason: _objectiveGap(objective, stats),
        );
      }
    }

    return const WeekPlan(
      focus: WeekFocus.steady,
      headline: '積み上げる週',
      reason: '急ぎの用は無い。伸ばしたい能力に時間を使える。',
    );
  }

  static String _objectiveGap(SeasonObjective objective, SeasonStats stats) {
    final parts = <String>[];
    if (stats.appearances < objective.appearances) {
      parts.add('出場 あと${objective.appearances - stats.appearances}試合');
    }
    if (stats.goals + stats.assists < objective.contributions) {
      parts.add(
          '得点関与 あと${objective.contributions - stats.goals - stats.assists}');
    }
    if (stats.averageRating < objective.rating) {
      parts.add('平均評価 ${objective.rating.toStringAsFixed(2)} に届いていない');
    }
    return '${parts.join('・')}。3つのうち2つで達成。';
  }
}

/// 次節、先発できそうか。
///
/// 出場機会は評価点・監督の信頼・方針・競争相手で決まるが、その式は
/// どこにも出ていなかった。落ちた理由が分からないまま数試合が過ぎるのが
/// 一番きつい。判定と同じ式（[MatchEngine.decideAppearance]）から出す。
class SelectionOutlook {
  const SelectionOutlook({
    required this.likely,
    required this.average,
    required this.bonus,
    required this.forgiveness,
    required this.debut,
  });

  /// 見込み。ローテーションで前後するので「必ず」ではない。
  final Appearance likely;

  /// 直近の評価点の平均（下駄を含まない素の値）。
  final double average;

  /// 監督の信頼・方針・競争相手ぶんの下駄。
  final double bonus;

  /// 外れ続けているぶんの情け。
  final double forgiveness;

  /// まだ評価点が付いていないか。
  final bool debut;

  /// 判定に使われる値。
  double get effective => average + bonus + forgiveness;

  static SelectionOutlook of(CareerState state, {required double bonus}) {
    final rated = state.leagueResults
        .where((r) => r.rating != null)
        .map((r) => r.rating!)
        .toList();
    if (rated.isEmpty) {
      return const SelectionOutlook(
        likely: Appearance.start,
        average: 0,
        bonus: 0,
        forgiveness: 0,
        debut: true,
      );
    }
    // 判定と同じ式。試合数が足りないぶんは基準点で埋まっている。
    final average = MatchEngine.formAverage(rated);
    final forgiveness = min(
      MatchEngine.idleRun(state.leagueResults) * Formulas.benchRecoveryPerMatch,
      Formulas.benchRecoveryMax,
    );
    return SelectionOutlook(
      likely: MatchEngine.decideAppearance(state.leagueResults, bonus: bonus),
      average: average,
      bonus: bonus,
      forgiveness: forgiveness,
      debut: false,
    );
  }

  /// 画面に出す一言。
  String get headline => switch (likely) {
        Appearance.start => '先発の見込み',
        Appearance.sub => '途中出場の見込み',
        Appearance.benched => 'ベンチ外の見込み',
        Appearance.injured => '出られない',
        Appearance.suspended => '出場停止',
      };

  /// なぜそうなるのか。数字で書く。
  String get reason {
    if (debut) return 'まだ評価点が付いていない。デビュー戦は必ず先発する。';
    final parts = <String>[
      '直近${Formulas.formWindow}試合の平均 ${average.toStringAsFixed(2)}',
    ];
    if (bonus.abs() >= 0.01) {
      parts.add('${bonus > 0 ? '信頼と序列で +' : '信頼と序列で '}'
          '${bonus.toStringAsFixed(2)}');
    }
    if (forgiveness >= 0.01) {
      parts.add('外れているぶん +${forgiveness.toStringAsFixed(2)}');
    }
    return '${parts.join('・')}。'
        '先発の線は ${Formulas.benchThreshold.toStringAsFixed(1)}、'
        'ベンチ入りの線は ${Formulas.squadThreshold.toStringAsFixed(1)}。';
  }
}
