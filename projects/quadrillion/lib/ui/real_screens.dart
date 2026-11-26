/// 横向きの画面の骨組みと、現実に寄せた画面（お金・世界・街）。1.1.0+25 から。
/// 骨組み: 上の帯（日付・現金・借金・時価総額・順位・社長の時間と体力）／左の切り替え／真ん中に本体／右の帯（今月やること・社長の予定）／下に「次の月へ」
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/game.dart';
import 'controller.dart';
import 'fin_screens.dart';
import 'glossary.dart';
import 'life_screens.dart';
import 'look.dart';
import 'sheets.dart';
import 'tabs.dart';
import 'widgets.dart';
import 'world_map.dart';
import 'world_screen.dart';

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
/// 上の帯に「次の月へ」などのボタンも載せる最小の幅（字の倍率で割った幅。これより狭い縦の画面は、今までどおり下にボタンの段を置く）
const topMergeMin = 600.0;

/// 上の帯の「まとめて進める」「社長の行動」に字まで書く最小の幅（字の倍率で割った幅。これより狭いと印だけにする）
const topLabelsMin = 760.0;

/// 上の帯。[merged] のときは、数字を2段に詰めて、右端に「まとめて進める」「社長の行動」「次の月へ」を置く（1.1.0+31。下の段をなくして、中身を見える高さを広げた）
Widget topBar(GameController ctl, {required bool side, bool merged = false, double width = 0}) {
  final s = ctl.game!;
  final rk = s.rank != 0 ? s.rank : s.rankList().indexWhere((x) => x.me) + 1;
  Widget stat(String k, String v, [Color c = Pal.ink, Key? key]) => Padding(
        padding: EdgeInsets.only(right: merged ? 10 : 12),
        child: Text.rich(key: key, TextSpan(children: [
          TextSpan(text: k, style: ts(size: 12, color: Pal.mute)),
          TextSpan(text: v, style: ts(size: 13, color: c, bold: true)),
        ])),
      );
  final date = Text(ym(s.year, s.q, sp: true), key: const ValueKey('top-date'), style: ts(size: merged ? 14 : 15, color: Pal.goldtx, bold: true));
  final cash = FlashStat(tr('現金 '), yen(s.cash), value: s.cash, turn: s.turn);
  final debt = stat(tr('借金 '), yen(s.debt), s.debt > 0 ? Pal.down : Pal.ink, const ValueKey('top-debt'));
  final cap = FlashStat(tr('時価総額 '), yen(s.cap), value: s.cap, turn: s.turn, color: Pal.goldtx);
  final rank = FlashStat(tr('世界 '), tr('{0}位', [rk]), value: rk.toDouble(), turn: s.turn, higherIsBetter: false);
  final hours = HoursGauge(s, key: const ValueKey('ap'));
  // 数字の列は、入りきらなければ字を縮めて収める
  final stats = merged
      ? FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [date, const SizedBox(width: 10), cash, const SizedBox(width: 10), debt]),
            Row(mainAxisSize: MainAxisSize.min, children: [cap, const SizedBox(width: 10), rank, const SizedBox(width: 10), hours]),
          ]),
        )
      : FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(children: [cash, const SizedBox(width: 12), debt, cap, const SizedBox(width: 12), rank, const SizedBox(width: 12), hours]),
        );
  // 狭い横の画面（667 など）では、「まとめて進める」「社長の行動」は印だけにする（「次の月へ」は字のまま、金の主ボタン）
  final labels = width / Ui.textScale >= topLabelsMin;
  final acts = merged && s.over == null
      ? <Widget>[
          const SizedBox(width: 6),
          labels
              ? Btn(tr('まとめて進める'), () => openAdvance(ctl), key: const ValueKey('advance-menu'), small: true, more: true)
              : IconBtn(Icons.fast_forward, tr('まとめて進める'), () => openAdvance(ctl), key: const ValueKey('advance-menu')),
          const SizedBox(width: 4),
          labels
              ? Btn(tr('社長の行動'), () => openPresSheet(ctl), key: const ValueKey('pres-open'), small: true, more: true)
              : IconBtn(Icons.directions_walk, tr('社長の行動'), () => openPresSheet(ctl), key: const ValueKey('pres-open')),
          const SizedBox(width: 4),
          Btn(tr('次の月へ'), () => doNext(ctl), key: const ValueKey('next'), primary: true),
        ]
      : const <Widget>[];
  return Container(
    decoration: const BoxDecoration(color: Pal.panel, border: Border(bottom: BorderSide(color: Pal.line))),
    padding: merged ? const EdgeInsets.fromLTRB(10, 1, 6, 1) : const EdgeInsets.fromLTRB(10, 4, 6, 4),
    child: Row(children: [
      if (!merged) ...[date, const SizedBox(width: 12)],
      Expanded(child: stats),
      ...acts,
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
        // ふつうに使える残りを出し、使い切ったら無理をして使える分を出す
        Text(
            s.down > 0
                ? tr('休養中 あと{0}か月', [s.down])
                : normal > 0 || left <= 0
                    ? tr('残り{0}h', [jsRound(normal)])
                    : tr('無理 +{0}h', [jsRound(left)]),
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
        // 7つが縦に入りきらない低い画面では、高さを等分する（1つ40未満なら字を省いて印だけにする）
        final compact = c.maxHeight < railTabs.length * 48;
        final each = compact ? c.maxHeight / railTabs.length : 48.0;
        // 流す欄にはしない（真ん中の一覧より前に流す欄があると、ほかの所の「最初の流す欄」を取り違える）。低い画面では高さを等分する
        Widget sized(Widget w) => compact ? Expanded(child: w) : SizedBox(height: each, child: w);
        return ClipRect(
          child: Column(children: [
            for (final t in railTabs)
              sized(Semantics(
                button: true,
                selected: ctl.tab == t.$1,
                label: tr(t.$2),
                child: InkWell(
                  key: ValueKey('tab-${t.$1}'),
                  onTap: () => ctl.setTab(t.$1),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: ctl.tab == t.$1 ? Pal.onBg : null, border: Border(left: BorderSide(color: ctl.tab == t.$1 ? Pal.gold : Colors.transparent, width: 3))),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(t.$3, size: compact ? 18 : 20, color: ctl.tab == t.$1 ? Pal.goldtx : Pal.mute),
                      if (each >= 40)
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(tr(t.$2), maxLines: 1, style: ts(size: 10.5, color: ctl.tab == t.$1 ? Pal.goldtx : Pal.mute, bold: ctl.tab == t.$1, height: 1.2)),
                        ),
                    ]),
                  ),
                ),
              )),
          ]),
        );
      }),
    );

