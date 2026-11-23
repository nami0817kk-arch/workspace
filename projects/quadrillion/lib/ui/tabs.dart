import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/game.dart';
import 'controller.dart';
import 'guide.dart';
import 'painters.dart';
import 'sheets.dart';
import 'widgets.dart';

/// 6つのタブの中身（試作の tTown / tBiz / tPeople / tStock / tNum / tZukan）

Widget _wrap(List<Widget> c) => Wrap(spacing: 6, runSpacing: 6, children: c);
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
            child: Semantics(label: '自社のビルが並ぶ街', child: CustomPaint(painter: TownPainter(s), size: Size.infinite))),
      ),
    ),
  ));
  final nCtry = <String>{for (final b in s.biz) ...s.ctryOf(b)}.length;
  out.add(Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Row(children: [
      Expanded(
          child: Text.rich(TextSpan(children: [
        TextSpan(text: s.stageName(), style: ts(bold: true)),
        TextSpan(text: '　${cm[s.home]!.city}を拠点に${nCtry == 0 ? 1 : nCtry}か国で勝負中', style: ts(color: Pal.mute)),
      ]))),
      Tag(s.officeName(), kind: TagKind.gold),
    ]),
    _gap(),
    Grid2([
      Kv('売上（月）', yen(s.rev)),
      Kv('利益（月）', yen(s.pre)),
      Kv('事業', '${s.biz.length}つ'),
      Kv('子会社', '${s.subs().length}社'),
      Kv('部下', '${s.staff.length}人'),
      Kv('持ち株', pct(s.sh.own)),
    ]),
  ])));
  out.add(_presPanel(ctl));
  out.add(Panel(
      child: Text.rich(TextSpan(children: [TextSpan(text: '目標　', style: ts(bold: true)), TextSpan(text: s.goalText(), style: ts())]))));
  final tips = s.advice();
  if (tips.isNotEmpty) {
    out.add(Panel(
        border: Pal.gold,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('番頭のひとこと', style: ts(bold: true, color: Pal.goldtx)),
          for (final x in tips) Padding(padding: const EdgeInsets.only(top: 4), child: Text('・$x', style: ts(size: 13))),
        ])));
  }
  out.add(const H2('宿敵'));
  for (final c in s.cos.where((c) => c.rival != null && c.alive)) {
    final rel = c.rel;
    out.add(Panel(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Face(c.presName, col: c.rival!.col),
      const SizedBox(width: 10),
      Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(c.name, style: ts(bold: true))),
          Tag(RTYPE[c.rival!.label ?? c.rival!.type] ?? ''),
        ]),
        Muted('${c.presName}・${jsNum(jsRound(c.presAge))}歳　時価総額 ${yen(c.cap)}　${c.parent == 'player' ? 'あなたの子会社' : ''}'),
        Text.rich(TextSpan(style: ts(size: 12.5), children: [
          const TextSpan(text: '関係 '),
          TextSpan(
              text: relWord(rel),
              style: ts(
                  size: 12.5,
                  color: rel > 10
                      ? Pal.up
                      : rel < -10
                          ? Pal.down
                          : Pal.mute)),
          if ((s.sh.riv[c.id] ?? 0) > 0) TextSpan(text: '　あなたの株を ${pct(s.sh.riv[c.id]!)} 保有'),
        ])),
        if (c.parent != 'player') Padding(padding: const EdgeInsets.only(top: 6), child: Btn('裏の手', () => openDirty(ctl, c), small: true)),
      ])),
    ])));
  }
  out.add(const H2('最近のできごと'));
  for (final n in s.log.reversed.take(8)) {
    out.add(NewsLine(n.m, n.t, prefix: n.y != null ? '${n.y}年 ' : null));
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
        Expanded(child: Text('社長の行動', style: ts(bold: true, color: Pal.goldtx))),
        const Muted('どれも手を1つ使う', size: 12),
      ]),
      _gap(),
      if (s.biz.isEmpty) ChoiceBtn('最初の事業を決める', () => openStart(ctl), primary: true, subs: const ['最初の1つは手を使わない']),
      ChoiceBtn('相棒を探す', () => openSeek(ctl), enabled: !(n >= 2 || noAp), subs: ['株を分けて口説く。今の相棒 $n/2人']),
      ChoiceBtn('日銭を稼ぐ', () => ctl.act(() => s.presAct('work')), enabled: !noAp, subs: ['受託の仕事を受ける。約${yen(s.workIncome())}']),
      ChoiceBtn('腕を磨く', () => openTrain(ctl), enabled: !noAp, subs: const ['社長の能力を1つ伸ばす。若いほど伸びる']),
      ChoiceBtn('人脈を作る', () => ctl.act(() => s.presAct('net')), enabled: !(noAp || s.net >= 5), subs: ['借りられる額と採用の質が上がる（${s.net}/5）']),
      ChoiceBtn('事業の種を探す', () => ctl.act(() => s.presAct('scout')), enabled: !noAp, subs: const ['これから生まれる市場や、相性のよい組み合わせが分かる']),
    ]),
  );
}

