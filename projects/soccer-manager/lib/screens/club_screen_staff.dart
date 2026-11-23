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

    // 役職ごとに見出しの1行(役職・効き目・いまの人)。候補はいつも畳み、
    // 「候補を見る」で開く。始めは全役職が空いていて、赤い空席の文と
    // 候補3人ずつが並び、タブが画面7つ分あった(2026-11-21)。
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(role.label,
                          style: Theme.of(context).textTheme.titleSmall),
                      Text(
                        role.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            color: SemanticColors.subtleText(context)),
                      ),
                    ],
                  ),
                ),
                if (current == null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 2),
                    child: Text(
                      Tr.pick('まだいません', 'Not filled'),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: SemanticColors.ink(
                              context, Colors.orange.shade700)),
                    ),
                  ),
              ],
            ),
            if (current != null) ...[
              _StaffRow(
                staff: current,
                trailing: TextButton(
                  onPressed: () => gameState.dismissStaff(role),
                  child: Text(gameState.staffSeveranceFor(current) > 0
                      ? Tr.pick(
                          '解任(違約金${formatMoney(gameState.staffSeveranceFor(current))})',
                          'Dismiss (severance ${formatMoney(gameState.staffSeveranceFor(current))})')
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
              if (gameState.staffOfferFor(role) case final offer?)
                _StaffOfferBox(offer: offer),
            ],
            // 候補の一覧はいつも畳んでおき、押すと表で開く。
            if (candidates.isNotEmpty)
              Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    Tr.pick('候補を見る(${candidates.length}人)',
                        'See candidates (${candidates.length})'),
                    style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.primary),
                  ),
                  children: [_candidateTable(context, candidates)],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 候補の表。同じ役職の候補は効く能力が同じなので、能力を列にそろえて
  /// 見比べられるようにする(2026-11-21)。
  Widget _candidateTable(BuildContext context, List<StaffMember> list) {
    final weights = staffRoleWeights(role);
    final gs = context.read<GameState>();
    final scheme = Theme.of(context).colorScheme;
    final head = TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: scheme.onSurfaceVariant);
    const small = TextStyle(fontSize: 12);
    Widget cell(String s, double w, TextStyle st) => SizedBox(
          width: w,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(s, style: st),
          ),
        );
    return Column(
      children: [
        Container(
          color: scheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Expanded(child: Text(Tr.pick('名前', 'Name'), style: head)),
              for (final a in weights.keys) cell(a.label, 56, head),
              cell(Tr.pick('年俸', 'Salary'), 60, head),
              cell(Tr.pick('契約', 'Until'), 64, head),
              const SizedBox(width: 72),
            ],
          ),
        ),
        for (final (i, c) in list.indexed)
          Container(
            color: i.isOdd ? scheme.surfaceContainerLow : null,
            padding: const EdgeInsets.only(left: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(
                              text: '${c.name} (${c.age})',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          if (c.shownSpecialty != StaffSpecialty.balanced)
                            TextSpan(
                                text: '  ${c.shownSpecialty.label}',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: SemanticColors.subtleText(context))),
                          if (c.formerPlayerId != null)
                            TextSpan(
                                text: Tr.pick('  うちのOB', '  One of ours'),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: SemanticColors.subtleText(context))),
                        ]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: small,
                      ),
                    ),
                    for (final a in weights.keys)
                      cell(
                          '${c.attribute(a)}',
                          56,
                          small.copyWith(
                              fontWeight: (weights[a] ?? 0) >= 0.5
                                  ? FontWeight.bold
                                  : null,
                              color: (weights[a] ?? 0) >= 0.5
                                  ? scheme.primary
                                  : null)),
                    cell(formatMoney(annualFromWeekly(gs.scaledMoney(c.wage))),
                        60, small),
                    cell(
                        Tr.pick(
                            '${Player.contractClockYear + c.contractYears - 1}/6',
                            '6/${Player.contractClockYear + c.contractYears - 1}'),
                        64,
                        small),
                    SizedBox(width: 72, child: _hireButton(context, c)),
                  ],
                ),
                if (c.manager != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6, right: 8),
                    child: _ManagerProfileLines(staff: c),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _hireButton(BuildContext context, StaffMember c) {
    final gameState = context.read<GameState>();
    return TextButton(
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        final ok = await runUndoable(
          context,
          action: () => gameState.hireStaff(c.id),
          done: Tr.pick('${c.name}を雇いました', 'Hired ${c.name}'),
        );
        if (!ok) {
          messenger.showSnackBar(SnackBar(
            content: Text(gameState.lastSigningBlockReason ??
                Tr.pick('給与予算が足りません。', 'Your wage budget will not cover him.')),
          ));
        }
      },
      child: Text(Tr.pick('雇う', 'Hire')),
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
                    if (staff.shownSpecialty != StaffSpecialty.balanced) ...[
                      const SizedBox(width: 6),
                      Tooltip(
                        message: staff.shownSpecialty.description,
                        child: Chip(
                          label: Text(staff.shownSpecialty.label,
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
                      value: Tr.pick(
                          '${Player.contractClockYear + staff.contractYears - 1}年6月まで',
                          'to June ${Player.contractClockYear + staff.contractYears - 1}'),
                    ),
                    if (staff.formerPlayerId != null)
                      StatChip(
                        label: Tr.pick('元選手', 'Ex-player'),
                        value: Tr.pick('うちのOB', 'One of ours'),
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
            Tr.pick(
                '考え方: ${m.style.label}(${m.style.description})・好みの布陣 ${m.formation.label}',
                'Style: ${m.style.label} (${m.style.description}) • Preferred shape ${m.formation.label}'),
            style: small,
          ),
          // 試合の中の戦い方は、この考え方で監督が毎節決める(オーナーは
          // 選べない)。雇う前に分かるよう、候補にも出す。
          Text(
            Tr.pick('この監督の戦い方: ${ManagerTactics.summary(m.style)}',
                "How he sets up: ${ManagerTactics.summary(m.style)}"),
            style: small,
          ),
          if (m.employerClubName != null)
            Text(
              Tr.pick(
                  'いま${m.employerClubName}で指揮している。引き抜きには補償金${formatMoney(context.read<GameState>().scaledMoney(m.compensation))}',
                  'Currently in charge at ${m.employerClubName}. Compensation to prise him away: ${formatMoney(context.read<GameState>().scaledMoney(m.compensation))}'),
              style: TextStyle(
                  fontSize: 11,
                  color: SemanticColors.ink(context, Colors.orange.shade800)),
            ),
          if (recent.isNotEmpty)
            Text(
              Tr.pick(
                  '経歴: ${recent.map((c) => '${season(c.season)} ${c.club}(${c.tier}部) ${c.rank}位').join('、')}',
                  'Record: ${recent.map((c) => '${season(c.season)} ${c.club} (Tier ${c.tier}) ${c.rank}/${c.teams}').join(', ')}'),
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
          Text(Tr.pick(
              '監督の立場: $standing / 100', 'Manager standing: $standing / 100')),
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

/// 他のクラブからの引き抜きの話(手放す/昇給して残す)。
class _StaffOfferBox extends StatelessWidget {
  final StaffOffer offer;
  const _StaffOfferBox({required this.offer});

  @override
  Widget build(BuildContext context) {
    final gameState = context.read<GameState>();
    final comp = formatMoney(gameState.scaledMoney(offer.compensation));
    final until = TransferWindowCalendar.formatMonthDay(offer.expiresOn);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.orange.shade700),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            Tr.pick(
                '${offer.clubName}が${offer.staffName}を引き抜きに来ています。補償金$comp。$untilまでに決めなければ移っていきます。',
                '${offer.clubName} want ${offer.staffName}. Compensation: $comp. Decide by $until or he leaves.'),
            style: TextStyle(
                fontSize: 12,
                color: SemanticColors.ink(context, Colors.orange.shade800)),
          ),
          OverflowBar(
            alignment: MainAxisAlignment.end,
            spacing: 8,
            children: [
              TextButton(
                onPressed: () => gameState.releaseStaffToOffer(offer.id),
                child: Text(Tr.pick('手放す', 'Let him go')),
              ),
              FilledButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final ok = await gameState.keepStaffWithRaise(offer.id);
                  if (!ok) {
                    messenger.showSnackBar(SnackBar(
                        content: Text(gameState.lastSigningBlockReason ??
                            Tr.pick('残せませんでした。', 'He could not be kept.'))));
                  }
                },
                // 残すと契約も1年延びる(keepStaffWithRaise)。押す前に
                // 分かるよう、ボタンにも書く(2026-11-23)。
                child: Text(Tr.pick('昇給(+${offer.raisePercent}%)・契約+1年で残す',
                    'Keep him (+${offer.raisePercent}% pay, +1 year)')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
