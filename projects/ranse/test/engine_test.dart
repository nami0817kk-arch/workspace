import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/data.dart';
import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/life.dart';
import 'package:ranse/engine/rng.dart';

/// 選択肢が出たらランダムに選び、出なければ行動をランダムに選んで、終わるまで進める。
void playOut(Game g, Rng pickRng, {int limit = 600}) {
  var n = 0;
  while (!g.finished && n++ < limit) {
    if (g.prompt != null) {
      g.choose(pickRng.range(0, g.prompt!.choices.length - 1));
      continue;
    }
    if (g.isChild) {
      g.doAct(pickRng.pick(g.childActions).id);
      continue;
    }
    final ok = g.availableActions().where((a) => a.dis == null || a.dis!() == null).toList();
    g.doAct(pickRng.pick(ok).id);
  }
}

void main() {
  test('どんな生まれでも最後まで進み、例外を出さない', () {
    for (var seed = 0; seed < 400; seed++) {
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
      return '${g.l.name}/${g.age}/${g.l.maxRank}/${g.l.dead ?? g.l.end}/${g.score}';
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
      if (g.l.dead != null) died++;
    }
    final rate = died / n;
    expect(rate, greaterThan(.10));
    expect(rate, lessThan(.30));
  });

  test('保存して復元しても人生が変わらない', () {
    final rng = Rng(3);
    final g = Game(rng: rng);
    g.start(rollBirth(rng));
    // 選択肢が出ていない区切りまで進める。
    var n = 0;
    while (n++ < 60 && !g.finished) {
      if (g.prompt != null) {
        g.choose(0);
        continue;
      }
      if (g.age >= 20) break;
      if (g.isChild) {
        g.doAct(g.childActions.first.id);
      } else {
        g.doAct('rest');
      }
    }
    expect(g.prompt, isNull);
    final json = jsonEncode({
      'life': g.l.toJson(),
      'world': g.fa.values.map((f) => f.toJson()).toList(),
    });
    final back = jsonDecode(json) as Map<String, dynamic>;
    final life = Life.fromJson(back['life'] as Map<String, dynamic>);
    expect(jsonEncode(life.toJson()), jsonEncode(g.l.toJson()));
    final world = (back['world'] as List)
        .map((e) => Faction.fromJson(e as Map<String, dynamic>))
        .toList();
    expect(world.length, g.fa.length);
    expect(world.first.power, closeTo(g.fa[world.first.name]!.power, 1e-9));
  });

  test('女性は合戦に出られない（女武者と当主を除く）', () {
    for (var seed = 0; seed < 300; seed++) {
      final rng = Rng(seed);
      final g = Game(rng: rng);
      g.start(rollBirth(rng));
      if (!g.l.female || g.l.dead != null) continue;
      var n = 0;
      while (!g.finished && n++ < 300) {
        if (g.prompt != null) {
          g.choose(rng.range(0, g.prompt!.choices.length - 1));
          continue;
        }
        if (!g.isChild && !g.has('onna') && g.l.rank != 8) {
          final ids = g.availableActions().map((a) => a.id);
          expect(ids.contains('war'), isFalse, reason: 'seed=$seed');
          expect(ids.contains('betray'), isFalse, reason: 'seed=$seed');
        }
        if (g.isChild) {
          g.doAct(g.childActions.first.id);
        } else {
          g.doAct('rest');
        }
      }
    }
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

    // 大名の子は6000回では出ないこともある。出たときだけ比べる。
    if (daimyo.isNotEmpty) {
      expect(median(daimyo), greaterThan(median(farmer) * 100));
    }
    // 同じ身分の人数: 農民は数百万人、大名の子は数百人以下。
    final cls = kClasses.firstWhere((c) => c.id == 'daimyo');
    final total = kClasses.fold<double>(0, (s, c) => s + c.w);
    expect(kPopulation * cls.w / total, lessThan(1000));
  });

  test('1600年を過ぎると乱世が終わる', () {
    final rng = Rng(5);
    final g = Game(rng: rng);
    g.start(rollBirth(rng));
    playOut(g, Rng(5));
    if (g.l.dead == null) {
      expect(g.l.end, anyOf('era', 'victory'));
    }
  });
}
