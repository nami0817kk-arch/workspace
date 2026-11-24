// 人（1.1.0+27。企画書「人を現実の人材に寄せる」の段3）：
// 経歴・細かい能力・人柄・暮らし、給料の相場（国と時代）、働き方の慣習、採用の市場、店長・指導員の出どころ、人が生まれてから辞めるまで
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';

import 'support/bot.dart';

Game _g({int year = 1990, String home = 'jp', int seed = 5}) =>
    Game.newGame(SetupConfig(year: year, home: home, traits: const ['charm', 'careful']), rng: ParkMiller(seed));

/// 月を進める（出来事は片付け、社長の時間は毎月まっさらにする）
void _month(Game g) {
  resolveEvents(g);
  g.nextQuarter();
  g.events.clear();
  g.hUsed = 0;
}

/// 決まった中身の人（能力 [v]・年齢 [age]）
Person _person(Game g, {int v = 50, int age = 35}) {
  final p = g.mkPerson(0);
  p.age = age;
  p.setSk({for (final k in skKeys) k: v});
  p.lic = [];
  p.fame = 30;
  p.salary = g.mktPay(p);
  return p;
}

void main() {
  group('人の中身', () {
    test('経歴・細かい能力・人柄・暮らしを持ち、4つの能力は今までの値のまま細かい能力から出る', () {
      final g = _g();
      for (var i = 0; i < 40; i++) {
        final p = g.mkPerson(0);
        expect(p.real, isTrue);
        expect(p.sk!.keys.toSet(), skKeys.toSet());
        for (final k in abKeys) {
          expect(p.ab[k], AbView.calc(p.sk!, k), reason: '4つの能力は細かい能力の重みつきの平均');
        }
        final grad = const [18, 20, 22, 22, 24][p.edu];
        expect(p.jobs.fold(0, (a, j) => a + j.years), lessThanOrEqualTo((p.age - grad).clamp(0, 99)), reason: '職歴は卒業してからの年数に収まる');
        if (p.lic.contains('doctor')) expect(p.major, 'med');
        expect(p.health, inInclusiveRange(0, 100));
        expect(p.salary, greaterThan(0));
      }
    });

    test('4つの能力を書き換えると（今までの出来事・年の衰え）、その差が細かい能力に配られる', () {
      final g = _g();
      final p = _person(g, v: 50);
      p.ab['kai'] = 70;
      expect(p.sk!['tech'], 70);
      expect(p.sk!['prod'], 70);
      expect(p.ab['kai'], 70);
      expect(p.sk!['sales'], 50, reason: 'ほかの分野は動かない');
    });

    test('保存して読み直しても、経歴・細かい能力・暮らし・社外の人が残る', () {
      final g = _g();
      final p = g.cands.first;
      g.hire(p);
      g.fire(g.staff.first, 'quit');
      final back = Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>, rng: ParkMiller(1));
      expect(back.alumni, hasLength(1));
      final q = back.alumni.first;
      expect(q.real, isTrue);
      expect(q.sk, p.sk);
      expect(q.jobs.length, p.jobs.length);
      expect(q.left, 'quit');
      q.ab['zai'] = 90;
      expect(q.sk!['fin'], greaterThan(p.sk!['fin']!), reason: '読み直した人も4つの能力が細かい能力の見え方になっている');
    });

    test('試作との一致を見る遊び（extras を切る）では、人に経歴を付けない', () {
      final g = Game.newGame(SetupConfig(traits: const ['charm', 'careful']), rng: ParkMiller(5), extras: false);
      expect(g.cands, hasLength(3));
      expect(g.cands.every((p) => !p.real), isTrue);
    });
  });

  group('給料の相場', () {
    test('平均賃金の統計で国と時代が変わる（物価が上がれば上がり、豊かな国ほど高い）', () {
      final j80 = _g(year: 1980), j20 = _g(year: 2020), us = _g(year: 2020, home: 'us'), inn = _g(year: 2020, home: 'in');
      double m(Game g) => g.mktPay(_person(g));
      expect(m(j20), greaterThan(m(j80) * 1.5));
      expect(m(us), greaterThan(m(j20)));
      expect(m(inn), lessThan(m(j20) * .3));
    });

    test('年功の強い国と時代（1980年の日本）は、同じ腕なら年上ほど高い。米国ではその差が小さい', () {
      double gap(Game g) => g.mktPay(_person(g, age: 50)) / g.mktPay(_person(g, age: 28));
      final jp = _g(year: 1980), us = _g(year: 1980, home: 'us');
      expect(gap(jp), greaterThan(1.3));
      expect(gap(us), lessThan(gap(jp)));
      expect(gap(us), lessThan(1.15));
    });

    test('腕・資格・評判で上がる', () {
      final g = _g(year: 2010);
      expect(g.mktPay(_person(g, v: 80)), greaterThan(g.mktPay(_person(g, v: 40)) * 1.5));
      final d = _person(g)..lic = ['doctor'];
      expect(g.mktPay(d), greaterThan(g.mktPay(_person(g)) * 1.8));
      final f = _person(g)..fame = 90;
      expect(g.mktPay(f), greaterThan(g.mktPay(_person(g))));
    });

    test('相場より低いとやる気が下がり、引き抜かれそうな印が付く。昇給で相場まで上げると戻る', () {
      final g = _g();
      final p = _person(g);
      p.salary = g.mktPay(p) * .7;
      p.loy = 70;
      p.tenure = 30;
      p.partner = true; // 転職で辞めないようにして、やる気の動きだけを見る
      g.staff.add(p);
      for (var i = 0; i < 6; i++) {
        p.health = 90;
        _month(g);
      }
      expect(p.loy, lessThan(70));
      expect(g.poachRisk(p), isTrue);
      expect(g.unhappy(p), isTrue);
      final before = p.loy;
      final m = g.raisePay(p);
      expect(txIn(m, 'ja'), contains('相場まで上げました'));
      expect(g.payRatio(p), greaterThanOrEqualTo(1));
      expect(p.loy, greaterThan(before));
      expect(g.poachRisk(p), isFalse);
    });
  });

  group('働き方の慣習', () {
    test('日本は1980年に終身雇用・年功が強く、2025年には転職が当たり前になる。米国は昔から転職が多い', () {
      final j80 = _g(year: 1980).normOf(), j25 = _g(year: 2025).normOf(), us = _g(year: 1980, home: 'us').normOf();
      expect(j80.life, greaterThan(.85));
      expect(j25.life, lessThan(.6));
      expect(j25.hop, greaterThan(j80.hop * 2));
      expect(us.hop, greaterThan(j80.hop * 4));
      expect(j80.retire, 55);
      expect(j25.retire, 65);
    });

    test('解雇の手当は終身雇用が強いほど重く、ほかの部下のやる気も下がる。解雇した人は社外に残るが呼び戻せない', () {
      final jp = _g(year: 1980), us = _g(year: 1980, home: 'us');
      expect(jp.severanceMonths(), greaterThan(us.severanceMonths() * 2.5));
      final a = _person(jp), b = _person(jp);
      jp.staff.addAll([a, b]);
      b.loy = 70;
      jp.cash = 1e10;
      final c0 = jp.cash;
      final m = jp.dismiss(a);
      expect(txIn(m, 'ja'), contains('解雇の手当'));
      expect(jp.cash, closeTo(c0 - a.salary * jp.severanceMonths(), 1));
      expect(b.loy, lessThan(70));
      expect(jp.alumni, contains(a));
      expect(txIn(jp.rehire(a), 'ja'), contains('戻ってくれません'));
    });

    test('定年は国と時代で変わる（1980年の日本は55歳で引退していく）', () {
      final g = _g(year: 1980);
      final p = _person(g, age: 57);
      g.staff.add(p);
      for (var i = 0; i < 36 && g.staff.contains(p); i++) {
        p.health = 90;
        p.loy = 90;
        _month(g);
      }
      expect(g.staff.contains(p), isFalse);
      expect(g.alumni.firstOrNull?.left, 'retired');
    });
  });

  group('採用の市場', () {
    test('一括採用の国（日本）は、新卒が4月にまとめて出る', () {
      final g = _g(year: 1990);
      while (g.q != 3) {
        _month(g);
      }
      _month(g); // 3月の終わりに4月の候補を作る
      expect(g.q, 4);
      expect(g.cands.where((p) => p.src == 'grad').length, greaterThanOrEqualTo(3));
      for (final p in g.cands.where((p) => p.src == 'grad')) {
        expect(p.age, inInclusiveRange(22, 24));
        expect(p.jobs, isEmpty);
        expect(g.hireFeeOf(p), lessThan(g.hireFeeOf(g.cands.firstWhere((x) => x.src == 'mid'))), reason: '新卒は安く雇える');
      }
      _month(g);
      expect(g.cands.where((p) => p.src == 'grad'), isEmpty, reason: '5月には新卒はいない');
    });

    test('中途の候補は転職の多い国・時代ほど多い', () {
      final jp = _g(year: 1980), us = _g(year: 2015, home: 'us');
      expect(us.hireMarket().mid, greaterThan(jp.hireMarket().mid));
    });

    test('会社の評判が良いほど、失業が多いほど、良い候補が来る', () {
      double avg(Game g) {
        var t = 0.0, n = 0;
        for (var i = 0; i < 60; i++) {
          for (final p in g.rollCands().where((p) => p.src == 'mid')) {
            t += Game.totOf(p);
            n++;
          }
        }
        return t / n;
      }

      final lo = _g(year: 2000, seed: 9), hi = _g(year: 2000, seed: 9);
      hi.rep = 40;
      hi.listed = true;
      expect(hi.coRep(), greaterThan(lo.coRep() + 30));
      expect(avg(hi), greaterThan(avg(lo) + 8));
      expect(hi.hireMarket().q, greaterThan(lo.hireMarket().q));
    });

    test('資格の要る業種（病院）は、医師がいないと始められない。医師を雇うと始められる', () {
      final g = _g(year: 2000);
      g.cash = 1e12;
      final m = g.startBiz('hospital');
      expect(txIn(m, 'ja'), contains('医師が要ります'));
      expect(g.biz, isEmpty);
      final d = _person(g)..lic = ['doctor'];
      g.staff.add(d);
      g.hUsed = 0;
      g.startBiz('hospital');
      expect(g.biz.map((b) => b.ind), contains('hospital'));
      expect(txIn(m, 'en'), isNot(contains('医')));
    });
  });

  group('店長・指導員を人の仕組みにつなぐ', () {
    Game shop() {
      final g = _g(year: 2000);
      g.cash = 1e11;
      g.startBiz('konbini');
      final b = g.biz.first;
      final s = g.siteKeys('jp', 'shop').first;
      b.young.clear();
      b.sites[s] = Site(n: 40);
      b.leads = 0;
      g.calcAll();
      return g;
    }

    test('中途で雇える店長の数は、終身雇用の強い国・時代ほど少ない', () {
      final jp = _g(year: 1980), us = _g(year: 2010, home: 'us');
      jp.cash = us.cash = 1e11;
      jp.startBiz('konbini');
      us.startBiz('konbini');
      expect(us.midLeadCap(us.biz.first), greaterThan(jp.midLeadCap(jp.biz.first) + 3));
    });

    test('店長が辞めると責任者のいない店ができ、売れる量が落ちる。中途で雇うと翌月に埋まる', () {
      final g = shop();
      final b = g.biz.first;
      final full = g.capRev(b);
      b.vac = 10;
      expect(g.capRev(b), lessThan(full * .95));
      g.hUsed = 0;
      final want = g.midLeadLeft(b);
      expect(want, greaterThan(0));
      g.hireLeads(b, 10);
      expect(g.trainees(b), greaterThan(0));
      _month(g);
      _month(g);
      expect(b.vac, lessThan(10));
    });

    test('辞める店長は国と時代の転職の多さで決まる（1980年の日本は少なく、米国は多い）', () {
      double lost(String home, int year) {
        final g = _g(year: year, home: home, seed: 3);
        g.cash = 1e12;
        g.startBiz('konbini');
        final b = g.biz.first;
        b.young.clear();
        b.sites[g.siteKeys(home, 'shop').first] = Site(n: 200);
        var v = 0.0;
        for (var i = 0; i < 24; i++) {
          b.vac = 0;
          b.leads = 0;
          g.monthLeads(b, (_, [_ = '']) {});
          v += b.vac;
        }
        return v;
      }

      expect(lost('us', 2010), greaterThan(lost('jp', 1980) * 3));
    });

    test('育てる店長の腕は、責任者の人事と統率の腕で上がり、育つのも早い', () {
      final g = shop();
      final b = g.biz.first;
      final weak = _person(g, v: 20), strong = _person(g, v: 90);
      g.staff.addAll([weak, strong]);
      b.mgr = weak.id;
      final qw = g.trainLeadQ(b);
      b.mgr = strong.id;
      final qs = g.trainLeadQ(b);
      expect(qs, greaterThan(qw + 15));
      g.hUsed = 0;
      g.trainLeads(b, 1);
      expect(b.pipe.last.left, lessThan(KIND_LEAD_MONTHS['shop']!));
    });

    test('手の空いた店長を、名前のある部下（同じ業種の経験つき）に引き上げられる', () {
      final g = shop();
      final b = g.biz.first;
      b.leads = 2;
      g.hUsed = 0;
      final n0 = g.staff.length;
      final m = g.promoteLead(b);
      expect(txIn(m, 'ja'), contains('引き上げました'));
      expect(g.staff.length, n0 + 1);
      expect(b.leads, 1);
      final p = g.staff.last;
      expect(p.src, 'lead');
      expect(p.jobs.any((j) => j.own && j.ind == b.ind), isTrue);
      expect(g.expF(p, indm[b.ind]!), greaterThan(1.05), reason: '同じ業種の経験が効く');
      expect(txIn(m, 'en'), isNot(contains('店長')));
    });
  });

  group('人が生まれてから辞めるまで', () {
    test('若い人は経験で伸び、年をとると衰える', () {
      final g = _g();
      final young = _person(g, v: 40, age: 24)..pot = 1.3;
      final old = _person(g, v: 60, age: 63);
      g.staff.addAll([young, old]);
      for (final p in [young, old]) {
        p.partner = true;
      }
      final y0 = g.topSkill(young), o0 = g.topSkill(old);
      for (var i = 0; i < 36; i++) {
        young.health = old.health = 90;
        young.loy = old.loy = 90;
        _month(g);
      }
      expect(g.topSkill(young), greaterThan(y0 + 3));
      expect(g.topSkill(old), lessThan(o0));
    });

    test('働かせすぎると健康を崩して休みに入り、そのあいだ責任者として働けない', () {
      final g = _g(year: 2000);
      g.cash = 1e11;
      g.startBiz('konbini');
      final b = g.biz.first;
      final p = _person(g)..str = 10;
      p.partner = true;
      g.staff.add(p);
      g.setManager(b, p.id);
      g.culture = 'sports';
      b.young.clear();
      b.sites[g.siteKeys('jp', 'shop').first] = Site(n: 80);
      for (var i = 0; i < 60 && p.away == 0; i++) {
        _month(g);
      }
      expect(p.away, greaterThan(0));
      expect(g.mgrOf(b), isNull, reason: '休んでいる責任者はいないのと同じ');
      expect(g.healthRisk(p), isFalse);
    });

    test('話を聞くと、隠れた人柄や家族のことが1つずつ分かり、困っていることを話してくれる', () {
      final g = _g();
      final p = g.mkPerson(0)..tenure = 1;
      g.staff.add(p);
      final k0 = p.known.length;
      final m = g.talkTo(p);
      expect(p.known.length, k0 + 1);
      expect(txIn(m, 'ja'), contains('と話しました'));
      expect(RegExp('[ぁ-ん]').hasMatch(txIn(m, 'en')), isFalse);
    });

    test('研修に出すと1か月いなくなり、戻るとその分野が伸びる。留学は1年', () {
      final g = _g();
      g.cash = 1e10;
      final p = _person(g, v: 40)..partner = true;
      g.staff.add(p);
      g.sendTraining(p, 3);
      expect(p.away, 1);
      _month(g);
      expect(p.away, 0);
      expect(p.sk!['fin'], greaterThan(40));
      g.hUsed = 0;
      g.sendTraining(p, -1);
      expect(p.away, 12);
    });

    test('辞めた人は社外に残り（8人まで）、呼び戻せる', () {
      final g = _g();
      g.cash = 1e10;
      final p = _person(g);
      g.staff.add(p);
      g.fire(p, 'poached');
      expect(g.alumni.first, p);
      expect(p.left, 'poached');
      g.hUsed = 0;
      final m = g.rehire(p);
      expect(txIn(m, 'ja'), contains('呼び戻しました'));
      expect(g.staff, contains(p));
      expect(g.alumni, isNot(contains(p)));
      for (var i = 0; i < 12; i++) {
        final x = _person(g);
        g.staff.add(x);
        g.fire(x, 'quit');
      }
      expect(g.alumni, hasLength(8));
    });

    test('自動で30年回すと、雇い・育ち・辞め・引退する人が出て、店長の腕と空きも動く', () {
      final g = _g(year: 1980, seed: 22);
      var hired = 0, left = 0;
      final seen = <int>{};
      for (var m = 0; m < 360 && g.over == null; m++) {
        botMonth(g, units: true, focus: true);
        for (final p in g.staff) {
          if (seen.add(p.id)) hired++;
        }
      }
      left = g.alumni.length;
      expect(hired, greaterThan(3));
      expect(left, greaterThan(0));
      for (final p in g.staff) {
        expect(p.real, isTrue);
      }
    });
  });

  group('「何倍」の書き方', () {
    test('1万倍からは上2桁に丸めて「約91万」「about 910,000」', () {
      L.lang = 'ja';
      expect(timesL(3.25), '3.3');
      expect(timesL(908607.6), '約91万');
      expect(timesL(12345), '約1.2万');
      expect(timesL(1.23e8), '約1.2億');
      expect(timesL(3.4e9), '約34億');
      expect(timesL(4321), '4,321');
      L.lang = 'en';
      expect(timesL(908607.6), 'about 910,000');
      L.lang = 'ja';
    });
  });
}
