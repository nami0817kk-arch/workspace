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

import '../l10n/lang.dart';
import '../models/career.dart';
import '../models/season.dart';
import 'career_engine.dart';
import 'match_engine.dart';
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
        tr('監督', 'Manager'),
        favours.isEmpty
            ? tr('${manager.tactic.label}。形は求めていない', '${manager.tactic.label}. No shape asked for')
            : tr('${manager.tactic.label}。'
                '${favours.map((k) => k.label).join('と')}の手で応える', '${manager.tactic.label}. Answer with ${favours.map((k) => k.label).join(' and ')} moves'),
      ));
    }

    // 監督の期待の残り。届いていない項目だけ。
    final objective = state.objective;
    if (objective != null) {
      final stats = state.seasonStats;
      final parts = <String>[];
      final appearances = objective.appearances - stats.appearances;
      if (appearances > 0) parts.add(tr('出場 あと$appearances', 'Appearances $appearances to go'));
      final contributions =
          objective.contributions - stats.goals - stats.assists;
      if (contributions > 0) parts.add(tr('得点関与 あと$contributions', 'Goals and assists $contributions to go'));
      if (stats.averageRating < objective.rating) {
        parts.add(tr('平均評価 ${objective.rating.toStringAsFixed(1)}', 'Average rating ${objective.rating.toStringAsFixed(1)}'));
      }
      // 1枚に収める。長い注釈はクラブタブのカードに任せる。
      lines.add(BriefLine(
        tr('目標', 'Targets'),
        parts.isEmpty
            ? tr('3つとも届いている', 'All three are within reach')
            // **区切りの記号も訳す。** 全角の「／」を英語の画面に
            // 出したままにしていた（2026-11-22、掲載画像で見つけた）。
            : parts.join(tr(' ／ ', ' / ')),
        urgent: state.objectiveReach != null,
      ));
    }

    // 自分から口にした約束。局面を選ぶ手前に必ず置く。
    // ここに出ないと、口にしたことをシーズンの途中で忘れられてしまう。
    final promise = state.promise;
    if (promise != null) {
      final short = promise.shortfall(state.seasonStats);
      lines.add(BriefLine(
        tr('約束', 'Promise'),
        short == null
            ? tr('${promise.label} — 果たした', '${promise.label} - kept')
            : tr('${promise.label}（$short）', '${promise.label} ($short)'),
        urgent: state.promiseReach != null,
      ));
    }

    if (!state.pendingInternational) {
      // 順位。クラブの去就も自分の契約も、最後はここで決まる。
      // 開幕直後の順位表は中身が無いので出さない（1枚に詰め込みすぎない）。
      final position = state.leaguePosition;
      if (position > 0 && state.leagueResults.length >= tableMeaningfulFrom) {
        lines.add(BriefLine(
            tr('順位', 'Table'), tr('${state.club.tier}部 $position位 / ${state.table.length}', 'Tier ${state.club.tier}, #$position of ${state.table.length}')));
      }

      // 得点王レース。終盤で手が届くときだけ。
      final chase = ScorerRace.chaseFor(state);
      if (chase != null) lines.add(BriefLine(tr('得点王', 'Top scorer'), chase, urgent: true));

      final opponent = state.opponentFor(state.matchday);
      final style = ClubStyle.of(opponent);
      lines.add(BriefLine(tr('相手', 'Opponent'),
          tr('${style.label}（${style.description}）',
              '${style.label} (${style.description})')));

      // 相手に知り合いが居るときだけ1行（2026-11-22）。**居ないときは出さない**
      // ——次節カードには余白が無い（行を足して「今の状態」が何度も
      // 画面の外に出た）。競った相手と、今度は敵として当たる。
      final faces = [
        for (final a in state.acquaintances)
          if (!a.retired && a.clubId == opponent.id) a,
      ];
      if (faces.isNotEmpty) {
        lines.add(BriefLine(
          tr('知り合い', 'Familiar face'),
          faces
              .map((a) => tr('${a.bond.label} ${a.name}（${a.overall}）',
                  '${a.bond.label} ${a.name} (${a.overall})'))
              .join(tr('・', ', ')),
        ));
      }

      // 自分が出るぶん、クラブがどれだけ強くなるか。判定と同じ式を読む。
      // 1 未満なら出さない（「+0」は情報ではない）。
      final lift = MatchEngine.starLift(
        overall: state.player.overall,
        clubStrength: state.club.strength,
        appearance: Appearance.start,
        seasonsAtClub: CareerEngine.seasonsAtClub(state),
      );
      if (lift >= 1) {
        lines.add(BriefLine(
          tr('チーム', 'Team'),
          tr('自分が出ると強さ ${state.club.strength} → '
              '${state.club.strength + lift.round()}', 'With you in the side, strength ${state.club.strength} -> ${state.club.strength + lift.round()}'),
        ));
      }
    }

    return lines;
  }
}
