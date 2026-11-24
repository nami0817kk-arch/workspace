import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';
import 'package:quadrillion/ui/app.dart';
import 'package:quadrillion/ui/controller.dart';
import 'package:quadrillion/ui/glossary.dart';
import 'package:quadrillion/ui/sheets.dart';
import 'package:quadrillion/ui/tabs.dart';
import 'package:quadrillion/ui/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bot.dart';

/// 画面を実際に押して遊ぶ役（通しの点検）。
/// 仕組みの関数を直接呼ばず、ボタン・札・選ぶ欄を「見える所まで動かして、押して、描き直す」道筋だけで進める。
/// 押すたびに、例外・はみ出し・文の抜け・数字の壊れ・値段の食い違いを調べ、見つけたものを [found] にためる
class Pilot {
  final WidgetTester t;
  final GameController ctl;

  /// 見つけた不具合（場面つき）
  final List<String> found = [];

  /// 通った場面（何をどれだけ押したか）
  final Map<String, int> seen = {};

  /// 今の場面の名前（見つけたものに添える）
  String where = 'start';

  Pilot(this.t, this.ctl);

  Game get s => ctl.game!;

  /// アプリを立ち上げる（はじめの画面）
  static Future<Pilot> launch(WidgetTester t, {String lang = 'ja', Size size = const Size(844, 390), double textScale = 1, int seed = 77, Game? game, Key? boundary}) async {
    // 1.1.0+25 から横向きの画面。縦の大きさ（幅320・390）を渡されたら、iPhone の横（844×390）で見る
    if (size.width < size.height) size = const Size(844, 390);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final ctl = GameController(prefs: prefs, newRandom: () => ParkMiller(seed), lang: lang);
    L.lang = lang;
    addTearDown(() => L.lang = 'ja');
    addTearDown(() => Ui.textScale = 1);
    ctl.buzz = (_) {};
    ctl.game = game;
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(t.view.reset);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    // [boundary] を渡すと、画面を PNG に描き出せる（目で見る確認用）
    await t.pumpWidget(boundary == null ? QuadrillionApp(controller: ctl) : RepaintBoundary(key: boundary, child: QuadrillionApp(controller: ctl)));
    await t.pump();
    final p = Pilot(t, ctl);
    p.check();
    return p;
  }

  void note(String m) {
    final line = '[$where] $m';
    if (found.contains(line)) return;
    found.add(line);
    // 長い通しでは、終わるのを待たずに見えるようにする
    if (verbose) say('見つけた: $line');
  }

  void mark(String k) => seen[k] = (seen[k] ?? 0) + 1;

  // ===== 調べる =====
  static final _bad = RegExp(r'NaN|Infinity|\{\d+\}|@@|[\u0001\u0002\u0003]|\bnull\b|undefined|Instance of');
  static final _jp = RegExp(r'[぀-ヿ㐀-鿿＀-￯、。「」・]');
  static final _minusCount = RegExp(r'-\d+(人|件|社|つ|店舗|か所|か月|か国|位|歳)');

  /// 英語の画面でも日本語のままでよい字（言語を選ぶ欄）
  static const _jpOk = ['言語 / Language', '日本語'];

  /// 画面に出ている字を全部集める
  List<String> texts() => [
        for (final w in t.allWidgets)
          if (w is RichText) w.text.toPlainText() else if (w is EditableText) w.controller.text,
      ];

  /// 2行に折れていたボタン（字 → 見つけた場面と幅）。[watchWraps] を立てたときだけ集める（本物のフォントで描いているときに使う）
  final Map<String, String> wraps = {};
  bool watchWraps = false;

  /// 画面に出ているふつうのボタン（[Btn]）のうち、字が2行以上に折れているものを [wraps] に控える。
  /// 1行の高さは字の大きさの約1.45倍なので、2.2倍を超えていれば折れている
  void _collectWraps() {
    for (final e in find.byType(Btn).evaluate()) {
      final btn = e.widget as Btn;
      // 幅の狭い右の帯（1.1.0+25）のボタンは、字を縮めずに折り返す作り（NoShrink）なので数えない
      if (e.findAncestorWidgetOfExactType<NoShrink>() != null) continue;
      void visit(Element c) {
        final ro = c.renderObject;
        if (c.widget is RichText && ro is RenderParagraph && ro.hasSize) {
          final fs = (ro.text.style?.fontSize ?? 14) * Ui.textScale;
          if (ro.size.height > fs * 2.2 && ro.text.toPlainText() == tx(btn.label)) {
            wraps.putIfAbsent(tx(btn.label), () => '$where（ボタンの幅 ${e.size?.width.round()}・字の高さ ${ro.size.height.round()}）');
          }
        }
        c.visitChildren(visit);
      }

      e.visitChildren(visit);
    }
  }

  /// 例外・はみ出し・文の抜け・数字の壊れを調べる
  void check() {
    if (watchWraps) _collectWraps();
    for (;;) {
      final e = t.takeException();
      if (e == null) break;
      final lines = e.toString().split('\n').where((l) => l.trim().isNotEmpty).toList();
      final at = lines.where((l) => l.contains('.dart:')).take(1).join();
      note('例外: ${lines.first}${at.isEmpty ? '' : ' ← ${at.trim()}'}${lines.first.contains('overflowed') || lines.first.contains('Multiple exceptions') ? ' ${_overflowing()}' : ''}');
    }
    for (final x in texts()) {
      if (_bad.hasMatch(x)) note('文の抜け・壊れた数字: 「${_clip(x)}」');
      if (_minusCount.hasMatch(x)) note('負の数: 「${_clip(x)}」');
      if (L.en && _jp.hasMatch(x) && !_jpOk.contains(x)) note('英語に日本語: 「${_clip(x)}」');
    }
    final g = ctl.game;
    if (g != null) {
      for (final v in [g.cash, g.cap, g.rev, g.pre, g.debt, g.wealth, g.sh.own]) {
        if (!v.isFinite) note('盤面の数字が壊れた: $v');
      }
      if (g.hUsed < 0 || g.hLeft() < 0 || g.stamina > 100) note('社長の時間・体力がおかしい: ${g.hUsed}/${g.hLeft()}/${g.stamina}');
      if (g.sh.own < -.01 || g.sh.own > 100.01) note('持ち株がおかしい: ${g.sh.own}');
      final sum = g.sh.own + g.sh.pt + g.sh.vc + g.sh.ally + g.sh.float + g.sh.rivSum;
      final neg = [g.sh.pt, g.sh.vc, g.sh.ally, g.sh.float, ...g.sh.riv.values].any((v) => v < -.05);
      if (((sum - 100).abs() > .5 || neg) && !_sumNoted) {
        _sumNoted = true;
        shareSumOff = '${g.year}年${g.q}月 [$where] 合計${sum.toStringAsFixed(1)}%（あなた${g.sh.own.toStringAsFixed(1)} 相棒${g.sh.pt.toStringAsFixed(1)} 投資家${g.sh.vc.toStringAsFixed(1)} 味方${g.sh.ally.toStringAsFixed(1)} 市場${g.sh.float.toStringAsFixed(1)} 宿敵${g.sh.rivSum.toStringAsFixed(1)}）';
        if (verbose) say('株主の割合の合計が100%でない: $shareSumOff');
      }
      for (final b in g.biz) {
        if (!b.share.isFinite || b.share < 0 || b.share > 1.0001) note('シェアがおかしい: ${b.ind} ${b.share}');
      }
    }
  }

