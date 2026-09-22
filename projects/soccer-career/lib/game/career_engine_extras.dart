import 'dart:math';

import '../models/career.dart';
import '../models/club.dart';
import '../models/objective.dart';
import '../models/player.dart';
import 'formulas.dart';
import 'national.dart';
import 'person.dart';

/// 代表招集と監督の目標。キャリア本体から切り出してある。
///
/// `career_engine.dart` に全部入れると、シーズン進行の筋が
/// 招集や目標の判定に埋もれて読めなくなる。
class CareerExtras {
  CareerExtras({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// 今季の目標を作る。
  ///
  /// クラブの中での位置づけで難度が変わる。格上のクラブに移れば
  /// 求められる出場数は下がるが、質は高く求められる。
  SeasonObjective objectiveFor({required Player player, required Club club}) {
    // **線は実測から置く。** 18試合・評価 6.3 という古い目安のままで、
    // 実際には1シーズン 29試合・評価 7.2 出ていた——**3つとも達成が 81%、
    // 2つ以上が 89%** で、毎週カードに出している「監督の期待」が
    // ほぼ無条件に付いてくるだけの飾りになっていた（2026-09-23 に測り直した）。
    final gap = player.overall - club.strength;
    final appearances = (28 + gap.clamp(-12, 12)).clamp(8, 36);

    // 攻撃のポジションほど得点関与を求められる。
    final attacking = switch (player.position.family.name) {
      'forward' => 23,
      'midfield' => 14,
      _ => 7,
    };
    final contributions = (attacking + (gap ~/ 4)).clamp(1, 34);
    final rating = (7.1 + gap * 0.02).clamp(6.4, 7.7);

    return SeasonObjective(
      appearances: appearances,
      contributions: contributions,
      rating: double.parse(rating.toStringAsFixed(2)),
    );
  }

  /// 代表に招集されるか。
  ///
  /// 実力（総合力）と、直近の出来の両方が要る。上手いだけでは呼ばれない。
  bool shouldCallUp(CareerState state) {
    // 一芸があれば、総合力の線が下がる。総合力はポジションの重みで出すので、
    // 尖らせるほど下がる——ここを開けないと、尖った育成を選んだ時点で
    // 代表が構造的に消える（実測で 代表12 → 0キャップ）。
    final line =
        Formulas.callUpOverall -
        (Person.standoutOf(state.player) > 0
            ? Formulas.standoutCallUpRelief
            : 0);
    if (state.player.overall < line) return false;

    final rated = state.leagueResults
        .where((r) => r.rating != null)
        .map((r) => r.rating!)
        .toList();
    if (rated.length < Formulas.callUpMinAppearances) return false;

    final window = rated.length <= Formulas.formWindow
        ? rated
        : rated.sublist(rated.length - Formulas.formWindow);
    final average = window.reduce((a, b) => a + b) / window.length;
    if (average >= Formulas.callUpRating) return true;

    // **決めているなら、評価点が届かなくても呼ばれる。**
    // 評価点だけを入口にすると「6.8だが25ゴール」のシーズンが
    // 代表から締め出される。平均は変動を嫌うので、点を取りにいく
    // 遊び方そのものが割に合わなくなっていた。
    final played = state.leagueResults.where((r) => r.appearance.played);
    if (played.isEmpty) return false;
    final acts = played.fold<int>(
      0,
      (a, r) => a + r.decisiveFor(state.player.position),
    );
    return acts / played.length >= Formulas.callUpProduction;
  }

  /// この節を終えたあとに代表ウィークが来るか。
  bool isBreakAfter(int matchday) =>
      National.breakAfterMatchday.contains(matchday);

  /// 代表戦の相手。
  Club pickOpponent() =>
      National.opponents[_random.nextInt(National.opponents.length)];

  /// 契約年数を引く。
  int rollContractYears() =>
      Formulas.contractYearsMin +
      _random.nextInt(
        Formulas.contractYearsMax - Formulas.contractYearsMin + 1,
      );
}
