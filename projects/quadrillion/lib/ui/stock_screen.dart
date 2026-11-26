/// 株の画面（1.1.0+29。企画書「株の画面（決定）」）。横向きで3面:
/// - 自社の株: 株価のグラフと動いた理由・株主の割合と買い増しの注意・次の決算発表と株主総会の日付と要求（と大口の客）
/// - 他社の株と買収: 左に会社の一覧（話を進めている・子会社・持ち株・買える会社）、右に1社の中身（見えている数字の幅・調べの有無・
///   買う話の進み・統合の進みと離職の割合・のれん）
/// - 上場: 準備の進み（監査・社内の決まり）と費用・年数・主幹事・市場の地合い
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/game.dart';
import 'controller.dart';
import 'glossary.dart';
import 'look.dart';
import 'real_screens.dart' show histBack;
import 'sheets.dart';
import 'tabs.dart';
import 'widgets.dart';

/// 面（id・名前）
const stockSegs = [('own', '自社の株'), ('ma', '他社の株と買収'), ('ipo', '上場')];

/// 2列にする真ん中の最小の幅（人の画面と同じ）
const stockSplitMin = 520.0;

List<Widget> stockScreen(GameController ctl, {double width = 0}) {
  final s = ctl.game!;
  // 試作と同じ遊び（extras を切ったとき）は今までの1枚の画面
  if (!s.unitsOn) return [stockBand(ctl), ...stockTab(ctl)];
  final seg = ctl.stockSeg;
  return [
    stockBand(ctl),
    Segments('stock', [for (final e in stockSegs) (e.$1, tr(e.$2))], value: seg, onChanged: ctl.setStockSeg),
    const SizedBox(height: 6),
    ...switch (seg) {
      'ma' => _maFace(ctl, width),
      'ipo' => _ipoFace(ctl),
      _ => _ownFace(ctl, width),
    },
  ];
}

/// 株の画面の見出しの帯（1.1.0+41）：株価・時価総額・あなたの持ち分・上場か
Widget stockBand(GameController ctl) {
  final s = ctl.game!;
  return ScreenBand(
    key: const ValueKey('stock-band'),
    tone: ScreenTone.stock,
    icon: Icons.pie_chart,
    title: tr('株@@tab'),
    facts: [
      (tr('株価'), yen(s.sharePrice())),
      (tr('時価総額'), yen(s.cap)),
      (tr('あなたの持ち分'), pct(s.sh.own)),
      (tr('市場'), tr(s.listed ? '上場@@tag' : '未上場')),
    ],
  );
}

/// 株価の月ごとの記録の、[back] か月前の値（無ければ null）
double? _pxBack(Game s, int back) => s.corp.px.length > back ? s.corp.px[s.corp.px.length - 1 - back] : null;

/// 自社の株の要点のカード（1.1.0+41）
Widget _ownKpis(GameController ctl) {
  final s = ctl.game!;
  final t = s.turn;
  const tone = ScreenTone.stock;
  final now = s.sharePrice();
  final m1 = histBack(s, 1), y1 = histBack(s, 12);
  final mon = tr('前月'), yr = tr('前年');
  final riv = s.sh.rivMax;
  return KpiRow(key: const ValueKey('stock-kpis'), minW: 92, [
    KpiCard(key: const ValueKey('kpi-price'), label: tr('株価'), icon: Icons.candlestick_chart_outlined, value: now, fmt: yen, turn: t, tone: tone,
        delta: Delta.pct(now, _pxBack(s, 1), label: mon), delta2: Delta.pct(now, _pxBack(s, 12), label: yr), sub: s.listed ? null : tr('未上場なので見込み')),
    KpiCard(key: const ValueKey('kpi-stock-cap'), label: tr('時価総額'), icon: Icons.trending_up, value: s.cap, fmt: yen, turn: t, tone: tone,
        delta: Delta.pct(s.cap, m1?.cap, label: mon), delta2: Delta.pct(s.cap, y1?.cap, label: yr)),
    KpiCard(key: const ValueKey('kpi-own'), label: tr('あなたの持ち分'), icon: Icons.person_outline, value: s.sh.own, fmt: pct, turn: t, tone: tone,
        color: s.sh.own > 50 ? Pal.up : (s.sh.own < 33.4 ? Pal.down : Pal.ink),
        sub: riv > 0 ? tr('宿敵の持ち分 最大{0}', [pct(riv)]) : tr('宿敵は持っていない'), subColor: riv >= 5 ? Pal.down : null),
    KpiCard(key: const ValueKey('kpi-shares'), label: tr('株の数'), icon: Icons.numbers, value: s.corp.nSh, fmt: (v) => jsNum(jsRound(v)), turn: t, tone: tone,
        sub: tr('市場の地合い：{0}', [_mood(s)])),
  ]);
}

