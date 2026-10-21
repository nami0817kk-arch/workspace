import 'dart:math';

import 'package:basketball_career/game/advice.dart';
import 'package:basketball_career/game/epilogue.dart';
import 'package:basketball_career/game/game.dart';
import 'package:basketball_career/game/legacy.dart';
import 'package:basketball_career/game/life.dart';
import 'package:basketball_career/game/match.dart';
import 'package:basketball_career/game/money.dart';
import 'package:basketball_career/game/path.dart';
import 'package:basketball_career/game/player.dart';
import 'package:basketball_career/game/season.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('お金の表示と年俸', () {
    test('moneyLabel: 万円・億円を読みやすく', () {
      expect(moneyLabel(0), '0円');
      expect(moneyLabel(400), '400万円');
      expect(moneyLabel(1650), '1,650万円');
      expect(moneyLabel(10000), '1億円');
      expect(moneyLabel(12500), '1億2,500万円');
      expect(moneyLabel(123456), '12億3,456万円');
    });

    test('新人契約はドラフトの順位が高いほど高い', () {
      expect(rookieSalary(1), greaterThan(rookieSalary(5)));
      expect(rookieSalary(5), greaterThan(rookieSalary(20)));
      expect(rookieSalary(20), greaterThan(rookieSalary(50)));
      expect(rookieSalary(0), 400);
    });

    test('契約更改: 総合評価が高いほど・表彰が多いほど・海外ほど高い', () {
      int s(double o, {int h = 0, bool a = false}) =>
          salaryOf(overall: o, honorsLastYear: h, abroad: a);
      expect(s(60), lessThan(s(70)));
      expect(s(70), lessThan(s(80)));
      expect(s(70, h: 3), greaterThan(s(70)));
      expect(s(70, h: 99), s(70, h: 5), reason: '表彰の上乗せは5つまで');
      expect(s(70, a: true), greaterThan(s(70) * 3));
      expect(s(30), 400, reason: '評価が低くても最低年俸');
    });
  });

  group('プロの収入', () {
    Game proGame() {
      final base = Game.start('x', rng: Random(1), events: false);
      return Game(
        eventsEnabled: false,
        player: base.player.copyWith(
          age: 19,
          heightCm: 200,
          abilities: {for (final a in Ability.values) a: 85},
        ),
        rng: Random(2),
        pathPending: true,
      );
    }

    test('プロ契約で新人契約の年俸が付き、年の終わりごとに通算収入へ加わる', () {
      final g = proGame();
      expect(g.salary, 0);
      expect(g.chooseRoute(Route.pro), isTrue);
      final first = g.salary;
      expect(first, rookieSalary(g.draftPick));
      expect(g.totalEarnings, 0);
      // 1年(4季節)進める。
      var guard = 0;
      final age = g.player.age;
      while (g.player.age == age && g.phase != Phase.retired && guard++ < 50) {
        switch (g.phase) {
          case Phase.season:
            g.choose(recommendedAction(g), recommendedFocus(g.player));
          case Phase.halftime:
            g.resolveHalftime(bestHalftime(g.player, g.halftimeInfo!));
          case Phase.clutch:
            g.resolveClutch(Clutch.drive);
          case Phase.event:
            g.resolveEvent(0);
          default:
            break;
        }
      }
      expect(g.totalEarnings, first, reason: '1年目の年俸がそのまま通算収入に入る');
      expect(g.salary, greaterThan(0));
    });

    test('プロ以外は年俸も収入も 0', () {
      final g = Game.start('x', rng: Random(3), events: false);
      for (var i = 0; i < 12; i++) {
        if (g.phase == Phase.season) g.choose(Action.practice, Ability.values.first);
        if (g.phase == Phase.halftime) g.resolveHalftime(Halftime.keep);
        if (g.phase == Phase.clutch) g.resolveClutch(Clutch.drive);
        if (g.phase == Phase.event) g.resolveEvent(0);
      }
      expect(g.salary, 0);
      expect(g.totalEarnings, 0);
    });

    test('年俸と収入は保存・復元で変わらず、古いセーブは 0 で読める', () {
      final g = proGame()..chooseRoute(Route.pro);
      g.totalEarnings = 12345;
      final back = Game.fromJson(g.toJson());
      expect(back.salary, g.salary);
      expect(back.totalEarnings, 12345);
      final j = g.toJson()..remove('salary')..remove('totalEarnings');
      final old = Game.fromJson(j);
      expect(old.salary, 0);
      expect(old.totalEarnings, 0);
    });
  });

  group('通算記録の節目', () {
    test('通算の得点・リバウンド・アシストが節目を超えた大会で知らせる', () {
      var seenLine = '';
      for (var seed = 0; seed < 30 && seenLine.isEmpty; seed++) {
        final g = Game.start('x', rng: Random(seed), events: false);
        var guard = 0;
        while (g.phase != Phase.retired && guard++ < 600 && seenLine.isEmpty) {
          switch (g.phase) {
            case Phase.season:
              g.choose(recommendedAction(g), recommendedFocus(g.player));
            case Phase.halftime:
              g.resolveHalftime(bestHalftime(g.player, g.halftimeInfo!));
            case Phase.clutch:
              g.resolveClutch(Clutch.drive);
            case Phase.event:
              g.resolveEvent(0);
            case Phase.path:
              if (!g.chooseRoute(Route.pro) && !g.retired) g.chooseRoute(Route.university);
            case Phase.retired:
              break;
          }
          if (g.lastCareerLines.isNotEmpty) seenLine = g.lastCareerLines.first;
        }
      }
      expect(seenLine, matches(RegExp(r'^通算\d+(得点|リバウンド|アシスト)達成!$')));
    });

    test('節目の段は小さい順に並び、到達できる範囲にある', () {
      for (final e in Game.careerLadder.entries) {
        final v = e.value;
        expect([...v]..sort(), v, reason: e.key);
        expect(v.first, greaterThan(0));
      }
      expect(Game.careerLadder.keys, containsAll(['得点', 'リバウンド', 'アシスト']));
    });
  });

  test('エンディングに生涯収入と通算記録が出て、実績が増えている', () {
    final base = Game.start('x', rng: Random(1), events: false);
    final g = Game(
      eventsEnabled: false,
      player: base.player.copyWith(age: 30, heightCm: 195),
      rng: Random(2),
      track: Track.pro,
      totalEarnings: 54000,
      salary: 4000,
    );
    g.records.add(const YearRecord(
      age: 25, league: League.proDomestic, wins: 5, games: 100, ppg: 22, rpg: 8,
      apg: 6, champion: false, achievement: 70,
    ));
    final lines = epilogueLines(g);
    expect(lines.any((l) => l.contains('生涯収入') && l.contains('5億4,000万円')), isTrue);
    expect(lines.any((l) => l.contains('通算2200得点')), isTrue);
    final ids = achievements.where((a) => a.earned(g)).map((a) => a.id).toSet();
    expect(ids, containsAll(['earn_5oku', 'career_points_2000']));
    expect(ids, isNot(contains('earn_20oku')));
  });
}
