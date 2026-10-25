// 実績が実際に取れるかを調べる: いろいろな遊び方で何人も遊ばせ、一度も取れなかった実績を出す
// (dart run tool/ach_audit.dart [人数])。
// ignore_for_file: avoid_print
import 'dart:math';

import 'package:baseball_manager/game/achievements.dart';
import 'package:baseball_manager/game/after_career.dart';
import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/difficulty.dart';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/invest.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/skills.dart';
import 'package:baseball_manager/game/snapshot.dart';

void main(List<String> a) {
  final n = a.isEmpty ? 600 : int.parse(a.first);
  final got = <String, int>{for (final x in achievements) x.id: 0};
  PlayerSnapshot? parent;
  for (var s = 0; s < n; s++) {
    final r = Random(s);
    final role = [Role.batter, Role.pitcher][r.nextInt(2)];
    final d = Difficulty.values[r.nextInt(Difficulty.values.length)];
    final g = Game.newGame(
        name: 't',
        role: role,
        rng: Random(s),
        difficulty: d,
        potential: 40 + r.nextInt(60),
        parent: r.nextInt(4) == 0 ? parent : null);
    final wantTwoWay = r.nextInt(5) == 0;
    final wantOverseas = r.nextInt(4) == 0;
    final invest = r.nextBool();
    final retireAge = 33 + r.nextInt(10);
    // 10人に1人は、プロで伸び悩む選手(戦力外→トライアウトの実績を調べるため)。
    final weak = r.nextInt(10) == 0;
    // 3人に1人は、特殊能力を集める選手(弱点は克服し、取れる特殊能力を安い順に取る)。
    final skillFan = r.nextInt(3) == 0;
    var steps = 0;
    while (g.phase != Phase.retired) {
      if (++steps > 6000) throw StateError('終わらない seed=$s');
      if (skillFan) {
        for (final k in weaknessesFor(g.player.role)) {
          if (g.player.skills.contains(k)) g.buySkill(k);
        }
        final cands = [...skillsFor(g.player.role)]
          ..sort((x, y) => g.skillPrice(x).compareTo(g.skillPrice(y)));
        for (final k in cands) {
          if (g.buySkill(k) == null) break;
        }
      }
      g.autoSpend();
      switch (g.phase) {
        case Phase.term:
          if (g.stage == Stage.pro && g.player.age >= retireAge) {
            g.retire();
            break;
          }
          if (g.stage == Stage.pro && weak) {
            for (final a in abilitiesOf(g.player.role)) {
              g.adminSetAbility(a, 10);
            }
          }
          if (g.stage == Stage.pro) {
            if (wantTwoWay && g.player.role != Role.twoWay) {
              g.changeRole(Role.twoWay);
            }
            if (wantOverseas && g.canMoveOverseas) g.moveOverseas();
            if (g.canUseFa) {
              g.useFa(FaChoice.values[r.nextInt(FaChoice.values.length)]);
            }
            if (invest) {
              for (final i in Invest.values) {
                g.buyInvest(i);
              }
            }
          }
          if (g.canChooseGoal && r.nextInt(3) == 0) {
            g.chooseGoalLevel(r.nextInt(3));
          }
          final ab = abilitiesOf(g.player.role);
          final plan = g.condition.fatigue >= 60
              ? Plan.rest
              : [
                  Plan.train,
                  Plan.special,
                  Plan.lesson,
                  Plan.social,
                  if (skillFan) Plan.study,
                  if (skillFan) Plan.match,
                ][r.nextInt(skillFan ? 6 : 4)];
          g.choose(plan, ab[r.nextInt(ab.length)]);
        case Phase.event:
          g.resolveEvent(g.pendingEvent!.id == 'tryout'
              ? (weak ? 0 : r.nextInt(2))
              : r.nextInt(g.pendingEvent!.choices.length));
        case Phase.pathChoice:
          g.chooseRoute(r.nextBool() ? Course.university : Course.corporate);
        case Phase.retired:
          break;
      }
    }
    // プロを引退した選手は、引退後の道を1つ選ぶ(実績「セカンドキャリア」を調べるため)。
    if (g.ending!.madePro) {
      g.chooseAfterPath(AfterPath.values[r.nextInt(AfterPath.values.length)]);
    }
    final snap = PlayerSnapshot.fromGame(g);
    parent = snap;
    for (final id in earnedBy(snap)) {
      got[id] = got[id]! + 1;
    }
  }
  final never = got.entries.where((e) => e.value == 0).toList();
  print('実績 ${got.length}個 / $n人。一度も取れなかった: ${never.length}個');
  for (final e in never) {
    final x = achievements.firstWhere((x) => x.id == e.key);
    print('  ${x.id}  ${x.title}: ${x.description}');
  }
  final rare = got.entries.where((e) => e.value > 0 && e.value < n * 0.01);
  print('1%未満: ${rare.map((e) => '${e.key}(${e.value})').join(', ')}');
}
