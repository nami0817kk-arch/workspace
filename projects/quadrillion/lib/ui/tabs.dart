import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/game.dart';
import 'controller.dart';
import 'glossary.dart';
import 'guide.dart';
import 'painters.dart';
import 'sheets.dart';
import 'widgets.dart';

/// 6つのタブの中身（試作の tTown / tBiz / tPeople / tStock / tNum / tZukan）

// ボタンは押せる範囲が 44pt あるので、行のあいだは空けない（見た目の隙間はその余白で足りる）
Widget _wrap(List<Widget> c) => Wrap(spacing: 6, runSpacing: 0, children: c);

/// 手を使うボタン。使う数の札（「1手」）を付け、手が足りなければ薄くして、押すと「今月の手が残っていません」を出す
Widget _apBtn(GameController ctl, String label, VoidCallback onTap, {int ap = 1, bool enabled = true, bool primary = false, bool more = false}) {
  final short = !ctl.game!.canAP(ap);
  return Btn(label, () {
    if (!ctl.noAp(ap)) onTap();
    // 1行に収め、入りきらないときは字だけを詰める。英語は語の途中で折れず2行になりやすく、
    // 日本語も幅320では「TOBで50.1%（…・成功率…）」のような長いものが2行に折れていた（1.0.0+17）
  }, small: true, ap: ap, dim: short, enabled: enabled, primary: primary, more: more, shrink: true);
}
Widget _gap([double h = 8]) => SizedBox(height: h);
String _pct0(double v) => '${jsNum(jsRound(v * 100))}%';

// --- 街 ---
List<Widget> townTab(GameController ctl) {
  final s = ctl.game!;
  final out = <Widget>[];
  // 上から：今月やること → 街の絵 → 会社の数字 → 社長の行動 → 宿敵 → 最近のできごと
  final todo = todoCard(ctl);
  if (todo != null) out.add(Padding(padding: const EdgeInsets.only(top: 6), child: todo));
  out.add(Padding(
    padding: EdgeInsets.only(top: todo != null ? 4 : 10, bottom: 4),
    child: Frame(
      key: const ValueKey('town-picture'),
      child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Semantics(label: tr('自社のビルが並ぶ街'), image: true, child: RepaintBoundary(child: CustomPaint(painter: TownPainter(s), size: Size.infinite)))),
    ),
  ));
  final nCtry = <String>{for (final b in s.biz) ...s.ctryOf(b)}.length;
  out.add(Panel(
      key: const ValueKey('town-company'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    // 会社の段階と拠点の文の右に、事務所の札。並べて入りきらないとき（英語の長い札・大きい字）は、札を次の行に回す
    // （横に並べたままだと、札が文の幅を食いつぶして、文が1字ずつ縦に折れる）
    LayoutBuilder(
        builder: (context, c) => Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 4, children: [
              Text.rich(
                  key: const ValueKey('town-stage'),
                  TextSpan(children: [
                    TextSpan(text: tx(s.stageName()), style: ts(bold: true)),
                    TextSpan(text: tr('　{0}を拠点に{1}か国で勝負中', [cm[s.home]!.city, nCtry == 0 ? 1 : nCtry]), style: ts(color: Pal.mute)),
                  ])),
              ConstrainedBox(constraints: BoxConstraints(maxWidth: c.maxWidth), child: Tag(s.officeName(), key: const ValueKey('town-office'), kind: TagKind.gold)),
            ])),
    _gap(),
    Grid2([
      Kv(tr('月の売上'), yen(s.rev)),
      Kv(tr('月の利益'), yen(s.pre)),
      Kv(tr('事業'), tr('{0}つ', [s.biz.length])),
      Kv(tr('子会社'), tr('{0}社', [s.subs().length])),
      Kv(tr('部下'), tr('{0}人', [s.staff.length])),
      Kv(tr('持ち株'), pct(s.sh.own)),
    ]),
    // 目標は会社の数字の下に添える
    Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.only(top: 8),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Pal.line))),
      child: Text.rich(TextSpan(children: [TextSpan(text: tr('目標　'), style: ts(size: 13, bold: true)), TextSpan(text: tx(s.goalText()), style: ts(size: 13))])),
    ),
  ])));
  final vow = s.vow;
  if (vow != null) {
    out.add(Panel(
        border: Pal.down,
        child: Text(tr('取締役会との約束：{0}年1月までに、年の利益を{1}まで戻す', [vow['y']!.round(), yen(vow['target']!)]), style: ts(size: 13))));
  }
  out.add(_presPanel(ctl));
  // 宿敵：見出しを押すとたためる。1人1行の要約で、押すと因縁と「裏の手」が開く
  final rivals = s.cos.where((c) => c.rival != null && c.alive).toList();
  final rivOpen = !ctl.folded.contains('rivals');
  out.add(FoldHead(tr('宿敵'), key: const ValueKey('fold-rivals'), open: rivOpen, onTap: () => ctl.toggleFold('rivals'), note: tr('{0}社', [rivals.length])));
  if (rivOpen) {
    if (rivals.isEmpty) out.add(Muted(tr('まだ宿敵はいません。同じ業種でぶつかると現れます。')));
    for (final c in rivals) {
      out.add(ctl.openRival == c.id ? _rivalCard(ctl, c) : _rivalRow(ctl, c));
    }
  }
  final newsOpen = !ctl.folded.contains('news');
  final recent = s.log.reversed.take(8).toList();
  out.add(FoldHead(tr('最近のできごと'), key: const ValueKey('fold-news'), open: newsOpen, onTap: () => ctl.toggleFold('news'), note: tr('{0}件', [recent.length])));
  if (newsOpen) {
    for (final n in recent) {
      out.add(NewsLine(n.m, n.t, prefix: n.y != null ? '${yearL(n.y!)} ' : null, icon: newsIcon(s, n)));
    }
  }
  return out;
}

/// 「今月やること」：はじめの案内と番頭のひとことを1つの欄にまとめる（合わせて3つまで）。出すものが無ければ null。
/// ひとことは2行までに切り、右上の「番頭のひとこと」から全部を小窓で読める
Widget? todoCard(GameController ctl) {
  final s = ctl.game!;
  final step = currentGuide(s);
  final tips = s.advice().take(step != null ? todoMax - 1 : todoMax).toList();
  if (step == null && tips.isEmpty) return null;
  return Panel(
    key: const ValueKey('todo'),
    border: Pal.gold,
    padding: const EdgeInsets.fromLTRB(Ui.pad, 2, 4, 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: CardTitle(tr('今月やること'), gold: true)),
        if (tips.isNotEmpty)
          InkWell(
            key: const ValueKey('todo-all'),
            borderRadius: BorderRadius.circular(Ui.rBtn),
            onTap: () => openAdvice(ctl),
            child: Container(
              constraints: const BoxConstraints(minHeight: minTap, minWidth: minTap),
              padding: const EdgeInsets.only(left: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(tr('番頭のひとこと'), style: ts(size: 12, color: Pal.goldtx)),
                const Icon(Icons.chevron_right, size: 18, color: Pal.goldtx),
              ]),
            ),
          )
        else
          const SizedBox(height: minTap),
      ]),
      if (step != null) GuideBar(ctl: ctl, step: step),
      for (final x in tips)
        Padding(
          padding: const EdgeInsets.only(top: 3, right: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(padding: EdgeInsets.only(top: 3, right: 6), child: Icon(Icons.lightbulb_outline, size: 15, color: Pal.goldtx)),
            Expanded(child: Text(tx(x), key: const ValueKey('todo-tip'), maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(size: 13, height: 1.4))),
          ]),
        ),
    ]),
  );
}

/// 「今月やること」に並べる数の上限（案内とひとことを合わせて）
const todoMax = 3;

/// 宿敵との関係の色
Color _relColor(int rel) => rel > 10
    ? Pal.up
    : rel < -10
        ? Pal.down
        : Pal.mute;

/// 宿敵の要約の文（時価総額・関係・あなたの株の持ち分）
TextSpan _rivalFacts(Game s, Company c) {
  final own = s.sh.riv[c.id] ?? 0;
  return TextSpan(style: ts(size: 12.5, color: Pal.mute), children: [
    TextSpan(text: tr('時価総額 {0}', [yen(c.cap)])),
    TextSpan(text: tr('・関係 ')),
    TextSpan(text: tx(relWord(c.rel)), style: ts(size: 12.5, color: _relColor(c.rel), bold: true)),
    if (c.parent == 'player')
      TextSpan(text: '${tr('・')}${tr('あなたの子会社')}')
    else if (own > 0)
      TextSpan(text: tr('・あなたの株 {0}', [pct(own)]), style: ts(size: 12.5, color: Pal.down, bold: true)),
  ]);
}

