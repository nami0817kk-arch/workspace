import 'package:flutter/material.dart';

import '../game/game.dart';
import 'controller.dart';
import 'sheets.dart';
import 'tabs.dart';
import 'widgets.dart';

class QuadrillionApp extends StatefulWidget {
  final GameController controller;
  const QuadrillionApp({super.key, required this.controller});

  @override
  State<QuadrillionApp> createState() => _QuadrillionAppState();
}

class _QuadrillionAppState extends State<QuadrillionApp> {
  GameController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    // アプリが裏に回る・閉じられるときに自動で保存する
    WidgetsBinding.instance.addObserver(controller);
  }

  @override
  void didUpdateWidget(QuadrillionApp old) {
    super.didUpdateWidget(old);
    if (old.controller != controller) {
      WidgetsBinding.instance.removeObserver(old.controller);
      WidgetsBinding.instance.addObserver(controller);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(controller);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: tr('クアドリリオン'),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: fontFamily,
        scaffoldBackgroundColor: Pal.sky,
        colorScheme: ColorScheme.fromSeed(seedColor: Pal.gold, surface: Pal.panel, brightness: Brightness.light),
        textTheme: const TextTheme().apply(bodyColor: Pal.ink, displayColor: Pal.ink),
      ),
      home: ListenableBuilder(listenable: controller, builder: (context, _) => RootScreen(ctl: controller)),
    );
  }
}

/// はじめの画面か本体かを選び、上に小窓を重ねる
class RootScreen extends StatelessWidget {
  final GameController ctl;
  const RootScreen({super.key, required this.ctl});

