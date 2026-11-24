import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/logic/injury_care.dart';
import 'package:soccer_manager/logic/lineup_utils.dart';
import 'package:soccer_manager/logic/match_engine.dart';
import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/logic/season_calendar.dart';
import 'package:soccer_manager/models/attributes.dart';
import 'package:soccer_manager/models/league_theme.dart';
import 'package:soccer_manager/models/match_result.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/team.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 試合まわりを実際のサッカーに近づけた変更(2026-11-22)の挙動を固定する。
/// 1. 前半の退場は後半も続く  2. 交代は5人・3回まで  3. 長期の怪我
/// 4. 代表は国際マッチウィークに全クラブから  5. カード・PK・直接FKの数
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Team squad(String id, {int tier = 60}) {
    final t =
        PlayerGenerator.generateSquad(id: id, name: id, strengthTier: tier);
    LineupUtils.autoFill(t);
    return t;
  }

  bool canPlay(Player p) =>
      !p.isInjured &&
      !p.isSuspended &&
      !p.isOnInternationalDuty &&
      !p.isLoanedOut &&
      !p.notRegistered;

  MatchEvent red(Team t, Player p, int minute) => MatchEvent(
        minute: minute,
        teamId: t.id,
        scorerName: p.name,
        scorerId: p.id,
        type: MatchEventType.redCard,
      );

  bool involves(MatchEvent e, String id) =>
      e.scorerId == id || e.assistId == id;

  group('1. 前半に退場した選手は後半に出ず、数的不利も続く', () {
    test('後半(simulateMinutes)に、前半に退場した選手が出てこない', () {
      final home = squad('h');
      final away = squad('a');
      final sentOff = MatchEngine.lineupOf(home)
          .firstWhere((p) => p.position.group == PositionGroup.att);
      for (var i = 0; i < 200; i++) {
        final half = MatchEngine.simulateMinutes(
          home: home,
          away: away,
          startMinute: 46,
          endMinute: 90,
          priorEvents: [red(home, sentOff, 30)],
        );
        expect(half.events.where((e) => involves(e, sentOff.id)), isEmpty,
            reason: '前半に退場した選手が後半に得点・カードに絡んだ');
      }
    });

    test('後半も数的不利のまま(ボールを持てる割合が下がる)', () {
      final home = squad('h');
      final away = squad('a');
      final sentOff = MatchEngine.lineupOf(home)
          .firstWhere((p) => p.position.group == PositionGroup.mid);
      double share({required bool withRed}) {
        var sum = 0.0;
        var n = 0;
        for (var i = 0; i < 300; i++) {
          final half = MatchEngine.simulateMinutes(
            home: home,
            away: away,
            startMinute: 46,
            endMinute: 90,
            priorEvents: withRed ? [red(home, sentOff, 20)] : const [],
          );
          // 後半に退場が出た試合は比べない(前半の退場の効き目だけを見る)。
          if (half.events.any((e) => e.type == MatchEventType.redCard)) {
            continue;
          }
          sum += half.possessionShareSum;
          n += half.chanceCount;
        }
        return sum / n;
      }

      final normal = share(withRed: false);
      final down = share(withRed: true);
      expect(down, lessThan(normal - 0.01),
          reason: '前半に退場したのに後半は11人のように戦っている '
              '(${normal.toStringAsFixed(3)} → ${down.toStringAsFixed(3)})');
    });

    test('CPU 同士の試合(simulate)で、退場した選手はその後に何もしない', () {
      var firstHalfReds = 0;
      for (var i = 0; i < 400; i++) {
        final r = MatchEngine.simulate(
            home: squad('h$i'), away: squad('a$i'), matchday: 1);
        for (final e in r.events) {
          if (e.type != MatchEventType.redCard) continue;
          if (e.minute <= 45) firstHalfReds++;
          final after = r.events
              .where((x) => x.minute > e.minute && involves(x, e.scorerId!));
          expect(after, isEmpty, reason: '${e.minute}分に退場した選手が、その後も試合に絡んだ');
        }
      }
      expect(firstHalfReds, greaterThan(0), reason: '前半の退場が1件も無く確かめられない');
    });

    test('ライブ観戦の後半も、前半に退場した選手を出さない', () {
      final home = squad('h');
      final away = squad('a');
      final sentOff = MatchEngine.lineupOf(home)
          .firstWhere((p) => p.position.group == PositionGroup.def);
      final state = MatchEngine.beginInteractiveHalf(
        home: home,
        away: away,
        startMinute: 46,
        endMinute: 90,
        interactiveTeamId: home.id,
        priorEvents: [red(home, sentOff, 40)],
      );
      expect(state.homeLineup.map((p) => p.id), isNot(contains(sentOff.id)));
      expect(state.homeRedMinute, isNotNull, reason: '後半の始めから数的不利になっていない');
    });

    test('試合中・ハーフタイムに、退場した選手を下げて11人に戻せない', () async {
      final home = squad('h');
      final away = squad('a');
      final state = MatchEngine.beginInteractiveHalf(
        home: home,
        away: away,
        startMinute: 1,
        endMinute: 45,
        interactiveTeamId: home.id,
      );
      if (!state.isFinished) {
        final pending = state.pending;
        final involved = {
          pending?.shooter?.id,
          pending?.passTarget?.id,
          pending?.keeper?.id,
          pending?.attacker?.id,
          pending?.defender?.id,
        };
        // 前半の中で本当に退場した選手は外す。外さないと、乱数でその選手を
        // 引いた回に「下げられる」はずの交代が断られて落ちていた(2026-11-24 CI)。
        final alreadyOff = MatchEngine.sentOffIds(state.events);
        final free = state.homeLineup
            .where((p) =>
                p.position != Position.gk &&
                !involved.contains(p.id) &&
                !alreadyOff.contains(p.id))
            .toList();
        final onPitch = state.homeLineup.map((p) => p.id).toSet();
        final bench = home.players
            .where((p) => !onPitch.contains(p.id) && canPlay(p))
            .toList();
        state.events.add(red(home, free[0], 1));
        expect(
            MatchEngine.applyInteractiveSubstitution(state,
                teamId: home.id,
                outPlayerId: free[0].id,
                inPlayerId: bench[0].id),
            isFalse,
            reason: '退場した選手を交代で下げられた');
        expect(
            MatchEngine.applyInteractiveSubstitution(state,
                teamId: home.id,
                outPlayerId: free[1].id,
                inPlayerId: bench[0].id),
            isTrue);
      }

      final game = GameState();
      await game.startNewGame('退場FC');
      await game.playNextMatchday();
      expect(game.isHalfTime, isTrue);
      final team = game.userTeam;
      final lineup = MatchEngine.lineupOf(team);
      final onPitch = lineup.map((p) => p.id).toSet();
      final bench =
          team.players.where((p) => !onPitch.contains(p.id) && canPlay(p));
      final outs = lineup.where((p) => p.position != Position.gk).toList();
      game.liveFirstHalfEventsSoFar.add(red(team, outs[0], 30));
      expect(
          game.makeHalfTimeSubstitution(
              outPlayerId: outs[0].id, inPlayerId: bench.first.id),
          isFalse,
          reason: 'ハーフタイムに退場した選手を下げられた');
      expect(
          game.makeHalfTimeSubstitution(
              outPlayerId: outs[1].id, inPlayerId: bench.first.id),
          isTrue);
    });
  });

  group('2. 交代は5人まで、ハーフタイム以外は3回まで', () {
    test('決まりの数: 5人・3回。手動と自動で同じ', () {
      expect(substitutionsPerMatch, 5);
      expect(substitutionWindowsPerMatch, 3);
      expect(GameState.maxSubstitutionsPerMatch, substitutionsPerMatch);
      expect(GameState.maxSubstitutionWindowsPerMatch,
          substitutionWindowsPerMatch);
    });

    test('疲れた選手が多ければ、ハーフタイムに5人まで替える', () {
      final t = squad('h');
      final lineup = MatchEngine.lineupOf(t);
      final onPitch = lineup.map((p) => p.id).toSet();
      for (final p in lineup) {
        p.fatigue = 100;
      }
      for (final b in t.players.where((p) => !onPitch.contains(p.id))) {
        b.attributes = {for (final k in AttributeKeys.all) k: 99};
        b.fatigue = 0;
      }
      final swaps =
          MatchEngine.chooseHalfTimeSubstitutions(t, lineup, goalDiff: 0);
      expect(swaps.length, greaterThan(3), reason: '3人で止まっている');
      expect(swaps.length, lessThanOrEqualTo(5));
    });

    test('後半の途中の交代は、ハーフタイムより低い疲れで替え、下がった選手は戻さない', () {
      final t = squad('h');
      final lineup = MatchEngine.lineupOf(t);
      for (final p in lineup) {
        p.fatigue = 0;
      }
      final tired = lineup.firstWhere((p) => p.position != Position.gk);
      tired.fatigue = 55;
      final onPitch = lineup.map((p) => p.id).toSet();
      final benchSame = t.players
          .where((p) => !onPitch.contains(p.id) && canPlay(p))
          .take(2)
          .toList();
      for (final b in benchSame) {
        b.position = tired.position;
        b.secondaryPositions = [];
        b.attributes = {for (final k in AttributeKeys.all) k: 99};
        b.fatigue = 0;
      }
      expect(MatchEngine.chooseHalfTimeSubstitutions(t, lineup, goalDiff: 0),
          isEmpty,
          reason: 'ハーフタイムの線(60)より下なのに替えた');
      final late = MatchEngine.chooseHalfTimeSubstitutions(
        t,
        lineup,
        goalDiff: 0,
        tiredFatigue: MatchEngine.lateAutoSubTiredFatigue,
        excludedIds: {benchSame[0].id}, // ハーフタイムに下がった選手
      );
      expect(late, hasLength(1));
      expect(late.single.out.id, tired.id);
      expect(late.single.incoming.id, benchSame[1].id,
          reason: '一度下がった選手をもう一度入れた');
    });

    test('後半の途中の交代は60〜75分', () {
      for (var i = 0; i < 200; i++) {
        expect(MatchEngine.rollLateSubMinute(), inInclusiveRange(60, 75));
      }
    });

    test('CPU 同士の試合で1チーム5人まで替わり、先発の指定は元に戻る', () {
      var maxSubs = 0;
      for (var i = 0; i < 60; i++) {
        final home = squad('h$i');
        final away = squad('a$i');
        for (final p in MatchEngine.lineupOf(home)) {
          p.fatigue = 90;
        }
        final xi = List<String>.of(home.startingXI);
        final before = {
          for (final p in home.players) p.id: p.careerAppearances
        };
        MatchEngine.simulate(home: home, away: away, matchday: 1);
        final played = home.players
            .where((p) => p.careerAppearances > before[p.id]!)
            .length;
        expect(played, lessThanOrEqualTo(11 + substitutionsPerMatch),
            reason: '交代が5人を超えた');
        maxSubs = played - 11 > maxSubs ? played - 11 : maxSubs;
        expect(home.startingXI, xi);
      }
      expect(maxSubs, greaterThan(3), reason: '4人目以降の交代が一度も無い');
    });

    Future<GameState> liveGame() async {
      final game = GameState();
      await game.startNewGame('交代FC');
      await game.playNextMatchday(interactive: true);
      return game;
    }

    /// 自クラブの誰か(GK 以外)と控えの誰かを、いまの場面で入れ替える。
    bool trySub(GameState game, {bool halfTime = false}) {
      final team = game.userTeam;
      final lineup = MatchEngine.lineupOf(team);
      final onPitch = lineup.map((p) => p.id).toSet();
      final bench =
          team.players.where((p) => !onPitch.contains(p.id) && canPlay(p));
      for (final out in lineup.where((p) => p.position != Position.gk)) {
        for (final incoming in bench) {
          final ok = halfTime
              ? game.makeHalfTimeSubstitution(
                  outPlayerId: out.id, inPlayerId: incoming.id)
              : game.makeLiveSubstitution(
                  outPlayerId: out.id, inPlayerId: incoming.id);
          if (ok) return true;
        }
      }
      return false;
    }

    /// 次の判断待ちの場面まで進める。試合が終わったら false。
    Future<bool> nextMoment(GameState game) async {
      await game.resolveChanceDecision(ChanceDecision.shoot);
      while (game.pendingChanceDecision == null) {
        if (game.isHalfTime) {
          await game.playSecondHalf(interactive: true);
          continue;
        }
        return false; // 試合が終わった
      }
      return true;
    }

    test('ライブ観戦: 同じ場面の交代は1回と数え、4回目の場面では替えられない', () async {
      GameState? game;
      var tries = 0;
      // 判断の場面が4つ以上ある試合を使う(ほとんどの試合で足りる)。
      while (tries++ < 3) {
        game = await liveGame();
        if (game.pendingChanceDecision == null) continue;
        expect(trySub(game), isTrue);
        expect(trySub(game), isTrue, reason: '同じ場面の2人目が替えられない');
        expect(game.substitutionWindowsUsed, 1, reason: '同じ場面の交代を2回と数えた');
        if (!await nextMoment(game)) continue;
        expect(trySub(game), isTrue);
        if (!await nextMoment(game)) continue;
        expect(trySub(game), isTrue);
        expect(game.substitutionsUsed, 4);
        expect(game.substitutionWindowsUsed, 3);
        if (!await nextMoment(game)) continue;
        expect(game.canMakeSubstitution, isTrue, reason: '枠(人数)はまだ1人ある');
        expect(game.canMakeLiveSubstitution, isFalse);
        expect(trySub(game), isFalse, reason: '4回目の場面で替えられた');
        expect(game.substitutionsRemaining, 1);
        expect(game.substitutionsLeftLabel, contains('1'));
        return;
      }
      fail('判断の場面が4つある試合が無かった');
    });

    test('ハーフタイムの交代は回数に数えず、5人を超えては替えられない', () async {
      final game = GameState();
      await game.startNewGame('交代FC');
      await game.playNextMatchday(interactive: true);
      while (game.pendingChanceDecision != null && !game.isHalfTime) {
        await game.resolveChanceDecision(ChanceDecision.shoot);
      }
      expect(game.isHalfTime, isTrue);
      for (var i = 0; i < 4; i++) {
        expect(trySub(game, halfTime: true), isTrue);
      }
      expect(game.substitutionWindowsUsed, 0, reason: 'ハーフタイムの交代を回数に数えた');
      expect(trySub(game, halfTime: true), isTrue);
      expect(game.substitutionsUsed, 5);
      expect(trySub(game, halfTime: true), isFalse, reason: '6人目が替えられた');
    });

    test('結果だけ見る自クラブの試合も、後半の途中に自動で交代する', () async {
      // 替える選手が試合の中で退場すると替えられない(退場した選手の交代は
      // 無い)。そうなった試合は数えず、やり直す。
      for (var tries = 0; tries < 5; tries++) {
        final game = GameState();
        await game.startNewGame('交代FC');
        await game.playNextMatchday();
        expect(game.isHalfTime, isTrue);
        final team = game.userTeam;
        final lineup = MatchEngine.lineupOf(team);
        final onPitch = lineup.map((p) => p.id).toSet();
        for (final p in team.players) {
          p.fatigue = 0;
        }
        // ハーフタイムの線(60)には届かないが、後半の途中の線(50)は越える。
        final tired = lineup.firstWhere((p) => p.position != Position.gk);
        tired.fatigue = 55;
        final bench = team.players
            .firstWhere((p) => !onPitch.contains(p.id) && canPlay(p));
        bench.position = tired.position;
        bench.secondaryPositions = [];
        bench.attributes = {for (final k in AttributeKeys.all) k: 99};
        final benchApps = bench.careerAppearances;
        final xi = List<String>.of(team.startingXI);

        final result = await game.playSecondHalf();

        expect(result, isNotNull);
        if (result!.events.any((e) =>
            e.type == MatchEventType.redCard && e.scorerId == tired.id)) {
          continue;
        }
        expect(bench.careerAppearances, benchApps + 1,
            reason: '後半の途中に控えが入っていない');
        expect(team.startingXI, xi);
        return;
      }
      fail('替える選手が退場しない試合が無かった');
    });

    test('ハーフタイムと後半の途中の両方で替えても、試合後の先発は元どおり', () async {
      // 替える2人が試合の中で退場すると替えられない(退場した選手の交代は
      // 無い)。そうなった試合は数えず、やり直す。
      for (var tries = 0; tries < 5; tries++) {
        final game = GameState();
        await game.startNewGame('交代FC');
        await game.playNextMatchday();
        expect(game.isHalfTime, isTrue);
        final team = game.userTeam;
        final lineup = MatchEngine.lineupOf(team);
        final onPitch = lineup.map((p) => p.id).toSet();
        for (final p in team.players) {
          p.fatigue = 0;
        }
        final htOut =
            lineup.firstWhere((p) => p.position.group == PositionGroup.def);
        final lateOut =
            lineup.firstWhere((p) => p.position.group == PositionGroup.att);
        htOut.fatigue = 95; // ハーフタイムに替わる
        lateOut.fatigue = 55; // 後半の途中に替わる
        final benches = team.players
            .where((p) => !onPitch.contains(p.id) && canPlay(p))
            .take(2)
            .toList();
        for (final (b, like) in [(benches[0], htOut), (benches[1], lateOut)]) {
          b.position = like.position;
          b.secondaryPositions = [];
          b.attributes = {for (final k in AttributeKeys.all) k: 99};
        }
        final apps = [for (final b in benches) b.careerAppearances];
        final xi = List<String>.of(team.startingXI);

        final result = await game.playSecondHalf();

        expect(result, isNotNull);
        if (result!.events.any((e) =>
            e.type == MatchEventType.redCard &&
            (e.scorerId == htOut.id || e.scorerId == lateOut.id))) {
          continue;
        }
        expect(benches[0].careerAppearances, apps[0] + 1);
        expect(benches[1].careerAppearances, apps[1] + 1);
        expect(team.startingXI, xi, reason: '自動の交代が先発の指定に残った');
        return;
      }
      fail('替える選手が退場しない試合が無かった');
    });
  });

  group('3. 長期の怪我', () {
    test('骨折・前十字靭帯・アキレス腱は2か月〜9か月', () {
      expect(InjuryType.fracture.durationRange, (8, 13));
      expect(InjuryType.acl.durationRange, (26, 39));
      expect(InjuryType.achilles.durationRange, (26, 39));
      for (final t in InjuryType.values) {
        expect(t.isLongTerm, t.durationRange.$1 >= 8, reason: t.name);
        expect(t.label, isNotEmpty);
      }
    });

    test('保存して読み直しても怪我の種類が残る', () {
      final p =
          PlayerGenerator.generate(position: Position.st, strengthTier: 60)
            ..injuryType = InjuryType.acl
            ..injuryWeeks = 30;
      final back = Player.fromJson(p.toJson());
      expect(back.injuryType, InjuryType.acl);
      expect(back.injuryWeeks, 30);
    });

    test('長期の怪我はまれ: 1季に1クラブ0〜2人ほど', () {
      // 1季38節を、毎節1週ずつ治しながら戦う(実測 約0.6人/1クラブ1季)。
      const seasons = 10;
      var longTerm = 0;
      var allInjuries = 0;
      for (var season = 0; season < seasons; season++) {
        final home = squad('h$season');
        final away = squad('a$season');
        int count(bool Function(InjuryType) f) => [
              for (final t in [home, away])
                for (final p in t.players)
                  for (final e in p.injuryHistoryCounts.entries)
                    if (f(InjuryType.values.byName(e.key))) e.value,
            ].fold(0, (a, b) => a + b);
        final longBefore = count((t) => t.isLongTerm);
        final allBefore = count((_) => true);
        for (var md = 0; md < 38; md++) {
          MatchEngine.simulate(
            home: md.isEven ? home : away,
            away: md.isEven ? away : home,
            matchday: md + 1,
          );
          for (final t in [home, away]) {
            for (final p in t.players) {
              p.fatigue = 0;
              p.suspendedMatches = 0;
              if (p.injuryWeeks > 0) {
                p.injuryWeeks -= 1;
                if (p.injuryWeeks == 0) p.injuryType = null;
              }
            }
          }
        }
        longTerm += count((t) => t.isLongTerm) - longBefore;
        allInjuries += count((_) => true) - allBefore;
      }
      final perClubSeason = longTerm / (seasons * 2);
      expect(perClubSeason, inInclusiveRange(0.1, 2.0),
          reason: '長期の怪我が1季1クラブ${perClubSeason.toStringAsFixed(2)}人 '
              '(怪我は全部で${allInjuries / (seasons * 2)}件)');
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('長期の怪我は長さによらず手術か保存療法かを選ばせる', () async {
      final gs = GameState();
      await gs.startNewGame('医療FC');
      final players = gs.userTeam.players;
      final acl = players[0]
        ..injuryType = InjuryType.acl
        ..injuryWeeks = 30;
      final fracture = players[1]
        ..injuryType = InjuryType.fracture
        ..injuryWeeks = 3; // 治りかけでも、骨折は選ばせる
      players[2]
        ..injuryType = InjuryType.bruise
        ..injuryWeeks = 2;
      gs.debugReviewInjuries();
      expect(gs.playersAwaitingSurgeryDecision.toSet(), {acl, fracture});
      expect(InjuryCare.describe(acl), InjuryType.acl.label);
      // 保存療法で再発したら、元の種類のまま。
      await gs.decideSurgery(acl.id, surgery: false);
      acl.injuryWeeks = 0;
      expect(gs.debugHeal(acl, 0.0), isTrue);
      expect(acl.injuryType, InjuryType.acl);
    });
  });

  group('4. 代表は国際マッチウィークに、全クラブから一斉に', () {
    Future<(GameState, Player, Player, Player)> setUpGame() async {
      final game = GameState();
      // イングランドの3部(始めの部)は代表ウィークにも試合をする
      // (2026-11-23)ので、代表ウィークに節を置かない国で確かめる。
      await game.startNewGame('代表FC', theme: LeagueTheme.spain);
      final s = game.save!;
      final star = game.userTeam.players
          .firstWhere((p) => p.position != Position.gk)
        ..attributes = {for (final k in AttributeKeys.all) k: 95};
      final weak = game.userTeam.players
          .lastWhere((p) => p.position != Position.gk && p.id != star.id)
        ..attributes = {for (final k in AttributeKeys.all) k: 35};
      final cpu = s.league.teams.firstWhere((t) => t.id != s.userTeamId);
      final cpuStar = cpu.players.firstWhere((p) => p.position != Position.gk)
        ..attributes = {for (final k in AttributeKeys.all) k: 95};
      // 夏の大会で抜けている・怪我をしている選手だと、呼ばれる・呼ばれないを
      // 確かめられない(開幕前の夏の大会の休みは代表とは別の印)。
      for (final p in [star, weak, cpuStar]) {
        p
          ..onTournamentLeave = false
          ..injuryWeeks = 0
          ..injuryType = null;
      }
      return (game, star, weak, cpuStar);
    }

    test('代表ウィークの週に、自クラブも他クラブも力のある選手が呼ばれる', () async {
      final (game, star, weak, cpuStar) = await setUpGame();
      final sat =
          SeasonCalendar.internationalSaturdays(game.save!.league.season).first;
      game.save!.today = sat;
      final called = game.debugAdvanceInternationalDuty();
      expect(star.isOnInternationalDuty, isTrue);
      expect(cpuStar.isOnInternationalDuty, isTrue, reason: '他クラブから呼ばれていない');
      expect(weak.isOnInternationalDuty, isFalse, reason: '代表の力が無いのに呼ばれた');
      expect(called, contains(star.name));
      expect(called, isNot(contains(cpuStar.name)), reason: '通知は自クラブの選手だけ');

      // 同じ代表ウィークの2回目の週の処理では、もう呼ばない。
      star.internationalDutyWeeksRemaining = 0;
      game.save!.today = DateTime(sat.year, sat.month, sat.day + 3);
      expect(game.debugAdvanceInternationalDuty(), isEmpty);
      expect(star.isOnInternationalDuty, isFalse);

      // 代表ウィークの間は戻らず、終われば戻る。
      cpuStar.internationalDutyWeeksRemaining = 1;
      game.debugReleaseInternationalDuty();
      expect(cpuStar.isOnInternationalDuty, isTrue);
      game.save!.today = DateTime(sat.year, sat.month, sat.day + 7);
      game.debugReleaseInternationalDuty();
      expect(cpuStar.isOnInternationalDuty, isFalse);
    });

    test('代表ウィークの外では呼ばない(一年中の抽選はやめた)', () async {
      final (game, star, _, cpuStar) = await setUpGame();
      final cal = game.seasonCalendar;
      for (var md = 1; md <= 10; md++) {
        final day = cal.dateForMatchday(md);
        expect(cal.isInternationalWindow(day), isFalse,
            reason: '代表ウィークにリーグ戦が入っている');
        game.save!.today = day;
        expect(game.debugAdvanceInternationalDuty(), isEmpty);
      }
      expect(star.isOnInternationalDuty, isFalse);
      expect(cpuStar.isOnInternationalDuty, isFalse);
    });

    test('9月の代表ウィークをまたいで進めると、呼ばれて、次の節には戻っている', () async {
      final (game, star, _, _) = await setUpGame();
      final sat =
          SeasonCalendar.internationalSaturdays(game.save!.league.season).first;
      var calledSeen = false;
      for (var i = 0; i < 10; i++) {
        game.lastInternationalCallUps = [];
        final r = await game.playNextMatchdayQuickSim();
        expect(r, isNotNull);
        // 試合で怪我をすると呼ばれないので、毎節治しておく。
        star
          ..injuryWeeks = 0
          ..injuryType = null;
        // 知らせの一覧は節ごとに作り直されるので、節を終えた時点でまだ
        // 代表に出ている印でも数える。
        if (game.lastInternationalCallUps.contains(star.name) ||
            star.isOnInternationalDuty) {
          calledSeen = true;
        }
        if (game.today.isAfter(sat)) break;
      }
      expect(calledSeen, isTrue, reason: '9月の代表ウィークに呼ばれていない');
      expect(star.isOnInternationalDuty, isFalse, reason: '代表ウィークが終わっても戻っていない');
    }, timeout: const Timeout(Duration(minutes: 5)));
  });

  group('5. カード・PK・直接FKの数が実際に近い(得点・引き分け・ホーム勝ちは崩さない)', () {
    test('数百試合の平均が実際の範囲に入る', () {
      const n = 800;
      var yellows = 0, reds = 0, goals = 0, fkGoals = 0, penalties = 0;
      var draws = 0, homeWins = 0;
      for (var i = 0; i < n; i++) {
        final r = MatchEngine.simulate(
            home: squad('h$i'), away: squad('a$i'), matchday: 1);
        goals += r.homeGoals + r.awayGoals;
        if (r.homeGoals == r.awayGoals) draws++;
        if (r.homeGoals > r.awayGoals) homeWins++;
        for (final e in r.events) {
          switch (e.type) {
            case MatchEventType.yellowCard:
              yellows++;
            case MatchEventType.redCard:
              reds++;
            case MatchEventType.goal:
              if (e.setPiece == SetPieceKind.directFreeKick) fkGoals++;
            // 交代(2026-11-22 に足した出来事)は数えない。
            case MatchEventType.chance:
            case MatchEventType.substitution:
              break;
          }
          // PK は決まっても外れても、必ず1件の出来事になる。
          if (e.setPiece == SetPieceKind.penalty) penalties++;
        }
      }
      final summary = '警告${(yellows / n).toStringAsFixed(2)} '
          '退場${(reds / n).toStringAsFixed(3)} '
          '得点${(goals / n).toStringAsFixed(2)} '
          '直接FK${(fkGoals / goals * 100).toStringAsFixed(1)}% '
          'PK${(penalties / n).toStringAsFixed(2)} '
          '引き分け${(draws / n * 100).toStringAsFixed(1)}% '
          'ホーム勝ち${(homeWins / n * 100).toStringAsFixed(1)}%';
      // 欧州5大リーグ: 警告4〜5枚・退場0.1〜0.3枚(2枚目込み)・直接FKは
      // 全得点の1〜2%・PK0.25〜0.3本・得点約2.7・引き分け約25%・ホーム勝ち約45%。
      // 範囲は800試合の揺れの分だけ広げてある。
      expect(yellows / n, inInclusiveRange(4.0, 5.5), reason: summary);
      expect(reds / n, inInclusiveRange(0.08, 0.3), reason: summary);
      expect(fkGoals / goals, inInclusiveRange(0.005, 0.025), reason: summary);
      expect(penalties / n, inInclusiveRange(0.2, 0.36), reason: summary);
      expect(goals / n, inInclusiveRange(2.4, 2.95), reason: summary);
      expect(draws / n, inInclusiveRange(0.19, 0.31), reason: summary);
      expect(homeWins / n, inInclusiveRange(0.38, 0.52), reason: summary);
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('2枚目の警告は1枚目より後の分に出る(分の順に処理する)', () {
      for (var i = 0; i < 300; i++) {
        final r = MatchEngine.simulate(
            home: squad('h$i'), away: squad('a$i'), matchday: 1);
        final firstYellow = <String, int>{};
        for (final e in r.events) {
          if (e.type == MatchEventType.yellowCard) {
            firstYellow.putIfAbsent(e.scorerId!, () => e.minute);
          }
        }
        for (final e in r.events) {
          if (e.type != MatchEventType.redCard) continue;
          final y = firstYellow[e.scorerId];
          if (y != null) {
            expect(y, lessThan(e.minute), reason: '退場の後に警告が出ている');
          }
          expect(
              r.events.where((x) =>
                  x.type == MatchEventType.redCard && x.scorerId == e.scorerId),
              hasLength(1),
              reason: '同じ選手が2度退場した');
        }
      }
    });

    test('PK・直接FKの印は保存して読み直しても残る', () {
      final e = MatchEvent(
        minute: 12,
        teamId: 't',
        scorerId: 'p',
        setPiece: SetPieceKind.directFreeKick,
      );
      expect(MatchEvent.fromJson(e.toJson()).setPiece,
          SetPieceKind.directFreeKick);
      final plain = MatchEvent(minute: 1, teamId: 't');
      expect(plain.toJson().containsKey('setPiece'), isFalse);
      expect(MatchEvent.fromJson(plain.toJson()).setPiece, isNull);
    });
  });
}