/// たたんだ宿敵の1行（名前・型・時価総額・関係・あなたの株の持ち分）。押すと因縁と「裏の手」が開く
Widget _rivalRow(GameController ctl, Company c) {
  final s = ctl.game!;
  return TapCard(
    inkKey: ValueKey('rival-row-${c.id}'),
    expanded: false,
    onTap: () => ctl.toggleRival(c.id),
    child: Container(
      constraints: const BoxConstraints(minHeight: minTap),
      padding: const EdgeInsets.fromLTRB(12, 7, 6, 7),
      child: Row(children: [
        Face.rival(c.presName, c.rival!.col),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(nmL(c.name), style: ts(size: 14, bold: true)),
              Tag(RTYPE[c.rival!.label ?? c.rival!.type] ?? ''),
            ]),
            const SizedBox(height: 2),
            Text.rich(_rivalFacts(s, c)),
          ]),
        ),
        const Icon(Icons.expand_more, size: 22, color: Pal.mute),
      ]),
    ),
  );
}

/// 開いた宿敵のカード（要約に、社長・因縁・最近のいきさつ・「裏の手」を足す）。名前の行を押すとたたむ
Widget _rivalCard(GameController ctl, Company c) {
  final s = ctl.game!;
  final r = c.rival!;
  return Panel(
    border: Pal.gold,
    padding: const EdgeInsets.fromLTRB(12, 2, 6, 10),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      FoldRow(
        inkKey: ValueKey('rival-fold-${c.id}'),
        onTap: () => ctl.toggleRival(c.id),
        child: Container(
          constraints: const BoxConstraints(minHeight: minTap),
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Face.rival(c.presName, r.col),
            const SizedBox(width: 10),
            Expanded(
              child: Wrap(spacing: 6, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(nmL(c.name), style: ts(size: 14, bold: true)),
                Tag(RTYPE[r.label ?? r.type] ?? ''),
              ]),
            ),
            const Icon(Icons.expand_less, size: 22, color: Pal.mute),
          ]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Muted(tr('社長 {0}（{1}歳）', [nmL(c.presName), jsNum(jsRound(c.presAge))])),
          const SizedBox(height: 2),
          Text.rich(_rivalFacts(s, c)),
          const SizedBox(height: 6),
          Text.rich(TextSpan(style: ts(size: 12.5), children: [
            TextSpan(text: tr('因縁 '), style: ts(size: 12.5, color: Pal.mute)),
            TextSpan(text: tx(s.storyStage(r)), style: ts(size: 12.5, bold: true)),
            if (r.st > 0) TextSpan(text: tr('　恨み {0}・恩 {1}・されたこと {2}', [r.grudge, r.favor, r.hurt])),
          ])),
          for (final t in r.ties.reversed.take(3)) Padding(padding: const EdgeInsets.only(top: 2), child: Muted('${tr('・@@bullet')}${tx(t)}', size: 12)),
          if (c.parent != 'player') Padding(padding: const EdgeInsets.only(top: 4), child: _apBtn(ctl, tr('裏の手'), () => openDirty(ctl, c), more: true)),
        ]),
      ),
    ]),
  );
}

Widget _presPanel(GameController ctl) {
  final s = ctl.game!;
  final n = s.partners().length;
  final noAp = s.ap < 1;
  // 手が残っていないときは薄く見せ、押すと「今月の手が残っていません」を出す
  VoidCallback go(VoidCallback f) => () {
        if (!ctl.noAp()) f();
      };
  return Panel(
    key: const ValueKey('town-pres'),
    border: Pal.gold,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        // 見出しは切らず、右の注意書きは残りの幅に収める（入りきらなければ折り返す。「i」は押せる所に残る）
        CardTitle(tr('社長の行動'), gold: true),
        const SizedBox(width: 8),
        Expanded(child: Text(tr('どれも手を1つ使う'), textAlign: TextAlign.right, style: ts(size: 12, color: Pal.mute))),
        Info(ctl, const ['ap']),
      ]),
      if (s.biz.isEmpty) ChoiceBtn(tr('最初の事業を決める'), () => openStart(ctl), primary: true, subs: [tr('最初の1つは手を使わない')]),
      ChoiceBtn(tr('相棒を探す'), go(() => openSeek(ctl)), enabled: n < 2, dim: noAp, ap: 1, subs: [tr('株を分けて口説く。今の相棒 {0}/2人', [n])]),
      ChoiceBtn(tr('日銭を稼ぐ'), go(() => ctl.act(() => s.presAct('work'))), dim: noAp, ap: 1, subs: [tr('受託の仕事を受ける。約{0}', [yen(s.workIncome())])]),
      ChoiceBtn(tr('腕を磨く'), go(() => openTrain(ctl)), dim: noAp, ap: 1, subs: [tr('社長の能力を1つ伸ばす。若いほど伸びる')]),
      ChoiceBtn(tr('人脈を作る'), go(() => ctl.act(() => s.presAct('net'))), enabled: s.net < 5, dim: noAp, ap: 1, subs: [tr('借りられる額と採用の質が上がる（{0}/5）', [s.net])]),
      ChoiceBtn(tr('事業の種を探す'), go(() => ctl.act(() => s.presAct('scout'))), dim: noAp, ap: 1, subs: [tr('これから生まれる市場や、相性のよい組み合わせが分かる')]),
    ]),
  );
}

// --- 事業 ---
/// 新しい事業の一覧の並べ替え（id・名前）
const bizSorts = [('cost', '元手の安い順'), ('market', '市場の大きい順'), ('new', '生まれたばかり順'), ('margin', '利益率の高い順')];

/// 新しい事業の一覧の絞り込み（このあとに分類が続く）
const bizFilters = [('all', 'すべて'), ('can', '今の資金で始められる'), ('new', '生まれて10年以内')];

/// 一覧の数字の列と「始める」の列の幅（字が大きい設定では、そのぶん広げる）
double get _colW => Ui.sw(78);
double get _startW => Ui.sw(72);

/// 新しい事業の一覧を、幅の狭い並び（市場の列を名前の下の行に回す）にするか。
/// 幅320の画面と、業種名の長い英語（幅390まで）で使う。字が大きい設定では、そのぶん幅が狭いものとして決める
bool narrowBizList(double width) => width / Ui.textScale < 340 || (L.en && width / Ui.textScale < 400);

/// 新しい事業の一覧（まだ持っていない、今ある業種）。[filter] で絞り、[query]（名前の一部。日本語でも英語でも）で絞り、[sort] で並べる。
/// 見るだけで、仕組みの数字も乱数も動かさない
List<Industry> newBizList(Game s, {String filter = 'all', String sort = 'cost', String query = ''}) {
  final y = s.yr();
  final q = query.trim().toLowerCase();
  bool hit(Industry i) => q.isEmpty || i.ja.toLowerCase().contains(q) || (enText(i.ja) ?? '').toLowerCase().contains(q);
  final list = s
      .liveInds()
      .where((i) => !s.biz.any((b) => b.ind == i.id))
      .where((i) => switch (filter) {
            'all' => true,
            'can' => s.capexOf(i) <= s.cash,
            'new' => y - i.b < 10,
            _ => i.cat == filter,
          })
      .where(hit)
      .toList()
    ..ssort((a, b) => s.capexOf(a).compareTo(s.capexOf(b)));
  // 元手の安い順に並べたうえで、選んだ順に並べ直す（同じ値どうしは元手の安い順のまま）
  switch (sort) {
    case 'market':
      final m = {for (final i in list) i.id: s.mkt(i)};
      list.ssort((a, b) => m[b.id]!.compareTo(m[a.id]!));
    case 'new':
      list.ssort((a, b) => b.b.compareTo(a.b));
    case 'margin':
      list.ssort((a, b) => b.mg.compareTo(a.mg));
  }
  return list;
}

/// 新しい事業の一覧を分類で絞る小窓（分類ごとに、今ある・まだ持っていない業種の数を添える）
void openCatPick(GameController ctl) {
  final s = ctl.game!;
  final q = ctl.bizSearch.text;
  void pick(String f) {
    ctl.bizFilter = f;
    ctl.closeSheet();
  }

  ctl.showSheet((_) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        H2(tr('分類で絞る'), top: true),
        LayoutBuilder(builder: (context, c) {
          // 2列に並べる（10個が1画面に収まる）
          final w = (c.maxWidth - 8) / 2;
          return Wrap(spacing: 8, runSpacing: 0, children: [
            for (final e in CATN.entries)
              SizedBox(
                width: w,
                child: Builder(builder: (_) {
                  final n = newBizList(s, filter: e.key, query: q).length;
                  return ChoiceBtn(e.value, () => pick(e.key), key: ValueKey('filter-${e.key}'), on: ctl.bizFilter == e.key, dim: n == 0, subs: [tr('{0}件', [n])]);
                }),
              ),
          ]);
        }),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Wrap(spacing: 8, children: [
            Btn(tr('やめる'), ctl.closeSheet),
            if (CATN.containsKey(ctl.bizFilter)) Btn(tr('分類を外す'), () => pick('all')),
          ]),
        ),
      ]));
}