  /// はみ出している並び（Row / Column）を探して、どこの何かを書く（中の字と、外側の部品の名前）
  String _overflowing() {
    final out = <String>[];
    void visit(Element e) {
      final ro = e.renderObject;
      if (e is RenderObjectElement && ro is RenderFlex && ro.toStringShort().contains('OVERFLOWING')) {
        final inside = <String>[];
        void txt(Element c) {
          if (c.widget case final RichText r) inside.add(r.text.toPlainText());
          c.visitChildren(txt);
        }

        e.visitChildren(txt);
        final chain = <String>[];
        e.visitAncestorElements((a) {
          final w = a.widget;
          if (w.key != null) chain.add('${w.runtimeType}${w.key}');
          return chain.length < 3;
        });
        out.add('〔${ro.direction.name} ${ro.size.width.round()}×${ro.size.height.round()} 中の字: ${inside.take(6).join(' / ')} 外側: ${chain.join(' < ')}〕');
      }
      e.visitChildren(visit);
    }

    t.binding.rootElement?.visitChildren(visit);
    return out.join(' ');
  }

  /// 株主の割合の合計が100%から外れた最初の場面（仕組みの側の話なので、不具合には数えずに控えるだけ）
  String? shareSumOff;
  bool _sumNoted = false;

  String _clip(String x) => x.length > 70 ? '${x.substring(0, 70)}…' : x;

  /// 進み具合と見つけたものを、その場で書き出すか（QUAD_PILOT_VERBOSE を渡したとき）
  static final verbose = Platform.environment['QUAD_PILOT_VERBOSE'] != null;

  /// 進み具合を書き足していくファイル（QUAD_PILOT_LOG。テストの出力は終わるまで出てこないので、長い通しはここで見る）
  static final _logFile = Platform.environment['QUAD_PILOT_LOG'];
  String logTag = '';
  void say(String m) {
    final f = _logFile;
    if (f != null) File(f).writeAsStringSync('$logTag $m\n', mode: FileMode.append, flush: true);
    debugPrint(m);
  }

  /// ひと回り見る間隔（か月）と、それにかかった時間
  int tourEvery = 60;
  int tourMs = 0;
  int pumps = 0;
  final Stopwatch swPump = Stopwatch(), swCheck = Stopwatch();
  Future<void> pump() async {
    pumps++;
    swPump.start();
    await t.pump();
    swPump.stop();
    swCheck.start();
    check();
    swCheck.stop();
  }

  // ===== 動かす・押す =====
  /// 今いちばん手前にある、上下に動く欄
  ScrollableState? _scroller() {
    Finder f;
    if (ctl.sheet != null) {
      f = find.descendant(of: find.byKey(const ValueKey('sheet-card')), matching: find.byType(Scrollable));
    } else if (find.byType(EndScreen).evaluate().isNotEmpty) {
      f = find.descendant(of: find.byType(EndScreen), matching: find.byType(Scrollable));
    } else if (ctl.game != null) {
      f = find.descendant(of: find.byKey(PageStorageKey('tab-${ctl.tab}')), matching: find.byType(Scrollable));
    } else {
      f = find.byType(Scrollable);
    }
    return f.evaluate().isEmpty ? null : t.state<ScrollableState>(f.first);
  }

  /// [f] が見える所まで欄を動かす（一覧は見える分しか作られないので、上から順に送って探す）
  Future<bool> reveal(Finder f) async {
    if (!_has(f)) {
      final sc = _scroller();
      if (sc == null) return false;
      await _top(sc);
      for (var i = 0; !_has(f) && sc.position.pixels < sc.position.maxScrollExtent; i++) {
        if (i > 600) {
          note('一覧の終わりまで送れない（${sc.position.pixels} / ${sc.position.maxScrollExtent}）');
          break;
        }
        // 横向きの画面は一覧の見える高さが低い（約280）ので、送る幅も小さく（1.1.0+25 で 450 → 200）
        sc.position.jumpTo((sc.position.pixels + 200).clamp(0, sc.position.maxScrollExtent).toDouble());
        await pump();
      }
      if (!_has(f)) return false;
    }
    // もう見えていて押せるなら、動かさない
    if (_has(f.hitTestable())) return true;
    await t.ensureVisible(f.first);
    await pump();
    if (!_has(f)) return false;
    if (_has(f.hitTestable()) || !_keptAway(f)) return true;
    // 入力中の欄は、画面の外へ送っても作られたまま残る（見つかるが、そこには無い）。上から送り直して探す
    final sc = _scroller();
    if (sc == null || sc.position.maxScrollExtent <= 0) return true;
    await _top(sc);
    for (var i = 0; _keptAway(f) && sc.position.pixels < sc.position.maxScrollExtent && i < 300; i++) {
      sc.position.jumpTo((sc.position.pixels + 300).clamp(0, sc.position.maxScrollExtent).toDouble());
      await pump();
    }
    if (_has(f) && !_has(f.hitTestable())) {
      await t.ensureVisible(f.first);
      await pump();
    }
    return _has(f);
  }

  /// [f] に当たる部品が今あるか（入れ子の探し方で、外側の部品が画面から消えているときも「無い」と答える）
  bool _has(Finder f) {
    try {
      return f.evaluate().isNotEmpty;
    } on StateError {
      return false;
    }
  }

  /// 一覧の外へ送られたのに、作られたまま残っている部品か（入力中の検索の欄など）
  bool _keptAway(Finder f) {
    if (!_has(f)) return false;
    RenderObject? r = f.evaluate().first.renderObject;
    while (r != null) {
      final pd = r.parentData;
      if (pd is SliverMultiBoxAdaptorParentData) return pd.keptAlive;
      r = r.parent;
    }
    return false;
  }

  /// 見える所まで動かして押す。見つからない・押せないときは [found] に書いて false
  Future<bool> press(Finder f, [String? what]) async {
    final name = what ?? f.describeMatch(Plurality.one);
    if (!await reveal(f)) {
      note('見つからない: $name（タブ ${ctl.tab}・小窓 ${ctl.sheet != null}）');
      return false;
    }
    final hit = f.hitTestable();
    if (!_has(hit)) {
      final r = t.getRect(f.first);
      final res = t.hitTestOnBinding(r.center);
      final top = res.path.map((e) => e.target).whereType<RenderObject>().take(verbose ? 40 : 3).map((o) => (o.debugCreator as DebugCreator?)?.element.widget.runtimeType).join(' < ');
      note('押せない（ほかの物の下・画面の外）: $name（場所 ${r.left.round()},${r.top.round()} ${r.width.round()}×${r.height.round()}・画面 ${t.view.physicalSize}・そこにある物 $top）');
      return false;
    }
    await t.tap(hit.first, warnIfMissed: false);
    taps++;
    await pump();
    return true;
  }

  /// 押した回数（[press] で押せた数。押す回数を比べる点検で使う）
  int taps = 0;

  Future<bool> pressText(String label) => press(find.text(label), '「$label」');
  Future<bool> pressKey(String key) => press(find.byKey(ValueKey(key)), key);

  /// 今の欄を上から下まで送って、全部を一度描く（見える分しか作られない一覧のはみ出しを拾う）
  Future<void> sweep() async {
    final sc = _scroller();
    if (sc == null) return;
    await _top(sc);
    for (var i = 0; sc.position.pixels < sc.position.maxScrollExtent; i++) {
      if (i > 300) {
        note('一覧の終わりまで送れない（${sc.position.pixels} / ${sc.position.maxScrollExtent}）');
        break;
      }
      sc.position.jumpTo((sc.position.pixels + 600).clamp(0, sc.position.maxScrollExtent).toDouble());
      await pump();
    }
    await _top(sc);
  }

  /// 欄をいちばん上に戻す。見える分しか作らない一覧は、遠くから一気に戻ると、作り直した行の高さのぶん位置がずれるので、
  /// 0 に落ち着くまで繰り返す
  Future<void> _top(ScrollableState sc) async {
    if (sc.position.pixels == 0) return;
    for (var i = 0; i < 6; i++) {
      sc.position.jumpTo(0);
      await pump();
      if (sc.position.pixels == 0) return;
    }
    note('いちばん上に戻れない: ${sc.position.pixels}');
  }

