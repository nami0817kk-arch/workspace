import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/economy_scale.dart';
import '../models/preseason_camp.dart';
import '../state/game_state.dart';
import 'decision_card.dart';

/// 開幕前に海外ツアーへ出るか(興行の判断なのでオーナーが決める)。
/// 練習のキャンプは監督の仕事なので、ここには出さない。
class PreseasonTourCard extends StatelessWidget {
  const PreseasonTourCard({super.key});

  /// カードを出すか: 開幕前(まだリーグ戦が1つも済んでいない)で、未決のとき。
  static bool visible(GameState gs) => gs.preseasonTourPending;

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    if (!visible(gs)) return const SizedBox.shrink();
    const tour = PreseasonCamp.overseasTour;
    // 題と答えだけ。中身は押すと開く(2026-11-25)。
    return DecisionCard(
      icon: Icons.flight_takeoff,
      title: Tr.pick('開幕前の海外ツアー', 'Pre-season overseas tour'),
      detail: Tr.pick(
          '興行の収入${formatMoney(gs.scaledMoney(tour.revenue))}が入りますが、移動の疲れ(+${tour.fatigueCost})を残して開幕します。',
          'Brings in ${formatMoney(gs.scaledMoney(tour.revenue))}, but the squad starts the season tired (+${tour.fatigueCost} fatigue).'),
      choices: [
        DecisionChoice(Tr.pick('ツアーに出る', 'Go on tour'),
            () => gs.choosePreseasonCamp(tour)),
        DecisionChoice(Tr.pick('出ない', 'Stay home'),
            () => gs.choosePreseasonCamp(PreseasonCamp.none),
            primary: false),
      ],
    );
  }
}
