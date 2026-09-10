/// 今日の試合が持つ意味を、1枚にまとめる。
///
/// 監督の求める形・シーズンの目標の残り・順位・得点王レース・相手の戦い方は、
/// これまで **4つの別々の画面**（クラブタブのカード・育成タブ・順位表・
/// 次節カード）に散っていた。試合に入る直前に「今日の1本が何に効くのか」を
/// 見返す場所が無いので、どの機能も独立した飾りに見えていた。
///
/// 判定に使う式は増やさない。すでにある `Manager.tactic.favours`・
/// `SeasonObjective`・`leaguePosition`・`ScorerRace` を1か所に集めるだけ。
library;

import '../models/career.dart';
import '../models/development.dart';
import 'newsroom.dart';

/// 「今日の意味」の1行。
class BriefLine {
  const BriefLine(this.label, this.text, {this.urgent = false});

  /// 左に出す見出し。「監督」「目標」など。
  final String label;

  final String text;

  /// 今日の1本で動くもの。強調して出す。
  final bool urgent;
}

/// 次の試合の「意味」を集めたもの。保存はしない。
class MatchBrief {
  const MatchBrief._();

  /// 順位表が意味を持ち始める節。これより前は勝ち点が数試合ぶんしか無い。
  static const int tableMeaningfulFrom = 5;

  static List<BriefLine> of(CareerState state) {
    if (state.seasonFinished) return const [];
    final lines = <BriefLine>[];

    // 監督が何を見ているか。信頼が動く理由がここにある。
    final manager = state.manager;
    if (manager != null) {
      final favours = manager.tactic.favours;
      lines.add(BriefLine(
        '監督',
        favours.isEmpty
            ? '${manager.tactic.label}。形は求めていない'
            : '${manager.tactic.label}。'
                '${favours.map((k) => k.label).join('と')}の手で応える',
      ));
    }

    // 監督の期待の残り。届いていない項目だけ。
    final objective = state.objective;
    if (objective != null) {
      final stats = state.seasonStats;
      final parts = <String>[];
      final appearances = objective.appearances - stats.appearances;
      if (appearances > 0) parts.add('出場 あと$appearances');
      final contributions =
          objective.contributions - stats.goals - stats.assists;
      if (contributions > 0) parts.add('得点関与 あと$contributions');
      if (stats.averageRating < objective.rating) {
        parts.add('平均評価 ${objective.rating.toStringAsFixed(1)}');
      }
      // 1枚に収める。長い注釈はクラブタブのカードに任せる。
      lines.add(BriefLine(
        '目標',
        parts.isEmpty ? '3つとも届いている' : parts.join(' ／ '),
        urgent: state.objectiveReach != null,
      ));
    }

    if (!state.pendingInternational) {
      // 順位。クラブの去就も自分の契約も、最後はここで決まる。
      // 開幕直後の順位表は中身が無いので出さない（1枚に詰め込みすぎない）。
      final position = state.leaguePosition;
      if (position > 0 && state.leagueResults.length >= tableMeaningfulFrom) {
        lines.add(BriefLine(
            '順位', '${state.club.tier}部 $position位 / ${state.table.length}'));
      }

      // 得点王レース。終盤で手が届くときだけ。
      final chase = ScorerRace.chaseFor(state);
      if (chase != null) lines.add(BriefLine('得点王', chase, urgent: true));

      final opponent = state.opponentFor(state.matchday);
      final style = ClubStyle.of(opponent);
      lines.add(BriefLine('相手', '${style.label}（${style.description}）'));
    }

    return lines;
  }
}
