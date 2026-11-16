import 'package:flutter/material.dart';

import '../../gm/career.dart';
import '../../gm/league.dart';
import '../../gm/player.dart';
import 'common.dart';
import 'gm_table.dart';
import 'player_card.dart';
import 'style.dart';

/// ドラフトの全体(2026-11-16、ユーザー「他チーム含めてドラフト見れない」)。
/// 左に今年のドラフト(ドラフト中は全指名の順と取られた選手、それ以外は今の順位での指名の順と指名権の持ち主)、
/// 右に過去のドラフト(年ごとに、指名した選手の今の力とチーム)。
class DraftBoardView extends StatefulWidget {
  const DraftBoardView({super.key, required this.car});
  final Career car;

  @override
  State<DraftBoardView> createState() => _DraftBoardViewState();
}

class _DraftBoardViewState extends State<DraftBoardView> {
  int? _year;

  Career get car => widget.car;

  @override
  Widget build(BuildContext context) {
    final years = car.draftYears();
    final year = _year ?? (years.isEmpty ? null : years.first);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 6, child: ListView(children: [_thisYear(context)])),
        const SizedBox(width: 8),
        Expanded(
          flex: 5,
          child: ListView(
            children: [
              if (years.isEmpty)
                const GmTable(
                  title: '過去のドラフト',
                  cols: [GmCol('', flex: 1)],
                  rows: [
                    GmRow([Text('まだ記録がない(1回目のドラフトのあとから並ぶ)', style: TextStyle(fontSize: 12, color: GmColors.sub))]),
                  ],
                )
              else
                _past(context, year!, years),
            ],
          ),
        ),
      ],
    );
  }

  /// 今年のドラフト。
  Widget _thisYear(BuildContext context) {
    final live = car.phase == Phase.draft && car.order.isNotEmpty;
    if (live) {
      final byNo = {
        for (final p in car.prospects)
          if (p.pickNo != null) p.pickNo!: p,
      };
      return GmTable(
        title: '今年のドラフト(${car.draftAt}/${car.order.length}人)',
        rowHeight: 24,
        cols: const [
          GmCol('番', width: 28),
          GmCol('', width: 22),
          GmCol('チーム', width: 92, align: TextAlign.left),
          GmCol('指名', flex: 1, align: TextAlign.left),
          GmCol('位', width: 26),
        ],
        rows: [
          for (var k = 0; k < car.order.length; k++)
            () {
              final pick = car.picks[car.order[k]];
              final p = byNo[k + 1];
              final now = k == car.draftAt;
              return GmRow([
                numCell('${k + 1}', color: k < teamDefs.length ? GmColors.gold : GmColors.sub, bold: now),
                TeamBadge(team: pick.owner, size: 16),
                Text(
                  pick.owner == pick.from ? car.teams[pick.owner].def.short : '${car.teams[pick.owner].def.short}(元${car.teams[pick.from].def.short})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
                p == null
                    ? Text(now ? 'いま指名中' : 'これから', style: TextStyle(fontSize: 11, color: now ? GmColors.ball : GmColors.sub))
                    : Text(
                        p.player.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                Text(p?.player.pos.short ?? '', style: const TextStyle(fontSize: 10, color: GmColors.sub)),
              ], highlight: pick.owner == car.mine);
            }(),
        ],
      );
    }
    // ドラフトの前: 今の勝率の低い順(くじの前)。指名権の持ち主と、元のチーム
    final slots = car.projectedDraftOrder();
    final inSeason = car.phase == Phase.season || car.phase == Phase.playoffs;
    return GmTable(
      title: inSeason ? '次のドラフトの指名の順(今の勝率なら・くじの前)' : '次のドラフトの指名の順(戦力の低い順・くじの前)',
      rowHeight: 24,
      cols: [
        const GmCol('番', width: 28),
        const GmCol('', width: 22),
        const GmCol('持ち主', flex: 1, align: TextAlign.left),
        const GmCol('元のチーム', width: 110, align: TextAlign.left),
        GmCol(inSeason ? '勝敗' : '戦力', width: 70),
      ],
      rows: [
        for (final (k, (from, owner, protect)) in slots.indexed)
          GmRow([
            numCell('${k + 1}', color: k < 4 ? GmColors.gold : GmColors.sub),
            TeamBadge(team: owner, size: 16),
            Text(car.teams[owner].def.short, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              owner == from ? '' : '${car.teams[from].def.short}${protect > 0 ? '(上位$protect保護)' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: GmColors.sub),
            ),
            numCell(inSeason ? record(car.teams[from]) : '${car.strengthRank(from) + 1}位', color: GmColors.sub),
          ], highlight: owner == car.mine),
      ],
    );
  }

  /// 過去のドラフト(年を選ぶ)。指名した選手の今の力とチーム。
  Widget _past(BuildContext context, int year, List<int> years) {
    final picks = car.draftHistory.where((x) => x.season == year).toList()..sort((a, b) => a.no.compareTo(b.no));
    final where = <int, (Player, int)>{
      for (final t in car.teams)
        for (final p in t.roster) p.id: (p, t.index),
    };
    return GmTable(
      title: '過去のドラフト',
      trailing: Wrap(
        spacing: 3,
        children: [
          for (final y in years.take(6))
            ChoiceChip(
              visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              showCheckmark: false,
              label: Text('$y年目', style: const TextStyle(fontSize: 10)),
              selected: y == year,
              onSelected: (_) => setState(() => _year = y),
            ),
        ],
      ),
      rowHeight: 24,
      cols: const [
        GmCol('番', width: 28),
        GmCol('', width: 22),
        GmCol('選手', flex: 1, align: TextAlign.left),
        GmCol('位', width: 26),
        GmCol('当時', width: 34),
        GmCol('今', width: 30),
        GmCol('今のチーム', width: 70, align: TextAlign.left),
      ],
      rows: [
        for (final x in picks)
          () {
            final now = where[x.id];
            return GmRow(
              [
                numCell('${x.no}', color: x.no <= teamDefs.length ? GmColors.gold : GmColors.sub),
                TeamBadge(team: x.team, size: 16),
                Text(
                  x.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(Pos.values[x.pos.clamp(0, Pos.values.length - 1)].short, style: const TextStyle(fontSize: 10, color: GmColors.sub)),
                numCell('${shown(x.ovr)}', color: GmColors.sub),
                now == null ? numCell('-', color: GmColors.sub) : numCell('${shown(now.$1.ovr)}', color: GmColors.ovr(now.$1.ovr), bold: true),
                Text(
                  now == null ? '引退・自由契約' : car.teams[now.$2].def.short,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: GmColors.sub),
                ),
              ],
              highlight: x.team == car.mine,
              onTap: now == null ? null : () => showPlayerCard(context, car, now.$1, now.$2),
            );
          }(),
      ],
    );
  }
}