  Finder get _sheet => find.byKey(const ValueKey('sheet-card'));
  Finder inSheet(Finder f) => find.descendant(of: _sheet, matching: f);

  /// 小窓の中の、押せる選択肢（薄くなっていないもの）
  List<ChoiceBtn> _choices() => [
        for (final e in inSheet(find.byType(ChoiceBtn)).evaluate())
          if (e.widget case final ChoiceBtn c when c.enabled && c.onTap != null && !c.dim) c,
      ];

  int _pick = 0;

  /// 開いている小窓を、人が押す道筋で全部片付ける（続ける・OK・閉じる・やめる。選ぶ出来事は選択肢を順ぐりに選ぶ）。
  /// 片付かなければ「閉じられない小窓」として書く
  Future<void> drain() async {
    for (var i = 0; ctl.sheet != null; i++) {
      if (i > 60) {
        note('閉じられない小窓: ${inSheet(find.byType(RichText)).evaluate().take(1).map((e) => (e.widget as RichText).text.toPlainText()).join()}');
        ctl.closeSheet();
        await pump();
        return;
      }
      var done = false;
      for (final l in [tr('続ける'), 'OK', tr('閉じる'), tr('やめる')]) {
        if (inSheet(find.text(l)).evaluate().isNotEmpty) {
          done = await press(inSheet(find.text(l)), '小窓の「$l」');
          break;
        }
      }
      if (done) continue;
      final cs = _choices();
      if (cs.isEmpty) {
        note('閉じるボタンの無い小窓');
        ctl.closeSheet();
        await pump();
        return;
      }
      mark('出来事の選択');
      await press(inSheet(find.byWidget(cs[_pick++ % cs.length])), '出来事の選択肢');
    }
  }

  /// 押して、現金が [delta]（増えるならプラス）だけ動いたかを確かめる。[shown] は画面に出ているはずの額の字
  Future<void> money(String what, double delta, Future<void> Function() go) async {
    final shown = yen(delta.abs());
    final c0 = s.cash;
    await go();
    final d = s.cash - c0;
    if (yen(d.abs()) != shown || (d != 0 && d.sign != delta.sign)) note('値段の食い違い $what: 画面 ${delta < 0 ? '-' : '+'}$shown / 実際 ${yen(d)}');
  }

  // ===== はじめの画面 =====
  Future<void> start({required int year, List<String> traits = const ['charm', 'careful'], String mode = 'world', String home = 'jp'}) async {
    where = 'はじめの画面';
    await sweep();
    const modes = {'world': '世界一位', 'quad': '1000兆円', 'endless': '終わりなし'};
    await pressText(tr(modes[mode]!));
    await pressText(tr('$year年'));
    await pressText(cm[home]!.n);
    for (final id in traits) {
      await pressText(TRAITS.firstWhere((x) => x.id == id).n);
    }
    // 3つ目は選べない（2つまで）
    final third = TRAITS.firstWhere((x) => !traits.contains(x.id));
    await pressText(third.n);
    if (ctl.setup.traits.length != 2) note('特性が2つを超えて選べた');
    await pressText(DIFFS.firstWhere((d) => d.id == 'normal').n);
    await pressText(tr('枠{0}', [2]));
    await pressText(tr('会社を立ち上げる'));
    if (ctl.game == null) {
      note('会社を立ち上げられない');
      return;
    }
    if (s.year != year || s.mode != mode || s.home != home || ctl.slot != 2) note('選んだとおりに始まっていない: ${s.year} ${s.mode} ${s.home} 枠${ctl.slot}');
    // はじめの小窓 → 相棒を探す → 出会う → 株を渡して誘う
    where = '創業';
    await pressText(tr('相棒を探しに行く'));
    final h0 = s.hUsed;
    await press(inSheet(find.byType(ChoiceBtn)).first, '相棒を探す行き先');
    if (s.hUsed - h0 != s.hrs('seek')) note('相棒探しの時間: 札は${s.hrs('seek')}時間、実際は${s.hUsed - h0}');
    if (s.meet != null) {
      await pressText(tr('株を{0}%渡して誘う', [10]));
      mark('相棒を誘う');
    }
    await drain();
    // 最初の事業（社長の時間を使う。1.1.0+25 から、社長の行動は右の帯の「社長の行動」の小窓）
    final h1 = s.hUsed;
    await pressKey('pres-open');
    await pressText(tr('最初の事業を決める'));
    final first = s.liveInds().where((i) => s.capexOf(i) <= s.cash && s.licMissing(i.id) == null).toList()..ssort((a, b) => s.capexOf(a).compareTo(s.capexOf(b)));
    final ind = first.first;
    await money('最初の事業', -s.capexOf(ind), () async {
      await press(inSheet(find.text(tr('{0}（元手 {1}）', [ind.name, yen(s.capexOf(ind))]))), '最初の事業');
      if (s.biz.isEmpty) await press(inSheet(find.byType(ChoiceBtn)).first, '稼ぎ方');
      await drain();
    });
    if (s.biz.length != 1) note('最初の事業が始まらない');
    if (s.hUsed - h1 != s.hrs('start')) note('最初の事業の時間: 札は${s.hrs('start')}時間、実際は${s.hUsed - h1}');
    mark('最初の事業');
  }

  // ===== 画面の行き来 =====
  Future<void> tab(String id) async {
    // 「数字」のタブは 1.1.0+25 から「お金」の「決算と記録」
    if (id == 'num') {
      await tab('money');
      if (ctl.moneyView != 'book') await pressKey('money-book');
      return;
    }
    if (ctl.tab == id) return;
    await pressKey('tab-$id');
    if (ctl.tab != id) note('タブ $id に替わらない');
  }

  /// 事業の画面が2列（左に一覧・右に中身。1.1.0+26）か
  // （1.1.0+27：事業が多いと左の一覧が長く、「新しい事業」のボタンが画面の下に隠れることがある。木にあるかで見る）
  bool get _split => find.byKey(const ValueKey('biz-new')).evaluate().isNotEmpty;

  /// 2列の画面で、右に「新しい事業」の一覧を出す（1つの列の画面では何もしない）
  Future<void> _newList() async {
    if (_split && !ctl.bizNew && s.biz.isNotEmpty) await pressKey('biz-new');
  }

  /// その事業のカードが見えるようにする（2列なら左の一覧で選ぶ。1つの列で3つ以上なら行を開く）
  Future<void> _select(Biz b) async {
    if (_split) {
      if (ctl.openBiz != b.id || ctl.bizNew) await pressKey('biz-row-${b.id}');
    } else if (s.biz.length >= 3 && ctl.openBiz != b.id) {
      await pressKey('biz-row-${b.id}');
    }
  }

  /// 事業のカードを開いて、その中のボタンの組を返す
  Future<Finder> _card(Biz b, String grp) async {
    await tab('biz');
    await _select(b);
    // ボタンの3つの組は「ほかの手」の中（1.0.0+20）。たたまれていれば開く
    if (ctl.moreBiz != b.id) await pressKey('biz-more-${b.id}');
    final g = find.byKey(ValueKey('grp-$grp-${b.id}'));
    await reveal(g);
    return g;
  }

  /// [f] を一覧のいちばん上に寄せる（目で見る確認の書き出し用）
  Future<void> alignTop(Finder f) async {
    if (!await reveal(f)) return;
    await Scrollable.ensureVisible(t.element(f.first));
    await pump();
  }

  /// 事業のカードを開いて（「ほかの手」はたたんだまま）、カードを返す
  Future<Finder> card(Biz b) async {
    await tab('biz');
    await _select(b);
    if (ctl.moreBiz == b.id) await pressKey('biz-more-${b.id}');
    final c = find.byKey(ValueKey('biz-card-${b.id}'));
    await reveal(c);
    return c;
  }

  Future<bool> _bizBtn(Biz b, String grp, String label) async {
    final g = await _card(b, grp);
    return press(find.descendant(of: g, matching: find.textContaining(label)), '事業の「$label」');
  }

