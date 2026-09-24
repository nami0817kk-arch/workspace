import '../models/save_game.dart';
import '../models/season_award.dart';
import '../models/season_record.dart';
import '../l10n/tr.dart';

/// 1シーズンを振り返るまとめ。
class SeasonReview {
  /// 見出し(「2シーズン目を終えて」など)。
  final String title;

  /// 成績の行。順位・勝敗・得失点など。
  final List<String> lines;

  /// 一言の総括。目標に対してどうだったかを言う。
  final String verdict;

  /// 昇格・降格・優勝など、その年を一言で表す出来事(無ければ null)。
  final String? headline;

  const SeasonReview({
    required this.title,
    required this.lines,
    required this.verdict,
    this.headline,
  });
}

/// 終わったシーズンの記録から、振り返りを組み立てる。
///
/// 成績はシーズン成績の画面に積まれていくが、シーズンが終わった瞬間に
/// 「今年はどうだったか」を突きつける場所が無かった。次の年が始まると
/// 順位表は白紙に戻り、前の年の手応えはどこにも残らない。
class SeasonReviewEngine {
  const SeasonReviewEngine._();

  /// 直近のシーズンについての振り返り。記録が無ければ null。
  static SeasonReview? buildFor(SaveGame save) {
    if (save.seasonHistory.isEmpty) return null;
    final r = save.seasonHistory.last;
    final award = save.seasonAwards
        .where((a) => a.season == r.season)
        .cast<SeasonAward?>()
        .firstWhere((a) => true, orElse: () => null);

    return SeasonReview(
      title: Tr.pick('${r.season}シーズンを終えて', 'Looking back on ${r.season}'),
      headline: _headlineFor(r),
      lines: _linesFor(r, award),
      verdict: _verdictFor(r),
    );
  }

  static String? _headlineFor(SeasonRecord r) {
    if (r.wonLeague) {
      return Tr.pick('リーグ優勝', 'Champions');
    }
    if (r.promoted) {
      return Tr.pick('昇格', 'Promoted');
    }
    if (r.relegated) {
      return Tr.pick('降格', 'Relegated');
    }
    if (r.cupsWon.isNotEmpty) {
      return Tr.pick('${r.cupsWon.first} 制覇', 'Won the ${r.cupsWon.first}');
    }
    return null;
  }

  static List<String> _linesFor(SeasonRecord r, SeasonAward? award) {
    final lines = <String>[
      Tr.pick('${r.divisionTier}部 ${r.finalRank}位 / ${r.teamCount}クラブ',
          'Tier ${r.divisionTier}, finished ${r.finalRank} of ${r.teamCount}'),
      Tr.pick('${r.won}勝${r.draw}分${r.lost}敗 (${r.played}試合)',
          '${r.won}W ${r.draw}D ${r.lost}L in ${r.played}'),
      Tr.pick(
          '得点${r.goalsFor} / 失点${r.goalsAgainst} (得失点差 ${r.goalsFor - r.goalsAgainst >= 0 ? '+' : ''}${r.goalsFor - r.goalsAgainst})',
          'Scored ${r.goalsFor}, conceded ${r.goalsAgainst} (${r.goalsFor - r.goalsAgainst >= 0 ? '+' : ''}${r.goalsFor - r.goalsAgainst})'),
    ];
    if (r.cupsWon.isNotEmpty) {
      lines.add(Tr.pick('獲得タイトル: ${r.cupsWon.join('、')}',
          'Trophies: ${r.cupsWon.join(', ')}'));
    }
    final scorer = award?.topScorerName;
    if (award != null && scorer != null) {
      lines.add(Tr.pick('リーグ得点王: $scorer(${award.topScorerGoals}得点)',
          'League top scorer: $scorer (${award.topScorerGoals})'));
    }
    return lines;
  }

  /// 総括の一言。順位を上位・中位・下位に分けて言い分ける。
  ///
  /// 「よくやった」しか言わないと、何位でも同じ言葉になって意味が消える。
  static String _verdictFor(SeasonRecord r) {
    if (r.wonLeague) {
      return Tr.pick('文句のつけようがない1年でした。', 'A season with nothing to argue about.');
    }
    if (r.promoted) {
      return Tr.pick('目標を達成し、上のディビジョンへ進みます。',
          'You got what you came for. Up a division.');
    }
    if (r.relegated) {
      return Tr.pick('立て直しが要ります。来季は下のディビジョンからの再出発です。',
          'This needs fixing. You start again a division lower.');
    }
    final third = r.teamCount / 3;
    if (r.finalRank <= third) {
      return Tr.pick('上位で戦い切りました。あと一歩のところまで来ています。',
          'You held your own near the top. Not far off now.');
    }
    if (r.finalRank <= third * 2) {
      return Tr.pick('可も不可もない位置でした。上を狙うには補強か育成が要ります。',
          'A middling finish. Signings or development are needed to climb.');
    }
    return Tr.pick('苦しい1年でした。守備と台所事情の両方に手を入れる必要があります。',
        'A hard year. Both the defence and the books need attention.');
  }
}
