import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/feedback_service.dart';
import '../logic/calendar_engine.dart';
import '../state/game_state.dart';
import '../widgets/club_emblem.dart';
import '../widgets/manager_report_card.dart';
import '../widgets/quick_access_drawer.dart';
import '../widgets/screen_bar.dart';
import '../widgets/group_page.dart';
import 'achievements_screen.dart';
import 'analysis_screen.dart';
import 'awards_screen.dart';
import 'best_eleven_screen.dart';
import 'club_calendar_screen.dart';
import 'club_screen.dart';
import 'contract_board_screen.dart';
import 'cup_screen.dart';
import 'finance_screen.dart';
import 'fixtures_screen.dart';
import 'hall_of_fame_screen.dart';
import 'home_screen.dart';
import 'league_ranking_screen.dart';
import 'news_screen.dart';
import 'owner_work_screen.dart';
import 'season_history_screen.dart';
import 'squad_screen.dart';
import 'transfer_screen.dart';
import 'youth_screen.dart';
import '../l10n/tr.dart';
import '../logic/economy_scale.dart';

/// 画面の行き先。横画面は左のメニューに全部を並べ(FM風)、縦画面は下の5タブにまとめる。
///
/// 横画面は7項目: 状況・財務・クラブ・選手・移籍・リーグ・オーナー室。
/// 縦画面は下の5タブ(状況・財務・補強・選手・リーグ)。
enum _Page { status, finance, club, squad, transfer, league, ownerRoom }