// ===== 右の帯（今月やること・社長の予定） =====
List<Widget> sideItems(GameController ctl, {bool sheet = false}) {
  final s = ctl.game!;
  // 右の帯と小窓では、ひとことを「…」で切らずに最後まで出す（1.1.0+40）
  final todo = todoCard(ctl, full: true);
  final meet = s.hMeet();
  return [
    // 右の帯の頭に「たたむ」（小窓には出さない）
    if (!sheet)
      Semantics(
        button: true,
        label: tr('右の帯をたたむ'),
        excludeSemantics: true,
        onTap: ctl.toggleSide,
        child: InkWell(
          key: const ValueKey('side-fold'),
          borderRadius: BorderRadius.circular(Ui.rBtn),
          onTap: ctl.toggleSide,
          child: Container(
            height: minTap,
            padding: const EdgeInsets.only(left: 4),
            child: Row(children: [
              const Icon(Icons.checklist, size: 15, color: Pal.goldtx),
              const SizedBox(width: 4),
              Expanded(child: Text(tr('今月 {0}件', [todoCount(s)]), maxLines: 1, style: ts(size: 12, bold: true, color: Pal.goldtx))),
              Text(tr('たたむ'), style: ts(size: 11, color: Pal.mute)),
              const Icon(Icons.keyboard_double_arrow_right, size: 18, color: Pal.mute),
            ]),
          ),
        ),
      ),
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
      ]),
    ),
  ];
}

/// たたんだ右の帯の幅（1.1.0+40）
const sideFoldW = 48.0;

