import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
}
