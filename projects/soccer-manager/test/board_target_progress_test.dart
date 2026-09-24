import 'package:flutter_test/flutter_test.dart';

import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/board_target_progress.dart';
import 'package:soccer_manager/models/league.dart';
import 'package:soccer_manager/models/match_result.dart';
import 'package:soccer_manager/models/team.dart';

/// 理事会の目標に対する進捗表示の検査。
///
/// 「目標: 4位以内」とだけ出ていても、いま届いているのか、あと何が要るのかが
/// 分からなかった。順位・勝点差・残り節数を添えて言えるようにする。
void main() {
  setUp(() => Tr.language = AppLanguage.japanese);
  tearDown(() => Tr.language = AppLanguage.system);

  /// 順位が1位から順に並ぶ総当たりの順位表を作る。
  ///
  /// 順位表は日程の結果から毎回計算されるため、行を直接書き換えても効かない
  /// (最初そうやって書いて、勝点が全部0になった)。実際に試合結果を置く。
  /// 番号の小さいチームが大きいチームに勝つので、勝点は 3*(n-1-i) になる。
  League ladder(int teamCount) {
    final teams = [
      for (var i = 0; i < teamCount; i++)
        Team(id: 't$i', name: 'Team $i', players: []),
    ];
    final fixtures = <Fixture>[];
    var md = 1;
    for (var i = 0; i < teamCount; i++) {
      for (var j = i + 1; j < teamCount; j++) {
        final f = Fixture(matchday: md++, homeTeamId: 't$i', awayTeamId: 't$j');
        f.result = MatchResult(
          matchday: f.matchday,
          homeTeamId: 't$i',
          awayTeamId: 't$j',
          homeGoals: 1,
          awayGoals: 0,
          events: const [],
        );
        fixtures.add(f);
      }
    }
    return League(teams: teams, fixtures: fixtures);
  }

  test('目標圏内なら、そのことと下位との差を出す', () {
    // 勝点は 12/9/6/3/0。t0 が首位で、目標は3位以内。
    final league = ladder(5);
    final p = BoardTargetProgressEngine.evaluate(
      league: league,
      userTeamId: 't0',
      targetRank: 3,
      matchdaysLeft: 5,
    )!;

    expect(p.rank, 1);
    expect(p.onTrack, isTrue);
    // 4位(3点)との差 = 12 - 3 = 9
    expect(p.pointsGap, 9);
    expect(p.label, contains('目標圏内'));
  });

  test('圏外なら、目標順位との勝点差を出す', () {
    // t4 は最下位(0点)。目標3位(6点)との差 = 6
    final league = ladder(5);
    final p = BoardTargetProgressEngine.evaluate(
      league: league,
      userTeamId: 't4',
      targetRank: 3,
      matchdaysLeft: 5,
    )!;

    expect(p.rank, 5);
    expect(p.onTrack, isFalse);
    expect(p.pointsGap, 6);
    expect(p.label, contains('勝点6差'));
  });

  test('差が小さいときは緊張していると見なす', () {
    // t1 は2位(9点)で目標2位以内。3位(6点)との差は3しかない。
    final league = ladder(5);
    final p = BoardTargetProgressEngine.evaluate(
      league: league,
      userTeamId: 't1',
      targetRank: 2,
      matchdaysLeft: 3,
    )!;
    expect(p.tight, isTrue, reason: '勝点差が小さいのに緊張していない扱いになっている');
  });

  test('シーズンが終わっていれば、達成したかどうかを言う', () {
    final league = ladder(5);
    final done = BoardTargetProgressEngine.evaluate(
      league: league,
      userTeamId: 't0',
      targetRank: 3,
      matchdaysLeft: 0,
    )!;
    expect(done.label, contains('目標達成'));

    final missed = BoardTargetProgressEngine.evaluate(
      league: league,
      userTeamId: 't4',
      targetRank: 3,
      matchdaysLeft: 0,
    )!;
    expect(missed.label, contains('目標未達'));
  });

  test('順位表に居ないチームでは何も返さない', () {
    final league = ladder(3);
    expect(
      BoardTargetProgressEngine.evaluate(
        league: league,
        userTeamId: 'よそのクラブ',
        targetRank: 1,
        matchdaysLeft: 5,
      ),
      isNull,
    );
  });
}
