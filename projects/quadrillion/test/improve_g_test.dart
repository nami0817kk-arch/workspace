import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';
import 'package:quadrillion/ui/sheets.dart';
import 'package:quadrillion/ui/widgets.dart';

import 'support/bot.dart';
import 'support/grown.dart';
import 'support/pilot.dart';
import 'support/shots.dart';

String? _grownJson;

/// 育った会社（1985年から25年）。作るのは1回だけで、あとは写しを返す
Game _grown([int seed = 5]) {
  _grownJson ??= jsonEncode(grownGame().toJson());
  return Game.fromJson(jsonDecode(_grownJson!) as Map<String, dynamic>, rng: ParkMiller(seed))
    ..events.clear()
    ..calcAll();
}

final _ph = RegExp(r'\{\d+\}');
final _cjk = RegExp(r'[぀-ヿ㐀-鿿]');

/// 文に {0} が残っていない・空でない・英語に日本語が残っていない
void _ok(String m, [String what = '']) {
  for (final lang in const ['ja', 'en']) {
    final t = txIn(m, lang);
    expect(t.trim(), isNotEmpty, reason: '$what（$lang）が空');
    expect(_ph.hasMatch(t), isFalse, reason: '$what（$lang）: $t');
    if (lang == 'en') expect(_cjk.hasMatch(t), isFalse, reason: '$what（en）: $t');
  }
}

void _okEvent(GameEvent e, String what) {
  _ok(e.title, '$what 題');
  _ok(e.text, '$what 文');
  for (final c in e.choices) {
    _ok(c.l, '$what 選択肢');
    _ok(c.s, '$what 説明「${txIn(c.l, 'ja')}」');
  }
}

/// その国に事業を出し、事件の年の幅の中に年を合わせる
Game _in(CeDef d) {
  final g = _grown();
  final top = (g.biz.toList()..ssort((a, b) => b.rev.compareTo(a.rev))).first;
  if (!g.ctryOf(top).contains(d.c)) top.ctry = [...g.ctryOf(top), d.c];
  g.year = d.y0 > g.year
      ? d.y0
      : d.y1 < g.year
          ? d.y1
          : g.year;
  g.cash = 1e15;
  g.calcAll();
  return g;
}

/// 張り合う段の宿敵を1社、型を決めて用意する
(Game, Company) _foe(String type, {int grudge = 0, int favor = 0}) {
  final g = _grown();
  final c = g.cos.firstWhere((x) => x.alive && x.rival != null && x.parent != 'player' && x.biz.isNotEmpty);
  c.rival!
    ..label = type
    ..st = 1
    ..grudge = grudge
    ..favor = favor
    ..hurt = 0;
  // 育てるあいだに起きた場面の「間をあける」控えは消しておく
  g.crisis.removeWhere((k, v) => k.startsWith('rs:'));
  g.cash = 1e15;
  g.calcAll();
  return (g, c);
}