Widget _wrap(List<Widget> c) => Wrap(spacing: 6, runSpacing: 4, children: c);

// ===== 自社の株 =====
List<Widget> _ownFace(GameController ctl, double width) {
  // 見出しはその下のカードとひとまとまりにして、短いほうの列へ詰めて2列に並べる（1.1.0+31）
  final g = <Widget>[];
  Widget? h;
  for (final w in stockTab(ctl, cos: false)) {
    if (w is H2 || w is H2Info) {
      h = w;
      continue;
    }
    g.add(h == null ? w : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [h, w]));
    h = null;
  }
  // 株価・株主・上場の有無を先に、決算と株主総会の日付はいちばん後ろに置く（短い欄を最後にすると、左右の長さがそろう）
  return [
    _ownKpis(ctl),
    Masonry2([_pricePanel(ctl), ...g.take(2), ..._clientPanels(ctl), ...g.skip(2), _schedulePanel(ctl)], min: stockSplitMin)
  ];
}

Widget _pricePanel(GameController ctl) {
  final s = ctl.game!;
  final px = s.corp.px;
  final now = s.sharePrice();
  final ago = px.length >= 13 ? px[px.length - 13] : (px.isNotEmpty ? px.first : now);
  final ch = ago > 0 ? now / ago - 1 : 0.0;
  final shown = px.length > 60 ? px.sublist(px.length - 60) : px;
  // 株価の推移は目盛り・日付つきのグラフ（押すとその月の株価。1.1.0+41）
  return Panel(
    key: const ValueKey('price-panel'),
    padding: const EdgeInsets.fromLTRB(Ui.pad, 8, Ui.pad, 10),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // 今の株価・1年の動き・時価総額・株の数は上の要点のカードに出すので、ここは推移と理由（1.1.0+41）
      SectionHead(tr('株価の推移'), Icons.show_chart,
          tone: ScreenTone.stock,
          trailing: Text(tr('{0}（{1}）', [yen(now), '${tr('1年で')} ${ch >= 0 ? '+' : '−'}${pctD(ch.abs() * 100)}%']), key: const ValueKey('price-now'), style: ts(size: 13, bold: true, color: ch >= 0 ? Pal.up : Pal.down))),
      const SizedBox(height: 4),
      if (shown.length < 2)
        Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Muted(tr('月を進めると、ここに線が引かれます'), size: 12))
      else
        TrendChart(
          key: const ValueKey('price-chart'),
          height: 110,
          labels: [for (var i = 0; i < shown.length; i++) ymBack(s.year, s.q, shown.length - 1 - i)],
          fmt: yen,
          series: [TrendSeries(tr('株価'), ScreenTone.stock.c, shown)],
          summary: tr('株価のグラフ（{0}か月）。今は{1}。押すと、その月の株価が出ます', [shown.length, yen(now)]),
        ),
      const SizedBox(height: 6),
      Text(tr('先月から動いた理由'), style: ts(size: 12.5, bold: true)),
      if (s.corp.why.isEmpty) Muted(tr('大きな動きはありませんでした'), size: 12),
      for (final w in s.corp.why)
        Padding(padding: const EdgeInsets.only(top: 2), child: Text('${L.en ? '• ' : '・'}${tx(w)}', style: ts(size: 12.5))),
      const SizedBox(height: 4),
      Muted(tr('株価は利益・売上の伸び・金利・市場の地合い・うわさで決まります。市場の地合い：{0}', [_mood(s)]), size: 11.5),
    ]),
  );
}

