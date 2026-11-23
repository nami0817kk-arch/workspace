import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/logic/dynamics_engine.dart';
import 'package:soccer_manager/logic/lineup_utils.dart';
import 'package:soccer_manager/logic/manager_tactics.dart';
import 'package:soccer_manager/logic/match_engine.dart';
import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/logic/tactics_ai.dart';
import 'package:soccer_manager/models/attributes.dart';
import 'package:soccer_manager/models/league.dart';
import 'package:soccer_manager/models/manager_profile.dart';
import 'package:soccer_manager/models/match_result.dart';
import 'package:soccer_manager/models/club_infrastructure.dart';
import 'package:soccer_manager/models/team.dart';
import 'package:soccer_manager/state/game_state.dart';

Team _copy(Team t, String id) {
  final json = t.toJson();
  json['id'] = id;
  return Team.fromJson(json);
}

/// CPU と同じ決め方([CpuTacticsAI])で [t] を整える(相手は同じ戦力)。
void _cpuSetup(Team t, Team opp) {
  t.mentality = CpuTacticsAI.mentalityFor(
      ownRating: t.overallRating, opponentRating: opp.overallRating);
  t.tacticalStyle = CpuTacticsAI.styleFor(t);
}

/// 監督の決め方で [t] を整える(ゲームの中と同じ順: 構え→戦い方)。
void _managerSetup(Team t, Team opp, ManagerStyle style, int level) {
  t.mentality = style.shift(CpuTacticsAI.mentalityFor(
      ownRating: t.overallRating, opponentRating: opp.overallRating));
  ManagerTactics.apply(t, style: style, level: level, opponent: opp);
}

({double win, double draw, double loss, double gf, double ga}) _measure({
  required List<Team> pool,
  required int matches,
  required void Function(Team a, Team b) setupA,
  required void Function(Team b, Team a) setupB,
}) {
  var w = 0, d = 0, l = 0, gf = 0, ga = 0;
  for (var i = 0; i < matches; i++) {
    final base = pool[i % pool.length];
    final a = _copy(base, 'A');
    final b = _copy(base, 'B');
    setupA(a, b);
    setupB(b, a);
    final aHome = i.isEven;
    final r = MatchEngine.simulate(
        home: aHome ? a : b, away: aHome ? b : a, matchday: 1);
    final ag = aHome ? r.homeGoals : r.awayGoals;
    final bg = aHome ? r.awayGoals : r.homeGoals;
    gf += ag;
    ga += bg;
    if (ag > bg) {
      w++;
    } else if (ag == bg) {
      d++;
    } else {
      l++;
    }
  }
  return (
    win: w / matches,
    draw: d / matches,
    loss: l / matches,
    gf: gf / matches,
    ga: ga / matches,
  );
}

