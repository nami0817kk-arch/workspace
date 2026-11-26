// 洗い出し2回目の直し（1.1.0+38）。どの項目も、直す前に起きていたことをそのまま再現する形で確かめる。
// QUAD_SHOTS にフォルダを渡すと、844×390 と 1194×834 の日英を PNG に書き出す（画像はコミットしない）
import 'dart:convert';
import 'dart:math' as math;

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

/// いつも 0 を返す乱数（「起きるかどうか」の乱数を必ず起きる側にする）
class _Zero implements math.Random {
  @override
  double nextDouble() => 0;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
}

String? _json;

/// 1990年から3年回し、事業を4つ以上にして、お金と手をたっぷり持たせた会社
Game _game() {
  if (_json == null) {
    final s = Game.newGame(SetupConfig(mode: 'endless', year: 1990, traits: const ['charm', 'careful']), rng: ParkMiller(3737));
    for (var i = 0; i < 36; i++) {
      botMonth(s);
    }
    resolveEvents(s);
    s.events.clear();
    s.cash = s.cap * 10 + 1e12;
    s.ap = 99;
    for (final i in s.liveInds().where((i) => s.licMissing(i.id) == null).toList()..ssort((a, b) => s.capexOf(a).compareTo(s.capexOf(b)))) {
      if (s.biz.length >= 5) break;
      if (!s.biz.any((b) => b.ind == i.id) && s.subOn(i.id) == null) {
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
  _fresh(g);
  g.cash = g.cap * 10 + 1e12;
  return g;
}

/// 社長の時間を戻す（1か月に打てる手の上限に当たらないように）
void _fresh(Game s) {
  s.hUsed = 0;
  s.ap = 99;
}

void _n(String m, [String t = '']) {}

/// 部下を1人足す
Person _staff(Game s) {
  final p = s.mkPerson(.5);
  s.staff.add(p);
  return p;
}

/// セーブして読み直す
Game _reload(Game s) => Game.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>, rng: ParkMiller(7));

/// 出来事の見た目（題・本文・選択肢の名前と中身の文）
String _look(GameEvent e) => [e.title, e.text, for (final c in e.choices) '${c.l}|${c.s}', e.small].join('/');

Company _rival(Game s) => s.cos.firstWhere((c) => c.alive && c.rival != null && c.parent != 'player');

void main() {
  tearDown(() => L.lang = 'ja');

  group('1 持ち株を売っても勝ちの点は増えない', () {
    test('上場して持ち株を5%ずつ19回売っても、ランキングの自社の数・1000兆円までの残り・勝ち負けの数は変わらない', () {
      final s = _game()
        ..listed = true
        ..sh = Shares(own: 99, float: 1)
        ..mode = 'quad';
      s.calcAll();
      final score0 = s.score, wealth0 = s.wealth;
      final rank0 = s.rankList().firstWhere((r) => r.me).cap;
      for (var i = 0; i < 19; i++) {
        s.sellOwn(5);
      }
      expect(s.wealth, greaterThan(wealth0 + s.cap * .5), reason: '売ったお金は財産に入る');
      expect(s.score, closeTo(score0, score0 * 1e-9), reason: '前は売るたびに増え、19回で約1.9倍になった');
      expect(s.rankList().firstWhere((r) => r.me).cap, closeTo(rank0, rank0 * 1e-9));
      expect(s.rankList().firstWhere((r) => r.me).cap, s.score, reason: 'ランキングの自社の行は勝ち負けの数と同じ');
      expect(msgKey(s.goalText()), '1000兆円まで：あと{0}');
    });

    test('会社を売ったお金（前の会社の分）は、勝ち負けの数に入る', () {
      final s = _game();
      final buyer = s.cos.firstWhere((c) => c.alive && c.parent != 'player' && c.rival == null)..cap = s.cap * 5;
      s.sellCompany(buyer, false, newName: 'うしお商会');
      expect(s.soldOut, 0);
      expect(s.score, closeTo(s.cap + s.wealth, 1));
    });
  });

  group('2 土地の話と土地を売る', () {
    test('銀行の管理中・格付けDの会社には、好景気の土地の話は来ない', () {
      final s = _game()
        ..rng = _Zero()
        ..econ = 1.2
        ..bankCtl = 24;
      s.events.clear();
      s.rollEvents6(_n);
      expect(s.events.where((e) => e.k == 'land'), isEmpty, reason: '前は銀行の管理中でも「お金はいくらでも貸します」と来て、借りられた');
      s.bankCtl = 0;
      s.rollEvents6(_n);
      final ev = s.events.firstWhere((e) => e.k == 'land');
      final debt0 = s.debt;
      // 選ぶまでに銀行の管理に入ったら、話は流れる
      s.bankCtl = 12;
      ev.choices.first.f();
      expect(s.debt, debt0);
    });

    test('土地を売りに出すと、3か月ほどで手数料3%を引いて売れる。急ぐなら15%引きですぐ売れる', () {
      final s = _game()..land = 1e9;
      final cash0 = s.cash;
      s.sellLand();
      expect(s.land, 1e9, reason: '前はその場で全額が入った');
      expect(s.cash, cash0);
      expect(s.landSell, s.turn + 3);
      // セーブしても売りに出したまま
      final r = _reload(s);
      expect(r.landSell, s.turn + 3);
      s.turn += 3;
      final v = s.land;
      s.landSellMonthly(_n);
      expect(s.land, 0);
      expect(s.cash - cash0, closeTo(v * .97, 1));
      final q = _game()..land = 1e9;
      final c0 = q.cash;
      q.sellLandNow();
      expect(q.cash - c0, closeTo(.85e9, 1));
    });

    test('土地は好景気でも年20%を超えては上がらない（前は毎月2%＝年27%）', () {
      final s = _game();
      for (final y in [1985, 1988, 1990, 1993, 2005]) {
        s.year = y;
        final k = math.pow(s.landMonthly(), 12);
        expect(k, inInclusiveRange(.85, 1.2001), reason: '$y年');
      }
    });
  });

  group('3 投資家の上場の約束', () {
    test('お金が足りないと「買い戻す」は出ない。持ち株30%未満なら「あと1年」も出ない。部下がいなければ「降りる」も出ない', () {
      final s = _game()
        ..sh = Shares(own: 25, vc: 40, float: 0, ally: 35)
        ..vcDeadline = 1
        ..cash = 0
        ..staff.clear();
      final e = s.evVc();
      final ls = e.choices.map((c) => msgKey(c.l)).toList();
      expect(ls, isNot(contains('株を買い戻す')), reason: '前は押しても何も起きず、毎月同じ出来事が来た');
      expect(ls, isNot(contains('あと1年待ってもらう')), reason: '前は持ち株30%未満で押すと株が増え、投資家の株がマイナスになりえた');
      expect(ls, isNot(contains('社長の座を降りる')), reason: '前は部下0人でも出て、何も起きなかった');
      e.choices.last.f();
      expect(s.sh.vc, 0);
      expect(s.vcDeadline, 0);
      expect(s.sh.own, 25);
    });

    test('「あと1年」は本当に期限を延ばし、株を渡す。2回目は無い', () {
      final s = _game()
        ..sh = Shares(own: 70, vc: 30)
        ..vcDeadline = 1
        ..cash = 0;
      s.turn = 10;
      s.evVc().choices.firstWhere((c) => msgKey(c.l) == 'あと1年待ってもらう').f();
      expect(s.vcDeadline, 22);
      expect(s.sh.own, 65);
      expect(s.sh.vc, 35);
      expect(s.evVc().choices.map((c) => msgKey(c.l)), isNot(contains('あと1年待ってもらう')));
      // 2回目はセーブを読み直しても無い
      expect(_reload(s).evVc().choices.map((c) => msgKey(c.l)), isNot(contains('あと1年待ってもらう')));
    });
  });

  group('4 選ぶ出来事はセーブに入る', () {
    test('30年回して、出来事が出るたびにセーブを読み直すと、同じ出来事が同じ選択肢で戻る', () {
      final s = Game.newGame(SetupConfig(mode: 'endless', year: 1980, traits: const ['charm', 'careful']), rng: ParkMiller(77));
      final kinds = <String>{};
      var lost = 0, seen = 0;
      for (var m = 0; m < 360 && s.over == null; m++) {
        botMonth(s, units: true, borrow: 'some');
        if (s.events.isEmpty) continue;
        final r = _reload(s);
        for (final e in s.events) {
          seen++;
          if (e.k == null) {
            lost++;
            continue;
          }
          kinds.add(e.k!);
        }
        expect(r.events.map(_look).toList(), s.events.map(_look).toList(), reason: '${s.year}年${s.q}月');
      }
      expect(lost, 0, reason: '保存できない出来事がある');
      expect(seen, greaterThan(20));
      expect(kinds.length, greaterThan(6), reason: '$kinds');
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('特許の訴えを開き直しても消えない。読み直した出来事を選ぶと効く', () {
      final s = _game();
      final b = s.biz.first;
      s.events.add(s.evSued(b));
      s.events.add(s.evProp(Proposal(k: 'ad', w: 1, cost: 0, l: M('広告を打ちたい'), d: M('客が増えます'))..by = _staff(s).id));
      final r = _reload(s);
      expect(r.events.map((e) => msgKey(e.title)), contains('特許で訴えられた'), reason: '前は開き直すと消え、罰なしで飛ばせた');
      final cash0 = r.cash;
      r.events.firstWhere((e) => e.k == 'sued').choices.first.f();
      expect(r.cash, lessThan(cash0));
    });

    test('古いセーブ（出来事の欄が無い）は空で読める', () {
      final j = jsonDecode(jsonEncode(_game().toJson())) as Map<String, dynamic>..remove('events');
      expect(Game.fromJson(j, rng: ParkMiller(1)).events, isEmpty);
    });
  });

  group('5 倒産から出直すと、前の会社のものは片付く', () {
    test('上場の約束・持ち株会社・粉飾・不祥事・上場の準備・買収の話・提携・取引先の縛り・訴え・売掛・土地・償却・特許・貸したお金', () {
      final s = _game();
      final c = _rival(s);
      s
        ..vcDeadline = s.turn + 3
        ..holding = true
        ..cooked = 6
        ..scandal = 10
        ..ar = 1e8
        ..land = 1e9
        ..wealth = 5e8
        ..suits.add(Suit(at: s.turn + 5, co: c.id, amt: 1e8))
        ..deals.add(Deal(co: c.id, type: 'sales', since: s.year))
        ..tie = Tie(co: c.id, inds: const [], cats: const [])
        ..lent.add(Lend(co: c.id, amt: 1e8, rate: .05, due: s.turn + 10));
      s.corp.ipo = IpoPrep(start: s.turn, total: 30);
      s.life.patents.add(Patent(s.biz.first.ind, s.turn + 100, lic: true));
      s.capSpend(1e9, 10, s.biz.first);
      s.rebirth();
      expect(s.vcDeadline, 0);
      expect(s.holding, isFalse);
      expect(s.cooked, 0);
      expect(s.scandal, 0);
      expect(s.corp.ipo, isNull);
      expect(s.deals, isEmpty);
      expect(s.tie, isNull);
      expect(s.suits, isEmpty);
      expect(s.ar, 0);
      expect(s.land, 0);
      expect(s.lent, isEmpty);
      expect(s.life.deps, isEmpty);
      expect(s.life.patents, isEmpty);
      expect(s.wealth, 5e8, reason: '社長個人の財産は残る');
    });
  });

  group('6 始める国と年', () {
    test('2000年でロシアを選んでから1980年にすると、日本に戻る。その年に無い国では始めない', () async {
      SharedPreferences.setMockInitialValues({});
      final ctl = GameController(prefs: await SharedPreferences.getInstance(), newRandom: () => ParkMiller(5), lang: 'ja');
      ctl.setYear(2000);
      ctl.setHome('ru');
      expect(ctl.setup.home, 'ru');
      ctl.setYear(1980);
      expect(ctl.setup.home, 'jp', reason: '前は 1980年でもロシアのまま始められた');
      final g = Game.newGame(SetupConfig(year: 1980, home: 'ru'), rng: ParkMiller(1));
      expect(g.home, 'jp');
    });
  });

  group('7 株の数', () {
    test('自社株買いで株の数が減り、株価は下がらない。新しい株を出すと株の数が増える。割合の合計は100%', () {
      final s = _game()
        ..listed = true
        ..sh = Shares(own: 60, float: 40);
      s.calcAll();
      final n0 = s.corp.nSh, px0 = s.sharePrice();
      s.doBuyback(10);
      s.calcAll();
      expect(s.corp.nSh, closeTo(n0 * .9, 1e-6), reason: '前は株の数が変わらず、自社株買いで株価が下がった');
      expect(s.sharePrice(), greaterThan(px0 * .98));
      final n1 = s.corp.nSh;
      s.lastOffer = null;
      _fresh(s);
      s.doDilute();
      expect(s.corp.nSh, closeTo(n1 * 115 / 100, 1e-6), reason: '前は新株で株の数が変わらなかった');
      final t = s.sh.own + s.sh.vc + s.sh.float + s.sh.ally + s.sh.pt + s.sh.rivSum;
      expect(t, closeTo(100, 1e-9));
      final u = _game()..sh = Shares(own: 80, pt: 20);
      final m0 = u.corp.nSh;
      u.vcRaise();
      expect(u.corp.nSh, closeTo(m0 / .9, 1e-6));
      expect(u.sh.own + u.sh.pt + u.sh.vc, closeTo(100, 1e-9));
    });
  });

  group('8 手放した事業の特許と償却', () {
    test('事業を売ると、その業種の特許の使用料と、その事業の設備の償却が外れる', () {
      final s = _game();
      final b = s.biz.first;
      s.life.patents.add(Patent(b.ind, s.turn + 240, lic: true));
      s.capSpend(1e9, 10, b);
      final dep0 = s.depMonth();
      s.sellBiz(b);
      expect(s.life.patents.where((p) => p.ind == b.ind), isEmpty, reason: '前は売ったあとも20年のあいだ使用料が入った');
      expect(s.depMonth(), lessThan(dep0 - 1e9 / 120 + 1), reason: '前は償却も決算書の設備も残った');
      expect(s.life.deps.where((d) => d.b == b.id), isEmpty);
    });
  });

  group('9 危機の会議の増資', () {
    test('増資してから1年のあいだは、会議にも「新しい株を出す」「集める」の案が出ない。出来事から薄めるのも同じ', () {
      final s = _game()
        ..listed = true
        ..sh = Shares(own: 60, float: 40);
      final c = _rival(s);
      s.sh.riv[c.id] = 0;
      s.publicOffer();
      expect(s.crisisOptions('takeover', foe: c).containsKey('dil'), isFalse, reason: '前は時間も年の上限も通らずに13.5%が入った');
      expect(s.crisisOptions('cash').containsKey('equity'), isFalse);
      final cash0 = s.cash;
      expect(msgKey(s.doDilute()), '新しい株を出すのは1年に1回までです');
      expect(s.cash, cash0);
    });
  });

  group('10 後継ぎの年', () {
    test('18歳の子を後継ぎに決めておけば、急死したときに継ぐ。継げなかったときは「決めていた後継ぎが継げず」と書く', () {
      final s = _game();
      final k = s.mkPerson(0)
        ..age = 18
        ..kid = true;
      s.kids.add(k);
      s.choosePresSucc(k.id);
      _staff(s).age = 40;
      final news = <String>[];
      s.presDies((m, [t = '']) => news.add(m));
      expect(s.pres.name, k.name, reason: '前は20歳からしか継げず、別の部下が社長になった');
      final t = _game();
      _staff(t).age = 40;
      t.succ = 99999;
      final n2 = <String>[];
      t.presDies((m, [x = '']) => n2.add(m));
      expect(msgKey(n2.first), '{0}が急死。決めていた後継ぎが継げず、{1}が急きょ社長になりました');
    });
  });

  group('11 月に1回までの手', () {
    test('寄付・取材は月に1回。同じ人の話を聞くのも月に1回。効き目は高くなるほど小さい', () {
      final s = _game();
      s.life.fame = 0;
      s.donate();
      final f1 = s.life.fame;
      _fresh(s);
      expect(msgKey(s.donate()), '寄付は月に1回までです。来月また寄付できます');
      expect(s.life.fame, f1, reason: '前は同じ月に何度でも寄付できて、1か月で100まで上がった');
      s.giveTalk();
      _fresh(s);
      expect(msgKey(s.giveTalk()), '取材・講演は月に1回までです。来月また受けられます');
      s.life.fame = 90;
      s.turn++;
      s.donate();
      expect(s.life.fame, lessThan(91), reason: '90からは1も上がらない');
      final p = _staff(s)..loy = 40;
      s.talkTo(p);
      final l1 = p.loy;
      _fresh(s);
      expect(msgKey(s.talkTo(p)), '{0}の話は今月もう聞きました。来月また聞けます');
      expect(p.loy, l1);
    });
  });

  group('12 払うだけで何も起きない手', () {
    test('広告を打っている最中に打ち直せない。新しい設備は耐用年数の半分を過ぎるまで新しくできない', () {
      final s = _game();
      final b = s.biz.first..ad = 4;
      final cash0 = s.cash;
      expect(msgKey(s.adv(b)), '広告を打っている最中です（あと{0}か月）');
      expect(b.ad, 4);
      s.life.eqAge[b.id] = 0;
      expect(msgKey(s.renewEquip(b)), '設備はまだ新しいです（古さ{0}年・耐用{1}年の半分を過ぎてから）');
      expect(s.cash, cash0, reason: '前は古さ0年でも35%を払えた');
    });
  });

  group('13 遅く始めたときのITと国ごとの社会の流れ', () {
    test('2000年に始めると、当たり前のIT（POS・社内のシステム）は入っていて、遅れの扱いにならない', () {
      final g = Game.newGame(SetupConfig(year: 2000, traits: const ['charm', 'careful']), rng: ParkMiller(3));
      expect(g.life.it, 2, reason: '前は0から始まり、2段遅れで毎月の売上から引かれた');
      final h = Game.newGame(SetupConfig(year: 2025, traits: const ['charm', 'careful']), rng: ParkMiller(3));
      expect(h.life.it, 4);
      expect(Game.newGame(SetupConfig(year: 1980), rng: ParkMiller(3)).life.it, 0);
    });

    test('女性の社会進出は米国では日本より早く、インドでは遅い', () {
      final food = IND.firstWhere((i) => i.cat == 'food');
      expect(socialF(food, 1980, 'us'), greaterThan(1), reason: '前はどの国も1986年から');
      expect(socialF(food, 1980, 'jp'), 1);
      expect(socialF(food, 2000, 'in'), 1);
      expect(adMediaOf(2000, 'in'), isNot(adMediaOf(2000, 'jp')));
    });
  });

  group('15・16 社長の時間とゲームオーバー', () {
    test('人たらしの社長が事業を売るとき、使う時間（2倍）で足りるかを見る', () {
      final s = _game();
      expect(s.hasT('charm'), isTrue);
      s.hUsed = s.hUsed + s.hLeft() - s.hrs('sell') * 1.5;
      final n = s.biz.length;
      expect(msgKey(s.sellBiz(s.biz.first)), '今月の社長の時間が足りません（{0}時間かかります・残り{1}時間）', reason: '前は1回分だけ見て、上限を超えて使えた');
      expect(s.biz.length, n);
    });

    test('ゲームオーバーのあとは手を打てず、2回目からは保存もしない', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final ctl = GameController(prefs: prefs, newRandom: () => ParkMiller(5), lang: 'ja');
      final g = _game()..over = M('資金が尽きて、会社は倒産しました');
      ctl.game = g;
      ctl.save();
      final saved = prefs.getString(slotKey(ctl.slot));
      final n = g.biz.length;
      ctl.act(() => g.sellBiz(g.biz.first));
      expect(g.biz.length, n, reason: '前は「盤面を見る」から事業を売れた');
      g.biz.removeLast();
      ctl.save();
      expect(prefs.getString(slotKey(ctl.slot)), saved, reason: '終わったあとに動いたものは保存しない');
    });
  });

  group('17 宿敵に貸したお金', () {
    test('2年後に利息を付けて返ってくる。担保の株も返す。相手が倒れたら戻らない', () {
      final s = _game();
      final c = _rival(s)..cash = 1e15;
      s.lent.add(Lend(co: c.id, amt: 1e8, rate: .05, due: s.turn, stake: 5));
      c.stakePlayer = 5;
      final cash0 = s.cash;
      s.lentMonthly(_n);
      expect(s.cash - cash0, closeTo(1.1e8, 1));
      expect(c.stakePlayer, 0);
      expect(s.lent, isEmpty);
      final d = _rival(s);
      s.lent.add(Lend(co: d.id, amt: 1e8, rate: .05, due: s.turn + 24));
      d.alive = false;
      final c1 = s.cash;
      s.lentMonthly(_n);
      expect(s.lent, isEmpty);
      expect(s.cash, c1);
    });
  });

  group('19 金額の桁の境目', () {
    test('9,999.5万円は1億円、9,999.5億円は1兆円。英語も同じ', () {
      L.lang = 'ja';
      expect(yen(99995000), '1億円', reason: '前は「10,000万円」');
      expect(yen(9999.6e8), '1兆円');
      expect(yen(9999.6e12), '1京円');
      expect(yen(9999.6), '1万円');
      expect(yen(99994000), '9,999万円');
      expect(yenEn(999600), '¥1M');
      expect(yenEn(999.6e9), '¥1T');
      expect(yenEn(999.6), '¥1K');
      expect(yenEn(999400), '¥999K');
    });
  });

  group('20 宿敵の出資の株', () {
    test('持ち株が10%を切っていれば話は来ない。渡す株がマイナスにならない', () {
      final s = _game()..sh = Shares(own: 8, float: 92);
      expect(s.rivFundStake(), 0, reason: '前は 20と(持ち株−10)の小さい方で、マイナスになった');
      final t = _game()..sh = Shares(own: 15, float: 85);
      final c = _rival(t);
      t.evRivFund(c, 1e9).choices.first.f();
      expect(t.sh.riv[c.id], closeTo(5, 1e-9));
      expect(t.sh.own, greaterThan(0));
    });
  });

  group('英訳', () {
    test('足した文に英語がある（用語の説明は110字以内）', () {
      const keys = [
        '{0}が、貸したお金を利息を付けて返してくれました（{1}）',
        '{0}が急死。決めていた後継ぎが継げず、{1}が急きょ社長になりました',
        '{0}の話は今月もう聞きました。来月また聞けます',
        '{0}は貸したお金をまだ返せず、1年待ってほしいと言っています',
        '{0}は貸したお金を返せませんでした。担保に預かった株はそのまま持ちます',
        '{0}を貸す（2年後に年{1}%の利息を付けて返ってくる。相手が倒れたら戻らない）。担保に株を5%預かり、大きな恩を売る',
        'お金が足りず、買い戻せませんでした',
        'お金を貸していた{0}がなくなり、貸した{1}は戻りませんでした',
        'ゲームは終わりました。盤面は見るだけで、手は打てません',
        '代わりの人がいませんでした',
        '取引のある銀行が「土地を買えば必ず上がります。お金はお貸しします」と言っています。',
        '取材・講演は月に1回までです。来月また受けられます',
        '土地は売りに出しています（あと{0}か月）',
        '土地を値引きして{0}ですぐ売る',
        '土地を値引きして、すぐに{0}で売りました',
        '土地を売りに出しました。買い手が見つかるまで{0}か月ほどかかります（仲介の手数料{1}%）',
        '売りに出していた土地が、{0}で売れました（仲介の手数料{1}を引いた額）',
        '寄付は月に1回までです。来月また寄付できます',
        '広告を打っている最中です（あと{0}か月）',
        '投資家から株を{0}買い取られた',
        '投資家が選んだ部下（{0}）が社長になる。期限は2年延びる',
        '投資家に株を{0}渡して、期限を1年延ばす（一度だけ）',
        '新しい株を出すのは1年に1回までです',
        '渡せる株が無く、待ってもらえませんでした',
        '約束を果たせず、投資家は株{0}を{1}に売りました',
        '約束を果たせず、投資家は株{0}を取引先の会社に売りました',
        '約束を果たせないと伝える',
        '投資家は株{0}を{1}に売る（宿敵が株を持つ）',
        '投資家は株{0}を取引先の会社に売る',
        '設備はまだ新しいです（古さ{0}年・耐用{1}年の半分を過ぎてから）',
        '銀行の態度が変わり、話は流れました',
        '値下げ合戦中（あと{0}か月）',
        '勝ち負けの数（時価総額＋財産）',
        '勝ち負けは「今の会社の時価総額＋あなたの財産」で測ります。持ち株を売ったお金は時価総額に入っているので、二重には数えません。今の財産 {0}・勝ち負けの数 {1}',
        '土地をすぐ売る（15%引き {0}）',
        '土地を売りに出しています（今の値 {0}・あと{1}か月ほどで売れます）',
        '土地を売りに出す（今の値 {0}・3か月ほど・手数料3%）',
        '広告中（あと{0}か月）',
        '投資家から集める（{0}・全員の割合−10%）',
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
        testWidgets('始める画面の国・広告中・土地を売る・開き直しても残る出来事・投資家の約束・終わりのまとめ ${size.width.round()}×${size.height.round()}（$lang）', (tester) async {
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

  // 始める画面：2000年でロシアを選び、1980年に戻すと日本になる
  final st = ctl.setup;
  ctl.setYear(2000);
  ctl.setHome('ru');
  ctl.render();
  await settle('ru');
  await tester.tap(find.text(tr('1980年')));
  await settle('1980');
  expect(st.home, 'jp');
  final jp = find.text(CTRY.first.n);
  await tester.scrollUntilVisible(jp, 120, scrollable: find.byType(Scrollable).first);
  await tester.drag(find.byType(Scrollable).first, const Offset(0, 80));
  await settle('jp');
  await shot(tester, key, 'a2_setup_home_$n', pixelRatio: 1.5);

  // 育った盤面：広告中の事業の「ほかの手」
  final g = _game();
  final b = g.biz.first..ad = 4;
  g.land = 3e9;
  ctl.game = g;
  ctl.save();
  ctl.setTab('biz');
  ctl.openBizCard(b.id);
  ctl.toggleMore(b.id);
  await settle('biz-more');
  final adOn = find.byKey(ValueKey('ad-on-${b.id}'));
  await tester.scrollUntilVisible(adOn, 150, scrollable: find.byType(Scrollable).first, maxScrolls: 100);
  expect(adOn, findsOneWidget);
  await settle('ad-on');
  await shot(tester, key, 'a2_ad_on_$n', pixelRatio: 1.5);

  // お金の画面：土地を売る2つのボタン
  ctl.setTab('money');
  ctl.setMoney('bank');
  await settle('money');
  final land = find.byKey(const ValueKey('land-sell'));
  await tester.scrollUntilVisible(land, 150, scrollable: find.byType(Scrollable).first, maxScrolls: 100);
  expect(land, findsOneWidget);
  await settle('land');
  await shot(tester, key, 'a2_land_$n', pixelRatio: 1.5);
  await tester.tap(land);
  await settle('land-sold');
  ctl.closeSheet();
  await settle('land-closed');
  expect(find.textContaining(tr('土地を売りに出しています（今の値 {0}・あと{1}か月ほどで売れます）', [yen(g.land), 3]).substring(0, 6)), findsWidgets);
  await shot(tester, key, 'a2_land_selling_$n', pixelRatio: 1.5);

  // 特許の訴え：見ている途中で閉じて、開き直しても残っている
  g.events.add(g.evSued(g.biz[1]));
  ctl.save();
  nextEvent(ctl);
  await settle('sued');
  ctl.closeSheet();
  ctl.save();
  expect(ctl.load(ctl.slot), isTrue);
  ctl.render();
  pendingFirst(ctl);
  await settle('reload');
  expect(find.text(tr('特許で訴えられた')), findsOneWidget, reason: '前は開き直すと消えた');
  await shot(tester, key, 'a2_event_reload_$n', pixelRatio: 1.5);
  ctl.closeSheet();
  await settle('sued-closed');

  // 投資家の約束（お金が足りず、部下もいない）
  final h = ctl.game!
    ..events.clear()
    ..sh = Shares(own: 25, vc: 40, ally: 35)
    ..listed = false
    ..vcDeadline = 1
    ..cash = 0;
  h.events.add(h.evVc());
  nextEvent(ctl);
  await settle('vc');
  expect(find.text(tr('約束を果たせないと伝える')), findsOneWidget);
  await shot(tester, key, 'a2_vc_$n', pixelRatio: 1.5);
  ctl.closeSheet();
  await settle('vc-closed');

  // 終わりのまとめ（勝ち負けの数）
  h.events.clear();
  h.over = M('資金が尽きて、会社は倒産しました');
  ctl.render();
  await settle('end');
  expect(find.text(tr('勝ち負けの数（時価総額＋財産）')), findsOneWidget);
  await shot(tester, key, 'a2_end_$n', pixelRatio: 1.5);
}