/// たたんだ右の帯：「今月やること」の件数と、社長の残りの時間だけ。全体を押すと開く
Widget sideFoldedBar(GameController ctl) {
  final s = ctl.game!;
  final n = todoCount(s);
  return Semantics(
    button: true,
    label: tr('今月やること {0}件・押すと右の帯を開く', [n]),
    excludeSemantics: true,
    onTap: ctl.toggleSide,
    child: InkWell(
      key: const ValueKey('side-unfold'),
      onTap: ctl.toggleSide,
      child: Column(children: [
        const SizedBox(height: 10),
        const Icon(Icons.keyboard_double_arrow_left, size: 20, color: Pal.mute),
        const SizedBox(height: 10),
        Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: Pal.goldBg, border: Border.all(color: Pal.gold), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.checklist, size: 20, color: Pal.goldtx),
          ),
          if (n > 0)
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                key: const ValueKey('side-count'),
                constraints: const BoxConstraints(minWidth: 18),
                height: 18,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(color: Pal.down, borderRadius: BorderRadius.circular(9), border: Border.all(color: Pal.panel, width: 1.5)),
                child: Text('$n', textScaler: TextScaler.noScaling, style: ts(size: 10.5, bold: true, color: Pal.panel, height: 1)),
              ),
            ),
        ]),
        const SizedBox(height: 4),
        FittedBox(fit: BoxFit.scaleDown, child: Text(tr('今月'), maxLines: 1, style: ts(size: 10.5, color: Pal.goldtx, bold: true))),
        const SizedBox(height: 12),
        const Icon(Icons.schedule, size: 18, color: Pal.goldtx),
        FittedBox(fit: BoxFit.scaleDown, child: Text(tr('残り{0}h', [jsRound(s.hNormalLeft())]), maxLines: 1, style: ts(size: 10.5, color: Pal.mute))),
      ]),
    ),
  );
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
  final wide = width >= 500;
  final cities = s.cityList(s.home);
  final city = ctl.townCity < cities.length ? ctl.townCity : 0;
  final nCtry = <String>{for (final b in s.biz) ...s.ctryOf(b)}.length;
  final rival = topRival(s);
  const tone = ScreenTone.town;
  final t = s.turn;
  final m1 = histBack(s, 1), y1 = histBack(s, 12);
  final mon = tr('前月'), yr = tr('前年');
  final rank = s.rank != 0 ? s.rank : s.rankList().indexWhere((x) => x.me) + 1;
  // 見出しの帯（1.1.0+41）：会社の段階・本社・拠点と出ている国の数
  final band = ScreenBand(
    key: const ValueKey('town-band'),
    tone: tone,
    icon: Icons.location_city,
    title: tr('街@@tab'),
    facts: [
      (tr('段階'), tx(s.stageName())),
      (tr('本社'), tx(s.officeName())),
      (tr('拠点'), tr('{0}・{1}か国', [cm[s.home]!.city, nCtry == 0 ? 1 : nCtry])),
    ],
  );
  // 会社の数字は要点のカード（前の月・前の年からの増減つき。1.1.0+41）
  final kpis = KpiRow(key: const ValueKey('town-kpis'), minW: 92, [
    KpiCard(key: const ValueKey('kpi-town-cap'), label: tr('時価総額'), icon: Icons.trending_up, value: s.cap, fmt: yen, turn: t, tone: tone,
        delta: Delta.pct(s.cap, m1?.cap, label: mon), delta2: Delta.pct(s.cap, y1?.cap, label: yr)),
    KpiCard(key: const ValueKey('kpi-town-rank'), label: tr('世界の順位'), icon: Icons.emoji_events_outlined, value: rank.toDouble(), fmt: (v) => tr('{0}位', [v.round()]), turn: t, tone: tone),
    KpiCard(key: const ValueKey('kpi-town-rev'), label: tr('月の売上'), icon: Icons.payments_outlined, value: s.rev, fmt: yen, turn: t, tone: tone,
        delta: Delta.pct(s.rev, m1?.rev, label: mon), delta2: Delta.pct(s.rev, y1?.rev, label: yr)),
    KpiCard(key: const ValueKey('kpi-town-pre'), label: tr('月の利益'), icon: Icons.savings_outlined, value: s.pre, fmt: yen, turn: t, tone: tone,
        color: s.pre >= 0 ? Pal.up : Pal.down, delta: Delta.diff(s.pre, m1?.pre, yen, label: mon), delta2: Delta.diff(s.pre, y1?.pre, yen, label: yr)),
    KpiCard(key: const ValueKey('kpi-town-cash'), label: tr('現金'), icon: Icons.account_balance_wallet_outlined, value: s.cash, fmt: yen, turn: t, tone: tone,
        color: s.cash < 0 ? Pal.down : Pal.ink, delta: Delta.diff(s.cash, m1?.cash, yen, label: mon)),
    KpiCard(key: const ValueKey('kpi-town-biz'), label: tr('事業'), icon: Icons.work_outline, value: s.biz.length.toDouble(), fmt: (v) => tr('{0}つ', [v.round()]), turn: t, tone: tone,
        sub: tr('子会社 {0}社・部下 {1}人', [s.subs().length, s.staff.length])),
  ], maxPer: 3);
  // 会社の段階・本社・拠点は上の帯に出すので、ここは目標だけ（1.1.0+41）
  final me = Panel(
    key: const ValueKey('town-company'),
    padding: const EdgeInsets.fromLTRB(Ui.pad, 8, Ui.pad, 8),
    child: Text.rich(TextSpan(children: [
      WidgetSpan(alignment: PlaceholderAlignment.middle, child: Padding(padding: const EdgeInsets.only(right: 6), child: Icon(Icons.flag, size: 16, color: tone.ink))),
      TextSpan(text: tr('目標　'), style: ts(size: 12.5, bold: true)),
      TextSpan(text: tx(s.goalText()), style: ts(size: 12.5)),
    ])),
  );
  // 宿敵の顔つき（いちばん大きい宿敵。顔・名前・時価総額の差。押すと下の宿敵の欄で開く）
  final foe = rival == null
      ? null
      : Panel(
          key: const ValueKey('town-rival-gap'),
          border: rivalInk(rival.rival!.col).withValues(alpha: .5),
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Row(children: [
            rivalFace(s, rival, size: 44),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text.rich(TextSpan(children: [
                  TextSpan(text: tr('宿敵 '), style: ts(size: 11.5, color: Pal.mute)),
                  TextSpan(text: nmL(rival.name), style: ts(size: 14, bold: true, color: rivalInk(rival.rival!.col))),
                ])),
                Text(tr('社長 {0}・関係 {1}', [nmL(rival.presName), tx(relWord(rival.rel))]), style: ts(size: 12, color: Pal.mute)),
                const SizedBox(height: 2),
                Text(
                    s.cap >= rival.cap
                        ? tr('時価総額 {0}（あなたが{1}倍）', [yen(rival.cap), timesL(s.cap / math.max(rival.cap, 1))])
                        : tr('時価総額 {0}（あなたの{1}倍）', [yen(rival.cap), timesL(rival.cap / math.max(s.cap, 1))]),
                    style: ts(size: 12.5, bold: true, color: s.cap >= rival.cap ? Pal.up : Pal.down)),
              ]),
            ),
          ]),
        );
  final econ = countryPanel(ctl, s.home, key: const ValueKey('town-econ'), title: tr('{0}の景気', [cm[s.home]!.n]), tone: tone);
  // 今月の分（この月と、月を進めたときに出た知らせ）を4つまで出し、残りは「もっと見る」で出す（1.1.0+31。1.1.0+41 から4つまで）
  final recent = s.log.reversed.take(townNewsMax).toList();
  final cur = s.year * 12 + s.q;
  final fresh = math.min(townNewsFew, recent.takeWhile((n) => n.y != null && n.q != null && n.y! * 12 + n.q! >= cur - 1).length);
  final newsOpen = ctl.shown.contains('town-news');
  Widget line(LogEntry n) => NewsLine(n.m, n.t, prefix: n.y != null ? '${yearL(n.y!)} ' : null, icon: newsIcon(s, n));
  final news = Panel(
    key: const ValueKey('town-news'),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHead(tr('今月のニュース'), Icons.newspaper, tone: tone),
      const SizedBox(height: 4),
      if (recent.isEmpty) Muted(tr('まだ知らせはありません')) else if (fresh == 0) Muted(tr('今月の知らせはありません')),
      for (final n in recent.take(newsOpen ? recent.length : fresh)) line(n),
      if (recent.length > fresh)
        MoreBtn(key: const ValueKey('more-town-news'), open: newsOpen, rest: recent.length - fresh, onTap: () => ctl.toggleShown('town-news')),
    ]),
  );
  // 1.1.0+42 から街の絵を外した。上の段は左に要点のカードと目標、右に宿敵と景気。
  // 下の段は左に都市ごとの自社の拠点（前は絵の看板でしか分からなかった）、右に今月のニュース
  final sites = townSitesPanel(ctl, city);
  final out = <Widget>[band];
  if (wide) {
    Widget cols(List<Widget> l, List<Widget> r, {int lf = 1, int rf = 1}) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: lf, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: l)),
          const SizedBox(width: 8),
          Expanded(flex: rf, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: r)),
        ]);
    out.add(cols([kpis, me], [?foe, econ], lf: 3, rf: 2));
    out.add(sites == null ? news : cols([sites], [news]));
  } else {
    out.addAll([kpis, me, ?sites, ?foe, econ, news]);
  }
  final vow = s.vow;
  if (vow != null) {
    out.add(Panel(border: Pal.down, child: Text(tr('取締役会との約束：{0}年1月までに、年の利益を{1}まで戻す', [vow['y']!.round(), yen(vow['target']!)]), style: ts(size: 13))));
  }
  out.addAll(townRivalsOf(ctl));
  return out;
}