// --- 事業 ---
List<Widget> bizTab(GameController ctl) {
  final s = ctl.game!;
  final out = <Widget>[const H2('自社の事業')];
  if (s.biz.isEmpty) out.add(const Panel(child: Muted('まだ事業がありません。下の「新しい事業」から始めましょう。', size: 14)));
  final y = s.yr();
  for (final b in s.biz.toList()..ssort((a, b) => b.rev.compareTo(a.rev))) {
    out.add(_bizCard(ctl, b));
  }
  out.add(const H2('新しい事業'));
  out.add(Row(children: [
    const Muted('絞り込み'),
    const SizedBox(width: 8),
    Expanded(
      child: Pick<String>(
        value: ctl.bizFilter,
        items: [('can', '今の資金で始められる'), ('new', '生まれて10年以内'), ('all', 'すべて'), for (final e in CATN.entries) (e.key, e.value)],
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
  if (list.isEmpty) out.add(const Panel(child: Muted('この条件で始められる事業はありません。', size: 14)));
  if (list.isNotEmpty) {
    out.add(Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: [
        const Expanded(child: Muted('業種', size: 12)),
        const SizedBox(width: 82, child: Align(alignment: Alignment.centerRight, child: Muted('元手', size: 12))),
        const SizedBox(width: 82, child: Align(alignment: Alignment.centerRight, child: Muted('市場（国内・月）', size: 11))),
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
                Tooltip(message: ks.map((x) => x.name).join('、'), child: const Tag('シナジー', kind: TagKind.gold)),
              if (age < 3)
                const Tag('先行者になれる', kind: TagKind.good)
              else if (age < 10)
                const Tag('新しい', kind: TagKind.good)
              else if (i.f != 0 && y > i.f)
                const Tag('沈み中', kind: TagKind.bad),
            ]),
            Muted('利益率${_pct0(i.mg)}・${ABN[i.key]}', size: 11.5),
          ]),
        ),
        SizedBox(width: 82, child: Text(yen(c), textAlign: TextAlign.right, style: ts(size: 13))),
        SizedBox(width: 82, child: Text(yen(s.mkt(i) / 3), textAlign: TextAlign.right, style: ts(size: 13))),
        SizedBox(
            width: 60,
            child: Align(
                alignment: Alignment.centerRight,
                child: Btn('始める', () => s.modelsFor(i.id).length > 1 ? openModel(ctl, i.id) : ctl.act(() => s.startBiz(i.id)),
                    small: true, enabled: s.cash >= c))),
      ]),
    ));
  }
  final soon = IND.where((i) => s.seen[i.id] != null && i.b > y).toList();
  if (soon.isNotEmpty) {
    out.add(Panel(
        child: Text.rich(TextSpan(children: [
      TextSpan(text: '近く生まれそうな市場　', style: ts(size: 12.5, bold: true, color: Pal.goldtx)),
      TextSpan(text: soon.map((i) => '${i.name}（${i.b}年ごろ）').join('・'), style: ts(size: 12.5)),
    ]))));
  }
  out.add(const H2('銀行'));
  final room = math.max(0.0, s.borrowLimit() - s.debt);
  out.add(Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('借金 ${yen(s.debt)}／借りられる上限 ${yen(room)}／利息 毎月${s.hasT('careful') ? '0.2' : '0.33'}%', style: ts(size: 13)),
    _gap(),
    _wrap([
      for (final k in const [.25, 1.0])
        Builder(builder: (_) {
          final a = math.max(0.0, (s.borrowLimit() - s.debt) * k);
          return Btn('${yen(a)} 借りる', () => ctl.act(() => s.borrow(a)), small: true, enabled: a >= 1e5);
        }),
      Btn('全部返す', () => ctl.act(() => s.repay(s.debt)), small: true, enabled: s.debt > 0),
      if (s.bond > 0)
        Muted('社債 ${yen(s.bond)}（${s.year + ((s.bondDue - s.turn + s.q - 1) / 12).floor()}年に返す）')
      else
        Btn('社債を出す', () => ctl.act(s.issueBond), small: true, enabled: s.canBond()),
      if (s.land > 0) Btn('土地を売る（今の値 ${yen(s.land)}）', () => ctl.act(s.sellLand), small: true),
    ]),
  ])));
  return out;
}

