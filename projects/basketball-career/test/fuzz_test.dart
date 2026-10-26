// でたらめな選び方で一生を大量に遊び、例外・範囲外の値・保存の取りこぼしが無いかを調べる(品質の網)。
import 'dart:convert';
import 'dart:math';

import 'package:basketball_career/game/build.dart';
import 'package:basketball_career/game/difficulty.dart';
import 'package:basketball_career/game/dream.dart';
import 'package:basketball_career/game/epilogue.dart';
import 'package:basketball_career/game/game.dart';
import 'package:basketball_career/game/life.dart';
import 'package:basketball_career/game/match.dart';
import 'package:basketball_career/game/player.dart';
import 'package:basketball_career/game/special.dart';
import 'package:flutter_test/flutter_test.dart';

/// 値が範囲に収まっているか(外れたら、どこで外れたかが分かる文を返す)。
String? _violation(Game g) {
  for (final a in Ability.values) {
    final v = g.player.of(a);
    if (v < 0 || v > abilityCap) return '${a.name} が範囲外: $v';
  }
  final c = g.condition;
  if (c.fatigue < 0 || c.fatigue > 100) return '疲れが範囲外: ${c.fatigue}';
  if (c.morale < 0 || c.morale > 100) return '気持ちが範囲外: ${c.morale}';
  if (g.teamwork < 0 || g.teamwork > 100) return 'チームワークが範囲外: ${g.teamwork}';
  if (g.coachBond < 0 || g.coachBond > 100) return 'コーチとの信頼が範囲外: ${g.coachBond}';
  if (g.sp < 0) return 'ポイントがマイナス: ${g.sp}';
  if (g.habit < -10 || g.habit > 10) return '生活習慣が範囲外: ${g.habit}';
  if (g.player.heightCm < 100 || g.player.heightCm > 240) {
    return '身長が不自然: ${g.player.heightCm}';
  }
  if (g.dreamProgress < 0 || g.dreamProgress > 1) return '夢の進み具合が範囲外';
  if (g.player.positionLock == null) return 'ポジションが決まっていない';
  if (g.player.overall < 0 || g.player.overall > 99) return '総合が範囲外: ${g.player.overall}';
  if (g.salary < 0 || g.sponsor < 0 || g.totalEarnings < 0) return 'お金がマイナス';
  final run = g.run;
  if (run != null && (run.timeouts < 0 || run.zones < 0)) return 'タイムアウト・ゾーンの残りがマイナス';
  return null;
}

/// 画面に出す文に、穴あきの語(`{rival}` など)・null・NaN・Infinity が残っていないか。
String? _badText(String t) {
  for (final bad in ['{', '}', 'null', 'NaN', 'Infinity', r'$']) {
    if (t.contains(bad)) return '「$bad」が文に残っている: $t';
  }
  return null;
}

void main() {
  test('でたらめな選び方で500人ぶん遊んでも、例外も範囲外の値も出ず、保存を読み戻しても同じ', () {
    final problems = <String>[];
    for (var seed = 0; seed < 500; seed++) {
      final r = Random(seed * 7919 + 13);
      final g = Game.start('ふ',
          rng: Random(seed),
          events: r.nextBool() || r.nextBool(),
          difficulty: Difficulty.values[r.nextInt(3)],
          dream: Dream.values[r.nextInt(Dream.values.length)],
          style: r.nextInt(3) == 0 ? null : Build.values[r.nextInt(Build.values.length)],
          legacyBonus: r.nextInt(6));
      var guard = 0, lastAge = g.player.age;
      try {
        while (g.phase != Phase.retired && guard++ < 900) {
          // 気まぐれに、特殊能力・型を選び直す。
          if (r.nextInt(6) == 0) {
            final options = learnPriority.where((s) => canLearn(g.player.specials, g.sp, s)).toList();
            if (options.isNotEmpty) g.learnSpecial(options[r.nextInt(options.length)]);
          }
          if (r.nextInt(30) == 0) {
            g.setPosition(r.nextBool() ? null : Position.values[r.nextInt(Position.values.length)]);
          }
          if (r.nextInt(40) == 0) {
            g.setStyle(r.nextBool() ? null : Build.values[r.nextInt(Build.values.length)]);
          }
          switch (g.phase) {
            case Phase.season:
              final ok = Action.values.where((a) => canChoose(a, g.condition)).toList();
              final f = Ability.values[r.nextInt(Ability.values.length)];
              final f2 = r.nextBool() ? null : Ability.values[r.nextInt(Ability.values.length)];
              if (g.goal == null && g.goalOptions.isNotEmpty && r.nextBool()) {
                g.adoptGoal(r.nextInt(g.goalOptions.length));
              }
              if (g.canRecover && r.nextInt(3) == 0) g.recover();
              g.choose(ok[r.nextInt(ok.length)], f,
                  focus2: f2 == f ? null : f2,
                  askClutch: r.nextBool(),
                  askHalftime: r.nextBool());
              if (g.canGoAbroad && r.nextBool()) g.goAbroad();
              if (g.phase == Phase.season &&
                  g.track == Track.pro &&
                  g.player.age > 32 &&
                  r.nextInt(30) == 0) {
                g.retire();
              }
            case Phase.halftime:
              g.resolveHalftime(Halftime.values[r.nextInt(Halftime.values.length)]);
            case Phase.clutch:
              if (r.nextInt(3) == 0 && (g.run?.timeouts ?? 0) > 0 && !(g.run?.pending?.timeout ?? true)) {
                g.useTimeout();
              }
              if (r.nextInt(3) == 0 && (g.run?.zones ?? 0) > 0 && !(g.run?.pending?.zone ?? true)) {
                g.useZone();
              }
              g.resolveClutch(Clutch.values[r.nextInt(Clutch.values.length)]);
            case Phase.event:
              final e = g.pendingEvent!;
              for (final t in [e.title, g.fill(e.body), for (final o in e.options) o.label]) {
                final bad = _badText(t);
                if (bad != null) problems.add('seed $seed 出来事 ${e.id}: $bad');
              }
              final lines = g.resolveEvent(r.nextInt(e.options.length));
              for (final t in lines) {
                final bad = _badText(t);
                if (bad != null) problems.add('seed $seed 出来事の結果 ${e.id}: $bad');
              }
            case Phase.path:
              final routes = g.availableRoutes;
              g.chooseRoute(routes[r.nextInt(routes.length)]);
            case Phase.retired:
              break;
          }
          final v = _violation(g);
          if (v != null) {
            problems.add('seed $seed 年齢${g.player.age}: $v');
            break;
          }
          if (g.player.age < lastAge) {
            problems.add('seed $seed: 年齢が戻った');
            break;
          }
          lastAge = g.player.age;
          // ときどき保存して読み戻し、同じになるか。
          if (r.nextInt(12) == 0) {
            final a = jsonEncode(g.toJson());
            final b = jsonEncode(Game.fromJson(jsonDecode(a) as Map<String, dynamic>).toJson());
            if (a != b) {
              problems.add('seed $seed 年齢${g.player.age}: 保存を読み戻すと変わる');
              break;
            }
          }
        }
        if (g.phase != Phase.retired && guard >= 900) problems.add('seed $seed: 終わらない');
        if (g.phase == Phase.retired) {
          for (final t in [...epilogueLines(g), shareText(g)]) {
            final bad = _badText(t);
            if (bad != null) problems.add('seed $seed エンディング: $bad');
          }
        }
      } catch (e, st) {
        problems.add('seed $seed 年齢${g.player.age} フェーズ${g.phase}: 例外 $e\n$st');
      }
      if (problems.length >= 8) break;
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}
