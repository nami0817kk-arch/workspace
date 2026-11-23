import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/game.dart';
import 'controller.dart';
import 'guide.dart';
import 'painters.dart';
import 'sheets.dart';
import 'widgets.dart';

/// 6つのタブの中身（試作の tTown / tBiz / tPeople / tStock / tNum / tZukan）

// ボタンは押せる範囲が 44pt あるので、行のあいだは空けない（見た目の隙間はその余白で足りる）
Widget _wrap(List<Widget> c) => Wrap(spacing: 6, runSpacing: 0, children: c);
Widget _gap([double h = 8]) => SizedBox(height: h);
String _pct0(double v) => '${jsNum(jsRound(v * 100))}%';

// --- 街 ---
List<Widget> townTab(GameController ctl) {
  final s = ctl.game!;
  final out = <Widget>[];
  final step = currentGuide(s);
  if (step != null) out.add(GuideBar(ctl: ctl, step: step));
  out.add(Padding(
    padding: const EdgeInsets.only(top: 10),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(border: Border.all(color: Pal.line), borderRadius: BorderRadius.circular(10)),
        child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Semantics(label: tr('自社のビルが並ぶ街'), child: RepaintBoundary(child: CustomPaint(painter: TownPainter(s), size: Size.infinite)))),
      ),
    ),
  ));
  final nCtry = <String>{for (final b in s.biz) ...s.ctryOf(b)}.length;
  out.add(Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Row(children: [
      Expanded(
          child: Text.rich(TextSpan(children: [
        TextSpan(text: tx(s.stageName()), style: ts(bold: true)),
        TextSpan(text: tr('　{0}を拠点に{1}か国で勝負中', [cm[s.home]!.city, nCtry == 0 ? 1 : nCtry]), style: ts(color: Pal.mute)),
      ]))),
      Tag(s.officeName(), kind: TagKind.gold),
    ]),
    _gap(),
    Grid2([
      Kv(tr('月の売上'), yen(s.rev)),
      Kv(tr('月の利益'), yen(s.pre)),
      Kv(tr('事業'), tr('{0}つ', [s.biz.length])),
      Kv(tr('子会社'), tr('{0}社', [s.subs().length])),
      Kv(tr('部下'), tr('{0}人', [s.staff.length])),
      Kv(tr('持ち株'), pct(s.sh.own)),
    ]),
  ])));
  out.add(_presPanel(ctl));
  out.add(Panel(
      child: Text.rich(TextSpan(children: [TextSpan(text: tr('目標　'), style: ts(bold: true)), TextSpan(text: tx(s.goalText()), style: ts())]))));
  final vow = s.vow;
  if (vow != null) {
    out.add(Panel(
        border: Pal.down,
        child: Text(tr('取締役会との約束：{0}年1月までに、年の利益を{1}まで戻す', [vow['y']!.round(), yen(vow['target']!)]), style: ts(size: 13))));
  }
  final tips = s.advice();
  if (tips.isNotEmpty) {
    out.add(Panel(
        border: Pal.gold,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('番頭のひとこと'), style: ts(bold: true, color: Pal.goldtx)),
          for (final x in tips) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${tr('・@@bullet')}${tx(x)}', style: ts(size: 13))),
        ])));
  }
  out.add(H2(tr('宿敵')));
  for (final c in s.cos.where((c) => c.rival != null && c.alive)) {
    final rel = c.rel;
    out.add(Panel(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Face(c.presName, col: c.rival!.col),
      const SizedBox(width: 10),
      Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(nmL(c.name), style: ts(bold: true))),
          Flexible(child: Tag(RTYPE[c.rival!.label ?? c.rival!.type] ?? '')),
        ]),
        Muted(tr('{0}・{1}歳　時価総額 {2}　{3}', [nmL(c.presName), jsNum(jsRound(c.presAge)), yen(c.cap), c.parent == 'player' ? tr('あなたの子会社') : ''])),
        Text.rich(TextSpan(style: ts(size: 12.5), children: [
          TextSpan(text: tr('関係 ')),
          TextSpan(
              text: tx(relWord(rel)),
              style: ts(
                  size: 12.5,
                  color: rel > 10
                      ? Pal.up
                      : rel < -10
                          ? Pal.down
                          : Pal.mute)),
          if ((s.sh.riv[c.id] ?? 0) > 0) TextSpan(text: tr('　あなたの株を {0} 保有', [pct(s.sh.riv[c.id]!)])),
        ])),
        Text.rich(TextSpan(style: ts(size: 12.5), children: [
          TextSpan(text: tr('因縁 ')),
          TextSpan(text: tx(s.storyStage(c.rival!)), style: ts(size: 12.5, bold: true)),
          if (c.rival!.st > 0) TextSpan(text: tr('　恨み {0}・恩 {1}・されたこと {2}', [c.rival!.grudge, c.rival!.favor, c.rival!.hurt])),
        ])),
        for (final t in c.rival!.ties.reversed.take(2)) Muted('${tr('・@@bullet')}${tx(t)}', size: 12),
        if (c.parent != 'player') Padding(padding: const EdgeInsets.only(top: 6), child: Btn(tr('裏の手'), () => openDirty(ctl, c), small: true)),
      ])),
    ])));
  }
  out.add(H2(tr('最近のできごと')));
  for (final n in s.log.reversed.take(8)) {
    out.add(NewsLine(n.m, n.t, prefix: n.y != null ? '${yearL(n.y!)} ' : null));
  }
  return out;
}

Widget _presPanel(GameController ctl) {
  final s = ctl.game!;
  final n = s.partners().length;
  final noAp = s.ap < 1;
  return Panel(
    border: Pal.gold,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text(tr('社長の行動'), style: ts(bold: true, color: Pal.goldtx))),
        Muted(tr('どれも手を1つ使う'), size: 12),
      ]),
      _gap(),
      if (s.biz.isEmpty) ChoiceBtn(tr('最初の事業を決める'), () => openStart(ctl), primary: true, subs: [tr('最初の1つは手を使わない')]),
      ChoiceBtn(tr('相棒を探す'), () => openSeek(ctl), enabled: !(n >= 2 || noAp), subs: [tr('株を分けて口説く。今の相棒 {0}/2人', [n])]),
      ChoiceBtn(tr('日銭を稼ぐ'), () => ctl.act(() => s.presAct('work')), enabled: !noAp, subs: [tr('受託の仕事を受ける。約{0}', [yen(s.workIncome())])]),
      ChoiceBtn(tr('腕を磨く'), () => openTrain(ctl), enabled: !noAp, subs: [tr('社長の能力を1つ伸ばす。若いほど伸びる')]),
      ChoiceBtn(tr('人脈を作る'), () => ctl.act(() => s.presAct('net')), enabled: !(noAp || s.net >= 5), subs: [tr('借りられる額と採用の質が上がる（{0}/5）', [s.net])]),
      ChoiceBtn(tr('事業の種を探す'), () => ctl.act(() => s.presAct('scout')), enabled: !noAp, subs: [tr('これから生まれる市場や、相性のよい組み合わせが分かる')]),
    ]),
  );
}