String _mood(Game s) => tr(s.perMul >= 1.15
    ? '良い'
    : s.perMul <= .85
        ? '悪い'
        : 'ふつう@@mood');

Widget _schedulePanel(GameController ctl) {
  final s = ctl.game!;
  final rows = <Widget>[];
  if (s.listed) {
    rows.add(Kv(tr('次の決算発表'), tr('{0}年{1}月', [s.nextEarnYear(), s.nextEarnMonth()])));
    rows.add(Kv(tr('次の株主総会'), tr('{0}年{1}月', [s.nextAgmYear(), 6])));
    rows.add(Kv(tr('前の決算（3か月の利益）'), s.corp.lastQ == 0 ? tr('まだありません') : yen(s.corp.lastQ)));
    rows.add(Kv(tr('上場を続ける費用'), tr('毎月{0}', [yen(s.listCost())])));
  }
  final act = s.activist();
  // 買い増しの注意（5%を超えると報告が出る。宿敵の持ち分）
  final warn = <Widget>[
    for (final e in s.sh.riv.entries)
      if (e.value > 0)
        Text(
          tr(e.value >= 5 ? '{0}が{1}を持っています（5%を超え、報告が出ました）' : '{0}が{1}を持っています（5%を超えると報告が出ます）', [nmL(s.coById(e.key)?.name ?? '?'), pct(e.value)]),
          style: ts(size: 12.5, color: e.value >= 5 ? Pal.down : Pal.ink),
        ),
  ];
  return Panel(
    key: const ValueKey('schedule-panel'),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHead(tr('決算と株主総会'), Icons.event_outlined, tone: ScreenTone.stock),
      if (!s.listed) Muted(tr('上場すると、3か月ごとに決算を発表し、毎年6月に株主総会を開きます'), size: 12),
      ...rows,
      if (s.listed)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            act ? tr('物言う株主がいます。総会で、貯めこんだ現金を株主に返すよう求めてきそうです') : tr('総会で大きな要求は出ていません'),
            style: ts(size: 12.5, color: act ? Pal.warn : Pal.mute),
          ),
        ),
      if (warn.isNotEmpty) ...[const SizedBox(height: 6), Text(tr('買い増しの注意'), style: ts(size: 12.5, bold: true)), ...warn],
    ]),
  );
}

List<Widget> _clientPanels(GameController ctl) {
  final s = ctl.game!;
  final l = [for (final b in s.biz) if (s.corp.clients[b.id] != null) (b, s.corp.clients[b.id]!)];
  if (l.isEmpty) return const [];
  return [
    Panel(
      key: const ValueKey('client-panel'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionHead(tr('取引先（大口の客）'), Icons.storefront_outlined, tone: ScreenTone.stock),
        Muted(tr('大口の客に頼りすぎると、取引を切られたり、客が倒れて売掛金が戻らないことがあります'), size: 12),
        for (final (b, c) in l)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(children: [
              Expanded(
                child: Text(
                  tr('{0}：{1}が売上の{2}', [indm[b.ind]!.name, c.co == 0 ? tr('役所') : nmL(s.coById(c.co)?.name ?? '?'), pct(c.share * 100)]),
                  style: ts(size: 12.5, color: c.share >= .4 ? Pal.down : Pal.ink),
                ),
              ),
              if (c.share > .1)
                apBtnOf(ctl, tr('客を広げる（{0}）', [yen(s.spreadCost(b))]), () => ctl.act(() => s.spreadClients(b)), k: 'deal'),
            ]),
          ),
      ]),
    ),
  ];
}

