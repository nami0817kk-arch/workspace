// 段5（1.1.0+28）：関税・輸送・交通とインフラ・海外の難しさ・供給の網。
// 仕組みごとに、数字の大きな流れが現実どおりか（WTO・協定・摩擦・コンテナ化・運賃の波・災害）と、ゲームのどの数字に効くかを見る。
// 海外に出る打ち方の自動プレイは、段5を切った同じ種と比べる（QUAD_BALANCE にファイルを渡すと .abroad に書き出す）
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';

import 'support/abroad.dart';
import 'support/bot.dart';

Game _g([int year = 1990, int seed = 5]) => Game.newGame(SetupConfig(year: year, traits: const ['charm', 'careful']), rng: ParkMiller(seed));

void _at(Game g, int y, [int q = 1]) {
  g.year = y;
  g.q = q;
}

void _month(Game g) {
  resolveEvents(g);
  g.nextQuarter();
  g.events.clear();
  g.hUsed = 0;
}

/// [id] の事業を始め、[abroad] の国にもすぐ出す（店などは段2の仕組みで置く）
Biz _biz(Game g, String id, {List<String> abroad = const [], String mode = 'solo'}) {
  g.cash = 1e14;
  g.hUsed = 0;
  g.startBiz(id);
  final b = g.biz.last;
  for (final c in abroad) {
    g.addCtry(b, c, mode, b.power * .5);
  }
  g.calcAll();
  return b;
}

final _cjk = RegExp('[　-ヿ㐀-鿿＀-￯]');

