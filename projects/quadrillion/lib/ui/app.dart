import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

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
        // 小窓は閉じたあとも沈み切るまで描くので、いつも置いておく
        Positioned.fill(child: SheetLayer(key: const ValueKey('sheet-layer'), ctl: ctl)),
      ]),
    );
  }
}

/// 小窓の出入りの動き
class SheetMotion {
  SheetMotion._();

  /// 出てくる長さと、沈む長さ（テストの決まりでは 0 にして、1回の描画で開け閉めし切る。動きを確かめるテストだけ元に戻す）
  static Duration duration = const Duration(milliseconds: 240);
  static Duration reverseDuration = const Duration(milliseconds: 200);
  static const curve = Curves.easeOutCubic;
  static const reverseCurve = Curves.easeInCubic;

  /// 後ろの幕の色（開き切ったとき）
  static const scrim = Color(0x59282832);

  /// 元の長さに戻す
  static void reset() {
    duration = const Duration(milliseconds: 240);
    reverseDuration = const Duration(milliseconds: 200);
  }
}

/// 小窓の層。開くと下から滑り出て、後ろの幕が薄く出る。閉じると沈み、幕も引く。
/// 沈むあいだは最後の中身をそのまま見せる（中身を作り直さないので、ゲームが無くなっても落ちない）。押しても何も起きない
class SheetLayer extends StatefulWidget {
  final GameController ctl;
  const SheetLayer({super.key, required this.ctl});
  @override
  State<SheetLayer> createState() => SheetLayerState();
}

class SheetLayerState extends State<SheetLayer> with SingleTickerProviderStateMixin {
  late final AnimationController anim = AnimationController(vsync: this, duration: SheetMotion.duration, reverseDuration: SheetMotion.reverseDuration)
    ..addStatusListener(_onStatus);
  late final Animation<double> _curved = CurvedAnimation(parent: anim, curve: SheetMotion.curve, reverseCurve: SheetMotion.reverseCurve);

  /// 狭い画面で、下の端から出入りするあいだだけ薄くする（はじめの3割ほどで濃くなり切る）
  late final Animation<double> _edgeFade = CurvedAnimation(parent: anim, curve: const Interval(0, .35));

  /// 今見せている小窓（閉じて沈むあいだも残す）
  Widget? _card;

  /// 閉じて沈んでいるところか
  bool get closing => widget.ctl.sheet == null && _card != null;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(SheetLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    anim.duration = SheetMotion.duration;
    anim.reverseDuration = SheetMotion.reverseDuration;
    final open = widget.ctl.sheet != null;
    final st = anim.status;
    if (open && (st == AnimationStatus.dismissed || st == AnimationStatus.reverse)) {
      anim.forward();
    } else if (!open && (st == AnimationStatus.forward || st == AnimationStatus.completed)) {
      anim.reverse();
    }
  }

  void _onStatus(AnimationStatus st) {
    if (st != AnimationStatus.dismissed || widget.ctl.sheet != null) return;
    _card = null;
    // 描いている途中（長さ0で閉じたとき）は、このあとの描画で消えるので描き直しは頼まない
    if (mounted && SchedulerBinding.instance.schedulerPhase != SchedulerPhase.persistentCallbacks) setState(() {});
  }

