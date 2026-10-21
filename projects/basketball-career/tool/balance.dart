// ignore_for_file: avoid_print
// バランスの目安を出す: dart run tool/balance.dart
// 練習中心(疲れたら休養)で 1000 人を最後まで進め、進路と結末の割合を数える。
import 'dart:math';

import 'package:basketball_career/game/advice.dart';
import 'package:basketball_career/game/game.dart';
import 'package:basketball_career/game/life.dart';
import 'package:basketball_career/game/match.dart';
import 'package:basketball_career/game/path.dart';
import 'package:basketball_career/game/player.dart';

void main(List<String> args) {
  const n = 1000;
  final smart = args.contains('--smart');
  final auto = args.contains('--auto');
  final spec = args.contains('--spec') || args.contains('--team');
  final team = args.contains('--team');
  var pro = 0, direct = 0, abroad = 0, titles = 0, rw = 0, rl = 0, awards = 0, skills = 0, st = 0, bl = 0, th = 0, games = 0, high = 0;
  var ovrAt18 = 0.0, heightAt18 = 0.0;
  var earnSum = 0, earnMax = 0, proCount = 0, salaryTop = 0;
  final totP = <int>[], totR = <int>[], totA = <int>[];
  final honorCareers = <String, int>{};
  final honorTotals = <String, int>{};
  for (var seed = 0; seed < n; seed++) {
    final g = Game.start('x', rng: Random(seed));
    var guard = 0;
    var seen18 = false;
    while (g.phase != Phase.retired && guard++ < 500) {
      if (!seen18 && g.player.age == 18) {
        seen18 = true;
        ovrAt18 += g.player.overall;
        heightAt18 += g.player.heightCm;
      }
      switch (g.phase) {
        case Phase.season:
          final rest = g.condition.fatigue >= 60 || g.condition.injured;
          // 重点は今いちばん低い能力ではなく、ポジションに効く能力を順に回す。
          if (auto) {
            // 画面の「おすすめで1年進める」と同じ方針。
            g.choose(recommendedAction(g), recommendedFocus(g.player));
          } else if (spec) {
            // ポジションに効く能力のうち、重み×(100-今の値)がいちばん大きいものを重点にする。
            final w = weightsOf(g.player.position);
            final focus = w.keys.reduce((a, b) =>
                w[a]! * (100 - g.player.of(a)) >= w[b]! * (100 - g.player.of(b))
                    ? a
                    : b);
            var act = rest
                ? Action.rest
                : (g.condition.fatigue < 25 ? Action.intense : Action.practice);
            // チームワークを保つため、年に2回は交流する。
            if (team && !g.condition.injured && (g.slot == 0 || g.slot == 2)) {
              act = Action.social;
            }
            g.choose(act, focus);
          } else if (smart) {
            // 一番低い能力を重点にし、疲れが軽いうちは特訓を混ぜる。
            final low = Ability.values.reduce(
                (a, b) => g.player.of(a) <= g.player.of(b) ? a : b);
            final act = rest
                ? Action.rest
                : (g.condition.fatigue < 25 ? Action.intense : Action.practice);
            g.choose(act, low);
          } else {
            g.choose(rest ? Action.rest : Action.practice,
                Ability.values[guard % Ability.values.length]);
          }
          if (g.canGoAbroad) {
            g.goAbroad();
            abroad++;
          }
        case Phase.halftime:
          g.resolveHalftime(bestHalftime(g.player, g.halftimeInfo!));
        case Phase.clutch:
          g.resolveClutch(bestClutch(g.player, g.run!.pending!.oppStrength, g.run!.pending!.form));
        case Phase.event:
          // --local: 進学先は地元の学校、--club: 少数精鋭。ほかの出来事は最初の選択肢。
          final school = g.pendingEventId?.startsWith('school_') ?? false;
          g.resolveEvent(school ? (args.contains('--local') ? 1 : args.contains('--club') ? 2 : 0) : 0);
        case Phase.path:
          final first = !g.secondChance;
          final ok = g.chooseRoute(Route.pro);
          if (ok && first) direct++;
          if (!ok && !g.retired) g.chooseRoute(Route.university);
        case Phase.retired:
          break;
      }
    }
    if (g.records.any((r) => r.league.name.startsWith('pro'))) pro++;
    titles += g.titles;
    st += g.totalSteals;
    bl += g.totalBlocks;
    th += g.totalThrees;
    games += g.totalGames;
    high += g.careerHigh?.points ?? 0;
    skills += g.player.skills.length;
    awards += g.records.where((r) => r.award != null).length;
    totP.add(g.totalPoints);
    totR.add(g.totalRebounds);
    totA.add(g.totalAssists);
    if (g.totalEarnings > 0) {
      proCount++;
      earnSum += g.totalEarnings;
      if (g.totalEarnings > earnMax) earnMax = g.totalEarnings;
    }
    if (g.salary > salaryTop) salaryTop = g.salary;
    g.honorCounts.forEach((h, c) {
      honorCareers[h] = (honorCareers[h] ?? 0) + 1;
      honorTotals[h] = (honorTotals[h] ?? 0) + c;
    });
    rw += g.rival.wins;
    rl += g.rival.losses;
  }
  String pct(int v) => '${(v / n * 100).toStringAsFixed(1)}%';
  print('プロ入り: ${pct(pro)}(高校から直接 ${pct(direct)})');
  print('海外挑戦: ${pct(abroad)}');
  String dist(List<int> v) {
    final x = [...v]..sort();
    return '平均 ${(x.fold(0, (a, b) => a + b) / x.length).round()} / 中央 ${x[x.length ~/ 2]} / 上位1割 ${x[(x.length * 0.9).floor()]} / 最大 ${x.last}';
  }
  print('通算 得点: ${dist(totP)}');
  print('通算 リバウンド: ${dist(totR)}');
  print('通算 アシスト: ${dist(totA)}');
  print('プロの生涯収入(万円): 平均 ${proCount == 0 ? 0 : (earnSum / proCount).round()} / 最大 $earnMax (対象 $proCount人)  最高年俸 $salaryTop');
  for (final h in honorCareers.keys.toList()..sort()) {
    print('表彰 $h: ${pct(honorCareers[h]!)}の人生で受賞(1人あたり ${(honorTotals[h]! / n).toStringAsFixed(2)}回)');
  }
  print('ライバルとの通算: ${(rw / n).toStringAsFixed(1)}勝 ${(rl / n).toStringAsFixed(1)}敗(1人あたり)');
  print('1試合あたり: スティール ${(st / games).toStringAsFixed(2)} ブロック ${(bl / games).toStringAsFixed(2)} 3P ${(th / games).toStringAsFixed(2)}本 / キャリアハイ平均 ${(high / n).toStringAsFixed(1)}点');
  print('平均の得意技: ${(skills / n).toStringAsFixed(1)}個');
  print('平均の個人賞: ${(awards / n).toStringAsFixed(2)}回');
  print('平均タイトル数: ${(titles / n).toStringAsFixed(2)}');
  print('18歳の平均 総合 ${(ovrAt18 / n).toStringAsFixed(1)} / 身長 ${(heightAt18 / n).toStringAsFixed(1)}cm');
}
