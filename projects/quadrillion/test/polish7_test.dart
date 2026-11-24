import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';

import 'support/bot.dart';

/// 7回目の改善: 業種を112から200に（88を足す）、シナジー43・大シナジー3を足す
void main() {
  group('業種200', () {
    test('業種は200で、id が重ならない', () {
      expect(IND.length, 200);
      expect(IND_BASE.length, 112);
      expect(IND_MORE.length, 88);
      expect({for (final i in IND) i.id}.length, 200);
      expect({for (final i in IND) i.ja}.length, 200, reason: '日本語の名前も重ならない');
      expect(indm.length, 200);
    });

    test('試作の112業種は前と同じ並び（足した分は後ろ）', () {
      expect(IND.take(112).map((i) => i.id).toList(), IND_BASE.map((i) => i.id).toList());
      expect(IND_BASE.first.id, 'yatai');
      expect(IND_BASE.last.id, 'seabed');
    });

    test('全業種に英語名がある（日本語と違う、短い名前）', () {
      for (final i in IND) {
        final en = enText(i.ja);
        expect(en, isNotNull, reason: i.ja);
        expect(en!.length, lessThanOrEqualTo(24), reason: en);
        expect(RegExp(r'[぀-ヿ一-鿿]').hasMatch(en), isFalse, reason: en);
      }
      for (final x in SYN) {
        expect(enText(x.ja), isNotNull, reason: x.ja);
      }
      for (final g in BIG) {
        expect(enText(g.ja), isNotNull, reason: g.ja);
      }
    });

    test('分類は10のどれかで、足した分は分類ごとに8〜9', () {
      final per = <String, int>{};
      for (final i in IND) {
        expect(CATN.keys.contains(i.cat), isTrue, reason: i.id);
        expect(ABN.keys.contains(i.key), isTrue, reason: i.id);
      }
      for (final i in IND_MORE) {
        per[i.cat] = (per[i.cat] ?? 0) + 1;
      }
      expect(per.keys.toSet(), CATN.keys.toSet());
      for (final e in per.entries) {
        expect(e.value, inInclusiveRange(8, 10), reason: e.key);
      }
    });

    test('数字は今の112業種と釣り合う範囲（年・利益率・景気・元手・市場）', () {
      double lo(double Function(Industry) f) => IND_BASE.map(f).reduce((a, b) => a < b ? a : b);
      double hi(double Function(Industry) f) => IND_BASE.map(f).reduce((a, b) => a > b ? a : b);
      for (final i in IND_MORE) {
        expect(i.b, inInclusiveRange(1900, 2060), reason: i.id);
        expect(i.p, greaterThan(i.b), reason: i.id);
        if (i.f != 0) expect(i.f, greaterThan(i.p), reason: i.id);
        expect(i.mg, inInclusiveRange(lo((x) => x.mg) * .5, hi((x) => x.mg)), reason: i.id);
        expect(i.sens, inInclusiveRange(lo((x) => x.sens), hi((x) => x.sens)), reason: i.id);
        expect(i.capex, inInclusiveRange(lo((x) => x.capex), hi((x) => x.capex) * 5), reason: i.id);
        expect(i.size, inInclusiveRange(lo((x) => x.size), hi((x) => x.size)), reason: i.id);
      }
    });

    test('時代が混ざっている（古い・1980〜2000年代に生まれて沈む・2010〜2030年代・2040年以降）', () {
      expect(IND_MORE.where((i) => i.b <= 1930).length, greaterThanOrEqualTo(10));
      expect(IND_MORE.where((i) => i.b >= 1980 && i.b < 2010 && i.f != 0).length, greaterThanOrEqualTo(5));
      expect(IND_MORE.where((i) => i.b >= 2010 && i.b < 2040).length, greaterThanOrEqualTo(15));
      expect(IND_MORE.where((i) => i.b >= 2040).length, greaterThanOrEqualTo(4));
    });

    test('年代ごとの業種の数が偏らない（足した分は試作の業種と同じような割合で散らばる）', () {
      bool thriving(Industry i, int y) => i.b <= y && (i.f == 0 || y <= i.f);
      final lines = <String>[];
      int? prev;
      for (var y = 1950; y <= 2090; y += 10) {
        final all = IND.where((i) => thriving(i, y)).length;
        final base = IND_BASE.where((i) => thriving(i, y)).length;
        final born = IND.where((i) => i.b > y - 10 && i.b <= y).length;
        final sunk = IND.where((i) => i.f != 0 && i.f > y - 10 && i.f <= y).length;
        lines.add('$y年: 盛りの業種 $all（試作 $base）+$born -$sunk');
        expect(all / base, inInclusiveRange(1.4, 2.0), reason: '$y年 $all / $base');
        if (prev != null) expect((all - prev).abs(), lessThanOrEqualTo(30), reason: '$y年');
        prev = all;
      }
      // ignore: avoid_print
      print(lines.join('\n'));
    });
  });

  group('稼ぎ方とシナジー', () {
    test('稼ぎ方の割り当ては実在の業種だけ。ものづくり・お金・未来に加盟店はない', () {
      for (final e in MODELS_BY.entries) {
        for (final id in e.value) {
          expect(indm.containsKey(id), isTrue, reason: '${e.key} $id');
        }
      }
      for (final id in MODELS_BY['fc']!) {
        expect(['make', 'money', 'fut', 'net', 'ene'].contains(indm[id]!.cat) && id != 'gasstation', isFalse, reason: id);
      }
      for (final id in MODELS_BY['plat']!) {
        expect(['net', 'money', 'food', 'live', 'med', 'fut'].contains(indm[id]!.cat), isTrue, reason: id);
      }
      final g = Game.newGame(SetupConfig(year: 2020, traits: ['charm', 'gambler']), rng: ParkMiller(5));
      expect(g.modelsFor('ramen'), ['direct', 'fc']);
      expect(g.modelsFor('flea'), ['direct', 'plat']);
      expect(g.modelsFor('battery'), ['direct', 'sub']);
      expect(g.modelsFor('coal'), ['direct']);
    });

    test('シナジーの両端・大シナジーの3つは実在の業種で、組み合わせが重ならない', () {
      final ks = <String>{};
      for (final s in SYN) {
        expect(indm.containsKey(s.a) && indm.containsKey(s.b), isTrue, reason: s.k);
        expect(s.a, isNot(s.b));
        expect(ks.add({s.a, s.b}.toList().join('|')) && ks.add({s.b, s.a}.toList().join('|')), isTrue, reason: s.k);
      }
      for (final s in SYN_MORE) {
        expect(IND_MORE.any((i) => i.id == s.a || i.id == s.b), isTrue, reason: '${s.k} は足した業種を含む');
      }
      for (final g in BIG) {
        expect(g.set.length, 3);
        for (final x in g.set) {
          expect(indm.containsKey(x), isTrue, reason: x);
        }
      }
      expect({for (final g in BIG) g.k}.length, BIG.length);
      expect(SYN_MORE.length, 43);
      expect(BIG_MORE.length, 3);
    });

    test('足したシナジーは見つかる（持つと力が2割上がる）', () {
      final g = Game.newGame(SetupConfig(year: 2020, traits: ['charm', 'gambler']), rng: ParkMiller(9));
      g.cash = 1e13;
      g.ap = 99;
      g.startBiz('clinic');
      g.startBiz('pharmacy');
      expect(g.synMult()['clinic'], closeTo(1.2, 1e-9));
      g.startBiz('telemed');
      // 門前薬局・スマホで診察には app も要る。大シナジー「かかりつけの全部」で4割
      expect(g.synMult()['telemed'], closeTo(1.4, 1e-9));
    });
  });

  group('extras の切り替え', () {
    test('extras を切ると112業種・98シナジー・10大シナジーだけを使う', () {
      final s = Game.newGame(SetupConfig(mode: 'world', year: 1980, traits: ['charm', 'gambler']), rng: ParkMiller(3), extras: false);
      expect(s.inds.length, 112);
      expect(s.syns.length, 98);
      expect(s.bigs.length, 10);
      final base = {for (final i in IND_BASE) i.id};
      expect(s.liveInds().every((i) => base.contains(i.id)), isTrue);
      for (var t = 0; t < 12 * 40; t++) {
        botMonth(s);
      }
      for (final c in s.cos) {
        for (final b in c.biz) {
          expect(base.contains(b.ind), isTrue, reason: b.ind);
        }
      }
      expect(s.indM.keys.every(base.contains), isTrue);
    });

    test('extras ありなら足した業種にも CPU の会社がいる', () {
      final s = Game.newGame(SetupConfig(mode: 'world', year: 1980, traits: ['charm', 'gambler']), rng: ParkMiller(3));
      expect(s.inds.length, 200);
      final held = {for (final c in s.cos) for (final b in c.biz) b.ind};
      for (final i in s.liveInds()) {
        expect(held.contains(i.id), isTrue, reason: i.id);
      }
    });

    test('extras ありで自動プレイ50年が落ちない（足した業種も生まれる）', () {
      for (final seed in [21, 22]) {
        final s = Game.newGame(SetupConfig(mode: 'endless', year: 1980, traits: ['charm', 'gambler']), rng: ParkMiller(seed));
        final born = <String>{};
        for (var t = 0; t < 12 * 50 && s.over == null; t++) {
          botMonth(s);
          expect(s.cash.isFinite && s.cap.isFinite, isTrue);
          for (final i in IND_MORE) {
            if ((s.indM[i.id] ?? 0) > 0) born.add(i.id);
          }
        }
        // 1.1.0+25 から、自動プレイが途中で乗っ取られて終わることがある（借金と時間の仕組みで動きが変わった）。
        // 終わった年までに生まれているはずの足した業種が、ほぼ全部生まれていることを見る
        final due = IND_MORE.where((i) => i.b < s.year).length;
        expect(born.length, greaterThanOrEqualTo((due * .9).floor()), reason: '$seed ${s.year}年 ${s.over}');
        expect(s.cos.where((c) => c.alive).length, lessThan(5000));
      }
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('1.0.0+7 までのセーブ（足した業種がない）を読むと、次の月に足した業種の会社が知らせなしで置かれる', () {
      final g = Game.newGame(SetupConfig(mode: 'world', year: 1990, traits: ['charm', 'gambler']), rng: ParkMiller(4), extras: false);
      for (var t = 0; t < 24; t++) {
        botMonth(g);
      }
      final j = g.toJson();
      final s = Game.fromJson(j, rng: ParkMiller(5));
      expect(s.extras, isTrue);
      expect(s.lateInds, isNotEmpty);
      expect(s.lateInds.every((id) => IND_MORE.any((i) => i.id == id)), isTrue);
      final late = s.lateInds.toSet();
      botMonth(s);
      expect(s.lateInds, isEmpty);
      final held = {for (final c in s.cos) for (final b in c.biz) b.ind};
      expect(late.every(held.contains), isTrue);
      expect(s.log.where((l) => msgKey(l.m).startsWith('新しい業種')).length, lessThan(5));
    });
  });
}
