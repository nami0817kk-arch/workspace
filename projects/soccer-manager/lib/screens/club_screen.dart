import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/board_engine.dart';
import '../logic/scouting_engine.dart';
import '../logic/manager_hr_engine.dart';
import '../logic/manager_tactics.dart';
import '../models/formation.dart';
import '../models/manager_profile.dart';
import '../models/player.dart';
import '../models/staff_offer.dart';
import '../logic/transfer_window.dart';
import '../models/club_infrastructure.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../widgets/undoable.dart';
import '../widgets/auto_columns.dart';
import '../widgets/quick_access_drawer.dart';
import '../widgets/responsive_body.dart';
import '../l10n/tr.dart';
import '../models/staff_member.dart';
import '../theme/semantic_colors.dart';
import '../widgets/player_stat_chips.dart';
import '../widgets/youth_analytics_card.dart';
import '../widgets/fan_segments_card.dart';
import '../widgets/club_look_card.dart';
import '../widgets/affiliate_card.dart';
import '../widgets/club_license_card.dart';
import '../widgets/season_tickets_card.dart';
import '../logic/economy_scale.dart';
import '../widgets/help_button.dart';
import '../widgets/screen_bar.dart';
import '../widgets/disabled_reason.dart';

part 'club_screen_staff.dart';

/// スタッフ・施設の現在レベル(と最大未満なら次レベル)の具体的な効果を1行にまとめる。
String _staffEffectLabel(StaffRole role, int level,
    {StaffMember? member, int tier = 3}) {
  const maxLevel = ClubInfrastructure.maxLevel;
  switch (role) {
    case StaffRole.headCoach:
      final cur = ClubInfrastructure.trainingGrowthMultiplier(level, 1);
      final next = level < maxLevel
          ? ClubInfrastructure.trainingGrowthMultiplier(level + 1, 1)
          : null;
      return Tr.pick(
          '練習での成長${_pct(cur)}${next == null ? '' : '(1つ上の人なら${_pct(next)})'}',
          "Training growth ${_pct(cur)}${next == null ? '' : ' (${_pct(next)} with a better coach)'}");
    case StaffRole.scout:
      final cur = scaleMoneyForTier(tier, ScoutingEngine.scoutCostFor(level));
      final curCount = ScoutingEngine.scoutCandidateCountFor(level);
      final next = level < maxLevel
          ? scaleMoneyForTier(tier, ScoutingEngine.scoutCostFor(level + 1))
          : null;
      final nextCount = level < maxLevel
          ? ScoutingEngine.scoutCandidateCountFor(level + 1)
          : null;
      return Tr.pick(
          '費用${formatMoney(cur)} / 候補$curCount人${next == null ? '' : ' → 次Lv: 費用${formatMoney(next)} / 候補$nextCount人'}',
          "${formatMoney(cur)} per signing / $curCount candidates${next == null ? '' : ' → next level: ${formatMoney(next)} / $nextCount candidates'}");
    case StaffRole.physio:
      final cur = ClubInfrastructure.injuryFactor(level);
      final next =
          level < maxLevel ? ClubInfrastructure.injuryFactor(level + 1) : null;
      return Tr.pick(
          '負傷リスク${((1 - cur) * 100).round()}%軽減${next == null ? '' : ' → 次Lv: ${((1 - next) * 100).round()}%軽減'}',
          "Injury risk down ${((1 - cur) * 100).round()}%${next == null ? '' : ' → next level: down ${((1 - next) * 100).round()}%'}");
    case StaffRole.youthCoach:
      // ユースコーチだけは2つの能力が別の仕事をしている。混ぜた水準で
      // 「質+n」とだけ出すと、見極めの高い人と指導の高い人の違いが
      // 見えず、どちらを雇うかの判断ができない。
      final judging = member?.levelOf(StaffAttribute.judging) ?? level;
      final coaching = member?.levelOf(StaffAttribute.coaching) ?? level;
      final quality = (judging - 1) * 3;
      final spread = ScoutingEngine.estimateUncertainty(judging);
      final extraKeys = (coaching - 1).clamp(0, maxLevel - 1);
      return Tr.pick(
          '見極め: 入ってくる子の質+$quality・伸びしろの見立て±$spread / '
              '指導: 練習で手の回る項目+$extraKeys',
          'Judging: intake quality +$quality, potential read within ±$spread / '
              'Coaching: +$extraKeys extra attributes worked on');
    case StaffRole.manager:
      return Tr.pick(
          level >= 4
              ? 'ふだんの試合は最善の先発で臨み、相手に合わせて構えを選ぶ'
              : level >= 3
                  ? 'ふだんの試合は相手に合わせて構えを選ぶ(先発は負傷の穴埋めまで)'
                  : 'ふだんの試合は負傷の穴を埋めるだけ(構えは変えない)',
          level >= 4
              ? 'Ordinary matches: best XI, approach set by the opponent'
              : level >= 3
                  ? 'Ordinary matches: approach set by the opponent (XI only patched for injuries)'
                  : 'Ordinary matches: only patches injury gaps (approach unchanged)');
    case StaffRole.fitnessCoach:
      final cur = ClubInfrastructure.fitnessCoachRecoveryBonus(level);
      final next = level < maxLevel
          ? ClubInfrastructure.fitnessCoachRecoveryBonus(level + 1)
          : null;
      return Tr.pick('追加疲労回復+$cur${next == null ? '' : ' → 次Lv: +$next'}',
          "Extra fatigue recovery +$cur${next == null ? '' : ' → next level: +$next'}");
    case StaffRole.sportingDirector:
      final judging = member?.levelOf(StaffAttribute.judging) ?? level;
      final off = (1.5 * (judging - 1)).toStringAsFixed(1);
      return Tr.pick('相手の言い値を$off%安くまとめる。移籍の画面で補強の交渉を任せられる',
          'Brings asking prices down $off%. You can hand him your transfer talks on the Transfers screen');
  }
}

