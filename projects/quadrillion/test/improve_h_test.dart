import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';
import 'package:quadrillion/ui/widgets.dart';

import 'support/bot.dart';
import 'support/deleg.dart';
import 'support/grown.dart';
import 'support/pilot.dart';
import 'support/shots.dart';

/// 改善の回H（1.0.0+20）:「操作が複雑になってきた」への手当て3つ
///  A 事業を責任者に任せる　B「今月やること」から1回で実行　C 事業カードを軽く

String? _grownJson;

/// 育った会社（1985年から25年・事業26）。作るのは1回だけで、あとは写しを返す
Game _grown([int seed = 5]) {
  _grownJson ??= jsonEncode(grownGame().toJson());
  return Game.fromJson(jsonDecode(_grownJson!) as Map<String, dynamic>, rng: ParkMiller(seed))
    ..events.clear()
    ..calcAll();
}

final _cjk = RegExp(r'[぀-ヿ㐀-鿿]');

/// 1.0.0+19 の開いた事業カードの高さ（幅390・本物のフォント・育った会社の26事業の中央値）。この回の前に測った値
const beforeCardJa = 823.0, beforeCardEn = 839.0;

/// 1.0.0+19 で、育った会社の1か月の用事を済ませるまでに押した回数（数え方は下の「押す回数」のテスト）
const beforeTaps = 18;

Key _k(String s) => ValueKey(s);

/// 月を進めても出来事で止まらないように片付けながら進める
void _month(Game g) {
  resolveEvents(g);
  g.nextQuarter();
}

