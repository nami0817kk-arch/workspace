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

/// 1.0.0+13 の操作と見た目の直し：下のタブのアイコン・新しい事業の検索と並べ替えと絞り込み・小窓の出入り・カードの見た目の決まり・手の数の表示
///
/// 画面の書き出し（目で見る用）は QUAD_SHOTS に書き出し先を渡したときだけ動く（画像はコミットしない）
final _out = Platform.environment['QUAD_SHOTS'];

/// ひらがな・カタカナ・漢字・全角の記号
final _cjk = RegExp('[　-ヿ㐀-鿿＀-￯]');

final _shotKey = GlobalKey();

Future<GameController> _pump(WidgetTester tester, {Game? game, String lang = 'ja', Size size = const Size(390, 844)}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final ctl = GameController(prefs: prefs, newRandom: () => ParkMiller(77), lang: lang);
  ctl.game = game;
  addTearDown(() => L.lang = 'ja');
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(RepaintBoundary(key: _shotKey, child: QuadrillionApp(controller: ctl)));
  await tester.pump();
  return ctl;
}

Game? _cached;

/// 途中のゲーム（事業・部下・宿敵がいる）。作るのに時間がかかるので、セーブの形で1回だけ作って写す
Game _midGame() {
  if (_cached == null) {
    final s = Game.newGame(SetupConfig(mode: 'world', year: 1980, traits: ['charm', 'gambler']), rng: ParkMiller(2024));
    for (var i = 0; i < 150; i++) {
      botMonth(s);
    }
    resolveEvents(s);
    s.calcAll();
    _cached = s;
  }
  return Game.fromJson(_cached!.toJson(), rng: ParkMiller(5))..calcAll();
}

/// 始めたばかりのゲーム（事業なし）
Game _newGame() => Game.newGame(SetupConfig(mode: 'world', year: 2000, traits: ['charm', 'gambler']), rng: ParkMiller(2024));

/// 本物のフォントで描く（書き出しのときだけ）
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
List<String> _texts(WidgetTester tester) => [
      for (final e in find.byWidgetPredicate((w) => w is RichText).evaluate()) (e.widget as RichText).text.toPlainText(),
      for (final e in find.byWidgetPredicate((w) => w is EditableText).evaluate()) (e.widget as EditableText).controller.text,
    ];

void _noJapanese(WidgetTester tester, String where) {
  final j = _texts(tester).where(_cjk.hasMatch).toList();
  expect(j, isEmpty, reason: '$where に日本語が残っている: ${j.take(12).join(' / ')}');
}

/// 新しい事業の一覧に並んでいる業種の名前（上から）
List<String> _rows(WidgetTester tester, Game s) {
  final names = {for (final i in s.inds) i.name};
  final hits = <(double, String)>[];
  for (final e in find.byType(Text).evaluate()) {
    final t = e.widget as Text;
    if (t.data != null && names.contains(t.data) && t.style?.fontSize == 13 && t.style?.fontWeight == FontWeight.w400) {
      hits.add((tester.getTopLeft(find.byWidget(t)).dy, t.data!));
    }
  }
  hits.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final h in hits) h.$2];
}

SheetHostState _host(WidgetTester tester) => tester.state<SheetHostState>(find.byType(SheetHost));

