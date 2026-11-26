// 子会社の名前と、子会社と同じ業種（1.1.0+36）:
// - 分社・現地法人を作るときに名前を決める（案が入っている）。あとから「名前を変える」で変えられ、セーブに残る。
// - 使えない名前（空・長すぎ・ほかの会社と同じ）は理由を出して弾く。
// - 株を過半持つ国内の子会社がいる業種は、自社では始められない（始める・業態を変える・部下の提案・一覧）。
//   持ち分50%以下の会社は他社として扱い、現地法人は今までどおり作れる。
// QUAD_SHOTS にフォルダを渡すと、844×390 と 1194×834 の日英を PNG に書き出す（画像はコミットしない）
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';
import 'package:quadrillion/ui/app.dart';
import 'package:quadrillion/ui/controller.dart';
import 'package:quadrillion/ui/sheets.dart';
import 'package:quadrillion/ui/tabs.dart';
import 'package:quadrillion/ui/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/bot.dart';
import 'support/shots.dart';

final _cjk = RegExp('[　-ヿ㐀-鿿＀-￯]');

String? _json;

/// 1990年から3年回し、事業を4つ以上にして、お金と手をたっぷり持たせた会社
Game _game() {
  if (_json == null) {
    final s = Game.newGame(SetupConfig(mode: 'endless', year: 1990, traits: const ['charm', 'careful']), rng: ParkMiller(3636));
    for (var i = 0; i < 36; i++) {
      botMonth(s);
    }
    resolveEvents(s);
    s.events.clear();
    s.cash = s.cap * 10 + 1e12;
    s.ap = 99;
    for (final i in s.liveInds().where((i) => s.licMissing(i.id) == null).toList()..ssort((a, b) => s.capexOf(a).compareTo(s.capexOf(b)))) {
      if (s.biz.length >= 4) break;
      if (!s.biz.any((b) => b.ind == i.id)) {
        s.hUsed = 0;
        s.startBiz(i.id);
      }
    }
    s.calcAll();
    _json = jsonEncode(s.toJson());
  }
  final g = Game.fromJson(jsonDecode(_json!) as Map<String, dynamic>, rng: ParkMiller(11))
    ..events.clear()
    ..calcAll();
  g.cash = g.cap * 10 + 1e12;
  g.ap = 99;
  g.hUsed = 0;
  return g;
}

/// 責任者を置いた事業（分社できる）
Biz _managed(Game s, [int i = 0]) {
  final b = s.biz[i];
  final p = s.mkPerson(.5);
  s.staff.add(p);
  b.mgr = p.id;
  return b;
}

/// 社長の時間を戻す（1か月に打てる手の上限に当たらないように）
void _fresh(Game s) {
  s.hUsed = 0;
  s.ap = 99;
}

