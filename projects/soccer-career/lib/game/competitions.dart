import 'dart:math';

import '../models/career.dart';
import '../models/competition.dart';
import 'eligibility.dart';
import 'formulas.dart';
import 'world.dart';

/// 大陸カップ・昇格プレーオフ・移籍市場の窓・登録メンバー。
///
/// どれも「シーズンの外側」の仕組み。試合中の操作は増やさず、
/// シーズンの区切りで結果として現れる。
class Competitions {
  Competitions({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// 今シーズン、大陸カップでどこまで行ったか。
  ///
  /// 出場していなければ none。クラブの強さと国の格で勝ち上がりが決まる。
  ContinentalStage runContinental(CareerState state, {required bool qualified}) {
    if (!qualified) return ContinentalStage.none;

    final country = World.byId(state.club.countryId);
    // 大陸の平均的な強さと比べる。格の低い国のクラブはグループで消える。
    final field = 60 + country.confederation.index * 2;
    final edge = (state.club.strength - field) / 22;

    var stage = ContinentalStage.group;
    for (final next in [
      ContinentalStage.round16,
      ContinentalStage.quarter,
      ContinentalStage.semi,
      ContinentalStage.runnerUp,
      ContinentalStage.winner,
    ]) {
      final chance = (0.45 + edge).clamp(0.05, 0.85);
      if (_random.nextDouble() >= chance) break;
      stage = next;
    }
    return stage;
  }

  /// 移籍市場の窓。シーズンの節の位置で決まる。
  ///
  /// 冬の窓は中盤の数節だけ。ここを逃すとシーズン終了まで動けない。
  TransferWindow windowAt(CareerState state) {
    if (state.seasonFinished) return TransferWindow.summer;
    final total = state.fixtures.length;
    final matchday = state.matchday;
    final winterFrom = (total * 0.45).round();
    final winterTo = winterFrom + 2;
    if (matchday >= winterFrom && matchday <= winterTo) {
      return TransferWindow.winter;
    }
    return TransferWindow.closed;
  }

  /// 登録メンバーに入れるか。
  ///
  /// 外国人枠が埋まっていれば外れる。枠に余裕があっても、クラブの中で
  /// 力が足りなければ25人に入れない。加入した瞬間に「登録外」になりうる
  /// のが現実で、それがローンに出る動機になる。
  SquadStatus registrationFor(CareerState state) {
    final country = World.byId(state.club.countryId);
    final foreign =
        Eligibility.isForeignIn(state.player.nationality, country);

    if (foreign) {
      final limit = country.foreignRule.squadLimit;
      if (limit != null) {
        final used = Eligibility.usedSlots(state.club, country);
        // 自分の分が入らないなら登録外。
        if (used >= limit) return SquadStatus.outOfSquad;
      }
    }

    // クラブの中での力量。大きく劣ると25人に入れない。
    final gap = state.player.overall - state.club.strength;
    if (gap < Formulas.squadRegistrationGap) return SquadStatus.outOfSquad;
    return SquadStatus.registered;
  }

  /// 昇格プレーオフの相手と結果。
  ///
  /// 3〜6位で回る。順位が上ほど勝ち上がりやすいが、確実ではない。
  bool winsPromotionPlayoff(int position) {
    final chance = (0.5 - (position - 3) * 0.09).clamp(0.15, 0.5);
    return _random.nextDouble() < chance;
  }

  /// 大陸カップの成績が国の格に効く。
  ///
  /// 自分のクラブが勝ち上がると、その国のリーグの評価が上がる。
  /// リーグ係数が動くと、翌年以降の出場枠と年俸水準が変わる。
  int coefficientGain(ContinentalStage stage) => switch (stage) {
        ContinentalStage.winner => 3,
        ContinentalStage.runnerUp => 2,
        ContinentalStage.semi => 1,
        _ => 0,
      };
}
