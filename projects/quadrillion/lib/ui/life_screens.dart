/// 段6（1.1.0+30）の画面: 社長の経歴・私生活・世間の顔（人の画面の社長）、税と保険・IT・特許（お金の画面の税金）、
/// 図鑑の業種の中身（37の特性と市場の大きさの推移）と歴史（その遊びの年表）
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/game.dart';
import 'controller.dart';
import 'widgets.dart';

String _p0(double v) => '${jsNum(jsRound(v * 100))}%';
String _yr(double v) => tr('{0}年', [jsNum((v * 10).round() / 10)]);
String _lv(double v) => v >= .67
    ? tr('高い')
    : v >= .34
        ? tr('ふつう@@lv')
        : tr('低い');

// ===== 社長 =====
/// 人の画面で社長を選んだときに足す欄（始め方と経歴・細かい能力・私生活・世間の顔）
List<Widget> presLifePanels(GameController ctl) {
  final s = ctl.game!;
  if (!s.lifeOn) return const [];
  final l = s.life, bio = l.bio;
  return [
    Panel(
      key: const ValueKey('pres-bio'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CardTitle(tr('経歴')),
        const SizedBox(height: 4),
        Grid2([
          Kv(tr('始め方'), switch (l.start) {
            'work' => tr('会社員を{0}年してから', [l.workYears]),
            'succ' => tr('先代から継いだ（{0}代目）', [s.gen]),
            _ => tr('大学を出てすぐ'),
          }),
          if (bio != null) Kv(tr('学歴'), bio.major != null ? tr('{0}・{1}', [de(EDU_JA[bio.edu]), de(MAJOR_JA[bio.major]!)]) : de(EDU_JA[bio.edu])),
          if (l.workCat != null) Kv(tr('前職'), tr('{0}の大きな会社で{1}年', [CATN[l.workCat!]!, l.workYears])),
          Kv(tr('人脈'), '${s.net}'),
        ]),
        if (bio?.sk != null) ...[
          const SizedBox(height: 6),
          for (final g in SK_GROUPS)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text.rich(TextSpan(style: ts(size: 12), children: [
                TextSpan(text: '${de(g.$1)}　', style: ts(size: 12, color: Pal.mute)),
                TextSpan(text: g.$2.map((k) => '${de(SK_JA[k]!)} ${bio!.sk![k]}').join(tr('・'))),
              ])),
            ),
        ],
        const SizedBox(height: 4),
        Muted(tr('勤めた業界と同じ分類の事業を自分で見ると、経験が効いて事業の力が上がります。'), size: 11.5),
      ]),
    ),
    Panel(
      key: const ValueKey('pres-private'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CardTitle(tr('私生活')),
        const SizedBox(height: 4),
        Grid2([
          Kv(tr('家族'), l.married ? tr('結婚・子ども{0}人', [s.kids.length]) : tr('独身・子ども{0}人', [s.kids.length])),
          Kv(tr('個人の財産'), yen(s.wealth)),
          Kv(tr('個人保証'), l.guarantee ? tr('あり（会社の借金）') : tr('なし')),
          Kv(tr('相続税（最高）'), '${jsNum(jsRound(inheritRate(s.home, s.yr()) * 100))}%'),
        ]),
        const SizedBox(height: 4),
        Muted(tr('個人保証があると、会社が倒れたときに社長の財産も失います（上場するか借金が無くなると外れます）。子どもが継ぐと、持ち株に相続税がかかり、払うために株の一部を手放します。'), size: 11.5),
      ]),
    ),
    Panel(
      key: const ValueKey('pres-public'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CardTitle(tr('世間の顔')),
        const SizedBox(height: 4),
        Grid2([
          Kv(tr('評判'), '${l.fame.round()}'),
          Kv(tr('ブランド'), '${l.brand.round()}'),
          Kv(tr('業界団体の役職'), s.turn < l.assocUntil ? tr('あと{0}か月', [l.assocUntil - s.turn]) : tr('なし')),
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 4, children: [
          Btn(tr('業界団体の役職に就く'), () => ctl.act(s.takeIndustryPost), key: const ValueKey('pres-assoc'), small: true, ap: s.hrs('assoc').round(), enabled: s.turn >= l.assocUntil),
          Btn(tr('取材・講演'), () => ctl.act(s.giveTalk), key: const ValueKey('pres-talk'), small: true, ap: s.hrs('media').round()),
          Btn(tr('寄付 {0}', [yen(s.donateCost())]), () => ctl.act(s.donate), key: const ValueKey('pres-donate'), small: true, ap: s.hrs('donate').round()),
        ]),
        const SizedBox(height: 4),
        Muted(tr('名前が知られるほど人脈とブランドが育ちますが、時間を取られ、失言すると会社の評判ごと落ちます。'), size: 11.5),
      ]),
    ),
  ];
}