  // ===== 手 =====
  Future<void> build(Biz b) async {
    if (s.ap < 1) return;
    // 1.1.0+26 から、増やす小窓は「開く・責任者を育てる・本部・物流の拠点・改装」。今いちばん要る手を、小窓の選び肢から打つ
    final go = s.unitsOn ? s.growOpt(b, s.cash * .4, want: 1, time: true) : null;
    if (go == null) return;
    final k = s.kindB(b);
    String label;
    double cost;
    String hk;
    switch (go.k) {
      case 'build':
        final site = s.openSites(b, 3).first;
        // 他社と取り合う物件は、取られるとお金が動かず確かめにくいので、取り合いの無い物件のときだけ打つ
        if (k == 'shop' && s.bestOffers(b, site).first.riv > 0) return;
        label = tr('{0}に1つ開く', [s.siteName(site)]);
        cost = s.unitCapexAt(b, site);
        hk = 'build';
      case 'train':
        label = tr('{0}を育てる（1人）', [tr(KIND_LEAD_JA[k]!)]);
        cost = s.leadCost(b);
        hk = 'crew';
      // 1.1.0+27 から、辞めて空いた店に中途で店長を雇う
      case 'leads':
        label = tr('{0}を中途で雇う（1人）', [tr(KIND_LEAD_JA[k]!)]);
        cost = s.midLeadCost(b);
        hk = 'crew';
      case 'hub':
        final a = s.hubWanted(b).first;
        label = tr('{0}に配送の拠点を作る', [s.areaName(a)]);
        cost = s.hubCost(b);
        hk = 'build';
      default:
        final n = s.svNeed(b) - b.sv;
        label = tr('{0}を{1}人置く', [tr(KIND_SV_JA[k]!), n]);
        cost = k == 'shop' ? 0 : s.svHireCost(b) * n;
        hk = 'hire';
    }
    where = '店・工場を増やす';
    // 開いたカードに出ていれば、そこから（1.0.0+20）。出ていなければ「ほかの手」の中から
    await card(b);
    final quick = find.descendant(of: find.byKey(ValueKey('biz-top-${b.id}')), matching: find.textContaining(tr('{0}を増やす', [s.uw(b)])));
    if (_has(quick)) {
      if (!await press(quick, '事業の「増やす」（上の手）')) return;
      mark('上の手から');
    } else if (!await _bizBtn(b, 'grow', tr('{0}を増やす', [s.uw(b)]))) {
      return;
    }
    final h0 = s.hUsed;
    await money('増やす', -cost, () async {
      await pressText(label);
      await drain();
    });
    if (s.hUsed - h0 != s.hrs(hk)) note('増やすの時間: 札は${s.hrs(hk)}時間、実際は${s.hUsed - h0}');
    mark('店・工場を増やす');
  }

  Future<void> develop(Biz b) async {
    final sz = [2, 1, 0].where((i) => s.devCost(b, i) <= s.cash * .2).firstOrNull;
    if (sz == null || s.ap < 1) return;
    where = '商品を作る';
    if (!await _bizBtn(b, 'grow', tr('商品を作る'))) return;
    await money('商品', -s.devCost(b, sz), () async {
      await pressText(tr('{0}（元手の{1}倍）', [s.devName(sz), devMults[sz]]));
      await drain();
    });
    mark('商品を作る');
  }

  Future<void> crew(Biz b) async {
    final need = s.crewNeedPeople(b);
    if (need <= 0 || s.ap < 1 || s.hireCost(b, need) > s.cash * .6) return;
    where = '現場の人を増やす';
    // 1つおきに、開いたカードの「足りない人を雇う」（小窓を開かずに雇う。1.0.0+20）と、「ほかの手」の中の小窓から
    if (_pick++ % 2 == 0) {
      await card(b);
      await money('現場の人（上の手）', -s.hireCost(b, need), () async {
        await pressKey('top-hire-${b.id}');
        await drain();
      });
      mark('足りない人を雇う（上の手）');
    } else {
      if (!await _bizBtn(b, 'grow', tr('現場の人を増やす（{0}人足りない）', [need]))) return;
      await money('現場の人', -s.hireCost(b, need), () async {
        await pressText(tr('足りない分（{0}人）を雇う', [need]));
        await drain();
      });
    }
    if (s.crewNeedPeople(b) > 0) note('足りない分を雇ったのに、まだ${s.crewNeedPeople(b)}人足りない');
    mark('現場の人');
  }

  Future<void> ad(Biz b) async {
    final cost = s.invBase(b) * .25;
    if (s.ap < 1 || cost > s.cash * .2 || b.ad > 0) return;
    where = '広告';
    await money('広告', -cost, () async {
      await _bizBtn(b, 'grow', tr('広告 {0}', [yen(cost)]));
      await drain();
    });
    mark('広告');
  }

  Future<void> enter(Biz b) async {
    if (s.ap < 1) return;
    final y = s.yr();
    // 現地法人が出ている国は選ばない（押すと「その国には現地法人が出ています」と断られ、お金は動かない）
    final cs = CTRY.where((x) => !s.ctryOf(b).contains(x.c) && !b.pipe.any((p) => p.k == 'enter' && p.c == x.c) && !s.hasLocal(x.c, b.ind)).toList()
      ..ssort((p, q) => cw(q.c, y).compareTo(cw(p.c, y)));
    for (final x in cs.take(4)) {
      final ms = s.entryModes(b, x.c);
      final m = ms.where((m) => s.entryCost(b, x.c, m) * 2.5 < s.cash).firstOrNull;
      if (m == null) continue;
      where = '海外に出る';
      if (!await _bizBtn(b, 'grow', tr('海外に出る'))) return;
      await sweep();
      final cost = s.entryCost(b, x.c, m);
      final panel = find.ancestor(of: inSheet(find.text(x.n)), matching: find.byType(Panel));
      await money('海外', -cost, () async {
        await press(find.descendant(of: panel, matching: find.text('${ENTRYN[m]} ${yen(cost)}')), '海外の「${ENTRYN[m]}」');
        await drain();
      });
      mark('海外に出る');
      return;
    }
  }

  /// 新しい事業を始める（一覧の「始める」から）
  Future<void> newBiz() async {
    if (s.ap < 1 || s.biz.length >= 7 || s.pre <= 0) return;
    final list = newBizList(s, filter: 'can', sort: 'cost').where((i) => s.capexOf(i) * 3 < s.cash).toList();
    if (list.isEmpty) return;
    final i = list.last;
    where = '新しい事業';
    await tab('biz');
    await _newList();
    await pressKey('sort-cost');
    await pressKey('filter-can');
    final row = find.ancestor(of: find.byKey(ValueKey('newbiz-${i.id}')), matching: find.byType(Row));
    if (!await reveal(find.byKey(ValueKey('newbiz-${i.id}')))) {
      final sc = _scroller();
      note('一覧に${i.ja}が無い（検索「${ctl.bizSearch.text}」・絞り込み ${ctl.bizFilter}・並び ${ctl.bizSort}・位置 ${sc?.position.pixels}/${sc?.position.maxScrollExtent}・'
          '一覧の件数 ${newBizList(s, filter: ctl.bizFilter, sort: ctl.bizSort, query: ctl.bizSearch.text).length}・出ている行 ${find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('newbiz-')).evaluate().length}）');
      return;
    }
    final n = s.biz.length;
    await money('新しい事業', -s.capexOf(i), () async {
      await press(find.descendant(of: row.first, matching: find.text(tr('始める'))), '始める');
      if (ctl.sheet != null && s.biz.length == n) await press(inSheet(find.byType(ChoiceBtn)).first, '稼ぎ方');
      await drain();
    });
    if (s.biz.length != n + 1) note('事業が増えない');
    mark('新しい事業');
  }