/// 倍率を「+8%」の形にする(1.08 → +8%)。
String _pct(double m) {
  final d = ((m - 1) * 100).round();
  return d >= 0 ? '+$d%' : '$d%';
}

/// 施設の効き目。式(x1.00 → 次Lv: x1.10)ではなく、「いま」と
/// 「次のLvで」を言葉と%で出す(2026-11-21)。
String _facilityEffectLabel(
  FacilityType type,
  int level,
  int expectedAttendance,
  int fanDemand, {
  bool gateAtCap = false,
}) {
  const maxLevel = ClubInfrastructure.maxLevel;
  final hasNext = level < maxLevel;
  switch (type) {
    case FacilityType.trainingGround:
      final g = ClubInfrastructure.trainingGrowthMultiplier(1, level);
      final f = ClubInfrastructure.fatigueRecoveryBonus(level);
      final ng = hasNext
          ? ClubInfrastructure.trainingGrowthMultiplier(1, level + 1)
          : g;
      final nf =
          hasNext ? ClubInfrastructure.fatigueRecoveryBonus(level + 1) : f;
      return Tr.pick(
          'いま: 成長${_pct(g)}・疲労回復+$f${hasNext ? '\n次のLvで: 成長${_pct(ng)}・疲労回復+$nf' : ''}',
          "Now: growth ${_pct(g)}, recovery +$f${hasNext ? '\nNext level: growth ${_pct(ng)}, recovery +$nf' : ''}");
    case FacilityType.stadium:
      final cur = ClubInfrastructure.stadiumCapacity(level);
      final next =
          hasNext ? ClubInfrastructure.stadiumCapacity(level + 1) : cur;
      // 人数は3桁で区切る(「12000人」が読みにくかった。2026-11-23)。
      final c = formatCount(cur);
      final n = formatCount(next);
      final usual = formatCount(expectedAttendance);
      final demand = formatCount(fanDemand);
      return Tr.pick(
          'いま: $c人入る(ふだんの入り$usual人・来たいファン$demand人)${hasNext ? '\n次のLvで: $n人' : ''}',
          "Now: holds $c (usual crowd $usual, fans wanting to come $demand)${hasNext ? '\nNext level: $n' : ''}");
    case FacilityType.youthFacility:
      final cur = ScoutingEngine.maxProspectsFor(level);
      final next = hasNext ? ScoutingEngine.maxProspectsFor(level + 1) : cur;
      return Tr.pick('いま: 受け入れ$cur人${hasNext ? '\n次のLvで: $next人' : ''}',
          "Now: $cur academy places${hasNext ? '\nNext level: $next' : ''}");
    case FacilityType.commercialFacility:
      final cur = ClubInfrastructure.commercialRevenueMultiplier(level);
      final next = hasNext
          ? ClubInfrastructure.commercialRevenueMultiplier(level + 1)
          : cur;
      // 観客収入は、入る人数 × 1人の単価の上限で頭打ちになる。上限に
      // 届いているクラブでは、商業施設を上げても観客収入は増えない
      // (以前は「観客・スポンサー収入+X%」とだけ出ていた。グッズにも
      // 掛かっているのに書いていなかった。2026-11-23)。
      return Tr.pick(
          'いま: スポンサー・グッズ収入${_pct(cur)}${hasNext ? '\n次のLvで: ${_pct(next)}' : ''}\n'
              '${gateAtCap ? '観客収入は上限(入る人数×1人の単価)に届いているので増えません' : '観客収入にも同じだけ効きます(入る人数×1人の単価の上限まで)'}',
          "Now: sponsorship and merchandise ${_pct(cur)}${hasNext ? '\nNext level: ${_pct(next)}' : ''}\n"
              "${gateAtCap ? 'Gate receipts are already at their ceiling (crowd x revenue per head), so they will not rise' : 'Gate receipts rise by the same, up to their ceiling (crowd x revenue per head)'}");
    case FacilityType.medicalCenter:
      final cur =
          ((1 - ClubInfrastructure.medicalCenterInjuryFactor(level)) * 100)
              .round();
      final next = hasNext
          ? ((1 - ClubInfrastructure.medicalCenterInjuryFactor(level + 1)) *
                  100)
              .round()
          : cur;
      return Tr.pick(
          'いま: 負傷リスク-$cur%(フィジオの分に上乗せ)${hasNext ? '\n次のLvで: -$next%' : ''}',
          "Now: injury risk -$cur% (on top of your physio)${hasNext ? '\nNext level: -$next%' : ''}");
  }
}