List<Widget> bizTab(GameController ctl) {
  final s = ctl.game!;
  // 事業が多い会社（[bizManyMin] 以上）は、見出しを押すと一覧ごとたためる（下の「新しい事業」「銀行」へすぐ行ける）。
  // 並べ替えと、まとめての手（足りない人をまとめて雇う・空いている部下を責任者に置く）も出す（1.0.0+18）
  final many = s.biz.length >= bizManyMin;
  final myOpen = !many || !ctl.folded.contains('mybiz');
  final out = <Widget>[
    many
        ? FoldHead(tr('自社の事業'), key: const ValueKey('fold-mybiz'), open: myOpen, onTap: () => ctl.toggleFold('mybiz'), note: tr('{0}件', [s.biz.length]))
        : H2(tr('自社の事業')),
  ];
  if (s.biz.isEmpty) out.add(Panel(child: Muted(tr('まだ事業がありません。下の「新しい事業」から始めましょう。'), size: 14)));
  final y = s.yr();
  void pick(VoidCallback f) {
    f();
    ctl.render();
  }

  if (many && myOpen) {
    final attn = _bizAttention(ctl);
    if (attn != null) out.add(attn);
    out.add(ChipRow('mysort', tr('並べ替え'), [
      for (final o in myBizSorts) PickChip(tr(o.$2), key: ValueKey('mysort-${o.$1}'), on: ctl.myBizSort == o.$1, onTap: () => pick(() => ctl.myBizSort = o.$1)),
    ]));
  }
  // 3つ以上は1行ずつにたたみ、押した1つだけを詳しく開く
  final fold = s.biz.length >= 3;
  if (myOpen) {
    for (final b in myBizList(s, many ? ctl.myBizSort : 'rev')) {
      out.add(!fold
          ? _bizCard(ctl, b)
          : ctl.openBiz == b.id
              ? _bizCard(ctl, b, onFold: () => ctl.toggleBiz(b.id))
              : _bizRow(ctl, b));
    }
  }
  out.add(H2(tr('新しい事業')));
  // 検索の欄・並べ替え・絞り込みを上に並べる

  out.add(SearchBox(key: const ValueKey('biz-search'), controller: ctl.bizSearch, hint: tr('業種の名前で探す'), onChanged: (_) => ctl.render()));
  out.add(ChipRow('sort', tr('並べ替え'), [
    for (final o in bizSorts) PickChip(tr(o.$2), key: ValueKey('sort-${o.$1}'), on: ctl.bizSort == o.$1, onTap: () => pick(() => ctl.bizSort = o.$1)),
  ]));
  // 絞り込みは折り返して全部見せる。分類（10個）は1つの札にまとめ、押すと選ぶ小窓が開く
  final f = ctl.bizFilter;
  final inCat = CATN.containsKey(f);
  out.add(ChipRow('filter', tr('絞り込み'), [
    for (final o in bizFilters) PickChip(tr(o.$2), key: ValueKey('filter-${o.$1}'), on: f == o.$1, onTap: () => pick(() => ctl.bizFilter = o.$1)),
    PickChip(inCat ? tr('分類：{0}', [CATN[f]]) : tr('分類'), key: const ValueKey('filter-cat'), on: inCat, more: true, onTap: () => openCatPick(ctl)),
  ]));
  final q = ctl.bizSearch.text.trim();
  final list = newBizList(s, filter: f, sort: ctl.bizSort, query: q);
  final firstFree = s.biz.isEmpty && !s.everBiz;
  if (list.isEmpty) {
    out.add(Panel(
        key: const ValueKey('biz-empty'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Muted(q.isNotEmpty ? tr('「{0}」に合う業種が見つかりません。', [q]) : tr('この条件で始められる事業はありません。'), size: 14),
          if (q.isNotEmpty || f != 'all')
            Btn(tr('条件を外して全部見る'), () {
              ctl.bizSearch.clear();
              ctl.bizFilter = 'all';
              ctl.render();
            }, small: true),
        ])));
  }
  if (list.isNotEmpty) {
    out.add(Padding(
      padding: const EdgeInsets.only(top: 4),
      child: LayoutBuilder(
          builder: (context, box) => Row(children: [
                Expanded(child: Muted(tr('業種（{0}件）', [list.length]), size: 12)),
                SizedBox(width: _colW, child: Align(alignment: Alignment.centerRight, child: Muted(tr('元手'), size: 12))),
                // 幅が狭いときは市場の列を出さず、名前の下の行に回す
                if (!narrowBizList(box.maxWidth))
                  Container(
                      width: _colW,
                      // 字の列が隣の「元手」とくっつかないよう、左を少し空けて、入りきらなければ字だけ縮める
                      padding: const EdgeInsets.only(left: 8),
                      child: FittedBox(
                          fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: Text(tr('市場（国内・月）'), maxLines: 1, softWrap: false, style: ts(size: 11, color: Pal.mute)))),
                SizedBox(width: _startW),
              ])),
    ));
  }
  for (final i in list) {
    final c = s.capexOf(i);
    final age = y - i.b;
    final ks = s.knownSynFor(i.id);
    out.add(Container(
      padding: const EdgeInsets.symmetric(vertical: 3),
      decoration: Ui.rowLine,
      child: LayoutBuilder(builder: (context, box) {
        final narrow = narrowBizList(box.maxWidth);
        return Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(key: ValueKey('newbiz-${i.id}'), spacing: 4, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
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
            if (narrow) Muted(tr('市場（国内・月） {0}', [yen(s.mkt(i) / 3)]), key: ValueKey('newbiz-mkt-${i.id}'), size: 11.5),
          ]),
        ),
        SizedBox(width: _colW, child: Text(yen(c), textAlign: TextAlign.right, style: ts(size: 13))),
        if (!narrow) SizedBox(width: _colW, child: Text(yen(s.mkt(i) / 3), textAlign: TextAlign.right, style: ts(size: 13))),
        SizedBox(
            width: _startW,
            child: Align(
                alignment: Alignment.centerRight,
                // 最初の1つは手を使わない。2つ目からは1手
                child: Btn(tr('始める'), () {
                  if (!firstFree && ctl.noAp()) return;
                  s.modelsFor(i.id).length > 1 ? openModel(ctl, i.id) : ctl.act(() => s.startBiz(i.id));
                }, small: true, enabled: s.cash >= c, ap: firstFree ? 0 : 1, apBelow: true, dim: !firstFree && !s.canAP(1)))),
      ]);
      }),
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
        _apBtn(ctl, tr('社債を出す'), () => ctl.act(s.issueBond), enabled: s.canBond()),
      if (s.land > 0) Btn(tr('土地を売る（今の値 {0}）', [yen(s.land)]), () => ctl.act(s.sellLand), small: true, shrink: true),
    ]),
  ])));
  return out;
}

/// 自社の事業の並べ替え（id・名前）
const myBizSorts = [('rev', '売上の大きい順'), ('warn', '注意があるものを先に'), ('low', '利益の少ない順'), ('share', 'シェアの低い順')];

/// 自社の事業を並べる（同じ値どうしは売上の大きい順のまま）。見るだけで、仕組みには触らない
List<Biz> myBizList(Game s, String sort) {
  final list = s.biz.toList()..ssort((a, b) => b.rev.compareTo(a.rev));
  switch (sort) {
    case 'warn':
      final w = {for (final b in list) b.id: bizWarnings(s, b).length};
      list.ssort((a, b) => w[b.id]!.compareTo(w[a.id]!));
    case 'low':
      list.ssort((a, b) => a.profit.compareTo(b.profit));
    case 'share':
      list.ssort((a, b) => a.share.compareTo(b.share));
  }
  return list;
}

/// 事業が多い会社の「まとめての手」の欄。人が足りない事業・責任者に置ける部下がいなければ null
Widget? _bizAttention(GameController ctl) {
  final s = ctl.game!;
  final short = s.crewShort();
  final can = s.crewShortDoable();
  final place = s.managerPlan();
  if (short.isEmpty && place.isEmpty) return null;
  final cost = can.fold(0.0, (a, b) => a + s.hireCost(b, s.crewNeedPeople(b)));
  return Panel(
    key: const ValueKey('biz-attn'),
    border: Pal.gold,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      CardTitle(tr('まとめての手'), gold: true),
      if (short.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(tr('人手不足の事業が{0}つ：{1}', [short.length, short.take(3).map((b) => indm[b.ind]!.name).join(tr('・')) + (short.length > 3 ? tr(' ほか') : '')]),
            style: ts(size: 12.5)),
        Align(
          alignment: Alignment.centerLeft,
          child: can.isEmpty
              // 手かお金が足りないときも押せて、理由を言う
              ? Btn(tr('足りない人をまとめて雇う'), () => ctl.toast(s.hireShortAll()), small: true, shrink: true, ap: 1, dim: true)
              : Btn(tr('足りない人をまとめて雇う（{0}つ・{1}）', [can.length, yen(cost)]), () => ctl.act(s.hireShortAll, mark: 'act'),
                  key: const ValueKey('hire-short-all'), small: true, shrink: true, ap: can.length),
        ),
        if (can.isNotEmpty && can.length < short.length) Muted(tr('手かお金が足りる{0}つだけ雇います（足りない割合の大きい順）', [can.length]), size: 12),
      ],
      if (place.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(tr('担当のない部下が、責任者のいない事業を{0}つ引き受けられます', [place.length]), style: ts(size: 12.5)),
        Align(
          alignment: Alignment.centerLeft,
          child: Btn(tr('空いている部下を責任者に置く（{0}人）', [place.length]), () {
            final m = s.placeManagers();
            ctl.save();
            ctl.toast(m);
          }, key: const ValueKey('place-managers'), small: true, shrink: true),
        ),
      ],
    ]),
  );
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
  return TapCard(
      border: warn.isNotEmpty ? Pal.down : Pal.line,
      inkKey: ValueKey('biz-row-${b.id}'),
      expanded: false,
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
  );
}