// --- 事業 ---
List<Widget> bizTab(GameController ctl) {
  final s = ctl.game!;
  final out = <Widget>[H2(tr('自社の事業'))];
  if (s.biz.isEmpty) out.add(Panel(child: Muted(tr('まだ事業がありません。下の「新しい事業」から始めましょう。'), size: 14)));
  final y = s.yr();
  // 3つ以上は1行ずつにたたみ、押した1つだけを詳しく開く
  final fold = s.biz.length >= 3;
  for (final b in s.biz.toList()..ssort((a, b) => b.rev.compareTo(a.rev))) {
    out.add(!fold
        ? _bizCard(ctl, b)
        : ctl.openBiz == b.id
            ? _bizCard(ctl, b, onFold: () => ctl.toggleBiz(b.id))
            : _bizRow(ctl, b));
  }
  out.add(H2(tr('新しい事業')));
  out.add(Row(children: [
    Muted(tr('絞り込み')),
    const SizedBox(width: 8),
    Expanded(
      child: Pick<String>(
        value: ctl.bizFilter,
        items: [('can', tr('今の資金で始められる')), ('new', tr('生まれて10年以内')), ('all', tr('すべて')), for (final e in CATN.entries) (e.key, e.value)],
        onChanged: (v) {
          ctl.bizFilter = v;
          ctl.render();
        },
      ),
    ),
  ]));
  final f = ctl.bizFilter;
  final list = s
      .liveInds()
      .where((i) => !s.biz.any((b) => b.ind == i.id))
      .where((i) => f == 'all'
          ? true
          : f == 'can'
              ? s.capexOf(i) <= s.cash
              : f == 'new'
                  ? y - i.b < 10
                  : i.cat == f)
      .toList()
    ..ssort((a, b) => s.capexOf(a).compareTo(s.capexOf(b)));
  if (list.isEmpty) out.add(Panel(child: Muted(tr('この条件で始められる事業はありません。'), size: 14)));
  if (list.isNotEmpty) {
    out.add(Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: [
        Expanded(child: Muted(tr('業種'), size: 12)),
        SizedBox(width: 82, child: Align(alignment: Alignment.centerRight, child: Muted(tr('元手'), size: 12))),
        SizedBox(width: 82, child: Align(alignment: Alignment.centerRight, child: Muted(tr('市場（国内・月）'), size: 11))),
        const SizedBox(width: 60),
      ]),
    ));
  }
  for (final i in list) {
    final c = s.capexOf(i);
    final age = y - i.b;
    final ks = s.knownSynFor(i.id);
    out.add(Container(
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Pal.line))),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 4, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(i.name, style: ts(size: 13)),
              if (ks.isNotEmpty)
                Tooltip(message: ks.map((x) => x.name).join(tr('、')), child: Tag(tr('シナジー'), kind: TagKind.gold)),
              if (age < 3)
                Tag(tr('先行者になれる'), kind: TagKind.good)
              else if (age < 10)
                Tag(tr('新しい'), kind: TagKind.good)
              else if (i.f != 0 && y > i.f)
                Tag(tr('沈み中'), kind: TagKind.bad),
            ]),
            Muted(tr('利益率{0}・{1}', [_pct0(i.mg), ABN[i.key]]), size: 11.5),
          ]),
        ),
        SizedBox(width: 82, child: Text(yen(c), textAlign: TextAlign.right, style: ts(size: 13))),
        SizedBox(width: 82, child: Text(yen(s.mkt(i) / 3), textAlign: TextAlign.right, style: ts(size: 13))),
        SizedBox(
            width: 60,
            child: Align(
                alignment: Alignment.centerRight,
                child: Btn(tr('始める'), () => s.modelsFor(i.id).length > 1 ? openModel(ctl, i.id) : ctl.act(() => s.startBiz(i.id)),
                    small: true, enabled: s.cash >= c))),
      ]),
    ));
  }
  final soon = s.inds.where((i) => s.seen[i.id] != null && i.b > y).toList();
  if (soon.isNotEmpty) {
    out.add(Panel(
        child: Text.rich(TextSpan(children: [
      TextSpan(text: tr('近く生まれそうな市場　'), style: ts(size: 12.5, bold: true, color: Pal.goldtx)),
      TextSpan(text: soon.map((i) => tr('{0}（{1}年ごろ）', [i.name, i.b])).join(tr('・')), style: ts(size: 12.5)),
    ]))));
  }
  out.add(H2(tr('銀行@@h')));
  final room = math.max(0.0, s.borrowLimit() - s.debt);
  out.add(Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(tr('借金 {0}／借りられる上限 {1}／利息 毎月{2}%', [yen(s.debt), yen(room), s.hasT('careful') ? '0.2' : '0.33']), style: ts(size: 13)),
    _gap(),
    _wrap([
      for (final k in const [.25, 1.0])
        Builder(builder: (_) {
          final a = math.max(0.0, (s.borrowLimit() - s.debt) * k);
          return Btn(tr('{0} 借りる', [yen(a)]), () => ctl.act(() => s.borrow(a)), small: true, enabled: a >= 1e5);
        }),
      Btn(tr('全部返す'), () => ctl.act(() => s.repay(s.debt)), small: true, enabled: s.debt > 0),
      if (s.bond > 0)
        Muted(tr('社債 {0}（{1}年に返す）', [yen(s.bond), s.year + ((s.bondDue - s.turn + s.q - 1) / 12).floor()]))
      else
        Btn(tr('社債を出す'), () => ctl.act(s.issueBond), small: true, enabled: s.canBond()),
      if (s.land > 0) Btn(tr('土地を売る（今の値 {0}）', [yen(s.land)]), () => ctl.act(s.sellLand), small: true),
    ]),
  ])));
  return out;
}