/// クラブの画面のどの部分を出すか。横画面ではタブで分け、1ページを短くする
/// (全部を1列に並べると縦に12画面分あった)。null なら全部。
enum ClubSection { staff, facilities, community }

class ClubScreen extends StatelessWidget {
  const ClubScreen({super.key, this.section});

  final ClubSection? section;

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final save = gameState.save!;
    final infra = save.infrastructure;
    final totalLevels = [
      ...StaffRole.values.map(infra.staffLevel),
      ...FacilityType.values.map(infra.facilityLevel),
    ].fold<int>(0, (s, l) => s + l);
    final maxTotalLevels =
        (StaffRole.values.length + FacilityType.values.length) *
            ClubInfrastructure.maxLevel;
    bool show(ClubSection x) => section == null || section == x;

    return Scaffold(
      appBar: AppBar(
        title: Text(Tr.pick('クラブ施設・スタッフ', 'Facilities & staff')),
        leading: const BackButton(),
        actions: const [QuickAccessMenuButton()],
      ),
      drawer: const QuickAccessDrawer(),
      body: ResponsiveBody(
        // 横画面では札を2列に並べ、縦の長さを半分にする。
        child: AutoColumns(
          // スタッフは候補の行が横に長いので1列のまま。
          twoColumnWidth: section == ClubSection.staff ? double.infinity : 640,
          children: [
            // 上の札は細い1行に。資金は上の段に出ているので、横画面では
            // 出さない(2026-11-21)。充実度とスタッフの年俸はスタッフの
            // 集計なので、スタッフのタブ(と全部を出すとき)だけに出す。
            // 施設・ファンと街のタブの上にもそのまま出ていた(2026-11-23)。
            if (!EmbeddedInShell.of(context) || show(ClubSection.staff))
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                // 狭い画面では折り返す(1行に並べきれないことがある)。
                child: Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (!EmbeddedInShell.of(context))
                      Text(
                        Tr.pick('資金 ${formatMoney(save.budget)}',
                            'Funds ${formatMoney(save.budget)}'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    if (show(ClubSection.staff)) ...[
                      Row(
                        key: const ValueKey('club-staff-summary-level'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            Tr.pick('充実度 $totalLevels/$maxTotalLevels',
                                'Development $totalLevels/$maxTotalLevels'),
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 80,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: totalLevels / maxTotalLevels,
                                minHeight: 6,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        Tr.pick(
                            'スタッフの年俸 ${formatMoney(annualFromWeekly(gameState.scaledMoney(infra.totalStaffWeeklyWage)))}',
                            'Staff salaries ${formatMoney(annualFromWeekly(gameState.scaledMoney(infra.totalStaffWeeklyWage)))} a year'),
                        key: const ValueKey('club-staff-summary-wages'),
                        style: TextStyle(
                            fontSize: 12,
                            color: SemanticColors.subtleText(context)),
                      ),
                    ],
                  ],
                ),
              ),
            if (show(ClubSection.staff)) ...[
              Builder(builder: (context) {
                final filled = StaffRole.values
                    .where((r) => gameState.staffFor(r) != null)
                    .length;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: Text(
                    Tr.pick(
                        'スタッフ: ${StaffRole.values.length}役のうち$filled人を雇っています',
                        'Staff: $filled of ${StaffRole.values.length} posts filled'),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                );
              }),
              for (final role in StaffRole.values) _StaffCard(role: role),
              const SizedBox(height: 8),
              const YouthAnalyticsCard(),
            ],
            if (show(ClubSection.facilities)) ...[
              const Divider(height: 32),
              Text(Tr.pick('施設', 'Facilities'),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final type in FacilityType.values)
                _UpgradeCard(
                  title: type.label,
                  description: type.description,
                  level: infra.facilityLevel(type),
                  cost: gameState.facilityUpgradeCostFor(type),
                  costLabel: Tr.pick('建設費', 'Build cost'),
                  extraLabel: _facilityEffectLabel(
                    type,
                    infra.facilityLevel(type),
                    gameState.expectedAttendance,
                    gameState.fanDemand,
                    gateAtCap: gameState.isGateAtCap,
                  ),
                  canAfford:
                      save.budget >= gameState.facilityUpgradeCostFor(type),
                  readyOn: infra.constructionReadyOn(type),
                  buildNote: type == FacilityType.stadium
                      ? Tr.pick(
                          '${formatCount(ClubInfrastructure.stadiumSeatsPerLevel)}席 × 1席${formatMoney(gameState.stadiumSeatCostNow)}。来季の開幕に完成します',
                          '${formatCount(ClubInfrastructure.stadiumSeatsPerLevel)} seats at ${formatMoney(gameState.stadiumSeatCostNow)} each. Ready for the start of next season')
                      : Tr.pick(
                          '工期${ClubInfrastructure.buildMonths}か月。完成までは効き目が出ません',
                          'Takes ${ClubInfrastructure.buildMonths} months. No effect until it is finished'),
                  onUpgrade: () => gameState.upgradeFacility(type),
                ),
              const SizedBox(height: 8),
              const ClubLicenseCard(),
              const SizedBox(height: 8),
              const AffiliateCard(),
            ],
            if (show(ClubSection.community)) ...[
              const SizedBox(height: 8),
              const FanSegmentsCard(),
              const SizedBox(height: 8),
              const ClubLookCard(),
              const SizedBox(height: 8),
              _TicketPricingCard(
                current: save.ticketPricing,
                onSelect: (p) => gameState.setTicketPricing(p),
              ),
              const SizedBox(height: 8),
              const SeasonTicketsCard(),
            ],
          ],
        ),
      ),
    );
  }
}