/// 仕掛かり1件の行（今までどおり、その場で取り下げられる）
Widget _pipeRow(GameController ctl, Biz b, int i) {
  final s = ctl.game!;
  return Padding(
    padding: const EdgeInsets.only(top: 4),
    child: TextBtnRow(
      text: Wrap(spacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Tag(pipeKindName(pipeKind(b.pipe[i]))),
        Text(pipeText(s, b, b.pipe[i]), style: ts(size: 12.5)),
      ]),
      btn: Btn(tr('取り下げる（半分戻る）'), () => ctl.act(() => s.cancelPipe(b, i)), small: true),
    ),
  );
}

/// 同じ種類の仕掛かりが2件以上あるときの1行。押すと一覧が開く
Widget _pipeGroupRow(GameController ctl, Biz b, PipeGroup g) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Material(
        color: Pal.panel2,
        shape: btnShape(Pal.line),
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
      Row(children: [
        Expanded(
            child: onFold == null
                ? Text(ind.name, style: ts(bold: true))
                // 名前の行を押すと、たたんで1行に戻す
                : FoldRow(
                    inkKey: ValueKey('biz-fold-${b.id}'),
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
        // 札の用語（稼ぎ方・先行者）の説明
        Info(ctl, [if (b.early > s.turn) 'early', 'model']),
      ]),
      Row(children: [
        Expanded(child: Semantics(label: tr('シェア {0}', [pct(b.share * 100)]), child: Bar([(b.share * 100, Pal.gold)]))),
        Info(ctl, const ['share']),
      ]),
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
      // 国と現場の2行の右に、用語の説明の「i」を1つ置く（規模の利益・現場の力・維持費）
      Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text.rich(TextSpan(style: ts(size: 12.5), children: [
            TextSpan(text: tr('出ている国 '), style: ts(size: 12.5, color: Pal.mute)),
            TextSpan(text: cts.map((c) => '${cm[c]!.n}${(b.jv ?? []).contains(c) ? tr('（組む）') : ''}').join(tr('・'))),
            cts.length >= 5
                ? TextSpan(text: tr('　規模の利益 利益率＋{0}%', [jsNum(jsRound(math.min(.5, (cts.length - 4) * .06) * 100))]), style: ts(size: 12.5, color: Pal.up))
                : TextSpan(text: tr('　5か国以上で規模の利益'), style: ts(size: 12.5, color: Pal.mute)),
          ])),
          const SizedBox(height: 6),
          crewLine,
          ]),
        ),
        Info(ctl, b.model == 'fc' ? const ['scale', 'upkeep'] : const ['scale', 'crew', 'upkeep']),
      ]),
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
      // ボタンは「伸ばす」「戦う」「形を変える」の3つの組に分けて並べる
      _grpHead(tr('伸ばす'), Icons.trending_up),
      Wrap(key: ValueKey('grp-grow-${b.id}'), spacing: 6, runSpacing: 0, children: [
        _apBtn(ctl, tr('{0}を増やす', [s.uw(b)]), () => openBuild(ctl, b), more: true),
        _apBtn(ctl, tr('商品を作る'), () => openDevelop(ctl, b), more: true),
        if (b.model != 'fc')
          _apBtn(ctl, s.crewNeedPeople(b) > 0 ? tr('現場の人を増やす（{0}人足りない）', [s.crewNeedPeople(b)]) : tr('現場の人を増やす'), () => openCrew(ctl, b), more: true),
        _apBtn(ctl, tr('広告 {0}', [yen(s.invBase(b) * .25)]), () => ctl.act(() => s.adv(b), mark: 'act')),
        _apBtn(ctl, tr('海外に出る'), () => openEnter(ctl, b), more: true),
      ]),
      _grpHead(tr('戦う@@grp'), Icons.flash_on),
      Column(key: ValueKey('grp-fight-${b.id}'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
        if (cs.isNotEmpty)
          _wrap([
            b.attack > 0
                ? Btn(tr('値下げ合戦中（あと{0}期）', [b.attack]), null, small: true, enabled: false)
                : _apBtn(ctl, tr('値下げ合戦を仕掛ける（相手：{0}）', [nmL(cs[0].c.name)]), () => ctl.act(() => s.priceWar(b), mark: 'act')),
            if (!s.inAssoc(b.ind)) Btn(tr('業界団体に入る'), () => ctl.act(() => s.joinAssoc(b), mark: 'act'), small: true),
          ]),
      ]),
      _grpHead(tr('形を変える'), Icons.account_tree_outlined),
      Wrap(key: ValueKey('grp-shape-${b.id}'), spacing: 6, runSpacing: 0, children: [
        if (s.modelsFor(b.ind).length > 1) _apBtn(ctl, tr('稼ぎ方を変える'), () => openModel(ctl, b.ind, b), more: true),
        if (s.pivotTargets(b).isNotEmpty) _apBtn(ctl, tr('業態を変える'), () => openPivot(ctl, b), more: true),
        _apBtn(ctl, tr('分社・独立'), () => openShape(ctl, b), more: true),
      ]),
      // 取り返しのつかない「売る」は、線で区切っていちばん下に離す。売るのは1手（「人たらし」の社長は2手）
      Container(
        key: ValueKey('biz-sell-${b.id}'),
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.only(top: 4),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Pal.line))),
        // 幅が足りなければ、ボタンは注意書きの下の行に回る
        child: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.warning_amber_rounded, size: 15, color: Pal.down),
            const SizedBox(width: 4),
            Flexible(child: Muted(tr('手放すと戻せません'), size: 12)),
          ]),
          _apBtn(ctl, tr('売る（約{0}）', [yen(s.sellValue(b))]),
              () => actConfirmed(ctl, tr('「{0}」を売る', [ind.name]), tr('「{0}」を約{1}で手放します。育てた力は戻りません。', [ind.name, yen(s.sellValue(b))]), tr('売る'), () => s.sellBiz(b)),
              ap: s.hasT('charm') ? 2 : 1),
        ]),
      ),
    ]),
  );
}

/// 事業カードのボタンの組の小見出し（アイコン・名前・右へ伸びる細い線）
Widget _grpHead(String label, IconData icon) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(children: [
        Icon(icon, size: 15, color: Pal.goldtx),
        const SizedBox(width: 4),
        Text(label, style: ts(size: 12.5, bold: true, color: Pal.goldtx)),
        const SizedBox(width: 8),
        const Expanded(child: SizedBox(height: 1, child: ColoredBox(color: Pal.line))),
      ]),
    );

