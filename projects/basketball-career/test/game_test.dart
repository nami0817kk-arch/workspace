import 'dart:math';

import 'package:basketball_career/game/career.dart';
import 'package:basketball_career/game/difficulty.dart';
import 'package:basketball_career/game/events.dart';
import 'package:basketball_career/game/game.dart';
import 'package:basketball_career/game/goals.dart';
import 'package:basketball_career/game/legacy.dart';
import 'package:basketball_career/game/life.dart';
import 'package:basketball_career/game/match.dart';
import 'package:basketball_career/game/path.dart';
import 'package:basketball_career/game/rival.dart';
import 'package:basketball_career/ui/labels.dart';
import 'package:basketball_career/game/player.dart';
import 'package:basketball_career/game/season.dart';
import 'package:basketball_career/game/traits.dart';
import 'package:flutter_test/flutter_test.dart';

Player strong({double height = 195}) => Player(
      name: 'テスト',
      age: 18,
      potential: 80,
      heightCm: height,
      heightGenes: 0.5,
      abilities: {for (final a in Ability.values) a: 80},
    );

Player weak() => Player(
      name: 'テスト',
      age: 18,
      potential: 30,
      heightCm: 170,
      heightGenes: 0.5,
      abilities: {for (final a in Ability.values) a: 20},
    );

Player kidPlayer() => Player(
    name: 'キッズ', age: 8, potential: 50, heightCm: 130, heightGenes: 0.5);

