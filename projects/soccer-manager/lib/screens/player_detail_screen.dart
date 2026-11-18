import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/attribute_context_engine.dart';
import '../logic/contract_engine.dart';
import '../logic/retirement_engine.dart';
import '../logic/dynamics_engine.dart';
import '../logic/lineup_utils.dart';
import '../logic/match_engine.dart';
import '../logic/transfer_window.dart';
import '../models/attributes.dart';
import '../models/contract_negotiation.dart';
import '../models/player.dart';
import '../models/training_result.dart';
import '../data/glossary_entries.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import 'glossary_screen.dart';
import '../widgets/attribute_radar.dart';
import '../widgets/growth_sparkline.dart';
import '../widgets/player_face_avatar.dart';
import '../widgets/stat_bar.dart';
import '../l10n/tr.dart';
import '../widgets/player_stat_chips.dart';
import '../logic/economy_scale.dart';
import 'dart:math';

class PlayerDetailScreen extends StatelessWidget {
  final String playerId;

  const PlayerDetailScreen({super.key, required this.playerId});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final team = gameState.userTeam;
    final p = team.players.firstWhere((pl) => pl.id == playerId);
    final isStarting = team.startingXI.contains(p.id);
    final netReleaseValue = gameState.netReleaseValueFor(p.id);
    final renewalCost = gameState.renewalCostFor(p.id);
    final signingBonus = gameState.signingBonusFor(p.id);
    final newAppearanceFee = gameState.appearanceFeeFor(p.id);
    final totalRenewalCost = renewalCost + signingBonus;
    final negotiation = gameState.pendingContractNegotiation;
    final isNegotiatingThisPlayer =
        negotiation != null && negotiation.playerId == p.id;
    final seasonStats = gameState.seasonStatsFor(p.id);
    final assignedSlot =
        LineupUtils.assignedSlotByPlayerId(team)[p.id] ?? p.position;
    PlayerGrowthSummary? latestGrowth;
    for (final r in gameState.lastTrainingResults) {
      if (r.playerId == p.id) {
        latestGrowth = r;
        break;
      }
    }

    // この選手で効いている能力。詳細一覧で印を付けるのに使う。
    final keyAttributeKeys = AttributeContextEngine.keyAttributesFor(p)
        .map((k) => k.key)
        .toSet();

