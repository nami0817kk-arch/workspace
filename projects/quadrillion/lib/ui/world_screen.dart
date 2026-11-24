/// 世界の画面の右側（押した国の中身）。1.1.0+28 から（企画書「世界の画面（決定）」と段5）。
/// 人口・成長・金利・為替・最低賃金・法人税に、関税・物流・政治・伸びている業種・自社の出方・仕入れの網・視察を足した。
/// 視察（社長の時間1週間）をすると、電気・道路・ネット・政治の数字と伸びている業種が詳しく分かる
library;

import 'package:flutter/material.dart';

import '../game/game.dart';
import 'controller.dart';
import 'real_screens.dart';
import 'widgets.dart';

/// 0〜1 の整い具合を言葉に（視察していない国はおおまかにしか分からない）
String _level(double v) => v >= .85
    ? tr('よく整っている')
    : v >= .6
        ? tr('ふつう')
        : v >= .4
            ? tr('弱い')
            : tr('とても弱い');

String _risk(double v) => v >= .5
    ? tr('不安定')
    : v >= .25
        ? tr('ときどき揺れる')
        : tr('安定');

String _pct1(double v) => '${(v * 100).toStringAsFixed(v * 100 < 10 ? 1 : 0)}%';

/// 国の比較の表に足す列（関税＝本拠から入る物にかかる関税・物流＝道路の整い具合）
String worldTariffCell(Game s, String c) => c == s.home ? '-' : _pct1(s.tariffOf(c, s.home));
String worldRoadCell(Game s, String c) {
  if (s.knowsCtry(c)) return _pct1(s.roadOf(c));
  final v = s.roadOf(c);
  return v >= .85
      ? tr('よい')
      : v >= .6
          ? tr('ふつう')
          : tr('弱い');
}

Widget worldDetail(GameController ctl, String c) {
  final s = ctl.game!;
  final mine = s.biz.where((b) => s.ctryOf(b).contains(c)).toList();
  final cities = econData.cities(c);
  final knows = s.knowsCtry(c);
  final ship = s.shipOf(s.home, c);
  final ftas = s.ftasOf(s.home, c);
  final wto = WTO_YEAR[c] ?? 0;
  final stops = s.trade.stops.where((x) => x.c == c).toList();
  final shock = s.trade.shock[c];
  final cc = s.capCtl(c);
  final inputs = s.biz.where((b) => s.inputOf(b) != null).toList();
  return Column(key: const ValueKey('world-detail'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    countryPanel(ctl, c, title: '${cm[c]!.n}${c == s.home ? tr('（本拠）') : ''}'),
    Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Grid2([
          Kv(tr('人口'), L.en ? '${(s.ev(c, 'pop') / 1e6).toStringAsFixed(1)}M' : tr('{0}万人', [jsNum(jsRound(s.ev(c, 'pop') / 1e4))])),
          Kv(tr('失業率'), '${pctD(s.ev(c, 'unemp'))}%'),
          Kv(tr('市場の大きさ'), tr('{0}の{1}倍', [cm[s.home]!.n, (cw(c, s.yr()) / (cw(s.home, s.yr()) > 1e-9 ? cw(s.home, s.yr()) : 1e-9)).toStringAsFixed(2)])),
          Kv(tr('平均賃金'), tr('{0}／年', [yen(s.ev(c, 'wage_usd') * s.usdJpy())])),
        ]),
        if (cities.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Muted(tr('主な都市：{0}', [cities.take(4).map((x) => L.en ? x.en : x.ja).join(tr('・'))]), size: 12)),
      ]),
    ),
    // 関税・物流・政治
    Panel(
      key: const ValueKey('world-trade'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: CardTitle(tr('関税・物流・政治'))),
          if (stops.isNotEmpty) Tag(tx(stops.first.ja), kind: TagKind.bad),
          if (shock != null) Padding(padding: const EdgeInsets.only(left: 4), child: Tag(tr('政変'), kind: TagKind.bad)),
        ]),
        const SizedBox(height: 4),
        Grid2([
          Kv(tr('関税の平均'), _pct1(kp(TARIFF[c] ?? const [(1980, 8.0)], s.yr()) / 100)),
          if (c != s.home) Kv(tr('{0}から入る物', [cm[s.home]!.n]), _pct1(s.tariffOf(c, s.home))),
          Kv(tr('WTO'), wto == 0 || s.year >= wto ? tr('加盟') : tr('{0}年に加盟', [wto])),
          if (c != s.home) Kv(tr('運び方'), tr('{0}・{1}日', [tr(SHIP_MODE_JA[ship.mode]!), ship.days.round()])),
          if (c != s.home) Kv(tr('運賃'), _pct1(ship.freight)),
          Kv(tr('電気'), knows ? _pct1(s.powerOf(c)) : _level(s.powerOf(c))),
          Kv(tr('道路と物流'), knows ? _pct1(s.roadOf(c)) : _level(s.roadOf(c))),
          Kv(tr('ネットを使う人'), knows ? _pct1(s.teleOf(c)) : _level(s.teleOf(c))),
          Kv(tr('政治'), knows ? tr('{0}（揺れ {1}）', [_risk(s.polRisk(c)), (s.polRisk(c) * 100).round()]) : _risk(s.polRisk(c))),
          if (c != s.home) Kv(tr('立ち上げ'), tr('{0}か月', [s.setupMonths(c, 'solo')])),
          if (c != s.home) Kv(tr('送金の制限'), cc > 0 ? tr('利益の{0}', [_pct1(cc)]) : tr('なし')),
          if (c != s.home) Kv(tr('税の取り決め'), s.treaty(c) ? tr('あり') : tr('なし（送ると1割）')),
        ]),
        if (c != s.home)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Muted(ftas.isEmpty ? tr('{0}との貿易協定：なし', [cm[s.home]!.n]) : tr('{0}との貿易協定：{1}', [cm[s.home]!.n, ftas.map((f) => de(f.ja)).toSet().join(tr('・'))]), size: 12),
          ),
        if (!knows) Padding(padding: const EdgeInsets.only(top: 4), child: Muted(tr('視察すると、電気・道路・ネット・政治の数字と伸びている業種が分かります'), size: 12)),
        if (c != s.home && s.ctryOpen(c))
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Btn(tr('視察する（1週間・{0}）', [yen(s.inspectCost(c))]), () => ctl.act(() => s.inspect(c)),
                key: const ValueKey('world-inspect'), small: true, enabled: s.cash >= s.inspectCost(c) && s.canT('inspect')),
          ),
      ]),
    ),
    // 伸びている業種
    Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CardTitle(tr('伸びている業種')),
        const SizedBox(height: 2),
        if (!s.ctryOpen(c))
          Muted(tr('この年はまだ入れません'))
        else if (!knows)
          Muted(tr('視察で分かります'))
        else
          for (final i in s.growingIn(c)) Text('${tr('・@@bullet')}${i.name}', style: ts(size: 12.5)),
      ]),
    ),
    // 自社の出方
    Panel(
      key: const ValueKey('world-mine'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CardTitle(tr('自社の出方')),
        const SizedBox(height: 2),
        if (!s.ctryOpen(c))
          Muted(tr('この年はまだ入れません'))
        else if (mine.isEmpty) ...[
          Muted(tr('まだ出ていません。「事業」の「海外に出る」から出られます')),
          if (s.biz.isNotEmpty && s.entryNote(s.biz.first, c) != null) Padding(padding: const EdgeInsets.only(top: 2), child: Muted(tx(s.entryNote(s.biz.first, c)!), size: 12)),
        ] else
          for (final b in mine) _mineRow(s, b, c),
        if ((s.trade.trapped[c] ?? 0) > 0)
          Padding(padding: const EdgeInsets.only(top: 4), child: Muted(tr('送金の制限で国の外へ出せないお金：{0}', [yen(s.trade.trapped[c]!)]), size: 12)),
      ]),
    ),
    // 仕入れの網
    if (inputs.isNotEmpty)
      Panel(
        key: const ValueKey('world-supply'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          CardTitle(tr('仕入れの網')),
          const SizedBox(height: 2),
          Muted(tr('仕入れ先を分けると高くつくが、1か国が止まっても作り続けられる'), size: 12),
          for (final b in inputs) _supplyRow(ctl, s, b, c),
        ]),
      ),
  ]);
}