  @override
  void dispose() {
    anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctl = widget.ctl;
    final sheet = ctl.sheet;
    if (sheet != null) {
      _card = Material(
        color: Pal.panel,
        shape: RoundedRectangleBorder(side: const BorderSide(color: Pal.line), borderRadius: BorderRadius.circular(Ui.sheetRadius)),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          key: ValueKey('sheet${ctl.sheetSeq}'),
          padding: const EdgeInsets.all(Ui.sheetPad),
          child: Builder(builder: sheet),
        ),
      );
    }
    final card = _card;
    if (card == null || anim.isDismissed) return const SizedBox.shrink();
    return IgnorePointer(
      ignoring: sheet == null,
      child: Stack(children: [
        Positioned.fill(child: FadeTransition(key: const ValueKey('sheet-scrim'), opacity: _curved, child: const ColoredBox(color: SheetMotion.scrim))),
        Positioned.fill(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: LayoutBuilder(builder: (context, c) {
                final wide = c.maxWidth >= 700;
                return Align(
                  alignment: wide ? Alignment.center : Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 620, maxHeight: c.maxHeight * .94),
                    // 狭い画面は下から滑り出る（下の余白12を越えて隠れ切るよう、高さの1.1倍ぶん下から）。広い画面は少しだけ上がりながら出る
                    child: SlideTransition(
                      key: const ValueKey('sheet-slide'),
                      position: Tween(begin: Offset(0, wide ? .04 : 1.1), end: Offset.zero).animate(_curved),
                      child: FadeTransition(
                        opacity: wide ? _curved : _edgeFade,
                        child: DecoratedBox(
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(Ui.sheetRadius), boxShadow: Ui.sheetShadow),
                          child: card,
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

  /// 下のタブのアイコン（選んでいないときは線の形、選んだら塗りの形）
  static const tabIcons = {
    'town': (Icons.location_city_outlined, Icons.location_city),
    'biz': (Icons.work_outline, Icons.work),
    'people': (Icons.people_outline, Icons.people),
    'stock': (Icons.pie_chart_outline, Icons.pie_chart),
    'num': (Icons.bar_chart_outlined, Icons.bar_chart),
    'zukan': (Icons.menu_book_outlined, Icons.menu_book),
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
              shape: Ui.partShape(),
              child: InkWell(
                key: const ValueKey('settings'),
                borderRadius: BorderRadius.circular(Ui.partRadius),
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
          // 手：金の四角（残り）と灰の四角（使った分）に、残りの数を数字でも添える
          Semantics(
            label: tr('今月の手 残り{0}/{1}', [s.ap, s.apMax]),
            excludeSemantics: true,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(tr('手 '), style: ts(size: 12.5, color: Pal.mute)),
              for (var i = 0; i < s.apMax; i++)
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(right: 3),
                  decoration: BoxDecoration(
                      color: i < s.ap ? Pal.gold : Pal.panel2,
                      border: Border.all(color: i < s.ap ? const Color(0xFFD9A62E) : Pal.line),
                      borderRadius: BorderRadius.circular(2)),
                ),
              const SizedBox(width: 2),
              Text('${s.ap}/${s.apMax}', key: const ValueKey('ap-count'), style: ts(size: 12.5, bold: true, color: s.ap > 0 ? Pal.goldtx : Pal.mute)),
            ]),
          ),
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
                  child: Semantics(
                    selected: ctl.tab == t.$1,
                    child: InkWell(
                      key: ValueKey('tab-${t.$1}'),
                      borderRadius: BorderRadius.circular(Ui.radius),
                      onTap: () => ctl.setTab(t.$1),
                      child: TabItem(icon: tabIcons[t.$1]!, label: tr(t.$2), on: ctl.tab == t.$1),
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

/// 下のタブの1つ（アイコンの上に字）。選んでいるタブは、アイコンの後ろに金の塗りの丸札を敷き、字を金にする
class TabItem extends StatelessWidget {
  final (IconData, IconData) icon;
  final String label;
  final bool on;
  const TabItem({super.key, required this.icon, required this.label, required this.on});
  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 54),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: 48,
            height: 28,
            // 消えるときも金のまま薄くなる（透明の黒を混ぜると途中で濁る）
            decoration: BoxDecoration(color: on ? Pal.gold : Pal.gold.withValues(alpha: 0), borderRadius: BorderRadius.circular(14)),
            child: Icon(on ? icon.$2 : icon.$1, size: 21, color: on ? const Color(0xFF1A1300) : Pal.mute),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, textAlign: TextAlign.center, maxLines: 1, style: ts(size: 11.5, color: on ? Pal.goldtx : Pal.mute, bold: on, height: 1.2)),
          ),
        ]),
      );
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