class _TicketPricingCard extends StatelessWidget {
  final TicketPricing current;
  final ValueChanged<TicketPricing> onSelect;

  const _TicketPricingCard({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TitleWithHelp(
              title: Tr.pick('チケットの値段', 'Ticket pricing'),
              help: Tr.pick(
                  '観客の入りと1人あたりの収入は、片方を取るともう片方が減ります。値上げすると席が埋まりにくくなり、値下げすると満員に近づきます。',
                  'Attendance and revenue per head pull against each other. Raise prices and fewer of your seats fill; lower them and you get closer to a full house.'),
            ),
            const SizedBox(height: 4),
            // 選んだ側の印を外し、字は1行のまま縮める。英語の
            // 「Standard」が「Standa/rd」に割れていた(2026-11-23)。
            SegmentedButton<TicketPricing>(
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                padding: WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 10)),
              ),
              segments: TicketPricing.values
                  .map((p) => ButtonSegment(
                      value: p,
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(p.label, maxLines: 1, softWrap: false),
                      )))
                  .toList(),
              selected: {current},
              onSelectionChanged: (s) => onSelect(s.first),
            ),
            const SizedBox(height: 8),
            Text(
              current.description,
              style: TextStyle(
                  fontSize: 12, color: SemanticColors.subtleText(context)),
            ),
            // サポーターの期待への効き目(試合のある月ごと。2026-11-23)。
            Builder(builder: (context) {
              final d = BoardEngine.ticketMonthlyDelta(current);
              return Text(
                Tr.pick(
                    'サポーターの期待: 試合のある月ごとに ${d > 0 ? '+$d' : d == 0 ? '±0' : '$d'}',
                    'Supporter expectation: ${d > 0 ? '+$d' : d == 0 ? '±0' : '$d'} each month with matches'),
                key: const ValueKey('ticket-supporter-effect'),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: d > 0
                        ? SemanticColors.positive(context)
                        : d < 0
                            ? SemanticColors.negative(context)
                            : SemanticColors.subtleText(context)),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _UpgradeCard extends StatelessWidget {
  final String title;
  final String description;
  final int level;
  final int cost;
  final String costLabel;
  final String? extraLabel;
  final bool canAfford;

  /// 工事中なら完成する日。工事中は重ねて増築できない。
  final DateTime? readyOn;

  /// 工事費の内訳と工期(1行)。
  final String? buildNote;
  final Future<bool> Function() onUpgrade;

  const _UpgradeCard({
    required this.title,
    required this.description,
    required this.level,
    required this.cost,
    required this.costLabel,
    this.extraLabel,
    required this.canAfford,
    this.readyOn,
    this.buildNote,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    const maxLevel = ClubInfrastructure.maxLevel;
    final isMax = level >= maxLevel;
    final building = readyOn != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: List.generate(
                    maxLevel,
                    (i) => Icon(
                      i < level ? Icons.star : Icons.star_border,
                      size: 16,
                      color: SemanticColors.ink(context, Colors.amber, min: 3),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                  fontSize: 12, color: SemanticColors.subtleText(context)),
            ),
            if (extraLabel != null) ...[
              const SizedBox(height: 2),
              Text(
                extraLabel!,
                style: TextStyle(
                    fontSize: 12, color: SemanticColors.subtleText(context)),
              ),
            ],
            if (!isMax && !building && buildNote != null) ...[
              const SizedBox(height: 2),
              Text(
                buildNote!,
                style: TextStyle(
                    fontSize: 12, color: SemanticColors.subtleText(context)),
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              // この箱の主な操作なので塗りのボタン。
              child: FilledButton(
                onPressed: isMax || building || !canAfford
                    ? null
                    : () async {
                        final ok = await runUndoable(
                          context,
                          action: onUpgrade,
                          done: Tr.pick(
                              '「$title」の増築に着工しました', 'Work has begun: $title'),
                        );
                        ok
                            ? FeedbackService.success()
                            : FeedbackService.error();
                      },
                child: Text(building
                    ? Tr.pick(
                        '工事中(${TransferWindowCalendar.formatYearMonth(readyOn!)}完成)',
                        'Under construction (ready ${TransferWindowCalendar.formatYearMonth(readyOn!)})')
                    : isMax
                        ? Tr.pick('最大レベル', 'Fully upgraded')
                        // 英語は「Upgrade for 150m yen (Build cost)」と
                        // 札を括弧で後ろに付けていて不自然だった(2026-11-23)。
                        : Tr.pick('$costLabel ${formatMoney(cost)}で増築',
                            'Upgrade for ${formatMoney(cost)}')),
              ),
            ),
            // 工事中・最大はボタンの字で分かる。資金が足りないときだけ、字が
            // 「…で増築」のまま灰色になるので、足りない額を下に出す。
            if (!isMax && !building && !canAfford)
              DisabledReason(
                fundsShortReason(
                    cost - (context.watch<GameState>().save?.budget ?? 0)),
                key: const ValueKey('upgrade-blocked'),
              ),
          ],
        ),
      ),
    );
  }
}