  /// 採用の候補を雇う
  Future<void> hire() async {
    if (s.ap < 1 || s.cands.isEmpty) return;
    // 月の利益で給料を払え、雇う費用（1.1.0+27 から採用の道で違う）が手元の半分までの候補だけ
    final p = s.cands.where((x) => s.hireFeeOf(x) <= s.cash * .5 && s.pre >= x.salary * 3 && x.salary * 6 <= s.cash).firstOrNull;
    if (p == null) return;
    where = '雇う';
    await tab('people');
    final n = s.staff.length;
    // 1.1.0+27 から人の画面は2列。左の区分で「採用の候補」を選び、候補の行を押して、右の「雇う」を押す
    if (find.byKey(const ValueKey('pseg-cand')).evaluate().isNotEmpty) {
      await press(find.byKey(const ValueKey('pseg-cand')), '採用の候補');
      await press(find.byKey(ValueKey('person-row-${p.id}')), '候補の行');
    } else {
      await reveal(find.text(tr('採用の候補')));
    }
    final c0 = s.cash;
    final fee = s.hireFeeOf(p);
    if (find.byKey(ValueKey('p-hire-${p.id}')).evaluate().isNotEmpty) {
      await press(find.byKey(ValueKey('p-hire-${p.id}')), '雇う');
    } else {
      await pressText(tr('雇う'));
    }
    await drain();
    if (s.staff.length != n + 1) {
      note('雇えない');
    } else {
      // 雇ったのは押した行の人。その人の雇う費用だけ減る
      final got = s.staff.last;
      if (got == p && (c0 - s.cash - fee).abs() > 1) note('値段の食い違い 雇う費用: ${yen(fee)} / 実際 ${yen(c0 - s.cash)}');
    }
    mark('雇う');
  }

  /// 責任者を選ぶ欄で、空いている部下を置く
  Future<void> manager(Biz b) async {
    final free = s.staff.where((x) => !s.biz.any((y) => y.mgr == x.id)).firstOrNull;
    if (free == null || b.mgr != null) return;
    where = '責任者を置く';
    final g = await _card(b, 'grow');
    final card = find.ancestor(of: g, matching: find.byType(Panel));
    final ind = indm[b.ind]!;
    if (!await press(find.descendant(of: card.first, matching: find.byType(DropdownButton<int>)), '責任者の欄')) return;
    await t.pump(const Duration(milliseconds: 400));
    check();
    final item = find.text(tr('{0}（{1} {2}）', [nmL(free.name), ABN[ind.key], s.showAb(free, ind.key)]));
    if (item.evaluate().isEmpty) {
      note('責任者の候補が出ない');
    } else {
      await t.tap(item.last, warnIfMissed: false);
    }
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    check();
    if (b.mgr != free.id) note('責任者が置けない');
    mark('責任者を置く');
  }

