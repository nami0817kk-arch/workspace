import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/data.dart';
import 'package:ranse/engine/ending.dart';
import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/history.dart';
import 'package:ranse/engine/history_lines.dart';
import 'package:ranse/engine/life.dart';
import 'package:ranse/engine/rng.dart';
import 'package:ranse/engine/ways.dart';

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
void playOut(
  Game g,
  Rng pickRng, {
  int limit = 1500,
  void Function(Prompt p)? onPrompt,
}) {
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
      playOut(
        g,
        Rng(seed + 5),
        onPrompt: (p) {
          if (p.title == '元服' || p.title == '裳着') return;
          for (final c in p.choices) {
            expect(c.hint, isNotNull, reason: '${p.title}/${c.label} に匂わせが無い');
            expect(
              c.hint!,
              isNot(contains('%')),
              reason: '${p.title}/${c.label}',
            );
            expect(
              c.hint!,
              isNot(contains('成功率')),
              reason: '${p.title}/${c.label}',
            );
            expect(
              c.label,
              isNot(contains('%')),
              reason: '${p.title}/${c.label}',
            );
          }
        },
      );
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
        expect(
          titles.where((t) => t == '今年の重点').length,
          10,
          reason: 'seed=$seed',
        );
        final n = titles.where((t) => t != '今年の重点').length;
        scenes += n;
        // 1年に1つまで。史実の岐路はその年に必ず出るので、10年すべてで出ることもある。
        expect(n, inInclusiveRange(2, 10), reason: 'seed=$seed $titles');
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
        expect(
          g.l.flags.where((f) => f.startsWith('scene:')).length,
          lessThanOrEqualTo(10),
        );
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
        playChildhood(
          g,
          Rng(seed),
          onPrompt: (p) {
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
          },
        );
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
        playOut(
          g,
          Rng(seed + 3),
          onPrompt: (p) {
            if (p.title == '今年の重点') years.add(g.age);
          },
        );
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
          expect(
            g.prompt?.title,
            forced[hit.first],
            reason: 'seed=$seed ${hit.first}',
          );
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
        playOut(
          g,
          Rng(seed),
          onPrompt: (p) {
            if (g.has('onna') || g.l.rank == 8) return;
            expect(
              p.title,
              isNot(anyOf('出陣', '初陣', '下剋上の誘い')),
              reason: 'seed=$seed',
            );
            expect(
              p.choices.map((c) => c.label),
              isNot(contains('戦に備える')),
              reason: 'seed=$seed',
            );
          },
        );
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
        playOut(
          g,
          Rng(seed),
          limit: 200,
          onPrompt: (p) {
            if (p.title == '信長') {
              reunions++;
              expect(g.year, greaterThanOrEqualTo(1552));
            }
          },
        );
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

  group('道と死に方（最期1000本の分け目）', () {
    test('亡くなった人生には、必ず8種のどれかの死に方が付き、10の道のどれかに入る', () {
      for (var seed = 0; seed < 300; seed++) {
        final rng = Rng(seed * 7 + 3);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        playOut(g, Rng(seed));
        if (g.l.dead != null) {
          expect(kDeathKinds.keys, contains(g.l.deathKind), reason: g.l.dead);
        }
        expect(kWays.keys, contains(lifeWay(g.l)));
        if (g.age < 15) expect(lifeWay(g.l), 'young');
      }
    });

    test('多くの人生を通すと、8種の死に方と、大名・天下人以外の道がどれも現れる', () {
      final kinds = <String>{}, ways = <String>{};
      for (var seed = 0; seed < 1500; seed++) {
        final rng = Rng(seed);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        playOut(g, Rng(seed + 1));
        if (g.l.deathKind != null) kinds.add(g.l.deathKind!);
        ways.add(lifeWay(g.l));
      }
      expect(kinds, containsAll(kDeathKinds.keys));
      expect(
        ways,
        containsAll(kWays.keys.where((k) => k != 'tenka' && k != 'daimyo')),
      );
    });

    test('世の動きは史実の年表に沿う（主家を自分が継いでいなければ）', () {
      var checked = 0;
      for (var seed = 0; seed < 300; seed++) {
        final rng = Rng(seed);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        playOut(g, Rng(seed));
        if (g.isChild) continue;
        final y = g.year;
        bool alive(String n) => g.fa[n]!.alive;
        bool ruled(String n) => g.l.lord == n && g.l.maxRank >= 8;
        if (y > 1569 && !ruled('斎藤')) expect(alive('斎藤'), isFalse);
        if (y > 1583 && !ruled('武田')) expect(alive('武田'), isFalse);
        if (y > 1591 && !ruled('北条')) expect(alive('北条'), isFalse);
        if (y > 1568 && y < 1600 && g.l.maxRank < 8) {
          expect(alive('織田'), isTrue, reason: '$y');
        }
        checked++;
      }
      expect(checked, greaterThan(100));
    });

    test('世界線の出し分けの表に書いた岐路・出来事は、すべて実在する', () {
      final g = Game();
      final ids = {
        for (final s in [...g.childScenes, ...g.adultScenes]) s.id,
      };
      for (final id in skipTableIds()) {
        expect(ids, contains(id), reason: id);
      }
      final ev = {for (final e in kHistory) e.id};
      for (final id in skipEventIds()) {
        expect(ev, contains(id), reason: id);
      }
    });

    test('歴史が変わった世では、その世に合わない史実は起きず、その世だけの出来事が起きる', () {
      const cases = {
        'history_okehazama': ('imagawa', 1569, 'x_imagawa_jouraku'),
        'history_honnoji': ('nobunaga', 1585, 'x_osaka_nobunaga'),
        'history_yamazaki': ('akechi', 1584, 'x_akechi_rule'),
      };
      cases.forEach((flag, c) {
        final (line, byYear, altEvent) = c;
        var reached = 0;
        for (var seed = 0; seed < 300; seed++) {
          final rng = Rng(seed);
          final g = Game(rng: rng);
          g.start(rollBirth(rng));
          if (g.finished) continue;
          g.setFlag(flag);
          expect(worldLine(g), line);
          playOut(g, Rng(seed));
          for (final id in kSkipScenes[line]!) {
            expect(g.hasFlag('scene:$id'), isFalse, reason: '$line で $id が出た');
          }
          if (g.year > byYear && !g.isChild) {
            reached++;
            expect(g.hasFlag('h:$altEvent'), isTrue, reason: '$line $altEvent');
          }
        }
        expect(reached, greaterThan(10), reason: line);
      });
      // 今川の世では、織田は1561年に滅ぶ（自分が織田の当主でなければ）。
      for (var seed = 0; seed < 200; seed++) {
        final rng = Rng(seed);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        if (g.finished) continue;
        g.setFlag('history_okehazama');
        playOut(g, Rng(seed));
        if (g.year > 1562 && !g.isChild && g.l.maxRank < 8) {
          expect(g.fa['織田']!.alive, isFalse);
        }
      }
    });

    test('城主・家老・大名の人生も最後まで進み、岐路は匂わせだけで数字を出さない', () {
      var lordScenes = 0;
      for (final rank in [6, 8]) {
        for (var seed = 0; seed < 150; seed++) {
          final rng = Rng(seed * 13 + rank);
          final g = Game(rng: rng);
          g.start(rollBirth(rng));
          playChildhood(g, Rng(seed));
          if (g.finished) continue;
          final home = g.fa[g.l.home]!.alive ? g.l.home : g.alive.first.name;
          g.l
            ..rank = rank
            ..maxRank = rank
            ..lord = home
            ..fav = 50
            ..troops = 40
            ..gold = 80;
          playOut(
            g,
            Rng(seed + 1),
            onPrompt: (p) {
              if (p.title == '元服' || p.title == '裳着') return;
              for (final c in p.choices) {
                expect(c.hint, isNotNull, reason: '${p.title}/${c.label}');
                expect(c.hint!, isNot(contains('%')), reason: p.title);
                expect(c.hint!, isNot(contains('成功率')), reason: p.title);
              }
            },
          );
          lordScenes += g.l.flags.where((f) => f.startsWith('scene:l_')).length;
        }
      }
      expect(lordScenes, greaterThan(100));
    });

    test('どの人生にも結末（称号・最期の文・選んだ道3〜4行）が付き、共有の文に載る', () {
      final titles = <String>{};
      for (var seed = 0; seed < 400; seed++) {
        final rng = Rng(seed + 31);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        playOut(g, Rng(seed));
        final e = buildEnding(g);
        titles.add(e.title);
        expect(e.title, isNotEmpty);
        expect(e.text, isNot(contains('null')), reason: e.text);
        expect(e.title, isNot(contains('null')));
        expect(e.highlights.length, lessThanOrEqualTo(4));
        if (g.l.path.isNotEmpty) expect(e.highlights, isNotEmpty);
        for (final h in e.highlights) {
          expect(g.l.path, contains(h));
        }
        final s = shareText(g, e);
        expect(s, contains(e.title));
        expect(s, contains('分の1'));
      }
      // 道 × 死に方 × 幸福で、称号はばらける。
      expect(titles.length, greaterThan(40));
    });

    test('選んだ道の抜き出しは、初めと終わりを残し、順番を崩さない', () {
      final path = [for (var i = 0; i < 12; i++) '$i歳　出来事$i'];
      path[6] = '20歳　信長に仕えた';
      final h = pickHighlights(path);
      expect(h.length, 4);
      expect(h.first, path.first);
      expect(h.last, path.last);
      expect(h, contains('20歳　信長に仕えた'));
      expect(pickHighlights(path.take(3).toList()), path.take(3).toList());
    });

    test('死に方は保存の往復で残る', () {
      for (var seed = 0; seed < 40; seed++) {
        final rng = Rng(seed);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        playOut(g, Rng(seed));
        final (back, _) = fromJson(jsonOf(g));
        expect(back.deathKind, g.l.deathKind);
      }
    });

    test('史実の岐路（桶狭間・本能寺・長篠・関ヶ原ほか）は、その年にだけ起きる', () {
      const years = {
        '桶狭間': 1560,
        '本能寺': 1582,
        '比叡山': 1571,
        '川中島': 1561,
        '姉川': 1570,
        '三方ヶ原': 1572,
        '長篠': 1575,
        '山崎': 1582,
        '賤ヶ岳': 1583,
        '小田原評定': 1590,
        '関ヶ原': 1600,
      };
      for (var seed = 0; seed < 400; seed++) {
        final rng = Rng(seed);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        playOut(
          g,
          Rng(seed),
          onPrompt: (p) {
            final y = years[p.title];
            if (y != null) expect(g.year, y, reason: p.title);
          },
        );
      }
    });
  });
}
