part of 'club_screen.dart';

/// 施設の効き目: いま・次の段で・ひとこと(2026-11-25 の第6段で表にした)。
({String now, String? next, String? note}) _facilityEffects(
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
      final ng = ClubInfrastructure.trainingGrowthMultiplier(1, level + 1);
      final nf = ClubInfrastructure.fatigueRecoveryBonus(level + 1);
      return (
        now: Tr.pick('練習の伸び${_pct(g)}・疲労回復+$f',
            'Training growth ${_pct(g)}, recovery +$f'),
        next: hasNext
            ? Tr.pick('伸び${_pct(ng)}・回復+$nf', 'Growth ${_pct(ng)}, recovery +$nf')
            : null,
        note: null,
      );
    case FacilityType.stadium:
      final cur = ClubInfrastructure.stadiumCapacity(level);
      final next = ClubInfrastructure.stadiumCapacity(level + 1);
      // 人数は3桁で区切る(「12000人」が読みにくかった。2026-11-23)。
      return (
        now: Tr.pick('${formatCount(cur)}人入る', 'Holds ${formatCount(cur)}'),
        next: hasNext
            ? Tr.pick('${formatCount(next)}人', 'Holds ${formatCount(next)}')
            : null,
        note: Tr.pick(
            'ふだんの入り${formatCount(expectedAttendance)}人・来たいファン${formatCount(fanDemand)}人',
            'Usual crowd ${formatCount(expectedAttendance)}, fans wanting to come ${formatCount(fanDemand)}'),
      );
    case FacilityType.youthFacility:
      final cur = ScoutingEngine.maxProspectsFor(level);
      final next = ScoutingEngine.maxProspectsFor(level + 1);
      return (
        now: Tr.pick('昇格候補の枠$cur人', '$cur academy places'),
        next: hasNext ? Tr.pick('枠$next人', '$next places') : null,
        note: Tr.pick('ユースコーチを雇える人数にも効きます',
            'Also lets you employ more youth coaches'),
      );
    case FacilityType.commercialFacility:
      final cur = ClubInfrastructure.commercialRevenueMultiplier(level);
      final next = ClubInfrastructure.commercialRevenueMultiplier(level + 1);
      // 観客収入は、入る人数 × 1人の単価の上限で頭打ちになる(2026-11-23)。
      return (
        now: Tr.pick('スポンサー・グッズ収入${_pct(cur)}',
            'Sponsorship and merchandise ${_pct(cur)}'),
        next: hasNext ? Tr.pick('収入${_pct(next)}', 'Income ${_pct(next)}') : null,
        note: gateAtCap
            ? Tr.pick('観客収入は上限(入る人数×1人の単価)に届いているので増えません',
                'Gate receipts are already at their ceiling (crowd x revenue per head), so they will not rise')
            : Tr.pick('観客収入にも同じだけ効きます(入る人数×1人の単価の上限まで)',
                'Gate receipts rise by the same, up to their ceiling (crowd x revenue per head)'),
      );
    case FacilityType.medicalCenter:
      int cut(int l) =>
          ((1 - ClubInfrastructure.medicalCenterInjuryFactor(l)) * 100).round();
      return (
        now: Tr.pick('負傷リスク-${cut(level)}%', 'Injury risk -${cut(level)}%'),
        next: hasNext
            ? Tr.pick('-${cut(level + 1)}%', '-${cut(level + 1)}%')
            : null,
        note: Tr.pick('フィジオの分に上乗せ。フィジオを雇える人数にも効きます',
            'On top of your physios. Also lets you employ more physios'),
      );
  }
}

/// 施設の表: 施設・水準・いま・次の段で・費用と期間・操作。
class _FacilityTable extends StatelessWidget {
  const _FacilityTable();

  static const double _levelW = 70;
  static const double _actionW = 150;

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final scheme = Theme.of(context).colorScheme;
    final head = TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: scheme.onSurfaceVariant);
    final building = FacilityType.values
        .where((t) => gs.save!.infrastructure.isUnderConstruction(t))
        .length;
    return FmPanel(
      key: const ValueKey('facility-table'),
      title: Tr.pick('施設', 'Facilities'),
      trailing: building == 0
          ? null
          : Text(Tr.pick('工事中 $building件', '$building under construction'),
              style: TextStyle(
                  fontSize: 12,
                  color: SemanticColors.ink(context, Colors.orange.shade800))),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: scheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text(Tr.pick('施設', 'Facility'), style: head)),
                SizedBox(width: _levelW, child: Text(Tr.pick('水準', 'Level'), style: head)),
                Expanded(flex: 4, child: Text(Tr.pick('いま', 'Now'), style: head)),
                Expanded(flex: 3, child: Text(Tr.pick('次の段で', 'Next level'), style: head)),
                Expanded(flex: 3, child: Text(Tr.pick('費用・期間', 'Cost and time'), style: head)),
                const SizedBox(width: _actionW),
              ],
            ),
          ),
          for (final type in FacilityType.values) _FacilityRow(type: type),
        ],
      ),
    );
  }
}

