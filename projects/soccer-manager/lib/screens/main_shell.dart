import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/feedback_service.dart';
import '../logic/calendar_engine.dart';
import '../state/game_state.dart';
import '../widgets/chip_switcher.dart';
import '../widgets/club_emblem.dart';
import '../widgets/fm_panel.dart';
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
import 'advance_flow.dart';
import 'calendar_screen.dart';
import 'league_ranking_screen.dart';
import 'news_screen.dart';
import 'owner_work_screen.dart';
import 'owner_world_screen.dart';
import 'season_history_screen.dart';
import 'squad_screen.dart';
import 'transfer_screen.dart';
import 'youth_screen.dart';
import '../l10n/tr.dart';
import '../logic/economy_scale.dart';
import '../logic/todo_advisor.dart';
import '../widgets/shell_nav.dart';
import '../widgets/todo_list.dart';

/// 画面の行き先。横画面は左のメニューに全部を並べ(FM風)、縦画面は下の5タブにまとめる。
///
/// 横画面は7項目: 状況・財務・クラブ・選手・移籍・リーグ・オーナー室。
/// 縦画面は下の5タブ(状況・財務・補強・選手・リーグ)。
///
/// 項目の並びは [TodoMenu]。「やること」の行き先([TodoPlace])と同じ型を
/// 使い、行き先へ移る口を [ShellNav.go] の1つにしてある。
typedef _Page = TodoMenu;

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
  /// いま開いている場所(左メニューの項目と、その下のタブ)。「やること」の
  /// 行や知らせの札は、画面を重ねずにここを切り替える。
  final ShellNav _nav = ShellNav();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  _Page get _page => _nav.menu;

  @override
  void initState() {
    super.initState();
    _nav.addListener(_onNav);
  }

  void _onNav() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nav
      ..removeListener(_onNav)
      ..dispose();
    super.dispose();
  }

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
          menu: TodoMenu.club,
          title: Tr.pick('クラブ', 'Club'),
          tabs: [
            GroupTab(Tr.pick('スタッフ', 'Staff'),
                (_) => const ClubScreen(section: ClubSection.staff)),
            GroupTab(Tr.pick('施設', 'Facilities'),
                (_) => const ClubScreen(section: ClubSection.facilities)),
            GroupTab(Tr.pick('ファンと街', 'Fans & city'),
                (_) => const ClubScreen(section: ClubSection.community)),
            GroupTab(Tr.pick('ユース・スカウト', 'Youth & scouting'),
                (_) => const YouthScreen()),
          ],
        ),
        GroupPage(
          menu: TodoMenu.squad,
          title: Tr.pick('選手', 'Players'),
          tabs: [
            GroupTab(Tr.pick('スカッド', 'Squad'), (_) => const SquadScreen()),
            GroupTab(Tr.pick('登録と契約', 'Contracts'),
                (_) => const ContractBoardScreen()),
          ],
        ),
        const TransferScreen(embedded: true),
        GroupPage(
          menu: TodoMenu.league,
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
          menu: TodoMenu.ownerRoom,
          title: Tr.pick('オーナー室', 'Owner\'s office'),
          tabs: [
            GroupTab(Tr.pick('オーナーの仕事', 'Owner\'s work'),
                (_) => const OwnerWorkScreen()),
            GroupTab(Tr.pick('オーナーと世界', 'Owner & world'),
                (_) => const OwnerWorldScreen()),
            // 1か月のマス目のカレンダー。1年の予定の一覧は中で切り替える
            // (2026-11-22)。左のメニューは7項目で高さいっぱいのため、ここに置く。
            GroupTab(
                Tr.pick('カレンダー', 'Calendar'),
                (_) => ChipSwitcher(items: [
                      (Tr.pick('月', 'Month'), (_) => const CalendarScreen()),
                      (
                        Tr.pick('1年の予定', 'The year'),
                        (_) => const ClubCalendarScreen()
                      ),
                    ])),
            GroupTab(Tr.pick('ニュース', 'News'), (_) => const NewsScreen()),
            GroupTab(
                Tr.pick('シーズン分析', 'Analysis'), (_) => const AnalysisScreen()),
            // 記録もの4つは1つのタブにまとめ、中で選ぶ(タブが8つあった)。
            GroupTab(
                Tr.pick('記録', 'Records'),
                (_) => ChipSwitcher(items: [
                      (
                        Tr.pick('シーズン成績', 'Seasons'),
                        (_) => const SeasonHistoryScreen()
                      ),
                      (
                        Tr.pick('ベストイレブン', 'Team of the season'),
                        (_) => const BestElevenScreen()
                      ),
                      (
                        Tr.pick('殿堂', 'Hall of fame'),
                        (_) => const HallOfFameScreen()
                      ),
                      (
                        Tr.pick('実績', 'Achievements'),
                        (_) => const AchievementsScreen()
                      ),
                    ])),
          ],
        ),
      ];

  int _narrowIndex() {
    final i = _narrowPages.indexOf(_page);
    return i < 0 ? 0 : i; // 横画面でだけある項目のとき、縦画面では状況に戻す。
  }

  void _go(_Page p) {
    FeedbackService.tap();
    _nav.select(p);
  }

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    // 「やること」の一覧。印(左メニュー・タブ・進むボタン)と状況の一覧は、
    // 全部この1つを見る(以前は場所ごとに別の条件で数えていた)。
    final todos = TodoAdvisor.build(gameState);
    final homeBadgeCount = todos.mustAt(TodoMenu.status);

    Widget homeIcon(bool selected) {
      final icon = Icon(selected ? Icons.home : Icons.home_outlined);
      if (homeBadgeCount == 0) return icon;
      return Badge(label: Text('$homeBadgeCount'), child: icon);
    }

    final size = MediaQuery.sizeOf(context);
    final wide = size.width > size.height;
    _nav.wide = wide;

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

    return ShellNavScope(
      nav: _nav,
      child: TodoScope(
        items: todos,
        child: PopScope(
      // 状況以外の画面で戻る操作をしたら、まず状況へ戻す。状況で戻る操作を
      // したときだけ、この画面を閉じる(=タイトルへ戻る)。
      canPop: _page == _Page.status,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _nav.select(_Page.status);
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
                      mustCount: todos.mustCount,
                      onTodo: () => _nav.go(TodoPlaces.status),
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
                            // 印は「やること」の一覧から付ける。その項目を
                            // 開けば、必ずその用件が見つかる(事件の札は
                            // 状況に出るのに、印はオーナー室に付いていた)。
                            todos: todos,
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
        ),
      ),
    );
  }
}

