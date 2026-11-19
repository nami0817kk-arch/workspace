part of 'club_screen.dart';

/// 役職1つぶんのカード。いま就いている人と、雇える候補を出す。
///
/// 以前は「金を払えばレベルが1つ上がる」だった。誰を雇っても同じ結果で、
/// 資金以外の判断が無かった。人にすると、能力の偏り・週俸・年齢・契約年数を
/// 見て選ぶことになる。
class _StaffCard extends StatelessWidget {
  final StaffRole role;
  const _StaffCard({required this.role});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final current = gameState.staffFor(role);
    final candidates = gameState.staffCandidatesFor(role);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(role.label, style: Theme.of(context).textTheme.titleSmall),
            Text(
              role.description,
              style: TextStyle(
                  fontSize: 12, color: SemanticColors.subtleText(context)),
            ),
            const SizedBox(height: 8),
            if (current == null)
              Text(
                Tr.pick('空席です。就いている人がいない間、この役職の効果はありません。',
                    'Vacant. Nothing works in this post while it is empty.'),
                style: TextStyle(
                    fontSize: 12, color: SemanticColors.negative(context)),
              )
            else ...[
              _StaffRow(
                staff: current,
                trailing: TextButton(
                  onPressed: () => gameState.dismissStaff(role),
                  child: Text(current.severance > 0
                      ? Tr.pick('解任(違約金${formatMoney(context.read<GameState>().scaledMoney(current.severance))})',
                          'Dismiss (severance ${formatMoney(context.read<GameState>().scaledMoney(current.severance))})')
                      : Tr.pick('解任', 'Dismiss')),
                ),
              ),
              Text(
                _staffEffectLabel(role, current.effectiveLevel,
                    member: current,
                    tier: context.read<GameState>().currentDivisionTier),
                style: TextStyle(
                    fontSize: 11, color: SemanticColors.subtleText(context)),
              ),
              if (role == StaffRole.manager) const _ManagerTargetPanel(),
            ],
            if (candidates.isNotEmpty) ...[
              const Divider(height: 20),
              Text(
                Tr.pick('雇える候補', 'Available to hire'),
                style: TextStyle(
                    fontSize: 12, color: SemanticColors.subtleText(context)),
              ),
              const SizedBox(height: 4),
              for (final c in candidates)
                _StaffRow(
                  staff: c,
                  trailing: FilledButton(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final ok = await gameState.hireStaff(c.id);
                      if (!ok) {
                        messenger.showSnackBar(SnackBar(
                          content: Text(gameState.lastSigningBlockReason ??
                              Tr.pick('給与予算が足りません。',
                                  'Your wage budget will not cover him.')),
                        ));
                      }
                    },
                    child: Text(Tr.pick('雇う', 'Hire')),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// スタッフ1人ぶんの行。役職に効く能力だけを出す。
///
/// 4項目すべてを並べると、その役職では働かない能力まで比較材料に見えて
/// しまう。スカウトに指導の高さは関係ない。
class _StaffRow extends StatelessWidget {
  final StaffMember staff;
  final Widget trailing;
  const _StaffRow({required this.staff, required this.trailing});

  @override
  Widget build(BuildContext context) {
    final weights = staffRoleWeights(staff.role);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text('${staff.name} (${staff.age})',
                          overflow: TextOverflow.ellipsis),
                    ),
                    // 得意分野。ユースコーチなら、ここが有望株の伸びる
                    // 能力を決める。万能のときは札を出さない(全員に
                    // 付くと見分けの役に立たない)。
                    if (staff.specialty != StaffSpecialty.balanced) ...[
                      const SizedBox(width: 6),
                      Tooltip(
                        message: staff.specialty.description,
                        child: Chip(
                          label: Text(staff.specialty.label,
                              style: const TextStyle(fontSize: 10)),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ],
                ),
                // **1行につなげない。** 「指導 5 / 動機づけ 9 / 週俸13万円 /
                // 契約2年」と並べると、どこが数字でどこが見出しなのか
                // 目で切り分ける必要があった。雇うかどうかは能力で決めるので、
                // 能力の数字だけを拾って読める形にする。
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final a in weights.keys)
                      StatChip(
                        label: a.label,
                        value: '${staff.attribute(a)}',
                        // この役割で効く能力ほど濃く出す。
                        color: (weights[a] ?? 0) >= 0.5
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    StatChip(
                      label: Tr.pick('年俸', 'Salary'),
                      value: formatMoney(annualFromWeekly(
                          context.read<GameState>().scaledMoney(staff.wage))),
                    ),
                    StatChip(
                      label: Tr.pick('契約', 'Deal'),
                      value: Tr.pick('${staff.contractYears}年',
                          '${staff.contractYears}y'),
                    ),
                  ],
                ),
                if (staff.manager != null) _ManagerProfileLines(staff: staff),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

/// 監督の考え方・好みの布陣・経歴・(候補なら)今の所属と補償金。
class _ManagerProfileLines extends StatelessWidget {
  final StaffMember staff;
  const _ManagerProfileLines({required this.staff});

  @override
  Widget build(BuildContext context) {
    final m = staff.manager!;
    final small =
        TextStyle(fontSize: 11, color: SemanticColors.subtleText(context));
    final recent = m.career.reversed.take(3).toList();
    String season(int y) => '${y - 1}/${(y % 100).toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            Tr.pick('考え方: ${m.style.label}(${m.style.description})・好みの布陣 ${m.formation.label}',
                'Style: ${m.style.label} (${m.style.description}) • Preferred shape ${m.formation.label}'),
            style: small,
          ),
          if (m.employerClubName != null)
            Text(
              Tr.pick(
                  'いま${m.employerClubName}で指揮している。引き抜きには補償金${formatMoney(context.read<GameState>().scaledMoney(m.compensation))}',
                  'Currently in charge at ${m.employerClubName}. Compensation to prise him away: ${formatMoney(context.read<GameState>().scaledMoney(m.compensation))}'),
              style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
            ),
          if (recent.isNotEmpty)
            Text(
              Tr.pick(
                  '経歴: ${recent.map((c) => '${season(c.season)} ${c.club}(${c.tier}部) ${c.rank}位').join('、')}',
                  'Record: ${recent.map((c) => '${season(c.season)} ${c.club} (tier ${c.tier}) ${c.rank}/${c.teams}').join(', ')}'),
              style: small,
            ),
        ],
      ),
    );
  }
}