/// 1.0.0+19（改善の回G）：中盤に起きることを増やす
void main() {
  group('国ごとの事件', () {
    test('24か国それぞれに2種類以上。良い・悪い・選ぶがあり、選ぶ事件は2〜3択で、どの選択肢にも得と損がある', () {
      expect(countryEvents.map((d) => d.id).toSet().length, countryEvents.length, reason: '同じ名前の事件がある');
      for (final c in CTRY) {
        final l = countryEvents.where((d) => d.c == c.c).toList();
        expect(l.length, greaterThanOrEqualTo(2), reason: c.ja);
        expect(l.map((d) => d.kind).toSet().length, greaterThanOrEqualTo(2), reason: '${c.ja}: 種類が1つだけ');
        // いつの時代に始めても起こせる事件が1つはある
        expect(l.where((d) => d.y0 == 0 && d.y1 == 9999), isNotEmpty, reason: '${c.ja}: 年の幅の無い事件が無い');
      }
      expect(countryEvents.map((d) => d.c).toSet(), CTRY.map((c) => c.c).toSet());
      for (final k in const ['good', 'bad', 'pick']) {
        expect(countryEvents.where((d) => d.kind == k).length, greaterThanOrEqualTo(20), reason: k);
      }
      for (final d in countryEvents.where((d) => d.kind == 'pick')) {
        expect(d.opts.length, inInclusiveRange(2, 3), reason: d.id);
        for (final o in d.opts) {
          // 損：お金を払う・力が落ちる・忠誠や評判が下がる・裏目に出るかもしれない
          final loss = o.u > 0 || o.fine > 0 || o.pow < 0 || o.loy < 0 || o.rep < 0 || o.sc > 0 || o.risk > 0;
          // 得：お金がかからない・お金が入る・力が上がる・忠誠や評判が上がる
          final gain = (o.u == 0 && o.fine == 0) || o.gain > 0 || o.pow > 0 || o.loy > 0 || o.rep > 0;
          expect(loss && gain, isTrue, reason: '${d.id}「${o.l}」');
        }
        // どれか1つが、ほかの全部より得で損が無い、ということが無い（勝ち筋が1つに決まらない）
        expect(d.opts.where((o) => o.u == 0 && o.fine == 0 && o.pow >= 0 && o.loy >= 0 && o.rep >= 0 && o.risk == 0), isEmpty, reason: d.id);
      }
      for (final d in countryEvents.where((d) => d.kind != 'pick')) {
        expect(d.kind == 'good' ? d.pow > 0 || d.gain > 0 : d.pow < 0 || d.fine > 0, isTrue, reason: d.id);
      }
    });

    test('全部の事件が出せて、文に {0} の抜けが無く、日英がそろっている。選択肢はどれも選べる', () {
      var picks = 0, news = 0;
      for (final d in countryEvents) {
        final g = _in(d);
        expect(g.ceCan(d), isTrue, reason: d.id);
        final out = <LogEntry>[];
        final ev = g.ceFire(d, (m, [t = '']) => out.add(LogEntry(m, t)), s: 1);
        if (d.kind != 'pick') {
          news++;
          expect(ev, isNull);
          expect(out.single.t, d.kind == 'bad' ? 'bad' : 'big');
          _ok(out.single.m, d.id);
          expect(txIn(out.single.m, 'ja'), contains(txIn(M(d.title), 'ja')));
          continue;
        }
        picks++;
        _okEvent(ev!, d.id);
        expect(ev.choices.length, d.opts.length);
        for (var i = 0; i < d.opts.length; i++) {
          final g2 = _in(d);
          final e2 = g2.ceFire(d, (m, [t = '']) {}, s: 1)!;
          final cash0 = g2.cash;
          _ok(e2.choices[i].f(), '${d.id} 結果$i');
          final o = d.opts[i];
          if (o.u > 0 || o.fine > 0) expect(g2.cash, lessThan(cash0), reason: '${d.id} $i');
          if (o.gain > 0 && o.u == 0 && o.fine == 0) expect(g2.cash, greaterThan(cash0), reason: '${d.id} $i');
        }
        // お金が足りないときは、いちばん下の選択肢と同じ結果になる（お金は減らない）
        final pay = d.opts.indexWhere((o) => o.u > 0);
        if (pay >= 0) {
          final g3 = _in(d);
          final e3 = g3.ceFire(d, (m, [t = '']) {}, s: 1)!;
          g3.cash = 0;
          final m = e3.choices[pay].f();
          _ok(m, '${d.id} 払えない');
          expect(txIn(m, 'ja'), contains('お金が足りず'));
          expect(g3.cash, d.opts.last.gain > 0 ? greaterThan(0) : 0);
        }
      }
      expect(picks, greaterThanOrEqualTo(24));
      expect(news, greaterThanOrEqualTo(40));
    });

    test('効き目はその国の分だけ。値段は1単位の固定額で、手元のお金や時価総額では変わらない', () {
      final d = countryEvents.firstWhere((d) => d.id == 'us_taxcut');
      final g = _in(d);
      final inUs = g.ceBiz('us'), out = g.biz.where((b) => !g.ctryOf(b).contains('us')).toList();
      expect(inUs, isNotEmpty);
      expect(out, isNotEmpty);
      final p0 = {for (final b in g.biz) b.id: b.power};
      g.ceFire(d, (m, [t = '']) {}, s: 1);
      for (final b in inUs) {
        final f = g.ceFrac(b, 'us');
        expect(b.power / p0[b.id]!, closeTo(1 + .05 * f, 1e-9));
        expect(f, inInclusiveRange(0, 1));
      }
      for (final b in out) {
        expect(b.power, p0[b.id]);
      }
      // 値段：その国でいちばん売れている事業の店・工場1つ分の何倍か
      final k = countryEvents.firstWhere((d) => d.id == 'mx_near');
      final g2 = _in(k);
      final unit = g2.ceUnit('mx');
      expect(unit, g2.capexOf(indm[g2.ceTop('mx')!]!));
      String desc(Game x) => txIn(x.ceFire(k, (m, [t = '']) {}, s: 1)!.choices.first.s, 'ja');
      final a = desc(g2);
      final g3 = _in(k)..cash = 5e16;
      expect(desc(g3), a, reason: '手元のお金で値段が変わった');
      expect(a, contains(txIn(Y(unit * 3), 'ja')));
    });

    test('年の幅の外では起きない。出ていない国の事件は起きない', () {
      final d = countryEvents.firstWhere((d) => d.id == 'uk_exit');
      final g = _in(d);
      g.year = 2010;
      expect(g.ceCan(d), isFalse);
      g.year = 2018;
      expect(g.ceCan(d), isTrue);
      for (final b in g.biz) {
        b.ctry = g.ctryOf(b).where((c) => c != 'uk').toList();
      }
      if (g.locals().any((c) => c.loc == 'uk')) return;
      expect(g.ceCan(d), isFalse);
    });

    test('間隔に上限がある：続けては起きず、出ている国が多くても確率は頭打ち。同じ事件は8年は繰り返さない。extras を切ると起きない', () {
      final g = _grown(9);
      // 全部の国に出ていることにする
      for (final b in g.biz.take(5)) {
        b.ctry = [for (final c in CTRY) c.c];
      }
      g.calcAll();
      expect(g.cePresent().length, 24);
      final at = <int>[];
      final seen = <String, int>{};
      var last = g.crisis['ce:last'] ?? -99;
      for (var m = 0; m < 240 && g.over == null; m++) {
        resolveEvents(g);
        g.nextQuarter();
        final now = g.crisis['ce:last'] ?? -99;
        if (now != last) {
          at.add(now);
          last = now;
          for (final e in g.crisis.entries.where((e) => e.key.startsWith('ce:') && e.key != 'ce:last' && e.value == now)) {
            if (seen[e.key] != null) expect(now - seen[e.key]!, greaterThanOrEqualTo(ceRepeat), reason: e.key);
            seen[e.key] = now;
          }
        }
      }
      // ignore: avoid_print
      print('[ce] 24か国・20年で ${at.length}件・${seen.length}種類');
      expect(at.length, greaterThan(8));
      for (var i = 1; i < at.length; i++) {
        expect(at[i] - at[i - 1], greaterThanOrEqualTo(ceGap));
      }
      // 頭打ち：毎月 ceMaxP、あいだを ceGap か月あけるので、20年で 240 ÷（ceGap ＋ 1/ceMaxP）の2倍を超えない
      expect(at.length, lessThan(240 / (ceGap + 1 / ceMaxP) * 2));
      final off = Game.newGame(SetupConfig(mode: 'endless', year: 1985, traits: const ['charm', 'careful']), rng: ParkMiller(9), extras: false);
      for (var m = 0; m < 180; m++) {
        botMonth(off);
      }
      expect(off.crisis.keys.where((k) => k.startsWith('ce:') || k.startsWith('rs:')), isEmpty);
    });
  });

  group('宿敵の張り合う場面', () {
    test('6種類の場面が、10の型それぞれの口ぶりで出せる。文に {0} の抜けが無く、日英がそろっている', () {
      expect(sceneTitle.keys.toSet(), sceneLines.keys.toSet());
      for (final k in sceneTitle.keys) {
        expect(sceneLines[k]!.keys.toSet(), RTYPE.ja.keys.toSet(), reason: k);
        // 型ごとに口ぶりが違う
        expect(sceneLines[k]!.values.toSet().length, RTYPE.ja.length, reason: k);
        for (final type in RTYPE.ja.keys) {
          final (g, c) = _foe(type);
          final ev = g.rivalScene(c, k);
          expect(ev, isNotNull, reason: '$k $type');
          _okEvent(ev!, '$k $type');
          expect(ev.choices.length, inInclusiveRange(2, 3), reason: '$k $type');
          expect(ev.who, c);
          expect(txIn(ev.text, 'ja'), contains(sceneLines[k]![type]!), reason: '$k $type');
          expect(sceneTitles.any((t) => msgKey(ev.title).startsWith(t)), isTrue);
        }
      }
    });

    test('どの選択肢も選べて、恨みと恩が動く', () {
      for (final k in sceneTitle.keys) {
        final (ga, ca) = _foe('peer');
        final n = ga.rivalScene(ca, k)!.choices.length;
        final moved = <String>{};
        for (var i = 0; i < n; i++) {
          final (g, c) = _foe('peer');
          final ev = g.rivalScene(c, k)!;
          final r = c.rival!;
          final g0 = r.grudge, f0 = r.favor, rel0 = c.rel;
          _ok(ev.choices[i].f(), '$k 結果$i');
          if (r.grudge > g0) moved.add('g');
          if (r.favor > f0) moved.add('f');
          if (c.rel != rel0) moved.add('rel');
          for (final t in r.ties) {
            _ok(t, '$k 因縁の記録');
          }
          // 続けて月を進めても壊れない
          for (var m = 0; m < 3; m++) {
            resolveEvents(g);
            g.nextQuarter();
          }
        }
        // 選び方で、関係か恨み・恩のどれかが変わる
        expect(moved, isNotEmpty, reason: k);
        // お金が足りないときも選べる（何も起きないか、流れる）
        final (g, c) = _foe('peer');
        final ev = g.rivalScene(c, k)!;
        g.cash = 0;
        _ok(ev.choices.first.f(), '$k お金なし');
        expect(g.cash, greaterThanOrEqualTo(-1e-6), reason: k);
      }
    });

    test('値段は相手や業種の1単位の額で、手元のお金や時価総額では変わらない', () {
      final (g, c) = _foe('peer');
      final t = g.bidTarget(c)!;
      expect(g.bidCost(t), t.cap * .65);
      expect(g.helpCost(c), c.rev * 3 > 1e7 * g.nom() ? c.rev * 3 : 1e7 * g.nom());
      final a = txIn(g.rivalScene(c, 'pact')!.choices.first.s, 'ja');
      final (g2, c2) = _foe('peer');
      g2.cash = 7e16;
      expect(txIn(g2.rivalScene(c2, 'pact')!.choices.first.s, 'ja'), a);
    });

    test('恨みが多いと攻める場面と値下げ合戦が、恩が多いと歩み寄る場面と提携の申し出が出やすい', () {
      final (g, c) = _foe('peer');
      final base = g.sceneWeights(c);
      expect(g.tieMood(c.rival!), 1);
      expect(g.tieWarm(c.rival!), 1);
      c.rival!.grudge = 4;
      final hot = g.sceneWeights(c);
      expect(hot['enter']!, greaterThan(base['enter']!));
      expect(hot['expose'], isNotNull);
      expect(hot['pact'], isNull, reason: '恨まれているあいだは、手を組む話は来ない');
      expect(g.tieMood(c.rival!), greaterThan(1));
      c.rival!
        ..grudge = 0
        ..favor = 3;
      final warm = g.sceneWeights(c);
      expect(warm['pact']!, greaterThan(base['pact']!));
      expect(warm['enter']!, lessThanOrEqualTo(base['enter']!));
      expect(g.tieMood(c.rival!), lessThan(1));
      expect(g.tieWarm(c.rival!), greaterThan(1));
      // 決着した宿敵・出会う前の宿敵には場面が無い
      c.rival!.st = 2;
      expect(g.sceneWeights(c), isEmpty);
      expect(g.tieMood(c.rival!), 1);
      c.rival!.st = 0;
      expect(g.sceneWeights(c), isEmpty);
      // extras を切ると 1 のまま（試作と同じ）
      c.rival!
        ..st = 1
        ..grudge = 4;
      g.extras = false;
      expect(g.tieMood(c.rival!), 1);
      expect(g.tieWarm(c.rival!), 1);
      expect(g.rivalScene(c, 'enter'), isNull);
    });

    test('場面は続けては起きず、同じ宿敵とは間をあける。ほかの選ぶ出来事がある月には出ない', () {
      final g = _grown(3);
      for (final c in g.cos.where((x) => x.alive && x.rival != null && x.parent != 'player')) {
        c.rival!.st = c.rival!.st == 2 ? 2 : 1;
      }
      final at = <int>[];
      final by = <int, int>{};
      for (var m = 0; m < 240 && g.over == null; m++) {
        resolveEvents(g);
        g.nextQuarter();
        final sc = g.events.where((e) => msgKey(e.title).startsWith('宿敵：')).toList();
        if (sc.isEmpty) continue;
        expect(sc.length, 1);
        expect(g.events.first, sc.single, reason: 'ほかの選ぶ出来事が先にある月に出た');
        final id = sc.single.who!.id;
        if (by[id] != null) expect(g.turn - by[id]!, greaterThanOrEqualTo(rsEach));
        by[id] = g.turn;
        at.add(g.turn);
      }
      // ignore: avoid_print
      print('[rs] 20年で ${at.length}場面・相手 ${by.length}社');
      expect(at.length, greaterThan(3));
      for (var i = 1; i < at.length; i++) {
        expect(at[i] - at[i - 1], greaterThanOrEqualTo(rsGap));
      }
    });
  });

  group('経営会議の提案の幅', () {
    List<Proposal> props(Game s, Biz b, String trait, {void Function(Person)? tune}) {
      final p = s.mkPerson(.5)
        ..trait = trait
        ..amb = 50
        ..tenure = 0;
      tune?.call(p);
      s.staff.add(p);
      for (final x in s.biz) {
        if (x.mgr == p.id) x.mgr = null;
      }
      b.mgr = p.id;
      final out = <Proposal>[];
      for (var i = 0; i < 400; i++) {
        final o = s.proposalFor(p);
        if (o != null) out.add(o);
      }
      for (final o in out) {
        _ok(o.l, '提案 ${o.k}');
        _ok(o.d, '提案の説明 ${o.k}');
      }
      return out;
    }

    Biz top(Game s) => (s.biz.where((b) => b.model == 'direct').toList()..ssort((a, b) => b.rev.compareTo(a.rev))).first;

    test('広告：打っていない事業にだけ出て、値段は画面の手と同じ。通すと6か月の広告が始まる', () {
      final s = _grown()..cash = 1e15;
      final b = top(s)..ad = 0;
      final o = props(s, b, 'grit').firstWhere((o) => o.k == 'ad');
      expect(o.cost, s.invBase(b) * .25);
      final c0 = s.cash;
      s.doProposal(o);
      expect(b.ad, 6);
      expect(s.cash, closeTo(c0 - o.cost, 1));
      expect(props(s, b, 'grit').where((o) => o.k == 'ad'), isEmpty, reason: '広告を打っているあいだは出ない');
    });

    test('海外：始めた国だけの事業の、最初の1か国だけ。通すと準備が始まり、2か国目は提案しない', () {
      final s = _grown()..cash = 1e15;
      final b = top(s)
        ..ctry = null
        ..pipe.clear();
      final l = props(s, b, 'grit').where((o) => o.k == 'abroad').toList();
      expect(l, isNotEmpty);
      final o = l.first;
      expect(o.c, isNot(s.home));
      expect(l.every((x) => x.c == o.c), isTrue, reason: '国はくじで選ばない');
      expect(o.cost, s.entryCost(b, o.c!, o.mode!));
      final ap0 = s.ap;
      s.doProposal(o);
      expect(s.ap, ap0, reason: '手は使わない');
      expect(b.pipe.where((x) => x.k == 'enter' && x.c == o.c), hasLength(1));
      expect(props(s, b, 'grit').where((o) => o.k == 'abroad'), isEmpty, reason: '準備中は出ない');
      b.pipe.clear();
      b.ctry = [s.home, o.c!];
      expect(props(s, b, 'grit').where((o) => o.k == 'abroad'), isEmpty, reason: '2か国目からは提案しない');
      // 払えないときは出ない
      b.ctry = null;
      s.cash = 1;
      expect(props(s, b, 'grit').where((o) => o.k == 'abroad'), isEmpty);
    });

    test('値付け・稼ぎ方・撤退・社風の提案が条件どおりに出て、通すとそのとおりになる', () {
      // 値下げをやめる
      var s = _grown()..cash = 1e15;
      var b = top(s)
        ..price = 'cut'
        ..war = 0
        ..share = .3;
      var o = props(s, b, 'grit').firstWhere((o) => o.k == 'price');
      s.doProposal(o);
      expect(b.price, 'normal');
      // 高くする（慎重な人）
      b.share = .3;
      o = props(s, b, 'careful').firstWhere((o) => o.k == 'price');
      s.doProposal(o);
      expect(b.price, 'premium');
      // 稼ぎ方
      s = _grown()..cash = 1e15;
      b = s.biz.firstWhere((x) => x.model == 'direct' && s.modelsFor(x.ind).length > 1)..age = 40;
      o = props(s, b, 'gambler').firstWhere((o) => o.k == 'model');
      final pw = b.power;
      s.doProposal(o);
      expect(b.model, isNot('direct'));
      expect(b.power, lessThan(pw));
      // 撤退
      s = _grown()..cash = 1e15;
      b = top(s)
        ..age = 40
        ..profit = -1
        ..share = .01
        ..pipe.clear();
      o = props(s, b, 'grit').firstWhere((o) => o.k == 'exit');
      final n = s.biz.length, c0 = s.cash, v = s.sellValue(b);
      s.doProposal(o);
      expect(s.biz.length, n - 1);
      expect(s.cash, closeTo(c0 + v, 1));
      // 社風（長く勤めた人だけ。10年に一度まで）
      s = _grown()..cash = 1e15;
      s.culture = 'merit';
      s.cultLeft = 0;
      s.crisis.remove('pc');
      b = top(s);
      expect(props(s, b, 'oneman').where((o) => o.k == 'culture'), isEmpty, reason: '入ったばかりの人は言い出さない');
      o = props(s, b, 'oneman', tune: (p) => p.tenure = 40).firstWhere((o) => o.k == 'culture');
      s.doProposal(o);
      expect(s.cultNext, 'sports');
      expect(s.cultLeft, 24);
      s.cultLeft = 0;
      s.culture = 'merit';
      expect(props(s, b, 'oneman', tune: (p) => p.tenure = 40).where((o) => o.k == 'culture'), isEmpty, reason: '10年に一度まで');
    });

    test('extras を切ると、新しい種類の提案は出ない', () {
      final s = _grown()..cash = 1e15;
      s.extras = false;
      final b = top(s)..ctry = null;
      final ks = props(s, b, 'grit', tune: (p) => p.tenure = 40).map((o) => o.k).toSet();
      expect(ks.intersection({'ad', 'abroad', 'price', 'model', 'exit', 'culture'}), isEmpty);
    });
  });

  group('中盤を数える', () {
    test('10〜30年目：何も起きない月が減り、宿敵の場面と提案の種類が増える。選ぶ出来事が重なる月は増えすぎない', () {
      final st = MidStats();
      for (final c in const [(2024, 1985), (31, 1980), (7, 1995)]) {
        measureMid(seed: c.$1, year: c.$2, into: st);
      }
      // ignore: avoid_print
      print('[mid-g] ${st.report()}');
      final tot = st.proposals.values.fold(0, (a, b) => a + b);
      // 前（1.0.0+18）: 544か月・何も起きない月 26.1%・選ぶ出来事が2つ以上の月 6.3%・宿敵の場面 6・
      //   提案 51件（店・工場25／新しい商品14／現場の人7／値下げ3／小さな改良1／維持費1）。3本のうち1本は途中で乗っ取られて終わっていた
      // 後（1.0.0+19）: 720か月・何も起きない月 18.5%・選ぶ出来事が2つ以上の月 9.3%・宿敵の場面 47（うち新しい場面46）・国の選ぶ事件 15・
      //   提案 78件（店・工場19／海外17／新しい商品12／現場の人11／広告8／大型開発4／値下げ3／稼ぎ方2／維持費2）
      expect(st.months, greaterThan(400));
      // 1.1.0+26（段2）で会社の伸びが遅くなり、中盤の大きな出来事（上場・乗っ取り・大きな買収）が減って、何も起きない月が増えた（18.5% → 約39%）。
      // 店が開く・責任者が育つ知らせは数えていない。出来事を足す後の段（人・宿敵・海外）で見直すまで、線を22%から45%に引き直す
      expect(st.quietPct, lessThan(45));
      // 1.1.0+27（段3：人）で、給料が相場より低い人も引き抜きの誘いの的になり、選ぶ出来事が重なる月が少し増えた（13〜16%）。線を12%から18%に引き直す
      expect(st.crowdedPct, lessThan(18));
      expect(st.scenes, greaterThan(12));
      expect((st.proposals['店・工場'] ?? 0) / tot, lessThan(.4));
      expect(st.proposals.keys.toSet().intersection({'広告', '海外', '値付け', '稼ぎ方', '撤退', '社風'}).length, greaterThanOrEqualTo(3));
      expect(st.events.keys.where((k) => k == '{0}：{1}'), isNotEmpty, reason: '国の選ぶ事件が1つも無い');
    }, timeout: const Timeout(Duration(minutes: 5)));
  });

  group('画面を目で見る（QUAD_SHOTS を渡したときだけ書き出す）', () {
    for (final lang in const ['ja', 'en']) {
      for (final w in const [390.0, 320.0]) {
        testWidgets('国の事件・宿敵の場面（$lang・幅${w.round()}）', (tester) async {
          await loadRealFonts();
          final key = GlobalKey();
          final (g, c) = _foe('zaibatsu', grudge: 3);
          final p = await Pilot.launch(tester, lang: lang, size: Size(w, 844), game: g, boundary: key);
          final tag = '${lang}_${w.round()}';
          Future<void> show(String name, GameEvent? e) async {
            expect(e, isNotNull, reason: name);
            g.events
              ..clear()
              ..add(e!);
            nextEvent(p.ctl);
            await p.pump();
            await p.sweep();
            await shot(tester, key, 'g_${name}_$tag', pixelRatio: 1.5);
            // いちばん上の選択肢を選んだ結果も見る
            g.cash = 1e15;
            await p.press(p.inSheet(find.byType(ChoiceBtn)).first, 'いちばん上の選択肢');
            await p.pump();
            await shot(tester, key, 'g_${name}_result_$tag', pixelRatio: 1.5);
            p.ctl.closeSheet();
            await p.pump();
          }

          Game at(String id) {
            final d = countryEvents.firstWhere((d) => d.id == id);
            final b = (g.biz.toList()..ssort((a, b) => b.rev.compareTo(a.rev))).first;
            if (!g.ctryOf(b).contains(d.c)) b.ctry = [...g.ctryOf(b), d.c];
            g.calcAll();
            return g;
          }

          for (final id in const ['us_probe', 'de_hours', 'ng_mobile']) {
            final d = countryEvents.firstWhere((d) => d.id == id);
            await show('ce_$id', at(id).ceFire(d, (m, [t = '']) {}, s: 1));
          }
          for (final k in sceneTitle.keys) {
            await show('rs_$k', g.rivalScene(c, k));
          }
          // 知らせ（良い・悪い）は、月の報告に出る
          final news = <LogEntry>[];
          for (final id in const ['jp_expo', 'th_flood', 'fr_tax']) {
            at(id).ceFire(countryEvents.firstWhere((d) => d.id == id), (m, [t = '']) => news.add(LogEntry(m, t)), s: 1);
          }
          g.events.clear();
          showReport(p.ctl, news, ReportBase.of(g));
          await p.pump();
          await p.sweep();
          await shot(tester, key, 'g_ce_news_$tag', pixelRatio: 1.5);
          p.ctl.closeSheet();
          await p.pump();
          expect(p.found, isEmpty, reason: p.found.join('\n'));
        }, timeout: const Timeout(Duration(minutes: 10)));
      }
    }
  });
}
