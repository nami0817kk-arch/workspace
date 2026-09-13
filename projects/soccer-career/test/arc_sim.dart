// ignore_for_file: avoid_print
/// **キャリアの弧を測る。**
///
/// 「1部到達 90%・代表経験 85%・W杯 82%」——普通に遊べば行きたいところに
/// 全部着く。問題は**何歳で着くか**と、**そのあと何が残っているか**。
///
/// 後半15年の「週に目的が無い」は磨きで埋めたが、**目標の層**で同じことが
/// 起きていないかを見る。手動実行（`_test.dart` で終わらない）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/game/world.dart';
import 'package:soccer_career/models/competition.dart';
import 'package:soccer_career/models/season.dart';

import 'support/career_sim.dart';

void main() {
  test('arc', () async {
    const n = 120;

    // 歳ごとの合計。
    final seasons = <int, int>{};
    final strength = <int, int>{};
    final overall = <int, int>{};
    final firsts = <int, int>{}; // その歳に「初めて」が起きたキャリア数
    final moved = <int, int>{};
    // **見出しの数は測らない。** `state.news` は `Newsroom.keep`（40件）で
    // 切られるので、24歳以降ずっと 40.0 になる——測っていたのは上限だった。
    // 代わりに「その年に実際に起きたこと」を数える。
    final titles = <int, int>{};
    final calledUp = <int, int>{};
    final newManager = <int, int>{};
    final apps = <int, int>{};
    final gotOffer = <int, int>{};   // 移籍オファーが1件でも来た
    final betterOffer = <int, int>{}; // 今より強いクラブから来た
    final renewal = <int, int>{};     // 契約更改の話だけがあった
    // **上のクラブへ行くと、条件は良くなるのか。**
    var upCount = 0;
    var upSalarySum = 0.0;   // 上のクラブのオファー年俸
    var staySalarySum = 0.0; // そのとき居るクラブの更改年俸
    var upStrengthSum = 0.0; // 強さの差

    // 「初めて」が起きた歳の分布。
    final firstTop = <int>[];
    final firstCap = <int>[];
    final firstTitle = <int>[];
    final firstContinental = <int>[];
    final firstWorldCup = <int>[];
    final firstTopFive = <int>[]; // 格5の国の1部
    final peakAge = <int>[];
    var lastFirstSum = 0;
    var retireSum = 0;

    for (var seed = 0; seed < n; seed++) {
      var top = 0;
      var cap = 0;
      var title = 0;
      var cont = 0;
      var wc = 0;
      var topFive = 0;
      var lastFirst = 0;
      var bestOverall = 0;
      var bestAge = 0;
      var lastClub = '';
      var lastCaps = 0;

      final career = await runCareer(
        Playstyle(
          name: 'cm',
          position: Position.cm,
          startAge: 18,
          sim: SimStyle.balanced,
          agent: Agent.pool.first,
        ),
        seed,
        onSeason: (state, stats, controller) {
          final age = state.player.age;
          seasons[age] = (seasons[age] ?? 0) + 1;
          strength[age] = (strength[age] ?? 0) + state.club.strength;
          overall[age] = (overall[age] ?? 0) + state.player.overall;
          if ((state.leaguePosition == 1 && state.club.tier == 1) ||
              state.cupStage == CupStage.winner) {
            titles[age] = (titles[age] ?? 0) + 1;
          }
          if (state.caps > lastCaps) calledUp[age] = (calledUp[age] ?? 0) + 1;
          lastCaps = state.caps;
          if (state.manager?.tenure == 0) {
            newManager[age] = (newManager[age] ?? 0) + 1;
          }
          apps[age] = (apps[age] ?? 0) + stats.appearances;
          // **来ていないのか、来ても受けないのかを分ける。**
          final market = controller.offers
              .where((o) => !o.isRenewal && !o.loan)
              .toList();
          if (market.isNotEmpty) gotOffer[age] = (gotOffer[age] ?? 0) + 1;
          if (market.any((o) => o.club.strength > state.club.strength)) {
            betterOffer[age] = (betterOffer[age] ?? 0) + 1;
          }
          if (market.isEmpty && controller.renewalOffer != null) {
            renewal[age] = (renewal[age] ?? 0) + 1;
          }
          final better = market
              .where((o) => o.club.strength > state.club.strength)
              .toList();
          final stay = controller.renewalOffer;
          if (better.isNotEmpty && stay != null && age >= 25) {
            better.sort((a, b) => b.salary.compareTo(a.salary));
            upCount++;
            upSalarySum += better.first.salary;
            staySalarySum += stay.salary;
            upStrengthSum += better.first.club.strength - state.club.strength;
          }
          if (lastClub.isNotEmpty && state.club.name != lastClub) {
            moved[age] = (moved[age] ?? 0) + 1;
          }
          lastClub = state.club.name;
          if (state.player.overall > bestOverall) {
            bestOverall = state.player.overall;
            bestAge = age;
          }

          var isFirst = false;
          void mark(bool reached, List<int> into, int flag) {
            if (!reached || flag != 0) return;
            into.add(age);
            isFirst = true;
          }

          mark(state.club.tier == 1, firstTop, top);
          if (state.club.tier == 1 && top == 0) top = age;
          mark(state.caps > 0, firstCap, cap);
          if (state.caps > 0 && cap == 0) cap = age;
          final won =
              (state.leaguePosition == 1 && state.club.tier == 1) ||
              state.cupStage == CupStage.winner;
          mark(won, firstTitle, title);
          if (won && title == 0) title = age;
          mark(state.continentalStage.participated, firstContinental, cont);
          if (state.continentalStage.participated && cont == 0) cont = age;
          mark(state.worldCupStage.participated, firstWorldCup, wc);
          if (state.worldCupStage.participated && wc == 0) wc = age;
          final elite = state.club.tier == 1 && World.byId(state.club.countryId).prestige >= 5;
          mark(elite, firstTopFive, topFive);
          if (elite && topFive == 0) topFive = age;

          if (isFirst) {
            firsts[age] = (firsts[age] ?? 0) + 1;
            lastFirst = age;
          }
        },
      );
      lastFirstSum += lastFirst;
      retireSum += career.retireAge;
      peakAge.add(bestAge);
    }

    String pct(List<int> ages) =>
        '${(ages.length / n * 100).toStringAsFixed(0)}%';
    String med(List<int> ages) {
      if (ages.isEmpty) return '—';
      final sorted = [...ages]..sort();
      return '${sorted[sorted.length ~/ 2]}歳';
    }

    print('--- 初めて届いた歳（$n キャリア・CM・18歳開始） ---');
    for (final row in [
      ('1部', firstTop),
      ('代表', firstCap),
      ('タイトル', firstTitle),
      ('大陸カップ', firstContinental),
      ('世界大会', firstWorldCup),
      ('格5の国の1部', firstTopFive),
      ('ピーク総合力', peakAge),
    ]) {
      print('${row.$1.padRight(12)} 到達 ${pct(row.$2).padLeft(4)}  中央 ${med(row.$2)}');
    }
    print('最後に「初めて」が起きた歳 平均 ${(lastFirstSum / n).toStringAsFixed(1)}');
    print('引退年齢 平均 ${(retireSum / n).toStringAsFixed(1)}');

    print('');
    print('');
    print('--- 25歳以降、上のクラブから来た話（$upCount 件） ---');
    if (upCount > 0) {
      print('  上のクラブの年俸  ${(upSalarySum / upCount).toStringAsFixed(0)}万');
      print('  残留の更改年俸    ${(staySalarySum / upCount).toStringAsFixed(0)}万');
      print(
        '  条件の差          '
        '${((upSalarySum - staySalarySum) / upCount).toStringAsFixed(0)}万'
        '（${(upSalarySum / staySalarySum * 100 - 100).toStringAsFixed(0)}%）',
      );
      print('  クラブの強さの差  +${(upStrengthSum / upCount).toStringAsFixed(1)}');
    }
    print('');
    print('歳  人数  移籍  オファー  上のクラブから  更改のみ  タイトル  代表  出場  強さ');
    for (final age in seasons.keys.toList()..sort()) {
      final c = seasons[age]!;
      if (c < n ~/ 6) continue;
      String p(Map<int, int> m) =>
          '${((m[age] ?? 0) / c * 100).toStringAsFixed(0).padLeft(4)}%';
      print(
        '$age  ${c.toString().padLeft(4)}  ${p(moved)}  ${p(gotOffer)}     '
        '${p(betterOffer)}          ${p(renewal)}   ${p(titles)}  '
        '${p(calledUp)}  '
        '${((apps[age] ?? 0) / c).toStringAsFixed(0).padLeft(4)}  '
        '${(strength[age]! / c).toStringAsFixed(1).padLeft(6)}',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 40)));
}
