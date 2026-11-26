// 子会社の借金（1.1.0+39）
// 1. 借りられる上限と格付けを、子会社の借金と担保の持ち分も合わせたグループの数で見る（利益と同じ数え方にそろえた）
// 2. 子会社の現金が尽きて返せなくなったら、助けるか倒れさせるかを選ぶ出来事を出す（前は何も起きず、マイナスのまま持ち続けられた）
// QUAD_SHOTS にフォルダを渡すと、銀行の画面・決算書・出来事の小窓を 844×390 と 1194×834 の日英で PNG に書き出す（画像はコミットしない）
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';
import 'package:quadrillion/ui/app.dart';
import 'package:quadrillion/ui/controller.dart';
import 'package:quadrillion/ui/sheets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/bot.dart';
import 'support/shots.dart';

final _cjk = RegExp('[　-ヿ㐀-鿿＀-￯]');

String? _json;

/// 1990年から3年回した会社（事業と利益がある）。お金はたっぷり持たせる
Game _game() {
  if (_json == null) {
    final s = Game.newGame(SetupConfig(mode: 'endless', year: 1990, traits: const ['charm', 'careful']), rng: ParkMiller(3737));
    for (var i = 0; i < 36; i++) {
      botMonth(s);
    }
    resolveEvents(s);
    s.events.clear();
    s.calcAll();
    _json = jsonEncode(s.toJson());
  }
  final g = Game.fromJson(jsonDecode(_json!) as Map<String, dynamic>, rng: ParkMiller(11))
    ..events.clear()
    ..calcAll();
  g.hUsed = 0;
  g.cfTag = 'reset';
  g.cash = g.cap * 3 + 1e10;
  // 書き込んだ現金は決算書の「入れ替え」にする（利益に見せない）
  g.finRebase();
  return g;
}

/// CPU の会社を1つ、株60%の子会社にする（借金は0から始める）
Company _sub(Game s, {double pct = 60}) {
  // 親の手元で助けられる大きさの会社（売上の小さい順で、まだ子会社でないもの）
  final c = (s.cos.where((c) => c.alive && c.parent != 'player' && c.rival == null && c.loc == null && c.biz.isNotEmpty && c.rev > 0).toList()
        ..ssort((a, b) => a.rev.compareTo(b.rev)))
      .first;
  c.parent = 'player';
  c.stakePlayer = pct;
  s.finOf(c).debt = 0;
  s.calcAll();
  return c;
}

/// 子会社の現金を尽きさせる（借金が利益の8倍を超えていて、もう借りられない）
void _broke(Game s, Company c) {
  final f = s.finOf(c);
  f.debt = math8(c);
  c.cash = -c.rev * 2 - 1e8;
  s.calcAll();
}

double math8(Company c) => (c.profit > 0 ? c.profit * 12 * 10 : 0) + c.rev * 24 + 1e9;

void _n(String m, [String t = '']) {}

Game _reload(Game s) => Game.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>, rng: ParkMiller(7));

GameEvent? _ev(Game s, Company c) => s.events.where((e) => e.k == 'subBroke' && e.subco == c.id).firstOrNull;