    final categories = [
      AttributeCategory.technical,
      AttributeCategory.mental,
      AttributeCategory.physical,
      if (p.position == Position.gk) AttributeCategory.goalkeeping,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(p.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: Tr.pick('能力値の意味を見る', 'What the attributes mean'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const GlossaryScreen(
                  initialCategory: GlossaryCategory.attribute,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              PlayerFaceAvatar(
                playerId: p.id,
                position: p.position,
                size: 56,
                highlighted: true,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  Tr.pick(
                      '${p.position.fullLabel} ・ ${p.age}歳(誕生日 ${p.birthMonth}月${p.birthDay}日)',
                      '${p.position.fullLabel} • ${p.age} (birthday ${TransferWindowCalendar.formatMonthDay(p.birthdayIn(2001))})'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          if (p.secondaryPositions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                Tr.pick(
                    '対応可能ポジション: ${p.secondaryPositions.map((s) => s.label).join(', ')}',
                    "Also plays: ${p.secondaryPositions.map((s) => s.label).join(', ')}"),
                style: TextStyle(color: SemanticColors.subtleText(context)),
              ),
            ),
          if (seasonStats.appearances > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                Tr.pick(
                    '今シーズン: ${seasonStats.appearances}試合 ${seasonStats.goals}得点${seasonStats.yellowCards > 0 ? ' 警告${seasonStats.yellowCards}' : ''}${seasonStats.redCards > 0 ? ' 退場${seasonStats.redCards}' : ''} / 平均採点${seasonStats.averageRating!.toStringAsFixed(1)}',
                    "This season: ${Tr.plural(seasonStats.appearances, 'app')}, ${Tr.plural(seasonStats.goals, 'goal')}${seasonStats.yellowCards > 0 ? ', ${seasonStats.yellowCards} yellow' : ''}${seasonStats.redCards > 0 ? ', ${seasonStats.redCards} red' : ''} / avg rating ${seasonStats.averageRating!.toStringAsFixed(1)}"),
                style: const TextStyle(
                  color: Colors.teal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (p.careerAppearances > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                Tr.pick('通算成績: ${p.careerAppearances}試合 ${p.careerGoals}得点',
                    'Career: ${Tr.plural(p.careerAppearances, 'app')}, ${Tr.plural(p.careerGoals, 'goal')}'),
                style: TextStyle(
                    color: SemanticColors.subtleText(context), fontSize: 12),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (isStarting)
                Chip(
                  label: Text(Tr.pick('スタメン', 'Starter')),
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                ),
              if (team.captainId == p.id)
                Chip(
                  label: Text(Tr.pick('キャプテン', 'Captain')),
                  backgroundColor: Colors.amber,
                  labelStyle: const TextStyle(color: Colors.white),
                ),
              if (team.viceCaptainId == p.id)
                Chip(
                  label: Text(Tr.pick('副キャプテン', 'Vice Captain')),
                  backgroundColor: Colors.blueGrey,
                  labelStyle: const TextStyle(color: Colors.white),
                ),
              // ダイナミクス: 影響力上位のチームリーダー。機嫌がロッカー
              // ルーム全体へ波及し、放出するとチームが動揺する。
              if (DynamicsEngine.isTeamLeader(team, p.id))
                Chip(
                  label: Text(Tr.pick('チームリーダー', 'Team Leader')),
                  backgroundColor: Colors.deepOrange,
                  labelStyle: const TextStyle(color: Colors.white),
                ),
              if (p.isLoan)
                Chip(
                  label: Text(Tr.pick('ローン加入中', 'On loan here')),
                  backgroundColor: Colors.indigo,
                  labelStyle: const TextStyle(color: Colors.white),
                ),
              if (p.wantsTransfer)
                Chip(
                  label: Text(Tr.pick('移籍を希望している', 'Wants a move away')),
                  backgroundColor: Colors.redAccent,
                  labelStyle: const TextStyle(color: Colors.white),
                ),
              Chip(label: Text(p.personality.label)),
              if (p.isOnInternationalDuty)
                Chip(
                  label: Text(p.onTournamentLeave
                      ? Tr.pick('大会明けの休み', 'Post-tournament break')
                      : Tr.pick('代表召集中', 'On international duty')),
                  backgroundColor: Colors.blueAccent,
                  labelStyle: const TextStyle(color: Colors.white),
                ),
              if (p.isLoanedOut)
                Chip(
                  label: Text(Tr.pick('${p.loanedOutToClubName}へローン中',
                      'On loan at ${p.loanedOutToClubName}')),
                  backgroundColor: Colors.deepPurple,
                  labelStyle: const TextStyle(color: Colors.white),
                ),
              if (p.isTransferListed)
                Chip(
                  label: Text(Tr.pick('移籍リスト登録中', 'Transfer listed')),
                  backgroundColor: Colors.orange,
                  labelStyle: const TextStyle(color: Colors.white),
                ),
            ],
          ),
          if (p.isInjured)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                p.injuryType == null
                    ? Tr.pick('負傷中（あと${p.injuryWeeks}週は出場不可）',
                        'Injured (out for another ${Tr.plural(p.injuryWeeks, 'week')})')
                    : Tr.pick(
                        '${p.injuryType!.label}で負傷中（あと${p.injuryWeeks}週は出場不可）',
                        '${p.injuryType!.label} (out for another ${Tr.plural(p.injuryWeeks, 'week')})'),
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (p.injuryHistoryCounts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${Tr.pick('負傷歴', 'Injury history')}: ${p.injuryHistoryCounts.entries.map((e) {
                  final type = InjuryType.values.firstWhere(
                      (t) => t.name == e.key,
                      orElse: () => InjuryType.bruise);
                  return Tr.pick(
                      '${type.label}${e.value}回', '${type.label} x${e.value}');
                }).join(Tr.pick('・', ' • '))}',
                style: TextStyle(
                    color: SemanticColors.subtleText(context), fontSize: 12),
              ),
            ),
          if (p.isSuspended)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                Tr.pick('出場停止中（あと${p.suspendedMatches}試合は出場不可）',
                    'Suspended (out for another ${Tr.plural(p.suspendedMatches, 'match', 'matches')})'),
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (p.yellowCards > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                Tr.pick(
                    '警告累積: ${p.yellowCards}/$yellowCardSuspensionThreshold(あと${yellowCardSuspensionThreshold - p.yellowCards}枚で出場停止)',
                    'Yellow cards: ${p.yellowCards}/$yellowCardSuspensionThreshold (${yellowCardSuspensionThreshold - p.yellowCards} more brings a ban)'),
                style: TextStyle(
                  color: p.yellowCards >= yellowCardSuspensionThreshold - 1
                      ? Colors.redAccent
                      : SemanticColors.subtleText(context),
                  fontSize: 12,
                ),
              ),
            ),
          if (p.isOnInternationalDuty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                p.onTournamentLeave
                    ? _tournamentLeaveText(context.read<GameState>())
                    : Tr.pick(
                        '代表召集中（あと${p.internationalDutyWeeksRemaining}週は出場不可）',
                        'On international duty (away for another ${Tr.plural(p.internationalDutyWeeksRemaining, 'week')})'),
                style: const TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // この画面の主役の数字。明朝の titleLarge に「総合力: 78」と
              // 書いていた頃は、見出しの一部に見えて目が止まらなかった。
              // 見出しを小さく上に置き、数字を大きく太く出す。
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    Tr.pick('総合力', 'Overall'),
                    style: TextStyle(
                        fontSize: 11,
                        color: SemanticColors.subtleText(context)),
                  ),
                  Text(
                    '${p.overall}',
                    style: TextStyle(
                      fontFamily: 'NotoSansJP',
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                      letterSpacing: -1,
                      color: OverallBadge.colorFor(context, p.overall),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              if (latestGrowth != null && latestGrowth.overallDelta != 0) ...[
                const SizedBox(width: 8),
                Text(
                  Tr.pick(
                      '(今週${latestGrowth.overallDelta > 0 ? '+' : ''}${latestGrowth.overallDelta})',
                      " (this week ${latestGrowth.overallDelta > 0 ? '+' : ''}${latestGrowth.overallDelta})"),
                  style: TextStyle(
                    color: latestGrowth.overallDelta > 0
                        ? Colors.green
                        : Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
          Builder(
            builder: (context) {
              final potentialProgress = p.potential > 0
                  ? (p.overall / p.potential * 100).clamp(0, 100)
                  : 0.0;
              final seasonStart =
                  gameState.save?.seasonStartOverallByPlayerId[p.id];
              final seasonDelta =
                  seasonStart != null ? p.overall - seasonStart : null;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Text(
                      Tr.pick(
                          '潜在能力到達度: ${potentialProgress.toStringAsFixed(0)}%',
                          'Potential reached: ${potentialProgress.toStringAsFixed(0)}%'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.purple,
                      ),
                    ),
                    if (seasonDelta != null) ...[
                      const SizedBox(width: 12),
                      Text(
                        Tr.pick(
                            '今シーズンの成長: ${seasonDelta > 0 ? '+' : ''}$seasonDelta',
                            "Growth this season: ${seasonDelta > 0 ? '+' : ''}$seasonDelta"),
                        style: TextStyle(
                          fontSize: 12,
                          color: seasonDelta > 0
                              ? Colors.green
                              : SemanticColors.subtleText(context),
                          fontWeight: seasonDelta > 0
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          Text(Tr.pick('市場価値: ${formatMoney(p.marketValue)}', 'Value: ${formatMoney(p.marketValue)}')),
          Builder(
            builder: (context) {
              final b = p.marketValueBreakdown;
              return Text(
                Tr.pick(
                    '内訳: 基礎${formatMoney(b.base.round())} + 伸びしろ${formatMoney(b.potentialBonus.round())} を年齢×${b.ageFactor.toStringAsFixed(2)} 性格×${b.personalityFactor.toStringAsFixed(2)} 統率力×${b.leadershipFactor.toStringAsFixed(2)}${b.tournamentFactor != 1 ? ' 夏の大会の活躍×${b.tournamentFactor.toStringAsFixed(2)}' : ''}',
                    'Breakdown: base ${formatMoney(b.base.round())} + potential ${formatMoney(b.potentialBonus.round())}, times age ${b.ageFactor.toStringAsFixed(2)}, personality ${b.personalityFactor.toStringAsFixed(2)}, leadership ${b.leadershipFactor.toStringAsFixed(2)}${b.tournamentFactor != 1 ? ', summer tournament ${b.tournamentFactor.toStringAsFixed(2)}' : ''}'),
                style: TextStyle(
                    fontSize: 11, color: SemanticColors.subtleText(context)),
              );
            },
          ),
          Text(
            p.isLoan
                ? (p.loanEndDate != null
                    ? Tr.pick(
                        '年俸: ${formatMoney(annualFromWeekly(p.wage))} / ローンは${TransferWindowCalendar.formatMonthDay(p.loanEndDate!)}まで',
                        'Salary: ${formatMoney(annualFromWeekly(p.wage))} a year / on loan until ${TransferWindowCalendar.formatMonthDay(p.loanEndDate!)}')
                    : Tr.pick('年俸: ${formatMoney(annualFromWeekly(p.wage))} / ローン残り${p.loanWeeksRemaining}週',
                        'Salary: ${formatMoney(annualFromWeekly(p.wage))} a year / ${Tr.plural(p.loanWeeksRemaining, 'week')} left on loan'))
                : Tr.pick(
                    '年俸: ${formatMoney(annualFromWeekly(p.wage))} / ${ContractEngine.contractLabel(p)}',
                    'Salary: ${formatMoney(annualFromWeekly(p.wage))} a year / ${ContractEngine.contractLabel(p)}'),
          ),
          if (p.releaseClause != null)
            Text(
              Tr.pick('リリース条項: ${formatMoney(p.releaseClause!)}',
                  'Release clause: ${formatMoney(p.releaseClause!)}'),
              style: const TextStyle(color: Colors.deepPurple),
            ),
          const SizedBox(height: 4),
          Text(
            p.personality.description,
            style: TextStyle(
                fontSize: 12, color: SemanticColors.subtleText(context)),
          ),
          Text(
            p.wantsTransfer
                ? Tr.pick(
                    '不満度${p.happiness}が移籍希望ライン(${p.personality.transferRequestThreshold}未満)を下回っており、移籍を希望している',
                    'Happiness ${p.happiness} has fallen below the transfer-request line (under ${p.personality.transferRequestThreshold}), so they want a move')
                : Tr.pick(
                    '移籍希望ライン: 不満度が${p.personality.transferRequestThreshold}未満になると移籍を希望する(現在${p.happiness})',
                    'Transfer-request line: they ask for a move below ${p.personality.transferRequestThreshold} happiness (currently ${p.happiness})'),
            style: TextStyle(
              fontSize: 11,
              color: p.wantsTransfer
                  ? Colors.redAccent
                  : SemanticColors.subtleText(context),
            ),
          ),
          if (p.role != PlayerRole.standard) ...[
            const SizedBox(height: 4),
            Text(
              Tr.pick('ロール: ${p.role.label} — ${p.role.description}',
                  'Role: ${p.role.label} — ${p.role.description}'),
              style: const TextStyle(fontSize: 12, color: Colors.teal),
            ),
          ],
          // 怪我のしやすさ。同じ疲労でも壊れやすい選手がいる。
          // 補強で見るべき情報なので、特性と並べて出す。
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              Tr.pick('怪我のしやすさ: ${p.injuryPronenessLabel}',
                  'Injury proneness: ${p.injuryPronenessLabel}'),
              style: TextStyle(
                fontSize: 12,
                color: p.injuryProneness >= 14
                    ? SemanticColors.negative(context)
                    : SemanticColors.subtleText(context),
              ),
            ),
          ),
          if (p.trait != null) ...[
            const SizedBox(height: 4),
            Text(
              Tr.pick(
                  '特性(${p.trait!.category.label}): ${p.trait!.label} — ${p.trait!.description}',
                  'Trait (${p.trait!.category.label}): ${p.trait!.label} — ${p.trait!.description}'),
              style: const TextStyle(fontSize: 12, color: Colors.deepOrange),
            ),
            // 能力値で発動する特性は、条件に届いていないと何も起きない。
            // その条件が実装の中にしか無く、持っているのに効果が無い状態が
            // 説明されないままだった。判定に使っている表をそのまま出す。
            Builder(builder: (context) {
              final gate = MatchEngine.attributeGatedTraits[p.trait!];
              if (gate == null) return const SizedBox.shrink();
              final current = p.attributeValue(gate.attribute);
              final active = current >= gate.threshold;
              final gain = ((gate.bonus - 1) * 100).round();
              return Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  active
                      ? Tr.pick(
                          '発動中: ${AttributeKeys.labelOf(gate.attribute)}$current '
                              '（${gate.threshold}以上）→ 出来が+$gain%',
                          'Active: ${AttributeKeys.labelOf(gate.attribute)} $current '
                              '(needs ${gate.threshold}) → +$gain% to his display')
                      : Tr.pick(
                          '未発動: ${AttributeKeys.labelOf(gate.attribute)}が'
                              '${gate.threshold}以上で+$gain%（現在$current / あと'
                              '${gate.threshold - current}）',
                          'Dormant: needs ${AttributeKeys.labelOf(gate.attribute)} '
                              '${gate.threshold} for +$gain% '
                              '(now $current, ${gate.threshold - current} to go)'),
                  style: TextStyle(
                    fontSize: 11,
                    color: active
                        ? SemanticColors.positive(context)
                        : SemanticColors.subtleText(context),
                  ),
                ),
              );
            }),
          ],
          if (p.growthType != PlayerGrowthType.balanced) ...[
            const SizedBox(height: 4),
            Text(
              Tr.pick(
                  '成長タイプ: ${p.growthType.label} — ${p.growthType.description}',
                  'Growth: ${p.growthType.label} — ${p.growthType.description}'),
              style: const TextStyle(fontSize: 12, color: Colors.indigo),
            ),
          ],
          if (latestGrowth != null && latestGrowth.isBreakthrough) ...[
            const SizedBox(height: 4),
            Text(
              Tr.pick('★ 今週、才能開花が発生しました！', '★ A breakthrough came this week.'),
              style: const TextStyle(
                fontSize: 12,
                color: Colors.amber,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          if (p.overallHistory.length >= 2) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Tr.pick(
                          '成長推移(直近${p.overallHistory.length}節): 総合 ${p.overallHistory.first} → ${p.overallHistory.last}',
                          'Progress (last ${p.overallHistory.length} matchdays): overall ${p.overallHistory.first} → ${p.overallHistory.last}'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GrowthSparkline(history: p.overallHistory),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Center(child: AttributeRadar(player: p)),
          const SizedBox(height: 12),
          _MatchImpactSummary(
            player: p,
            isStarting: isStarting,
            assignedSlot: assignedSlot,
          ),
          const SizedBox(height: 16),
          Text(Tr.pick('選手を操作', 'Player actions'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (p.isLoan)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Tr.pick('ローン加入中の選手は契約更新・放出の対象外です。ローン期間終了時に自動的にチームを離れます。',
                        'Players on loan here cannot be re-signed or released. They leave automatically when the loan ends.'),
                    style: TextStyle(
                        color: SemanticColors.subtleText(context),
                        fontSize: 12),
                  ),
                  if (p.loanBuyOptionFee != null) ...[
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: gameState.save!.budget < p.loanBuyOptionFee!
                          ? null
                          : () => _exerciseBuyOption(context),
                      child: Text(Tr.pick(
                          '買取オプションを行使する（${formatMoney(p.loanBuyOptionFee!)}）',
                          'Trigger the buy option (${formatMoney(p.loanBuyOptionFee!)})')),
                    ),
                  ],
                ],
              ),
            )
          else if (p.isLoanedOut)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Tr.pick('他クラブへローン放出中は契約更新・放出の対象外です。期間終了時に自動的に復帰します。',
                        'A player out on loan cannot be re-signed or released. They return automatically when the loan ends.'),
                    style: TextStyle(
                        color: SemanticColors.subtleText(context), fontSize: 12),
                  ),
                  if (p.loanedOutUntil != null)
                    Text(
                      Tr.pick(
                          '${TransferWindowCalendar.formatMonthDay(p.loanedOutUntil!)}に戻ります${p.loanRecallClause ? '(冬の窓で呼び戻せる条項付き)' : ''}',
                          'Back on ${TransferWindowCalendar.formatMonthDay(p.loanedOutUntil!)}${p.loanRecallClause ? ' (recall clause for the winter window)' : ''}'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  if (p.loanRecallClause) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.flight_land),
                      onPressed: gameState.canRecallLoanedOutPlayer(p)
                          ? () async {
                              final ok =
                                  await gameState.recallLoanedOutPlayer(playerId);
                              ok
                                  ? FeedbackService.success()
                                  : FeedbackService.error();
                            }
                          : null,
                      label: Text(Tr.pick('冬の窓で呼び戻す', 'Recall him in the winter window')),
                    ),
                  ],
                ],
              ),
            )
          else ...[
            Text(
              Tr.pick('現在の出場手当: ${formatMoney(p.appearanceFee)}/試合',
                  'Current appearance fee: ${formatMoney(p.appearanceFee)} per match'),
              style: TextStyle(
                  fontSize: 12, color: SemanticColors.subtleText(context)),
            ),
            const SizedBox(height: 8),
            // 高齢の選手は、契約を残していてもシーズン終了時に引退しうる。
            // 更新料を払った直後に引退されると、何が起きたのか分からない。
            // 引退判定が実際に使っている確率をそのまま出す。
            if (RetirementEngine.retirementChance(p) > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  Tr.pick(
                      '今シーズン終了時に引退する可能性: '
                          '${(RetirementEngine.retirementChance(p) * 100).round()}%'
                          '（契約が残っていても引退します）',
                      'Chance he retires at the end of this season: '
                          '${(RetirementEngine.retirementChance(p) * 100).round()}%'
                          ' (he retires even with time left on his deal)'),
                  style: TextStyle(
                      fontSize: 12, color: SemanticColors.subtleText(context)),
                ),
              ),
            // 資金が足りないとボタンが灰色になるだけで、何がどれだけ
            // 足りないのかが出ていなかった。更新できない理由が分からないと、
            // 資金を作るのか、諦めて放出するのかも決められない。
            if (gameState.save!.budget < totalRenewalCost)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  Tr.pick(
                      '資金が${formatMoney(totalRenewalCost - gameState.save!.budget)}足りません'
                          '（必要${formatMoney(totalRenewalCost)} / 手元${formatMoney(gameState.save!.budget)}）。'
                          '選手の放出や融資で資金を作るか、年俸交渉で更新してください。',
                      'You are ${formatMoney(totalRenewalCost - gameState.save!.budget)} short '
                          '(need ${formatMoney(totalRenewalCost)}, you have ${formatMoney(gameState.save!.budget)}). '
                          'Sell someone, take a loan, or re-sign him through wage talks.'),
                  style: TextStyle(
                      fontSize: 12, color: SemanticColors.negative(context)),
                ),
              ),
            // 仮契約で出ていく・「延長しない」選手とは更新できない。
            if (gameState.renewalBlockReason(p) != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  gameState.renewalBlockReason(p)!,
                  style: TextStyle(
                      fontSize: 12, color: SemanticColors.negative(context)),
                ),
              ),
            // 延長オプション(満了の年の3月31日まで)。
            if (p.contractOption) ...[
              Text(
                Tr.pick(
                    '延長オプション: ${TransferWindowCalendar.formatMonthDay(ContractEngine.optionDeadline(p.contractEndYear))}までに行使すると、同じ年俸で${ContractEngine.untilLabel(p.contractEndYear + 1)}に延びます。',
                    '1-year option: take it up by ${TransferWindowCalendar.formatMonthDay(ContractEngine.optionDeadline(p.contractEndYear))} to extend him on the same salary ${ContractEngine.untilLabel(p.contractEndYear + 1)}.'),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                icon: const Icon(Icons.event_repeat),
                onPressed: gameState.canExerciseContractOption(playerId)
                    ? () async {
                        final ok =
                            await gameState.exerciseContractOption(playerId);
                        ok
                            ? FeedbackService.success()
                            : FeedbackService.error();
                      }
                    : null,
                label: Text(
                    Tr.pick('延長オプションを行使する', 'Take up the 1-year option')),
              ),
              const SizedBox(height: 8),
            ],
            FilledButton(
              onPressed: gameState.save!.budget < totalRenewalCost ||
                      gameState.renewalBlockReason(p) != null
                  ? null
                  : () => _renew(context),
              child: Text(
                Tr.pick(
                    '契約更新する（基本${formatMoney(renewalCost)} + サインボーナス${formatMoney(signingBonus)} / ${ContractEngine.untilLabel(ContractEngine.defaultRenewalEndYear(p))} / 新出場手当${formatMoney(newAppearanceFee)}）',
                    'Renew his contract (base ${formatMoney(renewalCost)} + signing bonus ${formatMoney(signingBonus)} / ${ContractEngine.untilLabel(ContractEngine.defaultRenewalEndYear(p))} / new appearance fee ${formatMoney(newAppearanceFee)})'),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.handshake_outlined),
              onPressed: !isNegotiatingThisPlayer &&
                      gameState.renewalBlockReason(p) != null
                  ? null
                  : () => _negotiate(context, isNegotiatingThisPlayer),
              label: Text(
                isNegotiatingThisPlayer
                    ? Tr.pick('交渉を続ける（選手の対案: 年俸${formatMoney(annualFromWeekly(negotiation.counterWage))}）',
                        'Keep negotiating (their counter: ${formatMoney(annualFromWeekly(negotiation.counterWage))} a year)')
                    : Tr.pick('年俸交渉で更新する', 'Re-sign after wage talks'),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: (team.players.length <= minSquadSize ||
                      !gameState.isTransferWindowOpen)
                  ? null
                  : () => _confirmSell(context, netReleaseValue),
              child: Text(
                netReleaseValue >= 0
                    ? Tr.pick('放出する（${formatMoney(netReleaseValue)} 獲得）',
                        'Release him (you receive ${formatMoney(netReleaseValue)})')
                    : Tr.pick('放出する（違約金${formatMoney(-netReleaseValue)} 支払い）',
                        'Release him (you pay ${formatMoney(-netReleaseValue)} in compensation)'),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.sell_outlined),
              onPressed: () {
                FeedbackService.tap();
                gameState.setTransferListed(playerId, !p.isTransferListed);
              },
              label: Text(p.isTransferListed
                  ? Tr.pick('移籍リストから外す', 'Take off the transfer list')
                  : Tr.pick('移籍リストに登録する', 'Put on the transfer list')),
            ),
            const SizedBox(height: 8),
            // 合意して契約を解除する(窓の外でもできる。選手は自由契約になる)。
            OutlinedButton.icon(
              icon: const Icon(Icons.assignment_return_outlined),
              onPressed: team.players.length <= minSquadSize ||
                      gameState.mutualTerminationCostFor(playerId) == null
                  ? null
                  : () => _confirmMutualTermination(context),
              label: Text(
                  Tr.pick('合意して契約を解除する', 'Terminate by mutual consent')),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.flight_takeoff),
              onPressed: (team.players.length <= minSquadSize ||
                      !gameState.isTransferWindowOpen)
                  ? null
                  : () => _showLoanOutDialog(context),
              label: Text(Tr.pick('他クラブへローン放出する', 'Loan him out')),
            ),
            if (!gameState.isTransferWindowOpen) ...[
              const SizedBox(height: 4),
              Text(
                gameState.transferWindowStatusLabel,
                style: TextStyle(
                    fontSize: 12, color: SemanticColors.subtleText(context)),
              ),
            ],
          ],
          const SizedBox(height: 8),
          if (!p.isLoan && !p.isLoanedOut) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.gavel),
              onPressed: () =>
                  _editReleaseClause(context, p.releaseClause, p.marketValue),
              label: Text(
                p.releaseClause == null
                    ? Tr.pick('リリース条項を設定する', 'Set a release clause')
                    : Tr.pick('リリース条項を変更する', 'Change the release clause'),
              ),
            ),
          ],
          const Divider(height: 32),
          StatBar(label: Tr.pick('攻撃', 'Attack'), value: p.attack),
          StatBar(label: Tr.pick('守備', 'Defence'), value: p.defense),
          StatBar(label: Tr.pick('技術', 'Technical'), value: p.technique),
          StatBar(label: Tr.pick('スタミナ', 'Stamina'), value: p.stamina),
          if (p.position == Position.gk)
            StatBar(
                label: Tr.pick('ゴールキーピング', 'Goalkeeping'),
                value: p.goalkeeping),
          const Divider(height: 32),
          StatBar(
              label: Tr.pick('潜在能力', 'Potential'),
              value: p.potential,
              color: Colors.purple),
          StatBar(
            label: Tr.pick('疲労', 'Fatigue'),
            value: p.fatigue,
            max: 100,
            color: Colors.redAccent,
          ),
          StatBar(
            label: Tr.pick('士気', 'Morale'),
            value: p.morale,
            max: 100,
            color: Colors.blueAccent,
          ),
          StatBar(
            label: Tr.pick('マッチシャープネス', 'Match Sharpness'),
            value: p.matchSharpness,
            max: 100,
            color: Colors.teal,
          ),
          StatBar(
            label: Tr.pick('不満度(高いほど満足)', 'Happiness (higher is happier)'),
            value: p.happiness,
            max: 100,
            color: p.happiness < 30
                ? SemanticColors.negative(context)
                : SemanticColors.positive(context),
          ),
          const Divider(height: 32),
          // 42項目のうち、この選手で実際に効いているものだけを先に出す。
          // 全部並べても、どれを見ればいいのか分からない。
          _KeyAttributesCard(player: p),
          const SizedBox(height: 12),
          Text(Tr.pick('詳細能力値', 'Full attributes'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          for (final category in categories)
            Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: Text(Tr.pick(
                    '${category.label}（${category.keys.length}項目）',
                    '${category.label} (${category.keys.length})')),
                subtitle: Text(
                  Tr.pick(
                      '平均 ${(category.keys.fold<int>(0, (s, k) => s + p.attributeValue(k)) / category.keys.length).round()}',
                      'avg ${(category.keys.fold<int>(0, (s, k) => s + p.attributeValue(k)) / category.keys.length).round()}'),
                  style: TextStyle(color: SemanticColors.subtleText(context)),
                ),
                initiallyExpanded: false,
                children: [
                  for (final key in category.keys)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: StatBar(
                        // 効いている能力には印を付ける。折りたたみを
                        // 開いたときにも、見るべき行が分かるように。
                        label: keyAttributeKeys.contains(key)
                            ? Tr.pick('★${AttributeKeys.labelOf(key)}',
                                '* ${AttributeKeys.labelOf(key)}')
                            : AttributeKeys.labelOf(key),
                        value: p.attributeValue(key),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _renew(BuildContext context) async {
    final gameState = context.read<GameState>();
    final ok = await gameState.renewContract(playerId);
    ok ? FeedbackService.success() : FeedbackService.error();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(ok
                ? Tr.pick('契約を更新しました', 'Contract renewed')
                : Tr.pick('契約を更新できませんでした', 'Could not renew the contract'))),
      );
    }
  }

  Future<void> _negotiate(BuildContext context, bool isOngoing) async {
    final gameState = context.read<GameState>();
    if (!isOngoing) {
      gameState.startContractNegotiation(playerId);
    }
    if (!context.mounted) return;
    await _showNegotiationDialog(context);
  }

  /// 合意解除の確認。払う額を見せてから決めさせる。
  Future<void> _confirmMutualTermination(BuildContext context) async {
    final gameState = context.read<GameState>();
    final cost = gameState.mutualTerminationCostFor(playerId);
    if (cost == null) return;
    final p = gameState.userTeam.players.firstWhere((p) => p.id == playerId);
    final remaining = ContractEngine.remainingWages(p, gameState.today);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Tr.pick('合意して契約を解除する', 'Terminate by mutual consent')),
        content: Text(Tr.pick(
            '${p.name}の契約(${ContractEngine.untilLabel(p.contractEndYear)})を解除します。残りの年俸${formatMoney(remaining)}のうち${formatMoney(cost)}を払い、${p.name}は自由契約になります。',
            "${p.name}'s contract (${ContractEngine.untilLabel(p.contractEndYear)}) will be cancelled. You pay ${formatMoney(cost)} of the ${formatMoney(remaining)} left on it, and he becomes a free agent.")),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(Tr.pick('やめる', 'Cancel')),
          ),
          FilledButton(
            onPressed: gameState.save!.budget < cost
                ? null
                : () => Navigator.pop(ctx, true),
            child: Text(Tr.pick('${formatMoney(cost)}を払って解除する',
                'Pay ${formatMoney(cost)} and terminate')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final done = await gameState.terminateContractByMutualConsent(playerId);
    done ? FeedbackService.success() : FeedbackService.error();
    if (done && context.mounted) Navigator.of(context).maybePop();
  }

  Future<void> _showNegotiationDialog(BuildContext context) async {
    final gameState = context.read<GameState>();
    final first = gameState.pendingContractNegotiation;
    if (first == null) return;
    final player = gameState.userTeam.players
        .where((p) => p.id == first.playerId)
        .firstOrNull;
    if (player == null) return;
    final choices = ContractEngine.endYearChoicesNow(player.age);
    final controller = TextEditingController(
      // 年俸(万円)で入力してもらい、内部の週俸に直す。
      text: annualFromWeekly(first.counterWage).toString(),
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setState) {
        final negotiation = gameState.pendingContractNegotiation ?? first;
        final endYear =
            negotiation.endYear ?? ContractEngine.defaultRenewalEndYear(player);
        return AlertDialog(
        title: Text(Tr.pick('年俸交渉', 'Salary negotiation')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('現在の年俸: ${formatMoney(annualFromWeekly(negotiation.initialWage))}',
                'Current salary: ${formatMoney(annualFromWeekly(negotiation.initialWage))} a year')),
            Text(
              Tr.pick('選手の対案: 年俸${formatMoney(annualFromWeekly(negotiation.counterWage))}',
                  'His counter-offer: ${formatMoney(annualFromWeekly(negotiation.counterWage))} a year'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              Tr.pick(
                  '交渉回数: ${negotiation.roundsUsed}/${ContractEngine.maxNegotiationRounds}',
                  'Rounds used: ${negotiation.roundsUsed}/${ContractEngine.maxNegotiationRounds}'),
              style: TextStyle(
                  color: SemanticColors.subtleText(context), fontSize: 12),
            ),
            const SizedBox(height: 8),
            // 契約の長さ(最長5年、18歳未満は3年)。
            if (choices.isNotEmpty)
              DropdownButton<int>(
                value: choices.contains(endYear) ? endYear : choices.last,
                isExpanded: true,
                items: [
                  for (final y in choices)
                    DropdownMenuItem(
                        value: y, child: Text(ContractEngine.untilLabel(y))),
                ],
                onChanged: (y) {
                  if (y == null) return;
                  gameState.setNegotiationTerms(endYear: y);
                  setState(() {});
                },
              ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: negotiation.option,
              onChanged: ContractEngine.canAttachOption(endYear, player.age)
                  ? (v) {
                      gameState.setNegotiationTerms(option: v ?? false);
                      final n = gameState.pendingContractNegotiation;
                      if (n != null) {
                        controller.text =
                            annualFromWeekly(n.counterWage).toString();
                      }
                      setState(() {});
                    }
                  : null,
              title: Text(Tr.pick('クラブ側の1年延長オプションを付ける(年俸+5%)',
                  'Add a 1-year club option (salary +5%)')),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: Tr.pick('提示する年俸（万円）',
                      'Salary you are offering (in units of 10,000 yen)')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              gameState.cancelContractNegotiation();
              Navigator.pop(dialogContext);
            },
            child: Text(Tr.pick('交渉をやめる', 'Walk away')),
          ),
          FilledButton(
            onPressed: () async {
              final annual = int.tryParse(controller.text);
              if (annual == null || annual <= 0) return;
              final result = await gameState
                  .offerContractWage(max(1, (annual / 52).round()));
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (context.mounted) {
                _showNegotiationResultSnackBar(context, result);
              }
            },
            child: Text(Tr.pick('提示する', 'Offer')),
          ),
        ],
      );
      }),
    );
    controller.dispose();
  }

  void _showNegotiationResultSnackBar(
    BuildContext context,
    ContractOfferResult result,
  ) {
    switch (result) {
      case ContractOfferResult.accepted:
        FeedbackService.success();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(Tr.pick('年俸交渉が成立し、契約を更新しました',
                'You agreed terms and renewed the contract'))));
        break;
      case ContractOfferResult.countered:
        FeedbackService.tap();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(Tr.pick('選手から対案が届きました。もう一度交渉できます',
                  'He has come back with a counter-offer. You can negotiate again'))),
        );
        break;
      case ContractOfferResult.insufficientFunds:
        FeedbackService.error();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(
            content: Text(Tr.pick('資金が不足しており契約を更新できませんでした',
                'Not enough funds to renew the contract'))));
        break;
      case ContractOfferResult.walkedAway:
        FeedbackService.error();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(
            content: Text(Tr.pick('選手は交渉に納得できず、交渉から離脱しました',
                'He was not satisfied and walked away from the talks'))));
        break;
    }
  }

  Future<void> _exerciseBuyOption(BuildContext context) async {
    final gameState = context.read<GameState>();
    final ok = await gameState.exerciseLoanBuyOption(playerId);
    ok ? FeedbackService.success() : FeedbackService.error();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? Tr.pick('買取オプションを行使し、完全移籍が成立しました',
                  'You triggered the buy option and the permanent transfer went through')
              : Tr.pick(
                  '買取オプションを行使できませんでした', 'Could not trigger the buy option')),
        ),
      );
    }
  }

  void _editReleaseClause(BuildContext context, int? current, int marketValue) {
    final controller = TextEditingController(
      text: (current ?? marketValue).toString(),
    );
    final gameState = context.read<GameState>();
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final amount = int.tryParse(controller.text);
          final isValid = amount != null && amount > 0;
          return AlertDialog(
            title: Text(Tr.pick('リリース条項の設定', 'Set a release clause')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Tr.pick('市場価値: ${formatMoney(marketValue)}', 'Value: ${formatMoney(marketValue)}')),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: Tr.pick('解放金額(万円)', 'Clause amount'),
                    border: const OutlineInputBorder(),
                    errorText: isValid
                        ? null
                        : Tr.pick(
                            '1以上の金額を入力してください', 'Enter an amount of 1 or more'),
                  ),
                ),
              ],
            ),
            actions: [
              if (current != null)
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    gameState.setReleaseClause(playerId, null);
                  },
                  child: Text(Tr.pick('解除する', 'Remove')),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(Tr.pick('キャンセル', 'Cancel')),
              ),
              FilledButton(
                onPressed: !isValid
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        gameState.setReleaseClause(playerId, amount);
                      },
                child: Text(Tr.pick('設定する', 'Set')),
              ),
            ],
          );
        },
      ),
    ).then((_) => controller.dispose());
  }

  void _showLoanOutDialog(BuildContext context) {
    final gameState = context.read<GameState>();
    final theme = gameState.currentLeagueTheme;
    final today = gameState.today;
    final halfOk = TransferWindowCalendar.halfLoanAvailable(today, theme);
    LoanLength length = halfOk ? LoanLength.half : LoanLength.full;
    bool recallClause = false;
    bool guaranteePlayingTime = false;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(Tr.pick('ローン放出期間', 'Loan length')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(Tr.pick(
                  '${TransferWindowCalendar.formatMonthDay(TransferWindowCalendar.loanEndDate(today, theme, length))}まで他クラブへ貸し出します。期間中の給与は放出先が負担します。',
                  'He goes out on loan until ${TransferWindowCalendar.formatMonthDay(TransferWindowCalendar.loanEndDate(today, theme, length))}. The other club pays his wages while he is there.')),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  if (halfOk)
                    ChoiceChip(
                      selected: length == LoanLength.half,
                      onSelected: (_) =>
                          setState(() => length = LoanLength.half),
                      label: Text(Tr.pick('半年(冬の窓まで)', 'Half season')),
                    ),
                  ChoiceChip(
                    selected: length == LoanLength.full,
                    onSelected: (_) => setState(() => length = LoanLength.full),
                    label: Text(Tr.pick('1年(シーズン末まで)', 'Full season')),
                  ),
                ],
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: recallClause,
                onChanged: (v) => setState(() => recallClause = v ?? false),
                title: Text(Tr.pick('冬の窓で呼び戻せる条項を付ける', 'Add a winter recall clause')),
                subtitle: Text(
                  Tr.pick('冬の窓のあいだなら、期間の途中でも戻せる。',
                      'You can bring him back during the winter window, before the loan ends.'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              // 育成型レンタル。ただ出すか、育てるために出すかの違い。
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: guaranteePlayingTime,
                onChanged: (v) =>
                    setState(() => guaranteePlayingTime = v ?? false),
                title: Text(Tr.pick('出場機会を約束させる', 'Guarantee him playing time')),
                subtitle: Text(
                  Tr.pick('確実に試合に出るので大きく伸びる。代わりにレンタル料は受け取れない。',
                      'He is sure to play and comes on a lot. In return you get no loan fee.'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(Tr.pick('キャンセル', 'Cancel')),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final ok = await gameState.loanOutPlayer(
                  playerId,
                  length: length,
                  guaranteePlayingTime: guaranteePlayingTime,
                  recallClause: recallClause,
                );
                ok ? FeedbackService.success() : FeedbackService.error();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(ok
                            ? Tr.pick('ローン放出しました', 'Loan agreed')
                            : Tr.pick('ローン放出できませんでした',
                                'Could not arrange the loan'))),
                  );
                }
              },
              child: Text(Tr.pick('放出する', 'Release')),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmSell(BuildContext context, int netReleaseValue) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Tr.pick('この選手を放出しますか？', 'Release this player?')),
        content: Text(
          netReleaseValue >= 0
              ? Tr.pick('${formatMoney(netReleaseValue)}を獲得しますが、元には戻せません。',
                  'You receive ${formatMoney(netReleaseValue)}, and this cannot be undone.')
              : Tr.pick('違約金として${formatMoney(-netReleaseValue)}を支払うことになりますが、元には戻せません。',
                  'You pay ${formatMoney(-netReleaseValue)} in compensation, and this cannot be undone.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(Tr.pick('キャンセル', 'Cancel')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final gameState = context.read<GameState>();
              final messenger = ScaffoldMessenger.of(context);
              final ok = await gameState.sellPlayer(playerId);
              ok ? FeedbackService.success() : FeedbackService.error();
              if (ok) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(gameState.lastSaleNews ??
                        Tr.pick('選手を放出しました', 'Player released')),
                  ),
                );
              }
              if (context.mounted && ok) {
                Navigator.pop(context);
              }
            },
            child: Text(Tr.pick('放出する', 'Release')),
          ),
        ],
      ),
    );
  }
}