/// 事業の注意の印（人手不足・値下げ合戦中・沈む市場）
List<String> bizWarnings(Game s, Biz b) {
  final ind = indm[b.ind]!;
  return [
    if (b.model != 'fc' && b.power > 0 && s.crewEff(b) / b.power < .9) tr('人手不足'),
    if (b.war > 0) tr('値下げ合戦中'),
    if (ind.f != 0 && s.yr() > ind.f) tr('沈む市場'),
  ];
}

/// たたんだ事業の1行（業種名・稼ぎ方・シェア・月の売上と利益・注意の印）。押すと詳しいカードが開く
Widget _bizRow(GameController ctl, Biz b) {
  final s = ctl.game!;
  final ind = indm[b.ind]!;
  final warn = bizWarnings(s, b);
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 3),
    child: Material(
      color: Pal.panel,
      shape: RoundedRectangleBorder(side: BorderSide(color: warn.isNotEmpty ? Pal.down : Pal.line), borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('biz-row-${b.id}'),
        onTap: () => ctl.toggleBiz(b.id),
        child: Container(
          constraints: const BoxConstraints(minHeight: minTap),
          padding: const EdgeInsets.fromLTRB(12, 7, 6, 7),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 4, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text(ind.name, style: ts(size: 14, bold: true)),
                  Tag(MODELN[b.model]!, kind: TagKind.gold),
                  for (final w in warn) Tag(w, kind: TagKind.bad),
                  if (b.pipe.isNotEmpty) Tag(tr('仕掛かり {0}件', [b.pipe.length])),
                ]),
                const SizedBox(height: 2),
                Text.rich(TextSpan(style: ts(size: 12.5, color: Pal.mute), children: [
                  TextSpan(text: tr('シェア {0}', [pct(b.share * 100)])),
                  TextSpan(text: tr('・売上 {0}', [yen(b.rev)])),
                  TextSpan(text: tr('・利益 ')),
                  TextSpan(text: yen(b.profit), style: ts(size: 12.5, color: b.profit >= 0 ? Pal.up : Pal.down)),
                ])),
              ]),
            ),
            const Icon(Icons.expand_more, size: 22, color: Pal.mute),
          ]),
        ),
      ),
    ),
  );
}

/// 仕掛かり1件の行（今までどおり、その場で取り下げられる）
Widget _pipeRow(GameController ctl, Biz b, int i) {
  final s = ctl.game!;
  return Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(children: [
      Expanded(
        child: Wrap(spacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Tag(pipeKindName(b.pipe[i].k)),
          Text(pipeText(s, b, b.pipe[i]), style: ts(size: 12.5)),
        ]),
      ),
      Btn(tr('取り下げる（半分戻る）'), () => ctl.act(() => s.cancelPipe(b, i)), small: true),
    ]),
  );
}

/// 同じ種類の仕掛かりが2件以上あるときの1行。押すと一覧が開く
Widget _pipeGroupRow(GameController ctl, Biz b, PipeGroup g) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Material(
        color: Pal.panel2,
        shape: RoundedRectangleBorder(side: const BorderSide(color: Pal.line), borderRadius: BorderRadius.circular(8)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('pipe-${b.id}-${g.k}'),
          onTap: () => openPipes(ctl, b, g.k),
          child: Container(
            constraints: const BoxConstraints(minHeight: minTap),
            padding: const EdgeInsets.only(left: 8, right: 4),
            child: Row(children: [
              Tag(pipeKindName(g.k)),
              const SizedBox(width: 6),
              Expanded(child: Text(pipeGroupText(g), style: ts(size: 12.5))),
              const Icon(Icons.chevron_right, size: 20, color: Pal.mute),
            ]),
          ),
        ),
      ),
    );

