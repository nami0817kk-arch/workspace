import 'dart:convert';
import 'dart:math';

import 'package:baseball_manager/game/achievements.dart';
import 'package:baseball_manager/game/after_career.dart';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

SecondCareer _career(
  AfterPath p, {
  int peak = 70,
  int titles = 0,
  int champs = 0,
  int pop = 30,
  int money = 10000,
  int years = 12,
  bool married = false,
}) =>
    secondCareerOf(p,
        name: 'テスト',
        peak: peak,
        titles: titles,
        championships: champs,
        popularity: pop,
        money: money,
        proYears: years,
        married: married,
        team: '青波ホークス');

Game _retiredPro() {
  for (var s = 0; s < 80; s++) {
    final g = Game.newGame(
        name: 'a', role: Role.batter, rng: Random(s), potential: 100);
    var guard = 0;
    while (g.phase != Phase.retired && guard++ < 4000) {
      switch (g.phase) {
        case Phase.term:
          g.autoSpend();
          g.choose(Plan.train, Ability.contact);
        case Phase.event:
          g.resolveEvent(0);
        case Phase.pathChoice:
          g.chooseRoute(Course.university);
        case Phase.retired:
          break;
      }
    }
    if (g.ending!.madePro) return g;
  }
  fail('プロを引退した例が無い');
}

void main() {
  test('道は5つ。名前・説明がある', () {
    expect(AfterPath.values.length, 5);
    for (final p in AfterPath.values) {
      expect(p.label, isNotEmpty);
      expect(p.description, isNotEmpty);
      expect(AfterPath.parse(p.name), p);
    }
    expect(AfterPath.parse('xx'), isNull);
    expect(AfterPath.parse(null), isNull);
  });

  test('成績・人気・資産が高いほど結果が良い(道ごとに効く項目が違う)', () {
    // 監督: 総合評価・優勝・タイトル
    expect(_career(AfterPath.manager, peak: 95, champs: 6, titles: 8).tier, 2);
    expect(_career(AfterPath.manager, peak: 50, champs: 0, titles: 0).tier, 0);
    // 解説者: 人気とタイトル
    expect(_career(AfterPath.commentator, pop: 95, titles: 6).tier, 2);
    expect(
        _career(AfterPath.commentator, pop: 10, titles: 0, peak: 40).tier, 0);
    // 実業家: 資産
    expect(_career(AfterPath.business, money: 250000).tier, 2);
    expect(_career(AfterPath.business, money: 0, pop: 0).tier, 0);
    // 少年野球の指導者: 年数と家族
    expect(_career(AfterPath.teacher, years: 18, married: true, peak: 80).tier,
        greaterThanOrEqualTo(1));
    // 同じ入力なら同じ結果
    final a = _career(AfterPath.coach, peak: 85, titles: 4);
    final b = _career(AfterPath.coach, peak: 85, titles: 4);
    expect(a.lines, b.lines);
    // どの結果にも物語が1行以上ある
    for (final p in AfterPath.values) {
      for (final t in [(40, 0, 0, 5, 0, 3), (90, 8, 6, 95, 250000, 20)]) {
        final c = _career(p,
            peak: t.$1,
            titles: t.$2,
            champs: t.$3,
            pop: t.$4,
            money: t.$5,
            years: t.$6);
        expect(c.lines, isNotEmpty);
        expect(c.tierLabel, isNotEmpty);
      }
    }
  });

  test('引退したプロ選手だけが道を選べる。選ぶと物語が出て、保存で残る', () {
    final g = _retiredPro();
    expect(g.afterPath, isNull);
    expect(g.secondCareer, isNull);
    g.chooseAfterPath(AfterPath.commentator);
    expect(g.afterPath, AfterPath.commentator);
    expect(g.secondCareer!.lines, isNotEmpty);
    // 選び直せる
    g.chooseAfterPath(AfterPath.business);
    expect(g.afterPath, AfterPath.business);
    final back = Game.fromJson(
        jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>, Random(1));
    expect(back.afterPath, AfterPath.business);
    expect(back.secondCareer!.tier, g.secondCareer!.tier);
    // 古いセーブ(項目なし)は道なし
    final old = g.toJson()..remove('afterPath');
    expect(Game.fromJson(old, Random(1)).afterPath, isNull);
    // プロを引退していない(プロになれなかった・途中)選手は選べない
    final mid = Game.newGame(name: 'a', role: Role.batter, rng: Random(1));
    expect(() => mid.chooseAfterPath(AfterPath.coach), throwsStateError);
  });

  test('スナップショットに道と結果の段階が残り、実績になる', () {
    final g = _retiredPro();
    expect(PlayerSnapshot.fromGame(g).afterPath, isNull);
    g.chooseAfterPath(AfterPath.teacher);
    final snap = PlayerSnapshot.fromGame(g);
    expect(snap.afterPath, 'teacher');
    expect(snap.afterTier, g.secondCareer!.tier);
    final back = PlayerSnapshot.fromJson(snap.toJson());
    expect(back.afterPath, 'teacher');
    expect(back.afterTier, snap.afterTier);
    expect(earnedBy(snap), contains('second-career'));
    expect(earnedBy(PlayerSnapshot.fromJson(snap.toJson()..['afterTier'] = 2)),
        contains('second-career-star'));
    expect(earnedBy(PlayerSnapshot.fromJson(snap.toJson()..['afterTier'] = 1)),
        isNot(contains('second-career-star')));
    // 古い記録(道なし)
    expect(
        earnedBy(PlayerSnapshot.fromJson(snap.toJson()
          ..remove('afterPath')
          ..remove('afterTier'))),
        isNot(contains('second-career')));
  });
}