void main() {
  tearDown(() => L.lang = 'ja');

  group('1 グループの借金と格付け', () {
    test('子会社の借金と担保は持ち分だけグループの数に入る。株を過半持たない会社の借金は入らない', () {
      final s = _game();
      expect(s.annualProfit(), greaterThan(0), reason: '盤面の前提');
      final c = _sub(s);
      expect(s.groupDebt, closeTo(s.debt, 1), reason: '子会社が借りていなければ同じ');
      final coll0 = s.collateral();
      s.finOf(c).debt = 1e9;
      expect(s.subDebtShare(), closeTo(6e8, 1));
      expect(s.groupDebt, closeTo(s.debt + 6e8, 1));
      // 担保は店などの値打ちの6割×持ち分
      final unitColl = c.biz.fold(0.0, (t, b) => t + (b.u + b.uy) * s.coUnitCapex(b.ind) * .6);
      expect(s.collateral(), closeTo(coll0, 1), reason: '子会社の借金は担保を変えない');
      expect(s.subCollShare(), closeTo(unitColl * .6, 1));
      expect(s.subCollShare(), greaterThan(0));
      // 持ち分を過半より下にした（子会社でない）会社の借金は入らない
      c.parent = null;
      c.stakePlayer = 30;
      expect(s.subDebtShare(), 0);
      expect(s.groupDebt, closeTo(s.debt, 1));
    });

    test('子会社が借りすぎると親の格付けが下がり、借りられる残りが減って金利が上がる', () {
      final s = _game();
      s.loans.clear();
      s.missed = 0;
      final c = _sub(s);
      final a = s.annualProfit();
      expect(s.ratingIdx(), 0);
      final room0 = s.borrowRoom(), rate0 = s.loanRate();
      // 子会社の借金の持ち分が、親の年の利益の9倍
      s.finOf(c).debt = a * 9 / .6;
      expect(s.debtMultiple(), closeTo(9, .01));
      expect(s.ratingIdx(), 3, reason: '前は親の借金が0なら、子会社がいくら借りても A のままだった');
      expect(s.borrowRoom(), 0);
      expect(s.loanRate(), greaterThan(rate0));
      // 4倍なら B、借りられる残りはグループの借金の分だけ減る
      s.finOf(c).debt = a * 4 / .6;
      expect(s.ratingIdx(), 1);
      expect(s.borrowRoom(), lessThan(room0));
      expect(s.borrowRoom(), closeTo(s.borrowLimit() - s.groupDebt, 1));
    });

    test('貸借対照表に参考として子会社の借金の持ち分が残る（表の合計には入れない）', () {
      final s = _game();
      final c = _sub(s);
      s.finOf(c).debt = 1e9;
      s.nextQuarter();
      s.events.clear();
      final m = s.books.months.last;
      expect(m.g('b:subDebt'), closeTo(s.finOf(c).debt * s.pctOf(c) / 100, s.finOf(c).debt * .01));
      expect(finLiabs(m.v), closeTo(m.g('b:loan') + m.g('b:bond'), 1));
      expect(m.g('b:gap').abs(), lessThan(finAssets(m.v).abs() * 1e-6 + 10));
    });
  });

  group('2 子会社の資金が尽きたら選ぶ', () {
    test('返せなくなった月に出来事が出る（同じ子会社では重ねない）。助けられるなら選択肢の最後が「助ける」', () {
      final s = _game();
      final c = _sub(s);
      _broke(s, c);
      s.cpuMonth(_n);
      final e = _ev(s, c);
      expect(e, isNotNull, reason: '前は自分の子会社は何も起きなかった');
      expect(e!.small, isFalse);
      expect(msgKey(e.choices.first.l), '倒れさせる');
      expect(msgKey(e.choices.last.l), '{0}を入れて助ける');
      expect(c.alive, isTrue, reason: '選ぶまでは倒れない');
      s.cpuMonth(_n);
      expect(s.events.where((x) => x.k == 'subBroke' && x.subco == c.id).length, 1);
    });

    test('助ける：親の現金から足りない分と数か月分を増資で入れる。持ち株が増え、貸借が合う', () {
      final s = _game();
      final c = _sub(s);
      _broke(s, c);
      s.cpuMonth(_n);
      s.calcAll();
      s.finCut();
      final need = s.subHelpNeed(c);
      final p = s.subHelpPlan(c)!;
      expect(p.loan, 0, reason: '親は手元のお金で足りる');
      final cash0 = s.cash, ccash0 = c.cash, st0 = s.pctOf(c);
      final v0 = s.subStakeValue(c);
      _ev(s, c)!.choices.last.f();
      expect(s.cash, closeTo(cash0 - need, 1));
      expect(c.cash, closeTo(ccash0 + need, 1));
      expect(c.cash, greaterThan(0));
      expect(s.pctOf(c), greaterThan(st0));
      expect(s.finOf(c).distress, 0);
      expect(c.alive, isTrue);
      expect(v0 + need, greaterThan(v0));
      s.finClose(s.year, s.q);
      final m = s.books.months.last;
      expect(m.g('b:gap').abs(), lessThan(finAssets(m.v).abs() * 1e-6 + 10), reason: '貸借が合う');
      expect(m.g('c:stock'), closeTo(-need, 1), reason: '投資のキャッシュフロー（株・子会社の売買）に出る');
    });

    test('助ける：手元が足りなければ足りない分を借りる。借りられなければ「助ける」は選べない', () {
      final s = _game();
      final c = _sub(s);
      _broke(s, c);
      s.loans.clear();
      s.missed = 0;
      s.cash = s.dangerLine() + 1e3;
      final need = s.subHelpNeed(c);
      final p = s.subHelpPlan(c);
      if (s.borrowRoom() >= need) {
        expect(p, isNotNull);
        expect(p!.loan, closeTo(need - 1e3, 1));
        final debt0 = s.debt;
        s.evSubBroke(c).choices.last.f();
        expect(s.debt, closeTo(debt0 + p.loan, 1), reason: '足りない分は銀行から借りた');
      }
      // 銀行の管理中（借りられない）なら、選べるのは「倒れさせる」だけ
      final t = _game();
      final d = _sub(t);
      _broke(t, d);
      t.cash = 0;
      t.bankCtl = 24;
      final e = t.evSubBroke(d);
      expect(e.choices.map((x) => msgKey(x.l)), ['倒れさせる']);
    });

    test('倒れさせる：子会社は倒産、持ち株は0で特別損失。評判・ブランド・部下の忠誠が下がり、貸借が合う', () {
      final s = _game();
      final c = _sub(s);
      final p = s.mkPerson(.5);
      s.staff.add(p);
      _broke(s, c);
      s.cpuMonth(_n);
      s.calcAll();
      s.finCut();
      final v = s.subStakeValue(c);
      expect(v, greaterThan(0));
      final cash0 = s.cash, rep0 = s.rep, brand0 = s.lf.brand, loy0 = p.loy;
      _ev(s, c)!.choices.first.f();
      expect(c.alive, isFalse);
      expect(s.pctOf(c), 0);
      expect(s.subs().contains(c), isFalse);
      expect(s.subDebtShare(), 0, reason: '倒れた子会社の借金はグループから外れる（保証の仕組みは無いので親は払わない）');
      expect(s.cash, closeTo(cash0, 1), reason: '親の現金は動かない');
      expect(s.rep, rep0 - 3);
      if (s.lifeOn) expect(s.lf.brand, lessThan(brand0));
      expect(p.loy, closeTo(loy0 - 3, 1e-9));
      expect(s.books.cur['subLoss'], closeTo(v, 1));
      s.finClose(s.year, s.q);
      final m = s.books.months.last;
      expect(finSpLoss(m.v), greaterThanOrEqualTo(v - 1), reason: '特別損失に入る');
      expect(m.g('b:gap').abs(), lessThan(finAssets(m.v).abs() * 1e-6 + 10), reason: '貸借が合う');
    });

    test('保存して読み込んでも出来事が残る。子会社でなくなっていれば消える', () {
      final s = _game();
      final c = _sub(s);
      _broke(s, c);
      s.cpuMonth(_n);
      final e0 = _ev(s, c)!;
      final r = _reload(s);
      final rc = r.coById(c.id)!;
      final e1 = _ev(r, rc);
      expect(e1, isNotNull);
      expect(e1!.title, e0.title);
      expect(e1.choices.map((x) => x.l), e0.choices.map((x) => x.l));
      e1.choices.first.f();
      expect(rc.alive, isFalse, reason: '読み込んだあとも選択肢が効く');
      // 子会社でなくなっていれば作り直さない
      c.parent = null;
      final r2 = _reload(s);
      expect(r2.events.where((x) => x.k == 'subBroke'), isEmpty);
    });

    test('自動プレイは、助けられるなら助け、無理なら倒れさせる', () {
      final s = _game();
      final c = _sub(s);
      _broke(s, c);
      s.cpuMonth(_n);
      resolveEvents(s);
      expect(c.alive, isTrue);
      expect(c.cash, greaterThan(0));
      final t = _game();
      final d = _sub(t);
      _broke(t, d);
      t.cash = 0;
      t.bankCtl = 24;
      t.cpuMonth(_n);
      resolveEvents(t);
      expect(d.alive, isFalse);
    });
  });

  group('英訳', () {
    test('足した文に英語がある', () {
      const keys = [
        '子会社の資金が尽きた',
        '子会社{0}の現金が尽き、借金を返せなくなりました（足りない分 {1}・子会社の借金 {2}）。銀行はもう貸してくれません。親会社として助けるか、倒れさせるかを決めてください。',
        '倒れさせる',
        '子会社は倒産し、持ち株の値打ち{0}が特別損失になる。評判とブランド、部下の忠誠が少し下がる',
        '{0}を入れて助ける',
        '増資で入れ、持ち株は{0}に増える。うち{1}は銀行から借りる',
        '増資で入れ、持ち株は{0}に増える。借金はグループの数に入ったまま',
        '{0}はもう子会社ではありません',
        'お金が足りず、{0}を助けられませんでした',
        '{0}に{1}を入れて助けました（うち{2}は銀行から借りました）。持ち株は{3}になりました',
        '{0}に{1}を入れて助けました。持ち株は{2}になりました',
        '子会社{0}を倒産させた',
        '子会社{0}は倒産しました。持ち株の値打ち{1}を特別損失にしました。会社の評判と部下の気持ちが少し下がりました',
        '子会社の借金（持ち分）',
        'グループの借金',
        '子会社がいるので、格付け・上限・金利は、子会社の借金と利益と担保の持ち分を足したグループの数で見ます',
        '子会社の倒産',
        '参考：子会社の借金',
        '参考：グループ借金',
        'グループの借金@@term',
      ];
      final missing = [for (final k in keys) if (enText(k) == null) k];
      expect(missing, isEmpty, reason: missing.join('\n'));
      for (final k in keys) {
        expect(_cjk.hasMatch(enText(k)!), isFalse, reason: k);
      }
    });
  });

  group('画面', () {
    setUpAll(loadRealFonts);
    for (final size in const [Size(844, 390), Size(1194, 834)]) {
      for (final lang in const ['ja', 'en']) {
        testWidgets('銀行の画面のグループの借金・子会社の資金が尽きた小窓・決算書の特別損失 ${size.width.round()}×${size.height.round()}（$lang）', (tester) async {
          await _walk(tester, size, lang);
        });
      }
    }
  });
}

