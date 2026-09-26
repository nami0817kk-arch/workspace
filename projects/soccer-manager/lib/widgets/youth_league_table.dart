import 'package:flutter/material.dart';

import '../models/youth_league.dart';
import '../l10n/tr.dart';
import '../theme/semantic_colors.dart';

/// ユースリーグの順位表。
///
/// 練習試合の勝敗が何にも残らなかったため、年間の積み上がりを出す。
/// 自クラブの行だけ太字にして、長い表の中でも自分を見失わないようにする。
class YouthLeagueTable extends StatelessWidget {
  final YouthLeague league;

  const YouthLeagueTable({super.key, required this.league});

  @override
  Widget build(BuildContext context) {
    final sorted = league.sorted;
    final next = league.nextOpponent;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                league.isComplete
                    ? Tr.pick('ユースリーグ 最終順位 (${league.userRank}位)',
                        'Youth league, final table (${league.userRank})')
                    : Tr.pick(
                        'ユースリーグ 第${league.matchday + 1}節 / 全${YouthLeague.matchdayCount}節',
                        'Youth league, round ${league.matchday + 1} of ${YouthLeague.matchdayCount}'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (next != null)
                Text(
                  Tr.pick('今節の相手: ${next.name}(強さ ${next.strength})',
                      'Next up: ${next.name} (strength ${next.strength})'),
                  style: TextStyle(
                      fontSize: 12, color: SemanticColors.subtleText(context)),
                ),
              const SizedBox(height: 8),
              for (var i = 0; i < sorted.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        child: Text('${i + 1}',
                            style: const TextStyle(fontSize: 12)),
                      ),
                      Expanded(
                        child: Text(
                          sorted[i].name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: sorted[i].isUser
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      Text(
                        Tr.pick(
                            '${sorted[i].played}試 ${sorted[i].points}点 ${sorted[i].goalDiff >= 0 ? '+' : ''}${sorted[i].goalDiff}',
                            '${sorted[i].played}P ${sorted[i].points}pts ${sorted[i].goalDiff >= 0 ? '+' : ''}${sorted[i].goalDiff}'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: sorted[i].isUser
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