Widget _bizCard(GameController ctl, Biz b, {VoidCallback? onFold}) {
  final s = ctl.game!;
  final ind = indm[b.ind]!;
  final p = s.staffById(b.mgr);
  final free = s.staff.where((x) => !s.biz.any((y) => y.mgr == x.id)).toList();
  final cs = s.competitors(b);
  final cts = s.ctryOf(b);
  Widget crewLine;
  if (b.model == 'fc') {
    crewLine = Muted('${tr('現場の人は加盟店が集めます')}${b.upkeep > 0 ? tr('　維持費 {0}／月', [yen(b.upkeep)]) : ''}');
  } else {
    final r = b.power > 0 ? s.crewEff(b) / b.power : 1.0;
    crewLine = Text.rich(TextSpan(style: ts(size: 12.5), children: [
      TextSpan(text: tr('現場の力 '), style: ts(size: 12.5, color: Pal.mute)),
      TextSpan(text: '${jsNum(jsRound(r * 100))}%', style: ts(size: 12.5, bold: true, color: r < .9 ? Pal.down : Pal.up)),
      if (r < .9)
        TextSpan(text: tr('　人が足りず、{0}の一部が止まっている', [s.uw(b)]), style: ts(size: 12.5, color: Pal.down))
      else if (r > 1.6)
        TextSpan(text: tr('　人が余っている'), style: ts(size: 12.5, color: Pal.mute)),
      if (b.upkeep > 0) TextSpan(text: tr('　維持費 {0}／月', [yen(b.upkeep)]), style: ts(size: 12.5, color: Pal.mute)),
    ]));
  }
  final mgrItems = <(int, String)>[
    (0, tr('社長が直接')),
    for (final x in [?p, ...free]) (x.id, tr('{0}（{1} {2}）', [nmL(x.name), ABN[ind.key], s.showAb(x, ind.key)])),
  ];
  return Panel(
    border: onFold != null ? Pal.gold : Pal.line,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: onFold != null ? CrossAxisAlignment.center : CrossAxisAlignment.start, children: [
        Expanded(
            child: onFold == null
                ? Text(ind.name, style: ts(bold: true))
                // 名前の行を押すと、たたんで1行に戻す
                : InkWell(
                    key: ValueKey('biz-fold-${b.id}'),
                    onTap: onFold,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: minTap),
                      alignment: Alignment.centerLeft,
                      child: Row(children: [
                        Flexible(child: Text(ind.name, style: ts(bold: true))),
                        const Icon(Icons.expand_less, size: 22, color: Pal.mute),
                      ]),
                    ),
                  )),
        Flexible(
          child: Wrap(alignment: WrapAlignment.end, spacing: 4, runSpacing: 4, children: [
            if (b.war > 0) Tag(tr('値下げ合戦中'), kind: TagKind.bad),
            if (b.ad > 0) Tag(tr('広告中'), kind: TagKind.good),
            if (b.early > s.turn) Tooltip(message: tr('業種が生まれてすぐ始めたので、打ち手がよく効く'), child: Tag(tr('先行者'), kind: TagKind.good)),
            Tag(MODELN[b.model]!, kind: TagKind.gold),
            Tag(CATN[ind.cat]!),
          ]),
        ),
      ]),
      Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Semantics(label: tr('シェア'), child: Bar([(b.share * 100, Pal.gold)]))),
      Grid2([
        Kv(tr('シェア'), pct(b.share * 100)),
        Kv(
            tr('売上'),
            Text.rich(TextSpan(style: ts(size: 13), children: [
              TextSpan(text: yen(b.rev)),
              if (b.prevRev > 0)
                TextSpan(
                    text: ' ${b.rev >= b.prevRev ? '+' : ''}${jsNum(jsRound((b.rev / b.prevRev - 1) * 100))}%',
                    style: ts(size: 11.5, color: b.rev >= b.prevRev ? Pal.up : Pal.down)),
            ]))),
        Kv(tr('利益'), colored(yen(b.profit), b.profit >= 0 ? Pal.up : Pal.down)),
        Kv(tr('効く能力'), ABN[ind.key]!),
      ]),
      _gap(),
      cs.isEmpty
          ? Muted(tr('名のある競争相手はいません'))
          : Text.rich(TextSpan(style: ts(size: 12.5), children: [
              TextSpan(text: tr('競っている相手 '), style: ts(size: 12.5, color: Pal.mute)),
              for (var i = 0; i < cs.length; i++) ...[
                if (i > 0) TextSpan(text: tr('／')),
                TextSpan(
                    text: nmL(cs[i].c.name),
                    style: cs[i].c.rival != null ? ts(size: 12.5, bold: true, color: rivalInk(cs[i].c.rival!.col)) : null),
                TextSpan(text: ' ${pct(cs[i].share * 100)}'),
              ],
            ])),
      const SizedBox(height: 6),
      Text.rich(TextSpan(style: ts(size: 12.5), children: [
        TextSpan(text: tr('出ている国 '), style: ts(size: 12.5, color: Pal.mute)),
        TextSpan(text: cts.map((c) => '${cm[c]!.n}${(b.jv ?? []).contains(c) ? tr('（組む）') : ''}').join(tr('・'))),
        cts.length >= 5
            ? TextSpan(text: tr('　規模の利益 利益率＋{0}%', [jsNum(jsRound(math.min(.5, (cts.length - 4) * .06) * 100))]), style: ts(size: 12.5, color: Pal.up))
            : TextSpan(text: tr('　5か国以上で規模の利益'), style: ts(size: 12.5, color: Pal.mute)),
      ])),
      const SizedBox(height: 6),
      crewLine,
      // 仕掛かりは種類ごとに1行。1件だけの種類は今までどおりその場で取り下げられる
      for (final g in pipeGroups(b)) g.count == 1 ? _pipeRow(ctl, b, g.idx.first) : _pipeGroupRow(ctl, b, g),
      _gap(),
      Row(children: [
        Muted(tr('責任者')),
        const SizedBox(width: 6),
        Expanded(
          child: Pick<int>(
            value: b.mgr ?? 0,
            items: mgrItems,
            onChanged: (v) {
              s.setManager(b, v == 0 ? null : v);
              ctl.save();
              ctl.render();
            },
          ),
        ),
      ]),
      const SizedBox(height: 6),
      Row(children: [
        Muted(tr('値付け')),
        const SizedBox(width: 6),
        Expanded(
          child: Pick<String>(
            value: b.price,
            items: [('cut', tr('安く（客は増えるが利益が薄い）')), ('normal', tr('ふつう')), ('premium', tr('高く（利益は厚いが客が減る）'))],
            onChanged: (v) {
              s.setPrice(b, v);
              ctl.save();
              ctl.render();
            },
          ),
        ),
      ]),
      _gap(),
      _wrap([
        Btn(tr('商品を作る {0}', [yen(s.cash * .3)]), () => ctl.act(() => s.develop(b, .3), mark: 'act'), small: true, enabled: s.cash > 0),
        Btn(tr('{0}を増やす {1}', [s.uw(b), yen(s.cash * .3)]), () => ctl.act(() => s.build(b, .3), mark: 'act'), small: true, enabled: s.cash > 0),
        Btn(tr('大きく増やす {0}', [yen(s.cash * .6)]), () => ctl.act(() => s.build(b, .6), mark: 'act'), small: true, enabled: s.cash > 0),
        if (s.crewNeedCost(b) > 0)
          Btn(tr('足りない分の人を補う {0}', [yen(s.crewNeedCost(b))]), () => ctl.act(() => s.addCrewNeeded(b), mark: 'act'),
              small: true, enabled: s.cash >= s.crewNeedCost(b)),
        Btn(tr('現場の人を多めに増やす {0}', [yen(s.cash * .2)]), () => ctl.act(() => s.addCrew(b, .2), mark: 'act'), small: true, enabled: s.cash > 0),
        Btn(tr('広告 {0}', [yen(s.invBase(b) * .25)]), () => ctl.act(() => s.adv(b), mark: 'act'), small: true),
        if (cs.isNotEmpty)
          Btn(b.attack > 0 ? tr('値下げ合戦中（あと{0}期）', [b.attack]) : tr('値下げ合戦を仕掛ける（相手：{0}）', [nmL(cs[0].c.name)]), () => ctl.act(() => s.priceWar(b), mark: 'act'),
              small: true, enabled: b.attack <= 0),
        Btn(tr('海外に出る'), () => openEnter(ctl, b), small: true),
        Btn(tr('分社・独立'), () => openShape(ctl, b), small: true),
        if (!s.inAssoc(b.ind) && cs.isNotEmpty) Btn(tr('業界団体に入る'), () => ctl.act(() => s.joinAssoc(b), mark: 'act'), small: true),
        if (s.modelsFor(b.ind).length > 1) Btn(tr('稼ぎ方を変える'), () => openModel(ctl, b.ind, b), small: true),
        if (s.pivotTargets(b).isNotEmpty) Btn(tr('業態を変える'), () => openPivot(ctl, b), small: true),
        Btn(tr('売る（約{0}）', [yen(s.sellValue(b))]),
            () => actConfirmed(ctl, tr('「{0}」を売る', [ind.name]), tr('「{0}」を約{1}で手放します。育てた力は戻りません。', [ind.name, yen(s.sellValue(b))]), tr('売る'), () => s.sellBiz(b)),
            small: true),
      ]),
    ]),
  );
}

