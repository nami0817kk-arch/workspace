import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';
import '../support/bot.dart';

void main() {
  test('prof', () {
    final g = Game.newGame(SetupConfig(mode: 'endless', year: 2025, traits: ['charm', 'gambler']), rng: ParkMiller(2024));
    for (var i = 0; i < 420; i++) { botMonth(g); }
    resolveEvents(g);
    g.calcAll();
    void t(String n, void Function() f, [int k = 50]) {
      f();
      final sw = Stopwatch()..start();
      for (var i = 0; i < k; i++) { f(); }
      print('$n ${(sw.elapsedMicroseconds / k / 1000).toStringAsFixed(3)}ms');
    }
    print('cos ${g.cos.length} alive ${g.cos.where((c)=>c.alive).length} cobiz ${g.cos.fold(0,(s,c)=>s+c.biz.length)} inds ${g.inds.length}');
    t('calcAll', g.calcAll);
    t('totals', g.totals);
    t('rankList', g.rankList);
    t('toJson', g.toJson);
    final j = g.toJson();
    t('jsonEncode', () => jsonEncode(j));
    print('json len ${jsonEncode(j).length}');
    final sizes = <String,int>{for (final e in j.entries) e.key: jsonEncode(e.value).length};
    final top = sizes.entries.toList()..sort((a,b)=>b.value-a.value);
    print(top.take(8).toList());
    t('scaleLoop', () { for (final ind in g.inds) { for (final c in g.cos) { for (final b in c.biz) { if (b.ind == ind.id) b.power *= 1; } } } });
    t('mktAll', () { for (final ind in g.inds) { g.mkt(ind); } });
    t('liveInds', g.liveInds);
    t('advice', g.advice);
    t('goalText', g.goalText);
    t('stageName', g.stageName);
    t('officeName', g.officeName);
    t('subs', g.subs);
    void N(String m, [String t = '']) {}
    t('rivalAI', () => g.rivalAI(N));
    t('dealsMonthly', () => g.dealsMonthly(N));
    t('dirtyMonthly', () => g.dirtyMonthly(N));
    t('rivalReturns', () => g.rivalReturns(N));
    t('storyMonthly', () { g.storyMonthly(N); g.events.clear(); });
    t('localMonthly', () => g.localMonthly(N));
    t('crisisMonthly', () { g.crisisMonthly(); g.events.clear(); });
    t('rollEvents', () { g.rollEvents(N); g.events.clear(); });
    t('moneyChecks', () => g.moneyChecks(N));
    t('mkCo', () { g.mkCo(0, 'food'); g.cos.removeLast(); }, 20);
    t('nextQuarter', () { resolveEvents(g); g.nextQuarter(); }, 30);
  });
}
