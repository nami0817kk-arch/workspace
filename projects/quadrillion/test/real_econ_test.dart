// 本物の経済（1.1.0+25）：統計の読み込み・補い方・予測・極端な値でも壊れないこと
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';

bool _fine(double v) => v.isFinite && !v.isNaN;

void main() {
  test('統計を読むと24か国がそろい、1980〜2025年の全部の年に null が無い', () {
    final d = EconData.current!;
    expect(d.provisional, isFalse);
    for (final c in CTRY) {
      final k = d.countries[c.c];
      expect(k, isNotNull, reason: c.c);
      for (var y = 1980; y <= 2025; y++) {
        final e = d.year(c.c, y);
        for (final key in EconYear.keys) {
          final v = e.get(key);
          expect(v != null && _fine(v), isTrue, reason: '${c.c} $y $key');
        }
      }
    }
  });

  test('物価は上昇率から指数に積み上げる（日本の2020年→2024年は上がる）', () {
    final d = EconData.current!;
    expect(d.year('jp', 2024).cpi! > d.year('jp', 2020).cpi!, isTrue);
    // ブラジルのハイパーインフレでも有限
    expect(_fine(d.year('br', 1994).cpi!), isTrue);
  });

  test('ロシアは1991年まで選べない・出られない', () {
    final d = EconData.current!;
    expect(d.availableFrom('ru') > 1990, isTrue);
    expect(d.availableFrom('jp'), 1980);
    final g = Game.newGame(SetupConfig(year: 1980, traits: ['careful', 'charm']), rng: math.Random(3));
    expect(g.ctryOpen('ru'), isFalse);
    expect(g.ctryOpen('us'), isTrue);
  });

  test('2026年より先は予測。同じ種なら同じ数字、種が違えば違う数字', () {
    final d = EconData.current!;
    d.fcSeed = 11;
    final a = d.year('jp', 2040).gdpGrowth;
    d.fcSeed = 12;
    final b = d.year('jp', 2040).gdpGrowth;
    d.fcSeed = 11;
    expect(d.year('jp', 2040).gdpGrowth, a);
    expect(a == b, isFalse);
    for (final c in CTRY) {
      for (final key in EconYear.keys) {
        expect(_fine(d.year(c.c, 2060).get(key)!), isTrue, reason: '${c.c} 2060 $key');
      }
    }
  });

  for (final home in ['vn', 'sa', 'ru', 'br', 'ng', 'it']) {
    test('極端な値・null の多い国（$home）で始めても落ちず、NaN が出ない', () {
      for (final y in [1980, 2000, 2025]) {
        final g = Game.newGame(SetupConfig(year: y, home: home, traits: ['careful', 'charm']), rng: math.Random(y));
        g.startBiz(g.liveInds().firstWhere((i) => g.capexOf(i) <= g.cash).id);
        for (var i = 0; i < 30; i++) {
          g.nextQuarter();
          g.events.clear();
          for (final v in [g.cash, g.cap, g.pre, g.rev, g.econ, g.nom(), g.rateOf(home), g.corpTaxRate(), g.wageIdx(home), g.minWageYen(home), g.borrowLimit(), g.loanRate()]) {
            expect(_fine(v), isTrue, reason: '$home $y month $i');
          }
        }
        expect(g.rateOf(home) <= 30, isTrue);
      }
    });
  }

  test('仮のファイルの形（指数の物価・印つき）も読める', () {
    final d = EconData.parse(File('test/fixtures/econ_provisional.json').readAsStringSync(), codes: [for (final c in CTRY) c.c], shape: cwShape);
    expect(d.provisional, isTrue);
    expect(d.countries['us']!.synthetic, isFalse);
    expect(d.countries['in']!.synthetic, isTrue);
    expect(_fine(d.year('in', 2000).gdpUsd!), isTrue);
  });
}