/// 今季の目標の順位と、監督の立場。
class _ManagerTargetPanel extends StatelessWidget {
  const _ManagerTargetPanel();

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final teams = gameState.save!.league.teams.length;
    final target = gameState.managerTarget;
    final standing = gameState.managerStanding;
    final color = standing < ManagerHrEngine.warningStanding
        ? SemanticColors.negative(context)
        : Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(Tr.pick(
                    '今季の目標: $target位(戦力どおりなら${gameState.suggestedManagerTarget}位)',
                    'Target this season: position $target (squad strength says ${gameState.suggestedManagerTarget})')),
              ),
              IconButton(
                tooltip: Tr.pick('目標を上げる', 'Raise the target'),
                onPressed: target > 1
                    ? () => gameState.setManagerTarget(target - 1)
                    : null,
                icon: const Icon(Icons.arrow_upward),
              ),
              IconButton(
                tooltip: Tr.pick('目標を下げる', 'Lower the target'),
                onPressed: target < teams
                    ? () => gameState.setManagerTarget(target + 1)
                    : null,
                icon: const Icon(Icons.arrow_downward),
              ),
            ],
          ),
          Text(Tr.pick('監督の立場: $standing / 100', 'Manager standing: $standing / 100')),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: standing / 100, color: color),
          const SizedBox(height: 4),
          Text(
            Tr.pick(
                '目標の順位を下回る節が続くと立場が下がり、${ManagerHrEngine.warningStanding}を割ると「危うい」と報じられます。解任すると、残りの契約の年俸を全額払います。',
                'Each matchday below the target erodes his standing; under ${ManagerHrEngine.warningStanding} the press call him under pressure. Sacking him costs the rest of his contract in full.'),
            style: TextStyle(
                fontSize: 11, color: SemanticColors.subtleText(context)),
          ),
        ],
      ),
    );
  }
}
