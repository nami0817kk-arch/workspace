// 社員の特性 70種類（1.1.0+33。企画書「社員の特性」2026-11-26）：
// 70種がそろい、どれも実際の数に効くこと・古いセーブ（特性1つ）の移し替え・見えない特性は「？？？」・経験で付く/消える・相性・まれな特性の割合
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';
import 'package:quadrillion/ui/app.dart';
import 'package:quadrillion/ui/controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/bot.dart';
import 'support/shots.dart';

void _n(String m, [String t = '']) {}

/// 効き目を見る盤面: 1990年・日本（社長は人たらしでない）。古い店・工場・新しい開発（海外にも出ている・宿敵がいる）・営業・医療かエネルギーの事業
Game _env() {
  final g = Game.newGame(SetupConfig(year: 1990, home: 'jp', traits: const ['gambler', 'careful']), rng: ParkMiller(5));
  g.cash = 1e13;
  final picks = <Industry>[
    IND.firstWhere((i) => kindOf(i) == 'shop' && i.b <= 1950 && eraF(i, 1990) > 0),
    IND.firstWhere((i) => kindOf(i) == 'factory' && i.b <= 1950 && eraF(i, 1990) > 0),
    IND.firstWhere((i) => i.key == 'kai' && i.b >= 1978 && i.b <= 1990 && eraF(i, 1990) > 0),
    IND.firstWhere((i) => i.key == 'ei' && kindOf(i) != 'shop' && i.b <= 1960 && eraF(i, 1990) > 0),
    IND.firstWhere((i) => (i.cat == 'med' || i.cat == 'ene') && i.b <= 1960 && eraF(i, 1990) > 0),
  ];
  for (final i in picks) {
    g.hUsed = 0;
    g.startBiz(i.id);
  }
  expect(g.biz.length, picks.length);
  // 開発の事業は海外にも出ていて、宿敵が同じ業種にいる
  final dev = g.biz[2];
  dev.ctry = ['jp', 'us', 'cn'];
  final foe = g.cos.firstWhere((c) => c.alive && c.rival != null && c.parent != 'player');
  foe.biz.add(CoBiz(ind: dev.ind, power: 1));
  g.calcAll();
  return g;
}

Person _p(Game g, List<String> traits, {int id = 900001}) {
  final p = g.mkPerson(0)
    ..id = id
    ..age = 40
    ..amb = 50
    ..loy = 40
    ..health = 50
    ..str = 50
    ..tenure = 30
    ..married = true
    ..kidsAge = []
    ..care = false
    ..partner = false
    ..fac = null
    ..grudge = false;
  p.traits = [...traits];
  p.tseen = [...traits];
  p.salary = g.mktPay(p) * .8;
  return p;
}

