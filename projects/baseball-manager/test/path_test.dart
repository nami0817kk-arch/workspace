import 'dart:math';

import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:flutter_test/flutter_test.dart';

Player _batter(int v) => Player(
      name: 't',
      role: Role.batter,
      age: 18,
      potential: 50,
      abilities: {for (final a in batterAbilities) a: v},
    );

double _rate(Player p, double ach) {
  var n = 0;
  for (var s = 0; s < 2000; s++) {
    if (isDrafted(p, ach, Random(s))) n++;
  }
  return n / 2000;
}

void main() {
  test('一番上は確実に、一番下は絶対に指名されない', () {
    expect(_rate(_batter(95), 90), 1.0);
    expect(_rate(_batter(10), 5), 0.0);
  });

  test('境目は運しだい(0より大きく1より小さい)', () {
    final r = _rate(_batter(75), 40); // 0.7*75+0.3*40 = 64.5
    expect(r, inExclusiveRange(0.0, 1.0));
  });

  test('実績が高いほど指名されやすい', () {
    expect(_rate(_batter(70), 90), greaterThan(_rate(_batter(70), 10)));
  });

  test('目安の確率は評価に沿って単調', () {
    expect(draftChance(_batter(90), 80),
        greaterThan(draftChance(_batter(60), 30)));
    expect(draftChance(_batter(10), 0), 0.0);
  });

  test('再挑戦は大学22歳・社会人21歳、機会は1度だけ', () {
    expect(graduationAge(Course.university), 22);
    expect(graduationAge(Course.corporate), 21);
    expect(hasSecondChance(alreadyRetried: false), isTrue);
    expect(hasSecondChance(alreadyRetried: true), isFalse);
  });

  test('戦力外は低迷が2年続くと。持ち直すと数え直し', () {
    final weak = _batter(20), fine = _batter(60);
    var low = nextLowYears(weak, 0);
    expect(isReleased(low), isFalse);
    low = nextLowYears(weak, low);
    expect(isReleased(low), isTrue);
    expect(nextLowYears(fine, 1), 0);
  });

  test('年齢の強制引退と、自分で選べる範囲', () {
    final old = _batter(80).copyWith(age: maxProAge + 1);
    expect(mustRetire(old, 0), isTrue);
    expect(mustRetire(_batter(80), 0), isFalse);
    expect(canChooseRetire(Stage.pro), isTrue);
    expect(canChooseRetire(Stage.highSchool), isFalse);
  });

  group('指名順位と球団', () {
    test('余裕が大きいほど上位(1〜6位)', () {
      var prev = 7;
      for (var m = 0.0; m <= 40; m += 1) {
        final r = draftRound(m);
        expect(r, inInclusiveRange(1, 6));
        expect(r, lessThanOrEqualTo(prev));
        prev = r;
      }
      expect(draftRound(30), 1);
      expect(draftRound(0), 6);
    });

    test('球団は架空の名前で、重複しない', () {
      expect(draftTeams.toSet().length, draftTeams.length);
      expect(draftTeams.length, greaterThanOrEqualTo(6));
    });

    test('指名されると、ログに球団と順位が出る', () {
      var found = 0;
      for (var seed = 0; seed < 40 && found < 3; seed++) {
        final g = Game.newGame(
            name: 't', role: Role.batter, rng: Random(seed), potential: 95);
        var n = 0;
        while (
            g.phase != Phase.retired && g.proStartAge == null && n++ < 3000) {
          g.autoSpend();
          switch (g.phase) {
            case Phase.term:
              g.choose(g.condition.fatigue >= 60 ? Plan.rest : Plan.train,
                  Ability.contact);
            case Phase.event:
              g.resolveEvent(0);
            case Phase.pathChoice:
              g.chooseRoute(Course.university);
            case Phase.retired:
              break;
          }
        }
        if (g.proStartAge != null) {
          found++;
          final l = g.log.firstWhere((l) => l.contains('ドラフトで指名された'));
          expect(draftTeams.any(l.contains), isTrue, reason: l);
          expect(RegExp(r'[1-6]位指名').hasMatch(l), isTrue, reason: l);
          expect(draftTeams, contains(g.proTeam));
          // 保存して読み直しても残る。古いセーブ(proTeamなし)は null。
          final back = Game.fromJson(g.toJson(), Random(1));
          expect(back.proTeam, g.proTeam);
          final old = g.toJson()..remove('proTeam');
          expect(Game.fromJson(old, Random(1)).proTeam, isNull);
        }
      }
      expect(found, greaterThan(0));
    });
  });
}
