import 'package:flutter/material.dart';

import '../logic/todo_advisor.dart';
import '../services/feedback_service.dart';
import '../widgets/owner_goal_card.dart';
import '../widgets/shell_nav.dart';
import 'club_screen.dart';
import 'contract_board_screen.dart';
import 'cup_screen.dart';
import 'finance_screen.dart';
import 'fixtures_screen.dart';
import 'owner_work_screen.dart';
import 'squad_screen.dart';
import 'transfer_screen.dart';
import 'youth_screen.dart';

/// 行き先 [place] を開く。**行き先への移動は、全部ここを通す。**
///
/// - 横画面(左メニューがある)では、左メニューの項目とタブを切り替える。
///   画面を重ねて開かない(以前は左メニューにある画面が二重に開いた)。
/// - 縦画面や、重ねて開いた画面の中からは、今までどおりその画面を重ねて開く。
/// - オーナーの目標は画面ではなく、下から出る一覧。
void openTodoPlace(BuildContext context, TodoPlace place) {
  FeedbackService.tap();
  if (place.card == TodoPlaces.cardOwnerGoal) {
    OwnerGoalCard.choose(context);
    return;
  }
  final nav = ShellNav.maybeOf(context);
  if (nav != null && (nav.wide || place.menu == TodoMenu.status)) {
    nav.go(place);
    return;
  }
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => standaloneScreenFor(place)),
  );
}

/// [place] を単独の画面として開くときの画面(縦画面の経路)。
Widget standaloneScreenFor(TodoPlace place) => switch (place.menu) {
      TodoMenu.finance => FinanceScreen(initialTab: place.tab),
      TodoMenu.club => switch (place.tab) {
          1 => const ClubScreen(section: ClubSection.facilities),
          2 => const ClubScreen(section: ClubSection.community),
          3 => const YouthScreen(),
          _ => const ClubScreen(section: ClubSection.staff),
        },
      TodoMenu.squad =>
        place.tab == 1 ? const ContractBoardScreen() : const SquadScreen(),
      TodoMenu.transfer => TransferScreen(initialTab: place.tab),
      TodoMenu.league =>
        place.tab == 1 ? const CupScreen() : const FixturesScreen(),
      TodoMenu.ownerRoom => OwnerWorkScreen(initialCard: place.card),
      // 状況は重ねて開かない(openTodoPlace が先に切り替える)。
      TodoMenu.status => const SizedBox.shrink(),
    };
