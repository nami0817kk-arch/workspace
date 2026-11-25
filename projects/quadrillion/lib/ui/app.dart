import 'package:flutter/material.dart';

import '../game/game.dart';
import 'controller.dart';
import 'real_screens.dart';
import 'sheets.dart';
import 'stock_screen.dart';
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
      // 端末の「文字を大きく」に従う。ただし大きすぎると表や帯が崩れるので、[Ui.maxTextScale] 倍までに抑える
      builder: (context, child) {
        final scale = (MediaQuery.textScalerOf(context).scale(100) / 100).clamp(1.0, Ui.maxTextScale).toDouble();
        Ui.textScale = scale;
        return MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!);
      },
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
        Positioned.fill(child: SheetHost(sheet: sheet, seq: ctl.sheetSeq)),
      ]),
    );
  }
}

/// 小窓を重ねる所。開くときは下から滑り出て、閉じるときは沈む。後ろの幕も薄く出入りする。
/// 小窓から次の小窓へ続くとき（手の結果・出来事の続き）は、出入りさせずに中身だけ替える。
/// 沈んでいるあいだは中身を描き直さず（閉じたあとの盤面で組み直すと、もう無い事業を見に行くことがある）、押しても動かない
class SheetHost extends StatefulWidget {
  final WidgetBuilder? sheet;
  final int seq;
  const SheetHost({super.key, required this.sheet, required this.seq});

  @override
  State<SheetHost> createState() => SheetHostState();
}

