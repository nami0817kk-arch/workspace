import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';

import 'support/bot.dart';

Game _grown({int seed = 11, int months = 60, String home = 'jp', int year = 1980}) {
  final s = Game.newGame(SetupConfig(mode: 'endless', year: year, traits: ['charm', 'gambler'], home: home), rng: ParkMiller(seed));
  for (var i = 0; i < months; i++) {
    botMonth(s);
  }
  resolveEvents(s);
  return s;
}

void _fill(Game s) {
  s.ap = 99;
  s.cash = s.cap * 10 + 1e12;
}

void main() {
  test('同じ seed なら同じ進み方、違う seed なら違う進み方', () {
    final a = _grown(seed: 5, months: 24), b = _grown(seed: 5, months: 24), c = _grown(seed: 6, months: 24);
    expect(a.cap, b.cap);
    expect(a.cash, b.cash);
    expect(jsonEncode(a.toJson()), jsonEncode(b.toJson()));
    expect(a.cap == c.cap && a.cash == c.cash, isFalse);
  });

  test('数か月進めると月と年が回り、記録が増える', () {
    final s = Game.newGame(SetupConfig(year: 2000, traits: ['tech', 'oneman']), rng: ParkMiller(9));
    s.startBiz((s.liveInds().where((i) => s.capexOf(i) <= s.cash).toList()..ssort((a, b) => b.mg.compareTo(a.mg)))[0].id);
    for (var i = 0; i < 14; i++) {
      s.nextQuarter();
      resolveEvents(s);
    }
    expect(s.year, 2001);
    expect(s.q, 3);
    expect(s.turn, 14);
    expect(s.hist.length, 14);
    expect(s.cap.isFinite && s.cap >= 1, isTrue);
  });

  test('セーブと読み込みの往復で中身が変わらず、その後の進み方も同じ', () {
    final s = _grown(seed: 21, months: 72);
    // 読み込むと数字を計算し直す。出来事を片付けたあとの元の会社も、計算し直してから比べる
    // （1.1.0+26 から、店などで売上を抑えた倍を、人手の見積もりに使う。片付けた出来事で古いままだと、続きの手が変わる）
    s.calcAll();
    final j1 = jsonEncode(s.toJson());
    final back = Game.fromJson(jsonDecode(j1) as Map<String, dynamic>, rng: ParkMiller(1));
    expect(jsonEncode(back.toJson()), j1);
    expect(back.cap, closeTo(s.cap, s.cap.abs() * 1e-9));
    // 同じ乱数で続きを動かすと、同じ数字になる
    s.rng = ParkMiller(99);
    back.rng = ParkMiller(99);
    for (var i = 0; i < 24; i++) {
      botMonth(s);
      botMonth(back);
    }
    expect(back.cash, closeTo(s.cash, s.cash.abs() * 1e-9 + 1e-6));
    expect(back.cap, closeTo(s.cap, s.cap.abs() * 1e-9));
    expect(back.biz.length, s.biz.length);
  });

  test('読み込みは選ぶ出来事を持ち越さない（試作の save と同じ）', () {
    final s = _grown(seed: 4, months: 12);
    s.events.add(GameEvent(title: 't', text: 'x', choices: [Choice('a', 'b', () => 'c')]));
    final back = Game.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
    expect(back.events, isEmpty);
  });

  test('打ち手（商品・建設・現場の人・広告・値付け・稼ぎ方・業態）が例外を出さない', () {
    final s = _grown(seed: 31, months: 36);
    _fill(s);
    final b = s.biz.first;
    expect(tx(s.develop(b, .1)), contains('開発'));
    // 1.1.0+26 から、お金の割合の「店を増やす」は、今いちばん要る伸ばす手（開く・責任者を育てる・本部・拠点）を打つ
    expect(tx(s.build(b, .1)), anyOf(contains('開き始めました'), contains('育て始めました'), contains('置きました'), contains('拠点を作り始めました'), contains('増やせません')));
    expect(tx(s.addCrew(b, .05)), contains('現場の人'));
    expect(tx(s.adv(b)), contains('広告'));
    expect(s.invest(b, .05), isNotEmpty);
    s.setPrice(b, 'cut');
    expect(b.price, 'cut');
    for (final m in s.modelsFor(b.ind).where((m) => m != b.model)) {
      expect(tx(s.changeModel(b, m)), contains('切り替えました'));
    }
    final t = s.pivotTargets(b);
    if (t.isNotEmpty) expect(tx(s.pivot(b, t.first.id)), contains('業態転換'));
    expect(s.cancelPipe(b, 0), isNotEmpty);
    for (var i = 0; i < 8; i++) {
      s.nextQuarter();
      resolveEvents(s);
    }
  });

  test('社長の行動と相棒（探す・誘う・日銭・腕磨き・人脈・種探し）', () {
    final s = Game.newGame(SetupConfig(year: 1980, traits: ['charm', 'noble']), rng: ParkMiller(8));
    for (final pl in PLACES) {
      // 相棒は2人まで（誘いが断られることもあるので、何人目で埋まるかは乱数しだい）
      if (s.partners().length >= 2) break;
      s.ap = 3;
      expect(s.presAct('seek', pl.id), isNull);
      final p = s.meet!;
      expect(p.place, pl.id);
      final r = s.recruitPartner(p, 10);
      expect(tx(r), contains(p.name));
      expect(s.meet, isNull);
    }
    expect(s.partners().length, lessThanOrEqualTo(2));
    expect(s.sh.own + s.sh.pt, closeTo(100, 1e-9));
    s.ap = 9;
    expect(tx(s.presAct('work')), contains('稼ぎました'));
    expect(tx(s.presAct('train', 'zai')), contains('財務'));
    expect(s.presAct('net'), isNotEmpty);
    expect(s.presAct('scout'), isNotEmpty);
    if (s.partners().length >= 2) expect(tx(s.presAct('seek', 'lab')), '相棒は2人までです');
  });

  test('海外に出る（単独・組む・買う）と、準備が済むと国が増える', () {
    final s = _grown(seed: 41, months: 24);
    _fill(s);
    final b = s.biz.first;
    // 自動プレイがもう出ている国があれば、まだどこにも出ていない形に戻して見る（1.1.0+27 で人の仕組みの乱数が増え、自動プレイが先に韓国へ出ることがある）
    b.ctry = null;
    b.jv = null;
    s.calcAll();
    // 1.1.0+28（段5）から、外資の決まりのある国（1980年代の韓国・中国など）では出方が限られ、立ち上げの月は国と年で変わる。
    // 決まりの無い国（英国・米国・ドイツ）で、3つの出方と、立ち上げの月が札どおりかを見る
    expect(tx(s.enterCountry(b, 'uk', 'buy')), contains('すぐに'));
    expect(s.ctryOf(b), contains('uk'));
    expect(tx(s.enterCountry(b, 'us', 'solo')), contains('${s.setupMonths('us', 'solo')}か月後'));
    expect(tx(s.enterCountry(b, 'de', 'jv')), contains('${s.setupMonths('de', 'jv')}か月後'));
    expect(s.setupMonths('de', 'jv'), lessThan(s.setupMonths('de', 'solo')));
    for (var i = 0; i < 7; i++) {
      s.nextQuarter();
      resolveEvents(s);
    }
    expect(s.ctryOf(b), containsAll(['uk', 'us', 'de']));
    expect(b.jv, contains('de'));
    // 中国のネットと金融は組むだけ
    final net = Biz(id: 999999, ind: 'sns', power: 1);
    expect(s.entryModes(net, 'cn'), ['jv']);
  });

  test('株の手（上場・増資・自社株買い・TOB・合併・株式交換・持株会社・分社・独立・会社を割る）', () {
    final s = _grown(seed: 51, months: 48);
    _fill(s);
    s.turn = 30;
    if (!s.listed) {
      // 1.1.0+29 から、上場は2〜3年の準備（監査2期・社内の決まり）のあと。準備が済んだ形で上場する
      s.pre = 1e12;
      s.hist.add(HistEntry(t: 'x', cap: s.cap, rev: s.rev, cash: s.cash, pre: 1e12));
      s.corp.ipo = IpoPrep(start: 0, total: 24, done: 24, audit: 24, ctrl: 1);
      expect(tx(s.ipo()), contains('上場しました'));
    }
    s.calcAll();
    _fill(s);
    expect(s.publicOffer(), isNotEmpty);
    expect(s.buybackAct(), isNotEmpty);
    expect(s.whiteKnightAct(), isNotEmpty);
    // TOB と合併（1.1.0+29 から、TOB は申し入れ→相手の返事→審査→手続きと月をまたぐ。応じてもらえる形にして月を進める）
    void months(bool Function() done) {
      for (var i = 0; i < 30 && !done(); i++) {
        for (final d in s.corp.deals) {
          d.prem = 2;
          d.block = 0;
          s.coById(d.co)!
            ..fam = 0
            ..rel = 100;
        }
        _fill(s);
        s.nextQuarter();
        resolveEvents(s);
        s.events.clear();
      }
    }

    // 1.1.0+30 から CPU の会社の取り分が0.78倍になり、いちばん小さな会社は手続きのあいだに倒れることがある。借金の無い小さな会社を選ぶ
    final target = (s.cos.where((c) => c.alive && c.parent != 'player' && c.rival == null && c.loc == null && s.finOf(c).debt <= 0 && c.profit > 0).toList()
          ..ssort((a, b) => a.cap.compareTo(b.cap)))
        .first;
    expect(tx(s.tob(target, 50.1)), contains('申し入れました'));
    months(() => target.parent == 'player');
    expect(target.parent, 'player');
    _fill(s);
    s.tob(target, 66.7);
    months(() => s.pctOf(target) >= 66.7);
    _fill(s);
    if (s.pctOf(target) >= 66.7 && s.canMerge(target)) expect(tx(s.merge(target)), contains('合併しました'));
    // 株式交換（小さい会社を丸ごと）
    // 1.1.0+29 から、潰れかけの会社は時価総額が1円近くまで下がることがあるので、自社の1%以上の大きさの会社で見る
    final small = (s.cos.where((c) => c.alive && c.parent != 'player' && c.loc == null && c.cap > 1e9).toList()..ssort((a, b) => a.cap.compareTo(b.cap))).first;
    final own0 = s.sh.own;
    s.ap = 99;
    expect(tx(s.shareSwap(small)), contains('申し入れました'));
    final news = <String>[];
    for (var i = 0; i < 30 && small.alive; i++) {
      for (final d in s.corp.deals) {
        d.prem = 2;
        d.block = 0;
      }
      small
        ..fam = 0
        ..rel = 100;
      _fill(s);
      s.nextQuarter();
      news.addAll(s.lastNews.map((n) => tx(n.m)));
      resolveEvents(s);
      s.events.clear();
    }
    final r = news.firstWhere((n) => n.contains('丸ごと買いました'), orElse: () => news.join('\n'));
    expect(r, contains('丸ごと買いました'));
    expect(small.alive, isFalse);
    expect(s.sh.own, lessThan(own0));
    // 会社の形
    while (s.biz.length < 6) {
      final i = s.liveInds().firstWhere((i) => !s.biz.any((b) => b.ind == i.id));
      s.startBiz(i.id);
    }
    expect(tx(s.makeHolding()), contains('持株会社'));
    final staff1 = s.mkPerson(0), staff2 = s.mkPerson(0);
    s.staff.addAll([staff1, staff2]);
    s.biz[0].mgr = staff1.id;
    expect(tx(s.spinOff(s.biz[0])), contains('分社'));
    s.biz[0].mgr = staff2.id;
    expect(tx(s.releaseBiz(s.biz[0])), contains('独立させました'));
    final sub = s.subs().firstWhere((c) => s.pctOf(c) >= 60);
    expect(tx(s.subIPO(sub)), contains('上場させ'));
    final cat = indm[s.biz.last.ind]!.cat;
    if (s.biz.any((b) => indm[b.ind]!.cat != cat)) expect(tx(s.splitCompany(cat)), contains('切り離し'));
    expect(tx(s.sellOwn(5)), contains('財産'));
    _fill(s);
    expect(tx(s.goPrivate()), contains('非上場'));
    for (var i = 0; i < 12; i++) {
      s.nextQuarter();
      resolveEvents(s);
    }
  });

  test('会社を丸ごと売ると、財産が増え、ゼロから始め直し、前の会社が残る', () {
    final s = _grown(seed: 61, months: 60);
    s.ap = 5;
    final buyer = s.cos.firstWhere((c) => c.alive && c.parent != 'player');
    buyer.cap = s.cap * 3;
    final price = s.salePrice(true);
    final msg = s.sellCompany(buyer, true);
    expect(tx(msg), contains('売りました'));
    expect(s.biz, isEmpty);
    expect(s.wealth, closeTo(price * .5, price * 1e-9));
    expect(s.cash, closeTo(price * .5, price * 1e-9));
    expect(s.noncomp, isNotNull);
    expect(s.cos.any((c) => c.formerMine), isTrue);
    // 約束の業種には入れない。破ると裁判
    final banned = s.noncomp!.inds.first;
    // 元手が足りない理由で断られないよう、お金は足りている形で確かめる（1.1.0+26 から売値が店などの数で変わり、元手に届かないことがある）
    final cash0 = s.cash;
    s.cash = 1e15;
    expect(tx(s.startBiz(banned)), contains('約束'));
    s.cash = cash0;
    expect(tx(s.breakNoncomp()), contains('約束を破る'));
    expect(s.suits.single.against, isTrue);
    for (var i = 0; i < 30; i++) {
      s.nextQuarter();
      resolveEvents(s);
    }
  });

  test('組む（提携・共同開発・製造・業界団体）・裏切る・裏の手・社風・後継ぎ', () {
    final s = _grown(seed: 71, months: 48);
    _fill(s);
    final c = s.cos.firstWhere((c) => c.alive && c.parent != 'player' && c.rel >= -20);
    for (final t in const ['sales', 'codev', 'outsrc']) {
      expect(tx(s.makeDeal(c, t)), contains('組みました'));
    }
    expect(tx(s.makeDeal(c, 'sales')), 'すでに組んでいます');
    expect(tx(s.betray(s.deals.first)), contains('裏切り'));
    expect(tx(s.endDeal(s.deals.first)), contains('解消'));
    final b = s.biz.first;
    if (s.competitors(b).isNotEmpty) expect(s.joinAssoc(b), isNotEmpty);
    final foe = s.cos.firstWhere((c) => c.rival != null && c.alive && c.parent != 'player');
    for (final k in DIRTYN.keys) {
      _fill(s);
      expect(s.doDirty(k, foe), isNotEmpty);
    }
    expect(s.changeCulture('steady') + s.changeCulture('merit'), isNotEmpty);
    final p = s.mkPerson(0);
    s.staff.add(p);
    s.choosePresSucc(p.id);
    final gen0 = s.gen;
    expect(tx(s.retire()), contains('社長になりました'));
    expect(s.pres.name, p.name);
    expect(s.gen, gen0 + 1);
    for (var i = 0; i < 30; i++) {
      s.nextQuarter();
      resolveEvents(s);
    }
  });

  test('出来事の選択肢は、どれを選んでも例外を出さない', () {
    for (var seed = 1; seed <= 6; seed++) {
      final s = _grown(seed: seed * 13, months: 12);
      var n = 0;
      for (var t = 0; t < 120; t++) {
        botMonth(s);
        // botMonth が片付ける前に、残った出来事の選択肢を順に試す
        s.nextQuarter();
        final evs = s.events.toList();
        s.events.clear();
        for (var i = 0; i < evs.length; i++) {
          final ch = evs[i].choices[(seed + t + i) % evs[i].choices.length];
          expect(ch.f(), isA<String>());
          n++;
        }
      }
      expect(n, greaterThan(0));
    }
  });
}
