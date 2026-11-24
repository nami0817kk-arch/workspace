import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';
import 'package:quadrillion/ui/app.dart';
import 'package:quadrillion/ui/controller.dart';
import 'package:quadrillion/ui/guide.dart';
import 'package:quadrillion/ui/sheets.dart';
import 'package:quadrillion/ui/tabs.dart';
import 'package:quadrillion/ui/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/bot.dart';

/// 1.0.0+14 の操作と見た目の直し：絞り込みの札の折り返し・街のタブの整理・月送りの報告の表とニュースのアイコン・
/// 人のタブのたたみと能力の棒・株の節目の線と「あと何%」・英語の長いボタン
///
/// 画面の書き出し（目で見る用）は QUAD_SHOTS に書き出し先を渡したときだけ動く（画像はコミットしない）
final _out = Platform.environment['QUAD_SHOTS'];

/// ひらがな・カタカナ・漢字・全角の記号
final _cjk = RegExp('[　-ヿ㐀-鿿＀-￯]');

final _shotKey = GlobalKey();

Future<GameController> _pump(WidgetTester tester, {Game? game, String lang = 'ja', Size size = const Size(390, 6000)}) async {
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

/// 途中のゲーム（上場済み・事業12・部下12・宿敵4）。作るのに時間がかかるので、セーブの形で1回だけ作って写す
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

/// 始めたばかりのゲーム（事業なし・未上場）
Game _newGame() => Game.newGame(SetupConfig(mode: 'world', year: 2000, traits: ['charm', 'gambler']), rng: ParkMiller(2024));

List<Company> _rivals(Game s) => s.cos.where((c) => c.rival != null && c.alive).toList();

/// 宿敵の1社に、あなたの株を [p]% 持たせる（市場の株から移す）
void _giveRival(Game s, double p) {
  final c = _rivals(s).first;
  s.sh.riv[c.id] = p;
  s.sh.float = (s.sh.float - p).clamp(0, 100).toDouble();
}

bool _fontsLoaded = false;

/// 本物のフォントで描く（字の幅を確かめるテストと、書き出しのとき）
Future<void> _loadFonts() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;
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

/// 字が何行に描かれているか
int _lines(RenderParagraph rp) =>
    {for (final b in rp.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: rp.text.toPlainText().length))) b.top.round()}.length;

/// 開いている小窓の中だけを探す（後ろの画面にも同じ部品がある）
Finder _inSheet(Finder f) => find.descendant(of: find.byKey(const ValueKey('sheet-card')), matching: f);