class SheetHostState extends State<SheetHost> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: Ui.sheetMotion, value: widget.sheet != null ? 1 : 0)
    ..addStatusListener((st) {
      // 沈みきったら、残していた中身を外す
      if (st != AnimationStatus.dismissed || !mounted) return;
      _last = null;
      // 出入りの時間が0のときは、描き直しの途中でここに来る（そのまま次の描画に任せる）
      if (!_updating) setState(() {});
    });
  late final Animation<double> _curve = CurvedAnimation(parent: _a, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
  late final Animation<Offset> _slide = Tween(begin: const Offset(0, 1.08), end: Offset.zero).animate(_curve);
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    // late の初期化はここで済ませる（最初に開くときから出入りさせるため）
    _a.value = widget.sheet != null ? 1 : 0;
  }

  /// 最後に描いた小窓（沈むあいだ、これをそのまま見せる）
  Widget? _last;

  /// 出入りの進み（0 閉じている〜1 開いている）。テストから見る
  double get progress => _a.value;

  /// 沈んでいる途中か
  bool get closing => widget.sheet == null && _last != null;

  @override
  void didUpdateWidget(SheetHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.sheet == null) == (widget.sheet == null)) return;
    _a.duration = MediaQuery.maybeDisableAnimationsOf(context) == true ? Duration.zero : Ui.sheetMotion;
    _updating = true;
    if (widget.sheet != null) {
      _a.forward();
    } else {
      _a.reverse();
    }
    _updating = false;
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sheet = widget.sheet;
    if (sheet != null) {
      _last = SingleChildScrollView(
        key: ValueKey('sheet${widget.seq}'),
        padding: const EdgeInsets.all(Ui.sheetPad),
        child: Builder(builder: sheet),
      );
    }
    final body = _last;
    if (body == null) return const SizedBox.shrink();
    return IgnorePointer(
      ignoring: sheet == null,
      child: Stack(children: [
        Positioned.fill(child: FadeTransition(opacity: _curve, child: const ColoredBox(key: ValueKey('sheet-scrim'), color: Ui.scrim))),
        Positioned.fill(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: LayoutBuilder(builder: (context, c) {
                return Align(
                  alignment: c.maxWidth >= 700 ? Alignment.center : Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: Ui.maxSheet, maxHeight: c.maxHeight * .94),
                    // 小窓の高さのぶんだけ下から上がってくる（沈むときは逆）
                    child: SlideTransition(
                      position: _slide,
                      child: Container(
                        key: const ValueKey('sheet-card'),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(Ui.rSheet), boxShadow: Ui.sheetShadow),
                        child: Material(
                          color: Pal.panel,
                          shape: RoundedRectangleBorder(side: const BorderSide(color: Pal.line), borderRadius: BorderRadius.circular(Ui.rSheet)),
                          clipBehavior: Clip.antiAlias,
                          child: body,
                        ),
                      ),
                    ),
                  ),
                );
              }),
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
        constraints: const BoxConstraints(maxWidth: Ui.maxBody),
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
            // 統計がまだ無い年の国は選べない（ロシアは1991年まで。1.1.0+25）
            for (final x in CTRY.where((x) => st.year >= econData.availableFrom(x.c)))
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
        decoration: last ? null : Ui.rowLine,
        child: Row(children: [
          SizedBox(width: Ui.sw(56), child: Text(tr('枠{0}', [i]), style: ts(bold: true, color: Pal.goldtx))),
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

  /// 「次の月へ」のボタンに残りの時間まで書く、ボタンの欄の最小の幅（字の倍率で割った幅。これより狭いと「次の月へ」だけ）
  static const nextLongMin = 220.0;

  /// 左の切り替え（id・名前）
  static List<(String, String)> get tabs => [for (final t in railTabs) (t.$1, t.$2)];

  @override
  Widget build(BuildContext context) {
    final s = ctl.game!;
    return LayoutBuilder(builder: (context, box) {
      final side = box.maxWidth >= sidePanelMin;
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
      final center = LayoutBuilder(builder: (context, cb) {
        final w = cb.maxWidth - 16;
        final body = switch (ctl.tab) {
          'biz' => bizTab(ctl, width: w),
          'people' => peopleTab(ctl, width: w),
          'stock' => stockScreen(ctl, width: w),
          'money' => moneyTab(ctl),
          'world' => worldTab(ctl, w),
          'zukan' => zukanTab(ctl),
          _ => townTabL(ctl, w),
        };
        return ListView(
          key: PageStorageKey('tab-${ctl.tab}'),
          // 「事業」だけ、位置を外から動かせるようにする（「今月やること」から事業のカードへ飛ぶ）
          controller: ctl.tab == 'biz' ? ctl.bizScroll : null,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          children: [?result, ...body],
        );
      });
      final bottom = s.over == null
          ? Container(
              decoration: const BoxDecoration(color: Pal.panel, border: Border(top: BorderSide(color: Pal.line))),
              padding: const EdgeInsets.fromLTRB(8, 3, 8, 3),
              child: Row(children: [
                // まとめて進めるのは1つのボタンにまとめ、押すと長さ（何か起きるまで・3か月・1年）を選ぶ小窓が開く
                Btn(tr('まとめて進める'), () => openAdvance(ctl), key: const ValueKey('advance-menu'), small: true, more: true),
                const SizedBox(width: 6),
                // 社長の行動（相棒探し・日銭・腕磨き・人脈・種探し・休む）は、いつでも押せるよう下の帯に置く
                Btn(tr('社長の行動'), () => openPresSheet(ctl), key: const ValueKey('pres-open'), small: true, more: true),
                const SizedBox(width: 6),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: LayoutBuilder(
                        builder: (context, c) => Btn(
                            s.hNormalLeft() > 0 && c.maxWidth / Ui.textScale >= nextLongMin ? tr('次の月へ（社長の時間があと{0}時間）', [jsRound(s.hNormalLeft())]) : tr('次の月へ'),
                            () => doNext(ctl),
                            key: const ValueKey('next'),
                            primary: true,
                            shrink: true)),
                  ),
                ),
              ]),
            )
          : null;
      return Column(children: [
        topBar(ctl, side: side),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            leftRail(ctl),
            Expanded(child: center),
            if (side)
              Container(
                width: sideW,
                decoration: const BoxDecoration(color: Pal.sky, border: Border(left: BorderSide(color: Pal.line))),
                child: NoShrink(child: ListView(key: const ValueKey('side'), padding: const EdgeInsets.fromLTRB(6, 2, 6, 10), children: sideItems(ctl))),
              ),
          ]),
        ),
        ?bottom,
      ]);
    });
  }
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
    // 20年を超えて遊んだ会社は、節目を7つまで出す（5つだと、後半の出来事が入りきらない。それ以上は長くしない。1.0.0+18）
    final marks = s.highlights(years >= 20 ? 7 : 5);
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
            constraints: const BoxConstraints(maxWidth: Ui.maxBody),
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 28, 16, 32), children: [
              Text(tr(win ? '達成！' : 'ゲームオーバー'), style: ts(size: 30, bold: true, color: accent)),
              const SizedBox(height: 6),
              Text(tx(s.won ?? s.over), style: ts(size: 15, height: 1.5)),
              const SizedBox(height: 4),
              Row(children: [
                presFace(s, size: faceBig),
                const SizedBox(width: 10),
                Expanded(child: Muted('${nmL(s.pres.name)}${s.gen > 1 ? tr('（{0}代目）', [s.gen]) : ''}${tr('・')}${ym(s.year, s.q)}')),
              ]),
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
                          SizedBox(width: Ui.sw(84), child: Text(ym(e.y, e.q), style: ts(size: 12.5, color: Pal.mute))),
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
