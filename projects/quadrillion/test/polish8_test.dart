import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';

import 'support/bot.dart';

/// 8回目の改善: 現地法人（現地法人だけの上場）と臨時の会議
class FixedRandom implements math.Random {
  double v;
  int n = 0;
  FixedRandom(this.v);
  @override
  double nextDouble() {
    n++;
    return v;
  }

  @override
  int nextInt(int max) => (nextDouble() * max).floor();
  @override
  bool nextBool() => nextDouble() < .5;
}

/// 何回引いたかを数える乱数
class CountingRandom implements math.Random {
  final math.Random r;
  int n = 0;
  CountingRandom(this.r);
  @override
  double nextDouble() {
    n++;
    return r.nextDouble();
  }

  @override
  int nextInt(int max) => (nextDouble() * max).floor();
  @override
  bool nextBool() => nextDouble() < .5;
}

final _cjk = RegExp('[　-ヿ㐀-鿿＀-￯]');
final _news = <String>[];
void _n(String m, [String t = '']) => _news.add(m);

Game _game({int months = 36, int seed = 808, bool extras = true}) {
  final s = Game.newGame(SetupConfig(mode: 'endless', year: 1990, traits: ['charm', 'careful']), rng: ParkMiller(seed), extras: extras);
  for (var i = 0; i < months; i++) {
    botMonth(s);
  }
  resolveEvents(s);
  s.events.clear();
  s.ap = 3;
  return s;
}

/// 米国にも出ている事業を1つ用意する
Biz _abroad(Game s, [String c = 'us']) {
  final b = s.biz.first;
  b.ctry = [s.home, c];
  s.calcAll();
  return b;
}

Person _staff(Game s, {bool partner = false}) {
  final p = s.mkPerson(.5);
  if (partner) {
    p.partner = true;
    p.stake = 5;
  }
  s.staff.add(p);
  return p;
}

Company _rival(Game s) => s.cos.firstWhere((c) => c.alive && c.rival != null && c.parent != 'player');

