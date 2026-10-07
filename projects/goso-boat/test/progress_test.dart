import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:goso_boat/app/achievements.dart';
import 'package:goso_boat/app/progress.dart';
import 'package:goso_boat/engine/puzzle.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Progress> open() async {
  SharedPreferences.setMockInitialValues({});
  final data = jsonDecode(File('assets/levels.json').readAsStringSync()) as Map<String, Object?>;
  return Progress.open((data['levels']! as List).map((e) => Level.fromJson(e as Map<String, Object?>)).toList());
}

void main() {
  test('自己ベスト: 初回は記録だけ、縮めたときだけ新記録', () async {
    final p = await open();
    final l = p.levels.first;
    expect(p.best(l), isNull);
    expect(await p.record(l, 1, trips: 9), isFalse, reason: '初回は新記録と言わない');
    expect(p.best(l), 9);
    expect(await p.record(l, 2, trips: 11), isFalse, reason: '悪くなったら記録は変えない');
    expect(p.best(l), 9);
    expect(await p.record(l, 3, trips: 3), isTrue);
    expect(p.best(l), 3);
    expect(p.stars(l), 3);
    expect(await p.record(l, 2, trips: 5), isFalse);
    expect(p.stars(l), 3, reason: '星は下げない');
  });

  test('進み具合を消すと、星と自己ベストが消える', () async {
    final p = await open();
    final l = p.levels.first;
    await p.record(l, 3, trips: 3);
    await p.resetAll();
    expect(p.stars(l), 0);
    expect(p.best(l), isNull);
  });

  test('鬼門（舞台8）は、舞台1〜7の星が200に届くまで開かない', () async {
    // 舞台7まで全部を星2で解く（102面×2＝204だが、1面だけ星1にして203）
    final p0 = await open();
    final before = p0.levels.where((l) => l.world < 8).toList();
    final saved = <String, Object>{for (final l in before) 'stars.${l.id}': 2};
    final first8 = p0.levels.firstWhere((l) => l.world == 8);

    var p = await openWith({...saved, for (final l in before.take(5)) 'stars.${l.id}': 1});
    expect(p.starsBeforeNightmare, 199);
    expect(p.unlocked(first8), isFalse);
    expect(p.nextLevel, isNot(first8), reason: '開いていない面を「つづきから」にしない');
    expect(p.stars(p.nextLevel), lessThan(3), reason: '代わりに星を取り直せる面を出す');

    p = await openWith({...saved, for (final l in before.take(4)) 'stars.${l.id}': 1});
    expect(p.starsBeforeNightmare, 200);
    expect(p.unlocked(first8), isTrue);
    expect(p.nextLevel, first8);
  });

  test('今日の1問: 解いたが星3でない面から選び、その日のあいだは変わらない', () async {
    final p = await openWith({'stars.1-1': 3, 'stars.1-2': 2, 'stars.1-3': 1});
    final day = DateTime(2026, 9, 27);
    final l = p.dailyLevel(day)!;
    expect(['1-2', '1-3'], contains(l.id));
    expect(await p.recordDaily(l, 2, day), isFalse, reason: '星3でないと達成にしない');
    expect(await p.recordDaily(l, 3, day), isTrue);
    await p.record(l, 3);
    expect(p.dailyLevel(day), l, reason: '星3にしても、その日の問題は変えない');
    expect(await p.recordDaily(l, 3, day), isFalse, reason: '1日1回');
    expect(p.dailyStreak(day), 1);
  });

  test('今日の1問: 連続日数は途切れたら数え直す', () async {
    final p = await openWith({
      'stars.1-2': 1,
      'daily.done.2026-09-24': true,
      'daily.done.2026-09-25': true,
      'daily.done.2026-09-26': true,
    });
    expect(p.dailyStreak(DateTime(2026, 9, 27)), 3, reason: '今日まだでも昨日までの連続を出す');
    expect(p.dailyStreak(DateTime(2026, 9, 28)), 0, reason: '昨日（27日）を落とすと途切れる');
    expect((await openWith({})).dailyLevel(DateTime(2026, 9, 27)), isNull, reason: 'まだ1面も解いていなければ出さない');
  });

  test('実績: 満たしたときに1回だけ取れる。脱走にも実績がある', () async {
    final p = await openWith({'stars.1-1': 1});
    expect(await collectNewAchievements(p), [Achievement.firstClear]);
    expect(await collectNewAchievements(p), isEmpty, reason: '2回目は出さない');
    await p.bump('escapes', 10);
    expect(await collectNewAchievements(p), [Achievement.escape10]);
    expect(p.hasAchievement('escape10'), isTrue);
  });

  test('挑戦回数と中断した盤面。進み具合を消すとどちらも消える', () async {
    final p = await open();
    final l = p.levels.first;
    expect(await p.addTry(l), 1);
    expect(await p.addTry(l), 2);
    await p.saveResume(l, {'trips': 2});
    expect(p.resumeFor(l), {'trips': 2});
    await p.resetAll();
    expect(p.tries(l), 0);
    expect(p.resumeFor(l), isNull);
  });

  test('最速タイム: 初回は記録だけ、縮めたときだけ最速', () async {
    final p = await open();
    final l = p.levels.first;
    expect(await p.recordTime(l, 30000), isFalse);
    expect(p.bestTime(l), 30000);
    expect(await p.recordTime(l, 40000), isFalse);
    expect(p.bestTime(l), 30000);
    expect(await p.recordTime(l, 25000), isTrue);
    expect(p.bestTime(l), 25000);
  });

  test('階級は星の合計で上がる', () async {
    var p = await openWith({});
    expect(p.rank, 0);
    expect(p.starsToNextRank, 10);
    p = await openWith({for (final id in ['1-1', '1-2', '1-3', '1-4']) 'stars.$id': 3});
    expect(p.totalStars, 12);
    expect(p.rank, 1);
    expect(p.starsToNextRank, 18);
  });

  test('実績: 舞台の全面を星3で「達人」、一発護送は記録から', () async {
    final p0 = await open();
    final w1 = p0.levels.where((l) => l.world == 1).toList();
    final p = await openWith({for (final l in w1) 'stars.${l.id}': 3});
    final got = await collectNewAchievements(p);
    expect(got, contains(Achievement.perfect1));
    expect(got, isNot(contains(Achievement.perfect2)));
    await p.bump('firstTryThree');
    expect(await collectNewAchievements(p), [Achievement.firstTryThree]);
  });

  test('最速タイム: 初回は記録だけ、縮めたときだけ最速', () async {
    final p = await open();
    final l = p.levels.first;
    expect(await p.recordTime(l, 30000), isFalse);
    expect(p.bestTime(l), 30000);
    expect(await p.recordTime(l, 40000), isFalse);
    expect(p.bestTime(l), 30000);
    expect(await p.recordTime(l, 25000), isTrue);
    expect(p.bestTime(l), 25000);
  });

  test('階級は星の合計で上がる', () async {
    var p = await openWith({});
    expect(p.rank, 0);
    expect(p.starsToNextRank, 10);
    p = await openWith({for (final id in ['1-1', '1-2', '1-3', '1-4']) 'stars.$id': 3});
    expect(p.totalStars, 12);
    expect(p.rank, 1);
    expect(p.starsToNextRank, 18);
  });

  test('実績: 舞台の全面を星3で「達人」、一発護送は記録から', () async {
    final p0 = await open();
    final w1 = p0.levels.where((l) => l.world == 1).toList();
    final p = await openWith({for (final l in w1) 'stars.${l.id}': 3});
    final got = await collectNewAchievements(p);
    expect(got, contains(Achievement.perfect1));
    expect(got, isNot(contains(Achievement.perfect2)));
    await p.bump('firstTryThree');
    expect(await collectNewAchievements(p), [Achievement.firstTryThree]);
  });
}

Future<Progress> openWith(Map<String, Object> saved) async {
  SharedPreferences.setMockInitialValues(saved);
  final data = jsonDecode(File('assets/levels.json').readAsStringSync()) as Map<String, Object?>;
  return Progress.open((data['levels']! as List).map((e) => Level.fromJson(e as Map<String, Object?>)).toList());
}