// --- 人 ---
List<Widget> peopleTab(GameController ctl) {
  final s = ctl.game!;
  final P = s.pres;
  final out = <Widget>[H2(tr('社長'))];
  out.add(Panel(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Face.pres(P.name),
    const SizedBox(width: 10),
    Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(tr('{0}（{1}歳）', [nmL(P.name), P.age]), style: ts(bold: true)),
      const SizedBox(height: 6),
      Grid2([for (final k in abKeys) AbKv(ABN[k]!, '${P.ab[k]}', P.ab[k]!, P.ab[k]!)]),
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
    Row(children: [Expanded(child: CardTitle(tr('社風'))), Tag(cu.n, kind: TagKind.gold)]),
    const SizedBox(height: 4),
    Wrap(spacing: 8, children: [colored('${tr('＋')}${cu.g}', Pal.up, size: 12.5), colored('${tr('－')}${cu.b}', Pal.down, size: 12.5)]),
    const SizedBox(height: 6),
    if (s.cultLeft > 0)
      Muted(tr('「{0}」に切り替え中（あと{1}か月）', [CULT[s.cultNext]!.n, s.cultLeft]))
    else
      _wrap([
        for (final k in CULT.keys.where((k) => k != s.culture))
          Tooltip(message: '${tr('＋')}${CULT[k]!.g}${tr('／')}${tr('－')}${CULT[k]!.b}', child: _apBtn(ctl, tr('{0}にする', [CULT[k]!.n]), () => ctl.act(() => s.changeCulture(k)))),
      ]),
  ])));
  final succs = [...s.staff, ...s.kids.where((k) => k.age >= 18)];
  out.add(Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    CardTitle(tr('後継ぎ')),
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
  if (s.staff.isNotEmpty || s.cands.isNotEmpty) out.add(Padding(key: const ValueKey('face-legend'), padding: const EdgeInsets.only(bottom: 4), child: faceLegend()));
  // 4人以上は1人1行にたたみ、押した1人だけを詳しく開く
  final foldStaff = s.staff.length >= staffFoldMin;
  for (final p in s.staff) {
    out.add(!foldStaff
        ? _staffCard(ctl, p)
        : ctl.openStaff == p.id
            ? _staffCard(ctl, p, onFold: () => ctl.toggleStaff(p.id))
            : _staffRow(ctl, p));
  }
  out.add(H2(tr('採用の候補')));
  out.add(Muted(tr('面接で分かるのは能力の幅だけです。働かせると本当の値と特性が見えてきます。')));
  for (final p in s.cands) {
    out.add(Panel(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      staffFace(s, p),
      const SizedBox(width: 10),
      Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(tr('{0}（{1}歳）', [nmL(p.name), p.age]), style: ts(bold: true)),
        const SizedBox(height: 4),
        abGrid(s, p),
        const SizedBox(height: 4),
        p.traitKnown ? Text(tr('特性 {0}', [STRAITS.firstWhere((x) => x.id == p.trait).n]), style: ts(size: 12.5)) : Muted(tr('評判：{0}', [traitHints[p.trait]])),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: Muted(tr('給料 {0}／月・支度金 {1}', [yen(p.salary), yen(p.salary * 2)]))),
          _apBtn(ctl, tr('雇う'), () => ctl.act(() => s.hire(p))),
        ]),
      ])),
    ])));
  }
  return out;
}

/// 部下をたたみ始める人数
const staffFoldMin = 4;

/// 忠誠がこの値を下回ると、赤い注意の印を付ける。仕組みの線と同じ値にしてある:
/// 宿敵の引き抜きは「野心60超・忠誠55未満」（game_turn.dart の「引き抜き」）、相棒の独立は「野心65超・忠誠50未満」。
/// 55 は引き抜きが実際に始まる線そのものなので、遅くはないが、前触れにもならない → 手前に [loySoft] の線を足した（1.0.0+17）
const loyWarn = 55.0;

/// 前触れの線（橙の印）。月に 0.15〜0.6 ずつ下がる社風・特性の組み合わせで、赤の線の 8〜33 か月前に出る。
/// 会社を丸ごと売るときに相棒がついてくる線（忠誠60以上）とも同じ
const loySoft = 60.0;

/// 忠誠の注意の段（null 注意なし・'soft' 下がり気味・'bad' 引き抜きや独立の話が出うる）。
/// 野心が弱い（60以下）と分かっている人は、忠誠が低くても引き抜きの的にならないので、赤にはしない
String? loyLevel(Person p) {
  if (p.loy >= loySoft) return null;
  final risky = !p.ambKnown || p.amb > 60;
  return p.loy < loyWarn && risky ? 'bad' : 'soft';
}

/// 忠誠の注意の文と色
(String, Color) loyNote(String level) => level == 'bad' ? (tr('忠誠が下がっています'), Pal.down) : (tr('忠誠が下がり気味です'), Pal.warn);

/// いちばん高い能力（幅でしか分からないものは幅の真ん中で比べる。同じなら並びの先のもの）
String topAbility(Game s, Person p) {
  var best = abKeys.first;
  double mid(String k) {
    final r = s.rangeOf(p, k);
    return (r[0] + r[1]) / 2;
  }

  for (final k in abKeys) {
    if (mid(k) > mid(best)) best = k;
  }
  return best;
}

/// たたんだ部下の1行（名前・年齢・担当・いちばん高い能力・相棒の札・忠誠の注意の印）。押すと詳しいカードが開く
Widget _staffRow(GameController ctl, Person p) {
  final s = ctl.game!;
  final job = s.biz.where((b) => b.mgr == p.id).firstOrNull;
  final top = topAbility(s, p);
  final lv = loyLevel(p);
  return TapCard(
    border: lv == 'bad' ? Pal.down : lv == 'soft' ? Pal.warn : Pal.line,
    inkKey: ValueKey('staff-row-${p.id}'),
    expanded: false,
    onTap: () => ctl.toggleStaff(p.id),
    child: Container(
      constraints: const BoxConstraints(minHeight: minTap),
      padding: const EdgeInsets.fromLTRB(12, 7, 6, 7),
      child: Row(children: [
        staffFace(s, p),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(tr('{0}（{1}歳）', [nmL(p.name), p.age]), style: ts(size: 14, bold: true)),
              if (p.partner) Tag(tr('相棒@@tag'), kind: TagKind.gold),
              if (lv != null)
                Tooltip(
                  message: loyNote(lv).$1,
                  child: Icon(lv == 'bad' ? Icons.warning_amber_rounded : Icons.trending_down,
                      key: ValueKey('loy-warn-${p.id}'), size: 17, color: loyNote(lv).$2, semanticLabel: loyNote(lv).$1),
                ),
            ]),
            const SizedBox(height: 2),
            Text.rich(TextSpan(style: ts(size: 12.5, color: Pal.mute), children: [
              TextSpan(text: job != null ? tr('{0}の責任者', [indm[job.ind]!.name]) : tr('担当なし')),
              TextSpan(text: tr('・')),
              TextSpan(text: '${ABN[top]} ${s.showAb(p, top)}', style: ts(size: 12.5, color: Pal.ink, bold: true)),
            ])),
          ]),
        ),
        const Icon(Icons.expand_more, size: 22, color: Pal.mute),
      ]),
    ),
  );
}

/// 部下の詳しいカード。[onFold] があれば（たたんだ一覧から開いたとき）名前の行を押すと1行に戻る
Widget _staffCard(GameController ctl, Person p, {VoidCallback? onFold}) {
  final s = ctl.game!;
  {
    final t = STRAITS.firstWhere((x) => x.id == p.trait);
    final job = s.biz.where((b) => b.mgr == p.id).firstOrNull;
    final head = Wrap(spacing: 6, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
      Text(tr('{0}（{1}歳）', [nmL(p.name), p.age]), style: ts(bold: true)),
      if (p.partner) Tag(tr('相棒・株{0}', [pct(p.stake)]), kind: TagKind.gold),
      if (p.auto) Tag(tr('提案はまかせている'), kind: TagKind.good),
      Muted(job != null ? tr('{0}の責任者', [indm[job.ind]!.name]) : tr('担当なし')),
    ]);
    return Panel(
        border: onFold != null ? Pal.gold : Pal.line,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      staffFace(s, p),
      const SizedBox(width: 10),
      Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        onFold == null
            ? head
            : FoldRow(
                inkKey: ValueKey('staff-fold-${p.id}'),
                onTap: onFold,
                child: Container(
                  constraints: const BoxConstraints(minHeight: minTap),
                  alignment: Alignment.centerLeft,
                  child: Row(children: [Expanded(child: head), const Icon(Icons.expand_less, size: 22, color: Pal.mute)]),
                ),
              ),
        if (loyLevel(p) case final lv?)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(children: [
              Icon(lv == 'bad' ? Icons.warning_amber_rounded : Icons.trending_down, size: 15, color: loyNote(lv).$2),
              const SizedBox(width: 4),
              Expanded(child: Text(loyNote(lv).$1, style: ts(size: 12.5, color: loyNote(lv).$2))),
            ]),
          ),
        const SizedBox(height: 4),
        abGrid(s, p),
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
    ]));
  }
}

/// 宿敵の持ち分（いちばん多く握っている1社）が、次の節目（33.4%・50%・66.7%）まであと何%か。
/// 上場前は宿敵が株を買えないので null
String? rivalGapText(Game s) {
  if (!s.listed) return null;
  final r = s.sh.rivMax;
  final next = MarkBar.marks.where((m) => r < m).firstOrNull;
  if (next == null) return tr('宿敵の持ち分は{0}。{1}%を超えています', [pct(r), jsNum(MarkBar.marks.last)]);
  return tr('宿敵の持ち分は{0}。{1}%まであと{2}', [pct(r), jsNum(next), pct(next - r)]);
}