// ===== お金の画面の「税金」に足す欄 =====
List<Widget> taxLifePanels(GameController ctl) {
  final s = ctl.game!;
  if (!s.lifeOn) return const [];
  final l = s.life;
  final avail = s.itAvail();
  return [
    Panel(
      key: const ValueKey('money-tax-more'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CardTitle(tr('減価償却と消費税')),
        const SizedBox(height: 4),
        Grid2([
          Kv(tr('今月の減価償却'), yen(s.depMonth())),
          Kv(tr('消費税'), s.home == 'jp' ? '${jsNum(s.consumptionTax())}%' : tr('前からある（動きなし）')),
        ]),
        const SizedBox(height: 4),
        Muted(tr('店や工場に使ったお金は、耐用年数に分けて毎月の利益から引いてから税をかけます（減価償却）。消費税が上がると、しばらく一般の客の買い控えが起きます。'), size: 11.5),
      ]),
    ),
    Panel(
      key: const ValueKey('money-insure'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CardTitle(tr('災害と保険')),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(child: Text(l.insured ? tr('保険をかけている') : tr('保険をかけていない'), style: ts(size: 13, bold: true))),
          Btn(l.insured ? tr('保険をやめる') : tr('保険をかける'), () => ctl.act(() => s.setInsured(!l.insured)), key: const ValueKey('money-insure-btn'), small: true),
        ]),
        Muted(tr('保険料は毎月の経費に入ります。かけていれば、地震や台風で傷んだ店や工場の修理の8割が戻ります。'), size: 11.5),
      ]),
    ),
    Panel(
      key: const ValueKey('money-it'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CardTitle(tr('時代のIT')),
        const SizedBox(height: 4),
        for (var i = 0; i < itEras.length; i++)
          if (s.yr() >= itEras[i].$1)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(children: [
                Icon(l.it > i ? Icons.check_circle : Icons.radio_button_unchecked, size: 15, color: l.it > i ? Pal.goldtx : Pal.mute),
                const SizedBox(width: 6),
                Expanded(child: Text(tr('{0}（{1}年〜）', [de(itEras[i].$2), itEras[i].$1]), style: ts(size: 12.5))),
              ]),
            ),
        if (s.itBehind() > 0) Muted(tr('当たり前になったITを入れていないので、利益率が{0}落ちています', ['${s.itBehind()}%']), size: 11.5),
        const SizedBox(height: 4),
        if (avail > l.it)
          Align(
            alignment: Alignment.centerLeft,
            child: Btn(tr('「{0}」を入れる {1}', [de(itEras[avail - 1].$2), yen(s.itCost())]), () => ctl.act(s.adoptIT), key: const ValueKey('money-it-btn'), small: true, ap: s.hrs('it').round()),
          ),
        Muted(tr('宣伝の手段も時代で変わります。今よく効くのは「{0}」です。', [de(adMediaOf(s.yr()))]), size: 11.5),
      ]),
    ),
    if (l.patents.isNotEmpty)
      Panel(
        key: const ValueKey('money-patents'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          CardTitle(tr('特許')),
          for (final p in l.patents)
            Row(children: [
              Expanded(child: Text(tx(M('{0}（{1}年まで）', [I(p.ind), s.startYear + p.until ~/ 12])), style: ts(size: 12.5))),
              Btn(p.lic ? tr('使わせるのをやめる') : tr('他社に使わせる'), () => ctl.act(() => s.licensePatent(p)), small: true),
            ]),
          Muted(tr('特許があると真似されず、事業の力が上がります。他社に使わせると、毎月の使用料が入ります。'), size: 11.5),
        ]),
      ),
  ];
}