class _FacilityRow extends StatelessWidget {
  const _FacilityRow({required this.type});
  final FacilityType type;

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final save = gs.save!;
    final infra = save.infrastructure;
    final level = infra.facilityLevel(type);
    final cost = gs.facilityUpgradeCostFor(type);
    final readyOn = infra.constructionReadyOn(type);
    final isMax = level >= ClubInfrastructure.maxLevel;
    final building = readyOn != null;
    final canAfford = save.budget >= cost;
    final fx = _facilityEffects(
        type, level, gs.expectedAttendance, gs.fanDemand,
        gateAtCap: gs.isGateAtCap);
    final subtle = SemanticColors.subtleText(context);
    const small = TextStyle(fontSize: 12);
    final time = type == FacilityType.stadium
        ? Tr.pick('来季の開幕に完成', 'Ready next season')
        : Tr.pick('工期${ClubInfrastructure.buildMonths}か月',
            '${ClubInfrastructure.buildMonths} months');
    // 行ごとに Card にする(押せない理由をその行の中に出すため)。見た目は
    // 表の1行(角を立て、影と余白を消す)。
    return Card(
      key: ValueKey('facility-row-${type.name}'),
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.transparent,
      shape: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Tooltip(
                    message: type.description,
                    triggerMode: TooltipTriggerMode.tap,
                    child: Text(type.label,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
                SizedBox(
                  width: _FacilityTable._levelW,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Lv$level/${ClubInfrastructure.maxLevel}',
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.bold)),
                      SizedBox(
                        width: 60,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: level / ClubInfrastructure.maxLevel,
                            minHeight: 5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(flex: 4, child: Text(fx.now, style: small)),
                Expanded(
                  flex: 3,
                  child: Text(
                      isMax
                          ? Tr.pick('最大です', 'Fully upgraded')
                          : building
                              ? Tr.pick('完成すると: ${fx.next}', 'When ready: ${fx.next}')
                              : fx.next ?? '-',
                      style: small.copyWith(
                          color: isMax ? subtle : SemanticColors.positive(context))),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                      isMax ? '-' : '${formatMoney(cost)}\n$time',
                      style: small),
                ),
                SizedBox(
                  width: _FacilityTable._actionW,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10)),
                      onPressed: isMax || building || !canAfford
                          ? null
                          : () async {
                              final ok = await runUndoable(
                                context,
                                action: () => gs.upgradeFacility(type),
                                done: Tr.pick('「${type.label}」の増築に着工しました',
                                    'Work has begun: ${type.label}'),
                              );
                              ok
                                  ? FeedbackService.success()
                                  : FeedbackService.error();
                            },
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          building
                              ? Tr.pick(
                                  '工事中(${TransferWindowCalendar.formatYearMonth(readyOn)}完成)',
                                  'Building (ready ${TransferWindowCalendar.formatYearMonth(readyOn)})')
                              : isMax
                                  ? Tr.pick('最大レベル', 'Fully upgraded')
                                  : Tr.pick('${formatMoney(cost)}で増築',
                                      'Upgrade for ${formatMoney(cost)}'),
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (fx.note != null || type == FacilityType.stadium && !isMax && !building)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  [
                    if (fx.note != null) fx.note!,
                    if (type == FacilityType.stadium && !isMax && !building)
                      Tr.pick(
                          '${formatCount(ClubInfrastructure.stadiumSeatsPerLevel)}席 × 1席${formatMoney(gs.stadiumSeatCostNow)}',
                          '${formatCount(ClubInfrastructure.stadiumSeatsPerLevel)} seats at ${formatMoney(gs.stadiumSeatCostNow)} each'),
                  ].join(Tr.pick('。', '. ')),
                  style: TextStyle(fontSize: 11, color: subtle),
                ),
              ),
            // 工事中・最大はボタンの字で分かる。資金が足りないときだけ、
            // 足りない額を出す。
            if (!isMax && !building && !canAfford)
              Align(
                alignment: Alignment.centerRight,
                child: DisabledReason(
                  fundsShortReason(cost - save.budget),
                  key: const ValueKey('upgrade-blocked'),
                  alignEnd: true,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