/// 街のニュースで「もっと見る」まで含めて出す数
const townNewsMax = 10;

/// 街のニュースで、はじめに出す数（今月の知らせがもっとあれば「もっと見る」。1.1.0+41）
const townNewsFew = 4;

/// いちばん大きい宿敵（いなければ null）
Company? topRival(Game s) {
  final l = s.cos.where((c) => c.alive && c.rival != null && c.parent != 'player').toList()..ssort((a, b) => b.cap.compareTo(a.cap));
  return l.firstOrNull;
}

/// 街の画面に、一度に名前を出す事業の数（残りは「ほか○事業」）
const townSitesMax = 4;

/// 都市ごとの自社の拠点（1.1.0+42。前は街の絵の看板の数でしか分からなかった）。
/// 上に都市の切り替え、下に選んだ都市にある事業ごとの店・工場などの数（都心・郊外）。
/// 店などの数を使わない遊び（[GameUnits.unitsOn] が切れている）では出さない
Widget? townSitesPanel(GameController ctl, int city) {
  final s = ctl.game!;
  if (!s.unitsOn) return null;
  final cities = s.cityList(s.home);
  final name = city < cities.length ? (L.en ? cities[city].en : cities[city].ja) : cm[s.home]!.city;
  // 選んだ都市の都心・郊外にある数（育っている分を含む）。多い順
  final rows = <(Biz, double, double)>[
    for (final b in s.biz)
      if (KIND_ZONED.contains(s.kindB(b))) (b, s.unitsAt(b, '${s.home}/$city/0'), s.unitsAt(b, '${s.home}/$city/1')),
  ].where((r) => r.$2 + r.$3 > 0).toList()
    ..ssort((a, b) => (b.$2 + b.$3).compareTo(a.$2 + a.$3));
  String count(Biz b, double down, double sub) => [
        if (down > 0) '${tr(ZONE_JA[0])} ${s.unitCount(b, down)}',
        if (sub > 0) '${tr(ZONE_JA[1])} ${s.unitCount(b, sub)}',
      ].join(tr('・'));
  return Panel(
    key: const ValueKey('town-sites'),
    padding: const EdgeInsets.fromLTRB(Ui.pad, 8, Ui.pad, 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // 見出しの右に都市の切り替え（自分の国の都市。1.1.0+26）を同じ行に並べ、入りきらない分は横に送る
      if (cities.length > 1)
        Row(children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(color: ScreenTone.town.soft, borderRadius: BorderRadius.circular(6)),
            child: Icon(Icons.storefront, size: 14, color: ScreenTone.town.ink),
          ),
          const SizedBox(width: 6),
          Semantics(header: true, child: Text(tr('自社の拠点'), maxLines: 1, style: Ui.cardTitle())),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              key: const PageStorageKey('town-cities'),
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (var i = 0; i < cities.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  PickChip(L.en ? cities[i].en : cities[i].ja, key: ValueKey('town-city-$i'), on: city == i, onTap: () => ctl.setTownCity(i)),
                ],
              ]),
            ),
          ),
        ])
      else
        SectionHead(tr('{0}にある自社の拠点', [name]), Icons.storefront, tone: ScreenTone.town),
      const SizedBox(height: 2),
      if (rows.isEmpty) Muted(tr('{0}には、まだ店や工場がありません', [name]), size: 12.5),
      for (final r in rows.take(townSitesMax))
        Padding(
          key: ValueKey('town-site-${r.$1.id}'),
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            IndIcon(indm[r.$1.ind]!, size: 20),
            const SizedBox(width: 6),
            Expanded(flex: 2, child: Text(indm[r.$1.ind]!.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(size: 12.5))),
            const SizedBox(width: 6),
            // 数は切らずに、入りきらなければ字を縮める（英語は「Downtown 12 stores, Suburbs 30 stores」と長い）
            Flexible(
                flex: 3,
                child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(count(r.$1, r.$2, r.$3), maxLines: 1, softWrap: false, style: ts(size: 12.5, bold: true)))),
          ]),
        ),
      if (rows.length > townSitesMax) Muted(tr('ほか{0}事業', [rows.length - townSitesMax]), size: 12),
    ]),
  );
}