/// 株価の線（古い順。いちばん新しい点に印）
class PricePainter extends CustomPainter {
  final List<double> v;
  PricePainter(this.v);
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = Pal.panel2;
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(6)), bg);
    if (v.length < 2) return;
    final lo = v.reduce(math.min), hi = v.reduce(math.max);
    final span = hi - lo <= 0 ? math.max(1.0, hi.abs()) : hi - lo;
    double yy(double x) => size.height - 6 - (x - lo) / span * (size.height - 12);
    double xx(int i) => 4 + i * (size.width - 8) / (v.length - 1);
    final path = Path()..moveTo(xx(0), yy(v[0]));
    for (var i = 1; i < v.length; i++) {
      path.lineTo(xx(i), yy(v[i]));
    }
    final up = v.last >= v.first;
    canvas.drawPath(
        path,
        Paint()
          ..color = up ? Pal.up : Pal.down
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke);
    canvas.drawCircle(Offset(xx(v.length - 1), yy(v.last)), 3.5, Paint()..color = Pal.gold);
  }

  @override
  bool shouldRepaint(covariant PricePainter o) => o.v.length != v.length || (v.isNotEmpty && o.v.last != v.last);
}

// ===== 他社の株と買収 =====
List<Company> _maList(Game s, String grp) {
  final myInd = <String>{for (final b in s.biz) b.ind};
  int inMine(Company c) => c.biz.any((x) => myInd.contains(x.ind)) ? 1 : 0;
  return switch (grp) {
    'deal' => [for (final d in s.corp.deals) ?s.coById(d.co)],
    'sub' => s.subs(),
    'held' => s.cos.where((c) => c.alive && s.pctOf(c) > 0 && c.parent != 'player').toList(),
    _ => (s.cos.where((c) => c.alive && s.pctOf(c) == 0 && c.parent != 'player' && s.dealOf(c) == null).toList()
          ..ssort((a, b) {
            final d = inMine(b) - inMine(a);
            if (d != 0) return d;
            final r = (b.rival != null ? 1 : 0) - (a.rival != null ? 1 : 0);
            return r != 0 ? r : a.cap.compareTo(b.cap);
          }))
        .take(14)
        .toList(),
  };
}

const _maGroups = [('deal', '話を進めている'), ('sub', '子会社・現地法人'), ('held', '持っている他社の株'), ('buy', '買える会社')];

List<Widget> _maFace(GameController ctl, double width) {
  final s = ctl.game!;
  final all = <Company>[];
  final left = <Widget>[];
  for (final g in _maGroups) {
    final l = _maList(s, g.$1);
    if (l.isEmpty) continue;
    left.add(Padding(padding: const EdgeInsets.fromLTRB(2, 6, 0, 3), child: Text(tr(g.$2), style: ts(size: 12.5, bold: true, color: Pal.mute))));
    for (final c in l) {
      all.add(c);
      left.add(_coRow(ctl, c));
    }
  }
  if (left.isEmpty) left.add(Panel(child: Muted(tr('買える会社がありません'))));
  final sel = all.where((c) => c.id == ctl.openCo).firstOrNull ?? all.firstOrNull;
  final right = sel == null ? <Widget>[] : [_dealPanel(ctl, sel), coCardOf(ctl, sel)];
  if (width < stockSplitMin) return [...left, ...right];
  final lw = clampD(width * .34, 180, 280);
  return [
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: lw, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: left)),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: right)),
    ]),
  ];
}