void main() {
  group('A 責任者に任せる（仕組み）', () {
    test('任せる・戻すは手を使わず、いつでも切り替えられる。責任者がいない事業は任せられない', () {
      final g = _grown();
      final b = g.biz.firstWhere((b) => b.mgr != null);
      final none = g.biz.firstWhere((b) => b.mgr == null);
      final ap = g.ap;
      expect(g.canDeleg(b), isTrue);
      g.setDeleg(b, true);
      expect(g.delegated(b), isTrue);
      g.setBudget(b, 3);
      expect(g.delegBudget(b), g.capexOf(indm[b.ind]!) * 10);
      g.setDeleg(b, false);
      expect(g.delegated(b), isFalse);
      g.setDeleg(none, true);
      expect(none.deleg, isFalse, reason: '責任者がいない');
      expect(g.ap, ap, reason: '切り替えに手は使わない');
      // まとめて任せる・まとめて戻す
      final n = g.biz.where(g.canDeleg).length;
      g.delegAll();
      expect(g.delegatedBiz().length, n);
      expect(g.biz.where((b) => b.mgr == null).any((b) => b.deleg), isFalse);
      g.undelegAll();
      expect(g.delegatedBiz(), isEmpty);
      expect(g.ap, ap);
      // 責任者を外すと、任せるのもやめる
      g.setDeleg(b, true);
      g.setManager(b, null);
      expect(b.deleg, isFalse);
    });

    test('古いセーブ（任せるの印が無い）が読める。印と月の枠はセーブに残る', () {
      final g = _grown();
      final old = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
      for (final b in old['biz'] as List) {
        expect((b as Map).containsKey('deleg'), isFalse, reason: '任せていない事業は、前の版と同じ形のセーブ');
        expect(b.containsKey('budget'), isFalse);
        expect(b.containsKey('did'), isFalse);
      }
      final back = Game.fromJson(old, rng: ParkMiller(1));
      expect(back.biz.any((b) => b.deleg), isFalse);
      expect(back.biz.every((b) => b.budget == 1), isTrue, reason: '既定の枠は元手の1倍');
      final b = g.biz.firstWhere((b) => b.mgr != null);
      g.setDeleg(b, true);
      g.setBudget(b, 2);
      b.did = M('様子を見ました');
      final again = Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>, rng: ParkMiller(1));
      final b2 = again.biz.firstWhere((x) => x.id == b.id);
      expect(b2.deleg, isTrue);
      expect(b2.budget, 2);
      expect(txIn(b2.did, 'ja'), '様子を見ました');
    });

    test('任せた事業は毎月、責任者が手を打つ：社長の手は減らない・値段は固定額・月の枠まで・1人につき月1つ', () {
      final g = _grown();
      g.cash = 1e13;
      g.delegAll();
      final kinds = <String, int>{};
      for (var m = 0; m < 36 && g.over == null; m++) {
        _month(g);
        expect(g.ap, g.apMax, reason: '社長の手は使わない');
        final acts = g.delegLog.where((a) => a.turn == g.turn).toList();
        expect(acts.map((a) => a.biz).toSet().length, acts.length, reason: '1つの事業に月1つまで');
        for (final a in acts) {
          kinds[a.k] = (kinds[a.k] ?? 0) + 1;
          final b = g.biz.where((x) => x.id == a.biz).firstOrNull;
          if (b == null) continue;
          expect(a.cost, lessThanOrEqualTo(g.delegBudget(b) * 1.000001), reason: '月の枠（元手の1倍）まで: ${a.k}');
          // 値段は、社長が打つときと同じ固定額（元手の何倍か・人数ぶんの採用の費用）
          final cap = g.capexOf(indm[b.ind]!);
          switch (a.k) {
            case 'build':
              expect(buildUnits.any((n) => (a.cost - cap * n).abs() < cap * 1e-9), isTrue);
            case 'ext':
              expect(a.cost, closeTo(cap * extendMult, cap * 1e-9));
            case 'dev':
              expect(devMults.any((n) => (a.cost - cap * n).abs() < cap * 1e-9), isTrue);
            case 'crew':
              final per = g.hireCost(b, 1);
              expect((a.cost / per - (a.cost / per).round()).abs(), lessThan(1e-6), reason: '人数ぶんの採用の費用');
            case 'price' || 'none':
              expect(a.cost, 0);
          }
        }
      }
      // 任せない手（海外・売る・分社・稼ぎ方・値下げ合戦・裏の手）は、種類として存在しない
      expect(kinds.keys.toSet().difference({'crew', 'build', 'ext', 'dev', 'ad', 'price', 'none'}), isEmpty);
      expect((kinds['build'] ?? 0) + (kinds['dev'] ?? 0) + (kinds['crew'] ?? 0), greaterThan(50), reason: '手を打っている: $kinds');
      expect(kinds['none'] ?? 0, greaterThan(0), reason: '外れる（様子見の）月もある: $kinds');
      // 事業カードの1行
      final did = g.delegatedBiz().where((b) => b.did != null).toList();
      expect(did, isNotEmpty);
      for (final b in did) {
        expect(txIn(b.did, 'ja'), isNotEmpty);
        expect(_cjk.hasMatch(txIn(b.did, 'en')), isFalse, reason: txIn(b.did, 'en'));
      }
    });

    test('月の枠が0なら、お金は使わない。手元のお金が固定費の3か月分を割るときも使わない', () {
      final g = _grown();
      g.cash = 1e13;
      g.delegAll();
      for (final b in g.biz) {
        g.setBudget(b, 0);
      }
      for (var m = 0; m < 6; m++) {
        _month(g);
        expect(g.delegLog.where((a) => a.turn == g.turn).every((a) => a.cost == 0), isTrue);
      }
      final h = _grown();
      h.delegAll();
      h.calcAll();
      h.cash = h.delegReserve() * .5;
      h.delegMonthly();
      expect(h.delegLog.every((a) => a.cost == 0), isTrue, reason: '手元のお金を残す');
    });

    test('性格で打つ手が変わる：慎重な人は増やさない・博打打ちは大きく張る。腕が高いほど外さない', () {
      Map<String, int> run(String trait, int ab, {int amb = 50}) {
        final g = _grown(9);
        g.cash = 1e13;
        final b = g.biz.firstWhere((b) => b.mgr != null && b.model != 'fc');
        final p = g.staffById(b.mgr)!;
        p.trait = trait;
        p.amb = amb;
        p.ab[indm[b.ind]!.key] = ab;
        g.setDeleg(b, true);
        g.setBudget(b, 3);
        final out = <String, int>{};
        for (var m = 0; m < 120 && g.biz.contains(b) && g.staffById(b.mgr) == p; m++) {
          _month(g);
          g.cash = 1e13;
          p.trait = trait;
          p.amb = amb;
          p.ab[indm[b.ind]!.key] = ab;
          for (final a in g.delegLog.where((a) => a.turn == g.turn)) {
            out[a.k] = (out[a.k] ?? 0) + 1;
            final cap = g.capexOf(indm[b.ind]!);
            if (a.k == 'build' && (a.cost - cap * 10).abs() < cap * 1e-9) out['build10'] = (out['build10'] ?? 0) + 1;
          }
        }
        return out;
      }

      final careful = run('careful', 70);
      expect((careful['build'] ?? 0) + (careful['ext'] ?? 0), 0, reason: '慎重な人は店・工場を増やさない: $careful');
      // 月の枠は元手の10倍・お金は十分にある
      final gambler = run('gambler', 70);
      expect(gambler['build'] ?? 0, greaterThan(0));
      expect(gambler['build10'], gambler['build'], reason: '博打打ちは、いつも枠いっぱいの10店を張る: $gambler');
      final plain = run('grit', 70);
      expect(plain['build10'] ?? 0, greaterThan(0), reason: 'ふつうの人も枠いっぱいに張ることがある: $plain');
      expect(plain['build10'] ?? 0, lessThan(plain['build'] ?? 0), reason: 'ふつうの人は、1段小さく張ることもある: $plain');
      final good = run('grit', 99), bad = run('grit', 10);
      expect(good['none'] ?? 0, lessThan(bad['none'] ?? 0), reason: '腕が高いほど様子見が少ない: $good / $bad');
      final g = _grown();
      final b = g.biz.firstWhere((b) => b.mgr != null);
      final p = g.staffById(b.mgr)!;
      p.ab[indm[b.ind]!.key] = 99;
      final lo = g.delegMiss(b, p);
      p.ab[indm[b.ind]!.key] = 20;
      expect(lo, lessThan(g.delegMiss(b, p)));
    });

    test('任せた事業の責任者は、自分で打てる手（人・店や工場・商品・広告・値付け）を経営会議に持ってこない', () {
      final g = _grown();
      g.cash = 1e13;
      final b = g.biz.firstWhere((b) => b.mgr != null && b.model != 'fc');
      final p = g.staffById(b.mgr)!;
      Set<String> kinds() => {
            for (var i = 0; i < 300; i++)
              if (g.proposalFor(p) case final o?) o.k,
          };
      const own = {'crew', 'build', 'dev', 'ad', 'price', 'cut'};
      expect(kinds().intersection(own), isNotEmpty, reason: '任せていなければ、今までどおり提案する');
      g.setDeleg(b, true);
      expect(kinds().intersection(own), isEmpty, reason: '任せたら、自分で打つ');
      g.setDeleg(b, false);
      expect(kinds().intersection(own), isNotEmpty, reason: '戻せば、また提案する');
    });

    test('任せていた責任者が辞めたあとに新しい人を置いても、任せ直すまでは自分で動かす', () {
      final g = _grown();
      final b = g.biz.firstWhere((b) => b.mgr != null);
      final p = g.staffById(b.mgr)!;
      final other = g.staff.firstWhere((x) => x != p);
      g.setDeleg(b, true);
      // 人を替えただけなら、任せたまま引き継ぐ
      g.setManager(b, other.id);
      expect(g.delegated(b), isTrue);
      g.fire(other);
      expect(g.delegated(b), isFalse);
      final next = g.staff.firstWhere((x) => !g.biz.any((y) => y.mgr == x.id), orElse: () => g.staff.first);
      for (final y in g.biz) {
        if (y.mgr == next.id) y.mgr = null;
      }
      g.setManager(b, next.id);
      expect(g.delegated(b), isFalse);
      expect(b.deleg, isFalse);
    });

    test('extras を切ると、任せる仕組みは動かない', () {
      final g = Game.newGame(SetupConfig(mode: 'world', year: 1980), rng: ParkMiller(3), extras: false);
      for (var i = 0; i < 60; i++) {
        botMonth(g);
      }
      final b = g.biz.where((b) => b.mgr != null).firstOrNull;
      if (b != null) {
        expect(g.canDeleg(b), isFalse);
        b.deleg = true;
        g.delegMonthly();
        expect(g.delegLog, isEmpty);
      }
      expect(g.adviceTips().any((t) => t.act == 'deleg'), isFalse);
    });

    test('月の報告のまとめは1〜3行（事業ごとには並べない）。英語に日本語が残らない', () {
      final g = _grown();
      g.cash = 1e13;
      expect(g.delegSummary(g.turn), isEmpty, reason: '任せていなければ出さない');
      g.delegAll();
      final t0 = g.turn;
      for (var m = 0; m < 12; m++) {
        _month(g);
        final one = g.delegSummary(g.turn - 1);
        expect(one.length, inInclusiveRange(1, 3));
      }
      final year = g.delegSummary(t0);
      expect(year.length, inInclusiveRange(1, 3));
      expect(txIn(year.first, 'ja'), contains('任せた'));
      for (final m in year) {
        expect(RegExp(r'\{\d+\}').hasMatch(txIn(m, 'ja')), isFalse);
        expect(_cjk.hasMatch(txIn(m, 'en')), isFalse, reason: txIn(m, 'en'));
      }
    });

    test('番頭のひとこと：責任者のいる事業が3つ以上で、まだ1つも任せていなければ、半年に1度「任せる」を勧める', () {
      final g = _grown();
      while (g.turn % 6 != 2) {
        g.turn++;
      }
      final tip = g.adviceTips().where((t) => t.act == 'deleg').toList();
      expect(tip, hasLength(1));
      expect(_cjk.hasMatch(txIn(tip.first.m, 'en')), isFalse);
      g.delegAll();
      expect(g.adviceTips().any((t) => t.act == 'deleg'), isFalse);
      g.undelegAll();
      g.turn++;
      expect(g.adviceTips().any((t) => t.act == 'deleg'), isFalse, reason: '毎月は言わない');
    });

    test('釣り合い：任せた事業の伸びは、人が同じお金で最善手を打ったときより小さい（全部任せるのが最善にならない）', () {
      final g = Game.newGame(SetupConfig(mode: 'endless', year: 1985, traits: const ['charm', 'careful']), rng: ParkMiller(11));
      for (var m = 0; m < 120 && g.over == null; m++) {
        delegMonth(g, 'none');
      }
      resolveEvents(g);
      // 物差しは「使ったお金1円あたりの、打った手の力の伸びの見込み」（商品の大当たり・不発をならした値。当たり外れに左右されない）
      for (final budget in const [1, 2, 3]) {
        var a = 0.0, b = 0.0, sa = 0.0, sb = 0.0;
        for (final seed in const [5, 6]) {
          final r = delegVsBest(g, months: 36, budget: budget, seed: seed);
          a += r.gainA;
          b += r.gainB;
          sa += r.spentA;
          sb += r.spentB;
        }
        final perYen = (a / sa) / (b / sb);
        // ignore: avoid_print
        print('同じお金あたりの伸びの見込み：任せた ÷ 最善手（種11・36か月・2本・枠 元手の${delegMults[budget]}倍）: ${perYen.toStringAsFixed(3)}（使ったお金の比 ${(sa / sb).toStringAsFixed(2)}）');
        // 目安は7〜9割。手元で5つの盤面×6本×60か月を回した値は test/h_balance_test.dart の頭の注釈にある。ここでは幅を少し広めに見る
        expect(perYen, inInclusiveRange(.6, .95), reason: '枠 元手の${delegMults[budget]}倍');
        // 「使うお金も人より少ない」は 1.1.0+25 で外した（人の最善手は社長の時間で月に打てる数が限られ、任せた事業より使うお金が少ないことがある）
      }
    }, timeout: const Timeout(Duration(minutes: 5)));
  });

  group('B「今月やること」から1回で実行', () {
    /// その種類のひとことが「今月やること」に出る月まで、月の数だけを送る（ひとことは月ごとに順ぐりに出る）
    void showTip(Game g, String act) {
      for (var i = 0; i < 40 && !g.adviceTop().any((t) => t.act == act); i++) {
        g.turn++;
      }
      expect(g.adviceTop().any((t) => t.act == act), isTrue, reason: '$act が出ない');
    }

    /// 1つの事業だけ人手不足にする
    Biz shortOne(Game g) {
      for (final b in g.crewShort()) {
        b.crew = b.power * 3;
      }
      final b = g.biz.firstWhere((b) => b.model != 'fc' && b.power > 0);
      b.crew = b.power * .4 / g.crewMult(b);
      g.calcAll();
      expect(g.crewNeedPeople(b), greaterThan(0));
      return b;
    }

    for (final lang in const ['ja', 'en']) {
      testWidgets('人が足りない行の「足りない人を雇う（人数・値段）」を押すと、その場で雇えて行が消える（$lang）', (tester) async {
        final g = _grown();
        g.cash = 1e12;
        final b = shortOne(g);
        showTip(g, 'hire');
        final p = await Pilot.launch(tester, game: g, lang: lang);
        final i = g.adviceTop().indexWhere((t) => t.act == 'hire');
        final need = g.crewNeedPeople(b), cost = g.hireCost(b, need);
        final btn = find.byKey(_k('todo-act-$i'));
        expect(find.descendant(of: btn, matching: find.text(tr('足りない人を雇う（{0}人・{1}）', [need, yen(cost)]))), findsOneWidget);
        expect(find.descendant(of: btn, matching: find.text(tr('{0}時間', [g.hrs('crew').round()]))), findsOneWidget, reason: 'かかる社長の時間を書く（1.1.0+25）');
        final h0 = g.hUsed, cash = g.cash;
        await p.press(btn);
        expect(g.crewNeedPeople(b), 0);
        expect(g.hUsed - h0, g.hrs('crew'));
        expect(g.cash, closeTo(cash - cost, 1));
        await p.drain();
        expect(g.adviceTop().any((t) => t.act == 'hire'), isFalse);
        expect(find.textContaining(tr('足りない人を雇う（{0}人・{1}）', [need, yen(cost)])), findsNothing, reason: '行が消える');
        expect(p.found, isEmpty, reason: p.found.join('\n'));
      });
    }

    testWidgets('お金や手が足りないときは薄くなり、押すと理由を言う', (tester) async {
      final g = _grown();
      final b = shortOne(g);
      showTip(g, 'hire');
      g.cash = 0;
      final p = await Pilot.launch(tester, game: g);
      final i = g.adviceTop().indexWhere((t) => t.act == 'hire');
      expect(tester.widget<Btn>(find.byKey(_k('todo-act-$i'))).dim, isTrue);
      await p.press(find.byKey(_k('todo-act-$i')));
      expect(p.inSheet(find.text('お金が足りません')), findsOneWidget);
      await p.drain();
      expect(g.crewNeedPeople(b), greaterThan(0));
      g.cash = 1e12;
      g.ap = 0;
      p.ctl.render();
      await p.pump();
      await p.press(find.byKey(_k('todo-act-$i')));
      expect(p.inSheet(find.textContaining('今月の社長の時間が足りません')), findsOneWidget);
      await p.drain();
      expect(p.found, isEmpty, reason: p.found.join('\n'));
    });

    testWidgets('担当なしの部下は「責任者に置く」で、その場で置ける', (tester) async {
      final g = _grown();
      expect(g.managerPlan(), isNotEmpty);
      showTip(g, 'place');
      final n = g.managerPlan().length;
      final p = await Pilot.launch(tester, game: g);
      final i = g.adviceTop().indexWhere((t) => t.act == 'place');
      expect(find.descendant(of: find.byKey(_k('todo-act-$i')), matching: find.text('責任者に置く（$n人）')), findsOneWidget);
      final ap = g.ap;
      await p.press(find.byKey(_k('todo-act-$i')));
      expect(g.managerPlan(), isEmpty);
      expect(g.ap, ap, reason: '手は使わない');
      await p.drain();
      expect(p.found, isEmpty, reason: p.found.join('\n'));
    });

    testWidgets('その場で打てないものは、該当の場所へ飛ぶ：事業のカードは一覧のいちばん上に開く', (tester) async {
      final g = _grown();
      // いちばん売上の小さい事業を4か国に出す（「あと1か国で規模の利益」のひとこと → その事業のカードへ）
      final b = (g.biz.where((b) => g.ctryOf(b).length < 4).toList()..ssort((a, b) => a.rev.compareTo(b.rev))).first;
      for (final x in g.biz) {
        if (x != b && g.ctryOf(x).length == 4) x.ctry = g.ctryOf(x).take(3).toList();
      }
      b.ctry = [g.home, ...CTRY.where((c) => c.c != g.home).take(3).map((c) => c.c)];
      b.pipe.clear();
      g.calcAll();
      final p = await Pilot.launch(tester, game: g);
      // 全部のひとことは小窓「番頭のひとこと」に、同じボタンつきで並ぶ
      await p.pressKey('todo-all');
      final label = '「${indm[b.ind]!.name}」を開く';
      expect(p.inSheet(find.text(label)), findsWidgets);
      await p.press(p.inSheet(find.text(label)).first);
      await p.pump();
      expect(p.ctl.sheet, isNull);
      expect(p.ctl.tab, 'biz');
      expect(p.ctl.openBiz, b.id);
      final card = find.byKey(_k('biz-card-${b.id}'));
      expect(card.hitTestable(), findsOneWidget, reason: '動かさなくても見えている');
      expect(tester.getRect(card).top, lessThan(260), reason: '一覧のいちばん上');
      // たたむと、いつもの並びに戻る
      await p.pressKey('biz-fold-${b.id}');
      expect(p.ctl.pinBiz, isNull);
      // 画面を替えるだけのもの（「株」を開く）
      await p.tab('town');
      await p.pressKey('todo-all');
      if (p.inSheet(find.text('「株」を開く')).evaluate().isNotEmpty) {
        await p.press(p.inSheet(find.text('「株」を開く')).first);
        expect(p.ctl.tab, 'stock');
        expect(p.ctl.sheet, isNull);
      } else {
        await p.drain();
      }
      expect(p.found, isEmpty, reason: p.found.join('\n'));
    });

    testWidgets('新しい市場のひとことは、「新しい事業」の一覧でその業種を探した所へ飛ぶ', (tester) async {
      final g = _grown();
      final tip = g.adviceTips().where((t) => t.act == 'newInd').firstOrNull;
      if (tip == null) return;
      final ind = indm[tip.ref]!;
      final p = await Pilot.launch(tester, game: g);
      await p.pressKey('todo-all');
      await p.press(p.inSheet(find.text('「${ind.name}」を探す')).first);
      await p.pump();
      await p.pump();
      expect(p.ctl.tab, 'biz');
      expect(p.ctl.bizSearch.text, ind.name);
      // その業種の行が、動かさなくても画面の中に見えている
      expect(find.byKey(_k('newbiz-${ind.id}')), findsOneWidget);
      expect(tester.getRect(find.byKey(_k('newbiz-${ind.id}'))).top, inInclusiveRange(100, 700));
      expect(p.found, isEmpty, reason: p.found.join('\n'));
    });

    test('ひとこと（文）は前の版と同じ並び。ボタンの種類だけが増えた', () {
      final g = _grown();
      expect(g.adviceAll(), [for (final t in g.adviceTips()) t.m]);
      expect(g.advice(), [for (final t in g.adviceTop()) t.m]);
      const kinds = {'start', 'stock', 'people', 'staff', 'bizTab', 'biz', 'newInd', 'hire', 'hireAll', 'place', 'holding', 'deleg'};
      for (var m = 0; m < 24; m++) {
        for (final t in g.adviceTips()) {
          expect(t.act, isNotNull, reason: '行き先の無いひとこと: ${txIn(t.m, 'ja')}');
          expect(kinds.contains(t.act), isTrue, reason: t.act);
        }
        _month(g);
      }
    });
  });

  group('C 事業カードを軽く', () {
    testWidgets('開いたカードに常に出るのは2〜3個の手と「ほかの手」。押すと今までの3つの組と「売る」がそのまま出る（できることは減らない）', (tester) async {
      final g = _grown();
      g.cash = 1e12;
      final p = await Pilot.launch(tester, game: g);
      for (final b in [g.biz.first, g.biz.firstWhere((b) => b.model == 'fc', orElse: () => g.biz.last), g.biz.last]) {
        final card = await p.card(b);
        final top = find.byKey(_k('biz-top-${b.id}'));
        final n = find.descendant(of: top, matching: find.byType(Btn)).evaluate().length;
        expect(n, inInclusiveRange(3, 4), reason: '2〜3個の手＋「ほかの手」');
        expect(find.descendant(of: top, matching: find.text('ほかの手')), findsOneWidget);
        for (final k in ['grp-grow', 'grp-fight', 'grp-shape', 'biz-sell']) {
          expect(find.byKey(_k('$k-${b.id}')), findsNothing, reason: 'たたんでいる');
        }
        await p.pressKey('biz-more-${b.id}');
        expect(find.byKey(_k('biz-top-${b.id}')), findsNothing);
        bool has(String grp, String label) => find.descendant(of: find.byKey(_k('$grp-${b.id}')), matching: find.textContaining(label)).evaluate().isNotEmpty;
        // 伸ばす（5つ。フランチャイズは人を雇わないので4つ）
        expect(has('grp-grow', '${txIn(g.uw(b), 'ja')}を増やす'), isTrue);
        expect(has('grp-grow', '商品を作る'), isTrue);
        expect(has('grp-grow', '現場の人を増やす'), b.model != 'fc');
        expect(has('grp-grow', '広告 '), isTrue);
        expect(has('grp-grow', '海外に出る'), isTrue);
        // 戦う（値付け・値下げ合戦・業界団体）
        expect(find.descendant(of: find.byKey(_k('grp-fight-${b.id}')), matching: find.byType(DropdownButton<String>)), findsOneWidget);
        if (g.competitors(b).isNotEmpty) expect(has('grp-fight', '値下げ合戦'), isTrue);
        // 形を変える
        expect(has('grp-shape', '分社・独立'), isTrue);
        expect(has('grp-shape', '稼ぎ方を変える'), g.modelsFor(b.ind).length > 1);
        expect(has('grp-shape', '業態を変える'), g.pivotTargets(b).isNotEmpty);
        expect(has('biz-sell', '売る（約'), isTrue);
        expect(find.descendant(of: card, matching: find.text('手をたたむ')), findsOneWidget);
        await p.pressKey('biz-more-${b.id}');
        expect(find.byKey(_k('grp-grow-${b.id}')), findsNothing);
      }
      expect(p.found, isEmpty, reason: p.found.join('\n'));
    });

    testWidgets('人が足りない事業は「足りない人を雇う」が先頭に出て、小窓を開かずに雇える。責任者がいなければ「責任者に置く」', (tester) async {
      final g = _grown();
      g.cash = 1e12;
      final b = g.biz.firstWhere((b) => b.model != 'fc' && b.power > 0 && b.mgr == null);
      b.crew = b.power * .4 / g.crewMult(b);
      g.calcAll();
      final need = g.crewNeedPeople(b), cost = g.hireCost(b, need);
      final free = (g.staff.where((x) => !g.biz.any((y) => y.mgr == x.id)).toList()..ssort((x, y) => y.ab[indm[b.ind]!.key]!.compareTo(x.ab[indm[b.ind]!.key]!))).first;
      final p = await Pilot.launch(tester, game: g);
      await p.card(b);
      final top = find.byKey(_k('biz-top-${b.id}'));
      final labels = [for (final e in find.descendant(of: top, matching: find.byType(Btn)).evaluate()) (e.widget as Btn).label];
      expect(labels.first, '足りない人を雇う（$need人・${yen(cost)}）');
      expect(labels[1], '${free.name}を責任者に置く');
      final cash = g.cash;
      await p.pressKey('top-hire-${b.id}');
      expect(g.crewNeedPeople(b), 0);
      expect(g.cash, closeTo(cash - cost, 1));
      await p.drain();
      await p.card(b);
      expect(find.byKey(_k('top-hire-${b.id}')), findsNothing, reason: '済んだら入れ替わる');
      await p.pressKey('top-mgr-${b.id}');
      expect(b.mgr, free.id);
      // 責任者が付いたら、任せられる
      expect(find.byKey(_k('deleg-on-${b.id}')), findsOneWidget);
      expect(p.found, isEmpty, reason: p.found.join('\n'));
    });

    for (final lang in const ['ja', 'en']) {
      testWidgets('開いたカードの高さ（幅390・$lang）：前より3割以上低い', (tester) async {
        await loadRealFonts();
        final g = _grown();
        final p = await Pilot.launch(tester, game: g, lang: lang);
        await p.tab('biz');
        Future<List<double>> heights() async {
          final hs = <double>[];
          for (final b in g.biz) {
            p.ctl.openBiz = b.id;
            p.ctl.render();
            await p.pump();
            final card = find.byKey(_k('biz-card-${b.id}'));
            await p.reveal(card);
            hs.add(tester.getSize(card).height);
          }
          return hs..sort();
        }

        final hs = await heights();
        g.delegAll();
        for (final b in g.delegatedBiz()) {
          b.did = M('現場の人を{0}人雇いました（{1}）', [12, Y(3.2e8)]);
        }
        final hd = await heights();
        final before = lang == 'ja' ? beforeCardJa : beforeCardEn;
        final med = hs[hs.length ~/ 2], medD = hd[hd.length ~/ 2];
        // ignore: avoid_print
        print('開いたカードの高さ $lang：前 $before → 今 $med（${((1 - med / before) * 100).round()}%低い・最小 ${hs.first}・最大 ${hs.last}）／任せ中 $medD（${((1 - medD / before) * 100).round()}%低い・最大 ${hd.last}）');
        expect(med, lessThanOrEqualTo(before * .7));
        expect(medD, lessThanOrEqualTo(before * .7), reason: '任せ中（月の枠と今月の1行が増える）でも3割低い');
        expect(p.found, isEmpty, reason: p.found.join('\n'));
      });
    }
  });

  group('A 責任者に任せる（画面）', () {
    testWidgets('事業カードで任せる → 「任せ中」の札・月の枠・今月の1行。一覧の「まとめて任せる」「まとめて戻す」。報告に1〜3行', (tester) async {
      final g = _grown();
      g.cash = 1e13;
      final b = g.biz.firstWhere((b) => b.mgr != null);
      final p = await Pilot.launch(tester, game: g);
      final card = await p.card(b);
      final h0 = g.hUsed, meet0 = g.hMeet();
      await p.pressKey('deleg-on-${b.id}');
      expect(g.delegated(b), isTrue);
      // 任せるのに時間は使わず、会議の時間が減る（1.1.0+25）
      expect(g.hUsed, h0);
      expect(g.hMeet(), lessThan(meet0));
      expect(find.descendant(of: card, matching: find.text('任せ中')), findsOneWidget);
      expect(find.byKey(_k('deleg-budget-${b.id}')), findsOneWidget);
      expect(find.byKey(_k('deleg-did-${b.id}')), findsOneWidget);
      // 月の枠を選ぶ（元手の 0／1／3／10 倍）
      await p.press(find.descendant(of: find.byKey(_k('deleg-budget-${b.id}')), matching: find.byType(DropdownButton<int>)));
      await tester.pump(const Duration(milliseconds: 400));
      for (final i in [1, 2, 3]) {
        expect(find.text('${yen(g.delegBudgetAt(b, i))}まで（元手の${delegMults[i]}倍）'), findsWidgets);
      }
      await tester.tap(find.text('${yen(g.delegBudgetAt(b, 2))}まで（元手の3倍）').last, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(b.budget, 2);
      // 任せていても、社長が自分で手を打てる（できることは減らない）
      expect(find.byKey(_k('biz-top-${b.id}')), findsOneWidget);
      await p.pressKey('deleg-off-${b.id}');
      expect(g.delegated(b), isFalse);
      // たたんだ行にも札
      await p.pressKey('biz-fold-${b.id}');
      final bar = find.byKey(_k('deleg-bar'));
      await p.reveal(bar);
      await p.pressKey('deleg-all');
      await p.drain();
      final n = g.biz.where(g.canDeleg).length;
      expect(g.delegatedBiz().length, n);
      expect(find.descendant(of: bar, matching: find.textContaining('任せ中 $n／$n', findRichText: true)), findsOneWidget);
      await p.reveal(find.byKey(_k('biz-row-${b.id}')));
      expect(find.descendant(of: find.byKey(_k('biz-row-${b.id}')), matching: find.text('任せ中')), findsOneWidget);
      // 3か月進めると、報告に「任せた事業でやったこと」が1〜3行
      await p.pressKey('advance-menu');
      await p.pressKey('adv-3');
      final rep = find.byKey(_k('report-deleg'));
      if (p.ctl.sheet != null && rep.evaluate().isNotEmpty) {
        expect(find.byKey(_k('report-deleg-line')).evaluate().length, inInclusiveRange(1, 3));
      }
      await p.drain();
      expect(g.delegLog, isNotEmpty);
      expect(g.delegatedBiz().any((x) => x.did != null), isTrue);
      await p.tab('biz');
      await p.reveal(bar);
      await p.pressKey('undeleg-all');
      await p.drain();
      expect(g.biz.any((x) => x.deleg), isFalse);
      expect(p.found, isEmpty, reason: p.found.join('\n'));
    });

    testWidgets('押す回数：育った会社で、1か月の用事を済ませるまで（前 $beforeTaps 回）', (tester) async {
      // 数え方（前の版も同じ道筋で数えた）:
      //  1 人手不足の事業に足りない人を雇う　2 担当のない部下を責任者に置く　3「今月やること」の3行の場所を見る・打つ
      //  4 残りの手を、いちばん売上の大きい事業の「店・工場を増やす」に使い切る　5「次の月へ」を押して、報告を閉じる
      // 前の版: 1 は「事業」→「足りない人をまとめて雇う」→ OK（3回）、2 は「空いている部下を責任者に置く」→ OK（2回）、
      //         3 は「人」→ 部下の行 →「株」（3回）、4 は 行を開く → 増やす → 数を選ぶ → OK を2手ぶん（8回）、5 は2回 ＝ 18回。
      //         責任者のいる22の事業のうち、手を打てたのは1つ（残りの手が2つしか無い）
      Future<(int, String)> run(bool deleg) async {
        // 前の版を数えたときと同じ盤面・同じ乱数の続きから（写しではなく、作ったままの会社）
        final g = grownGame();
        final p = await Pilot.launch(tester, game: g);
        if (deleg) {
          // 前の月に、責任者を置いて、まとめて任せてある（最初の1回だけの操作。数に入れない）
          g.placeManagers();
          g.delegAll();
          _month(g);
          resolveEvents(g);
          p.ctl.render();
          await p.pump();
        }
        final log = <String>[];
        var last = 0;
        void lap(String what) {
          log.add('$what ${p.taps - last}');
          last = p.taps;
        }

        p.taps = 0;
        // 3:「今月やること」の3行のボタンを押す（月のはじめに出ている3行）。同じ画面へ飛ぶ行（「株」を開く、が2つなど）は、1回で両方が片付く
        final tips = g.adviceTop();
        final went = <String>{};
        for (var i = 0; i < tips.length; i++) {
          final where = '${tips[i].act}${tips[i].ref is Biz ? (tips[i].ref as Biz).id : tips[i].ref is Person ? (tips[i].ref as Person).id : ''}';
          if (!went.add(where)) continue;
          await p.tab('town');
          final f = find.byKey(_k('todo-act-$i'));
          if (f.evaluate().isEmpty) continue;
          await p.press(f);
          await p.drain();
        }
        lap('やること（${tips.map((t) => t.act).join('・')}）');
        // 1: 人手不足（任せた事業の分は、責任者が自分で雇うので、社長は手を出さない）
        Future<void> bizList() async {
          await p.tab('biz');
          // 「新しい事業」へ飛んだあとは、自社の一覧がたたまれている。開き直す
          if (p.ctl.folded.contains('mybiz')) await p.press(find.descendant(of: find.byKey(_k('fold-mybiz')), matching: find.byType(InkWell)));
        }

        if (g.crewShort().any((b) => !g.delegated(b))) {
          await bizList();
          await p.pressKey('hire-short-all');
          await p.drain();
        }
        lap('人手不足');
        // 2: 担当のない部下を責任者に置く
        if (g.managerPlan().isNotEmpty) {
          await bizList();
          await p.pressKey('place-managers');
          await p.drain();
        }
        lap('責任者');
        // 4: 任せていれば、事業を伸ばす手は責任者が打つ（社長の手は、海外や買収などに取っておける）
        final ap = g.ap;
        if (!deleg) {
          final top = (g.biz.toList()..sort((a, b) => b.rev.compareTo(a.rev))).first;
          while (g.ap > 0) {
            final a0 = g.ap;
            await p.build(top);
            if (g.ap == a0) break;
          }
        }
        lap('伸ばす手（$ap手）');
        final t = g.turn;
        await p.next();
        lap('次の月へ');
        final moved = g.delegLog.where((a) => a.turn == t + 1 && a.k != 'none').length;
        expect(p.found, isEmpty, reason: p.found.join('\n'));
        return (p.taps, '${log.join(' / ')}・責任者が打った手 $moved');
      }

      final self = await run(false);
      final dg = await run(true);
      // ignore: avoid_print
      print('押す回数：前 $beforeTaps → 今（自分で） ${self.$1}［${self.$2}］ → 今（任せて） ${dg.$1}［${dg.$2}］');
      // 1.1.0+25 から手の数ではなく社長の時間なので、月に打てる「伸ばす手」が3つ→最大12ほどに増え（8時間ずつ）、そのぶん押す回数が増える。
      // 段1では線を 18→30 に引き直す（手1つあたりの押す回数は変わらない。月に打てる数の釣り合いは後の段で見直す）
      expect(self.$1, lessThanOrEqualTo(30), reason: '自分で全部動かしても、手1つあたりの押す回数は前と同じ');
      expect(dg.$1, lessThanOrEqualTo(beforeTaps * 2 ~/ 3), reason: '任せれば3分の2以下');
    }, timeout: const Timeout(Duration(minutes: 5)));
  });

  group('はみ出し・折れ', () {
    for (final c in const [(390.0, 'ja'), (320.0, 'ja'), (390.0, 'en'), (320.0, 'en')]) {
      testWidgets('幅${c.$1.round()}・${c.$2}：今月やること・番頭のひとこと・任せる・軽いカード・報告に、はみ出しと2行に折れたボタンが無い', (tester) async {
        await loadRealFonts();
        final key = GlobalKey();
        final g = _grown();
        g.cash = 1e12;
        final n = '${c.$1.round()}_${c.$2}';
        // 行にボタンの付くひとことを、なるべく多く出す（人手不足2つ・担当なし・任せる）
        final shorts = g.biz.where((b) => b.model != 'fc' && b.power > 0).take(2).toList();
        for (final b in shorts) {
          b.crew = b.power * .4 / g.crewMult(b);
        }
        while (g.turn % 6 != 2) {
          g.turn++;
        }
        g.calcAll();
        final p = await Pilot.launch(tester, game: g, lang: c.$2, size: Size(c.$1, 844), boundary: key);
        p.watchWraps = true;
        await p.pump();
        await shot(tester, key, 'h_town_todo_$n');
        // 月を順に送って、いろいろなひとことの行を出す
        final t0 = g.turn;
        for (var i = 0; i < 8; i++) {
          g.turn++;
          p.ctl.render();
          await p.pump();
        }
        g.turn = t0;
        p.ctl.render();
        await p.pump();
        await p.pressKey('todo-all');
        await p.sweep();
        await shot(tester, key, 'h_advice_sheet_$n');
        await p.drain();
        // 事業：まとめて任せる・たたんだ行の札
        await p.tab('biz');
        await shot(tester, key, 'h_biz_top_$n');
        final b = g.biz.firstWhere((b) => b.mgr != null && !shorts.contains(b));
        await p.alignTop(await p.card(b));
        await shot(tester, key, 'h_card_light_$n');
        await p.pressKey('biz-more-${b.id}');
        await p.alignTop(find.byKey(_k('biz-card-${b.id}')));
        await shot(tester, key, 'h_card_more_$n');
        await p.reveal(find.byKey(_k('biz-sell-${b.id}')));
        await shot(tester, key, 'h_card_more_bottom_$n');
        await p.pressKey('biz-more-${b.id}');
        // 人が足りない・責任者がいない事業のカード
        final s0 = shorts.first;
        await p.alignTop(await p.card(s0));
        await shot(tester, key, 'h_card_short_$n');
        final un = g.biz.where((x) => x.mgr == null).firstOrNull;
        if (un != null) {
          await p.alignTop(await p.card(un));
          await shot(tester, key, 'h_card_nomgr_$n');
        }
        // 任せ中のカード（月の枠・今月の1行。長い1行も）
        await p.card(b);
        await p.pressKey('deleg-on-${b.id}');
        for (final m in [
          M('{0}増やし始めました（{1}）', [g.unitsOf(b, 10), Y(g.buildCost(b, 10))]),
          M('月の枠が0なので、お金のかかる手は打ちませんでした'),
          M('現場の人を{0}人雇いました（{1}）', [128, Y(3.84e9)]),
        ]) {
          b.did = m;
          p.ctl.render();
          await p.pump();
        }
        await p.alignTop(find.byKey(_k('biz-card-${b.id}')));
        await shot(tester, key, 'h_card_deleg_$n');
        await p.press(find.descendant(of: find.byKey(_k('deleg-budget-${b.id}')), matching: find.byType(DropdownButton<int>)));
        await tester.pump(const Duration(milliseconds: 400));
        p.check();
        await shot(tester, key, 'h_deleg_budget_$n');
        await tester.tap(find.text(tr('お金は使わせない')).last, warnIfMissed: false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        p.check();
        b.budget = 1;
        // まとめて任せて、1年進めた報告
        await p.pressKey('biz-fold-${b.id}');
        await p.reveal(find.byKey(_k('deleg-bar')));
        await p.pressKey('deleg-all');
        await shot(tester, key, 'h_deleg_all_toast_$n');
        await p.drain();
        await shot(tester, key, 'h_biz_deleg_rows_$n');
        await p.pressKey('advance-menu');
        await p.pressKey('adv-3');
        if (find.byKey(_k('report-deleg')).evaluate().isNotEmpty) await shot(tester, key, 'h_report_deleg_$n');
        await p.drain();
        await p.tab('biz');
        await p.sweep();
        await p.alignTop(await p.card(b));
        await shot(tester, key, 'h_card_deleg_after_$n');
        await p.tab('town');
        await shot(tester, key, 'h_town_after_$n');
        expect(p.found, isEmpty, reason: p.found.join('\n'));
        expect(p.wraps, isEmpty, reason: p.wraps.entries.map((e) => '${e.key} ← ${e.value}').join('\n'));
      }, timeout: const Timeout(Duration(minutes: 5)));
    }
  });
}

// 釣り合いの数字（手元で QUAD_H_BALANCE=1 flutter test test/h_balance_test.dart を回した値）は、test/h_balance_test.dart の頭の注釈にある