// --- 株 ---
List<Widget> stockTab(GameController ctl) {
  final s = ctl.game!;
  final sh = s.sh;
  final out = <Widget>[H2Info(tr('あなたの会社の株主'), ctl, const ['own', 'cap'])];
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
  final gap = rivalGapText(s);
  // 次の節目まで5%を切ったら（または節目を越えていたら）赤で知らせる
  final rmax = sh.rivMax;
  final near = MarkBar.marks.any((m) => rmax >= m || m - rmax < 5);
  out.add(Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    // 棒の上に 33.4%・50%・66.7% の線を重ねる
    // 棒は色でしか分からないので、読み上げには割合を言葉で渡す（節目の小さな字は読ませない）
    Semantics(
        key: const ValueKey('sem-owners'),
        label: '${tr('あなたの会社の株主')}${tr('：{0}', [parts.where((p) => p.$2 > .05).map((p) => '${p.$1} ${pct(p.$2)}').join(tr('、'))])}',
        excludeSemantics: true,
        child: MarkBar([for (final p in parts) (p.$2, p.$3)], height: 14)),
    const SizedBox(height: 4),
    Grid2([
      for (final p in parts.where((p) => p.$2 > .05))
        Row(children: [
          Container(width: 9, height: 9, margin: const EdgeInsets.only(right: 5), decoration: BoxDecoration(color: p.$3, borderRadius: BorderRadius.circular(2))),
          Expanded(child: Kv(p.$1, pct(p.$2))),
        ]),
    ]),
    if (gap != null)
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 2, right: 5), child: Icon(near ? Icons.warning_amber_rounded : Icons.shield_outlined, size: 15, color: near ? Pal.down : Pal.mute)),
          Expanded(child: Text(gap, key: const ValueKey('rival-gap'), style: ts(size: 13, bold: true, color: near ? Pal.down : Pal.ink))),
        ]),
      ),
    const SizedBox(height: 6),
    Muted(tr('5%で相手に知られる／33.4%で合併を止められる／50%超で社長を替えられる／66.7%で合併も自由')),
  ])));
  out.add(Panel(
    child: s.listed
        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CardTitle(tr('上場済み')),
            Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Muted(tr('誰でもあなたの株を買えます。乗っ取りに注意。'))),
            _wrap([
              _apBtn(ctl, tr('増資で集める（{0}・全員の割合−9%）', [yen(s.cap * .095)]), () => ctl.act(s.publicOffer)),
              _apBtn(ctl, tr('自社株買い 5%（約{0}）', [yen(s.cap * .0575)]), () => ctl.act(s.buybackAct), enabled: sh.float >= 1),
              _apBtn(ctl, tr('ホワイトナイトを頼む'), () => ctl.act(s.whiteKnightAct)),
            ]),
          ])
        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CardTitle(tr('未上場')),
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Muted(tr('上場すると大金が入るが、宿敵があなたの株を買えるようになる。条件：年の利益 {0} 以上・創業2年以上', [yen(3e8 * s.nom())]))),
            _wrap([
              _apBtn(ctl, tr('投資家から集める（{0}・持ち株−10%）', [yen(s.cap * .1)]), () => ctl.act(s.vcRaise)),
              _apBtn(ctl, tr('上場する'), () => ctl.act(s.ipo), enabled: s.canIPO()),
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
    LayoutBuilder(
        builder: (context, c) => Row(children: [
              Expanded(child: Text(tr(s.holding ? '持株会社' : 'ふつうの会社'), style: ts(bold: s.holding))),
              // ボタンは字の幅をそのまま取る（半分の幅に押し込むと2行に折れる）。欄の7割までは広がれる
              if (!s.holding)
                ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: c.maxWidth * .7),
                    child: _apBtn(ctl, tr('持株会社にする'), () => ctl.act(s.makeHolding), enabled: s.biz.length + s.subs().length >= 5)),
            ])),
    Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Muted(tr('持株会社は、社長が直接見られる事業の上限がなくなります。事業は「事業」の画面から、分社（子会社にする）や、責任者に渡して独立させることもできます。'))),
    // 分類ごとのボタンを縦に並べると、事業が増えた会社では10個並んだ（1.0.0+18）。1つのボタンにまとめ、どの分類を切り離すかは小窓で選ぶ
    if (s.listed && s.biz.length >= 2) _apBtn(ctl, tr('会社を2つに割る'), () => openSplit(ctl), more: true),
  ])));
  out.add(H2(tr('売り抜け')));
  out.add(Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Muted(tr('勝ち負けは「今の会社の時価総額＋あなたの財産」で測ります。今の財産 {0}', [yen(s.wealth)])),
    const SizedBox(height: 6),
    _wrap([
      if (s.listed) Btn(tr('持ち株を5%売る（約{0}）', [yen(s.cap * .045)]), () => ctl.act(() => s.sellOwn(5)), small: true, shrink: true),
      if (s.listed) _apBtn(ctl, tr('非上場に戻す（MBO）'), () => ctl.act(s.goPrivate)),
      _apBtn(ctl, tr('会社を丸ごと売る'), () => openSell(ctl), enabled: s.biz.isNotEmpty && s.buyers().isNotEmpty, more: true),
      if (s.noncomp != null && !s.noncomp!.broken)
        Tooltip(message: tr('2年後に裁判で賠償を求められる'), child: Btn(tr('同じ業種に入らない約束を破る'), () => ctl.act(s.breakNoncomp), small: true, shrink: true)),
    ]),
  ])));
  // 子会社・現地法人と、株を持っているだけの会社を分けて並べる（混ざっていると、子会社を探すのに全部のカードを見ることになる。1.0.0+18）
  final held = s.cos.where((c) => c.alive && s.pctOf(c) > 0).toList();
  final subs = held.where((c) => c.parent == 'player').toList();
  final others = held.where((c) => c.parent != 'player').toList();
  if (subs.isNotEmpty) {
    out.add(H2(tr('子会社・現地法人（{0}社）', [subs.length]), key: const ValueKey('h-subs')));
    for (final c in subs) {
      out.add(_coCard(ctl, c));
    }
  }
  if (others.isNotEmpty) {
    out.add(H2(tr('持っている他社の株')));
    for (final c in others) {
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
  final mine = c.parent == 'player';
  final swap = s.listed && c.cap <= s.cap && !(mine && own >= 66.7);
  return Panel(
      key: ValueKey('co-${c.id}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    // 名前と札は折り返して並べる（横に押し込むと、幅320では名前と札がくっつき、札の字が語の途中で折れていた。1.0.0+18）
    Wrap(spacing: 6, runSpacing: 3, crossAxisAlignment: WrapCrossAlignment.center, children: [
      if (c.rival != null) Face.rival(c.presName, c.rival!.col),
      Text(nmL(c.name), style: ts(bold: true)),
      if (mine) Tag(c.loc != null ? tr('現地法人（{0}）', [cm[c.loc!]!.n]) : tr('子会社@@tag'), kind: TagKind.gold),
      // 現地法人は国の名前が札に出ているので、「国内・地域・世界」の札は付けない
      if (c.loc == null) Tag(c.rival != null ? RTYPE[c.rival!.label ?? c.rival!.type] ?? '' : REGN[c.tier]),
      if (c.listed && mine) Tag(tr('上場@@tag'), kind: TagKind.good),
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
      // 自分の子会社で、市場に株が出ていないときは「市場で買う」を出さない（押せないボタンが並ぶだけになる）
      if (!(mine && s.floatOf(c) <= 0))
        _apBtn(ctl, tr('市場で5%買う（{0}）', [yen(c.cap * .0525)]), () => ctl.act(() => s.buyStake(c, 5)), enabled: s.floatOf(c) > 0),
      if (own < 50.1)
        _apBtn(ctl, tr('TOBで{0}%（{1}・成功率{2}）', ['50.1', yen(s.tobCost(c, 50.1)), _pct0(s.tobChance(c, 50.1))]), () => ctl.act(() => s.tob(c, 50.1))),
      if (own > 50 && own < 66.7)
        _apBtn(ctl, tr('TOBで{0}%（{1}・成功率{2}）', ['66.7', yen(s.tobCost(c, 66.7)), _pct0(s.tobChance(c, 66.7))]), () => ctl.act(() => s.tob(c, 66.7))),
      if (s.canMerge(c)) _apBtn(ctl, tr('合併する（株を渡して払う）'), () => ctl.act(() => s.merge(c)), primary: true),
      if (c.parent != 'player') _apBtn(ctl, tr('組む'), () => openDeal(ctl, c), more: true),
      if (swap)
        Tooltip(
          message: tr('現金の代わりに自社の株を渡して丸ごと買う。あなたの持ち株は薄まる'),
          // ボタンの字は短くして、持ち株がどう薄まるかは下の行に出す（1行に詰めると、幅320では字が読めない大きさまで縮んでいた。1.0.0+18）
          child: _apBtn(ctl, tr('株式交換で丸ごと買う（成功率{0}）', [_pct0(s.swapChance(c))]), () => ctl.act(() => s.shareSwap(c))),
        ),
      if (mine && !c.listed && own >= 60)
        _apBtn(ctl, c.loc != null ? tr('{0}の市場に上場させる（30%売る・約{1}）', [cm[c.loc!]!.n, yen(c.cap * .3 * .95)]) : tr('子会社を上場させる（30%売る・約{0}）', [yen(c.cap * .3 * .95)]),
            () => ctl.act(() => s.subIPO(c))),
      if (c.loc != null && c.locRivPct > 0 && s.coById(c.locRiv) != null)
        Btn(tr('宿敵の持ち分を買い戻す（{0}）', [yen(s.localBuybackCost(c))]), () {
          // お金が足りないときも押せて、理由を言う（薄いだけのボタンは、なぜ押せないのかが分からない）
          if (s.cash < s.localBuybackCost(c)) {
            ctl.toast(M('お金が足りず、買い戻せませんでした'));
          } else {
            ctl.act(() => s.localBuyback(c));
          }
        }, small: true, shrink: true, dim: s.cash < s.localBuybackCost(c)),
      // 子会社でない会社の株は、今までどおりその場で売れる
      if (own > 0 && !mine) Btn(tr('全部売る（{0}）', [yen(c.cap * own / 100 * .95)]), () => ctl.act(() => s.sellStake(c)), small: true, shrink: true),
    ]),
    // 小数1桁で見て変わらないほど小さな相手なら、注意書きは出さない
    if (swap && pct(s.sh.own) != pct(s.sh.own * (1 - restC / (s.cap + restC))))
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Muted(tr('株式交換をすると、あなたの持ち株は {0}→{1} に薄まります', [pct(s.sh.own), pct(s.sh.own * (1 - restC / (s.cap + restC)))]), key: ValueKey('swap-note-${c.id}'), size: 12),
      ),
    // 子会社・現地法人を手放すのは取り返しがつかないので、事業の「売る」と同じように線で区切っていちばん下に離し、確認を挟む（1.0.0+18）
    if (own > 0 && mine)
      Container(
        key: ValueKey('co-sell-${c.id}'),
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.only(top: 4),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Pal.line))),
        child: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.warning_amber_rounded, size: 15, color: Pal.down),
            const SizedBox(width: 4),
            Flexible(child: Muted(tr('手放すと戻せません'), size: 12)),
          ]),
          Btn(
              tr('全部売る（{0}）', [yen(c.cap * own / 100 * .95)]),
              () => actConfirmed(ctl, tr('{0}の株を全部売る', [nmL(c.name)]),
                  tr('{0}の株{1}を約{2}で手放します。子会社ではなくなり、買い戻すには市場やTOBで集め直すことになります。', [nmL(c.name), pct(own), yen(c.cap * own / 100 * .95)]), tr('売る'), () => s.sellStake(c)),
              small: true,
              shrink: true),
        ]),
      ),
  ]));
}

