import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/data.dart';
import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/life.dart';
import 'package:ranse/engine/rng.dart';

/// 生き延びて元服まで進める生まれを探して始める。
Game startSurvivor(int seed) {
  final rng = Rng(seed);
  var g = Game(rng: rng);
  var guard = 0;
  do {
    g = Game(rng: rng);
    g.start(rollBirth(rng));
  } while (g.finished && guard++ < 50);
  return g;
}

/// 選択肢をランダムに選び、人生の終わりまで進める。
/// どの年も、選択肢（今年の重点か岐路）が必ず出ていること。
void playOut(Game g, Rng pickRng, {int limit = 1500, void Function(Prompt p)? onPrompt}) {
  var n = 0;
  while (!g.finished && n++ < limit) {
    final p = g.prompt;
    expect(p, isNotNull, reason: '人生の途中なのに選択肢が出ていない（${g.age}歳）');
    onPrompt?.call(p!);
    g.choose(pickRng.range(0, p!.choices.length - 1));
  }
}

/// 幼少期だけを、ランダムに選んで最後まで進める（元服の手前まで）。
void playChildhood(Game g, Rng pickRng, {void Function(Prompt p)? onPrompt}) {
  var n = 0;
  while (!g.finished && g.isChild && n++ < 200) {
    final p = g.prompt;
    expect(p, isNotNull, reason: '幼少期なのに選択肢が出ていない');
    onPrompt?.call(p!);
    g.choose(pickRng.range(0, p!.choices.length - 1));
  }
}

String jsonOf(Game g) => jsonEncode({
      'life': g.l.toJson(),
      'world': g.fa.values.map((f) => f.toJson()).toList(),
    });

(Life, Map<String, Faction>) fromJson(String s) {
  final back = jsonDecode(s) as Map<String, dynamic>;
  final life = Life.fromJson(back['life'] as Map<String, dynamic>);
  final world = {
    for (final e in (back['world'] as List))
      (e as Map<String, dynamic>)['n'] as String: Faction.fromJson(e),
  };
  return (life, world);
}

