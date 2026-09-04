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
                  child: Text(Tr.pick('解任', 'Dismiss')),
                ),
              ),
              Text(
                _staffEffectLabel(role, current.effectiveLevel),
                style: TextStyle(
                    fontSize: 11, color: SemanticColors.subtleText(context)),
              ),
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
                          content: Text(Tr.pick('給与予算が足りません。',
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
                Text('${staff.name} (${staff.age})'),
                Text(
                  [
                    for (final a in weights.keys)
                      '${a.label} ${staff.attribute(a)}',
                    Tr.pick('週俸${staff.wage}万円', 'Wage ${staff.wage}'),
                    Tr.pick(
                        '契約${staff.contractYears}年', '${staff.contractYears}yr'),
                  ].join(' / '),
                  style: TextStyle(
                      fontSize: 11,
                      color: SemanticColors.subtleText(context)),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
