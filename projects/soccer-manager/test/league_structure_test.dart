import 'package:flutter_test/flutter_test.dart';

import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/logic/promotion_engine.dart';
import 'package:soccer_manager/models/league.dart';
import 'package:soccer_manager/models/league_theme.dart';
import 'package:soccer_manager/models/team.dart';

List<Team> _teams(String prefix, int n, {int strength = 50}) => [
      for (var i = 0; i < n; i++)
        PlayerGenerator.generateSquad(
            id: '$prefix$i', name: '$prefix$i', strengthTier: strength),
    ];

void main() {
  test('国ごとに部のクラブ数が違う(イングランド風は2部・3部が24)', () {
    // 2026-11-22 に3部制にした(実在の上から3つのリーグ)。
    expect(LeagueTheme.england.teamsByTier, [20, 24, 24]);
    expect(LeagueTheme.germany.teamsInTier(1), 18);
    expect(LeagueTheme.france.teamsInTier(1), 18);
    for (final t in LeagueTheme.values) {
      expect(t.teamsByTier.length, totalDivisionTiers);
    }
  });

  test('どの国のどの段でも、上がる数と落ちる数が釣り合う', () {
    for (final theme in LeagueTheme.values) {
      for (var upper = 1; upper < totalDivisionTiers; upper++) {
        final r = theme.rulesBelow(upper);
        // プレーオフで上がる数は国で違う(スペインの3部は2枠。2026-11-22)
        // ので、プレーオフ1枠と決め打ちせず promotionPlaces で数える。
        final up = r.promotionPlaces;
        expect(up, r.autoDown, reason: '$theme $upper部');
      }
    }
  });

  test('入れ替えの後も、上下の部のクラブ数は変わらない', () {
    for (final theme in LeagueTheme.values) {
      for (var upper = 1; upper < totalDivisionTiers; upper++) {
        final a = _teams('a', theme.teamsInTier(upper));
        final b = _teams('b', theme.teamsInTier(upper + 1));
        final r = PromotionEngine.resolve(
          tier1Teams: a,
          tier2Teams: b,
          tier1PlayedOrder: a,
          tier2PlayedOrder: b,
          rules: theme.rulesBelow(upper),
        );
        expect(r.tier1.length, a.length, reason: '$theme $upper部');
        expect(r.tier2.length, b.length, reason: '$theme ${upper + 1}部');
      }
    }
  });

  test('入れ替え戦のある国では、入れ替え戦が足され、勝った側が上の部に入る', () {
    final a = _teams('a', 18);
    final b = _teams('b', 18);
    final r = PromotionEngine.resolve(
      tier1Teams: a,
      tier2Teams: b,
      tier1PlayedOrder: a,
      tier2PlayedOrder: b,
      rules: LeagueTheme.germany.rulesBelow(1),
    );
    // 入れ替え戦はドイツ・フランスとも2試合合計(2026-11-22。以前は1試合で、
    // 上の部のホームだった)。第1戦は下の部のホーム、第2戦は上の部のホーム。
    expect(r.promotionPlayoff.length, 2);
    final m = r.promotionPlayoff.last;
    expect(m.homeId, a[15].id);
    expect(m.awayId, b[2].id);
    expect(r.promotionPlayoff.first.homeId, b[2].id);
    expect(r.tier1.any((t) => t.id == m.winnerId), isTrue);
    // 自動の2つずつは必ず入れ替わる
    expect(r.tier1.any((t) => t.id == b[0].id), isTrue);
    expect(r.tier2.any((t) => t.id == a[17].id), isTrue);
  });

  test('部の大きさを合わせる: 余りは下へ、足りない分は下から上げ、最下部は作る', () {
    final byTier = {
      1: _teams('x', 20, strength: 70),
      2: _teams('y', 20, strength: 60),
      3: _teams('z', 20, strength: 50),
    };
    final userId = byTier[1]!.first.id;
    var made = 0;
    final out = PromotionEngine.resize(
      byTier,
      [18, 24, 20],
      protectedId: userId,
      create: (tier, i) {
        made++;
        return PlayerGenerator.generateSquad(
            id: 'new$tier$i', name: 'new$tier$i', strengthTier: 40);
      },
    );
    expect(out[1]!.length, 18);
    expect(out[2]!.length, 24);
    expect(out[3]!.length, 20);
    expect(out[1]!.any((t) => t.id == userId), isTrue);
    // 1部から2つ落ちて2部は22。2部は3部から2つ上げて24、3部は2つ作る
    expect(made, 2);
    final ids = {
      for (final l in out.values)
        for (final t in l) t.id,
    };
    expect(ids.length, 62);
  });
}