// ===== 図鑑 =====
/// 業種の37の特性（分野ごとの名前と値）
List<(String, List<(String, String)>)> traitRows(Industry i) {
  final p = profileOf(i);
  String yn(bool b) => b ? tr('はい') : tr('いいえ');
  return [
    (tr('稼ぎの形'), [
      (tr('稼ぎの型'), p.kindName),
      (tr('利益率の相場'), _p0(p.mg)),
      (tr('固定費の重さ'), _lv(p.fixed)),
      (tr('規模の効き方'), _lv(p.scale)),
      (tr('客の種類'), de(CUST_JA[p.cust]!)),
    ]),
    (tr('お金の入り方'), [
      (tr('代金をもらうまで'), tr('{0}か月', [jsNum((p.payLag * 10).round() / 10)])),
      (tr('定期収入の割合'), _p0(p.recur)),
      (tr('解約のしやすさ'), tr('月{0}', [_p0(p.churn)])),
      (tr('値上げのしやすさ'), _lv(p.pricing)),
    ]),
    (tr('作る・運ぶ'), [
      (tr('主な原価'), de(COST_JA[p.costKey] ?? p.costKey)),
      (tr('開発の長さ'), tr('{0}か月', [jsRound(p.devMonths)])),
      (tr('開発の成功率'), _p0(p.devHit)),
      (tr('設備の寿命'), _yr(p.life)),
      (tr('運びやすさ'), _lv(p.ship)),
      (tr('原料を外国に頼る割合'), _p0(p.imported)),
      (tr('在庫'), de(INV_JA[p.inv]!)),
      (tr('技術の寿命'), _yr(p.techLife)),
    ]),
    (tr('時と外の力'), [
      (tr('季節の波'), _lv(p.season)),
      (tr('天候の影響'), _lv(p.weather)),
      (tr('景気への弱さ'), _lv(p.sens)),
      (tr('為替の向き'), p.fx > 0 ? tr('円安で得') : p.fx < 0 ? tr('円安で損') : tr('どちらでもない')),
      (tr('金利への弱さ'), _lv(p.rateSens)),
      (tr('ブームのなりやすさ'), _lv(p.boom)),
    ]),
    (tr('人@@trait'), [
      (tr('要る人材'), de(ABN[p.talent] ?? p.talent)),
      (tr('熟練に要る年数'), _yr(p.skillYears)),
      (tr('辞めやすさ'), _lv(p.quit)),
      (tr('24時間・夜の仕事'), yn(p.night)),
    ]),
    (tr('社会と規制'), [
      (tr('入りにくさ'), _lv(p.barrier)),
      (tr('公共事業への頼り具合'), _lv(p.publicDep)),
      (tr('環境の規制'), _lv(p.env)),
      (tr('個人情報'), _lv(p.privacy)),
      (tr('事故と訴訟'), _lv(p.liability)),
      (tr('国が値段を決める'), yn(p.priceReg)),
      (tr('評判の悪い業種'), yn(p.stigma)),
    ]),
    (tr('市場の形'), [
      (tr('業界の集まり方'), p.conc >= .5 ? tr('寡占') : tr('乱立')),
      (tr('下請けの構造'), yn(p.subcon)),
      (tr('開くまで'), tr('{0}〜{1}か月', [p.open.$1, p.open.$2])),
    ]),
  ];
}

/// 業種の市場の大きさ（1年分・その年の円）の推移。統計の業種の推移と、社会の移り変わりを入れる
List<(int, double)> marketSeries(Game s, Industry i) {
  final out = <(int, double)>[];
  for (var y = s.startYear; y <= s.startYear + 60; y += 2) {
    final v = i.size / 4 * eraF(i, y.toDouble()) * nomOf(y.toDouble()) * socialF(i, y.toDouble()) * 12;
    out.add((y, v));
  }
  return out;
}

