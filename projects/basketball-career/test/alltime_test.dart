import 'dart:math';

import 'package:basketball_career/game/alltime.dart';
import 'package:basketball_career/game/epilogue.dart';
import 'package:basketball_career/game/game.dart';
import 'package:basketball_career/game/legacy.dart';
import 'package:basketball_career/game/life.dart';
import 'package:basketball_career/game/player.dart';
import 'package:basketball_career/game/season.dart';
import 'package:flutter_test/flutter_test.dart';

Game _pro() => Game(
      eventsEnabled: false,
      player: Player(name: 'ミナト', age: 30, potential: 60, heightCm: 190, heightGenes: 0.5,
          abilities: {for (final a in Ability.values) a: 70}),
      rng: Random(1),
      track: Track.pro,
    );

YearRecord _year(int age, double ppg, {int games = 10, bool champion = false, League league = League.proDomestic}) =>
    YearRecord(age: age, league: league, wins: 6, games: games, ppg: ppg, rpg: 3, apg: 3, champion: champion, achievement: 50);

void main() {
  test('名選手は10人。種目ごとに数がばらばらで、名前は重ならない', () {
    expect(legends.length, 10);
    expect(legends.map((l) => l.name).toSet().length, 10);
    for (final s in AllTimeStat.values) {
      final top = legends.reduce((a, b) => a.of(s) >= b.of(s) ? a : b);
      expect(top.of(s), greaterThan(0), reason: s.label);
    }
    // 得点の1位と、リバウンドの1位は別の選手(種目ごとに顔ぶれが変わる)。
    Legend first(AllTimeStat s) => legends.reduce((a, b) => a.of(s) >= b.of(s) ? a : b);
    expect(first(AllTimeStat.points).name, isNot(first(AllTimeStat.rebounds).name));
  });

  test('順位: 同じ数なら名選手が上。抜くと上がる', () {
    expect(allTimeRank(AllTimeStat.points, 0), 11);
    expect(allTimeRank(AllTimeStat.points, 3000), 11, reason: '10位(3,000)と同じでは抜いていない');
    expect(allTimeRank(AllTimeStat.points, 3001), 10);
    expect(allTimeRank(AllTimeStat.points, 99999), 1);
    expect(nextLegend(AllTimeStat.points, 3001)!.value, 3300);
    expect(nextLegend(AllTimeStat.points, 99999), isNull);
  });

  test('抜いた名選手と知らせの文', () {
    expect(passedLegends(AllTimeStat.points, 2900, 3100), ['御子柴 航']);
    expect(passedLegends(AllTimeStat.points, 3100, 3200), isEmpty);
    expect(allTimeLines(AllTimeStat.points, 2900, 3400).single, contains('歴代9位'));
    expect(allTimeLines(AllTimeStat.points, 2900, 3400).single, contains('霧島 慎吾ら2人'));
  });

  test('表: 自分の行が入り、上から順。11位以下でも最後に出る', () {
    final t = allTimeTable(AllTimeStat.assists, 500, 'ミナト');
    expect(t.length, 11);
    expect(t.last.me, isTrue);
    expect(t.last.rank, 11);
    for (var i = 1; i < t.length; i++) {
      expect(t[i - 1].value, greaterThanOrEqualTo(t[i].value));
    }
  });

  test('状態カードの一言: いちばん順位の高い種目と、次までの差', () {
    expect(allTimeSummary({AllTimeStat.points: 0}), isNull);
    expect(allTimeSummary({AllTimeStat.points: 2800}), '通算得点 歴代10位まであと201点');
    expect(allTimeSummary({AllTimeStat.points: 3500, AllTimeStat.assists: 100}),
        '通算得点 歴代9位(8位の不破 隆之介まであと101点)');
    expect(allTimeSummary({AllTimeStat.points: 99999}), '通算得点 歴代1位!');
  });

  test('大会で名選手を抜くと知らせが出て、エンディング・共有文・実績に残る', () {
    final g = _pro();
    g.records.add(_year(28, 290)); // 通算2,900点
    expect(allTimeRank(AllTimeStat.points, g.totalPoints), 11);
    g.records.add(_year(29, 20, champion: true));
    expect(g.allTimeValues[AllTimeStat.points], 3100);
    expect(g.allTimeValues[AllTimeStat.titles], 1);
    g.retire();
    expect(epilogueLines(g).join(), contains('通算得点 歴代10位'));
    expect(shareText(g), contains('歴代記録: 通算得点 歴代10位'));
    expect(earnedBy(g), contains('alltime_top10'));
    expect(earnedBy(g), isNot(contains('alltime_first')));
  });

  test('遊んでいる途中で抜くと、その大会の知らせ(lastAllTimeLines)に出る', () {
    // プロを何年か遊び、通算得点が10位(3,000)をまたいだ大会で知らせが出るか。
    for (var seed = 0; seed < 40; seed++) {
      final g = _pro()..player = _pro().player.copyWith(age: 24);
      g.records.add(_year(23, 298)); // 通算2,980点から始める
      var seen = false;
      for (var turn = 0; turn < 12 && g.phase == Phase.season; turn++) {
        final before = g.totalPoints;
        g.choose(Action.rest, Ability.threePoint);
        if (before <= 3000 && g.totalPoints > 3000) {
          expect(g.lastAllTimeLines.join(), contains('御子柴 航'));
          seen = true;
          break;
        }
      }
      if (seen) return;
    }
    fail('通算3,000点をまたぐ大会が見つからない');
  });
}
