import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/feedback_service.dart';
import '../state/game_state.dart';
import 'fixtures_screen.dart';
import 'home_screen.dart';
import 'lineup_screen.dart';
import 'squad_screen.dart';
import '../l10n/l10n_ext.dart';

/// ホーム/スカッド/戦術/順位表をボトムナビゲーションのタブとして保持するシェル。
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _tabs = [
    HomeScreen(),
    SquadScreen(),
    LineupScreen(),
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

    void select(int i) {
      FeedbackService.tap();
      setState(() => _index = i);
    }

    final items = [
      (
        icon: homeIcon(false),
        selectedIcon: homeIcon(true),
        label: context.l10n.navHome,
      ),
      (
        icon: const Icon(Icons.groups_outlined),
        selectedIcon: const Icon(Icons.groups),
        label: context.l10n.navSquad,
      ),
      (
        icon: const Icon(Icons.checklist_outlined),
        selectedIcon: const Icon(Icons.checklist),
        label: context.l10n.navTactics,
      ),
      (
        icon: const Icon(Icons.leaderboard_outlined),
        selectedIcon: const Icon(Icons.leaderboard),
        label: context.l10n.navStandings,
      ),
    ];

    return PopScope(
      // ボトムナビゲーションのタブ切り替えはルートを積まないため、ホーム以外の
      // タブを表示中に戻る操作をすると、そのままタイトル画面まで戻ってしまう。
      // ホーム以外のタブではまずホームタブへ戻し、ホームタブの状態で戻る操作を
      // した場合のみ実際にこの画面を閉じる(=タイトルへ戻る)。
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() => _index = 0);
      },
      child: Scaffold(
        // 横長の画面では縦の高さが貴重なので、ナビは下ではなく左に置く。
        body: wide
            ? Row(
                children: [
                  SafeArea(
                    right: false,
                    child: NavigationRail(
                      selectedIndex: _index,
                      onDestinationSelected: select,
                      labelType: NavigationRailLabelType.all,
                      destinations: [
                        for (final d in items)
                          NavigationRailDestination(
                            icon: d.icon,
                            selectedIcon: d.selectedIcon,
                            label: Text(d.label),
                          ),
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: IndexedStack(index: _index, children: _tabs)),
                ],
              )
            : IndexedStack(index: _index, children: _tabs),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: select,
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