// --- 数字 ---
List<Widget> numTab(GameController ctl) {
  final s = ctl.game!;
  final rows = plRows(s);
  final top = rows.fold(0.0, (a, r) => math.max(a, r.$3.abs()));
  final dec = plDecades(rows.map((r) => r.$3));
  final out = <Widget>[H2(tr('今月の決算'))];
  // 内訳は横棒で見せる（いちばん大きい額を端まで。入るお金は緑、出るお金は赤）。
  // 棒の長さは桁の目盛り（1目盛りで10倍。1.0.0+18）。育った会社では給料や本社の経費が利益の1万分の1ほどで、額の比のままだと全部同じ最小の幅に並んだ
  out.add(Panel(
      key: const ValueKey('pl'),
      child: Column(children: [
        for (final r in rows)
          Container(
            key: ValueKey('pl-${r.$1}'),
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: Ui.rowLine,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text(tr(r.$2), style: ts(size: 13))),
                Text(yen(r.$3), style: ts(size: 13, color: r.$3 < 0 ? Pal.down : Pal.ink)),
              ]),
              const SizedBox(height: 4),
              Semantics(label: '${tr(r.$2)} ${yen(r.$3)}', child: AmountBar(plFrac(r.$3, top, dec), key: ValueKey('pl-bar-${r.$1}'), minus: r.$3 < 0, ticks: dec)),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Align(alignment: Alignment.centerLeft, child: Muted(tr('棒は桁の目盛りです（1目盛りで10倍）'), key: const ValueKey('pl-scale-note'), size: 11.5)),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 7, bottom: 2),
          child: Row(key: const ValueKey('pl-total'), children: [
            Expanded(child: Text(tr('税引前の利益'), style: ts(size: 14, bold: true))),
            Text(yen(s.pre), style: ts(size: 14, bold: true, color: s.pre < 0 ? Pal.down : Pal.up)),
          ]),
        ),
      ])));
  out.add(H2Info(tr('時価総額の推移'), ctl, const ['cap']));
  out.add(Frame(
    child: AspectRatio(
        aspectRatio: 4,
        // グラフは絵なので、読み上げには見出しと、はじめと今の値を言葉で渡す
        child: Semantics(
            key: const ValueKey('sem-cap-graph'),
            image: true,
            label: s.hist.isEmpty ? tr('時価総額の推移') : tr('{0}。はじめ {1}、今 {2}', [tr('時価総額の推移'), yen(s.hist.first.cap), yen(s.hist.last.cap)]),
            child: CustomPaint(painter: SparkPainter(s.hist), size: Size.infinite))),
  ));
  out.add(H2(tr('売上と利益の推移（月）')));
  out.add(Frame(
    child: AspectRatio(
        aspectRatio: 640 / 180,
        child: Semantics(
            key: const ValueKey('sem-rev-graph'),
            image: true,
            label: s.hist.isEmpty ? tr('売上と利益の推移') : tr('{0}。今の売上 {1}、利益 {2}', [tr('売上と利益の推移'), yen(s.hist.last.rev), yen(s.hist.last.pre)]),
            child: CustomPaint(painter: RevProfitPainter(s.hist), size: Size.infinite))),
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
  out.add(H2Info(tr('世界の企業ランキング'), ctl, const ['rank', 'cap']));
  final rk = s.rankList();
  final lines = <Widget>[
    Row(children: [
      SizedBox(width: Ui.sw(44), child: Muted(tr('順位'), size: 12)),
      Expanded(child: Muted(tr('会社'), size: 12)),
      Muted(tr('時価総額'), size: 12),
    ]),
  ];
  // 上位10・自分の前後5・宿敵を出す。あいだが飛ぶところは「…」の行で区切る
  var prev = -1;
  for (final i in rankShown(rk)) {
    if (i != prev + 1) {
      lines.add(const Padding(padding: EdgeInsets.symmetric(vertical: 1), child: Icon(Icons.more_horiz, key: ValueKey('rank-gap'), size: 16, color: Pal.mute)));
    }
    prev = i;
    final x = rk[i];
    final rv = x.c?.rival;
    final st = ts(
        size: 13,
        color: x.me
            ? Pal.goldtx
            : rv != null
                ? rivalInk(rv.col)
                : Pal.ink,
        bold: x.me || rv != null);
    lines.add(Container(
      key: ValueKey('rank-${i + 1}'),
      color: x.me ? Pal.goldBg : null,
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        SizedBox(width: Ui.sw(44), child: Text('${i + 1}', style: st)),
        // 宿敵には、その宿敵の色の丸を付ける
        if (rv != null)
          Padding(padding: const EdgeInsets.only(right: 6), child: RivalDot(rv.col, key: ValueKey('rank-rival-${x.c!.id}'))),
        Expanded(child: Text(x.me ? tx(x.name) : nmL(x.name), style: st, overflow: TextOverflow.ellipsis)),
        Text(yen(x.cap), style: st),
      ]),
    ));
  }
  out.add(Panel(key: const ValueKey('rank'), child: Column(children: lines)));
  out.add(Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Row(children: [
      const Padding(padding: EdgeInsets.only(right: 6), child: RivalDot('#f2c14e')),
      Expanded(child: Muted(tr('色の四角は宿敵（宿敵ごとの色）。上位10社・あなたの前後5社・宿敵を出しています'), size: 12)),
    ]),
  ));
  out.addAll(chronSection(ctl));
  return out;
}

/// 決算の内訳の行（id・名前の鍵・額。出るお金はマイナス）
List<(String, String, double)> plRows(Game s) => [
      ('biz', '事業の利益', s.biz.fold(0.0, (a, b) => a + b.profit)),
      ('sub', '子会社の利益（持ち分）', s.subP),
      ('pay', '給料', -s.salaries()),
      ('hq', '本社の経費', -s.hq),
      ('int', '利息', -s.interest),
    ];

/// 世界ランキングで出す行（[rk] の何番目か。小さい順）。上位10・自分の前後5・宿敵
List<int> rankShown(List<RankRow> rk) {
  final me = rk.indexWhere((x) => x.me);
  return [
    for (var i = 0; i < rk.length; i++)
      if (i < 10 || (me >= 0 && (i - me).abs() <= 5) || rk[i].c?.rival != null) i,
  ];
}