// --- 人 ---
List<Widget> peopleTab(GameController ctl) {
  final s = ctl.game!;
  final P = s.pres;
  final out = <Widget>[H2(tr('社長'))];
  out.add(Panel(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Face(P.name, col: '#f2c14e'),
    const SizedBox(width: 10),
    Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(tr('{0}（{1}歳）', [nmL(P.name), P.age]), style: ts(bold: true)),
      const SizedBox(height: 6),
      Grid2([for (final k in abKeys) Kv(ABN[k]!, '${P.ab[k]}')]),
      for (final t in P.traits)
        Builder(builder: (_) {
          final T = TRAITS.firstWhere((x) => x.id == t, orElse: () => STRAITS.firstWhere((x) => x.id == t));
          return Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(spacing: 4, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Tag(T.n, kind: TagKind.gold),
              colored('${tr('＋')}${T.g}', Pal.up, size: 12.5),
              colored('${tr('－')}${T.b}', Pal.down, size: 12.5),
            ]),
          );
        }),
      const SizedBox(height: 8),
      Text('${tr('自分で見られる事業は{0}つまで。', [s.presCap()])}${P.age >= 55 ? tr('そろそろ後継ぎを考える年です。') : ''}', style: ts(size: 12.5)),
    ])),
  ])));
  final cu = CULT[s.culture]!;
  out.add(Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Expanded(child: Text(tr('社風'), style: ts(bold: true))), Tag(cu.n, kind: TagKind.gold)]),
    const SizedBox(height: 4),
    Wrap(spacing: 8, children: [colored('${tr('＋')}${cu.g}', Pal.up, size: 12.5), colored('${tr('－')}${cu.b}', Pal.down, size: 12.5)]),
    const SizedBox(height: 6),
    if (s.cultLeft > 0)
      Muted(tr('「{0}」に切り替え中（あと{1}か月）', [CULT[s.cultNext]!.n, s.cultLeft]))
    else
      _wrap([
        for (final k in CULT.keys.where((k) => k != s.culture))
          Tooltip(message: '${tr('＋')}${CULT[k]!.g}${tr('／')}${tr('－')}${CULT[k]!.b}', child: Btn(tr('{0}にする', [CULT[k]!.n]), () => ctl.act(() => s.changeCulture(k)), small: true)),
      ]),
  ])));
  final succs = [...s.staff, ...s.kids.where((k) => k.age >= 18)];
  out.add(Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Text(tr('後継ぎ'), style: ts(bold: true)),
    const SizedBox(height: 6),
    Row(children: [
      Muted(tr('候補')),
      const SizedBox(width: 6),
      Expanded(
        child: Pick<int>(
          value: s.succ ?? 0,
          items: [(0, tr('まだ決めていない')), for (final p in succs) (p.id, tr('{0}（{1}{2}歳）', [nmL(p.name), p.kid ? tr('子ども・') : '', p.age]))],
          onChanged: (v) {
            s.choosePresSucc(v == 0 ? null : v);
            ctl.save();
            ctl.render();
          },
        ),
      ),
      const SizedBox(width: 6),
      Btn(tr('引退して譲る'), () => ctl.act(s.retire), small: true, enabled: s.succ != null),
    ]),
    for (final k in s.kids)
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(children: [
          Expanded(child: Muted(tr('子ども {0}（{1}歳）', [nmL(Game.givenOf(k.name)), k.age]))),
          k.age >= 22 ? Btn(tr('入社させる'), () => ctl.act(() => s.kidJoin(k)), small: true) : Muted(tr('22歳で入社できる')),
        ]),
      ),
  ])));
  out.add(H2(tr('部下（{0}人）', [s.staff.length])));
  for (final p in s.staff) {
    final t = STRAITS.firstWhere((x) => x.id == p.trait);
    final job = s.biz.where((b) => b.mgr == p.id).firstOrNull;
    out.add(Panel(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Face(p.name),
      const SizedBox(width: 10),
      Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 6, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(tr('{0}（{1}歳）', [nmL(p.name), p.age]), style: ts(bold: true)),
          if (p.partner) Tag(tr('相棒・株{0}', [pct(p.stake)]), kind: TagKind.gold),
          if (p.auto) Tag(tr('提案はまかせている'), kind: TagKind.good),
          Muted(job != null ? tr('{0}の責任者', [indm[job.ind]!.name]) : tr('担当なし')),
        ]),
        const SizedBox(height: 4),
        Grid2([for (final k in abKeys) Kv(ABN[k]!, s.showAb(p, k))]),
        const SizedBox(height: 4),
        Wrap(spacing: 4, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(tr('特性'), style: ts(size: 12.5)),
          if (p.traitKnown) ...[Tag(t.n), colored('${tr('＋')}${t.g}', Pal.up, size: 12.5), colored('${tr('－')}${t.b}', Pal.down, size: 12.5)] else Muted(tr('？（働かせると分かる）')),
          Text(tr('　野心'), style: ts(size: 12.5)),
          p.ambKnown
              ? colored(
                  tr(p.amb > 70
                      ? '強い'
                      : p.amb > 40
                          ? 'ふつう@@amb'
                          : '弱い'),
                  p.amb > 70 ? Pal.down : Pal.ink,
                  size: 12.5)
              : Muted(tr('？')),
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Muted(tr('給料 {0}／月', [yen(p.salary * (s.hasT('frugal') ? .7 : 1))])),
          if (p.auto)
            Btn(tr('まかせるのをやめる'), () {
              p.auto = false;
              ctl.save();
              ctl.render();
            }, small: true),
          Btn(
              tr(p.partner ? '相棒と別れる' : '解雇'),
              () => p.partner
                  ? actConfirmed(ctl, tr('相棒と別れる'), tr(s.listed ? '{0}は会社を去り、持っている株{1}は市場で売られます。' : '{0}は会社を去り、持っている株{1}は投資家の手に渡ります。', [nmL(p.name), pct(p.stake)]), tr('別れる'), () => s.dismiss(p))
                  : actConfirmed(ctl, tr('解雇'), tr('{0}を解雇します。もう呼び戻せません。', [nmL(p.name)]), tr('解雇する'), () => s.dismiss(p)),
              small: true),
        ]),
      ])),
    ])));
  }
  out.add(H2(tr('採用の候補')));
  out.add(Muted(tr('面接で分かるのは能力の幅だけです。働かせると本当の値と特性が見えてきます。')));
  for (final p in s.cands) {
    out.add(Panel(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Face(p.name),
      const SizedBox(width: 10),
      Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(tr('{0}（{1}歳）', [nmL(p.name), p.age]), style: ts(bold: true)),
        const SizedBox(height: 4),
        Grid2([for (final k in abKeys) Kv(ABN[k]!, s.showAb(p, k))]),
        const SizedBox(height: 4),
        p.traitKnown ? Text(tr('特性 {0}', [STRAITS.firstWhere((x) => x.id == p.trait).n]), style: ts(size: 12.5)) : Muted(tr('評判：{0}', [traitHints[p.trait]])),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: Muted(tr('給料 {0}／月・支度金 {1}', [yen(p.salary), yen(p.salary * 2)]))),
          Btn(tr('雇う'), () => ctl.act(() => s.hire(p)), small: true),
        ]),
      ])),
    ])));
  }
  return out;
}

