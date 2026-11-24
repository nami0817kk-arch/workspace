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

double _median(List<num> xs) {
  final l = xs.map((e) => e.toDouble()).toList()..sort();
  final n = l.length;
  return n.isOdd ? l[n ~/ 2] : (l[n ~/ 2 - 1] + l[n ~/ 2]) / 2;
}

void main() {
  group('1単位の値段', () {
    test('店・工場は1つがその業種の元手。業種と年で変わり、現金では変わらない', () {
      final s = _grown();
      final b = _direct(s);
      final capex = s.capexOf(indm[b.ind]!);
      expect(s.buildCost(b, 1), capex);
      expect(s.buildCost(b, 3), capex * 3);
      expect(s.buildCost(b, 10), capex * 10);
      final c0 = s.buildCost(b, 3);
      s.cash *= 50;
      expect(s.buildCost(b, 3), c0);
      // 業種が違えば値段も違う
      final other = s.biz.firstWhere((x) => indm[x.ind]!.capex != indm[b.ind]!.capex, orElse: () => b);
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
      expect(s.wageOf(b), wageByCat[indm[b.ind]!.cat]! * s.nom());
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
    test('店・工場：払った額が仕掛かりに入り、開いたときの伸びは割合の手と同じ1円あたりの効き目', () {
      final s = _grown();
      final b = _direct(s);
      s.cash = s.buildCost(b, 10) * 3;
      s.ap = 3;
      final c0 = s.cash;
      expect(tx(s.buildN(b, 3)), anyOf(contains('店を3店舗'), contains('工場を3か所'), contains('拠点を3か所'), contains('設備を3式')));
      expect(c0 - s.cash, closeTo(s.buildCost(b, 3), 1));
      final x = b.pipe.last;
      expect(x.k, 'build');
      expect(x.cost, s.buildCost(b, 3));
      final p0 = b.power, u0 = b.upkeep;
      final eff = s.pipeEff(b, x.cost);
      b.pipe.remove(x);
      s.finishPipe(b, x, (m, [t = '']) {});
      expect(b.power - p0, closeTo(x.cost * eff, x.cost * eff * 1e-9));
      expect(b.upkeep - u0, closeTo(x.cost * .006, x.cost * 1e-9));
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

    test('ふつうの部下は3店・新商品。値段は単位の値段そのもの', () {
      final s = _grown();
      s.cash = 1e15;
      final b = _direct(s);
      final l = props(s, 'grit');
      final build = l.firstWhere((o) => o.k == 'build');
      expect(build.n, 3);
      expect(build.cost, s.buildCost(b, 3));
      expect(txIn(build.l, 'ja'), matches(RegExp('で(店を3店舗|工場を3か所|拠点を3か所|設備を3式)増やしたい')));
      final dev = l.firstWhere((o) => o.k == 'dev');
      expect(dev.sz, 1);
      expect(dev.cost, s.devCost(b, 1));
    });

    test('博打打ちは10店・大型開発、慎重は1店・小さな改良', () {
      final s = _grown();
      s.cash = 1e15;
      final g = props(s, 'gambler');
      expect(g.firstWhere((o) => o.k == 'build').n, 10);
      expect(g.firstWhere((o) => o.k == 'dev').sz, 2);
      expect(txIn(g.firstWhere((o) => o.k == 'dev').l, 'ja'), contains('大型開発'));
      final s2 = _grown();
      s2.cash = 1e15;
      final c = props(s2, 'careful');
      expect(c.firstWhere((o) => o.k == 'build').n, 1);
      expect(c.firstWhere((o) => o.k == 'dev').sz, 0);
    });

    test('提案の値段は手元のお金で変わらない（払えないときは小さくする）', () {
      final s = _grown();
      final b = _direct(s);
      s.cash = 1e15;
      final big = props(s, 'grit').firstWhere((o) => o.k == 'build');
      s.cash = 1e16;
      expect(props(s, 'grit').firstWhere((o) => o.k == 'build').cost, big.cost);
      // 3店は払えないが1店は払える
      s.cash = s.buildCost(b, 2);
      final l = props(s, 'grit').where((o) => o.k == 'build').toList();
      expect(l, isNotEmpty);
      expect(l.every((o) => o.n == 1 && o.cost <= s.cash), isTrue);
    });

    test('人の提案は足りない人数。通すとその人数が入る', () {
      final s = _grown();
      final b = _direct(s);
      s.cash = 1e15;
      b.crew = s.crewOf(b) * .5;
      s.calcAll();
      final o = props(s, 'grit').firstWhere((o) => o.k == 'crew');
      // 責任者（統率）で足りない人数が変わるので、提案した人を置いたあとの人数で比べる
      final need = s.crewNeedPeople(b);
      expect(need, greaterThan(0));
      expect(o.n, need);
      expect(o.cost, closeTo(s.hireCost(b, need), 1e-3));
      expect(txIn(o.l, 'ja'), contains('$need人'));
      s.doProposal(o);
      expect(s.crewNeedPeople(b), 0);
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

  group('自動プレイの比べ', () {
    // 割合の手の自動プレイは毎月、現金の4割で店を、2割ずつで商品と人を買い続けるので、維持費（店は1円あたり毎月0.6%）が積み上がって
    // 利益を食い、現金がほとんど残らない（30年後の維持費は単位の手の数十倍）。単位の手は1手で使える額に上限があり、余った現金で海外に出て、
    // 現金も時価総額に入るので、順位は良いほうに寄る（実測: 割合243位・単位132位）。1円あたりの効き目は同じにしてあるので、事業の力は近い
    // 1.0.0+19（国ごとの事件・宿敵の場面・提案に広告と最初の1か国だけの海外など）の前後（9通りの中央値）:
    //   順位 割合 243位→232位・単位 132位→155位／事業の力 割合 4.62兆→7.93兆・単位 7.28兆→6.09兆
    //   乱数の流れは変わったが、線（半分〜2倍）は引き直さずに通る
    test('単位の手で遊んでも、2000年から30年の順位の中央値と事業の力の中央値が、割合の手の半分〜2倍に収まる', () {
      final old = <int>[], unit = <int>[];
      final pOld = <double>[], pUnit = <double>[];
      final lines = <String>[];
      for (var seed = 1; seed <= 9; seed++) {
        for (final u in [false, true]) {
          final s = Game.newGame(SetupConfig(mode: 'endless', year: 2000, traits: ['charm', 'noble']), rng: ParkMiller(seed * 7919));
          for (var t = 0; t < 12 * 30 && s.over == null; t++) {
            botMonth(s, units: u);
          }
          final pw = s.biz.fold(0.0, (a, b) => a + b.power);
          (u ? unit : old).add(s.rank);
          (u ? pUnit : pOld).add(pw);
          lines.add('seed$seed ${u ? '単位' : '割合'} 順位${s.rank} 時価総額${yen(s.cap)} 現金${yen(s.cash)} 事業の力${yen(pw)} 維持費${yen(s.biz.fold(0.0, (a, b) => a + b.upkeep))}/月');
        }
      }
      final mo = _median(old), mu = _median(unit), po = _median(pOld), pu = _median(pUnit);
      // ignore: avoid_print
      print('[bot] 割合の手 順位 $old 中央値 $mo / 単位の手 順位 $unit 中央値 $mu\n'
          '[bot] 事業の力の中央値 割合 ${yen(po)} / 単位 ${yen(pu)}\n[bot] ${lines.join('\n[bot] ')}');
      expect(mu, inInclusiveRange(mo / 2, mo * 2));
      expect(pu, inInclusiveRange(po / 2, po * 2));
    }, timeout: const Timeout(Duration(minutes: 10)));
  });

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
        b.crew = g.crewOf(b) * .6;
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

        // 10店が払えない手元にして、薄いボタンを見る
        g.cash = g.buildCost(b, 3) * 1.2;
        await sheet('build', () => openBuild(ctl, b));
        // 薄いボタンを押すと「お金が足りません」、お金は減らない
        openBuild(ctl, b);
        await tester.pump();
        final c0 = g.cash;
        // 1.0.0+17 で一番上に「広げる」（元手の1/4）が入ったので、10店は4つ目
        await tester.tap(find.byType(ChoiceBtn).at(3));
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
