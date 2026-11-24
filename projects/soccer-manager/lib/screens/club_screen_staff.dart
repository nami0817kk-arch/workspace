part of 'club_screen.dart';

/// スタッフの表(2026-11-25 の第6段。FM のスタッフの画面に寄せた)。
///
/// 役職ごとに1つの塊: 見出しの行(役職・人数/上限・役職の質・効き目・
/// 候補)の下に、雇っている人を1行ずつ(名前・役職の能力・年俸・契約の
/// 残り・契約/解任)。役職・人数・能力・年俸・契約の残りが一目で並ぶ。
/// 雇うのも契約を延ばすのも、選手と同じ交渉の画面で決める。
class _StaffTable extends StatelessWidget {
  const _StaffTable();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final head = TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: scheme.onSurfaceVariant);
    return FmPanel(
      key: const ValueKey('staff-table'),
      title: Tr.pick('スタッフ', 'Staff'),
      padding: EdgeInsets.zero,
      // 狭いとき(縦画面・2列に割ったとき)は、列をやめて1人を2段で出す。
      child: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth / MediaQuery.textScalerOf(context).scale(1) >=
            _StaffCols.wideWidth;
        return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (wide)
          Container(
            color: scheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              children: [
                Expanded(flex: 5, child: Text(Tr.pick('名前', 'Name'), style: head)),
                _cell(Tr.pick('能力', 'Ability'), _StaffCols.ability, head),
                _cell(Tr.pick('年俸', 'Salary'), _StaffCols.wage, head),
                _cell(Tr.pick('契約の残り', 'Contract'), _StaffCols.contract, head),
                const SizedBox(width: _StaffCols.actions),
              ],
            ),
          ),
          for (final role in StaffRole.values)
            _StaffRoleBlock(role: role, wide: wide),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
            child: Text(
              Tr.pick(
                  '能力はその役職に効く能力のまとめ(1〜20)。スカウト・フィジオ・ユースコーチ・フィットネスコーチは何人か雇え、2人目からは逓減して上乗せされます(人数の上限は部と施設で増えます)。',
                  'Ability is the blend of what matters for the role (1-20). You can hire several scouts, physios, youth coaches and fitness coaches; each extra one adds less than the last (the limit grows with your division and facilities).'),
              style: TextStyle(
                  fontSize: 11, color: SemanticColors.subtleText(context)),
            ),
          ),
        ],
      );
      }),
    );
  }
}

/// 表の列の幅。
class _StaffCols {
  /// これより狭ければ、列をやめて2段にする。
  static const double wideWidth = 600;
  static const double ability = 56;
  static const double wage = 84;
  static const double contract = 84;
  static const double actions = 132;
}

Widget _cell(String s, double w, TextStyle st, {Alignment align = Alignment.center}) =>
    SizedBox(
      width: w,
      child: Align(
        alignment: align,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(s, style: st, maxLines: 1),
        ),
      ),
    );

/// 能力(1-20)の色。
Color _abilityColor(BuildContext context, double a) => a >= 15
    ? SemanticColors.positive(context)
    : a >= 9
        ? Theme.of(context).colorScheme.primary
        : SemanticColors.subtleText(context);

