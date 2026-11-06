import 'package:flutter/material.dart';

import '../../gm/career.dart';
import '../../gm/league.dart';
import '../gm_controller.dart';
import '../layout.dart';
import 'common.dart';
import 'draft_view.dart';
import 'league_tab.dart';
import 'market_tab.dart';
import 'progress_tab.dart';
import 'roster_tab.dart';
import 'style.dart';
import 'trade_tab.dart';

String phaseLabel(Career c) => switch (c.phase) {
      Phase.preseason => 'シーズン前',
      Phase.season => 'シーズン ${blockStart(c.block)}/$gamesPerSeason試合',
      Phase.playoffs => 'プレーオフ前',
      Phase.seasonEnd => 'シーズン終了',
      Phase.draft => 'オフ・ドラフト',
      Phase.contracts => 'オフ・契約',
      Phase.over => '任期の終わり',
    };

/// 任期中の画面。下の5つの切り替えで、進行・チーム・トレード・補強・リーグ。
class HubScreen extends StatefulWidget {
  const HubScreen({super.key, required this.c, this.initialTab = 0});
  final GmController c;
  final int initialTab;

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen> {
  late int _tab = widget.initialTab;

  void _go(int t) => setState(() => _tab = t);

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final car = c.career!;
    final me = car.me;
    final body = switch (_tab) {
      0 => car.phase == Phase.draft ? DraftView(c: c) : ProgressTab(c: c, goTab: _go),
      1 => RosterTab(c: c),
      2 => TradeTab(c: c),
      3 => MarketTab(c: c),
      _ => LeagueTab(c: c),
    };
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(children: [
          TeamBadge(team: Career.mine, size: 28),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${car.season}年目・${phaseLabel(car)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text('${me.name}  ${record(me)}', style: const TextStyle(fontSize: 12, color: GmColors.sub)),
            ]),
          ),
        ]),
        actions: [
          IconButton(tooltip: 'はじめの画面へ', onPressed: c.goHome, icon: const Icon(Icons.home_rounded)),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Row(children: [
              Expanded(child: TrustBar(trust: car.trust)),
              const SizedBox(width: 14),
              Expanded(child: PayrollBar(payroll: me.payroll, compact: true)),
            ]),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxWidth(context, phone: 620)),
            child: body,
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        height: 64,
        selectedIndex: _tab,
        onDestinationSelected: _go,
        backgroundColor: GmColors.panel,
        indicatorColor: GmColors.ball.withValues(alpha: 0.3),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          const NavigationDestination(icon: Icon(Icons.flag_rounded), label: '進行'),
          const NavigationDestination(icon: Icon(Icons.groups_rounded), label: 'チーム'),
          NavigationDestination(
            icon: Badge(isLabelVisible: car.incoming != null, child: const Icon(Icons.swap_horiz_rounded)),
            label: 'トレード',
          ),
          const NavigationDestination(icon: Icon(Icons.person_add_alt_1_rounded), label: '補強'),
          const NavigationDestination(icon: Icon(Icons.leaderboard_rounded), label: 'リーグ'),
        ],
      ),
    );
  }
}
