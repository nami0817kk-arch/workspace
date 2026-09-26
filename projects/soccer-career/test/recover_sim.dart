// ignore_for_file: avoid_print
/// **落ちたあと、戻ってこられるか。**
///
/// `flutter test test/recover_sim.dart` で明示的に走らせる。
///
/// このゲームは「取り返しのつかないところ」を意図して作ってある
/// （重傷・構想外）。だが**落ちたきり終わる**なら、それは深さではなく
/// ただの終了条件になる。落ちた回数と、そこから何季で戻ったかを測る。
///
/// 見るのは3つの落ち方:
/// - 構想外（監督の信頼が `frozenOutTrust` を割る）
/// - 無出場シーズン（1試合も出ない）
/// - 降格（部が下がる）
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/season.dart';

import 'support/career_sim.dart';

void main() {
  test('落ちてから戻るまで', () async {
    const seeds = 40;

    for (final position in [Position.st, Position.cm, Position.cb]) {
      var careers = 0;
      // 構想外
      var frozenCareers = 0;
      var frozenSpells = 0;
      var frozenSeasons = 0;
      var frozenAtEnd = 0;
      var trustSum = 0;
      var nearMiss = 0;
      // 無出場
      var zeroCareers = 0;
      var zeroSpells = 0;
      var backAfterZero = 0;
      // 降格
      var relegatedCareers = 0;
      var relegations = 0;
      var backUp = 0;

      for (var seed = 0; seed < seeds; seed++) {
        careers++;
        var wasFrozen = false;
        var frozenHere = 0;
        var frozenSeasonsHere = 0;
        var zeroHere = 0;
        var pendingZero = false;
        var relegatedHere = 0;
        var pendingRelegation = false;
        var lastTier = 0;
        var endedFrozen = false;
        var minTrust = 100;

        await runCareer(
          Playstyle(
            name: '立て直し',
            position: position,
            startAge: 18,
            sim: SimStyle.balanced,
            agent: Agent.pool.first,
          ),
          seed,
          onSeason: (state, stats, c) {
            // **構想外は状態なので、季の切れ目だけ見ると取りこぼす。**
            // 季の途中で落ちて季の途中で戻った回は数えられない。
            // 信頼の最小値も一緒に出して、線（12）にどれだけ近づいたかを見る。
            if (state.relations.manager < minTrust) {
              minTrust = state.relations.manager;
            }
            final frozen = state.frozenOut;
            if (frozen) {
              if (!wasFrozen) frozenHere++;
              frozenSeasonsHere++;
            }
            wasFrozen = frozen;
            endedFrozen = frozen;

            // 無出場シーズンのあと、次の季に出られたか。
            final played = stats.appearances > 0;
            if (pendingZero && played) backAfterZero++;
            pendingZero = !played;
            if (!played) zeroHere++;

            // 降格したあと、また上の部に戻れたか。
            final tier = state.club.tier;
            if (lastTier != 0) {
              if (tier > lastTier) {
                relegatedHere++;
                pendingRelegation = true;
              } else if (tier < lastTier && pendingRelegation) {
                backUp++;
                pendingRelegation = false;
              }
            }
            lastTier = tier;
          },
        );

        trustSum += minTrust;
        if (minTrust < Formulas.trustWarning) nearMiss++;
        if (frozenHere > 0) {
          frozenCareers++;
          frozenSpells += frozenHere;
          frozenSeasons += frozenSeasonsHere;
          if (endedFrozen) frozenAtEnd++;
        }
        if (zeroHere > 0) {
          zeroCareers++;
          zeroSpells += zeroHere;
        }
        if (relegatedHere > 0) {
          relegatedCareers++;
          relegations += relegatedHere;
        }
      }

      String pct(int n) => '${(n / careers * 100).round()}%';
      print(
        '${position.name.toUpperCase().padRight(3)} '
        '構想外 ${pct(frozenCareers)}'
        '（落ちた回数 $frozenSpells・のべ $frozenSeasons季・'
        '引退時も構想外 $frozenAtEnd人）  '
        '無出場 ${pct(zeroCareers)}（$zeroSpells季・翌季に復帰 $backAfterZero）  '
        '降格 ${pct(relegatedCareers)}（$relegations回・戻った $backUp回）  '
        '信頼の底 平均${(trustSum / careers).toStringAsFixed(1)}  '
        '警告の線(${Formulas.trustWarning})を割った ${pct(nearMiss)}',
      );
    }
    // 参考: 構想外に落ちる線
    print('構想外の線: 監督の信頼 ${Formulas.frozenOutTrust} 未満');
  }, timeout: const Timeout(Duration(minutes: 60)));
}
