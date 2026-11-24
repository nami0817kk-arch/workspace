/// 横向きの画面の骨組みと、現実に寄せた画面（お金・世界・街）。1.1.0+25 から。
/// 骨組み: 上の帯（日付・現金・借金・時価総額・順位・社長の時間と体力）／左の切り替え／真ん中に本体／右の帯（今月やること・社長の予定）／下に「次の月へ」
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/game.dart';
import 'controller.dart';
import 'glossary.dart';
import 'painters.dart';
import 'sheets.dart';
import 'tabs.dart';
import 'widgets.dart';

/// 左の切り替え（id・名前・印）
const railTabs = [
  ('town', '街@@tab', Icons.location_city),
  ('biz', '事業@@tab', Icons.work),
  ('people', '人@@tab', Icons.people),
  ('stock', '株@@tab', Icons.pie_chart),
  ('money', 'お金@@tab', Icons.account_balance),
  ('world', '世界@@tab', Icons.public),
  ('zukan', '図鑑@@tab', Icons.menu_book),
];

/// 右の帯を出す最小の幅（これより狭いと、上の帯の「今月」から小窓で開く）
const sidePanelMin = 760.0;

/// 右の帯の幅
const sideW = 210.0;

/// 左の切り替えの幅
const railW = 66.0;

// ===== 上の帯 =====
Widget topBar(GameController ctl, {required bool side}) {
  final s = ctl.game!;
  final rk = s.rank != 0 ? s.rank : s.rankList().indexWhere((x) => x.me) + 1;
  Widget stat(String k, String v, [Color c = Pal.ink, Key? key]) => Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Text.rich(key: key, TextSpan(children: [
          TextSpan(text: k, style: ts(size: 12, color: Pal.mute)),
          TextSpan(text: v, style: ts(size: 13, color: c, bold: true)),
        ])),
      );
  return Container(
    decoration: const BoxDecoration(color: Pal.panel, border: Border(bottom: BorderSide(color: Pal.line))),
    padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
    child: Row(children: [
      Text(ym(s.year, s.q, sp: true), key: const ValueKey('top-date'), style: ts(size: 15, color: Pal.goldtx, bold: true)),
      const SizedBox(width: 12),
      // 数字の列は、入りきらなければ横に動かせる（画面ごとは動かない）
      Expanded(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            FlashStat(tr('現金 '), yen(s.cash), value: s.cash, turn: s.turn),
            const SizedBox(width: 12),
            stat(tr('借金 '), yen(s.debt), s.debt > 0 ? Pal.down : Pal.ink, const ValueKey('top-debt')),
            FlashStat(tr('時価総額 '), yen(s.cap), value: s.cap, turn: s.turn, color: Pal.goldtx),
            const SizedBox(width: 12),
            FlashStat(tr('世界 '), tr('{0}位', [rk]), value: rk.toDouble(), turn: s.turn, higherIsBetter: false),
            const SizedBox(width: 12),
            HoursGauge(s, key: const ValueKey('ap')),
          ]),
        ),
      ),
      if (!side)
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Btn(tr('今月'), () => openSideSheet(ctl), key: const ValueKey('side-open'), small: true, more: true),
        ),
      const SizedBox(width: 4),
      Semantics(
          label: tr('遊び方'),
          button: true,
          excludeSemantics: true,
          onTap: () => showHelp(ctl),
          child: Btn(tr('？'), () => showHelp(ctl), key: const ValueKey('help'), small: true)),
      const SizedBox(width: 4),
      Semantics(
        label: tr('設定'),
        button: true,
        child: TapArea(
            key: const ValueKey('settings-tap'),
            onTap: () => openSettings(ctl),
            child: Material(
              color: Pal.panel2,
              shape: btnShape(Pal.line),
              child: InkWell(
                key: const ValueKey('settings'),
                borderRadius: BorderRadius.circular(Ui.rBtn),
                onTap: () => openSettings(ctl),
                child: const Padding(padding: EdgeInsets.all(5), child: Icon(Icons.settings, size: 18, color: Pal.ink)),
              ),
            )),
      ),
    ]),
  );
}

/// 社長の残り時間と体力の小さな計り（上の帯）
class HoursGauge extends StatelessWidget {
  final Game s;
  const HoursGauge(this.s, {super.key});
  @override
  Widget build(BuildContext context) {
    final left = s.hLeft(), normal = s.hNormalLeft();
    final st = s.stamina.clamp(0, 100) / 100;
    final stc = st > .5
        ? Pal.up
        : st > .25
            ? Pal.warn
            : Pal.down;
    return Semantics(
      label: tr('社長の時間 残り{0}時間・体力{1}', [jsRound(left), jsRound(s.stamina)]),
      excludeSemantics: true,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(s.down > 0 ? Icons.local_hospital : Icons.schedule, size: 15, color: s.down > 0 ? Pal.down : Pal.goldtx),
        const SizedBox(width: 3),
        Text(s.down > 0 ? tr('休養中 あと{0}か月', [s.down]) : tr('残り{0}h', [jsRound(left)]),
            key: const ValueKey('ap-count'), style: ts(size: 13, bold: true, color: normal > 0 ? Pal.goldtx : (left > 0 ? Pal.warn : Pal.mute))),
        const SizedBox(width: 8),
        Text(tr('体力 '), style: ts(size: 12, color: Pal.mute)),
        Container(
          width: 46,
          height: 8,
          decoration: BoxDecoration(color: Pal.line, borderRadius: BorderRadius.circular(4)),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
              widthFactor: st.toDouble(),
              child: Container(decoration: BoxDecoration(color: stc, borderRadius: BorderRadius.circular(4)))),
        ),
      ]),
    );
  }
}