/// 本体の縦の巻きを上から送り、[f] が見えるところで止める
Future<void> _seek(WidgetTester tester, Finder f) async {
  // いちばん高さのある縦の巻き（本体）
  final st = tester.stateList<ScrollableState>(find.byType(Scrollable)).where((s) => axisDirectionToAxis(s.axisDirection) == Axis.vertical).toList()
    ..sort((a, b) => (b.context.size!.width * b.context.size!.height).compareTo(a.context.size!.width * a.context.size!.height));
  final pos = st.first.position;
  pos.jumpTo(0);
  await tester.pump();
  for (var i = 0; i < 40 && f.evaluate().isEmpty; i++) {
    pos.jumpTo((pos.pixels + pos.viewportDimension * .5).clamp(0, pos.maxScrollExtent).toDouble());
    await tester.pump();
  }
  if (f.evaluate().isNotEmpty) {
    await tester.ensureVisible(f.first);
    await tester.pump();
  }
}

Future<void> _walk(WidgetTester tester, Size size, String lang) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final ctl = GameController(prefs: prefs, newRandom: () => ParkMiller(5), lang: lang);
  L.lang = lang;
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
    }
  }

  final g = _game();
  final c = _sub(g);
  // 子会社の借金の持ち分が親の年の利益の4倍（格付け B）
  g.finOf(c).debt = g.annualProfit() * 4 / (g.pctOf(c) / 100);
  g.calcAll();
  ctl.game = g;
  ctl.save();

  // 銀行の画面：子会社の借金（持ち分）とグループの借金
  ctl.setTab('money');
  ctl.setMoney('bank');
  await settle('bank');
  expect(find.byKey(const ValueKey('bank-grpdebt')), findsOneWidget);
  await shot(tester, key, 'sd_bank_$n', pixelRatio: 1.5);

  // 子会社の資金が尽きた小窓
  _broke(g, c);
  g.cpuMonth(_n);
  ctl.save();
  nextEvent(ctl);
  await settle('event');
  expect(find.text(tr('子会社の資金が尽きた')), findsOneWidget);
  await shot(tester, key, 'sd_event_$n', pixelRatio: 1.5);
  // 倒れさせる → 月を締めて、決算書の特別損失に出る
  final e = g.events.firstWhere((x) => x.k == 'subBroke');
  ctl.closeSheet();
  g.events.remove(e);
  e.choices.first.f();
  g.nextQuarter();
  g.events.clear();
  ctl.render();
  ctl.setMoney('fs');
  ctl.setFs(tab: 'pl', mode: 'year', year: g.finThisYear()!.y);
  ctl.toggleShown('fs-sp');
  expect(g.books.months.last.g('subLoss'), greaterThan(0));
  await settle('fs-pl');
  final sp = find.text(tr('子会社の倒産'));
  await _seek(tester, sp);
  await settle('fs-sp');
  expect(sp, findsWidgets);
  await shot(tester, key, 'sd_fs_pl_$n', pixelRatio: 1.5);

  // 貸借対照表の参考の行（もう1つ借りている子会社を持たせて）
  final c2 = _sub(g);
  g.finOf(c2).debt = 2e9;
  g.nextQuarter();
  g.events.clear();
  ctl.render();
  ctl.setFs(tab: 'bs', mode: 'year', year: g.finThisYear()!.y);
  await settle('fs-bs');
  final memo = find.text(tr('参考：グループ借金'));
  await _seek(tester, memo);
  await settle('fs-bs-memo');
  expect(memo, findsWidgets);
  await shot(tester, key, 'sd_fs_bs_$n', pixelRatio: 1.5);
}