void main() {
  tearDown(() => L.lang = 'ja');
  setUp(_news.clear);

  group('現地法人', () {
    test('部下を社長にして、その国の分を株100%の子会社に分ける', () {
      final s = _game();
      final b = _abroad(s);
      final p = _staff(s);
      b.mgr = p.id;
      final pow0 = b.power, frac = cw('us', s.yr()) / s.reachOf(b);
      final msg = s.makeLocal(b, 'us', p.id);
      expect(msgKey(msg), isNot('今月の手が残っていません'));
      final c = s.locals().single;
      expect(c.loc, 'us');
      expect(c.parent, 'player');
      expect(s.pctOf(c), 100);
      expect(c.presName, p.name);
      expect(c.fromStaff, p.trait, reason: '社長の特性を持ち、自分の判断で動く');
      expect(s.staff.contains(p), isFalse);
      expect(b.mgr, isNull);
      expect(s.ctryOf(b), isNot(contains('us')));
      expect(b.power, closeTo(pow0 * (1 - frac), pow0 * 1e-9));
      expect(c.biz.single.power, closeTo(pow0 * frac, pow0 * 1e-9));
      expect(c.rev, greaterThan(0));
      expect(s.ap, 2);
      expect(s.history.last.k, 'local');
      expect(txIn(msg, 'ja'), contains('現地法人'));
      // 同じ国にはもう出られない（現地法人が出ている）
      expect(msgKey(s.enterCountry(b, 'us', 'solo')), 'その国には現地法人が出ています');
      expect(s.hasLocal('us', b.ind), isTrue);
    });

    test('現地で社長を雇うと、その国の名前の人が社長になる', () {
      final s = _game();
      final b = _abroad(s, 'de');
      s.makeLocal(b, 'de');
      final c = s.locals().single;
      expect(c.presName, contains('・'), reason: 'ドイツの名前（名・姓）');
      expect(c.fromStaff, isNotNull);
      expect(STRAITS.any((t) => t.id == c.fromStaff), isTrue);
    });

    test('分けられないとき: 始めた国・出ていない国・相棒・2つ目・手がない', () {
      final s = _game();
      final b = _abroad(s);
      expect(msgKey(s.makeLocal(b, s.home)), '始めた国の分は分けられません');
      expect(msgKey(s.makeLocal(b, 'fr')), 'その国には出ていません');
      final pt = _staff(s, partner: true);
      expect(msgKey(s.makeLocal(b, 'us', pt.id)), startsWith('相棒は本社に残します'));
      expect(s.localPresCands().contains(pt), isFalse);
      s.ap = 0;
      expect(msgKey(s.makeLocal(b, 'us')), '今月の手が残っていません');
      s.ap = 3;
      s.makeLocal(b, 'us');
      b.ctry = [s.home, 'us'];
      expect(msgKey(s.makeLocal(b, 'us')), 'その国にはもう現地法人があります');
    });

    test('地元の規制の緩み: 組んでいた国でも利益を半分にされない。中国に現地法人があればネットと金融も組まずに入れる', () {
      final s = _game();
      s.econ = 1;
      final b = s.biz.first;
      b.ctry = [s.home, 'cn'];
      b.jv = ['cn'];
      s.calcAll();
      s.makeLocal(b, 'cn');
      final c = s.locals().single;
      expect(b.jv, isEmpty);
      final ind = indm[c.biz.single.ind]!;
      expect(c.profit / c.rev, closeTo(ind.mg * c.eff, 1e-9), reason: '組む相手の取り分がない');
      // ネットの事業を始めて、中国への出方を見る
      final net = s.inds.firstWhere((i) => i.cat == 'net');
      final nb = Biz(id: s.uid(), ind: net.id, power: 1);
      expect(s.entryModes(nb, 'cn'), containsAll(['solo', 'jv', 'buy']));
      s.extras = false;
      expect(s.entryModes(nb, 'cn'), ['jv'], reason: 'extras を切ると前と同じ');
    });

    test('現地法人の社長は自分の判断で動く（独断の投資・反発）', () {
      final s = _game();
      final b = _abroad(s);
      s.makeLocal(b, 'us');
      final c = s.locals().single;
      final pw = c.biz.single.power;
      c.rel = 0;
      s.rng = FixedRandom(.005);
      s.dealsMonthly(_n);
      expect(c.biz.single.power, closeTo(pw * 1.1, pw * 1e-9));
      expect(_news.map(msgKey), contains('子会社{0}の社長{1}が、独断で大きな投資をしました'));
      expect(s.events.any((e) => e.subco == c.id), isTrue, reason: '関係が悪いと反発する');
    });

    test('現地法人の株の30%をその国の市場に上場させて大金を得る', () {
      final s = _game();
      final b = _abroad(s);
      s.makeLocal(b, 'us');
      final c = s.locals().single;
      final cash0 = s.cash, v = c.cap * .3 * .95;
      s.ap = 3;
      final msg = s.subIPO(c);
      expect(msgKey(msg), '現地法人{0}を{1}の市場に上場させ、株を30%売って{2}を得ました。まだ{3}持っています');
      expect(c.listed, isTrue);
      expect(s.pctOf(c), 70);
      expect(s.cash, closeTo(cash0 + v, v * 1e-6 + 1));
      expect(s.history.last.k, 'ipo');
      expect(txIn(msg, 'en'), contains('USA'));
    });

    test('上場した現地法人は宿敵に狙われる（10%で知らせ、25%で3つの答え）', () {
      final s = _game();
      final b = _abroad(s);
      s.makeLocal(b, 'us');
      final c = s.locals().single;
      s.subIPO(c);
      for (final x in s.cos) {
        if (x.rival != null) x.cash = c.cap * 10;
      }
      s.rng = FixedRandom(.001);
      // 上場していなければ狙われない
      c.listed = false;
      s.localMonthly(_n);
      expect(c.locRivPct, 0);
      c.listed = true;
      s.localMonthly(_n);
      expect(c.locRiv, isNotNull);
      expect(c.locRivPct, 3);
      final foe = s.coById(c.locRiv)!;
      expect(foe.rival, isNotNull);
      expect(foe.rival!.hurt, greaterThan(0), reason: '因縁に残る');
      for (var i = 0; i < 20 && c.locRivPct < 25; i++) {
        s.localMonthly(_n);
      }
      expect(c.locRivPct, greaterThanOrEqualTo(25));
      expect(c.locRivPct, lessThanOrEqualTo(30), reason: '市場に出た30%まで');
      final evs = s.events.where((e) => e.who == foe).toList();
      expect(evs.map((e) => msgKey(e.title)), ['現地法人の株を買われている', '現地法人が狙われている']);
      final big = evs.last;
      expect(big.choices.map((x) => msgKey(x.l)), ['株を買い戻す', '持ち株を売り渡す', '突っぱねる']);
      // 突っぱねる → 稼ぐ力が落ちる
      final eff = c.eff;
      big.choices[2].f();
      expect(c.eff, closeTo(eff * .9, 1e-12));
      // 買い戻す → 相手の持ち分がなくなる
      final cost = s.localBuybackCost(c);
      s.cash = cost * 2;
      big.choices[0].f();
      expect(c.locRivPct, 0);
      expect(c.locRiv, isNull);
      expect(s.cash, closeTo(cost, cost * 1e-9));
    });

    test('狙われた現地法人を売り渡すと、相手の会社のものになる', () {
      final s = _game();
      final b = _abroad(s);
      s.makeLocal(b, 'us');
      final c = s.locals().single;
      s.subIPO(c);
      final foe = _rival(s);
      c.locRiv = foe.id;
      c.locRivPct = 26;
      final e = s.evLocalHostile(c, foe, 25);
      final cash0 = s.cash, v = c.cap * .7 * 1.3, n0 = foe.biz.length;
      e.choices[1].f();
      expect(c.alive, isFalse);
      expect(s.locals(), isEmpty);
      expect(foe.biz.length, n0 + 1);
      expect(s.cash, closeTo(cash0 + v, v * 1e-6 + 1));
    });

    test('ロシアの制裁でも現地法人は手を引かずに済む（力は2割落ちる・一度だけ）', () {
      final s = _game();
      final b = _abroad(s, 'ru');
      s.makeLocal(b, 'ru');
      final c = s.locals().single;
      final pw = c.biz.single.power;
      s.year = 2023;
      s.localMonthly(_n);
      s.localMonthly(_n);
      expect(c.alive, isTrue);
      expect(c.biz.single.power, closeTo(pw * .8, pw * 1e-9));
      expect(_news.where((m) => msgKey(m).startsWith('【制裁】')), hasLength(1));
    });

    test('extras を切ると、現地法人は作れず、毎月の動きも乱数を使わない', () {
      final s = _game(extras: false);
      final b = _abroad(s);
      expect(s.localCountries(b), isEmpty);
      expect(msgKey(s.makeLocal(b, 'us')), '今は使えません');
      final r = CountingRandom(math.Random(1));
      s.rng = r;
      s.localMonthly(_n);
      s.crisisMonthly();
      expect(r.n, 0);
      expect(s.events, isEmpty);
    });
  });

  group('臨時の会議', () {
    /// 相棒と部下が1人ずついる会社
    Game withPeople({bool listed = true}) {
      final s = _game();
      s.staff.clear();
      _staff(s, partner: true);
      final p = _staff(s);
      s.biz.first.mgr = p.id;
      s.listed = listed;
      s.events.clear();
      return s;
    }

    test('乗っ取りの危機: 宿敵が20%に近づくと会議。相棒・部下・株主の代表が別々の案を出す', () {
      final s = withPeople();
      final foe = _rival(s);
      s.sh = Shares(own: 40, float: 42, riv: {foe.id: 18});
      s.crisisMonthly();
      final e = s.events.single;
      expect(e.em, 'takeover');
      expect(e.who, foe);
      expect(msgKey(e.title), '臨時の会議：{0}');
      expect(txIn(e.title, 'ja'), '臨時の会議：乗っ取りの危機');
      expect(txIn(e.text, 'ja'), contains('20%に近づいています'));
      final ls = e.choices.map((c) => txIn(c.l, 'ja')).toList();
      expect(ls, hasLength(4));
      expect(ls[0], endsWith('ホワイトナイトに頼む'), reason: '相棒');
      expect(ls[1], endsWith('新しい株を出して薄める'), reason: '部下');
      expect(ls[2], '株主の代表の案：自社株買いで市場の株を減らす');
      expect(ls[3], '会議を打ち切る');
      // 同じ割合では二度開かない
      s.events.clear();
      s.crisisMonthly();
      expect(s.events, isEmpty);
      // 33.4% に近づくと、もう一度
      s.sh.riv[foe.id] = 31;
      s.crisisMonthly();
      expect(txIn(s.events.single.text, 'ja'), contains('33.4%に近づいています'));
      // 50% に近づくと、もう一度
      s.events.clear();
      s.sh.riv[foe.id] = 46;
      s.crisisMonthly();
      expect(txIn(s.events.single.text, 'ja'), contains('50%に近づいています'));
    });

    test('株主の代表の案を選ぶと自社株買いが手を使わずに実行され、選ばれなかった相棒と部下の忠誠が下がる', () {
      final s = withPeople();
      final foe = _rival(s);
      s.sh = Shares(own: 40, float: 42, riv: {foe.id: 18});
      s.cash = s.cap;
      s.crisisMonthly();
      final e = s.events.single;
      final pt = s.staff.firstWhere((p) => p.partner), st = s.staff.firstWhere((p) => !p.partner);
      final l0 = pt.loy, l1 = st.loy, ap0 = s.ap, f0 = s.sh.float;
      expect(txIn(e.choices[2].s, 'ja'), contains('の忠誠が下がる'));
      final r = e.choices[2].f();
      expect(txIn(r, 'ja'), startsWith('株主の代表の案を選びました'));
      expect(s.sh.float, lessThan(f0));
      expect(pt.loy, closeTo(l0 - 10, 1e-9));
      expect(st.loy, closeTo(l1 - 10, 1e-9));
      expect(pt.rej, 1);
      expect(s.ap, ap0, reason: '手は使わない');
    });

    test('相棒の案（ホワイトナイト）を選ぶと、相棒の忠誠は上がり部下は下がる', () {
      final s = withPeople();
      final foe = _rival(s);
      s.sh = Shares(own: 40, float: 42, riv: {foe.id: 18});
      s.cash = s.cap * 10;
      s.crisisMonthly();
      final pt = s.staff.firstWhere((p) => p.partner), st = s.staff.firstWhere((p) => !p.partner);
      pt.loy = 50;
      st.loy = 50;
      final ally0 = s.sh.ally;
      s.cash = 1e20;
      final r = s.events.single.choices[0].f();
      expect(txIn(r, 'ja'), contains('ホワイトナイトになり'));
      expect(s.sh.ally, greaterThan(ally0));
      expect(pt.loy, 53);
      expect(st.loy, 40);
    });

    test('大きな不祥事: 謝罪会見・社長の報酬の返上・広告から選ぶ。1年に一度まで', () {
      final s = withPeople();
      s.scandal = 12;
      s.crisisMonthly();
      final e = s.events.single;
      expect(e.em, 'scandal');
      expect(txIn(e.title, 'ja'), '臨時の会議：大きな不祥事');
      final ls = e.choices.map((c) => msgKey(c.l)).toList();
      expect(ls, ['{0}の案：{1}', '{0}の案：{1}', '{0}の案：{1}', '会議を打ち切る']);
      expect(txIn(e.choices[0].l, 'ja'), endsWith('社長の報酬を返上する'), reason: '相棒');
      expect(txIn(e.choices[1].l, 'ja'), endsWith('広告で信用を取り戻す'), reason: '部下');
      expect(txIn(e.choices[2].l, 'ja'), endsWith('謝罪会見を開く'), reason: '株主の代表');
      final cash0 = s.cash;
      e.choices[2].f();
      expect(s.scandal, 6);
      expect(s.cash, lessThan(cash0));
      s.events.clear();
      s.scandal = 12;
      s.crisisMonthly();
      expect(s.events, isEmpty, reason: '1年に一度まで');
      s.turn += 12;
      s.crisisMonthly();
      expect(s.events.single.em, 'scandal');
    });

    test('資金が尽きかける: 上場前はメインバンクが入る。借入・資産の売却・経費の削減', () {
      final s = withPeople(listed: false);
      s.sh = Shares(own: 100);
      while (s.biz.length < 2) {
        final i = s.liveInds().firstWhere((i) => !s.biz.any((b) => b.ind == i.id));
        s.cash += s.capexOf(i);
        s.startBiz(i.id);
      }
      s.land = 0;
      s.pre = -1e8;
      s.cash = 1e8;
      s.crisisMonthly();
      final e = s.events.single;
      expect(e.em, 'cash');
      expect(txIn(e.text, 'ja'), contains('メインバンクの担当者（銀行）'));
      expect(txIn(e.choices[0].l, 'ja'), endsWith('銀行から借りる'), reason: '相棒');
      expect(txIn(e.choices[1].l, 'ja'), endsWith('資産を売る'), reason: '部下');
      expect(txIn(e.choices[2].l, 'ja'), 'メインバンクの担当者の案：経費を削る');
      final d0 = s.debt, c0 = s.cash;
      e.choices[0].f();
      expect(s.debt, greaterThan(d0));
      expect(s.cash - c0, closeTo(s.debt - d0, 1));
      // 資産を売る
      s.events.clear();
      s.turn += 12;
      s.pre = -1e8;
      s.cash = 1e8;
      s.crisisMonthly();
      final n0 = s.biz.length;
      s.events.single.choices[1].f();
      expect(s.biz.length, n0 - 1);
    });

    test('会議を打ち切ると、意見を出した部下と相棒の忠誠が少し下がる', () {
      final s = withPeople();
      s.scandal = 12;
      s.crisisMonthly();
      for (final p in s.staff) {
        p.loy = 50;
      }
      final e = s.events.single;
      e.choices.last.f();
      expect(s.staff.map((p) => p.loy), everyElement(46));
    });

    test('部下がいなくても、株主の代表とメインバンクの2人で会議になる', () {
      final s = withPeople();
      s.staff.clear();
      for (final b in s.biz) {
        b.mgr = null;
      }
      s.scandal = 12;
      s.crisisMonthly();
      final e = s.events.single;
      expect(e.choices, hasLength(3));
      expect(txIn(e.choices[0].l, 'ja'), startsWith('株主の代表の案'));
      expect(txIn(e.choices[1].l, 'ja'), startsWith('メインバンクの担当者の案'));
      expect(txIn(e.choices[2].s, 'ja'), '何もしない');
    });

    test('会議が残っているあいだは、次の会議を開かない', () {
      final s = withPeople();
      s.scandal = 12;
      s.crisisMonthly();
      s.pre = -1e8;
      s.cash = 1;
      s.crisisMonthly();
      expect(s.events.where((e) => e.em != null), hasLength(1));
    });
  });

  group('セーブ', () {
    test('現地法人と臨時の会議のしるしはセーブに入り、読み戻せる', () {
      final s = _game();
      final b = _abroad(s);
      s.makeLocal(b, 'us');
      final c = s.locals().single;
      s.subIPO(c);
      c.locRiv = _rival(s).id;
      c.locRivPct = 12;
      s.scandal = 12;
      s.crisisMonthly();
      final back = Game.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>, rng: ParkMiller(1));
      final c2 = back.locals().single;
      expect(c2.loc, 'us');
      expect(c2.listed, isTrue);
      expect(c2.locRiv, c.locRiv);
      expect(c2.locRivPct, 12);
      expect(back.crisis, s.crisis);
      expect(back.crisis['em:s'], s.turn);
      expect(c2.rev, closeTo(c.rev, c.rev * 1e-9));
    });

    test('古いセーブ（現地法人・臨時の会議がない）は空から始める', () {
      final s = _game();
      final j = jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>;
      j.remove('crisis');
      for (final c in j['cos'] as List) {
        (c as Map).remove('loc');
        c.remove('locRiv');
        c.remove('locRivPct');
      }
      final back = Game.fromJson(j, rng: ParkMiller(1));
      expect(back.crisis, isEmpty);
      expect(back.locals(), isEmpty);
      expect(back.cos.every((c) => c.loc == null && c.locRiv == null && c.locRivPct == 0), isTrue);
      botMonth(back);
    });
  });

  group('英語', () {
    test('臨時の会議と現地法人の出来事・結果に日本語が残らない', () {
      final seen = <String>[];
      final s = _game();
      s.staff.clear();
      _staff(s, partner: true);
      final st = _staff(s);
      s.biz.first.mgr = st.id;
      s.listed = true;
      final foe = _rival(s);
      s.sh = Shares(own: 40, float: 42, riv: {foe.id: 18});
      s.cash = s.cap * 10;
      for (final kind in ['takeover', 'scandal', 'cash']) {
        final e = s.crisisMeeting(kind, foe: foe, near: 20)!;
        seen.addAll([e.title, e.text, for (final c in e.choices) ...[c.l, c.s]]);
        seen.add(e.choices.first.f());
      }
      final b = _abroad(s);
      seen.add(s.makeLocal(b, 'us', st.id));
      final c = s.locals().single;
      seen.add(s.subIPO(c));
      c.locRiv = foe.id;
      c.locRivPct = 26;
      for (final th in [10.0, 25.0]) {
        final e = s.evLocalHostile(c, foe, th);
        seen.addAll([e.title, e.text, for (final x in e.choices) ...[x.l, x.s]]);
      }
      seen.add(s.localBuyback(c));
      seen.addAll([for (final h in s.history) h.m, for (final t in foe.rival!.ties) t]);
      final bad = seen.map((m) => txIn(m, 'en')).where(_cjk.hasMatch).toSet();
      expect(bad, isEmpty, reason: bad.join('\n'));
    });
  });

  group('自動プレイ', () {
    /// 現地法人を作って上場させる自動プレイ（試作の手順に足す）
    void botLocal(Game s) {
      if (s.ap > 0) {
        for (final b in s.biz.toList()) {
          final cs = s.localCountries(b).where((c) => !s.hasLocal(c, b.ind)).toList();
          if (cs.isNotEmpty && s.ap > 0 && s.locals().length < 4) {
            final p = s.localPresCands().where((x) => !s.biz.any((y) => y.mgr == x.id)).firstOrNull;
            s.makeLocal(b, cs.first, p?.id);
          }
        }
      }
      for (final c in s.locals()) {
        if (!c.listed && s.ap > 0 && c.cap > 0) s.subIPO(c);
        if (c.locRivPct > 15 && s.cash > s.localBuybackCost(c) * 3) s.localBuyback(c);
      }
      botMonth(s);
    }

    for (final c in const [
      ('world', 1980, ['charm', 'gambler'], 'jp', 11),
      ('endless', 2000, ['tech', 'noble'], 'us', 12),
      ('quad', 1990, ['liar', 'frugal'], 'cn', 13),
    ]) {
      test('現地法人を作りながら50年回しても落ちない（${c.$1}・${c.$2}年・${c.$4}）', () {
        final s = Game.newGame(SetupConfig(mode: c.$1, year: c.$2, traits: c.$3, home: c.$4), rng: ParkMiller(c.$5 * 977));
        var made = 0, meetings = 0;
        for (var t = 0; t < 12 * 50 && s.over == null; t++) {
          meetings += s.events.where((e) => e.em != null).length;
          botLocal(s);
          made = math.max(made, s.locals().length);
          if (s.won != null) {
            s.mode = 'endless';
            s.won = null;
          }
          expect(s.cash.isFinite, isTrue);
          expect(s.cap.isFinite && s.cap >= 1, isTrue);
          for (final x in s.locals()) {
            expect(x.rev.isFinite && x.profit.isFinite && x.cap.isFinite, isTrue);
            expect(x.locRivPct, inInclusiveRange(0, 30.0001));
          }
          expect(s.sh.own, inInclusiveRange(0, 100.0001));
        }
        expect(made > 0 || s.over != null || s.biz.every((b) => s.localCountries(b).isEmpty), isTrue, reason: '海外に出ていれば現地法人を作れた');
        // ignore: avoid_print
        print('${c.$1}/${c.$4}: 現地法人 最大$made社・臨時の会議 $meetings回・${s.year}年・${s.over ?? ''}');
      }, timeout: const Timeout(Duration(minutes: 5)));
    }
  });
}
