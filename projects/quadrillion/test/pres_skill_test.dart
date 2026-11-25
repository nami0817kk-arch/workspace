// 社長の腕は、事業を進める中で磨かれる（1.1.0+32）。
// 「腕を磨く」の行動を無くし、実際にやったこと（人を雇う・商品を作る・売上を伸ばす・借りる/返す/買収/上場）で経験がたまり、たまると +1。
// はじめの腕は、持ち点を自分で振り分けるか、おまかせ（今までどおりのランダム）で決める。
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';

import 'support/bot.dart';
import 'support/pro.dart';

Game _new({Map<String, int>? ab, List<String> traits = const ['charm', 'careful'], int seed = 3, String start = 'grad', int workYears = 0}) =>
    Game.newGame(SetupConfig(year: 1980, traits: traits.toList(), ab: ab, start: start, workYears: workYears, workCat: start == 'work' ? 'money' : null), rng: ParkMiller(seed));

void main() {
  group('はじめの腕', () {
    test('おまかせは今までどおり（同じ種なら、振り分けを足す前と同じ腕・同じ乱数の並び）', () {
      final a = _new(), b = _new();
      expect(a.pres.ab, b.pres.ab);
      for (final k in abKeys) {
        expect(a.pres.ab[k], inInclusiveRange(35, 55));
      }
    });

    test('振り分けた腕で始まり、ほかの乱数の並びはずれない', () {
      final r = _new();
      final g = _new(ab: {'tou': 20, 'kai': 80, 'ei': 50, 'zai': 30});
      expect(g.pres.ab, {'tou': 20, 'kai': 80, 'ei': 50, 'zai': 30});
      // 腕を振り分けても、会社の顔ぶれ・お金・予測の種は同じ
      expect(g.cash, r.cash);
      expect(g.fcSeed, r.fcSeed);
      expect(g.cos.map((c) => c.name).toList(), r.cos.map((c) => c.name).toList());
    });

    test('振り分けの外れた値は 20〜80 に収める。特性と会社員の年数の分は上に足す', () {
      final g = _new(ab: {'tou': 5, 'kai': 95, 'ei': 45, 'zai': 35}, traits: const ['tech', 'careful']);
      // tech は開発+25・営業-10・財務-10（上限99・下限5）
      expect(g.pres.ab, {'tou': 20, 'kai': 99, 'ei': 35, 'zai': 25});
      final w = _new(ab: {'tou': 45, 'kai': 45, 'ei': 45, 'zai': 45}, start: 'work', workYears: 5);
      // 金融で5年：財務 +10、統率 +5
      expect(w.pres.ab['zai'], 55);
      expect(w.pres.ab['tou'], 50);
    });

    test('持ち点の残り', () {
      final c = SetupConfig();
      expect(c.abLeft(), 0);
      c.ab = {for (final k in abKeys) k: 45};
      expect(c.abLeft(), 0);
      c.ab!['kai'] = 50;
      expect(c.abLeft(), -5);
    });
  });

  group('経験', () {
    test('「腕を磨く」は無い（古い呼び出しは落ちず、時間も腕も動かさない）', () {
      final g = _new();
      final ab = {...g.pres.ab}, h0 = g.hUsed;
      expect(tx(g.presAct('train', 'kai')), contains('事業を進める中で'));
      expect(g.hUsed, h0);
      expect(g.pres.ab, ab);
      expect(hoursOf.containsKey('train'), isFalse);
    });

    test('事業を始めると開発の経験がたまり、月の終わりに腕の経験になる。1か月の上限がある', () {
      final g = _new(ab: {'tou': 45, 'kai': 45, 'ei': 45, 'zai': 45});
      g.startBiz((g.liveInds().where((i) => g.capexOf(i) <= g.cash).toList()..ssort((a, b) => g.capexOf(a).compareTo(g.capexOf(b))))[0].id);
      // 新しい事業は一度きりの山なので、上限の外（'kai!'）にたまる
      expect(g.pres.pend['kai!'], 5);
      // 同じ月に何度借りても、1か月にたまるのは上限まで
      g.cash += 1e12;
      for (var i = 0; i < 6; i++) {
        g.presXp('zai', 1.5);
      }
      g.nextQuarter();
      expect(g.pres.xp['kai'], closeTo(5, 1e-9));
      expect(g.pres.xp['zai'], closeTo(presXpCap, 1e-9));
      expect(g.pres.pend, isEmpty);
    });

    test('経験がたまると腕が1上がり、知らせが出る。高いほど要る経験が多い', () {
      final g = _new(ab: {'tou': 45, 'kai': 45, 'ei': 45, 'zai': 45});
      expect(presNeedOf(80), greaterThan(presNeedOf(45)));
      g.pres.xp['ei'] = presNeedOf(45) - .5;
      g.presXp('ei', 1);
      g.nextQuarter();
      expect(g.pres.ab['ei'], 46);
      expect(g.lastNews.map((n) => tx(n.m)).join('\n'), contains('営業の腕が上がりました（45 → 46）'));
    });

    test('上場・合併のような大きな山は、1か月の上限に数えない', () {
      final g = _new();
      // 腕が高いと1上げるのに要る経験が多いので、この月は上がらない
      g.pres.ab['zai'] = 90;
      g.presXp('zai', 6, big: true);
      g.presXp('zai', 9);
      g.nextQuarter();
      expect(g.pres.ab['zai'], 90);
      expect(g.pres.xp['zai'], closeTo(6 + presXpCap, 1e-9));
    });

    test('50代から鈍る', () {
      final g = _new();
      g.pres.age = 55;
      g.presXp('tou', 2);
      g.nextQuarter();
      expect(g.pres.xp['tou'], closeTo(2 * .6, 1e-9));
    });

    test('任せた責任者の手は、社長の経験にならない', () {
      final g = _new();
      g.presXp('kai', 1);
      final keep = {...g.pres.pend};
      g.delegMonthly();
      expect(g.pres.pend, keep);
    });

    test('経験はセーブに入り、古いセーブは0から', () {
      final g = _new();
      g.pres.xp['tou'] = 4.5;
      g.pres.pend['kai'] = 2;
      g.pres.hd = 12;
      g.pres.crisis = 1;
      final j = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
      final back = Game.fromJson(j);
      expect(back.pres.xp['tou'], 4.5);
      expect(back.pres.pend['kai'], 2);
      expect(back.pres.hd, 12);
      expect(back.pres.crisis, 1);
      final p = Map<String, dynamic>.from(j['pres'] as Map)
        ..remove('xp')
        ..remove('pend')
        ..remove('hd')
        ..remove('cr');
      final old = President.fromJson(p);
      expect(old.xp, isEmpty);
      expect(old.crisis, 0);
    });
  });

  // 腕の伸びの目安（30年で各腕 +15〜25 ほど）を、ふつうの上手な人の自動プレイで測る。
  // 数字は PR の本文に載せる。線は目安より広め（種によって、売上の伸び方や借り方が違う）
  test('30年で腕がどれだけ伸びるか（自動プレイ）', () {
    final gains = <String, List<int>>{for (final k in abKeys) k: []};
    // 「ふつうの上手な人」は店などを開くのが主で、商品はあまり作らない。そのため開発は伸びが小さい（+6〜10）。
    // 開発の線は、店などで客をつかむ遊び方でも少しは伸びる、の意味で、ほかと同じ広さにしてある
    for (final seed in const [1, 2, 3, 4]) {
      final g = Game.newGame(SetupConfig(mode: 'world', year: 1980, traits: const ['charm', 'careful'], home: 'jp'), rng: ParkMiller(seed));
      final name = g.pres.name;
      final ab0 = {...g.pres.ab};
      var last = {...g.pres.ab};
      for (var m = 0; m < 30 * 12; m++) {
        proMonth(g, borrow: 'some');
        if (g.won != null) {
          g.mode = 'endless';
          g.won = null;
        }
        if (g.over != null || g.pres.name != name) break;
        last = {...g.pres.ab};
      }
      final line = [for (final k in abKeys) '${ABN.ja[k]} ${ab0[k]}→${last[k]}'].join('・');
      // ignore: avoid_print
      print('seed$seed（${g.pres.name == name ? '${g.pres.age}歳まで' : '社長が替わるまで'}${g.over != null ? '・倒産' : ''}）: $line');
      for (final k in abKeys) {
        gains[k]!.add(last[k]! - ab0[k]!);
      }
    }
    for (final k in abKeys) {
      final avg = gains[k]!.reduce((a, b) => a + b) / gains[k]!.length;
      // ignore: avoid_print
      print('${ABN.ja[k]}: ${gains[k]} 平均 +${avg.toStringAsFixed(1)}');
      expect(avg, inInclusiveRange(5, 35), reason: '${ABN.ja[k]} ${gains[k]}');
    }
  });
}
