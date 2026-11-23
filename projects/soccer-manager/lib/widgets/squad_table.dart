import 'package:flutter/material.dart';
import '../theme/semantic_colors.dart';

import '../l10n/tr.dart';
import '../logic/contract_engine.dart';
import '../models/player.dart';
import 'player_stat_chips.dart';
import 'table_sort.dart';
import '../logic/economy_scale.dart';

/// 選手の一覧を、情報の密な表で見せる(Football Manager の選手画面に寄せる)。
///
/// 1行1人。背番号・名前・ポジション・年齢・総合・疲労・契約・週俸を並べる。
/// 負傷・出場停止・契約切れ間近は色で目立たせる。行を押すと詳細へ。
class SquadTable extends StatefulWidget {
  const SquadTable({
    super.key,
    required this.players,
    required this.startingIds,
    required this.onTap,
  });

  final List<Player> players;
  final Set<String> startingIds;
  final void Function(Player) onTap;

  @override
  State<SquadTable> createState() => _SquadTableState();
}

/// 見出しを押すと並べ替える(TableSort)。
class _SquadTableState extends State<SquadTable> {
  String? _sortKey;
  bool _asc = true;

  void _sortBy(String k) => setState(() {
        if (_sortKey == k) {
          _asc = !_asc;
        } else {
          _sortKey = k;
          _asc = TableSort.startsAscending(k);
        }
      });

  List<Player> get players => TableSort.sort(widget.players, _sortKey, _asc);
  Set<String> get startingIds => widget.startingIds;
  void Function(Player) get onTap => widget.onTap;

  static const double _rowHeight = 34;

  /// 疲労の列の幅。英語は見出しを「Fatigue」と略さずに出すので広げる。
  static double get _fatigueWidth => Tr.isEnglish ? 56 : 28;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final headStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.bold,
      color: scheme.onSurfaceVariant,
    );
    Widget head(String s,
            {double? width, TextAlign align = TextAlign.center, String? key}) =>
        TableSort.header(
          key: key,
          onSort: _sortBy,
          child: SizedBox(
            width: width,
            child: Text(TableSort.label(s, key, _sortKey, _asc),
                style: headStyle, textAlign: align),
          ),
        );
    return Column(
      children: [
        Container(
          color: scheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              head('#', width: 22),
              Expanded(
                  child: head(Tr.pick('名前', 'Name'),
                      align: TextAlign.left, key: 'name')),
              head(Tr.pick('位置', 'Pos'), width: 40, key: 'pos'),
              head(Tr.pick('年', 'Age'), width: 26, key: 'age'),
              head(Tr.pick('総合', 'OVR'), width: 34, key: 'ovr'),
              head(Tr.pick('疲', 'Fatigue'), width: _fatigueWidth, key: 'fat'),
              // 列の中身は満了の年(2030 なら 2030年6月まで)。「契約」だと
              // 年数に読めるので「満了」にする(2026-11-23)。
              head(Tr.pick('満了', 'Ends'), width: 34, key: 'term'),
              head(Tr.pick('年俸', 'Salary'), width: 52, key: 'wage'),
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
    final unavailable = p.isInjured ||
        p.isSuspended ||
        p.isOnInternationalDuty ||
        p.isLoanedOut ||
        p.notRegistered;
    final expiring = !p.isLoan && p.contractYearsRemaining <= 1;
    final starting = startingIds.contains(p.id);
    const small = TextStyle(fontSize: 12);
    final base = unavailable ? scheme.error : null;
    return InkWell(
      onTap: () => onTap(p),
      child: Container(
        color: starting
            ? scheme.primaryContainer.withValues(alpha: 0.35)
            : (index.isOdd ? scheme.surfaceContainerLow : Colors.transparent),
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
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      p.name,
                      overflow: TextOverflow.ellipsis,
                      style: small.copyWith(
                          fontWeight: FontWeight.w700, color: base),
                    ),
                  ),
                  // 移籍リストの印。縦画面の一覧(squad_screen)と同じ。
                  if (p.isTransferListed) ...[
                    const SizedBox(width: 4),
                    Tooltip(
                      message: Tr.pick('移籍リストに登録済み', 'On the transfer list'),
                      child: Icon(
                        Icons.sell_outlined,
                        key: ValueKey('squad-table-listed'),
                        size: 14,
                        color: SemanticColors.ink(context, Colors.orange),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(
              width: 40,
              child: Text(p.position.label,
                  textAlign: TextAlign.center,
                  style: small.copyWith(color: base)),
            ),
            SizedBox(
              width: 26,
              child: Text('${p.age}',
                  textAlign: TextAlign.center,
                  style: small.copyWith(color: base)),
            ),
            SizedBox(
                width: 34,
                child: Center(child: OverallBadge(overall: p.overall))),
            SizedBox(
              width: _fatigueWidth,
              child: Text('${p.fatigue}',
                  textAlign: TextAlign.center,
                  style: small.copyWith(
                      color: p.fatigue >= 70 ? scheme.error : base)),
            ),
            SizedBox(
              width: 34,
              // 4桁の年が切れないよう、入りきらなければ縮める。
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                    p.isLoan
                        ? Tr.pick('借', 'Loan')
                        : ContractEngine.untilTinyLabel(p.contractEndYear),
                    key: ValueKey('squad-table-term-${p.id}'),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: small.copyWith(
                        color: expiring
                            ? SemanticColors.ink(context, Colors.orange)
                            : base)),
              ),
            ),
            SizedBox(
              width: 52,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(formatMoney(annualFromWeekly(p.wage)),
                    textAlign: TextAlign.right,
                    style: small.copyWith(color: base)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
