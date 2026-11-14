import 'package:flutter/material.dart';

import '../../gm/career.dart';
import '../../gm/league.dart';
import '../../gm/player.dart';
import '../../gm/rating.dart';
import '../gm_controller.dart';
import '../layout.dart';
import 'common.dart';
import 'gm_table.dart';
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
const _menuWidth = 72.0;

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
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: contentMaxWidth(context, phone: 980)), child: child),
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
      height: 48,
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

/// ホーム。左に「いまやること」(試合を進める・オフの手続き)、右にダッシュボード(知らせ・地区の順位・主力)。
/// 2026-11-14、ユーザー「画面構成を変えて」「もう少し文字小さくても良いので、質を上げる」で、右の大きな札を表に替えた。
class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.c, required this.goTab, required this.openInbox});
  final GmController c;
  final ValueChanged<int> goTab;
  final VoidCallback openInbox;

  @override
  Widget build(BuildContext context) {
    final car = c.career!;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(flex: 11, child: ProgressTab(c: c, goTab: goTab)),
      const VerticalDivider(width: 1, color: GmColors.line),
      Expanded(
        flex: 9,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
          children: [
            _alerts(car),
            const SizedBox(height: 6),
            _standings(car),
            const SizedBox(height: 6),
            _core(car),
          ],
        ),
      ),
    ]);
  }

  /// 知らせ(受信箱・トレードの申し込み・けが人・契約切れ)を1行ずつ。
  Widget _alerts(Career car) {
    final hurt = car.me.roster.where((p) => p.injured > 0).toList();
    final items = <(IconData, String, Color, VoidCallback)>[
      if (car.unread > 0) (Icons.mail_rounded, '受信箱に未読が${car.unread}件', GmColors.ball, openInbox),
      if (car.incoming != null) (Icons.swap_horiz_rounded, 'トレードの申し込みが届いている', GmColors.ball, () => goTab(2)),
      if (hurt.isNotEmpty) (Icons.healing_rounded, 'けが人 ${hurt.length}人(${hurt.map((p) => p.name).take(2).join('・')}${hurt.length > 2 ? 'ほか' : ''})', GmColors.bad, () => goTab(1)),
      if (car.phase == Phase.season && car.canTrade) (Icons.event_rounded, 'トレードの締め切りまで受け付け中', GmColors.sub, () => goTab(2)),
      (Icons.person_add_alt_1_rounded, '自由契約 ${car.freeAgents.length}人', GmColors.sub, () => goTab(3)),
    ];
    return Container(
      decoration: BoxDecoration(color: GmColors.panel, borderRadius: BorderRadius.circular(8), border: Border.all(color: GmColors.line)),
      child: Column(children: [
        for (final (icon, text, color, onTap) in items)
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: Row(children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 6),
                Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: color == GmColors.sub ? GmColors.text : color))),
                const Icon(Icons.chevron_right_rounded, size: 14, color: GmColors.sub),
              ]),
            ),
          ),
      ]),
    );
  }

  /// 自分の地区の順位(シーズン前は戦力の順)。
  Widget _standings(Career car) {
    final started = car.phase == Phase.season || car.phase == Phase.playoffs || car.phase == Phase.seasonEnd;
    final east = car.me.east;
    final list = started ? standings(car.teams, east: east) : ([...car.teams.where((t) => t.east == east)]..sort((a, b) => b.strength.compareTo(a.strength)));
    final leader = list.first;
    return GmTable(
      title: '${east ? '東' : '西'}地区 ${started ? '順位' : '戦力の順'}',
      trailing: InkWell(onTap: () => goTab(4), child: const Text('リーグへ', style: TextStyle(fontSize: 10.5, color: GmColors.ball))),
      rowHeight: 22,
      cols: const [
        GmCol('#', width: 26),
        GmCol('チーム', flex: 4, align: TextAlign.left),
        GmCol('勝敗', width: 50),
        GmCol('差', width: 30),
        GmCol('連', width: 30),
      ],
      rows: [
        for (final (i, t) in list.indexed)
          GmRow(
            [
              numCell('${i + 1}', bold: true, color: !started ? GmColors.sub : i < directSeeds ? GmColors.gold : i < playInSeeds ? GmColors.ball : GmColors.sub),
              Row(children: [
                TeamBadge(team: t.index, size: 15),
                const SizedBox(width: 4),
                Flexible(child: Text(t.def.short, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: t.index == car.mine ? GmColors.ball : null))),
              ]),
              numCell(started ? '${t.wins}-${t.losses}' : t.strength.toStringAsFixed(1)),
              numCell(() {
                final gb = gamesBehind(leader, t);
                return !started || gb == 0 ? '-' : gb.toStringAsFixed(gb == gb.roundToDouble() ? 0 : 1);
              }(), color: GmColors.sub),
              numCell(t.streak == 0 ? '-' : t.streak > 0 ? '${t.streak}勝' : '${-t.streak}敗',
                  color: t.streak >= 3 ? GmColors.good : t.streak <= -3 ? GmColors.bad : GmColors.sub),
            ],
            highlight: t.index == car.mine,
            divider: started && (i == directSeeds || i == playInSeeds),
            onTap: () => goTab(4),
          ),
      ],
    );
  }

  /// 主力(出場の順に8人)。
  Widget _core(Career car) {
    final order = car.me.order.take(8).toList();
    String one(double v) => v.toStringAsFixed(1);
    return GmTable(
      title: '主力',
      trailing: InkWell(onTap: () => goTab(1), child: const Text('チームへ', style: TextStyle(fontSize: 10.5, color: GmColors.ball))),
      rowHeight: 22,
      cols: const [
        GmCol('位置', width: 30),
        GmCol('選手', flex: 4, align: TextAlign.left),
        GmCol('OVR', width: 32),
        GmCol('点', width: 34),
        GmCol('リ', width: 32),
        GmCol('ア', width: 32),
      ],
      rows: [
        for (final (i, p) in order.indexed)
          () {
            final s = p.stats.gp > 0 ? p.stats : p.prev;
            return GmRow(
              [
                numCell(p.pos.short, color: GmColors.sub),
                Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: p.injured > 0 ? GmColors.bad : null)),
                numCell('${shown(p.ovr)}', bold: true, color: GmColors.ovr(p.ovr)),
                numCell(s.gp == 0 ? '-' : one(s.ppg)),
                numCell(s.gp == 0 ? '-' : one(s.rpg)),
                numCell(s.gp == 0 ? '-' : one(s.apg)),
              ],
              divider: i == 5,
              dim: p.injured > 0,
              onTap: () => goTab(1),
            );
          }(),
      ],
    );
  }
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
