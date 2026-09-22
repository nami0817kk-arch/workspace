/// 監督に何を約束できるか。
///
/// 監督の目標（`SeasonObjective`）を土台に、3つの出方を作る。
/// 保存はしない。同じ状態からは毎回同じ3つが出る。
library;

import '../models/attributes.dart';
import '../models/career.dart';
import '../models/promise.dart';

class PromiseOffers {
  const PromiseOffers._();

  /// これより後の節では、もう約束できない。
  ///
  /// シーズンの終わりに「あと1点だから約束する」ができてしまうと、
  /// 賭けではなく後出しになる。
  static const int window = 8;

  /// 今、約束できるか。
  ///
  /// 1シーズンに1つだけ。取り消せない。
  static bool canPromise(CareerState state) =>
      state.promise == null &&
      state.objective != null &&
      !state.seasonFinished &&
      state.matchday <= window;

  /// 監督の求める数字に、どれだけ上乗せするか。
  ///
  /// **ここは実測で決めてある**（`test/promise_sim.dart`、2304シーズン）。
  /// 狙いは「控えめ ≒ 3回に2回、順当 ≒ 五分より少し上、大きく出る ≒ 3回に1回」。
  ///
  /// **世界の側が動くと、この順はずれる。** 2回逆転した:
  /// - 最初の案（出場+2 / 得点関与+3 / ゴール+4）では
  ///   **順当（23.5%）が大きく出る（27.0%）より難しかった**。
  /// - 2026-09-22 に測り直したら、**控えめ（61.9%）が順当（67.2%）より難しく**、
  ///   ゴール（52.9%）が得点関与（33.1%）より易しかった。9/10 に合わせた後、
  ///   平均評価が 7.07 → 7.20 に上がり（順当が易しく）、上のクラブへ移って
  ///   出場が減り（控えめが難しく）、流れの1本と布石でゴールが増えた。
  ///   **控えめが順当より難しいと、見返りも小さいので押す理由が1つも無い。**
  ///   いまは 控えめ 66.3% / 順当 56.2% / 大きく出る 33.2%
  ///   （ゴール 33.2% ・ 得点関与 33.1%）。
  ///
  /// 評価や得点の効きを変えたら、ここも測り直す。
  static const int appearancesOver = -8;
  static const double ratingOver = -0.38;
  static const int goalsOver = -2;
  static const int contributionsOver = -6;

  /// 選べる3つ。控えめ・順当・大きく出る。
  static List<ManagerPromise> forState(CareerState state) {
    final objective = state.objective;
    if (objective == null) return const [];
    final year = state.year;

    // 前に出るポジションなら、ゴールで大きく出られる。
    // 後ろの選手にゴール数を約束させても、ただの罰にしかならない。
    final family = state.player.position.family;
    final attacking =
        family == ScenarioFamily.forward || state.player.position == Position.am;

    return [
      // 「試合に出続ける」。一番地味で、一番落としやすい。
      ManagerPromise(
        kind: PromiseKind.appearances,
        target: (objective.appearances + appearancesOver).toDouble(),
        weight: PromiseWeight.modest,
        year: year,
      ),
      // 「毎試合こなす」。1試合の当たり外れでは動かない数字。
      ManagerPromise(
        kind: PromiseKind.rating,
        target: objective.rating + ratingOver,
        weight: PromiseWeight.fair,
        year: year,
      ),
      if (attacking)
        // 前の選手は、得点関与の目標を超えるゴールを口にする。
        ManagerPromise(
          kind: PromiseKind.goals,
          target: (objective.contributions + goalsOver).toDouble(),
          weight: PromiseWeight.bold,
          year: year,
        )
      else
        ManagerPromise(
          kind: PromiseKind.contributions,
          target: (objective.contributions + contributionsOver).toDouble(),
          weight: PromiseWeight.bold,
          year: year,
        ),
    ];
  }
}