/// 会社の状態の札（調べ中・審査中・統合の進み・調べ済み・苦しい）
String? _coStatus(Game s, Company c) {
  final d = s.dealOf(c);
  if (d != null) {
    return tr(switch (d.stage) {
      'dd' => '調べ中（あと{0}か月）',
      'offer' => '返事待ち',
      'review' => '審査中（あと{0}か月）',
      _ => '手続き中',
    }, [d.left]);
  }
  final f = c.fin;
  if (c.parent == 'player' && f != null && f.integ > 0) return tr('統合 {0}', [pct0Of(1 - f.integ / math.max(1, f.integAll))]);
  if (f != null && f.distress >= 3) return tr('資金繰りが苦しい');
  if (f != null && f.dd > 0 && c.parent != 'player') return tr('調べ済み');
  return null;
}

Widget _coRow(GameController ctl, Company c) {
  final s = ctl.game!;
  final on = c.id == (ctl.openCo ?? -1);
  final st = _coStatus(s, c);
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: TapCard(
      border: on ? Pal.gold : Pal.line,
      color: on ? Pal.onBg : Pal.panel,
      inkKey: ValueKey('co-row-${c.id}'),
      onTap: () => ctl.selectCo(c.id),
      child: Container(
        constraints: const BoxConstraints(minHeight: minTap),
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
        child: Row(children: [
          // 宿敵は顔、ほかの会社はいちばん大きい業種の絵（1.1.0+41）
          if (c.rival != null)
            ...[rivalFace(s, c), const SizedBox(width: 4)]
          else if (c.biz.isNotEmpty && indm[c.biz.first.ind] != null)
            ...[IndIcon(indm[c.biz.first.ind]!, size: 28), const SizedBox(width: 6)],
          // 名前を1行目に広く取り、時価総額と状態（調べ中・審査中・統合の進み）は2行目に並べる（札を右に置くと、狭い列で名前が切れた）
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(nmL(c.name), maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(size: 13, bold: true)),
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: c.listed ? yen(c.cap) : seenText(s, c, c.cap, 0), style: ts(size: 11.5, color: Pal.mute)),
                  if (st != null)
                    TextSpan(text: '  $st', style: ts(size: 11.5, bold: true, color: st == tr('資金繰りが苦しい') ? Pal.down : Pal.up)),
                ]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ]),
          ),
        ]),
      ),
    ),
  );
}