// ===== 左の切り替え =====
Widget leftRail(GameController ctl) => Container(
      width: railW,
      decoration: const BoxDecoration(color: Pal.panel, border: Border(right: BorderSide(color: Pal.line))),
      child: LayoutBuilder(builder: (context, c) {
        // 7つが縦に入りきらない低い画面では、字を省いて印だけにする
        final compact = c.maxHeight < railTabs.length * 46;
        return SingleChildScrollView(
          child: Column(children: [
            for (final t in railTabs)
              Semantics(
                button: true,
                selected: ctl.tab == t.$1,
                label: tr(t.$2),
                child: InkWell(
                  key: ValueKey('tab-${t.$1}'),
                  onTap: () => ctl.setTab(t.$1),
                  child: Container(
                    height: compact ? math.max(minTap, c.maxHeight / railTabs.length) : 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: ctl.tab == t.$1 ? Pal.onBg : null, border: Border(left: BorderSide(color: ctl.tab == t.$1 ? Pal.gold : Colors.transparent, width: 3))),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(t.$3, size: compact ? 18 : 20, color: ctl.tab == t.$1 ? Pal.goldtx : Pal.mute),
                      if (!compact || c.maxHeight >= railTabs.length * 40)
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(tr(t.$2), maxLines: 1, style: ts(size: 10.5, color: ctl.tab == t.$1 ? Pal.goldtx : Pal.mute, bold: ctl.tab == t.$1, height: 1.2)),
                        ),
                    ]),
                  ),
                ),
              ),
          ]),
        );
      }),
    );

// ===== 右の帯（今月やること・社長の予定） =====
List<Widget> sideItems(GameController ctl, {bool sheet = false}) {
  final s = ctl.game!;
  final todo = todoCard(ctl);
  final meet = s.hMeet();
  return [
    ?todo,
    Panel(
      key: const ValueKey('side-plan'),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: CardTitle(tr('社長の予定'), gold: true)),
          Info(ctl, const ['ap']),
        ]),
        // 社長の名前・年齢・代（名前は切らず、入りきらなければ折り返す）
        Wrap(runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(nmL(s.pres.name), key: const ValueKey('pres-name'), style: ts(size: 12, color: Pal.mute)),
          Text(tr('・{0}歳', [s.pres.age]), key: const ValueKey('pres-age'), maxLines: 1, softWrap: false, style: ts(size: 12, color: Pal.mute)),
          if (s.gen > 1) Padding(padding: const EdgeInsets.only(left: 6), child: Tag(tr('{0}代目', [s.gen]), key: const ValueKey('pres-gen'))),
        ]),
        const SizedBox(height: 2),
        if (s.down > 0) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(tr('倒れて休養中（あと{0}か月）。会議と任せた事業は部下が回します', [s.down]), style: ts(size: 12, color: Pal.down))),
        _planRow(tr('会議と決めごと'), meet, Pal.mute),
        _planRow(tr('今月の行動'), s.hUsed, Pal.goldtx),
        _planRow(tr('ふつうに使える残り'), s.hNormalLeft(), Pal.up),
        _planRow(tr('無理をして使える残り'), math.max(0, s.hLeft() - s.hNormalLeft()), Pal.warn),
        const SizedBox(height: 4),
        HoursBar(s),
        const SizedBox(height: 6),
        Text(tr('体力 {0}／100', [jsRound(s.stamina)]), style: ts(size: 12.5, bold: true, color: s.stamina < 25 ? Pal.down : Pal.ink)),
        Text(tr('200時間を超えて働くと体力が減り、0で倒れます。事業を任せると会議の時間が減ります'), style: ts(size: 11.5, color: Pal.mute, height: 1.35)),
        const SizedBox(height: 6),
        Btn(tr('社長の行動'), () => openPresSheet(ctl), key: const ValueKey('pres-open'), small: true, more: true, shrink: true),
      ]),
    ),
  ];
}

Widget _planRow(String k, double h, Color c) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(children: [
        Expanded(child: Text(k, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(size: 12, color: Pal.mute))),
        Text(tr('{0}時間', [jsRound(h)]), style: ts(size: 12.5, bold: true, color: c)),
      ]),
    );

