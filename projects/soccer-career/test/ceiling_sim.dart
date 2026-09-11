// ignore_for_file: avoid_print
/// **能力99の選手が底辺の環境に居ると、なぜ成績が普通なのか。**
///
/// 成功率は上がっているはずなのに、ゴールもアシストも評価点も
/// 大して伸びない——その理由を、試合の層だけ取り出して測る
/// （キャリアを回すと移籍で環境が変わってしまうので、ここは
/// `MatchEngine` を直に叩いて環境を固定する）。
///
/// `flutter test test/ceiling_sim.dart` で明示的に走らせる。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/game/scenarios.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/club.dart';
import 'package:soccer_career/models/player.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/season.dart';

import 'support/career_sim.dart';

Attributes flat(int value) =>
    Attributes.fromDetails({for (final d in Detail.values) d: value});

Player who(int value, Position position) => Player(
  name: 'P',
  age: 26,
  position: position,
  attributes: flat(value),
  potential: 99,
);

Club club(String id, int strength) =>
    Club(id: id, name: id, strength: strength, tier: 1, countryId: 'yamato');

class Tally {
  int matches = 0;
  int scenarios = 0;
  double chance = 0;
  int goals = 0;
  int assists = 0;
  double chances = 0;
  double rating = 0;
  int teamGoals = 0;
}

void main() {
  test('能力99が底辺で何を残すか', () {
    const seasons = 40;

    Tally run({
      required int ability,
      required int clubStrength,
      required int opponentStrength,
      required Position position,
      bool big = false,
    }) {
      final tally = Tally();
      final engine = MatchEngine(random: Random(7));
      final player = who(ability, position);
      for (var season = 0; season < seasons; season++) {
        for (var day = 1; day <= 38; day++) {
          final match = engine.start(
            matchday: day,
            player: player,
            club: club('home', clubStrength),
            opponent: club('away$day', opponentStrength),
            home: day.isEven,
            appearance: Appearance.start,
            big: big,
          );
          tally.scenarios += match.scenarios.length;
          // 選ぶ直前の成功率を控える。
          while (!match.isFinished) {
            final option = match.pickFor(SimStyle.balanced);
            tally.chance += match.chanceFor(option);
            // 得点に繋がる手を選んだ回数。打席の数そのもの。
            if (option.outcome != Outcome.play) tally.chances += 1;
            match.autoArm(SimStyle.balanced);
            match.choose(option);
          }
          final result = match.finish();
          tally.matches++;
          tally.goals += result.goals;
          tally.assists += result.assists;
          tally.rating += result.rating ?? 0;
          tally.teamGoals += result.scored;
        }
      }
      return tally;
    }

    void show(String name, Tally t) {
      print(
        '${name.padRight(28)} '
        '局面 ${(t.scenarios / t.matches).toStringAsFixed(2)}/試合  '
        '成功率 ${(t.chance / t.scenarios * 100).toStringAsFixed(1)}%  '
        '勝負手 ${(t.chances / t.matches).toStringAsFixed(2)}  '
        'ゴール ${(t.goals / t.matches).toStringAsFixed(2)}  '
        'アシスト ${(t.assists / t.matches).toStringAsFixed(2)}  '
        '評価 ${(t.rating / t.matches).toStringAsFixed(2)}  '
        'チーム得点 ${(t.teamGoals / t.matches).toStringAsFixed(2)}',
      );
    }

    for (final position in [Position.st, Position.cm]) {
      print('--- ${position.label} ---');
      // 底辺: 弱いクラブ、相手も弱い。
      show('能力60・底辺(40 vs 40)', run(
        ability: 60,
        clubStrength: 40,
        opponentStrength: 40,
        position: position,
      ));
      show('能力99・底辺(40 vs 40)', run(
        ability: 99,
        clubStrength: 40,
        opponentStrength: 40,
        position: position,
      ));
      // 強いクラブに居て、相手も強い。
      show('能力99・最上位(85 vs 85)', run(
        ability: 99,
        clubStrength: 85,
        opponentStrength: 85,
        position: position,
      ));
      // 弱いクラブだが、じっくりやる試合なら局面が6つ来る。
      show('能力99・底辺・重い試合', run(
        ability: 99,
        clubStrength: 40,
        opponentStrength: 40,
        position: position,
        big: true,
      ));
      // 強いクラブが弱い相手を叩く（得点の総量が増える形）。
      show('能力99・強クラブ vs 弱敵', run(
        ability: 99,
        clubStrength: 85,
        opponentStrength: 45,
        position: position,
      ));
      print('');
    }
  }, timeout: const Timeout(Duration(minutes: 30)));

  test('能力99のまま底辺に居続けたキャリア', () async {
    const seeds = 12;

    Future<void> run(String name, {int? pin, bool stay = true}) async {
      var goals = 0.0;
      var assists = 0.0;
      var apps = 0.0;
      var rating = 0.0;
      var caps = 0.0;
      var prestige = 0.0;
      var big = 0.0;
      var league = 0.0;
      var titles = 0.0;
      var bestTier = 0.0;
      var promoted = 0;
      var promotions = 0.0;

      for (var seed = 0; seed < seeds; seed++) {
        final career = await runCareer(
          Playstyle(
            name: 'x',
            position: Position.st,
            startAge: 18,
            sim: SimStyle.balanced,
            agent: Agent.pool.first,
            pinAbility: pin,
            staysPut: stay,
          ),
          seed,
        );
        goals += career.goals;
        assists += career.assists;
        apps += career.appearances;
        rating += career.averageRating;
        caps += career.caps;
        prestige += career.bestPrestige;
        big += career.bigFixtures;
        league += career.leagueMatches;
        titles += career.leagueTitles;
        bestTier += career.bestTier;
        if (career.reachedTopByPromotion) promoted++;
        promotions += career.promotions;
      }

      print(
        '${name.padRight(26)} '
        '通算ゴール ${(goals / seeds).toStringAsFixed(0)}  '
        'アシスト ${(assists / seeds).toStringAsFixed(0)}  '
        '出場 ${(apps / seeds).toStringAsFixed(0)}  '
        '1試合 ${(goals / max(1, apps)).toStringAsFixed(2)}G  '
        '評価 ${(rating / seeds).toStringAsFixed(2)}  '
        '代表 ${(caps / seeds).toStringAsFixed(0)}  '
        '国の格 ${(prestige / seeds).toStringAsFixed(1)}  '
        'リーグ優勝 ${(titles / seeds).toStringAsFixed(1)}  '
        '到達した部 ${(bestTier / seeds).toStringAsFixed(1)}  '
        '昇格 ${(promotions / seeds).toStringAsFixed(1)}回  '
        '昇格で1部 ${promoted * 100 ~/ seeds}%  '
        '重い試合 ${(big * 100 / max(1, league)).toStringAsFixed(0)}%',
      );
    }

    print('--- キャリアを通して（ST・残留し続ける）---');
    await run('普通に育つ', pin: null);
    await run('能力99に固定', pin: 99);
    print('');
    print('--- 移籍もする（比較）---');
    await run('能力99に固定・移籍あり', pin: 99, stay: false);
  }, timeout: const Timeout(Duration(minutes: 60)));
}