Widget _dealPanel(GameController ctl, Company c) {
  final s = ctl.game!;
  final f = s.finOf(c);
  final d = s.dealOf(c);
  final mine = c.parent == 'player';
  const tone = ScreenTone.stock;
  final own = s.pctOf(c);
  final kids = <Widget>[
    // 名前の行（宿敵は顔、ほかは業種の絵）と、見えている数字の確かさ
    Row(children: [
      if (c.rival != null)
        Padding(padding: const EdgeInsets.only(right: 8), child: rivalFace(s, c, size: 38))
      else if (c.biz.isNotEmpty && indm[c.biz.first.ind] != null)
        Padding(padding: const EdgeInsets.only(right: 8), child: IndIcon(indm[c.biz.first.ind]!, size: 34)),
      Expanded(child: Semantics(header: true, child: Text(nmL(c.name), style: ts(size: 15, bold: true)))),
      Flexible(child: Text(tr(f.dd > 0 || mine ? '調べ済み' : c.listed ? '決算で見える幅' : '未上場（幅が広い）'), textAlign: TextAlign.right, style: ts(size: 12, color: Pal.mute))),
    ]),
    const SizedBox(height: 6),
    // 時価総額・あなたの持ち分・月の利益は要点のカード（1.1.0+41）
    KpiRow(minW: 88, [
      KpiCard(key: ValueKey('kpi-co-cap-${c.id}'), label: tr('時価総額'), icon: Icons.trending_up, value: c.cap, fmt: (v) => c.listed ? yen(v) : seenText(s, c, v, 0), turn: s.turn, tone: tone),
      KpiCard(key: ValueKey('kpi-co-own-${c.id}'), label: tr('あなたの持ち分'), icon: Icons.pie_chart_outline, value: own, fmt: pct, turn: s.turn, tone: tone,
          color: own > 50 ? Pal.up : Pal.ink, sub: own >= 66.7 ? tr('合併も自由') : own > 50 ? tr('子会社') : own >= 33.4 ? tr('合併を止められる') : null),
      KpiCard(key: ValueKey('kpi-co-pro-${c.id}'), label: tr('月の利益'), icon: Icons.savings_outlined, value: c.profit, fmt: (v) => seenText(s, c, v, 1), turn: s.turn, tone: tone,
          color: c.profit >= 0 ? Pal.ink : Pal.down),
    ]),
    Grid2([
      Kv(tr('月の売上'), seenText(s, c, c.rev, 2)),
      Kv(tr('借金'), seenText(s, c, s.coDebt(c), 3)),
      Kv(tr('店などの数'), _seenCount(s, c)),
    ]),
    const SizedBox(height: 4),
    if (f.dd > 0 || mine)
      Text(_issues(s, c), style: ts(size: 12.5, color: f.offDebt + f.suit + f.flight > 0 ? Pal.down : Pal.up))
    else
      Muted(tr('調べないと分からないこと：帳簿に載っていない借金・訴訟・買われると辞める人'), size: 12),
  ];
  if (mine && f.integAll > 0) {
    kids.add(const SizedBox(height: 6));
    kids.add(Text(
        f.integ > 0
            ? tr('統合の進み {0}（あと{1}か月）・辞めた人 {2}', [pct0Of(1 - f.integ / math.max(1, f.integAll)), f.integ, pct(f.attr * 100)])
            : tr('統合は終わりました（辞めた人 {0}）', [pct(f.attr * 100)]),
        key: ValueKey('integ-${c.id}'),
        style: ts(size: 12.5)));
    if (f.gw > 0 || f.impaired > 0) kids.add(Text(tr('のれん {0}・減損した額 {1}', [yen(f.gw), yen(f.impaired)]), style: ts(size: 12.5, color: Pal.mute)));
  }
  if (d != null) {
    kids.add(const SizedBox(height: 6));
    kids.add(Text(
        tr(switch (d.stage) {
          'dd' => '調べています（あと{0}か月）。終われば隠れた問題が分かり、申し入れに進みます',
          'offer' => '買い付けを申し入れ、相手の株主の返事を待っています',
          'review' => '当局の審査中です（あと{0}か月）。止められる見込み {1}',
          _ => '手続き中です。来月、株を受け取ります',
        }, [d.left, pct0Of(d.block)]),
        key: ValueKey('deal-stage-${c.id}'),
        style: ts(size: 12.5, bold: true)));
    // 1.1.0+30 から、何%分の値段かを添える（過半を買う値段が時価総額より安く見え、計算違いに見えていた）
    kids.add(Text(
        tr('株{0}を買う値段 {1}（時価に上乗せ {2}）・これまでの費用 {3}', [pct(math.max(0, d.target - s.pctOf(c))), yen(s.dealPrice(c, d)), pct(d.prem * 100), yen(d.spent)]),
        key: ValueKey('deal-price-${c.id}'),
        style: ts(size: 12, color: Pal.mute)));
    kids.add(Padding(padding: const EdgeInsets.only(top: 4), child: Btn(tr('話をやめる'), () => ctl.act(() => s.maCancel(c)), small: true)));
  } else if (!mine || s.pctOf(c) < 50.1) {
    final t = MaDeal(co: c.id, stage: 'offer', left: 1);
    final rv = s.reviewOf(c);
    kids.add(const SizedBox(height: 6));
    kids.add(Text(
        rv.$1 > 1
            ? tr('合わせたシェア {0}。当局の審査に約{1}か月、止められる見込み {2}', [pct(s.myMergedShare(c) * 100), rv.$1, pct0Of(rv.$2)])
            : tr('合わせても市場の大きな割合にはならず、審査はすぐ済みます'),
        style: ts(size: 12, color: rv.$2 > 0 ? Pal.warn : Pal.mute)));
    kids.add(const SizedBox(height: 4));
    kids.add(_wrap([
      if (f.dd == 0)
        apBtnOf(ctl, tr('調べる（{0}か月・{1}）', [s.ddMonths(c), yen(s.ddCost(c))]), () => ctl.act(() => s.maStart(c)), k: 'merge', primary: true),
      apBtnOf(ctl, tr(f.dd == 0 ? '調べずに株{2}を買い付ける（{0}・応じる見込み{1}）' : '株{2}の買い付けを申し入れる（{0}・応じる見込み{1}）', [yen(s.dealPrice(c, t)), pct0Of(s.dealChance(c, t)), pct(math.max(0, t.target - s.pctOf(c)))]),
          () => ctl.act(() => s.maStart(c, dd: false)),
          k: 'tob'),
      if (s.listed && c.cap <= s.cap && c.loc == null)
        apBtnOf(ctl, tr('株式交換で丸ごと買う（応じる見込み{0}）', [pct0Of(s.dealChance(c, MaDeal(co: c.id, stage: 'offer', left: 1, target: 100)))]),
            () => ctl.act(() => s.maStart(c, dd: false, target: 100, pay: 'swap')),
            k: 'tob'),
    ]));
    kids.add(Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Muted(tr('買う値段は、過半（50.1%）を持つまでの株の分だけで、今の株価に3割ほど上乗せします（会社を丸ごと買う値段ではありません）。調べずに買うと、隠れた問題が買ったあとに出ます'), size: 11.5)));
  }
  return Panel(key: ValueKey('deal-${c.id}'), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: kids));
}

