import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/economy_scale.dart';
import '../logic/owner_history_engine.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import 'help_button.dart';

/// 5か年計画(立てる・進み具合)。
class FiveYearPlanCard extends StatelessWidget {
  const FiveYearPlanCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final save = gs.save;
    if (save == null) return const SizedBox.shrink();
    final small =
        TextStyle(fontSize: 12, color: SemanticColors.subtleText(context));
    // 字形の無い記号(チェックマーク)は使わない。
    String mark(bool ok) =>
        ok ? Tr.pick('[済]', '[done]') : Tr.pick('[未]', '[    ]');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('5か年計画', 'Five-year plan'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            if (gs.hasFiveYearPlan) ...[
              Text(Tr.pick('残り${gs.planSeasonsLeft}季',
                  '${Tr.plural(gs.planSeasonsLeft, 'season')} left')),
              () {
                final (a, b, c) = gs.planProgress;
                return Text(
                  Tr.pick(
                      '${mark(a)} ${save.planTargetTier}部まで上がる\n${mark(b)} クラブ価値 ${formatMoney(save.planTargetValue)}(いま ${formatMoney(gs.clubValue.total)})\n${mark(c)} スタジアム水準 ${save.planTargetStadium}',
                      '${mark(a)} Reach Tier ${save.planTargetTier}\n${mark(b)} Club value ${formatMoney(save.planTargetValue)} (now ${formatMoney(gs.clubValue.total)})\n${mark(c)} Stadium level ${save.planTargetStadium}'),
                );
              }(),
              const SizedBox(height: 4),
              Text(
                  Tr.pick('5季たつと採点します。3つ果たせば株主の期待+15、2つ+5、1つ-5、0は-12。',
                      'Marked after five seasons: all 3 met +15 shareholder faith, 2 +5, 1 -5, none -12.'),
                  style: small),
            ] else ...[
              Text(
                  Tr.pick('部・クラブ価値・スタジアムの3つの目標を立て、5季後に株主に採点してもらいます。',
                      'Set three targets — division, club value and stadium — and let the shareholders mark you after five seasons.'),
                  style: small),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final a in PlanAmbition.values)
                    OutlinedButton(
                      onPressed: () => gs.startFiveYearPlan(a),
                      child: Text(Tr.pick(
                          '${a.label}(${a.tiersUp}部上・価値×${a.valueMultiple}・スタジアム+${a.stadiumUp})',
                          '${a.label} (+${a.tiersUp} tiers, value x${a.valueMultiple}, stadium +${a.stadiumUp})')),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// オーナーの経歴と、歴代オーナーの順位。
class OwnerCareerCard extends StatelessWidget {
  const OwnerCareerCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    if (gs.save == null) return const SizedBox.shrink();
    final career = gs.ownerCareer;
    final table = OwnerHistoryEngine.table(gs.ownerScore);
    final myRank = table.indexWhere((r) => r.isYou) + 1;
    final small =
        TextStyle(fontSize: 12, color: SemanticColors.subtleText(context));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TitleWithHelp(
              title: Tr.pick('オーナーの経歴', 'Your career as owner'),
              help: Tr.pick(
                  '点: リーグ優勝30・カップ10・1季2、最高順位1位+10・3位以内+5。名オーナーは作り物です。',
                  'Points: league title 30, cup 10, each season 2, best finish 1st +10 or top three +5. The legends are fictional.'),
            ),
            // 1季目はどれも0で「0季・最高-(0点)」と空の値が並んでいた。
            // 1季を終えるまでは、その旨の1行だけにする(2026-11-21)。
            if (career.every((l) => l.seasons == 0))
              Text(
                Tr.pick('まだ記録はありません(1季を終えると出ます)。',
                    'No record yet (it appears after your first season).'),
                style: small,
              )
            else
              for (final l in career)
                Text(
                  Tr.pick(
                      '${l.clubName}: ${l.seasons}季・リーグ優勝${l.leagueTitles}・カップ${l.cupTitles}・最高${l.bestRank > 0 ? '${l.bestRank}位' : '-'}(${OwnerHistoryEngine.score(l)}点)',
                      '${l.clubName}: ${Tr.plural(l.seasons, 'season')}, ${Tr.plural(l.leagueTitles, 'title')}, ${Tr.plural(l.cupTitles, 'cup')}, best ${l.bestRank > 0 ? '${l.bestRank}' : '-'} (${OwnerHistoryEngine.score(l)} pts)'),
                  style: const TextStyle(fontSize: 12),
                ),
            const Divider(height: 20),
            Text(gs.ownerScore == 0
                ? Tr.pick('歴代オーナーの順位(あなたはまだ0点)',
                    'All-time owners (you have no points yet)')
                : Tr.pick(
                    '歴代オーナーの順位: $myRank位 / ${table.length}人(${gs.ownerScore}点)',
                    'All-time owners: ${myRank}th of ${table.length} (${gs.ownerScore} pts)')),
            const SizedBox(height: 4),
            for (var i = 0; i < table.length; i++)
              Text(
                '${i + 1}. ${table[i].name}  ${table[i].score}',
                style: table[i].isYou
                    ? const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)
                    : small,
              ),
          ],
        ),
      ),
    );
  }
}