  @override
  Widget build(BuildContext context) {
    final sheet = ctl.sheet;
    return Scaffold(
      backgroundColor: Pal.sky,
      body: Stack(children: [
        Positioned.fill(child: SafeArea(bottom: false, child: ctl.game == null ? SetupScreen(ctl: ctl) : MainScreen(ctl: ctl))),
        // 勝ち負けが決まったら、小窓を閉じたあとに全画面のまとめを出す
        if (sheet == null && ctl.game != null && ctl.game!.ended && !ctl.endHidden) Positioned.fill(child: EndScreen(ctl: ctl)),
        if (sheet != null)
          Positioned.fill(
            child: Container(
              color: const Color(0x59282832),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: LayoutBuilder(builder: (context, c) {
                    return Align(
                      alignment: c.maxWidth >= 700 ? Alignment.center : Alignment.bottomCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 620, maxHeight: c.maxHeight * .94),
                        child: Material(
                          color: Pal.panel,
                          shape: RoundedRectangleBorder(side: const BorderSide(color: Pal.line), borderRadius: BorderRadius.circular(14)),
                          clipBehavior: Clip.antiAlias,
                          child: SingleChildScrollView(
                            key: ValueKey('sheet${ctl.sheetSeq}'),
                            padding: const EdgeInsets.all(16),
                            child: Builder(builder: sheet),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

// ===== はじめの画面 =====
class SetupScreen extends StatelessWidget {
  final GameController ctl;
  const SetupScreen({super.key, required this.ctl});

  Widget _opt(List<Widget> items) => LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth >= 520 ? 3 : 2;
        final w = (c.maxWidth - 8 * (cols - 1)) / cols;
        return Wrap(spacing: 8, runSpacing: 0, children: [for (final i in items) SizedBox(width: w, child: i)]);
      });

  @override
  Widget build(BuildContext context) {
    final st = ctl.setup;
    void set(VoidCallback f) {
      f();
      ctl.render();
    }

    final y = st.year.toDouble();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: ListView(padding: const EdgeInsets.fromLTRB(12, 24, 12, 40), children: [
          Text('QUADRILLION', style: ts(size: 34, color: Pal.goldtx, bold: true)),
          Padding(padding: const EdgeInsets.only(bottom: 18), child: Muted(tr('クアドリリオンゲーム ― 屋台から1000兆円へ'), size: 14)),
          if (ctl.hasSave()) ...[
            H2(tr('続きから'), top: true),
            Panel(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (var i = 1; i <= slotCount; i++) _slotRow(i, ctl.slotInfo(i), last: i == slotCount),
                ])),
          ],
          H2(tr('モード')),
          _opt([
            for (final o in const [
              ('world', '世界一位', '世界の企業ランキングで1位になれば勝ち'),
              ('quad', '1000兆円', 'グループの時価総額1000兆円を目指す'),
              ('endless', '終わりなし', '倒産しても再起できる。のんびり育てる'),
            ])
              ChoiceBtn(tr(o.$2), () => set(() => st.mode = o.$1), on: st.mode == o.$1, subs: [tr(o.$3)]),
          ]),
          H2(tr('始める年代')),
          _opt([
            for (final o in const [
              (1980, '1980年', 'バブル・崩壊・ネット・スマホ・AI をすべてくぐる'),
              (2000, '2000年', 'ネットの到来から。IT の成り上がり'),
              (2025, '2025年', 'AI の時代から未来へ'),
            ])
              ChoiceBtn(tr(o.$2), () => set(() => st.year = o.$1), on: st.year == o.$1, subs: [tr(o.$3)]),
          ]),
          H2(tr('始める国')),
          _opt([
            for (final x in CTRY)
              ChoiceBtn(x.n, () => set(() => st.home = x.c),
                  on: st.home == x.c, subs: [tr('{0}・市場 ×{1}', [x.city, (cw(x.c, y) / cw('jp', y)).toStringAsFixed(2)])]),
          ]),
          H2(tr('社長の特性（2つ選ぶ）')),
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Muted(tr('どの特性にも強い点と弱い点があります'))),
          _opt([
            for (final t in TRAITS)
              ChoiceBtn(t.n, () {
                set(() {
                  if (st.traits.contains(t.id)) {
                    st.traits.remove(t.id);
                  } else if (st.traits.length < 2) {
                    st.traits.add(t.id);
                  }
                });
              }, on: st.traits.contains(t.id), subs: ['${tr('＋')}${t.g}', '${tr('－')}${t.b}']),
          ]),
          H2(tr('難しさ')),
          _opt([
            for (final d in DIFFS) ChoiceBtn(d.n, () => set(() => st.diff = d.id), on: st.diff == d.id, subs: [d.d]),
          ]),
          H2(tr('保存する枠')),
          _opt([
            for (var i = 1; i <= slotCount; i++)
              ChoiceBtn(tr('枠{0}', [i]), () => set(() => ctl.newSlot = i), on: ctl.startSlot == i, subs: [_slotShort(ctl.slotInfo(i))]),
          ]),
          Padding(padding: const EdgeInsets.only(top: 16), child: Muted(tr('社長は22歳、大学を出たばかり。最初は会社の名前だけがあります。'))),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Btn(tr('会社を立ち上げる'), () {
              void go() {
                ctl.startNew();
                ctl.render();
                openIntro(ctl);
              }

              final k = ctl.startSlot;
              final old = ctl.slotInfo(k);
              if (old == null) {
                go();
              } else {
                confirmThen(ctl,
                    title: tr('枠{0}に上書きする', [k]),
                    text: tr('枠{0}の{1}の会社（{2}・時価総額{3}）は消え、新しい会社に置き換わります。', [k, nmL(old.name), ym(old.year, old.q), yen(old.cap)]),
                    yes: tr('上書きして始める'),
                    onYes: go);
              }
            }, primary: true, enabled: st.traits.length >= 2),
          ),
        ]),
      ),
    );
  }

  /// 続きからの一覧の1行（年月・社長の名前・時価総額・順位）
  Widget _slotRow(int i, SlotInfo? info, {bool last = false}) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: last ? null : const BoxDecoration(border: Border(bottom: BorderSide(color: Pal.line))),
        child: Row(children: [
          SizedBox(width: 56, child: Text(tr('枠{0}', [i]), style: ts(bold: true, color: Pal.goldtx))),
          Expanded(
            child: info == null
                ? Muted(tr('空き'), size: 13)
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${ym(info.year, info.q)}${tr('　')}${nmL(info.name)}', style: ts(size: 14, bold: true)),
                    Text(
                        '${tr('時価総額{0}・世界{1}', [yen(info.cap), info.rank > 0 ? tr('{0}位', [info.rank]) : '―'])}'
                        '\n${modeName(info.mode)}${tr('・')}${diffOf(info.diff).n}${info.ended ? tr('・決着済み') : ''}',
                        style: ts(size: 12, color: Pal.mute, height: 1.4)),
                  ]),
          ),
          if (info != null)
            Btn(tr('続きから'), () {
              if (ctl.load(i)) {
                ctl.tab = 'town';
                ctl.render();
              }
            }, primary: true, small: true),
        ]),
      );

  static String _slotShort(SlotInfo? i) => i == null ? tr('空き') : tr('使用中：{0} {1}', [yearL(i.year), nmL(i.name)]);
}