/// 今月の時間の配分の棒（会議・行動・ふつうの残り・無理の分。全体は300時間）
class HoursBar extends StatelessWidget {
  final Game s;
  const HoursBar(this.s, {super.key});
  @override
  Widget build(BuildContext context) {
    final meet = math.min(hoursMax, s.hMeet()), used = math.min(hoursMax - meet, s.hUsed);
    final normal = s.hNormalLeft(), over = math.max(0.0, s.hLeft() - normal);
    Widget seg(double v, Color c) => v <= 0 ? const SizedBox.shrink() : Expanded(flex: math.max(1, (v * 10).round()), child: Container(color: c));
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 10,
        child: Row(children: [
          seg(meet, const Color(0xFFB9B2A2)),
          seg(used, Pal.gold),
          seg(normal, const Color(0xFFBFE3C9)),
          seg(over, const Color(0xFFF6D3A3)),
        ]),
      ),
    );
  }
}

/// 右の帯の中身を小窓で開く（幅の狭い画面）
void openSideSheet(GameController ctl) => ctl.showSheet((_) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      ...sideItems(ctl, sheet: true),
      Align(alignment: Alignment.centerRight, child: Btn(tr('閉じる'), ctl.closeSheet, small: true)),
    ]));

/// 社長の行動の小窓
void openPresSheet(GameController ctl) => ctl.showSheet((_) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      presPanel(ctl, sheet: true),
      Align(alignment: Alignment.centerRight, child: Btn(tr('閉じる'), ctl.closeSheet, small: true)),
    ]));

// ===== 街 =====
List<Widget> townTabL(GameController ctl, double width) {
  final s = ctl.game!;
  final wide = width >= 560;
  final pic = Frame(
    key: const ValueKey('town-picture'),
    child: AspectRatio(
        aspectRatio: wide ? 480 / 180 : 16 / 9,
        child: Semantics(
            label: tr('自社のビルが並ぶ街'), image: true, child: RepaintBoundary(child: CustomPaint(painter: TownPainter(s, W: wide ? 480 : 320), size: Size.infinite)))),
  );
  final nCtry = <String>{for (final b in s.biz) ...s.ctryOf(b)}.length;
  final rival = topRival(s);
  final me = Panel(
    key: const ValueKey('town-company'),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text(tx(s.stageName()), key: const ValueKey('town-stage'), style: ts(bold: true)),
        Text(tr('{0}を拠点に{1}か国で勝負中', [cm[s.home]!.city, nCtry == 0 ? 1 : nCtry]), style: ts(size: 12.5, color: Pal.mute)),
        Tag(s.officeName(), key: const ValueKey('town-office'), kind: TagKind.gold),
      ]),
      const SizedBox(height: 6),
      Grid2([
        Kv(tr('時価総額'), yen(s.cap)),
        Kv(tr('世界の順位'), tr('{0}位', [s.rank != 0 ? s.rank : s.rankList().indexWhere((x) => x.me) + 1])),
        Kv(tr('月の売上'), yen(s.rev)),
        Kv(tr('月の利益'), yen(s.pre)),
        Kv(tr('現金'), yen(s.cash)),
        Kv(tr('事業'), tr('{0}つ', [s.biz.length])),
      ]),
      if (rival != null)
        Container(
          key: const ValueKey('town-rival-gap'),
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.only(top: 6),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Pal.line))),
          child: Text(
              s.cap >= rival.cap
                  ? tr('宿敵 {0} の時価総額は{1}。あなたが{2}倍', [nmL(rival.name), yen(rival.cap), (s.cap / math.max(rival.cap, 1)).toStringAsFixed(1)])
                  : tr('宿敵 {0} の時価総額は{1}。あなたの{2}倍', [nmL(rival.name), yen(rival.cap), (rival.cap / math.max(s.cap, 1)).toStringAsFixed(1)]),
              style: ts(size: 12.5)),
        ),
      Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.only(top: 6),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Pal.line))),
        child: Text.rich(TextSpan(children: [TextSpan(text: tr('目標　'), style: ts(size: 12.5, bold: true)), TextSpan(text: tx(s.goalText()), style: ts(size: 12.5))])),
      ),
    ]),
  );
  final econ = countryPanel(ctl, s.home, key: const ValueKey('town-econ'), title: tr('{0}の景気', [cm[s.home]!.n]));
  final recent = s.log.reversed.take(6).toList();
  final news = Panel(
    key: const ValueKey('town-news'),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      CardTitle(tr('今月のニュース')),
      const SizedBox(height: 4),
      if (recent.isEmpty) Muted(tr('まだ知らせはありません')),
      for (final n in recent) NewsLine(n.m, n.t, prefix: n.y != null ? '${yearL(n.y!)} ' : null, icon: newsIcon(s, n)),
    ]),
  );
  final out = <Widget>[];
  if (wide) {
    out.add(Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [pic, me])),
        const SizedBox(width: 8),
        Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [econ, news])),
      ]),
    ));
  } else {
    out.addAll([const SizedBox(height: 6), pic, me, econ, news]);
  }
  final vow = s.vow;
  if (vow != null) {
    out.add(Panel(border: Pal.down, child: Text(tr('取締役会との約束：{0}年1月までに、年の利益を{1}まで戻す', [vow['y']!.round(), yen(vow['target']!)]), style: ts(size: 13))));
  }
  out.addAll(townRivalsOf(ctl));
  return out;
}