/// その人を置いたときの数をたくさん並べる（同じ盤面・同じ乱数の並びで、特性だけを変えて比べる）
List<double> _probe(List<String> traits) {
  final out = <double>[];
  void add(num v) => out.add(v.toDouble());
  for (final mode in ['normal', 'crisis', 'recession']) {
    final g = _env();
    g.trSeed = 12345;
    if (mode == 'crisis') g.bankCtl = 3;
    if (mode == 'recession') g.econ = .9;
    final p = _p(g, traits);
    final o = _p(g, ['grit'], id: 900002)
      ..age = 25
      ..tenure = 3;
    g.staff.addAll([p, o]);
    // 責任者として置いたときの、事業ごとの数
    for (final b in g.biz) {
      b.mgr = p.id;
      final ind = indm[b.ind]!;
      final pr0 = b.profit;
      b.profit = -1;
      add(g.trPowF(b, p));
      b.profit = pr0;
      add(g.trPowF(b, p));
      add(g.trCrewF(b));
      add(g.trMg(b, p, ind));
      add(g.trHitAdd(b));
      add(g.trMissAdd(b));
      add(g.mgrMult(b));
      g.rng = ParkMiller(3);
      final pr = g.proposalFor(p);
      add(pr?.cost ?? -1);
      add(pr?.k.hashCode ?? -1);
      b.mgr = null;
    }
    g.biz.first.mgr = p.id;
    g.calcAll();
    add(g.biz.first.profit);
    // 会社に1人いるときの数
    final c = g.cos.firstWhere((c) => c.alive && c.parent != 'player' && c.rival == null);
    add(g.trHqF());
    add(g.trScandalF());
    add(g.trDealPriceF());
    add(g.trBlockF());
    add(g.ipoMonths());
    add(g.ddMonths(c));
    add(g.itCost());
    add(g.techCost(g.biz[2]));
    add(g.hireMarket().q);
    add(g.tobChance(c, 51));
    add(g.dirtyRisk('spy', c));
    add(g.trWideCand(0) == null ? 0 : 1);
    add(g.trTeachF(o));
    add(g.trGrowF(o));
    add(g.trQuitF(o, 1));
    add(g.trHealthF(p));
    add(g.trQuitF(p, .8));
    add(g.trQuitF(p, 1));
    add(g.trGrowF(p));
    add(g.trHelpF(p));
    add(g.poachRisk(p) ? 1 : 0);
    add(g.refusesPosting(p) ? 1 : 0);
    // 扱い方への反応（海外の事業の責任者にする・ほかの人に替える・昇給・叱る）
    final dev = g.biz[2];
    final l0 = p.loy;
    g.setManager(dev, p.id);
    add(p.loy - l0);
    final l1 = p.loy;
    g.setManager(dev, o.id);
    add(p.loy - l1);
    add(p.grudge ? 1 : 0);
    p.loy = 40;
    p.grudge = false;
    p.salary = g.mktPay(p) * .8;
    g.hUsed = 0;
    g.raisePay(p);
    add(p.loy);
    p.loy = 40;
    g.hUsed = 0;
    g.trSeed = 777;
    g.scold(p);
    add(p.loy);
    add(p.health);
    add(g.staff.contains(p) ? 1 : 0);
    add(p.grudge ? 1 : 0);
    if (!g.staff.contains(p)) g.staff.add(p);
    // 1か月（周りの人のやる気・健康・見えてくる）
    p
      ..loy = 40
      ..health = 50
      ..grudge = false;
    o.loy = 40;
    g.trSeed = 4242;
    g.rng = ParkMiller(9);
    g.biz.first.mgr = p.id;
    g.monthPeople(_n);
    g.trMonth(_n);
    add(p.loy);
    add(o.loy);
    add(p.health);
    // 何度も起きる出来事（酒の席・使い込み・漏れ・事故・独立・派閥・手の早さ・客をつなぎ止める）
    var scandals = 0, gone = 0, fac = 0, events = 0;
    var cash = 0.0, left = 0, rivalPow = 0.0, keep = 0, dodge = 0;
    final b0 = g.biz[2];
    for (var i = 0; i < 400; i++) {
      if (!g.staff.contains(p)) {
        gone++;
        g.staff.add(p);
      }
      if (!g.staff.contains(o)) g.staff.add(o);
      g.scandal = 0;
      g.events.clear();
      final c0 = g.cash;
      p.loy = 30;
      o.fac = null;
      p.grudge = false;
      b0.mgr = p.id;
      g.biz.first.mgr = null;
      b0.pipe = [Pipe(k: 'dev', cost: 1, left: 5), Pipe(k: 'open', c: 'x', cost: 1, left: 5)];
      final fp = foePow(g, b0);
      g.trMonth(_n);
      scandals += g.scandal;
      cash += g.cash - c0;
      if (o.fac != null) fac++;
      events += g.events.length;
      left += b0.pipe.fold(0, (a, x) => a + x.left);
      rivalPow += foePow(g, b0) - fp;
      if (g.trKeepClient(b0, _n)) keep++;
      if (g.trDodgePoach(p)) dodge++;
    }
    for (final v in [scandals, gone, fac, events, cash, left, rivalPow, keep, dodge]) {
      add(v);
    }
    // 辞めたとき（ムードメーカー・派閥の頭・仲裁役）
    if (!g.staff.contains(p)) g.staff.add(p);
    o.loy = 40;
    final q = _p(g, ['grit', 'mood'], id: 900003);
    g.staff.add(q);
    g.fire(q, 'quit');
    add(o.loy);
    final ol = o.loy;
    o.loy = 40;
    g.fire(p, 'quit');
    add(o.loy - 40 + ol);
    add(g.staff.contains(o) ? 1 : 0);
  }
  return out;
}

double foePow(Game g, Biz b) => g.cos.where((c) => c.alive && c.parent != 'player').fold(0.0, (a, c) => a + c.biz.where((x) => x.ind == b.ind).fold(0.0, (s, x) => s + x.power));

