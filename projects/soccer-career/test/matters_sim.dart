// ignore_for_file: avoid_print
/// **局面の選択は、キャリアを変えているのか。**
///
/// このゲームの中核は「試合中の選択」だと決めてある。1試合3局面 × 38節 ×
/// 20年で 2280回。その2280回が本当に効いているなら、わざと一番悪い手を
/// 選び続けたキャリアは、最善手のキャリアとはっきり違うはずだ。
/// 同じなら、2280回のタップは飾りということになる。
///
/// `flutter test test/matters_sim.dart` で明示的に走らせる。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/game/scenarios.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/season.dart';

import 'support/career_sim.dart';

void main() {
  test('選択がキャリアを変えているか', () async {
    // **24本では差が読めない。** 同じ設定を2回回して、平均評価が
    // 7.22 → 7.20、代表が 35 → 33キャップ動いた。比べたい差と
    // 同じ大きさの揺れがあるので、束ねる本数を先に決める。
    const seeds = 120;

    Future<void> run(
      String name, {
      SimStyle sim = SimStyle.balanced,
      ScenarioOption Function(MatchInProgress)? pick,
      Position position = Position.cm,
    }) async {
      var peak = 0.0;
      var rating = 0.0;
      var goals = 0.0;
      var apps = 0.0;
      var caps = 0.0;
      var titles = 0.0;
      var tier = 0.0;
      var big = 0.0;
      var weeks = 0.0;
      for (var seed = 0; seed < seeds; seed++) {
        final c = await runCareer(
          Playstyle(
            name: 'x',
            position: position,
            startAge: 18,
            sim: sim,
            agent: Agent.pool.first,
            pick: pick,
          ),
          seed,
        );
        peak += c.peakOverall;
        rating += c.averageRating;
        goals += c.goals;
        apps += c.appearances;
        caps += c.caps;
        titles += c.leagueTitles + c.cupTitles;
        tier += c.bestTier;
        big += c.bigFixtures;
        weeks += c.leagueMatches;
      }
      print(
        '${name.padRight(18)} '
        'ピーク ${(peak / seeds).toStringAsFixed(1)}  '
        '平均評価 ${(rating / seeds).toStringAsFixed(2)}  '
        '通算 ${(goals / seeds).toStringAsFixed(0)}G  '
        '出場 ${(apps / seeds).toStringAsFixed(0)}  '
        '代表 ${(caps / seeds).toStringAsFixed(0)}キャップ  '
        'タイトル ${(titles / seeds).toStringAsFixed(1)}  '
        '最高の部 ${(tier / seeds).toStringAsFixed(1)}  '
        'じっくり ${(big / seeds).toStringAsFixed(0)}/'
        '${(weeks / seeds).toStringAsFixed(0)}週'
        '（${(big * 100 / max(1, weeks)).toStringAsFixed(0)}%）',
      );
    }

    // 一番悪い手（期待値が最小）を選び続ける。
    ScenarioOption worst(MatchInProgress m) => m.current.options.reduce(
      (a, b) => m.expectedDelta(a) <= m.expectedDelta(b) ? a : b,
    );
    // 毎回いちばん左の手を選ぶ。読まずに押しているのと同じ。
    ScenarioOption first(MatchInProgress m) => m.current.options.first;

    print('--- 2280回の選択が、キャリアをどれだけ動かすか ---');
    await run('最善（期待値）');
    await run('安全に', sim: SimStyle.safe);
    await run('勝負に出る', sim: SimStyle.aggressive);
    await run('読まずに左端', pick: first);
    await run('わざと最悪', pick: worst);

    // **ノリを見て決める。** 乗っていなければ確実に通し、乗ったら決めにいく。
    // 「上手い遊び方」が存在するなら、これが3つの型より上に出るはず。
    ScenarioOption ride(MatchInProgress m) {
      final options = m.current.options;
      final left = m.scenarios.length - m.resolutions.length;
      // 乗り切っているか、使う場が残り少ないなら決めにいく。
      final strike = m.momentum >= Formulas.momentumMax || left <= 2;
      if (strike) {
        final scoring = options.where((o) => o.outcome != Outcome.play);
        if (scoring.isNotEmpty) {
          return scoring.reduce(
            (a, b) => m.expectedDelta(a) >= m.expectedDelta(b) ? a : b,
          );
        }
      }
      // 積む番。通す確率が一番高い手で、ノリを落とさない。
      return options.reduce((a, b) => m.chanceFor(a) >= m.chanceFor(b) ? a : b);
    }

    await run('刻んでから決める', pick: ride);

    // **布石を打ってから仕留める。** 布石はその場の見返りがほぼゼロなので、
    // 1手ぶんしか見ない `expectedDelta` は選ばない。2手先に投資できるのは
    // 人だけ——ここが、情報を隠さずに人がエンジンを上回れる隙間のはず。
    ScenarioOption combo(MatchInProgress m) {
      final options = m.current.options;
      final left = m.scenarios.length - m.resolutions.length;
      // **段取りが組めるのは、じっくりやる試合だけ。**
      // 2局面しかない試合で1つを布石に使うと、ただ点を捨てることになる。
      //
      // 布石を打つのは、その局面に仕留めもあるときだけ——
      // 最初は「仕留め＝一番難しい手」を固定で選ばせていて、
      // 通らない手ばかり選んで評価が落ちていた（7.09 対 最善 7.18）。
      if (!m.setupReady && left >= 3) {
        final hasFinish = options.any(
          (o) => m.current.roleOf(o) == ComboRole.finish,
        );
        if (hasFinish) {
          for (final o in options) {
            if (m.current.roleOf(o) == ComboRole.setup) return o;
          }
        }
      }
      // 乗っているぶんは `expectedDelta` が見ているので、
      // あとは普通に一番良い手を選べば仕留めに行く。
      return options.reduce(
        (a, b) => m.expectedDelta(a) >= m.expectedDelta(b) ? a : b,
      );
    }

    await run('布石から仕留める', pick: combo);

    if (const bool.fromEnvironment('MATTERS_POSITIONS')) {
      print('--- ポジション別（最善） ---');
      for (final position in [Position.st, Position.wg, Position.cb]) {
        await run(position.name, position: position);
      }
    }
  }, timeout: const Timeout(Duration(minutes: 40)));
}