Widget _mineRow(Game s, Biz b, String c) {
  final v = s.trade.view[b.id] ?? const {};
  final a = s.adaptOf(b, c);
  final cost = (v['tariff'] ?? 0) + (v['freight'] ?? 0);
  return Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('${tr('・@@bullet')}${indm[b.ind]!.name}${(b.jv ?? []).contains(c) ? tr('（組んで）') : ''}', style: ts(size: 12.5, bold: true)),
      if (c != s.home)
        Muted(tr('現地の慣れ {0}／事業全体の関税と運賃 月{1}', [_pct1(a), yen(cost)]), size: 12)
      else
        Muted(tr('事業全体の関税と運賃 月{0}', [yen(cost)]), size: 12),
    ]),
  );
}

Widget _supplyRow(GameController ctl, Game s, Biz b, String c) {
  final inp = s.inputOf(b)!;
  final l = s.supOf(b);
  final ok = s.srcOk(b, c);
  final has = l.contains(c);
  return Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(
          tr('{0}（{1}）：{2}', [
            indm[b.ind]!.name,
            de(GROUPS[inp.$1]!.ja),
            l.map((x) => s.supHit(x) > 0 ? tr('{0}（止まっている）', [cm[x]!.n]) : cm[x]!.n).join(tr('・')),
          ]),
          style: ts(size: 12.5)),
      if (inp.$3) Muted(tr('止まると作れなくなる部品'), size: 11.5),
      if (has && l.length > 1)
        Align(
          alignment: Alignment.centerLeft,
          child: Btn(tr('{0}から仕入れるのをやめる', [cm[c]!.n]), () => ctl.act(() => s.dropSupplier(b, c)), small: true),
        )
      else if (!has && ok && l.length < maxSuppliers)
        Align(
          alignment: Alignment.centerLeft,
          child: Btn(tr('{0}からも仕入れる（{1}）', [cm[c]!.n, yen(s.supplierCost(b))]), () => ctl.act(() => s.addSupplier(b, c)),
              small: true, enabled: s.cash >= s.supplierCost(b) && s.canT('supply')),
        ),
    ]),
  );
}