String modeName(String m) => switch (m) {
      'quad' => tr('1000兆円'),
      'endless' => tr('終わりなし'),
      _ => tr('世界一位'),
    };

// ===== 本体 =====
class MainScreen extends StatelessWidget {
  final GameController ctl;
  const MainScreen({super.key, required this.ctl});

  static const tabs = [('town', '街@@tab'), ('biz', '事業@@tab'), ('people', '人@@tab'), ('stock', '株@@tab'), ('num', '数字@@tab'), ('zukan', '図鑑@@tab')];

  @override
  Widget build(BuildContext context) {
    final s = ctl.game!;
    final rk = s.rank != 0 ? s.rank : s.rankList().indexWhere((x) => x.me) + 1;
    final body = switch (ctl.tab) {
      'biz' => bizTab(ctl),
      'people' => peopleTab(ctl),
      'stock' => stockTab(ctl),
      'num' => numTab(ctl),
      'zukan' => zukanTab(ctl),
      _ => townTab(ctl),
    };
    final header = Container(
      decoration: const BoxDecoration(color: Pal.sky, border: Border(bottom: BorderSide(color: Pal.line))),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text(ym(s.year, s.q, sp: true), style: ts(size: 18, color: Pal.goldtx, bold: true)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(tr('{0}・{1}歳{2}', [nmL(s.pres.name), s.pres.age, s.gen > 1 ? tr('（{0}代目）', [s.gen]) : '']),
                  textAlign: TextAlign.right, overflow: TextOverflow.ellipsis, style: ts(size: 12.5, color: Pal.mute))),
          const SizedBox(width: 8),
          Semantics(label: tr('遊び方'), child: Btn(tr('？'), () => showHelp(ctl), small: true)),
          const SizedBox(width: 6),
          Semantics(
            label: tr('設定'),
            button: true,
            child: TapArea(
              key: const ValueKey('settings-tap'),
              onTap: () => openSettings(ctl),
              child: Material(
              color: Pal.panel2,
              shape: RoundedRectangleBorder(side: const BorderSide(color: Pal.line), borderRadius: BorderRadius.circular(8)),
              child: InkWell(
                key: const ValueKey('settings'),
                borderRadius: BorderRadius.circular(8),
                onTap: () => openSettings(ctl),
                child: const Padding(padding: EdgeInsets.all(5), child: Icon(Icons.settings, size: 18, color: Pal.ink)),
              ),
            )),
          ),
        ]),
        const SizedBox(height: 4),
        Wrap(spacing: 14, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
          FlashStat(tr('現金 '), yen(s.cash), value: s.cash, turn: s.turn),
          if (s.debt > 0) _stat(tr('借金 '), yen(s.debt), Pal.down),
          FlashStat(tr('時価総額 '), yen(s.cap), value: s.cap, turn: s.turn, color: Pal.goldtx),
          if (s.wealth > 0) _stat(tr('財産 '), yen(s.wealth)),
          FlashStat(tr('世界 '), tr('{0}位', [rk]), value: rk.toDouble(), turn: s.turn, higherIsBetter: false),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(tr('手 '), style: ts(size: 12.5, color: Pal.mute)),
            for (var i = 0; i < s.apMax; i++)
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(right: 3),
                decoration: BoxDecoration(color: i < s.ap ? Pal.gold : Pal.line, borderRadius: BorderRadius.circular(2)),
              ),
          ]),
        ]),
      ]),
    );
    final result = s.won != null || s.over != null
        ? Panel(
            border: s.won != null ? Pal.gold : Pal.down,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              H2(tr(s.won != null ? '達成！' : 'ゲームオーバー'), top: true),
              Text(tx(s.won ?? s.over), style: ts()),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (s.won != null && s.over == null) Btn(tr('このまま続ける'), () => continueAfterWin(ctl)),
                Btn(tr('まとめを見る'), () {
                  ctl.endHidden = false;
                  ctl.render();
                }),
                Btn(tr('はじめから'), () => s.over != null ? ctl.backToSetup() : confirmRestart(ctl)),
              ]),
            ]),
          )
        : null;
    return Column(children: [
      header,
      Expanded(
        child: ListView(
          key: PageStorageKey('tab-${ctl.tab}'),
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          children: [?result, ...body],
        ),
      ),
      if (s.over == null)
        Container(
          color: Pal.sky,
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          // 出来事が起きたらそこで止まる
          child: Row(children: [
            Btn(tr('1年進める'), () => doYear(ctl, 12), small: true),
            const SizedBox(width: 6),
            Btn(tr('3か月進める'), () => doYear(ctl, 3), small: true),
            const SizedBox(width: 6),
            Expanded(
              // 幅が足りないときは字だけ縮める（押せる高さは 44pt のまま）
              child: Align(
                alignment: Alignment.centerRight,
                child: Btn(s.ap > 0 ? tr('次の月へ（手が{0}残っています）', [s.ap]) : tr('次の月へ'), () => doNext(ctl), primary: true, shrink: true),
              ),
            ),
          ]),
        ),
      Container(
        decoration: const BoxDecoration(color: Pal.panel, border: Border(top: BorderSide(color: Pal.line))),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(children: [
              for (final t in tabs)
                Expanded(
                  child: InkWell(
                    key: ValueKey('tab-${t.$1}'),
                    onTap: () => ctl.setTab(t.$1),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: minTap),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(tr(t.$2),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            style: ts(size: 13, color: ctl.tab == t.$1 ? Pal.goldtx : Pal.mute, bold: ctl.tab == t.$1)),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    ]);
  }

  Widget _stat(String k, String v, [Color c = Pal.ink]) => Text.rich(TextSpan(children: [
        TextSpan(text: tx(k), style: ts(size: 12.5, color: Pal.mute)),
        TextSpan(text: v, style: ts(size: 12.5, color: c, bold: true)),
      ]));
}

/// 勝ったあと、終わりなしのモードで続ける
void continueAfterWin(GameController ctl) {
  final s = ctl.game!;
  s.mode = 'endless';
  s.won = null;
  ctl.endHidden = false;
  ctl.save();
  ctl.render();
}

// ===== 終わったときのまとめ =====
class EndScreen extends StatelessWidget {
  final GameController ctl;
  const EndScreen({super.key, required this.ctl});

  @override
  Widget build(BuildContext context) {
    final s = ctl.game!;
    final win = s.won != null && s.over == null;
    final accent = win ? Pal.goldtx : Pal.down;
    final years = s.year - s.startYear;
    final marks = s.highlights();
    Widget stat(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Expanded(child: Text(k, style: ts(size: 13.5, color: Pal.mute))),
            Text(v, style: ts(size: 15, bold: true)),
          ]),
        );
    return Material(
      color: Pal.sky,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 28, 16, 32), children: [
              Text(tr(win ? '達成！' : 'ゲームオーバー'), style: ts(size: 30, bold: true, color: accent)),
              const SizedBox(height: 6),
              Text(tx(s.won ?? s.over), style: ts(size: 15, height: 1.5)),
              const SizedBox(height: 4),
              Muted('${nmL(s.pres.name)}${s.gen > 1 ? tr('（{0}代目）', [s.gen]) : ''}${tr('・')}${ym(s.year, s.q)}'),
              const SizedBox(height: 14),
              Panel(
                border: win ? Pal.gold : Pal.line,
                child: Column(children: [
                  stat(tr('創業から'), tr('{0}年（{1}年〜）', [years, s.startYear])),
                  stat(tr('世界ランキングの最高位'), s.peakRank >= 999 ? '―' : tr('{0}位', [s.peakRank])),
                  stat(tr('時価総額の最大'), yen(s.maxCap)),
                  stat(tr('財産の最大'), yen(s.maxWealth)),
                ]),
              ),
              if (marks.isNotEmpty) ...[
                H2(tr('社史の節目')),
                Panel(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    for (final e in marks)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          SizedBox(width: 84, child: Text(ym(e.y, e.q), style: ts(size: 12.5, color: Pal.mute))),
                          Expanded(child: Text(tx(e.m), style: ts(size: 13.5, height: 1.45))),
                        ]),
                      ),
                  ]),
                ),
              ],
              const SizedBox(height: 18),
              if (win) ChoiceBtn(tr('このまま続ける'), () => continueAfterWin(ctl), primary: true, subs: [tr('「終わりなし」のモードで、この会社を育て続ける')]),
              ChoiceBtn(tr('はじめから'), () => win ? confirmRestart(ctl) : ctl.backToSetup(), primary: !win, subs: [tr('新しい会社を立ち上げる')]),
              Align(
                alignment: Alignment.centerLeft,
                child: Btn(tr('盤面を見る'), () {
                  ctl.endHidden = true;
                  ctl.render();
                }),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
