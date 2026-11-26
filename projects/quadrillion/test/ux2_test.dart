import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';
import 'package:quadrillion/ui/app.dart';
import 'package:quadrillion/ui/controller.dart';
import 'package:quadrillion/ui/sheets.dart';
import 'package:quadrillion/ui/tabs.dart';
import 'package:quadrillion/ui/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/bot.dart';

/// 1.0.0+11 の使いやすさ・見た目の直し：下のタブのアイコン・新しい事業の検索と並べ替えと絞り込み・小窓の出入り・カードの決まり・手の数
///
/// 画面の書き出し（目で見る用）は QUAD_SHOTS に書き出し先を渡したときだけ動く（画像はコミットしない）
final _out = Platform.environment['QUAD_SHOTS'];

final _cjk = RegExp('[　-ヿ㐀-鿿＀-￯]');

/// 本物のフォントで描く（字の幅と、アイコンの形を見るため）
Future<void> _loadFonts() async {
  final jp = FontLoader(fontFamily);
  for (final f in ['assets/fonts/NotoSansJP-Regular.ttf', 'assets/fonts/NotoSansJP-Bold.ttf']) {
    jp.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await jp.load();
  final root = Platform.environment['FLUTTER_ROOT'] ?? '';
  final icons = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())))).load();
  }
}

/// 途中のゲーム（事業がいくつかあり、現金もある）
Game _midGame() {
  final g = Game.newGame(SetupConfig(mode: 'world', year: 1990, traits: ['charm', 'gambler']), rng: ParkMiller(2024));
  for (var i = 0; i < 120; i++) {
    botMonth(g);
  }
  resolveEvents(g);
  g.calcAll();
  g.ap = 3;
  return g;
}

final _shotKey = GlobalKey();

Future<GameController> _pump(WidgetTester tester, Game? g, {double width = 390, double height = 844, String lang = 'ja'}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final ctl = GameController(prefs: prefs, newRandom: () => ParkMiller(77), lang: lang)..game = g;
  addTearDown(() => L.lang = 'ja');
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(RepaintBoundary(key: _shotKey, child: QuadrillionApp(controller: ctl)));
  await tester.pump();
  return ctl;
}

Future<void> _shot(WidgetTester tester, String name) async {
  if (_out == null) return;
  final ro = tester.renderObject<RenderRepaintBoundary>(find.byKey(_shotKey));
  await tester.runAsync(() async {
    final im = await ro.toImage(pixelRatio: 2);
    final bd = await im.toByteData(format: ui.ImageByteFormat.png);
    File('$_out/$name.png').writeAsBytesSync(bd!.buffer.asUint8List());
  });
}

/// 画面に描かれている文をすべて集める
List<String> _texts() => [
      for (final e in find.byWidgetPredicate((w) => w is RichText).evaluate()) (e.widget as RichText).text.toPlainText(),
      for (final e in find.byWidgetPredicate((w) => w is EditableText).evaluate()) (e.widget as EditableText).controller.text,
    ];

void _noJapanese(String where) {
  final j = _texts().where((t) => _cjk.hasMatch(t)).toList();
  expect(j, isEmpty, reason: '$where に日本語が残っている: ${j.take(12).join(' / ')}');
}

/// 「新しい事業」の一覧の行（「始める」のボタン）の数
int _rows() => find.byWidgetPredicate((w) => w is Btn && (w.label == tr('始める'))).evaluate().length;

/// タブの中身の縦の一覧（横に流れる分類の札の列ではなく）
Finder _mainList() => find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;

/// 「新しい事業」の上の部品まで送る
Future<void> _toNewBiz(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.byKey(const ValueKey('biz-search')), 300, scrollable: _mainList());
  await tester.pump();
}

