import 'package:flutter/material.dart';

import '../../gm/career.dart';
import '../../gm/league.dart';
import '../../gm/rating.dart';
import '../gm_controller.dart';
import '../layout.dart';
import 'common.dart';
import 'draft_view.dart';
import 'inbox_screen.dart';
import 'league_tab.dart';
import 'market_tab.dart';
import 'progress_tab.dart';
import 'roster_tab.dart';
import 'style.dart';
import 'trade_tab.dart';

String phaseLabel(Career c) => switch (c.phase) {
      Phase.preseason => 'シーズン前',
      Phase.season => 'シーズン ${c.roundAt}/$gamesPerSeason試合',
      Phase.playoffs => 'プレーオフ前',
      Phase.seasonEnd => 'シーズン終了',
      Phase.draft => 'オフ・ドラフト',
      Phase.contracts => 'オフ・契約',
      Phase.over => '任期の終わり',
    };

/// 左のメニューの項目の高さ(横画面は縦が短いので、全部が1画面に入る大きさにする)。
const _menuItemHeight = 50.0;
const _menuWidth = 88.0;

/// 任期中の画面(横画面)。左に縦のメニュー、上に帯(勝敗・順位・信頼・年俸)、残りが中身。
/// メニュー: ホーム・受信箱・チーム・トレード・補強・リーグ・はじめの画面。
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

  void _openInbox() => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => InboxScreen(c: widget.c)));

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final car = c.career!;
    final drafting = car.phase == Phase.draft;
    final body = switch (_tab) {
      0 => drafting ? DraftView(c: c) : _HomeTab(c: c, goTab: _go, openInbox: _openInbox),
      1 => _centered(context, RosterTab(c: c)),
      2 => _centered(context, TradeTab(c: c)),
      3 => _centered(context, MarketTab(c: c)),
      _ => _centered(context, LeagueTab(c: c)),
    };
    return Scaffold(
      body: SafeArea(
        child: Row(children: [
          _SideMenu(
            selected: _tab,
            onSelect: _go,
            unread: car.unread,
            hasOffer: car.incoming != null,
            onInbox: _openInbox,
            onTitle: c.goHome,
          ),
          const VerticalDivider(width: 1, color: GmColors.line),
          Expanded(
            child: Column(children: [
              _TopBand(car: car),
              const Divider(height: 1, color: GmColors.line),
              Expanded(child: body),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _centered(BuildContext context, Widget child) => Center(
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: contentMaxWidth(context, phone: 700)), child: child),
      );
}

/// 上の帯。チームの名前・シーズン・勝敗と、オーナーの信頼・年俸。
class _TopBand extends StatelessWidget {
  const _TopBand({required this.car});
  final Career car;

  @override
  Widget build(BuildContext context) {
    final me = car.me;
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          TeamBadge(team: car.mine, size: 34),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${car.season}年目・${phaseLabel(car)}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              Text('${me.def.short}  ${record(me)}・地区${car.confRank}位',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: GmColors.sub)),
            ]),
          ),
          const SizedBox(width: 8),
          _GmBadge(car: car),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: TrustBar(trust: car.trust, compact: true)),
          const SizedBox(width: 14),
          Expanded(flex: 2, child: PayrollBar(payroll: me.payroll, compact: true)),
        ]),
      ),
    );
  }
}

