import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';
import 'package:quadrillion/ui/app.dart';
import 'package:quadrillion/ui/sheets.dart';
import 'package:quadrillion/ui/tabs.dart';
import 'package:quadrillion/ui/widgets.dart';

import 'support/bot.dart';
import 'support/grown.dart';
import 'support/pilot.dart';
import 'support/shots.dart';

String? _grownJson;

/// 育った会社（1985年から25年。事業20〜30・子会社・現地法人・持株会社・子会社の上場・提携）。作るのは1回だけで、あとは写しを返す
Game _grown() {
  _grownJson ??= jsonEncode(grownGame().toJson());
  return Game.fromJson(jsonDecode(_grownJson!) as Map<String, dynamic>, rng: ParkMiller(5))..calcAll();
}

/// 押して遊ぶ役で回す年数（中盤の通し）。手元で長く回すときは QUAD_PILOT_MID_YEARS=20
final _midYears = int.tryParse(Platform.environment['QUAD_PILOT_MID_YEARS'] ?? '') ?? 2;

/// 1.0.0+18（改善の回F）：中盤〜終盤（育った会社）の遊びやすさ
void main() {
  group('育った会社の組み立て役', () {
    test('仕組みを進めて、事業20〜30・子会社・現地法人・持株会社・子会社の上場・提携のある盤面になる', () {
      final g = _grown();
      // ignore: avoid_print
      print('[grown] ${grownSummary(g)}');
      expect(g.over, isNull);
      expect(g.biz.length, inInclusiveRange(20, 30));
      expect(g.holding, isTrue);
      // 上場（年の利益3億円が条件）は 1.1.0+26 から入らないことがある（店などの数で伸びが遅くなった）。子会社の上場は見る
      expect(g.locals(), isNotEmpty);
      expect(g.subs().where((c) => c.loc == null), isNotEmpty);
      expect(g.subs().where((c) => c.listed), isNotEmpty);
      expect(g.deals, isNotEmpty);
    });

    test('はじめの数年は、投資家の出資を受けた上場前の盤面になる', () {
      Game? hit;
      final g = Game.newGame(SetupConfig(mode: 'endless', year: 1985, traits: const ['charm', 'careful']), rng: ParkMiller(2024));
      for (var m = 0; m < 12 * 12 && hit == null; m++) {
        growMonth(g);
        if (!g.listed && g.sh.vc > 0) hit = g;
      }
      expect(hit, isNotNull, reason: '投資家の出資を受けた月が無い');
    });
  });

  group('子会社・現地法人のカード', () {
    test('現地法人で宿敵が買い集めた分は、市場の株から引く（合計が100%を超えない）', () {
      final g = _grown();
      final c = g.locals().firstWhere((c) => c.listed, orElse: () {
        final x = g.locals().first;
        g.ap = 1;
        g.subIPO(x);
        return x;
      });
      final foe = g.cos.firstWhere((x) => x.alive && x.rival != null && x.parent != 'player');
      c.locRiv = foe.id;
      c.locRivPct = 100 - c.fam - c.stakePlayer;
      expect(g.floatOf(c), 0);
      final own = c.stakePlayer;
      g.ap = 3;
      g.cash = 1e15;
      expect(txIn(g.buyStake(c, 5), 'ja'), '市場に株が残っていません');
      expect(c.stakePlayer, own);
      c.locRivPct = 10;
      expect(g.floatOf(c), closeTo(100 - c.fam - own - 10, 1e-9));
    });

    for (final lang in const ['ja', 'en']) {
      testWidgets('幅320でも名前と札が折り返して並び、子会社を売るのは確認を挟む（$lang）', (tester) async {
        // 本物のフォントで測る（テスト用のフォントは1字が字の大きさの正方形で、英語の「Local sub (South Africa)」のような長い札が、本物では収まるのに折れる）
        await loadRealFonts();
        final g = _grown();
        final p = await Pilot.launch(tester, lang: lang, size: const Size(320, 844), game: g);
        final loc = g.locals().first;
        final foe = g.cos.firstWhere((x) => x.alive && x.rival != null && x.parent != 'player');
        if (!loc.listed) {
          g.ap = 1;
          g.subIPO(loc);
        }
        loc.locRiv = foe.id;
        loc.locRivPct = 12;
        g.ap = g.apMax;
        // 買い戻せるお金を持たせる（1.1.0+26 から伸びが遅くなり、育った会社の手元が少ないことがある）
        g.cash = 1e15;
        g.calcAll();
        p.where = '子会社のカード';
        await p.tab('stock');
        await p.sweep();
        final card = find.byKey(ValueKey('co-${loc.id}'));
        expect(await p.reveal(card), isTrue);
        // 現地法人の札は国の名前つき。「国内・地域・世界」の札は付けない
        expect(find.descendant(of: card, matching: find.text(tr('現地法人（{0}）', [cm[loc.loc!]!.n]))), findsOneWidget);
        expect(find.descendant(of: card, matching: find.text(REGN[loc.tier])), findsNothing);
        // 札の字は1行（語の途中で折れない）
        for (final e in find.descendant(of: card, matching: find.byType(Tag)).evaluate()) {
          expect(e.size!.height, lessThan(30), reason: (e.widget as Tag).text);
        }
        // 買い戻す・全部売るのボタンは、画面の幅に収まっていて押せる
        final back = find.descendant(of: card, matching: find.text(tr('宿敵の持ち分を買い戻す（{0}）', [yen(g.localBuybackCost(loc))])));
        expect(await p.reveal(back), isTrue);
        // 1.1.0+25 から横向き（844×390）。真ん中の欄（右の帯210の手前）に収まる
        expect(tester.getRect(back).right, lessThanOrEqualTo(844 - 210));
        final cash0 = g.cash;
        final cost = g.localBuybackCost(loc);
        await p.press(back, '買い戻す');
        await p.drain();
        expect(loc.locRivPct, 0);
        expect(g.cash, closeTo(cash0 - cost, cost * 1e-9));
        // 全部売る → 確認の小窓 → やめる（子会社のまま）
        final sell = find.descendant(of: find.byKey(ValueKey('co-sell-${loc.id}')), matching: find.byType(Btn));
        await p.press(sell, '全部売る');
        expect(p.ctl.sheet, isNotNull, reason: '確認が出ない');
        expect(loc.parent, 'player');
        await p.press(p.inSheet(find.text(tr('やめる'))), 'やめる');
        expect(loc.parent, 'player');
        expect(g.pctOf(loc), greaterThan(0));
        // もう一度押して「売る」→ 手放す
        await p.press(sell, '全部売る');
        await p.press(p.inSheet(find.byType(DangerBtn)), '売る');
        await p.drain();
        expect(g.pctOf(loc), 0);
        expect(loc.parent, isNull);
        expect(p.found, isEmpty, reason: p.found.join('\n'));
      });
    }

    testWidgets('会社を2つに割るのは、1つのボタンから小窓で分類を選ぶ', (tester) async {
      final g = _grown();
      // 会社を2つに割るのは上場している会社だけ。1.1.0+26 から育った会社が上場していないことがあるので、上場した形で見る
      g.listed = true;
      final p = await Pilot.launch(tester, game: g);
      await p.tab('stock');
      final cats = <String>{for (final b in g.biz) indm[b.ind]!.cat};
      expect(cats.length, greaterThan(3));
      // 分類ごとのボタンは、画面には並ばない
      await p.sweep();
      for (final c in cats) {
        expect(find.text(tr('{0}を切り離す', [CATN[c]])), findsNothing);
      }
      await p.press(find.text(tr('会社を2つに割る')), '会社を2つに割る');
      expect(p.ctl.sheet, isNotNull);
      for (final c in cats) {
        expect(p.inSheet(find.byKey(ValueKey('split-$c'))), findsOneWidget);
      }
      final cat = cats.first;
      final n = g.biz.where((b) => indm[b.ind]!.cat == cat).length;
      final all = g.biz.length;
      await p.press(p.inSheet(find.byKey(ValueKey('split-$cat'))), '切り離す');
      await p.drain();
      expect(g.biz.length, all - n);
      expect(p.found, isEmpty, reason: p.found.join('\n'));
    });
  });

  group('事業が多いときの一覧', () {
    test('並べ替え：注意があるものを先に・利益の少ない順・シェアの低い順', () {
      final g = _grown();
      expect(myBizList(g, 'rev').map((b) => b.rev).toList(), orderedEquals(g.biz.map((b) => b.rev).toList()..sort((a, b) => b.compareTo(a))));
      final low = myBizList(g, 'low');
      for (var i = 1; i < low.length; i++) {
        expect(low[i - 1].profit, lessThanOrEqualTo(low[i].profit));
      }
      final sh = myBizList(g, 'share');
      for (var i = 1; i < sh.length; i++) {
        expect(sh[i - 1].share, lessThanOrEqualTo(sh[i].share));
      }
      final w = myBizList(g, 'warn').map((b) => bizWarnings(g, b).length).toList();
      for (var i = 1; i < w.length; i++) {
        expect(w[i - 1], greaterThanOrEqualTo(w[i]));
      }
      expect(myBizList(g, 'warn').length, g.biz.length);
    });

    test('足りない人をまとめて雇う：1つずつ雇うのと同じ値段・同じ手の数', () {
      final a = _grown(), b = _grown();
      for (final g in [a, b]) {
        // 人手不足の事業を3つ作る
        for (final x in g.biz.where((x) => x.model != 'fc').take(3)) {
          x.crew = g.crewOf(x) * .02; // 1.1.0+26 から、店などの数で売上が頭打ちのときは要る人が少ないので、人手不足を作るときは大きく減らす
        }
        g.calcAll();
        // 社長の時間を、人を雇う2回ぶんだけ残す（1.1.0+25 から手ではなく時間）
        g.hUsed = hoursMax - g.hMeet() - 2 * g.hrs('crew');
        g.cash = 1e14;
      }
      expect(a.crewShort().length, greaterThanOrEqualTo(3));
      // 時間は2回ぶんなので、足りない割合の大きい2つだけ
      final plan = a.crewShortDoable();
      expect(plan.length, 2);
      final ids = plan.map((x) => x.id).toList();
      final cost = plan.fold(0.0, (s, x) => s + a.hireCost(x, a.crewNeedPeople(x)));
      final cashA = a.cash;
      a.hireShortAll();
      expect(a.hLeft(), 0);
      expect(cashA - a.cash, closeTo(cost, cost * 1e-9));
      for (final id in ids) {
        final x = b.biz.firstWhere((x) => x.id == id);
        b.hireN(x, b.crewNeedPeople(x));
      }
      expect(b.hLeft(), 0);
      expect(b.cash, closeTo(a.cash, a.cash.abs() * 1e-12));
      for (final id in ids) {
        expect(a.crewNeedPeople(a.biz.firstWhere((x) => x.id == id)), 0);
        expect(a.biz.firstWhere((x) => x.id == id).crew, closeTo(b.biz.firstWhere((x) => x.id == id).crew!, 1e-3));
      }
      // 手が無ければ何もしないで、わけを言う
      expect(txIn(a.hireShortAll(), 'ja'), startsWith('今月の社長の時間が足りません'));
      a.ap = 1;
      a.cash = 0;
      expect(txIn(a.hireShortAll(), 'ja'), 'お金が足りません');
    });

    test('空いている部下を責任者に置く：放置された事業が先で、置いたほうが強くなるときだけ。手は使わない', () {
      final g = _grown();
      g.holding = false;
      for (final b in g.biz) {
        b.mgr = null;
      }
      g.calcAll();
      final free = g.staff.length;
      expect(free, greaterThan(3));
      final ap = g.ap;
      final plan = g.managerPlan();
      expect(plan, isNotEmpty);
      expect(plan.map((x) => x.$2.id).toSet().length, plan.length, reason: '同じ人を2つの事業に置かない');
      // 社長が見られる数（2つ）を超えて放置されている事業から埋まる
      final neglected = g.biz.where((b) => b.mgr == null).skip(g.presCap()).map((b) => b.id).toSet();
      expect(neglected.contains(plan.first.$1.id), isTrue);
      final before = {for (final x in plan) x.$1.id: g.mgrMult(x.$1)};
      g.placeManagers();
      expect(g.ap, ap);
      for (final x in plan) {
        expect(x.$1.mgr, x.$2.id);
        expect(g.mgrMult(x.$1), greaterThan(before[x.$1.id]!));
      }
    });

    testWidgets('見出しを押すと一覧ごとたためて、「新しい事業」がすぐ下に来る。まとめての手が押せる', (tester) async {
      final g = _grown();
      for (final x in g.biz.where((x) => x.model != 'fc').take(2)) {
        x.crew = g.crewOf(x) * .02; // 1.1.0+26 から、店などの数で売上が頭打ちのときは要る人が少ないので、人手不足を作るときは大きく減らす
      }
      g.calcAll();
      g.cash = 1e14;
      // 見出しでたたむ・並べ替え・まとめての手の欄は1つの列の事業の画面のもの（1.1.0+26 から、真ん中が幅520以上なら2列）。幅600の窓で見る
      final p = await Pilot.launch(tester, game: g, size: const Size(600, 590));
      await p.tab('biz');
      expect(g.biz.length, greaterThanOrEqualTo(bizManyMin));
      expect(find.byKey(const ValueKey('biz-attn')), findsOneWidget);
      // 並べ替え
      await p.pressKey('mysort-low');
      expect(p.ctl.myBizSort, 'low');
      final first = myBizList(g, 'low').first;
      expect(tester.getTopLeft(find.byKey(ValueKey('biz-row-${first.id}'))).dy, lessThan(tester.getTopLeft(find.byKey(ValueKey('biz-row-${myBizList(g, 'low')[1].id}'))).dy));
      // まとめて雇う
      final n = g.crewShortDoable().length;
      final short = g.crewShort().length;
      expect(n, greaterThanOrEqualTo(2));
      final h0 = g.hUsed;
      await p.pressKey('hire-short-all');
      await p.drain();
      // 1つの事業につき、人を雇う時間（1.1.0+25 から手ではなく時間）
      expect(g.hUsed - h0, g.hrs('crew') * n);
      expect(g.crewShort().length, short - n);
      // たたむ
      await p.press(find.descendant(of: find.byKey(const ValueKey('fold-mybiz')), matching: find.byType(InkWell)), '自社の事業の見出し');
      expect(p.ctl.folded.contains('mybiz'), isTrue);
      expect(find.byKey(ValueKey('biz-row-${first.id}')), findsNothing);
      expect(find.text(tr('新しい事業')), findsOneWidget);
      expect(tester.getTopLeft(find.text(tr('新しい事業'))).dy, lessThan(400));
      await p.press(find.descendant(of: find.byKey(const ValueKey('fold-mybiz')), matching: find.byType(InkWell)), '自社の事業の見出し');
      // 横向きの画面は低いので、一覧のその行まで送って確かめる（1.1.0+25）
      expect(await p.reveal(find.byKey(ValueKey('biz-row-${first.id}'))), isTrue);
      expect(p.found, isEmpty, reason: p.found.join('\n'));
    });

    testWidgets('事業が少ないうちは、今までどおり（たたむ見出し・まとめての手は出ない）', (tester) async {
      final g = Game.newGame(SetupConfig(mode: 'world', year: 1980, traits: ['charm', 'gambler']), rng: ParkMiller(2024));
      for (var i = 0; i < 60 && g.biz.length < bizManyMin - 1; i++) {
        botMonth(g, units: true);
      }
      resolveEvents(g);
      g.calcAll();
      expect(g.biz.length, inInclusiveRange(3, bizManyMin - 1));
      final p = await Pilot.launch(tester, game: g);
      await p.tab('biz');
      expect(find.byKey(const ValueKey('fold-mybiz')), findsNothing);
      expect(find.byKey(const ValueKey('biz-attn')), findsNothing);
      expect(find.byKey(const ValueKey('chips-mysort')), findsNothing);
    });
  });

  group('中盤の単調さ', () {
    test('10〜30年目：助言が先月と同じ文の月は3割未満（月の進み方そのものは前と変えていない）', () {
      final st = MidStats();
      for (final c in const [(2024, 1985), (31, 1980), (7, 1995)]) {
        measureMid(seed: c.$1, year: c.$2, into: st);
      }
      // ignore: avoid_print
      print('[mid] ${st.report()}');
      // 前（1.0.0+17）: 先月と同じ文の月 99.6%・同じ文の最長 240か月・単調な月 26.1%
      expect(st.sameAdvicePct, lessThan(30));
      expect(st.longestSame, lessThan(12));
      expect(st.monoPct, lessThan(10));
      // 1.0.0+18 までは月の進み方（乱数の流れ・出来事・提案）は 1.0.0+17 のまま（3本で544か月・何も起きない月142・経営会議の提案51件のうち店・工場25件）。
      // 1.0.0+19 で国ごとの事件・宿敵の場面・提案の種類を足した（数え方と前後の数字は test/improve_g_test.dart「中盤を数える」）
      expect(st.months, greaterThan(400));
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('助言：いちばん大事な1つは先頭のまま、2つ目からは月ごとに回る。全部の一覧は大事な順のまま', () {
      final g = _grown();
      g.pres.age = 65;
      g.succ = null;
      final all = g.adviceAll();
      expect(all.length, greaterThan(3));
      final seen = <String>{};
      // どの月にも候補に入っている文（「沈む市場」「新しい市場」の文は、月によって出たり引っ込んだりするので除く）
      var steady = all.map(msgKey).toSet();
      final t0 = g.turn;
      for (var i = 0; i < all.length * 2; i++) {
        g.turn = t0 + i;
        final a = g.advice();
        expect(a.length, 3);
        expect(a.first, g.adviceAll().first);
        expect(a.toSet().length, 3);
        seen.addAll(a.map(msgKey));
        steady = steady.intersection(g.adviceAll().map(msgKey).toSet());
      }
      g.turn = t0;
      // 何か月かで、候補が全部1度は出る
      expect(steady.length, greaterThan(3));
      expect(seen, containsAll(steady));
      expect(g.adviceAll(), all);
    });

    test('中盤からの勧め：忠誠・現地法人の株・子会社の上場・現地法人。どれも英語がある', () {
      final g = _grown();
      String all() => g.adviceAll().map((m) => txIn(m, 'ja')).join('\n');
      for (final x in g.staff) {
        x.loy = 90;
      }
      final p = g.staff.first
        ..loy = 40
        ..amb = 80
        ..ambKnown = true;
      expect(all(), contains('${p.name}の忠誠が下がっています'));
      p.loy = 90;
      for (final x in g.staff) {
        x.loy = 90;
      }
      expect(all(), isNot(contains('忠誠が下がっています')));
      final loc = g.locals().first;
      final foe = g.cos.firstWhere((x) => x.alive && x.rival != null && x.parent != 'player');
      loc.locRiv = foe.id;
      loc.locRivPct = 16;
      expect(all(), contains('現地法人${loc.name}の株を、${foe.name}が16%まで買い集めています'));
      expect(g.adviceAll().first, contains('買い集めています'), reason: '25%が近いときは先頭');
      loc.locRivPct = 0;
      expect(all(), isNot(contains('買い集めています')));
      // 子会社の上場（まだ1社も上場させていないとき）
      for (final c in g.subs()) {
        if (c.listed) {
          c.listed = false;
          c.stakePlayer = 100;
        }
      }
      g.calcAll();
      expect(all(), contains('は上場させられます'));
      final sub = g.subs().firstWhere((c) => g.pctOf(c) >= 60);
      g.ap = 1;
      g.subIPO(sub);
      expect(sub.listed, isTrue);
      expect(all(), isNot(contains('は上場させられます')));
      // 英語に日本語が残らない
      final jp = RegExp(r'[぀-ヿ㐀-鿿]');
      loc.locRivPct = 30;
      p.loy = 40;
      for (final m in g.adviceAll()) {
        expect(jp.hasMatch(txIn(m, 'en')), isFalse, reason: txIn(m, 'en'));
      }
    });

    testWidgets('押して遊ぶ役で、育った会社（10年目から）を$_midYears年回す', (tester) async {
      final g = grownGame(years: 10);
      final p = await Pilot.launch(tester, game: g, seed: 41);
      p.logTag = '中盤';
      final end = g.turn + _midYears * 12;
      var months = 0, mono = 0, same = 0;
      var prev = g.advice().map(msgKey).join('|');
      await p.tour();
      while (g.turn < end && g.over == null) {
        final picks = p.seen['出来事の選択'] ?? 0;
        await p.month();
        if (!await p.next()) break;
        months++;
        final now = g.advice().map(msgKey).join('|');
        final quiet = (p.seen['出来事の選択'] ?? 0) == picks && !g.lastNews.any((n) => n.t == 'big' || n.t == 'bad');
        if (now == prev) same++;
        if (quiet && now == prev) mono++;
        prev = now;
        if (g.turn % 12 == 6) await p.tour();
      }
      // ignore: avoid_print
      print('[mid-pilot] ${g.year}年${g.q}月まで $monthsか月・事業${g.biz.length}・助言が先月と同じ月 $same・単調な月 $mono / ${p.seen.entries.map((e) => '${e.key}×${e.value}').join('、')}');
      expect(p.found, isEmpty, reason: p.found.join('\n'));
      expect(months, greaterThanOrEqualTo(_midYears * 12 - 1), reason: '途中で終わった: ${g.over}');
      expect(same / months, lessThan(.5));
    }, timeout: const Timeout(Duration(minutes: 30)));
  });

  group('回Eの残り', () {
    test('「今ある店を広げる」は、仕掛かりの札・行・開いたときの知らせが「増やす」と別になる', () {
      final g = _grown();
      final b = g.biz.firstWhere((b) => b.pipe.isEmpty && b.model != 'fc' && g.kindB(b) == 'shop');
      g.cash = 1e14;
      g.ap = 2;
      // 1.1.0+26 から「増やす」は物件と店長の分だけ開く（仕掛かりの種類は open）。「広げる」は改装で、仕組みの上では今までどおり建設（build）
      b.leads = 3;
      b.lic = 0;
      b.upg = 1;
      b.offers = [Offer(s: g.siteKeys(g.home, 'shop').first)];
      g.extendN(b);
      g.ap = 2;
      g.buildN(b, 1);
      expect(b.pipe.map((x) => x.k), ['build', 'open']);
      expect(b.pipe.map(pipeKind), ['ext', 'open']);
      expect(pipeKindName('ext'), '拡張中');
      expect(pipeKindName('open'), '開く準備');
      expect(pipeKindName('build'), '建設中');
      expect(pipeGroups(b).map((x) => x.k), ['ext', 'open']);
      expect(pipeText(g, b, b.pipe[0]), contains('今ある${txIn(g.uw(b), 'ja')}を広げる'));
      expect(pipeText(g, b, b.pipe[1]), isNot(contains('広げる')));
      // セーブを読み直しても残る。古いセーブ（印なし）は「増やす」として読む
      final back = Pipe.fromJson(jsonDecode(jsonEncode(b.pipe[0].toJson())) as Map<String, dynamic>);
      expect(back.ext, isTrue);
      expect(Pipe.fromJson({'k': 'build', 'cost': 1.0, 'left': 1}).ext, isFalse);
      expect(b.pipe[1].toJson().containsKey('ext'), isFalse);
      // 開いたときの知らせ
      final news = <String>[];
      g.finishPipe(b, b.pipe[0], (m, [t = '']) => news.add(txIn(m, 'ja')));
      g.finishPipe(b, b.pipe[1], (m, [t = '']) => news.add(txIn(m, 'ja')));
      expect(news[0], contains('を広げ終わりました'));
      expect(news[1], contains('が開きました'));
      final en = <String>[];
      g.finishPipe(b, b.pipe[0], (m, [t = '']) => en.add(txIn(m, 'en')));
      expect(RegExp(r'[぀-ヿ㐀-鿿]').hasMatch(en.single), isFalse);
    });

    testWidgets('事業のカードで、広げている分は「拡張中」の札で出る', (tester) async {
      final g = _grown();
      final b = g.biz.firstWhere((b) => b.pipe.isEmpty && b.model != 'fc' && g.kindB(b) == 'shop');
      g.cash = 1e14;
      g.ap = 2;
      // 1.1.0+26 から「増やす」は物件と店長の分だけ開く（札は「開く準備」）
      b.leads = 3;
      b.upg = 1;
      b.offers = [for (var i = 0; i < 3; i++) Offer(s: g.siteKeys(g.home, 'shop').first)];
      g.extendN(b);
      g.ap = 2;
      g.buildN(b, 3);
      final p = await Pilot.launch(tester, game: g);
      await p.tab('biz');
      p.ctl.openBiz = p.ctl.moreBiz = b.id;
      p.ctl.render();
      await p.pump();
      final card = find.ancestor(of: find.byKey(ValueKey('grp-grow-${b.id}')), matching: find.byType(Panel)).first;
      expect(await p.reveal(find.byKey(ValueKey('grp-grow-${b.id}'))), isTrue);
      expect(find.descendant(of: card, matching: find.text('拡張中')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('開く準備')), findsOneWidget);
      expect(p.found, isEmpty, reason: p.found.join('\n'));
    });

    testWidgets('図鑑のシナジーの数は1か所だけに出る', (tester) async {
      final g = _grown();
      final p = await Pilot.launch(tester, game: g);
      await p.tab('zukan');
      expect(find.textContaining('${g.found.length} / ${g.syns.length}'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('syn-progress')), matching: find.text('${g.found.length} / ${g.syns.length}')), findsOneWidget);
      expect(find.text('シナジー図鑑'), findsOneWidget);
    });

    test('決算の棒は桁の目盛り：小さい費用どうしでも長さが違う', () {
      const vals = [3911e8, 34.8e8, -1648e4, -353e4, 0.0];
      final top = vals.map((v) => v.abs()).reduce((a, b) => a > b ? a : b);
      final dec = plDecades(vals);
      expect(dec, 7, reason: '3911億と353万のあいだは5桁あまり → 6＋1');
      final f = [for (final v in vals) plFrac(v, top, dec)];
      expect(f[0], 1);
      expect(f[4], 0);
      for (var i = 1; i < 4; i++) {
        expect(f[i], lessThan(f[i - 1] - .05), reason: '$i 番目');
        expect(f[i], greaterThan(.1));
      }
      // 額が10分の1になるごとに、ちょうど1目盛り短い
      expect(plFrac(100, 1000, 4), closeTo(.75, 1e-9));
      expect(plFrac(10, 1000, 4), closeTo(.5, 1e-9));
      // 額がそろっているときも壊れない
      expect(plDecades(const [5.0, 5.0]), 2);
      expect(plDecades(const [0.0, 0.0]), 2);
      expect(plFrac(5, 0, 2), 0);
      // 前（額の比のまま）は、1648万も353万も最小の幅（12）だった
      const full = 300.0;
      expect(const AmountBar(1648e4 / 3911e8, minus: true).fillWidth(full), AmountBar.minFill);
      expect(const AmountBar(353e4 / 3911e8, minus: true).fillWidth(full), AmountBar.minFill);
      expect(AmountBar(f[2], minus: true).fillWidth(full) - AmountBar(f[3], minus: true).fillWidth(full), greaterThan(20));
    });

    testWidgets('「数字」の決算に、目盛りの注意書きが出る', (tester) async {
      final g = _grown();
      final p = await Pilot.launch(tester, game: g);
      await p.tab('num');
      expect(find.byKey(const ValueKey('pl-scale-note')), findsOneWidget);
      final pay = tester.getSize(find.descendant(of: find.byKey(const ValueKey('pl-bar-pay')), matching: find.byType(ColoredBox)).last).width;
      final hq = tester.getSize(find.descendant(of: find.byKey(const ValueKey('pl-bar-hq')), matching: find.byType(ColoredBox)).last).width;
      expect((pay - hq).abs(), greaterThan(4), reason: '給料 ${g.salaries()} と本社の経費 ${g.hq} の棒が同じ長さ');
    });
  });

  group('終わりの画面と社史', () {
    test('節目：同じ種類は2つまで。宿敵との決着・解任も入る。順位は上の節目から', () {
      final g = Game.newGame(SetupConfig(mode: 'endless', year: 1980, traits: const ['charm', 'careful']), rng: ParkMiller(3));
      g.history.clear();
      g.chron('found', '創業');
      // 創業してすぐの10年に、記録がたくさんある（海外・合併・順位）
      for (var i = 0; i < 5; i++) {
        g.year = 1981 + i;
        g.chron('abroad', '国$i');
        g.chron('merge', M('{0}を合併した', [Nm('はじめの相手$i')]));
      }
      g.year = 1987;
      g.chron('ipo', M('株式を上場した。{0}が入った（時価総額 {1}）', [Y(1e9), Y(1e10)]));
      for (final (i, th) in [500, 300, 100, 50, 10].indexed) {
        g.year = 1984 + i * 5;
        g.chron('rank', M('世界の企業ランキングで初めて{0}位以内に入った（{1}位）', [th, th - 1]));
      }
      for (var i = 0; i < 6; i++) {
        g.year = 1992 + i * 3;
        g.chron('ipo', M('現地法人{0}を{1}の市場に上場させた。{2}が入った', [Nm('会社$i'), C('us'), Y(1e9)]));
        g.chron('merge', M('{0}を合併した', [Nm('相手$i')]));
        g.chron('era', '時代$i');
      }
      g.year = 2010;
      g.chron('rival', M('{0}（{1}）との因縁に決着がついた：{2}', [Nm('黒田 剛造'), Nm('黒田興産'), D('和解')]));
      g.year = 2011;
      g.chron('board', '解任');
      g.history.sort((a, b) => a.y.compareTo(b.y));
      final h = g.highlights(7);
      expect(h.length, 7);
      final kinds = <String, int>{};
      for (final e in h) {
        kinds[e.k] = (kinds[e.k] ?? 0) + 1;
      }
      expect(kinds.values.every((n) => n <= 2), isTrue, reason: '$kinds');
      expect(kinds.keys, containsAll(['found', 'rank', 'ipo', 'rival', 'merge']));
      expect(h.any((e) => e.k == 'era'), isFalse);
      // 順位は 10位以内・50位以内（上の2つ）
      final ranks = h.where((e) => e.k == 'rank').map((e) => txIn(e.m, 'ja')).toList();
      expect(ranks.any((m) => m.contains('10位以内')), isTrue);
      expect(ranks.any((m) => m.contains('500位以内')), isFalse);
      // 自社の上場は、現地法人の上場より先に選ばれる
      expect(h.where((e) => e.k == 'ipo').any((e) => txIn(e.m, 'ja').startsWith('株式を上場した')), isTrue);
      // 古い順
      for (var i = 1; i < h.length; i++) {
        expect(g.history.indexOf(h[i - 1]), lessThan(g.history.indexOf(h[i])));
      }
      // はじめの10年からは半分（3つ）まで。後半の節目も入る
      expect(h.where((e) => e.y < 1990).length, lessThanOrEqualTo(3));
      expect(h.where((e) => e.y >= 2000).length, greaterThanOrEqualTo(2));
      // 枠が余れば、同じ種類の残りで埋める
      final few = Game.newGame(SetupConfig(mode: 'endless', year: 1980), rng: ParkMiller(3));
      few.history.clear();
      for (var i = 0; i < 6; i++) {
        few.chron('abroad', '国$i');
      }
      expect(few.highlights(5).length, 5);
    });

    testWidgets('30年遊んだ会社：「数字」の社史は主な節目が先、全部の記録はたたんである', (tester) async {
      final g = grownGame(years: 31);
      expect(g.over, isNull);
      expect(g.history.length, greaterThan(chronFoldMin));
      final p = await Pilot.launch(tester, game: g);
      await p.tab('num');
      final marks = find.byKey(const ValueKey('chron-marks'));
      expect(await p.reveal(marks), isTrue);
      expect(find.descendant(of: marks, matching: find.byType(Row)).evaluate().length, lessThanOrEqualTo(chronMarks * 2));
      expect(find.byKey(const ValueKey('chron-all')), findsNothing);
      // 開くと全部出る（新しい順）
      await p.press(find.descendant(of: find.byKey(const ValueKey('fold-chron')), matching: find.byType(InkWell)), 'すべての記録');
      expect(await p.reveal(find.byKey(const ValueKey('chron-all'))), isTrue);
      await p.sweep();
      expect(p.found, isEmpty, reason: p.found.join('\n'));
      // 終わりのまとめ：節目は7つまで。1画面半に収まる
      g.over = M('宿敵に株の過半数を握られ、社長の座を追われました');
      p.ctl.render();
      await p.pump();
      expect(find.byType(EndScreen), findsOneWidget);
      expect(g.highlights(7).length, lessThanOrEqualTo(7));
      final sc = tester.state<ScrollableState>(find.descendant(of: find.byType(EndScreen), matching: find.byType(Scrollable)).first);
      expect(sc.position.maxScrollExtent, lessThan(844 * .5), reason: 'まとめが長すぎる');
      await p.sweep();
      expect(p.found, isEmpty, reason: p.found.join('\n'));
    });

    testWidgets('記録が少ないうちは、今までどおり1つの一覧', (tester) async {
      final g = Game.newGame(SetupConfig(mode: 'world', year: 1980, traits: ['charm', 'gambler']), rng: ParkMiller(2024));
      for (var i = 0; i < 30; i++) {
        botMonth(g, units: true);
      }
      resolveEvents(g);
      g.calcAll();
      expect(g.history.length, lessThanOrEqualTo(chronFoldMin));
      final p = await Pilot.launch(tester, game: g);
      await p.tab('num');
      await p.sweep();
      expect(find.byKey(const ValueKey('fold-chron')), findsNothing);
      expect(find.byKey(const ValueKey('chron-marks')), findsNothing);
    });
  });

  group('育った会社の画面を目で見る（QUAD_SHOTS を渡したときだけ書き出す）', () {
    for (final lang in const ['ja', 'en']) {
      for (final w in const [390.0, 320.0]) {
        testWidgets('$lang・幅${w.round()}', (tester) async {
          await loadRealFonts();
          final key = GlobalKey();
          final g = _grown();
          // 宿敵に株を買われた現地法人・人手不足の事業・広げている店も見えるようにする
          final foe = g.cos.firstWhere((x) => x.alive && x.rival != null && x.parent != 'player');
          final loc = g.locals().firstWhere((c) => c.listed, orElse: () => g.locals().first);
          if (loc.listed) {
            loc.locRiv = foe.id;
            loc.locRivPct = 18;
          }
          for (final x in g.biz.where((x) => x.model != 'fc').take(3)) {
            x.crew = g.crewOf(x) * .02; // 1.1.0+26 から、店などの数で売上が頭打ちのときは要る人が少ないので、人手不足を作るときは大きく減らす
          }
          final top = (g.biz.toList()..ssort((x, y) => y.rev.compareTo(x.rev))).first;
          g.ap = g.apMax;
          g.extendN(top);
          g.ap = g.apMax;
          g.calcAll();
          final p = await Pilot.launch(tester, lang: lang, size: Size(w, 844), game: g, boundary: key);
          p.watchWraps = true;
          final tag = '${lang}_${w.round()}';
          // 今の欄を上から下まで、1画面ずつ書き出す
          Future<void> pages(String name) async {
            final f = p.ctl.sheet != null
                ? find.descendant(of: find.byKey(const ValueKey('sheet-card')), matching: find.byType(Scrollable))
                : find.byType(EndScreen).evaluate().isNotEmpty
                    ? find.descendant(of: find.byType(EndScreen), matching: find.byType(Scrollable))
                    : find.descendant(of: find.byKey(PageStorageKey('tab-${p.ctl.tab}')), matching: find.byType(Scrollable));
            if (f.evaluate().isEmpty) {
              await shot(tester, key, 'f_${name}_$tag', pixelRatio: 1.5);
              return;
            }
            final sc = tester.state<ScrollableState>(f.first);
            sc.position.jumpTo(0);
            await p.pump();
            for (var i = 0; i < 40; i++) {
              await shot(tester, key, 'f_${name}_${tag}_${i.toString().padLeft(2, '0')}', pixelRatio: 1.5);
              if (sc.position.pixels >= sc.position.maxScrollExtent) break;
              sc.position.jumpTo((sc.position.pixels + 640).clamp(0, sc.position.maxScrollExtent).toDouble());
              await p.pump();
            }
            sc.position.jumpTo(0);
            await p.pump();
          }

          for (final t in const ['town', 'biz', 'people', 'stock', 'num', 'zukan']) {
            p.where = '育った会社（$t）';
            await p.tab(t);
            await p.sweep();
            await pages(t);
          }
          // 社史の全部の記録を開いた所
          await p.tab('num');
          p.ctl.toggleFold('chron-all');
          await p.pump();
          await p.sweep();
          await pages('num_chron_open');
          p.ctl.toggleFold('chron-all');
          // 事業の一覧をたたんだ所・カードを1つ開いた所と、その小窓
          await p.tab('biz');
          p.ctl.toggleFold('mybiz');
          await p.pump();
          await shot(tester, key, 'f_biz_folded_$tag', pixelRatio: 1.5);
          p.ctl.toggleFold('mybiz');
          p.ctl.openBiz = p.ctl.moreBiz = top.id;
          p.ctl.render();
          await p.pump();
          await p.sweep();
          await pages('biz_open');
          final sheets = <String, VoidCallback>{
            'build': () => openBuild(p.ctl, top),
            'develop': () => openDevelop(p.ctl, top),
            'enter': () => openEnter(p.ctl, top),
            'shape': () => openShape(p.ctl, top),
            'split': () => openSplit(p.ctl),
            'advice': () => openAdvice(p.ctl),
            'sell': () => openSell(p.ctl),
            'settings': () => openSettings(p.ctl),
          };
          for (final e in sheets.entries) {
            p.where = '育った会社（小窓 ${e.key}）';
            e.value();
            await p.pump();
            await p.sweep();
            await pages('sheet_${e.key}');
            p.ctl.closeSheet();
            await p.pump();
          }
          // 終わりのまとめ（負け）
          p.where = '育った会社（終わり）';
          g.over = M('宿敵に株の過半数を握られ、社長の座を追われました');
          p.ctl.render();
          await p.pump();
          await p.sweep();
          await pages('end_over');
          // ignore: avoid_print
          print('[wrap] $tag: ${p.wraps.length}件\n${p.wraps.entries.map((e) => '  「${e.key}」 ${e.value}').join('\n')}');
          expect(p.found, isEmpty, reason: p.found.join('\n'));
          if (Platform.environment['QUAD_WRAP_LIST'] == null && lang == 'ja') {
            expect(p.wraps, isEmpty, reason: p.wraps.entries.map((e) => '「${e.key}」 ${e.value}').join('\n'));
          }
        }, timeout: const Timeout(Duration(minutes: 10)));
      }
    }
  });
}
