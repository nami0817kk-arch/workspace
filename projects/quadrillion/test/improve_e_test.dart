import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';
import 'package:quadrillion/ui/app.dart';
import 'package:quadrillion/ui/controller.dart';
import 'package:quadrillion/ui/sheets.dart';
import 'package:quadrillion/ui/tabs.dart';
import 'package:quadrillion/ui/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/bot.dart';
import 'support/pilot.dart';
import 'support/shots.dart';

String? _midJson;

/// 途中のゲーム（150か月。事業・部下・宿敵がそろっている）
Game _mid() {
  if (_midJson == null) {
    final s = Game.newGame(SetupConfig(mode: 'world', year: 1980, traits: ['charm', 'gambler']), rng: ParkMiller(2024));
    for (var i = 0; i < 150; i++) {
      botMonth(s);
    }
    resolveEvents(s);
    s.calcAll();
    _midJson = jsonEncode(s.toJson());
  }
  return Game.fromJson(jsonDecode(_midJson!) as Map<String, dynamic>, rng: ParkMiller(5))..calcAll();
}

Future<GameController> _ctl(Game g) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return GameController(prefs: prefs, newRandom: () => ParkMiller(7), lang: 'ja')
    ..game = g
    ..buzz = (_) {};
}

int _turnOf(String? raw) => Game.fromJson(jsonDecode(raw!) as Map<String, dynamic>, rng: ParkMiller(1)).turn;

