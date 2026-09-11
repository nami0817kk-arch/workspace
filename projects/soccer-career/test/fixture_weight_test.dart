/// 試合の重さ。じっくりやる試合と、流す試合。
///
/// **38試合すべてを同じ濃さでプレイする前提をやめた**（2026-09-11）。
/// 全部を等しく3局面にすると、1試合が「3回タップして終わり」の薄さに固定され、
/// 試合の中で段取りを組む余地が無い。実測（`test/matters_sim.dart`）で、
/// 「刻んでノリを作り、勝負どころで決める」手筋を書いて回したら**最下位**に
/// なった——2手しかないので、積むコストが必ず見返りを上回っていた。
///
/// 重い試合だけを厚くして（2 → 6局面）、ふつうの試合は薄くする。
/// **総量は変えない**（重い試合は全体の25%前後）。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/game/newsroom.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/club.dart';
import 'package:soccer_career/models/player.dart';
import 'package:soccer_career/models/season.dart';

import 'package:soccer_career/models/agent.dart';

import 'support/career_sim.dart';
import 'ui_test.dart' as ui;

Player striker() => Player(
  name: 'テスト',
  age: 24,
  position: Position.st,
  attributes: Attributes(
    pace: 70,
    shooting: 70,
    passing: 70,
    dribbling: 70,
    defending: 70,
    physical: 70,
    goalkeeping: 70,
  ),
  potential: 90,
);

const home = Club(id: 'a', name: 'A', strength: 60, tier: 1);
const away = Club(id: 'b', name: 'B', strength: 60, tier: 1);

MatchInProgress start({
  required bool big,
  Appearance appearance = Appearance.start,
}) => MatchEngine(random: Random(3)).start(
  matchday: 1,
  player: striker(),
  club: home,
  opponent: away,
  home: true,
  appearance: appearance,
  big: big,
);

void main() {
  group('局面の数', () {
    test('じっくりやる試合は厚い', () {
      expect(start(big: false).scenarios.length, Formulas.scenariosPerStart);
      expect(start(big: true).scenarios.length, Formulas.scenariosPerBigStart);
      // 「積んで使う」に手数が要る。2手では段取りが組めない。
      expect(
        Formulas.scenariosPerBigStart,
        greaterThanOrEqualTo(Formulas.momentumMax + 3),
      );
    });

    test('途中出場は、重い試合でも先発より少ない', () {
      expect(
        start(big: true, appearance: Appearance.sub).scenarios.length,
        lessThan(Formulas.scenariosPerBigStart),
      );
      expect(
        start(big: false, appearance: Appearance.sub).scenarios.length,
        lessThan(Formulas.scenariosPerStart + 1),
      );
    });

    test('出ていない試合に局面は無い', () {
      for (final appearance in [
        Appearance.benched,
        Appearance.injured,
        Appearance.suspended,
      ]) {
        expect(MatchEngine.scenarioCount(appearance, big: true), 0);
        expect(MatchEngine.scenarioCount(appearance, big: false), 0);
      }
    });
  });

  group('評価点は重さで動かない', () {
    test('局面の数に関わらず、1試合ぶんの重みに割り戻す', () {
      // 割り戻さないと、重い試合に出ただけで評価点が跳ね、
      // 薄い試合に出ると下がる（＝出た試合の重さが平均評価になる）。
      final light = start(big: false);
      final heavy = start(big: true);
      expect(
        light.ratingScale * light.scenarios.length,
        closeTo(Formulas.ratingScenarios.toDouble(), 0.0001),
      );
      expect(
        heavy.ratingScale * heavy.scenarios.length,
        closeTo(Formulas.ratingScenarios.toDouble(), 0.0001),
      );
    });

    test('途中出場は先発より軽いまま', () {
      final sub = start(big: true, appearance: Appearance.sub);
      final starter = start(big: true);
      expect(
        sub.ratingScale * sub.scenarios.length,
        lessThan(starter.ratingScale * starter.scenarios.length),
      );
    });

    test('局面が無ければ割り戻さない', () {
      final benched = start(big: false, appearance: Appearance.benched);
      expect(benched.ratingScale, 1);
    });
  });

  group('どの試合が重いか', () {
    test('代表戦は必ず重い', () async {
      final c = await ui.newCareer(hallRepository: ui.MemoryHall());
      c.state!.pendingInternational = true;
      expect(Newsroom.isBigFixture(c.state!), isTrue);
    });

    test('シーズンが終わっていれば重くない', () async {
      final c = await ui.newCareer(hallRepository: ui.MemoryHall());
      c.state!.pendingInternational = false;
      while (!c.state!.seasonFinished) {
        await c.simulateMatch();
      }
      expect(Newsroom.isBigFixture(c.state!), isFalse);
    });

    test('重い試合は多すぎない', () async {
      // 全部が重いなら、ただ長くなっただけ。**キャリア全体**で見る——
      // 駆け出しの1年目は格上ばかりなので、開幕シーズンだけを見ると
      // 半分が重くなる（それ自体はおかしくない）。
      var big = 0;
      var total = 0;
      for (var seed = 0; seed < 3; seed++) {
        final career = await runCareer(
          Playstyle(
            name: 'x',
            position: Position.cm,
            startAge: 18,
            sim: SimStyle.balanced,
            agent: Agent.pool.first,
          ),
          seed,
        );
        big += career.bigFixtures;
        total += career.leagueMatches;
      }
      final share = big / total;
      expect(share, greaterThan(0.05), reason: 'じっくりやる試合が来ない');
      expect(share, lessThan(0.45), reason: '$share が重い＝ただ長いだけ');
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
