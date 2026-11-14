import 'dart:convert';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/game_sim.dart';
import 'package:basketball_career/gm/personality.dart';
import 'package:basketball_career/gm/player.dart';
import 'package:basketball_career/gm/rng.dart';
import 'package:flutter_test/flutter_test.dart';

/// [t] の性格だけを持つ(2つ目の性格が無い)選手の id を探す。
int _idWith(Trait t, {int from = 1}) {
  for (var id = from;; id++) {
    final p = personalityOf(_player(id));
    if (p.traits.length == 1 && p.traits.first == t) return id;
  }
}

Player _player(int id, {int age = 24, int ovr = 60, int pot = 75}) =>
    Player(id: id, name: '選手$id', pos: Pos.sf, age: age, ovr: ovr, pot: pot, salary: 30, years: 2, exp: 3);

void main() {
  test('出場時間: 若手はよく出ると伸び、ほとんど出ないと伸びが削られる', () {
    final id = _idWith(Trait.leader);
    final starter = _player(id)..stats = Stats(gp: 70, min: 70 * 31);
    expect(extraGrowth(starter, 2), [('出場時間', 1)]);
    final bench = _player(id)..stats = Stats(gp: 10, min: 40);
    expect(extraGrowth(bench, 2), [('出場時間', -1)]);
    // 伸びしろに届いていれば、出場時間でも伸びない
    final capped = _player(id, ovr: 75, pot: 75)..stats = Stats(gp: 70, min: 70 * 31);
    expect(extraGrowth(capped, 0), isEmpty);
    // 30歳は出場時間で変わらない
    final vet = _player(id, age: 30)..stats = Stats(gp: 10, min: 40);
    expect(extraGrowth(vet, -1), isEmpty);
  });

  test('練習の虫は若いうちに伸び、年を取っても落ちにくい。遅咲きは24〜28歳で伸びる', () {
    final g = _idWith(Trait.grinder);
    final full = Stats(gp: 50, min: 50 * 20);
    expect(extraGrowth(_player(g)..stats = full, 1), [('練習の虫', 1)]);
    expect(extraGrowth(_player(g, age: 32)..stats = full, -3), [('練習の虫', 1)]);
    final lb = _idWith(Trait.lateBloomer);
    expect(extraGrowth(_player(lb, age: 21)..stats = full, 4), [('遅咲き', -1)]);
    expect(extraGrowth(_player(lb, age: 26)..stats = full, 0), [('遅咲き', 1)]);
  });

  test('けがしがち・ムラっ気・安定感の数字', () {
    expect(injuryProne(_player(_idWith(Trait.fragile))), 1.6);
    expect(injuryProne(_player(_idWith(Trait.leader))), 1.0);
    expect(formRange(_player(_idWith(Trait.streaky))), greaterThan(formRange(_player(_idWith(Trait.leader)))));
    expect(formRange(_player(_idWith(Trait.steady))), lessThan(formRange(_player(_idWith(Trait.leader)))));
  });

  test('試合ごとの調子は、性格で決まる幅の中で散らばる', () {
    final c = careerAt(3, 8);
    final t = c.me;
    final star = t.order.first;
    final forms = <double>[];
    for (var s = 0; s < 200; s++) {
      final sim = simulateGame(t, c.teams[(c.mine + 1) % 30], Rng(s), homeStr: t.strength, awayStr: c.teams[(c.mine + 1) % 30].strength);
      forms.add(sim.home.form[0]);
    }
    final r = formRange(star);
    expect(forms.every((f) => f.abs() <= r + 1e-9), isTrue);
    expect(forms.reduce((a, b) => a > b ? a : b), greaterThan(r * 0.8));
  });

  test('オフの成長: 自分の選手の伸びに内訳が付き、保存して読み直せる', () {
    final c = careerAt(6, 8);
    var guard = 0;
    while (c.phase != Phase.seasonEnd && guard++ < 200) {
      botStep(c);
    }
    c.toOffseason();
    expect(c.growth, isNotEmpty);
    expect(c.growth.where((g) => g.parts.isNotEmpty), isNotEmpty);
    for (final g in c.growth) {
      // 力の端(35と99)で止まらなければ、内訳の合計が伸びと同じ
      if (g.after > 36 && g.after < 98 && g.before > 36) {
        expect(g.parts.fold(0, (n, x) => n + x.$2), g.delta, reason: '${g.name} ${g.parts}');
      }
    }
    final back = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
    expect([for (final g in back.growth) g.parts], [for (final g in c.growth) g.parts]);
  });
}