/// 国の景気の欄（成長・物価・金利・為替・最低賃金・法人税・失業率）
Widget countryPanel(GameController ctl, String c, {Key? key, String? title, ScreenTone tone = ScreenTone.world}) {
  final s = ctl.game!;
  final g = s.growthOf(c);
  return Panel(
    key: key,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // 見出しは印つき（1.1.0+41）
      SectionHead(title ?? cm[c]!.n, Icons.insights,
          tone: tone, trailing: Tag(growthWord(g), kind: g < 0 ? TagKind.bad : g >= 4 ? TagKind.good : TagKind.plain)),
      const SizedBox(height: 4),
      Grid2([
        Kv(tr('成長率'), '${pctD(g)}%'),
        Kv(tr('物価'), '${pctD(s.inflOf(c))}%'),
        Kv(tr('金利'), '${pctD(s.rateOf(c))}%'),
        Kv(tr('為替'), tx(s.fxText(c))),
        Kv(tr('最低賃金（月）'), yen(s.minWageYen(c) / 12)),
        Kv(tr('法人税'), '${pctD(s.ev(c, 'corp_tax'))}%'),
      ]),
      if (s.yr() > econData.lastYear + 1) Padding(padding: const EdgeInsets.only(top: 4), child: Muted(tr('{0}年より先は予測です', [econData.lastYear + 1]), size: 11.5)),
    ]),
  );
}

// ===== お金 =====
/// 1.1.0+34 から、「決算と記録」を「決算書」「事業別（事業ごとの損益）」「社史と順位（社史とランキング）」に分けた。
/// iPhone の横の画面で札が1行に収まるように、札の名前は短くしている
const moneyViews = [('cash', '資金繰り'), ('bank', '借金と銀行'), ('cost', '経費'), ('tax', '税金'), ('fs', '決算書'), ('seg', '事業別'), ('book', '社史と順位')];

List<Widget> moneyTab(GameController ctl) {
  final s = ctl.game!;
  final out = <Widget>[
    // 見出しの帯（1.1.0+41）：現金・借金・月の利益・格付け
    ScreenBand(
      key: const ValueKey('money-band'),
      tone: ScreenTone.money,
      icon: Icons.account_balance,
      title: tr('お金@@tab'),
      facts: [(tr('現金'), yen(s.cash)), (tr('借金'), yen(s.debt)), (tr('月の利益'), yen(s.pre)), (tr('格付け'), s.rating())],
    ),
    // 札は1行に並べ、入りきらない分は横に送る（1.1.0+41）
    SingleChildScrollView(
      key: const PageStorageKey('money-views'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        for (final v in moneyViews) ...[
          if (v != moneyViews.first) const SizedBox(width: 6),
          PickChip(tr(v.$2), key: ValueKey('money-${v.$1}'), on: ctl.moneyView == v.$1, onTap: () => ctl.setMoney(v.$1)),
        ],
      ]),
    ),
    ?moneyKpis(ctl),
  ];
  switch (ctl.moneyView) {
    case 'bank':
      out.addAll(_bankView(ctl));
    case 'cost':
      out.addAll(_costView(ctl));
    case 'tax':
      out.addAll(_taxView(ctl));
    case 'fs':
      out.addAll(finView(ctl));
    case 'seg':
      out.addAll(segView(ctl));
    case 'book':
      out.addAll(numTab(ctl));
    default:
      out.addAll(_cashView(ctl));
  }
  return out;
}

/// 前の月・1年前の記録（無ければ null。hist のいちばん後ろが今月）
HistEntry? histBack(Game s, int back) => s.hist.length > back ? s.hist[s.hist.length - 1 - back] : null;

