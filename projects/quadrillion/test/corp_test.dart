// 会社どうしの仕組み（1.1.0+29。企画書「現実に寄せる」の段4）：
// 宿敵・CPU も同じ決まり（店などの数・借金・税・株価の式）・M&A（調べ・上乗せ・審査・統合・のれんと減損）・
// 上場（監査と社内の決まり・主幹事・地合い）・株価（決算・総会・動いた理由）・取引先・隠れた情報
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';

import 'support/bot.dart';

Game _g([int seed = 7, int months = 0]) {
  final g = Game.newGame(SetupConfig(mode: 'world', year: 1990, traits: const ['charm', 'careful']), rng: ParkMiller(seed));
  for (var m = 0; m < months && g.over == null; m++) {
    botMonth(g, units: true, focus: true);
  }
  resolveEvents(g);
  g.events.clear();
  g.hUsed = 0;
  g.down = 0;
  return g;
}

/// 自分の事業と同じ業種を持つ、小さめの CPU の会社（宿敵でない）
Company _target(Game g) {
  final my = {for (final b in g.biz) b.ind};
  final l = g.cos.where((c) => c.alive && c.parent != 'player' && c.rival == null && c.loc == null && c.cap > 0).toList()
    ..ssort((a, b) {
      final x = (b.biz.any((y) => my.contains(y.ind)) ? 1 : 0) - (a.biz.any((y) => my.contains(y.ind)) ? 1 : 0);
      return x != 0 ? x : a.cap.compareTo(b.cap);
    });
  return l.first;
}

void _month(Game g) {
  g.hUsed = 0;
  g.down = 0;
  g.nextQuarter();
  resolveEvents(g);
  g.events.clear();
}