/// いちばん大きい宿敵（いなければ null）
Company? topRival(Game s) {
  final l = s.cos.where((c) => c.alive && c.rival != null && c.parent != 'player').toList()..ssort((a, b) => b.cap.compareTo(a.cap));
  return l.firstOrNull;
}

/// 国の景気の欄（成長・物価・金利・為替・最低賃金・法人税・失業率）
Widget countryPanel(GameController ctl, String c, {Key? key, String? title}) {
  final s = ctl.game!;
  final g = s.growthOf(c);
  return Panel(
    key: key,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: CardTitle(title ?? cm[c]!.n)),
        Tag(g < 0 ? tr('不況') : g < 1.5 ? tr('足踏み') : g < 4 ? tr('ふつう') : tr('好景気'), kind: g < 0 ? TagKind.bad : g >= 4 ? TagKind.good : TagKind.plain),
      ]),
      const SizedBox(height: 4),
      Grid2([
        Kv(tr('成長率'), '${pctD(g)}%'),
        Kv(tr('物価'), '${pctD(s.inflOf(c))}%'),
        Kv(tr('金利'), '${pctD(s.rateOf(c))}%'),
        Kv(tr('為替'), tx(s.fxText(c))),
        Kv(tr('最低賃金'), tr('{0}／月', [yen(s.minWageYen(c) / 12)])),
        Kv(tr('法人税'), '${pctD(s.ev(c, 'corp_tax'))}%'),
      ]),
      if (s.yr() > econData.lastYear + 1) Padding(padding: const EdgeInsets.only(top: 4), child: Muted(tr('{0}年より先は予測です', [econData.lastYear + 1]), size: 11.5)),
    ]),
  );
}

// ===== お金 =====
const moneyViews = [('cash', '資金繰り'), ('bank', '借金と銀行'), ('cost', '経費'), ('tax', '税金'), ('book', '決算と記録')];

List<Widget> moneyTab(GameController ctl) {
  final out = <Widget>[
    Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Wrap(spacing: 6, runSpacing: 4, children: [
        for (final v in moneyViews) PickChip(tr(v.$2), key: ValueKey('money-${v.$1}'), on: ctl.moneyView == v.$1, onTap: () => ctl.setMoney(v.$1)),
      ]),
    ),
  ];
  switch (ctl.moneyView) {
    case 'bank':
      out.addAll(_bankView(ctl));
    case 'cost':
      out.addAll(_costView(ctl));
    case 'tax':
      out.addAll(_taxView(ctl));
    case 'book':
      out.addAll(numTab(ctl));
    default:
      out.addAll(_cashView(ctl));
  }
  return out;
}

Widget _cell(String t, {double w = 0, bool bold = false, Color c = Pal.ink, TextAlign a = TextAlign.right}) {
  final txt = Text(t, maxLines: 1, softWrap: false, textAlign: a, style: ts(size: 12.5, bold: bold, color: c));
  return w > 0 ? SizedBox(width: w, child: FittedBox(fit: BoxFit.scaleDown, alignment: a == TextAlign.left ? Alignment.centerLeft : Alignment.centerRight, child: txt)) : Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: a == TextAlign.left ? Alignment.centerLeft : Alignment.centerRight, child: txt));
}

List<Widget> _cashView(GameController ctl) {
  final s = ctl.game!;
  final plan = s.cashPlan();
  final line = s.dangerLine();
  var y = s.year, q = s.q;
  final rows = <Widget>[];
  for (final p in plan) {
    final bad = p.cash < line;
    rows.add(Container(
      key: ValueKey('cash-row-${rows.length}'),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: Ui.rowLine,
      child: Row(children: [
        _cell(ym(y, q), w: Ui.sw(72), a: TextAlign.left),
        _cell(yen(p.inflow), c: Pal.up),
        _cell(yen(-p.out), c: Pal.down),
        _cell(yen(p.cash), bold: true, c: bad ? Pal.down : Pal.ink),
        SizedBox(width: 22, child: bad ? const Icon(Icons.warning_amber_rounded, size: 16, color: Pal.down) : null),
      ]),
    ));
    q++;
    if (q > 12) {
      q = 1;
      y++;
    }
  }
  final firstBad = plan.indexWhere((p) => p.cash < line);
  return [
    Panel(
      key: const ValueKey('money-cash'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CardTitle(tr('この先6か月の資金繰り')),
        const SizedBox(height: 4),
        Text(
            firstBad < 0
                ? tr('今のままなら、6か月のあいだ払えなくなる心配はありません')
                : tr('{0}か月後に、払えなくなる線（{1}）を下回る見込みです', [firstBad + 1, yen(line)]),
            key: const ValueKey('cash-verdict'),
            style: ts(size: 13, color: firstBad < 0 ? Pal.up : Pal.down, bold: true)),
        const SizedBox(height: 6),
        SizedBox(height: 70, child: CustomPaint(painter: CashPlanPainter([s.cash, ...plan.map((p) => p.cash)], line), size: Size.infinite)),
        const SizedBox(height: 6),
        Row(children: [
          _cell(tr('月'), w: Ui.sw(72), a: TextAlign.left, c: Pal.mute),
          _cell(tr('入る'), c: Pal.mute),
          _cell(tr('出る'), c: Pal.mute),
          _cell(tr('残り'), c: Pal.mute),
          const SizedBox(width: 22),
        ]),
        ...rows,
        const SizedBox(height: 4),
        Muted(tr('今月の売上と経費が続き、借金を予定どおり返すとしたときの見込み。払えなくなる線は、経費の半月分と毎月の返済の合計'), size: 11.5),
      ]),
    ),
  ];
}