// --- 株 ---
List<Widget> stockTab(GameController ctl) {
  final s = ctl.game!;
  final sh = s.sh;
  final out = <Widget>[H2(tr('あなたの会社の株主'))];
  final parts = <(String, double, Color)>[
    (tr('あなた'), sh.own, Pal.gold),
    (tr('相棒'), sh.pt, const Color(0xFFFFB454)),
    (tr('投資家'), sh.vc, const Color(0xFF9FB3FF)),
    (tr('味方'), sh.ally, Pal.teal),
    (tr('市場'), sh.float, const Color(0xFF55618F)),
  ];
  for (final e in sh.riv.entries) {
    if (e.value > 0) parts.add((nmL(s.coById(e.key)?.name ?? '?'), e.value, Pal.down));
  }
  out.add(Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Bar([for (final p in parts) (p.$2, p.$3)], height: 14),
    _gap(),
    Grid2([for (final p in parts.where((p) => p.$2 > .05)) Kv(p.$1, pct(p.$2))]),
    const SizedBox(height: 6),
    Muted(tr('5%で相手に知られる／33.4%で合併を止められる／50%超で社長を替えられる／66.7%で合併も自由')),
  ])));
  out.add(Panel(
    child: s.listed
        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('上場済み'), style: ts(bold: true)),
            Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Muted(tr('誰でもあなたの株を買えます。乗っ取りに注意。'))),
            _wrap([
              Btn(tr('増資で集める（{0}・全員の割合−9%）', [yen(s.cap * .095)]), () => ctl.act(s.publicOffer), small: true),
              Btn(tr('自社株買い 5%（約{0}）', [yen(s.cap * .0575)]), () => ctl.act(s.buybackAct), small: true, enabled: sh.float >= 1),
              Btn(tr('ホワイトナイトを頼む'), () => ctl.act(s.whiteKnightAct), small: true),
            ]),
          ])
        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('未上場'), style: ts(bold: true)),
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Muted(tr('上場すると大金が入るが、宿敵があなたの株を買えるようになる。条件：年の利益 {0} 以上・創業2年以上', [yen(3e8 * s.nom())]))),
            _wrap([
              Btn(tr('投資家から集める（{0}・持ち株−10%）', [yen(s.cap * .1)]), () => ctl.act(s.vcRaise), small: true),
              Btn(tr('上場する'), () => ctl.act(s.ipo), small: true, enabled: s.canIPO()),
            ]),
          ]),
  ));
  if (s.deals.isNotEmpty) {
    out.add(H2(tr('組んでいる相手')));
    for (final d in s.deals.toList()) {
      final c = s.coById(d.co);
      if (c == null) continue;
      out.add(Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(nmL(c.name), style: ts(bold: true))),
          Flexible(child: Tag('${DEALN[d.type]}${d.ind != null ? tr('：{0}', [indm[d.ind]!.name]) : ''}', kind: TagKind.good)),
        ]),
        Muted(tr('{0}年から　関係 {1}', [d.since, tr(c.rel > 25 ? '友好' : c.rel > 10 ? 'やや良い' : c.rel < -10 ? '警戒' : 'ふつう@@rel')])),
        const SizedBox(height: 6),
        _wrap([
          Btn(tr('解消する'), () => ctl.act(() => s.endDeal(d)), small: true),
          if (d.type != 'assoc')
            Tooltip(message: tr('相手の客を奪う。相手は激怒し、業界の評判も落ちる'), child: Btn(tr('裏切る'), () => ctl.act(() => s.betray(d)), small: true)),
        ]),
      ])));
    }
  }
  out.add(H2(tr('会社の形')));
  out.add(Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Expanded(child: Text(tr(s.holding ? '持株会社' : 'ふつうの会社'), style: ts(bold: s.holding))),
      if (!s.holding) Flexible(child: Btn(tr('持株会社にする'), () => ctl.act(s.makeHolding), small: true, enabled: s.biz.length + s.subs().length >= 5)),
    ]),
    Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Muted(tr('持株会社は、社長が直接見られる事業の上限がなくなります。事業は「事業」の画面から、分社（子会社にする）や、責任者に渡して独立させることもできます。'))),
    if (s.listed && s.biz.length >= 2)
      _wrap([
        Muted(tr('会社を2つに割る：')),
        for (final cat in <String>{for (final b in s.biz) indm[b.ind]!.cat})
          Btn(tr('{0}を切り離す', [CATN[cat]]), () => ctl.act(() => s.splitCompany(cat)), small: true),
      ]),
  ])));
  out.add(H2(tr('売り抜け')));
  out.add(Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Muted(tr('勝ち負けは「今の会社の時価総額＋あなたの財産」で測ります。今の財産 {0}', [yen(s.wealth)])),
    const SizedBox(height: 6),
    _wrap([
      if (s.listed) Btn(tr('持ち株を5%売る（約{0}）', [yen(s.cap * .045)]), () => ctl.act(() => s.sellOwn(5)), small: true),
      if (s.listed) Btn(tr('非上場に戻す（MBO）'), () => ctl.act(s.goPrivate), small: true),
      Btn(tr('会社を丸ごと売る'), () => openSell(ctl), small: true, enabled: s.biz.isNotEmpty && s.buyers().isNotEmpty),
      if (s.noncomp != null && !s.noncomp!.broken)
        Tooltip(message: tr('2年後に裁判で賠償を求められる'), child: Btn(tr('同じ業種に入らない約束を破る'), () => ctl.act(s.breakNoncomp), small: true)),
    ]),
  ])));
  final mine = s.cos.where((c) => c.alive && s.pctOf(c) > 0).toList();
  if (mine.isNotEmpty) {
    out.add(H2(tr('持っている他社の株')));
    for (final c in mine) {
      out.add(_coCard(ctl, c));
    }
  }
  out.add(H2(tr('買える会社')));
  out.add(Muted(tr('時価総額の小さい順に、あなたのいる業種の会社を先に並べています。')));
  final myInd = <String>{for (final b in s.biz) b.ind};
  int inMine(Company c) => c.biz.any((x) => myInd.contains(x.ind)) ? 1 : 0;
  final list = s.cos.where((c) => c.alive && s.pctOf(c) == 0 && c.parent != 'player').toList()
    ..ssort((a, b) {
      final d = inMine(b) - inMine(a);
      return d != 0 ? d : a.cap.compareTo(b.cap);
    });
  for (final c in list.take(14)) {
    out.add(_coCard(ctl, c));
  }
  return out;
}