void main() {
  setUpAll(_loadFonts);

  group('下のタブのアイコン', () {
    for (final lang in ['ja', 'en']) {
      testWidgets('6つのタブに字とアイコンがあり、選んだタブは塗りのアイコンと金の字（$lang）', (tester) async {
        final ctl = await _pump(tester, _midGame(), lang: lang);
        const want = {
          'town': Icons.location_city,
          'biz': Icons.work,
          'people': Icons.people,
          'stock': Icons.pie_chart,
          'num': Icons.bar_chart,
          'zukan': Icons.menu_book,
        };
        for (final t in MainScreen.tabs) {
          await tester.tap(find.byKey(ValueKey('tab-${t.$1}')));
          await tester.pump();
          expect(ctl.tab, t.$1);
          for (final u in MainScreen.tabs) {
            final tab = find.byKey(ValueKey('tab-${u.$1}'));
            final item = tester.widget<TabItem>(find.descendant(of: tab, matching: find.byType(TabItem)));
            expect(item.on, u.$1 == t.$1);
            expect(item.icon.$2, want[u.$1], reason: u.$1);
            final icon = tester.widget<Icon>(find.descendant(of: tab, matching: find.byType(Icon)));
            expect(icon.icon, u.$1 == t.$1 ? want[u.$1] : MainScreen.tabIcons[u.$1]!.$1);
            final label = tester.widget<Text>(find.descendant(of: tab, matching: find.text(tr(u.$2))));
            expect(label.style!.color, u.$1 == t.$1 ? Pal.goldtx : Pal.mute);
            // 押せる範囲は 44pt 以上のまま
            final r = tester.getRect(tab);
            expect(r.height, greaterThanOrEqualTo(minTap), reason: u.$1);
            expect(r.width, greaterThanOrEqualTo(minTap), reason: u.$1);
          }
          // 字は 1行で、アイコンの下にある
          final tab = find.byKey(ValueKey('tab-${t.$1}'));
          expect(tester.getCenter(find.descendant(of: tab, matching: find.byType(Icon))).dy,
              lessThan(tester.getCenter(find.descendant(of: tab, matching: find.text(tr(t.$2)))).dy));
        }
        if (lang == 'en') _noJapanese('タブ');
        ctl.setTab('town');
        await tester.pump();
        await _shot(tester, 'tabs_town_$lang');
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('幅320でもタブの字が切れない', (tester) async {
      await _pump(tester, _midGame(), width: 320, lang: 'en');
      for (final t in MainScreen.tabs) {
        final f = find.descendant(of: find.byKey(ValueKey('tab-${t.$1}')), matching: find.text(tr(t.$2)));
        final rp = tester.renderObject<RenderParagraph>(f);
        expect(rp.didExceedMaxLines, isFalse, reason: t.$1);
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('新しい事業の一覧（検索・並べ替え・絞り込み）', () {
    test('名前で絞る（日英）', () {
      final g = _midGame();
      for (final lang in ['ja', 'en']) {
        L.lang = lang;
        final all = newBizList(g);
        expect(all.length, greaterThan(20));
        // 一覧にある業種の名前の一部で探すと、その名前を含むものだけが出る
        final pick = all[all.length ~/ 2];
        final q = lang == 'en' ? pick.name.split(' ').first.toUpperCase() : pick.name.characters.take(2).toString();
        final hit = newBizList(g, query: q);
        expect(hit, contains(pick), reason: '$lang $q');
        for (final i in hit) {
          expect(i.name.toLowerCase(), contains(q.toLowerCase()), reason: '$lang $q');
        }
        expect(hit.length, lessThan(all.length));
        // 前後の空白は無視する
        expect(newBizList(g, query: '  $q ').length, hit.length);
        // 合うものが無い言葉
        expect(newBizList(g, query: lang == 'en' ? 'zzqx' : 'ゑゑゑ'), isEmpty);
      }
      L.lang = 'ja';
    });

    test('並べ替え（元手の安い順・市場の大きい順・生まれたばかり順・利益率の高い順）', () {
      final g = _midGame();
      final cheap = newBizList(g, sort: 'cheap');
      for (var i = 1; i < cheap.length; i++) {
        expect(g.capexOf(cheap[i]), greaterThanOrEqualTo(g.capexOf(cheap[i - 1])));
      }
      final mkt = newBizList(g, sort: 'mkt');
      for (var i = 1; i < mkt.length; i++) {
        expect(g.mkt(mkt[i]), lessThanOrEqualTo(g.mkt(mkt[i - 1])));
      }
      final nw = newBizList(g, sort: 'new');
      for (var i = 1; i < nw.length; i++) {
        expect(nw[i].b, lessThanOrEqualTo(nw[i - 1].b));
      }
      final mg = newBizList(g, sort: 'margin');
      for (var i = 1; i < mg.length; i++) {
        expect(mg[i].mg, lessThanOrEqualTo(mg[i - 1].mg));
      }
      // 並べ替えても中身は同じ
      for (final l in [mkt, nw, mg]) {
        expect(l.toSet(), cheap.toSet());
      }
    });

    test('分類と「始められるものだけ」で絞る。持っている業種は出さない', () {
      final g = _midGame();
      final all = newBizList(g);
      final own = {for (final b in g.biz) b.ind};
      expect(all.where((i) => own.contains(i.id)), isEmpty);
      var cats = 0;
      for (final c in CATN.keys) {
        final l = newBizList(g, cat: c);
        if (l.isNotEmpty) cats++;
        expect(l.every((i) => i.cat == c), isTrue, reason: c);
      }
      expect(cats, greaterThan(5));
      final can = newBizList(g, can: true);
      expect(can.every((i) => g.capexOf(i) <= g.cash), isTrue);
      expect(can.length, all.where((i) => g.capexOf(i) <= g.cash).length);
      g.cash = 0;
      expect(newBizList(g, can: true), isEmpty);
    });

    test('一覧を出しても、仕組みの数字と乱数は変わらない', () {
      final a = _midGame(), b = _midGame();
      for (final s in ['cheap', 'mkt', 'new', 'margin']) {
        newBizList(a, query: 'a', sort: s, can: true, cat: 'net');
      }
      for (var i = 0; i < 6; i++) {
        botMonth(a);
        botMonth(b);
      }
      expect(row(a), row(b));
    });

    for (final lang in ['ja', 'en']) {
      if (lang == 'ja') {
        testWidgets('縦に送っても、分類の札の列は左端のまま（一覧の位置を取り違えない）', (tester) async {
          final ctl = await _pump(tester, _midGame());
          ctl.setTab('biz');
          await tester.pump();
          // 縦の一覧を送ってから札の列が組み立てられる（前は縦の位置をそのまま横に使っていた）
          await _toNewBiz(tester);
          final pos = tester
              .state<ScrollableState>(find.descendant(
                  of: find.byKey(const PageStorageKey<String>('biz-chips'), skipOffstage: false), matching: find.byType(Scrollable), skipOffstage: false))
              .position;
          expect(pos.pixels, 0);
          expect(tester.state<ScrollableState>(_mainList()).position.pixels, greaterThan(100));
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('画面で検索・並べ替え・絞り込みを使う（$lang）', (tester) async {
        final g = _midGame();
        // 一覧の行を全部組み立てるように、縦を長くしておく
        final ctl = await _pump(tester, g, lang: lang, height: 9000);
        ctl.setTab('biz');
        await tester.pump();
        await _toNewBiz(tester);
        // 前の「絞り込み」の選択欄は無い（責任者や値付けの選択だけ）
        expect(find.text(tr('絞り込み')), findsNothing);
        expect(ctl.bizCan, isTrue);
        final can = newBizList(g, can: true).length;
        expect(_rows(), can);
        expect(find.text(tr('{0}件', [can])), findsOneWidget);
        await _shot(tester, 'newbiz_top_$lang');

        // 「始められるものだけ」を外す
        await tester.tap(find.byKey(const ValueKey('biz-can')));
        await tester.pump();
        expect(ctl.bizCan, isFalse);
        expect(_rows(), newBizList(g).length);

        // 並べ替え：市場が大きい順。一覧の1行目が一番大きい市場の業種になる
        await tester.tap(find.byKey(const ValueKey('biz-sort-mkt')));
        await tester.pump();
        expect(ctl.bizSort, 'mkt');
        final top = newBizList(g, sort: 'mkt').first;
        final firstName = find.text(top.name);
        expect(firstName, findsWidgets);
        final names = newBizList(g, sort: 'mkt').take(3).map((i) => tester.getTopLeft(find.text(i.name).last).dy).toList();
        expect(names[0], lessThan(names[1]));
        expect(names[1], lessThan(names[2]));

        // 分類で絞る
        final cat = CATN.keys.firstWhere((c) => newBizList(g, cat: c).length >= 2);
        await tester.ensureVisible(find.byKey(ValueKey('biz-cat-$cat')));
        await tester.pump();
        await tester.tap(find.byKey(ValueKey('biz-cat-$cat')));
        await tester.pump();
        expect(ctl.bizFilter, cat);
        expect(_rows(), newBizList(g, cat: cat).length);

        // 名前で探す
        final pick = newBizList(g, cat: cat).first;
        final q = lang == 'en' ? pick.name.split(' ').first.toLowerCase() : pick.name.characters.take(2).toString();
        await tester.enterText(find.byKey(const ValueKey('biz-search')), q);
        await tester.pump();
        expect(_rows(), newBizList(g, cat: cat, query: q).length);
        expect(find.text(pick.name), findsWidgets);
        expect(find.byKey(const ValueKey('biz-search-clear')), findsOneWidget);
        await _shot(tester, 'newbiz_search_$lang');

        // 合うものが無いときの文
        await tester.enterText(find.byKey(const ValueKey('biz-search')), lang == 'en' ? 'zzqx' : 'ゑゑゑ');
        await tester.pump();
        expect(_rows(), 0);
        expect(find.byKey(const ValueKey('biz-empty')), findsOneWidget);
        expect(find.text(tr('条件に合う事業はありません')), findsOneWidget);
        expect(find.text(tr('{0}件', [0])), findsOneWidget);
        if (lang == 'en') {
          // 検索の欄の中身（日本語で打った言葉）は除いて、画面の文に日本語が残らない
          final j = _texts().where((t) => _cjk.hasMatch(t) && t != 'ゑゑゑ').toList();
          expect(j, isEmpty, reason: j.join(' / '));
        }
        await tester.ensureVisible(find.byKey(const ValueKey('biz-empty')));
        await tester.pump();
        await _shot(tester, 'newbiz_empty_$lang');

        // 消すボタンで元に戻る
        await tester.tap(find.byKey(const ValueKey('biz-search-clear')));
        await tester.pump();
        expect(ctl.bizSearch.text, '');
        expect(_rows(), newBizList(g, cat: cat).length);

        // 部品の押せる範囲は 44pt 以上
        for (final f in [
          find.byKey(const ValueKey('biz-search')),
          find.byKey(const ValueKey('biz-can')),
          for (final s in bizSorts()) find.byKey(ValueKey('biz-sort-${s.$1}')),
          find.byKey(const ValueKey('biz-cat-all')),
          for (final c in CATN.keys) find.byKey(ValueKey('biz-cat-$c')),
        ]) {
          final r = tester.getRect(f);
          expect(r.height, greaterThanOrEqualTo(minTap - .01), reason: '$f');
          expect(r.width, greaterThanOrEqualTo(minTap - .01), reason: '$f');
        }
        // 並べ替えの4つの段は1行に収まる
        for (final s in bizSorts()) {
          final rp = tester.renderObject<RenderParagraph>(find.descendant(of: find.byKey(ValueKey('biz-sort-${s.$1}')), matching: find.byType(RichText)));
          expect(rp.didExceedMaxLines, isFalse);
        }
        if (lang == 'en') _noJapanese('事業のタブ');
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('小窓の出入り', () {
    setUp(SheetMotion.reset);
    tearDown(() {
      SheetMotion.duration = Duration.zero;
      SheetMotion.reverseDuration = Duration.zero;
    });

    double scrim(WidgetTester tester) => tester.widget<FadeTransition>(find.byKey(const ValueKey('sheet-scrim'))).opacity.value;
    Rect card(WidgetTester tester) => tester.getRect(find.byKey(ValueKey('sheet${tester.state<SheetLayerState>(find.byType(SheetLayer)).widget.ctl.sheetSeq}')));

    testWidgets('下から滑り出て、幕が出る。閉じると沈み、幕も引いて消える', (tester) async {
      final ctl = await _pump(tester, _midGame());
      expect(find.byKey(const ValueKey('sheet-scrim')), findsNothing);
      openSettings(ctl);
      await tester.pump();
      final st = tester.state<SheetLayerState>(find.byType(SheetLayer));
      expect(st.anim.value, 0);
      expect(scrim(tester), 0);
      final start = card(tester);
      await tester.pump(const Duration(milliseconds: 100));
      final mid = card(tester);
      expect(mid.top, lessThan(start.top), reason: '上がってきている');
      expect(scrim(tester), inExclusiveRange(0, 1));
      await _shot(tester, 'sheet_opening_ja');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 60));
      expect(st.anim.isCompleted, isTrue, reason: '240ms で開き切る');
      await tester.pumpAndSettle();
      final end = card(tester);
      expect(end.top, lessThan(mid.top));
      expect(scrim(tester), 1);
      // 下に寄せて置く（下の余白12）
      expect(end.bottom, closeTo(844 - 12, 1));
      expect(find.text(tr('設定')), findsWidgets);
      await _shot(tester, 'sheet_open_ja');

      // 閉じる：沈むあいだは最後の中身を見せ、押しても何も起きない
      ctl.closeSheet();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      expect(st.closing, isTrue);
      expect(card(tester).top, greaterThan(end.top));
      expect(scrim(tester), inExclusiveRange(0, 1));
      final ignore = tester.widget<IgnorePointer>(find.ancestor(of: find.byKey(const ValueKey('sheet-scrim')), matching: find.byType(IgnorePointer)).first);
      expect(ignore.ignoring, isTrue);
      await _shot(tester, 'sheet_closing_ja');
      await tester.pump(const Duration(milliseconds: 120));
      expect(st.anim.isDismissed, isTrue, reason: '200ms で沈み切る');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('sheet-scrim')), findsNothing);
      expect(st.closing, isFalse);
      // 下のタブが押せる
      await tester.tap(find.byKey(const ValueKey('tab-biz')));
      await tester.pump();
      expect(ctl.tab, 'biz');
      expect(tester.takeException(), isNull);
    });

    testWidgets('開いたまま中身を替えても、出入りし直さない', (tester) async {
      final ctl = await _pump(tester, _midGame());
      openSettings(ctl);
      await tester.pumpAndSettle();
      final st = tester.state<SheetLayerState>(find.byType(SheetLayer));
      showHelp(ctl);
      await tester.pump();
      expect(st.anim.isCompleted, isTrue);
      expect(find.text(tr('遊び方')), findsWidgets);
      ctl.closeSheet();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      // 沈んでいる途中でまた開くと、そこから上がる
      openSettings(ctl);
      await tester.pump();
      expect(st.anim.value, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(st.anim.isCompleted, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('沈むあいだにゲームが無くなっても落ちない（はじめから）', (tester) async {
      final ctl = await _pump(tester, _midGame());
      confirmRestart(ctl);
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr('はじめからにする')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(ctl.game, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(find.byType(SetupScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('sheet-scrim')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('月を進めて、報告と出来事を出入りの動きつきで最後まで送れる（英語）', (tester) async {
      final g = _midGame();
      final ctl = await _pump(tester, g, lang: 'en');
      for (var m = 0; m < 4; m++) {
        doYear(ctl, 3);
        await tester.pumpAndSettle();
        var guard = 0;
        while (ctl.sheet != null && guard++ < 40) {
          expect(tester.takeException(), isNull);
          _noJapanese('報告・出来事');
          final cont = find.text('Continue');
          final ok = find.text('OK');
          final target = cont.evaluate().isNotEmpty
              ? cont
              : ok.evaluate().isNotEmpty
                  ? ok
                  : find.byType(ChoiceBtn).last;
          await tester.ensureVisible(target.first);
          await tester.pumpAndSettle();
          await tester.tap(target.first);
          await tester.pumpAndSettle();
        }
        expect(ctl.sheet, isNull);
        expect(find.byKey(const ValueKey('sheet-scrim')), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('カードの見た目の決まり', () {
    testWidgets('カードは角丸12・余白14・影1段・線の色。小窓は角丸16・余白16', (tester) async {
      final ctl = await _pump(tester, _midGame(), height: 3000);
      expect(Ui.radius, 12);
      expect(Ui.pad, 14);
      expect(Ui.shadow, hasLength(1));
      for (final t in MainScreen.tabs) {
        ctl.setTab(t.$1);
        await tester.pump();
        final panels = find.byType(Panel).evaluate().toList();
        if (const ['town', 'people', 'stock'].contains(t.$1)) expect(panels, isNotEmpty, reason: t.$1);
        for (final e in panels) {
          final c = tester.widget<Container>(find.descendant(of: find.byWidget(e.widget), matching: find.byType(Container)).first);
          final d = c.decoration! as BoxDecoration;
          expect(d.borderRadius, BorderRadius.circular(12), reason: t.$1);
          expect(d.boxShadow, Ui.shadow, reason: t.$1);
          expect(c.padding, const EdgeInsets.all(14), reason: t.$1);
        }
      }
      ctl.setTab('town');
      await tester.pump();
      openSettings(ctl);
      await tester.pump();
      final m = tester.widget<Material>(find.ancestor(of: find.byKey(ValueKey('sheet${ctl.sheetSeq}')), matching: find.byType(Material)).first);
      expect((m.shape! as RoundedRectangleBorder).borderRadius, BorderRadius.circular(16));
      final sv = tester.widget<SingleChildScrollView>(find.byKey(ValueKey('sheet${ctl.sheetSeq}')));
      expect(sv.padding, const EdgeInsets.all(16));
      expect(tester.takeException(), isNull);
    });

    test('画面の部品に、角の丸みの直書きが残っていない', () {
      // 色の四角（上の帯の手・札）などの小さな印を除き、角の丸みは Ui の値を使う
      for (final f in ['tabs', 'sheets', 'guide']) {
        final src = File('lib/ui/$f.dart').readAsStringSync();
        final raw = RegExp(r'BorderRadius\.circular\((\d+(\.\d+)?)\)').allMatches(src).map((m) => m.group(0)).toList();
        expect(raw, isEmpty, reason: '$f: $raw');
      }
    });
  });

  group('手の表示', () {
    for (final lang in ['ja', 'en']) {
      testWidgets('上の帯に残りの数を数字でも出し、手を使うボタンに札を添える（$lang）', (tester) async {
        final g = _midGame();
        g.ap = 2;
        final ctl = await _pump(tester, g, lang: lang, height: 3000);
        expect(find.byKey(const ValueKey('ap-count')), findsOneWidget);
        expect(tester.widget<Text>(find.byKey(const ValueKey('ap-count'))).data, '2/${g.apMax}');
        // 金の四角は手の上限の数だけ並び、数字はその右
        expect(tester.getTopLeft(find.byKey(const ValueKey('ap-count'))).dx, greaterThan(tester.getTopLeft(find.text(tr('手 '))).dx));
        // 街の社長の行動は、どれも「1手」の札が付く
        expect(find.descendant(of: find.byType(ChoiceBtn), matching: find.byType(ApBadge)), findsNWidgets(5));
        expect(find.text(tr('{0}手', [1])), findsWidgets);
        if (lang == 'en') expect(find.text('1 move'), findsWidgets);
        await _shot(tester, 'ap_town_$lang');
        // 事業のカードの打ち手にも付く
        ctl.setTab('biz');
        ctl.openBiz = (g.biz.toList()..ssort((a, b) => b.rev.compareTo(a.rev))).first.id;
        await tester.pump();
        final badged = find.byWidgetPredicate((w) => w is Btn && w.ap > 0);
        expect(badged.evaluate().length, greaterThanOrEqualTo(6));
        for (final e in badged.evaluate()) {
          expect(find.descendant(of: find.byWidget(e.widget), matching: find.byType(ApBadge)), findsOneWidget);
        }
        // 手を使わない打ち手（借りる・返す）には付かない
        await tester.scrollUntilVisible(find.widgetWithText(Btn, tr('全部返す')), 600, scrollable: _mainList());
        await tester.pump();
        expect((tester.widget<Btn>(find.widgetWithText(Btn, tr('全部返す')))).ap, 0);
        if (lang == 'en') _noJapanese('手の札');
        expect(tester.takeException(), isNull);
      });

      testWidgets('手が残っていないと、手を使うボタンは薄くなり、押すと「今月の手が残っていません」（$lang）', (tester) async {
        final g = _midGame();
        g.ap = 0;
        final ctl = await _pump(tester, g, lang: lang, height: 3000);
        expect(tester.widget<Text>(find.byKey(const ValueKey('ap-count'))).data, '0/${g.apMax}');
        // 薄い（押せないときの .4 とは別の .45）が、押せる
        final work = find.widgetWithText(ChoiceBtn, tr('日銭を稼ぐ'));
        expect(tester.widget<ChoiceBtn>(work).apShort, isTrue);
        final op = tester.widget<Opacity>(find.descendant(of: work, matching: find.byType(Opacity)).first);
        expect(op.opacity, apShortOpacity);
        final cash = g.cash;
        await tester.tap(work);
        await tester.pump();
        expect(find.text(tr('今月の手が残っていません')), findsOneWidget);
        expect(g.cash, cash);
        expect(g.ap, 0);
        await _shot(tester, 'ap_none_toast_$lang');
        ctl.closeSheet();
        await tester.pump();
        // 相棒探し・腕磨きも同じ（今までどおり小窓は開かず、手が無いと知らせる）
        for (final label in ['相棒を探す', '腕を磨く']) {
          final b = find.widgetWithText(ChoiceBtn, tr(label));
          if (!tester.widget<ChoiceBtn>(b).enabled) continue;
          await tester.tap(b);
          await tester.pump();
          expect(find.text(tr('今月の手が残っていません')), findsOneWidget, reason: label);
          ctl.closeSheet();
          await tester.pump();
        }
        // 事業の打ち手も薄い。押すと同じ知らせ
        ctl.setTab('biz');
        final b = (g.biz.toList()..ssort((a, b) => b.rev.compareTo(a.rev))).first;
        ctl.openBiz = b.id;
        await tester.pump();
        final dev = find.byWidgetPredicate((w) => w is Btn && w.label.startsWith(tr('商品を作る {0}', ['']).trim()));
        expect(dev, findsOneWidget);
        expect(tester.widget<Btn>(dev).apShort, isTrue);
        final pipes = b.pipe.length;
        await tester.ensureVisible(dev);
        await tester.pump();
        await tester.tap(dev);
        await tester.pump();
        expect(find.text(tr('今月の手が残っていません')), findsOneWidget);
        expect(b.pipe.length, pipes);
        expect(g.cash, cash);
        ctl.closeSheet();
        await tester.pump();
        // 手を使わないボタンは薄くならない
        await tester.scrollUntilVisible(find.widgetWithText(Btn, tr('全部返す')), 600, scrollable: _mainList());
        await tester.pump();
        expect(tester.widget<Btn>(find.widgetWithText(Btn, tr('全部返す'))).apShort, isFalse);
        if (lang == 'en') _noJapanese('手が無いとき');
        expect(tester.takeException(), isNull);
      });
    }

    test('手を使う打ち手の札の数は、仕組みで使う数と同じ', () {
      final g = _midGame();
      g.ap = 3;
      final b = g.biz.first;
      final before = g.ap;
      g.develop(b, .01);
      expect(before - g.ap, 1);
      // 魅力の特性があると、事業を売るのは2手（ボタンの札も2手）
      expect(g.hasT('charm'), isTrue);
      g.ap = 1;
      expect(msgKey(g.sellBiz(b)), '今月の手が足りません');
    });
  });

  group('目で見る用の画面（幅390・高さ844）', () {
    for (final lang in ['ja', 'en']) {
      testWidgets('事業のタブ・手が無いとき・小窓（$lang）', (tester) async {
        final g = _midGame();
        final ctl = await _pump(tester, g, lang: lang);
        ctl.setTab('biz');
        await tester.pump();
        await _toNewBiz(tester);
        // 分類の札の列は左端から始まる
        double chipsX() => tester.state<ScrollableState>(find.descendant(of: find.byKey(const PageStorageKey<String>('biz-chips')), matching: find.byType(Scrollable))).position.pixels;
        expect(chipsX(), 0);
        await tester.drag(_mainList(), const Offset(0, -40));
        await tester.pump();
        expect(chipsX(), 0);
        await _shot(tester, 'v_newbiz_$lang');
        await tester.tap(find.byKey(const ValueKey('biz-sort-margin')));
        await tester.ensureVisible(find.byKey(const ValueKey('biz-cat-net')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('biz-cat-net')));
        await tester.pump();
        await _shot(tester, 'v_newbiz_net_$lang');
        await tester.ensureVisible(find.byKey(const ValueKey('biz-search'), skipOffstage: false));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const ValueKey('biz-search')), 'zzqx');
        await tester.pump();
        await _shot(tester, 'v_newbiz_empty_$lang');
        ctl.bizSearch.clear();
        FocusManager.instance.primaryFocus?.unfocus();
        g.ap = 0;
        ctl.openBiz = (g.biz.toList()..ssort((a, b) => b.rev.compareTo(a.rev))).first.id;
        ctl.render();
        await tester.pump();
        await tester.scrollUntilVisible(find.byKey(ValueKey('biz-fold-${ctl.openBiz}')), -300, scrollable: _mainList());
        await tester.drag(_mainList(), const Offset(0, -380));
        await tester.pump();
        await _shot(tester, 'v_bizcard_noap_$lang');
        g.ap = 2;
        openEnter(ctl, g.biz.first);
        await tester.pumpAndSettle();
        await _shot(tester, 'v_sheet_enter_$lang');
        expect(tester.takeException(), isNull);
      }, skip: _out == null);
    }
  });

  group('英語に日本語が残らない（新しい部品）', () {
    testWidgets('事業のタブの部品と、手の札（幅390）', (tester) async {
      final g = _midGame();
      final ctl = await _pump(tester, g, lang: 'en', height: 4000);
      for (final t in MainScreen.tabs) {
        ctl.setTab(t.$1);
        await tester.pump();
        _noJapanese(t.$1);
      }
      for (final s in bizSorts()) {
        expect(_cjk.hasMatch(s.$2), isFalse);
      }
      expect(tr('{0}手@@pl', [2]), '2 moves');
      expect(tr('今月の手 残り{0}/{1}', [1, 3]), 'Moves left this month: 1 of 3');
      expect(tester.takeException(), isNull);
    });
  });
}
