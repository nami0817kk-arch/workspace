import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import '../widgets/auto_columns.dart';
import '../widgets/club_comparison_card.dart';
import '../widgets/club_ranking_card.dart';
import '../widgets/club_timeline_card.dart';
import '../widgets/club_value_card.dart';
import '../widgets/country_coefficient_card.dart';
import '../widgets/former_clubs_card.dart';
import '../widgets/ledger_card.dart';
import '../widgets/owner_career_card.dart';
import '../widgets/projection_card.dart';
import '../widgets/responsive_body.dart';
import '../widgets/rival_card.dart';
import '../widgets/trend_chart.dart';
import 'calendar_screen.dart';
import 'club_calendar_screen.dart';

/// 見るだけの画面(資料)。左上の ≡ の「資料」から開く。
///
/// 操作のタブに、見るだけの表や記録が混ざっていた(経営の「収支・契約」
/// 「記録」、オーナー室の「オーナーと世界」の一部)。操作する場所と見る場所を
/// 分け、見るだけのものはここへ集めた(2026-11-24)。

/// 収支の詳しい表: 今季の帳簿・資金の月ごとの推移・5年の見込み。
///
/// 2026-11-25: 全員の契約の一覧は外した(選手の「登録と契約」と同じ表だった)。
/// 季ごとの推移はシーズン成績の画面に同じものがあるので外し、代わりに資金を
/// 1季目から月ごとに出す。試合がまだ無いうちは、空の表を並べずに
/// 「まだ試合がありません」の1行だけにする。
class FinanceReportScreen extends StatelessWidget {
  const FinanceReportScreen({super.key});

  /// 帳簿に出せる試合がまだ無いか(今季のリーグ戦が1つも済んでおらず、
  /// 終えた季も無い)。
  static bool noMatchesYet(GameState gs) {
    final s = gs.save;
    if (s == null) return true;
    return gs.seasonHistory.isEmpty &&
        s.league.fixtures.every((f) => f.result == null);
  }

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    return Scaffold(
      appBar: AppBar(title: Text(Tr.pick('収支の詳しい表', 'Accounts in detail'))),
      body: ResponsiveBody(
        child: noMatchesYet(gameState)
            ? Center(
                child: Padding(
                  key: const ValueKey('finance-report-empty'),
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    Tr.pick('まだ試合がありません。節が進むと、収支の内訳と月ごとの資金の推移が出ます。',
                        'No matches yet. Once matchdays are played, the accounts and the month-by-month funds appear here.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: SemanticColors.subtleText(context)),
                  ),
                ),
              )
            : const AutoColumns(
                minChildren: 2,
                // 横画面は左に月ごとの資金と5年の見込み、右に長い帳簿。
                children: [
                  MonthlyFundsCard(),
                  ProjectionCard(),
                  LedgerCard(),
                ],
              ),
      ),
    );
  }
}

/// クラブとオーナーの記録(2026-11-25 に「クラブの記録」と「オーナーの記録」を
/// 1つにした。どちらもクラブの価値・他のクラブとの比べを持っていて、
/// 同じ話が2つのページに分かれていた)。
///
/// 上から: クラブ価値(内訳と季末の推移)・リーグの他クラブとの比べ・世界の
/// 番付・宿敵・年表・オーナーの経歴・手放したクラブ・国の係数。
class ClubRecordsScreen extends StatelessWidget {
  const ClubRecordsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar:
            AppBar(title: Text(Tr.pick('クラブとオーナーの記録', 'Club & owner records'))),
        body: const ResponsiveBody(
          child: AutoColumns(
            children: [
              ClubValueCard(),
              ClubComparisonCard(),
              ClubRankingCard(),
              RivalCard(),
              ClubTimelineCard(),
              OwnerCareerCard(),
              FormerClubsCard(),
              CountryCoefficientCard(),
            ],
          ),
        ),
      );
}

/// カレンダー(月のマス目と、1年の予定)。
///
/// 横画面では左メニューの項目(状況のすぐ下)として [embedded] で出し、
/// 上の帯の日付を押してもこの項目に切り替わる(重ねて開かない)。縦画面では
/// ≡ の引き出しから単独の画面として開く。
class CalendarHubScreen extends StatefulWidget {
  const CalendarHubScreen({super.key, this.embedded = false});

  /// 左メニューの項目として埋め込まれているか。見出しの帯と戻るボタンを
  /// 出さない(上の帯と左メニューで、どこにいるかは分かる)。
  final bool embedded;

  @override
  State<CalendarHubScreen> createState() => _CalendarHubScreenState();
}

class _CalendarHubScreenState extends State<CalendarHubScreen> {
  bool _year = false;

  @override
  Widget build(BuildContext context) {
    // 「月」と「1年の予定」の切り替えは、中の画面の見出しの行に置く
    // (切り替えだけで1段使うと、月の表が1画面に収まらない。2026-11-25)。
    final modeSwitch = Wrap(
      spacing: 6,
      children: [
        for (final (k, label) in [
          (0, Tr.pick('月', 'Month')),
          (1, Tr.pick('1年の予定', 'The year')),
        ])
          ChoiceChip(
            key: ValueKey('chip-$k'),
            label: Text(label),
            selected: _year == (k == 1),
            onSelected: (_) => setState(() => _year = k == 1),
          ),
      ],
    );
    final body = _year
        ? ClubCalendarScreen(modeSwitch: modeSwitch)
        : CalendarScreen(modeSwitch: modeSwitch);
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: Text(Tr.pick('カレンダー', 'Calendar'))),
      body: body,
    );
  }
}
