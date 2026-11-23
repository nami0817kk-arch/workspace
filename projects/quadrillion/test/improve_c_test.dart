import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';
import 'package:quadrillion/ui/app.dart';
import 'package:quadrillion/ui/controller.dart';
import 'package:quadrillion/ui/glossary.dart';
import 'package:quadrillion/ui/sheets.dart';
import 'package:quadrillion/ui/tabs.dart';
import 'package:quadrillion/ui/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/bot.dart';

/// 改善C（1.0.0+15）: 事業カードのボタンの組・用語の説明・図鑑の3つの切り替え（業種・実績）・
/// 何か起きるまで進める・決算の内訳の横棒とランキング・幅320の一覧

/// 画面の書き出し（目で見る用）は QUAD_SHOTS に書き出し先を渡したときだけ動く（画像はコミットしない）
final _out = Platform.environment['QUAD_SHOTS'];

/// ひらがな・カタカナ・漢字・全角の記号
final _cjk = RegExp('[　-ヿ㐀-鿿＀-￯]');

final _shotKey = GlobalKey();

/// 何回引いたかを数える乱数
class CountingRandom implements math.Random {
  final math.Random r;
  int n = 0;
  CountingRandom(this.r);
  @override
  double nextDouble() {
    n++;
    return r.nextDouble();
  }

  @override
  int nextInt(int max) => (nextDouble() * max).floor();
  @override
  bool nextBool() => nextDouble() < .5;
}

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
Game _midGame([int seed = 5]) {
  if (_cached == null) {
    final s = Game.newGame(SetupConfig(mode: 'world', year: 1980, traits: ['charm', 'gambler']), rng: ParkMiller(2024));
    for (var i = 0; i < 150; i++) {
      botMonth(s);
    }
    resolveEvents(s);
    s.calcAll();
    _cached = s;
  }
  return Game.fromJson(_cached!.toJson(), rng: ParkMiller(seed))..calcAll();
}

/// 始めたばかりのゲーム（事業なし）
Game _newGame([int year = 2000]) => Game.newGame(SetupConfig(mode: 'endless', year: year, traits: ['charm', 'gambler']), rng: ParkMiller(2024));

/// 本物のフォントで描く
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

Finder _key(String k) => find.byKey(ValueKey(k));

/// 画面の一覧を上から下まで少しずつ送りながら [f] を呼ぶ（一覧は見えている所しか組まれない）
Future<void> _sweep(WidgetTester tester, Future<void> Function() f) async {
  final sc = find.byType(Scrollable).first;
  // 前の画面の位置が残っていることがあるので、いちばん上から始める
  tester.state<ScrollableState>(sc).position.jumpTo(0);
  await tester.pump();
  for (var i = 0; i < 200; i++) {
    await f();
    final pos = tester.state<ScrollableState>(sc).position;
    if (pos.pixels >= pos.maxScrollExtent - .5) break;
    // 幅320の画面は見えている高さが350ほどなので、それより小さく刻む
    pos.jumpTo(math.min(pos.maxScrollExtent, pos.pixels + 250));
    await tester.pump();
  }
}

/// 一覧を [finder] が見つかるまで送る
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  // 下へしか送らないので、いちばん上から探す
  tester.state<ScrollableState>(find.byType(Scrollable).first).position.jumpTo(0);
  await tester.pump();
  await tester.scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable).first, maxScrolls: 200);
  await tester.pump();
}