Widget _bizCard(GameController ctl, Biz b) {
  final s = ctl.game!;
  final ind = indm[b.ind]!;
  final p = s.staffById(b.mgr);
  final free = s.staff.where((x) => !s.biz.any((y) => y.mgr == x.id)).toList();
  final cs = s.competitors(b);
  final cts = s.ctryOf(b);
  Widget crewLine;
  if (b.model == 'fc') {
    crewLine = Muted('現場の人は加盟店が集めます${b.upkeep > 0 ? '　維持費 ${yen(b.upkeep)}／月' : ''}');
  } else {
    final r = b.power > 0 ? s.crewEff(b) / b.power : 1.0;
    crewLine = Text.rich(TextSpan(style: ts(size: 12.5), children: [
      TextSpan(text: '現場の力 ', style: ts(size: 12.5, color: Pal.mute)),
      TextSpan(text: '${jsNum(jsRound(r * 100))}%', style: ts(size: 12.5, bold: true, color: r < .9 ? Pal.down : Pal.up)),
      if (r < .9)
        TextSpan(text: '　人が足りず、${s.uw(b)}の一部が止まっている', style: ts(size: 12.5, color: Pal.down))
      else if (r > 1.6)
        TextSpan(text: '　人が余っている', style: ts(size: 12.5, color: Pal.mute)),
      if (b.upkeep > 0) TextSpan(text: '　維持費 ${yen(b.upkeep)}／月', style: ts(size: 12.5, color: Pal.mute)),
    ]));
  }
  final mgrItems = <(int, String)>[
    (0, '社長が直接'),
    for (final x in [?p, ...free]) (x.id, '${x.name}（${ABN[ind.key]} ${s.showAb(x, ind.key)}）'),
  ];
  return Panel(
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Text(ind.name, style: ts(bold: true))),
        Flexible(
          child: Wrap(alignment: WrapAlignment.end, spacing: 4, runSpacing: 4, children: [
            if (b.war > 0) const Tag('値下げ合戦中', kind: TagKind.bad),
            if (b.ad > 0) const Tag('広告中', kind: TagKind.good),
            if (b.early > s.turn) const Tooltip(message: '業種が生まれてすぐ始めたので、打ち手がよく効く', child: Tag('先行者', kind: TagKind.good)),
            Tag(MODELN[b.model]!, kind: TagKind.gold),
            Tag(CATN[ind.cat]!),
          ]),
        ),
      ]),
      Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Semantics(label: 'シェア', child: Bar([(b.share * 100, Pal.gold)]))),
      Grid2([
        Kv('シェア', pct(b.share * 100)),
        Kv(
            '売上',
            Text.rich(TextSpan(style: ts(size: 13), children: [
              TextSpan(text: yen(b.rev)),
              if (b.prevRev > 0)
                TextSpan(
                    text: ' ${b.rev >= b.prevRev ? '+' : ''}${jsNum(jsRound((b.rev / b.prevRev - 1) * 100))}%',
                    style: ts(size: 11.5, color: b.rev >= b.prevRev ? Pal.up : Pal.down)),
            ]))),
        Kv('利益', colored(yen(b.profit), b.profit >= 0 ? Pal.up : Pal.down)),
        Kv('効く能力', ABN[ind.key]!),
      ]),
      _gap(),
      cs.isEmpty
          ? const Muted('名のある競争相手はいません')
          : Text.rich(TextSpan(style: ts(size: 12.5), children: [
              TextSpan(text: '競っている相手 ', style: ts(size: 12.5, color: Pal.mute)),
              for (var i = 0; i < cs.length; i++) ...[
                if (i > 0) const TextSpan(text: '／'),
                TextSpan(
                    text: cs[i].c.name,
                    style: cs[i].c.rival != null ? ts(size: 12.5, bold: true, color: rivalInk(cs[i].c.rival!.col)) : null),
                TextSpan(text: ' ${pct(cs[i].share * 100)}'),
              ],
            ])),
      const SizedBox(height: 6),
      Text.rich(TextSpan(style: ts(size: 12.5), children: [
        TextSpan(text: '出ている国 ', style: ts(size: 12.5, color: Pal.mute)),
        TextSpan(text: cts.map((c) => '${cm[c]!.n}${(b.jv ?? []).contains(c) ? '（組む）' : ''}').join('・')),
        cts.length >= 5
            ? TextSpan(text: '　規模の利益 利益率＋${jsNum(jsRound(math.min(.5, (cts.length - 4) * .06) * 100))}%', style: ts(size: 12.5, color: Pal.up))
            : TextSpan(text: '　5か国以上で規模の利益', style: ts(size: 12.5, color: Pal.mute)),
      ])),
      const SizedBox(height: 6),
      crewLine,
      if (b.pipe.isNotEmpty)
        for (var i = 0; i < b.pipe.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(children: [
              Expanded(
                child: Wrap(spacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Tag(b.pipe[i].k == 'dev'
                      ? '開発中'
                      : b.pipe[i].k == 'enter'
                          ? '進出準備'
                          : '建設中'),
                  Text(
                      '${b.pipe[i].k == 'dev' ? '新商品' : b.pipe[i].k == 'enter' ? '${cm[b.pipe[i].c]!.n}（${ENTRYN[b.pipe[i].mode]}）' : s.uw(b)}（${yen(b.pipe[i].cost)}）あと${b.pipe[i].left}か月',
                      style: ts(size: 12.5)),
                ]),
              ),
              Btn('取り下げる（半分戻る）', () {
                final idx = i;
                ctl.act(() => s.cancelPipe(b, idx));
              }, small: true),
            ]),
          ),
      _gap(),
      Row(children: [
        const Muted('責任者'),
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
        const Muted('値付け'),
        const SizedBox(width: 6),
        Expanded(
          child: Pick<String>(
            value: b.price,
            items: const [('cut', '安く（客は増えるが利益が薄い）'), ('normal', 'ふつう'), ('premium', '高く（利益は厚いが客が減る）')],
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
        Btn('商品を作る ${yen(s.cash * .3)}', () => ctl.act(() => s.develop(b, .3), mark: 'act'), small: true, enabled: s.cash > 0),
        Btn('${s.uw(b)}を増やす ${yen(s.cash * .3)}', () => ctl.act(() => s.build(b, .3), mark: 'act'), small: true, enabled: s.cash > 0),
        Btn('大きく増やす ${yen(s.cash * .6)}', () => ctl.act(() => s.build(b, .6), mark: 'act'), small: true, enabled: s.cash > 0),
        Btn('現場の人を増やす ${yen(s.cash * .2)}', () => ctl.act(() => s.addCrew(b, .2), mark: 'act'), small: true, enabled: s.cash > 0),
        Btn('広告 ${yen(s.invBase(b) * .25)}', () => ctl.act(() => s.adv(b), mark: 'act'), small: true),
        if (cs.isNotEmpty)
          Btn(b.attack > 0 ? '値下げ合戦中（あと${b.attack}期）' : '値下げ合戦を仕掛ける（相手：${cs[0].c.name}）', () => ctl.act(() => s.priceWar(b), mark: 'act'),
              small: true, enabled: b.attack <= 0),
        Btn('海外に出る', () => openEnter(ctl, b), small: true),
        Btn('分社・独立', () => openShape(ctl, b), small: true),
        if (!s.inAssoc(b.ind) && cs.isNotEmpty) Btn('業界団体に入る', () => ctl.act(() => s.joinAssoc(b), mark: 'act'), small: true),
        if (s.modelsFor(b.ind).length > 1) Btn('稼ぎ方を変える', () => openModel(ctl, b.ind, b), small: true),
        if (s.pivotTargets(b).isNotEmpty) Btn('業態を変える', () => openPivot(ctl, b), small: true),
        Btn('売る（約${yen(s.sellValue(b))}）',
            () => actConfirmed(ctl, '「${ind.name}」を売る', '「${ind.name}」を約${yen(s.sellValue(b))}で手放します。育てた力は戻りません。', '売る', () => s.sellBiz(b)),
            small: true),
      ]),
    ]),
  );
}