  /// 値付けの欄を替えて戻す
  Future<void> price(Biz b) async {
    where = '値付け';
    final g = await _card(b, 'fight');
    if (!await press(find.descendant(of: g, matching: find.byType(DropdownButton<String>)), '値付けの欄')) return;
    await t.pump(const Duration(milliseconds: 400));
    check();
    await t.tap(find.text(tr('高く（利益は厚いが客が減る）')).last, warnIfMissed: false);
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    check();
    if (b.price != 'premium') note('値付けが替わらない');
    await press(find.descendant(of: g, matching: find.byType(DropdownButton<String>)), '値付けの欄');
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text(tr('ふつう')).last, warnIfMissed: false);
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    check();
    mark('値付け');
  }

  /// 分社する
  Future<void> spin(Biz b) async {
    if (s.ap < 1 || b.mgr == null) return;
    where = '分社';
    if (!await _bizBtn(b, 'shape', tr('分社・独立'))) return;
    final n = s.subs().length;
    await pressText(tr('分社する'));
    await drain();
    if (s.subs().length != n + 1) note('分社で子会社が増えない');
    mark('分社');
  }

  /// 社長の行動（街）
  Future<void> pres(String kind) async {
    if (s.ap < 1) return;
    where = '社長の行動 $kind';
    await tab('town');
    final h0 = s.hUsed;
    // 社長の行動は右の帯の「社長の行動」の小窓から（1.1.0+25）
    await pressKey('pres-open');
    switch (kind) {
      case 'work':
        await money('日銭', s.workIncome(), () async {
          await pressText(tr('日銭を稼ぐ'));
          await drain();
        });
      case 'train':
        await pressText(tr('腕を磨く'));
        await press(inSheet(find.byType(ChoiceBtn)).at(_pick++ % 4), '磨く能力');
        await drain();
      case 'net':
        if (s.net >= 5) {
          await drain();
          return;
        }
        await pressText(tr('人脈を作る'));
        await drain();
      case 'scout':
        await pressText(tr('事業の種を探す'));
        await drain();
    }
    if (s.hUsed - h0 != s.hrs(kind)) note('社長の行動 $kind の時間: 札は${s.hrs(kind)}時間、実際は${s.hUsed - h0}');
    mark('社長の行動');
  }

  /// 「株」のタブで、その会社のカードを見える所まで出す（無ければ null）
  Future<Finder?> _stockCard(Company c) async {
    await tab('stock');
    final name = find.text(nmL(c.name));
    if (!await reveal(name)) return null;
    final cards = find.ancestor(of: name, matching: find.byType(Panel));
    return _has(cards) ? cards.first : null;
  }

  /// 株の手（上場・投資家・増資・他社の株・組む・TOB・合併）
  Future<void> stock() async {
    if (s.ap < 1) return;
    where = '株';
    if (s.canIPO()) {
      await tab('stock');
      await pressText(tr('上場する'));
      await drain();
      if (!s.listed) note('上場できない');
      mark('上場');
      return;
    }
    if (!s.listed && s.sh.own > 60 && s.turn > 14 && s.turn - (s.lastOffer ?? -99) >= 12 && s.cash < s.cap * .05) {
      await tab('stock');
      final v = s.cap * .1;
      await money('投資家から集める', v, () async {
        await pressText(tr('投資家から集める（{0}・持ち株−10%）', [yen(v)]));
        await drain();
      });
      mark('投資家から集める');
      return;
    }
    // 上場後の増資（集まる額がボタンの額と同じか）
    if (s.listed && s.sh.own > 55 && s.turn % 12 == 5 && s.turn - (s.lastOffer ?? -99) >= 12) {
      await tab('stock');
      final v = s.cap * .095;
      await money('増資', v, () async {
        await pressText(tr('増資で集める（{0}・全員の割合−9%）', [yen(v)]));
        await drain();
      });
      mark('増資');
      return;
    }
    // 持株会社にする
    if (!s.holding && s.biz.length + s.subs().length >= 5 && s.turn % 12 == 2) {
      await tab('stock');
      await pressText(tr('持株会社にする'));
      await drain();
      if (!s.holding) note('持株会社にならない');
      mark('持株会社');
      return;
    }
    // 持っている他社の株を全部売る（入る額がボタンの額と同じか）
    final held = s.cos.where((c) => c.alive && c.parent != 'player' && s.pctOf(c) > 0).firstOrNull;
    if (held != null && s.turn % 9 == 4) {
      final hc = await _stockCard(held);
      if (hc != null) {
        final v = held.cap * s.pctOf(held) / 100 * .95;
        await money('他社の株を全部売る', v, () async {
          await press(find.descendant(of: hc, matching: find.text(tr('全部売る（{0}）', [yen(v)]))), '全部売る');
          await drain();
        });
        if (s.pctOf(held) != 0) note('全部売ったのに株が残っている');
        mark('他社の株を売る');
        return;
      }
    }
    // 合併できる子会社
    final mg = s.subs().where((c) => s.canMerge(c)).firstOrNull;
    if (mg != null && s.turn % 5 == 0) {
      await tab('stock');
      final card = find.ancestor(of: find.text(nmL(mg.name)), matching: find.byType(Panel));
      if (await reveal(find.text(nmL(mg.name))) && card.evaluate().isNotEmpty) {
        await press(find.descendant(of: card.first, matching: find.textContaining(tr('合併する（株を渡して払う）'))), '合併する');
        await drain();
        mark('合併');
      }
      return;
    }
    // 小さな会社の株を市場で買う・組む・TOB
    final cands = s.cos.where((c) => c.alive && c.parent != 'player' && s.floatOf(c) > 5).toList()..ssort((a, b) => a.cap.compareTo(b.cap));
    final myInd = <String>{for (final b in s.biz) b.ind};
    final shown = (cands.where((c) => s.pctOf(c) > 0).toList() + (cands.where((c) => s.pctOf(c) == 0).toList()..ssort((a, b) => (b.biz.any((x) => myInd.contains(x.ind)) ? 1 : 0) - (a.biz.any((x) => myInd.contains(x.ind)) ? 1 : 0))).take(14).toList());
    final c = shown.where((c) => c.cap * .0525 * 4 < s.cash).firstOrNull;
    if (c == null) return;
    await tab('stock');
    // カードは会社の番号で探す（同じ名前の会社が世界に何社もいることがあり、名前で探すと、同じ名前の自分の現地法人のカードを押そうとしていた。1.0.0+19）
    final card = find.byKey(ValueKey('co-${c.id}'));
    if (!await reveal(card)) return;
    Finder inCard(Finder f) => find.descendant(of: card, matching: f);
    if (s.turn % 3 == 0 && s.pctOf(c) < 50.1 && s.tobCost(c, 50.1) * 2 < s.cash) {
      await press(inCard(find.textContaining(tr('TOBで{0}%（{1}・成功率{2}）', ['50.1', yen(s.tobCost(c, 50.1)), '${jsNum(jsRound(s.tobChance(c, 50.1) * 100))}%']))), 'TOB');
      await drain();
      mark('TOB');
    } else if (s.turn % 3 == 1 && !s.deals.any((d) => d.co == c.id)) {
      await press(inCard(find.text(tr('組む'))), '組む');
      final cs = _choices();
      if (cs.isNotEmpty) {
        await press(inSheet(find.byWidget(cs.first)), '組み方');
        mark('組む');
      }
      await drain();
    } else {
      final cost = c.cap * .0525;
      await money('市場で5%買う', -cost, () async {
        await press(inCard(find.text(tr('市場で5%買う（{0}）', [yen(cost)]))), '市場で5%買う');
        await drain();
      });
      mark('他社の株を買う');
    }
  }

  // ===== ひと回り見る（タブ・小窓・図鑑・用語） =====
  Future<void> _peek(Finder f, String what) async {
    if (!await reveal(f)) return;
    await press(f, what);
    if (ctl.sheet == null) {
      note('小窓が開かない: $what');
      return;
    }
    await sweep();
    await drain();
    mark('小窓 $what');
  }

  /// 設定で言語を替えて、ひと通り見て、すぐ戻す（替えたあとの画面に、前の言語の字が残らないか）
  Future<void> flipLang() async {
    where = '言語の切り替え';
    final back = L.lang;
    final other = back == 'ja' ? 'en' : 'ja';
    String name(String l) => l == 'en' ? 'English' : '日本語';
    await pressKey('settings');
    await press(inSheet(find.text(name(other))), name(other));
    if (L.lang != other) note('言語が替わらない');
    await sweep();
    await drain();
    for (final id in const ['biz', 'people', 'town']) {
      await tab(id);
    }
    await pressKey('settings');
    await press(inSheet(find.text(name(back))), name(back));
    await drain();
    if (L.lang != back) note('言語が戻らない');
    if (ctl.prefs?.getString(GameController.langKey) != back) note('選んだ言語が残っていない');
    mark('言語の切り替え');
  }

  /// 後継ぎの欄で候補を選び、「まだ決めていない」に戻す
  Future<void> successor() async {
    if (s.staff.isEmpty) return;
    where = '後継ぎ';
    await tab('people');
    final pick = find.byType(DropdownButton<int>);
    if (!await press(pick, '後継ぎの欄')) return;
    await t.pump(const Duration(milliseconds: 400));
    check();
    final p = s.staff.first;
    final item = find.text(tr('{0}（{1}{2}歳）', [nmL(p.name), p.kid ? tr('子ども・') : '', p.age]));
    if (!_has(item)) {
      note('後継ぎの候補が出ない');
      return;
    }
    await t.tap(item.last, warnIfMissed: false);
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    check();
    if (s.succ != p.id) note('後継ぎが選べない');
    await press(pick, '後継ぎの欄');
    await t.pump(const Duration(milliseconds: 400));
    // 横向きの低い画面では、選ぶ欄の一覧が流れていて「まだ決めていない」が上に隠れていることがある。見える所まで送る
    final none = find.text(tr('まだ決めていない')).last;
    if (!_has(none.hitTestable())) {
      try {
        await t.dragUntilVisible(none, find.byType(Scrollable).last, const Offset(0, 120), maxIteration: 20);
        await t.pump();
      } catch (_) {}
    }
    await t.tap(find.text(tr('まだ決めていない')).last, warnIfMissed: false);
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    check();
    if (s.succ != null) note('後継ぎを外せない');
    mark('後継ぎ');
  }

  Future<void> tour() async {
    where = 'ひと回り（街）';
    await tab('town');
    await sweep();
    await _peek(find.text(tr('？')), '遊び方');
    await _peek(find.byKey(const ValueKey('settings')), '設定');
    await flipLang();
    // 設定の「はじめから」は確認が出て、やめられる
    where = 'ひと回り（街）';
    await pressKey('settings');
    await press(inSheet(find.text(tr('はじめから'))), '設定の「はじめから」');
    if (!_has(inSheet(find.text(tr('はじめからにする'))))) note('「はじめから」の確認が出ない');
    await drain();
    if (ctl.game == null) note('やめたのに、はじめの画面に戻った');
    await _peek(find.byKey(const ValueKey('todo-all')), '番頭のひとこと');
    // 「今月やること」の行のボタン（その場で打つ・該当の場所へ飛ぶ。1.0.0+20）
    for (var i = 0; i < todoMax; i++) {
      await tab('town');
      final sc = _scroller();
      if (sc != null) await _top(sc);
      final f = find.byKey(ValueKey('todo-act-$i'));
      if (!_has(f)) continue;
      await press(f, '今月やることのボタン');
      await drain();
      mark('今月やることのボタン');
    }
    await tab('town');
    await _peek(find.byKey(const ValueKey('info-ap')), '用語（手）');
    for (final k in ['fold-rivals', 'fold-news']) {
      if (await reveal(find.byKey(ValueKey(k)))) {
        await press(find.descendant(of: find.byKey(ValueKey(k)), matching: find.byType(InkWell)), k);
        await press(find.descendant(of: find.byKey(ValueKey(k)), matching: find.byType(InkWell)), k);
      }
    }
    final rv = s.cos.where((c) => c.rival != null && c.alive).firstOrNull;
    if (rv != null && s.ap > 0) {
      where = 'ひと回り（宿敵）';
      if (ctl.openRival != rv.id) await pressKey('rival-row-${rv.id}');
      if (rv.parent != 'player') await _peek(find.text(tr('裏の手')), '裏の手');
      await pressKey('rival-fold-${rv.id}');
    }
    where = 'ひと回り（事業）';
    await tab('biz');
    await sweep();
    // 責任者に任せる：まとめて任せる・まとめて戻す（1つも任せていなかったときだけ戻す。任せてあれば、任せたまま遊び続ける）
    if (s.biz.any(s.canDeleg) && await reveal(find.byKey(const ValueKey('deleg-bar')))) {
      final had = s.delegatedBiz().length;
      await _peek(find.byKey(const ValueKey('info-deleg')), '用語（任せる）');
      if (s.delegable().isNotEmpty) {
        await pressKey('deleg-all');
        await drain();
        if (s.delegable().isNotEmpty) note('まとめて任せたのに、任せていない事業が残った');
      }
      if (had == 0) {
        await reveal(find.byKey(const ValueKey('deleg-bar')));
        await pressKey('undeleg-all');
        await drain();
        if (s.biz.any((b) => b.deleg)) note('まとめて戻したのに、任せた事業が残った');
      }
      mark('まとめて任せる');
    }
    // 事業が多い会社：自社の事業の並べ替えと、見出しでたたむ・開く（1つの列の画面だけ。2列の画面は左に一覧がいつも出る）
    // （任せる帯の小窓などで別の画面に移っていることがあるので、事業の画面に戻してから見る。1.1.0+27）
    if (ctl.tab != 'biz') await tab('biz');
    if (s.biz.length >= bizManyMin && !_split) {
      for (final o in myBizSorts) {
        await pressKey('mysort-${o.$1}');
        if (ctl.myBizSort != o.$1) note('自社の事業の並びが${o.$1}に替わらない');
      }
      await pressKey('mysort-rev');
      final head = find.descendant(of: find.byKey(const ValueKey('fold-mybiz')), matching: find.byType(InkWell));
      await press(head, '自社の事業の見出し');
      if (_has(find.byKey(ValueKey('biz-row-${s.biz.first.id}')))) note('自社の事業がたためない');
      await press(head, '自社の事業の見出し');
      mark('事業の一覧をたたむ');
    }
    await _newList();
    for (final o in bizSorts) {
      await pressKey('sort-${o.$1}');
    }
    for (final o in bizFilters) {
      await pressKey('filter-${o.$1}');
      await sweep();
    }
    await pressKey('filter-cat');
    if (ctl.sheet != null) {
      await press(inSheet(find.byType(ChoiceBtn)).at(1), '分類');
      await sweep();
      await pressKey('filter-all');
    } else {
      note('分類の小窓が開かない');
    }
    // 検索して、消す
    if (await reveal(find.byKey(const ValueKey('biz-search')))) {
      final searchH = t.getSize(find.byKey(const ValueKey('biz-search'))).height;
      // 字を打つと、欄はカーソルが見える所まで一覧を少し動かす（0.1秒ほど。そのあいだ一覧は押せない）。動き終わるまで待つ
      Future<void> type(String text) async {
        await t.enterText(find.descendant(of: find.byKey(const ValueKey('biz-search')), matching: find.byType(EditableText)), text);
        await pump();
        await t.pump(const Duration(milliseconds: 200));
        await t.pump(const Duration(milliseconds: 200));
        check();
      }

      await type(L.en ? 'zzz' : 'んんん');
      await pressText(tr('条件を外して全部見る'));
      await reveal(find.byKey(const ValueKey('biz-search')));
      await type(L.en ? 'a' : 'ー');
      // 字を打っても、欄の高さは変わらない（消すボタンが出るときに一覧がずれない）
      final hBox = t.getSize(find.byKey(const ValueKey('biz-search'))).height;
      if ((hBox - searchH).abs() > .5 && searchH > 0) note('検索の欄の高さが、字を打つと変わる: $searchH → $hBox');
      await pressKey('search-clear');
      FocusManager.instance.primaryFocus?.unfocus();
      await pump();
    }
    if (s.biz.isNotEmpty) {
      final b = s.biz.first;
      final g = await _card(b, 'grow');
      final card = find.ancestor(of: g, matching: find.byType(Panel)).first;
      for (final e in find.descendant(of: card, matching: find.byType(Info)).evaluate().toList()) {
        final k = 'info-${(e.widget as Info).terms.join('-')}';
        await _peek(find.descendant(of: card, matching: find.byKey(ValueKey(k))), '用語 $k');
      }
      for (final l in [tr('{0}を増やす', [s.uw(b)]), tr('商品を作る'), tr('海外に出る'), tr('分社・独立')]) {
        if (s.ap < 1) break;
        final f = find.descendant(of: card, matching: find.textContaining(l));
        if (f.evaluate().isNotEmpty) await _peek(f, l);
      }
      if (s.ap > 0 && b.model != 'fc') await _peek(find.descendant(of: card, matching: find.textContaining(tr('現場の人を増やす'))), '現場の人を増やす');
      if (s.ap > 0) {
        for (final l in [tr('稼ぎ方を変える'), tr('業態を変える')]) {
          final f = find.descendant(of: card, matching: find.text(l));
          if (f.evaluate().isNotEmpty) await _peek(f, l);
        }
        // 売るは確認の小窓が出て、やめられる
        final n = s.biz.length;
        await _peek(find.descendant(of: find.byKey(ValueKey('biz-sell-${b.id}')), matching: find.textContaining(tr('売る（約{0}）', [yen(s.sellValue(b))]))), '売る');
        if (s.biz.length != n) note('売るをやめたのに事業が減った');
      }
      await price(b);
      for (final g in pipeGroups(b).where((g) => g.count > 1)) {
        await _peek(find.byKey(ValueKey('pipe-${b.id}-${g.k}')), '仕掛かりの一覧');
      }
    }
    // 銀行：借りて、返す
    where = 'ひと回り（銀行）';
    // 1.1.0+25 から「お金」の「借金と銀行」で、借りるには社長の時間（銀行に会う）がかかる
    final a = s.borrowRoom() * .25;
    if (a >= 1e5 && s.debt == 0 && s.canT('bank')) {
      await tab('money');
      await pressKey('money-bank');
      await money('借りる', a, () async {
        await pressKey('borrow-0.25');
        await drain();
      });
      await money('返す', -a, () async {
        await pressKey('repay-all');
        await drain();
      });
      mark('銀行');
    }
    where = 'ひと回り（人）';
    await tab('people');
    await sweep();
    // 1.1.0+27 から、横に広い人の画面は2列（左の一覧で人を押すと右に中身）。区分（幹部・責任者）を選んで押し、右の解雇を開いてやめる
    if (find.byKey(const ValueKey('pseg-exec')).evaluate().isNotEmpty) {
      for (final p in {if (s.staff.isNotEmpty) s.staff.first, if (s.staff.isNotEmpty) s.staff.last}) {
        await pressKey(s.biz.any((b) => b.mgr == p.id) ? 'pseg-mgr' : 'pseg-exec');
        await pressKey('person-row-${p.id}');
        if (p == s.staff.last) {
          final n = s.staff.length;
          final fire = find.byKey(ValueKey('p-fire-${p.id}'));
          if (await reveal(fire)) await _peek(fire.last, '解雇の確認');
          if (s.staff.length != n) note('解雇をやめたのに部下が減った');
        }
      }
      await pressKey('pseg-exec');
      await successor();
    } else {
      await _peopleNarrow();
    }
    await _afterPeople();
  }

  /// 狭い人の画面（縦に並べる）のひと回り
  Future<void> _peopleNarrow() async {
    if (s.staff.length >= staffFoldMin) {
      final p = s.staff.first;
      if (ctl.openStaff != p.id) await pressKey('staff-row-${p.id}');
      await pressKey('staff-fold-${p.id}');
    }
    if (s.staff.isNotEmpty) {
      final p = s.staff.last;
      if (s.staff.length >= staffFoldMin && ctl.openStaff != p.id) await pressKey('staff-row-${p.id}');
      final n = s.staff.length;
      final fire = find.text(tr(p.partner ? '相棒と別れる' : '解雇'));
      if (await reveal(fire)) await _peek(fire.last, '解雇の確認');
      if (s.staff.length != n) note('解雇をやめたのに部下が減った');
    }
    await successor();
  }

  /// 人のあとのひと回り（株から）
  Future<void> _afterPeople() async {
    where = 'ひと回り（株）';
    await tab('stock');
    await sweep();
    await _peek(find.byKey(const ValueKey('info-own-cap')), '用語（持ち株）');
    if (s.ap > 0 && s.biz.isNotEmpty && s.buyers().isNotEmpty) await _peek(find.text(tr('会社を丸ごと売る')), '会社を丸ごと売る');
    // 会社を2つに割る（小窓で分類を選ぶ。開いて、やめる）
    if (s.ap > 0 && s.listed && s.biz.length >= 2) {
      final n = s.biz.length;
      await _peek(find.text(tr('会社を2つに割る')), '会社を2つに割る');
      if (s.biz.length != n) note('割るのをやめたのに事業が減った');
    }
    // 子会社を手放すのは確認が出て、やめられる
    final sub = s.subs().where((c) => s.pctOf(c) > 0).firstOrNull;
    if (sub != null && await reveal(find.byKey(ValueKey('co-sell-${sub.id}')))) {
      await _peek(find.descendant(of: find.byKey(ValueKey('co-sell-${sub.id}')), matching: find.byType(Btn)), '子会社を全部売る');
      if (sub.parent != 'player') note('売るのをやめたのに子会社でなくなった');
    }
    where = 'ひと回り（数字）';
    await tab('num');
    await sweep();
    await _peek(find.byKey(const ValueKey('info-rank-cap')), '用語（順位）');
    where = 'ひと回り（図鑑）';
    await tab('zukan');
    for (final v in zukanViews) {
      await pressKey('zukan-${v.$1}');
      if (ctl.zukanView != v.$1) note('図鑑が${v.$1}に替わらない');
      await sweep();
    }
    await _peek(find.byKey(const ValueKey('info-synergy')), '用語（シナジー）');
    await tab('town');
    mark('ひと回り');
  }

  // ===== 月を進める =====
  /// 勝ち負けが決まったあとの画面を通る。続けられるなら true
  Future<bool> _ended() async {
    if (!s.ended) return true;
    where = '終わりの画面';
    await sweep();
    await pressText(tr('盤面を見る'));
    await sweep();
    await pressText(tr('まとめを見る'));
    mark(s.over != null ? '負けの画面' : '勝ちの画面');
    if (s.over == null) {
      await pressText(tr('このまま続ける'));
      return !s.ended;
    }
    return false;
  }

  /// 次の月へ（報告・出来事を片付ける）。続けられなくなったら false
  Future<bool> next() async {
    where = '次の月へ ${s.year}/${s.q}';
    final turn = s.turn;
    await press(find.textContaining(tr('次の月へ')), '次の月へ');
    await drain();
    if (s.turn != turn + 1 && !s.ended) note('月が進まない');
    mark('次の月へ');
    return _ended();
  }

  /// まとめて進める（until・3・12）
  Future<bool> advance(String key) async {
    where = 'まとめて進める $key ${s.year}/${s.q}';
    final turn = s.turn;
    await pressKey('advance-menu');
    await pressKey('adv-$key');
    await drain();
    if (s.turn == turn && !s.ended) note('まとめて進めても月が進まない');
    mark('まとめて進める $key');
    return _ended();
  }

  /// 1か月ぶんの手を、人が遊ぶ順に打つ
  Future<void> month() async {
    final m = s.turn;
    if (s.biz.isEmpty) {
      // 事業を全部失ったら、最初の事業を決め直す
      await tab('town');
      if (find.text(tr('最初の事業を決める')).evaluate().isNotEmpty || await reveal(find.text(tr('最初の事業を決める')))) {
        where = '事業の決め直し';
        await pressText(tr('最初の事業を決める'));
        if (inSheet(find.byType(ChoiceBtn)).evaluate().isNotEmpty) {
          await press(inSheet(find.byType(ChoiceBtn)).first, '事業');
          if (s.biz.isEmpty && ctl.sheet != null && _choices().isNotEmpty) await press(inSheet(find.byWidget(_choices().first)), '稼ぎ方');
        }
        await drain();
      }
      if (s.biz.isEmpty) {
        await pres('work');
        return;
      }
    }
    // はじめの1年は社長の行動も混ぜる
    if (m < 12) {
      await pres(const ['work', 'train', 'net', 'scout'][m % 4]);
    }
    // 赤字で手元が細ってきたら、打ち手を止めて日銭を稼ぐ（人が遊ぶときと同じ守り方）
    if (s.pre < 0 && s.cash < -s.pre * 8) {
      await pres('work');
      await pres('work');
      return;
    }
    for (final b in s.biz.toList()) {
      if (s.biz.contains(b)) await crew(b);
    }
    if (s.staff.length < s.biz.length + (m > 60 ? 1 : 0) && s.staff.length < 8) await hire();
    for (final b in s.biz.toList()) {
      if (b.mgr == null && s.biz.where((x) => x.mgr == null).length > (s.staff.isEmpty ? 99 : 1)) await manager(b);
    }
    await stock();
    // 年に1度、責任者のいる事業を1つ任せる（カードの「任せる」。手は使わない）
    if (m % 12 == 4) {
      final b = s.biz.where((b) => s.canDeleg(b) && !b.deleg).firstOrNull;
      if (b != null) {
        where = '任せる';
        final h0 = s.hUsed;
        await card(b);
        await pressKey('deleg-on-${b.id}');
        if (!s.delegated(b)) note('任せられない');
        // 任せるのに社長の時間は使わない（任せると会議の時間が減る。1.1.0+25）
        if (s.hUsed != h0) note('任せるのに時間を使った');
        mark('任せる');
      }
    }
    if (m % 6 == 3) await newBiz();
    double score(Biz y) => (y.profit / (y.rev + 1)) * (1 - y.share);
    final top = (s.biz.toList()..ssort((x, y) => score(y).compareTo(score(x)))).firstOrNull;
    if (top != null) {
      if (m % 4 == 2) await enter(top);
      if (m % 7 == 5) await ad(top);
      if (m % 2 == 0) {
        await build(top);
      } else {
        await develop(top);
      }
      if (s.biz.contains(top)) await build(top);
    }
    if (s.biz.length >= 4 && s.subs().isEmpty && m % 12 == 8) {
      final b = s.biz.where((b) => b.mgr != null).firstOrNull;
      if (b != null) await spin(b);
    }
  }

  /// はじめの画面から [years] 年ぶん遊ぶ
  Future<void> play({required int year, required int years, String mode = 'world', String home = 'jp', List<String> traits = const ['charm', 'careful']}) async {
    logTag = '$year ${L.lang}';
    await start(year: year, traits: traits, mode: mode, home: home);
    if (ctl.game == null) return;
    final end = s.turn + years * 12;
    final sw = Stopwatch()..start();
    Future<void> timedTour() async {
      final t0 = sw.elapsedMilliseconds;
      await tour();
      tourMs += sw.elapsedMilliseconds - t0;
    }

    await timedTour();
    while (s.turn < end) {
      final m = s.turn;
      if (verbose && m % 12 == 0) {
        say('通し ${L.lang} ${s.year}年:${sw.elapsed.inSeconds}秒・事業${s.biz.length}・部下${s.staff.length}・子会社${s.subs().length}・上場${s.listed}・現金${yenJa(s.cash)}・時価${yenJa(s.cap)}・見つけた${found.length}');
      }
      await month();
      // ひと回り見るのは、はじめ・半年後・そのあとは [tourEvery] か月ごと。年に1回ずつ、まとめて進める3つも使う
      if (m == 6 || (m > 6 && m % tourEvery == 30 % tourEvery)) await timedTour();
      final ok = m % 12 == 9 && m > 12
          ? await advance(const ['3', 'until', '12'][(m ~/ 12) % 3])
          : await next();
      if (!ok) break;
    }
    where = '終わり';
    await t.pump(const Duration(seconds: 1));
    check();
  }
}
