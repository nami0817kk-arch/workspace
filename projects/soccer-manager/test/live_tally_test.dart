import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/models/match_result.dart';
import 'package:soccer_manager/widgets/match_widgets.dart';

/// 試合中の途中経過パネルの検査。
///
/// 完了後の統計をそのまま出すと、まだ起きていない結果が見えてしまう。
/// 「明かされた出来事だけを数えている」ことを固定する。
void main() {
  // 文言は言語設定で切り替わる。テスト環境の既定は英語なので、日本語の
  // 見出しを確かめるならここで決めておく。
  setUp(() => Tr.language = AppLanguage.japanese);
  tearDown(() => Tr.language = AppLanguage.system);

  MatchEvent event(MatchEventType type, String teamId, int minute) =>
      MatchEvent(minute: minute, teamId: teamId, type: type);

  LiveMatchTally tally(List<MatchEvent> revealed) => LiveMatchTally(
        revealed: revealed,
        homeTeamId: 'home',
        homeTeamName: 'ホーム',
        awayTeamName: 'アウェイ',
      );

  test('渡された出来事だけを数える', () {
    final panel = tally([
      event(MatchEventType.goal, 'home', 10),
      event(MatchEventType.goal, 'away', 20),
      event(MatchEventType.goal, 'away', 30),
      event(MatchEventType.chance, 'home', 35),
    ]);

    expect(panel.countOf(MatchEventType.goal), (1, 2));
    expect(panel.countOf(MatchEventType.chance), (1, 0));
    expect(panel.countOf(MatchEventType.yellowCard), (0, 0));
  });

  test('まだ明かされていない出来事は数に入らない', () {
    // 試合の結果そのものは先に決まっているが、画面に出るのは明かされた分だけ。
    final all = [
      event(MatchEventType.goal, 'home', 10),
      event(MatchEventType.goal, 'home', 80),
    ];
    final revealedSoFar = all.where((e) => e.minute <= 45).toList();

    expect(tally(revealedSoFar).countOf(MatchEventType.goal), (1, 0),
        reason: '後半の得点が前半のうちに見えている');
  });

  testWidgets('得点・決定機・カードの行が出る', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: tally([
          event(MatchEventType.goal, 'home', 10),
          event(MatchEventType.chance, 'away', 22),
          event(MatchEventType.yellowCard, 'away', 30),
          event(MatchEventType.redCard, 'away', 40),
        ]),
      ),
    ));

    expect(find.text('得点'), findsOneWidget);
    expect(find.text('決定機'), findsOneWidget);
    expect(find.text('カード'), findsOneWidget);
    // カードは警告と退場の合計。別々に出すと行が増えるだけで読みにくい。
    expect(find.text('2'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