void main() {
  tearDown(() => L.lang = 'ja');

  group('絞り込みの札', () {
    for (final lang in ['ja', 'en']) {
      for (final w in [390.0, 320.0]) {
        testWidgets('並べ替えと絞り込みの札が、流さなくても全部見える（$lang・幅${w.round()}）', (tester) async {
          final ctl = await _pump(tester, game: _midGame(), lang: lang, size: Size(w, 6000));
          ctl.setTab('biz');
          await tester.pump();
          // 横に流す列はもう無い
          expect(find.byWidgetPredicate((x) => x is SingleChildScrollView && x.scrollDirection == Axis.horizontal), findsNothing);
          final keys = [for (final o in bizSorts) 'sort-${o.$1}', for (final o in bizFilters) 'filter-${o.$1}', 'filter-cat'];
          for (final k in keys) {
            final r = tester.getRect(find.byKey(ValueKey(k)));
            expect(r.left, greaterThanOrEqualTo(0), reason: k);
            expect(r.right, lessThanOrEqualTo(w - 12 + .01), reason: '$k が右にはみ出している');
            expect(r.height, greaterThanOrEqualTo(minTap), reason: '$k の押せる高さ');
            expect(r.width, greaterThanOrEqualTo(minTap), reason: '$k の押せる幅');
          }
          // 札どうしは重ならない
          for (var i = 0; i < keys.length; i++) {
            for (var j = i + 1; j < keys.length; j++) {
              final a = tester.getRect(find.byKey(ValueKey(keys[i]))), b = tester.getRect(find.byKey(ValueKey(keys[j])));
              expect(a.deflate(.5).overlaps(b.deflate(.5)), isFalse, reason: '${keys[i]} と ${keys[j]}');
            }
          }
          if (lang == 'en') _noJapanese(tester, '事業のタブ');
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('「分類」の札を押すと小窓が開き、10の分類から選べる。選ぶと札に名前が出て、外せる', (tester) async {
      final s = _midGame();
      final ctl = await _pump(tester, game: s);
      ctl.setTab('biz');
      await tester.pump();
      expect(find.descendant(of: find.byKey(const ValueKey('filter-cat')), matching: find.text('分類')), findsOneWidget);
      expect(tester.widget<PickChip>(find.byKey(const ValueKey('filter-cat'))).on, isFalse);
      await tester.tap(find.byKey(const ValueKey('filter-cat')));
      await tester.pump();
      expect(ctl.sheet, isNotNull);
      for (final cat in CATN.ja.keys) {
        final f = find.byKey(ValueKey('filter-$cat'));
        expect(f, findsOneWidget, reason: cat);
        expect(tester.getRect(f).height, greaterThanOrEqualTo(minTap));
        // 分類ごとの件数を添える
        expect(find.descendant(of: f, matching: find.text('${newBizList(s, filter: cat).length}件')), findsOneWidget, reason: cat);
      }
      await tester.tap(find.byKey(const ValueKey('filter-food')));
      await tester.pump();
      expect(ctl.sheet, isNull);
      expect(ctl.bizFilter, 'food');
      expect(tester.widget<PickChip>(find.byKey(const ValueKey('filter-cat'))).on, isTrue);
      expect(find.descendant(of: find.byKey(const ValueKey('filter-cat')), matching: find.text('分類：食')), findsOneWidget);
      expect(find.text('業種（${newBizList(s, filter: 'food').length}件）'), findsOneWidget);
      // 小窓から外す
      await tester.tap(find.byKey(const ValueKey('filter-cat')));
      await tester.pump();
      expect(tester.widget<ChoiceBtn>(find.byKey(const ValueKey('filter-food'))).on, isTrue);
      await tester.tap(find.text('分類を外す'));
      await tester.pump();
      expect(ctl.bizFilter, 'all');
      expect(ctl.sheet, isNull);
      expect(tester.takeException(), isNull);
    });
  });

  group('街のタブの整理', () {
    for (final lang in ['ja', 'en']) {
      testWidgets('上から 今月やること → 街の絵 → 会社の数字 → 社長の行動 → 宿敵 → 最近のできごと（$lang）', (tester) async {
        final s = _midGame();
        await _pump(tester, game: s, lang: lang);
        final order = [
          find.byKey(const ValueKey('todo')),
          find.byKey(const ValueKey('town-picture')),
          find.byKey(const ValueKey('town-company')),
          find.byKey(const ValueKey('town-pres')),
          find.byKey(const ValueKey('fold-rivals')),
          find.byKey(const ValueKey('fold-news')),
        ];
        var bottom = -1.0;
        for (final f in order) {
          expect(f, findsOneWidget);
          final r = tester.getRect(f);
          expect(r.top, greaterThanOrEqualTo(bottom - .01), reason: '$f の位置');
          bottom = r.bottom;
        }
        // 目標は会社の数字の欄の中
        expect(find.descendant(of: order[2], matching: find.textContaining(tx(s.goalText()), findRichText: true)), findsOneWidget);
        if (lang == 'en') _noJapanese(tester, '街のタブ');
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('「今月やること」は案内とひとことを合わせて3つまで。ひとことは2行までで、全部は小窓で読める', (tester) async {
      final s = _midGame();
      // ひとことが4つ以上出る盤面にする
      _giveRival(s, 25);
      s.holding = false;
      s.pres.age = 61;
      s.succ = null;
      expect(s.adviceAll().length, greaterThan(todoMax));
      startGuide(s);
      expect(currentGuide(s), isNotNull);
      final ctl = await _pump(tester, game: s);
      final todo = find.byKey(const ValueKey('todo'));
      expect(find.descendant(of: todo, matching: find.text('今月やること')), findsOneWidget);
      // 案内1つ＋ひとこと2つ
      expect(find.descendant(of: todo, matching: find.byType(GuideBar)), findsOneWidget);
      expect(find.descendant(of: todo, matching: find.text('次にやること')), findsOneWidget);
      final tips = find.descendant(of: todo, matching: find.byKey(const ValueKey('todo-tip')));
      expect(tips, findsNWidgets(todoMax - 1));
      for (final e in tips.evaluate()) {
        expect((e.widget as Text).maxLines, 2);
        expect(_lines(e.renderObject as RenderParagraph), lessThanOrEqualTo(2));
      }
      expect(tester.widget<Text>(tips.first).data, tx(s.advice().first));
      // 案内を閉じると、ひとこと3つ
      await tester.tap(find.byTooltip('案内を閉じる'));
      await tester.pump();
      expect(find.byType(GuideBar), findsNothing);
      expect(find.byKey(const ValueKey('todo-tip')), findsNWidgets(todoMax));
      // 全部は小窓で
      final all = find.byKey(const ValueKey('todo-all'));
      expect(tester.getRect(all).height, greaterThanOrEqualTo(minTap));
      await tester.tap(all);
      await tester.pump();
      expect(ctl.sheet, isNotNull);
      for (final x in s.adviceAll()) {
        expect(find.text(tx(x)), findsWidgets);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('案内もひとことも無ければ「今月やること」の欄は出さない', (tester) async {
      final s = _midGame();
      final ctl = await _pump(tester, game: s);
      expect(currentGuide(s), isNull);
      if (s.advice().isEmpty) {
        expect(find.byKey(const ValueKey('todo')), findsNothing);
      } else {
        expect(find.byKey(const ValueKey('todo')), findsOneWidget);
      }
      expect(todoCard(ctl) == null, s.advice().isEmpty);
    });

    testWidgets('宿敵と最近のできごとは、見出しを押すとたためる（セーブには入れない）', (tester) async {
      final s = _midGame();
      final ctl = await _pump(tester, game: s);
      final rivals = _rivals(s);
      expect(rivals.length, greaterThanOrEqualTo(2));
      final before = s.toJson().toString();
      for (final c in rivals) {
        expect(find.byKey(ValueKey('rival-row-${c.id}')), findsOneWidget);
      }
      expect(find.byType(NewsLine), findsNWidgets(8));
      for (final k in ['fold-rivals', 'fold-news']) {
        expect(tester.getRect(find.byKey(ValueKey(k))).height, greaterThanOrEqualTo(minTap), reason: k);
      }
      await tester.tap(find.byKey(const ValueKey('fold-rivals')));
      await tester.pump();
      expect(ctl.folded, {'rivals'});
      for (final c in rivals) {
        expect(find.byKey(ValueKey('rival-row-${c.id}')), findsNothing);
      }
      // たたんだ見出しには数を添える
      expect(find.descendant(of: find.byKey(const ValueKey('fold-rivals')), matching: find.text('${rivals.length}社')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('fold-rivals')), matching: find.byIcon(Icons.expand_more)), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('fold-news')));
      await tester.pump();
      expect(find.byType(NewsLine), findsNothing);
      expect(find.descendant(of: find.byKey(const ValueKey('fold-news')), matching: find.text('8件')), findsOneWidget);
      // 開き直す
      await tester.tap(find.byKey(const ValueKey('fold-rivals')));
      await tester.tap(find.byKey(const ValueKey('fold-news')));
      await tester.pump();
      expect(ctl.folded, isEmpty);
      expect(find.byKey(ValueKey('rival-row-${rivals.first.id}')), findsOneWidget);
      expect(find.byType(NewsLine), findsNWidgets(8));
      // 最近のできごとにも種類のアイコンが付く
      for (final e in find.byType(NewsLine).evaluate()) {
        expect((e.widget as NewsLine).icon, isNotNull);
      }
      expect(s.toJson().toString(), before, reason: '開閉は画面だけの状態');
      expect(tester.takeException(), isNull);
    });

    for (final lang in ['ja', 'en']) {
      testWidgets('宿敵は1人1行の要約で、押すと因縁と「裏の手」が開く（$lang）', (tester) async {
        final s = _midGame();
        _giveRival(s, 18);
        final ctl = await _pump(tester, game: s, lang: lang);
        final rivals = _rivals(s);
        final c = rivals.first;
        final row = find.byKey(ValueKey('rival-row-${c.id}'));
        expect(tester.getRect(row).height, greaterThanOrEqualTo(minTap));
        // 名前・型・時価総額・関係・あなたの株の持ち分
        expect(find.descendant(of: row, matching: find.text(nmL(c.name))), findsOneWidget);
        expect(find.descendant(of: row, matching: find.text(RTYPE[c.rival!.label ?? c.rival!.type]!)), findsOneWidget);
        final facts = find.descendant(of: row, matching: find.byType(RichText)).evaluate().map((e) => (e.widget as RichText).text.toPlainText()).join('\n');
        expect(facts, contains(yen(c.cap)));
        expect(facts, contains(tx(relWord(c.rel))));
        expect(facts, contains(tr('・あなたの株 {0}', ['18%'])));
        // たたんだ行には因縁も裏の手も出さない
        expect(find.text(tr('裏の手')), findsNothing);
        expect(find.textContaining(tr('因縁 '), findRichText: true), findsNothing);
        await tester.tap(row);
        await tester.pump();
        expect(ctl.openRival, c.id);
        final story = find.textContaining(tr('因縁 '), findRichText: true);
        expect(story, findsOneWidget);
        expect((tester.widget(story) as RichText).text.toPlainText(), contains(tx(s.storyStage(c.rival!))));
        expect(find.text(tr('裏の手')), findsOneWidget);
        // 開けるのは1つだけ
        final other = rivals[1];
        await tester.tap(find.byKey(ValueKey('rival-row-${other.id}')));
        await tester.pump();
        expect(ctl.openRival, other.id);
        expect(find.byKey(ValueKey('rival-row-${c.id}')), findsOneWidget);
        expect(find.text(tr('裏の手')), findsOneWidget);
        // 裏の手の小窓へ
        await tester.tap(find.text(tr('裏の手')));
        await tester.pump();
        expect(ctl.sheet, isNotNull);
        ctl.closeSheet();
        await tester.pump();
        // 名前の行を押すとたたむ
        final fold = find.byKey(ValueKey('rival-fold-${other.id}'));
        expect(tester.getRect(fold).height, greaterThanOrEqualTo(minTap));
        await tester.tap(fold);
        await tester.pump();
        expect(ctl.openRival, isNull);
        expect(find.text(tr('裏の手')), findsNothing);
        if (lang == 'en') _noJapanese(tester, '街のタブ');
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('月送りの報告', () {
    test('表の中身：現金・時価総額・売上・利益・順位の「前→今」と向き', () {
      final s = _midGame();
      final rk = rankNow(s);
      final rows = reportRows(s, ReportBase(s.cap * .9, s.cash * 1.2, null, s.rev, s.pre.abs() * 2 + 1, rk + 3));
      expect(rows.map((r) => r.id), ['cash', 'cap', 'rev', 'pre', 'rank']);
      final by = {for (final r in rows) r.id: r};
      expect(by['cash']!.dir, s.cash > 0 ? -1 : 1);
      expect(by['cap']!.dir, 1);
      expect(by['rev']!.dir, 0);
      expect(by['pre']!.dir, -1);
      // 順位は数が小さくなると「良くなった」
      expect(by['rank']!.dir, 1);
      expect(by['cap']!.before, yen(s.cap * .9));
      expect(by['cap']!.now, yen(s.cap));
      expect(by['rank']!.before, '${rk + 3}位');
      expect(by['rank']!.now, '$rk位');
      expect(reportRows(s, ReportBase(s.cap, s.cash, null, s.rev, s.pre, rk + 1)).last.dir, 1);
      expect(reportRows(s, ReportBase(s.cap, s.cash, null, s.rev, s.pre, rk - 1)).last.dir, -1);
      // 前の版の形（現金と時価総額だけ控えた）でも落ちない
      expect(reportRows(s, ReportBase(s.cap, s.cash)).map((r) => r.id), ['cash', 'cap']);
      expect(ReportBase.of(s).rank, rk);
    });

    test('ニュースの並び：big と bad が上、そのほかは下（それぞれの中は起きた順）', () {
      final n = [LogEntry('a'), LogEntry('b', 'bad'), LogEntry('c', 'good'), LogEntry('d', 'big'), LogEntry('e'), LogEntry('f', 'bad')];
      expect(sortNews(n).map((x) => x.m).join(), 'bdface');
      expect(sortNews([]), isEmpty);
    });

    test('ニュースの種類：時代の事件・宿敵・人・良い知らせ・悪い知らせ・社内', () {
      final s = _midGame();
      final r = _rivals(s).first;
      final p = s.staff.first;
      expect(newsKind(s, LogEntry(M('【{0}】{1}', ['バブル', '株と土地が上がり続けています']), 'big')), 'era');
      expect(newsKind(s, LogEntry(M('新しい業種「{0}」が生まれました。まだ大きな会社はいません', [I(s.inds.first.id)]), 'big')), 'era');
      expect(newsKind(s, LogEntry(M('{0}が、あなたの後を追って「{1}」に参入しました', [Nm(r.rival!.pres), I(s.inds.first.id)]), 'bad')), 'rival');
      expect(newsKind(s, LogEntry(M('{0}が、値上がりしたあなたの会社の株を半分売り抜けました', [Nm(r.name)]), 'good')), 'rival');
      expect(newsKind(s, LogEntry(M('{0}（{1}歳）が引退しました', [Nm('どこかの 誰か'), 70]))), 'person');
      expect(newsKind(s, LogEntry(M('{0}が勝手に「{1}」で値下げ合戦を始めました。野心が強い人のようです', [Nm(p.name), I(s.inds.first.id)]), 'bad')), 'person');
      expect(newsKind(s, LogEntry(M('社風が「{0}」に変わりました', [D('堅実')]), 'good')), 'good');
      expect(newsKind(s, LogEntry(M('投資家との上場の約束まで、あと1年です'), 'bad')), 'bad');
      expect(newsKind(s, LogEntry(M('社債の{0}を返しました', [Y(1e8)]))), 'inside');
      // どの種類にもアイコンがあり、互いに違う
      expect(newsIcons.keys.toSet(), {'era', 'rival', 'person', 'good', 'bad', 'inside'});
      expect(newsIcons.values.toSet().length, newsIcons.length);
      // 見るだけで、仕組みは動かさない
      final a = _midGame(), b = _midGame();
      newsKind(a, LogEntry(M('社債の{0}を返しました', [Y(1e8)])));
      expect(a.toJson().toString(), b.toJson().toString());
      expect(a.rnd(), b.rnd());
    });

    for (final lang in ['ja', 'en']) {
      for (final w in [390.0, 320.0]) {
        testWidgets('小窓の上に「前月→今月」の表、ニュースは種類のアイコン付きで大事なものが上（$lang・幅${w.round()}）', (tester) async {
          final s = _midGame();
          final ctl = await _pump(tester, game: s, lang: lang, size: Size(w, 3000));
          final r = _rivals(s).first;
          final rk = rankNow(s);
          final news = [
            LogEntry(M('社債の{0}を返しました', [Y(1e8)])),
            LogEntry(M('社風が「{0}」に変わりました', [D('堅実')]), 'good'),
            LogEntry(M('{0}が、あなたの後を追って「{1}」に参入しました', [Nm(r.rival!.pres), I(s.inds.first.id)]), 'bad'),
            LogEntry(M('{0}（{1}歳）が引退しました', [Nm(s.staff.first.name), 70])),
            LogEntry(M('新しい業種「{0}」が生まれました。まだ大きな会社はいません', [I(s.inds.first.id)]), 'big'),
          ];
          showReport(ctl, news, ReportBase(s.cap * .9, s.cash * 1.2, null, s.rev * .8, s.pre.abs() * 2 + 1, rk + 3));
          await tester.pump();
          final table = find.byKey(const ValueKey('report-table'));
          expect(table, findsOneWidget);
          // 表は見出しのすぐ下、発言やニュースより上
          expect(tester.getRect(table).bottom, lessThanOrEqualTo(tester.getRect(_inSheet(find.byType(NewsLine)).first).top));
          expect(_inSheet(find.byType(Say)), findsWidgets);
          expect(tester.getRect(table).bottom, lessThanOrEqualTo(tester.getRect(_inSheet(find.byType(Say)).first).top + .01));
          expect(find.descendant(of: table, matching: find.text(tr('前月'))), findsOneWidget);
          expect(find.descendant(of: table, matching: find.text(tr('今月'))), findsOneWidget);
          const want = {'cash': -1, 'cap': 1, 'rev': 1, 'pre': -1, 'rank': 1};
          for (final e in want.entries) {
            final row = find.byKey(ValueKey('report-${e.key}'));
            expect(row, findsOneWidget, reason: e.key);
            final icon = tester.widget<Icon>(find.byKey(ValueKey('report-dir-${e.key}')));
            expect(icon.icon, e.value > 0 ? Icons.arrow_upward : Icons.arrow_downward, reason: e.key);
            expect(icon.color, e.value > 0 ? Pal.up : Pal.down, reason: e.key);
            // 今の値は緑か赤
            final now = find.descendant(of: row, matching: find.byWidgetPredicate((x) => x is Text && x.style?.fontWeight == FontWeight.w700));
            expect(tester.widget<Text>(now).style!.color, e.value > 0 ? Pal.up : Pal.down, reason: e.key);
            // 行は小窓の幅に収まる
            expect(tester.getRect(row).right, lessThanOrEqualTo(w - 12));
          }
          expect(find.descendant(of: find.byKey(const ValueKey('report-cap')), matching: find.text(yen(s.cap))), findsOneWidget);
          expect(find.descendant(of: find.byKey(const ValueKey('report-rank')), matching: find.text(tr('{0}位', [rk]))), findsOneWidget);
          // ニュース：big と bad が上
          final lines = _inSheet(find.byType(NewsLine)).evaluate().map((e) => e.widget as NewsLine).toList();
          expect(lines.map((l) => l.kind), ['bad', 'big', '', 'good', '']);
          expect(lines.map((l) => l.icon), [Icons.local_fire_department, Icons.public, Icons.business, Icons.thumb_up_alt_outlined, Icons.person]);
          for (final l in lines) {
            expect(find.descendant(of: find.byWidget(l), matching: find.byIcon(l.icon!)), findsOneWidget);
          }
          if (lang == 'en') _noJapanese(tester, '報告の小窓');
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('まとめて進めたときの見出しは「進める前」と「今」。変わらない値は横棒', (tester) async {
      final s = _midGame();
      final ctl = await _pump(tester, game: s);
      showReport(ctl, const [], ReportBase(s.cap, s.cash, '1990年 1月から', s.rev, s.pre, rankNow(s)));
      await tester.pump();
      final table = find.byKey(const ValueKey('report-table'));
      expect(find.descendant(of: table, matching: find.text('進める前')), findsOneWidget);
      expect(find.descendant(of: table, matching: find.text('今')), findsOneWidget);
      for (final k in ['cash', 'cap', 'rev', 'pre', 'rank']) {
        final icon = tester.widget<Icon>(find.byKey(ValueKey('report-dir-$k')));
        expect(icon.icon, Icons.remove, reason: k);
        expect(icon.color, Pal.mute);
      }
      expect(_inSheet(find.byType(NewsLine)), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('「次の月へ」で出る報告にも表が付き、前月の値が入る', (tester) async {
      final s = _midGame();
      final ctl = await _pump(tester, game: s);
      // 経営会議の月（必ず報告が出る）まで進める
      while (s.q % 3 != 0) {
        s.nextQuarter();
        resolveEvents(s);
      }
      final cash0 = s.cash, cap0 = s.cap;
      doNext(ctl);
      await tester.pump();
      expect(ctl.sheet, isNotNull);
      expect(find.descendant(of: find.byKey(const ValueKey('report-cash')), matching: find.text(yen(cash0))), findsWidgets);
      expect(find.descendant(of: find.byKey(const ValueKey('report-cap')), matching: find.text(yen(cap0))), findsWidgets);
      expect(find.byKey(const ValueKey('report-rank')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('人のタブ', () {
    for (final lang in ['ja', 'en']) {
      testWidgets('部下が4人以上なら1人1行にたたみ、押すと詳しいカードが開く（$lang）', (tester) async {
        final s = _midGame();
        expect(s.staff.length, greaterThanOrEqualTo(staffFoldMin));
        final low = s.staff[1]..loy = 30;
        for (final p in s.staff) {
          if (p != low) p.loy = 80;
        }
        final partner = s.staff[2]
          ..partner = true
          ..stake = 5;
        final ctl = await _pump(tester, game: s, lang: lang);
        ctl.setTab('people');
        await tester.pump();
        for (final p in s.staff) {
          final row = find.byKey(ValueKey('staff-row-${p.id}'));
          expect(row, findsOneWidget);
          expect(tester.getRect(row).height, greaterThanOrEqualTo(minTap));
          // 名前と年齢・担当・いちばん高い能力
          expect(find.descendant(of: row, matching: find.text(tr('{0}（{1}歳）', [nmL(p.name), p.age]))), findsOneWidget);
          final top = topAbility(s, p);
          final line = find.descendant(of: row, matching: find.byType(RichText)).evaluate().map((e) => (e.widget as RichText).text.toPlainText()).join('\n');
          expect(line, contains('${ABN[top]} ${s.showAb(p, top)}'));
          final job = s.biz.where((b) => b.mgr == p.id).firstOrNull;
          expect(line, contains(job != null ? tr('{0}の責任者', [indm[job.ind]!.name]) : tr('担当なし')));
          // 忠誠の注意の印は、下がっている人だけ
          expect(find.byKey(ValueKey('loy-warn-${p.id}')), p == low ? findsOneWidget : findsNothing);
          // 相棒の札
          expect(find.descendant(of: row, matching: find.text(tr('相棒@@tag'))), p.partner ? findsOneWidget : findsNothing);
        }
        expect(s.staff.where((p) => p.partner), contains(partner));
        // たたんでいるあいだは、解雇のボタンは出ない
        expect(find.text(tr('解雇')), findsNothing);
        final p = s.staff.first;
        await tester.tap(find.byKey(ValueKey('staff-row-${p.id}')));
        await tester.pump();
        expect(ctl.openStaff, p.id);
        expect(find.byKey(ValueKey('staff-row-${p.id}')), findsNothing);
        expect(find.text(tr(p.partner ? '相棒と別れる' : '解雇')), findsOneWidget);
        // 開けるのは1つだけ。名前の行でたたむ
        await tester.tap(find.byKey(ValueKey('staff-row-${low.id}')));
        await tester.pump();
        expect(ctl.openStaff, low.id);
        expect(find.byKey(ValueKey('staff-row-${p.id}')), findsOneWidget);
        expect(find.text(tr('忠誠が下がっています')), findsOneWidget);
        final fold = find.byKey(ValueKey('staff-fold-${low.id}'));
        expect(tester.getRect(fold).height, greaterThanOrEqualTo(minTap));
        await tester.tap(fold);
        await tester.pump();
        expect(ctl.openStaff, isNull);
        if (lang == 'en') _noJapanese(tester, '人のタブ');
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('部下が3人までなら、今までどおりカードのまま', (tester) async {
      final s = _midGame();
      for (final b in s.biz) {
        b.mgr = null;
      }
      s.staff.removeRange(staffFoldMin - 1, s.staff.length);
      final ctl = await _pump(tester, game: s);
      ctl.setTab('people');
      await tester.pump();
      for (final p in s.staff) {
        expect(find.byKey(ValueKey('staff-row-${p.id}')), findsNothing);
      }
      expect(find.text('解雇'), findsNWidgets(s.staff.where((p) => !p.partner).length));
      expect(tester.takeException(), isNull);
    });

    test('いちばん高い能力は、幅でしか分からないものは幅の真ん中で比べる', () {
      final s = _midGame();
      final p = s.staff.first
        ..w = 0
        ..ab = {'tou': 40, 'kai': 77, 'ei': 55, 'zai': 60};
      expect(topAbility(s, p), 'kai');
      p.ab = {'tou': 60, 'kai': 60, 'ei': 60, 'zai': 60};
      expect(topAbility(s, p), abKeys.first);
    });

    testWidgets('能力は数字に加えて細い棒でも見せる。幅でしか分からないものは薄い帯', (tester) async {
      final s = _midGame();
      for (final b in s.biz) {
        b.mgr = null;
      }
      s.staff.removeRange(1, s.staff.length);
      // 1人目は値が分かっている（幅なし）
      final p = s.staff.first
        ..w = 0
        ..ab = {'tou': 99, 'kai': 50, 'ei': 0, 'zai': 25};
      s.cands.removeRange(1, s.cands.length);
      final c = s.cands.first
        ..w = 12
        ..tenure = 0;
      final ctl = await _pump(tester, game: s);
      ctl.setTab('people');
      await tester.pump();
      // 社長4つ＋部下4つ＋候補4つ
      expect(find.byType(AbBar), findsNWidgets(12));
      final bars = find.byType(AbBar).evaluate().map((e) => e.widget as AbBar).toList();
      final pres = bars.sublist(0, 4), staff = bars.sublist(4, 8), cand = bars.sublist(8);
      expect([for (final b in pres) b.lo], [for (final k in abKeys) s.pres.ab[k]]);
      expect([for (final b in staff) (b.lo, b.hi)], [for (final k in abKeys) (p.ab[k], p.ab[k])]);
      expect([for (final b in cand) (b.lo, b.hi)], [for (final k in abKeys) (s.rangeOf(c, k)[0], s.rangeOf(c, k)[1])]);
      expect(cand.every((b) => b.hi > b.lo), isTrue);
      // 棒の長さは値に比例する（99 でいっぱい、0 で空）
      final staffBars = find.byType(AbBar).evaluate().skip(4).take(4).toList();
      for (var i = 0; i < 4; i++) {
        final bar = find.byWidget(staffBars[i].widget);
        final full = tester.getSize(bar);
        expect(full.height, AbBar.h);
        final fill = tester.getSize(find.descendant(of: bar, matching: find.byKey(const ValueKey('ab-fill'))));
        expect(fill.width, closeTo(full.width * p.ab[abKeys[i]]! / 99, .01));
        expect(find.descendant(of: bar, matching: find.byKey(const ValueKey('ab-band'))), findsNothing);
      }
      // 候補は「58〜70」のような幅を薄い帯で
      final candBars = find.byType(AbBar).evaluate().skip(8).toList();
      for (var i = 0; i < 4; i++) {
        final bar = find.byWidget(candBars[i].widget);
        final full = tester.getSize(bar);
        final r = s.rangeOf(c, abKeys[i]);
        final band = find.descendant(of: bar, matching: find.byKey(const ValueKey('ab-band')));
        expect(band, findsOneWidget);
        expect(tester.getSize(band).width, closeTo(full.width * (r[1] - r[0]) / 99, .01));
        expect(tester.getTopLeft(band).dx - tester.getTopLeft(bar).dx, closeTo(full.width * r[0] / 99, .01));
        // 数字もそのまま出る
        expect(find.text(s.showAb(c, abKeys[i])), findsWidgets);
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('株のタブ', () {
    test('宿敵の持ち分が、いちばん近い節目まであと何%か', () {
      final s = _midGame();
      expect(s.listed, isTrue);
      _giveRival(s, 18);
      expect(rivalGapText(s), '宿敵の持ち分は18%。33.4%まであと15.4%');
      s.sh.riv[_rivals(s).first.id] = 33.4;
      expect(rivalGapText(s), '宿敵の持ち分は33.4%。50%まであと16.6%');
      s.sh.riv[_rivals(s).first.id] = 51;
      expect(rivalGapText(s), '宿敵の持ち分は51%。66.7%まであと15.7%');
      s.sh.riv[_rivals(s).first.id] = 70;
      expect(rivalGapText(s), '宿敵の持ち分は70%。66.7%を超えています');
      s.sh.riv.clear();
      expect(rivalGapText(s), '宿敵の持ち分は0%。33.4%まであと33.4%');
      // いちばん多く握っている1社で数える
      s.sh.riv[_rivals(s)[0].id] = 12;
      s.sh.riv[_rivals(s)[1].id] = 20.5;
      expect(rivalGapText(s), '宿敵の持ち分は20.5%。33.4%まであと12.9%');
      L.lang = 'en';
      expect(rivalGapText(s), 'Rivals hold 20.5%: 12.9% short of 33.4%');
      L.lang = 'ja';
      // 上場前は出さない
      expect(rivalGapText(_newGame()), isNull);
    });

    for (final lang in ['ja', 'en']) {
      for (final w in [390.0, 320.0]) {
        testWidgets('株主の棒に 33.4%・50%・66.7% の線と字の印が重なり、「あと何%」が1行で出る（$lang・幅${w.round()}）', (tester) async {
          final s = _midGame();
          _giveRival(s, 18);
          final ctl = await _pump(tester, game: s, lang: lang, size: Size(w, 6000));
          ctl.setTab('stock');
          await tester.pump();
          final bar = find.descendant(of: find.byType(MarkBar), matching: find.byType(Bar));
          expect(bar, findsOneWidget);
          final br = tester.getRect(bar);
          for (final m in MarkBar.marks) {
            final line = tester.getRect(find.byKey(ValueKey('mark-$m')));
            expect(line.center.dx, closeTo(br.left + br.width * m / 100, .6), reason: '$m の線の位置');
            // 線は棒をまたぐ
            expect(line.top, lessThan(br.top));
            expect(line.bottom, greaterThan(br.bottom));
            final label = find.byKey(ValueKey('mark-label-$m'));
            expect(tester.widget<Text>(label).data, m == 50 ? '50%' : '$m%');
            expect(tester.getRect(label).center.dx, closeTo(line.center.dx, .6));
            expect(tester.getRect(label).top, greaterThanOrEqualTo(br.bottom));
          }
          // 字の印どうしは重ならない
          final l1 = tester.getRect(find.byKey(const ValueKey('mark-label-33.4')));
          final l2 = tester.getRect(find.byKey(const ValueKey('mark-label-50.0')));
          final l3 = tester.getRect(find.byKey(const ValueKey('mark-label-66.7')));
          expect(l1.right, lessThanOrEqualTo(l2.left + .01));
          expect(l2.right, lessThanOrEqualTo(l3.left + .01));
          final gap = find.byKey(const ValueKey('rival-gap'));
          expect(tester.widget<Text>(gap).data, rivalGapText(s));
          if (lang == 'ja') expect(tester.widget<Text>(gap).data, '宿敵の持ち分は18%。33.4%まであと15.4%');
          if (lang == 'en') _noJapanese(tester, '株のタブ');
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('節目まで5%を切ると赤で知らせる。上場前は「あと何%」の行を出さない（線は出す）', (tester) async {
      final s = _midGame();
      _giveRival(s, 30);
      final ctl = await _pump(tester, game: s);
      ctl.setTab('stock');
      await tester.pump();
      expect(tester.widget<Text>(find.byKey(const ValueKey('rival-gap'))).style!.color, Pal.down);
      s.sh.riv[_rivals(s).first.id] = 10;
      ctl.render();
      await tester.pump();
      expect(tester.widget<Text>(find.byKey(const ValueKey('rival-gap'))).style!.color, Pal.ink);
      ctl.game = _newGame();
      ctl.render();
      await tester.pump();
      expect(ctl.game!.listed, isFalse);
      expect(find.byKey(const ValueKey('rival-gap')), findsNothing);
      expect(find.byType(MarkBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('英語の長いボタン', () {
    for (final w in [390.0, 320.0]) {
      testWidgets('6つのタブのボタンは、英語でも1行に収まる（幅${w.round()}）', (tester) async {
        await _loadFonts();
        final s = _midGame();
        _giveRival(s, 18);
        s.holding = false;
        // 値下げ合戦を仕掛けられる事業を開いておく
        final ctl = await _pump(tester, game: s, lang: 'en', size: Size(w, 30000));
        final bad = <String>[];
        var seen = 0;
        for (final t in MainScreen.tabs) {
          ctl.openBiz = ctl.moreBiz = s.biz.first.id;
          ctl.openStaff = s.staff.first.id;
          ctl.openRival = _rivals(s).first.id;
          ctl.setTab(t.$1);
          await tester.pump();
          for (final e in find.byType(Btn).evaluate()) {
            final b = e.widget as Btn;
            final rect = tester.getRect(find.byWidget(b));
            expect(rect.height, greaterThanOrEqualTo(minTap), reason: '${t.$1}: ${tx(b.label)}');
            expect(rect.right, lessThanOrEqualTo(w + .01), reason: '${t.$1}: ${tx(b.label)} が右にはみ出している');
            for (final te in find.descendant(of: find.byWidget(b), matching: find.byType(RichText)).evaluate()) {
              seen++;
              final n = _lines(te.renderObject as RenderParagraph);
              if (n > 1) bad.add('${t.$1}: "${tx(b.label)}" が$n行');
            }
          }
        }
        expect(seen, greaterThan(60));
        expect(bad, isEmpty, reason: bad.take(10).join('\n'));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('未上場の「株」のボタンも英語で1行（幅320）。「持株会社にする」は字の幅をそのまま取る', (tester) async {
      await _loadFonts();
      final s = _newGame();
      final ctl = await _pump(tester, game: s, lang: 'en', size: const Size(320, 12000));
      ctl.setTab('stock');
      await tester.pump();
      final holding = find.widgetWithText(Btn, 'Form holding co.');
      expect(holding, findsOneWidget);
      for (final e in find.byType(Btn).evaluate()) {
        for (final te in find.descendant(of: find.byWidget(e.widget), matching: find.byType(RichText)).evaluate()) {
          expect(_lines(te.renderObject as RenderParagraph), 1, reason: tx((e.widget as Btn).label));
        }
      }
      // 日本語でも1行（半分の幅に押し込まれない）
      ctl.setLang('ja');
      await tester.pump();
      final ja = find.descendant(of: find.widgetWithText(Btn, '持株会社にする'), matching: find.text('持株会社にする'));
      expect(_lines(tester.renderObject<RenderParagraph>(ja)), 1);
      expect(tester.takeException(), isNull);
    });
  });

  group('画面の書き出し（目で見る用）', () {
    for (final lang in ['ja', 'en']) {
      for (final w in [390.0, 320.0]) {
        final tag = '${lang}_${w.round()}';
        testWidgets('街・事業・人・株・報告（$tag）', (tester) async {
          if (_out == null) return;
          await _loadFonts();
          final s = _midGame();
          _giveRival(s, 18);
          s.staff[1].loy = 30;
          s.staff[2]
            ..partner = true
            ..stake = 5;
          startGuide(s);
          final ctl = await _pump(tester, game: s, lang: lang, size: Size(w, 1900));
          ctl.openRival = _rivals(s).first.id;
          ctl.render();
          await tester.pump();
          await _shot(tester, 'b_town_$tag');
          ctl.setTab('biz');
          ctl.openBiz = ctl.moreBiz = null;
          await tester.pump();
          await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
          await tester.pump();
          await _shot(tester, 'b_biz_$tag');
          openCatPick(ctl);
          await tester.pump();
          await _shot(tester, 'b_cat_$tag');
          ctl.bizFilter = 'food';
          ctl.closeSheet();
          await tester.pump();
          await _shot(tester, 'b_biz_cat_$tag');
          ctl.setTab('people');
          ctl.openStaff = s.staff.first.id;
          await tester.pump();
          await _shot(tester, 'b_people_$tag');
          await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
          await tester.pump();
          await _shot(tester, 'b_people2_$tag');
          ctl.setTab('stock');
          await tester.pump();
          await _shot(tester, 'b_stock_$tag');
          final r = _rivals(s).first;
          showReport(
              ctl,
              [
                LogEntry(M('社債の{0}を返しました', [Y(1e8)])),
                LogEntry(M('社風が「{0}」に変わりました', [D('堅実')]), 'good'),
                LogEntry(M('{0}が、あなたの後を追って「{1}」に参入しました', [Nm(r.rival!.pres), I(s.inds.first.id)]), 'bad'),
                LogEntry(M('{0}（{1}歳）が引退しました', [Nm(s.staff.first.name), 70])),
                LogEntry(M('新しい業種「{0}」が生まれました。まだ大きな会社はいません', [I(s.inds.first.id)]), 'big'),
                LogEntry(M('投資家との上場の約束まで、あと1年です'), 'bad'),
              ],
              ReportBase(s.cap * .93, s.cash * 1.2, null, s.rev * .96, s.pre * 1.1, rankNow(s) + 2));
          await tester.pump();
          await _shot(tester, 'b_report_$tag');
          tester.takeException();
        });
      }
    }
  });
}
