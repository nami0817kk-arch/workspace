import 'dart:convert';
import 'dart:math';

import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/farm.dart';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/records.dart';
import 'package:baseball_manager/game/season.dart';
import 'package:flutter_test/flutter_test.dart';

/// プロに入るまで進める。`want` が true を返す(6位=二軍かどうか)選手が見つかるまで試す。
Game _pro({required bool farm}) {
  for (var s = 0; s < 200; s++) {
    final g = Game.newGame(name: 't', role: Role.batter, rng: Random(s));
    var guard = 0;
    while (g.phase != Phase.retired && !g.turnedPro && guard++ < 3000) {
      g.autoSpend();
      switch (g.phase) {
        case Phase.term:
          g.choose(Plan.train, Ability.contact);
        case Phase.event:
          g.resolveEvent(0);
        case Phase.pathChoice:
          g.chooseRoute(Course.university);
        case Phase.retired:
          break;
      }
    }
    if (g.turnedPro && g.onFarm == farm) return g;
  }
  fail('見つからない farm=$farm');
}

void main() {
  test('6位(育成契約)だけが二軍。5位以上は一軍', () {
    expect(farmYearsFor(6), farmMaxYears);
    for (final r in [1, 2, 3, 4, 5]) {
      expect(farmYearsFor(r), 0, reason: '$r位');
    }
    expect(promoted(yearsLeft: 0, overall: 10), isTrue);
    expect(promoted(yearsLeft: 1, overall: 10), isFalse);
    expect(promoted(yearsLeft: 1, overall: promoteLine), isTrue);
  });

  test('育成契約で入団すると二軍からのスタート。ログと所属に出る', () {
    final g = _pro(farm: true);
    expect(g.farmYears, farmMaxYears);
    expect(g.onFarm, isTrue);
    expect(g.proTeamLabel, contains('二軍(育成)'));
    expect(g.log.any((l) => l.contains('育成契約での入団')), isTrue);
    expect(g.lifeLog.any((e) => e.text.contains('育成契約で入団')), isTrue);
  });

  test('一軍スタートの選手は、二軍のしるしが無い', () {
    final g = _pro(farm: false);
    expect(g.farmYears, 0);
    expect(g.proTeamLabel, g.proTeam);
  });

  test('二軍の年は、タイトル・表彰・日本一の対象外で、年俸が低い。昇格すると普通に戻る', () {
    for (var s = 0; s < 40; s++) {
      final g = _pro(farm: true);
      var guard = 0;
      while (g.phase != Phase.retired &&
          g.records.where((r) => r.stage == Stage.pro).length < 6 &&
          guard++ < 4000) {
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
      final pro = g.records.where((r) => r.stage == Stage.pro).toList();
      if (pro.length < 3) continue;
      final farmRecs = pro.where((r) => r.farm).toList();
      expect(farmRecs, isNotEmpty);
      expect(farmRecs.length, lessThanOrEqualTo(farmMaxYears));
      for (final r in farmRecs) {
        expect(r.titles, isEmpty);
        expect(r.awards, isEmpty);
      }
      // 二軍の年は、すべて最初の年(昇格したあとは二軍に戻らない)
      final firstNon = pro.indexWhere((r) => !r.farm);
      if (firstNon >= 0) {
        expect(pro.skip(firstNon).every((r) => !r.farm), isTrue);
        expect(g.log.any((l) => l.contains('一軍に昇格した')), isTrue);
      }
      // 年俸: 同じ成績なら二軍は一軍の4割
      final r0 = farmRecs.first;
      final asMain = SeasonRecord(
          age: r0.age, stage: r0.stage, line: r0.line, farm: false);
      expect(salaryOf(r0), lessThan(salaryOf(asMain)));
      return;
    }
    fail('二軍の記録が見つからない');
  });

  test('保存と読み込み。古いセーブ(二軍の項目なし)は一軍', () {
    final g = _pro(farm: true);
    final back = Game.fromJson(
        jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>, Random(1));
    expect(back.farmYears, g.farmYears);
    final old = g.toJson()..remove('farmYears');
    expect(Game.fromJson(old, Random(1)).farmYears, 0);
    final rec =
        SeasonRecord(age: 19, stage: Stage.pro, line: const Line(), farm: true);
    expect(SeasonRecord.fromJson(rec.toJson()).farm, isTrue);
    expect((rec.toJson()..remove('farm'))['farm'], isNull);
    expect(SeasonRecord.fromJson(rec.toJson()..remove('farm')).farm, isFalse);
  });
}