void main() {
  group('career', () {
    test('年齢で段階が決まる', () {
      expect(stageOf(6), Stage.minibasket);
      expect(stageOf(13), Stage.juniorHigh);
      expect(stageOf(16), Stage.highSchool);
      expect(stageOf(19), Stage.pathChoice);
      expect(stageOf(19, turnedPro: true), Stage.pro);
      expect(stageOf(41, turnedPro: true), Stage.retired);
    });

    test('身長は成長期に伸び、21歳以降は止まる', () {
      expect(heightGrowthPerYear(14, 0.5),
          greaterThan(heightGrowthPerYear(8, 0.5)));
      expect(heightGrowthPerYear(21, 1), 0);
      expect(heightGrowthPerYear(14, 1),
          greaterThan(heightGrowthPerYear(14, 0)));
    });
  });

  group('player', () {
    test('身長が高いとポジションが内側になる', () {
      expect(strong(height: 208).position, Position.center);
      expect(strong(height: 178).position,
          anyOf(Position.pointGuard, Position.shootingGuard));
    });

    test('身長でリバウンドの実効値が上がる', () {
      expect(strong(height: 205).effective(Ability.rebound),
          greaterThan(strong(height: 175).effective(Ability.rebound)));
    });

    test('保存して読み戻せる / 欠けた項目は既定値', () {
      final p = strong().copyWith(traits: {Trait.clutch});
      final q = Player.fromJson(p.toJson());
      expect(q.heightCm, p.heightCm);
      expect(q.of(Ability.pass), 80);
      expect(q.traits, {Trait.clutch});
      final old = Player.fromJson({'name': 'x'});
      expect(old.age, startAge);
      expect(old.of(Ability.inside), startLevel);
    });
  });

  group('traits', () {
    test('矛盾する特性は同時に持てない', () {
      expect(canGain({Trait.clutch}, Trait.nervy), isFalse);
      expect(canGain({Trait.sturdy}, Trait.glassBody), isFalse);
      expect(canGain({Trait.clutch}, Trait.sturdy), isTrue);
    });
  });

  group('life', () {
    test('練習で重点の能力が伸びる(平均して)', () {
      final rng = Random(1);
      var p = Player(
          name: 'a', age: 12, potential: 60, heightCm: 150, heightGenes: 0.5);
      var c = const Condition();
      for (var i = 0; i < 4; i++) {
        final r = playTerm(p, c, Action.practice, Ability.threePoint, rng);
        p = r.player;
        c = r.condition.copyWith(fatigue: 0, injuredTerms: 0);
      }
      expect(p.of(Ability.threePoint), greaterThan(startLevel + 3));
    });

    test('休養は疲れを取り、能力を動かさない', () {
      final p = strong();
      final r = playTerm(p, const Condition(fatigue: 60), Action.rest,
          Ability.pass, Random(2));
      expect(r.condition.fatigue, lessThan(60));
      expect(r.player.of(Ability.pass), p.of(Ability.pass));
    });

    test('怪我中は特訓と練習試合を選べない', () {
      const c = Condition(injuredTerms: 2);
      expect(canChoose(Action.intense, c), isFalse);
      expect(canChoose(Action.scrimmage, c), isFalse);
      expect(canChoose(Action.rest, c), isTrue);
      expect(
          () => playTerm(strong(), c, Action.intense, Ability.pass, Random(3)),
          throwsStateError);
    });

    test('30代は衰える', () {
      final p = strong().copyWith(age: 34);
      expect(yearlyDelta(p, Ability.speed, Ability.pass), lessThan(0));
    });

    test('年末で年齢と身長が進む', () {
      final p = Player(
          name: 'a', age: 13, potential: 50, heightCm: 150, heightGenes: 0.5);
      final q = ageUp(p, Random(4));
      expect(q.age, 14);
      expect(q.heightCm, greaterThan(150));
    });
  });

  group('match', () {
    test('強い選手のほうが勝ちやすい', () {
      var strongWins = 0, weakWins = 0;
      for (var i = 0; i < 300; i++) {
        if (simulateMatch(strong(),
                teamStrength: 50, oppStrength: 55, form: 1, rng: Random(i))
            .won) {
          strongWins++;
        }
        if (simulateMatch(weak(),
                teamStrength: 50, oppStrength: 55, form: 1, rng: Random(i))
            .won) {
          weakWins++;
        }
      }
      expect(strongWins, greaterThan(weakWins));
    });

    test('点差が近ければ勝負どころが訪れ、選んだプレーが使われる', () {
      var clutches = 0;
      for (var i = 0; i < 200; i++) {
        final m = simulateMatch(strong(),
            teamStrength: 55,
            oppStrength: 55,
            form: 1,
            rng: Random(i),
            chooseClutch: (_) => Clutch.threePoint);
        if (m.clutch != null) {
          clutches++;
          expect(m.clutch, Clutch.threePoint);
        }
      }
      expect(clutches, greaterThan(0));
    });

    test('勝負強い特性で成功率が上がり、ノミの心臓で下がる', () {
      final base = strong();
      final hot = base.copyWith(traits: {Trait.clutch});
      final cold = base.copyWith(traits: {Trait.nervy});
      final a = clutchChance(hot, Clutch.drive, 50, 1);
      final b = clutchChance(base, Clutch.drive, 50, 1);
      final c = clutchChance(cold, Clutch.drive, 50, 1);
      expect(a, greaterThan(b));
      expect(b, greaterThan(c));
    });

    test('引き分けは無い(同点は延長で決着)', () {
      for (var i = 0; i < 200; i++) {
        final m = simulateMatch(strong(),
            teamStrength: 50, oppStrength: 50, form: 1, rng: Random(i));
        expect(m.teamScore, isNot(m.oppScore));
        expect(m.won, m.teamScore > m.oppScore);
      }
    });
  });

  group('season', () {
    test('勝ち抜きは負けたらそこで終わり、プロは全試合を戦う', () {
      for (var i = 0; i < 50; i++) {
        final t = playTournament(weak(), League.highSchool,
            form: 1, rng: Random(i));
        expect(t.games, lessThanOrEqualTo(League.highSchool.rounds));
        expect(t.games, t.wins + 1 > t.games ? t.games : t.wins + 1);
        final p = playTournament(weak(), League.proDomestic,
            form: 1, rng: Random(i));
        expect(p.games, League.proDomestic.rounds);
      }
    });
  });

  group('path', () {
    test('一番上は確実、一番下は絶対に無理', () {
      for (var i = 0; i < 100; i++) {
        expect(winsContract(strong(height: 205), 90, Random(i)), isTrue);
        expect(winsContract(weak(), 0, Random(i)), isFalse);
      }
    });

    test('身長が高いほど評価が高い', () {
      expect(offerScore(strong(height: 205), 50),
          greaterThan(offerScore(strong(height: 175), 50)));
    });

    test('海外挑戦は年齢と総合評価の条件', () {
      expect(canGoAbroad(strong().copyWith(age: 20)), isFalse);
      expect(canGoAbroad(strong().copyWith(age: 25)), isTrue);
      expect(canGoAbroad(weak().copyWith(age: 25)), isFalse);
    });
  });

  group('Game', () {
    Game fresh({int seed = 7}) => Game.start('テスト', rng: Random(seed), events: false);

    test('1年は4回の choose で進む。夏に大会が行われる', () {
      final g = fresh();
      final r1 = g.choose(Action.practice, Ability.pass);
      expect(r1.tournament, isNull);
      final r2 = g.choose(Action.practice, Ability.pass);
      expect(r2.tournament, isNotNull);
      g.choose(Action.rest, Ability.pass);
      final r4 = g.choose(Action.rest, Ability.pass);
      expect(r4.yearEnded, isTrue);
      expect(g.player.age, startAge + 1);
      expect(g.slot, 0);
      expect(g.records, hasLength(1));
    });

    test('段階に合わない操作は StateError', () {
      final g = fresh();
      expect(() => g.chooseRoute(Route.pro), throwsStateError);
      expect(() => g.giveUp(), throwsStateError);
      expect(() => g.retire(), throwsStateError);
      expect(() => g.goAbroad(), throwsStateError);
    });

    test('19歳で進路の局面になる', () {
      final g = fresh();
      while (g.phase == Phase.season) {
        g.choose(
            g.condition.injured ? Action.rest : Action.practice, Ability.pass);
      }
      expect(g.phase, Phase.path);
      expect(g.player.age, 19);
      expect(g.stage, Stage.pathChoice);
      expect(g.availableRoutes,
          containsAll([Route.pro, Route.university, Route.corporate]));
    });

    test('プロに落ちたら大学・実業団だけ。卒業後はプロだけで、落ちたら引退', () {
      final g = Game(
          eventsEnabled: false,
          player: weak().copyWith(age: 19), rng: Random(1), pathPending: true);
      expect(g.chooseRoute(Route.pro), isFalse);
      expect(g.proRejected, isTrue);
      expect(g.availableRoutes, [Route.university, Route.corporate]);
      expect(() => g.chooseRoute(Route.pro), throwsStateError);
      g.chooseRoute(Route.university);
      expect(g.stage, Stage.college);
      expect(g.collegeYearsLeft, 4);
      while (g.phase == Phase.season) {
        g.choose(Action.rest, Ability.pass);
      }
      expect(g.phase, Phase.path);
      expect(g.availableRoutes, [Route.pro]);
      expect(g.chooseRoute(Route.pro), isFalse);
      expect(g.phase, Phase.retired);
    });

    test('強い選手はプロ契約を取れ、プロの段階で海外挑戦・引退ができる', () {
      final g = Game(
          eventsEnabled: false,
          player: strong(height: 205).copyWith(age: 21),
          rng: Random(1),
          pathPending: true);
      expect(g.chooseRoute(Route.pro), isTrue);
      expect(g.stage, Stage.pro);
      expect(g.league, League.proDomestic);
      expect(g.canGoAbroad, isTrue);
      g.goAbroad();
      expect(g.league, League.proAbroad);
      expect(() => g.goAbroad(), throwsStateError);
      g.retire();
      expect(g.phase, Phase.retired);
      expect(g.retiredReason, isNotNull);
    });

    test('プロで評価が低い年が続くと戦力外', () {
      final g = Game(
        eventsEnabled: false,
        player: weak().copyWith(age: 20),
        rng: Random(1),
        track: Track.pro,
      );
      while (g.phase == Phase.season) {
        g.choose(Action.rest, Ability.pass);
      }
      expect(g.retiredReason, contains('戦力外'));
    });

    test('40歳を超えたら強制引退', () {
      final g = Game(
        eventsEnabled: false,
        player: strong().copyWith(age: maxProAge),
        rng: Random(1),
        track: Track.pro,
      );
      for (var i = 0; i < 4; i++) {
        g.choose(Action.rest, Ability.pass);
      }
      expect(g.phase, Phase.retired);
    });

    test('怪我で大会に出られない年は記録が残らない', () {
      final g = Game(
        eventsEnabled: false,
        player: strong().copyWith(age: 12),
        rng: Random(1),
        condition: const Condition(injuredTerms: 5),
        slot: 1,
      );
      final r = g.choose(Action.rest, Ability.pass);
      expect(r.satOut, isTrue);
      expect(g.records, isEmpty);
    });

    test('保存して読み戻せる / 古いセーブは既定値で読める', () {
      final g = fresh();
      g.choose(Action.practice, Ability.pass);
      g.choose(Action.practice, Ability.pass);
      final h = Game.fromJson(g.toJson());
      expect(h.slot, g.slot);
      expect(h.records, hasLength(g.records.length));
      expect(h.player.age, g.player.age);
      final old = Game.fromJson({
        'player': {'name': 'old'}
      });
      expect(old.phase, Phase.season);
      expect(old.track, Track.school);
    });

    test('最後まで通しで遊べる(どの乱数でも止まらず、引退に着く)', () {
      for (var seed = 0; seed < 40; seed++) {
        final g = Game.start('ファズ', rng: Random(seed), events: false);
        var guard = 0;
        while (g.phase != Phase.retired && guard++ < 400) {
          switch (g.phase) {
            case Phase.season:
              final a = g.condition.fatigue >= 60 || g.condition.injured
                  ? Action.rest
                  : Action.practice;
              g.choose(a, Ability.values[guard % Ability.values.length]);
              if (g.canGoAbroad) g.goAbroad();
            case Phase.path:
              g.chooseRoute(g.availableRoutes.first);
            case Phase.clutch || Phase.event || Phase.retired:
              break;
          }
        }
        expect(g.phase, Phase.retired, reason: 'seed=$seed');
        expect(g.player.age, lessThanOrEqualTo(maxProAge + 2));
      }
    });
  });

  group('events', () {
    Game withEvent(String id) => Game(
          player: strong().copyWith(age: 12),
          rng: Random(1),
          eventsEnabled: false,
          pendingEventId: id,
        );

    test('出来事が起きている間は季節を進められない', () {
      final g = withEvent('friends');
      expect(g.phase, Phase.event);
      expect(() => g.choose(Action.rest, Ability.pass), throwsStateError);
      g.resolveEvent(0);
      expect(g.phase, Phase.season);
      expect(() => g.resolveEvent(0), throwsStateError);
    });

    test('選択の結果が当たる(友だち: 気持ちが上がり疲れが取れる)', () {
      final g = withEvent('friends');
      g.condition = const Condition(fatigue: 40, morale: 40);
      final lines = g.resolveEvent(0);
      expect(g.condition.morale, greaterThan(40));
      expect(g.condition.fatigue, lessThan(40));
      expect(lines, isNotEmpty);
    });

    test('重点の能力に足す出来事は、直近に選んだ重点に効く', () {
      final g = withEvent('coach_menu');
      g.lastFocus = Ability.pass;
      final before = g.player.of(Ability.pass);
      g.resolveEvent(0);
      expect(g.player.of(Ability.pass), before + 3);
    });

    test('特性を得られる。矛盾するものは得られない', () {
      final g = Game(
        player: strong().copyWith(age: 18, traits: {Trait.nervy}),
        rng: Random(1),
        eventsEnabled: false,
        pendingEventId: 'scout',
      );
      g.resolveEvent(1); // 勝負強い(ノミの心臓と矛盾)
      expect(g.player.traits.contains(Trait.clutch), isFalse);
    });

    test('年齢に合わない出来事は引かれない', () {
      final rng = Random(5);
      final young = Player(
          name: 'a', age: 7, potential: 50, heightCm: 120, heightGenes: 0.5);
      for (var i = 0; i < 500; i++) {
        final e = rollEvent(young, pro: false, rng: rng);
        if (e != null) {
          expect(e.minAge, lessThanOrEqualTo(7));
          expect(e.proOnly, isFalse);
        }
      }
    });

    test('出来事つきでも最後まで遊べる(毎回最初の選択肢を選ぶ)', () {
      for (var seed = 0; seed < 30; seed++) {
        final g = Game.start('ファズ', rng: Random(seed));
        var guard = 0;
        var sawEvent = false;
        while (g.phase != Phase.retired && guard++ < 600) {
          switch (g.phase) {
            case Phase.season:
              g.choose(
                  g.condition.fatigue >= 60 || g.condition.injured
                      ? Action.rest
                      : Action.practice,
                  Ability.values[guard % Ability.values.length]);
            case Phase.clutch:
              g.resolveClutch(Clutch.drive);
            case Phase.event:
              sawEvent = true;
              g.resolveEvent(0);
            case Phase.path:
              g.chooseRoute(g.availableRoutes.first);
            case Phase.retired:
              break;
          }
        }
        expect(g.phase, Phase.retired, reason: 'seed=$seed');
        expect(sawEvent, isTrue);
      }
    });

    test('出来事の途中でも保存して読み戻せる', () {
      final g = withEvent('rival');
      g.lastFocus = Ability.speed;
      final h = Game.fromJson(g.toJson());
      expect(h.phase, Phase.event);
      expect(h.pendingEventId, 'rival');
      expect(h.lastFocus, Ability.speed);
    });
  });

  group('winter / legacy', () {
    test('高校では冬にも大会があり、ミニバスにはない', () {
      final hs = Game(
        eventsEnabled: false,
        player: strong().copyWith(age: 16),
        rng: Random(1),
        slot: 3,
      );
      expect(hs.hasWinterCup, isTrue);
      final r = hs.choose(Action.rest, Ability.pass);
      expect(r.tournament, isNotNull);
      expect(hs.records.single.winter, isTrue);
      final kid = Game(
        eventsEnabled: false,
        player: strong().copyWith(age: 8),
        rng: Random(1),
        slot: 3,
      );
      expect(kid.hasWinterCup, isFalse);
      expect(kid.choose(Action.rest, Ability.pass).tournament, isNull);
    });

    test('殿堂の記録は保存して読み戻せる', () {
      final g = Game(
        eventsEnabled: false,
        player: strong(height: 205).copyWith(age: 25),
        rng: Random(1),
        track: Track.pro,
      );
      g.choose(Action.rest, Ability.pass);
      g.choose(Action.rest, Ability.pass);
      g.retire();
      final h = HistoryEntry.of(g);
      final j = HistoryEntry.fromJson(h.toJson());
      expect(j.name, h.name);
      expect(j.pro, isTrue);
      expect(j.reason, g.retiredReason);
      expect(HistoryEntry.fromJson({}).name, '名無し');
    });

    test('実績の判定(巨人・3Pの名手・プロの扉)', () {
      final p = strong(height: 207)
          .copyWith(abilities: {for (final a in Ability.values) a: 91});
      final g = Game(
        eventsEnabled: false,
        player: p.copyWith(age: 25),
        rng: Random(1),
        track: Track.pro,
      );
      g.choose(Action.rest, Ability.pass);
      g.choose(Action.rest, Ability.pass);
      final got = earnedBy(g);
      expect(got, containsAll(['giant', 'sniper', 'wall', 'allround']));
      expect(got.contains('late_pro'), isFalse);
    });

    test('実績の id は重複しない', () {
      final ids = achievements.map((a) => a.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('勝負どころをその場で選ぶ', () {
    /// 勝負どころが必ず来る試合(同点付近)になる乱数を探す。
    Game summerGame(int seed) => Game(
          eventsEnabled: false,
          player: strong().copyWith(age: 15),
          rng: Random(seed),
          slot: 1,
        );

    int findSeed() {
      for (var seed = 0; seed < 400; seed++) {
        final g = summerGame(seed);
        g.choose(Action.rest, Ability.pass, askClutch: true);
        if (g.phase == Phase.clutch) return seed;
      }
      throw StateError('勝負どころになる乱数が見つからない');
    }

    test('askClutch なら勝負どころで止まり、選ぶまで季節は進まない', () {
      final g = summerGame(findSeed());
      final r = g.choose(Action.rest, Ability.pass, askClutch: true);
      expect(r.paused, isTrue);
      expect(g.phase, Phase.clutch);
      expect(g.slot, 1, reason: '大会が終わるまで季節は進まない');
      expect(() => g.choose(Action.rest, Ability.pass), throwsStateError);
      final info = g.clutchInfo!;
      expect(info.chances.keys, containsAll(Clutch.values));
      expect(info.margin.abs(), lessThanOrEqualTo(clutchWindow));
    });

    test('選ぶと続きが進み、大会が終わると季節が進んで記録が残る', () {
      final g = summerGame(findSeed());
      g.choose(Action.rest, Ability.pass, askClutch: true);
      var guard = 0;
      TermReport? done;
      while (g.phase == Phase.clutch && guard++ < 10) {
        final r = g.resolveClutch(Clutch.drive);
        if (!r.paused) done = r;
      }
      expect(done, isNotNull);
      expect(g.phase, isNot(Phase.clutch));
      expect(g.slot, 2);
      expect(g.records, hasLength(1));
      expect(g.lastReport, done);
      expect(done!.tournament!.matches.any((m) => m.clutch == Clutch.drive),
          isTrue);
    });

    test('止まっていないときに選ぶと StateError', () {
      final g = summerGame(0);
      expect(() => g.resolveClutch(Clutch.drive), throwsStateError);
    });

    test('勝負どころで止まっていても、保存して読み戻して続けられる', () {
      final g = summerGame(findSeed());
      g.choose(Action.rest, Ability.pass, askClutch: true);
      final h = Game.fromJson(g.toJson());
      expect(h.phase, Phase.clutch);
      expect(h.run!.pending!.team, g.run!.pending!.team);
      expect(h.run!.matches.length, g.run!.matches.length);
      var guard = 0;
      while (h.phase == Phase.clutch && guard++ < 10) {
        h.resolveClutch(Clutch.threePoint);
      }
      expect(h.slot, 2);
      expect(h.records, hasLength(1));
    });

    test('chooseClutch を渡せば止まらない(askClutch は無視)', () {
      final g = summerGame(findSeed());
      final r = g.choose(Action.rest, Ability.pass,
          askClutch: true, chooseClutch: (_) => Clutch.pass);
      expect(r.paused, isFalse);
      expect(g.phase, isNot(Phase.clutch));
    });

    test('クォーターごとの得点が残り、合計と一致する', () {
      final s = playQuarters(strong(),
          teamStrength: 50, oppStrength: 50, form: 1, rng: Random(3));
      expect(s.teamQuarters, hasLength(4));
      expect(s.teamQuarters.reduce((a, b) => a + b), s.team);
      expect(s.oppQuarters.reduce((a, b) => a + b), s.opp);
    });
  });

  group('ライバル', () {
    test('9歳から現れ、素質が高いほど強い。30歳を過ぎると衰える', () {
      final r = Rival(name: '神谷リョウ', potential: 80);
      final low = Rival(name: 'x', potential: 40);
      expect(r.activeAt(8), isFalse);
      expect(r.activeAt(9), isTrue);
      expect(r.activeAt(37), isFalse);
      expect(r.edgeAt(14), greaterThan(low.edgeAt(14)));
      expect(r.edgeAt(34), lessThan(r.edgeAt(28)));
    });

    test('準決勝のあたりで現れ、勝ち負けが通算に残る', () {
      final g = Game(
        eventsEnabled: false,
        player: strong().copyWith(age: 15),
        rng: Random(2),
        slot: 1,
        rival: Rival(name: '黒瀬ツバサ', potential: 60),
      );
      g.choose(Action.rest, Ability.pass);
      final t = g.records.single;
      expect(t.games, greaterThan(0));
      final rivalRound = max(1, League.juniorHigh.rounds - 2);
      // 3試合以上戦ったなら、ライバル戦が1つ入っている
      if (t.games > rivalRound) {
        expect(g.rival.games, 1);
      }
    });

    test('負けたライバル戦は敗数に、勝てば勝数に入る', () {
      var wins = 0, losses = 0;
      for (var seed = 0; seed < 60; seed++) {
        final g = Game(
          eventsEnabled: false,
          player: strong().copyWith(age: 18),
          rng: Random(seed),
          slot: 1,
          rival: Rival(name: '氷室シン', potential: 70),
        );
        g.choose(Action.rest, Ability.pass);
        wins += g.rival.wins;
        losses += g.rival.losses;
      }
      expect(wins + losses, greaterThan(0));
      expect(wins, greaterThan(0), reason: '強い選手は勝つこともある');
      expect(losses, greaterThan(0), reason: 'ライバルは強く、負けることもある');
    });

    test('9歳より前には現れない', () {
      final g = Game(
        eventsEnabled: false,
        player: Player(
            name: 'a', age: 7, potential: 50, heightCm: 125, heightGenes: 0.5),
        rng: Random(1),
        slot: 1,
      );
      g.choose(Action.rest, Ability.pass);
      expect(g.rival.games, 0);
    });

    test('保存して読み戻せる', () {
      final g = Game(
        eventsEnabled: false,
        player: strong(),
        rng: Random(1),
        rival: Rival(name: '桐生レン', potential: 77, wins: 3, losses: 2),
      );
      final h = Game.fromJson(g.toJson());
      expect(h.rival.name, '桐生レン');
      expect(h.rival.potential, 77);
      expect(h.rival.wins, 3);
      expect(h.rival.losses, 2);
      expect(Game.fromJson({'player': {'name': 'old'}}).rival.name, 'ライバル');
    });

    test('対戦チームの名前は段階に合う', () {
      final rng = Random(1);
      expect(opponentTeamName(League.highSchool, rng), endsWith('高校'));
      expect(opponentTeamName(League.juniorHigh, rng), endsWith('中学'));
      expect(opponentTeamName(League.proAbroad, rng), endsWith('タイタンズ'));
    });
  });

  group('難易度とおすすめ', () {
    int grown(Difficulty d) {
      var total = 0;
      for (var seed = 0; seed < 60; seed++) {
        final p = Player(
            name: 'a', age: 12, potential: 60, heightCm: 150, heightGenes: 0.5);
        final r = playTerm(p, const Condition(), Action.practice,
            Ability.threePoint, Random(seed),
            growthScale: d.growth);
        total += r.player.of(Ability.threePoint) - p.of(Ability.threePoint);
      }
      return total;
    }

    test('やさしいほどよく伸び、むずかしいほど伸びない', () {
      expect(grown(Difficulty.easy), greaterThan(grown(Difficulty.normal)));
      expect(grown(Difficulty.normal), greaterThan(grown(Difficulty.hard)));
    });

    test('難易度は保存され、古いセーブは「ふつう」になる', () {
      final g = Game.start('a', rng: Random(1), difficulty: Difficulty.hard);
      expect(Game.fromJson(g.toJson()).difficulty, Difficulty.hard);
      expect(Game.fromJson({'player': {'name': 'old'}}).difficulty,
          Difficulty.normal);
    });

    test('おすすめの重点は、ポジションに効く伸びしろの大きい能力', () {
      final p = strong(height: 208).copyWith(abilities: {
        for (final a in Ability.values) a: 80,
        Ability.inside: 30,
        Ability.threePoint: 10, // センターには効かない
      });
      expect(p.position, Position.center);
      expect(recommendedFocus(p), Ability.inside);
    });
  });

  group('年の目標', () {
    Game fresh() => Game.start('目標', rng: Random(5), events: false);

    test('始めると候補が2つ出る(確実と挑戦)', () {
      final g = fresh();
      expect(g.goalOptions, hasLength(2));
      expect(g.goalOptions[0].stretch, isFalse);
      expect(g.goalOptions[1].stretch, isTrue);
      expect(g.goal, isNull);
    });

    test('選ぶと目標になり、二重には選べない', () {
      final g = fresh();
      g.adoptGoal(0);
      expect(g.goal, isNotNull);
      expect(g.goalProgress, isNotNull);
      expect(() => g.adoptGoal(1), throwsStateError);
    });

    test('能力の目標を達成すると、年末にごほうびが入る', () {
      final g = Game(
        eventsEnabled: false,
        player: kidPlayer(),
        rng: Random(1),
        goalOptions: const [
          Goal(kind: GoalKind.abilityUp, ability: Ability.pass, target: 1)
        ],
      );
      g.adoptGoal(0);
      g.player = g.player.copyWith(abilities: {
        for (final a in Ability.values) a: g.player.of(a),
        Ability.pass: g.player.of(Ability.pass) + 5,
      });
      final before = g.player.of(Ability.pass);
      for (var i = 0; i < 4; i++) {
        g.choose(Action.rest, Ability.pass);
      }
      expect(g.lastGoalMessage, contains('目標達成'));
      expect(g.player.of(Ability.pass), greaterThanOrEqualTo(before + 2));
      expect(g.goal, isNull, reason: '年が明けたら次の目標を選び直す');
    });

    test('届かなければ、ごほうびなしで終わる', () {
      final g = Game(
        eventsEnabled: false,
        player: kidPlayer(),
        rng: Random(1),
        goalOptions: const [
          Goal(kind: GoalKind.tournamentWins, target: 99, stretch: true)
        ],
      );
      g.adoptGoal(0);
      for (var i = 0; i < 4; i++) {
        g.choose(Action.rest, Ability.pass);
      }
      expect(g.lastGoalMessage, contains('届かなかった'));
    });

    test('年が明けると次の年の候補が出る', () {
      final g = fresh();
      for (var i = 0; i < 4; i++) {
        g.choose(Action.rest, Ability.pass);
      }
      expect(g.goalOptions, hasLength(2));
      expect(g.goal, isNull);
    });

    test('勝ち数の目標は、その年の大会の最多勝で判定する', () {
      final g = Game(
        eventsEnabled: false,
        player: strong().copyWith(age: 12),
        rng: Random(3),
        slot: 1,
        goalOptions: const [Goal(kind: GoalKind.tournamentWins, target: 1)],
      );
      g.adoptGoal(0);
      g.choose(Action.rest, Ability.pass);
      expect(g.yearBestWins, g.records.single.wins);
    });

    test('保存して読み戻せる', () {
      final g = fresh();
      g.adoptGoal(1);
      final h = Game.fromJson(g.toJson());
      expect(h.goal!.label, g.goal!.label);
      expect(h.goalOptions, hasLength(2));
      expect(h.goalStart.length, g.goalStart.length);
    });
  });

  group('チームワークと過ごし方の役割', () {
    Game g0() => Game(
        eventsEnabled: false, player: strong().copyWith(age: 15), rng: Random(1));

    test('交流で大きく上がり、何もしないと薄れる', () {
      final g = g0();
      final t0 = g.teamwork;
      g.choose(Action.social, Ability.pass);
      expect(g.teamwork, greaterThan(t0));
      final t1 = g.teamwork;
      g.choose(Action.rest, Ability.pass);
      expect(g.teamwork, lessThan(t1));
    });

    test('チームワークが高いと味方が強くなり、低いと弱くなる', () {
      final g = g0();
      g.teamwork = 100;
      final hi = g.teamBonus;
      g.teamwork = 0;
      final lo = g.teamBonus;
      expect(hi, greaterThan(0));
      expect(lo, lessThan(0));
      expect(hi - lo, lessThan(10), reason: '効きすぎない');
    });

    test('中学に上がると新しいチームでチームワークが40に戻る', () {
      final g = Game(
        eventsEnabled: false,
        player: Player(
            name: 'a', age: 12, potential: 50, heightCm: 150, heightGenes: 0.5),
        rng: Random(1),
        teamwork: 90,
      );
      for (var i = 0; i < 4; i++) {
        g.choose(Action.rest, Ability.pass);
      }
      expect(g.stage, Stage.juniorHigh);
      expect(g.teamwork, 40);
    });

    test('保存して読み戻せる', () {
      final g = g0()..teamwork = 77;
      expect(Game.fromJson(g.toJson()).teamwork, 77);
      expect(Game.fromJson({'player': {'name': 'old'}}).teamwork, 40);
    });

    test('大会の味方の強さにチームワークが入る', () {
      final run = TournamentRun(League.highSchool, teamBonus: 3.5);
      expect(TournamentRun.fromJson(run.toJson()).teamBonus, 3.5);
    });

    /// 伸びの合計(重点1・他9を0.25の重み)と疲れで、役割を比べる。
    double growthOf(Action a) {
      final p = Player(
          name: 'a', age: 14, potential: 60, heightCm: 160, heightGenes: 0.5);
      var total = 0;
      for (var seed = 0; seed < 80; seed++) {
        final r = playTerm(p, const Condition(), a, Ability.threePoint, Random(seed));
        for (final ab in Ability.values) {
          total += r.player.of(ab) - p.of(ab);
        }
      }
      return total / 80;
    }

    test('どの過ごし方も他の完全な上位互換ではない', () {
      final practice = growthOf(Action.practice);
      final intense = growthOf(Action.intense);
      final study = growthOf(Action.study);
      final social = growthOf(Action.social);
      final scrimmage = growthOf(Action.scrimmage);
      expect(intense, greaterThan(practice), reason: '特訓は伸びる(代わりに疲れる)');
      expect(practice, greaterThan(social), reason: '練習は交流より伸びる');
      expect(social, greaterThan(0));
      // 練習は交流より疲れる、特訓は練習より疲れる
      final c = const Condition();
      Condition after(Action a) =>
          playTerm(strong(), c, a, Ability.pass, Random(1)).condition;
      expect(after(Action.intense).fatigue, greaterThan(after(Action.practice).fatigue));
      expect(after(Action.practice).fatigue, greaterThan(after(Action.social).fatigue));
      expect(study, greaterThan(social));
      expect(scrimmage, greaterThan(social));
    });

    test('試合の流れを一言にする', () {
      MatchResult m(bool won, List<int> t, List<int> o, {Clutch? c, bool? ok}) =>
          MatchResult(
              won: won,
              teamScore: t.reduce((a, b) => a + b),
              oppScore: o.reduce((a, b) => a + b),
              points: 10,
              rebounds: 3,
              assists: 2,
              teamQuarters: t,
              oppQuarters: o,
              clutch: c,
              clutchSuccess: ok);
      expect(matchStory(m(true, [10, 10, 20, 20], [20, 15, 12, 12])), contains('逆転'));
      expect(matchStory(m(false, [20, 20, 10, 10], [10, 10, 20, 20])), contains('リード'));
      expect(matchStory(m(true, [25, 25, 25, 25], [10, 10, 10, 10])), contains('圧勝'));
      expect(matchStory(m(true, [15, 15, 15, 17], [15, 15, 15, 15], c: Clutch.threePoint, ok: true)),
          contains('3P'));
      expect(matchStory(const MatchResult(won: true, teamScore: 1, oppScore: 0, points: 0, rebounds: 0, assists: 0)), isNull);
    });
  });

  group('序盤とイベントの偏り', () {
    test('同じ出来事は続けて起きない', () {
      final rng = Random(9);
      final p = Player(
          name: 'a', age: 14, potential: 50, heightCm: 160, heightGenes: 0.5);
      final recent = <String>[];
      var repeats = 0;
      String? prev;
      for (var i = 0; i < 2000; i++) {
        final e = rollEvent(p, pro: false, rng: rng, recent: recent);
        if (e == null) continue;
        if (e.id == prev) repeats++;
        prev = e.id;
        recent.add(e.id);
        while (recent.length > 5) {
          recent.removeAt(0);
        }
      }
      expect(repeats, 0);
    });

    test('ゲームが最近の出来事を覚え、保存される', () {
      final g = Game(
        eventsEnabled: true,
        player: strong().copyWith(age: 14),
        rng: Random(2),
      );
      for (var i = 0; i < 40 && g.phase != Phase.retired; i++) {
        if (g.phase == Phase.event) g.resolveEvent(0);
        if (g.phase == Phase.season) g.choose(Action.rest, Ability.pass);
      }
      expect(g.recentEventIds.length, lessThanOrEqualTo(5));
      expect(Game.fromJson(g.toJson()).recentEventIds, g.recentEventIds);
    });

    test('ミニバスは年齢が低いほど勝ちやすい(序盤を勝てないままにしない)', () {
      double winRate(int age) {
        var wins = 0, games = 0;
        for (var seed = 0; seed < 300; seed++) {
          final g = Game(
            eventsEnabled: false,
            player: Player(
                name: 'a',
                age: age,
                potential: 50,
                heightCm: 110.0 + age * 5,
                heightGenes: 0.5),
            rng: Random(seed),
            slot: 1,
          );
          g.choose(Action.rest, Ability.pass);
          wins += g.records.single.wins;
          games += g.records.single.games;
        }
        return wins / games;
      }

      expect(winRate(6), greaterThan(0.45));
    });
  });
}