void main() {
  tearDown(() => L.lang = 'ja');

  group('事業カードのボタンの組', () {
    for (final lang in ['ja', 'en']) {
      testWidgets('「伸ばす」「戦う」「形を変える」に分かれ、売るはいちばん下に離れる（$lang）', (tester) async {
        final s = _midGame()..ap = 3;
        final b = (s.biz.toList()..ssort((a, b) => b.rev.compareTo(a.rev))).first;
        final ctl = await _pump(tester, game: s, lang: lang);
        ctl.openBiz = b.id;
        ctl.setTab('biz');
        await tester.pump();
        final grow = _key('grp-grow-${b.id}'), fight = _key('grp-fight-${b.id}'), shape = _key('grp-shape-${b.id}'), sell = _key('biz-sell-${b.id}');
        for (final f in [grow, fight, shape, sell]) {
          expect(f, findsOneWidget);
        }
        // 小見出し
        for (final h in ['伸ばす', '戦う@@grp', '形を変える']) {
          expect(find.text(tr(h)), findsOneWidget, reason: h);
        }
        bool inside(Finder grp, String label) => find.descendant(of: grp, matching: find.textContaining(label)).evaluate().isNotEmpty;
        // 伸ばす：店・工場／商品／現場の人／広告／海外
        expect(inside(grow, tr('{0}を増やす', [s.uw(b)])), isTrue);
        expect(inside(grow, tr('商品を作る')), isTrue);
        if (b.model != 'fc') expect(inside(grow, tr('現場の人を増やす')), isTrue);
        expect(inside(grow, tr('広告 {0}', [yen(s.invBase(b) * .25)])), isTrue);
        expect(inside(grow, tr('海外に出る')), isTrue);
        expect(inside(grow, tr('分社・独立')), isFalse);
        // 戦う：値付け（＋競争相手がいれば値下げ合戦・業界団体）
        expect(find.descendant(of: fight, matching: find.byType(Pick<String>)), findsOneWidget);
        expect(inside(fight, tr('値付け')), isTrue);
        if (s.competitors(b).isNotEmpty && b.attack <= 0) expect(find.descendant(of: fight, matching: find.byType(Btn)), findsWidgets);
        // 形を変える：分社・独立（＋稼ぎ方・業態転換）
        expect(inside(shape, tr('分社・独立')), isTrue);
        if (s.modelsFor(b.ind).length > 1) expect(inside(shape, tr('稼ぎ方を変える')), isTrue);
        if (s.pivotTargets(b).isNotEmpty) expect(inside(shape, tr('業態を変える')), isTrue);
        expect(find.descendant(of: shape, matching: find.textContaining(tr('売る（約{0}）', [yen(s.sellValue(b))]))), findsNothing);
        // 売るは線で区切って、組の下
        expect(find.descendant(of: sell, matching: find.byType(Btn)), findsOneWidget);
        expect(tester.getTopLeft(grow).dy, lessThan(tester.getTopLeft(fight).dy));
        expect(tester.getTopLeft(fight).dy, lessThan(tester.getTopLeft(shape).dy));
        expect(tester.getTopLeft(sell).dy, greaterThanOrEqualTo(tester.getBottomLeft(shape).dy));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('組の中のボタンは今までどおり動く（売るは確認が出る）', (tester) async {
      final s = _midGame()..ap = 3;
      final b = (s.biz.toList()..ssort((a, b) => b.rev.compareTo(a.rev))).first;
      final ctl = await _pump(tester, game: s);
      ctl.openBiz = b.id;
      ctl.setTab('biz');
      await tester.pump();
      final sellBtn = find.descendant(of: _key('biz-sell-${b.id}'), matching: find.byType(Btn));
      await tester.ensureVisible(sellBtn);
      await tester.pump();
      await tester.tap(sellBtn);
      await tester.pump();
      expect(find.text('この操作は取り消せません。本当によいですか？'), findsOneWidget);
      expect(s.biz.contains(b), isTrue);
    });
  });

  group('用語の説明', () {
    test('用語は全部、日本語と英語の名前と説明がある', () {
      expect(glossary.keys, containsAll(['ap', 'share', 'crew', 'upkeep', 'early', 'scale', 'model', 'own', 'cap', 'synergy']));
      for (final e in glossary.entries) {
        for (final k in [e.value.$1, e.value.$2]) {
          final en = enText(k);
          expect(en, isNotNull, reason: '${e.key}: $k');
          expect(_cjk.hasMatch(en!), isFalse, reason: en);
          L.lang = 'ja';
          expect(_cjk.hasMatch(tr(k)), isTrue);
          expect(tr(k).contains('@@'), isFalse);
          L.lang = 'en';
          expect(tr(k), en);
          L.lang = 'ja';
        }
        // 説明は2〜3行に収まる長さ
        expect(e.value.$2.length, inInclusiveRange(30, 110), reason: e.key);
      }
    });

    for (final lang in ['ja', 'en']) {
      testWidgets('「i」を押すと説明の小窓が開く（$lang）', (tester) async {
        final s = _midGame()..ap = 3;
        final b = (s.biz.toList()..ssort((a, b) => b.rev.compareTo(a.rev))).first;
        final ctl = await _pump(tester, game: s, lang: lang);
        ctl.openBiz = b.id;
        ctl.setTab('biz');
        await tester.pump();
        expect(_key('info-share'), findsWidgets);
        await tester.tap(_key('info-share').first);
        await tester.pump();
        expect(find.text(tr('用語の説明')), findsOneWidget);
        expect(_key('term-share'), findsOneWidget);
        expect(find.descendant(of: _key('term-share'), matching: find.text(tr(glossary['share']!.$1))), findsOneWidget);
        expect(find.descendant(of: _key('term-share'), matching: find.text(tr(glossary['share']!.$2))), findsOneWidget);
        if (lang == 'en') _noJapanese(tester, '用語の小窓');
        await tester.tap(find.text(tr('閉じる')));
        await tester.pump();
        expect(ctl.sheet, isNull);
        // いくつかまとめて出すもの（現場の力と維持費）
        if (b.model != 'fc') {
          await tester.ensureVisible(find.byWidgetPredicate((w) => w is Info && w.terms.contains('upkeep')).first);
          await tester.pump();
          await tester.tap(find.byWidgetPredicate((w) => w is Info && w.terms.contains('upkeep')).first);
          await tester.pump();
          expect(_key('term-crew'), findsOneWidget);
          expect(_key('term-upkeep'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('どのタブの「i」も、押せる範囲が 44pt 四方以上（幅390・320）', (tester) async {
      for (final size in const [Size(390, 844), Size(320, 568)]) {
        for (final lang in ['ja', 'en']) {
          final s = _midGame()..ap = 3;
          final ctl = await _pump(tester, game: s, lang: lang, size: size);
          ctl.openBiz = s.biz.first.id;
          final seen = <String>{};
          for (final t in ['town', 'biz', 'stock', 'num', 'zukan']) {
            ctl.setTab(t);
            await tester.pump();
            await _sweep(tester, () async {
              for (final e in find.byType(Info).evaluate()) {
                final w = e.widget as Info;
                final r = tester.getRect(find.byWidget(w));
                expect(r.width, greaterThanOrEqualTo(minTap - .01), reason: '$t ${w.terms}');
                expect(r.height, greaterThanOrEqualTo(minTap - .01), reason: '$t ${w.terms}');
                seen.addAll(w.terms);
              }
            });
            expect(tester.takeException(), isNull, reason: '$t $lang $size');
          }
          // 辞書の用語は、どれも画面のどこかに「i」がある（先行者は、先行者の事業があるときだけ）
          expect(seen, containsAll(glossary.keys.where((k) => k != 'early')), reason: '$lang $size');
        }
      }
    });
  });

  group('図鑑', () {
    testWidgets('「シナジー」「業種」「実績」を切り替えられる', (tester) async {
      final s = _midGame();
      final ctl = await _pump(tester, game: s);
      ctl.setTab('zukan');
      await tester.pump();
      for (final v in ['syn', 'ind', 'ach']) {
        expect(_key('zukan-$v'), findsOneWidget);
        expect(tester.getSize(_key('zukan-$v')).height, greaterThanOrEqualTo(minTap));
      }
      // はじめはシナジー：進み具合の棒と数
      expect(find.textContaining('シナジー図鑑'), findsOneWidget);
      expect(_key('syn-progress'), findsOneWidget);
      expect(find.descendant(of: _key('syn-progress'), matching: find.text('${s.found.length} / ${s.syns.length}')), findsOneWidget);
      await tester.tap(_key('zukan-ind'));
      await tester.pump();
      expect(ctl.zukanView, 'ind');
      expect(_key('ind-progress'), findsOneWidget);
      expect(find.textContaining('シナジー図鑑'), findsNothing);
      final done = s.inds.where((i) => s.handled(i.id)).length;
      expect(done, greaterThan(0));
      expect(find.descendant(of: _key('ind-progress'), matching: find.text('$done / ${s.inds.length}')), findsOneWidget);
      await tester.tap(_key('zukan-ach'));
      await tester.pump();
      expect(_key('ach-progress'), findsOneWidget);
      expect(find.descendant(of: _key('ach-progress'), matching: find.text('${s.ach.length} / ${ACHS.length}')), findsOneWidget);
      await tester.tap(_key('zukan-syn'));
      await tester.pump();
      expect(find.textContaining('シナジー図鑑'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('業種の見え方：手がけた・まだ・未来（種探しで知ったものは名前が出る）', () {
      final s = _midGame();
      expect(s.inds.length, 200);
      final y = s.yr();
      final mine = indm[s.biz.first.ind]!;
      expect(indLook(s, mine), 'done');
      final other = s.liveInds().firstWhere((i) => !s.handled(i.id));
      expect(indLook(s, other), 'seen');
      final fut = s.inds.where((i) => i.b > y && s.seen[i.id] == null).toList();
      expect(fut, isNotEmpty);
      expect(indLook(s, fut.first), 'future');
      s.seen[fut.first.id] = 1;
      expect(indLook(s, fut.first), 'soon');
      // 手放しても、手がけたことは残る
      s.noteInds();
      final b = s.biz.first;
      s.biz.remove(b);
      expect(s.handled(b.ind), isTrue);
      expect(indLook(s, mine), 'done');
    });

    testWidgets('業種の一覧：手がけた業種は中身、まだの業種は名前と「？」、未来の業種は「？？？」', (tester) async {
      final s = _midGame();
      final ctl = await _pump(tester, game: s);
      ctl.zukanView = 'ind';
      ctl.setTab('zukan');
      await tester.pump();
      final y = s.yr();
      final mine = indm[s.biz.first.ind]!;
      await _scrollTo(tester, _key('ind-done-${mine.id}'));
      final row = _key('ind-done-${mine.id}');
      expect(find.descendant(of: row, matching: find.text(mine.name)), findsOneWidget);
      expect(find.descendant(of: row, matching: find.text('${mine.b}年生まれ・頂点 ${mine.p}年・利益率${(mine.mg * 100).round()}%')), findsOneWidget);
      expect(find.descendant(of: row, matching: find.textContaining('稼ぎ方：直営')), findsOneWidget);
      // まだの業種（同じ分類で、今ある業種）
      final other = s.liveInds().firstWhere((i) => !s.handled(i.id));
      await _scrollTo(tester, _key('ind-seen-${other.id}'));
      final r2 = _key('ind-seen-${other.id}');
      expect(find.descendant(of: r2, matching: find.text(other.name)), findsOneWidget);
      expect(find.descendant(of: r2, matching: find.text('？')), findsOneWidget);
      expect(find.descendant(of: r2, matching: find.textContaining('利益率')), findsNothing);
      // 未来の業種は名前を出さない
      final fut = s.inds.where((i) => i.b > y && s.seen[i.id] == null).toList();
      final cat = fut.first.cat;
      await _scrollTo(tester, _key('ind-future-$cat'));
      expect(find.descendant(of: _key('ind-future-$cat'), matching: find.text('？？？（未来の業種）')), findsOneWidget);
      expect(find.descendant(of: _key('ind-future-$cat'), matching: find.text('×${fut.where((i) => i.cat == cat).length}')), findsOneWidget);
      for (final i in fut.where((i) => i.cat == cat)) {
        expect(find.text(i.name), findsNothing, reason: i.ja);
      }
      expect(tester.takeException(), isNull);
    });

    test('実績は20個ほどで、名前と説明に日本語と英語がある', () {
      expect(ACHS.length, inInclusiveRange(18, 26));
      expect({for (final a in ACHS) a.id}.length, ACHS.length);
      for (final a in ACHS) {
        for (final k in [a.nJa, a.dJa]) {
          expect(enText(k), isNotNull, reason: k);
          expect(_cjk.hasMatch(enText(k)!), isFalse, reason: k);
        }
      }
      expect(_cjk.hasMatch(txIn(M('実績「{0}」を達成しました', [D(ACHS.first.nJa)]), 'en')), isFalse);
      expect(txIn(M('実績「{0}」を達成しました', [D('上場')]), 'ja'), '実績「上場」を達成しました');
    });

    test('達成すると、月送りの報告に知らせが出て、年月が残る（乱数は使わない）', () {
      final rng = CountingRandom(ParkMiller(2024));
      final s = Game.newGame(SetupConfig(mode: 'endless', year: 2000, traits: ['charm', 'gambler']), rng: rng);
      expect(s.ach, isEmpty);
      expect(s.achMet(), isEmpty);
      final l = s.liveInds().where((i) => s.capexOf(i) <= s.cash).toList();
      s.startBiz(l.first.id);
      final n0 = rng.n;
      expect(s.achMet(), {'first_biz'});
      final got = s.achCheck();
      expect(rng.n, n0, reason: '実績の判定は乱数を使わない');
      expect(got.map((a) => a.id), ['first_biz']);
      expect(s.achWhen('first_biz'), (2000, 1));
      expect(s.achCheck(), isEmpty, reason: '一度達成したものは二度出ない');
      expect(s.everInd, {l.first.id});
      // 月送りで出る知らせ
      s.ach.clear();
      final news = s.nextQuarter();
      final hit = news.where((n) => msgKey(n.m) == '実績「{0}」を達成しました' && txIn(n.m, 'ja').contains('初めての事業')).toList();
      expect(hit.length, 1);
      expect(hit.first.t, 'big');
      expect(txIn(hit.first.m, 'ja'), '実績「初めての事業」を達成しました');
      expect(txIn(hit.first.m, 'en'), 'Milestone reached: "First business"');
      expect(s.achWhen('first_biz'), (2000, 2));
      expect(s.nextQuarter().where((n) => msgKey(n.m).startsWith('実績')), isEmpty);
    });

    test('条件ごとの達成（上場・海外・シナジー・時価総額・順位・宿敵・再起業・50年・3代）', () {
      final s = _midGame();
      s.ach.clear();
      bool met(String id) => s.achMet().contains(id);
      s.listed = true;
      expect(met('ipo'), isTrue);
      final b = s.biz.first;
      b.ctry = [s.home, 'us'];
      expect(met('abroad1'), isTrue);
      expect(met('abroad10'), isFalse);
      b.ctry = [s.home, ...CTRY.where((c) => c.c != s.home).take(10).map((c) => c.c)];
      expect(met('abroad10'), isTrue);
      s.found
        ..clear()
        ..addAll({for (final x in s.syns.take(9)) x.k: 1990});
      expect(met('syn1'), isTrue);
      expect(met('syn10'), isFalse);
      s.found[s.syns[9].k] = 1991;
      expect(met('syn10'), isTrue);
      s.big[s.bigs.first.k] = 1991;
      expect(met('bigsyn'), isTrue);
      s.maxCap = 9.9e11;
      s.cap = 1;
      expect(met('cap1t'), isFalse);
      s.maxCap = 1e12;
      expect(met('cap1t'), isTrue);
      expect(met('cap100t'), isFalse);
      s.maxCap = 1e14;
      expect(met('cap100t'), isTrue);
      s.peakRank = 101;
      expect(met('rank100'), isFalse);
      s.peakRank = 100;
      expect(met('rank100'), isTrue);
      expect(met('rank10'), isFalse);
      s.peakRank = 1;
      expect(met('rank10') && met('rank1'), isTrue);
      expect(met('rival_buy'), isFalse);
      final rv = s.cos.firstWhere((c) => c.rival != null && c.alive);
      rv.parent = 'player';
      rv.stakePlayer = 60;
      expect(met('rival_buy') && met('sub1'), isTrue);
      expect(met('resell'), isFalse);
      s.serial = 1;
      expect(met('resell'), isTrue);
      expect(met('rebirth'), isFalse);
      s.chron('rebirth', M('会社が倒産した。残った人脈で、もう一度ゼロから始めた'));
      expect(met('rebirth'), isTrue);
      s.year = s.startYear + 49;
      expect(met('years50'), isFalse);
      s.year = s.startYear + 50;
      expect(met('years50'), isTrue);
      s.gen = 2;
      expect(met('gen3'), isFalse);
      s.gen = 3;
      expect(met('gen3'), isTrue);
      s.holding = true;
      expect(met('holding'), isTrue);
      s.everInd.addAll(s.inds.take(20).map((i) => i.id));
      expect(met('ind20'), isTrue);
      // 一覧にある実績は、どれも条件がある
      final got = s.achCheck();
      expect(got.length, greaterThan(10));
      expect(s.ach.keys.every(achm.containsKey), isTrue);
    });

    test('達成の記録と手がけた業種はセーブに入る', () {
      final s = _midGame();
      expect(s.ach, isNotEmpty);
      s.ach['ipo'] = 199504;
      s.everInd.add('semi');
      final back = Game.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>, rng: ParkMiller(1));
      expect(back.ach, s.ach);
      expect(back.achWhen('ipo'), (1995, 4));
      expect(back.everInd, s.everInd);
    });

    test('古いセーブ（実績なし）は、今の状態から分かるものだけ達成済みになる（年月なし）', () {
      final s = _midGame();
      final j = jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>
        ..remove('ach')
        ..remove('everInd');
      final back = Game.fromJson(j, rng: ParkMiller(1));
      expect(back.ach.keys.toSet(), back.achMet());
      expect(back.ach.keys, contains('first_biz'));
      expect(back.ach.values.every((v) => v == 0), isTrue);
      expect(back.achWhen('first_biz'), (0, 0));
      expect(back.ach.containsKey('rank1'), isFalse);
      // 今持っている業種は手がけたことになる
      expect(back.everInd, containsAll(back.biz.map((b) => b.ind)));
      // 読んだあとの月送りで、同じ実績の知らせは出ない
      final news = back.nextQuarter();
      for (final n in news.where((n) => msgKey(n.m).startsWith('実績'))) {
        expect(txIn(n.m, 'ja').contains('初めての事業'), isFalse);
      }
    });

    testWidgets('実績の一覧：達成は金の印と年月、古いセーブの分は「達成済み」、まだのものは鍵の印', (tester) async {
      final s = _midGame();
      s.ach
        ..clear()
        ..addAll({'first_biz': 198003, 'partner': 0});
      final ctl = await _pump(tester, game: s);
      ctl.zukanView = 'ach';
      ctl.setTab('zukan');
      await tester.pump();
      final done = _key('ach-done-first_biz');
      expect(find.descendant(of: done, matching: find.text('初めての事業')), findsOneWidget);
      expect(find.descendant(of: done, matching: find.text('1980年3月')), findsOneWidget);
      expect(find.descendant(of: done, matching: find.byIcon(Icons.emoji_events)), findsOneWidget);
      expect(find.descendant(of: _key('ach-done-partner'), matching: find.text('達成済み')), findsOneWidget);
      final todo = _key('ach-todo-staff5');
      expect(find.descendant(of: todo, matching: find.byIcon(Icons.lock_outline)), findsOneWidget);
      expect(find.descendant(of: todo, matching: find.text('部下を5人かかえる')), findsOneWidget);
      expect(find.descendant(of: _key('ach-progress'), matching: find.text('2 / ${ACHS.length}')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('extras を切ると、実績も手がけた業種も記録しない（試作と同じ記録の数のまま）', () {
      final s = Game.newGame(SetupConfig(mode: 'world', year: 1980, traits: ['charm', 'gambler']), rng: ParkMiller(2024), extras: false);
      for (var i = 0; i < 60; i++) {
        botMonth(s);
      }
      expect(s.biz, isNotEmpty);
      expect(s.ach, isEmpty);
      expect(s.everInd, isEmpty);
      expect(s.achCheck(), isEmpty);
      expect(s.log.where((n) => msgKey(n.m).startsWith('実績')), isEmpty);
    });
  });

  group('何か起きるまで進める', () {
    /// 止まる条件（その月に、選ぶ出来事・大事な知らせ・勝ち負けがあったか）
    bool stops(Game g, List<LogEntry> news) => g.events.isNotEmpty || g.over != null || g.won != null || news.any((n) => n.t == 'big' || n.t == 'bad');

    test('選ぶ出来事・大事な知らせ・勝ち負けが出た最初の月で止まり、最大24か月', () {
      expect(untilMax, 24);
      final whys = <String?>{};
      for (final seed in [5, 6, 7, 8, 9, 10, 11, 12]) {
        for (final mk in [() => _midGame(seed), () => Game.fromJson(_newGame(1982).toJson(), rng: ParkMiller(seed))]) {
          final a = mk(), b = mk();
          final t0 = a.turn;
          final r = advanceUntil(a);
          whys.add(r.why);
          expect(r.months, inInclusiveRange(1, untilMax));
          expect(a.turn - t0, r.months);
          // 同じ乱数の写しを1か月ずつ進めて、止まった月が「最初に条件を満たした月」であることを確かめる
          for (var i = 1; i <= r.months; i++) {
            final news = b.nextQuarter();
            expect(stops(b, news), i == r.months && r.why != null, reason: 'seed $seed・$iか月目');
          }
          switch (r.why) {
            case 'event':
              expect(a.events, isNotEmpty);
            case 'news':
              expect(r.news.any((n) => n.t == 'big' || n.t == 'bad'), isTrue);
              expect(a.events, isEmpty);
            case 'end':
              expect(a.ended, isTrue);
            case null:
              expect(r.months, untilMax);
          }
        }
      }
      expect(whys.length, greaterThan(1), reason: '止まる理由が1種類しか出ていない: $whys');
    });

    test('上限の月で止まる（何も起きなくても、それより先へは進まない）', () {
      final s = _midGame();
      final t0 = s.turn;
      final r = advanceUntil(s, max: 1);
      expect(r.months, 1);
      expect(s.turn, t0 + 1);
    });

    testWidgets('「まとめて進める」を押すと選ぶ小窓が開き、「何か起きるまで」で進んで理由が出る', (tester) async {
      for (final lang in ['ja', 'en']) {
        final s = _midGame();
        await _pump(tester, game: s, lang: lang);
        final t0 = s.turn;
        expect(_key('advance-menu'), findsOneWidget);
        expect(tester.getSize(_key('advance-menu')).height, greaterThanOrEqualTo(minTap));
        expect(find.text(tr('1年進める')), findsNothing);
        await tester.tap(_key('advance-menu'));
        await tester.pump();
        expect(find.text(tr('何か起きるまで')), findsOneWidget);
        expect(find.text(tr('3か月進める')), findsOneWidget);
        expect(find.text(tr('1年進める')), findsOneWidget);
        if (lang == 'en') _noJapanese(tester, 'まとめて進める小窓');
        await tester.tap(_key('adv-until'));
        await tester.pump();
        expect(s.turn - t0, inInclusiveRange(1, untilMax));
        expect(_key('stop-reason'), findsOneWidget);
        expect(_key('report-table'), findsOneWidget);
        if (lang == 'en') _noJapanese(tester, '何か起きるまでの報告');
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('小窓から3か月・1年も今までどおり進められる', (tester) async {
      final s = _newGame();
      final ctl = await _pump(tester, game: s);
      await tester.tap(_key('advance-menu'));
      await tester.pump();
      final t0 = s.turn;
      await tester.tap(_key('adv-3'));
      await tester.pump();
      expect(s.turn - t0, inInclusiveRange(1, 3));
      expect(ctl.sheet, isNotNull);
      expect(tester.takeException(), isNull);
    });
  });

  group('数字のタブ', () {
    test('決算の内訳を足すと税引前の利益になる', () {
      final s = _midGame();
      final rows = plRows(s);
      expect(rows.map((r) => r.$1), ['biz', 'sub', 'pay', 'hq', 'int']);
      expect(rows.fold(0.0, (a, r) => a + r.$3), closeTo(s.pre, s.pre.abs() * 1e-9 + 1e-6));
      expect(rows.firstWhere((r) => r.$1 == 'pay').$3, lessThanOrEqualTo(0));
      expect(rows.firstWhere((r) => r.$1 == 'hq').$3, lessThan(0));
    });

    testWidgets('内訳は横棒で出る（いちばん大きい額が端まで・出るお金は赤）', (tester) async {
      for (final lang in ['ja', 'en']) {
        final s = _midGame();
        final ctl = await _pump(tester, game: s, lang: lang);
        ctl.setTab('num');
        await tester.pump();
        final rows = plRows(s);
        final top = rows.map((r) => r.$3.abs()).reduce(math.max);
        final full = tester.getSize(_key('pl-bar-biz')).width;
        for (final r in rows) {
          final bar = tester.widget<AmountBar>(_key('pl-bar-${r.$1}'));
          expect(bar.frac, closeTo(r.$3.abs() / top, 1e-9));
          expect(bar.minus, r.$3 < 0);
          final fill = find.descendant(of: _key('pl-bar-${r.$1}'), matching: find.byType(ColoredBox)).last;
          expect(tester.getSize(fill).width, closeTo(full * bar.frac, .6), reason: r.$1);
          expect(tester.widget<ColoredBox>(fill).color, r.$3 < 0 ? Pal.down : Pal.up);
          expect(find.descendant(of: _key('pl-${r.$1}'), matching: find.text(yen(r.$3))), findsOneWidget);
        }
        expect(find.descendant(of: _key('pl-total'), matching: find.text(yen(s.pre))), findsOneWidget);
        if (lang == 'en') _noJapanese(tester, '数字');
        expect(tester.takeException(), isNull);
      }
    });

    test('ランキングは上位10・自分の前後5・宿敵を、順位の順に出す', () {
      final s = _midGame();
      final rk = s.rankList();
      final me = rk.indexWhere((x) => x.me);
      final shown = rankShown(rk);
      expect(shown, [...shown]..sort());
      expect(shown.toSet().length, shown.length);
      expect(shown, containsAll([for (var i = 0; i < 10; i++) i]));
      expect(shown, containsAll([for (var i = math.max(0, me - 5); i <= math.min(rk.length - 1, me + 5); i++) i]));
      final rivals = [for (var i = 0; i < rk.length; i++) if (rk[i].c?.rival != null) i];
      expect(rivals, isNotEmpty);
      expect(shown, containsAll(rivals));
      for (final i in shown) {
        expect(i < 10 || (i - me).abs() <= 5 || rk[i].c?.rival != null, isTrue);
      }
      expect(shown.length, lessThanOrEqualTo(10 + 11 + rivals.length));
    });

    testWidgets('宿敵には色の印が付き、順位が出る', (tester) async {
      final s = _midGame();
      final ctl = await _pump(tester, game: s);
      ctl.setTab('num');
      await tester.pump();
      await _scrollTo(tester, _key('rank'));
      final rk = s.rankList();
      final me = rk.indexWhere((x) => x.me);
      var dots = 0;
      await _scrollTo(tester, _key('rank-${me + 1}'));
      expect(find.descendant(of: _key('rank-${me + 1}'), matching: find.text('${me + 1}')), findsOneWidget);
      for (var i = 0; i < rk.length; i++) {
        final rv = rk[i].c?.rival;
        if (rv == null) continue;
        dots++;
        final row = _key('rank-${i + 1}');
        expect(row, findsOneWidget, reason: '宿敵 ${rk[i].name} の行');
        final dot = find.descendant(of: row, matching: _key('rank-rival-${rk[i].c!.id}'));
        expect(dot, findsOneWidget);
        expect((tester.widget<Container>(dot).decoration as BoxDecoration).color, hexColor(rv.col));
        expect(find.descendant(of: row, matching: find.text('${i + 1}')), findsOneWidget);
        // 名前はその宿敵の色（白い面で読める濃さ）
        final name = tester.widget<Text>(find.descendant(of: row, matching: find.text(rk[i].name)));
        expect(name.style!.color, rivalInk(rv.col));
        expect(contrastRatio(name.style!.color!, Pal.panel), greaterThanOrEqualTo(4.5));
      }
      expect(dots, greaterThan(0));
      expect(find.textContaining('★'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('新しい事業の一覧（幅320・英語）', () {
    test('幅の狭い並びにする条件', () {
      L.lang = 'ja';
      expect(narrowBizList(296), isTrue);
      expect(narrowBizList(366), isFalse);
      L.lang = 'en';
      expect(narrowBizList(296), isTrue);
      expect(narrowBizList(366), isTrue);
      expect(narrowBizList(406), isFalse);
    });

    for (final c in const [('ja', 320.0), ('en', 320.0), ('en', 390.0), ('ja', 390.0)]) {
      testWidgets('${c.$1}・幅${c.$2.round()}：業種名が語の途中で折れない', (tester) async {
        await _loadFonts();
        final s = _midGame()..ap = 3;
        final ctl = await _pump(tester, game: s, lang: c.$1, size: Size(c.$2, 700));
        ctl.bizFilter = 'all';
        ctl.setTab('biz');
        await tester.pump();
        final list = newBizList(s);
        expect(list.length, greaterThan(20));
        await _scrollTo(tester, _key('newbiz-${list.first.id}'));
        // 1行目のすぐ上の見出しの行も画面に入れる
        final pos = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
        pos.jumpTo(pos.pixels - 80);
        await tester.pump();
        final narrow = c.$2 < 340 || c.$1 == 'en';
        // 狭い並びでは、市場の列をやめて名前の下の行に回す
        expect(find.text(tr('市場（国内・月）')), narrow ? findsNothing : findsOneWidget);
        expect(_key('newbiz-mkt-${list.first.id}'), narrow ? findsOneWidget : findsNothing);
        if (narrow) expect(tester.widget<Muted>(_key('newbiz-mkt-${list.first.id}')).text, tr('市場（国内・月） {0}', [yen(s.mkt(list.first) / 3)]));
        // 名前の列の幅
        final w = tester.getSize(find.ancestor(of: _key('newbiz-${list.first.id}'), matching: find.byType(Column)).first).width;
        expect(w, greaterThanOrEqualTo(!narrow ? 130 : c.$2 < 340 ? 140 : 180), reason: '名前の列の幅 $w');
        // どの業種の名前も、いちばん長い語が名前の列に収まる（＝語の途中では折れない）
        if (c.$1 == 'en') {
          final bad = <String>[];
          for (final i in s.inds) {
            for (final word in i.name.split(RegExp(r'[\s]'))) {
              final tp = TextPainter(text: TextSpan(text: word, style: ts(size: 13)), textDirection: TextDirection.ltr)..layout();
              if (tp.width > w) bad.add('$word(${tp.width.round()})');
              tp.dispose();
            }
          }
          expect(bad, isEmpty, reason: '幅 $w に収まらない語: ${bad.join(', ')}');
        }
        // 並んでいる行を上から見て、名前が1行に収まるか、空白のところで折れている
        var rows = 0;
        await _sweep(tester, () async {
          for (final i in list) {
            final f = find.descendant(of: _key('newbiz-${i.id}'), matching: find.text(i.name));
            if (f.evaluate().isEmpty) continue;
            rows++;
            // 画面と同じ字・同じ幅で組み直して、行の変わり目を調べる
            final text = i.name;
            final p = TextPainter(text: TextSpan(text: text, style: ts(size: 13)), textDirection: TextDirection.ltr)..layout(maxWidth: tester.getSize(f).width);
            expect(p.height, closeTo(tester.getSize(f).height, .5), reason: text);
            for (final b in p.computeLineMetrics().skip(1)) {
              // 2行目から先の行の頭は、語の頭であること
              final pos = p.getPositionForOffset(Offset(1, b.baseline - 2)).offset;
              if (c.$1 == 'en') expect(pos == 0 || text[pos - 1] == ' ' || text[pos - 1] == '-' || text[pos - 1] == '/', isTrue, reason: '$text が ${text.substring(0, pos)}|${text.substring(pos)} で折れた');
            }
            p.dispose();
          }
        });
        expect(rows, greaterThan(10));
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('押せる範囲と英語', () {
    testWidgets('足した部品（切り替え・まとめて進める・組のボタン）は 44pt 以上（幅320・390）', (tester) async {
      for (final size in const [Size(320, 568), Size(390, 844)]) {
        for (final lang in ['ja', 'en']) {
          final s = _midGame()..ap = 3;
          final ctl = await _pump(tester, game: s, lang: lang, size: size);
          ctl.openBiz = s.biz.first.id;
          for (final t in ['biz', 'zukan']) {
            ctl.setTab(t);
            await tester.pump();
            final bad = <String>[];
            for (final e in find.byType(Btn).evaluate()) {
              final r = tester.getRect(find.byWidget(e.widget).first);
              if (r.height < minTap - .01 || r.width < minTap - .01) bad.add('Btn ${(e.widget as Btn).label} ${r.size}');
            }
            for (final v in ['syn', 'ind', 'ach']) {
              if (_key('zukan-$v').evaluate().isEmpty) continue;
              final r = tester.getRect(_key('zukan-$v'));
              if (r.height < minTap - .01 || r.width < minTap - .01) bad.add('zukan-$v ${r.size}');
            }
            expect(bad, isEmpty, reason: '$t $lang $size');
            expect(tester.takeException(), isNull, reason: '$t $lang $size');
          }
          expect(tester.getSize(_key('advance-menu')).height, greaterThanOrEqualTo(minTap));
        }
      }
    });

    testWidgets('英語の画面に日本語が残らない（事業カード・図鑑の3つ・数字・小窓。幅390・320）', (tester) async {
      for (final size in const [Size(390, 844), Size(320, 568)]) {
        final s = _midGame()..ap = 3;
        s.seen[s.inds.firstWhere((i) => i.b > s.yr()).id] = 1;
        s.ach['partner'] = 0;
        final ctl = await _pump(tester, game: s, lang: 'en', size: size);
        ctl.openBiz = s.biz.first.id;
        for (final t in ['town', 'biz', 'num']) {
          ctl.setTab(t);
          await tester.pump();
          await _sweep(tester, () async => _noJapanese(tester, '$t $size'));
          expect(tester.takeException(), isNull, reason: '$t $size');
        }
        for (final v in ['syn', 'ind', 'ach']) {
          ctl.zukanView = v;
          ctl.setTab('zukan');
          await tester.pump();
          await _sweep(tester, () async => _noJapanese(tester, '図鑑 $v $size'));
          expect(tester.takeException(), isNull, reason: '図鑑 $v $size');
        }
        openGlossary(ctl, glossary.keys.toList());
        await tester.pump();
        _noJapanese(tester, '用語の小窓');
        openAdvance(ctl);
        await tester.pump();
        _noJapanese(tester, 'まとめて進める');
        ctl.closeSheet();
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });
  });

  // 目で見る用の書き出し（QUAD_SHOTS があるときだけ）
  for (final c in const [('ja', 390.0), ('en', 390.0), ('ja', 320.0), ('en', 320.0)]) {
    testWidgets('直した画面の書き出し（${c.$1}・幅${c.$2.round()}）', (tester) async {
      if (_out == null) return;
      await _loadFonts();
      final lang = c.$1;
      final tag = '${lang}_${c.$2.round()}';
      final s = _midGame()..ap = 3;
      final b = (s.biz.toList()..ssort((a, b) => b.rev.compareTo(a.rev))).first;
      final ctl = await _pump(tester, game: s, lang: lang, size: Size(c.$2, c.$2 < 340 ? 640 : 844));
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -420));
      await tester.pump();
      await _shot(tester, 'c0_town_actions_$tag');
      ctl.openBiz = b.id;
      ctl.setTab('biz');
      await tester.pump();
      await _shot(tester, 'c1_biz_card_top_$tag');
      await tester.ensureVisible(_key('biz-sell-${b.id}'));
      await tester.pump();
      await _shot(tester, 'c1_biz_card_buttons_$tag');
      await tester.ensureVisible(find.byWidgetPredicate((w) => w is Info && w.terms.contains('upkeep')).first);
      await tester.pump();
      await tester.tap(find.byWidgetPredicate((w) => w is Info && w.terms.contains('upkeep')).first);
      await tester.pumpAndSettle();
      await _shot(tester, 'c2_glossary_$tag');
      ctl.closeSheet();
      await tester.pumpAndSettle();
      ctl.bizFilter = 'all';
      ctl.render();
      await tester.pump();
      await tester.scrollUntilVisible(find.byType(SearchBox), 300, scrollable: find.byType(Scrollable).first);
      await Scrollable.ensureVisible(tester.element(find.byType(SearchBox)), alignment: .02);
      await tester.pump();
      await _shot(tester, 'c6_newbiz_$tag');
      for (final v in ['syn', 'ind', 'ach']) {
        ctl.zukanView = v;
        ctl.setTab('zukan');
        await tester.pumpAndSettle();
        await _shot(tester, 'c3_zukan_${v}_$tag');
      }
      ctl.setTab('num');
      await tester.pumpAndSettle();
      await _shot(tester, 'c5_num_$tag');
      await tester.scrollUntilVisible(_key('rank'), 300, scrollable: find.byType(Scrollable).first);
      await Scrollable.ensureVisible(tester.element(_key('rank')), alignment: .0);
      await tester.pump();
      await _shot(tester, 'c5_rank_$tag');
      ctl.setTab('stock');
      await tester.pumpAndSettle();
      await _shot(tester, 'c2_stock_head_$tag');
      openAdvance(ctl);
      await tester.pumpAndSettle();
      await _shot(tester, 'c4_advance_$tag');
      await tester.tap(_key('adv-until'));
      await tester.pumpAndSettle();
      await _shot(tester, 'c4_until_report_$tag');
      expect(tester.takeException(), isNull);
    });
  }
}
