import 'dart:math';

import 'package:baseball_manager/game/fielding.dart';
import 'package:baseball_manager/game/flavor.dart';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/awards.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/records.dart';
import 'package:baseball_manager/game/season.dart';
import 'package:flutter_test/flutter_test.dart';

Player _p(int fielding, {Role role = Role.batter, String name = 'テスト'}) =>
    Player(name: name, role: role, age: 25, potential: 60, abilities: {
      for (final a in abilitiesOf(role))
        a: a == Ability.fielding ? fielding : 50
    });

void main() {
  test('守備力が高いほど失策率が低い(10→3.2%・50→1.9%・99→0.2%)', () {
    expect(errorRate(10), closeTo(0.032, 0.001));
    expect(errorRate(50), closeTo(0.0185, 0.001));
    expect(errorRate(99), closeTo(0.0023, 0.001));
    expect(errorRate(99), lessThan(errorRate(50)));
    for (var f = 0; f <= 99; f++) {
      expect(errorRate(f), inInclusiveRange(0.002, 0.04));
    }
  });

  test('投手と指名打者は守備の記録が無い。野手は守備機会と守備率が出る', () {
    expect(
        fieldingOf(
                player: _p(60, role: Role.pitcher),
                pos: Pos.starter,
                games: 30,
                age: 25)
            .chances,
        0);
    expect(fieldingOf(player: _p(60), pos: Pos.dh, games: 143, age: 25).chances,
        0);
    final f =
        fieldingOf(player: _p(60), pos: Pos.shortstop, games: 143, age: 25);
    expect(f.chances, (4.2 * 143).round());
    expect(f.errors, greaterThanOrEqualTo(0));
    expect(f.pct, inInclusiveRange(0.9, 1.0));
    expect(const FieldingLine(0, 0).pct, isNull);
  });

  test('守備力が高い選手ほど守備率が高い(平均)。同じ選手の同じ年は毎回同じ', () {
    double avg(int fielding) {
      var sum = 0.0;
      for (var i = 0; i < 200; i++) {
        sum += fieldingOf(
                player: _p(fielding, name: 'n$i'),
                pos: Pos.second,
                games: 143,
                age: 20 + i % 15)
            .pct!;
      }
      return sum / 200;
    }

    expect(avg(95), greaterThan(avg(50)));
    expect(avg(50), greaterThan(avg(10)));
    expect(avg(95), greaterThan(0.995));
    expect(avg(50), inInclusiveRange(0.975, 0.99));
    final a = fieldingOf(
        player: _p(70, name: 'さくら'), pos: Pos.third, games: 140, age: 27);
    final b = fieldingOf(
        player: _p(70, name: 'さくら'), pos: Pos.third, games: 140, age: 27);
    expect(a.errors, b.errors);
  });

  test('ゴールデングラブ: 守備力・出場に加えて、守備率が低ければ付かない', () {
    final l = const Line(games: 140, atBats: 500, hits: 130, walks: 50);
    List<String> aw(double? pct) => awardsOf(l,
        games: 143,
        firstYear: false,
        prevGames: 143,
        fielding: 80,
        isBatter: true,
        fieldingPct: pct);
    expect(aw(0.995), contains('ゴールデングラブ'));
    expect(aw(0.980), isNot(contains('ゴールデングラブ')));
    expect(aw(null), contains('ゴールデングラブ')); // 古い記録(守備率なし)は従来どおり
  });

  test('一生を遊ぶと、プロの野手の記録に守備の数字が付く。保存で残り、古い記録は0', () {
    for (var seed = 0; seed < 40; seed++) {
      final g = Game.newGame(
          name: 'a', role: Role.batter, rng: Random(seed), potential: 100);
      var guard = 0;
      while (g.phase != Phase.retired && guard++ < 4000) {
        switch (g.phase) {
          case Phase.term:
            g.autoSpend();
            // 打撃型の選手は指名打者(守らない)になりやすいので、遊撃手に決める。
            if (g.canChoosePosition) g.choosePosition(Pos.shortstop);
            g.choose(Plan.train, Ability.contact);
          case Phase.event:
            g.resolveEvent(0);
          case Phase.pathChoice:
            g.chooseRoute(Course.university);
          case Phase.retired:
            break;
        }
      }
      final pro = g.records.where((r) => r.isLeague).toList();
      if (pro.isEmpty) continue;
      final withField = pro.where((r) => r.chances > 0).toList();
      if (withField.isEmpty) continue; // 指名打者(守らない)の選手は飛ばす
      for (final r in withField) {
        expect(r.errors, lessThanOrEqualTo(r.chances));
        expect(r.fieldingPct, inInclusiveRange(0.9, 1.0));
      }
      final r = withField.first;
      final back = SeasonRecord.fromJson(r.toJson());
      expect(back.chances, r.chances);
      expect(back.errors, r.errors);
      final old = SeasonRecord.fromJson(r.toJson()
        ..remove('chances')
        ..remove('errors'));
      expect(old.chances, 0);
      expect(old.fieldingPct, isNull);
      return;
    }
    fail('プロに入った例が無い');
  });
}