/// 状況/経営/補強/チーム/リーグのシェル。
///
/// 横画面(スマホの標準)では、Football Manager のように、上に日付・資金・
/// 「次の節へ」を置いた常駐のバーと、左に常設のメニューを置く。縦画面では
/// 下のナビゲーションに5タブでまとめる。
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  _Page _page = _Page.status;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

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
    SquadScreen(),
    FixturesScreen(),
  ];

  // 横画面の7項目(左メニューの並びと同じ)。関連する画面は、1つの項目の中に
  // サブページとしてまとめる(GroupPage)。
  static const _widePages = [
    _Page.status,
    _Page.finance,
    _Page.club,
    _Page.squad,
    _Page.transfer,
    _Page.league,
    _Page.ownerRoom,
  ];

  List<Widget> get _wideTabs => [
        const HomeScreen(),
        const FinanceScreen(embedded: true),
        GroupPage(
          title: Tr.pick('クラブ', 'Club'),
          tabs: [
            GroupTab(Tr.pick('施設・スタッフ', 'Facilities & staff'),
                (_) => const ClubScreen()),
            GroupTab(Tr.pick('ユース・スカウト', 'Youth & scouting'),
                (_) => const YouthScreen()),
          ],
        ),
        GroupPage(
          title: Tr.pick('選手', 'Players'),
          tabs: [
            GroupTab(Tr.pick('スカッド', 'Squad'), (_) => const SquadScreen()),
            GroupTab(Tr.pick('登録と契約', 'Contracts'),
                (_) => const ContractBoardScreen()),
          ],
        ),
        const TransferScreen(embedded: true),
        GroupPage(
          title: Tr.pick('リーグ', 'League'),
          tabs: [
            GroupTab(Tr.pick('順位・日程', 'Table & fixtures'),
                (_) => const FixturesScreen()),
            GroupTab(Tr.pick('カップ戦', 'Cups'), (_) => const CupScreen()),
            GroupTab(Tr.pick('ランキング', 'Rankings'),
                (_) => const LeagueRankingScreen()),
            GroupTab(Tr.pick('個人タイトル', 'Awards'), (_) => const AwardsScreen()),
          ],
        ),
        GroupPage(
          title: Tr.pick('オーナー室', 'Owner\'s office'),
          tabs: [
            GroupTab(Tr.pick('オーナーの仕事', 'Owner\'s work'),
                (_) => const OwnerWorkScreen()),
            GroupTab(
                Tr.pick('年間予定', 'Calendar'), (_) => const ClubCalendarScreen()),
            GroupTab(Tr.pick('ニュース', 'News'), (_) => const NewsScreen()),
            GroupTab(
                Tr.pick('シーズン分析', 'Analysis'), (_) => const AnalysisScreen()),
            GroupTab(Tr.pick('シーズン成績', 'Seasons'),
                (_) => const SeasonHistoryScreen()),
            GroupTab(Tr.pick('ベストイレブン', 'Team of the season'),
                (_) => const BestElevenScreen()),
            GroupTab(
                Tr.pick('殿堂', 'Hall of fame'), (_) => const HallOfFameScreen()),
            GroupTab(Tr.pick('実績', 'Achievements'),
                (_) => const AchievementsScreen()),
          ],
        ),
      ];

  int _pendingHomeActionCount(GameState gameState) {
    var count = 0;
    count += gameState.pendingYouthIntake.length;
    count += gameState.incomingOffers.length;
    return count;
  }

  int _narrowIndex() {
    final i = _narrowPages.indexOf(_page);
    return i < 0 ? 0 : i; // 横画面でだけある項目のとき、縦画面では状況に戻す。
  }

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
        key: _scaffoldKey,
        drawer: wide ? const QuickAccessDrawer(onlyOthers: true) : null,
        body: wide
            ? Column(
                children: [
                  SafeArea(
                    bottom: false,
                    child: _FmTopBar(
                      gameState: gameState,
                      onMore: () => _scaffoldKey.currentState?.openDrawer(),
                    ),
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
                            // 判断待ちがある項目に件数の印を付ける。
                            // 状況: ユース受け入れ・売却オファー、
                            // 移籍: 売却オファー、オーナー室: 事件の判断。
                            badges: {
                              _Page.status: homeBadgeCount,
                              _Page.transfer: gameState.incomingOffers.length,
                              _Page.ownerRoom:
                                  gameState.pendingOwnerEvent == null ? 0 : 1,
                            },
                            onSelect: _go,
                          ),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(
                          // 上のバーがあるので、各画面の見出しの帯は低くする。
                          child: Theme(
                            // 密な FM 風の見た目は main.dart の FmThemeScope が当てる。
                            data: Theme.of(context).copyWith(
                              appBarTheme: Theme.of(context)
                                  .appBarTheme
                                  .copyWith(toolbarHeight: 40),
                            ),
                            child: EmbeddedInShell(
                              child: IndexedStack(
                                index: _widePages.indexOf(_page),
                                children: _wideTabs,
                              ),
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

/// 横画面の上バー(バスケGM と同じ作り)。クラブの印と、2行(クラブ名/季・節・部)、
/// 資金、試合を進めるボタン。高さは 52 で固定。
class _FmTopBar extends StatelessWidget {
  const _FmTopBar({required this.gameState, required this.onMore});

  final GameState gameState;

  /// 設定・用語集・ガイドを開く(左のメニューに入りきらないので帯の左端に置く)。
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final save = gameState.save;
    if (save == null) return const SizedBox(height: 52);
    final league = save.league;
    final next = league.nextUnplayedFixture;
    final matchday = next?.matchday ??
        (league.fixtures.isEmpty
            ? 0
            : league.fixtures
                .map((f) => f.matchday)
                .reduce((a, b) => a > b ? a : b));
    final scheme = Theme.of(context).colorScheme;
    final sub = TextStyle(fontSize: 12, color: scheme.onSurfaceVariant);
    // 帯の高さは決まっているので、文字の大きさの設定は少しだけ効かせる
    // (1.3倍だと「サポーター」が2行になり、メーターがはみ出していた)。
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.1,
      child: Container(
        height: 52,
        color: scheme.surfaceContainerHighest,
        padding: const EdgeInsets.only(left: 4, right: 12),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.menu),
              tooltip: Tr.pick('設定・用語集・ガイド', 'Settings, glossary, guide'),
              onPressed: onMore,
            ),
            ClubEmblem(
              teamId: gameState.userTeam.id,
              teamName: save.clubName,
              size: 34,
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    save.clubName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    Tr.pick(
                        '${CalendarEngine.formatDate(gameState.today)}  第${league.season}季 第$matchday節・${save.currentDivisionTier}部',
                        '${CalendarEngine.formatDate(gameState.today)}  Season ${league.season} MD $matchday • Tier ${save.currentDivisionTier}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: sub,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(Tr.pick('資金', 'Funds'),
                      style: sub.copyWith(fontSize: 11)),
                  Text(
                    formatMoney(save.budget),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: save.budget < 0 ? scheme.error : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const ExpectationMeters(compact: true),
            const SizedBox(width: 12),
            if (next != null && gameState.saleReason == null)
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                onPressed: gameState.isBusy
                    ? null
                    : () => const HomeScreen().playMatch(context),
                icon: const Icon(Icons.play_arrow, size: 18),
                label: Text(Tr.pick('次の節へ', 'Next matchday')),
              ),
          ],
        ),
      ),
    );
  }
}