void main() {
  tearDown(() => L.lang = 'ja');

  group('子会社の名前', () {
    test('分社のときに名前を付けられる', () {
      final s = _game();
      final b = _managed(s);
      final ind = b.ind;
      final m = s.spinOff(b, name: '  みなと商会  ');
      expect(msgKey(m), startsWith('「{0}」を分社し'));
      final c = s.subOn(ind)!;
      expect(c.name, 'みなと商会', reason: '前後の空白は落とす');
      expect(c.parent, 'player');
    });

    test('案のまま決められる。案はほかの会社と重ならず、作り物の冠＋分類の言葉。2社目からは同じ冠を使う', () {
      final s = _game();
      final b = _managed(s);
      final cat = indm[b.ind]!.cat;
      final idea = s.subNameIdea(cat);
      expect(s.coNameErr(idea), isNull);
      expect([...CO_A, ...CO_C].any(idea.startsWith), isTrue, reason: idea);
      expect(idea.endsWith(CO_SUF[cat]!) || idea.endsWith(CO_FSUF[cat]!), isTrue, reason: idea);
      expect(s.subNameIdea(cat), idea, reason: '案を作るのに乱数を引かない（同じ盤面なら同じ案）');
      s.spinOff(b, name: idea);
      final c = s.subs().single;
      expect(c.name, idea);
      final crown = [...CO_A, ...CO_C].firstWhere(idea.startsWith);
      _fresh(s);
      final b2 = _managed(s, 0);
      final idea2 = s.subNameIdea(indm[b2.ind]!.cat);
      expect(idea2, isNot(idea));
      expect(idea2, startsWith(crown), reason: '2社目もグループの冠を付ける');
      // 英語の画面では、案はローマ字で見え、日本語が残らない
      L.lang = 'en';
      expect(_cjk.hasMatch(nmL(idea2)), isFalse, reason: nmL(idea2));
    });

    test('名前を決めても乱数の並びは変わらない（決めた名前・仕組みの名前で、そのあとの進みが同じ）', () {
      final a = _game(), b = _game();
      a.spinOff(_managed(a), name: 'みなと商会');
      b.spinOff(_managed(b));
      for (var i = 0; i < 6; i++) {
        botMonth(a);
        botMonth(b);
      }
      expect(a.turn, b.turn);
      expect(a.cash, b.cash);
      expect(a.cap, b.cap);
    });

    test('使えない名前は理由を出して弾く（空・長すぎ・ほかの会社と同じ・英語の読みが同じ・宿敵の会社）。弾いたら手も使わない', () {
      final s = _game();
      final cpu = s.cos.firstWhere((c) => c.alive && c.parent != 'player' && c.rival == null && CO_A.any(c.name.startsWith));
      final riv = s.cos.firstWhere((c) => c.rival != null);
      expect(msgKey(s.coNameErr('')!), '名前を入れてください');
      expect(msgKey(s.coNameErr('   ')!), '名前を入れてください');
      expect(msgKey(s.coNameErr('あ' * 17)!), '名前は全角{0}字（半角{1}字）までです');
      expect(s.coNameErr('あ' * 16), isNull);
      expect(s.coNameErr('a' * 32), isNull);
      expect(msgKey(s.coNameErr('a' * 33)!), '名前は全角{0}字（半角{1}字）までです');
      expect(msgKey(s.coNameErr('A\u0001B')!), '使えない文字が入っています');
      expect(msgKey(s.coNameErr(cpu.name)!), '「{0}」という会社はもうあります');
      expect(msgKey(s.coNameErr(romanize(cpu.name).toUpperCase())!), '「{0}」という会社はもうあります', reason: '英語の画面での読みが同じ');
      expect(msgKey(s.coNameErr(riv.name)!), '「{0}」という会社はもうあります');
      expect(msgKey(s.coNameErr(RIVALS.firstWhere((r) => !s.cos.any((c) => c.name == r.co)).co)!), '「{0}」という会社はもうあります', reason: 'まだ出ていない宿敵の会社も');
      // 自分の子会社どうしも重ねない
      final b = _managed(s);
      s.spinOff(b, name: 'みなと商会');
      _fresh(s);
      final b2 = _managed(s);
      final n0 = s.subs().length, biz0 = s.biz.length, h0 = s.hUsed;
      expect(msgKey(s.spinOff(b2, name: 'みなと商会')), '「{0}」という会社はもうあります');
      expect(msgKey(s.spinOff(b2, name: '')), '名前を入れてください');
      expect(s.subs().length, n0);
      expect(s.biz.length, biz0);
      expect(s.hUsed, h0, reason: '弾いたときは時間を使わない');
      // 英語の理由
      L.lang = 'en';
      for (final e in [s.coNameErr('')!, s.coNameErr('a' * 33)!, s.coNameErr(cpu.name)!, s.coNameErr('A\u0001B')!]) {
        expect(_cjk.hasMatch(tx(e)), isFalse, reason: tx(e));
      }
    });

    test('あとから名前を変えられる（過半を持つ会社だけ。買収した会社も）。セーブに残る', () {
      final s = _game();
      s.spinOff(_managed(s), name: 'みなと商会');
      final c = s.subs().single;
      expect(s.canRename(c), isTrue);
      expect(msgKey(s.renameCo(c, 'あおば工房')), '{0}の名前を「{1}」に変えました');
      expect(c.name, 'あおば工房');
      expect(msgKey(s.renameCo(c, 'あおば工房')), '今と同じ名前です');
      final cpu = s.cos.firstWhere((x) => x.alive && x.parent != 'player' && x.rival == null);
      expect(msgKey(s.renameCo(c, cpu.name)), '「{0}」という会社はもうあります');
      expect(c.name, 'あおば工房');
      // 持ち分50%以下の会社は他社のまま。名前は変えられない
      cpu.stakePlayer = 50;
      expect(s.canRename(cpu), isFalse);
      expect(msgKey(s.renameCo(cpu, 'かえで商事')), '名前を変えられるのは、株を過半持つ会社だけです');
      // 買収した会社（過半を持つ）は元の名前のまま、変えることもできる
      final old = cpu.name;
      cpu.stakePlayer = 60;
      s.afterStake(cpu);
      expect(cpu.name, old);
      expect(s.canRename(cpu), isTrue);
      expect(msgKey(s.renameCo(cpu, 'かえで商事')), '{0}の名前を「{1}」に変えました');
      // セーブに残る
      final back = Game.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>, rng: ParkMiller(1));
      expect(back.coById(c.id)!.name, 'あおば工房');
      expect(back.coById(cpu.id)!.name, 'かえで商事');
    });

    test('現地法人も名前を付けて作れる（同じ業種でも、別の国なので作れる）', () {
      final s = _game();
      final b = s.biz.first;
      b.ctry = [s.home, 'us'];
      s.calcAll();
      final idea = s.subNameIdea(indm[b.ind]!.cat);
      final m = s.makeLocal(b, 'us', null, idea);
      expect(msgKey(m), isNot('「{0}」という会社はもうあります'));
      final loc = s.locals().single;
      expect(loc.name, idea);
      expect(loc.biz.single.ind, b.ind);
      // 現地法人は別の国の市場なので、同じ業種の決まりには数えない
      expect(s.subOn(b.ind), isNull);
      _fresh(s);
      b.ctry = [s.home, 'de'];
      s.calcAll();
      expect(msgKey(s.makeLocal(b, 'de', null, idea)), '「{0}」という会社はもうあります');
      expect(s.locals().length, 1);
    });
  });

  group('子会社と同じ業種は自社で始めない', () {
    test('分社した業種は始め直せない。理由は子会社の名前つき', () {
      final s = _game();
      final b = _managed(s);
      final ind = b.ind;
      s.spinOff(b, name: 'みなと商会');
      _fresh(s);
      final m = s.startBiz(ind);
      expect(msgKey(m), '子会社「{0}」がこの業種にいます。広げるなら子会社に任せます');
      expect(tx(m), '子会社「みなと商会」がこの業種にいます。広げるなら子会社に任せます');
      expect(s.biz.any((x) => x.ind == ind), isFalse);
      L.lang = 'en';
      expect(_cjk.hasMatch(tx(m).replaceAll('みなと商会', '')), isFalse, reason: tx(m));
      L.lang = 'ja';
      // 一覧：「始められる」には入らず、全部の一覧には出る（薄く出す）
      expect(newBizList(s, filter: 'can').any((i) => i.id == ind), isFalse);
      expect(newBizList(s).any((i) => i.id == ind), isTrue);
    });

    test('持ち分50%以下になった会社は他社として扱い、同じ業種でも始められる', () {
      final s = _game();
      final b = _managed(s);
      final ind = b.ind;
      s.spinOff(b, name: 'みなと商会');
      _fresh(s);
      final c = s.subs().single;
      c.stakePlayer = 50;
      expect(s.subOn(ind), isNull);
      expect(msgKey(s.startBiz(ind)), '「{0}」を{1}で始めました（元手 {2}）');
    });

    test('業態を変える先に子会社の業種は選べない', () {
      final s = _game();
      // 同じ分類の業種を1つ子会社に持たせる
      final b = s.biz.first;
      final to = s.pivotTargets(b).first;
      final cpu = s.cos.firstWhere((x) => x.alive && x.parent != 'player' && x.rival == null && x.loc == null);
      cpu.biz.add(CoBiz(ind: to.id, power: 1e6));
      cpu.stakePlayer = 80;
      s.afterStake(cpu);
      expect(s.pivotTargets(b).any((i) => i.id == to.id), isTrue, reason: '候補には出す（画面で薄くして理由を出す）');
      expect(msgKey(s.pivot(b, to.id)), '子会社「{0}」がこの業種にいます。広げるなら子会社に任せます');
      expect(b.ind, isNot(to.id));
    });

    test('部下の「新しく始めたい」は子会社の業種を出さず、通しても始めない', () {
      final s = _game();
      final b = _managed(s);
      final ind = b.ind;
      final p = s.staffById(b.mgr)!;
      s.spinOff(b, name: 'みなと商会');
      _fresh(s);
      final q = s.mkPerson(.5)..partner = true;
      s.staff.add(q);
      s.biz.first.mgr = q.id;
      for (var i = 0; i < 300; i++) {
        final o = s.proposalFor(q);
        if (o != null && o.k == 'newbiz') expect(o.ind, isNot(ind));
      }
      expect(p, isNotNull);
      // 提案のあとで子会社が入った業種は、通しても始めない
      final o = Proposal(k: 'newbiz', w: 2, cost: 0, l: M('新しい事業を始めたい'), d: M('自分で立ち上げて、責任者をやります'))
        ..ind = ind
        ..by = q.id
        ..bid = s.biz.first.id;
      expect(msgKey(s.doProposal(o)), '子会社「{0}」がこの業種にいます。広げるなら子会社に任せます');
      expect(s.biz.any((x) => x.ind == ind), isFalse);
    });
  });

  group('画面', () {
    setUpAll(loadRealFonts);
    for (final size in const [Size(844, 390), Size(1194, 834)]) {
      for (final lang in const ['ja', 'en']) {
        testWidgets('名前の入力・子会社のカード・薄い業種 ${size.width.round()}×${size.height.round()}（$lang）', (tester) async {
          await _walk(tester, size, lang);
        });
      }
    }
  });
}