/// 図鑑の業種の中身（37の特性と市場の大きさの推移）
void openIndDetail(GameController ctl, Industry i) {
  final s = ctl.game!;
  ctl.showSheet((_) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        H2(i.name, top: true),
        Muted(tr('{0}・{1}年生まれ・頂点 {2}年・特性{3}', [CATN[i.cat]!, i.b, i.p, IndProfile.count]), size: 12),
        const SizedBox(height: 8),
        Text(tr('市場の大きさの推移（1年・その年の円）'), style: ts(size: 12.5, bold: true)),
        SizedBox(height: 120, child: CustomPaint(key: const ValueKey('ind-market-chart'), painter: _MarketPainter(marketSeries(s, i), s.year), size: Size.infinite)),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth >= 640 ? 2 : 1;
          final w = (c.maxWidth - 10 * (cols - 1)) / cols;
          return Wrap(spacing: 10, runSpacing: 8, children: [
            for (final g in traitRows(i))
              SizedBox(
                width: w,
                child: Panel(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(g.$1, style: ts(size: 12.5, bold: true, color: Pal.goldtx)),
                    for (final r in g.$2) Kv(r.$1, r.$2),
                  ]),
                ),
              ),
          ]);
        }),
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerLeft, child: Btn(tr('閉じる'), ctl.closeSheet, small: true)),
      ]));
}

class _MarketPainter extends CustomPainter {
  final List<(int, double)> d;
  final int now;
  _MarketPainter(this.d, this.now);
  @override
  void paint(Canvas canvas, Size size) {
    if (d.isEmpty) return;
    final hi = d.map((e) => e.$2).reduce(math.max);
    if (hi <= 0) return;
    final x0 = d.first.$1.toDouble(), x1 = d.last.$1.toDouble();
    double px(double y) => 44 + (y - x0) / (x1 - x0) * (size.width - 52);
    double py(double v) => size.height - 16 - v / hi * (size.height - 26);
    final axis = Paint()
      ..color = Pal.line
      ..strokeWidth = 1;
    canvas.drawLine(Offset(44, size.height - 16), Offset(size.width - 8, size.height - 16), axis);
    final path = Path();
    for (var k = 0; k < d.length; k++) {
      final o = Offset(px(d[k].$1.toDouble()), py(d[k].$2));
      k == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = Pal.goldtx
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke);
    final nx = px(now.toDouble().clamp(x0, x1));
    canvas.drawLine(Offset(nx, 6), Offset(nx, size.height - 16), axis);
    void text(String t, Offset o) {
      final tp = TextPainter(text: TextSpan(text: t, style: TextStyle(fontSize: 10, color: Pal.mute, fontFamily: fontFamily)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, o);
    }

    text(yen(hi), const Offset(0, 2));
    text('${d.first.$1}', Offset(px(x0) - 10, size.height - 13));
    text('${d.last.$1}', Offset(px(x1) - 24, size.height - 13));
    text(tr('今'), Offset(nx - 6, size.height - 13));
  }

  @override
  bool shouldRepaint(covariant _MarketPainter old) => old.d != d;
}

/// 図鑑の「歴史」：その遊びで起きた大きな出来事の年表（社史の記録を年ごとに）
List<Widget> zukanHist(GameController ctl) {
  final s = ctl.game!;
  final rows = s.history.reversed.toList();
  final years = <int>[];
  for (final c in rows) {
    if (!years.contains(c.y)) years.add(c.y);
  }
  return [
    H2(tr('歴史')),
    Muted(tr('この遊びで起きた大きな出来事の年表です（新しい順）。')),
    if (rows.isEmpty) Panel(child: Muted(tr('まだ記録はありません。'))),
    for (final y in years)
      Panel(
        key: ValueKey('hist-$y'),
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 56, child: Text(yearL(y), style: ts(size: 13, bold: true, color: Pal.goldtx))),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final c in rows.where((c) => c.y == y)) Padding(padding: const EdgeInsets.only(bottom: 3), child: Text(tx(c.m), style: ts(size: 12.5))),
            ]),
          ),
        ]),
      ),
  ];
}