/// 役職1つぶん: 見出しの行と、雇っている人の行。
class _StaffRoleBlock extends StatelessWidget {
  const _StaffRoleBlock({required this.role, required this.wide});
  final StaffRole role;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final members = gs.staffMembersFor(role);
    final max = gs.maxStaffFor(role);
    final candidates = gs.staffCandidatesFor(role);
    final scheme = Theme.of(context).colorScheme;
    final level = gs.staffRoleLevel(role);
    final subtle = SemanticColors.subtleText(context);
    return Container(
      key: ValueKey('staff-role-${role.name}'),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 見出しの行。
          Container(
            color: scheme.surfaceContainer,
            padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(role.label,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold)),
                      Text(
                        Tr.pick('${members.length}/$max人',
                            '${members.length}/$max'),
                        key: ValueKey('staff-count-${role.name}'),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: members.isEmpty
                                ? SemanticColors.ink(
                                    context, Colors.orange.shade700)
                                : subtle),
                      ),
                      Text(Tr.pick('質 Lv$level', 'Level $level'),
                          style: TextStyle(fontSize: 12, color: subtle)),
                      Text(
                        _staffEffectLabel(role, level,
                            member: members.firstOrNull,
                            tier: gs.currentDivisionTier),
                        style: TextStyle(fontSize: 11, color: subtle),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  key: ValueKey('staff-candidates-${role.name}'),
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8)),
                  onPressed: candidates.isEmpty
                      ? null
                      : () => _showCandidates(context, role),
                  child: Text(
                      candidates.isEmpty
                          ? Tr.pick('候補なし', 'No candidates')
                          : members.length < max
                              ? Tr.pick('雇う(候補${candidates.length})',
                                  'Hire (${candidates.length})')
                              : Tr.pick('入れ替え(候補${candidates.length})',
                                  'Replace (${candidates.length})'),
                      style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          if (members.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              child: Text(
                Tr.pick('空き(この役職の仕事は最低限になります)',
                    'Vacant (this work is only done at the most basic level)'),
                style: TextStyle(
                    fontSize: 12,
                    color: SemanticColors.ink(context, Colors.orange.shade700)),
              ),
            ),
          for (final (i, m) in members.indexed)
            _StaffMemberRow(
                staff: m, lead: i == 0 && members.length > 1, wide: wide),
          if (role == StaffRole.manager && members.isNotEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(10, 0, 10, 6),
              child: _ManagerTargetPanel(),
            ),
          if (gs.staffOfferFor(role) case final offer?)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
              child: _StaffOfferBox(offer: offer),
            ),
        ],
      ),
    );
  }
}

/// 雇っている人の1行。
class _StaffMemberRow extends StatelessWidget {
  const _StaffMemberRow(
      {required this.staff, required this.lead, required this.wide});
  final StaffMember staff;
  final bool wide;

  /// 何人かいる役職の主任か(札を付ける)。
  final bool lead;

  @override
  Widget build(BuildContext context) {
    final gs = context.read<GameState>();
    final subtle = SemanticColors.subtleText(context);
    final ability = staff.roleAbility;
    final weeks = staff.weeksLeftOn(gs.today, Player.contractClockYear);
    final endYear = Player.contractClockYear + staff.contractYears - 1;
    final expiring = staff.contractYears <= 1;
    final severance = gs.staffSeveranceFor(staff);
    final abilityStyle = TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: _abilityColor(context, ability));
    final contractText =
        Tr.pick('$endYear/6($weeks週)', '6/$endYear ($weeks wk)');
    final contractStyle = TextStyle(
        fontSize: 12,
        color: expiring
            ? SemanticColors.ink(context, Colors.orange.shade800)
            : null);
    final wage = formatMoney(annualFromWeekly(gs.scaledMoney(staff.wage)));
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          key: ValueKey('staff-renew-${staff.id}'),
          style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6)),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  StaffNegotiationScreen(staff: staff, renewal: true))),
          child: Text(Tr.pick('契約', 'Contract'),
              style: const TextStyle(fontSize: 12)),
        ),
        TextButton(
          key: ValueKey('staff-dismiss-${staff.id}'),
          style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6)),
          onPressed: () => _confirmDismiss(context, staff, severance),
          child: Text(Tr.pick('解任', 'Dismiss'),
              style: const TextStyle(fontSize: 12)),
        ),
      ],
    );
    final name = Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: '${staff.name} (${staff.age})',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (lead)
                      TextSpan(
                          text: Tr.pick('  主任', '  Head'),
                          style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.primary)),
                    if (staff.shownSpecialty != StaffSpecialty.balanced)
                      TextSpan(
                          text: '  ${staff.shownSpecialty.label}',
                          style: TextStyle(fontSize: 11, color: subtle)),
                    if (staff.formerPlayerId != null)
                      TextSpan(
                          text: Tr.pick('  うちのOB', '  One of ours'),
                          style: TextStyle(fontSize: 11, color: subtle)),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5),
                );
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 2, 4, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (wide)
            Row(
              children: [
                Expanded(flex: 5, child: name),
                _cell(ability.toStringAsFixed(0), _StaffCols.ability,
                    abilityStyle),
                _cell(wage, _StaffCols.wage, const TextStyle(fontSize: 12)),
                _cell(contractText, _StaffCols.contract, contractStyle),
                SizedBox(width: _StaffCols.actions, child: actions),
              ],
            )
          else ...[
            name,
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                          Tr.pick('能力 ${ability.toStringAsFixed(0)}',
                              'Ability ${ability.toStringAsFixed(0)}'),
                          style: abilityStyle),
                      Text(wage, style: const TextStyle(fontSize: 12)),
                      Text(contractText, style: contractStyle),
                    ],
                  ),
                ),
                actions,
              ],
            ),
          ],
          if (staff.manager != null) _ManagerProfileLines(staff: staff),
        ],
      ),
    );
  }

  Future<void> _confirmDismiss(
      BuildContext context, StaffMember staff, int severance) async {
    final gs = context.read<GameState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Tr.pick('${staff.name}を解任しますか？', 'Dismiss ${staff.name}?')),
        content: Text(severance > 0
            ? Tr.pick('違約金${formatMoney(severance)}を払います(残りの契約の分)。',
                'You pay ${formatMoney(severance)} in severance for the rest of his contract.')
            : Tr.pick('契約が残っていないので、違約金は掛かりません。',
                'No severance: his contract has run its course.')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(Tr.pick('やめる', 'Cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(Tr.pick('解任する', 'Dismiss him'))),
        ],
      ),
    );
    if (ok == true) await gs.dismissStaffMember(staff.id);
  }
}

