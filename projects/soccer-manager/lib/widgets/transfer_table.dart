import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../models/player.dart';
import 'player_stat_chips.dart';
import 'table_sort.dart';
import '../logic/economy_scale.dart';

/// 補強の候補を、情報の密な表で見せる(FM の移籍検索に寄せる)。
///
/// 市場は「所属・年齢・位置・総合・潜在・移籍金」、フリー選手は「年齢・位置・総合・週俸」。
/// 右端の「獲得」で契約へ進む。資金が足りない選手は移籍金が赤くなる。
class TransferTable extends StatefulWidget {
  const TransferTable({
    super.key,
    required this.players,
    required this.market,
    required this.budget,
    required this.canSign,
    required this.onSign,
  });

  final List<Player> players;

  /// true なら市場(所属・潜在・移籍金)、false ならフリー選手(週俸)。
  final bool market;
  final int budget;

  /// 獲得できる状態か(枠・移籍期間)。
  final bool canSign;
  final void Function(Player) onSign;

  @override
  State<TransferTable> createState() => _TransferTableState();
}

/// 見出しを押すと並べ替える(TableSort)。
class _TransferTableState extends State<TransferTable> {
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
  bool get market => widget.market;
  int get budget => widget.budget;
  bool get canSign => widget.canSign;
  void Function(Player) get onSign => widget.onSign;

  // 行はタップの的でもある。移籍の判断なので、押し間違えない高さにする。
  static const double _rowHeight = 48;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) => _table(
          context,
          // 狭い画面では所属・潜在を省く。名前と値段が読めることを優先する。
          showClub: market && c.maxWidth >= 520,
          showPot: market && c.maxWidth >= 400,
        ),
      );

  Widget _table(BuildContext context,
      {required bool showClub, required bool showPot}) {
    final scheme = Theme.of(context).colorScheme;
    final head = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.bold,
      color: scheme.onSurfaceVariant,
    );
    Widget h(String s, double w,
            [TextAlign a = TextAlign.center, String? key]) =>
        TableSort.header(
          key: key,
          onSort: _sortBy,
          child: SizedBox(
            width: w,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment:
                  a == TextAlign.left ? Alignment.centerLeft : Alignment.center,
              child: Text(TableSort.label(s, key, _sortKey, _asc),
                  style: head, textAlign: a),
            ),
          ),
        );
    return Column(
      children: [
        Container(
          color: scheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(
                  child: h(Tr.pick('名前', 'Name'), double.infinity,
                      TextAlign.left, 'name')),
              if (showClub) h(Tr.pick('所属', 'Club'), 84),
              h(Tr.pick('年', 'Age'), 26, TextAlign.center, 'age'),
              h(Tr.pick('位置', 'Pos'), 40, TextAlign.center, 'pos'),
              h(Tr.pick('総合', 'OVR'), 34, TextAlign.center, 'ovr'),
              if (showPot) h(Tr.pick('潜在', 'POT'), 30, TextAlign.center, 'pot'),
              h(market ? Tr.pick('移籍金', 'Fee') : Tr.pick('年俸', 'Salary'), 52,
                  TextAlign.center, market ? 'fee' : 'wage'),
              const SizedBox(width: 56),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: players.length,
            itemExtent: _rowHeight,
            itemBuilder: (context, i) => _row(context, players[i], i,
                showClub: showClub, showPot: showPot),
          ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, Player p, int index,
      {required bool showClub, required bool showPot}) {
    final scheme = Theme.of(context).colorScheme;
    const small = TextStyle(fontSize: 12);
    final affordable = !market || budget >= p.marketValue;
    Widget cell(String s, double w, {TextStyle? style}) => SizedBox(
          width: w,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(s, textAlign: TextAlign.center, style: style ?? small),
          ),
        );
    return Container(
      color: index.isOdd ? scheme.surfaceContainerLow : null,
      padding: const EdgeInsets.only(left: 8, right: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              p.name,
              overflow: TextOverflow.ellipsis,
              style: small.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (showClub) cell(p.originClubName ?? '-', 84),
          cell('${p.age}', 26),
          cell(p.position.label, 40),
          SizedBox(
              width: 34,
              child: Center(child: OverallBadge(overall: p.overall))),
          if (showPot) cell('${p.potential}', 30),
          cell(
            market
                ? formatMoney(p.marketValue)
                : formatMoney(annualFromWeekly(p.wage)),
            52,
            style: small.copyWith(
              color: affordable ? null : scheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(
            width: 52,
            child: TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(52, 48),
              ),
              onPressed: canSign ? () => onSign(p) : null,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(Tr.pick('獲得', 'Sign'),
                    style: const TextStyle(fontSize: 12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