/// お金の画面の要点のカード（1.1.0+41。見ている面ごとに4枚まで。決算書・事業別は表が主なので出さない）
Widget? moneyKpis(GameController ctl) {
  final s = ctl.game!;
  final t = s.turn;
  final m1 = histBack(s, 1), y1 = histBack(s, 12);
  final mon = tr('前月'), yr = tr('前年');
  const tone = ScreenTone.money;
  KpiCard card(String id, String label, IconData icon, double v, String Function(double) fmt,
          {Delta? d, Delta? d2, String? sub, Color? subColor, Color color = Pal.ink}) =>
      KpiCard(key: ValueKey('kpi-$id'), label: label, icon: icon, value: v, fmt: fmt, turn: t, tone: tone, color: color, delta: d, delta2: d2, sub: sub, subColor: subColor);
  final cards = <Widget>[];
  switch (ctl.moneyView) {
    case 'cash':
      final plan = s.cashPlan();
      final line = s.dangerLine();
      final last = plan.isEmpty ? s.cash : plan.last.cash;
      cards.addAll([
        card('cash', tr('現金'), Icons.account_balance_wallet_outlined, s.cash, yen,
            d: Delta.diff(s.cash, m1?.cash, yen, label: mon), d2: Delta.diff(s.cash, y1?.cash, yen, label: yr), color: s.cash < 0 ? Pal.down : Pal.ink),
        if (plan.isNotEmpty) ...[
          card('cash-in', tr('来月入る'), Icons.south_west, plan.first.inflow, yen, color: Pal.up),
          card('cash-out', tr('来月出る'), Icons.north_east, plan.first.out, yen, color: Pal.down),
        ],
        card('cash-6', tr('6か月後の残り'), Icons.event_outlined, last, yen,
            color: last < line ? Pal.down : Pal.ink, sub: tr('払えなくなる線 {0}', [yen(line)]), subColor: last < line ? Pal.down : null),
      ]);
    case 'bank':
      final r = s.ratingIdx();
      final hasSubs = s.subs().isNotEmpty;
      cards.addAll([
        card('bank-rating', tr('格付け'), Icons.verified_outlined, r.toDouble(), (v) => ratings[v.round().clamp(0, ratings.length - 1)],
            color: r == 0 ? Pal.up : r >= 3 ? Pal.down : r == 2 ? Pal.warn : Pal.ink,
            sub: tr('借金は利益の{0}', [s.groupDebt <= 0 ? '―' : (s.annualProfit() <= 0 ? tr('赤字') : tr('{0}倍', [s.debtMultiple().toStringAsFixed(1)]))])),
        card('debt', tr('借金の合計'), Icons.receipt_long_outlined, s.debt, yen, sub: hasSubs ? tr('グループ {0}', [yen(s.groupDebt)]) : null),
        card('room', tr('あと借りられる'), Icons.add_card_outlined, s.borrowRoom(), yen, sub: tr('上限 {0}', [yen(s.borrowLimit())])),
        card('rate', tr('次に借りる金利'), Icons.percent, s.loanRate() * 100, (v) => '${pctD(v)}%', sub: tr('今月の返済 {0}', [yen(s.loanPrincipal() + s.loanInterest())])),
      ]);
    case 'cost':
      final now = s.expenses(), was = s.expLast;
      double sum(Map<String, double> m) => expKeys.fold(0.0, (a, k) => a + (m[k] ?? 0));
      final top = expKeys.reduce((a, b) => (now[a] ?? 0) >= (now[b] ?? 0) ? a : b);
      cards.addAll([
        card('cost-all', tr('経費の合計（月）'), Icons.receipt_outlined, sum(now), yen,
            d: was.isEmpty ? null : Delta.pct(sum(now), sum(was), label: mon, higherIsBetter: false)),
        card('cost-labor', tr('人件費'), Icons.groups_outlined, now['labor'] ?? 0, yen,
            d: was['labor'] == null ? null : Delta.pct(now['labor'] ?? 0, was['labor'], label: mon, higherIsBetter: false)),
        card('cost-top', tr('いちばん大きい内訳'), Icons.leaderboard_outlined, now[top] ?? 0, yen, sub: tr(expNames[top]!)),
      ]);
    case 'tax':
      cards.addAll([
        card('tax-rate', tr('法人税率'), Icons.gavel_outlined, s.corpTaxRate() * 100, (v) => '${pctD(v)}%', sub: '${cm[s.home]!.n}${tr('・')}${yearL(s.year)}'),
        card('tax-ytd', tr('今年払った税金'), Icons.request_quote_outlined, s.ytdTax, yen, sub: tr('今年の利益 {0}', [yen(s.ytdPre)])),
        card('tax-last', tr('先月の税金'), Icons.event_note_outlined, s.lastTax, yen),
      ]);
    case 'book':
      final me = s.rank != 0 ? s.rank : s.rankList().indexWhere((x) => x.me) + 1;
      cards.addAll([
        card('cap', tr('時価総額'), Icons.trending_up, s.cap, yen, d: Delta.pct(s.cap, m1?.cap, label: mon), d2: Delta.pct(s.cap, y1?.cap, label: yr)),
        card('rank', tr('世界の順位'), Icons.emoji_events_outlined, me.toDouble(), (v) => tr('{0}位', [v.round()])),
        card('rev', tr('月の売上'), Icons.payments_outlined, s.rev, yen, d: Delta.pct(s.rev, m1?.rev, label: mon), d2: Delta.pct(s.rev, y1?.rev, label: yr)),
        card('pre', tr('月の利益'), Icons.savings_outlined, s.pre, yen,
            color: s.pre >= 0 ? Pal.up : Pal.down, d: Delta.diff(s.pre, m1?.pre, yen, label: mon), d2: Delta.diff(s.pre, y1?.pre, yen, label: yr)),
      ]);
    default:
      return null;
  }
  return Padding(padding: const EdgeInsets.only(top: 2), child: KpiRow(cards, minW: 92));
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
        SectionHead(tr('この先6か月の資金繰り'), Icons.waterfall_chart, tone: ScreenTone.money),
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
  // 子会社の借金の持ち分（1.1.0+39。子会社がいれば、グループの借金として出す）
  final subD = s.subDebtShare();
  final hasSubs = s.subs().isNotEmpty;
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
        // 格付け・借金の合計・あと借りられる・次に借りる金利は、上の要点のカードに出す（1.1.0+41）
        SectionHead(tr('借金と銀行'), Icons.account_balance_outlined,
            tone: ScreenTone.money, trailing: hasSubs ? Info(ctl, const ['grpdebt']) : null),
        const SizedBox(height: 4),
        Grid2([
          Kv(tr('年の利益'), yen(s.annualProfit())),
          if (hasSubs) ...[
            Kv(tr('子会社の借金（持ち分）'), yen(subD), key: const ValueKey('bank-subdebt')),
            Kv(tr('グループの借金'), yen(s.groupDebt), key: const ValueKey('bank-grpdebt')),
          ],
          // 「赤字」は年の利益が無いときだけ（1.1.0+39。子会社の借金が入ると、黒字でも99倍を超えることがある）
          Kv(tr('借金は利益の'), s.groupDebt <= 0 ? '―' : (s.annualProfit() <= 0 ? tr('赤字') : tr('{0}倍', [x.toStringAsFixed(1)]))),
          Kv(tr('借りられる上限'), yen(s.borrowLimit())),
          Kv(tr('担保の値打ち'), yen(s.collateral())),
        ]),
        const SizedBox(height: 4),
        Muted(
            tr('上限は年の利益の約3倍と、店・工場・土地の値打ちの4割で決まります。現金は入りません。借金が利益の3倍・5倍・8倍を超えるごとに金利が上がり、格付けが下がります。C は残りの半分まで、D は貸してもらえません'),
            size: 11.5),
        if (hasSubs) Padding(padding: const EdgeInsets.only(top: 2), child: Muted(tr('子会社がいるので、格付け・上限・金利は、子会社の借金と利益と担保の持ち分を足したグループの数で見ます'), size: 11.5)),
        if (s.bankCtl > 0) Padding(padding: const EdgeInsets.only(top: 4), child: Text(tr('メインバンクが経営に口を出しています（あと{0}か月）。新しく借りられません', [s.bankCtl]), style: ts(size: 12.5, color: Pal.down, bold: true))),
      ]),
    ),
    Panel(
      key: const ValueKey('bank-loans'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionHead(tr('借りている相手'), Icons.list_alt, tone: ScreenTone.money, trailing: rows.isEmpty ? null : Muted(tr('{0}件', [rows.length]), size: 12)),
        const SizedBox(height: 4),
        if (rows.isEmpty)
          Muted(tr('借金はありません'))
        else ...[
          Row(children: [
            _cell(tr('借りた相手'), w: Ui.sw(92), a: TextAlign.left, c: Pal.mute),
            _cell(tr('残り'), c: Pal.mute),
            _cell(tr('金利'), c: Pal.mute),
            _cell(tr('期限'), c: Pal.mute),
            _cell(tr('毎月の返済'), c: Pal.mute),
          ]),
          // 期限の近い5件を先に出し、残りは「もっと見る」（1.1.0+41。毎月借りる会社では20件を超えて、画面が長くなっていた）
          ...firstOf(ctl, 'bank-loans', rows, 5),
        ],
      ]),
    ),
    Panel(
      key: const ValueKey('bank-act'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionHead(tr('銀行に会う'), Icons.handshake_outlined, tone: ScreenTone.money, trailing: ApTag(hr(s, 'bank'))),
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
          // 土地は仲介に頼むと3か月ほどで売れる（手数料3%）。急ぐなら値引きしてすぐ売る（1.1.0+38）
          if (s.land > 0 && s.landSell == 0) ...[
            Btn(tr('土地を売りに出す（今の値 {0}・3か月ほど・手数料3%）', [yen(s.land)]), () => ctl.act(s.sellLand), key: const ValueKey('land-sell'), small: true, shrink: true),
            Btn(tr('土地をすぐ売る（15%引き {0}）', [yen(s.land * (1 - GameActions.landQuickCut))]), () => ctl.act(s.sellLandNow), key: const ValueKey('land-quick'), small: true, shrink: true),
          ],
        ]),
        if (s.land > 0 && s.landSell > 0)
          Muted(tr('土地を売りに出しています（今の値 {0}・あと{1}か月ほどで売れます）', [yen(s.land), math.max(0, s.landSell - s.turn)]), size: 11.5),
      ]),
    ),
  ];
}

