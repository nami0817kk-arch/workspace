import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_manager/logic/fixture_generator.dart';
import 'package:soccer_manager/models/league.dart';
import 'package:soccer_manager/models/team.dart';

/// 後半戦を前半戦の単純な裏返しにしない(2026-11-23)。
void main() {
  List<Team> teamsOf(int n) => [
        for (var i = 0; i < n; i++)
          Team(id: 't$i', name: 'T$i', players: const []),
      ];

  for (final n in [4, 6, 10, 16, 18, 20, 24]) {
    test('$nクラブ: どの組も1回ずつホームで当たり、後半戦は前半の裏返しでない', () {
      final fixtures = FixtureGenerator.generateDoubleRoundRobin(teamsOf(n));
      final rounds = n - 1;
      // 同じ組み合わせ(ホーム → アウェイ)はちょうど1回。
      final seen = <String>{};
      for (final f in fixtures) {
        expect(seen.add('${f.homeTeamId}>${f.awayTeamId}'), isTrue,
            reason: '${f.homeTeamId} 対 ${f.awayTeamId} が2回ある');
      }
      expect(seen.length, n * (n - 1));
      // 後半の各節が、前半の同じ番号の節の裏返しになっていない節がある。
      var mirrored = 0;
      for (var md = 1; md <= rounds; md++) {
        final first = {
          for (final f in fixtures.where((f) => f.matchday == md))
            '${f.awayTeamId}>${f.homeTeamId}',
        };
        final second = {
          for (final f in fixtures.where((f) => f.matchday == md + rounds))
            '${f.homeTeamId}>${f.awayTeamId}',
        };
        if (first.length == second.length && first.containsAll(second)) {
          mirrored++;
        }
      }
      expect(mirrored, lessThan(rounds), reason: '後半戦が前半戦の裏返しのまま');
    });

    test('$nクラブ: 同じ相手と連戦せず、同じ側は3節まで・3節続くのはまれ', () {
      final teams = teamsOf(n);
      final fixtures = FixtureGenerator.generateDoubleRoundRobin(teams);
      var triples = 0;
      for (final t in teams) {
        final mine = fixtures
            .where((f) => f.homeTeamId == t.id || f.awayTeamId == t.id)
            .toList()
          ..sort((a, b) => a.matchday.compareTo(b.matchday));
        expect(mine.length, (n - 1) * 2);
        String opp(Fixture f) =>
            f.homeTeamId == t.id ? f.awayTeamId : f.homeTeamId;
        var run = 1;
        for (var i = 1; i < mine.length; i++) {
          expect(opp(mine[i]), isNot(opp(mine[i - 1])),
              reason: '${t.id} が第${mine[i].matchday}節に同じ相手と連戦');
          final same =
              (mine[i].homeTeamId == t.id) == (mine[i - 1].homeTeamId == t.id);
          run = same ? run + 1 : 1;
          expect(run, lessThanOrEqualTo(3), reason: '${t.id} は同じ側が$run節続く');
          if (run == 3) triples++;
        }
      }
      // 3節続くのは、全クラブの全節の1割未満。
      expect(triples, lessThan(n * (n - 1) * 2 ~/ 10));
    });
  }

  test('奇数のクラブ数でも全部の組み合わせがそろう', () {
    for (final n in [5, 19]) {
      final fixtures = FixtureGenerator.generateDoubleRoundRobin(teamsOf(n));
      expect(fixtures.length, n * (n - 1));
      expect(fixtures.map((f) => '${f.homeTeamId}>${f.awayTeamId}').toSet(),
          hasLength(n * (n - 1)));
    }
  });
}
