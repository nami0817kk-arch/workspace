import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';
import 'package:quadrillion/ui/app.dart';
import 'package:quadrillion/ui/controller.dart';
import 'package:quadrillion/ui/sheets.dart';
import 'package:quadrillion/ui/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/bot.dart';

/// 1.0.0+12: 現金や時価総額に比例して値段が決まる手をやめ、「1単位いくら」の固定の値段にした。
///
/// 画面の書き出し（目で見る用）は QUAD_SHOTS に書き出し先を渡したときだけ動く（画像はコミットしない）
final _out = Platform.environment['QUAD_SHOTS'];

final _jp = RegExp('[぀-ヿ㐀-鿿！-～]');

Game _grown({int seed = 11, int months = 60, int year = 1990, List<String> traits = const ['charm', 'noble']}) {
  final s = Game.newGame(SetupConfig(mode: 'endless', year: year, traits: traits), rng: ParkMiller(seed));
  for (var i = 0; i < months; i++) {
    botMonth(s);
  }
  resolveEvents(s);
  s.calcAll();
  return s;
}

Biz _direct(Game s) => (s.biz.where((b) => b.model != 'fc').toList()..ssort((a, b) => b.rev.compareTo(a.rev))).first;

void main() {
  group('1単位の値段', () {
    // 1.1.0+26（段2）から、店・ライン・拠点などの1つの値段は、業種ごとの1単位の初期投資の実額（元手ではない）。立地で変わり、物価だけが乗る
    test('店などは1つが業種の1単位の初期投資。業種と年で変わり、現金では変わらない', () {
      final s = _grown();
      final b = _direct(s);
      final one = s.unitCapexAvg(b);
      expect(one, closeTo(profileOf(indm[b.ind]!).unitCapex * s.nom(), 1));
      expect(s.buildCost(b, 1), closeTo(one, 1));
      expect(s.buildCost(b, 3), closeTo(one * 3, 1));
      expect(s.buildCost(b, 10), closeTo(one * 10, 1));
      final c0 = s.buildCost(b, 3);
      s.cash *= 50;
      expect(s.buildCost(b, 3), c0);
      // 業種が違えば値段も違う
      final other = s.biz.firstWhere((x) => profileOf(indm[x.ind]!).unitCapex != profileOf(indm[b.ind]!).unitCapex, orElse: () => b);
      if (other != b) expect(s.buildCost(other, 1), isNot(s.buildCost(b, 1)));
      // 年が進むと物価の分だけ上がる
      final y0 = s.buildCost(b, 1);
      s.year += 10;
      expect(s.buildCost(b, 1) / y0, closeTo(nomOf(s.yr()) / nomOf(s.yr() - 10), 1e-9));
    });

    test('商品は元手の1倍・3倍・10倍、人は分類ごとの年の人件費、どれも現金では変わらない', () {
      final s = _grown();
      final b = _direct(s);
      final capex = s.capexOf(indm[b.ind]!);
      expect([for (var i = 0; i < 3; i++) s.devCost(b, i)], [capex, capex * 3, capex * 10]);
      // 1.1.0+25 から、人件費はその国の賃金（と店の仕事は最低賃金）の統計で動く
      expect(s.wageOf(b), s.wageCat(indm[b.ind]!.cat));
      expect(s.hireCost(b, 10), closeTo(s.wageOf(b) * hireFee * 10, 1e-3));
      expect(s.payPerMonth(b, 50), closeTo(s.wageOf(b) / 12 * 50, 1e-3));
      final d = s.devCost(b, 1), h = s.hireCost(b, 10);
      s.cash = 1e16;
      expect(s.devCost(b, 1), d);
      expect(s.hireCost(b, 10), h);
    });

    test('人件費の表は全部の分類にある（食・暮らし300万〜未来800万）', () {
      for (final k in CATN.ja.keys) {
        expect(wageByCat[k], isNotNull, reason: k);
      }
      expect(wageByCat['food'], 3e6);
      expect(wageByCat['fut'], 8e6);
    });

    test('裏の手は手ごとの固定額で、時価総額では変わらない（extras を切ると試作と同じ割合）', () {
      final s = _grown();
      final want = {'poach': 5e7, 'spy': 1e8, 'lobby': 5e8, 'cook': 2e7, 'cartel': 3e7};
      for (final k in want.keys) {
        expect(s.dirtyCost(k), closeTo(want[k]! * s.nom(), 1e-3), reason: k);
      }
      final v = s.dirtyCost('lobby');
      s.cap *= 100;
      expect(s.dirtyCost('lobby'), v);
      s.extras = false;
      expect(s.dirtyCost('lobby'), closeTo(s.cap * .015, 1));
    });

    test('配当・報酬の返上も現金や財産の割合ではない', () {
      final s = _grown();
      final a = s.meetingDividend(), o = s.oustDividend();
      s.cash *= 20;
      expect(s.meetingDividend(), a);
      expect(s.oustDividend(), o);
      s.wealth = 1e13;
      expect(s.presRefund(), closeTo(5e7 * s.nom(), 1e-3));
      s.wealth = 1e6;
      expect(s.presRefund(), 1e6);
    });
  });

  group('単位で買ったときの効き目', () {
    // 1.1.0+26（段2）から、増やす手は「いちばん良い立地に、責任者・物件・上限の分だけ開く」。払った額が開く仕掛かりに入り、
    // 開いたときに数と客（事業の力）が増える。割合の手と同じ1円あたりの効き目ではなく、1単位の売上に見合う分だけ
    test('店など：払った額が開く仕掛かりに入り、開くと数と客が増える', () {
      final s = _grown();
      final b = _direct(s);
      s.cash = s.buildCost(b, 10) * 3;
      s.ap = 3;
      b.leads = 10;
      final site = s.siteKeys(s.home, s.kindB(b)).first;
      b.offers = [for (var i = 0; i < 5; i++) Offer(s: site)];
      b.lic = 0;
      s.calcAll();
      final c0 = s.cash, u0 = s.unitTotal(b);
      final r = s.buildN(b, 3);
      expect(msgKey(r), startsWith('{0}に{1}を開き始めました'), reason: txIn(r, 'ja'));
      final x = b.pipe.last;
      expect(x.k, 'open');
      expect(c0 - s.cash, closeTo(x.cost, 1));
      expect(x.cost, closeTo(s.unitCapexAt(b, x.c!) * x.pw!, 1));
      final p0 = b.power;
      b.pipe.remove(x);
      s.finishPipe(b, x, (m, [t = '']) {});
      expect(s.unitTotal(b), u0 + x.pw!);
      expect(b.power, greaterThan(p0));
    });

    test('商品：大きさが仕掛かりに残り、期間は大きいほど長い。保存しても消えない', () {
      final s = _grown();
      final b = _direct(s);
      s.cash = s.devCost(b, 2) * 2;
      for (var sz = 0; sz < 3; sz++) {
        s.ap = 3;
        s.developN(b, sz);
        final x = b.pipe.last;
        expect(x.sz, sz);
        expect(x.cost, s.devCost(b, sz));
        expect(x.left, inInclusiveRange(devMonths[sz].$1, devMonths[sz].$2));
        s.cash += x.cost;
      }
      final back = Game.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>, rng: ParkMiller(1));
      final bb = back.biz.firstWhere((x) => x.id == b.id);
      expect(bb.pipe.where((x) => x.sz != null).map((x) => x.sz), [0, 1, 2]);
      expect(devHitMul[0] < devHitMul[1] && devHitMul[1] < devHitMul[2], isTrue);
    });

    test('大型開発は当たったときの伸びが大きい（同じ乱数で比べる）', () {
      double gain(int sz) {
        final s = _grown();
        final b = _direct(s);
        // 大当たりが出る乱数まで回す
        final x = Pipe(k: 'dev', cost: 1e9, left: 0, sz: sz);
        final p0 = b.power;
        s.rng = ParkMiller(3);
        // 当たりを出すため、開発の腕を最大にする
        s.pres.ab['kai'] = 99;
        for (var i = 0; i < 200; i++) {
          final before = b.power;
          s.finishPipe(b, x, (m, [t = '']) {});
          if (b.power - before > 1e9 * s.pipeEff(b, 1e9) * 2.5) return (b.power - before) / (1e9 * s.pipeEff(b, 1e9));
          b.power = p0;
        }
        return 0;
      }

      final small = gain(0), mid = gain(1), big = gain(2);
      expect(small, greaterThan(0));
      expect(small, lessThan(mid));
      expect(mid, lessThan(big));
    });

    test('人：n人で現場の力が n×1人分、毎月の人件費が n人分の月給だけ増える', () {
      final s = _grown();
      final b = _direct(s);
      s.cash = 1e15;
      s.ap = 3;
      final c0 = s.crewOf(b), u0 = b.upkeep, cash0 = s.cash;
      expect(tx(s.hireN(b, 10)), contains('10人'));
      expect(s.crewOf(b) - c0, closeTo(s.crewPerHead(b) * 10, s.crewPerHead(b) * 1e-9));
      expect(b.upkeep - u0, closeTo(s.payPerMonth(b, 10), s.payPerMonth(b, 10) * 1e-9));
      expect(cash0 - s.cash, closeTo(s.hireCost(b, 10), 1));
    });

    test('人の数え方は、割合の手（1円で現場の力4・維持費0.8%/月）と3年分の総額で同じ', () {
      final s = _grown();
      final b = _direct(s);
      // 3年分の総額1円あたりの現場の力
      final unit = s.crewPerHead(b) / (s.hireCost(b, 1) + s.payPerMonth(b, 1) * 36);
      final old = 4 / (1 + .008 * 36);
      expect(unit, closeTo(old, old * 1e-9));
    });

    test('払えない単位は買えず、お金も手も減らない', () {
      final s = _grown();
      final b = _direct(s);
      // 責任者と物件はあるが、お金が足りない（1.1.0+26）
      b.leads = 5;
      b.lic = 0;
      b.offers = [for (final x in s.siteKeys(s.home, s.kindB(b))) Offer(s: x)];
      s.calcAll();
      s.cash = s.buildCost(b, 1) * .5;
      s.ap = 3;
      for (final f in [() => s.buildN(b, 1), () => s.developN(b, 0), () => s.hireN(b, 1000000)]) {
        expect(tx(f()), 'お金が足りません');
      }
      expect(s.ap, 3);
      expect(s.cash, s.buildCost(b, 1) * .5);
    });
  });

  group('経営会議の提案は単位で出る', () {
    List<Proposal> props(Game s, String trait) {
      final b = _direct(s);
      final p = s.mkPerson(.5)..trait = trait;
      s.staff.add(p);
      for (final x in s.biz) {
        if (x.mgr == p.id) x.mgr = null;
      }
      b.mgr = p.id;
      final out = <Proposal>[];
      for (var i = 0; i < 300; i++) {
        final o = s.proposalFor(p);
        if (o != null) out.add(o);
      }
      return out;
    }

    // 1.1.0+26（段2）から、店などを増やす提案は「今いちばん要る伸ばす手」（開く・責任者を育てる・本部・物流の拠点）になった。
    // 何店を開くかは、責任者・物件・上限で決まるので、性格で3店・10店と決めていた前の形のテストは書き直した
    void soldOut(Game s, Biz b) {
      b.lic = 0;
      b.leads = 10;
      b.offers = [for (final x in s.siteKeys(s.home, s.kindB(b))) Offer(s: x)];
      b.power *= 20;
      s.calcAll();
      b.sv = s.svNeed(b);
    }

    test('ふつうの部下は伸ばす手と新商品を出す。値段は1単位の値段の実額', () {
      final s = _grown();
      s.cash = 1e15;
      final b = _direct(s);
      soldOut(s, b);
      final l = props(s, 'grit');
      final grow = l.firstWhere((o) => o.k == 'grow');
      expect(grow.cost, greaterThan(0));
      final dev = l.firstWhere((o) => o.k == 'dev');
      expect(dev.sz, 1);
      expect(dev.cost, s.devCost(b, 1));
      // 通すと、社長の時間を使わずに打たれる
      final h0 = s.hUsed, n0 = b.pipe.length;
      s.doProposal(grow);
      expect(b.pipe.length, greaterThan(n0));
      expect(s.hUsed, h0);
    });

    test('博打打ちは大きく（10まで開く・大型開発）、慎重は小さく（1つ・小さな改良）', () {
      final s = _grown();
      s.cash = 1e15;
      soldOut(s, _direct(s));
      final g = props(s, 'gambler');
      expect(g.firstWhere((o) => o.k == 'dev').sz, 2);
      expect(txIn(g.firstWhere((o) => o.k == 'dev').l, 'ja'), contains('大型開発'));
      final s2 = _grown();
      s2.cash = 1e15;
      soldOut(s2, _direct(s2));
      final c = props(s2, 'careful');
      expect(c.firstWhere((o) => o.k == 'dev').sz, 0);
      final gg = g.where((o) => o.k == 'grow').map((o) => o.cost).fold(0.0, (a, x) => a > x ? a : x);
      final cc = c.where((o) => o.k == 'grow').map((o) => o.cost).fold(0.0, (a, x) => a > x ? a : x);
      expect(gg, greaterThanOrEqualTo(cc));
    });

    test('提案の値段は手元のお金の割合で決まらない（1単位の値段×数）', () {
      final s = _grown();
      final b = _direct(s);
      s.cash = 1e15;
      soldOut(s, b);
      final big = props(s, 'grit').where((o) => o.k == 'grow').toList();
      s.cash = 1e16;
      final big2 = props(s, 'grit').where((o) => o.k == 'grow').toList();
      expect(big.map((o) => o.cost).toSet(), big2.map((o) => o.cost).toSet());
    });

    test('人の提案は足りない人数。通すとその人数が入る', () {
      final s = _grown();
      final b = _direct(s);
      s.cash = 1e15;
      b.crew = s.crewOf(b) * .05;
      s.calcAll();
      final o = props(s, 'grit').firstWhere((o) => o.k == 'crew');
      // 責任者（統率）で足りない人数が変わるので、提案した人を置いたあとの人数で比べる
      final need = s.crewNeedPeople(b);
      expect(need, greaterThan(0));
      expect(o.n, need);
      expect(o.cost, closeTo(s.hireCost(b, need), 1e-3));
      expect(txIn(o.l, 'ja'), contains('$need人'));
      s.doProposal(o);
      expect(s.crewNeedPeople(b), lessThanOrEqualTo(1));
    });

    test('通した商品の提案は、大きさつきで仕掛かりに入る', () {
      final s = _grown();
      s.cash = 1e15;
      final b = _direct(s);
      final o = props(s, 'gambler').firstWhere((o) => o.k == 'dev');
      final n0 = b.pipe.length;
      s.doProposal(o);
      expect(b.pipe.length, n0 + 1);
      expect(b.pipe.last.sz, 2);
      expect(b.pipe.last.left, inInclusiveRange(6, 10));
    });

    test('extras を切ると、前と同じ現金の割合の提案', () {
      final s = _grown();
      s.extras = false;
      s.cash = 1e12;
      final l = props(s, 'grit').where((o) => o.k == 'build' || o.k == 'dev').toList();
      expect(l, isNotEmpty);
      expect(l.every((o) => o.n == 0 && o.sz == null && (o.cost - 1e12 * .25).abs() < 1), isTrue);
    });
  });

  // 「自動プレイの比べ（割合の手と単位の手）」は 1.1.0+25 で外した（割合の手は試作の古い道。作り直しで比べる意味が無くなった）

  group('画面', () {
    setUpAll(() async {
      final jp = FontLoader(fontFamily);
      for (final f in ['assets/fonts/NotoSansJP-Regular.ttf', 'assets/fonts/NotoSansJP-Bold.ttf']) {
        jp.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
      }
      await jp.load();
      final root = Platform.environment['FLUTTER_ROOT'] ?? '';
      final icons = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
      if (icons.existsSync()) {
        await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())))).load();
      }
    });

    final shotKey = GlobalKey();

    Future<GameController> pump(WidgetTester tester, Game g, String lang, {double height = 844}) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final ctl = GameController(prefs: prefs, newRandom: () => ParkMiller(77), lang: lang)..game = g;
      addTearDown(() => L.lang = 'ja');
      tester.view.physicalSize = Size(390, height);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(RepaintBoundary(key: shotKey, child: QuadrillionApp(controller: ctl)));
      await tester.pump();
      return ctl;
    }

    Future<void> shot(WidgetTester tester, String name) async {
      if (_out == null) return;
      final ro = tester.renderObject<RenderRepaintBoundary>(find.byKey(shotKey));
      await tester.runAsync(() async {
        final im = await ro.toImage(pixelRatio: 2);
        final bd = await im.toByteData(format: ui.ImageByteFormat.png);
        File('$_out/$name.png').writeAsBytesSync(bd!.buffer.asUint8List());
      });
    }

    List<String> japanese() => [
          for (final e in find.byWidgetPredicate((w) => w is RichText).evaluate())
            if (_jp.hasMatch((e.widget as RichText).text.toPlainText()) && !{'日本語', '言語 / Language'}.contains((e.widget as RichText).text.toPlainText()))
              (e.widget as RichText).text.toPlainText()
        ];

    for (final lang in ['ja', 'en']) {
      testWidgets('事業のカード・店を増やす・商品を作る・人を増やす・裏の手・提案の小窓（$lang・幅390）', (tester) async {
        final g = _grown(months: 120, traits: const ['charm', 'gambler']);
        g.ap = 3;
        final b = _direct(g);
        b.crew = g.crewOf(b) * .02; // 1.1.0+26 から、店などの数で売上が頭打ちのときは要る人が少ないので、人手不足を作るときは大きく減らす
        g.calcAll();
        final ctl = await pump(tester, g, lang, height: 1500);
        ctl.setTab('biz');
        ctl.openBiz = ctl.moreBiz = b.id;
        ctl.render();
        await tester.pump();
        // 割合の手のボタンは無く、単位を選ぶ小窓へのボタンがある
        expect(find.text(lang == 'ja' ? '商品を作る' : 'Make products'), findsOneWidget);
        expect(find.byIcon(Icons.chevron_right), findsAtLeastNWidgets(3));
        expect(find.textContaining(lang == 'ja' ? '大きく増やす' : 'Expand big'), findsNothing);
        if (lang == 'en') expect(japanese(), isEmpty, reason: japanese().join(' / '));
        expect(tester.takeException(), isNull);
        await shot(tester, 'fp_card_$lang');
        tester.view.physicalSize = const Size(390, 844);
        await tester.pump();

        Future<void> sheet(String name, void Function() open, {int choices = 3}) async {
          open();
          await tester.pump();
          expect(find.byType(ChoiceBtn), findsAtLeastNWidgets(choices));
          if (lang == 'en') expect(japanese(), isEmpty, reason: '$name: ${japanese().join(' / ')}');
          expect(tester.takeException(), isNull);
          await shot(tester, 'fp_${name}_$lang');
          ctl.closeSheet();
          await tester.pump();
        }

        // 1.1.0+26 から、増やす小窓は「立地に開く・まとめて開く・責任者を育てる・本部・物流・改装」。
        // 客が余っていて、店長と物件がある形にしてから、1つも開けない手元にして、薄いボタンを見る
        final site = g.siteKeys(g.home, g.kindB(b)).first;
        b.lic = 0;
        b.leads = 3;
        b.offers = [for (var i = 0; i < 3; i++) Offer(s: site)];
        b.power *= 20;
        g.calcAll();
        b.sv = g.svNeed(b);
        g.cash = g.unitCapexAt(b, site) * .5;
        await sheet('build', () => openBuild(ctl, b));
        // 薄いボタンを押すと「お金が足りません」、お金は減らない
        openBuild(ctl, b);
        await tester.pump();
        final c0 = g.cash;
        // いちばん上は「（立地）に1つ開く」
        expect(find.textContaining(tr('{0}に1つ開く', [g.siteName(site)])), findsOneWidget);
        await tester.tap(find.byType(ChoiceBtn).at(0));
        await tester.pump();
        expect(g.cash, c0);
        expect(tx(g.log.last.m), lang == 'ja' ? 'お金が足りません' : 'Not enough money');
        ctl.closeSheet();
        await tester.pump(const Duration(seconds: 5));
        g.cash = g.devCost(b, 2) * 1.5;
        await sheet('develop', () => openDevelop(ctl, b));
        await sheet('crew', () => openCrew(ctl, b), choices: 3);
        final foe = g.cos.firstWhere((x) => x.alive && x.parent != 'player' && x.rival != null, orElse: () => g.cos.firstWhere((x) => x.alive && x.parent != 'player'));
        g.cash = g.dirtyCost('spy') * 2;
        await sheet('dirty', () => openDirty(ctl, foe), choices: 5);
        // 経営会議の提案
        g.cash = g.buildCost(b, 10) * 2;
        final p = g.mkPerson(.5)..trait = 'gambler';
        g.staff.add(p);
        b.mgr = p.id;
        Proposal? o;
        for (var i = 0; i < 50 && (o == null || o.k != 'build'); i++) {
          o = g.proposalFor(p);
        }
        g.events
          ..clear()
          ..add(GameEvent(title: M('経営会議の提案'), person: p, text: M('{0}。{1}（{2}）', [o!.l, o.d, Y(o.cost)]), choices: [
            Choice(M('承認する'), M('手は使わない。忠誠が少し上がる'), () => g.doProposal(o!)),
            Choice(M('却下する'), M('忠誠が下がる'), () => g.rejectProposal(o!)),
          ]));
        nextEvent(ctl);
        await tester.pump();
        if (lang == 'en') expect(japanese(), isEmpty, reason: japanese().join(' / '));
        expect(tester.takeException(), isNull);
        await shot(tester, 'fp_proposal_$lang');
      });
    }
  });
}