/// 左の縦のメニュー。選んでいる項目に橙の印。受信箱は別の画面を開く(未読の数つき)。
class _SideMenu extends StatelessWidget {
  const _SideMenu({
    required this.selected,
    required this.onSelect,
    required this.unread,
    required this.hasOffer,
    required this.onInbox,
    required this.onTitle,
  });
  final int selected;
  final ValueChanged<int> onSelect;
  final int unread;
  final bool hasOffer;
  final VoidCallback onInbox;
  final VoidCallback onTitle;

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String label, {bool on = false, Widget? badge, required VoidCallback onTap}) => InkWell(
          onTap: onTap,
          child: Container(
            height: _menuItemHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              color: on ? GmColors.ball.withValues(alpha: 0.18) : null,
              border: Border(left: BorderSide(color: on ? GmColors.ball : Colors.transparent, width: 3)),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              badge ?? Icon(icon, size: 22, color: on ? GmColors.ball : GmColors.sub),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: on ? FontWeight.bold : FontWeight.normal, color: on ? GmColors.text : GmColors.sub)),
            ]),
          ),
        );
    return Container(
      width: _menuWidth,
      color: GmColors.panel,
      child: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(children: [
              item(Icons.home_rounded, 'ホーム', on: selected == 0, onTap: () => onSelect(0)),
              item(Icons.mail_rounded, '受信箱',
                  badge: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.mail_rounded, size: 22, color: GmColors.sub)),
                  onTap: onInbox),
              item(Icons.groups_rounded, 'チーム', on: selected == 1, onTap: () => onSelect(1)),
              item(Icons.swap_horiz_rounded, 'トレード',
                  on: selected == 2,
                  badge: Badge(
                      isLabelVisible: hasOffer,
                      child: Icon(Icons.swap_horiz_rounded, size: 22, color: selected == 2 ? GmColors.ball : GmColors.sub)),
                  onTap: () => onSelect(2)),
              item(Icons.person_add_alt_1_rounded, '補強', on: selected == 3, onTap: () => onSelect(3)),
              item(Icons.leaderboard_rounded, 'リーグ', on: selected == 4, onTap: () => onSelect(4)),
            ]),
          ),
        ),
        const Divider(height: 1, color: GmColors.line),
        item(Icons.logout_rounded, 'タイトル', onTap: onTitle),
      ]),
    );
  }
}

/// ホーム。左に「いまやること」(試合を進める・オフの手続き)、右に各画面への札(今の状態を小さく)。
class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.c, required this.goTab, required this.openInbox});
  final GmController c;
  final ValueChanged<int> goTab;
  final VoidCallback openInbox;

  @override
  Widget build(BuildContext context) {
    final car = c.career!;
    final cards = [
      _Tile(Icons.groups_rounded, 'チーム', '戦力${car.strengthRank(car.mine) + 1}位・${car.me.roster.length}人', () => goTab(1)),
      _Tile(Icons.swap_horiz_rounded, 'トレード', car.incoming != null ? '申し込みが届いている' : car.canTrade ? '受け付け中' : '締め切り後', () => goTab(2),
          hot: car.incoming != null),
      _Tile(Icons.person_add_alt_1_rounded, '補強', '自由契約 ${car.freeAgents.length}人', () => goTab(3)),
      _Tile(Icons.leaderboard_rounded, 'リーグ', '地区${car.confRank}位', () => goTab(4)),
      _Tile(Icons.mail_rounded, '受信箱', car.unread > 0 ? '未読${car.unread}件' : '新着なし', openInbox, hot: car.unread > 0),
    ];
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: contentMaxWidth(context, phone: 520)), child: ProgressTab(c: c, goTab: goTab)))),
      const VerticalDivider(width: 1, color: GmColors.line),
      SizedBox(
        width: 214,
        child: ListView(
          padding: const EdgeInsets.all(10),
          children: [for (final t in cards) Padding(padding: const EdgeInsets.only(bottom: 8), child: t)],
        ),
      ),
    ]);
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.icon, this.title, this.status, this.onTap, {this.hot = false});
  final IconData icon;
  final String title;
  final String status;
  final VoidCallback onTap;
  final bool hot;

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Icon(icon, color: hot ? GmColors.ball : GmColors.sub),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(status, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: hot ? GmColors.ball : GmColors.sub)),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded, color: GmColors.sub, size: 18),
            ]),
          ),
        ),
      );
}

/// 上の帯の GM の格。押すと名前と通算の点・次の段階までの点が出る。
class _GmBadge extends StatelessWidget {
  const _GmBadge({required this.car});
  final Career car;

  @override
  Widget build(BuildContext context) {
    final next = nextRatingFloor(car.gmPoints);
    return Tooltip(
      message: '${ratingNameOf(car.gmLevel)}・通算${car.gmPoints}点${next == null ? '' : '(次の段階まで${next - car.gmPoints}点)'}',
      triggerMode: TooltipTriggerMode.tap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: GmColors.gold.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: GmColors.gold.withValues(alpha: 0.6)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('GMの格', style: TextStyle(fontSize: 9, color: GmColors.sub)),
          Text('Lv${car.gmLevel}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: GmColors.gold)),
        ]),
      ),
    );
  }
}