/// 資金繰りの残りの線と、払えなくなる線
class CashPlanPainter extends CustomPainter {
  final List<double> v;
  final double line;
  CashPlanPainter(this.v, this.line);
  @override
  void paint(Canvas canvas, Size size) {
    final lo = math.min(0.0, [...v, line].reduce(math.min)), hi = math.max(1.0, [...v, line].reduce(math.max));
    double yy(double x) => size.height - 4 - (x - lo) / (hi - lo) * (size.height - 8);
    final bw = size.width / v.length;
    final p = Paint();
    for (var i = 0; i < v.length; i++) {
      p.color = v[i] < line ? Pal.down.withValues(alpha: .55) : (i == 0 ? Pal.gold : Pal.teal.withValues(alpha: .55));
      final top = yy(math.max(v[i], 0)), base = yy(math.min(v[i], 0));
      canvas.drawRect(Rect.fromLTRB(i * bw + 3, math.min(top, yy(0)), (i + 1) * bw - 3, math.max(base, yy(0))), p);
    }
    final lp = Paint()
      ..color = Pal.down
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(0, yy(line)), Offset(size.width, yy(line)), lp);
    canvas.drawLine(Offset(0, yy(0)), Offset(size.width, yy(0)), Paint()..color = Pal.line);
  }

  @override
  bool shouldRepaint(covariant CashPlanPainter o) => o.line != line || o.v.join() != v.join();
}

String lenderName(String k) => tr(switch (k) {
      'second' => '二番手の銀行',
      'local' => '地元の信用金庫',
      'bridge' => 'つなぎの融資',
      'bond' => '社債',
      _ => 'メインバンク',
    });

