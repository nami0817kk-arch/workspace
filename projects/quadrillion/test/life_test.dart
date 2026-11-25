// 現実に寄せる 段6（1.1.0+30）の仕組み：税（減価償却・消費税・相続税）・設備の古び・技術の世代・ブランド・災害と保険・特許・
// 時代のIT・宣伝・社会の移り変わり・民事再生・社長の始め方と経歴・私生活・世間の顔・小さな知らせ・世界の上位の大きさ・目標の文
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';

import 'support/bot.dart';

Game _g({int year = 1980, String start = 'grad', int workYears = 0, String? workCat, int seed = 11}) => Game.newGame(
    SetupConfig(mode: 'world', year: year, traits: const ['charm', 'careful'], start: start, workYears: workYears, workCat: workCat),
    rng: ParkMiller(seed));

/// 事業を1つ始めた会社（店舗型）
Game _withBiz({int year = 1980}) {
  final g = _g(year: year);
  g.cash = 1e10;
  final i = g.liveInds().firstWhere((i) => kindOf(i) == 'shop' && g.licMissing(i.id) == null);
  g.startBiz(i.id);
  g.hUsed = 0;
  return g;
}

void main() {
  test('減価償却：店などに使ったお金は耐用年数で毎月の償却になり、税の計算で利益から引く', () {
    final g = _withBiz();
    expect(g.depMonth(), greaterThan(0));
    final b = g.biz.first;
    final life = profileOf(indm[b.ind]!).life;
    expect(g.life.deps.first.left, (life * 12).round());
    // 同じ利益でも、償却がある月は税が少ない
    g.q = 2;
    g.ytdPre = 0;
    g.ytdTax = 0;
    final withDep = g.monthTax(1e8);
    final saved = g.life.deps.toList();
    g.life.deps.clear();
    g.ytdPre = 0;
    g.ytdTax = 0;
    final noDep = g.monthTax(1e8);
    g.life.deps = saved;
    expect(withDep, lessThan(noDep));
  });

  test('消費税：1989年4月に3%になり、半年は一般の客の買い控えで事業の力が落ちる', () {
    final g = _withBiz(year: 1988);
    while (!(g.year == 1989 && g.q == 5)) {
      resolveEvents(g);
      g.nextQuarter();
    }
    expect(g.consumptionTax(), 3);
    expect(g.log.any((l) => msgKey(l.m).startsWith('消費税が')), isTrue);
    expect(g.life.ctaxLeft, greaterThan(0));
  });

  test('設備の古び：寿命を過ぎると修繕が増えて客も離れ、新しくすると戻る', () {
    final g = _withBiz();
    final b = g.biz.first;
    for (var i = 0; i < 6; i++) {
      resolveEvents(g);
      g.nextQuarter();
    }
    g.calcAll();
    final fresh = g.lifePowF(b);
    g.life.eqAge[b.id] = (profileOf(indm[b.ind]!).life * 12 * 1.6).round();
    g.calcAll();
    expect(g.eqOver(b), greaterThan(.5));
    expect(g.lifePowF(b), lessThan(fresh));
    g.cash = 1e12;
    g.hUsed = 0;
    g.renewEquip(b);
    expect(g.life.eqAge[b.id], 0);
    expect(g.eqOver(b), 0);
  });

  test('技術の世代：新しい世代が出ると、乗り換えるまで事業の力が落ちる', () {
    final g = _g(year: 2000);
    g.cash = 1e12;
    final i = g.liveInds().firstWhere((i) => g.techInd(i) && g.licMissing(i.id) == null);
    g.startBiz(i.id);
    final b = g.biz.first;
    g.life.techGen[b.id] = g.techCur(i) - 1;
    expect(g.techBehind(b), 1);
    final behind = g.lifePowF(b);
    g.hUsed = 0;
    g.upgradeTech(b);
    expect(g.techBehind(b), 0);
    expect(g.lifePowF(b), greaterThan(behind));
  });

  test('災害と保険：保険をかけていれば修理の8割が戻る。やめると全部自社の負担', () {
    final g = _withBiz();
    final n = <String>[];
    g.cash = 1e10;
    g.disasterHit(g.home, .1, (m, [t = '']) => n.add(m));
    final insured = 1e10 - g.cash;
    g.setInsured(false);
    g.cash = 1e10;
    g.disasterHit(g.home, .1, (m, [t = '']) => n.add(m));
    final bare = 1e10 - g.cash;
    expect(insured, greaterThan(0));
    expect(bare, closeTo(insured * 5, insured * .01));
  });

  test('特許：技術の業種で大当たりすると取れ、他社に使わせると使用料が入る。期限で切れる', () {
    final g = _g(year: 2000);
    g.cash = 1e12;
    final i = g.liveInds().firstWhere((i) => g.patentInd(i) && g.licMissing(i.id) == null);
    g.startBiz(i.id);
    final b = g.biz.first;
    g.patentOnHit(b, (m, [t = '']) {});
    expect(g.life.patents.length, 1);
    final p = g.life.patents.first;
    final f0 = g.lifePowF(b);
    g.licensePatent(p);
    expect(p.lic, isTrue);
    expect(g.lifePowF(b), lessThan(f0), reason: '使わせると真似を止める力はなくなる');
    expect(g.patentFee(p), greaterThan(0));
    p.until = g.turn;
    resolveEvents(g);
    g.nextQuarter();
    expect(g.life.patents, isEmpty);
  });

  test('時代のIT：当たり前になったITを入れていないと利益率が落ち、入れると戻る', () {
    final g = _withBiz(year: 1992);
    expect(g.itBehind(), 1, reason: 'POS（1982）が当たり前');
    final b = g.biz.first;
    g.calcAll();
    final before = b.profit;
    g.cash = 1e12;
    g.hUsed = 0;
    g.adoptIT();
    expect(g.life.it, 2);
    expect(g.itBehind(), 0);
    g.calcAll();
    expect(b.profit, greaterThan(before));
  });

  test('社会の移り変わり：少子高齢化で医療の市場が伸び、環境への関心でエネルギーが縮む', () {
    final med = IND.firstWhere((i) => i.cat == 'med');
    final ene = IND.firstWhere((i) => i.cat == 'ene');
    expect(socialF(med, 1990), 1);
    expect(socialF(med, 2030), greaterThan(1.1));
    expect(socialF(ene, 2035), lessThan(1));
    expect(adMediaOf(1985), isNot(adMediaOf(2015)));
  });

  test('民事再生：資金が尽きたら一度だけ借金の6割を減らして立て直し、二度目は倒産', () {
    final g = _withBiz();
    g.loanFromEvent(5e9);
    g.cash = -1e9;
    g.bankCtl = 5;
    final debt0 = g.debt;
    final own0 = g.sh.own;
    g.coverShort((m, [t = '']) {});
    expect(g.over, isNull);
    expect(g.life.restructured, isTrue);
    expect(g.debt, lessThan(debt0 * .4 + 1e9 + 1));
    expect(g.sh.own, closeTo(own0 * .4, .01));
    expect(g.cash, 0);
    g.cash = -1e9;
    g.coverShort((m, [t = '']) {});
    expect(g.over, isNotNull);
  });

  test('社長の始め方：会社員を5年してからだと27歳・貯金と人脈があり、勤めた業界の事業に経験が効く', () {
    final a = _g();
    final b = _g(start: 'work', workYears: 5, workCat: 'food');
    expect(a.pres.age, 22);
    expect(b.pres.age, 27);
    expect(b.cash, greaterThan(a.cash));
    expect(b.net, greaterThan(a.net));
    expect(b.life.bio!.jobs.single.cat, 'food');
    expect(b.life.bio!.sk, isNotNull);
    final food = IND.firstWhere((i) => i.cat == 'food');
    final make = IND.firstWhere((i) => i.cat == 'make');
    expect(b.presExpF(food), greaterThan(1));
    expect(b.presExpF(make), 1);
    // 経歴を作っても、ゲームの乱数の並びはずれない（同じ種なら CPU の会社は同じ）
    expect(a.cos.map((c) => c.name).toList(), b.cos.map((c) => c.name).toList());
  });

  test('相続税：子どもが継ぐと持ち株の一部を手放す', () {
    final g = _withBiz();
    final k = g.mkPerson(0)..kid = true;
    k.age = 30;
    final own0 = g.sh.own;
    g.takeOver(k);
    expect(g.sh.own, lessThan(own0));
    expect(g.history.any((c) => msgKey(c.m).startsWith('相続税')), isTrue);
  });

  test('私生活と世間の顔：結婚・業界団体の役職・取材・寄付で評判とブランドが育つ', () {
    final g = _withBiz();
    for (var y = 0; y < 25 && !g.life.married; y++) {
      for (var m = 0; m < 12; m++) {
        resolveEvents(g);
        g.nextQuarter();
      }
    }
    expect(g.life.married, isTrue);
    g.hUsed = 0;
    g.cash = 1e12;
    final f0 = g.life.fame;
    g.takeIndustryPost();
    g.giveTalk();
    g.donate();
    expect(g.life.fame, greaterThan(f0));
    expect(g.turn < g.life.assocUntil, isTrue);
  });

  test('赤字の店などを閉めると数が減り、解約金がかかる。最後の1つは閉められない', () {
    final g = _withBiz();
    final b = g.biz.first;
    // 始めたばかりの店は育ちかけなので、育ちきった店を4つ置く
    final s = b.young.first.s;
    b.sites[s] = Site(n: 4);
    g.calcAll();
    final n0 = g.unitTotal(b), c0 = g.cash;
    g.closeUnits(b, s, 1);
    expect(g.unitTotal(b), n0 - 1);
    expect(g.cash, lessThan(c0));
    b.sites[s]!.n = 1;
    b.young.clear();
    for (final k in b.sites.keys.toList()) {
      if (k != s) b.sites.remove(k);
    }
    g.hUsed = 0;
    expect(msgKey(g.closeUnits(b, s, 1)), startsWith('最後の1つ'));
  });

  test('格付け：赤字の月に少し借りただけでは D にならない（担保の4分の1までは B）', () {
    final g = _withBiz();
    g.hist = [HistEntry(t: '1980-1', cap: 1, rev: 1, cash: 0, pre: -1e5)];
    g.loanFromEvent(1e5);
    expect(g.ratingIdx(), 1);
  });

  test('事業を売る値は、店などの値打ちを下回らない（資金繰りで手放しても投げ売りにならない）', () {
    final g = _withBiz();
    final b = g.biz.first;
    b.sites[b.young.first.s] = Site(n: 100);
    g.calcAll();
    expect(g.sellValue(b), greaterThanOrEqualTo(g.unitTotal(b) * g.unitCapexAvg(b) * .5 * .7 - 1));
  });

  test('小さな知らせは月が替わると見送る方で片付く', () {
    final g = _withBiz();
    var took = false;
    g.events.add(GameEvent(title: M('大型の受注'), small: true, text: 'x', choices: [
      Choice(M('受ける'), M(''), () {
        took = true;
        return M('受注しました。現場は大忙しです');
      }),
      Choice(M('断る'), M(''), () => M('見送りました')),
    ]));
    g.nextQuarter();
    expect(took, isFalse);
    expect(g.events.where((e) => e.small && msgKey(e.title) == '大型の受注' && e.text == 'x'), isEmpty);
  });

  test('世界の上位：1980年の1位は12兆円を下回る（CPU の取り分を0.78倍にした）', () {
    final g = _g();
    final top = g.rankList().firstWhere((r) => !r.me);
    expect(top.cap, lessThan(12e12));
    expect(top.cap, greaterThan(6e12));
  });

  test('目標の文：世界1位ではなく、次の順位の節目と主な業種での順位を出す', () {
    final g = _withBiz();
    final t = msgKey(g.goalText());
    expect(t, startsWith('次の目標：世界'));
  });

  test('保存して読み戻しても、段6の状態は同じ', () {
    final g = _g(start: 'work', workYears: 3, workCat: 'net');
    g.cash = 1e10;
    g.startBiz(g.liveInds().firstWhere((i) => g.licMissing(i.id) == null && g.capexOf(i) < 1e9).id);
    g.life.patents.add(Patent(g.biz.first.ind, 300, lic: true));
    g.life.married = true;
    g.life.brand = 42;
    g.life.eqAge[g.biz.first.id] = 77;
    final back = Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>, rng: ParkMiller(1));
    expect(back.life.start, 'work');
    expect(back.life.workCat, 'net');
    expect(back.life.patents.single.lic, isTrue);
    expect(back.life.married, isTrue);
    expect(back.life.brand, 42);
    expect(back.life.eqAge[g.biz.first.id], 77);
    expect(back.life.bio?.jobs.single.cat, 'net');
    expect(back.depMonth(), closeTo(g.depMonth(), 1));
    expect(back.life.seed, g.life.seed);
  });
}
