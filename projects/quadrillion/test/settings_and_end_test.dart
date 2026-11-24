import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';
import 'package:quadrillion/ui/app.dart';
import 'package:quadrillion/ui/controller.dart';
import 'package:quadrillion/ui/sheets.dart';
import 'package:quadrillion/ui/widgets.dart';
import 'package:quadrillion/version.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/bot.dart';

Future<GameController> _pump(WidgetTester tester, {Game? game, Size size = const Size(390, 844)}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final ctl = GameController(prefs: prefs, newRandom: () => ParkMiller(77));
  ctl.game = game;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(QuadrillionApp(controller: ctl));
  await tester.pump();
  return ctl;
}

Game _run(int months, {int seed = 2024, String mode = 'world', int year = 1980}) {
  final s = Game.newGame(
    SetupConfig(mode: mode, year: year, traits: ['charm', 'gambler']),
    rng: ParkMiller(seed),
  );
  for (var i = 0; i < months; i++) {
    botMonth(s);
    if (s.over != null || s.won != null) break;
  }
  resolveEvents(s);
  return s;
}

Finder _onEnd(String t) => find.descendant(of: find.byType(EndScreen), matching: find.text(t));
Finder _inSheet(Finder f) => find.descendant(of: find.byType(SingleChildScrollView), matching: f);