Future<void> _walk(WidgetTester tester, Size size, String lang) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final ctl = GameController(prefs: prefs, newRandom: () => ParkMiller(5), lang: lang);
  L.lang = lang;
  final s = _game();
  ctl.game = s;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(() => L.lang = 'ja');
  final key = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(key: key, child: QuadrillionApp(controller: ctl)));
  await tester.pump();
  final n = '${size.width.round()}x${size.height.round()}_$lang';
  Future<void> settle(String what) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull, reason: '$what $n');
    if (lang == 'en') {
      for (final w in tester.widgetList<RichText>(find.byType(RichText))) {
        final t = w.text.toPlainText();
        expect(_cjk.hasMatch(t), isFalse, reason: '$what: 英語の画面に日本語「$t」');
      }
      for (final w in tester.widgetList<EditableText>(find.byType(EditableText))) {
        expect(_cjk.hasMatch(w.controller.text), isFalse, reason: '$what: 欄に日本語「${w.controller.text}」');
      }
    }
  }

  Future<void> tap(Finder f) async {
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
    await settle('tap');
  }

  // 分社 → 名前の入力
  final b = _managed(s);
  final ind = b.ind;
  final idea = s.subNameIdea(indm[ind]!.cat);
  openShape(ctl, b);
  await settle('shape');
  await tap(find.text(tr('分社する')));
  expect(find.byKey(const ValueKey('name-spin')), findsOneWidget);
  final field = find.byKey(const ValueKey('co-name-field'));
  expect(tester.widget<TextField>(field).controller!.text, nmL(idea));
  await shot(tester, key, 'sub_name_spin_$n', pixelRatio: 1.5);
  // 使えない名前は、その場で理由が出る
  final cpu = s.cos.firstWhere((c) => c.alive && c.parent != 'player' && c.rival == null);
  await tester.enterText(field, nmL(cpu.name));
  await tap(find.byKey(const ValueKey('co-name-ok')));
  expect(find.byKey(const ValueKey('co-name-err')), findsOneWidget);
  expect(s.subs(), isEmpty);
  await shot(tester, key, 'sub_name_err_$n', pixelRatio: 1.5);
  // 案に戻してそのまま決める
  await tap(find.text(tr('案に戻す')));
  await tap(find.byKey(const ValueKey('co-name-ok')));
  final c = s.subs().single;
  expect(c.name, idea, reason: '英語の画面で案のまま決めても、案の元の名前でしまう');
  ctl.closeSheet();
  await settle('closed');

  // 子会社のカード（名前を変える）
  ctl.setTab('stock');
  ctl.selectCo(c.id);
  await settle('stock');
  final rn = find.byKey(ValueKey('co-rename-${c.id}'));
  // カードの上（名前と札）から見せる
  await tester.ensureVisible(find.byKey(ValueKey('co-${c.id}')));
  await settle('card');
  expect(rn, findsOneWidget);
  await shot(tester, key, 'sub_card_$n', pixelRatio: 1.5);
  await tap(rn);
  expect(find.byKey(ValueKey('name-co-${c.id}')), findsOneWidget);
  await tester.enterText(field, lang == 'en' ? 'Harbor Works' : 'みなと工房');
  await settle('typed');
  await shot(tester, key, 'sub_rename_$n', pixelRatio: 1.5);
  await tap(find.byKey(const ValueKey('co-name-ok')));
  expect(c.name, lang == 'en' ? 'Harbor Works' : 'みなと工房');
  ctl.closeSheet();
  await settle('renamed');

  // 新しい事業の一覧：子会社の業種は薄く、理由が出て、「始める」は押せない
  ctl.goNewInd(indm[ind]!.name);
  ctl.render();
  await settle('newbiz');
  final row = find.byKey(ValueKey('newbiz-block-$ind'));
  await tester.ensureVisible(row);
  await settle('newbiz-row');
  expect(tester.widget<Opacity>(find.byKey(ValueKey('newbiz-row-$ind'))).opacity, lessThan(1));
  await shot(tester, key, 'sub_newbiz_$n', pixelRatio: 1.5);
  // 創業の小窓（業種を選ぶ所）でも薄く、理由が出る
  openStart(ctl);
  await settle('start');
  final st = find.byKey(ValueKey('start-$ind'));
  if (st.evaluate().isNotEmpty) {
    await tester.ensureVisible(st);
    await settle('start-row');
    expect(tester.widget<ChoiceBtn>(st).enabled, isFalse);
    await shot(tester, key, 'sub_start_$n', pixelRatio: 1.5);
  }
  ctl.closeSheet();
  await settle('end');
}