/// [role] の候補の一覧(下から出る表)。押すと交渉の画面へ。
Future<void> _showCandidates(BuildContext context, StaffRole role) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => ChangeNotifierProvider<GameState>.value(
      value: context.read<GameState>(),
      child: _CandidateSheet(role: role),
    ),
  );
}

class _CandidateSheet extends StatelessWidget {
  const _CandidateSheet({required this.role});
  final StaffRole role;

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final list = gs.staffCandidatesFor(role);
    final weights = staffRoleWeights(role);
    final scheme = Theme.of(context).colorScheme;
    final replaced = gs.staffReplacedBy(role);
    final head = TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: scheme.onSurfaceVariant);
    const small = TextStyle(fontSize: 12);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(Tr.pick('${role.label}の候補', '${role.label} candidates'),
                  style: Theme.of(context).textTheme.titleMedium),
              Text(
                replaced == null
                    ? Tr.pick(
                        'まだ枠があります(${gs.staffMembersFor(role).length}/${gs.maxStaffFor(role)}人)。雇うと加わります。',
                        'There is room (${gs.staffMembersFor(role).length}/${gs.maxStaffFor(role)}). A new hire joins the department.')
                    : Tr.pick('枠がいっぱいです。雇うと${replaced.name}と入れ替わります(違約金${formatMoney(gs.staffSeveranceFor(replaced))})。',
                        'The department is full. A new hire replaces ${replaced.name} (severance ${formatMoney(gs.staffSeveranceFor(replaced))}).'),
                style: TextStyle(
                    fontSize: 12, color: SemanticColors.subtleText(context)),
              ),
              const SizedBox(height: 6),
              Container(
                color: scheme.surfaceContainerHighest,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(Tr.pick('名前', 'Name'), style: head)),
                    for (final a in weights.keys) _cell(a.label, 64, head),
                    _cell(Tr.pick('能力', 'Ability'), 52, head),
                    _cell(Tr.pick('年俸の希望', 'Wants'), 84, head),
                    const SizedBox(width: 76),
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
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                if (c.shownSpecialty != StaffSpecialty.balanced)
                                  TextSpan(
                                      text: '  ${c.shownSpecialty.label}',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: SemanticColors.subtleText(
                                              context))),
                                if (c.formerPlayerId != null)
                                  TextSpan(
                                      text: Tr.pick('  うちのOB', '  One of ours'),
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: SemanticColors.subtleText(
                                              context))),
                              ]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: small,
                            ),
                          ),
                          for (final a in weights.keys)
                            _cell('${c.attribute(a)}', 64,
                                small.copyWith(color: scheme.primary)),
                          _cell(
                              c.roleAbility.toStringAsFixed(0),
                              52,
                              small.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: _abilityColor(context, c.roleAbility))),
                          _cell(
                              formatMoney(
                                  annualFromWeekly(gs.scaledMoney(c.wage))),
                              84,
                              small),
                          SizedBox(
                            width: 76,
                            child: TextButton(
                              key: ValueKey('staff-negotiate-${c.id}'),
                              onPressed: () {
                                Navigator.of(context).pop();
                                Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) =>
                                        StaffNegotiationScreen(staff: c)));
                              },
                              child: Text(Tr.pick('交渉', 'Talk')),
                            ),
                          ),
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
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(Tr.pick('今月の候補はいません。来月に入れ替わります。',
                      'No candidates this month. A new list arrives next month.')),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 人事の委託(FM の「スタッフの責任」)。任せると、空いた役職を毎月埋め、
