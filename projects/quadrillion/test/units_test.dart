// 店・ライン・拠点の数（1.1.0+26。企画書「現実に寄せる」の段2）：
// 業種の型と特性・上限・責任者・本部・物流・開くまでの月・許可・経費の内訳。
// いちばん大事なのは「借金を積んでも、店の数は上限・責任者・本部・物流・開くまでの月で頭打ちになる」こと
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';

import 'support/bot.dart';

Game _g([int year = 1990, int seed = 5]) => Game.newGame(SetupConfig(year: year, traits: const ['charm', 'careful']), rng: ParkMiller(seed));

/// 月を進める（出来事は片付け、社長の時間は毎月まっさらにする）
void _month(Game g) {
  resolveEvents(g);
  g.nextQuarter();
  g.events.clear();
  g.hUsed = 0;
}

/// 自動で伸ばす（いちばん要る手を、時間とお金の続くかぎり毎月打つ。人手も補う）
void _grow(Game g, Biz b, int months) {
  for (var m = 0; m < months; m++) {
    for (var i = 0; i < 6; i++) {
      g.hUsed = 0;
      final o = g.growOpt(b, g.cash * .9, want: 50, time: true);
      if (o == null) break;
      o.run();
    }
    final need = g.crewNeedPeople(b);
    if (need > 0) g.hireN(b, need);
    _month(g);
  }
}