void main() {
  group('社史', () {
    test('創業・最初の事業・時代の大事件・上場などが年月つきで残る', () {
      final s = _run(240);
      final kinds = s.history.map((e) => e.k).toSet();
      expect(s.history.first.k, 'found');
      expect(s.history.first.y, 1980);
      expect(kinds, containsAll(['found', 'first_biz', 'era']));
      expect(kinds.contains('ipo'), s.listed || s.history.any((e) => e.k == 'ipo'));
      // 年月は古い順に並ぶ
      for (var i = 1; i < s.history.length; i++) {
        final a = s.history[i - 1], b = s.history[i];
        expect(a.y * 12 + a.q <= b.y * 12 + b.q, isTrue, reason: '${a.m} / ${b.m}');
      }
    });

    test('相棒・合併・株式交換・会社を売る・社長の交代・ランキングの節目を残す', () {
      final s = _run(60);
      final p = s.mkPartner('club');
      s.sh.own = 100;
      s.ap = 3;
      // 口説けるまで続ける（乱数は進むが、記録の有無だけを見る）
      while (!p.partner) {
        s.recruitPartner(p, 10);
      }
      expect(s.history.last.k, 'partner');
      s.partnerOut(p);
      expect(s.history.last.k, 'partner_out');
      final c = s.cos.firstWhere((c) => c.alive && c.parent != 'player' && c.rival == null);
      c.stakePlayer = 70;
      c.parent = 'player';
      s.sh.riv.clear();
      s.ap = 3;
      s.merge(c);
      expect(s.history.last.k, 'merge');
      expect(s.history.last.m, contains(c.name));
      final heir = s.mkPerson(0);
      s.staff.add(heir);
      final old = s.pres.name;
      s.takeOver(heir);
      expect(s.history.last.k, 'pres');
      expect(s.history.last.m, contains(old));
      final buyer = s.cos.firstWhere((c) => c.alive && c.parent != 'player');
      s.ap = 3;
      s.sellCompany(buyer, false);
      expect(s.history.last.k, 'sold');
      // ランキングの節目（一度に越えたら一番上の節目だけ）
      final n0 = s.history.length;
      s.peakRank = 999;
      s.nextQuarter();
      final added = s.history.sublist(n0).where((e) => e.k == 'rank').toList();
      expect(added.length, s.peakRank <= 500 ? 1 : 0);
    });

    test('セーブで残り、古いセーブ（社史なし）でも落ちずに空から始める', () {
      final s = _run(120);
      expect(s.history, isNotEmpty);
      final j = jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>;
      final back = Game.fromJson(j, rng: ParkMiller(1));
      expect(back.history.map((e) => '${e.y}-${e.q}-${e.k}-${e.m}').toList(), s.history.map((e) => '${e.y}-${e.q}-${e.k}-${e.m}').toList());
      expect(back.maxCap, s.maxCap);
      expect(back.maxWealth, s.maxWealth);
      // 1.0.0+2 までのセーブには history / maxCap / maxWealth がない
      final oldSave = Map<String, dynamic>.from(j)
        ..remove('history')
        ..remove('maxCap')
        ..remove('maxWealth');
      final o = Game.fromJson(oldSave, rng: ParkMiller(1));
      expect(o.history, isEmpty);
      expect(o.maxCap, greaterThanOrEqualTo(o.cap));
      // 続けて遊べて、そこから記録が始まる
      for (var i = 0; i < 24; i++) {
        botMonth(o);
      }
      expect(o.turn, s.turn + 24);
    });

    test('記録は乱数を使わない（同じ種なら、記録の有無にかかわらず同じ数字になる）', () {
      final a = Game.newGame(
        SetupConfig(mode: 'world', year: 1980, traits: ['charm', 'gambler']),
        rng: ParkMiller(9),
      );
      final b = Game.newGame(
        SetupConfig(mode: 'world', year: 1980, traits: ['charm', 'gambler']),
        rng: ParkMiller(9),
      );
      for (var i = 0; i < 120; i++) {
        botMonth(a);
        botMonth(b);
        // 片方だけ社史を消しても、数字はずれない
        b.history.clear();
      }
      expect(row(b), row(a));
      expect((b.rng as ParkMiller).s, (a.rng as ParkMiller).s);
    });

    test('まとめの節目は5つまで、大きいものを古い順に', () {
      final s = _run(240);
      for (var i = 0; i < 8; i++) {
        s.chron('abroad', '国$i');
      }
      s.chron('rank', '世界の企業ランキングで1位になった');
      final h = s.highlights();
      expect(h.length, 5);
      expect(h.map((e) => e.k), contains('found'));
      expect(h.map((e) => e.k), contains('rank'));
      expect(h.any((e) => e.k == 'era' || e.k == 'won' || e.k == 'over'), isFalse);
      for (var i = 1; i < h.length; i++) {
        expect(s.history.indexOf(h[i - 1]) < s.history.indexOf(h[i]), isTrue);
      }
    });
  });

  group('画面', () {
    testWidgets('「数字」タブの下に社史が新しい順で出る', (tester) async {
      final s = _run(150);
      s.chron('ipo', 'テストで一番新しい記録');
      final ctl = await _pump(tester, game: s, size: const Size(390, 20000));
      ctl.setTab('num');
      await tester.pump();
      expect(find.text('社史'), findsOneWidget);
      final newest = tester.getTopLeft(find.text('テストで一番新しい記録'));
      final oldest = tester.getTopLeft(find.textContaining('会社を立ち上げた。元手は'));
      expect(newest.dy < oldest.dy, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('設定が歯車から開き、遊び方・はじめから（確認あり）・ライセンス・版がある', (tester) async {
      final ctl = await _pump(tester, game: _run(30));
      await tester.tap(find.byKey(const ValueKey('settings')));
      await tester.pump();
      expect(find.text('設定'), findsOneWidget);
      expect(find.text('遊び方'), findsOneWidget);
      expect(find.text('フォントのライセンス'), findsOneWidget);
      expect(find.text(appVersion), findsOneWidget);
      // はじめから → 確認 → やめる なら続きのまま
      await tester.tap(find.text('はじめから'));
      await tester.pump();
      expect(find.textContaining('本当によいですか'), findsOneWidget);
      expect(ctl.game, isNotNull);
      await tester.tap(find.text('やめる'));
      await tester.pump();
      expect(ctl.game, isNotNull);
      expect(ctl.sheet, isNull);
      // はじめから → する でセーブが消えて、はじめの画面
      await tester.tap(find.byKey(const ValueKey('settings')));
      await tester.pump();
      await tester.tap(find.text('はじめから'));
      await tester.pump();
      await tester.tap(find.text('はじめからにする'));
      await tester.pump();
      expect(ctl.game, isNull);
      expect(find.text('QUADRILLION'), findsOneWidget);
    });

    testWidgets('設定からライセンスの画面が開く', (tester) async {
      await _pump(tester, game: _run(30));
      await tester.tap(find.byKey(const ValueKey('settings')));
      await tester.pump();
      await tester.tap(find.text('フォントのライセンス'));
      await tester.pumpAndSettle();
      expect(find.byType(LicensePage), findsOneWidget);
    });

    testWidgets('事業を売る・解雇・相棒と別れるは、確認の小窓で「する」を押すまで起きない', (tester) async {
      final s = _run(150);
      final ctl = await _pump(tester, game: s, size: const Size(390, 20000));
      s.ap = 5;
      // 事業が3つ以上だとたたまれているので、1つ開く
      ctl.openBiz = ctl.moreBiz = s.biz.first.id;
      ctl.setTab('biz');
      await tester.pump();
      final n = s.biz.length;
      await tester.tap(find.textContaining('売る（約').first);
      await tester.pump();
      expect(s.biz.length, n, reason: '確認の前に売れてはいけない');
      expect(find.textContaining('本当によいですか'), findsOneWidget);
      await tester.tap(find.text('やめる'));
      await tester.pump();
      expect(s.biz.length, n);
      await tester.tap(find.textContaining('売る（約').first);
      await tester.pump();
      await tester.tap(_inSheet(find.widgetWithText(DangerBtn, '売る')));
      await tester.pump();
      expect(s.biz.length, n - 1);
      ctl.closeSheet();
      // 解雇
      s.staff.add(s.mkPerson(0)..name = '解雇 太郎');
      // 部下が4人以上のときは1行にたたまれているので、その人を開いておく（1.0.0+14）
      ctl.openStaff = s.staff.last.id;
      ctl.setTab('people');
      await tester.pump();
      final m = s.staff.length;
      await tester.tap(find.text('解雇').first);
      await tester.pump();
      expect(s.staff.length, m);
      await tester.tap(find.text('解雇する'));
      await tester.pump();
      expect(s.staff.length, m - 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('会社を丸ごと売る・粉飾決算も確認してから', (tester) async {
      final s = _run(150);
      final ctl = await _pump(tester, game: s, size: const Size(390, 2000));
      s.ap = 5;
      final buyer = s.cos.firstWhere((c) => c.alive && c.parent != 'player');
      buyer.cap = s.cap * 3;
      openSell(ctl);
      await tester.pump();
      final serial = s.serial;
      await tester.tap(find.textContaining('約束なしで売る').first);
      await tester.pump();
      expect(s.serial, serial);
      expect(find.textContaining('本当によいですか'), findsOneWidget);
      await tester.tap(find.widgetWithText(DangerBtn, '売る'));
      await tester.pump();
      expect(s.serial, serial + 1);
      ctl.closeSheet();
      await tester.pump();
      // 粉飾決算
      final foe = s.cos.firstWhere((c) => c.rival != null && c.alive);
      s.ap = 5;
      s.cash = 1e15;
      openDirty(ctl, foe);
      await tester.pump();
      final d = s.dirty;
      await tester.tap(find.textContaining('粉飾決算（'));
      await tester.pump();
      expect(s.dirty, d);
      await tester.tap(find.text('粉飾する'));
      await tester.pump();
      expect(s.dirty, d + 1);
    });

    for (final win in [true, false]) {
      testWidgets('終わったときのまとめ（${win ? '勝ち' : '負け'}）', (tester) async {
        final s = _run(150);
        s.peakRank = 7;
        s.maxWealth = 5e10;
        if (win) {
          s.won = '1999年、世界の企業ランキングで1位になりました';
        } else {
          s.over = '資金が尽きて、会社は倒産しました';
        }
        final ctl = await _pump(tester, game: s, size: const Size(390, 1600));
        expect(find.byType(EndScreen), findsOneWidget);
        expect(_onEnd(win ? '達成！' : 'ゲームオーバー'), findsOneWidget);
        expect(_onEnd((s.won ?? s.over)!), findsOneWidget);
        expect(_onEnd('7位'), findsOneWidget);
        expect(_onEnd('${s.year - s.startYear}年（1980年〜）'), findsOneWidget);
        expect(_onEnd('社史の節目'), findsOneWidget);
        expect(_onEnd('このまま続ける'), win ? findsOneWidget : findsNothing);
        expect(_onEnd('はじめから'), findsOneWidget);
        expect(tester.takeException(), isNull);
        // 小窓が開いている間は、まとめは後ろに下がる
        showHelp(ctl);
        await tester.pump();
        expect(find.byType(EndScreen), findsNothing);
        ctl.closeSheet();
        await tester.pump();
        expect(find.byType(EndScreen), findsOneWidget);
        if (win) {
          // 勝ちのときの「はじめから」は確認がある
          await tester.tap(_onEnd('はじめから'));
          await tester.pump();
          expect(ctl.game, isNotNull);
          expect(find.textContaining('本当によいですか'), findsOneWidget);
        }
      });
    }
  });

  group('振動', () {
    test('勝ち・負け・乗っ取りの警告は強く、上場・大当たり・シナジー発見は中くらい', () {
      final s = _run(30);
      BuzzSnap snap({bool listed = false, String? won, String? over, double riv = 0}) => BuzzSnap(listed: listed, won: won, over: over, rivMax: riv);
      s.listed = false;
      s.sh.riv.clear();
      expect(GameController.buzzKind(s, snap(), const []), isNull);
      expect(GameController.buzzKind(s, snap(), [LogEntry('大当たり！「屋台」の新商品が爆発的に売れています')]), isFalse);
      expect(GameController.buzzKind(s, snap(), [LogEntry('シナジー発見！「a」×「b」')]), isFalse);
      expect(GameController.buzzKind(s, snap(), [LogEntry('大シナジー「x」が完成！')]), isFalse);
      s.listed = true;
      expect(GameController.buzzKind(s, snap(), const []), isFalse);
      expect(GameController.buzzKind(s, snap(listed: true), const []), isNull);
      s.sh.riv[1] = 34;
      expect(GameController.buzzKind(s, snap(listed: true, riv: 20), const []), isTrue);
      expect(GameController.buzzKind(s, snap(listed: true, riv: 34), const []), isNull, reason: '越えたときだけ');
      s.won = '勝ち';
      expect(GameController.buzzKind(s, snap(listed: true, riv: 34), const []), isTrue);
      s.won = null;
      s.over = '負け';
      expect(GameController.buzzKind(s, snap(listed: true, riv: 34), const []), isTrue);
    });

    test('手を打って上場したら振動する', () {
      final ctl = GameController(newRandom: () => ParkMiller(5));
      ctl.game = _run(30)..listed = false;
      final got = <bool>[];
      ctl.buzz = got.add;
      ctl.act(() => null);
      expect(got, isEmpty);
      ctl.act(() {
        ctl.game!.listed = true;
        return null;
      });
      expect(got, [false]);
    });
  });

  test('版の番号が pubspec.yaml と同じ', () {
    final v = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1);
    expect(appVersion, v);
  });
}
