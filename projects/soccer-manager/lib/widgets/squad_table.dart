import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../models/player.dart';
import 'player_stat_chips.dart';

/// 選手の一覧を、情報の密な表で見せる(Football Manager の選手画面に寄せる)。
///
/// 1行1人。背番号・名前・ポジション・年齢・総合・疲労・契約・週俸を並べる。
/// 負傷・出場停止・契約切れ間近は色で目立たせる。行を押すと詳細へ。
class SquadTable extends StatelessWidget {
  const SquadTable({
    super.key,
    required this.players,
    required this.startingIds,
    required this.onTap,
  });

  final List<Player> players;
  final Set<String> startingIds;
  final void Function(Player) onTap;

  static const double _rowHeight = 34;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final headStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.bold,
      color: scheme.onSurfaceVariant,
    );
    Widget head(String s, {double? width, TextAlign align = TextAlign.center}) =>
        SizedBox(
          width: width,
          child: Text(s, style: headStyle, textAlign: align),
        );
    return Column(
      children: [
        Container(
          color: scheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              head('#', width: 22),
              Expanded(child: head(Tr.pick('名前', 'Name'), align: TextAlign.left)),
              head(Tr.pick('位置', 'Pos'), width: 40),
              head(Tr.pick('年', 'Age'), width: 26),
              head(Tr.pick('総合', 'OVR'), width: 34),
              head(Tr.pick('疲', 'Fat'), width: 28),
              head(Tr.pick('契約', 'Term'), width: 34),
              head(Tr.pick('週俸', 'Wage'), width: 36),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: players.length,
            itemExtent: _rowHeight,
            itemBuilder: (context, i) => _row(context, players[i], i),
          ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, Player p, int index) {
    final scheme = Theme.of(context).colorScheme;
    final unavailable =
        p.isInjured || p.isSuspended || p.isOnInternationalDuty || p.isLoanedOut;
    final expiring = !p.isLoan && p.contractYearsRemaining <= 1;
    final starting = startingIds.contains(p.id);
    const small = TextStyle(fontSize: 12);
    final base = unavailable ? scheme.error : null;
    return InkWell(
      onTap: () => onTap(p),
      child: Container(
        color: starting
            ? scheme.primaryContainer.withValues(alpha: 0.35)
            : (index.isOdd
                ? scheme.surfaceContainerLow
                : Colors.transparent),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text(p.squadNumber == null ? '' : '${p.squadNumber}',
                  textAlign: TextAlign.center,
                  style: small.copyWith(color: scheme.onSurfaceVariant)),
            ),
            Expanded(
              child: Text(
                p.name,
                overflow: TextOverflow.ellipsis,
                style: small.copyWith(
                    fontWeight: FontWeight.w700, color: base),
              ),
            ),
            SizedBox(
              width: 40,
              child: Text(p.position.label,
                  textAlign: TextAlign.center, style: small.copyWith(color: base)),
            ),
            SizedBox(
              width: 26,
              child: Text('${p.age}',
                  textAlign: TextAlign.center, style: small.copyWith(color: base)),
            ),
            SizedBox(width: 34, child: Center(child: OverallBadge(overall: p.overall))),
            SizedBox(
              width: 28,
              child: Text('${p.fatigue}',
                  textAlign: TextAlign.center,
                  style: small.copyWith(
                      color: p.fatigue >= 70 ? scheme.error : base)),
            ),
            SizedBox(
              width: 34,
              child: Text(
                  p.isLoan
                      ? Tr.pick('借', 'Ln')
                      : Tr.pick('${p.contractYearsRemaining}年',
                          '${p.contractYearsRemaining}y'),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: small.copyWith(
                      color: expiring ? Colors.orange : base)),
            ),
            SizedBox(
              width: 36,
              child: Text('${p.wage}',
                  textAlign: TextAlign.right, style: small.copyWith(color: base)),
            ),
          ],
        ),
      ),
    );
  }
}