void main() {
  test('どんな生まれでも最後まで進み、例外を出さない', () {
    for (var seed = 0; seed < 300; seed++) {
      final rng = Rng(seed);
      final g = Game(rng: rng);
      g.start(rollBirth(rng));
      playOut(g, Rng(seed + 10000));
      expect(g.finished, isTrue, reason: 'seed=$seed が終わらない');
      expect(g.l.dead != null || g.l.end != null, isTrue);
    }
  });

  test('同じ種なら同じ人生になる', () {
    String run(int seed) {
      final rng = Rng(seed);
      final g = Game(rng: rng);
      g.start(rollBirth(rng));
      playOut(g, Rng(seed + 1));
      return '${g.l.name}/${g.age}/${g.l.maxRank}/${g.l.dead ?? g.l.end}/${g.score}/${g.l.path.join('|')}';
    }

    expect(run(7), run(7));
  });

  test('乳幼児の死亡は五人に一人くらい（10〜30%）', () {
    var died = 0;
    const n = 3000;
    for (var i = 0; i < n; i++) {
      final rng = Rng(i);
      final g = Game(rng: rng);
      g.start(rollBirth(rng));
      if (g.l.dead != null && g.age < 5) died++;
    }
    final rate = died / n;
    expect(rate, greaterThan(.10));
    expect(rate, lessThan(.30));
  });

  test('岐路の選択肢は結果を匂わせる一言を持ち、数字（成功率）は出さない（一生を通して）', () {
    for (var seed = 0; seed < 200; seed++) {
      final rng = Rng(seed);
      final g = Game(rng: rng);
      g.start(rollBirth(rng));
      playOut(g, Rng(seed + 5), onPrompt: (p) {
        if (p.title == '元服' || p.title == '裳着') return;
        for (final c in p.choices) {
          expect(c.hint, isNotNull, reason: '${p.title}/${c.label} に匂わせが無い');
          expect(c.hint!, isNot(contains('%')), reason: '${p.title}/${c.label}');
          expect(c.hint!, isNot(contains('成功率')), reason: '${p.title}/${c.label}');
          expect(c.label, isNot(contains('%')), reason: '${p.title}/${c.label}');
        }
      });
    }
  });

  group('幼少期', () {
    test('毎年「今年の重点」を選び、その途中で岐路が起きる', () {
      var checked = 0, scenes = 0;
      for (var seed = 0; seed < 200; seed++) {
        final rng = Rng(seed);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        if (g.finished) continue;
        final titles = <String>[];
        playChildhood(g, Rng(seed), onPrompt: (p) => titles.add(p.title));
        if (g.l.dead != null) continue;
        checked++;
        expect(titles.where((t) => t == '今年の重点').length, 10, reason: 'seed=$seed');
        final n = titles.where((t) => t != '今年の重点').length;
        scenes += n;
        expect(n, inInclusiveRange(2, 9), reason: 'seed=$seed $titles');
        expect(g.prompt?.title, anyOf('元服', '裳着'), reason: 'seed=$seed');
        expect(g.age, 15);
      }
      expect(checked, greaterThan(100));
      expect(scenes / checked, inInclusiveRange(4, 8));
    });

    test('選んだ道が歩んだ道・縁のある人・旗として残る', () {
      var withPath = 0, withPeople = 0, total = 0;
      for (var seed = 0; seed < 300; seed++) {
        final rng = Rng(seed);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        if (g.finished) continue;
        playChildhood(g, Rng(seed + 9));
        if (g.l.dead != null) continue;
        total++;
        if (g.l.path.isNotEmpty) withPath++;
        if (g.l.people.isNotEmpty) withPeople++;
        expect(g.l.flags.where((f) => f.startsWith('scene:')).length, lessThanOrEqualTo(10));
      }
      expect(withPath / total, greaterThan(.8));
      expect(withPeople / total, greaterThan(.3));
    });

    test('有名人との出会いは、史実の年代にだけ起きる', () {
      var seen = 0;
      for (var seed = 0; seed < 2500; seed++) {
        final rng = Rng(seed);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        if (g.finished) continue;
        playChildhood(g, Rng(seed), onPrompt: (p) {
          if (p.title == '城下の若殿') {
            seen++;
            expect(g.l.region, '尾張');
            expect(g.year, inInclusiveRange(1542, 1546));
          }
          if (p.title == '寺の少年') {
            seen++;
            expect(g.l.region, '越後');
            expect(g.year, inInclusiveRange(1537, 1543));
          }
        });
      }
      expect(seen, greaterThan(0), reason: '2500人で一度も出会いが起きない');
    });

    test('幼少期の途中で保存した状態から、その年を最初からやり直せる', () {
      final saved = <String>[];
      final rng = Rng(3);
      var g = Game(rng: rng, onCheckpoint: (g) => saved.add(jsonOf(g)));
      var guard = 0;
      g.start(rollBirth(rng));
      while (g.finished && guard++ < 50) {
        g = Game(rng: rng, onCheckpoint: (g) => saved.add(jsonOf(g)));
        g.start(rollBirth(rng));
      }
      expect(g.finished, isFalse);
      expect(saved, isNotEmpty, reason: '年の始まりで保存していない');
      final (life, world) = fromJson(saved.last);
      final g2 = Game(rng: Rng(99));
      g2.restore(life, world);
      expect(g2.prompt?.title, '今年の重点');
      expect(g2.l.name, g.l.name);
      expect(g2.age, inInclusiveRange(5, 14));
    });
  });

  group('大人（15歳〜）', () {
    test('元服のあとも毎年「今年の重点」が一度ずつ出る', () {
      var checked = 0;
      for (var seed = 0; seed < 150; seed++) {
        final g = startSurvivor(seed);
        if (g.finished) continue;
        playChildhood(g, Rng(seed));
        if (g.finished) continue;
        g.choose(0); // 元服
        final years = <int>[];
        playOut(g, Rng(seed + 3), onPrompt: (p) {
          if (p.title == '今年の重点') years.add(g.age);
        });
        if (years.isEmpty) continue;
        checked++;
        // 同じ年に二度聞かれない。年は一つずつ進む。
        for (var i = 1; i < years.length; i++) {
          expect(years[i], years[i - 1] + 1, reason: 'seed=$seed $years');
        }
        expect(years.first, 15);
      }
      expect(checked, greaterThan(80));
    });

    test('重点で選んだ年には、その岐路が必ず起きる（仕官・出陣・縁談）', () {
      for (var seed = 0; seed < 200; seed++) {
        final g = startSurvivor(seed);
        if (g.finished) continue;
        playChildhood(g, Rng(seed));
        if (g.finished) continue;
        g.choose(0); // 元服
        var n = 0;
        while (!g.finished && n++ < 30) {
          final p = g.prompt!;
          if (p.title != '今年の重点') {
            g.choose(0);
            continue;
          }
          final labels = p.choices.map((c) => c.label).toList();
          const forced = {
            '仕官の口を探す': '仕官',
            '奉公先を探す': '奉公先',
            '妻を探す': '縁談',
            '嫁ぎ先を探す': '縁談',
          };
          final hit = forced.keys.where(labels.contains).toList();
          if (hit.isEmpty) {
            g.choose(0);
            continue;
          }
          g.choose(labels.indexOf(hit.first));
          if (g.finished) break;
          expect(g.prompt?.title, forced[hit.first], reason: 'seed=$seed ${hit.first}');
          g.choose(0);
        }
      }
    });

    test('「戦に備える」を選ぶと、最初は初陣、そのあとは出陣になる', () {
      var firsts = 0, battles = 0;
      for (var seed = 0; seed < 300; seed++) {
        final g = startSurvivor(seed);
        if (g.finished) continue;
        playChildhood(g, Rng(seed));
        if (g.finished) continue;
        g.choose(0);
        var n = 0;
        while (!g.finished && n++ < 40) {
          final p = g.prompt!;
          if (p.title == '今年の重点' && p.choices.any((c) => c.label == '戦に備える')) {
            final had = g.hasFlag('first_battle');
            g.choose(p.choices.indexWhere((c) => c.label == '戦に備える'));
            if (g.finished) break;
            expect(g.prompt?.title, had ? '出陣' : '初陣', reason: 'seed=$seed');
            had ? battles++ : firsts++;
            // 後詰め（いちばん安全）を選んで進める。
            final q = g.prompt!;
            g.choose(q.title == '出陣' ? 2 : 1);
            continue;
          }
          g.choose(0);
        }
      }
      expect(firsts, greaterThan(0));
      expect(battles, greaterThan(0));
    });

    test('女性は合戦・下剋上の岐路に出ない（女武者と当主を除く）', () {
      for (var seed = 0; seed < 400; seed++) {
        final rng = Rng(seed);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        if (!g.l.female || g.finished) continue;
        playOut(g, Rng(seed), onPrompt: (p) {
          if (g.has('onna') || g.l.rank == 8) return;
          expect(p.title, isNot(anyOf('出陣', '初陣', '下剋上の誘い')), reason: 'seed=$seed');
          expect(p.choices.map((c) => c.label), isNot(contains('戦に備える')), reason: 'seed=$seed');
        });
      }
    });

    test('幼い日に信長と遊んだ人は、のちに信長と再会しうる（史実の年代で）', () {
      var reunions = 0;
      for (var seed = 0; seed < 6000 && reunions == 0; seed++) {
        final rng = Rng(seed);
        final b = rollBirth(rng);
        if (b.region.n != '尾張') continue;
        final g = Game(rng: rng);
        g.start(b);
        if (g.finished) continue;
        playChildhood(g, Rng(seed));
        if (g.finished || !g.hasFlag('met_nobunaga')) continue;
        g.choose(0);
        playOut(g, Rng(seed), limit: 200, onPrompt: (p) {
          if (p.title == '信長') {
            reunions++;
            expect(g.year, greaterThanOrEqualTo(1552));
          }
        });
      }
      expect(reunions, greaterThan(0), reason: '信長との再会が一度も起きない');
    });

    test('大人の途中で保存しても、旗・縁・道を含めて往復でき、その年から再開できる', () {
      final saved = <String>[];
      final rng = Rng(3);
      var g = Game(rng: rng, onCheckpoint: (g) => saved.add(jsonOf(g)));
      var guard = 0;
      do {
        g = Game(rng: rng, onCheckpoint: (g) => saved.add(jsonOf(g)));
        g.start(rollBirth(rng));
        playChildhood(g, Rng(1));
      } while (g.finished && guard++ < 50);
      g.choose(0); // 元服 → 15歳の年の始まりで保存される
      expect(g.prompt?.title, '今年の重点');
      final last = saved.last;
      final (life, world) = fromJson(last);
      expect(jsonEncode(life.toJson()), jsonEncode(g.l.toJson()));
      expect(life.path, g.l.path);
      expect(life.flags, g.l.flags);
      expect(life.people.keys, g.l.people.keys);
      expect(life.focus, g.l.focus);
      final g2 = Game(rng: Rng(42));
      g2.restore(life, world);
      expect(g2.prompt?.title, '今年の重点');
      expect(g2.age, 15);
      expect(world.length, g.fa.length);
    });
  });

  test('生まれの稀少度: 大名の子は農民より桁違いに珍しい', () {
    final rng = Rng(1);
    final daimyo = <double>[], farmer = <double>[];
    for (var i = 0; i < 6000; i++) {
      final b = rollBirth(rng);
      expect(b.rarity, greaterThan(1));
      if (b.cls.id == 'daimyo') daimyo.add(b.rarity);
      if (b.cls.id == 'farmer') farmer.add(b.rarity);
    }
    expect(farmer, isNotEmpty);
    double median(List<double> l) {
      l.sort();
      return l[l.length ~/ 2];
    }

    if (daimyo.isNotEmpty) {
      expect(median(daimyo), greaterThan(median(farmer) * 100));
    }
    final cls = kClasses.firstWhere((c) => c.id == 'daimyo');
    final total = kClasses.fold<double>(0, (s, c) => s + c.w);
    expect(kPopulation * cls.w / total, lessThan(1000));
  });

  test('1600年を過ぎると乱世が終わる', () {
    for (var seed = 0; seed < 40; seed++) {
      final rng = Rng(seed);
      final g = Game(rng: rng);
      g.start(rollBirth(rng));
      playOut(g, Rng(seed));
      if (g.l.dead == null) {
        expect(g.l.end, anyOf('era', 'victory'));
      }
      if (g.l.end == 'era') expect(g.year, greaterThan(1600));
    }
  });
}