/// 1.0.0+17（改善の回E）で直した所の確かめ。
void main() {
  group('保存を軽くする', () {
    // もとからあるテストは待ち時間0（次の描き終わりにその場で保存）。ここでは本番と同じ「手が止まってから・別 Isolate で」の道を確かめる
    setUp(() => GameController.saveDelay = const Duration(milliseconds: 350));
    tearDown(() => GameController.saveDelay = Duration.zero);

    test('本番の待ち時間は350ms。別 Isolate で文字にしたものは、その場で文字にしたものと同じ', () async {
      expect(GameController.saveDelay, const Duration(milliseconds: 350));
      final g = _mid();
      final ctl = await _ctl(g);
      final want = jsonEncode(g.toJson());
      await ctl.saveOff();
      expect(ctl.prefs!.getString(slotKey(1)), want);
      expect(ctl.prefs!.getString(slotMetaKey(1)), isNotNull);
      expect(ctl.savesInFlight, 0);
    });

    testWidgets('月送りを連打しているあいだは書かず、手が止まってから1回だけ、最新の月を書く', (tester) async {
      final g = _mid();
      final ctl = await _ctl(g);
      final enc = <Map<String, dynamic>>[];
      ctl.encodeOff = (tree) async {
        enc.add(tree);
        return jsonEncode(tree);
      };
      await tester.pumpWidget(QuadrillionApp(controller: ctl));
      await tester.pump();
      for (var i = 0; i < 5; i++) {
        resolveEvents(g);
        doNext(ctl);
        ctl.hideSheet();
        await tester.pump(const Duration(milliseconds: 120));
        expect(ctl.savePending, isTrue);
        expect(ctl.prefs!.getString(slotKey(1)), isNull, reason: '連打のあいだは書かない（$i回目）');
      }
      expect(enc, isEmpty);
      await tester.pump(const Duration(milliseconds: 360));
      await tester.pump();
      expect(enc.length, 1, reason: '手が止まってから1回だけ');
      expect(ctl.savePending, isFalse);
      expect(_turnOf(ctl.prefs!.getString(slotKey(1))), g.turn, reason: '最新の月が入っている');
    });

    testWidgets('連打が続いても、決めた回数を超えたら1度は書き出す', (tester) async {
      final g = _mid();
      final ctl = await _ctl(g);
      var n = 0;
      ctl.encodeOff = (tree) async {
        n++;
        return jsonEncode(tree);
      };
      await tester.pumpWidget(QuadrillionApp(controller: ctl));
      for (var i = 0; i < GameController.saveDeferMax + 8; i++) {
        ctl.saveSoon();
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(n, greaterThanOrEqualTo(1));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(ctl.savePending, isFalse);
    });

    testWidgets('アプリが裏に回ると、待っている保存をその場で済ませる。裏で作りかけの古い保存は、あとから上書きしない', (tester) async {
      final g = _mid();
      final ctl = await _ctl(g);
      final gates = <Completer<void>>[];
      ctl.encodeOff = (tree) async {
        final c = Completer<void>();
        gates.add(c);
        await c.future;
        return jsonEncode(tree);
      };
      await tester.pumpWidget(QuadrillionApp(controller: ctl));
      // 1) 待っているあいだに裏へ → その場で書く
      resolveEvents(g);
      doNext(ctl);
      ctl.hideSheet();
      expect(ctl.prefs!.getString(slotKey(1)), isNull);
      ctl.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(ctl.savePending, isFalse);
      expect(_turnOf(ctl.prefs!.getString(slotKey(1))), g.turn);
      await tester.pump(const Duration(milliseconds: 400));
      expect(gates, isEmpty, reason: '済んだ予約では、もう裏の保存を始めない');
      // 2) 裏で文字にしている最中に、次の月へ進んで裏へ回る → 新しい月が残る
      final t1 = g.turn;
      ctl.saveSoon();
      await tester.pump(const Duration(milliseconds: 400));
      expect(gates.length, 1);
      expect(ctl.savesInFlight, 1);
      resolveEvents(g);
      g.nextQuarter();
      ctl.didChangeAppLifecycleState(AppLifecycleState.inactive);
      expect(_turnOf(ctl.prefs!.getString(slotKey(1))), t1 + 1);
      gates.single.complete();
      await tester.pump();
      await tester.pump();
      expect(ctl.savesInFlight, 0);
      expect(_turnOf(ctl.prefs!.getString(slotKey(1))), t1 + 1, reason: '古い保存があとから上書きしていない');
    });

    testWidgets('手を打ったあとの保存も、結果を見せたあとに回す。セーブを消したあとに、作りかけの保存が書き戻さない', (tester) async {
      final g = _mid();
      final ctl = await _ctl(g);
      final gates = <Completer<void>>[];
      ctl.encodeOff = (tree) async {
        final c = Completer<void>();
        gates.add(c);
        await c.future;
        return jsonEncode(tree);
      };
      await tester.pumpWidget(QuadrillionApp(controller: ctl));
      g.ap = 3;
      ctl.act(() => g.presAct('work'));
      expect(ctl.sheet, isNotNull, reason: '結果の小窓は先に出る');
      expect(ctl.prefs!.getString(slotKey(1)), isNull);
      expect(ctl.savePending, isTrue);
      await tester.pump(const Duration(milliseconds: 400));
      expect(gates.length, 1);
      // 作りかけのまま、はじめからにする（セーブを消す）
      ctl.backToSetup();
      gates.single.complete();
      await tester.pump();
      await tester.pump();
      expect(ctl.prefs!.getString(slotKey(1)), isNull, reason: '消したセーブが書き戻されていない');
    });

    testWidgets('枠を替える前に、待っている保存を済ませる', (tester) async {
      final g = _mid();
      final ctl = await _ctl(g);
      await tester.pumpWidget(QuadrillionApp(controller: ctl));
      ctl.save();
      resolveEvents(g);
      g.nextQuarter();
      ctl.saveSoon();
      expect(ctl.savePending, isTrue);
      ctl.load(1);
      expect(ctl.savePending, isFalse);
      expect(ctl.game!.turn, g.turn, reason: '進めた月が残っている');
      await tester.pump(const Duration(milliseconds: 400));
    });
  });

  group('見やすさ', () {
    test('宿敵の色は、字も印も顔も、白地と紙色の上で 4.5:1 以上', () {
      final cols = {for (final r in RIVALS) r.col, '#ffb454', ...faceCols};
      for (final c in cols) {
        final ink = rivalInk(c);
        expect(contrastRatio(ink, Pal.panel), greaterThanOrEqualTo(4.5), reason: c);
        expect(contrastRatio(ink, Pal.sky), greaterThanOrEqualTo(4.5), reason: c);
        // 顔の印は、その濃い色で塗って白い字を載せる
        final f = Face.rival('黒田 剛造', c);
        expect(f.fill, ink);
        expect(contrastRatio(Pal.panel, f.fill), greaterThanOrEqualTo(4.5), reason: c);
      }
      // 直す前の印（明るい塗り）は、白地では薄かった
      expect(contrastRatio(hexColor('#9fb3ff'), Pal.panel), lessThan(3));
    });

    test('顔の印は、社長・相棒・部下・宿敵で形と色が違う。部下の色はいちばん高い能力', () {
      final s = _mid();
      const dark = Color(0xFF0D1426);
      for (final c in abFaceCols.values) {
        expect(contrastRatio(dark, hexColor(c)), greaterThanOrEqualTo(4.5), reason: c);
      }
      expect(abFaceCols.keys.toSet(), abKeys.toSet());
      expect(abFaceCols.values.toSet().length, abKeys.length);
      final p = s.staff.first;
      final f = staffFace(s, p);
      expect(f.col, abFaceCols[topAbility(s, p)]);
      expect(f.ring, p.partner);
      expect(f.rival, isFalse);
      p.partner = true;
      expect(staffFace(s, p).ring, isTrue);
      final pres = Face.pres(s.pres.name);
      expect(pres.ring, isTrue);
      expect(pres.col, '#f2c14e');
      expect(const Face.rival('x', '#9fb3ff').rival, isTrue);
    });

    testWidgets('宿敵の顔は角の丸い四角、部下は丸。「人」に色の見方が出る（日本語・英語）', (tester) async {
      for (final lang in const ['ja', 'en']) {
        final g = _mid();
        final p = await Pilot.launch(tester, lang: lang, game: g);
        final rv = g.cos.where((c) => c.rival != null && c.alive).first;
        await p.reveal(find.byKey(ValueKey('rival-row-${rv.id}')));
        final face = find.descendant(of: find.byKey(ValueKey('rival-row-${rv.id}')), matching: find.byType(Face));
        final box = tester.widget<Container>(find.descendant(of: face, matching: find.byType(Container)).first).decoration as BoxDecoration;
        expect(box.shape, BoxShape.rectangle);
        expect(box.color, rivalInk(rv.rival!.col));
        await p.tab('people');
        await p.reveal(find.byKey(const ValueKey('face-legend')));
        final legend = find.descendant(of: find.byKey(const ValueKey('face-legend')), matching: find.byType(RichText));
        final text = tester.widget<RichText>(legend.first).text.toPlainText();
        expect(text, contains(tr('顔の色はいちばん高い能力')));
        expect(text, contains(tr('輪つきは社長と相棒')));
        for (final k in abKeys) {
          expect(text, contains(ABN[k]!));
        }
        await p.reveal(find.text(tr('社長')));
        expect(find.byWidgetPredicate((w) => w is Face && w.ring && w.col == '#f2c14e'), findsWidgets, reason: '社長は金色の丸に輪');
        expect(p.found, isEmpty, reason: p.found.join('\n'));
      }
    });

    testWidgets('決算の棒は、額が小さくても豆粒にならない（0でなければ12以上）', (tester) async {
      await tester.pumpWidget(const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
              child: SizedBox(
                  width: 300,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    AmountBar(1, key: ValueKey('a'), minus: false),
                    AmountBar(.004, key: ValueKey('b'), minus: true),
                    AmountBar(0, key: ValueKey('c'), minus: true),
                    AmountBar(.5, key: ValueKey('d'), minus: true),
                  ])))));
      double w(String k) => tester.getSize(find.descendant(of: find.byKey(ValueKey(k)), matching: find.byType(ColoredBox)).last).width;
      expect(w('a'), 300);
      expect(w('b'), AmountBar.minFill);
      expect(w('c'), 0);
      expect(w('d'), 150);
      expect(tester.getSize(find.byKey(const ValueKey('a'))).height, 8);
    });
  });

  group('忠誠の注意の線', () {
    Person p(double loy, {int amb = 80, bool known = false}) =>
        Person(id: 1, name: '山田 太郎', age: 30, ab: {for (final k in abKeys) k: 50}, trait: STRAITS.first.id, amb: amb, loy: loy)..ambKnown = known;

    test('赤は引き抜きが始まる線（55）と同じ。その手前（60未満）は橙の前触れ', () {
      expect(loyWarn, 55);
      expect(loySoft, 60);
      expect(loyLevel(p(75)), isNull);
      expect(loyLevel(p(60)), isNull);
      expect(loyLevel(p(59.9)), 'soft');
      expect(loyLevel(p(55)), 'soft');
      expect(loyLevel(p(54.9)), 'bad');
      // 野心が弱いと分かっている人は、引き抜きの的にならないので赤にしない。分かっていなければ赤
      expect(loyLevel(p(40, amb: 30, known: true)), 'soft');
      expect(loyLevel(p(40, amb: 30)), 'bad');
      expect(loyLevel(p(40, amb: 61, known: true)), 'bad');
      expect(loyNote('bad').$2, Pal.down);
      expect(loyNote('soft').$2, Pal.warn);
      expect(contrastRatio(Pal.warn, Pal.panel), greaterThanOrEqualTo(3), reason: '印として見える濃さ');
    });

    test('仕組みの線と合っている: 忠誠55以上の人は引き抜かれず、相棒は50以上なら独立を言い出さない', () {
      // 忠誠を 55 と 54 に固定した野心家で、600か月ぶんの出来事を数える
      int poached(double loy) {
        final s = _mid();
        var n = 0;
        for (var i = 0; i < 600 && s.over == null; i++) {
          n += s.events.where((e) => e.poach != null).length;
          resolveEvents(s);
          // 忠誠は、出来事を片付けたあとに固定する（1.0.0+19 から、国の事件や宿敵の場面の選び方で忠誠が動く）
          for (final x in s.staff) {
            x
              ..amb = 90
              ..loy = loy;
          }
          s.nextQuarter();
        }
        return n;
      }

      expect(poached(55), 0);
      expect(poached(54), greaterThan(0));
    });
  });

  group('画面を目で見る（QUAD_SHOTS を渡したときだけ書き出す）', () {
    for (final w in const [390.0, 320.0]) {
      testWidgets('幅${w.round()}', (tester) async {
        await loadRealFonts();
        final key = GlobalKey();
        final g = _mid();
        // 忠誠の2段と、相棒の輪が見えるようにする
        if (g.staff.length >= 3) {
          g.staff[0].loy = 40;
          g.staff[1].loy = 57;
          g.staff[2].partner = true;
        }
        final p = await Pilot.launch(tester, lang: 'ja', size: Size(w, 844), game: g, boundary: key);
        final n = w.round();
        final rv = g.cos.where((c) => c.rival != null && c.alive).first;
        await p.reveal(find.byKey(ValueKey('rival-row-${rv.id}')));
        await shot(tester, key, 'e_town_rivals_$n');
        await p.pressKey('rival-row-${rv.id}');
        await shot(tester, key, 'e_town_rival_open_$n');
        await p.tab('people');
        await shot(tester, key, 'e_people_top_$n');
        await p.reveal(find.byKey(const ValueKey('face-legend')));
        await shot(tester, key, 'e_people_staff_$n');
        await p.tab('num');
        await shot(tester, key, 'e_num_pl_$n');
        await p.reveal(find.byKey(const ValueKey('rank')));
        await shot(tester, key, 'e_num_rank_$n');
        await p.tab('stock');
        await p.sweep();
        await shot(tester, key, 'e_stock_bottom_$n');
        await p.tab('biz');
        final b = g.biz.first;
        p.ctl.openBiz = b.id;
        p.ctl.render();
        await p.pump();
        await p.reveal(find.byKey(ValueKey('grp-grow-${b.id}')));
        await shot(tester, key, 'e_biz_card_$n');
        openBuild(p.ctl, b);
        await p.pump();
        await shot(tester, key, 'e_build_sheet_$n');
        expect(find.textContaining(tr('今ある{0}を広げる（元手の1/4）', [g.uw(b)])), findsOneWidget);
        expect(p.found, isEmpty, reason: p.found.join('\n'));
      });
    }
  });

  group('日本語のボタンが2行に折れない', () {
    // 本物のフォント（同梱の Noto Sans JP）で、押して遊ぶ役に2年ぶん遊ばせ、出てきたふつうのボタンの字が1行に収まっているかを見る
    for (final w in const [390.0, 320.0]) {
      testWidgets('幅${w.round()}', (tester) async {
        await loadRealFonts();
        final p = await Pilot.launch(tester, lang: 'ja', seed: 23, size: Size(w, 844));
        p.watchWraps = true;
        await p.play(year: 2000, years: 2, mode: 'world', home: 'jp');
        // ignore: avoid_print
        print('[wrap] 幅${w.round()}: ${p.wraps.length}件\n${p.wraps.entries.map((e) => '  「${e.key}」 ${e.value}').join('\n')}');
        expect(p.found, isEmpty, reason: p.found.join('\n'));
        if (Platform.environment['QUAD_WRAP_LIST'] == null) expect(p.wraps, isEmpty, reason: p.wraps.entries.map((e) => '「${e.key}」 ${e.value}').join('\n'));
      }, timeout: const Timeout(Duration(minutes: 10)));

      // 育った会社（上場・子会社・部下が多い）の画面をひと回りする。序盤には出ないボタンを見る
      testWidgets('幅${w.round()}・育った会社をひと回り', (tester) async {
        await loadRealFonts();
        for (final c in const [(1980, 300, 2024), (2000, 180, 31)]) {
          final g = Game.newGame(SetupConfig(mode: 'endless', year: c.$1, traits: ['charm', 'gambler']), rng: ParkMiller(c.$3));
          for (var i = 0; i < c.$2 && g.over == null; i++) {
            botMonth(g, units: true);
          }
          resolveEvents(g);
          g.calcAll();
          final p = await Pilot.launch(tester, lang: 'ja', seed: 23, size: Size(w, 844), game: g);
          p.watchWraps = true;
          // 5つのタブを上から下まで見る。事業・宿敵・部下は、1つずつ開いたカードも見る
          for (final t in const ['town', 'biz', 'people', 'stock', 'num']) {
            p.where = '育った会社（$t）';
            p.ctl.setTab(t);
            await p.pump();
            await p.sweep();
            final opens = <VoidCallback>[
              if (t == 'biz')
                for (final b in g.biz.take(4)) () => p.ctl.openBiz = b.id,
              if (t == 'town')
                for (final c in g.cos.where((c) => c.rival != null && c.alive).take(3)) () => p.ctl.openRival = c.id,
              if (t == 'people')
                for (final x in g.staff.take(3)) () => p.ctl.openStaff = x.id,
            ];
            for (final o in opens) {
              o();
              p.ctl.render();
              await p.pump();
              await p.sweep();
            }
          }
          // ignore: avoid_print
          print('[wrap] 幅${w.round()} 育った会社（${g.year}年・事業${g.biz.length}・子会社${g.subs().length}・部下${g.staff.length}・上場${g.listed}）: ${p.wraps.length}件\n'
              '${p.wraps.entries.map((e) => '  「${e.key}」 ${e.value}').join('\n')}');
          expect(p.found, isEmpty, reason: p.found.join('\n'));
          if (Platform.environment['QUAD_WRAP_LIST'] == null) expect(p.wraps, isEmpty, reason: p.wraps.entries.map((e) => '「${e.key}」 ${e.value}').join('\n'));
        }
      }, timeout: const Timeout(Duration(minutes: 10)));
    }
  });
}
