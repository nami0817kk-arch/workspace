/// オーナー型の数値(規則・景気・方針・突発の出来事)を測る。
///
/// **CI では回らない。** `test/` の外に置いてあるのは、これがテストではなく
/// 測定器だからで、時間が掛かる。
///
///     flutter test tool/balance/owner_balance_test.dart
///
/// 何も操作しない(予算配分は初期のまま、補強も売却もしない)クラブを、
/// 国ごとに数シーズン動かし、シーズンごとの損益・人件費率・規則の罰・
/// 突発の出来事を並べる。「何もしないでも罰を受け続ける」「何をしても
/// 一度も罰を受けない」はどちらも数値が合っていない。
library;

// ignore_for_file: avoid_print, invalid_use_of_visible_for_testing_member

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/models/league_theme.dart';
import 'package:soccer_manager/state/game_state.dart';

const int _seasons = 5;

Future<void> _playSeason(GameState gs) async {
  var guard = 0;
  while (!gs.save!.league.isSeasonComplete && guard++ < 80) {
    final results = await gs.simulateAheadMatchdays(8);
    if (results.isEmpty) break;
    if (gs.pendingBoardReviewMessage != null) await gs.dismissBoardReview();
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
  });

  for (final theme in LeagueTheme.values) {
    test('測定: ${theme.name}', () async {
      final gs = GameState();
      await gs.startNewGame('測定FC', theme: theme);
      final rule = gs.ruleSet.name;
      print('=== ${theme.name} / 規則 $rule ===');
      print('季  部 順位  営業収入  人件費率  損益  資金  罰  出来事');
      var penalties = 0;
      var incidents = 0;
      for (var s = 1; s <= _seasons; s++) {
        await _playSeason(gs);
        final ledger = gs.currentLedger;
        final tier = gs.save!.currentDivisionTier;
        final standings = gs.save!.league.sortedStandings;
        final rank =
            standings.indexWhere((r) => r.teamId == gs.save!.userTeamId) + 1;
        final newsBefore = gs.save!.newsLog.length;
        final income = ledger.operatingIncome;
        final ratio = (ledger.wageRatio * 100).round();
        final profit = ledger.profit;
        await gs.startNextSeason();
        final added = gs.save!.newsLog.skip(newsBefore).toList();
        final p = added.where((n) => n.context.contains('規則')).length;
        final i = added.where((n) => n.context.contains('突発')).length;
        penalties += p;
        incidents += i;
        print('$s  $tier  $rank  $income  $ratio%  $profit  '
            '${gs.save!.budget}  ${p == 0 ? '-' : '罰$p'}  ${i == 0 ? '-' : '有'}');
        if (gs.saleReason != null) {
          print('  → クラブを手放す状況(${gs.saleReason})');
          break;
        }
      }
      print('--- 罰 $penalties 回 / 突発 $incidents 回 / 持分 ${gs.save!.ownerShare}%');
    }, timeout: const Timeout(Duration(minutes: 20)));
  }
}