Widget _coCard(GameController ctl, Company c) {
  final s = ctl.game!;
  final own = s.pctOf(c);
  final restC = c.cap * (100 - own) / 100;
  return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Row(children: [
      if (c.rival != null) ...[Face(c.presName, col: c.rival!.col), const SizedBox(width: 6)],
      Expanded(child: Text(nmL(c.name), style: ts(bold: true))),
      if (c.parent == 'player') ...[Tag(c.loc != null ? tr('現地法人（{0}）', [cm[c.loc!]!.n]) : tr('子会社@@tag'), kind: TagKind.gold), const SizedBox(width: 4)],
      Flexible(child: Tag(c.rival != null ? RTYPE[c.rival!.label ?? c.rival!.type] ?? '' : REGN[c.tier])),
    ]),
    Muted(c.biz.map((b) => indm[b.ind]!.name).join(tr('・'))),
    const SizedBox(height: 6),
    Grid2([
      Kv(tr('時価総額'), yen(c.cap)),
      Kv(tr('月の利益'), yen(c.profit)),
      Kv(tr('創業家'), pct(c.fam)),
      Kv(tr('社風'), CULT[s.cultureOf(c)]!.n),
      Kv(tr('市場の株'), pct(s.floatOf(c))),
      if (own > 0) Kv(tr('あなた'), pct(own)),
      if (c.loc != null && c.locRivPct > 0 && s.coById(c.locRiv) != null) Kv(tr('宿敵の持ち分'), pct(c.locRivPct)),
    ]),
    _gap(),
    _wrap([
      Btn(tr('市場で5%買う（{0}）', [yen(c.cap * .0525)]), () => ctl.act(() => s.buyStake(c, 5)), small: true, enabled: s.floatOf(c) > 0),
      if (own < 50.1)
        Btn(tr('TOBで{0}%（{1}・成功率{2}）', ['50.1', yen(s.tobCost(c, 50.1)), _pct0(s.tobChance(c, 50.1))]), () => ctl.act(() => s.tob(c, 50.1)), small: true),
      if (own > 50 && own < 66.7)
        Btn(tr('TOBで{0}%（{1}・成功率{2}）', ['66.7', yen(s.tobCost(c, 66.7)), _pct0(s.tobChance(c, 66.7))]), () => ctl.act(() => s.tob(c, 66.7)), small: true),
      if (s.canMerge(c)) Btn(tr('合併する（株を渡して払う）'), () => ctl.act(() => s.merge(c)), small: true, primary: true),
      if (c.parent != 'player') Btn(tr('組む'), () => openDeal(ctl, c), small: true),
      if (s.listed && c.cap <= s.cap && !(c.parent == 'player' && own >= 66.7))
        Tooltip(
          message: tr('現金の代わりに自社の株を渡して丸ごと買う。あなたの持ち株は薄まる'),
          child: Btn(tr('株式交換で丸ごと買う（成功率{0}・持ち株 {1}→{2}）', [_pct0(s.swapChance(c)), pct(s.sh.own), pct(s.sh.own * (1 - restC / (s.cap + restC)))]),
              () => ctl.act(() => s.shareSwap(c)),
              small: true),
        ),
      if (c.parent == 'player' && !c.listed && own >= 60)
        Btn(c.loc != null ? tr('{0}の市場に上場させる（30%売る・約{1}）', [cm[c.loc!]!.n, yen(c.cap * .3 * .95)]) : tr('子会社を上場させる（30%売る・約{0}）', [yen(c.cap * .3 * .95)]),
            () => ctl.act(() => s.subIPO(c)),
            small: true),
      if (c.loc != null && c.locRivPct > 0 && s.coById(c.locRiv) != null)
        Btn(tr('宿敵の持ち分を買い戻す（{0}）', [yen(s.localBuybackCost(c))]), () => ctl.act(() => s.localBuyback(c)), small: true, enabled: s.cash >= s.localBuybackCost(c)),
      if (own > 0) Btn(tr('全部売る（{0}）', [yen(c.cap * own / 100 * .95)]), () => ctl.act(() => s.sellStake(c)), small: true),
    ]),
  ]));
}