/// 社史の色（種類ごと）
Color chronColor(String k) => switch (k) {
      'found' || 'ipo' || 'rank' || 'won' || 'swap' || 'merge' || 'buy' || 'sold' => Pal.gold,
      'over' || 'rebirth' || 'partner_out' => Pal.down,
      'era' => Pal.line,
      _ => Pal.up,
    };

/// 「数字」の下の社史（新しい順）
List<Widget> chronSection(GameController ctl) {
  final s = ctl.game!;
  final out = <Widget>[H2(tr('社史'))];
  if (s.history.isEmpty) {
    out.add(Muted(tr('まだ記録がありません。上場・買収・海外進出などの節目がここに残ります。')));
    return out;
  }
  Widget row(Chron e) => Container(
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: Ui.rowLine,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: Ui.sw(84), child: Text(ym(e.y, e.q), style: ts(size: 12.5, color: Pal.mute))),
          Container(width: 3, height: 16, margin: const EdgeInsets.only(right: 8, top: 2), color: chronColor(e.k)),
          // 時代の出来事（会社の節目ではない）は薄い字にして、会社の節目が目に入るようにする
          Expanded(child: Text(tx(e.m), style: ts(size: 13, height: 1.45, color: e.k == 'era' ? Pal.mute : Pal.ink))),
        ]),
      );
  // 記録が増えたら（[chronFoldMin] 件を超えたら）、主な節目だけを先に見せ、全部の記録はたたんでおく。
  // 30年遊ぶと50〜100件が1列に並び、上場や宿敵との決着が、海外進出や時代の出来事の行に埋もれていた（1.0.0+18）
  final long = s.history.length > chronFoldMin;
  if (long) {
    out.add(Panel(
        key: const ValueKey('chron-marks'),
        border: Pal.gold,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          CardTitle(tr('主な節目'), gold: true),
          for (final e in s.highlights(chronMarks).reversed) row(e),
        ])));
    final open = ctl.folded.contains('chron-all');
    out.add(FoldHead(tr('すべての記録'), key: const ValueKey('fold-chron'), open: open, onTap: () => ctl.toggleFold('chron-all'), note: tr('{0}件', [s.history.length])));
    if (!open) return out;
  }
  out.add(Panel(key: const ValueKey('chron-all'), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final e in s.history.reversed) row(e)])));
  return out;
}

/// 社史の記録がこの数を超えたら、主な節目を先に見せて、全部の記録はたたむ
const chronFoldMin = 16;

/// 「数字」の社史に出す主な節目の数
const chronMarks = 8;

// --- 図鑑 ---
/// 図鑑の切り替え（id・名前）
const zukanViews = [('syn', 'シナジー'), ('ind', '業種@@zukan'), ('ach', '実績')];

List<Widget> zukanTab(GameController ctl) {
  final view = zukanViews.any((v) => v.$1 == ctl.zukanView) ? ctl.zukanView : 'syn';
  return [
    Segments('zukan', [for (final v in zukanViews) (v.$1, tr(v.$2))], value: view, onChanged: ctl.setZukan),
    ...switch (view) {
      'ind' => zukanInds(ctl),
      'ach' => zukanAchs(ctl),
      _ => zukanSyns(ctl),
    },
  ];
}

/// 図鑑の業種1つの見え方（done 手がけた・seen 名前だけ・soon 種探しで知った未来の業種・future まだ生まれていない）
String indLook(Game s, Industry i) => s.handled(i.id)
    ? 'done'
    : i.b > s.yr()
        ? (s.seen[i.id] != null ? 'soon' : 'future')
        : 'seen';

/// 図鑑の「業種」：分類ごとの一覧。手がけた業種は中身が見え、まだの業種は名前だけ、未来の業種は「？？？」
List<Widget> zukanInds(GameController ctl) {
  final s = ctl.game!;
  final done = s.inds.where((i) => s.handled(i.id)).length;
  final out = <Widget>[
    H2(tr('業種図鑑')),
    Progress(tr('手がけた業種'), done, s.inds.length, key: const ValueKey('ind-progress')),
    Muted(tr('手がけたことのある業種は、生まれた年・頂点の年・利益率・稼ぎ方が見えます。')),
  ];
  for (final cat in CATN.keys) {
    final list = s.inds.where((i) => i.cat == cat).toList();
    if (list.isEmpty) continue;
    final future = list.where((i) => indLook(s, i) == 'future').length;
    out.add(Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 2),
      child: Row(children: [
        Expanded(child: Text(CATN[cat]!, style: Ui.h3)),
        Muted('${list.where((i) => s.handled(i.id)).length} / ${list.length}', size: 12),
      ]),
    ));
    out.add(Panel(
        key: ValueKey('ind-cat-$cat'),
        padding: const EdgeInsets.symmetric(horizontal: Ui.pad, vertical: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final i in list)
            if (indLook(s, i) case final look when look != 'future')
              Container(
                key: ValueKey('ind-$look-${i.id}'),
                padding: const EdgeInsets.symmetric(vertical: 5),
                decoration: Ui.rowLine,
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 6),
                    child: Icon(look == 'done' ? Icons.check_circle : Icons.radio_button_unchecked, size: 15, color: look == 'done' ? Pal.goldtx : Pal.line),
                  ),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(i.name, style: ts(size: 13, bold: look == 'done')),
                      if (look == 'done') ...[
                        Muted(tr('{0}年生まれ・頂点 {1}年・利益率{2}', [i.b, i.p, _pct0(i.mg)]), size: 11.5),
                        Muted(tr('稼ぎ方：{0}', [s.modelsFor(i.id).map((m) => MODELN[m]).join(tr('・'))]), size: 11.5),
                      ] else if (look == 'soon')
                        Muted(tr('{0}年ごろ生まれそう', [i.b]), size: 11.5),
                    ]),
                  ),
                  if (look == 'seen') Text(tr('？'), style: ts(size: 13, color: Pal.mute)),
                ]),
              ),
          // まだ生まれていない業種は、名前を伏せて数だけ出す
          if (future > 0)
            Padding(
              key: ValueKey('ind-future-$cat'),
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.lock_outline, size: 15, color: Pal.mute)),
                Expanded(child: Muted(tr('？？？（未来の業種）'), size: 13)),
                Muted('×$future', size: 13),
              ]),
            ),
        ])));
  }
  return out;
}

/// 図鑑の「実績」：節目の一覧。達成したものは金の印と達成した年月
List<Widget> zukanAchs(GameController ctl) {
  final s = ctl.game!;
  return [
    H2(tr('実績')),
    Progress(tr('達成した実績'), s.ach.keys.where(achm.containsKey).length, ACHS.length, key: const ValueKey('ach-progress')),
    Panel(
        padding: const EdgeInsets.symmetric(horizontal: Ui.pad, vertical: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final a in ACHS)
            if (s.achWhen(a.id) case final w)
              Container(
                key: ValueKey('ach-${w != null ? 'done' : 'todo'}-${a.id}'),
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: Ui.rowLine,
                child: Row(children: [
                  Container(
                    width: 30,
                    height: 30,
                    margin: const EdgeInsets.only(right: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: w != null ? Pal.gold : Pal.panel2, shape: BoxShape.circle, border: Border.all(color: w != null ? Pal.goldtx : Pal.line)),
                    child: Icon(w != null ? Icons.emoji_events : Icons.lock_outline, size: 17, color: w != null ? const Color(0xFF1A1300) : Pal.mute),
                  ),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a.n, style: ts(size: 13.5, bold: true, color: w != null ? Pal.ink : Pal.mute)),
                      Muted(a.d, size: 12),
                    ]),
                  ),
                  if (w != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(w.$1 > 0 ? ym(w.$1, w.$2) : tr('達成済み'), style: ts(size: 12, color: Pal.goldtx, bold: true)),
                    ),
                ]),
              ),
        ])),
  ];
}

/// 図鑑の「シナジー」：見つけた数の進み具合と、組み合わせの一覧
List<Widget> zukanSyns(GameController ctl) {
  final s = ctl.game!;
  // 数は下の進み具合の欄に出す（見出しにも同じ「0 / 141」を出していて、同じ数字が2つ並んでいた。業種・実績の見出しとそろえた。1.0.0+18）
  final out = <Widget>[H2Info(tr('シナジー図鑑'), ctl, const ['synergy'])];
  out.add(Progress(tr('見つけたシナジー'), s.found.length, s.syns.length, key: const ValueKey('syn-progress')));
  out.add(Muted(tr('2つの事業を同時に持つと見つかります。見つけた組み合わせは事業の力を2割上げます。')));
  out.add(Panel(
      child: Column(children: [
    for (final x in s.syns)
      Builder(builder: (_) {
        final f = s.found[x.k];
        final hn = f == null && s.hint[x.k] != null;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: Ui.rowLine,
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
            SizedBox(width: Ui.sw(50), child: Text(f != null ? yearL(f) : '', textAlign: TextAlign.right, style: ts(size: 13, color: Pal.mute))),
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