void main() {
  tearDown(() => L.lang = 'ja');

  group('下のタブのアイコン', () {
    const icons = {
      'town': Icons.location_city,
      'biz': Icons.work,
      'people': Icons.people,
      'stock': Icons.pie_chart,
      'num': Icons.bar_chart,
      'zukan': Icons.menu_book,
    };
    for (final lang in ['ja', 'en']) {
      testWidgets('6つのタブにアイコンと字が付き、選んだタブだけ金になる（$lang）', (tester) async {
        final ctl = await _pump(tester, game: _midGame(), lang: lang);
        for (final t in MainScreen.tabs) {
          final tab = find.byKey(ValueKey('tab-${t.$1}'));
          expect(find.descendant(of: tab, matching: find.byIcon(icons[t.$1]!)), findsOneWidget, reason: t.$1);
          expect(find.descendant(of: tab, matching: find.text(tr(t.$2))), findsOneWidget, reason: t.$1);
          // 押せる範囲は 44pt 以上
          final r = tester.getRect(tab);
          expect(r.height, greaterThanOrEqualTo(minTap), reason: t.$1);
          expect(r.width, greaterThanOrEqualTo(minTap), reason: t.$1);
        }
        for (final t in MainScreen.tabs) {
          await tester.tap(find.byKey(ValueKey('tab-${t.$1}')));
          await tester.pumpAndSettle();
          expect(ctl.tab, t.$1);
          for (final o in MainScreen.tabs) {
            final tab = find.byKey(ValueKey('tab-${o.$1}'));
            final on = o.$1 == t.$1;
            final label = tester.widget<Text>(find.descendant(of: tab, matching: find.text(tr(o.$2))));
            expect(label.style!.color, on ? Pal.goldtx : Pal.mute, reason: '${t.$1} を選んだときの ${o.$1} の字');
            expect(label.style!.fontWeight, on ? FontWeight.w700 : FontWeight.w400);
            // 選んだタブはアイコンの後ろに金の帯
            final pill = tester.widget<AnimatedContainer>(find.descendant(of: tab, matching: find.byType(AnimatedContainer)));
            expect((pill.decoration as BoxDecoration).color, on ? Pal.gold : Pal.gold.withValues(alpha: 0), reason: '${o.$1} の帯');
          }
        }
        if (lang == 'en') _noJapanese(tester, '図鑑のタブ');
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('幅320でもタブの字がはみ出さない', (tester) async {
      await _pump(tester, game: _midGame(), lang: 'en', size: const Size(320, 640));
      expect(tester.takeException(), isNull);
      for (final t in MainScreen.tabs) {
        expect(tester.getRect(find.byKey(ValueKey('tab-${t.$1}'))).height, greaterThanOrEqualTo(minTap));
      }
    });
  });

  group('新しい事業の一覧：検索・並べ替え・絞り込み', () {
    test('並べ替えの4つの順', () {
      final s = _midGame();
      final cost = newBizList(s, sort: 'cost');
      expect(cost.length, greaterThan(20));
      for (var i = 1; i < cost.length; i++) {
        expect(s.capexOf(cost[i]), greaterThanOrEqualTo(s.capexOf(cost[i - 1])));
      }
      final market = newBizList(s, sort: 'market');
      for (var i = 1; i < market.length; i++) {
        expect(s.mkt(market[i]), lessThanOrEqualTo(s.mkt(market[i - 1])));
      }
      final born = newBizList(s, sort: 'new');
      for (var i = 1; i < born.length; i++) {
        expect(born[i].b, lessThanOrEqualTo(born[i - 1].b));
      }
      final margin = newBizList(s, sort: 'margin');
      for (var i = 1; i < margin.length; i++) {
        expect(margin[i].mg, lessThanOrEqualTo(margin[i - 1].mg));
      }
      // 並べ替えても中身は同じ
      for (final l in [market, born, margin]) {
        expect({for (final i in l) i.id}, {for (final i in cost) i.id});
      }
      // 持っている業種は出さない
      expect(cost.any((i) => s.biz.any((b) => b.ind == i.id)), isFalse);
    });

    test('絞り込み（始められる・10年以内・分類）と名前の検索（日本語でも英語でも）', () {
      final s = _midGame();
      final all = newBizList(s);
      expect(newBizList(s, filter: 'can').every((i) => s.capexOf(i) <= s.cash), isTrue);
      expect(newBizList(s, filter: 'new').every((i) => s.yr() - i.b < 10), isTrue);
      for (final cat in CATN.ja.keys) {
        final l = newBizList(s, filter: cat);
        expect(l.every((i) => i.cat == cat), isTrue, reason: cat);
        expect(l.length, all.where((i) => i.cat == cat).length, reason: cat);
      }
      final one = all.first;
      final ja = one.ja, en = enText(one.ja)!;
      // 名前の一部で絞れる。大文字と小文字は区別しない。前後の空白は無視する
      expect(newBizList(s, query: ja).map((i) => i.id), contains(one.id));
      expect(newBizList(s, query: ' ${en.toUpperCase()} ').map((i) => i.id), contains(one.id));
      expect(newBizList(s, query: en.substring(0, 3).toLowerCase()).map((i) => i.id), contains(one.id));
      expect(newBizList(s, query: ja).every((i) => i.ja.contains(ja)), isTrue);
      expect(newBizList(s, query: 'zzzzqq'), isEmpty);
      // 絞り込みと検索は重ねて効く
      expect(newBizList(s, filter: one.cat, query: ja).map((i) => i.id), contains(one.id));
      final other = CATN.ja.keys.firstWhere((c) => c != one.cat && !all.any((i) => i.cat == c && i.ja.contains(ja)));
      expect(newBizList(s, filter: other, query: ja), isEmpty);
    });

    test('一覧を作っても、仕組みの数字と乱数は動かない', () {
      final a = _midGame(), b = _midGame();
      for (final sort in ['cost', 'market', 'new', 'margin']) {
        newBizList(a, filter: 'can', sort: sort, query: 'a');
      }
      expect(a.toJson().toString(), b.toJson().toString());
      expect(a.rnd(), b.rnd());
    });

    for (final lang in ['ja', 'en']) {
      testWidgets('検索の欄と札で絞れる。合うものが無いときの文も出る（$lang）', (tester) async {
        final s = _midGame();
        // 一覧を全部いちどに描ける高さにする（1.0.0+18 で自社の事業の上に「まとめての手」と並べ替えの札が入り、12000 では英語の一覧の末尾が入りきらなくなった）
        final ctl = await _pump(tester, game: s, lang: lang, size: const Size(390, 16000));
        ctl.setTab('biz');
        await tester.pump();
        // 前の選ぶ欄（絞り込み）は札に置き換わった
        expect(find.byType(SearchBox), findsOneWidget);
        expect(find.byKey(const ValueKey('sort-cost')), findsOneWidget);
        // 分類の10個は「分類」の札1つにまとめた（1.0.0+14）
        // 事業が多い会社では、自社の事業の並べ替えの札も出る（1.0.0+18）
        expect(find.byType(PickChip), findsNWidgets(bizSorts.length + bizFilters.length + 1 + (s.biz.length >= bizManyMin ? myBizSorts.length : 0)));
        for (final o in bizSorts) {
          expect(find.descendant(of: find.byKey(ValueKey('sort-${o.$1}')), matching: find.text(tr(o.$2))), findsOneWidget);
        }
        // はじめは「今の資金で始められる」を元手の安い順
        expect(tester.widget<PickChip>(find.byKey(const ValueKey('filter-can'))).on, isTrue);
        expect(tester.widget<PickChip>(find.byKey(const ValueKey('sort-cost'))).on, isTrue);
        expect(_rows(tester, s), newBizList(s, filter: 'can').map((i) => i.name).toList());

        // 絞り込みの札
        await tester.ensureVisible(find.byKey(const ValueKey('filter-all')));
        await tester.tap(find.byKey(const ValueKey('filter-all')));
        await tester.pump();
        expect(ctl.bizFilter, 'all');
        expect(_rows(tester, s), newBizList(s).map((i) => i.name).toList());
        expect(find.text(tr('業種（{0}件）', [newBizList(s).length])), findsOneWidget);

        // 並べ替えの札（4つとも）
        for (final o in bizSorts) {
          await tester.ensureVisible(find.byKey(ValueKey('sort-${o.$1}')));
          await tester.tap(find.byKey(ValueKey('sort-${o.$1}')));
          await tester.pump();
          expect(ctl.bizSort, o.$1);
          expect(tester.widget<PickChip>(find.byKey(ValueKey('sort-${o.$1}'))).on, isTrue);
          expect(_rows(tester, s), newBizList(s, sort: o.$1).map((i) => i.name).toList(), reason: o.$1);
        }

        // 分類の札（押すと選ぶ小窓が開く）
        final cat = CATN.ja.keys.last;
        await tester.ensureVisible(find.byKey(const ValueKey('filter-cat')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('filter-cat')));
        await tester.pump();
        await tester.ensureVisible(find.byKey(ValueKey('filter-$cat')));
        await tester.tap(find.byKey(ValueKey('filter-$cat')));
        await tester.pump();
        expect(ctl.sheet, isNull);
        expect(ctl.bizFilter, cat);
        expect(_rows(tester, s), newBizList(s, filter: cat, sort: ctl.bizSort).map((i) => i.name).toList());

        // 名前で探す（今の言語の名前の一部）
        await tester.ensureVisible(find.byKey(const ValueKey('filter-all')));
        await tester.tap(find.byKey(const ValueKey('filter-all')));
        await tester.pump();
        final target = newBizList(s)[7];
        final word = lang == 'en' ? target.name.substring(0, 4).toUpperCase() : target.name.substring(0, 2);
        await tester.enterText(find.byType(TextField), word);
        await tester.pump();
        final hit = newBizList(s, sort: ctl.bizSort, query: word);
        expect(hit.map((i) => i.id), contains(target.id));
        expect(hit.length, lessThan(newBizList(s).length));
        expect(_rows(tester, s), hit.map((i) => i.name).toList());

        // 合うものが無い
        await tester.enterText(find.byType(TextField), 'zzzzqq');
        await tester.pump();
        expect(_rows(tester, s), isEmpty);
        expect(find.byKey(const ValueKey('biz-empty')), findsOneWidget);
        expect(find.text(tr('「{0}」に合う業種が見つかりません。', ['zzzzqq'])), findsOneWidget);
        if (lang == 'en') _noJapanese(tester, '合うものが無い一覧');

        // 欄の×で消すと元に戻る
        await tester.tap(find.byKey(const ValueKey('search-clear')));
        await tester.pump();
        expect(ctl.bizSearch.text, '');
        expect(_rows(tester, s).length, newBizList(s).length);

        // 「条件を外して全部見る」
        ctl.bizFilter = 'can';
        await tester.enterText(find.byType(TextField), 'zzzzqq');
        await tester.pump();
        await tester.tap(find.text(tr('条件を外して全部見る')));
        await tester.pump();
        expect(ctl.bizFilter, 'all');
        expect(ctl.bizSearch.text, '');
        expect(_rows(tester, s).length, newBizList(s).length);
        if (lang == 'en') _noJapanese(tester, '事業のタブ');
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('一覧を下まで流してからタブを行き来しても、札の列と検索の字は左の端から出る', (tester) async {
      final s = _midGame();
      final ctl = await _pump(tester, game: s);
      ctl.bizFilter = 'all';
      ctl.setTab('biz');
      await tester.pump();
      // 外側の一覧を大きく流す（この位置をタブごとに覚えている）
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await tester.pumpAndSettle();
      ctl.setTab('town');
      await tester.pump();
      ctl.setTab('biz');
      await tester.pump();
      await tester.dragUntilVisible(find.byType(SearchBox), find.byType(Scrollable).first, const Offset(0, 250));
      await tester.pumpAndSettle();
      // 並べ替えの最初の札が、見出しのすぐ右に見えている（右の端まで流れていない）
      final first = tester.getRect(find.byKey(const ValueKey('sort-cost')));
      expect(first.left, greaterThan(50));
      expect(first.left, lessThan(140));
      expect(tester.getRect(find.byKey(const ValueKey('filter-all'))).left, inExclusiveRange(50, 140));
      // 打った字が欄の中に見えている
      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pump();
      final field = tester.getRect(find.byType(SearchBox));
      final text = tester.getRect(find.byType(EditableText));
      expect(text.left, greaterThanOrEqualTo(field.left));
      final editable = tester.state<EditableTextState>(find.byType(EditableText));
      expect(editable.renderEditable.offset.pixels, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('絞り込みだけで合うものが無いときは、今までどおりの文', (tester) async {
      final s = _midGame()..cash = 0;
      final ctl = await _pump(tester, game: s, size: const Size(390, 6000));
      ctl.setTab('biz');
      await tester.pump();
      expect(find.text('この条件で始められる事業はありません。'), findsOneWidget);
      expect(find.text('条件を外して全部見る'), findsOneWidget);
    });
  });

  group('小窓の出入り', () {
    // ほかのテストは出入りの時間を0にしている（flutter_test_config.dart）。ここは本物の時間で確かめる
    setUp(() => Ui.sheetMotion = Ui.sheetMotionDefault);
    tearDown(() => Ui.sheetMotion = Duration.zero);

    test('出入りの時間は 200〜250ms', () {
      expect(Ui.sheetMotionDefault.inMilliseconds, inInclusiveRange(200, 250));
      expect(Ui.sheetMotion, Ui.sheetMotionDefault);
    });

    testWidgets('下から滑り出て、閉じるときは沈む。後ろの幕も薄く出入りする', (tester) async {
      final ctl = await _pump(tester, game: _midGame());
      expect(find.byKey(const ValueKey('sheet-card')), findsNothing);
      final screen = tester.getRect(find.byType(Scaffold));

      openSettings(ctl);
      await tester.pump();
      // 出はじめ：小窓は画面の下の外、幕は透明
      final card = find.byKey(const ValueKey('sheet-card'));
      double scrim() => tester.widget<FadeTransition>(find.ancestor(of: find.byKey(const ValueKey('sheet-scrim')), matching: find.byType(FadeTransition)).first).opacity.value;
      expect(_host(tester).progress, 0);
      expect(tester.getRect(card).top, greaterThanOrEqualTo(screen.bottom));
      expect(scrim(), 0);
      // 途中：上がってくる途中で、幕は半透明
      await tester.pump(Duration(milliseconds: Ui.sheetMotion.inMilliseconds ~/ 2));
      final mid = tester.getRect(card);
      expect(_host(tester).progress, inExclusiveRange(0, 1));
      expect(scrim(), inExclusiveRange(0, 1));
      // 終わり：画面の中に収まって止まる
      await tester.pump(Ui.sheetMotion);
      final end = tester.getRect(card);
      expect(_host(tester).progress, 1);
      expect(scrim(), 1);
      expect(mid.top, greaterThan(end.top));
      expect(end.bottom, lessThanOrEqualTo(screen.bottom));
      expect(end.top, greaterThanOrEqualTo(0));
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.text('設定'), findsOneWidget);

      // 閉じる：沈むあいだは中身が残り、押しても動かない。終わると消える
      ctl.closeSheet();
      await tester.pump();
      expect(ctl.sheet, isNull);
      expect(_host(tester).closing, isTrue);
      await tester.pump(Duration(milliseconds: Ui.sheetMotion.inMilliseconds ~/ 2));
      expect(find.text('設定'), findsOneWidget);
      expect(tester.getRect(card).top, greaterThan(end.top));
      expect(scrim(), inExclusiveRange(0, 1));
      await tester.tap(find.text('English'), warnIfMissed: false);
      expect(L.lang, 'ja', reason: '沈んでいる小窓は押せない');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('sheet-card')), findsNothing);
      expect(find.byKey(const ValueKey('sheet-scrim')), findsNothing);
      expect(_host(tester).progress, 0);
      expect(_host(tester).closing, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('小窓から次の小窓へ続くときは出入りさせず、中身だけ替わる', (tester) async {
      final ctl = await _pump(tester, game: _midGame());
      openSettings(ctl);
      await tester.pumpAndSettle();
      showHelp(ctl);
      await tester.pump();
      expect(_host(tester).progress, 1);
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.text('遊び方'), findsWidgets);
      // 沈んでいる途中で開き直すと、そこから上がり直す
      ctl.closeSheet();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      openSettings(ctl);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(_host(tester).progress, inExclusiveRange(0, 1));
      expect(_host(tester).closing, isFalse);
      await tester.pumpAndSettle();
      expect(_host(tester).progress, 1);
      expect(find.text('設定'), findsOneWidget);
    });

    testWidgets('事業を売った結果の小窓を閉じても、沈むあいだに落ちない（もう無い事業を組み直さない）', (tester) async {
      final s = _midGame();
      final ctl = await _pump(tester, game: s);
      final b = s.biz.first;
      s.ap = 5;
      openBuild(ctl, b);
      await tester.pumpAndSettle();
      // 小窓を開いたまま、後ろで事業が消える
      s.biz.remove(b);
      ctl.closeSheet();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      ctl.render();
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('sheet-card')), findsNothing);
    });

    testWidgets('手を打つ→結果→OK を、出入りの終わりまで進めながら続けても落ちない（日英）', (tester) async {
      for (final lang in ['ja', 'en']) {
        final s = _newGame();
        final ctl = await _pump(tester, game: s, lang: lang);
        // 「社長の行動」は「今月やること」・街の絵・会社の数字の下（1.0.0+14）。流して出す
        await tester.scrollUntilVisible(find.text(tr('日銭を稼ぐ')), 200, scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text(tr('日銭を稼ぐ')));
        await tester.pumpAndSettle();
        expect(ctl.sheet, isNotNull);
        expect(_host(tester).progress, 1);
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        expect(ctl.sheet, isNull);
        expect(find.byKey(const ValueKey('sheet-card')), findsNothing);
        // 月を進めて、報告と出来事を最後まで閉じる
        for (var m = 0; m < 6; m++) {
          doNext(ctl);
          await tester.pumpAndSettle();
          var guard = 0;
          while (ctl.sheet != null && guard++ < 30) {
            final sheet = find.byKey(const ValueKey('sheet-card'));
            final btn = find.descendant(of: sheet, matching: find.byWidgetPredicate((w) => w is Btn || w is ChoiceBtn));
            await tester.ensureVisible(btn.last);
            await tester.pumpAndSettle();
            await tester.tap(find.descendant(of: btn.last, matching: find.byType(InkWell)));
            await tester.pumpAndSettle();
          }
          expect(ctl.sheet, isNull);
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('動きを減らす設定の端末では、すぐ出てすぐ消える', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final ctl = await _pump(tester, game: _midGame());
      openSettings(ctl);
      await tester.pump();
      expect(_host(tester).progress, 1);
      ctl.closeSheet();
      await tester.pump();
      expect(find.byKey(const ValueKey('sheet-card')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('カードの見た目の決まり', () {
    testWidgets('全部の画面のカードが、同じ角の丸み・枠・薄い影・余白になっている', (tester) async {
      final s = _midGame();
      final ctl = await _pump(tester, game: s, size: const Size(390, 12000));
      ctl.openBiz = s.biz.first.id;
      var seen = 0;
      for (final t in MainScreen.tabs) {
        ctl.setTab(t.$1);
        await tester.pump();
        for (final e in find.byType(Panel).evaluate()) {
          final box = tester.widget<Container>(find.descendant(of: find.byWidget(e.widget), matching: find.byType(Container)).first);
          final d = box.decoration as BoxDecoration;
          expect(d.borderRadius, BorderRadius.circular(Ui.rCard), reason: t.$1);
          expect(d.boxShadow, Ui.shadow, reason: t.$1);
          expect((d.border as Border).top.width, 1, reason: t.$1);
          seen++;
        }
      }
      expect(seen, greaterThan(20));
      // 影はごく薄い（不透明度 10% 未満）
      expect(Ui.shadow.single.color.a, lessThan(.1));
      expect(Ui.shadow.single.blurRadius, lessThanOrEqualTo(8));
      // たたんだ事業の行・絵の枠・案内の帯も同じ決まり
      expect(cardDeco().borderRadius, BorderRadius.circular(Ui.rCard));
      expect(const Panel(child: SizedBox()).padding, const EdgeInsets.all(Ui.pad));
    });

    testWidgets('小窓の角・枠・余白と、見出しの字', (tester) async {
      final ctl = await _pump(tester, game: _midGame());
      openSettings(ctl);
      await tester.pumpAndSettle();
      final m = tester.widget<Material>(find.descendant(of: find.byKey(const ValueKey('sheet-card')), matching: find.byType(Material)).first);
      final shape = m.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(Ui.rSheet));
      expect(shape.side.color, Pal.line);
      expect(m.color, Pal.panel);
      final scroll = tester.widget<SingleChildScrollView>(find.descendant(of: find.byKey(const ValueKey('sheet-card')), matching: find.byType(SingleChildScrollView)));
      expect(scroll.padding, const EdgeInsets.all(Ui.sheetPad));
      final h = tester.widget<Text>(find.text('設定'));
      expect(h.style!.fontSize, Ui.h2.fontSize);
      expect(h.style!.color, Pal.goldtx);
      ctl.closeSheet();
      ctl.setTab('town');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('社長の行動'), 200, scrollable: find.byType(Scrollable).first);
      final title = tester.widget<Text>(find.text('社長の行動'));
      expect(title.style, Ui.cardTitle(gold: true));
    });
  });

  group('手の表示', () {
    for (final lang in ['ja', 'en']) {
      testWidgets('上の帯に、金の四角と残りの数字が出る（$lang）', (tester) async {
        final s = _midGame();
        s.ap = 2;
        final ctl = await _pump(tester, game: s, lang: lang);
        final ap = find.byKey(const ValueKey('ap'));
        expect(find.descendant(of: ap, matching: find.text('2/${s.apMax}')), findsOneWidget);
        // 四角は全部の数だけあり、残りの数だけ金
        final boxes = [
          for (final e in find.descendant(of: ap, matching: find.byType(Container)).evaluate())
            if ((e.widget as Container).decoration case final BoxDecoration d) d.color
        ];
        expect(boxes.length, s.apMax);
        expect(boxes.where((c) => c == Pal.gold).length, 2);
        expect(boxes.where((c) => c == Pal.line).length, s.apMax - 2);
        // 手を使うと数字も減る
        ctl.act(() => s.presAct('work'));
        await tester.pumpAndSettle();
        expect(find.descendant(of: ap, matching: find.text('1/${s.apMax}')), findsOneWidget);
        if (lang == 'en') _noJapanese(tester, '上の帯');
      });

      testWidgets('手を使うボタンに「1手」の札。足りないと薄くなり、押すと知らせが出る（$lang）', (tester) async {
        final s = _midGame();
        s.ap = 3;
        if (!s.hasT('charm')) s.pres.traits.add('charm');
        final ctl = await _pump(tester, game: s, lang: lang, size: const Size(390, 12000));
        final one = lang == 'en' ? '1 move' : '1手';
        // 街：社長の行動の5つ
        for (final name in ['相棒を探す', '日銭を稼ぐ', '腕を磨く', '人脈を作る', '事業の種を探す']) {
          final btn = find.ancestor(of: find.text(tr(name)), matching: find.byType(ChoiceBtn));
          expect(find.descendant(of: btn, matching: find.text(one)), findsOneWidget, reason: name);
          expect(tester.widget<ChoiceBtn>(btn).dim, isFalse, reason: name);
        }
        // 事業：打ち手のボタン（手を使わない「業界団体に入る」や責任者の欄には付かない）
        ctl.openBiz = s.biz.first.id;
        ctl.setTab('biz');
        await tester.pump();
        Finder btnOf(String label) => find.ancestor(of: find.text(label), matching: find.byType(Btn));
        for (final label in [tr('商品を作る'), tr('海外に出る'), tr('分社・独立')]) {
          expect(tester.widget<Btn>(btnOf(label)).ap, 1, reason: label);
          expect(find.descendant(of: btnOf(label), matching: find.text(one)), findsOneWidget, reason: label);
        }
        // 「人たらし」の社長が事業を売るのは2手
        final sell = find.byWidgetPredicate((w) => w is Btn && w.label.startsWith(lang == 'en' ? 'Sell' : '売る（'));
        expect(tester.widget<Btn>(sell.first).ap, 2);
        expect(find.descendant(of: sell.first, matching: find.text(lang == 'en' ? '2 moves' : '2手')), findsOneWidget);
        expect(find.byType(ApTag), findsWidgets);
        for (final e in find.byType(Btn).evaluate()) {
          final b = e.widget as Btn;
          if (b.label.contains(tr('借りる')) || b.label == tr('全部返す')) expect(b.ap, 0, reason: b.label);
        }
        if (lang == 'en') _noJapanese(tester, '事業のタブ');

        // 手が0：薄くなり、押すと「今月の手が残っていません」。小窓は開かず、手もお金も動かない
        s.ap = 0;
        ctl.render();
        await tester.pump();
        final develop = btnOf(tr('商品を作る'));
        expect(tester.widget<Btn>(develop).dim, isTrue);
        expect(tester.widget<Opacity>(find.descendant(of: develop, matching: find.byType(Opacity)).first).opacity, .4);
        final cash = s.cash;
        await tester.tap(find.descendant(of: develop, matching: find.byType(InkWell)));
        await tester.pumpAndSettle();
        expect(find.text(tr('今月の手が残っていません')), findsOneWidget);
        expect(find.textContaining(tr('手元 {0}', [yen(s.cash)])), findsNothing, reason: '商品を作る小窓は開かない');
        expect(s.cash, cash);
        expect(s.ap, 0);
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        expect(ctl.sheet, isNull);

        // 街の社長の行動も同じ
        ctl.setTab('town');
        await tester.pump();
        final work = find.ancestor(of: find.text(tr('日銭を稼ぐ')), matching: find.byType(ChoiceBtn));
        expect(tester.widget<ChoiceBtn>(work).dim, isTrue);
        await tester.tap(find.descendant(of: work, matching: find.byType(InkWell)));
        await tester.pumpAndSettle();
        expect(find.text(tr('今月の手が残っていません')), findsOneWidget);
        expect(s.cash, cash);
        if (lang == 'en') _noJapanese(tester, '知らせの小窓');
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        // 人・株のタブでも、手を使うボタンは薄くなって札が付く
        for (final t in ['people', 'stock']) {
          ctl.setTab(t);
          await tester.pump();
          final withAp = find.byWidgetPredicate((w) => w is Btn && w.ap > 0);
          expect(withAp, findsWidgets, reason: t);
          for (final e in withAp.evaluate()) {
            expect((e.widget as Btn).dim, isTrue, reason: '$t ${(e.widget as Btn).label}');
          }
          if (lang == 'en') _noJapanese(tester, 'タブ $t');
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('最初の事業は手を使わないので札を付けない。2つ目からは「1手」', (tester) async {
      final s = _newGame();
      final ctl = await _pump(tester, game: s, size: const Size(390, 6000));
      ctl.setTab('biz');
      await tester.pump();
      final start = find.byWidgetPredicate((w) => w is Btn && w.label == '始める');
      expect(start, findsWidgets);
      expect(start.evaluate().every((e) => (e.widget as Btn).ap == 0), isTrue);
      // 手が0でも最初の1つは始められる
      s.ap = 0;
      ctl.render();
      await tester.pump();
      expect(start.evaluate().every((e) => !(e.widget as Btn).dim), isTrue);
      final first = newBizList(s, filter: 'can').firstWhere((i) => s.modelsFor(i.id).length == 1);
      ctl.act(() => s.startBiz(first.id));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(s.biz.length, 1);
      s.cash = 1e12;
      ctl.render();
      await tester.pump();
      expect(start.evaluate().every((e) => (e.widget as Btn).ap == 1 && (e.widget as Btn).dim), isTrue);
      await tester.tap(find.descendant(of: start.first, matching: find.byType(InkWell)));
      await tester.pumpAndSettle();
      expect(find.text('今月の手が残っていません'), findsOneWidget);
      expect(s.biz.length, 1);
    });
  });

  group('押しやすさ（44pt 以上）は今も守られている', () {
    for (final lang in ['ja', 'en']) {
      testWidgets('札・検索の欄・タブ・手の札つきのボタン（$lang）', (tester) async {
        final s = _midGame();
        final ctl = await _pump(tester, game: s, lang: lang, size: const Size(390, 12000));
        ctl.openBiz = s.biz.first.id;
        for (final t in MainScreen.tabs) {
          ctl.setTab(t.$1);
          await tester.pump();
          final bad = <String>[];
          void check(Finder f, String name, {bool width = true}) {
            for (final e in f.evaluate()) {
              final r = tester.getRect(find.byWidget(e.widget).first);
              if (r.height < minTap - .01 || (width && r.width < minTap - .01)) bad.add('$name ${r.size}');
            }
          }

          check(find.byType(Btn), 'Btn');
          check(find.descendant(of: find.byType(ChoiceBtn), matching: find.byType(InkWell)), 'ChoiceBtn');
          check(find.byType(PickChip), 'PickChip');
          check(find.byType(SearchBox), 'SearchBox', width: false);
          check(find.byType(IconButton), 'IconButton');
          check(find.byWidgetPredicate((w) => w is InkWell && w.key is ValueKey && RegExp(r'^(tab-|biz-|pipe-)').hasMatch('${(w.key as ValueKey).value}')), 'InkWell');
          expect(bad, isEmpty, reason: 'タブ ${t.$1}: ${bad.take(8).join(', ')}');
        }
        expect(tester.takeException(), isNull);
      });
    }
  });

  // 目で見る用の書き出し（QUAD_SHOTS があるときだけ）
  for (final lang in ['ja', 'en']) {
    testWidgets('直した画面の書き出し（$lang・幅390）', (tester) async {
      await _loadFonts();
      final s = _midGame();
      s.ap = 3;
      final ctl = await _pump(tester, game: s, lang: lang);
      await _shot(tester, 'a1_town_$lang');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -420));
      await tester.pump();
      await _shot(tester, 'a2_town_actions_$lang');
      s.ap = 0;
      ctl.render();
      await tester.pump();
      await _shot(tester, 'a3_town_noap_$lang');
      s.ap = 3;
      ctl.openBiz = s.biz.first.id;
      ctl.setTab('biz');
      await tester.pump();
      await _shot(tester, 'a4_biz_$lang');
      await tester.scrollUntilVisible(find.byType(SearchBox), 300, scrollable: find.byType(Scrollable).first);
      await Scrollable.ensureVisible(tester.element(find.byType(SearchBox)), alignment: .08);
      await tester.pump();
      await _shot(tester, 'a5_newbiz_$lang');
      ctl.bizFilter = 'all';
      ctl.bizSort = 'market';
      await tester.enterText(find.byType(TextField), lang == 'en' ? 'sh' : '屋');
      await tester.pump();
      await _shot(tester, 'a6_newbiz_search_$lang');
      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pump();
      await _shot(tester, 'a7_newbiz_empty_$lang');
      await tester.enterText(find.byType(TextField), '');
      FocusManager.instance.primaryFocus?.unfocus();
      for (final t in ['people', 'stock', 'num', 'zukan']) {
        ctl.setTab(t);
        await tester.pumpAndSettle();
        await _shot(tester, 'a8_${t}_$lang');
      }
      ctl.setTab('biz');
      await tester.pumpAndSettle();
      openDevelop(ctl, s.biz.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      await _shot(tester, 'a9_sheet_mid_$lang');
      await tester.pumpAndSettle();
      await _shot(tester, 'a9_sheet_open_$lang');
      ctl.closeSheet();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110));
      await _shot(tester, 'a9_sheet_closing_$lang');
      await tester.pumpAndSettle();
      openSettings(ctl);
      await tester.pumpAndSettle();
      await _shot(tester, 'a10_settings_$lang');
      expect(tester.takeException(), isNull);
    });
  }
}
