import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/appearance_fee_engine.dart';
import 'package:soccer_manager/logic/cup_engine.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/logic/lineup_utils.dart';
import 'package:soccer_manager/logic/match_engine.dart';
import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/models/match_result.dart';
import 'package:soccer_manager/models/opposition_plan.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/team.dart';

/// 品質改善の12回目(2026-11-23): 試合の記録の中の食い違い。
///
/// 試合の記録(MatchResult)を、出来事の順に「いまピッチにいる選手」を
/// 追いながら読み、つじつまの合わない所を数える。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
  });
  tearDown(() => Tr.language = AppLanguage.system);

  Team squad(String id, {int tier = 60}) {
    final t = PlayerGenerator.generateSquad(
      id: id,
      name: id,
      strengthTier: tier,
    );
    LineupUtils.autoFill(t);
    return t;
  }

  test('300試合: 記録に食い違いが無い(先発の欠けは控えが埋める・GK は1人)', () {
    final rng = Random(12);
    final problems = <String>[];
    final seen = <MatchEventType, int>{};
    for (var i = 0; i < 300; i++) {
      final home = squad('h$i', tier: 45 + rng.nextInt(40));
      final away = squad('a$i', tier: 45 + rng.nextInt(40));
      // 疲れた選手を混ぜて、交代が起きるようにする。
      for (final p in [...home.players, ...away.players]) {
        p.fatigue = rng.nextInt(80);
      }
      // 先発の何人かが怪我・代表・出場停止(先発の指定には残っている)。
      for (final t in [home, away]) {
        final xi = MatchEngine.lineupOf(t);
        for (var k = rng.nextInt(5); k > 0; k--) {
          final p = xi[rng.nextInt(xi.length)];
          switch (rng.nextInt(3)) {
            case 0:
              p.injuryWeeks = 2;
            case 1:
              p.internationalDutyWeeksRemaining = 1;
            default:
              p.suspendedMatches = 1;
          }
        }
      }
      final starters = {
        home.id: MatchEngine.lineupOf(home).map((p) => p.id).toSet(),
        away.id: MatchEngine.lineupOf(away).map((p) => p.id).toSet(),
      };
      for (final t in [home, away]) {
        if (starters[t.id]!.length != 11) {
          problems.add('${t.id}: 先発が${starters[t.id]!.length}人');
        }
        final gks = t.players.where(
            (p) => starters[t.id]!.contains(p.id) && p.position == Position.gk);
        if (gks.length != 1) problems.add('${t.id}: 先発の GK が${gks.length}人');
      }
      final r = MatchEngine.simulate(home: home, away: away, matchday: 1);
      problems.addAll(matchRecordProblems(r, home, away, starters));
      for (final e in r.events) {
        seen[e.type] = (seen[e.type] ?? 0) + 1;
      }
    }
    expect(problems.take(30).toList(), isEmpty);
    // 交代・退場・警告が実際に起きた記録を読んでいる。
    expect(seen[MatchEventType.substitution] ?? 0, greaterThan(300));
    expect(seen[MatchEventType.redCard] ?? 0, greaterThan(10));
  });

  test('延長: 得点・アシストは90分の終わりにピッチにいた選手だけ(枠内シュートにも足す)', () {
    final problems = <String>[];
    var et = 0;
    for (var i = 0; i < 400 && et < 120; i++) {
      final home = squad('h$i');
      final away = squad('a$i');
      for (final p in [...home.players, ...away.players]) {
        p.fatigue = 65;
      }
      final starters = {
        home.id: MatchEngine.lineupOf(home).map((p) => p.id).toSet(),
        away.id: MatchEngine.lineupOf(away).map((p) => p.id).toSet(),
      };
      final r = MatchEngine.simulate(home: home, away: away, matchday: 1);
      if (r.homeGoals != r.awayGoals) continue;
      et++;
      final after = CupEngine.extraTime(r, home, away);
      problems.addAll(matchRecordProblems(after, home, away, starters,
          checkRatings: false));
    }
    expect(problems.take(30).toList(), isEmpty);
  });

  test('30節: 自クラブの記録と、通算の出場・得点の増え方が合う', () async {
    final gs = GameState();
    await gs.startNewGame('十二回目FC');
    final problems = <String>[];
    final userId = gs.userTeam.id;
    List<MatchResult> cupResults() => [
          for (final c in [gs.leagueCup, gs.domesticCup])
            if (c != null)
              for (final round in c.rounds)
                for (final m in round)
                  if (m.homeTeamId == userId || m.awayTeamId == userId) ...[
                    if (m.firstLeg != null) m.firstLeg!,
                    if (m.result != null) m.result!,
                  ],
        ];
    for (var md = 0; md < 30; md++) {
      final before = {
        for (final p in gs.userTeam.players)
          p.id: (apps: p.careerAppearances, goals: p.careerGoals),
      };
      final cupsBefore = Set<MatchResult>.identity()..addAll(cupResults());
      final r = await gs.playNextMatchdayQuickSim();
      if (r == null) break;
      final newCup = [
        for (final c in cupResults())
          if (!cupsBefore.contains(c)) c,
      ];
      final home = gs.teamById(r.homeTeamId)!;
      final away = gs.teamById(r.awayTeamId)!;
      Set<String> startersOf(Team t) {
        final ids = {for (final p in t.players) p.id};
        final on = AppearanceFeeEngine.substitutesOn(r, t.id);
        return {
          for (final id in r.playerRatings.keys)
            if (ids.contains(id) && !on.contains(id)) id,
        };
      }

      problems.addAll(matchRecordProblems(r, home, away,
          {home.id: startersOf(home), away.id: startersOf(away)}));
      final user = home.id == userId ? home : away;
      for (final p in user.players) {
        final b = before[p.id];
        if (b == null) continue;
        final all = [r, ...newCup];
        final playedNow =
            all.where((x) => x.playerRatings.containsKey(p.id)).length;
        final goalsNow = [
          for (final x in all)
            for (final e in x.events)
              if (e.type == MatchEventType.goal && e.scorerId == p.id) e,
        ].length;
        if (p.careerAppearances - b.apps != playedNow) {
          problems.add('${r.matchday}節 ${p.name}: 出場の数が'
              '${p.careerAppearances - b.apps}増えた(記録では$playedNow)');
        }
        if (p.careerGoals - b.goals != goalsNow) {
          problems.add('${r.matchday}節 ${p.name}: 得点の数が'
              '${p.careerGoals - b.goals}増えた(記録では$goalsNow)');
        }
      }
    }
    expect(problems.take(30).toList(), isEmpty);
  });

  group('先発が11人そろわない節', () {
    test('出られない先発の枠に控えが入る(先発の指定は変えない)', () {
      final t = squad('lack');
      final xi = MatchEngine.lineupOf(t);
      final gk = xi.firstWhere((p) => p.position == Position.gk);
      final outfield = xi.firstWhere((p) => p.position != Position.gk);
      gk.injuryWeeks = 3;
      outfield.internationalDutyWeeksRemaining = 1;
      final before = List.of(t.startingXI);
      final lineup = MatchEngine.lineupOf(t);
      expect(lineup.length, 11, reason: '9人で試合をしている');
      expect(lineup.where((p) => p.position == Position.gk).length, 1,
          reason: 'GK のいないまま試合をしている');
      expect(lineup.map((p) => p.id), isNot(contains(gk.id)));
      expect(t.startingXI, before, reason: '先発の指定まで書き換えている');
      // 同じ状態なら何度呼んでも同じ顔ぶれ(試合の前と後で採点が合う)。
      expect(MatchEngine.lineupOf(t).map((p) => p.id), lineup.map((p) => p.id));
    });

    test('カップ戦の出場手当は、実際に出た選手に払う', () {
      final t = squad('fee');
      for (final p in t.players) {
        p.appearanceFee = 10;
      }
      final injured = MatchEngine.lineupOf(t).first..injuryWeeks = 2;
      final opp = squad('opp');
      final r = MatchEngine.simulate(home: t, away: opp, matchday: 0);
      final ids = {for (final p in t.players) p.id};
      final played = {
        for (final id in r.playerRatings.keys)
          if (ids.contains(id)) id,
      };
      final on = AppearanceFeeEngine.substitutesOn(r, t.id);
      expect(played, isNot(contains(injured.id)));
      expect(AppearanceFeeEngine.feesFor(t, r),
          (played.length - on.length) * 10 + on.length * 5);
    });
  });

  group('試合中の交代', () {
    /// 後半(46分〜)の進行中の状態。自クラブ(ホーム)の判断待ちで止まる。
    ({Team home, Team away, InteractiveHalfState s}) secondHalf(int i) {
      final home = squad('lh$i');
      final away = squad('la$i');
      MatchEngine.resetMatchCards(home, away);
      final s = MatchEngine.beginInteractiveHalf(
        home: home,
        away: away,
        startMinute: 46,
        endMinute: 90,
        interactiveTeamId: home.id,
      );
      return (home: home, away: away, s: s);
    }

    Player benchOf(Team t, InteractiveHalfState s) {
      final on = {for (final p in s.homeLineup) p.id};
      return t.players.firstWhere((p) =>
          !on.contains(p.id) && p.position != Position.gk && !p.isInjured);
    }

    Set<String?> involvedIn(InteractiveHalfState s) => {
          s.pending?.shooter?.id,
          s.pending?.passTarget?.id,
          s.pending?.defender?.id,
          s.pending?.keeper?.id,
          s.pending?.attacker?.id,
        };

    test('交代のあとも、対策指示の攻守力が残る', () {
      for (var i = 0; i < 50; i++) {
        final home = squad('ph$i');
        final away = squad('pa$i');
        home.oppositionPlan = OppositionPlan.stayCompact;
        away.oppositionPlan = OppositionPlan.pressPlaymaker;
        final s = MatchEngine.beginInteractiveHalf(
          home: home,
          away: away,
          startMinute: 46,
          endMinute: 90,
          interactiveTeamId: home.id,
        );
        if (s.isFinished) continue;
        final involved = involvedIn(s);
        final out = s.homeLineup.firstWhere(
            (p) => p.position != Position.gk && !involved.contains(p.id));
        final incoming = benchOf(home, s);
        expect(
            MatchEngine.applyInteractiveSubstitution(s,
                teamId: home.id, outPlayerId: out.id, inPlayerId: incoming.id),
            isTrue);
        // 交代のあとの顔ぶれで区間を始め直したときと同じ攻守力になる。
        home.startingXI = [for (final p in s.homeLineup) p.id];
        final fresh = MatchEngine.beginInteractiveHalf(
          home: home,
          away: away,
          startMinute: 46,
          endMinute: 90,
          interactiveTeamId: 'nobody',
        );
        expect(s.homeAttackBase, closeTo(fresh.homeAttackBase, 1e-9));
        expect(s.awayAttackBase, closeTo(fresh.awayAttackBase, 1e-9));
        expect(s.homeDefenseBase, closeTo(fresh.homeDefenseBase, 1e-9));
        expect(s.awayDefenseBase, closeTo(fresh.awayDefenseBase, 1e-9));
        return;
      }
      fail('判断待ちの後半を作れなかった');
    });

    test('下がった選手に、この先の警告・退場が付かない', () {
      var checked = 0;
      for (var i = 0; i < 400 && checked < 20; i++) {
        final m = secondHalf(i);
        final s = m.s;
        if (s.isFinished) continue;
        final now = MatchEngine.currentMinuteOf(s);
        final involved = involvedIn(s);
        final later = s.events
            .where((e) =>
                e.teamId == m.home.id &&
                (e.type == MatchEventType.yellowCard ||
                    e.type == MatchEventType.redCard) &&
                e.minute > now &&
                !involved.contains(e.scorerId))
            .firstOrNull;
        if (later == null) continue;
        final outId = later.scorerId!;
        expect(
            MatchEngine.applyInteractiveSubstitution(s,
                teamId: m.home.id,
                outPlayerId: outId,
                inPlayerId: benchOf(m.home, s).id),
            isTrue,
            reason: 'まだ来ていない退場で、交代を断っている');
        checked++;
        expect(
            s.events.where((e) =>
                e.scorerId == outId &&
                e.minute > now &&
                (e.type == MatchEventType.yellowCard ||
                    e.type == MatchEventType.redCard)),
            isEmpty,
            reason: 'ベンチに下がった選手が警告・退場を受ける');
        final homeReds = s.events.where(
            (e) => e.type == MatchEventType.redCard && e.teamId == m.home.id);
        if (homeReds.isEmpty) {
          expect(s.homeRedMinute, isNull, reason: '11人のまま数的不利');
        }
      }
      expect(checked, greaterThan(5));
    });

    test('一度下がった選手は、もう一度は入れない', () {
      for (var i = 0; i < 50; i++) {
        final m = secondHalf(100 + i);
        final s = m.s;
        if (s.isFinished) continue;
        final involved = involvedIn(s);
        final out = s.homeLineup.firstWhere(
            (p) => p.position != Position.gk && !involved.contains(p.id));
        final incoming = benchOf(m.home, s);
        expect(
            MatchEngine.applyInteractiveSubstitution(s,
                teamId: m.home.id,
                outPlayerId: out.id,
                inPlayerId: incoming.id),
            isTrue);
        s.events.add(MatchEngine.substitutionEvent(
            minute: MatchEngine.currentMinuteOf(s),
            teamId: m.home.id,
            out: out,
            incoming: incoming));
        expect(
            MatchEngine.applyInteractiveSubstitution(s,
                teamId: m.home.id,
                outPlayerId: incoming.id,
                inPlayerId: out.id),
            isFalse,
            reason: '下げた選手をもう一度入れられる');
        return;
      }
      fail('判断待ちの後半を作れなかった');
    });

    test('積極的なタックルの2枚目は、この分までに受けた警告で決まる', () {
      var yellowNow = 0;
      var tries = 0;
      for (var i = 0; i < 800 && yellowNow < 5; i++) {
        final m = secondHalf(200 + i);
        final s = m.s;
        if (s.isFinished || s.pending == null) continue;
        final minute = s.pending!.minute;
        if (minute > 80) continue;
        // 相手(アウェイ)の攻撃を、ホームの守備者が積極的に止めにいく。
        final defender = s.homeLineup.firstWhere((p) =>
            p.position != Position.gk &&
            !s.events.any((e) => e.scorerId == p.id));
        final attacker =
            s.awayLineup.firstWhere((p) => p.position != Position.gk);
        // 85分に受ける予定の警告(区間の始めに決まり、印は立っている)。
        s.events.add(MatchEvent(
          minute: 85,
          teamId: m.home.id,
          scorerName: defender.name,
          scorerId: defender.id,
          type: MatchEventType.yellowCard,
        ));
        defender.yellowCardedThisMatch = true;
        s.pending = PendingChanceDecision.defense(
          minute: minute,
          attacker: attacker,
          aggressiveChanceAgainst: 0,
          safeChanceAgainst: 0,
          defender: defender,
        );
        s.pendingIsHomeChance = false;
        MatchEngine.resolvePendingChance(s, ChanceDecision.aggressiveTackle);
        final cards = s.events
            .where((e) =>
                e.scorerId == defender.id &&
                (e.type == MatchEventType.yellowCard ||
                    e.type == MatchEventType.redCard))
            .toList();
        final atMinute = cards.where((e) => e.minute == minute).toList();
        if (atMinute.isEmpty) continue;
        tries++;
        final later = [
          for (final e in cards)
            if (e.minute > minute) e.type,
        ];
        if (atMinute.single.type == MatchEventType.yellowCard) {
          yellowNow++;
          // 85分の警告は2枚目なので退場になる。
          expect(later, [MatchEventType.redCard]);
        } else {
          // 退場したら、その先のカードは無い。
          expect(later, isEmpty);
        }
      }
      expect(yellowNow, greaterThan(0),
          reason: 'まだ受けていない警告で、いつも2枚目の退場になる($tries回)');
    });
  });

  test('同じ分の出来事は、入っていた順のまま並べる', () {
    final events = [
      for (var i = 0; i < 60; i++)
        MatchEvent(
          minute: 46 + (i % 3),
          teamId: 't',
          scorerId: 'p$i',
          type: MatchEventType.chance,
        ),
    ];
    final sorted = MatchEngine.sortedByMinute(events.reversed.toList());
    for (var i = 1; i < sorted.length; i++) {
      final a = sorted[i - 1];
      final b = sorted[i];
      expect(a.minute, lessThanOrEqualTo(b.minute));
      if (a.minute == b.minute) {
        expect(int.parse(a.scorerId!.substring(1)),
            greaterThan(int.parse(b.scorerId!.substring(1))));
      }
    }
  });

  test('ハーフタイムの交代: ピッチにいない・出られない・下げた選手では替えられず、下げた選手も数える', () async {
    final gs = GameState();
    await gs.startNewGame('十二回目HT');
    final first = await gs.playNextMatchday();
    expect(first, isNotNull);
    expect(gs.isHalfTime, isTrue);
    final team = gs.userTeam;
    final onPitch = MatchEngine.lineupOf(team);
    final bench = team.players
        .where((p) =>
            !onPitch.contains(p) &&
            p.position != Position.gk &&
            !p.isInjured &&
            !p.isSuspended &&
            !p.isOnInternationalDuty &&
            !p.isLoanedOut &&
            !p.notRegistered)
        .toList();
    final used = gs.substitutionsUsed;
    // ピッチにいない選手を下げる(先発が12人になっていた)。
    expect(
        gs.makeHalfTimeSubstitution(
            outPlayerId: bench[0].id, inPlayerId: bench[1].id),
        isFalse);
    // 怪我人を入れる。
    bench[2].injuryWeeks = 3;
    final out = onPitch.firstWhere((p) =>
        p.position != Position.gk &&
        !MatchEngine.sentOffIds(gs.liveFirstHalfEventsSoFar).contains(p.id));
    expect(
        gs.makeHalfTimeSubstitution(
            outPlayerId: out.id, inPlayerId: bench[2].id),
        isFalse);
    expect(gs.substitutionsUsed, used, reason: '断ったのに枠が減った');
    // 正しい交代。
    expect(
        gs.makeHalfTimeSubstitution(
            outPlayerId: out.id, inPlayerId: bench[3].id),
        isTrue);
    // 下げた選手をもう一度入れる。
    expect(
        gs.makeHalfTimeSubstitution(
            outPlayerId: bench[3].id, inPlayerId: out.id),
        isFalse);
    expect(MatchEngine.lineupOf(team).length, 11);

    final appsBefore = out.careerAppearances;
    final r = await gs.playSecondHalf();
    expect(r, isNotNull);
    // 前半を戦って下がった選手にも採点・出場がある。
    expect(r!.playerRatings.containsKey(out.id), isTrue,
        reason: 'ハーフタイムに下げた選手の採点が無い');
    expect(out.careerAppearances, appsBefore + 1);
    expect(gs.seasonStatsFor(out.id).appearances, 1);
  });
}

