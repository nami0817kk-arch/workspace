import 'dart:convert';
import 'dart:ui' show PictureRecorder;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';
import 'package:quadrillion/ui/app.dart';
import 'package:quadrillion/ui/controller.dart';
import 'package:quadrillion/ui/painters.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/bot.dart';

Future<GameController> _ctl([Map<String, Object> init = const {}]) async {
  SharedPreferences.setMockInitialValues(init);
  final prefs = await SharedPreferences.getInstance();
  return GameController(prefs: prefs, newRandom: () => ParkMiller(77))
    ..setup = SetupConfig(mode: 'world', year: 1980, traits: ['charm', 'gambler']);
}

Game _g({int seed = 5, String diff = 'normal', int year = 1980}) =>
    Game.newGame(SetupConfig(mode: 'endless', year: year, traits: ['charm', 'gambler'], diff: diff), rng: ParkMiller(seed));

void main() {
  group('難しさ', () {
    test('ふつうは何も指定しないときと1円も変わらない', () {
      final a = Game.newGame(SetupConfig(mode: 'world', year: 2000, traits: ['tech', 'noble'], home: 'us'), rng: ParkMiller(42));
      final b = Game.newGame(SetupConfig(mode: 'world', year: 2000, traits: ['tech', 'noble'], home: 'us', diff: 'normal'), rng: ParkMiller(42));
      for (var t = 0; t < 120; t++) {
        botMonth(a);
        botMonth(b);
      }
      expect(row(b), row(a));
      expect(a.diff, 'normal');
    });

    test('2000年から30年、自動プレイの順位がやさしい＞ふつう＞むずかしいになる', () {
      final med = <String, int>{};
      for (final d in const ['easy', 'normal', 'hard']) {
        final ranks = <int>[];
        for (var seed = 1; seed <= 6; seed++) {
          final s = _g(seed: seed * 7919, diff: d, year: 2000);
          // 1.0.0+12 から画面の打ち手は1単位の手なので、自動プレイもそれで遊ぶ
          for (var t = 0; t < 360 && s.over == null; t++) {
            botMonth(s, units: true);
          }
          ranks.add(s.rank);
        }
        ranks.sort();
        med[d] = ranks[ranks.length ~/ 2];
      }
      // 実測（12通りの中央値）: やさしい86位・ふつう157位・むずかしい244位
      expect(med['easy']! < med['normal']! * .8, isTrue, reason: '$med');
      expect(med['hard']! > med['normal']! * 1.2, isTrue, reason: '$med');
    }, timeout: const Timeout(Duration(minutes: 10)));

    test('難しさはセーブに入り、古いセーブはふつう', () {
      final s = _g(diff: 'hard');
      final j = jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>;
      expect(Game.fromJson(j, rng: ParkMiller(1)).diff, 'hard');
      j.remove('diff');
      expect(Game.fromJson(j, rng: ParkMiller(1)).diff, 'normal');
      expect(diffOf('???').id, 'normal');
    });
  });

  group('セーブ枠', () {
    test('空いている枠に始め、自動保存は今の枠へ。枠ごとに読み込める', () async {
      final ctl = await _ctl();
      expect(ctl.hasSave(), isFalse);
      ctl.startNew();
      expect(ctl.slot, 1);
      expect(ctl.hasSave(1), isTrue);
      final name1 = ctl.game!.pres.name;
      ctl.game = null;
      expect(ctl.startSlot, 2);
      ctl.setup.diff = 'easy';
      ctl.startNew();
      expect(ctl.slot, 2);
      ctl.game!.cash = 4321;
      ctl.save();
      expect((jsonDecode(ctl.prefs!.getString(slotKey(2))!) as Map)['cash'], 4321);
      expect((jsonDecode(ctl.prefs!.getString(slotKey(1))!) as Map)['cash'], isNot(4321));
      final back = GameController(prefs: ctl.prefs);
      expect(back.load(1), isTrue);
      expect(back.game!.pres.name, name1);
      expect(back.slot, 1);
      expect(back.load(3), isFalse);
      expect(back.load(2), isTrue);
      expect(back.game!.diff, 'easy');
      final info = back.slotInfo(2)!;
      expect(info.year, 1980);
      expect(info.diff, 'easy');
      expect(info.name, back.game!.pres.name);
      expect(back.slotInfo(3), isNull);
    });

    test('全部埋まっていたら枠1。はじめからは今の枠だけ消す', () async {
      final ctl = await _ctl();
      for (var i = 0; i < 3; i++) {
        ctl.startNew();
        ctl.game = null;
      }
      expect([1, 2, 3].every(ctl.hasSave), isTrue);
      expect(ctl.startSlot, 1);
      ctl.load(2);
      ctl.backToSetup();
      expect(ctl.hasSave(2), isFalse);
      expect(ctl.hasSave(1) && ctl.hasSave(3), isTrue);
      expect(ctl.startSlot, 2);
    });

    test('前の版の1つだけのセーブは枠1として読み込む', () async {
      final old = _g(seed: 9)..cash = 98765;
      final ctl = await _ctl({legacySaveKey: jsonEncode(old.toJson())});
      expect(ctl.prefs!.getString(legacySaveKey), isNull);
      expect(ctl.hasSave(1), isTrue);
      expect(ctl.slotInfo(1)!.name, old.pres.name);
      expect(ctl.load(1), isTrue);
      expect(ctl.game!.cash, 98765);
    });

    testWidgets('一覧に年月・名前・時価総額・順位が出て、埋まった枠に始めると上書きを確かめる', (tester) async {
      final ctl = await _ctl();
      ctl.startNew();
      final g = ctl.game!;
      ctl.game = null;
      ctl.newSlot = 1;
      tester.view.physicalSize = const Size(390, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(QuadrillionApp(controller: ctl));
      await tester.pump();
      expect(find.text('1980年1月　${g.pres.name}'), findsOneWidget);
      expect(find.textContaining('時価総額${yen(g.cap)}・世界${g.rankList().indexWhere((x) => x.me) + 1}位'), findsOneWidget);
      expect(find.text('空き'), findsNWidgets(4)); // 一覧に2つ・保存する枠に2つ
      await tester.tap(find.text('会社を立ち上げる'));
      await tester.pump();
      expect(find.text('枠1に上書きする'), findsOneWidget);
      expect(ctl.game, isNull);
      await tester.tap(find.text('上書きして始める'));
      await tester.pump();
      expect(ctl.game, isNotNull);
      expect(ctl.slot, 1);
      expect(tester.takeException(), isNull);
    });
  });

  test('社史の節目に500位・200位がある', () {
    expect(rankMarks, containsAll([200, 500]));
    final seen = <int>{};
    for (var seed = 1; seed <= 8; seed++) {
      final s = _g(seed: seed * 31, year: 2000);
      for (var t = 0; t < 120; t++) {
        botMonth(s);
        if (t % 12 == 0) {
          // 節目の行が出るように最高位を忘れさせて、1か月進める
          final n0 = s.history.length;
          s.peakRank = 999;
          resolveEvents(s);
          s.nextQuarter();
          final added = s.history.sublist(n0).where((e) => e.k == 'rank').toList();
          final th = rankMarks.where((m) => s.peakRank <= m).firstOrNull;
          expect(added.length, th == null ? 0 : 1);
          if (th != null && th > 1) {
            expect(tx(added.single.m), contains('$th位以内'));
            seen.add(th);
          }
        }
      }
    }
    expect(seen, containsAll([200, 500]), reason: '$seen');
  }, timeout: const Timeout(Duration(minutes: 5)));

  group('番頭のひとこと', () {
    Game mid() {
      final s = Game.newGame(SetupConfig(mode: 'world', year: 1980, traits: ['charm', 'gambler']), rng: ParkMiller(2024));
      for (var i = 0; i < 150; i++) {
        botMonth(s);
      }
      resolveEvents(s);
      s.calcAll();
      return s;
    }

    test('5つ以上で持株会社でなければ勧め、持株会社なら言わない', () {
      final s = mid();
      expect(s.biz.length + s.subs().length, greaterThanOrEqualTo(5));
      s.holding = false;
      expect(s.adviceAll().map(tx).any((m) => m.contains('持株会社')), isTrue);
      s.holding = true;
      expect(s.adviceAll().map(tx).any((m) => m.contains('持株会社')), isFalse);
    });

    test('4か国の事業には「あと1か国で規模の利益」', () {
      final s = mid();
      final b = s.biz.first;
      b.pipe.clear();
      b.ctry = [s.home, 'us', 'cn', 'de'];
      expect(s.adviceAll().map(tx).any((m) => m.contains('あと1か国で規模の利益')), isTrue);
      b.ctry = [s.home, 'us', 'cn', 'de', 'in'];
      expect(s.adviceAll().map(tx).any((m) => m.contains('「${indm[b.ind]!.name}」は4か国')), isFalse);
    });

    test('伸びている事業が1か国だけなら海外を勧める', () {
      final s = mid();
      for (final b in s.biz) {
        b.ctry = [s.home, 'us'];
      }
      final b = s.biz.first;
      b.ctry = null;
      b.pipe.clear();
      b.prevRev = b.rev * .9;
      b.profit = b.rev.abs() + 1;
      s.cash = 1e15;
      expect(s.adviceAll().map(tx).any((m) => m.contains('「${indm[b.ind]!.name}」が伸びています') && m.contains('海外に出る')), isTrue);
      b.prevRev = b.rev * 1.1;
      expect(s.adviceAll().map(tx).any((m) => m.contains('海外に出る')), isFalse);
    });

    test('上場していて小さい同業があれば株式交換。上場前は言わない', () {
      final s = mid();
      final ind = s.biz.first.ind;
      final c = s.mkCo(0, indm[ind]!.cat, name: 'テスト商会')..biz.add(CoBiz(ind: ind, power: 1));
      c.cap = s.cap * .3;
      s.listed = false;
      expect(s.adviceAll().map(tx).any((m) => m.contains('株式交換')), isFalse);
      s.listed = true;
      s.sh.riv.clear();
      final m = s.adviceAll().map(tx).where((m) => m.contains('株式交換')).toList();
      expect(m, hasLength(1));
    });

    test('最大3行で、大事なものが先。汚い手は勧めない', () {
      final s = mid();
      s.holding = false;
      s.pres.age = 65;
      s.succ = null;
      final all = s.adviceAll().map(tx).toList();
      expect(s.advice().map(tx).toList(), all.take(3).toList());
      expect(s.advice().length, lessThanOrEqualTo(3));
      expect(all.indexWhere((m) => m.contains('60歳')), lessThan(all.indexWhere((m) => m.contains('持株会社'))));
      expect(all.any((m) => RegExp('粉飾|談合|汚い|裏金|スパイ').hasMatch(m)), isFalse);
    });
  });

  group('売上と利益の推移', () {
    test('2か月未満は線を引かない', () {
      final p = RevProfitPainter([HistEntry(t: '1980-1', cap: 1, rev: 1, cash: 1, pre: 1)]);
      final rec = PictureRecorder();
      p.paint(Canvas(rec), const Size(390, 110));
      rec.endRecording();
      expect(p.drawn[0], isEmpty);
    });

    test('利益が負の月は0の線の下、正の月は上に描く', () {
      final h = [
        for (var i = 0; i < 24; i++) HistEntry(t: '1980-$i', cap: 1e9, rev: 1e7 + i * 1e6, cash: 0, pre: i < 6 ? -3e6 : 2e6 + i * 1e5),
      ];
      final p = RevProfitPainter(h);
      final rec = PictureRecorder();
      p.paint(Canvas(rec), const Size(390, 110));
      rec.endRecording();
      expect(p.drawn[0], hasLength(24));
      expect(p.drawn[1], hasLength(24));
      for (var i = 0; i < 24; i++) {
        // 画面の y は下に行くほど大きい
        if (h[i].pre < 0) {
          expect(p.drawn[1][i].dy, greaterThan(p.zeroY));
        } else {
          expect(p.drawn[1][i].dy, lessThan(p.zeroY));
        }
        expect(p.drawn[0][i].dy, lessThanOrEqualTo(p.drawn[1][i].dy));
      }
      // 売上の線は右肩上がり
      expect(p.drawn[0].last.dy, lessThan(p.drawn[0].first.dy));
    });

    testWidgets('数字タブに出て、幅390で崩れない', (tester) async {
      final ctl = await _ctl();
      final g = Game.newGame(SetupConfig(mode: 'world', year: 1980, traits: ['charm', 'gambler']), rng: ParkMiller(2024));
      for (var i = 0; i < 40; i++) {
        botMonth(g);
      }
      resolveEvents(g);
      g.calcAll();
      ctl.game = g;
      ctl.tab = 'num';
      tester.view.physicalSize = const Size(390, 5000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(QuadrillionApp(controller: ctl));
      await tester.pump();
      expect(find.text('売上と利益の推移（月）'), findsOneWidget);
      expect(find.bySemanticsLabel('売上と利益の推移'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