void main() {
  group('宿敵・CPU も同じ決まりで動く', () {
    test('始めの CPU の会社は、客に見合う店などを持ち、借金と利息を持つ。上場しているのは大きな会社', () {
      final g = _g();
      final live = g.cos.where((c) => c.alive).toList();
      expect(live.length, greaterThan(200));
      for (final c in live.take(80)) {
        for (final b in c.biz) {
          if (b.dem <= 0) continue;
          expect(b.u, greaterThan(0), reason: c.name);
          // 売上は客の数と、店などが売れる量の小さい方
          expect(b.rev, lessThanOrEqualTo(b.dem + 1e-6));
          expect(b.rev, lessThanOrEqualTo(g.coCapRev(b) + 1e-6));
        }
      }
      final borrowed = live.where((c) => (c.fin?.debt ?? 0) > 0).length;
      expect(borrowed, greaterThan(live.length ~/ 2));
      final listed = live.where((c) => c.listed);
      expect(listed, isNotEmpty);
      for (final c in listed.take(30)) {
        expect(c.profit * 12 >= 3e8 * g.nom() || c.tier >= 1, isTrue);
      }
    });

    test('店などが足りなければ売上は店などで頭打ちになり、借金の利息で利益が減る', () {
      final g = _g();
      final c = g.cos.firstWhere((c) => c.alive && c.biz.isNotEmpty && c.biz.first.dem > 0 && c.loc == null);
      final b = c.biz.first;
      g.calcAll();
      final r0 = b.rev, p0 = c.profit;
      b.u *= .5;
      b.uy = 0;
      g.calcAll();
      expect(b.rev, closeTo(g.coCapRev(b), 1));
      expect(b.rev, lessThan(r0));
      b.u *= 2;
      g.calcAll();
      c.fin!.debt += 1e12;
      c.fin!.rate = .06;
      g.calcAll();
      expect(c.profit, closeTo(p0 - 1e12 * .06 / 12, p0.abs() * .02 + 1));
    });

    test('客が店などを超える会社は、毎月お金と借金で店などを開く（1か月に開ける数は責任者を育てる速さまで）', () {
      final g = _g();
      final c = g.cos.firstWhere((c) => c.alive && c.loc == null && c.biz.isNotEmpty && c.biz.first.dem > 0 && kindOf(indm[c.biz.first.ind]!) == 'shop');
      final b = c.biz.first;
      b.u *= .6;
      c.cash = 1e14;
      g.calcAll();
      final max = g.coOpenMax(b);
      final before = b.u + b.uy;
      g.cpuMonth((_, [_ = '']) {});
      final opened = b.u + b.uy - before;
      expect(opened, greaterThan(0));
      expect(opened, lessThanOrEqualTo(max + 1e-6));
      expect(c.fin!.heat, greaterThan(0));
    });

    test('借りすぎた会社は払えなくなると株価が半分になり、1年続くと倒れる。国の後ろ盾があれば助けが入る', () {
      final g = _g();
      final c = g.cos.firstWhere((c) => c.alive && c.rival == null && c.loc == null && c.parent != 'player' && c.biz.isNotEmpty);
      final news = <String>[];
      void n(String m, [String t = '']) => news.add(txIn(m, 'ja'));
      c.fin!.debt = 1e15;
      c.fin!.rate = .1;
      c.cash = -1e13;
      g.calcAll();
      final cap0 = c.cap;
      for (var i = 0; i < 3; i++) {
        c.cash = -1e13;
        g.cpuMonth(n);
      }
      expect(c.fin!.distress, greaterThanOrEqualTo(3));
      g.calcAll();
      expect(c.cap, lessThan(cap0));
      for (var i = 0; i < 12 && c.alive; i++) {
        c.cash = -1e13;
        g.cpuMonth(n);
      }
      expect(c.alive, isFalse);
      // 国策企業は倒れない
      final st = g.cos.where((x) => x.alive && x.rival?.type == 'state').firstOrNull ??
          (g.cos.firstWhere((x) => x.alive && x.rival != null && x.parent != 'player')..rival!.type = 'state');
      st.fin!.debt = 1e15;
      for (var i = 0; i < 14; i++) {
        st.cash = -1e13;
        g.cpuMonth(n);
      }
      expect(st.alive, isTrue);
      expect(news.any((m) => m.contains('国の支援')), isTrue, reason: news.join('\n'));
    });

    test('CPU どうしの買収も独禁法で止められる（同じ業種で合わせたシェアが5割を超える）', () {
      final g = _g();
      final a = g.cos.firstWhere((c) => c.alive && c.loc == null && c.biz.isNotEmpty);
      final ind = a.biz.first.ind;
      final b = g.cos.firstWhere((c) => c != a && c.alive && c.loc == null && c.biz.any((x) => x.ind == ind) && c.tier == a.tier,
          orElse: () => g.cos.firstWhere((c) => c != a && c.alive && c.biz.any((x) => x.ind == ind)));
      final m = g.mkt(indm[ind]!) * g.reg[a.tier] / 3;
      a.biz.first.rev = m * .4;
      b.biz.firstWhere((x) => x.ind == ind).rev = m * .3;
      expect(g.mergedShare(a, b), greaterThan(.5));
    });

    test('物件の取り合い：同じ業種で宿敵が店を開いた月は、物件を狙う他社が1社増える', () {
      final g = _g();
      final foe = g.cos.firstWhere((c) => c.alive && c.rival != null && c.biz.isNotEmpty && c.parent != 'player');
      final ind = foe.biz.first.ind;
      for (final c in g.cos) {
        c.fin?.heat = 0;
      }
      expect(g.offerRivals(ind, 0), 0);
      // 宿敵でない会社の出店は数えない
      for (final c in g.cos.where((c) => c.alive && c.rival == null && c.biz.any((b) => b.ind == ind))) {
        c.fin!.heat = 30;
      }
      expect(g.offerRivals(ind, 0), 0);
      foe.fin!.heat = 2;
      expect(g.offerRivals(ind, 1), 2);
    });
  });

  group('隠れた情報', () {
    test('他社の数字は、未上場なら±20%・上場なら±5%の幅で見え、調べると幅が狭まる。幅は計算のたびに同じ', () {
      final g = _g();
      final c = g.cos.firstWhere((c) => c.alive && c.parent != 'player' && c.profit > 0);
      c.listed = false;
      final r1 = g.seenRange(c, c.profit, 1);
      expect((r1.$2 - r1.$1) / c.profit, closeTo(.4, .1));
      expect(r1.$1, lessThan(c.profit * 1.25));
      expect(r1.$2, greaterThan(c.profit * .75));
      expect(g.seenRange(c, c.profit, 1), r1);
      c.listed = true;
      final r2 = g.seenRange(c, c.profit, 1);
      expect(r2.$2 - r2.$1, lessThan(r1.$2 - r1.$1));
      c.fin!.dd = 1;
      final r3 = g.seenRange(c, c.profit, 1);
      expect(r3.$2 - r3.$1, lessThan(r2.$2 - r2.$1));
    });
  });

  group('M&A', () {
    test('調べ→申し入れ（上乗せ）→手続き→統合。のれんが付き、統合のあいだは人が辞める', () {
      final g = _g(7, 36);
      g.cash = 1e15;
      final c = _target(g);
      c.fin!.offDebt = .1;
      c.fin!.suit = 0;
      c.fin!.flight = .1;
      c.fin!.rolled = true;
      final months = g.ddMonths(c);
      final cost = g.ddCost(c);
      final cash0 = g.cash;
      final r = txIn(g.maStart(c), 'ja');
      expect(r, contains('調べ始めました'));
      expect(g.cash, closeTo(cash0 - cost, 1));
      expect(g.dealOf(c)!.stage, 'dd');
      expect(txIn(g.maStart(c), 'ja'), contains('もう話を進めています'));
      for (var i = 0; i < months; i++) {
        _month(g);
      }
      expect(c.fin!.dd, 1);
      expect(g.dealOf(c)!.stage, 'offer');
      // 見つかった簿外の借金の分、上乗せを下げて申し入れる
      expect(g.dealOf(c)!.prem, closeTo(.2, 1e-9));
      // 必ず応じる形で見る
      c.fam = 0;
      c.rel = 100;
      for (var i = 0; i < 20 && g.dealOf(c) != null; i++) {
        g.dealOf(c)!.prem = 2;
        _month(g);
      }
      expect(c.parent, 'player');
      expect(c.fin!.gw, greaterThan(0));
      expect(c.fin!.integ, greaterThan(0));
      expect(c.fin!.integAll, inInclusiveRange(12, 36));
      final i0 = c.fin!.integ;
      _month(g);
      expect(c.fin!.attr, greaterThan(0));
      expect(c.fin!.integ, i0 - 1);
    });

    test('調べずに買うと、隠れた問題（簿外の借金・訴訟）が買ったあとに出る', () {
      final g = _g(8, 36);
      g.cash = 1e15;
      final c = _target(g);
      c.fin!.offDebt = .2;
      c.fin!.suit = .05;
      c.fin!.rolled = true;
      c.fam = 0;
      c.rel = 100;
      final d = MaDeal(co: c.id, stage: 'close', left: 1, prem: 1);
      final cash0 = c.cash;
      final msg = txIn(g.closeDeal(c, d), 'ja');
      expect(msg, contains('帳簿に載っていない借金'));
      expect(msg, contains('訴訟'));
      expect(c.cash, lessThan(cash0));
    });

    test('合わせたシェアが大きいと当局の審査が長く、止められることがある', () {
      final g = _g(7, 36);
      final c = _target(g);
      final b = g.biz.first;
      final m = g.mkt(indm[b.ind]!) / 3;
      if (!c.biz.any((x) => x.ind == b.ind)) c.biz.add(CoBiz(ind: b.ind, power: 1));
      c.biz.firstWhere((x) => x.ind == b.ind).rev = m * .3;
      b.rev = m * .35;
      expect(g.myMergedShare(c), greaterThan(.6));
      final rv = g.reviewOf(c);
      expect(rv.$1, 12);
      expect(rv.$2, greaterThan(.5));
      // 小さければすぐ済む
      c.biz.firstWhere((x) => x.ind == b.ind).rev = 0;
      b.rev = m * .01;
      expect(g.reviewOf(c).$1, 1);
      expect(g.reviewOf(c).$2, 0);
    });

    test('のれんは、買った会社が見込みの6割に届かないと年に一度減損し、株が売られる', () {
      final g = _g(7, 36);
      final c = _target(g);
      c.parent = 'player';
      c.stakePlayer = 60;
      c.fin!.gw = 1e10;
      c.fin!.plan = c.profit.abs() * 12 * 10 + 1e9;
      g.q = 12;
      final news = <String>[];
      g.integMonthly((m, [t = '']) => news.add(txIn(m, 'ja')));
      expect(c.fin!.impaired, greaterThan(0));
      expect(c.fin!.gw, lessThan(1e10));
      expect(g.corp.shock, lessThan(1));
      expect(news.single, contains('減損'));
    });

    test('TOB のボタン（tob）は、その場で決まらず買う話として始まる', () {
      final g = _g(7, 36);
      g.cash = 1e15;
      final c = _target(g);
      g.ap = 5;
      expect(txIn(g.tob(c, 50.1), 'ja'), contains('買い付けを申し入れました'));
      expect(g.dealOf(c)!.stage, 'offer');
      expect(c.parent, isNot('player'));
    });
  });

  group('上場', () {
    test('準備は2〜3年（会計士・弁護士で早まる）。監査2期と社内の決まりが済むまで上場できない', () {
      final g = _g(7, 48);
      expect(g.ipoMonths(), inInclusiveRange(24, 36));
      final base = g.ipoMonths();
      final cpa = g.mkPerson(0)..lic = ['cpa'];
      g.staff.add(cpa);
      expect(g.ipoMonths(), lessThan(base));
      g.staff.remove(cpa);
      g.listed = false;
      g.corp.ipo = null;
      g.ap = 10;
      if (!g.canIpoPrep()) {
        // 利益が出ていない遊びでも、準備の流れだけを見る
        g.hist.add(HistEntry(t: 'x', cap: g.cap, rev: g.rev, cash: g.cash, pre: 1e9));
      }
      expect(txIn(g.ipoPrepStart(), 'ja'), contains('上場の準備を始めました'));
      expect(g.canIPO(), isFalse);
      expect(txIn(g.ipo(), 'ja'), contains('まだ整っていません'));
      final p = g.corp.ipo!;
      g.cash = 1e14;
      // 経理・法務に強い人がいなければ、社内の決まりが整うまで予定より延びる（最大で4割ほど）
      final news = <String>[];
      for (var i = 0; i < p.total * 1.4 && !g.ipoReady(); i++) {
        g.ipoMonthly((m, [t = '']) => news.add(txIn(m, 'ja')));
      }
      expect(g.ipoReady(), isTrue);
      expect(news.single, contains('準備が整いました'));
      expect(p.done, inInclusiveRange(p.total, (p.total * 1.4).ceil()));
      expect(p.audit, greaterThanOrEqualTo(24));
      expect(p.ctrl, greaterThanOrEqualTo(.95));
      expect(p.spent, greaterThan(0));
    });

    test('上場すると、集めたお金から手数料を引いた分が入り、株の数が増える。大手の主幹事は小さな会社を引き受けない', () {
      final g = _g(7, 48);
      g.listed = false;
      g.corp.ipo = IpoPrep(start: 0, total: 24, done: 24, audit: 24, ctrl: 1);
      // 年の利益が1.2億円ほどの小さな会社として見る
      g.hist = [for (final h in g.hist) HistEntry(t: h.t, cap: h.cap, rev: h.rev, cash: h.cash, pre: 1e7)];
      g.pre = 1e7;
      expect(g.ipoReady(), isTrue);
      g.ap = 10;
      expect(txIn(g.chooseUw('big'), 'ja'), contains('引き受けてくれません'));
      expect(txIn(g.chooseUw('small'), 'ja'), '主幹事を決めました');
      final money = g.ipoRaise(), fee = g.ipoFee();
      expect(fee, greaterThan(money * .09));
      final cash0 = g.cash, n0 = g.corp.nSh;
      expect(txIn(g.ipo(), 'ja'), contains('上場しました'));
      expect(g.listed, isTrue);
      expect(g.cash, closeTo(cash0 + money - fee, (money + 1) * 1e-6));
      expect(g.corp.nSh, closeTo(n0 * 1.2, 1e-6));
      expect(g.corp.ipo, isNull);
    });

    test('市場の地合いが悪いと、上場で集まるお金が減る', () {
      final g = _g(7, 48);
      g.pre = 1e9;
      g.perMul = 1;
      final a = g.ipoRaise('mid');
      g.perMul = .7;
      expect(g.ipoRaise('mid'), lessThan(a * .8));
    });
  });

  group('株価', () {
    test('毎月の株価を記録し、先月から動いた理由（利益・伸び・金利・地合い）を並べる', () {
      final g = _g(7, 24);
      g.recordPrice();
      final n = g.corp.px.length;
      expect(g.sharePrice(), closeTo(g.cap / g.corp.nSh, 1e-6));
      g.perMul *= 1.3;
      g.calcAll();
      g.recordPrice();
      expect(g.corp.px.length, n + 1);
      expect(g.corp.why.map((w) => txIn(w, 'ja')).join(), contains('地合い'));
    });

    test('決算の上ぶれで買われ、下ぶれで売られる', () {
      final g = _g(7, 24);
      g.listed = true;
      g.corp.expQ = 1;
      for (final h in g.hist.sublist(g.hist.length - 3)) {
        g.hist[g.hist.indexOf(h)] = HistEntry(t: h.t, cap: h.cap, rev: h.rev, cash: h.cash, pre: 1e9);
      }
      final news = <String>[];
      g.corp.noise = 1;
      g.earnings((m, [t = '']) => news.add(txIn(m, 'ja')));
      expect(g.corp.noise, greaterThan(1));
      expect(news.single, contains('上回り'));
      g.corp.expQ = 1e12;
      g.corp.noise = 1;
      g.earnings((m, [t = '']) => news.add(txIn(m, 'ja')));
      expect(g.corp.noise, lessThan(1));
      expect(news.last, contains('下回り'));
    });

    test('物言う株主がいれば、6月の総会で現金を返すよう求められる（断ると株が売られる）', () {
      final g = _g(7, 24);
      g.listed = true;
      g.sh = Shares(own: 50, float: 50);
      g.cash = g.cap;
      expect(g.activist(), isTrue);
      g.events.clear();
      g.agm((_, [_ = '']) {});
      expect(g.events.single.choices.length, 3);
      g.corp.noise = 1;
      g.events.single.choices.last.f();
      expect(g.corp.noise, lessThan(1));
    });
  });

  group('取引先', () {
    test('大口の客が倒れると、売掛金が戻らず売上も減る。客を広げると頼る割合が下がる', () {
      final g = _g(7, 36);
      final b = g.biz.first;
      final c = g.cos.firstWhere((x) => x.alive && x.parent != 'player' && x.loc == null);
      b.rev = math.max(b.rev, 1e8);
      g.corp.clients[b.id] = Client(co: c.id, share: .5, since: g.year);
      final cash0 = g.cash, p0 = b.power;
      final news = <String>[];
      g.clientGone(c, (m, [t = '']) => news.add(txIn(m, 'ja')));
      expect(g.cash, lessThan(cash0));
      expect(b.power, lessThan(p0));
      expect(news.single, contains('売掛金'));
      g.corp.clients[b.id] = Client(co: c.id, share: .5, since: g.year);
      g.cash = 1e15;
      g.ap = 5;
      g.spreadClients(b);
      expect(g.corp.clients[b.id]!.share, closeTo(.35, 1e-9));
    });
  });

  test('会社どうしの状態はセーブに入り、読み直しても同じ', () {
    final g = _g(7, 24);
    g.corp.deals.add(MaDeal(co: g.cos.first.id, stage: 'review', left: 3, block: .2));
    g.corp.ipo = IpoPrep(start: 3, total: 30, done: 4, audit: 4, ctrl: .1, uw: 'small');
    g.corp.clients[g.biz.first.id] = Client(co: 0, share: .4, since: 1990);
    g.recordPrice();
    final j = jsonEncode(g.toJson());
    final h = Game.fromJson(jsonDecode(j) as Map<String, dynamic>, rng: ParkMiller(1));
    expect(jsonEncode(h.toJson()), j);
    expect(h.corp.deals.single.stage, 'review');
    expect(h.corp.ipo!.uw, 'small');
    expect(h.cos.first.fin!.debt, g.cos.first.fin!.debt);
    expect(h.cos.first.biz.first.u, g.cos.first.biz.first.u);
  });

  test('1980年から30年：世界の上位は数十兆円になる（現実の大企業の大きさに近い）', () {
    final g = Game.newGame(SetupConfig(mode: 'world', year: 1980, traits: const ['charm', 'careful'], home: 'jp'), rng: ParkMiller(22));
    final lines = <String>[];
    void top() {
      final l = g.rankList();
      final me = l.indexWhere((r) => r.me) + 1;
      lines.add('${g.year}年: 上位10社 ${l.take(10).map((r) => '${r.me ? 'あなた ' : r.c?.rival != null ? '宿敵 ' : ''}${r.c?.name ?? ''} ${yen(r.cap)}').join(' / ')}・自社 $me位（${yen(g.cap)}）');
    }

    top();
    final top0 = g.rankList().first.cap;
    // 見たいのは世界の大きさなので、自社が倒れても世界はそのまま進める
    for (var m = 0; m < 360; m++) {
      botMonth(g, units: true, borrow: 'none', focus: true);
      if (g.over != null) {
        g.over = null;
        g.mode = 'endless';
      }
      if (g.won != null) {
        g.mode = 'endless';
        g.won = null;
      }
      if (m % 120 == 119) top();
    }
    final l = g.rankList();
    // 1980年の1位は数兆〜十数兆円、30年後の上位10社は数兆〜100兆円の間（古い決まりでは百兆円を超えていた）
    expect(top0, inInclusiveRange(3e12, 2e13));
    expect(l.first.cap, inInclusiveRange(1e13, 1e14));
    expect(l[9].cap, greaterThan(3e12));
    final out = Platform.environment['QUAD_BALANCE'];
    if (out != null) File('$out.top').writeAsStringSync(lines.join('\n'));
    // ignore: avoid_print
    print(lines.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 5)));
}