/// 横画面の上バー(バスケGM と同じ作り)。クラブの印と、2行(クラブ名/季・節・部)、
/// 資金、試合を進めるボタン。高さは 52 で固定。
class _FmTopBar extends StatelessWidget {
  const _FmTopBar({
    required this.gameState,
    required this.onMore,
    required this.mustCount,
    required this.onTodo,
  });

  final GameState gameState;

  /// 必ず決めることの件数。残っていれば、進むボタンの左に出す。
  final int mustCount;

  /// 「やること」の一覧(状況)を開く。
  final VoidCallback onTodo;

  /// 設定・用語集・ガイドを開く(左のメニューに入りきらないので帯の左端に置く)。
  final VoidCallback onMore;

  /// 帯の日付。日本語は「7/1(水)」、英語は曜日を落として「1 Jul」。
  static String _shortToday(DateTime d) {
    final full = CalendarEngine.formatShortDate(d);
    return Tr.pick(full, full.substring(full.indexOf(' ') + 1));
  }

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
    final barWidth = MediaQuery.sizeOf(context).width;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.1,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: FmLook.of(context)?.topBar ?? scheme.surfaceContainerHighest,
          boxShadow: FmLook.shadowOf(context),
        ),
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
              // 日付を押すとカレンダーを開く(2026-11-22)。
              child: InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const CalendarScreen(standalone: true))),
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
                    // 日付は年なしの短い形にし、節と部は切らずに残す。
                    // 小さな端末で「第7節・3部」が「…」に切れていた
                    // (2026-11-23)。切れるなら季のほうから。
                    //
                    // 日付は切らない。進むボタンと件数の札で帯が詰まると、
                    // 「7/1(…」「Wed 1 J…」と日付から切れていた。切れるのは
                    // 右端の季から(2026-11-24)。英語は曜日を落として短くする。
                    // 小さなカレンダーの印で、押すとカレンダーが開くと分かる
                    // ようにする。
                    Row(
                      children: [
                        Icon(Icons.calendar_month,
                            key: const ValueKey('topbar-calendar-icon'),
                            size: 13,
                            color: scheme.primary),
                        const SizedBox(width: 3),
                        Text(
                          _shortToday(gameState.today),
                          key: const ValueKey('topbar-date'),
                          maxLines: 1,
                          style: sub,
                        ),
                        Flexible(
                          child: Text(
                            Tr.pick(
                                ' 第$matchday節・${save.currentDivisionTier}部 第${league.season}季',
                                ' • MD $matchday • Tier ${save.currentDivisionTier} • S${league.season}'),
                            key: const ValueKey('topbar-division'),
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            softWrap: false,
                            style: sub,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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
              // 帯が狭いとき(小さな端末・大きい文字)は、件数の札を数字だけに
              // し、それでも入らなければボタンの字を「…」で切る(はみ出さない)。
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: barWidth * 0.42),
                child: AdvanceButton(
                  gameState: gameState,
                  mustCount: mustCount,
                  onTodo: onTodo,
                  // スマホの幅では、日付と節の字を残すために数字だけにする。
                  compact: barWidth < 1000,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 上の帯の進むボタン。どこまで進むかを動詞つきで書き(「次の試合へ 9/5(土)」)、
/// 必ず決めることが残っていれば、左に赤い札で件数を出す。
///
/// 札は知らせるだけで、進むのは止めない(期限が来れば自動で片付く)。札を
/// 押すと「やること」の一覧(状況)へ移る。
class AdvanceButton extends StatelessWidget {
  const AdvanceButton({
    super.key,
    required this.gameState,
    required this.mustCount,
    required this.onTodo,
    this.compact = false,
  });

  final GameState gameState;
  final int mustCount;
  final VoidCallback onTodo;

  /// 帯が狭いとき。件数の札を数字だけにする。
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final button = FilledButton.icon(
      key: const ValueKey('advance-button'),
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        // 札が付くときは、札と1つのボタンに見えるよう左の角を落とす。
        shape: mustCount > 0
            ? const RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.horizontal(right: Radius.circular(8)))
            : null,
      ),
      // 次の予定がある日まで進む。行き先の日付と中身をボタンに
      // 書く(2026-11-22)。
      onPressed: gameState.isBusy ? null : () => advanceToNextStop(context),
      icon: Icon(advanceButtonIcon(gameState), size: 18),
      label: Text(
        advanceButtonLabel(gameState) ?? Tr.pick('次の節へ', 'Next matchday'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
    if (mustCount == 0) return button;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: scheme.error,
          borderRadius:
              const BorderRadius.horizontal(left: Radius.circular(8)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const ValueKey('advance-todo'),
            onTap: onTodo,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.checklist, size: 16, color: scheme.onError),
                  const SizedBox(width: 4),
                  Text(
                    compact
                        ? Tr.pick('$mustCount件', '$mustCount')
                        : Tr.pick('やること $mustCount件', 'To do: $mustCount'),
                    semanticsLabel: Tr.pick(
                        'やること $mustCount件', 'To do: $mustCount'),
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: scheme.onError,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 1),
        Flexible(child: button),
      ],
    );
  }
}

/// 横画面の左メニュー(バスケGM と同じ作り)。幅 88 に、アイコンの下に名前。
/// 選んでいる項目は左に太い印と薄い下地。いちばん下に、その他の画面への入口。
class _FmSidebar extends StatelessWidget {
  const _FmSidebar({
    required this.page,
    required this.todos,
    required this.onSelect,
  });

  final _Page page;

  /// 「やること」の一覧。項目ごとの印を付ける。
  final List<TodoItem> todos;
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
        Padding(
          // 選んでいる項目は、主役の色で塗った札にする。以前は左の細い印と
          // 12%の下地だけで、どこを開いているか一目で分からなかった。
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Material(
            color: on ? scheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onTap,
              child: SizedBox(
                height: _itemHeight,
                width: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    icon,
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: on ? scheme.onPrimary : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

    // 文字の大きさの設定は少しだけ効かせる。1.5倍では7項目が詰まり、
    // 件数の印がアイコンを隠していた(上の帯と同じ作り)。
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.2,
      child: Container(
        width: 88,
        color: FmLook.of(context)?.sidebar ?? scheme.surfaceContainerLow,
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
                                ? scheme.onPrimary
                                : scheme.onSurfaceVariant,
                          );
                          final must = todos.mustAt(p);
                          final rec = todos.recommendedAt(p);
                          if (must == 0 && rec == 0) return i;
                          // 必須は赤い数字、おすすめだけなら青い点。
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              i,
                              Positioned(
                                key: ValueKey('menu-mark-${p.name}'),
                                top: must > 0 ? -5 : -2,
                                left: must > 0 ? 14 : 18,
                                child: TodoMark(
                                  must: must,
                                  recommended: rec,
                                  onPrimary: page == p,
                                ),
                              ),
                            ],
                          );
                        }(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