/// 経費の名前
/// 経費の11の内訳（1.1.0+26。企画書「毎月の経費」）
const expNames = {
  'labor': '人件費',
  'rent': '家賃',
  'cogs': '原価',
  'util': '光熱費',
  'logi': '物流費',
  'ad': '広告費',
  'insur': '保険料',
  'repair': '修繕と更新',
  'hq': '本社の経費',
  'int': '支払利息',
  'tax': '税金',
};

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
        SectionHead(tr('経費（毎月）'), Icons.receipt_outlined, tone: ScreenTone.money),
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
  // 税金・減価償却・保険・IT・特許の欄は、短いほうの列へ詰めて2列に（1.1.0+41）
  return [
    Masonry2([
    Panel(
      key: const ValueKey('money-tax'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionHead(tr('税金'), Icons.gavel_outlined, tone: ScreenTone.money),
        // 税率・今年払った税金・先月の税金は、上の要点のカードに出す（1.1.0+41）
        const SizedBox(height: 2),
        Muted(tr('税金は国と年の法人税率で、今年の利益の積み上げにかかります。赤字の月があると、今年払った分から戻ります。年が替わると積み上げは0に戻ります'), size: 11.5),
      ]),
    ),
    // 減価償却・消費税・保険・IT・特許（1.1.0+30）
    ...taxLifePanels(ctl),
    ]),
  ];
}