/// 選手の性格・ロール・デューティ・ポジション適性が、実際の試合でどれだけ
/// 攻撃力・守備力に影響するかを定量的にまとめたカード。
class _MatchImpactSummary extends StatelessWidget {
  final Player player;
  final bool isStarting;
  final Position assignedSlot;

  const _MatchImpactSummary({
    required this.player,
    required this.isStarting,
    required this.assignedSlot,
  });

  @override
  Widget build(BuildContext context) {
    String pct(double multiplier) {
      final delta = ((multiplier - 1) * 100).round();
      return delta >= 0 ? '+$delta%' : '$delta%';
    }

    final roleAttack = MatchEngine.roleMultiplier(player, forAttack: true);
    final roleDefense = MatchEngine.roleMultiplier(player, forAttack: false);
    final dutyAttack = MatchEngine.dutyAttackMultiplier(player.duty);
    final dutyDefense = MatchEngine.dutyDefenseMultiplier(player.duty);
    final positionFit = isStarting
        ? MatchEngine.positionFitMultiplier(player, assignedSlot)
        : null;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            Tr.pick('試合への影響(定量)', 'Effect on matches'),
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            Tr.pick('ロール適性: 攻撃${pct(roleAttack)} / 守備${pct(roleDefense)}',
                'Role fit: attack ${pct(roleAttack)} / defence ${pct(roleDefense)}'),
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            Tr.pick(
                'デューティ(${player.duty.label}): 攻撃${pct(dutyAttack)} / 守備${pct(dutyDefense)}',
                'Duty (${player.duty.label}): attack ${pct(dutyAttack)} / defence ${pct(dutyDefense)}'),
            style: const TextStyle(fontSize: 12),
          ),
          if (positionFit != null && positionFit != 1.0)
            Text(
              Tr.pick('ポジション適性(${assignedSlot.label}で起用中): ${pct(positionFit)}',
                  'Position fit (playing at ${assignedSlot.label}): ${pct(positionFit)}'),
              style: TextStyle(
                fontSize: 12,
                color: SemanticColors.negative(context),
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}


/// この選手で効いている能力を、理由つきで並べるカード。
///
/// 42項目を全部見せても、どれを見ればいいのかは分からない。ロールが
/// 見ている能力・特性の発動条件・そのポジションの総合力に効く能力——
/// **実際に計算へ使われているもの**だけを拾って出す。
class _KeyAttributesCard extends StatelessWidget {
  final Player player;
  const _KeyAttributesCard({required this.player});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final keys = AttributeContextEngine.keyAttributesFor(
      player,
      league: gameState.save?.league,
    );
    if (keys.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('この選手で効いている能力', 'What matters for this player'),
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final k in keys)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${AttributeKeys.labelOf(k.key)} ${k.value}',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (k.standingLabel != null)
                          Text(
                            k.standingLabel!,
                            style: TextStyle(
                              fontSize: 11,
                              color: SemanticColors.subtleText(context),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      k.why,
                      style: TextStyle(
                        fontSize: 11,
                        color: SemanticColors.subtleText(context),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 夏の大会のあとの休みの説明(合流の日つき)。
String _tournamentLeaveText(GameState game) {
  final back = game.tournamentReturnDate;
  final name = game.summerTournament?.name ?? '';
  if (back == null) {
    return Tr.pick('夏の大会のあとの休み(まもなく合流)',
        'Post-tournament break (back soon)');
  }
  final day = TransferWindowCalendar.formatMonthDay(back);
  return Tr.pick('$nameのあとの休み($dayに合流するまで出場不可)',
      'Break after the $name (cannot play until he rejoins on $day)');
}
