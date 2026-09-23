/// **今節の的。**
///
/// 参考にした野球のキャリアゲームは「今週の目標：7安打」を出し、
/// 達成すると「週替わり目標達成！報酬：20万円」と小さく払う。
/// 38試合を同じ顔で並べないための、**近い的**。
///
/// 判定に使う式は増やさない。すでに記録している1試合の結果
/// （ゴール・アシスト・無失点・評価点）だけを見る。
library;

import '../models/attributes.dart';
import '../models/career.dart';
import '../models/season.dart';
import 'formulas.dart';

/// 今節の的。
class MatchTarget {
  const MatchTarget(this.label, this._met);

  /// 画面に出す文。「今節の的: 1ゴール」。
  final String label;

  final bool Function(MatchResult) _met;

  /// その試合で達成したか。**出ていない試合は達成にしない。**
  bool metBy(MatchResult result) => result.appearance.played && _met(result);

  /// その節の的。**節から決まるので、見てから引き直せない。**
  ///
  /// ポジションで求められるものが違う。守る選手に「1ゴール」を出しても
  /// 的にならないので、無失点のほうを見る。
  static MatchTarget of(CareerState state) {
    final family = state.player.position.family;
    // 節ごとに3種を回す。同じ的が続くと、あってもなくても同じになる。
    final turn = state.matchday % 3;
    if (family == ScenarioFamily.forward) {
      return switch (turn) {
        0 => MatchTarget('1ゴール', (r) => r.goals >= 1),
        1 => MatchTarget('得点に絡む', (r) => r.goals + r.assists >= 1),
        _ => MatchTarget('評価 7.0', (r) => (r.rating ?? 0) >= 7.0),
      };
    }
    if (family == ScenarioFamily.midfield) {
      return switch (turn) {
        0 => MatchTarget('1アシスト', (r) => r.assists >= 1),
        1 => MatchTarget('得点に絡む', (r) => r.goals + r.assists >= 1),
        _ => MatchTarget('評価 7.0', (r) => (r.rating ?? 0) >= 7.0),
      };
    }
    return switch (turn) {
      0 => MatchTarget('無失点', (r) => r.conceded == 0),
      1 => MatchTarget('評価 7.0', (r) => (r.rating ?? 0) >= 7.0),
      _ => MatchTarget('失点1以内', (r) => r.conceded <= 1),
    };
  }

  /// 達成したときの報酬（万円）。
  static int get reward => Formulas.matchTargetReward;
}
