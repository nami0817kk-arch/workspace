import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/contract_engine.dart';
import '../logic/economy_scale.dart';
import '../models/player.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import '../widgets/auto_columns.dart';
import '../widgets/chip_switcher.dart';
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
import '../widgets/screen_bar.dart';
import '../widgets/trend_chart.dart';
import 'calendar_screen.dart';
import 'club_calendar_screen.dart';
import 'player_detail_screen.dart';

/// 見るだけの画面(資料)。左上の ≡ の「資料」から開く。
///
/// 操作のタブに、見るだけの表や記録が混ざっていた(経営の「収支・契約」
/// 「記録」、オーナー室の「オーナーと世界」の一部)。操作する場所と見る場所を
/// 分け、見るだけのものはここへ集めた(2026-11-24)。

/// 収支の詳しい表: 帳簿・5年の見込み・推移・全員の契約の一覧。
class FinanceReportScreen extends StatelessWidget {
  const FinanceReportScreen({super.key});

  void _openPlayer(BuildContext context, String playerId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlayerDetailScreen(playerId: playerId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final team = gameState.userTeam;
    final sortedByExpiry = team.players.where((p) => !p.isLoan).toList()
      ..sort(
        (a, b) => a.contractYearsRemaining.compareTo(b.contractYearsRemaining),
      );
    return Scaffold(
      appBar: AppBar(title: Text(Tr.pick('収支の詳しい表', 'Accounts in detail'))),
      body: ResponsiveBody(
        child: AutoColumns(
          children: [
            const LedgerCard(),
            const ProjectionCard(),
            const TrendsCard(),
            // 見出しと行を1つにまとめる(2列に割るとき、見出しだけが左の列に
            // 残らないように)。
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Text(
                  Tr.pick(
                      '契約状況（残り年数が少ない順）', 'Contracts, shortest remaining first'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (final (i, p) in sortedByExpiry.indexed)
                  InkWell(
                    onTap: () => _openPlayer(context, p.id),
                    child: Container(
                      height: 48,
                      color: i.isOdd
                          ? Theme.of(context).colorScheme.surfaceContainerLow
                          : null,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(p.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                          SizedBox(
                            width: 44,
                            child: Text(p.position.label,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12)),
                          ),
                          // 英語の「1.2m yen」が2行に折れていた(2026-11-23)。
                          SizedBox(
                            width: 84,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(formatMoney(annualFromWeekly(p.wage)),
                                  maxLines: 1,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontSize: 12)),
                            ),
                          ),
                          SizedBox(
                            width: 64,
                            child: Text(
                              ContractEngine.untilShortLabel(p.contractEndYear),
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 12,
                                color: p.contractYearsRemaining <= 1
                                    ? SemanticColors.negative(context)
                                    : null,
                                fontWeight: p.contractYearsRemaining <= 1
                                    ? FontWeight.bold
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// クラブの記録: クラブの価値・番付・宿敵・年表。
class ClubRecordsScreen extends StatelessWidget {
  const ClubRecordsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(Tr.pick('クラブの記録', 'Club records'))),
        body: const ResponsiveBody(
          child: AutoColumns(
            children: [
              ClubValueCard(),
              ClubRankingCard(),
              RivalCard(),
              ClubTimelineCard(),
            ],
          ),
        ),
      );
}

/// オーナーの記録: 経歴・他のクラブとの比較・手放したクラブのその後・国の係数。
class OwnerRecordsScreen extends StatelessWidget {
  const OwnerRecordsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(Tr.pick('オーナーの記録', 'Owner records'))),
        body: const ResponsiveBody(
          child: AutoColumns(
            children: [
              OwnerCareerCard(),
              ClubComparisonCard(),
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
class CalendarHubScreen extends StatelessWidget {
  const CalendarHubScreen({super.key, this.embedded = false});

  /// 左メニューの項目として埋め込まれているか。見出しの帯と戻るボタンを
  /// 出さない(上の帯と左メニューで、どこにいるかは分かる)。
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 中の2つの画面は自分の見出しを持つので、ここでは隠す(見出しが
    // 2段にならないように)。
    final body = HideScreenBar(
      child: Theme(
        data: theme.copyWith(
          appBarTheme: theme.appBarTheme.copyWith(toolbarHeight: 0),
        ),
        child: ChipSwitcher(items: [
          (Tr.pick('月', 'Month'), (_) => const CalendarScreen()),
          (Tr.pick('1年の予定', 'The year'), (_) => const ClubCalendarScreen()),
        ]),
      ),
    );
    if (embedded) return body;
    return Scaffold(
      appBar: AppBar(title: Text(Tr.pick('カレンダー', 'Calendar'))),
      body: body,
    );
  }
}
