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

  static const tabs = [('town', '街@@tab'), ('biz', '事業@@tab'), ('people', '人@@tab'), ('stock', '株@@tab'), ('num', '数字@@tab'), ('zukan', '図鑑@@tab')];

  /// 「次の月へ」のボタンに残りの手の数まで書く、ボタンの欄の最小の幅（字の倍率で割った幅。これより狭いと「次の月へ」だけ）
  static const nextLongMin = 160.0;

  /// 下のタブのアイコン
  static const tabIcons = <String, IconData>{
    'town': Icons.location_city,
    'biz': Icons.work,
    'people': Icons.people,
    'stock': Icons.pie_chart,
    'num': Icons.bar_chart,
    'zukan': Icons.menu_book,
  };

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
      child: Wide(
          child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          // 年月の下に社長の名前と年齢。代は札にして、幅が足りなければ次の行へ回す（名前は切らない）
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(ym(s.year, s.q, sp: true), style: ts(size: 18, color: Pal.goldtx, bold: true, height: 1.25)),
              // 名前・年齢・代の札は、入りきらなければ区切りごとに次の行へ回る（長い外国の名前でも切らない）
              Wrap(runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(nmL(s.pres.name), key: const ValueKey('pres-name'), maxLines: 1, softWrap: false, style: ts(size: 12.5, color: Pal.mute)),
                ),
                Text(tr('・{0}歳', [s.pres.age]), key: const ValueKey('pres-age'), maxLines: 1, softWrap: false, style: ts(size: 12.5, color: Pal.mute)),
                if (s.gen > 1)
                  Padding(padding: const EdgeInsets.only(left: 6), child: Tag(tr('{0}代目', [s.gen]), key: const ValueKey('pres-gen'))),
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          // 読み上げでは「？」ではなく「遊び方」と読む
          Semantics(
              label: tr('遊び方'),
              button: true,
              excludeSemantics: true,
              onTap: () => showHelp(ctl),
              child: Btn(tr('？'), () => showHelp(ctl), key: const ValueKey('help'), small: true)),
          const SizedBox(width: 6),
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
        const SizedBox(height: 4),
        Wrap(spacing: 14, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
          FlashStat(tr('現金 '), yen(s.cash), value: s.cash, turn: s.turn),
          if (s.debt > 0) _stat(tr('借金 '), yen(s.debt), Pal.down),
          FlashStat(tr('時価総額 '), yen(s.cap), value: s.cap, turn: s.turn, color: Pal.goldtx),
          if (s.wealth > 0) _stat(tr('財産 '), yen(s.wealth)),
          FlashStat(tr('世界 '), tr('{0}位', [rk]), value: rk.toDouble(), turn: s.turn, higherIsBetter: false),
          // 今月の残りの手。金の四角に、数字（残り/全部）も添える
          Semantics(
            label: tr('手 残り{0}／{1}', [s.ap, s.apMax]),
            excludeSemantics: true,
            child: Row(key: const ValueKey('ap'), mainAxisSize: MainAxisSize.min, children: [
              Text(tr('手 '), style: ts(size: 12.5, color: Pal.mute)),
              for (var i = 0; i < s.apMax; i++)
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(right: 3),
                  decoration: BoxDecoration(color: i < s.ap ? Pal.gold : Pal.line, borderRadius: BorderRadius.circular(2)),
                ),
              const SizedBox(width: 2),
              Text('${s.ap}/${s.apMax}', key: const ValueKey('ap-count'), style: ts(size: 12.5, color: s.ap > 0 ? Pal.goldtx : Pal.mute, bold: true)),
            ]),
          ),
        ]),
      ]),
      )),
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
        // 幅の広い画面では、一覧は端から端まで動かせるまま、中身だけを中央の幅に収める（左右は余白）
        child: LayoutBuilder(builder: (context, box) {
          final side = 12 + Ui.sideGap(box.maxWidth);
          return ListView(
            key: PageStorageKey('tab-${ctl.tab}'),
            // 「事業」だけ、位置を外から動かせるようにする（「今月やること」から事業のカードへ飛ぶ）
            controller: ctl.tab == 'biz' ? ctl.bizScroll : null,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(side, 0, side, 16),
            children: [?result, ...body],
          );
        }),
      ),
      if (s.over == null)
        Container(
          color: Pal.sky,
          // 出来事が起きたらそこで止まる
          child: Wide(
              child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: Row(children: [
            // まとめて進めるのは1つのボタンにまとめ、押すと長さ（何か起きるまで・3か月・1年）を選ぶ小窓が開く
            Btn(tr('まとめて進める'), () => openAdvance(ctl), key: const ValueKey('advance-menu'), small: true, more: true),
            const SizedBox(width: 6),
            Expanded(
              // 幅が足りないときは字だけ縮める（押せる高さは 44pt のまま）
              child: Align(
                alignment: Alignment.centerRight,
                // 幅が狭い・字が大きいときは、残りの手の数を省く（上の帯の「手」に出ている。入れると字が豆粒になる）
                child: LayoutBuilder(
                    builder: (context, c) => Btn(
                        s.ap > 0 && c.maxWidth / Ui.textScale >= nextLongMin ? tr('次の月へ（手が{0}残っています）', [s.ap]) : tr('次の月へ'), () => doNext(ctl),
                        key: const ValueKey('next'), primary: true, shrink: true)),
              ),
            ),
          ]),
          )),
        ),
      Container(
        decoration: const BoxDecoration(color: Pal.panel, border: Border(top: BorderSide(color: Pal.line))),
        child: SafeArea(
          top: false,
          child: Wide(
              child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Row(children: [
              for (final t in tabs)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: ctl.tab == t.$1,
                    child: InkWell(
                      key: ValueKey('tab-${t.$1}'),
                      borderRadius: BorderRadius.circular(Ui.rBtn),
                      onTap: () => ctl.setTab(t.$1),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: minTap),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          // 選んでいるタブは、アイコンの後ろに金の丸い帯を敷く
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 46,
                            height: 26,
                            decoration: BoxDecoration(color: ctl.tab == t.$1 ? Pal.gold : Pal.gold.withValues(alpha: 0), borderRadius: BorderRadius.circular(13)),
                            child: Icon(tabIcons[t.$1], size: 20, color: ctl.tab == t.$1 ? const Color(0xFF1A1300) : Pal.mute),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(tr(t.$2),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                style: ts(size: 11.5, color: ctl.tab == t.$1 ? Pal.goldtx : Pal.mute, bold: ctl.tab == t.$1, height: 1.3)),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
            ]),
          )),
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