// --- 人 ---
List<Widget> peopleTab(GameController ctl) {
  final s = ctl.game!;
  final P = s.pres;
  final out = <Widget>[const H2('社長')];
  out.add(Panel(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Face(P.name, col: '#f2c14e'),
    const SizedBox(width: 10),
    Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('${P.name}（${P.age}歳）', style: ts(bold: true)),
      const SizedBox(height: 6),
      Grid2([for (final k in abKeys) Kv(ABN[k]!, '${P.ab[k]}')]),
      for (final t in P.traits)
        Builder(builder: (_) {
          final T = TRAITS.firstWhere((x) => x.id == t, orElse: () => STRAITS.firstWhere((x) => x.id == t));
          return Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(spacing: 4, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Tag(T.n, kind: TagKind.gold),
              colored('＋${T.g}', Pal.up, size: 12.5),
              colored('－${T.b}', Pal.down, size: 12.5),
            ]),
          );
        }),
      const SizedBox(height: 8),
      Text('自分で見られる事業は${s.presCap()}つまで。${P.age >= 55 ? 'そろそろ後継ぎを考える年です。' : ''}', style: ts(size: 12.5)),
    ])),
  ])));
  final cu = CULT[s.culture]!;
  out.add(Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Expanded(child: Text('社風', style: ts(bold: true))), Tag(cu.n, kind: TagKind.gold)]),
    const SizedBox(height: 4),
    Wrap(spacing: 8, children: [colored('＋${cu.g}', Pal.up, size: 12.5), colored('－${cu.b}', Pal.down, size: 12.5)]),
    const SizedBox(height: 6),
    if (s.cultLeft > 0)
      Muted('「${CULT[s.cultNext]!.n}」に切り替え中（あと${s.cultLeft}か月）')
    else
      _wrap([
        for (final k in CULT.keys.where((k) => k != s.culture))
          Tooltip(message: '＋${CULT[k]!.g}／－${CULT[k]!.b}', child: Btn('${CULT[k]!.n}にする', () => ctl.act(() => s.changeCulture(k)), small: true)),
      ]),
  ])));
  final succs = [...s.staff, ...s.kids.where((k) => k.age >= 18)];
  out.add(Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Text('後継ぎ', style: ts(bold: true)),
    const SizedBox(height: 6),
    Row(children: [
      const Muted('候補'),
      const SizedBox(width: 6),
      Expanded(
        child: Pick<int>(
          value: s.succ ?? 0,
          items: [(0, 'まだ決めていない'), for (final p in succs) (p.id, '${p.name}（${p.kid ? '子ども・' : ''}${p.age}歳）')],
          onChanged: (v) {
            s.choosePresSucc(v == 0 ? null : v);
            ctl.save();
            ctl.render();
          },
        ),
      ),
      const SizedBox(width: 6),
      Btn('引退して譲る', () => ctl.act(s.retire), small: true, enabled: s.succ != null),
    ]),
    for (final k in s.kids)
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(children: [
          Expanded(child: Muted('子ども ${Game.givenOf(k.name)}（${k.age}歳）')),
          k.age >= 22 ? Btn('入社させる', () => ctl.act(() => s.kidJoin(k)), small: true) : const Muted('22歳で入社できる'),
        ]),
      ),
  ])));
  out.add(H2('部下（${s.staff.length}人）'));
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
          Text('${p.name}（${p.age}歳）', style: ts(bold: true)),
          if (p.partner) Tag('相棒・株${pct(p.stake)}', kind: TagKind.gold),
          if (p.auto) const Tag('提案はまかせている', kind: TagKind.good),
          Muted(job != null ? '${indm[job.ind]!.name}の責任者' : '担当なし'),
        ]),
        const SizedBox(height: 4),
        Grid2([for (final k in abKeys) Kv(ABN[k]!, s.showAb(p, k))]),
        const SizedBox(height: 4),
        Wrap(spacing: 4, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('特性', style: ts(size: 12.5)),
          if (p.traitKnown) ...[Tag(t.n), colored('＋${t.g}', Pal.up, size: 12.5), colored('－${t.b}', Pal.down, size: 12.5)] else const Muted('？（働かせると分かる）'),
          Text('　野心', style: ts(size: 12.5)),
          p.ambKnown
              ? colored(
                  p.amb > 70
                      ? '強い'
                      : p.amb > 40
                          ? 'ふつう'
                          : '弱い',
                  p.amb > 70 ? Pal.down : Pal.ink,
                  size: 12.5)
              : const Muted('？'),
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Muted('給料 ${yen(p.salary * (s.hasT('frugal') ? .7 : 1))}／月'),
          if (p.auto)
            Btn('まかせるのをやめる', () {
              p.auto = false;
              ctl.save();
              ctl.render();
            }, small: true),
          Btn(
              p.partner ? '相棒と別れる' : '解雇',
              () => p.partner
                  ? actConfirmed(ctl, '相棒と別れる', '${p.name}は会社を去り、持っている株${pct(p.stake)}は${s.listed ? '市場で売られます' : '投資家の手に渡ります'}。', '別れる', () => s.dismiss(p))
                  : actConfirmed(ctl, '解雇', '${p.name}を解雇します。もう呼び戻せません。', '解雇する', () => s.dismiss(p)),
              small: true),
        ]),
      ])),
    ])));
  }
  out.add(const H2('採用の候補'));
  out.add(const Muted('面接で分かるのは能力の幅だけです。働かせると本当の値と特性が見えてきます。'));
  for (final p in s.cands) {
    out.add(Panel(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Face(p.name),
      const SizedBox(width: 10),
      Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${p.name}（${p.age}歳）', style: ts(bold: true)),
        const SizedBox(height: 4),
        Grid2([for (final k in abKeys) Kv(ABN[k]!, s.showAb(p, k))]),
        const SizedBox(height: 4),
        p.traitKnown ? Text('特性 ${STRAITS.firstWhere((x) => x.id == p.trait).n}', style: ts(size: 12.5)) : Muted('評判：${traitHints[p.trait]}'),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: Muted('給料 ${yen(p.salary)}／月・支度金 ${yen(p.salary * 2)}')),
          Btn('雇う', () => ctl.act(() => s.hire(p)), small: true),
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
  final out = <Widget>[const H2('あなたの会社の株主')];
  final parts = <(String, double, Color)>[
    ('あなた', sh.own, Pal.gold),
    ('相棒', sh.pt, const Color(0xFFFFB454)),
    ('投資家', sh.vc, const Color(0xFF9FB3FF)),
    ('味方', sh.ally, Pal.teal),
    ('市場', sh.float, const Color(0xFF55618F)),
  ];
  for (final e in sh.riv.entries) {
    if (e.value > 0) parts.add((s.coById(e.key)?.name ?? '?', e.value, Pal.down));
  }
  out.add(Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Bar([for (final p in parts) (p.$2, p.$3)], height: 14),
    _gap(),
    Grid2([for (final p in parts.where((p) => p.$2 > .05)) Kv(p.$1, pct(p.$2))]),
    const SizedBox(height: 6),
    const Muted('5%で相手に知られる／33.4%で合併を止められる／50%超で社長を替えられる／66.7%で合併も自由'),
  ])));
  out.add(Panel(
    child: s.listed
        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('上場済み', style: ts(bold: true)),
            const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Muted('誰でもあなたの株を買えます。乗っ取りに注意。')),
            _wrap([
              Btn('増資で集める（${yen(s.cap * .095)}・全員の割合−9%）', () => ctl.act(s.publicOffer), small: true),
              Btn('自社株買い 5%（約${yen(s.cap * .0575)}）', () => ctl.act(s.buybackAct), small: true, enabled: sh.float >= 1),
              Btn('ホワイトナイトを頼む', () => ctl.act(s.whiteKnightAct), small: true),
            ]),
          ])
        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('未上場', style: ts(bold: true)),
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Muted('上場すると大金が入るが、宿敵があなたの株を買えるようになる。条件：年の利益 ${yen(3e8 * s.nom())} 以上・創業2年以上')),
            _wrap([
              Btn('投資家から集める（${yen(s.cap * .1)}・持ち株−10%）', () => ctl.act(s.vcRaise), small: true),
              Btn('上場する', () => ctl.act(s.ipo), small: true, enabled: s.canIPO()),
            ]),
          ]),
  ));
  if (s.deals.isNotEmpty) {
    out.add(const H2('組んでいる相手'));
    for (final d in s.deals.toList()) {
      final c = s.coById(d.co);
      if (c == null) continue;
      out.add(Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(c.name, style: ts(bold: true))),
          Tag('${DEALN[d.type]}${d.ind != null ? '：${indm[d.ind]!.name}' : ''}', kind: TagKind.good),
        ]),
        Muted(
            '${d.since}年から　関係 ${c.rel > 25 ? '友好' : c.rel > 10 ? 'やや良い' : c.rel < -10 ? '警戒' : 'ふつう'}'),
        const SizedBox(height: 6),
        _wrap([
          Btn('解消する', () => ctl.act(() => s.endDeal(d)), small: true),
          if (d.type != 'assoc')
            Tooltip(message: '相手の客を奪う。相手は激怒し、業界の評判も落ちる', child: Btn('裏切る', () => ctl.act(() => s.betray(d)), small: true)),
        ]),
      ])));
    }
  }
  out.add(const H2('会社の形'));
  out.add(Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Expanded(child: Text(s.holding ? '持株会社' : 'ふつうの会社', style: ts(bold: s.holding))),
      if (!s.holding) Btn('持株会社にする', () => ctl.act(s.makeHolding), small: true, enabled: s.biz.length + s.subs().length >= 5),
    ]),
    const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Muted('持株会社は、社長が直接見られる事業の上限がなくなります。事業は「事業」の画面から、分社（子会社にする）や、責任者に渡して独立させることもできます。')),
    if (s.listed && s.biz.length >= 2)
      _wrap([
        const Muted('会社を2つに割る：'),
        for (final cat in <String>{for (final b in s.biz) indm[b.ind]!.cat})
          Btn('${CATN[cat]}を切り離す', () => ctl.act(() => s.splitCompany(cat)), small: true),
      ]),
  ])));
  out.add(const H2('売り抜け'));
  out.add(Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Muted('勝ち負けは「今の会社の時価総額＋あなたの財産」で測ります。今の財産 ${yen(s.wealth)}'),
    const SizedBox(height: 6),
    _wrap([
      if (s.listed) Btn('持ち株を5%売る（約${yen(s.cap * .045)}）', () => ctl.act(() => s.sellOwn(5)), small: true),
      if (s.listed) Btn('非上場に戻す（MBO）', () => ctl.act(s.goPrivate), small: true),
      Btn('会社を丸ごと売る', () => openSell(ctl), small: true, enabled: s.biz.isNotEmpty && s.buyers().isNotEmpty),
      if (s.noncomp != null && !s.noncomp!.broken)
        Tooltip(message: '2年後に裁判で賠償を求められる', child: Btn('同じ業種に入らない約束を破る', () => ctl.act(s.breakNoncomp), small: true)),
    ]),
  ])));
  final mine = s.cos.where((c) => c.alive && s.pctOf(c) > 0).toList();
  if (mine.isNotEmpty) {
    out.add(const H2('持っている他社の株'));
    for (final c in mine) {
      out.add(_coCard(ctl, c));
    }
  }
  out.add(const H2('買える会社'));
  out.add(const Muted('時価総額の小さい順に、あなたのいる業種の会社を先に並べています。'));
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
      Expanded(child: Text(c.name, style: ts(bold: true))),
      if (c.parent == 'player') ...[const Tag('子会社', kind: TagKind.gold), const SizedBox(width: 4)],
      Tag(c.rival != null ? RTYPE[c.rival!.label ?? c.rival!.type] ?? '' : REGN[c.tier]),
    ]),
    Muted(c.biz.map((b) => indm[b.ind]!.name).join('・')),
    const SizedBox(height: 6),
    Grid2([
      Kv('時価総額', yen(c.cap)),
      Kv('月の利益', yen(c.profit)),
      Kv('創業家', pct(c.fam)),
      Kv('社風', CULT[s.cultureOf(c)]!.n),
      Kv('市場の株', pct(s.floatOf(c))),
      if (own > 0) Kv('あなた', pct(own)),
    ]),
    _gap(),
    _wrap([
      Btn('市場で5%買う（${yen(c.cap * .0525)}）', () => ctl.act(() => s.buyStake(c, 5)), small: true, enabled: s.floatOf(c) > 0),
      if (own < 50.1)
        Btn('TOBで50.1%（${yen(s.tobCost(c, 50.1))}・成功率${_pct0(s.tobChance(c, 50.1))}）', () => ctl.act(() => s.tob(c, 50.1)), small: true),
      if (own > 50 && own < 66.7)
        Btn('TOBで66.7%（${yen(s.tobCost(c, 66.7))}・成功率${_pct0(s.tobChance(c, 66.7))}）', () => ctl.act(() => s.tob(c, 66.7)), small: true),
      if (s.canMerge(c)) Btn('合併する（株を渡して払う）', () => ctl.act(() => s.merge(c)), small: true, primary: true),
      if (c.parent != 'player') Btn('組む', () => openDeal(ctl, c), small: true),
      if (s.listed && c.cap <= s.cap && !(c.parent == 'player' && own >= 66.7))
        Tooltip(
          message: '現金の代わりに自社の株を渡して丸ごと買う。あなたの持ち株は薄まる',
          child: Btn('株式交換で丸ごと買う（成功率${_pct0(s.swapChance(c))}・持ち株 ${pct(s.sh.own)}→${pct(s.sh.own * (1 - restC / (s.cap + restC)))}）',
              () => ctl.act(() => s.shareSwap(c)),
              small: true),
        ),
      if (c.parent == 'player' && !c.listed && own >= 60) Btn('子会社を上場させる（30%売る・約${yen(c.cap * .3 * .95)}）', () => ctl.act(() => s.subIPO(c)), small: true),
      if (own > 0) Btn('全部売る（${yen(c.cap * own / 100 * .95)}）', () => ctl.act(() => s.sellStake(c)), small: true),
    ]),
  ]));
}