List<Widget> _bankView(GameController ctl) {
  final s = ctl.game!;
  final room = s.borrowRoom();
  final x = s.debtMultiple();
  final r = s.rating();
  final rows = [
    for (final l in s.loans)
      Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: Ui.rowLine,
        child: Row(children: [
          _cell(lenderName(l.lender), w: Ui.sw(92), a: TextAlign.left),
          _cell(yen(l.amt)),
          _cell('${pctD(l.rate * 100)}%'),
          _cell(l.left >= 12 ? tr('あと{0}年{1}か月', [l.left ~/ 12, l.left % 12]) : tr('あと{0}か月', [l.left])),
          _cell(yen(l.principal + l.interest)),
        ]),
      ),
  ];
  return [
    Panel(
      key: const ValueKey('money-bank'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: CardTitle(tr('借金と銀行'))),
          Tag(tr('格付け {0}', [r]), key: const ValueKey('bank-rating'), kind: r == 'A' ? TagKind.good : r == 'D' ? TagKind.bad : r == 'C' ? TagKind.gold : TagKind.plain),
        ]),
        const SizedBox(height: 4),
        Grid2([
          Kv(tr('借金の合計'), yen(s.debt)),
          Kv(tr('年の利益'), yen(s.annualProfit())),
          Kv(tr('借金は利益の'), s.debt <= 0 ? '―' : (x >= 99 ? tr('赤字') : tr('{0}倍', [x.toStringAsFixed(1)]))),
          Kv(tr('借りられる上限'), yen(s.borrowLimit())),
          Kv(tr('あと借りられる'), yen(room)),
          Kv(tr('担保の値打ち'), yen(s.collateral())),
          Kv(tr('次に借りる金利'), '${pctD(s.loanRate() * 100)}%'),
          Kv(tr('今月の返済'), yen(s.loanPrincipal() + s.loanInterest())),
        ]),
        const SizedBox(height: 4),
        Muted(
            tr('上限は年の利益の約4倍と、店・工場・土地の値打ちの半分で決まります。現金は入りません。借金が利益の3倍・5倍・8倍を超えるごとに金利が上がり、格付けが下がります。C は残りの半分まで、D は貸してもらえません'),
            size: 11.5),
        if (s.bankCtl > 0) Padding(padding: const EdgeInsets.only(top: 4), child: Text(tr('メインバンクが経営に口を出しています（あと{0}か月）。新しく借りられません', [s.bankCtl]), style: ts(size: 12.5, color: Pal.down, bold: true))),
      ]),
    ),
    Panel(
      key: const ValueKey('bank-loans'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CardTitle(tr('借りている相手')),
        const SizedBox(height: 4),
        if (rows.isEmpty)
          Muted(tr('借金はありません'))
        else ...[
          Row(children: [
            _cell(tr('相手'), w: Ui.sw(92), a: TextAlign.left, c: Pal.mute),
            _cell(tr('残り'), c: Pal.mute),
            _cell(tr('金利'), c: Pal.mute),
            _cell(tr('期限'), c: Pal.mute),
            _cell(tr('毎月の返済'), c: Pal.mute),
          ]),
          ...rows,
        ],
      ]),
    ),
    Panel(
      key: const ValueKey('bank-act'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: CardTitle(tr('銀行に会う'))),
          ApTag(hr(s, 'bank')),
        ]),
        const SizedBox(height: 4),
        Wrap(spacing: 6, runSpacing: 4, children: [
          Muted(tr('返す期限'), size: 12),
          for (final m in loanTerms) PickChip(tr('{0}年', [m ~/ 12]), key: ValueKey('term-$m'), on: ctl.loanTerm == m, onTap: () => ctl.setLoanTerm(m)),
        ]),
        const SizedBox(height: 4),
        Wrap(spacing: 6, runSpacing: 0, children: [
          for (final k in const [.25, .5, 1.0])
            Builder(builder: (_) {
              final a = room * k;
              return Btn(tr('{0} 借りる', [yen(a)]), () {
                if (!ctl.noAp('bank')) ctl.act(() => s.borrow(a, ctl.loanTerm));
              }, key: ValueKey('borrow-$k'), small: true, enabled: a >= 1e5, dim: !s.canT('bank'));
            }),
          Btn(tr('全部返す'), () => ctl.act(() => s.repay(s.debt)), key: const ValueKey('repay-all'), small: true, enabled: s.debt > 0 && s.cash > 0),
          Btn(tr('社債を出す（約{0}）', [yen(s.bondSize())]), () {
            if (!ctl.noAp('bond')) ctl.act(s.issueBond);
          }, small: true, enabled: s.canBond(), ap: hr(s, 'bond')),
          if (s.land > 0) Btn(tr('土地を売る（今の値 {0}）', [yen(s.land)]), () => ctl.act(s.sellLand), small: true, shrink: true),
        ]),
      ]),
    ),
  ];
}

/// 経費の名前
const expNames = {'crew': '現場の人件費', 'staff': '部下の給料', 'hq': '本社の経費', 'ad': '広告費', 'int': '支払利息', 'tax': '税金'};

List<Widget> _costView(GameController ctl) {
  final s = ctl.game!;
  final now = s.expenses(), was = s.expLast;
  final rows = <Widget>[];
  for (final k in expKeys) {
    final a = now[k] ?? 0, b = was[k];
    final d = b == null ? null : a - b;
    rows.add(Container(
      key: ValueKey('cost-$k'),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: Ui.rowLine,
      child: Row(children: [
        _cell(tr(expNames[k]!), w: Ui.sw(110), a: TextAlign.left),
        _cell(yen(a)),
        _cell(b == null ? '―' : yen(b), c: Pal.mute),
        _cell(d == null || d.abs() < 1 ? '―' : '${d > 0 ? '+' : ''}${yen(d)}', c: d == null ? Pal.mute : (d > 0 ? Pal.down : Pal.up)),
      ]),
    ));
  }
  return [
    Panel(
      key: const ValueKey('money-cost'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CardTitle(tr('経費（毎月）')),
        const SizedBox(height: 4),
        Row(children: [
          _cell(tr('内訳'), w: Ui.sw(110), a: TextAlign.left, c: Pal.mute),
          _cell(tr('今月'), c: Pal.mute),
          _cell(tr('先月'), c: Pal.mute),
          _cell(tr('増減'), c: Pal.mute),
        ]),
        ...rows,
        const SizedBox(height: 6),
        Muted(tr('現場の人件費は、その国の賃金と最低賃金の動きに毎月ついていきます。今の最低賃金は月{0}', [yen(s.minWageYen(s.home) / 12)]), size: 11.5),
      ]),
    ),
  ];
}

List<Widget> _taxView(GameController ctl) {
  final s = ctl.game!;
  return [
    Panel(
      key: const ValueKey('money-tax'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CardTitle(tr('税金')),
        const SizedBox(height: 4),
        Grid2([
          Kv(tr('法人税率（{0}・{1}）', [cm[s.home]!.n, yearL(s.year)]), '${pctD(s.corpTaxRate() * 100)}%'),
          Kv(tr('今年の利益（積み上げ）'), yen(s.ytdPre)),
          Kv(tr('今年払った税金'), yen(s.ytdTax)),
          Kv(tr('先月の税金'), yen(s.lastTax)),
        ]),
        const SizedBox(height: 6),
        Muted(tr('税金は国と年の法人税率で、今年の利益の積み上げにかかります。赤字の月があると、今年払った分から戻ります。年が替わると積み上げは0に戻ります'), size: 11.5),
      ]),
    ),
  ];
}

