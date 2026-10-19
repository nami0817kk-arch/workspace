// 保存の互換と完全性を守る(長編なので、保存データの取りこぼしは一生を壊す)。
import 'dart:convert';
import 'dart:math';

import 'package:basketball_career/game/game.dart';
import 'package:basketball_career/game/life.dart';
import 'package:basketball_career/game/match.dart';
import 'package:basketball_career/game/player.dart';
import 'package:flutter_test/flutter_test.dart';

/// 1手ぶん進める。選択は決まった規則(乱数を使わない)。
void step(Game g) {
  switch (g.phase) {
    case Phase.season:
      g.choose(
        g.condition.fatigue >= 60 || g.condition.injured
            ? Action.rest
            : Action.practice,
        recommendedFocus(g.player),
        askClutch: true,
      );
      if (g.canGoAbroad) g.goAbroad();
    case Phase.halftime:
      g.resolveHalftime(Halftime.values[g.player.age % Halftime.values.length]);
    case Phase.clutch:
      g.resolveClutch(Clutch.values[g.player.age % Clutch.values.length]);
    case Phase.event:
      g.resolveEvent(g.player.age % 2);
    case Phase.path:
      final r = g.availableRoutes;
      g.chooseRoute(r[g.player.age % r.length]);
    case Phase.retired:
      break;
  }
}

String fingerprint(Game g) => jsonEncode({
      'p': g.player.toJson(),
      'c': g.condition.toJson(),
      'r': [for (final r in g.records) r.toJson()],
      'rival': g.rival.toJson(),
      'phase': g.phase.name,
      'slot': g.slot,
      'tw': g.teamwork,
      'coach': g.coachBond,
      'met': g.rivalMet,
      'stats': [g.totalSteals, g.totalBlocks, g.totalThrees, g.careerHigh?.points],
      'skills': [for (final k in g.player.skills) k.name]..sort(),
      'mate': g.mate,
      'coachLabel': g.coachLabel,
      'school': g.schoolLabel,
      'ach': g.recentAchievements,
      'reason': g.retiredReason,
    });

void main() {
  test('どこで保存して読み戻しても、一生の結果が変わらない(保存の取りこぼし検出)', () {
    for (var seed = 0; seed < 12; seed++) {
      final a = Game.start('保存', rng: Random(seed));
      var b = Game.start('保存', rng: Random(seed));
      // b は1手ごとに保存→読み戻し。同じ乱数(b の rng)を引き継ぐ。
      final rngB = b.rng;
      var guard = 0;
      while ((a.phase != Phase.retired || b.phase != Phase.retired) &&
          guard++ < 600) {
        step(a);
        step(b);
        b = Game.fromJson(
            jsonDecode(jsonEncode(b.toJson())) as Map<String, dynamic>,
            rng: rngB);
        expect(fingerprint(b), fingerprint(a),
            reason: 'seed=$seed step=$guard');
      }
      expect(a.phase, Phase.retired, reason: 'seed=$seed');
    }
  });

  test('初期の形の古いセーブ(項目が少ない)でも読めて、最後まで遊べる', () {
    // 勝負どころ・ライバル・目標・チームワークなどが無かった頃の形。
    final old = <String, dynamic>{
      'player': {
        'name': 'むかし',
        'age': 14,
        'potential': 60,
        'heightCm': 165.0,
        'heightGenes': 0.5,
        'abilities': {'threePoint': 40, 'pass': 45},
        'traits': ['clutch', 'ふめいな特性'],
      },
      'condition': {'fatigue': 10, 'morale': 55},
      'track': 'school',
      'slot': 2,
      'recentAchievements': [40.0],
      'records': [
        {'age': 13, 'league': 'juniorHigh', 'wins': 2, 'games': 3, 'ppg': 9.0}
      ],
    };
    final g = Game.fromJson(old, rng: Random(1));
    expect(g.phase, Phase.season);
    expect(g.player.of(Ability.threePoint), 40);
    expect(g.player.of(Ability.inside), startLevel, reason: '無い能力は初期値');
    expect(g.teamwork, 40);
    expect(g.coachBond, 20);
    expect(g.difficulty.name, 'normal');
    expect(g.records.single.league.name, 'juniorHigh');
    var guard = 0;
    while (g.phase != Phase.retired && guard++ < 600) {
      step(g);
    }
    expect(g.phase, Phase.retired);
  });

  test('未知の項目や壊れた一部があっても、読み込みで落ちない', () {
    final j = Game.start('x', rng: Random(1)).toJson();
    j['将来の項目'] = {'a': 1};
    (j['player'] as Map)['abilities'] = {'そんな能力': 99, 'pass': 50};
    j['track'] = 'どこでもない';
    j['difficulty'] = '???';
    final g = Game.fromJson(j, rng: Random(1));
    expect(g.player.of(Ability.pass), 50);
    expect(g.track, Track.school);
  });

  test('古いセーブ: ライバルとの対戦があれば「出会い済み」、無ければ未出会い', () {
    final met = Game.fromJson({
      'player': {'name': 'a'},
      'rival': {'name': 'x', 'potential': 60, 'wins': 1, 'losses': 2},
    });
    expect(met.rivalMet, isTrue);
    final fresh = Game.fromJson({
      'player': {'name': 'a'},
      'rival': {'name': 'x', 'potential': 60},
    });
    expect(fresh.rivalMet, isFalse);
    expect(Game.fromJson({'player': {'name': 'a'}}).rivalMet, isFalse);
  });
}
