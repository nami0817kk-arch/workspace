import 'dart:math';

import 'package:basketball_career/game/advice.dart';
import 'package:basketball_career/game/epilogue.dart';
import 'package:basketball_career/game/game.dart';
import 'package:basketball_career/game/honors.dart';
import 'package:basketball_career/game/legacy.dart';
import 'package:basketball_career/game/life.dart';
import 'package:basketball_career/game/match.dart';
import 'package:basketball_career/game/path.dart';
import 'package:basketball_career/game/player.dart';
import 'package:basketball_career/game/season.dart';
import 'package:flutter_test/flutter_test.dart';

MatchResult _m({
  bool won = true,
  int pts = 10,
  int reb = 4,
  int ast = 2,
  int stl = 0,
  int blk = 0,
}) =>
    MatchResult(
      won: won,
      teamScore: won ? 70 : 60,
      oppScore: won ? 60 : 70,
      points: pts,
      rebounds: reb,
      assists: ast,
      steals: stl,
      blocks: blk,
    );

TournamentResult _t(League l, List<MatchResult> ms) => TournamentResult(
      league: l,
      matches: ms,
      wins: ms.where((m) => m.won).length,
      achievement: 70,
    );

void main() {
  group('個人タイトル・表彰', () {
    test('プロで1試合平均の得点が高ければ得点王、リバウンドが高ければリバウンド王', () {
      final t = _t(League.proDomestic, [for (var i = 0; i < 6; i++) _m(pts: 25, reb: 12)]);
      final h = t.honors(rookie: false);
      expect(h, contains(Honor.scoringKing));
      expect(h, contains(Honor.reboundKing));
      expect(h, isNot(contains(Honor.assistKing)));
    });

    test('平凡な成績なら何も付かない', () {
      final t = _t(League.proDomestic, [for (var i = 0; i < 6; i++) _m()]);
      expect(t.honors(rookie: true), isEmpty);
    });

    test('新人王はプロ1年目だけ(2年目は同じ成績でも付かない)', () {
      final ms = [for (var i = 0; i < 6; i++) _m(pts: 24, reb: 9, ast: 6)];
      final t = _t(League.proDomestic, ms);
      expect(t.honors(rookie: true), contains(Honor.rookie));
      expect(t.honors(rookie: false), isNot(contains(Honor.rookie)));
    });

    test('学生の大会と日本代表の短期戦には個人タイトルは付かない', () {
      final ms = [for (var i = 0; i < 6; i++) _m(pts: 30, reb: 15, ast: 10)];
      for (final l in [League.minibasket, League.juniorHigh, League.highSchool, League.national]) {
        expect(_t(l, ms).honors(rookie: true), isEmpty, reason: l.name);
      }
    });

    test('4試合に満たなければ付かない', () {
      final t = _t(League.proDomestic, [for (var i = 0; i < 3; i++) _m(pts: 30)]);
      expect(t.honors(rookie: false), isEmpty);
    });

    test('トリプルダブルは1試合で得点・リバウンド・アシストが全部10以上', () {
      final base = [for (var i = 0; i < 5; i++) _m()];
      expect(_t(League.proDomestic, [...base, _m(pts: 14, reb: 11, ast: 10)]).honors(rookie: false),
          contains(Honor.tripleDouble));
      expect(_t(League.proDomestic, [...base, _m(pts: 14, reb: 11, ast: 9)]).honors(rookie: false),
          isNot(contains(Honor.tripleDouble)));
    });

    test('ファイナルMVPは優勝して決勝で活躍したとき', () {
      final ms = [
        for (var i = 0; i < 6; i++) _m(),
        _m(pts: 8),
        _m(pts: 24),
      ];
      final t = _t(League.proDomestic, ms);
      expect(t.champion, isTrue);
      expect(t.honors(rookie: false), contains(Honor.finalMvp));
      final weak = _t(League.proDomestic, [for (var i = 0; i < 6; i++) _m(), _m(), _m(pts: 6)]);
      expect(weak.honors(rookie: false), isNot(contains(Honor.finalMvp)));
    });

    test('表彰は `Honor.all` の順に並び、説明がそろっている', () {
      final t = _t(League.proDomestic, [for (var i = 0; i < 6; i++) _m(pts: 26, reb: 12, ast: 9, stl: 3, blk: 2)]);
      final h = t.honors(rookie: true);
      final order = [for (final x in Honor.all) if (h.contains(x)) x];
      expect(h, order);
      for (final x in Honor.all) {
        expect(Honor.descriptions[x], isNotEmpty, reason: x);
      }
    });

    test('年の記録(YearRecord)に表彰が保存され、古いセーブは空で読める', () {
      const r = YearRecord(
        age: 25, league: League.proDomestic, wins: 5, games: 8, ppg: 24, rpg: 8, apg: 4,
        champion: false, achievement: 70, honors: [Honor.scoringKing, Honor.allStar],
      );
      expect(YearRecord.fromJson(r.toJson()).honors, [Honor.scoringKing, Honor.allStar]);
      final j = r.toJson()..remove('honors');
      expect(YearRecord.fromJson(j).honors, isEmpty);
    });

    test('一生の通しで、表彰が記録に残り、保存・復元後も数が変わらない', () {
      var found = 0;
      for (var seed = 0; seed < 300 && found < 3; seed++) {
        final g = Game.start('x', rng: Random(seed), events: false);
        var guard = 0;
        while (g.phase != Phase.retired && guard++ < 600) {
          switch (g.phase) {
            case Phase.season:
              g.choose(recommendedAction(g), recommendedFocus(g.player));
              if (g.canGoAbroad) g.goAbroad();
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
        }
        if (g.honorTotal == 0) continue;
        found++;
        final back = Game.fromJson(g.toJson());
        expect(back.honorCounts, g.honorCounts);
        expect(back.honorTotal, g.honorTotal);
        expect(epilogueLines(g).any((l) => l.contains('個人タイトル')), isTrue);
      }
      expect(found, greaterThan(0), reason: '300人のうち、表彰を受けた人生が1つもない');
    });

    test('実績に新人王・得点王・オールスターの常連・タイトルコレクター・トリプルダブルがある', () {
      final ids = achievements.map((a) => a.id).toSet();
      expect(ids, containsAll(['honor_rookie', 'honor_scoring', 'honor_allstar5', 'honor_collector', 'triple_double']));
    });
  });
}
