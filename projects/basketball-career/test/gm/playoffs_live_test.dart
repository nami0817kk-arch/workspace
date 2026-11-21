import 'dart:convert';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/game_sim.dart';
import 'package:basketball_career/gm/league.dart';
import 'package:flutter_test/flutter_test.dart';

/// レギュラーシーズンを終えて、プレーオフに出られる経歴(強いチームから始める)。
Career _toPlayoffs(int seed) {
  final c = careerAt(seed, 2)..startSeason();
  while (c.phase == Phase.season) {
    c.playBlock();
  }
  expect(c.phase, Phase.playoffs);
  return c;
}

void main() {
  test('1試合ずつ: 始めると自分の最初の試合の手前で止まり、1試合ずつ進み、最後まで行くと結果が締まる', () {
    for (final seed in [1, 2, 3]) {
      final c = _toPlayoffs(seed);
      if (c.confRank > playInSeeds) continue;
      c.startPlayoffs();
      expect(c.poLive, isTrue);
      final s = c.myLiveSeries!;
      expect(s.games, isEmpty);
      expect(c.nextMyGame, s.highHomeNext ? (s.high, s.low) : (s.low, s.high));
      c.playPlayoffGame();
      expect(s.games.length, 1);
      // 保存して読み直しても、途中から続けられる
      final copy = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
      expect(copy.poLive, isTrue);
      expect(copy.myLiveSeries?.games.length ?? 0, s.over ? 0 : 1);
      if (!s.over) {
        c.playPlayoffSeries();
        expect(s.over, isTrue);
      }
      c.playPlayoffs();
      expect(c.phase, Phase.seasonEnd);
      expect(c.poLive, isFalse);
      expect(c.playoffs.length, 21, reason: 'プレーイン3×2・1回戦4×2・2回戦2×2・地区決勝1×2・ファイナル1');
      expect(c.playoffs.every((x) => x.over), isTrue);
      expect(c.finals, isNotNull);
      expect(c.history.last.season, c.season);
      expect(c.history.last.result, c.myResult);
      // 読み直した続きも、最後まで行ける
      copy.playPlayoffs();
      expect(copy.phase, Phase.seasonEnd);
      expect(copy.playoffs.length, 21);
    }
  });

  test('プレーオフの采配: 試合の途中で見た結果と、確定した試合の点がそろう', () {
    for (final seed in [1, 2, 3, 4]) {
      final c = _toPlayoffs(seed);
      if (c.confRank > playInSeeds) continue;
      c.startPlayoffs();
      final calls = breakCalls(const [GameCall.fast]);
      final preview = c.previewLive(calls, null)!;
      final g = c.nextMyGame!;
      c.playPlayoffGame(calls: calls);
      final played = c.myLastPlayoffGame!;
      expect(played.home, g.$1);
      final (hp, ap) = (played.home == g.$1 ? played.ptsOf(g.$1) : 0, played.ptsOf(g.$2));
      expect((hp, ap), (preview.home.pts, preview.away.pts));
      return;
    }
    fail('プレーオフに出られる経歴が無い');
  });

  test('自動で遊ぶGM(まとめて戦う)は、始める前からなら今までどおり1度に最後まで', () {
    final c = _toPlayoffs(5);
    c.playPlayoffs();
    expect(c.phase, Phase.seasonEnd);
    expect(c.playoffs.length, 21);
    expect(c.poLive, isFalse);
  });
}
