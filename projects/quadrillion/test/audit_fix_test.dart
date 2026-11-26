// 洗い出し1回目の直し（1.1.0+37）:
// 遊びが壊れるもの（1〜7）・抜け道（8〜12）・社長と自社の名前（15）・軽いもの（仕掛かりの返し方・海外に出す一覧）。
// どの項目も、直す前に起きていたことをそのまま再現する形で確かめる。
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

/// 宿敵でも子会社でもない、国内の CPU の会社
Iterable<Company> _cpu(Game s) => s.cos.where((c) => c.alive && c.parent != 'player' && c.rival == null && c.loc == null);

/// 上場して、宿敵に株を持たせた会社
Company _rivalHolds(Game s, double x) {
  s.listed = true;
  s.sh = Shares(own: 100 - x - 20, float: 20);
  final foe = s.cos.firstWhere((c) => c.alive && c.rival != null && c.parent != 'player');
  s.sh.riv[foe.id] = x;
  return foe;
}

Person _staff(Game s) {
  final p = s.mkPerson(.5);
  s.staff.add(p);
  return p;
}

void main() {
  tearDown(() => L.lang = 'ja');

  group('1 宿敵の持つ自社株', () {
    test('宿敵を子会社にすると、宿敵が持っていたあなたの株は市場で売られる', () {
      final s = _game();
      final foe = _rivalHolds(s, 30);
      final cash0 = foe.cash;
      foe.fam = math.min(foe.fam, 40);
      foe.stakePlayer = 51;
      s.afterStake(foe);
      expect(foe.parent, 'player');
      expect(s.sh.riv.containsKey(foe.id), isFalse, reason: '前は子会社にしたあとも30%が残った');
      expect(s.sh.float, closeTo(50, 1e-9));
      expect(foe.cash, greaterThan(cash0), reason: '売った代金は子会社に入る');
      expect(s.canMerge(foe..stakePlayer = 70), isTrue, reason: '33.4%以上が残ると合併できなかった');
      // 自社株買いで、残った宿敵の割合が膨らんで過半を超えることもない
      for (var i = 0; i < 6; i++) {
        s.doBuyback(5);
      }
      expect(s.sh.rivMax, 0);
    });

    test('買収の手続き（closeDeal）で子会社にしたときも同じ', () {
      final s = _game();
      final foe = _rivalHolds(s, 34);
      s.closeDeal(foe, MaDeal(co: foe.id, stage: 'close', left: 0, target: 51));
      expect(foe.parent, 'player');
      expect(s.sh.riv.containsKey(foe.id), isFalse);
    });

    test('宿敵が倒れると、持っていた株は市場に出る', () {
      final s = _game();
      final foe = _rivalHolds(s, 40);
      s.coFail(foe, _n);
      expect(foe.alive, isFalse);
      expect(s.sh.riv.containsKey(foe.id), isFalse, reason: '前は倒れた宿敵の40%が残り、合併を止め続けた');
      expect(s.sh.float, closeTo(60, 1e-9));
    });
  });

  group('2 CPU どうしの買収と自分の持ち分', () {
    test('少し持つ会社が買われると、買収の値段で買い取られる。3分の1以上持つ会社は買われない', () {
      final s = _game()..rng = _Zero();
      final cpu = _cpu(s).toList();
      final b = cpu.firstWhere((c) => c.tier == 0);
      final t = cpu.firstWhere((c) => c != b);
      final t2 = cpu.firstWhere((c) => c != b && c != t);
      for (final c in s.cos) {
        s.finOf(c).distress = c == b ? 0 : 1;
        for (final x in c.biz) {
          x.rev = 0;
        }
      }
      b.cap = 1e16;
      b.cash = 1e16;
      b.rev = 0;
      s.finOf(t).distress = 5;
      s.finOf(t2).distress = 6;
      t.stakePlayer = 10;
      t2.stakePlayer = 40;
      final price = t.cap * 1.3;
      final cash0 = s.cash;
      s.cpuDeals(_n);
      expect(t2.alive, isTrue, reason: '3分の1以上持つ会社は、合併を止められるので買われない');
      expect(t.alive, isFalse);
      expect(s.cash - cash0, closeTo(price * .1, price * 1e-9), reason: '前は消えて何も入らなかった');
      expect(t.stakePlayer, 0);
    });
  });

  group('3 相棒・後継ぎの分社', () {
    test('相棒が責任者の事業は分社できない。後継ぎを社長にしたら後継ぎは決め直す', () {
      final s = _game();
      final b = s.biz[0];
      final p = _staff(s)
        ..partner = true
        ..stake = 10;
      s.sh.own -= 10;
      s.sh.pt = 10;
      b.mgr = p.id;
      expect(msgKey(s.spinOff(b)), '相棒は本社に残します。ほかの部下を責任者に置いてから分社してください');
      expect(s.subs().where((c) => c.loc == null), isEmpty);
      expect(s.staff, contains(p));
      final q = _staff(s);
      b.mgr = q.id;
      s.succ = q.id;
      s.spinOff(b);
      expect(s.succ, isNull, reason: '前は子会社の社長になった人が後継ぎのまま残った');
      expect(s.sh.pt, 10);
    });
  });

  group('4 独立させた元部下', () {
    test('渡して独立させた人は社外の一覧に入らず、呼び戻せない', () {
      final s = _game();
      final b = s.biz[0];
      final p = _staff(s);
      expect(p.real, isTrue);
      b.mgr = p.id;
      s.releaseBiz(b);
      expect(s.alumni, isNot(contains(p)), reason: '前は社外に入り、よその会社の社長のまま呼び戻せた');
      // 前のセーブで社外に残っている人も、出さず・呼び戻せない
      s.alumni.insert(0, p);
      expect(s.alumniShown(), isNot(contains(p)));
      _fresh(s);
      expect(msgKey(s.rehire(p)), '{0}は今、よその会社の社長をしています');
      expect(s.staff, isNot(contains(p)));
    });
  });

  group('5 会社を割った新会社', () {
    test('過半を持つなら子会社になる', () {
      final s = _game();
      s.listed = true;
      s.sh = Shares(own: 70, float: 30);
      final cats = <String>{for (final b in s.biz) indm[b.ind]!.cat};
      expect(cats.length, greaterThan(1));
      final cat = cats.first;
      final n0 = s.cos.length;
      s.splitCompany(cat);
      final c = s.cos.sublist(n0).single;
      expect(s.pctOf(c), 70);
      expect(c.parent, 'player', reason: '前は外の会社のままで、値下げ合戦や CPU の買収の的になった');
    });
  });

  group('6 子会社・合併の相手への、外の会社の頃の参照', () {
    test('値下げ合戦・提携・取引先の出資の縛りは、子会社にすると片付く', () {
      final s = _game();
      final c = _cpu(s).first;
      final b = s.biz[0];
      b.attack = 9;
      b.target = c.id;
      s.deals.add(Deal(co: c.id, type: 'codev', since: s.year));
      s.tie = Tie(co: c.id, inds: const [], cats: const []);
      c.fam = math.min(c.fam, 40);
      c.stakePlayer = 51;
      s.afterStake(c);
      expect(b.attack, 0, reason: '前は子会社に値下げ合戦を続けた');
      expect(s.deals.where((d) => d.co == c.id), isEmpty);
      expect(s.tie, isNull);
    });

    test('大口の客を合併すると、その客の縛りは消える', () {
      final s = _game();
      final c = _cpu(s).first;
      final b = s.biz[0];
      s.corp.clients[b.id] = Client(co: c.id, share: .3, since: s.year);
      c.parent = 'player';
      c.stakePlayer = 70;
      expect(msgKey(s.merge(c)), startsWith('{0}を合併しました'));
      expect(s.corp.clients.values.where((x) => x.co == c.id), isEmpty, reason: '前は消えた会社が大口の客のまま残った');
    });
  });

  group('7 取引先からの出資の話', () {
    test('自分と同じ業種の会社からは来ない', () {
      final s = _game();
      s.tie = null;
      s.sh = Shares();
      final mine = <String>{for (final b in s.biz) b.ind};
      // 同じ業種の大きな会社を先頭に置く（前はここから話が来て、受けると翌月に取引を切られた）
      final same = _cpu(s).firstWhere((c) => c.tier == 0);
      same.biz.add(CoBiz(ind: s.biz[0].ind, power: 1));
      same.cap = s.cap * 5;
      s.cos.remove(same);
      s.cos.insert(0, same);
      final other = _cpu(s).firstWhere((c) => c != same && c.tier == 0);
      other.biz.removeWhere((x) => mine.contains(x.ind));
      other.cap = s.cap * 5;
      s.rng = _Zero();
      s.moneyChecks(_n);
      final ev = s.events.firstWhere((e) => msgKey(e.title) == '取引先からの出資の話');
      ev.choices.first.f();
      final c = s.coById(s.tie!.co)!;
      expect(c, isNot(same));
      expect(c.biz.any((x) => mine.contains(x.ind)), isFalse);
    });
  });

  group('8 責任者の兼任と海外赴任', () {
    test('異動で前の事業の責任者から外れる。赴任を断る人は海外だけの事業に置けない', () {
      final s = _game();
      final a = s.biz[0], b = s.biz[1], c = s.biz[2];
      final p = _staff(s);
      s.setManager(a, p.id);
      s.setManager(b, p.id);
      expect(a.mgr, isNull, reason: '前は1人が全事業の責任者になれた');
      expect(b.mgr, p.id);
      final q = _staff(s)..care = true;
      expect(s.refusesPosting(q), isTrue);
      c.ctry = ['us'];
      c.mgr = null;
      s.setManager(c, q.id);
      expect(c.mgr, isNull);
      expect(s.managerPlan().where((x) => x.$1 == c && x.$2 == q), isEmpty);
    });
  });

  group('9 市場で買う・競り勝つ', () {
    test('市場で買えるのは3分の1まで', () {
      final s = _game();
      final c = _cpu(s).first;
      c.fam = 10;
      c.stakePlayer = 30;
      _fresh(s);
      s.buyStake(c, 5);
      expect(c.stakePlayer, closeTo(100 / 3, 1e-9));
      _fresh(s);
      expect(msgKey(s.buyStake(c, 5)), '市場で買えるのは株の3分の1までです。それより上は「買う話を始める」（TOB）で買います');
      expect(c.stakePlayer, closeTo(100 / 3, 1e-9), reason: '前は5%ずつ買って、審査なしで50%を超えた');
      expect(c.parent, isNot('player'));
      // 子会社になったあとは、合併に向けて市場で買い増せる
      c.parent = 'player';
      c.stakePlayer = 51;
      _fresh(s);
      s.buyStake(c, 5);
      expect(c.stakePlayer, 56);
    });

    for (final big in [true, false]) {
      test('宿敵との取り合いに競り勝つ（シェアが${big ? '大きいと当局の審査に入る' : '小さいとその場で子会社'}）', () {
        final s = _game();
        final foe = s.cos.firstWhere((c) => c.alive && c.rival != null && c.parent != 'player');
        final ev = s.rivalScene(foe, 'bid');
        expect(ev, isNotNull);
        final t = s.bidTarget(foe)!;
        final mine = s.biz[0];
        if (big) {
          t.biz.add(CoBiz(ind: mine.ind, power: 1));
          mine.rev = s.mkt(indm[mine.ind]!) / 3 * .7;
        }
        ev!.choices.first.f();
        if (big) {
          expect(t.parent, isNot('player'), reason: '前は審査なしで51%になった');
          final d = s.dealOf(t)!;
          expect(d.stage, 'review');
          expect(d.block, greaterThan(0));
        } else {
          expect(t.parent, 'player');
          expect(s.pctOf(t), 51);
        }
      });
    }
  });

  group('10 売ったときの約束・資格・銀行の口出し', () {
    test('業態転換・部下の提案・合併でも、始めるときと同じ決まりを通す', () {
      final s = _game();
      final b = s.biz.firstWhere((b) => s.pivotTargets(b).any((i) => s.newIndBlock(i.id) == null));
      final tos = s.pivotTargets(b).where((i) => s.newIndBlock(i.id) == null).toList();
      final x = tos.first.id;
      s.noncomp = Noncomp(inds: [x], until: s.turn + 60, buyer: 0, price: 1);
      const nc = '会社を売ったときの約束で、この業種にはまだ入れません（「株」の画面で約束を破ることもできます）';
      _fresh(s);
      expect(msgKey(s.pivot(b, x)), nc, reason: '前は業態転換で素通りした');
      // 部下の提案
      final p = _staff(s)..partner = true;
      final o = Proposal(k: 'newbiz', w: 2, cost: 0, l: M('新しい事業を始めたい'), d: M('自分で立ち上げて、責任者をやります'))
        ..ind = x
        ..by = p.id
        ..bid = b.id;
      expect(msgKey(s.doProposal(o)), nc);
      expect(s.biz.any((y) => y.ind == x), isFalse);
      // 合併で入る業種
      final c = _cpu(s).first;
      c.biz.add(CoBiz(ind: x, power: 1));
      c.parent = 'player';
      c.stakePlayer = 70;
      _fresh(s);
      expect(msgKey(s.merge(c)), '{0}には「{1}」の事業があり、会社を売ったときの約束で、まだ自社には入れられません');
      expect(c.alive, isTrue);
      // 銀行が口を出している間は、業態転換もできない（上の子会社は手放しておく）
      c.parent = null;
      c.stakePlayer = 0;
      s.noncomp = null;
      s.bankCtl = 3;
      _fresh(s);
      expect(msgKey(s.pivot(b, x)), '銀行が経営に口を出している間は、新しい事業を始められません');
      expect(b.ind, isNot(x));
    });
  });

  group('11 会社を丸ごと売る', () {
    test('上場の準備と途中の買収は、新しい会社に残らない', () {
      final s = _game();
      final buyer = _cpu(s).first..cap = s.cap * 5;
      final c = _cpu(s).firstWhere((x) => x != buyer);
      s.corp.ipo = IpoPrep(start: s.turn, total: 30);
      s.corp.deals.add(MaDeal(co: c.id, stage: 'dd', left: 2));
      _fresh(s);
      s.sellCompany(buyer, false);
      expect(s.corp.ipo, isNull);
      expect(s.corp.deals, isEmpty);
    });
  });

  group('12 同時に進める買収のお金', () {
    test('申し入れで、手続きを待つ買収の額も数える', () {
      final s = _game();
      final cs = _cpu(s).toList();
      final a = cs[0], b = cs[1];
      final da = MaDeal(co: a.id, stage: 'close', left: 1, target: 51);
      final db = MaDeal(co: b.id, stage: 'offer', left: 1, target: 51);
      final pa = s.dealPrice(a, da), pb = s.dealPrice(b, db);
      s.cash = pa + pb * .5;
      s.corp.deals
        ..clear()
        ..addAll([db, da]);
      s.dealsProgress(_n);
      expect(s.pctOf(b), lessThan(51), reason: '前は1件ずつしか見ず、両方買って払いすぎた');
      expect(s.pctOf(a), 51);
      expect(s.cash, closeTo(pb * .5, pa * 1e-9));
    });

    test('手続きの時点で足りず、銀行も貸さなければ話は流れる', () {
      final s = _game();
      final a = _cpu(s).first;
      final da = MaDeal(co: a.id, stage: 'close', left: 1, target: 51);
      s.cash = s.dealPrice(a, da) * .5;
      s.bankCtl = 5;
      s.corp.deals
        ..clear()
        ..add(da);
      final c0 = s.cash;
      s.dealsProgress(_n);
      expect(s.pctOf(a), lessThan(51), reason: '前は払えなくても買い、手元のお金が大きく負になった');
      expect(s.cash, c0);
      expect(s.corp.deals, isEmpty);
    });
  });

  group('軽いもの', () {
    test('事業を売る・業態を変えるとき、仕掛かりは取り下げと同じく半分戻る', () {
      // 同じ盤面を2つ作り、仕掛かりのある方だけ半分多く入る
      final s = _game(), s0 = _game();
      final b = s.biz[0];
      b.pipe
        ..clear()
        ..add(Pipe(k: 'build', cost: 1e8, left: 2));
      s0.biz[0].pipe.clear();
      final c0 = s.cash;
      s.sellBiz(b);
      s0.sellBiz(s0.biz[0]);
      expect(s.cash - c0 - (s0.cash - c0), closeTo(5e7, 1));
      final b2 = s.biz.firstWhere((b) => s.pivotTargets(b).any((i) => s.newIndBlock(i.id) == null));
      b2.pipe.add(Pipe(k: 'dev', cost: 2e8, left: 3));
      final to = s.pivotTargets(b2).where((i) => s.newIndBlock(i.id) == null).first;
      _fresh(s);
      final c1 = s.cash;
      final m = s.pivot(b2, to.id);
      expect(s.cash - c1, closeTo(-s.capexOf(to) + 1e8, 1));
      expect(txIn(m, 'ja'), contains('途中の仕掛かりは半分'));
    });
  });

  group('15 社長と自社の名前', () {
    test('名前を決めても乱数の並びはずれない。ランキング・社史・セーブに出る', () {
      SetupConfig cfg({String? name, String? co}) => SetupConfig(mode: 'endless', year: 1990, traits: const ['charm', 'careful'], name: name, co: co);
      final a = Game.newGame(cfg(), rng: ParkMiller(99));
      final b = Game.newGame(cfg(name: '港 一郎', co: 'みなと商会'), rng: ParkMiller(99));
      expect(b.pres.name, '港 一郎');
      expect(b.myCo, 'みなと商会');
      expect(b.cos.map((c) => c.name).toList(), a.cos.map((c) => c.name).toList());
      expect(b.pres.ab, a.pres.ab);
      expect(b.fcSeed, a.fcSeed);
      expect(a.myCo, '');
      expect(txIn(a.rankList().firstWhere((x) => x.me).name, 'ja'), 'あなたのグループ');
      expect(txIn(b.rankList().firstWhere((x) => x.me).name, 'ja'), 'みなと商会（あなた）');
      // 案の名前（作り物の冠＋商会）は、英語の画面では読みで出る
      final c = Game.newGame(cfg(co: '暁星商会'), rng: ParkMiller(99));
      expect(txIn(c.rankList().firstWhere((x) => x.me).name, 'en'), 'Gyosei Shokai (you)');
      expect(txIn(b.history.first.m, 'ja'), contains('「みなと商会」を立ち上げた'));
      final back = Game.fromJson(jsonDecode(jsonEncode(b.toJson())) as Map<String, dynamic>, rng: ParkMiller(1));
      expect(back.myCo, 'みなと商会');
      // 子会社の名前の案は「自社の名前の頭＋分類」
      expect(b.subNameIdea('food'), 'みなと食品');
      expect(b.subNameIdea('food', group: false), isNot(startsWith('みなと')));
    });

    test('使えない名前は弾き、空なら今までどおり', () {
      expect(GameNames.myNameErrStatic(''), isNull);
      expect(GameNames.presNameErr(''), isNull);
      expect(GameNames.myNameErrStatic('あ' * 17), isNotNull);
      expect(GameNames.presNameErr('あ' * 17), isNotNull);
      expect(GameNames.myNameErrStatic(RIVALS.first.co), isNotNull, reason: '宿敵の会社と同じ名前');
      final s = Game.newGame(SetupConfig(mode: 'endless', year: 1990, traits: const ['charm', 'careful'], name: '  ', co: ''), rng: ParkMiller(99));
      expect(s.pres.name.trim(), isNotEmpty);
      expect(s.myCo, '');
      // 子会社には自社と同じ名前を付けられない
      s.myCo = 'みなと商会';
      expect(s.coNameErr('みなと商会'), isNotNull);
    });

    test('会社を売ると、前の会社は今の名前のまま残り、新しい会社の名前を決め直す', () {
      final s = _game()..myCo = 'みなと商会';
      final buyer = _cpu(s).first..cap = s.cap * 5;
      _fresh(s);
      expect(msgKey(s.sellCompany(buyer, false, newName: 'みなと商会')), '「{0}」は前の会社の名前として残ります。新しい名前を決めてください');
      s.sellCompany(buyer, false, newName: 'うしお商会');
      expect(s.cos.where((c) => c.formerMine).last.name, 'みなと商会', reason: '前は「〇〇グループ」になった');
      expect(s.myCo, 'うしお商会');
    });
  });

  group('画面', () {
    setUpAll(loadRealFonts);
    for (final size in const [Size(844, 390), Size(1194, 834)]) {
      for (final lang in const ['ja', 'en']) {
        testWidgets('始める画面の名前・自社の名前が出る所・海外に出す一覧 ${size.width.round()}×${size.height.round()}（$lang）', (tester) async {
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

  // 始める画面：名前の欄には案が入っている
  final st = ctl.setup;
  final presIdea = st.name!, coIdea = st.co!;
  expect(presIdea, isNotEmpty);
  expect(coIdea, endsWith('商会'));
  final pf = find.byKey(const ValueKey('setup-pres-name')), cf = find.byKey(const ValueKey('setup-co-name'));
  await tester.scrollUntilVisible(cf, 120, scrollable: find.byType(Scrollable).first);
  // 欄の上の見出し（名前）も入るように少し戻す
  await tester.drag(find.byType(Scrollable).first, const Offset(0, 90));
  await settle('setup');
  expect(tester.widget<TextField>(pf).controller!.text, nmL(presIdea));
  expect(tester.widget<TextField>(cf).controller!.text, nmL(coIdea));
  await shot(tester, key, 'audit_setup_names_$n', pixelRatio: 1.5);
  // 長すぎる名前は理由が出て、始められない
  await tester.enterText(cf, lang == 'en' ? 'a' * 40 : 'あ' * 20);
  await settle('long');
  expect(find.byKey(const ValueKey('setup-co-name-err')), findsOneWidget);
  expect(setupNameErr(st), isNotNull);
  await shot(tester, key, 'audit_setup_err_$n', pixelRatio: 1.5);
  // 書き直して始める
  await tester.enterText(cf, lang == 'en' ? 'Minato Trading' : 'みなと商会');
  await settle('typed');
  expect(setupNameErr(st), isNull);
  st.traits = ['charm', 'careful'];
  ctl.render();
  await settle('traits');
  final go = find.text(tr('会社を立ち上げる'));
  await tester.scrollUntilVisible(go, 200, scrollable: find.byType(Scrollable).first);
  await tap(go);
  final s = ctl.game!;
  expect(s.myCo, lang == 'en' ? 'Minato Trading' : 'みなと商会');
  expect(s.pres.name, presIdea, reason: '英語の画面で案のまま始めても、案の元の名前でしまう');
  ctl.closeSheet();
  await settle('started');

  // 育った盤面に名前を付けて、名前が出る所を見る
  final g = _game()..myCo = s.myCo;
  ctl.game = g;
  ctl.save();
  ctl.setTab('money');
  ctl.setMoney('book');
  await settle('book');
  final me = find.text(tx(g.myLabel()));
  expect(me, findsWidgets);
  await tester.ensureVisible(me.first);
  await settle('rank');
  await shot(tester, key, 'audit_rank_$n', pixelRatio: 1.5);
  ctl.setMoney('fs');
  await settle('fs');
  // 上（決算書の名前）まで戻す
  await tester.drag(find.byKey(const PageStorageKey('tab-money')), const Offset(0, 6000));
  await settle('fs-top');
  expect(find.byKey(const ValueKey('fs-co')), findsOneWidget);
  await shot(tester, key, 'audit_fs_$n', pixelRatio: 1.5);

  // 渡して独立させる会社の名前
  final b = g.biz[0];
  final p = g.mkPerson(.5);
  g.staff.add(p);
  b.mgr = p.id;
  openShape(ctl, b);
  await settle('shape');
  await tap(find.text(tr('渡して独立させる')));
  expect(find.byKey(const ValueKey('name-release')), findsOneWidget);
  await shot(tester, key, 'audit_release_name_$n', pixelRatio: 1.5);
  await tap(find.byKey(const ValueKey('co-name-ok')));
  expect(g.biz, isNot(contains(b)));
  ctl.closeSheet();
  await settle('released');

  // 海外に出す一覧：出る準備中の国は薄くして理由を出す
  final b2 = g.biz[0];
  final ctry = CTRY.map((x) => x.c).firstWhere((c) => c != g.home && !g.ctryOf(b2).contains(c) && g.entryModes(b2, c).contains('jv'));
  _fresh(g);
  g.enterCountry(b2, ctry, 'jv');
  expect(b2.pipe.any((x) => x.k == 'enter' && x.c == ctry), isTrue);
  openEnter(ctl, b2);
  await settle('enter');
  final why = find.text(tr('出る準備中です'));
  expect(why, findsOneWidget);
  await tester.ensureVisible(why);
  // 国の名前の行も入るように少し戻す
  await tester.drag(find.byKey(const ValueKey('sheet-card')), const Offset(0, 140));
  await settle('enter-row');
  await shot(tester, key, 'audit_enter_$n', pixelRatio: 1.5);
  ctl.closeSheet();
  await settle('enter-closed');

  // 会社を売る：新しい会社の名前を決めてから、いつもの確かめ
  final buyer = g.cos.firstWhere((c) => c.alive && c.parent != 'player' && c.rival == null)..cap = g.cap * 5;
  openSellName(ctl, buyer, false);
  await settle('sell');
  expect(tester.widget<TextField>(find.byKey(const ValueKey('co-name-field'))).controller!.text, isNotEmpty, reason: '新しい会社の名前の案が入っている');
  await shot(tester, key, 'audit_sell_name_$n', pixelRatio: 1.5);
  ctl.closeSheet();
  await settle('sell-closed');

  // 続きからの一覧に自社の名前
  ctl.save();
  ctl.game = null;
  ctl.render();
  await settle('slots');
  expect(find.textContaining(nmL(g.myCo)), findsWidgets);
  await tester.drag(find.byType(ListView).first, const Offset(0, 300));
  await settle('slots-top');
  await shot(tester, key, 'audit_slots_$n', pixelRatio: 1.5);
}
