import 'dart:math' as math;

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
import '../logic/todo_advisor.dart';
import '../widgets/community_card.dart';
import '../widgets/place_link.dart';
import '../l10n/tr.dart';
import '../models/staff_member.dart';
import '../theme/semantic_colors.dart';
import '../widgets/youth_analytics_card.dart';
import '../widgets/fan_segments_card.dart';
import '../widgets/club_look_card.dart';
import '../widgets/club_license_card.dart';
import '../widgets/season_tickets_card.dart';
import '../logic/economy_scale.dart';
import '../widgets/help_button.dart';
import '../widgets/screen_bar.dart';
import '../widgets/disabled_reason.dart';
import '../widgets/offseason_lock_note.dart';
import '../widgets/fm_panel.dart';
import 'staff_negotiation_screen.dart';

part 'club_screen_staff.dart';
part 'club_screen_facilities.dart';
part 'club_screen_community.dart';

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
          // 施設も表なので1列で横いっぱいに(2026-11-25)。
          twoColumnWidth:
              section == ClubSection.staff || section == ClubSection.facilities
                  ? double.infinity
                  : 640,
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
                        'スタッフ: ${StaffRole.values.length}役のうち$filled役が埋まっています(${infra.allStaff.length}人)',
                        'Staff: $filled of ${StaffRole.values.length} posts filled (${infra.allStaff.length} people)'),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                );
              }),
              // 人事の委託を上に(任せると下の表は見るだけで済む)。
              const _StaffDelegationPanel(),
              const _StaffTable(),
              // 分析部門はスタッフの一部門として残す(U18・U21 はユースへ
              // 移した。2026-11-25)。
              const AnalyticsDepartmentCard(),
            ],
            if (show(ClubSection.facilities))
              // 施設は表にした(2026-11-25): 水準・いま・次の段で・費用と
              // 期間・工事中が1行ずつ並ぶ。下の札とまとめて1つの塊にする
              // (一覧が大きな表1つの高さから全体の長さを見積もり、実際の
              // 4倍近い長さに見せていた)。
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _FacilityTable(),
                  const SizedBox(height: 8),
                  const ClubLicenseCard(),
                  const SizedBox(height: 8),
                  // 系列クラブ(選手の貸し借り)は移籍の話なので、移籍の「探す」へ
                  // 移した(2026-11-25)。ここには入口だけを置く。
                  PlaceLink(
                    key: const ValueKey('club-to-affiliate'),
                    icon: Icons.handshake_outlined,
                    title: Tr.pick('系列クラブは「移籍 > 探す」へ',
                        'Feeder club: open Transfers > Search'),
                    note: Tr.pick('親子の関係・貸し出し・育成先・優先交渉権・売却時の取り分を決めて結びます。',
                        'Set the parent club, loans, development, first refusal and sell-on share.'),
                    place: TodoPlaces.transferAffiliate,
                  ),
                ],
              ),
            if (show(ClubSection.community)) ...[
              // 上に数字とオフシーズンの決まり、その下に操作(チケット・
              // 季席・見た目・地域活動)、最後に客層の内訳(2026-11-25)。
              const _FansCityOverview(),
              _TicketPricingCard(
                current: save.ticketPricing,
                locked: !gameState.isOffseason,
                onSelect: (p) => gameState.setTicketPricing(p),
              ),
              const SizedBox(height: 8),
              const SeasonTicketsCard(),
              const SizedBox(height: 8),
              const ClubLookCard(),
              const SizedBox(height: 8),
              // 地域の用件はここに寄せる(地域貢献は、以前は経営の
              // 「備えと地域貢献」にあった)。
              const CommunityCard(),
              PlaceLink(
                key: const ValueKey('club-to-community-works'),
                icon: Icons.work_outline,
                title: Tr.pick('チャリティー・学校訪問は「オーナーの仕事」へ',
                    "Charity and school visits: open Owner's work"),
                note: Tr.pick('オーナーが自分で出向く手(1シーズンに1回ずつ)は、オーナー室にまとめてあります。',
                    "Things you do in person (once a season each) are in the owner's office."),
                place: TodoPlaces.ownerCommunityWorks,
              ),
              const SizedBox(height: 8),
              const FanSegmentsCard(),
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

  /// シーズン中か(変えられるのはオフシーズンだけ。2026-11-25)。
  final bool locked;

  const _TicketPricingCard(
      {required this.current, required this.onSelect, required this.locked});

  @override
  Widget build(BuildContext context) {
    if (locked) {
      return Card(
        key: const ValueKey('ticket-locked'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(Tr.pick('チケットの値段', 'Ticket pricing'),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              OffseasonLockNote(current.label),
            ],
          ),
        ),
      );
    }
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