// --- 数字 ---
List<Widget> numTab(GameController ctl) {
  final s = ctl.game!;
  final own = s.biz.fold(0.0, (a, b) => a + b.profit);
  final rows = [('事業の利益', own), ('子会社の利益（持ち分）', s.subP), ('給料', -s.salaries()), ('本社の経費', -s.hq), ('利息', -s.interest), ('税引前の利益', s.pre)];
  final out = <Widget>[const H2('今月の決算')];
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
  out.add(const H2('時価総額の推移'));
  out.add(Container(
    decoration: BoxDecoration(border: Border.all(color: Pal.line), borderRadius: BorderRadius.circular(10)),
    child: AspectRatio(
        aspectRatio: 4,
        child: Semantics(label: '時価総額の推移', child: CustomPaint(painter: SparkPainter(s.hist), size: Size.infinite))),
  ));
  out.add(const H2('世界の企業ランキング'));
  final rk = s.rankList();
  final me = rk.indexWhere((x) => x.me);
  final lines = <Widget>[
    Row(children: [
      const SizedBox(width: 44, child: Muted('順位', size: 12)),
      const Expanded(child: Muted('会社', size: 12)),
      const Muted('時価総額', size: 12),
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
        Expanded(child: Text('${x.name}${x.c != null && x.c!.rival != null ? ' ★' : ''}', style: st, overflow: TextOverflow.ellipsis)),
        Text(yen(x.cap), style: st),
      ]),
    ));
  }
  out.add(Panel(child: Column(children: lines)));
  out.add(const Muted('★ は宿敵', size: 12));
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
  final out = <Widget>[const H2('社史')];
  if (s.history.isEmpty) {
    out.add(const Muted('まだ記録がありません。上場・買収・海外進出などの節目がここに残ります。'));
    return out;
  }
  out.add(Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    for (final e in s.history.reversed)
      Container(
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Pal.line))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 84, child: Text('${e.y}年${e.q}月', style: ts(size: 12.5, color: Pal.mute))),
          Container(width: 3, height: 16, margin: const EdgeInsets.only(right: 8, top: 2), color: chronColor(e.k)),
          Expanded(child: Text(e.m, style: ts(size: 13, height: 1.45))),
        ]),
      ),
  ])));
  return out;
}