/// 横画面の左メニュー(バスケGM と同じ作り)。幅 88 に、アイコンの下に名前。
/// 選んでいる項目は左に太い印と薄い下地。いちばん下に、その他の画面への入口。
class _FmSidebar extends StatelessWidget {
  const _FmSidebar({
    required this.page,
    required this.badges,
    required this.onSelect,
  });

  final _Page page;
  final Map<_Page, int> badges;
  final void Function(_Page) onSelect;

  // 7項目が、横画面の低い高さに収まり、指で押せる高さ(44pt 以上)。
  // 「その他」は上の帯の左端へ移した。
  static const double _itemHeight = 48;

  @override
  Widget build(BuildContext context) {
    final entries = <(_Page, IconData, IconData, String)>[
      (_Page.status, Icons.home_outlined, Icons.home, Tr.pick('状況', 'Status')),
      (
        _Page.finance,
        Icons.account_balance_outlined,
        Icons.account_balance,
        Tr.pick('経営', 'Finance')
      ),
      (
        _Page.club,
        Icons.apartment_outlined,
        Icons.apartment,
        Tr.pick('クラブ', 'Club')
      ),
      (
        _Page.squad,
        Icons.groups_outlined,
        Icons.groups,
        Tr.pick('選手', 'Players')
      ),
      (
        _Page.transfer,
        Icons.swap_horiz_outlined,
        Icons.swap_horiz,
        Tr.pick('移籍', 'Transfers')
      ),
      (
        _Page.league,
        Icons.leaderboard_outlined,
        Icons.leaderboard,
        Tr.pick('リーグ', 'League')
      ),
      (
        _Page.ownerRoom,
        Icons.work_outline,
        Icons.work,
        Tr.pick('オーナー室', 'Office')
      ),
    ];
    final scheme = Theme.of(context).colorScheme;

    Widget item({
      required Widget icon,
      required String label,
      required bool on,
      required VoidCallback onTap,
    }) =>
        InkWell(
          onTap: onTap,
          child: Container(
            height: _itemHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              color: on ? scheme.primary.withValues(alpha: 0.12) : null,
              border: Border(
                left: BorderSide(
                  color: on ? scheme.primary : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                icon,
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: on ? FontWeight.bold : FontWeight.normal,
                    color: on ? scheme.onSurface : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );

    return Container(
      width: 88,
      color: scheme.surfaceContainerLow,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final (p, icon, selectedIcon, label) in entries)
                    item(
                      on: page == p,
                      label: label,
                      onTap: () => onSelect(p),
                      icon: () {
                        final i = Icon(
                          page == p ? selectedIcon : icon,
                          size: 22,
                          color: page == p
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        );
                        final n = badges[p] ?? 0;
                        return n > 0 ? Badge(label: Text('$n'), child: i) : i;
                      }(),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
