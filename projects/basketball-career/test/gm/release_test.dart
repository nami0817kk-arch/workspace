import 'dart:convert';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Career setup(int years, {int salary = 100}) {
    final c = careerAt(6, 8);
    c.phase = Phase.preseason;
    c.expiring = [];
    c.me.deadCap = 0;
    c.me.deadLater = [];
    c.me.roster.first
      ..salary = salary
      ..years = years
      ..morale = 70;
    return c;
  }

  test('全額: 今季と残りの年に年俸がそのまま残る', () {
    final c = setup(3);
    final p = c.me.roster.first;
    c.release(p.id);
    expect(c.me.deadCap, 100);
    expect(c.me.deadLater, [100, 100]);
  });

  test('ストレッチ: 残りの総額を2倍＋1年に均す。今季は軽く、長く残る', () {
    final c = setup(3);
    final p = c.me.roster.first;
    c.release(p.id, mode: ReleaseMode.stretch);
    expect(c.me.deadCap, 43); // 300 / 7 を切り上げ
    expect(c.me.deadLater.length, 6);
    expect(c.me.deadCap + c.me.deadLater.fold(0, (a, b) => a + b), greaterThanOrEqualTo(300));
  });

  test('バイアウト: 3割少ない。残り1年と、気持ちの低い選手には使えない', () {
    final c = setup(3);
    final p = c.me.roster.first;
    c.release(p.id, mode: ReleaseMode.buyout);
    expect(c.me.deadCap, 70);
    expect(c.me.deadLater, [70, 70]);
    final d = setup(1);
    expect(d.releaseProblem(d.me.roster.first, ReleaseMode.buyout), isNotNull);
    expect(d.releaseProblem(d.me.roster.first, ReleaseMode.stretch), isNotNull);
    final e = setup(3);
    e.me.roster.first.morale = 30;
    expect(e.releaseProblem(e.me.roster.first, ReleaseMode.buyout), isNotNull);
  });

  test('残りは来季以降に回り、保存して読み直しても残る', () {
    final c = setup(3);
    c.release(c.me.roster.first.id);
    final back = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
    expect(back.me.deadLater, [100, 100]);
    c.phase = Phase.seasonEnd;
    c.toOffseason();
    if (!c.fired) {
      expect(c.me.deadCap, 100);
      expect(c.me.deadLater, [100]);
    }
  });
}
