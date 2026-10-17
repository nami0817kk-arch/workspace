import 'dart:math';

import 'package:baseball_manager/game/career.dart';
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
    expect(draftChance(_batter(90), 80), greaterThan(draftChance(_batter(60), 30)));
    expect(draftChance(_batter(10), 0), 0.0);
  });

  test('再挑戦は大学22歳・社会人21歳、機会は1度だけ', () {
    expect(graduationAge(Route.university), 22);
    expect(graduationAge(Route.corporate), 21);
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
}
