// 決算書（損益計算書・貸借対照表・キャッシュフロー計算書・事業ごとの損益。1.1.0+34）の数の合い方
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';

import 'support/bot.dart';
import 'support/grown.dart';

/// 丸めた記録どうしを比べるときの許し（円の丸め＋大きな額の桁落ち）
double tol(double scale, [int n = 1]) => 4.0 * n + scale.abs() * 1e-9;

/// 流れ（損益・キャッシュフロー）の鍵
bool isFlow(String k) => !k.startsWith('b:') && !k.startsWith('b0:');

/// 数年遊ばせた会社（事業4つ以上・借金・子会社か現地法人）を、月ごとに記録を見ながら作る
class FinRun {
  final Game g;
  final List<FinRec> allMonths = [];
  FinRun(this.g);
}

FinRun runFin({int seed = 2024, int years = 12, void Function(Game g, FinRec m, FinRec? prev)? each}) {
  final g = Game.newGame(SetupConfig(mode: 'endless', year: 1985, traits: const ['charm', 'careful']), rng: ParkMiller(seed));
  final r = FinRun(g);
  FinRec? prev;
  for (var m = 0; m < years * 12 && g.over == null; m++) {
    growMonth(g);
    final rec = g.books.months.last;
    r.allMonths.add(rec);
    each?.call(g, rec, prev);
    prev = rec;
  }
  return r;
}