void main() {
  group('業種の型と特性', () {
    test('200業種すべてに7つの型のどれかを当てる（数の内訳）', () {
      final n = <String, int>{for (final k in KINDS) k: 0};
      for (final i in IND) {
        expect(KIND_OF.containsKey(i.id), isTrue, reason: '${i.id} に型が無い');
        n[kindOf(i)] = n[kindOf(i)]! + 1;
      }
      expect(KIND_OF.length, IND.length, reason: '型の表に、業種に無い鍵がある');
      expect(n.values.fold(0, (a, b) => a + b), 200);
      for (final k in KINDS) {
        expect(n[k], greaterThanOrEqualTo(10), reason: '$k が少なすぎる');
      }
      // ignore: avoid_print
      print('型の内訳: ${n.entries.map((e) => '${KIND_JA[e.key]} ${e.value}').join('・')}');
    });

    test('業種ごとに約30の特性を持ち、1単位の初期投資と月の売上は正の実額。札は4つまで', () {
      expect(IndProfile.count, greaterThanOrEqualTo(30));
      for (final i in IND) {
        final p = profileOf(i);
        expect(p.unitCapex, greaterThan(0), reason: i.id);
        expect(p.unitRev, greaterThan(0), reason: i.id);
        expect(p.unitRev, lessThan(p.unitCapex * 2), reason: '${i.id}: 1か月で元が取れるほどの回転は無い');
        expect(p.open.$1, lessThanOrEqualTo(p.open.$2));
        expect(profileTags(p).length, lessThanOrEqualTo(4));
      }
      // コンビニ1店は数千万円、日販50万円前後
      final k = profileOf(indm['konbini']!);
      expect(k.kind, 'shop');
      expect(k.unitCapex, inInclusiveRange(1e7, 1e8));
      expect(k.unitRev / 30, inInclusiveRange(3e5, 7e5));
      // 半導体は工場型・銀行は許認可型・鉄道はインフラ型・映画は当たり外れ型・コンサルは人で稼ぐ型・SNSはネット型
      expect(kindOf(indm['semi']!), 'factory');
      expect(kindOf(indm['bank']!), 'license');
      expect(kindOf(indm['rail']!), 'infra');
      expect(kindOf(indm['movie']!), 'hit');
      expect(kindOf(indm['consult']!), 'people');
      expect(kindOf(indm['sns']!), 'net');
    });

    test('値段は物価だけで動く（現金や時価総額の割合で決めない）', () {
      final a = _g(1990)..cash = 1e9;
      a.startBiz('konbini');
      final b = _g(1990)..cash = 1e12;
      b.startBiz('konbini');
      expect(a.unitCapexAvg(a.biz.first), closeTo(b.unitCapexAvg(b.biz.first), 1));
      expect(a.leadCost(a.biz.first), closeTo(b.leadCost(b.biz.first), 1));
      final c = _g(2020)..cash = 1e9;
      c.startBiz('konbini');
      expect(c.unitCapexAvg(c.biz.first) / a.unitCapexAvg(a.biz.first), closeTo(nomOf(2020) / nomOf(1990), .01));
    });
  });

  group('店を出すまでの流れ', () {
    test('店長がいないと開けない。育てると6か月後に開けるようになる', () {
      final g = _g()..cash = 5e10;
      g.startBiz('konbini');
      final b = g.biz.first;
      _month(g);
      b.leads = 0;
      final s = g.siteKeys('jp', 'shop').first;
      expect(msgKey(g.openBlock(b, s, 1)!), startsWith('{0}が足りません'));
      expect(msgKey(g.trainLeads(b, 2)), startsWith('{0}を{1}人育て始めました'));
      for (var m = 0; m < 5; m++) {
        _month(g);
      }
      expect(b.leads, 0, reason: '5か月ではまだ育たない');
      _month(g);
      expect(b.leads, 2);
    });

    test('開くまで3〜6か月かかり、その間は数に入らない。開いた直後は売上が育つ途中', () {
      final g = _g()..cash = 5e10;
      g.startBiz('konbini');
      final b = g.biz.first;
      _month(g);
      b.leads = 5;
      final before = g.unitTotal(b);
      final r = g.openBest(b, 3);
      expect(txIn(r, 'ja'), contains('を開き始めました'), reason: txIn(r, 'ja'));
      final pend = g.pendingUnits(b);
      expect(pend, greaterThan(0));
      _month(g);
      _month(g);
      expect(g.unitTotal(b), before, reason: '2か月ではまだ開かない');
      for (var m = 0; m < 4; m++) {
        _month(g);
      }
      expect(g.unitTotal(b), before + pend, reason: '6か月以内には開く');
      final fresh = b.young.where((y) => y.age <= 4).toList();
      expect(fresh, isNotEmpty);
      expect(g.rampF(b, 0), lessThan(.6));
      expect(g.rampF(b, 30), 1);
    });

    test('物件は立地ごとに毎月出て、使うと減る。他社と取り合う物件は取られることがある', () {
      final g = _g()..cash = 5e10;
      g.startBiz('konbini');
      final b = g.biz.first;
      _month(g);
      expect(b.offers, isNotEmpty);
      b.leads = 99;
      final s = b.offers.first.s;
      final n0 = g.offersAt(b, s);
      g.openUnits(b, s, 1);
      expect(g.offersAt(b, s), n0 - 1);
      // 他社が3社狙う物件ばかりだと、何度かに1度は取られる
      var lost = 0;
      for (var i = 0; i < 40; i++) {
        b.offers = [Offer(s: s, riv: 3)];
        g.hUsed = 0;
        if (msgKey(g.openUnits(b, s, 1)).startsWith('狙った物件は')) lost++;
      }
      expect(lost, inInclusiveRange(10, 39));
    });

    test('指導員が足りないと売れる量が落ちる。置くと戻る', () {
      final g = _g()..cash = 5e10;
      g.startBiz('konbini');
      final b = g.biz.first;
      _month(g);
      b.young.add(Cohort(s: g.siteKeys('jp', 'shop').first, n: 60, age: 40));
      b.sv = 0;
      final need = g.svNeed(b);
      expect(need, greaterThan(5));
      final low = g.capRev(b);
      b.leads = need;
      expect(msgKey(g.placeSV(b, need)), startsWith('{0}を{1}人置きました'));
      expect(g.capRev(b), greaterThan(low * 1.2));
      expect(b.leads, 0, reason: '指導員は育った店長から上げる');
    });

    test('1つの都市圏で20店を超えると配送の拠点が要る。無いと原価が上がり、作ると消える', () {
      final g = _g()..cash = 5e10;
      g.startBiz('konbini');
      final b = g.biz.first;
      _month(g);
      b.young.add(Cohort(s: 'jp/0/1', n: 40, age: 40));
      _month(g);
      expect(g.hubShort(b), isNotEmpty);
      expect(g.hubPen(b), greaterThan(0));
      expect(g.hubWanted(b), contains('jp/0'));
      final p0 = b.profit;
      expect(msgKey(g.buildHub(b, 'jp/0')), startsWith('{0}に配送の拠点を作り始めました'));
      for (var m = 0; m < 9; m++) {
        _month(g);
      }
      expect(b.hubs, contains('jp/0'));
      expect(g.hubShort(b)['jp/0'], isNull);
      expect(g.hubPen(b), lessThan(1e-9));
      expect(b.profit, isNot(p0));
    });

    test('上限を超えては開けない（市場の大きさと都市の人口から）', () {
      final g = _g()..cash = 5e10;
      g.startBiz('konbini');
      final b = g.biz.first;
      _month(g);
      final cap = g.capUnits(b);
      expect(cap, greaterThan(100));
      final keys = g.siteKeys('jp', 'shop');
      final tot = keys.fold(0.0, (a, s) => a + g.siteCap(b, s));
      expect(tot, closeTo(cap, keys.length + 2.0), reason: '立地の上限の合計は国の上限');
      // 東京の都心は地方より1人あたりの置きやすさが高い
      expect(g.siteCap(b, 'jp/0/0') / g.sitePop('jp/0/0'), greaterThan(g.siteCap(b, 'jp/-/2') / g.sitePop('jp/-/2')));
      b.young.add(Cohort(s: 'jp/0/0', n: g.siteCap(b, 'jp/0/0'), age: 40));
      b.leads = 9;
      b.offers = [Offer(s: 'jp/0/0')];
      expect(msgKey(g.openBlock(b, 'jp/0/0', 1)!), anyOf(startsWith('その立地はもう上限です'), startsWith('{0}の上限')));
    });

    test('許認可型は許可が下りるまで売上が無く、下りると営業を始める', () {
      final g = _g(1990)..cash = 1e12;
      expect(msgKey(g.startBiz('bank')), startsWith('「{0}」を{1}で始めました'));
      final b = g.biz.first;
      expect(b.lic, inInclusiveRange(10, 30));
      _month(g);
      expect(b.rev, 0);
      expect(msgKey(g.openBest(b, 1)), startsWith('許可がまだ下りていません'));
      var m = 0;
      while (b.lic > 0 && m < 40) {
        _month(g);
        m++;
      }
      expect(g.unitTotal(b), greaterThan(0));
      _month(g);
      expect(b.rev, greaterThan(0));
    });

    test('ネット型は解約で利用者が減り、宣伝で一度に集められる数に上限がある', () {
      final g = _g(2010)..cash = 1e11;
      g.startBiz('sns');
      final b = g.biz.first;
      final u0 = g.unitTotal(b);
      for (var i = 0; i < 30; i++) {
        _month(g);
      }
      expect(g.unitTotal(b), lessThan(u0), reason: '何もしないと解約で減る');
      expect(g.monthOpenCap(b), lessThan(10));
      expect(msgKey(g.openUnits(b, 'jp/-/n', 50)), startsWith('宣伝で一度に集められる利用者には限りがあります'));
    });
  });

  group('借金を積んでも頭打ち', () {
    test('同じ遊びで手元が50億円と1兆円でも、2年後の店の数はほとんど同じ（上限・店長・指導員・物流・開くまでの月で決まる）', () {
      int run(double money) {
        final g = _g(1990, 21)..cash = money;
        g.startBiz('konbini');
        final b = g.biz.first;
        _grow(g, b, 24);
        return (g.unitTotal(b) + g.pendingUnits(b)).round();
      }

      final small = run(5e10), huge = run(1e12);
      // ignore: avoid_print
      print('2年後の店の数（開く準備中を含む）: 手元50億円 $small店／手元1兆円 $huge店');
      expect(huge, lessThanOrEqualTo((small * 1.1).ceil()), reason: 'お金を20倍にしても店は増えない');
      final g = _g(1990, 21)..cash = 1e12;
      g.startBiz('konbini');
      expect(huge, lessThan(g.capUnits(g.biz.first) * .2), reason: '2年では上限に遠く届かない（育つ速さで頭打ち）');
    });

    test('お金の割合の手（店を増やす・投資）をいくら打っても、売れる量を超えた売上は出ない', () {
      final g = _g()..cash = 1e12;
      g.startBiz('konbini');
      final b = g.biz.first;
      _month(g);
      final cap = g.capRev(b) * g.seasonF(b);
      for (var i = 0; i < 5; i++) {
        g.hUsed = 0;
        g.invest(b, .5);
      }
      g.calcAll();
      expect(b.rev, lessThanOrEqualTo(cap * 1.001 + 1));
      expect(g.limitOf(b), 'cap');
    });
  });

  group('経費と保存', () {
    test('経費は11の内訳を持ち、売上から利益を引いた額とおおむね合う', () {
      final g = _g()..cash = 5e10;
      g.startBiz('konbini');
      final b = g.biz.first;
      _grow(g, b, 12);
      final e = g.expenses();
      expect(e.keys.toList(), expKeys);
      expect(expKeys.length, 11);
      final spent = e.entries.where((x) => x.key != 'tax').fold(0.0, (a, x) => a + x.value);
      final want = g.biz.fold(0.0, (a, x) => a + x.rev) - g.pre;
      expect(spent, closeTo(want, want.abs() * .02 + 1e4));
      expect(e['rent'], greaterThan(0));
      expect(e['cogs'], greaterThan(e['rent']!));
    });

    test('店・物件・責任者・拠点・売掛は保存して戻せる', () {
      final g = _g()..cash = 5e10;
      g.startBiz('konbini');
      final b = g.biz.first;
      _grow(g, b, 8);
      b.hubs.add('jp/1');
      final back = Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>, rng: ParkMiller(1));
      final c = back.biz.first;
      expect(back.unitTotal(c), closeTo(g.unitTotal(b), 1e-6));
      expect(c.offers.length, b.offers.length);
      expect(c.leads, b.leads);
      expect(c.sv, b.sv);
      expect(c.hubs, b.hubs);
      expect(c.young.length, b.young.length);
      expect(back.ar, closeTo(g.ar, 1));
      expect(back.capRev(c), closeTo(g.capRev(b), g.capRev(b) * 1e-6 + 1));
    });

    test('店などを持たない古い形の事業は、読み込んだときに売上から数を見積もって置く', () {
      final g = _g()..cash = 5e10;
      g.startBiz('konbini');
      _month(g);
      final j = g.toJson();
      final bj = (j['biz'] as List).first as Map<String, dynamic>;
      bj.remove('sites');
      bj.remove('young');
      final back = Game.fromJson(jsonDecode(jsonEncode(j)) as Map<String, dynamic>, rng: ParkMiller(1));
      expect(back.unitTotal(back.biz.first), greaterThan(0));
    });
  });
}
