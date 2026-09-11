import 'dart:math';

import '../models/career.dart';
import '../models/club.dart';
import '../models/objective.dart';
import '../models/player.dart';
import 'formulas.dart';
import 'national.dart';

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
    final gap = player.overall - club.strength;
    final appearances = (18 + gap.clamp(-12, 12)).clamp(8, 34);

    // 攻撃のポジションほど得点関与を求められる。
    final attacking = switch (player.position.family.name) {
      'forward' => 12,
      'midfield' => 7,
      _ => 3,
    };
    final contributions = (attacking + (gap ~/ 4)).clamp(1, 30);
    final rating = (6.3 + gap * 0.012).clamp(6.0, 7.4);

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
    if (state.player.overall < Formulas.callUpOverall) return false;

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
