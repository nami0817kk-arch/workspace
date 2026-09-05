import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/season_analysis_engine.dart';
import '../state/game_state.dart';
import '../l10n/tr.dart';
import '../theme/semantic_colors.dart';

/// 今シーズンの傾向を見る画面。
///
/// 順位表と選手ごとの出場・得点はあったが、**どう勝って、どう
/// 負けたのか**が分からなかった。前半に失点が多いのか、アウェイで
/// 取りこぼしているのか、終盤に崩れるのか。次に何を変えるかは、
/// そこを見ないと決まらない。
///
/// 出しているのは、保存済みの試合結果から数え直したものだけ。
/// 新しい数値は持たせていないので、表示と実態がずれない。
class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final save = gameState.save;
    if (save == null) {
      return Scaffold(
        appBar: AppBar(title: Text(Tr.pick('シーズン分析', 'Season analysis'))),
        body: const SizedBox.shrink(),
      );
    }

    final league = save.league;
    final teamId = save.userTeamId;
    final all = SeasonAnalysisEngine.record(league, teamId);

    if (all.played == 0) {
      return Scaffold(
        appBar: AppBar(title: Text(Tr.pick('シーズン分析', 'Season analysis'))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              Tr.pick('まだ試合を行っていません。数試合を終えると傾向が出ます。',
                  'No matches played yet. Play a few and the patterns appear here.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: SemanticColors.subtleText(context)),
            ),
          ),
        ),
      );
    }

    final home = SeasonAnalysisEngine.record(league, teamId, home: true);
    final away = SeasonAnalysisEngine.record(league, teamId, home: false);
    final periods = SeasonAnalysisEngine.goalsByPeriod(league, teamId);
    final lostFromAhead =
        SeasonAnalysisEngine.gamesLostFromAhead(league, teamId);

    String recordLabel(
            ({int played, int won, int drawn, int lost, int gf, int ga}) r) =>
        Tr.pick('${r.won}勝${r.drawn}分${r.lost}敗 / 得点${r.gf} 失点${r.ga}',
            '${r.won}W ${r.drawn}D ${r.lost}L / ${r.gf} for, ${r.ga} against');

    return Scaffold(
      appBar: AppBar(title: Text(Tr.pick('シーズン分析', 'Season analysis'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(
            title: Tr.pick('ホームとアウェイ', 'Home and away'),
            rows: [
              AnalysisRow(
                  label: Tr.pick('通算', 'Overall'), value: recordLabel(all)),
              AnalysisRow(
                  label: Tr.pick('ホーム', 'Home'), value: recordLabel(home)),
              AnalysisRow(
                  label: Tr.pick('アウェイ', 'Away'), value: recordLabel(away)),
            ],
            note: home.played > 0 && away.played > 0
                ? _homeAwayNote(home, away)
                : null,
          ),
          _Section(
            title: Tr.pick('時間帯', 'When the goals come'),
            rows: [
              AnalysisRow(
                label: Tr.pick('前半', 'First half'),
                value: Tr.pick(
                    '得点${periods.firstFor} / 失点${periods.firstAgainst}',
                    '${periods.firstFor} for / ${periods.firstAgainst} against'),
              ),
              AnalysisRow(
                label: Tr.pick('後半', 'Second half'),
                value: Tr.pick(
                    '得点${periods.secondFor} / 失点${periods.secondAgainst}',
                    '${periods.secondFor} for / ${periods.secondAgainst} against'),
              ),
              AnalysisRow(
                label: Tr.pick('うち終盤(75分以降)', 'of which late (75+)'),
                value: Tr.pick(
                    '得点${periods.lateFor} / 失点${periods.lateAgainst}',
                    '${periods.lateFor} for / ${periods.lateAgainst} against'),
              ),
            ],
            note: _periodNote(periods),
          ),
          _Section(
            title: Tr.pick('落とし方', 'How you lose'),
            rows: [
              AnalysisRow(
                label: Tr.pick('先制しながら負けた試合', 'Lost after scoring first'),
                value: Tr.pick('$lostFromAhead試合', '$lostFromAhead'),
              ),
            ],
            note: lostFromAhead >= 2
                ? Tr.pick('先制しても守り切れていません。終盤の疲労と、リードしたときの姿勢を見直す価値があります。',
                    'You are not holding on to leads. Look at late fatigue and how you set up in front.')
                : null,
          ),
        ],
      ),
    );
  }

  static String? _homeAwayNote(
    ({int played, int won, int drawn, int lost, int gf, int ga}) home,
    ({int played, int won, int drawn, int lost, int gf, int ga}) away,
  ) {
    final homePoints = (home.won * 3 + home.drawn) / home.played;
    final awayPoints = (away.won * 3 + away.drawn) / away.played;
    if (homePoints - awayPoints >= 1.0) {
      return Tr.pick('アウェイで大きく落としています。',
          'You are dropping far more points on the road.');
    }
    if (awayPoints - homePoints >= 1.0) {
      return Tr.pick('ホームで取りこぼしています。',
          'You are dropping points at home.');
    }
    return null;
  }

  static String? _periodNote(
      ({int firstFor, int firstAgainst, int secondFor, int secondAgainst,
              int lateFor, int lateAgainst})
          p) {
    final totalAgainst = p.firstAgainst + p.secondAgainst;
    if (totalAgainst >= 5 && p.lateAgainst * 2 >= totalAgainst) {
      return Tr.pick('失点の半分以上が終盤です。疲労と交代を見直す価値があります。',
          'More than half your goals against come late. Look at fatigue and your substitutions.');
    }
    if (p.firstAgainst > p.secondAgainst * 2 && p.firstAgainst >= 4) {
      return Tr.pick('立ち上がりに失点が集中しています。',
          'You are conceding early far too often.');
    }
    return null;
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<AnalysisRow> rows;
  final String? note;

  const _Section({required this.title, required this.rows, this.note});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        r.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: SemanticColors.subtleText(context),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(r.value,
                          style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
            if (note != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  note!,
                  style: TextStyle(
                    fontSize: 12,
                    color: SemanticColors.negative(context),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