void main() {
  group('関税', () {
    test('時代と国の組で変わる：WTO の加盟・協定で下がり、摩擦で上がる', () {
      final g = _g();
      _at(g, 1995);
      final cn95 = g.tariffOf('cn', 'jp');
      _at(g, 2005);
      final cn05 = g.tariffOf('cn', 'jp');
      expect(cn95, greaterThan(.2), reason: '中国の1995年の関税は20%を超えていた');
      expect(cn05, lessThan(.11), reason: '2001年の WTO 加盟で10%前後へ');
      // 北米自由貿易協定（1994年）：米国がメキシコから入れる物の関税は、ほかの国より低い
      _at(g, 2005);
      expect(g.tariffOf('us', 'mx'), lessThan(g.tariffOf('us', 'jp') * .5));
      // EC の中は関税が無い
      expect(g.tariffOf('de', 'fr'), 0);
      // 米中の貿易摩擦（2018年7月から）
      _at(g, 2017);
      final us17 = g.tariffOf('us', 'cn');
      _at(g, 2019);
      expect(g.tariffOf('us', 'cn') - us17, greaterThan(.12));
      expect(g.tariffOf('us', 'jp'), lessThan(.05), reason: '摩擦は中国からの物だけ');
      // RCEP（2022年）で、日本と中国のあいだの関税が年をかけて下がる
      _at(g, 2021);
      final r21 = g.tariffOf('jp', 'cn');
      _at(g, 2030);
      expect(g.tariffOf('jp', 'cn'), lessThan(r21));
      // 原油はほぼ関税がかからず、農産物は高い
      expect(g.tariffOf('jp', 'sa', 'oil'), lessThan(g.tariffOf('jp', 'us', 'grain')));
    });

    test('関税が高い国へは、自分の国の工場から運ぶより、現地に工場を持つほうが安い', () {
      final g = _g(1995);
      final b = _biz(g, 'kaden', abroad: ['in']);
      // インドの店などを無くして、全部を日本から運ぶ形にする
      b.sites.removeWhere((k, _) => g.siteCtry(k) == 'in');
      b.young.removeWhere((y) => g.siteCtry(y.s) == 'in');
      g.calcAll();
      final v0 = Map.of(g.trade.view[b.id]!);
      expect(v0['export'], greaterThan(0), reason: '${g.trade.view[b.id]}');
      expect(v0['exTariff'], greaterThan(0));
      // インドに工場を置くと、運ぶ分が減り、品にかかる関税も減る（ただし部品をインドへ入れる関税はかかる。1995年は約40%）
      // （インドで売れる分だけの工場を置く。多く置くと、余った分を日本へ運ぶことになる）
      g.seedUnits(b, 'in', math.max(1, (b.rev * g.revShare(b, 'in') / g.unitRevNow(b)).ceil()));
      g.calcAll();
      final v1 = g.trade.view[b.id]!;
      expect(v1['export'], lessThan(v0['export']!));
      expect(v1['exTariff'], lessThan(v0['exTariff']!));
    });
  });

  group('輸送', () {
    test('距離と手段と時代で決まる：半導体は飛行機、鉱石は船、陸続きはトラック。コンテナ化と2021年の運賃の跳ね上がり', () {
      final g = _g(2010);
      expect(g.shipOf('jp', 'us', 'chip').mode, 'air');
      expect(g.shipOf('jp', 'us', 'ore').mode, 'sea');
      expect(g.shipOf('de', 'fr', 'goods').mode, 'land');
      expect(g.shipOf('jp', 'kr', 'goods').cost, lessThan(g.shipOf('jp', 'br', 'goods').cost));
      // 重い物ほど運賃の割合が高い
      expect(g.shipOf('au', 'jp', 'ore').cost, greaterThan(g.shipOf('au', 'jp', 'goods').cost));
      // 運賃の水準：ふつうの品を日本から米国へ船で運ぶと、値段の数%〜10%ほど
      final jpus = g.shipOf('jp', 'us', 'goods');
      expect(jpus.cost, inInclusiveRange(.03, .12));
      // 中国の港のコンテナ化（1990年ごろ）の前は高い
      _at(g, 1985);
      final c85 = g.shipOf('cn', 'jp', 'goods').cost;
      _at(g, 1995);
      expect(g.shipOf('cn', 'jp', 'goods').cost, lessThan(c85 * .8));
      // 2021年はコンテナ不足で海の運賃が跳ね上がった
      _at(g, 2019);
      final s19 = g.shipOf('cn', 'us', 'goods').freight;
      _at(g, 2021, 6);
      expect(g.shipOf('cn', 'us', 'goods').freight, greaterThan(s19 * 1.6));
    });
  });

  group('交通とインフラ', () {
    test('電気とネットが足りない国には出せない業種がある。整うと出せる', () {
      final g = _g(1990);
      final semi = indm['semi']!;
      expect(g.infraBlock(semi, 'in'), isNotNull, reason: '1990年のインドは電気が止まりやすい');
      expect(g.infraBlock(semi, 'us'), isNull);
      _at(g, 2000);
      expect(g.infraBlock(indm['portal']!, 'in'), isNotNull, reason: '2000年のインドはネットを使う人が1%に満たない');
      expect(g.infraBlock(indm['portal']!, 'kr'), isNull);
      _at(g, 2022);
      expect(g.infraBlock(indm['portal']!, 'in'), isNull);
    });

    test('道路が弱い国は、物流費が上がり、店の売れる量が落ちる。道路の網は郊外と地方への客の広がりを変える', () {
      final g = _g(2005);
      final b = _biz(g, 'konbini', abroad: ['ng']);
      expect(g.infraSalesF(b, 'ng'), lessThan(g.infraSalesF(b, 'jp')));
      expect(g.trade.view[b.id]!['infra'], greaterThan(0));
      expect(g.zoneReachF('jp', 2), greaterThan(g.zoneReachF('ng', 2)));
      expect(g.zoneReachF('jp', 0), 1, reason: '都心は道路で変わらない');
    });

    test('ネットを使う人が少ない国では、ネットの業種の利用者の上限も小さい', () {
      final g = _g(2005);
      final b = _biz(g, 'portal', abroad: ['kr']);
      _at(g, 2005);
      final kr = g.capUnits(b, 'kr');
      g.trade.off = true;
      final krOff = g.capUnits(b, 'kr');
      g.trade.off = false;
      expect(kr, lessThanOrEqualTo(krOff));
    });
  });

  group('海外の難しさ', () {
    test('外資の決まり：1990年の中国は組む相手が要り、2000年のインドは小売を開いていない。タイの店は組む相手が要る', () {
      final g = _g(1990);
      final b = _biz(g, 'konbini');
      expect(g.entryModes(b, 'cn'), ['jv']);
      expect(g.entryNote(b, 'cn'), isNotNull);
      _at(g, 2000);
      expect(g.entryModes(b, 'in'), isEmpty);
      expect(g.entryModes(b, 'th'), ['jv']);
      expect(g.entryModes(b, 'us'), ['solo', 'jv', 'buy']);
      _at(g, 2010);
      expect(g.entryModes(b, 'cn'), contains('solo'), reason: 'WTO 加盟のあと小売も開いた');
    });

    test('現地法人の立ち上げには時間がかかる（1990年代のインドは米国より長い。組むと早い）', () {
      final g = _g(1995);
      expect(g.setupMonths('in', 'solo'), greaterThan(g.setupMonths('us', 'solo')));
      expect(g.setupMonths('in', 'jv'), lessThan(g.setupMonths('in', 'solo')));
      // （1995年のインドは電気が足りず工場は置けないので、人で稼ぐ業種で見る）
      final b = _biz(g, 'consult');
      g.hUsed = 0;
      g.enterCountry(b, 'in', 'solo');
      expect(b.pipe.firstWhere((x) => x.k == 'enter').left, g.setupMonths('in', 'solo'));
    });

    test('言葉と文化が遠いほど慣れは低く始まり、客の数が減る。現地の言葉ができる責任者がいると早く慣れる', () {
      final g = _g(2000);
      expect(g.adapt0('kr', 'solo'), greaterThan(g.adapt0('us', 'solo')));
      expect(g.adapt0('us', 'solo'), greaterThan(g.adapt0('in', 'solo')));
      expect(g.adapt0('us', 'jv'), greaterThan(g.adapt0('us', 'solo')), reason: '地元の会社と組むと慣れが早い');
      // 慣れが低いと、その国の客の数（市場の重み）が減る
      final b = _biz(g, 'konbini', abroad: ['us']);
      g.trade.adapt['${b.id}/us'] = .6;
      final low = g.reachOf(b);
      g.trade.adapt['${b.id}/us'] = 1;
      expect(low, lessThan(g.reachOf(b)));
      // 同じ事業を2つの遊びで1年回し、片方には英語のできる責任者を置く
      double run(bool speaker) {
        final h = _g(2000, 9);
        final x = _biz(h, 'konbini', abroad: ['us']);
        h.trade.adapt['${x.id}/us'] = .7;
        if (speaker) {
          final p = h.mkPerson(.5);
          p.lg = 'en';
          p.sk!['lang'] = 85;
          p.kidsAge = [];
          p.care = false;
          h.staff.add(p);
          x.mgr = p.id;
        }
        for (var m = 0; m < 12; m++) {
          _month(h);
        }
        return h.adaptOf(x, 'us');
      }

      expect(run(true), greaterThan(run(false) + .03));
    });

    test('現地の人を雇う手間は人件費に入り、慣れるほど減る。経費の内訳は売上から利益を引いた額と合う', () {
      final g = _g(2000);
      final b = _biz(g, 'konbini', abroad: ['us']);
      g.trade.adapt['${b.id}/us'] = .6;
      g.calcAll();
      final l0 = g.trade.labor[b.id]!;
      expect(l0, greaterThan(0));
      g.trade.adapt['${b.id}/us'] = .95;
      g.calcAll();
      expect(g.trade.labor[b.id]!, lessThan(l0));
      final e = g.expenses();
      final spent = e.entries.where((x) => x.key != 'tax').fold(0.0, (a, x) => a + x.value);
      final want = g.biz.fold(0.0, (a, x) => a + x.rev) - g.pre;
      expect(spent, closeTo(want, want.abs() * .03 + 1e4));
    });

    test('為替の損：1997年のタイのバーツ急落で、現地にあるお金の値打ちが減る', () {
      final g = _g(1997);
      final b = _biz(g, 'konbini', abroad: ['th'], mode: 'jv');
      _at(g, 1997, 9);
      g.calcAll();
      g.monthTrade((m, [t = '']) {});
      expect(g.trade.fx[b.id], greaterThan(0), reason: 'バーツが円に対して下がった月');
    });

    test('送金の制限：1990年のブラジルの利益は一部が国の外へ出せず、制限が終わると戻る', () {
      final g = _g(1990);
      final b = _biz(g, 'konbini', abroad: ['br']);
      for (var m = 0; m < 3; m++) {
        b.profit = 1e10;
        g.monthTrade((m, [t = '']) {});
      }
      final t0 = g.trade.trapped['br'] ?? 0;
      expect(t0, greaterThan(0));
      _at(g, 1997);
      final c0 = g.cash;
      b.profit = 0;
      g.monthTrade((m, [t = '']) {});
      expect(g.trade.trapped['br'] ?? 0, lessThan(t0));
      expect(g.cash, greaterThan(c0 - 1e9));
    });

    test('政変・国有化の起きやすさは国で違う（ナイジェリアは日本より不安定）', () {
      final g = _g(2000);
      expect(g.polRisk('ng'), greaterThan(g.polRisk('jp') * 5));
      final b = _biz(g, 'konbini', abroad: ['ng']);
      final n0 = g.unitsIn(b, 'ng');
      expect(n0, greaterThan(0));
      g.nationalize(b, 'ng', (m, [t = '']) {});
      expect(g.ctryOf(b), isNot(contains('ng')));
      expect(g.unitsIn(b, 'ng'), 0);
    });

    test('視察で国のことが詳しく分かり、出たあとの慣れも高く始まる（社長の時間 1週間）', () {
      final g = _g(2000);
      g.cash = 1e12;
      expect(g.knowsCtry('kr'), isFalse);
      final a0 = g.adapt0('kr', 'solo');
      g.hUsed = 0;
      expect(msgKey(g.inspect('kr')), startsWith('{0}を1週間視察しました'));
      expect(g.knowsCtry('kr'), isTrue);
      expect(g.hUsed, greaterThanOrEqualTo(50));
      expect(g.adapt0('kr', 'solo'), greaterThan(a0));
      expect(g.growingIn('kr'), isNotEmpty);
    });
  });

  group('供給の網', () {
    test('仕入れ先の国が止まると作れなくなる（部品）。仕入れ先を分けると、止まる分が減る代わりに高くつく', () {
      final g = _g(1999);
      final b = _biz(g, 'semi');
      g.trade.sup[b.id] = ['tw'];
      g.calcAll();
      final cap0 = g.capRev(b);
      final in0 = g.trade.view[b.id]!['input']!;
      // 1999年9月の台湾の大地震
      _at(g, 1999, 9);
      g.monthTrade((m, [t = '']) {});
      expect(g.trade.stops.any((s) => s.c == 'tw'), isTrue);
      final one = g.supplyVolF(b);
      expect(one, lessThan(.85));
      expect(g.capRev(b), lessThan(cap0));
      // 日本からも仕入れると、止まる分は半分になる
      g.hUsed = 0;
      expect(msgKey(g.addSupplier(b, 'jp')), startsWith('「{0}」の仕入れ先に{1}を足しました'));
      expect(g.supplyVolF(b), greaterThan(one));
      // 止まっていない時は、分けた分だけ高くつく
      g.trade.stops.clear();
      g.calcAll();
      expect(g.trade.view[b.id]!['input']!, greaterThan(in0));
    });

    test('相場の品（原油）は、止まっても作れなくはならず、高くつく', () {
      final g = _g(1990);
      final b = _biz(g, 'oil');
      g.trade.sup[b.id] = ['sa'];
      g.calcAll();
      final in0 = g.trade.view[b.id]!['input']!;
      _at(g, 1990, 8);
      g.monthTrade((m, [t = '']) {});
      expect(g.supplyVolF(b), 1);
      g.calcAll();
      expect(g.trade.view[b.id]!['input']!, greaterThan(in0));
    });

    test('仕入れ先は、はじめはいちばん安い国を1つ。ロシアは2022年から仕入れられず、自動で外れる', () {
      final g = _g(2015);
      final b = _biz(g, 'chem');
      g.trade.sup[b.id] = ['ru', 'sa'];
      _at(g, 2022, 6);
      g.monthTrade((m, [t = '']) {});
      expect(g.supOf(b), ['sa']);
      final h = _g(1995);
      final x = _biz(h, 'yen100');
      expect(h.supOf(x), hasLength(1));
      expect(h.srcOk(x, h.supOf(x).first), isTrue);
    });
  });

  group('保存と英語', () {
    test('段5の状態は保存して戻せる', () {
      final g = _g(2000);
      final b = _biz(g, 'semi', abroad: ['us']);
      g.trade.sup[b.id] = ['tw', 'jp'];
      g.trade.know['us'] = .6;
      g.trade.trapped['cn'] = 1e8;
      g.trade.stops.add(ActiveStop(c: 'tw', ja: M('台風'), left: 2, unit: .05, sup: .3));
      g.trade.shock['us'] = [3, .2];
      g.trade.exp[3] = 12;
      final back = Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>, rng: ParkMiller(1));
      expect(back.trade.sup[b.id], ['tw', 'jp']);
      expect(back.trade.know['us'], .6);
      expect(back.trade.trapped['cn'], 1e8);
      expect(back.trade.stops.single.c, 'tw');
      expect(back.trade.shock['us'], [3, .2]);
      expect(back.trade.exp[3], 12);
      expect(back.adaptOf(back.biz.last, 'us'), closeTo(g.adaptOf(b, 'us'), 1e-9));
    });

    test('段5の仕組みの文と、協定・摩擦・出来事・仕入れの種類の名前に、すべて英語がある', () {
      final missing = <String>[];
      for (final f in ['game_trade', 'trade_data']) {
        final src = File('lib/game/$f.dart').readAsStringSync().split('\n').where((l) => !l.trim().startsWith('//')).join('\n');
        for (final m in RegExp(r"'((?:[^'\\\n]|\\.)*)'").allMatches(src)) {
          final k = m.group(1)!;
          if (!_cjk.hasMatch(k) || k.contains(r'$')) continue;
          if (enText(k) == null) missing.add(k);
        }
      }
      for (final k in [
        for (final f in FTAS) f.ja,
        for (final f in FRICTIONS) f.ja,
        for (final s in STOPS) s.ja,
        for (final x in GROUPS.values) x.ja,
        ...SHIP_MODE_JA.values,
      ]) {
        if (enText(k) == null) missing.add(k);
      }
      expect(missing, isEmpty, reason: missing.join('\n'));
      for (final v in [for (final k in [for (final f in FTAS) f.ja, for (final s in STOPS) s.ja]) enText(k)!]) {
        expect(_cjk.hasMatch(v), isFalse, reason: v);
      }
    });

    test('段5を切ると（試作との一致を見る遊び）、何も変わらない', () {
      final g = Game.newGame(SetupConfig(year: 1990, traits: const ['charm', 'careful']), rng: ParkMiller(3), extras: false);
      expect(g.tradeOn, isFalse);
      g.cash = 1e12;
      g.startBiz(g.liveInds().first.id);
      final b = g.biz.first;
      expect(g.ctryReachF(b, 'us'), 1);
      expect(g.tradeModes(b, 'cn'), isNull);
    });
  });

  test('海外に出る打ち方（1980年・日本・借りない・1995年から韓国と米国へ・30年）を、段5を切った同じ種と比べる', () {
    final lines = <String>[];
    final on = <AbroadRun>[], off = <AbroadRun>[];
    String yr(AbroadRun r) => r.broke ? '倒産 ${r.months ~/ 12}年目${r.bank ? '（銀行の管理）' : ''}' : '30年生存${r.bank ? '（銀行の管理あり）' : ''}';
    for (final seed in [11, 22, 33, 44, 55, 66]) {
      final a = playAbroad(seed), b = playAbroad(seed, off: true);
      on.add(a);
      off.add(b);
      lines.add('| $seed | ${yr(b)} | ${yen(b.cap)} | ${yen(b.peakCap)} | ${(b.ctry.toList()..sort()).join(',')} '
          '| ${yr(a)} | ${yen(a.cap)} | ${yen(a.peakCap)} | ${(a.ctry.toList()..sort()).join(',')} | ${(a.abroadShare * 100).toStringAsFixed(0)}% | ${(a.adapt * 100).toStringAsFixed(0)}% | ${yen(a.tradeCost)} | ${yen(a.trapped)} |');
    }
    final out = lines.join('\n');
    final f = Platform.environment['QUAD_BALANCE'];
    if (f != null) File('$f.abroad').writeAsStringSync(out);
    // ignore: avoid_print
    print(out);
    // 段5は結果を変える（6つの種のどれかで、最後の時価か時価の最高が違う）
    expect([for (var i = 0; i < 6; i++) on[i].peakCap != off[i].peakCap || on[i].cap != off[i].cap].any((x) => x), isTrue, reason: out);
    // 海外に出た遊びでは、出た国の慣れが育っている（出た直後の6〜8割から上がる）
    final went = on.where((r) => r.ctry.length > 1 && !r.broke).toList();
    for (final r in went) {
      expect(r.adapt, greaterThan(.7), reason: out);
    }
    // 段5があっても、海外に出る打ち方がいつも倒れるわけではない
    expect(on.where((r) => !r.broke).length, greaterThanOrEqualTo(1), reason: out);
  }, timeout: const Timeout(Duration(minutes: 20)));
}