void main() {
  group('特性の一覧', () {
    test('70種がそろい、分類ごとの数・まれな特性・今までの10種と同じ id・英語がある', () {
      expect(STAFF_TRAITS.length, 70);
      expect(STAFF_TRAITS.map((t) => t.id).toSet().length, 70);
      final n = <String, int>{};
      for (final t in STAFF_TRAITS) {
        n[t.cat] = (n[t.cat] ?? 0) + 1;
      }
      expect(n, {'old': 10, 'work': 12, 'rel': 12, 'val': 10, 'mind': 8, 'quirk': 10, 'shine': 8});
      expect(STAFF_TRAITS.where((t) => t.cat == 'old').map((t) => t.id).toList(), STRAITS.map((t) => t.id).toList());
      expect(STAFF_TRAITS.where((t) => t.rare).map((t) => t.id).toSet(), {'genius', ...STAFF_TRAITS.where((t) => t.cat == 'shine').map((t) => t.id)});
      final missing = <String>[
        for (final t in STAFF_TRAITS) ...[t.nJa, if (t.gJa.isNotEmpty) t.gJa, if (t.bJa.isNotEmpty) t.bJa],
        for (final c in STRAIT_CATS) c.$2,
        for (final c in PRES_COMPAT) c.$4,
        for (final c in STAFF_COMPAT) c.$3,
      ].where((k) => enText(k) == null).toList();
      expect(missing, isEmpty, reason: missing.join(' / '));
      for (final t in STAFF_TRAITS) {
        expect(t.gJa.isNotEmpty || t.bJa.isNotEmpty, isTrue, reason: t.id);
      }
    });

    test('70種のどれも、持つ人と持たない人で何かの数が変わる（札だけの特性は無い）', () {
      final base = _probe(['grit']);
      final none = <String>[];
      for (final t in STAFF_TRAITS) {
        final List<String> a, b;
        if (t.cat == 'old') {
          a = [t.id];
          b = [t.id == 'grit' ? 'careful' : 'grit'];
        } else {
          a = ['grit', t.id];
          b = ['grit'];
        }
        final x = _probe(a), y = t.id == 'grit' ? _probe(b) : base;
        var diff = false;
        for (var i = 0; i < x.length && !diff; i++) {
          if ((x[i] - y[i]).abs() > 1e-9 * (1 + y[i].abs())) diff = true;
        }
        if (!diff) none.add(t.id);
      }
      expect(none, isEmpty, reason: '効き目の見えない特性: ${none.join(', ')}');
    }, timeout: const Timeout(Duration(minutes: 10)));
  });

  group('人を作る', () {
    test('1人2〜4個。いちばん上は今までの10種。合わない組み合わせは持たない。天才肌と光るものはまれ', () {
      final g = Game.newGame(SetupConfig(year: 1990, home: 'jp', traits: const ['gambler', 'careful']), rng: ParkMiller(11));
      final count = <int, int>{};
      var rare = 0, genius = 0;
      const n = 3000;
      for (var i = 0; i < n; i++) {
        final p = g.mkPerson(0);
        count[p.traits.length] = (count[p.traits.length] ?? 0) + 1;
        expect(p.traits.length, inInclusiveRange(2, 4));
        expect(STRAITS.any((t) => t.id == p.trait), isTrue);
        expect(p.traits.skip(1).every((t) => stm[t]!.cat != 'old'), isTrue);
        expect(p.traits.toSet().length, p.traits.length);
        for (final a in p.traits) {
          for (final b in p.traits) {
            expect(straitNg(a, b), isFalse, reason: '$a と $b');
          }
        }
        if (p.traits.any((t) => stm[t]!.rare)) rare++;
        if (p.has('genius')) genius++;
        // はじめは1つだけ見える（社長が人たらしでなければ）
        expect(g.trVisible(p).length, 1);
      }
      // ignore: avoid_print
      print('特性の数: $count・まれな特性を持つ人 ${(rare / n * 100).toStringAsFixed(1)}%・天才肌 ${(genius / n * 100).toStringAsFixed(1)}%');
      expect(genius / n, inInclusiveRange(.015, .05), reason: '天才肌は今までの1割から3%ほどに');
      expect(rare / n, inInclusiveRange(.04, .12));
      expect(count[2]! > count[4]!, isTrue);
    });

    test('人たらしの社長だと、はじめに見える特性が1つ多い', () {
      final g = Game.newGame(SetupConfig(year: 1990, home: 'jp', traits: const ['charm', 'careful']), rng: ParkMiller(11));
      for (var i = 0; i < 50; i++) {
        final p = g.mkPerson(0);
        expect(g.trVisible(p).length, 2);
        expect(g.trSeen(p, p.trait), isTrue);
      }
    });

    test('試作との一致を見る遊び（extras を切る）では、特性は今までどおり1つで、新しい効き目は無い', () {
      final g = Game.newGame(SetupConfig(year: 1990, home: 'jp', traits: const ['charm', 'careful']), rng: ParkMiller(11), extras: false);
      for (var i = 0; i < 100; i++) {
        final p = g.mkPerson(0);
        expect(p.traits.length, 1);
      }
      expect(g.trSeed, 0, reason: '別の乱数の並びも使わない');
    });

    test('特性を引いても、ゲームの乱数の並びはずれない（同じ種で作った人の名前・能力・年齢が今までと同じ）', () {
      final a = Game.newGame(SetupConfig(year: 1990, home: 'jp', traits: const ['gambler', 'careful']), rng: ParkMiller(21));
      final b = Game.newGame(SetupConfig(year: 1990, home: 'jp', traits: const ['gambler', 'careful']), rng: ParkMiller(21));
      b.trSeed = 999; // 別の並びの種だけを変える
      for (var i = 0; i < 30; i++) {
        final x = a.mkPerson(0), y = b.mkPerson(0);
        expect(y.name, x.name);
        expect(y.age, x.age);
        expect(y.ab['tou'], x.ab['tou']);
        expect(y.amb, x.amb);
      }
    });
  });

  group('古いセーブ', () {
    test('特性が1つのセーブを読むと、その1つを残して2〜4個になり、落ちない', () {
      final g = Game.newGame(SetupConfig(mode: 'world', year: 1990, traits: const ['charm', 'careful']), rng: ParkMiller(7));
      for (var m = 0; m < 36 && g.over == null; m++) {
        botMonth(g, units: true, focus: true);
      }
      resolveEvents(g);
      while (g.staff.length < 3 && g.cands.isNotEmpty) {
        g.hUsed = 0;
        g.cash += 1e9;
        g.hire(g.cands.first);
      }
      final j = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
      // 1.1.0+32 までの形に戻す（特性は trait の1つだけ）
      final olds = <String, String>{};
      for (final k in ['staff', 'cands', 'alumni']) {
        for (final e in (j[k] as List)) {
          final m = e as Map<String, dynamic>;
          m.remove('traits');
          m.remove('ts');
          m.remove('fac');
          m.remove('gru');
          m.remove('hm');
          olds['${m['id']}'] = m['trait'] as String;
        }
      }
      j.remove('trs');
      j.remove('trf');
      j.remove('trc');
      final back = Game.fromJson(j, rng: ParkMiller(1));
      expect(back.staff, isNotEmpty);
      for (final p in [...back.staff, ...back.cands]) {
        expect(p.trait, olds['${p.id}'], reason: '今の1つは残る');
        expect(p.traits.length, inInclusiveRange(2, 4));
        expect(back.trVisible(p), isNotEmpty);
      }
      // 続きを回しても落ちない
      for (var m = 0; m < 12 && back.over == null; m++) {
        botMonth(back, units: true, focus: true);
      }
      // 新しい形のセーブは、そのまま読み戻せる
      final again = Game.fromJson(jsonDecode(jsonEncode(back.toJson())) as Map<String, dynamic>, rng: ParkMiller(1));
      for (var i = 0; i < back.staff.length; i++) {
        expect(again.staff[i].traits, back.staff[i].traits);
        expect(again.staff[i].tseen, back.staff[i].tseen);
      }
      expect(again.trSeed, back.trSeed);
    });
  });

  group('見える・付く・消える', () {
    test('働いた月日と話を聞くことで、隠れた特性が分かる', () {
      final g = _env();
      final p = _p(g, ['grit', 'neat', 'mood', 'drunk'])
        ..tseen = ['neat']
        ..traitKnown = false
        ..tenure = 7;
      g.staff.add(p);
      expect(g.trHidden(p), 3);
      p.tenure = 8;
      g.trMonth(_n);
      expect(g.trHidden(p), 2, reason: '8か月ごとに1つ見える');
      var talks = 0;
      while (g.trHidden(p) > 0 && talks < 40) {
        g.hUsed = 0;
        // 1.1.0+38 から、同じ人の話を聞くのは月に1回まで。1回ずつ月を替える
        g.turn++;
        g.talkTo(p);
        talks++;
      }
      expect(g.trHidden(p), 0);
      expect(g.trFound, containsAll(['neat', 'mood', 'drunk', 'grit']));
    });

    test('修羅場を越えると「肝が据わっている」が付き、「打たれ弱い」が抜ける。責任者を3年続けると「面倒見がいい」が付くことがある', () {
      var steel = 0, fragileGone = 0, mentor = 0;
      for (var s = 0; s < 40; s++) {
        final g = _env();
        g.trSeed = 1000 + s;
        final p = _p(g, ['grit', 'fragile']);
        g.staff.add(p);
        g.biz.first.mgr = p.id;
        g.bankCtl = 5;
        g.q = 12;
        g.trCrisisM = 5;
        p.headM = 35;
        g.trMonth(_n);
        if (p.has('steel')) steel++;
        if (!p.has('fragile')) fragileGone++;
        if (p.has('mentor')) mentor++;
      }
      expect(steel, greaterThan(3));
      expect(fragileGone, steel, reason: '肝が据わると打たれ弱さが抜ける（合わない組み合わせは入れ替わる）');
      expect(mentor, greaterThan(3));
    });

    test('特性は4つまで。いちばん上の今までの特性は消えない', () {
      final g = _env();
      final p = _p(g, ['grit', 'neat', 'mood', 'drunk']);
      g.staff.add(p);
      g.bankCtl = 5;
      g.q = 12;
      g.trCrisisM = 5;
      for (var s = 0; s < 20; s++) {
        g.trSeed = 50 + s;
        g.trMonth(_n);
        expect(p.traits.length, lessThanOrEqualTo(4));
        expect(p.trait, 'grit');
      }
    });
  });

  group('相性', () {
    test('ワンマンの社長とプライドが高い人は、ほかの社長のときよりやる気が下がる', () {
      double run(List<String> pt) {
        final g = Game.newGame(SetupConfig(year: 1990, home: 'jp', traits: pt), rng: ParkMiller(5));
        g.trSeed = 1;
        final p = _p(g, ['grit', 'proud'])..age = 20;
        g.staff.add(p);
        g.trMonth(_n);
        return p.loy;
      }

      expect(run(['oneman', 'careful']), lessThan(run(['gambler', 'careful'])));
      expect(run(['noble', 'careful']), greaterThan(run(['gambler', 'careful'])));
    });

    test('派閥を作る人が2人いると揉めごとが起き、仲裁役がいると痛手は半分', () {
      double hit({required bool med}) {
        final g = _env();
        final a = _p(g, ['grit', 'faction'], id: 1), b = _p(g, ['grit', 'faction'], id: 2);
        g.staff.addAll([a, b]);
        if (med) g.staff.add(_p(g, ['grit', 'mediate'], id: 3));
        GameEvent? e;
        for (var i = 0; i < 2000 && e == null; i++) {
          g.trMonth(_n);
          e = g.events.where((x) => msgKey(x.title) == '派閥の揉めごと').firstOrNull;
        }
        expect(e, isNotNull);
        a.loy = 60;
        b.loy = 60;
        e!.choices.first.f();
        // 肩を持たなかった方（頭）のやる気の下がり方
        return 60 - math.min(a.loy, b.loy);
      }

      final full = hit(med: false), half = hit(med: true);
      expect(full, 15);
      expect(half, 7.5);
    });

    test('面倒見がいい人がいると、入って2年までの若手が辞めにくく、よく育つ', () {
      final g = _env();
      final young = _p(g, ['grit'], id: 5)
        ..age = 24
        ..tenure = 6;
      g.staff.add(young);
      final q0 = g.trQuitF(young, 1), g0 = g.trGrowF(young);
      g.staff.add(_p(g, ['grit', 'mentor'], id: 6));
      expect(g.trQuitF(young, 1), lessThan(q0));
      expect(g.trGrowF(young), greaterThan(g0));
      expect(g.trCompat(young).map(msgKey), contains('面倒見がいい人がいると、入って2年までの人がよく育ち、辞めにくい'));
    });
  });

  group('画面（日英・横の2つの大きさ）', () {
    setUpAll(loadRealFonts);
    final cjk = RegExp(r'[぀-ヿ㐀-鿿]');
    for (final size in const [Size(844, 390), Size(1194, 834)]) {
      for (final lang in const ['ja', 'en']) {
        testWidgets('人の特性の札と説明・採用の候補・図鑑 ${size.width.round()}×${size.height.round()}（$lang）', (tester) async {
          final g = _env();
          g.trSeed = 31;
          final p = _p(g, ['oneman', 'perfect', 'mood', 'drunk'])
            ..tseen = ['perfect', 'mood']
            ..traitKnown = false;
          g.staff.add(p);
          g.staff.add(_p(g, ['grit', 'fragile'], id: 900007)..tseen = ['fragile']);
          g.biz.first.mgr = p.id;
          g.cands = [for (var i = 0; i < 4; i++) g.mkPerson(.5)..src = 'mid'];
          g.trFound.addAll(['perfect', 'mood', 'fragile', 'charisma', 'grit']);
          g.ensureFaces();
          SharedPreferences.setMockInitialValues({});
          final prefs = await SharedPreferences.getInstance();
          final ctl = GameController(prefs: prefs, newRandom: () => ParkMiller(77), lang: lang);
          L.lang = lang;
          addTearDown(() => L.lang = 'ja');
          ctl.game = g;
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final key = GlobalKey();
          await tester.pumpWidget(RepaintBoundary(key: key, child: QuadrillionApp(controller: ctl)));
          await tester.pump();
          Future<void> check(String name) async {
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
            expect(tester.takeException(), isNull, reason: name);
            if (lang == 'en') {
              for (final w in tester.widgetList<RichText>(find.byType(RichText))) {
                expect(cjk.hasMatch(w.text.toPlainText()), isFalse, reason: '$name: 英語の画面に日本語「${w.text.toPlainText()}」');
              }
            }
            await shot(tester, key, 'traits_${size.width.round()}x${size.height.round()}_${lang}_$name', pixelRatio: 1.5);
          }

          ctl.setTab('people');
          ctl.setPeopleSeg('mgr');
          ctl.selectPerson(p.id);
          ctl.toggleShown('trait-${p.id}-perfect');
          await check('person');
          // 札のところまで送って撮る
          await tester.ensureVisible(find.byKey(ValueKey('ptrait-desc-${p.id}-perfect')));
          await check('person-traits');
          ctl.setPeopleSeg('cand', src: 'mid');
          ctl.selectPerson(g.cands.first.id);
          await check('cand');
          await tester.ensureVisible(find.byKey(ValueKey('ptrait-${g.cands.first.id}-${g.trVisible(g.cands.first).first}')));
          await check('cand-traits');
          ctl.setTab('zukan');
          ctl.setZukan('trait');
          await check('zukan');
        });
      }
    }
  });

  group('画面', () {
    testWidgets('人の画面: 見えている特性は札、見えていない特性は「？？？」。札を押すと効き目が開く', (tester) async {
      final g = _env();
      final p = _p(g, ['grit', 'neat', 'drunk'])
        ..tseen = ['neat']
        ..traitKnown = false;
      g.staff.add(p);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final ctl = GameController(prefs: prefs, newRandom: () => ParkMiller(77));
      ctl.game = g;
      tester.view.physicalSize = centerAs(const Size(1194, 834));
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(QuadrillionApp(controller: ctl));
      await tester.pump();
      ctl.setTab('people');
      ctl.setPeopleSeg('exec');
      ctl.selectPerson(p.id);
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('ptrait-${p.id}-neat')), findsOneWidget);
      expect(find.byKey(ValueKey('ptrait-${p.id}-hidden-0')), findsOneWidget, reason: 'いちばん上の特性もまだ見えない');
      expect(find.byKey(ValueKey('ptrait-${p.id}-hidden-2')), findsOneWidget);
      expect(find.text('？？？'), findsNWidgets(2));
      expect(find.text('酒癖が悪い'), findsNothing);
      await tester.tap(find.byKey(ValueKey('ptrait-${p.id}-neat')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('ptrait-desc-${p.id}-neat')), findsOneWidget);
      expect(find.textContaining('経費のむだ'), findsOneWidget);
    });
  });
}
