import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../models/player.dart';
import 'player_stat_chips.dart';

/// 補強の候補を、情報の密な表で見せる(FM の移籍検索に寄せる)。
///
/// 市場は「所属・年齢・位置・総合・潜在・移籍金」、フリー選手は「年齢・位置・総合・週俸」。
/// 右端の「獲得」で契約へ進む。資金が足りない選手は移籍金が赤くなる。
class TransferTable extends StatelessWidget {
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

  static const double _rowHeight = 38;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final head = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.bold,
      color: scheme.onSurfaceVariant,
    );
    Widget h(String s, double w, [TextAlign a = TextAlign.center]) =>
        SizedBox(width: w, child: Text(s, style: head, textAlign: a));
    return Column(
      children: [
        Container(
          color: scheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Expanded(child: h(Tr.pick('名前', 'Name'), double.infinity, TextAlign.left)),
              if (market) h(Tr.pick('所属', 'Club'), 84),
              h(Tr.pick('年', 'Age'), 26),
              h(Tr.pick('位置', 'Pos'), 40),
              h(Tr.pick('総合', 'OVR'), 34),
              if (market) h(Tr.pick('潜在', 'POT'), 30),
              h(market ? Tr.pick('移籍金', 'Fee') : Tr.pick('週俸', 'Wage'), 46),
              const SizedBox(width: 56),
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
    const small = TextStyle(fontSize: 12);
    final affordable = !market || budget >= p.marketValue;
    Widget cell(String s, double w, {TextStyle? style}) => SizedBox(
          width: w,
          child: Text(s,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: style ?? small),
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
          if (market) cell(p.originClubName ?? '-', 84),
          cell('${p.age}', 26),
          cell(p.position.label, 40),
          SizedBox(width: 34, child: Center(child: OverallBadge(overall: p.overall))),
          if (market) cell('${p.potential}', 30),
          cell(
            market ? '${p.marketValue}' : '${p.wage}',
            46,
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
                minimumSize: const Size(52, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: canSign ? () => onSign(p) : null,
              child: Text(Tr.pick('獲得', 'Sign'),
                  style: const TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}
