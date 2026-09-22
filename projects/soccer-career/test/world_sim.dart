// ignore_for_file: avoid_print
/// **自分の出来が、世界に映るか。**
///
/// 順位表は他クラブ同士の試合を `club.strength` だけで振り、自分の得点は
/// 自分の試合のスコアにしか乗らない。クラブの強さは昇格・降格でしか動かない。
/// だとすると、20年同じクラブに居続けても**クラブは自分の活躍で強くならない**
/// はずで、「引っ張り上げた実感」がどこで止まるかを数字で見る。
///
/// 見るもの:
/// 1. 自分の出来（クラブとの力の差）と、クラブの順位のずれ
///    （強さの序列より上に終わったか）。
/// 2. 居続けたとき、クラブの強さ・部・順位がどう動くか。
/// 3. 無出場シーズンの理由の内訳。
///
/// 手動実行（`_test.dart` で終わらないので CI では走らない）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/eligibility.dart';
import 'package:soccer_career/game/world.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/competition.dart';
import 'package:soccer_career/models/season.dart';

import 'support/career_sim.dart';

class _Bucket {
  int n = 0;
  double overSum = 0; // 強さの序列 − 順位（正なら序列より上に終わった）
  double posSum = 0;
  double ratingSum = 0;
  int titles = 0;
  int promoted = 0;
  int relegated = 0;
}

void main() {
  test('world', () async {
    const n = 96;

    for (final (label, style) in [
      (
        '移籍する（バランス）',
        Playstyle(
          name: 'move',
          position: Position.cm,
          startAge: 18,
          sim: SimStyle.balanced,
          agent: Agent.pool.first,
        ),
      ),
      (
        '居続ける',
        Playstyle(
          name: 'stay',
          position: Position.cm,
          startAge: 18,
          sim: SimStyle.balanced,
          agent: Agent.pool.first,
          staysPut: true,
        ),
      ),
    ]) {
      // 力の差（総合力 − クラブの強さ）で束ねる。
      final buckets = <String, _Bucket>{};
      String bucketOf(int gap) => gap < 0
          ? '差 <0'
          : gap < 6
          ? '差 0〜5'
          : gap < 12
          ? '差 6〜11'
          : gap < 18
          ? '差 12〜17'
          : '差 18+';

      // 居続けたときの、年ごとのクラブの強さ・部・順位。
      final byYear =
          <int, List<int>>{}; // year → [strength, tier, position, overall]
      final zeroReasons = <String, int>{};
      var zeroSeasons = 0;
      var seasonsTotal = 0;
      var lastClubName = '';

      for (var seed = 0; seed < n; seed++) {
        var year = 0;
        lastClubName = '';
        await runCareer(
          style,
          seed,
          onSeason: (state, stats, controller) {
            year++;
            seasonsTotal++;
            final gap = state.player.overall - state.club.strength;
            final b = buckets.putIfAbsent(bucketOf(gap), _Bucket.new);
            final ranked = [...state.league]
              ..sort((a, c) => c.strength.compareTo(a.strength));
            final strengthRank =
                ranked.indexWhere((c) => c.id == state.club.id) + 1;
            final position = state.leaguePosition;
            b.n++;
            b.overSum += strengthRank - position;
            b.posSum += position;
            b.ratingSum += stats.appearances == 0 ? 0 : stats.averageRating;
            if (position == 1 && state.club.tier == 1) b.titles++;
            final size = World.byId(state.club.countryId)
                .clubsInTier(state.club.tier);
            if (state.club.tier > 1 && position <= 2) b.promoted++;
            if (position > size - 3) b.relegated++;

            byYear.putIfAbsent(year, () => [0, 0, 0, 0, 0]);
            final row = byYear[year]!;
            row[0] += state.club.strength;
            row[1] += state.club.tier;
            row[2] += position;
            row[3] += state.player.overall;
            row[4] += 1;

            if (stats.appearances == 0) {
              zeroSeasons++;
              final country = World.byId(state.club.countryId);
              final foreign = Eligibility.isForeignIn(
                state.player.nationality,
                country,
              );
              final reason = state.squadStatus == SquadStatus.outOfSquad
                  ? (foreign &&
                            country.foreignRule.squadLimit != null &&
                            Eligibility.usedSlots(state.club, country) >=
                                country.foreignRule.squadLimit!
                        ? '登録外（外国人枠）'
                        : '登録外（力量差 ${state.player.overall - state.club.strength}）')
                  : state.frozenOut
                  ? '構想外'
                  : state.injured
                  ? '離脱'
                  : 'その他（ベンチ外が続いた）';
              final moved = state.club.name != lastClubName;
              final key = '$reason ${moved ? '・移籍した年' : '・同じクラブ'}';
              zeroReasons[key] = (zeroReasons[key] ?? 0) + 1;
            }
            lastClubName = state.club.name;
          },
        );
      }

      print('');
      print('=== $label（$n キャリア・CM・18歳開始・$seasonsTotal シーズン） ===');
      print('');
      print('--- 力の差（総合力 − クラブの強さ）と、順位のずれ ---');
      print('  「ずれ」= 強さの序列 − 実際の順位。正なら序列より上に終わった。');
      print('  束          季数   ずれ    平均順位  評価    優勝  昇格  降格');
      for (final key in ['差 <0', '差 0〜5', '差 6〜11', '差 12〜17', '差 18+']) {
        final b = buckets[key];
        if (b == null || b.n == 0) continue;
        print(
          '  ${key.padRight(10)} ${b.n.toString().padLeft(5)}  '
          '${(b.overSum / b.n).toStringAsFixed(2).padLeft(5)}  '
          '${(b.posSum / b.n).toStringAsFixed(1).padLeft(7)}   '
          '${(b.ratingSum / b.n).toStringAsFixed(2)}  '
          '${(b.titles / b.n * 100).toStringAsFixed(0).padLeft(3)}%  '
          '${(b.promoted / b.n * 100).toStringAsFixed(0).padLeft(3)}%  '
          '${(b.relegated / b.n * 100).toStringAsFixed(0).padLeft(3)}%',
        );
      }

      print('');
      print('--- 年ごと（クラブの強さ / 部 / 順位 / 総合力） ---');
      for (final y in byYear.keys.toList()..sort()) {
        final r = byYear[y]!;
        if (r[4] < n ~/ 4) continue;
        print(
          '  ${y.toString().padLeft(2)}年目  強さ ${(r[0] / r[4]).toStringAsFixed(1)}  '
          '部 ${(r[1] / r[4]).toStringAsFixed(2)}  '
          '順位 ${(r[2] / r[4]).toStringAsFixed(1)}  '
          '総合力 ${(r[3] / r[4]).toStringAsFixed(1)}',
        );
      }

      print('');
      print(
        '--- 無出場シーズン $zeroSeasons（${(zeroSeasons / n).toStringAsFixed(2)}/キャリア） ---',
      );
      final keys = zeroReasons.keys.toList()
        ..sort((a, b) => zeroReasons[b]!.compareTo(zeroReasons[a]!));
      for (final k in keys) {
        print('  ${zeroReasons[k].toString().padLeft(3)}  $k');
      }
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}