/// 満了する人の更新も判断する。オーナーは週俸の総額の上限だけ決める。
class _StaffDelegationPanel extends StatelessWidget {
  const _StaffDelegationPanel();

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final infra = gs.save!.infrastructure;
    final delegate = gs.staffDelegate;
    final on = gs.staffDelegated;
    final cap = gs.staffDelegateWeeklyCap;
    final total = infra.totalStaffWeeklyWage;
    final subtle = SemanticColors.subtleText(context);
    String annual(int weekly) =>
        formatMoney(annualFromWeekly(gs.scaledMoney(weekly)));
    // 上限は今の総額の1割きざみで動かす(0 は「給与予算の中で」)。
    final step = math.max(1, (total / 10).round());
    return FmPanel(
      key: const ValueKey('staff-delegation'),
      title: Tr.pick('スタッフの人事', 'Staff responsibilities'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 札(FmPanel)の地の上なので、ListTile の地と波紋が隠れないよう
          // 透明な Material を挟む。
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
            key: const ValueKey('staff-delegate-switch'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: on,
            onChanged: delegate == null
                ? null
                : (v) => gs.setStaffDelegation(on: v),
            title: Text(delegate == null
                ? Tr.pick('人事を任せる', 'Delegate staff hiring')
                : Tr.pick('人事を${delegate.name}(${delegate.role.label})に任せる',
                    'Leave staff hiring to ${delegate.name} (${delegate.role.label})')),
            subtitle: Text(
              delegate == null
                  ? Tr.pick('スポーツディレクターか監督を雇うと任せられます。',
                      'Hire a director of football or a manager to delegate.')
                  : Tr.pick('任せると、空いた役職を毎月埋め、満了する人の更新も判断します(監督・SD はオーナーが決めます)。',
                      'He fills vacant posts each month and decides on renewals (you still choose the manager and director).'),
              style: TextStyle(fontSize: 11, color: subtle),
            ),
          ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  Tr.pick('年俸の総額の上限', 'Salary ceiling'),
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
              // 押せる広さ 48x48 を保つため、交渉の表の小さな増減は使わない。
              IconButton(
                key: const ValueKey('staff-delegate-cap-down'),
                tooltip: Tr.pick('下げる', 'Lower'),
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                onPressed: cap <= 0
                    ? null
                    : () => gs.setStaffDelegation(
                        weeklyCap: cap - step < total ~/ 2 ? 0 : cap - step),
              ),
              Flexible(
                child: Text(
                  cap <= 0
                      ? Tr.pick('給与予算の中で', 'Within the wage budget')
                      : annual(cap),
                  key: const ValueKey('staff-delegate-cap'),
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                key: const ValueKey('staff-delegate-cap-up'),
                tooltip: Tr.pick('上げる', 'Raise'),
                icon: const Icon(Icons.add_circle_outline, size: 20),
                onPressed: () => gs.setStaffDelegation(
                    weeklyCap: cap <= 0 ? total + step : cap + step),
              ),
            ],
          ),
          Text(
            Tr.pick('いまの年俸の総額 ${annual(total)}(${infra.allStaff.length}人)',
                'Current salaries ${annual(total)} (${infra.allStaff.length} staff)'),
            style: TextStyle(fontSize: 11, color: subtle),
          ),
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
      padding: const EdgeInsets.only(top: 2),
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
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                    Tr.pick(
                        '今季の目標: $target位(戦力どおりなら${gameState.suggestedManagerTarget}位)',
                        'Target this season: position $target (squad strength says ${gameState.suggestedManagerTarget})'),
                    style: const TextStyle(fontSize: 12.5)),
              ),
              IconButton(
                tooltip: Tr.pick('目標を上げる', 'Raise the target'),
                onPressed: target > 1
                    ? () => gameState.setManagerTarget(target - 1)
                    : null,
                icon: const Icon(Icons.arrow_upward, size: 18),
              ),
              IconButton(
                tooltip: Tr.pick('目標を下げる', 'Lower the target'),
                onPressed: target < teams
                    ? () => gameState.setManagerTarget(target + 1)
                    : null,
                icon: const Icon(Icons.arrow_downward, size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                  Tr.pick('監督の立場 $standing/100',
                      'Standing $standing/100'),
                  style: const TextStyle(fontSize: 12.5)),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: LinearProgressIndicator(
                    value: standing / 100, color: color),
              ),
            ],
          ),
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
      margin: const EdgeInsets.only(top: 4),
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