// --- 図鑑 ---
List<Widget> zukanTab(GameController ctl) {
  final s = ctl.game!;
  final out = <Widget>[H2('シナジー図鑑　${s.found.length} / ${SYN.length}')];
  out.add(const Muted('2つの事業を同時に持つと見つかります。見つけた組み合わせは事業の力を2割上げます。'));
  out.add(Panel(
      child: Column(children: [
    for (final x in SYN)
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
                  : Muted('${CATN[indm[x.a]!.cat]}の何か × ${CATN[indm[x.b]!.cat]}の何か', size: 13),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 4,
              child: f != null
                  ? Text(x.name, style: ts(size: 13, bold: true, color: Pal.goldtx))
                  : hn
                      ? const Muted('？？？（相性がよさそう）', size: 13)
                      : Text('？？？', style: ts(size: 13)),
            ),
            SizedBox(width: 50, child: Text(f != null ? '$f年' : '', textAlign: TextAlign.right, style: ts(size: 13, color: Pal.mute))),
          ]),
        );
      }),
  ])));
  out.add(const H2('大シナジー'));
  for (final g in BIG) {
    final f = s.big[g.k];
    out.add(Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(f != null ? g.name : '？？？', style: ts(bold: true, color: f != null ? Pal.goldtx : Pal.mute)),
      Muted(f != null ? '${g.set.map((x) => indm[x]!.name).join(' × ')}（$f年に完成）' : '3つの業種をそろえると完成。3つとも力が4割上がる'),
    ])));
  }
  return out;
}