// --- 数字 ---
List<Widget> numTab(GameController ctl) {
  final s = ctl.game!;
  final own = s.biz.fold(0.0, (a, b) => a + b.profit);
  final rows = [(tr('事業の利益'), own), (tr('子会社の利益（持ち分）'), s.subP), (tr('給料'), -s.salaries()), (tr('本社の経費'), -s.hq), (tr('利息'), -s.interest), (tr('税引前の利益'), s.pre)];
  final out = <Widget>[H2(tr('今月の決算'))];
  out.add(Panel(
      child: Column(children: [
    for (var i = 0; i < rows.length; i++)
      Container(
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Pal.line))),
        child: Row(children: [
          Expanded(child: Text(rows[i].$1, style: ts(size: 13, bold: i == rows.length - 1))),
          Text(yen(rows[i].$2), style: ts(size: 13, color: rows[i].$2 < 0 ? Pal.down : Pal.ink)),
        ]),
      ),
  ])));
  out.add(H2(tr('時価総額の推移')));
  out.add(Container(
    decoration: BoxDecoration(border: Border.all(color: Pal.line), borderRadius: BorderRadius.circular(10)),
    child: AspectRatio(
        aspectRatio: 4,
        child: Semantics(label: tr('時価総額の推移'), child: CustomPaint(painter: SparkPainter(s.hist), size: Size.infinite))),
  ));
  out.add(H2(tr('売上と利益の推移（月）')));
  out.add(Container(
    decoration: BoxDecoration(border: Border.all(color: Pal.line), borderRadius: BorderRadius.circular(10)),
    child: AspectRatio(
        aspectRatio: 640 / 180,
        child: Semantics(label: tr('売上と利益の推移'), child: CustomPaint(painter: RevProfitPainter(s.hist), size: Size.infinite))),
  ));
  out.add(Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Wrap(spacing: 14, children: [
      for (final x in const [('売上', RevProfitPainter.revCol), ('利益（税引前）', RevProfitPainter.proCol), ('赤字の月', RevProfitPainter.lossCol)])
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 14, height: 3, color: x.$2),
          const SizedBox(width: 5),
          Muted(tr(x.$1), size: 12),
        ]),
    ]),
  ));
  out.add(H2(tr('世界の企業ランキング')));
  final rk = s.rankList();
  final me = rk.indexWhere((x) => x.me);
  final lines = <Widget>[
    Row(children: [
      SizedBox(width: 44, child: Muted(tr('順位'), size: 12)),
      Expanded(child: Muted(tr('会社'), size: 12)),
      Muted(tr('時価総額'), size: 12),
    ]),
  ];
  for (var i = 0; i < rk.length; i++) {
    if (!(i < 10 || (i - me).abs() <= 2)) continue;
    final x = rk[i];
    final st = ts(size: 13, color: x.me ? Pal.goldtx : Pal.ink, bold: x.me);
    lines.add(Container(
      color: x.me ? Pal.goldBg : null,
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: null,
      child: Row(children: [
        SizedBox(width: 44, child: Text('${i + 1}', style: st)),
        Expanded(child: Text('${x.me ? tx(x.name) : nmL(x.name)}${x.c != null && x.c!.rival != null ? ' ★' : ''}', style: st, overflow: TextOverflow.ellipsis)),
        Text(yen(x.cap), style: st),
      ]),
    ));
  }
  out.add(Panel(child: Column(children: lines)));
  out.add(Muted(tr('★ は宿敵'), size: 12));
  out.addAll(chronSection(s));
  return out;
}

/// 社史の色（種類ごと）
Color chronColor(String k) => switch (k) {
      'found' || 'ipo' || 'rank' || 'won' || 'swap' || 'merge' || 'buy' || 'sold' => Pal.gold,
      'over' || 'rebirth' || 'partner_out' => Pal.down,
      'era' => Pal.line,
      _ => Pal.up,
    };

/// 「数字」の下の社史（新しい順）
List<Widget> chronSection(Game s) {
  final out = <Widget>[H2(tr('社史'))];
  if (s.history.isEmpty) {
    out.add(Muted(tr('まだ記録がありません。上場・買収・海外進出などの節目がここに残ります。')));
    return out;
  }
  out.add(Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    for (final e in s.history.reversed)
      Container(
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Pal.line))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 84, child: Text(ym(e.y, e.q), style: ts(size: 12.5, color: Pal.mute))),
          Container(width: 3, height: 16, margin: const EdgeInsets.only(right: 8, top: 2), color: chronColor(e.k)),
          Expanded(child: Text(tx(e.m), style: ts(size: 13, height: 1.45))),
        ]),
      ),
  ])));
  return out;
}

// --- 図鑑 ---
List<Widget> zukanTab(GameController ctl) {
  final s = ctl.game!;
  final out = <Widget>[H2(tr('シナジー図鑑　{0} / {1}', [s.found.length, s.syns.length]))];
  out.add(Muted(tr('2つの事業を同時に持つと見つかります。見つけた組み合わせは事業の力を2割上げます。')));
  out.add(Panel(
      child: Column(children: [
    for (final x in s.syns)
      Builder(builder: (_) {
        final f = s.found[x.k];
        final hn = f == null && s.hint[x.k] != null;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Pal.line))),
          child: Row(children: [
            Expanded(
              flex: 5,
              child: f != null || hn
                  ? Text('${indm[x.a]!.name} × ${indm[x.b]!.name}', style: ts(size: 13))
                  : Muted(tr('{0}の何か × {1}の何か', [CATN[indm[x.a]!.cat], CATN[indm[x.b]!.cat]]), size: 13),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 4,
              child: f != null
                  ? Text(x.name, style: ts(size: 13, bold: true, color: Pal.goldtx))
                  : hn
                      ? Muted(tr('？？？（相性がよさそう）'), size: 13)
                      : Text(tr('？？？'), style: ts(size: 13)),
            ),
            SizedBox(width: 50, child: Text(f != null ? yearL(f) : '', textAlign: TextAlign.right, style: ts(size: 13, color: Pal.mute))),
          ]),
        );
      }),
  ])));
  out.add(H2(tr('大シナジー')));
  for (final g in s.bigs) {
    final f = s.big[g.k];
    out.add(Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(f != null ? g.name : tr('？？？'), style: ts(bold: true, color: f != null ? Pal.goldtx : Pal.mute)),
      Muted(f != null ? '${g.set.map((x) => indm[x]!.name).join(' × ')}${tr('（{0}年に完成）', [f])}' : tr('3つの業種をそろえると完成。3つとも力が4割上がる')),
    ])));
  }
  return out;
}