// ===== 世界 =====
/// 景気のひとこと（成長率から）
String growthWord(double g) => g < 0
    ? tr('不況')
    : g < 1.5
        ? tr('足踏み')
        : g < 4
            ? tr('ふつう')
            : tr('好景気');

/// 世界の画面（1.1.0+41 から、見出しの帯と、本物の形の地図を幅いっぱいに。地図は world_map.dart）
List<Widget> worldTab(GameController ctl, double width) {
  final s = ctl.game!;
  final sel = ctl.worldSel ?? s.home;
  final open = [for (final c in CTRY) if (s.ctryOpen(c.c)) c];
  final sorted = open.toList()..ssort((a, b) => cw(b.c, s.yr()).compareTo(cw(a.c, s.yr())));
  final nIn = CTRY.where((c) => _inMark(s, c.c).isNotEmpty).length;
  final foes = s.unitsOn ? s.rivalsByCountry() : const <String, List<Company>>{};
  final band = ScreenBand(
    key: const ValueKey('world-band'),
    tone: ScreenTone.world,
    icon: Icons.public,
    title: tr('世界@@tab'),
    facts: [
      (tr('出られる国'), tr('{0}か国', [open.length])),
      (tr('出ている国'), tr('{0}か国', [nIn])),
      (tr('選んでいる国'), '${cm[sel]!.n}${tr('・')}${growthWord(s.growthOf(sel))}'),
    ],
  );
  Widget key(Widget mark, String t, {Key? k}) => Row(mainAxisSize: MainAxisSize.min, children: [mark, const SizedBox(width: 3), Text(t, key: k, style: ts(size: 11, color: Pal.mute))]);
  Widget box(Color c) => Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2), border: Border.all(color: const Color(0x22000000))));
  final map = Panel(
    key: const ValueKey('world-map'),
    padding: const EdgeInsets.all(6),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      WorldMap(s: s, sel: sel, onPick: ctl.setWorld),
      const SizedBox(height: 4),
      Wrap(spacing: 10, runSpacing: 2, children: [
        for (final l in [(-1.0, '不況'), (1.0, '足踏み'), (3.0, 'ふつう'), (5.0, '好景気')]) key(box(growthColor(l.$1)), tr(l.$2)),
        if (open.length < CTRY.length) key(box(MapPal.closed), tr('まだ出られない国')),
        // 自社の名前があれば、その名前で（1.1.0+37）
        Text(s.myCo.isNotEmpty ? tr('★ {0}が出ている国', [nmL(s.myCo)]) : tr('★ 自社が出ている国'), style: ts(size: 11, color: Pal.mute)),
        if (s.unitsOn)
          key(Container(width: 9, height: 9, decoration: BoxDecoration(color: rivalInk(foes.values.expand((l) => l).firstOrNull?.rival?.col ?? '#d23f3f'), borderRadius: BorderRadius.circular(2.5))),
              tr('宿敵の本拠（札の右の四角）'),
              k: const ValueKey('legend-rival')),
        Text(tr('国を押すと、下に中身が出ます'), style: ts(size: 11, color: Pal.mute)),
      ]),
    ]),
  );
  final table = Panel(
    key: const ValueKey('world-table'),
    padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHead(tr('国の比較（{0}）', [yearL(s.year)]), Icons.table_chart_outlined, tone: ScreenTone.world),
      const SizedBox(height: 4),
      Row(children: [
        _cell(tr('国'), w: Ui.sw(84), a: TextAlign.left, c: Pal.mute),
        _cell(tr('成長'), c: Pal.mute),
        _cell(tr('金利'), c: Pal.mute),
        _cell(tr('物価'), c: Pal.mute),
        _cell(tr('市場'), c: Pal.mute),
        _cell(tr('最低賃金'), c: Pal.mute),
        _cell(tr('関税'), c: Pal.mute),
        _cell(tr('物流'), c: Pal.mute),
      ]),
      // はじめは市場の大きい4か国（選んでいる国まで）だけを出し、残りは「もっと見る」（1.1.0+31）
      ...firstOf(ctl, 'world-table', [
      for (final c in sorted)
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
              _cell(worldTariffCell(s, c.c)),
              _cell(worldRoadCell(s, c.c)),
            ]),
          ),
        ),
      ], math.max(4, sorted.indexWhere((c) => c.c == sel) + 1)),
    ]),
  );
  // 1.1.0+28 から、関税・物流・政治・伸びている業種・仕入れの網・視察を足した（world_screen.dart）
  // iPhone の横（幅約550）は、地図と国の中身の欄を短いほうの列へ詰めて2列にし、表はその下に全部の幅で置く（1.1.0+31）
  // 1.1.0+41 から、地図は幅いっぱいに置き、その下に国の中身（短いほうの列へ詰めて2列）と表
  if (width < 620 && width >= cols2Min) {
    return [band, map, Masonry2(worldDetailPanels(ctl, sel)), table];
  }
  final detail = worldDetail(ctl, sel);
  if (width >= 620) {
    return [
      band,
      map,
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 3, child: table),
        const SizedBox(width: 8),
        Expanded(flex: 2, child: detail),
      ]),
    ];
  }
  return [band, map, detail, table];
}

String _inMark(Game s, String c) => s.biz.any((b) => s.ctryOf(b).contains(c)) ? '★' : '';