String _seenCount(Game s, Company c) {
  final n = s.coUnits(c);
  if (c.parent == 'player' || s.infoWidth(c) <= .03) return jsNum(jsRound(n));
  final r = s.seenRange(c, n, 4);
  return tr('{0}〜{1}', [jsNum(jsRound(r.$1)), jsNum(jsRound(r.$2))]);
}

String _issues(Game s, Company c) {
  final f = s.finOf(c);
  final l = <String>[
    if (f.offDebt > 0) tr('帳簿に載っていない借金 {0}', [yen(c.cap * f.offDebt)]),
    if (f.suit > 0) tr('抱えている訴訟 {0}', [yen(c.cap * f.suit)]),
    if (f.flight > 0) tr('買われると辞めそうな人が多い'),
  ];
  return l.isEmpty ? tr('隠れた問題は見つかっていません') : tr('見つかったこと：{0}', [l.join(tr('・'))]);
}

// ===== 上場 =====
List<Widget> _ipoFace(GameController ctl) {
  final s = ctl.game!;
  if (s.listed) {
    return [
      Panel(
        key: const ValueKey('ipo-listed'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SectionHead(tr('上場済み'), Icons.verified_outlined, tone: ScreenTone.stock),
          Muted(tr('3か月ごとに決算を発表し、開示の義務があります。毎月の費用 {0}', [yen(s.listCost())]), size: 12.5),
          Kv(tr('次の決算発表'), tr('{0}年{1}月', [s.nextEarnYear(), s.nextEarnMonth()])),
          Kv(tr('市場の地合い'), _mood(s)),
        ]),
      ),
    ];
  }
  final p = s.corp.ipo;
  final cpa = s.staff.any((x) => x.lic.contains('cpa')), law = s.staff.any((x) => x.lic.contains('lawyer'));
  final who = Panel(
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHead(tr('準備に効く人'), Icons.badge_outlined, tone: ScreenTone.stock),
      Kv(tr('会計士'), tr(cpa ? 'いる（6か月早い・調べも安い）' : 'いない')),
      Kv(tr('弁護士'), tr(law ? 'いる（3か月早い）' : 'いない')),
      Muted(tr('会計士・弁護士は「人」の画面の採用で、資格を持つ人を雇えます'), size: 11.5),
    ]),
  );
  if (p == null) {
    final m = s.ipoMonths();
    return [
      Panel(
        key: const ValueKey('ipo-plan'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SectionHead(tr('上場の準備'), Icons.flag_outlined, tone: ScreenTone.stock),
          Muted(tr('上場するには、監査法人の監査を2期分（24か月）受け、社内の決まり（内部統制）を整え、主幹事の証券会社を選びます。'), size: 12.5),
          const SizedBox(height: 4),
          Kv(tr('かかる年数'), tr('約{0}か月（{1}年）', [m, pctD(m / 12)])),
          Kv(tr('準備の費用'), tr('毎月{0}（合わせて約{1}）', [yen(s.ipoMonthCost()), yen(s.ipoMonthCost() * m)])),
          Kv(tr('市場の地合い'), _mood(s)),
          const SizedBox(height: 6),
          apBtnOf(ctl, tr('上場の準備を始める'), () => ctl.act(s.ipoPrepStart), k: 'ipo', enabled: s.canIpoPrep(), primary: true),
          if (!s.canIpoPrep()) Muted(tr('事業があり、1年の利益が出ていると始められます'), size: 11.5),
        ]),
      ),
      who,
    ];
  }
  return [
    Panel(
      key: const ValueKey('ipo-prep'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionHead(tr('上場の準備の進み'), Icons.timelapse, tone: ScreenTone.stock),
        _bar(tr('準備 {0}/{1}か月', [p.done, p.total]), p.done / math.max(1, p.total)),
        _bar(tr('監査 {0}/24か月', [math.min(24, p.audit)]), math.min(1, p.audit / 24)),
        _bar(tr('社内の決まり {0}', [pct0Of(p.ctrl)]), p.ctrl),
        Kv(tr('これまでの費用'), yen(p.spent)),
        Kv(tr('毎月の費用'), yen(s.ipoMonthCost())),
        Kv(tr('市場の地合い'), _mood(s)),
      ]),
    ),
    Panel(
      key: const ValueKey('ipo-uw'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionHead(tr('主幹事'), Icons.account_balance_outlined, tone: ScreenTone.stock),
        _wrap([
          for (final k in const ['big', 'mid', 'small'])
            PickChip(
              tr('{0}（手数料{1}）', [tr(const {'big': '大手', 'mid': '中堅', 'small': '小さな証券会社'}[k]!), pct(GameCorp.uwTerms[k]!.$1 * 100)]),
              key: ValueKey('uw-$k'),
              on: p.uw == k,
              onTap: () => ctl.act(() => s.chooseUw(k)),
            ),
        ]),
        const SizedBox(height: 4),
        Muted(tr('大手ほど高い値が付くが、大きな会社でないと引き受けてくれません'), size: 11.5),
        Kv(tr('集まる見込み'), yen(s.ipoRaise())),
        Kv(tr('手数料と上場の費用'), yen(s.ipoFee())),
        const SizedBox(height: 6),
        _wrap([
          apBtnOf(ctl, tr('上場する'), () => ctl.act(s.ipoList), k: 'offer', enabled: s.ipoReady(), primary: true),
          Btn(tr('準備をやめる'), () => ctl.act(s.ipoPrepStop), small: true),
        ]),
        if (s.ipoReady() && s.perMul < .9) Muted(tr('市場の地合いが悪く、安い値しか付きません。待つこともできます'), size: 11.5),
      ]),
    ),
    who,
  ];
}

Widget _bar(String label, double v) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(label, style: ts(size: 12.5)),
        const SizedBox(height: 2),
        Bar([(clampD(v, 0, 1) * 100, Pal.gold)], height: 8),
      ]),
    );