void main() {
  group('決算書の数', () {
    late FinRun run;
    setUpAll(() {
      // 1.1.0+36 で種を 2024 → 2026 に替えた。子会社のいる業種を自社で始め直せなくなり（自動プレイの手が変わり）、
      // 2024 の盤面は12年目に事業1つになった（替える前もちょうど4つで、線の上だった）。2026 は替える前もあとも事業25前後・子会社あり・借金あり
      // 1.1.0+38 で種 2026 → 2027。倒産して出直したときに前の会社のものを片付け、1990年代に始めた会社は当たり前のITを入れて始めるようになり、
      // 2026 の盤面は12年目に事業2つになった。2027 は事業11・借金あり・子会社あり
      run = runFin(seed: 2027);
    });

    test('数年遊ばせた会社: 事業4つ以上・借金あり・子会社か現地法人あり（盤面の前提）', () {
      final g = run.g;
      // ignore: avoid_print
      print(grownSummary(g));
      expect(g.over, isNull);
      expect(g.biz.length, greaterThanOrEqualTo(4));
      expect(run.allMonths.any((m) => m.g('b:loan') + m.g('b:bond') > 0), isTrue, reason: 'どこかの月で借金がある');
      expect(run.allMonths.any((m) => m.g('b:sub') > 0), isTrue, reason: 'どこかの月で子会社か現地法人がある');
      expect(g.books.years.length, greaterThanOrEqualTo(10));
    });

    test('毎月、資産＝負債＋純資産（合わない差は 0）', () {
      for (final m in run.allMonths) {
        final a = finAssets(m.v), l = finLiabs(m.v), e = finEquity(m.v);
        expect((a - l - e).abs(), lessThan(tol(a, 20)), reason: '${m.y}年${m.q}月 資産$a 負債$l 純資産$e');
        expect(m.g('b:gap').abs(), lessThan(tol(a, 20)), reason: '${m.y}年${m.q}月 合わない差 ${m.g('b:gap')}');
      }
    });

    test('毎年、資産＝負債＋純資産', () {
      for (final y in run.g.books.years) {
        final a = finAssets(y.v), l = finLiabs(y.v), e = finEquity(y.v);
        expect((a - l - e).abs(), lessThan(tol(a, 20)), reason: '${y.y}年 資産$a 負債$l 純資産$e');
      }
    });

    test('分類していない現金の出入りは無い（どの現金の動きにも種類が付いている）', () {
      for (final m in run.allMonths) {
        expect(m.g('c:unc').abs(), lessThan(1), reason: '${m.y}年${m.q}月 分類していない出入り ${m.g('c:unc')}');
      }
    });

    test('キャッシュフローの合計は、現金の増減と合う（月ごと・年ごと）', () {
      FinRec? prev;
      for (final m in run.allMonths) {
        if (prev != null) {
          final d = m.g('b:cash') - prev.g('b:cash');
          expect((finCfAll(m.v) - d).abs(), lessThan(tol(m.g('b:cash').abs() + prev.g('b:cash').abs(), 40)), reason: '${m.y}年${m.q}月');
        }
        prev = m;
      }
      for (final y in run.g.books.years) {
        final d = y.g('b:cash') - y.g('b0:cash');
        expect((finCfAll(y.v) - d).abs(), lessThan(tol(y.g('b:cash').abs() + y.g('b0:cash').abs(), 60)), reason: '${y.y}年');
      }
    });

    test('年の損益とキャッシュフローは、その年の月の合計と合う', () {
      for (final y in run.g.books.years) {
        final ms = run.allMonths.where((m) => m.y == y.y).toList();
        expect(ms.length, y.n, reason: '${y.y}年の月の数');
        final keys = {...y.v.keys, for (final m in ms) ...m.v.keys}.where(isFlow);
        for (final k in keys) {
          final sum = ms.fold(0.0, (s, m) => s + m.g(k));
          expect((sum - y.g(k)).abs(), lessThan(tol(y.g(k), 30)), reason: '${y.y}年 $k 月の合計 $sum 年 ${y.g(k)}');
        }
        // 純利益も（行の合計から求めたもの）
        final ni = ms.fold(0.0, (s, m) => s + finNi(m.v));
        expect((ni - finNi(y.v)).abs(), lessThan(tol(finNi(y.v), 400)), reason: '${y.y}年 純利益');
        // 年の終わりの持ち物は12月の値
        expect(y.g('b:cash'), ms.last.g('b:cash'));
      }
    });

    test('事業ごとの利益の合計（−部下の給料・本社）は、全体の本業の利益と合う。売上の合計も合う', () {
      for (final y in run.g.books.years) {
        final rows = y.biz.values;
        final sumRev = rows.fold(0.0, (s, r) => s + r.rev);
        final sumPro = rows.fold(0.0, (s, r) => s + r.profit);
        final ownLabor = rows.where((r) => !r.sub).fold(0.0, (s, r) => s + r.v[2]);
        final pay = y.g('labor') - ownLabor;
        final whole = finGross(y.v) - (finSga(y.v) + y.g('c:grow') + y.g('c:misc') - y.g('dep'));
        expect((sumRev - y.g('rev')).abs(), lessThan(tol(y.g('rev'), 200)), reason: '${y.y}年 売上');
        expect((sumPro - pay - y.g('hq') - whole).abs(), lessThan(tol(y.g('rev'), 400)), reason: '${y.y}年 利益');
        // 各事業の列の合計は売上−利益（原価・人件費・家賃・広告・ほかの固定費・その他）
        for (final r in rows) {
          final cost = r.v[1] + r.v[2] + r.v[3] + r.v[4] + r.v[5] + r.v[6];
          expect((r.rev - cost - r.profit).abs(), lessThan(tol(r.rev, 40)), reason: '${y.y}年 ${r.ind}');
        }
      }
    });

    test('今年の途中の記録も、締めた月の合計', () {
      final g = run.g;
      final t = g.finThisYear();
      if (t == null) return;
      final ms = g.books.months.where((m) => m.y == t.y).toList();
      expect(ms.length, t.n);
      expect((ms.fold(0.0, (s, m) => s + m.g('rev')) - t.g('rev')).abs(), lessThan(tol(t.g('rev'), 20)));
    });

    test('月の記録は直近24か月だけ、年の記録は全部。セーブの大きさの増え方', () {
      final g = run.g;
      expect(g.books.months.length, lessThanOrEqualTo(finMonthsKeep));
      final all = jsonEncode(g.toJson()).length;
      final fin = jsonEncode(g.books.toJson()).length;
      // ignore: avoid_print
      print('セーブ全体 ${(all / 1024).round()}KB のうち決算書 ${(fin / 1024).round()}KB（年${g.books.years.length}・月${g.books.months.length}）');
      expect(fin, lessThan(all * .25), reason: '決算書の記録がセーブの4分の1を超えない');
    });

    test('セーブして読み込んでも、記録は同じで、続きも同じ', () {
      final g = run.g;
      final j1 = jsonEncode(g.toJson());
      final g2 = Game.fromJson(jsonDecode(j1) as Map<String, dynamic>, rng: ParkMiller(5));
      expect(jsonEncode(g2.toJson()), j1);
    });
  });

  test('古いセーブ（記録の無いもの）を読んでも落ちず、読んだ月から記録する。前の年は記録なし', () {
    final g = grownGame(years: 3, search: false);
    final j = g.toJson()..remove('books');
    final g2 = Game.fromJson(jsonDecode(jsonEncode(j)) as Map<String, dynamic>, rng: ParkMiller(9));
    expect(g2.books.on, isTrue);
    expect(g2.books.years, isEmpty);
    expect(g2.finYear(g2.year - 1), isNull, reason: '前の年は記録なし');
    // 読み込んだときの純資産が資本金
    final st = g2.finStocks();
    final e = st['cash']! + st['ar']! + st['pp']! + st['trap']! + st['eq']! + st['land']! + st['stk']! + st['sub']! - st['loan']! - st['bond']!;
    expect((g2.books.eCap - e).abs(), lessThan(1));
    for (var i = 0; i < 14 && g2.over == null; i++) {
      growMonth(g2);
      final m = g2.books.months.last;
      final a = finAssets(m.v);
      expect((a - finLiabs(m.v) - finEquity(m.v)).abs(), lessThan(tol(a, 20)));
    }
    expect(g2.finYears(), isNotEmpty);
  });

  test('会社を売って始め直しても、貸借は合い、差は「入れ替え」に出る', () {
    final g = grownGame(years: 4, search: false);
    final buyer = g.cos.where((c) => c.alive && c.parent != 'player' && c.rival == null).reduce((a, b) => a.cap > b.cap ? a : b);
    g.hUsed = 0;
    g.sellCompany(buyer, false);
    for (var i = 0; i < 3; i++) {
      botMonth(g, units: true);
    }
    final ms = g.books.months;
    final r = ms.reversed.take(3).toList();
    expect(r.any((m) => m.g('rst') != 0) || ms.any((m) => m.g('rst') != 0), isTrue);
    for (final m in r) {
      final a = finAssets(m.v);
      expect((a - finLiabs(m.v) - finEquity(m.v)).abs(), lessThan(tol(a, 20)), reason: '${m.y}年${m.q}月');
    }
  });

  test('土地を借りて買う・民事再生の借金の減免は、評価差額と特別利益に入り、貸借は合う', () {
    final g = grownGame(years: 3, search: false);
    // 借りて土地を買った（出来事の手と同じ動き）
    final a = 1e9;
    g.loanFromEvent(a);
    g.land = g.land + a;
    g.books.add('landNC', a);
    g.finCut();
    expect(g.books.cur['revL'] ?? 0, closeTo(0, 1));
    expect(g.books.cur['debtG'] ?? 0, closeTo(0, 1));
    // 借金の6割を減らす（民事再生と同じ動き）
    final d0 = g.debt;
    for (final l in g.loans) {
      l.amt *= .4;
    }
    g.finCut();
    expect(g.books.cur['debtG'], closeTo(d0 * .6, math.max(1, d0 * 1e-9)));
    expect(finSpGain(g.books.cur), greaterThanOrEqualTo(d0 * .6 - 1));
  });
}