// ===== 世界 =====
/// 地図に置く国の場所（経度・緯度のおおよそ）
const Map<String, (double, double)> ctryPos = {
  'jp': (138, 36), 'cn': (105, 34), 'kr': (127.5, 37), 'tw': (121, 23.7), 'in': (78, 22), 'id': (113, -2), 'th': (101, 15), 'vn': (106, 17), //
  'ph': (122, 12), 'sg': (103.8, 1.3), 'us': (-98, 39), 'ca': (-100, 57), 'mx': (-102, 23), 'br': (-52, -10), 'uk': (-2, 54), 'de': (10, 51), //
  'fr': (2, 46.5), 'it': (12.5, 42.5), 'es': (-4, 40), 'ru': (80, 60), 'sa': (45, 24), 'ng': (8, 9), 'za': (25, -29), 'au': (134, -25),
};

/// 成長率の色（不況は赤、ふつうは薄い緑、好景気は濃い緑）
Color growthColor(double g) => g < 0
    ? const Color(0xFFE57373)
    : g < 1.5
        ? const Color(0xFFF2D98A)
        : g < 4
            ? const Color(0xFFA5D6A7)
            : const Color(0xFF43A047);

List<Widget> worldTab(GameController ctl, double width) {
  final s = ctl.game!;
  final sel = ctl.worldSel ?? s.home;
  final open = [for (final c in CTRY) if (s.ctryOpen(c.c)) c];
  final map = Panel(
    key: const ValueKey('world-map'),
    padding: const EdgeInsets.all(6),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AspectRatio(
        aspectRatio: 2.1,
        child: LayoutBuilder(
          builder: (context, c) => GestureDetector(
            onTapUp: (d) {
              final hit = WorldPainter.hitCountry(s, Size(c.maxWidth, c.maxHeight), d.localPosition);
              if (hit != null) ctl.setWorld(hit);
            },
            child: Semantics(
                label: tr('世界地図。国の色はその年の成長率'),
                image: true,
                child: CustomPaint(painter: WorldPainter(s, sel), size: Size.infinite)),
          ),
        ),
      ),
      const SizedBox(height: 4),
      Wrap(spacing: 10, runSpacing: 2, children: [
        for (final l in [(-1.0, '不況'), (1.0, '足踏み'), (3.0, 'ふつう'), (5.0, '好景気')])
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: growthColor(l.$1), borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 3),
            Text(tr(l.$2), style: ts(size: 11, color: Pal.mute)),
          ]),
        Text(tr('★ 自社が出ている国'), style: ts(size: 11, color: Pal.mute)),
      ]),
    ]),
  );
  final table = Panel(
    key: const ValueKey('world-table'),
    padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      CardTitle(tr('国の比較（{0}）', [yearL(s.year)])),
      const SizedBox(height: 4),
      Row(children: [
        _cell(tr('国'), w: Ui.sw(84), a: TextAlign.left, c: Pal.mute),
        _cell(tr('成長'), c: Pal.mute),
        _cell(tr('金利'), c: Pal.mute),
        _cell(tr('物価'), c: Pal.mute),
        _cell(tr('市場'), c: Pal.mute),
        _cell(tr('最低賃金'), c: Pal.mute),
      ]),
      for (final c in open.toList()..ssort((a, b) => cw(b.c, s.yr()).compareTo(cw(a.c, s.yr()))))
        InkWell(
          key: ValueKey('world-row-${c.c}'),
          onTap: () => ctl.setWorld(c.c),
          child: Container(
            constraints: const BoxConstraints(minHeight: 30),
            color: c.c == sel ? Pal.onBg : null,
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              _cell('${_inMark(s, c.c)}${c.n}', w: Ui.sw(84), a: TextAlign.left, bold: c.c == s.home),
              _cell('${pctD(s.growthOf(c.c))}%', c: s.growthOf(c.c) < 0 ? Pal.down : Pal.ink),
              _cell('${pctD(s.rateOf(c.c))}%'),
              _cell('${pctD(s.inflOf(c.c))}%'),
              _cell('×${(cw(c.c, s.yr()) / math.max(cw(s.home, s.yr()), 1e-9)).toStringAsFixed(2)}'),
              _cell(yen(s.minWageYen(c.c) / 12)),
            ]),
          ),
        ),
    ]),
  );
  final detail = _countryDetail(ctl, sel);
  if (width >= 620) {
    return [
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [map, table])),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: detail),
        ]),
      ),
    ];
  }
  return [const SizedBox(height: 6), map, detail, table];
}

String _inMark(Game s, String c) => s.biz.any((b) => s.ctryOf(b).contains(c)) ? '★' : '';