String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('考え方ごとの値', () {
    test('攻撃的は前がかり・堅守は低く遅く、逃げ切るのは現実的と堅守', () {
      final att = ManagerTactics.planFor(ManagerStyle.attacking);
      final def = ManagerTactics.planFor(ManagerStyle.defensive);
      final pra = ManagerTactics.planFor(ManagerStyle.pragmatic);
      final you = ManagerTactics.planFor(ManagerStyle.youth);
      expect(att.lineHeight, greaterThan(pra.lineHeight));
      expect(att.pressing, greaterThan(pra.pressing));
      expect(att.tempo, greaterThan(pra.tempo));
      expect(def.lineHeight, lessThan(pra.lineHeight));
      expect(def.pressing, lessThan(pra.pressing));
      expect(you.pressing, greaterThan(pra.pressing));
      expect(att.holdLeadLate, isFalse);
      expect(you.holdLeadLate, isFalse);
      expect(pra.holdLeadLate, isTrue);
      expect(def.holdLeadLate, isTrue);
      expect(def.styles, isNot(contains(TacticalStyle.gegenpress)));
      expect(att.styles, isNot(contains(TacticalStyle.counter)));
    });

    test('当てると値が入り、試合の頭からの逃げ切りは消える', () {
      final t =
          PlayerGenerator.generateSquad(id: 't', name: 'T', strengthTier: 60);
      LineupUtils.autoFill(t);
      t.timeWastingMode = true;
      for (final style in ManagerStyle.values) {
        ManagerTactics.apply(t, style: style, level: 4);
        final plan = ManagerTactics.planFor(style);
        expect(t.pressing, plan.pressing);
        expect(t.lineHeight, plan.lineHeight);
        expect(t.width, plan.width);
        expect(t.tempo, plan.tempo);
        expect(t.holdLeadLate, plan.holdLeadLate);
        expect(t.timeWastingMode, isFalse);
        expect(
            t.tacticalStyle == TacticalStyle.flexible ||
                plan.styles.contains(t.tacticalStyle),
            isTrue,
            reason: '$style は好みの型か柔軟だけを使う');
      }
    });

    test('水準の高い監督は格上相手にラインを下げ、低い監督は変えない', () {
      final weak =
          PlayerGenerator.generateSquad(id: 'w', name: 'W', strengthTier: 45);
      final strong =
          PlayerGenerator.generateSquad(id: 's', name: 'S', strengthTier: 75);
      LineupUtils.autoFill(weak);
      LineupUtils.autoFill(strong);
      ManagerTactics.apply(weak,
          style: ManagerStyle.attacking, level: 7, opponent: strong);
      expect(weak.lineHeight,
          lessThan(ManagerTactics.planFor(ManagerStyle.attacking).lineHeight));
      ManagerTactics.apply(weak,
          style: ManagerStyle.attacking, level: 2, opponent: strong);
      expect(weak.lineHeight,
          ManagerTactics.planFor(ManagerStyle.attacking).lineHeight);
    });

    test('水準の高い監督は、相性で負ける型を避ける', () {
      final t =
          PlayerGenerator.generateSquad(id: 't', name: 'T', strengthTier: 70);
      LineupUtils.autoFill(t);
      // ゲーゲンプレスはポゼッションに勝つ。相手がゲーゲンプレスなら、
      // ポゼッション(負ける型)は選ばない。
      final picked = ManagerTactics.styleFor(t,
          style: ManagerStyle.pragmatic,
          level: 7,
          opponentStyle: TacticalStyle.gegenpress);
      expect(picked, isNot(TacticalStyle.possession));
    });

    test('説明は2行で、考え方ごとに違う', () {
      final texts = {
        for (final s in ManagerStyle.values) ManagerTactics.summary(s),
      };
      expect(texts.length, ManagerStyle.values.length);
      for (final t in texts) {
        expect('\n'.allMatches(t).length, 1);
      }
    });
  });

  group('キャプテン', () {
    test('統率力の高い選手を指名し、借りている選手は選ばない', () {
      final t =
          PlayerGenerator.generateSquad(id: 't', name: 'T', strengthTier: 60);
      final leader = t.players[3];
      leader.attributes[AttributeKeys.leadership] = 99;
      final loanee = t.players[4];
      loanee.attributes[AttributeKeys.leadership] = 100;
      loanee.isLoan = true;
      expect(ManagerTactics.appointCaptains(t), isTrue);
      expect(t.captainId, leader.id);
      expect(t.viceCaptainId, isNot(loanee.id));
      expect(t.viceCaptainId, isNot(leader.id));
      // 同じなら変わらない。
      expect(ManagerTactics.appointCaptains(t), isFalse);
      // 肩書が付き、チームリーダーにも数えられる。
      expect(DynamicsEngine.isTeamLeader(t, leader.id), isTrue);
    });

    test('キャプテンがいなくなったら選び直しが要る', () {
      final t =
          PlayerGenerator.generateSquad(id: 't', name: 'T', strengthTier: 60);
      expect(ManagerTactics.needsNewCaptain(t), isTrue);
      ManagerTactics.appointCaptains(t);
      expect(ManagerTactics.needsNewCaptain(t), isFalse);
      t.players.removeWhere((p) => p.id == t.captainId);
      expect(ManagerTactics.needsNewCaptain(t), isTrue);
    });
  });

  group('ゲームの中', () {
    Fixture nextFixture(GameState gs) =>
        gs.save!.league.fixtures.firstWhere((f) =>
            f.result == null &&
            (f.homeTeamId == gs.save!.userTeamId ||
                f.awayTeamId == gs.save!.userTeamId));

    test('毎節、監督の考え方の戦い方が当たり、季の初めにキャプテンが決まる', () async {
      final gs = GameState();
      await gs.startNewGame('戦い方FC');
      final team = gs.userTeam;
      team.pressing = 5;
      team.lineHeight = 95;
      team.timeWastingMode = true;
      team.captainId = null;
      final next = nextFixture(gs);
      gs.debugManagerPreparesMatch(next);
      final style = gs.currentManager?.manager?.style ?? ManagerStyle.pragmatic;
      final plan = ManagerTactics.planFor(style);
      final level = gs.save!.infrastructure.staffLevel(StaffRole.manager);
      if (level < ManagerTactics.adjustToOpponentLevel) {
        expect(team.lineHeight, plan.lineHeight);
      }
      expect(team.pressing, plan.pressing);
      expect(team.holdLeadLate, plan.holdLeadLate);
      expect(team.timeWastingMode, isFalse);
      expect(team.captainId, isNotNull);
    });

    test('セットプレーの担当(PK・FK・CK・守備)も毎節、監督が CPU と同じ決め方で決める', () async {
      final gs = GameState();
      await gs.startNewGame('戦い方FC');
      final team = gs.userTeam;
      team.penaltyTakerId = null;
      team.freeKickTakerId = null;
      team.cornerTakerId = null;
      team.setPieceDefenderId = null;
      gs.debugManagerPreparesMatch(nextFixture(gs));
      final best = team.players.reduce((a, b) =>
          b.attributeValue(AttributeKeys.penalties) >
                  a.attributeValue(AttributeKeys.penalties)
              ? b
              : a);
      expect(team.penaltyTakerId, best.id);
      expect(team.freeKickTakerId, isNotNull);
      expect(team.cornerTakerId, isNotNull);
      expect(team.setPieceDefenderId, isNotNull);
    });

    test('監督を替えると戦い方とキャプテンが新しい監督のものになる', () async {
      final gs = GameState();
      await gs.startNewGame('戦い方FC');
      gs.save!.budget = 99999999;
      gs.save!.wageBudget = 99999999;
      final current = gs.currentManager?.manager?.style;
      final c = gs.staffCandidatesFor(StaffRole.manager).firstWhere(
          (c) => c.manager!.style != current,
          orElse: () => gs.staffCandidatesFor(StaffRole.manager).first);
      gs.userTeam.captainId = null;
      expect(await gs.hireStaff(c.id), isTrue);
      final plan = ManagerTactics.planFor(c.manager!.style);
      expect(gs.userTeam.pressing, plan.pressing);
      expect(gs.userTeam.tempo, plan.tempo);
      expect(gs.userTeam.holdLeadLate, plan.holdLeadLate);
      expect(gs.userTeam.captainId, isNotNull);
      final captain =
          gs.userTeam.players.firstWhere((p) => p.id == gs.userTeam.captainId);
      expect(
          ManagerTactics.captaincyScore(captain),
          greaterThanOrEqualTo(gs.userTeam.players
              .where(ManagerTactics.canCaptain)
              .map(ManagerTactics.captaincyScore)
              .reduce((a, b) => a > b ? a : b)));
    });

    test('値の入った古いセーブを読め、次の節で監督の値に置き換わる', () async {
      final gs = GameState();
      await gs.startNewGame('戦い方FC');
      final json = gs.userTeam.toJson();
      json['pressing'] = 80;
      json['lineHeight'] = 20;
      json['width'] = 70;
      json['tempo'] = 30;
      json['tacticalStyle'] = 'longBall';
      json['timeWastingMode'] = true;
      json.remove('holdLeadLate');
      final old = Team.fromJson(json);
      expect(old.pressing, 80);
      expect(old.lineHeight, 20);
      expect(old.tacticalStyle, TacticalStyle.longBall);
      expect(old.timeWastingMode, isTrue);
      expect(old.holdLeadLate, isFalse);
      // 逃げ切りの考え方は保存して読み戻せる。
      old.holdLeadLate = true;
      expect(Team.fromJson(old.toJson()).holdLeadLate, isTrue);
    });
  });

  group('逃げ切り(リードした終盤)', () {
    test('逃げ切る考え方のチームは、試合のあと逃げ切りモードが残らない', () {
      for (var i = 0; i < 40; i++) {
        final home =
            PlayerGenerator.generateSquad(id: 'h', name: 'H', strengthTier: 75);
        final away =
            PlayerGenerator.generateSquad(id: 'a', name: 'A', strengthTier: 40);
        LineupUtils.autoFill(home);
        LineupUtils.autoFill(away);
        home.holdLeadLate = true;
        MatchEngine.simulate(home: home, away: away, matchday: 1);
        expect(home.timeWastingMode, isFalse);
      }
    });

    test('終盤の区間をリードして迎えたときだけ、その区間を逃げ切る', () {
      final home =
          PlayerGenerator.generateSquad(id: 'h', name: 'H', strengthTier: 60);
      final away =
          PlayerGenerator.generateSquad(id: 'a', name: 'A', strengthTier: 60);
      home.holdLeadLate = true;
      final homeGoal =
          MatchEvent(minute: 30, teamId: 'h', type: MatchEventType.goal);
      final awayGoal =
          MatchEvent(minute: 40, teamId: 'a', type: MatchEventType.goal);

      // リードして70分から: 逃げ切る。戻すと元どおり。
      var end = MatchEngine.beginLateHold(home, away, 70, [homeGoal]);
      expect(home.timeWastingMode, isTrue);
      expect(away.timeWastingMode, isFalse);
      end();
      expect(home.timeWastingMode, isFalse);

      // 後半の頭(46分)からは使わない。
      end = MatchEngine.beginLateHold(home, away, 46, [homeGoal]);
      expect(home.timeWastingMode, isFalse);
      end();

      // 同点・負けているときは使わない。
      end = MatchEngine.beginLateHold(home, away, 70, [homeGoal, awayGoal]);
      expect(home.timeWastingMode, isFalse);
      end();
      end = MatchEngine.beginLateHold(home, away, 70, [awayGoal]);
      expect(home.timeWastingMode, isFalse);
      end();

      // 逃げ切らない考え方なら、リードしていても使わない。
      home.holdLeadLate = false;
      end = MatchEngine.beginLateHold(home, away, 70, [homeGoal]);
      expect(home.timeWastingMode, isFalse);
      end();
    });
  });

  group('釣り合い', () {
    // 同じ戦力どうしで、考え方ごとの戦い方が勝率を極端に偏らせないか。
    // 相手は CPU の決め方(CpuTacticsAI)。測る数は環境変数で増やせる
    // (MT_BALANCE_N=3000 で表を作った)。
    final n = int.tryParse(Platform.environment['MT_BALANCE_N'] ?? '') ?? 800;

    test('同じ戦力の CPU 相手に、どの考え方も勝ち負けが大きく偏らない', () {
      final pool = [
        for (var i = 0; i < 12; i++)
          PlayerGenerator.generateSquad(
              id: 'p$i', name: 'P$i', strengthTier: 50 + i * 3)
            ..players.forEach((p) => p.fatigue = 0),
      ];
      for (final t in pool) {
        LineupUtils.autoFill(t);
      }
      final rows = <String>[];
      final bad = <String>[];
      final cpu = _measure(
          pool: pool,
          matches: n,
          setupA: (a, b) => _cpuSetup(a, b),
          setupB: (b, a) => _cpuSetup(b, a));
      rows.add('CPU同士 | ${_pct(cpu.win)} | ${_pct(cpu.draw)} | '
          '${_pct(cpu.loss)} | ${cpu.gf.toStringAsFixed(2)} | '
          '${cpu.ga.toStringAsFixed(2)}');
      for (final level in [4, 7]) {
        for (final style in ManagerStyle.values) {
          final r = _measure(
              pool: pool,
              matches: n,
              setupA: (a, b) => _managerSetup(a, b, style, level),
              setupB: (b, a) => _cpuSetup(b, a));
          rows.add('${style.name}(水準$level) | ${_pct(r.win)} | '
              '${_pct(r.draw)} | ${_pct(r.loss)} | '
              '${r.gf.toStringAsFixed(2)} | ${r.ga.toStringAsFixed(2)}');
          // 勝ちと負けの差が大きく開かない。3000試合で測った差は最大で
          // 攻撃的(水準7)の+12.5点。800試合の揺れ(標準誤差およそ3点)の
          // 3倍を見込んで、22点を超えたら偏りとみなす。
          if ((r.win - r.loss).abs() >= 0.22) {
            bad.add('$style 水準$level: 勝ち${_pct(r.win)} 負け${_pct(r.loss)}');
          }
        }
      }
      // ignore: avoid_print
      print('考え方 | 勝ち | 分け | 負け | 得点 | 失点\n${rows.join('\n')}');
      expect(bad, isEmpty);
    }, timeout: const Timeout(Duration(minutes: 10)));

    test('考え方どうしの対戦(同じ戦力)', () {
      final pool = [
        for (var i = 0; i < 12; i++)
          PlayerGenerator.generateSquad(
              id: 'p$i', name: 'P$i', strengthTier: 50 + i * 3),
      ];
      for (final t in pool) {
        LineupUtils.autoFill(t);
      }
      final rows = <String>[];
      final bad = <String>[];
      final styles = ManagerStyle.values;
      for (var i = 0; i < styles.length; i++) {
        for (var j = i + 1; j < styles.length; j++) {
          final r = _measure(
              pool: pool,
              matches: n,
              setupA: (a, b) => _managerSetup(a, b, styles[i], 4),
              setupB: (b, a) => _managerSetup(b, a, styles[j], 4));
          rows.add('${styles[i].name} 対 ${styles[j].name} | ${_pct(r.win)} | '
              '${_pct(r.draw)} | ${_pct(r.loss)} | '
              '${r.gf.toStringAsFixed(2)} | ${r.ga.toStringAsFixed(2)}');
          // 攻撃的と堅守は構えが2段違う(以前からの ManagerStyle.shift)ので、
          // 3000試合で+14点の差が出る。揺れを見込んで26点まで。
          if ((r.win - r.loss).abs() >= 0.26) {
            bad.add('${styles[i]} 対 ${styles[j]}');
          }
        }
      }
      // ignore: avoid_print
      print('対戦 | 勝ち | 分け | 負け | 得点 | 失点\n${rows.join('\n')}');
      expect(bad, isEmpty);
    }, timeout: const Timeout(Duration(minutes: 10)));
  });
}
