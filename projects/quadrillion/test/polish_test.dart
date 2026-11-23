import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';
import 'package:quadrillion/ui/app.dart';
import 'package:quadrillion/ui/controller.dart';
import 'package:quadrillion/ui/guide.dart';
import 'package:quadrillion/ui/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/bot.dart';

Future<GameController> _newCtl() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return GameController(prefs: prefs, newRandom: () => ParkMiller(77))
    ..setup = SetupConfig(mode: 'world', year: 1980, traits: ['charm', 'gambler']);
}

/// PNG の IHDR（幅・高さ・色の型）と、透過の札（tRNS）があるかを読む
({int w, int h, int colorType, bool trns}) _png(Uint8List b) {
  expect(b.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
  final d = ByteData.sublistView(b);
  var p = 8;
  int w = 0, h = 0, ct = -1;
  var trns = false;
  while (p < b.length) {
    final len = d.getUint32(p);
    final type = ascii.decode(b.sublist(p + 4, p + 8));
    if (type == 'IHDR') {
      w = d.getUint32(p + 8);
      h = d.getUint32(p + 12);
      ct = b[p + 17];
    }
    if (type == 'tRNS') trns = true;
    if (type == 'IEND') break;
    p += 12 + len;
  }
  return (w: w, h: h, colorType: ct, trns: trns);
}

void main() {
  group('初めて遊ぶ人への案内', () {
    test('相棒→最初の事業→打ち手→経営会議の順に進み、できたものは消える', () async {
      final ctl = await _newCtl();
      ctl.startNew();
      final s = ctl.game!;
      expect(currentGuide(s)!.id, 'partner');

      // 相棒探しをした（出会えなくても済み）
      markGuide(s, 'partner');
      expect(currentGuide(s)!.id, 'biz');

      // 最初の事業
      final ind = s.liveInds().where((i) => s.capexOf(i) <= s.cash).first;
      ctl.act(() => s.startBiz(ind.id));
      expect(currentGuide(s)!.id, 'act');

      // 手が残っていないと打ち手は使えず、済みにならない
      final ap = s.ap;
      s.ap = 0;
      ctl.act(() => s.adv(s.biz.first), mark: 'act');
      expect(currentGuide(s)!.id, 'act');
      s.ap = ap;
      ctl.act(() => s.develop(s.biz.first, .3), mark: 'act');
      expect(currentGuide(s)!.id, 'meet');

      markGuide(s, 'meet');
      expect(currentGuide(s), isNull);
    });

    test('相棒がいれば相棒探しは済み・事業があれば事業は済み', () async {
      final ctl = await _newCtl();
      ctl.startNew();
      final s = ctl.game!;
      s.staff.add(s.mkPerson(0)..partner = true);
      final ind = s.liveInds().where((i) => s.capexOf(i) <= s.cash).first;
      s.startBiz(ind.id);
      expect(currentGuide(s)!.id, 'act');
    });

    test('出すのは最初の6か月だけ', () async {
      final ctl = await _newCtl();
      ctl.startNew();
      final s = ctl.game!;
      s.turn += guideMonths - 1;
      expect(currentGuide(s), isNotNull);
      s.turn += 1;
      expect(currentGuide(s), isNull);
    });

    test('閉じたら出ない。進みはセーブに入り、読み込んでも続く', () async {
      final ctl = await _newCtl();
      ctl.startNew();
      final s = ctl.game!;
      markGuide(s, 'partner');
      ctl.save();
      final back = GameController(prefs: ctl.prefs);
      expect(back.load(), isTrue);
      expect(currentGuide(back.game!)!.id, 'biz');
      back.game!.guide['off'] = 1;
      expect(currentGuide(back.game!), isNull);
    });

    test('案内の無かった前の版のセーブでは出さない', () {
      final s = Game.newGame(SetupConfig(mode: 'world', year: 1980, traits: ['charm', 'gambler']), rng: ParkMiller(5));
      final j = s.toJson()..remove('guide');
      final back = Game.fromJson(jsonDecode(jsonEncode(j)) as Map<String, dynamic>, rng: ParkMiller(5));
      expect(currentGuide(back), isNull);
      markGuide(back, 'meet');
      expect(back.guide, isEmpty);
    });

    testWidgets('街のタブの上に1行で出て、×で閉じられる', (tester) async {
      final ctl = await _newCtl();
      ctl.startNew();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(QuadrillionApp(controller: ctl));
      await tester.pump();
      expect(find.text('次にやること'), findsOneWidget);
      expect(find.text('相棒を探す（社長の行動から）'), findsOneWidget);
      // 押すと相棒探しの小窓が開く
      await tester.tap(find.text('相棒を探す（社長の行動から）'));
      await tester.pump();
      expect(ctl.sheet, isNotNull);
      ctl.closeSheet();
      await tester.pump();
      await tester.tap(find.byTooltip('案内を閉じる'));
      await tester.pump();
      expect(find.text('次にやること'), findsNothing);
      expect(ctl.game!.guide['off'], 1);
      expect(tester.takeException(), isNull);
    });
  });

  group('自動保存', () {
    testWidgets('アプリが裏に回る・閉じられるときに保存する', (tester) async {
      final ctl = await _newCtl();
      ctl.startNew();
      await tester.pumpWidget(QuadrillionApp(controller: ctl));
      await tester.pump();
      for (final (i, st) in const [AppLifecycleState.inactive, AppLifecycleState.paused, AppLifecycleState.detached].indexed) {
        ctl.game!.cash = 12345.0 + i;
        tester.binding.handleAppLifecycleStateChanged(st);
        final saved = jsonDecode(ctl.prefs!.getString(saveKey)!) as Map<String, dynamic>;
        expect(saved['cash'], 12345.0 + i, reason: '$st');
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      }
      // 戻ってきたときは保存しない
      ctl.game!.cash = 1;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect((jsonDecode(ctl.prefs!.getString(saveKey)!) as Map)['cash'], isNot(1));
    });

    test('ゲームが無いときは何もしない', () async {
      final ctl = await _newCtl();
      ctl.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(ctl.hasSave(), isFalse);
    });
  });

  group('宿敵の文字色', () {
    for (final r in RIVALS) {
      test('${r.co}（${r.col}）は白地と紙色の上でコントラスト比 4.5 以上', () {
        final c = rivalInk(r.col);
        expect(contrastRatio(c, Pal.panel), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(c, Pal.sky), greaterThanOrEqualTo(4.5));
        // 色味は残す（色相が大きく変わらない）
        final h0 = HSLColor.fromColor(hexColor(r.col)).hue, h1 = HSLColor.fromColor(c).hue;
        final dh = (h0 - h1).abs();
        expect(dh < 3 || dh > 357, isTrue, reason: '色相 $h0 → $h1');
      });
    }
    test('コントラスト比の計算は WCAG と同じ', () {
      expect(contrastRatio(Colors.black, Colors.white), closeTo(21, .01));
      expect(contrastRatio(const Color(0xFF777777), Colors.white), closeTo(4.48, .01));
    });
  });

  group('数字の動き', () {
    testWidgets('月を進めて変わると光り、0.6秒ほどで消える。月が同じなら光らない', (tester) async {
      Widget box(double v, int turn) => MaterialApp(
          home: Scaffold(body: Center(child: FlashStat('現金 ', '$v', value: v, turn: turn))));
      DecoratedBox deco() => tester.widget<DecoratedBox>(find.descendant(of: find.byType(FlashStat), matching: find.byType(DecoratedBox)));
      Color? col() => (deco().decoration as BoxDecoration).color;

      await tester.pumpWidget(box(100, 0));
      expect(col()!.a, 0);
      // 手を打って現金が減っただけ（月は同じ）なら光らない
      await tester.pumpWidget(box(80, 0));
      await tester.pump(const Duration(milliseconds: 200));
      expect(col()!.a, 0);
      // 月が進んで増えたら緑に光る
      await tester.pumpWidget(box(150, 1));
      await tester.pump(const Duration(milliseconds: 200));
      expect(col()!.a, greaterThan(0));
      expect(col()!.withValues(alpha: 1), Pal.up);
      await tester.pump(const Duration(milliseconds: 500));
      expect(col()!.a, 0);
      // 減ったら赤
      await tester.pumpWidget(box(120, 2));
      await tester.pump(const Duration(milliseconds: 200));
      expect(col()!.withValues(alpha: 1), Pal.down);
      await tester.pumpAndSettle();
    });

    testWidgets('順位は数が小さくなると緑', (tester) async {
      Widget box(int rk, int turn) => MaterialApp(
          home: Scaffold(body: FlashStat('世界 ', '$rk位', value: rk.toDouble(), turn: turn, higherIsBetter: false)));
      await tester.pumpWidget(box(10, 0));
      await tester.pumpWidget(box(8, 1));
      await tester.pump(const Duration(milliseconds: 200));
      final d = tester.widget<DecoratedBox>(find.descendant(of: find.byType(FlashStat), matching: find.byType(DecoratedBox)));
      expect((d.decoration as BoxDecoration).color!.withValues(alpha: 1), Pal.up);
      await tester.pumpAndSettle();
    });
  });

  group('アプリのアイコン', () {
    const dir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
    test('1024 は透過なしの正方形', () {
      final p = _png(File('$dir/Icon-App-1024x1024@1x.png').readAsBytesSync());
      expect((p.w, p.h), (1024, 1024));
      // 2 = RGB（アルファなし）。4・6 はアルファあり、3 は tRNS があれば透過
      expect(p.colorType, 2);
      expect(p.trns, isFalse);
    });
    test('Contents.json のすべての大きさがそろっている', () {
      final c = jsonDecode(File('$dir/Contents.json').readAsStringSync()) as Map<String, dynamic>;
      for (final im in (c['images'] as List).cast<Map<String, dynamic>>()) {
        final size = double.parse((im['size'] as String).split('x').first);
        final scale = int.parse((im['scale'] as String).replaceAll('x', ''));
        final px = (size * scale).round();
        final p = _png(File('$dir/${im['filename']}').readAsBytesSync());
        expect((p.w, p.h), (px, px), reason: im['filename'] as String);
        expect(p.colorType, 2, reason: im['filename'] as String);
      }
    });
  });

  testWidgets('案内から最初の事業の小窓が開く', (tester) async {
    final ctl = await _newCtl();
    ctl.startNew();
    markGuide(ctl.game!, 'partner');
    await tester.pumpWidget(QuadrillionApp(controller: ctl));
    await tester.pump();
    await tester.tap(find.text('最初の事業を決める').first);
    await tester.pump();
    expect(ctl.sheet, isNotNull);
    expect(find.textContaining('創業'), findsWidgets);
  });
}