Widget _countryDetail(GameController ctl, String c) {
  final s = ctl.game!;
  final mine = s.biz.where((b) => s.ctryOf(b).contains(c)).toList();
  final cities = econData.cities(c);
  return Column(key: const ValueKey('world-detail'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    countryPanel(ctl, c, title: '${cm[c]!.n}${c == s.home ? tr('（本拠）') : ''}'),
    Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Grid2([
          Kv(tr('人口'), tr('{0}万人', [jsNum(jsRound(s.ev(c, 'pop') / 1e4))])),
          Kv(tr('失業率'), '${pctD(s.ev(c, 'unemp'))}%'),
          Kv(tr('市場の大きさ'), tr('{0}の{1}倍', [cm[s.home]!.n, (cw(c, s.yr()) / math.max(cw(s.home, s.yr()), 1e-9)).toStringAsFixed(2)])),
          Kv(tr('平均賃金'), tr('{0}／年', [yen(s.ev(c, 'wage_usd') * s.usdJpy())])),
        ]),
        if (cities.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Muted(tr('主な都市：{0}', [cities.take(4).map((x) => tx(x.ja)).join(tr('・'))]), size: 12)),
        const SizedBox(height: 6),
        CardTitle(tr('自社の出方')),
        const SizedBox(height: 2),
        if (!s.ctryOpen(c))
          Muted(tr('この年はまだ入れません'))
        else if (mine.isEmpty)
          Muted(tr('まだ出ていません。「事業」の「海外に出る」から出られます'))
        else
          for (final b in mine)
            Text('${tr('・@@bullet')}${indm[b.ind]!.name}${(b.jv ?? []).contains(c) ? tr('（組んで）') : ''}', style: ts(size: 12.5)),
      ]),
    ),
  ]);
}

/// 世界地図（国を丸で置く。色＝その年の成長率、大きさ＝市場の大きさ、★＝自社が出ている国）
class WorldPainter extends CustomPainter {
  final Game s;
  final String sel;
  final int stamp;
  WorldPainter(this.s, this.sel) : stamp = Object.hash(s.turn, sel, s.biz.length, L.lang);

  static Offset _pos(String c, Size size) {
    final p = ctryPos[c] ?? (0.0, 0.0);
    // 経度 -130〜160、緯度 -45〜70 を絵に収める
    return Offset((p.$1 + 130) / 290 * size.width, (70 - p.$2) / 115 * size.height);
  }

  static double _r(Game s, String c, Size size) => (math.sqrt(math.max(cw(c, s.yr()), .01)) * .045 * size.height).clamp(size.height * .035, size.height * .12).toDouble();

  /// 押した場所の国（いちばん近い国。遠すぎれば null）
  static String? hitCountry(Game s, Size size, Offset at) {
    String? best;
    var bd = double.infinity;
    for (final c in CTRY) {
      if (!s.ctryOpen(c.c)) continue;
      final d = (_pos(c.c, size) - at).distance - _r(s, c.c, size);
      if (d < bd) {
        bd = d;
        best = c.c;
      }
    }
    return bd < size.height * .12 ? best : null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFFDDEFF8);
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)), bg);
    // 大陸の目安（ごく簡単な形）
    final land = Paint()..color = const Color(0xFFF3EEDF);
    for (final r in const [
      (-125.0, 70.0, -60.0, 15.0), (-80.0, 12.0, -35.0, -40.0), (-10.0, 70.0, 40.0, 36.0), (-15.0, 35.0, 50.0, -35.0), //
      (40.0, 70.0, 145.0, 10.0), (95.0, 8.0, 125.0, -8.0), (113.0, -12.0, 153.0, -38.0),
    ]) {
      final a = _pos2(r.$1, r.$2, size), b = _pos2(r.$3, r.$4, size);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromPoints(a, b), Radius.circular(size.height * .08)), land);
    }
    final dot = Paint();
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final c in CTRY) {
      final o = _pos(c.c, size);
      final r = _r(s, c.c, size);
      final open = s.ctryOpen(c.c);
      dot.color = open ? growthColor(s.growthOf(c.c)) : const Color(0xFFCCCCCC);
      canvas.drawCircle(o, r, dot);
      ring.color = c.c == sel ? Pal.goldtx : (c.c == s.home ? Pal.ink : Pal.line);
      ring.strokeWidth = c.c == sel ? 2.5 : 1;
      canvas.drawCircle(o, r, ring);
      final mark = _inMark(s, c.c);
      final tp = TextPainter(
          text: TextSpan(text: '$mark${c.c.toUpperCase()}', style: TextStyle(fontSize: math.max(8, size.height * .045), color: Pal.ink, fontFamily: fontFamily, fontWeight: FontWeight.w700)),
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, o - Offset(tp.width / 2, tp.height / 2));
    }
  }

  static Offset _pos2(double lon, double lat, Size size) => Offset((lon + 130) / 290 * size.width, (70 - lat) / 115 * size.height);

  @override
  bool shouldRepaint(covariant WorldPainter o) => o.s != s || o.stamp != stamp;
}
