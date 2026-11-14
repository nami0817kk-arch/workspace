import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../widgets/club_emblem.dart';
import 'finance_screen.dart';
import 'fixtures_screen.dart';
import 'home_screen.dart';
import 'lineup_screen.dart';
import 'squad_screen.dart';
import 'team_tabs.dart';
import 'transfer_screen.dart';
import '../l10n/tr.dart';

/// 画面の行き先。横画面は左のメニューに全部を並べ(FM風)、縦画面は下の5タブにまとめる。
enum _Page { status, finance, squad, lineup, transfer, league }

/// 状況/経営/補強/チーム/リーグのシェル。
///
/// 横画面(スマホの標準)では、Football Manager のように、上に日付・資金・
/// 「試合を行う」を置いた常駐のバーと、左に常設のメニューを置く。縦画面では
/// 下のナビゲーションに5タブでまとめる。
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  _Page _page = _Page.status;

  // 縦画面の5タブ(チームは選手/先発を切り替える)。
  static const _narrowPages = [
    _Page.status,
    _Page.finance,
    _Page.transfer,
    _Page.squad,
    _Page.league,
  ];
  static const _narrowTabs = [
    HomeScreen(),
    FinanceScreen(embedded: true),
    TransferScreen(embedded: true),
    TeamTabs(),
    FixturesScreen(),
  ];

  // 横画面の6画面(左メニューの並びと同じ)。
  static const _widePages = [
    _Page.status,
    _Page.finance,
    _Page.squad,
    _Page.lineup,
    _Page.transfer,
    _Page.league,
  ];
  static const _wideTabs = [
    HomeScreen(),
    FinanceScreen(embedded: true),
    SquadScreen(),
    LineupScreen(),
    TransferScreen(embedded: true),
    FixturesScreen(),
  ];

  int _pendingHomeActionCount(GameState gameState) {
    var count = 0;
    if (gameState.pendingPressConference != null) count++;
    if (gameState.pendingJobOfferTeam != null) count++;
    count += gameState.pendingYouthIntake.length;
    count += gameState.incomingOffers.length;
    return count;
  }

  int _narrowIndex() => _page == _Page.lineup
      ? _narrowPages.indexOf(_Page.squad)
      : _narrowPages.indexOf(_page);

  void _go(_Page p) {
    FeedbackService.tap();
    setState(() => _page = p);
  }

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final homeBadgeCount = _pendingHomeActionCount(gameState);

    Widget homeIcon(bool selected) {
      final icon = Icon(selected ? Icons.home : Icons.home_outlined);
      if (homeBadgeCount == 0) return icon;
      return Badge(label: Text('$homeBadgeCount'), child: icon);
    }

    final size = MediaQuery.sizeOf(context);
    final wide = size.width > size.height;

    final items = [
      (
        icon: homeIcon(false),
        selectedIcon: homeIcon(true),
        label: Tr.pick('状況', 'Status'),
      ),
      (
        icon: const Icon(Icons.account_balance_outlined),
        selectedIcon: const Icon(Icons.account_balance),
        label: Tr.pick('経営', 'Finance'),
      ),
      (
        icon: const Icon(Icons.swap_horiz_outlined),
        selectedIcon: const Icon(Icons.swap_horiz),
        label: Tr.pick('補強', 'Signings'),
      ),
      (
        icon: const Icon(Icons.groups_outlined),
        selectedIcon: const Icon(Icons.groups),
        label: Tr.pick('チーム', 'Team'),
      ),
      (
        icon: const Icon(Icons.leaderboard_outlined),
        selectedIcon: const Icon(Icons.leaderboard),
        label: Tr.pick('リーグ', 'League'),
      ),
    ];

    return PopScope(
      // 状況以外の画面で戻る操作をしたら、まず状況へ戻す。状況で戻る操作を
      // したときだけ、この画面を閉じる(=タイトルへ戻る)。
      canPop: _page == _Page.status,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() => _page = _Page.status);
      },
      child: Scaffold(
        body: wide
            ? Column(
                children: [
                  SafeArea(
                    bottom: false,
                    child: _FmTopBar(gameState: gameState),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: Row(
                      children: [
                        SafeArea(
                          top: false,
                          right: false,
                          child: _FmSidebar(
                            page: _page,
                            badge: homeBadgeCount,
                            onSelect: _go,
                          ),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(
                          // 上のバーがあるので、各画面の見出しの帯は低くする。
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              appBarTheme: Theme.of(context)
                                  .appBarTheme
                                  .copyWith(toolbarHeight: 40),
                            ),
                            child: IndexedStack(
                              index: _widePages.indexOf(_page),
                              children: _wideTabs,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : IndexedStack(index: _narrowIndex(), children: _narrowTabs),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: _narrowIndex(),
                onDestinationSelected: (i) => _go(_narrowPages[i]),
                destinations: [
                  for (final d in items)
                    NavigationDestination(
                      icon: d.icon,
                      selectedIcon: d.selectedIcon,
                      label: d.label,
                    ),
                ],
              ),
      ),
    );
  }
}

/// 横画面の上バー。クラブ・日付・資金と、試合を進めるボタン。
class _FmTopBar extends StatelessWidget {
  const _FmTopBar({required this.gameState});

  final GameState gameState;

  @override
  Widget build(BuildContext context) {
    final save = gameState.save;
    if (save == null) return const SizedBox(height: 40);
    final league = save.league;
    final next = league.nextUnplayedFixture;
    final matchday = next?.matchday ??
        (league.fixtures.isEmpty
            ? 0
            : league.fixtures.map((f) => f.matchday).reduce((a, b) => a > b ? a : b));
    final scheme = Theme.of(context).colorScheme;
    final small = Theme.of(context).textTheme.bodySmall;
    return Container(
      color: scheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                ClubEmblem(
                  teamId: gameState.userTeam.id,
                  teamName: save.clubName,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(save.clubName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: Text(
                    Tr.pick(
                        '第${league.season}季 第$matchday節・${save.currentDivisionTier}部',
                        'Season ${league.season} MD $matchday • Tier ${save.currentDivisionTier}'),
                    overflow: TextOverflow.ellipsis,
                    style: small,
                  ),
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: Text(
                    Tr.pick('資金 ${save.budget}万円', 'Funds ${save.budget}'),
                    overflow: TextOverflow.ellipsis,
                    style: small?.copyWith(
                      color: save.budget < 0 ? scheme.error : null,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (next != null && gameState.saleReason == null)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onPressed: gameState.isBusy
                  ? null
                  : () => const HomeScreen().playMatch(context),
              icon: const Icon(Icons.play_arrow, size: 18),
              label: Text(Tr.pick('試合を行う', 'Play the match')),
            ),
        ],
      ),
    );
  }
}

/// 横画面の左メニュー。見出しごとに行き先を並べる(FMのサイドメニュー)。
class _FmSidebar extends StatelessWidget {
  const _FmSidebar({
    required this.page,
    required this.badge,
    required this.onSelect,
  });

  final _Page page;
  final int badge;
  final void Function(_Page) onSelect;

  @override
  Widget build(BuildContext context) {
    final groups = <(String, List<(_Page, IconData, String)>)>[
      (
        Tr.pick('クラブ', 'Club'),
        [
          (_Page.status, Icons.inbox_outlined, Tr.pick('状況', 'Status')),
          (_Page.finance, Icons.account_balance_outlined, Tr.pick('経営', 'Finance')),
        ],
      ),
      (
        Tr.pick('チーム', 'Team'),
        [
          (_Page.squad, Icons.groups_outlined, Tr.pick('選手', 'Players')),
          (_Page.lineup, Icons.checklist_outlined, Tr.pick('先発', 'Lineup')),
        ],
      ),
      (
        Tr.pick('移籍', 'Transfers'),
        [
          (_Page.transfer, Icons.swap_horiz_outlined, Tr.pick('補強', 'Signings')),
        ],
      ),
      (
        Tr.pick('競技', 'Competition'),
        [
          (_Page.league, Icons.leaderboard_outlined, Tr.pick('リーグ', 'League')),
        ],
      ),
    ];
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 148,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 4),
        children: [
          for (final (title, entries) in groups) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
              child: Text(title,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurfaceVariant)),
            ),
            for (final (p, icon, label) in entries)
              ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                selected: page == p,
                selectedTileColor: scheme.secondaryContainer,
                leading: p == _Page.status && badge > 0
                    ? Badge(label: Text('$badge'), child: Icon(icon, size: 20))
                    : Icon(icon, size: 20),
                title: Text(label),
                onTap: () => onSelect(p),
              ),
          ],
        ],
      ),
    );
  }
}