/// [r]の記録の食い違い(人が読める文)。[starters]はチームごとの、
/// 試合の始まりにピッチにいた選手。
List<String> matchRecordProblems(
  MatchResult r,
  Team home,
  Team away,
  Map<String, Set<String>> starters, {
  bool checkRatings = true,
}) {
  final out = <String>[];
  final teams = {home.id: home, away.id: away};
  final roster = {
    for (final t in [home, away]) t.id: {for (final p in t.players) p.id},
  };
  final onPitch = {
    for (final e in starters.entries) e.key: {...e.value},
  };
  final played = {
    for (final e in starters.entries) e.key: {...e.value},
  };
  final sentOff = <String>{};
  final booked = <String>{};
  final subsUsed = {home.id: 0, away.id: 0};
  final windows = {home.id: <int>{}, away.id: <int>{}};
  final goals = {home.id: 0, away.id: 0};
  final reds = {home.id: 0, away.id: 0};

  var lastMinute = 0;
  final events = r.events;
  for (var i = 0; i < events.length; i++) {
    final e = events[i];
    final tag = '${r.homeTeamId}-${r.awayTeamId} ${e.minute}分 ${e.type.name}';
    if (e.minute < lastMinute) out.add('$tag: 分の順に並んでいない');
    lastMinute = e.minute;
    final team = teams[e.teamId];
    if (team == null) {
      out.add('$tag: どちらのチームでもない');
      continue;
    }
    final pitch = onPitch[e.teamId]!;
    // 記録の並び(画面の実況の順)どおりに追う。同じ分の交代と出来事も、
    // 並んだ順に起きたものとして読む。
    bool there(String? id) =>
        id == null || (!sentOff.contains(id) && pitch.contains(id));
    switch (e.type) {
      case MatchEventType.goal:
        goals[e.teamId] = goals[e.teamId]! + 1;
        if (e.scorerId != null && !roster[e.teamId]!.contains(e.scorerId)) {
          out.add('$tag: 得点者が別のチームの選手');
        }
        if (!there(e.scorerId)) out.add('$tag: 得点者がピッチにいない');
        if (!there(e.assistId)) out.add('$tag: アシストがピッチにいない');
        if (e.assistId != null && e.assistId == e.scorerId) {
          out.add('$tag: 自分にアシスト');
        }
      case MatchEventType.chance:
        if (!there(e.scorerId)) out.add('$tag: シュートした選手がピッチにいない');
      case MatchEventType.yellowCard:
        if (!there(e.scorerId)) out.add('$tag: 警告の選手がピッチにいない');
        if (booked.contains(e.scorerId)) out.add('$tag: 同じ選手に2枚目の警告');
        booked.add(e.scorerId!);
      case MatchEventType.redCard:
        if (!there(e.scorerId)) out.add('$tag: 退場の選手がピッチにいない');
        sentOff.add(e.scorerId!);
        pitch.remove(e.scorerId);
        reds[e.teamId] = reds[e.teamId]! + 1;
      case MatchEventType.substitution:
        final inId = e.scorerId;
        final outId = e.assistId;
        subsUsed[e.teamId] = subsUsed[e.teamId]! + 1;
        if (e.minute != 46) windows[e.teamId]!.add(e.minute);
        if (outId == null || !pitch.contains(outId)) {
          out.add('$tag: 下がる選手がピッチにいない');
        }
        if (sentOff.contains(outId)) out.add('$tag: 退場した選手を交代で下げた');
        if (inId == null || !roster[e.teamId]!.contains(inId)) {
          out.add('$tag: 入る選手が名簿にいない');
        } else if (played[e.teamId]!.contains(inId)) {
          out.add('$tag: 一度出た選手がもう一度入った');
        }
        pitch.remove(outId);
        if (inId != null) {
          pitch.add(inId);
          played[e.teamId]!.add(inId);
        }
    }
    final expected = starters[e.teamId]!.length - reds[e.teamId]!;
    if (pitch.length != expected) {
      out.add('$tag: ピッチの人数が${pitch.length}人(本来$expected人)');
    }
  }
  for (final id in [home.id, away.id]) {
    if (subsUsed[id]! > substitutionsPerMatch) {
      out.add('$id: 交代が${subsUsed[id]}人');
    }
    if (windows[id]!.length > substitutionWindowsPerMatch) {
      out.add('$id: 交代の回数が${windows[id]!.length}回');
    }
  }
  if (goals[r.homeTeamId] != r.homeGoals ||
      goals[r.awayTeamId] != r.awayGoals) {
    out.add('${r.homeTeamId}: 得点の出来事(${goals[r.homeTeamId]}-'
        '${goals[r.awayTeamId]})と結果(${r.homeGoals}-${r.awayGoals})が違う');
  }
  if ((r.homeShotsOnTarget ?? r.homeGoals) < r.homeGoals ||
      (r.awayShotsOnTarget ?? r.awayGoals) < r.awayGoals) {
    out.add('${r.homeTeamId}: 枠内シュートが得点より少ない');
  }
  if (checkRatings && r.playerRatings.isNotEmpty) {
    final everyone = {...played[home.id]!, ...played[away.id]!};
    final rated = r.playerRatings.keys.toSet();
    final missing = everyone.difference(rated);
    final extra = rated.difference(everyone);
    if (missing.isNotEmpty) {
      out.add('${r.homeTeamId}: 出たのに採点が無い ${missing.length}人');
    }
    if (extra.isNotEmpty) {
      out.add('${r.homeTeamId}: 出ていないのに採点がある ${extra.length}人');
    }
  }
  return out;
}
