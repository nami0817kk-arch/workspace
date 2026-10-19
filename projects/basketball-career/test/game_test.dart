import 'dart:math';

import 'package:basketball_career/game/advice.dart';
import 'package:basketball_career/game/career.dart';
import 'package:basketball_career/game/difficulty.dart';
import 'package:basketball_career/game/epilogue.dart';
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
import 'package:basketball_career/game/skills.dart';
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
            case Phase.halftime || Phase.clutch || Phase.event || Phase.retired:
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
            case Phase.halftime:
              g.resolveHalftime(Halftime.keep);
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

  group('出来事の内容とコーチとの信頼', () {
    test('出来事の id は重複せず、どれも2択以上で、選択肢に何か効果がある', () {
      final ids = events.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final e in events) {
        expect(e.options.length, greaterThanOrEqualTo(2), reason: e.id);
        expect(e.title, isNotEmpty);
        expect(e.body, isNotEmpty);
      }
      expect(events.length, greaterThanOrEqualTo(30));
    });

    test('どの年齢・段階でも、出来事の候補が十分にある', () {
      for (var age = 6; age <= maxProAge; age++) {
        for (final pro in [false, true]) {
          final p = Player(
              name: 'a', age: age, potential: 50, heightCm: 150, heightGenes: 0.5);
          final pool = [
            for (final e in events)
              if (age >= e.minAge && age <= e.maxAge && (!e.proOnly || pro)) e
          ];
          expect(pool.length, greaterThanOrEqualTo(6), reason: '$age歳 pro=$pro');
          expect(p.age, age);
        }
      }
    });

    test('ライバルの名前が文中に入る', () {
      final g = Game(
        eventsEnabled: false,
        player: strong().copyWith(age: 14),
        rng: Random(1),
        rival: Rival(name: '神谷リョウ', potential: 70),
        pendingEventId: 'rival_talk',
      );
      expect(g.fill(g.pendingEvent!.body), contains('神谷リョウ'));
      expect(g.fill(g.pendingEvent!.body), isNot(contains('{rival}')));
    });

    test('コーチとの面談で信頼が上がり、上限は100', () {
      final g = Game(
        eventsEnabled: false,
        player: strong().copyWith(age: 14),
        rng: Random(1),
        coachBond: 95,
        pendingEventId: 'coach_talk',
      );
      g.resolveEvent(0);
      expect(g.coachBond, 100);
    });

    test('信頼が高いほど伸びが大きい', () {
      double grow(int bond) {
        var total = 0;
        for (var seed = 0; seed < 80; seed++) {
          final g = Game(
            eventsEnabled: false,
            player: Player(
                name: 'a', age: 14, potential: 60, heightCm: 160, heightGenes: 0.5),
            rng: Random(seed),
            coachBond: bond,
          );
          final before = g.player.of(Ability.threePoint);
          g.choose(Action.practice, Ability.threePoint);
          total += g.player.of(Ability.threePoint) - before;
        }
        return total / 80;
      }

      expect(grow(100), greaterThan(grow(0)));
    });

    test('練習で信頼が増え、進学で新しいコーチに戻る。保存もされる', () {
      final g = Game(
        eventsEnabled: false,
        player: Player(
            name: 'a', age: 12, potential: 50, heightCm: 150, heightGenes: 0.5),
        rng: Random(1),
        coachBond: 60,
      );
      g.choose(Action.practice, Ability.pass);
      expect(g.coachBond, 61);
      expect(Game.fromJson(g.toJson()).coachBond, 61);
      for (var i = 0; i < 3; i++) {
        g.choose(Action.rest, Ability.pass);
      }
      expect(g.stage, Stage.juniorHigh);
      expect(g.coachBond, 20);
    });
  });

  group('エンディング', () {
    Game finished({bool abroad = false, bool pro = true}) {
      final g = Game(
        eventsEnabled: false,
        player: strong(height: 205).copyWith(age: 26),
        rng: Random(1),
        track: pro ? Track.pro : Track.school,
        abroad: abroad,
        rival: Rival(name: '神谷リョウ', potential: 70, wins: 4, losses: 2),
      );
      if (pro) {
        g.choose(Action.rest, Ability.pass);
        g.choose(Action.rest, Ability.pass);
        g.retire();
      } else {
        g.pathPending = true;
        g.giveUp();
      }
      return g;
    }

    test('称号は到達点で決まる', () {
      expect(careerTitle(finished(abroad: true)), contains('世界'));
      expect(careerTitle(finished()), contains('プロ'));
      expect(careerTitle(finished()), contains(positionNickname(Position.center)));
    });

    test('文章に生い立ち・ライバル・結末が入る', () {
      final g = finished();
      final lines = epilogueLines(g);
      final all = lines.join(' ');
      expect(all, contains('205cm'));
      expect(all, contains('神谷リョウ'));
      expect(all, contains('${g.rival.wins}勝${g.rival.losses}敗'));
      expect(all, contains('越えた'));
      expect(lines.length, greaterThanOrEqualTo(4));
    });

    test('殿堂に称号が残り、古い記録でも読める', () {
      final h = HistoryEntry.of(finished(abroad: true));
      expect(HistoryEntry.fromJson(h.toJson()).title, h.title);
      expect(HistoryEntry.fromJson({}).title, '');
    });
  });

  group('成長の軌跡と実績', () {
    test('年末ごとに総合評価と身長が記録され、保存される', () {
      final g = Game(
        eventsEnabled: false,
        player: Player(
            name: 'a', age: 12, potential: 50, heightCm: 150, heightGenes: 0.5),
        rng: Random(1),
      );
      for (var i = 0; i < 8; i++) {
        g.choose(Action.rest, Ability.pass);
      }
      expect(g.growthLog.length, 2);
      expect(g.growthLog.first.age, 12);
      expect(g.growthLog.last.age, 13);
      expect(g.growthLog.last.heightCm, greaterThan(g.growthLog.first.heightCm));
      final h = Game.fromJson(g.toJson());
      expect(h.growthLog.length, 2);
      expect(Game.fromJson({'player': {'name': 'old'}}).growthLog, isEmpty);
    });

    test('実績は20個以上で、id が重複しない', () {
      expect(achievements.length, greaterThanOrEqualTo(20));
      final ids = achievements.map((a) => a.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('全制覇はミニバス・中学・高校の優勝がそろったときだけ', () {
      YearRecord rec(League l, bool champion) => YearRecord(
          age: 12, league: l, wins: 3, games: 3, ppg: 10, rpg: 3, apg: 2,
          champion: champion, achievement: 80);
      final g = Game(eventsEnabled: false, player: strong(), rng: Random(1));
      g.records.addAll([rec(League.minibasket, true), rec(League.juniorHigh, true)]);
      expect(earnedBy(g).contains('grand_slam'), isFalse);
      g.records.add(rec(League.highSchool, true));
      expect(earnedBy(g).containsAll(['grand_slam', 'mini_king', 'jh_king', 'hs_king']), isTrue);
    });
  });

  group('契約の見込み', () {
    test('評価点で見込みが分かれる', () {
      expect(outlookOf(75), Outlook.sure);
      expect(outlookOf(65), Outlook.good);
      expect(outlookOf(57), Outlook.even);
      expect(outlookOf(45), Outlook.low);
      expect(outlookOf(20), Outlook.none);
    });

    test('見込みと実際の契約が食い違わない(確実なら必ず、難しいなら絶対に無理)', () {
      for (var i = 0; i < 100; i++) {
        final g = Game(
            eventsEnabled: false, player: strong(height: 205), rng: Random(i));
        if (g.outlook == Outlook.sure) {
          expect(winsContract(g.player, g.achievement, Random(i)), isTrue);
        }
        final w = Game(eventsEnabled: false, player: weak(), rng: Random(i));
        if (w.outlook == Outlook.none) {
          expect(winsContract(w.player, w.achievement, Random(i)), isFalse);
        }
      }
    });

    test('ゲームが現在の評価点と見込みを出す', () {
      final g = Game(eventsEnabled: false, player: strong(height: 205), rng: Random(1));
      expect(g.offerNow, offerScore(g.player, g.achievement));
      expect(g.outlook, outlookOf(g.offerNow));
    });
  });

  group('進学先の選択', () {
    Game at12({bool events = true}) => Game(
          eventsEnabled: events,
          player: Player(
              name: 'a', age: 12, potential: 60, heightCm: 150, heightGenes: 0.5),
          rng: Random(1),
        );

    void finishYear(Game g) {
      for (var i = 0; i < 4; i++) {
        if (g.phase == Phase.event) g.resolveEvent(0);
        g.choose(Action.rest, Ability.pass);
      }
    }

    test('中学に上がるとき、進学先の選択が必ず起きる', () {
      final g = at12();
      finishYear(g);
      expect(g.player.age, 13);
      // 年末の出来事(ランダム)が先に起きていても、解決すれば進学先が出る
      var guard = 0;
      while (g.pendingEventId != 'school_jh' && g.phase == Phase.event && guard++ < 5) {
        g.resolveEvent(0);
      }
      expect(g.pendingEventId, 'school_jh');
      expect(g.pendingEvent!.options.length, 3);
    });

    test('出来事を切っているときは起きない', () {
      final g = at12(events: false);
      finishYear(g);
      expect(g.phase, Phase.season);
    });

    test('強豪校は味方が強く、地元の学校は伸びのびやれる(気持ち・チームワーク)', () {
      final a = Game(
          eventsEnabled: false,
          player: strong().copyWith(age: 13),
          rng: Random(1),
          pendingEventId: 'school_jh');
      a.resolveEvent(0);
      expect(a.schoolBonus, greaterThan(0));
      expect(a.schoolLabel, '強豪校');
      final b = Game(
          eventsEnabled: false,
          player: strong().copyWith(age: 13),
          rng: Random(1),
          pendingEventId: 'school_jh');
      b.resolveEvent(1);
      expect(b.schoolBonus, lessThan(0));
      expect(b.teamwork, greaterThan(a.teamwork));
      expect(b.condition.morale, greaterThan(a.condition.morale));
    });

    test('環境は大会の味方の強さに入り、保存され、段階が変わると決め直しになる', () {
      final g = Game(
        eventsEnabled: false,
        player: Player(
            name: 'a', age: 12, potential: 50, heightCm: 150, heightGenes: 0.5),
        rng: Random(1),
        schoolBonus: 4,
        schoolLabel: '強豪校',
      );
      expect(Game.fromJson(g.toJson()).schoolBonus, 4);
      expect(Game.fromJson(g.toJson()).schoolLabel, '強豪校');
      for (var i = 0; i < 4; i++) {
        g.choose(Action.rest, Ability.pass);
      }
      expect(g.stage, Stage.juniorHigh);
      expect(g.schoolBonus, 0);
      expect(g.schoolLabel, '');
    });

    test('進学先の出来事はふだんの抽選には出ない', () {
      final rng = Random(4);
      final p = Player(
          name: 'a', age: 13, potential: 50, heightCm: 160, heightGenes: 0.5);
      for (var i = 0; i < 2000; i++) {
        final e = rollEvent(p, pro: false, rng: rng);
        expect(e?.forced ?? false, isFalse);
      }
    });
  });

  group('個人賞', () {
    MatchResult m(bool won, int pts, int reb, int ast) => MatchResult(
        won: won,
        teamScore: 70,
        oppScore: 60,
        points: pts,
        rebounds: reb,
        assists: ast);

    TournamentResult t(List<MatchResult> ms, {League l = League.highSchool}) =>
        TournamentResult(
            league: l,
            matches: ms,
            wins: ms.where((x) => x.won).length,
            achievement: 70);

    test('優勝して個人も高ければ最優秀選手、個人だけ高ければベスト5', () {
      final all = List.generate(5, (_) => m(true, 18, 7, 5));
      expect(t(all).champion, isTrue);
      expect(t(all).award, '最優秀選手');
      final lost = [...List.generate(3, (_) => m(true, 20, 8, 6)), m(false, 20, 8, 6)];
      expect(t(lost).champion, isFalse);
      expect(t(lost).award, 'ベスト5');
    });

    test('平凡な成績や1試合だけでは賞は出ない', () {
      expect(t(List.generate(3, (_) => m(true, 6, 2, 1))).award, isNull);
      expect(t([m(false, 30, 10, 8)]).award, isNull);
    });

    test('個人賞は年の記録に残り、保存される', () {
      final r = YearRecord(
          age: 17, league: League.highSchool, wins: 5, games: 5, ppg: 18, rpg: 7,
          apg: 5, champion: true, achievement: 90, award: '最優秀選手');
      expect(YearRecord.fromJson(r.toJson()).award, '最優秀選手');
      expect(YearRecord.fromJson({}).award, isNull);
    });

    test('実績: 最優秀選手・ベスト5の常連', () {
      YearRecord rec(String? a) => YearRecord(
          age: 15, league: League.juniorHigh, wins: 3, games: 3, ppg: 10, rpg: 3,
          apg: 2, champion: false, achievement: 60, award: a);
      final g = Game(eventsEnabled: false, player: strong(), rng: Random(1));
      g.records.addAll([rec('ベスト5'), rec('ベスト5')]);
      expect(earnedBy(g).contains('best5_x3'), isFalse);
      g.records.add(rec('最優秀選手'));
      expect(earnedBy(g).containsAll(['best5_x3', 'mvp']), isTrue);
    });
  });

  group('殿堂からの引き継ぎ', () {
    test('実績5個ごとに初期能力が+1(最大+5)', () {
      expect(legacyBonusFor(0), 0);
      expect(legacyBonusFor(4), 0);
      expect(legacyBonusFor(5), 1);
      expect(legacyBonusFor(12), 2);
      expect(legacyBonusFor(100), 5);
    });

    test('新しい選手の初期能力に加わる', () {
      final a = Game.start('a', rng: Random(1), legacyBonus: 0);
      final b = Game.start('a', rng: Random(1), legacyBonus: 3);
      for (final ab in Ability.values) {
        expect(b.player.of(ab), a.player.of(ab) + 3);
      }
    });
  });

  group('プロの入団先・移籍', () {
    Game proGame({int age = 21, bool events = true}) => Game(
          eventsEnabled: events,
          player: strong(height: 205).copyWith(age: age),
          rng: Random(1),
          pathPending: true,
        );

    test('プロ契約を勝ち取ると入団先を選ぶ', () {
      final g = proGame();
      expect(g.chooseRoute(Route.pro), isTrue);
      expect(g.pendingEventId, 'pro_join');
      expect(g.pendingEvent!.options.length, 3);
      g.resolveEvent(0);
      expect(g.schoolLabel, '強豪チーム');
      expect(g.phase, Phase.season);
    });

    test('出来事を切っていれば選ばない', () {
      final g = proGame(events: false);
      g.chooseRoute(Route.pro);
      expect(g.pendingEventId, isNull);
    });

    test('23歳で移籍のオファーが届き、選ぶと環境が変わる', () {
      final g = Game(
        eventsEnabled: true,
        player: strong(height: 205).copyWith(age: 22),
        rng: Random(1),
        track: Track.pro,
      );
      for (var i = 0; i < 4; i++) {
        if (g.phase == Phase.event) g.resolveEvent(1);
        if (g.phase == Phase.clutch) g.resolveClutch(Clutch.drive);
        g.choose(Action.rest, Ability.pass);
      }
      var guard = 0;
      while (g.pendingEventId != 'pro_move' && g.phase == Phase.event && guard++ < 5) {
        g.resolveEvent(1);
      }
      expect(g.player.age, 23);
      expect(g.pendingEventId, 'pro_move');
      g.resolveEvent(0);
      expect(g.schoolLabel, '強豪チーム');
    });

    test('入団・移籍の出来事はふだんの抽選に出ない', () {
      final rng = Random(8);
      final p = strong().copyWith(age: 25);
      for (var i = 0; i < 2000; i++) {
        final e = rollEvent(p, pro: true, rng: rng);
        expect(e?.forced ?? false, isFalse);
      }
    });
  });

  group('ポジションの持ち味', () {
    Player at(Position pos) {
      final h = switch (pos) {
        Position.center => 208.0,
        Position.powerForward => 197.0,
        Position.smallForward => 190.0,
        Position.shootingGuard => 184.0,
        Position.pointGuard => 176.0,
      };
      var p = strong(height: h);
      if (pos == Position.powerForward) {
        p = p.copyWith(abilities: {
          for (final a in Ability.values) a: 80,
          Ability.inside: 90,
          Ability.threePoint: 40,
        });
      }
      if (pos == Position.shootingGuard) {
        p = p.copyWith(abilities: {
          for (final a in Ability.values) a: 80,
          Ability.pass: 40,
          Ability.dribble: 60,
          Ability.threePoint: 90,
        });
      }
      return p;
    }

    test('身長と能力から5つのポジションそれぞれに当たる', () {
      for (final pos in Position.values) {
        expect(at(pos).position, pos, reason: pos.label);
        expect(pos.perk, isNotEmpty);
      }
    });

    test('シューターは3Pの勝負どころ、PFはドライブ、Cはディフェンスが決まりやすい', () {
      double chance(Position pos, Clutch c) =>
          clutchChance(at(pos), c, 50, 1) -
          clutchChance(at(pos).copyWith(heightCm: pos == Position.shootingGuard ? 184 : 200), c, 50, 1);
      // 持ち味の分は、同じ能力でも他ポジションより高い
      final sg = clutchChance(at(Position.shootingGuard), Clutch.threePoint, 50, 1);
      final sgOther = clutchChance(
          at(Position.shootingGuard).copyWith(heightCm: 190), Clutch.threePoint, 50, 1);
      expect(sg, greaterThan(sgOther));
      expect(chance(Position.center, Clutch.defend), isNotNull);
      final cDef = clutchChance(at(Position.center), Clutch.defend, 50, 1);
      final cNoPerk = clutchChance(at(Position.center).copyWith(heightCm: 190), Clutch.defend, 50, 1);
      expect(cDef, greaterThan(cNoPerk));
    });

    test('PGはチームワークの効きが大きい', () {
      final pg = Game(eventsEnabled: false, player: at(Position.pointGuard), rng: Random(1), teamwork: 100);
      final sf = Game(eventsEnabled: false, player: at(Position.smallForward), rng: Random(1), teamwork: 100);
      expect(pg.teamBonus, greaterThan(sf.teamBonus));
    });

    test('センターはリバウンドが多い', () {
      double rpg(Position pos) {
        var total = 0;
        for (var i = 0; i < 200; i++) {
          total += playQuarters(at(pos), teamStrength: 50, oppStrength: 50, form: 1, rng: Random(i)).rebounds;
        }
        return total / 200;
      }

      expect(rpg(Position.center), greaterThan(rpg(Position.pointGuard)));
    });

    test('SFは大会での動きの良さに加算がある', () {
      final sf = Game(eventsEnabled: false, player: at(Position.smallForward), rng: Random(1));
      expect(sf.formNow, sf.condition.form + 0.03);
      final pg = Game(eventsEnabled: false, player: at(Position.pointGuard), rng: Random(1));
      expect(pg.formNow, pg.condition.form);
    });
  });

  group('プロ・海外の出来事', () {
    test('海外限定の出来事は、国内プロや学生には出ない', () {
      final rng = Random(5);
      final p = strong().copyWith(age: 25);
      var seenAbroad = false;
      for (var i = 0; i < 3000; i++) {
        final dom = rollEvent(p, pro: true, abroad: false, rng: rng);
        expect(dom?.abroadOnly ?? false, isFalse);
        final stu = rollEvent(p, pro: false, abroad: false, rng: rng);
        expect(stu?.proOnly ?? false, isFalse);
        final ab = rollEvent(p, pro: true, abroad: true, rng: rng);
        if (ab?.abroadOnly ?? false) seenAbroad = true;
      }
      expect(seenAbroad, isTrue);
    });

    test('30歳以上のプロには「衰えとの向き合い」が出うる。若いうちは出ない', () {
      final rng = Random(6);
      var old = false;
      for (var i = 0; i < 3000; i++) {
        final y = rollEvent(strong().copyWith(age: 24), pro: true, rng: rng);
        expect(y?.id == 'aging', isFalse);
        if (rollEvent(strong().copyWith(age: 33), pro: true, rng: rng)?.id == 'aging') old = true;
      }
      expect(old, isTrue);
    });
  });

  group('怪我の種類', () {
    test('軽い怪我ほど多く、骨折はまれ', () {
      final rng = Random(3);
      final count = <Injury, int>{for (final i in Injury.values) i: 0};
      for (var i = 0; i < 5000; i++) {
        final k = rollInjury(rng);
        count[k] = count[k]! + 1;
      }
      expect(count[Injury.sprain]!, greaterThan(count[Injury.strain]!));
      expect(count[Injury.strain]!, greaterThan(count[Injury.fracture]!));
      expect(count[Injury.fracture]!, greaterThan(0));
    });

    test('休む期間は種類ごとの範囲に入る', () {
      final rng = Random(4);
      for (final k in Injury.values) {
        for (var i = 0; i < 200; i++) {
          final t = k.terms(rng);
          expect(t, inInclusiveRange(k.minTerms, k.maxTerms));
        }
      }
      expect(Injury.fracture.minTerms, greaterThan(Injury.strain.maxTerms - 1));
    });

    test('大怪我の後遺症: スピードとフィジカルが落ちる。ほかは変わらない', () {
      final a = {for (final x in Ability.values) x: 70};
      final b = applyLastingInjury(a);
      expect(b[Ability.speed], 67);
      expect(b[Ability.physical], 67);
      expect(b[Ability.pass], 70);
      expect(Injury.fracture.lasting, isTrue);
      expect(Injury.sprain.lasting, isFalse);
    });

    test('怪我をすると名前が付き、治ると消える。保存される', () {
      var injured = false;
      for (var seed = 0; seed < 400 && !injured; seed++) {
        final p = strong();
        final r = playTerm(
            p,
            const Condition(fatigue: 90),
            Action.intense,
            Ability.pass,
            Random(seed));
        if (r.gotInjured) {
          injured = true;
          expect(r.condition.injured, isTrue);
          expect(r.condition.injuryName, isNotEmpty);
          expect(
              Condition.fromJson(r.condition.toJson()).injuryName,
              r.condition.injuryName);
          final healed = r.condition.copyWith(injuredTerms: 0);
          expect(healed.injuryName, '');
        }
      }
      expect(injured, isTrue);
    });

    test('古いセーブ(怪我の名前なし)でも読める', () {
      final c = Condition.fromJson({'fatigue': 5, 'morale': 50, 'injuredTerms': 2});
      expect(c.injured, isTrue);
      expect(c.injuryName, '');
    });
  });

  group('まれな出来事', () {
    test('重みの小さい出来事は、普通の出来事より少ない', () {
      final rng = Random(12);
      final p = strong().copyWith(age: 16);
      final count = <String, int>{};
      for (var i = 0; i < 20000; i++) {
        final e = rollEvent(p, pro: false, rng: rng);
        if (e != null) count[e.id] = (count[e.id] ?? 0) + 1;
      }
      final rare = (count['breakthrough'] ?? 0) + (count['legend_visit'] ?? 0);
      final normal = (count['friends'] ?? 0) + (count['video'] ?? 0);
      expect(rare, greaterThan(0));
      expect(rare, lessThan(normal), reason: 'まれ');
      expect(events.where((e) => e.weight < 1).length, greaterThanOrEqualTo(2));
    });

    test('ひらめきで重点の能力が大きく伸びる', () {
      final g = Game(
        eventsEnabled: false,
        player: strong().copyWith(age: 15),
        rng: Random(1),
        pendingEventId: 'breakthrough',
      );
      g.lastFocus = Ability.dribble;
      final before = g.player.of(Ability.dribble);
      g.resolveEvent(0);
      expect(g.player.of(Ability.dribble), before + 4);
    });
  });

  group('ライバルのその後', () {
    test('素質で結末が変わり、名前が入る', () {
      final fates = {
        for (final pot in [90, 75, 60, 40])
          Rival(name: '神谷リョウ', potential: pot).fate
      };
      expect(fates.length, 4, reason: '4通り');
      for (final f in fates) {
        expect(f, contains('神谷リョウ'));
      }
    });

    test('対戦があったときだけ、エンディングで語られる', () {
      Game ended(int wins) {
        final g = Game(
          eventsEnabled: false,
          player: strong().copyWith(age: 25),
          rng: Random(1),
          track: Track.pro,
          rival: Rival(name: '氷室シン', potential: 90, wins: wins, losses: 0),
        );
        g.retire();
        return g;
      }

      expect(epilogueLines(ended(2)).join(' '), contains('世界最高峰'));
      expect(epilogueLines(ended(0)).join(' '), isNot(contains('氷室シン')));
    });
  });

  group('おすすめの過ごし方', () {
    Game g({Condition c = const Condition(), int tw = 50, int slot = 1, int age = 12}) =>
        Game(
          eventsEnabled: false,
          player: Player(
              name: 'a', age: age, potential: 60, heightCm: 150, heightGenes: 0.5),
          rng: Random(1),
          condition: c,
          teamwork: tw,
          slot: slot,
        );

    test('怪我・疲れなら休養、気持ちが沈めば交流', () {
      expect(recommendedAction(g(c: const Condition(injuredTerms: 2))), Action.rest);
      expect(recommendedAction(g(c: const Condition(fatigue: 80))), Action.rest);
      expect(recommendedAction(g(c: const Condition(morale: 20))), Action.social);
    });

    test('チームワークが薄れたら、練習試合(疲れていれば交流)', () {
      expect(recommendedAction(g(tw: 10)), Action.scrimmage);
      expect(recommendedAction(g(tw: 10, c: const Condition(fatigue: 55))), Action.social);
    });

    test('疲れが軽ければ特訓。ただし大会の前の季節は避ける', () {
      expect(recommendedAction(g(slot: 1)), Action.intense);
      expect(recommendedAction(g(slot: 0)), Action.practice);
      expect(recommendedAction(g(slot: 2, age: 17)), Action.practice, reason: '高校は冬の大会がある');
      expect(recommendedAction(g(slot: 2, age: 12)), Action.intense, reason: '小学生は冬の大会がない');
    });

    test('同じ練習が続いてマンネリなら別の練習に替える', () {
      final x = g(c: const Condition(fatigue: 40), slot: 1);
      x.recentActions.addAll([Action.practice, Action.practice]);
      expect(recommendedAction(x), isNot(Action.practice));
      expect(x.isRut(recommendedAction(x)), isFalse);
    });

    test('それ以外は練習', () {
      expect(recommendedAction(g(c: const Condition(fatigue: 40), slot: 1)), Action.practice);
    });
  });

  group('通算と共有', () {
    Game withRecords() {
      final g = Game(
        eventsEnabled: false,
        player: strong(height: 205).copyWith(age: 26),
        rng: Random(1),
        track: Track.pro,
        rival: Rival(name: '神谷リョウ', potential: 70, wins: 3, losses: 2),
      );
      g.records.addAll([
        YearRecord(age: 24, league: League.proDomestic, wins: 4, games: 6, ppg: 20, rpg: 8, apg: 5, champion: false, achievement: 70, award: 'ベスト5'),
        YearRecord(age: 25, league: League.proDomestic, wins: 6, games: 6, ppg: 10, rpg: 4, apg: 2, champion: true, achievement: 90),
      ]);
      g.retire();
      return g;
    }

    test('通算の得点・リバウンド・アシストは年ごとの平均×試合数の合計', () {
      final g = withRecords();
      expect(g.totalPoints, 20 * 6 + 10 * 6);
      expect(g.totalRebounds, 8 * 6 + 4 * 6);
      expect(g.totalAssists, 5 * 6 + 2 * 6);
      expect(g.awardCount, 1);
    });

    test('共有用の文章に称号・通算・ライバルが入る', () {
      final g = withRecords();
      final t = shareText(g);
      expect(t, contains(careerTitle(g)));
      expect(t, contains('${g.totalPoints}得点'));
      expect(t, contains('神谷リョウ'));
      expect(t, contains('3勝2敗'));
      expect(t, contains('#バスケ育成'));
    });
  });

  group('マンネリ', () {
    Game g0() => Game(
        eventsEnabled: false,
        player: Player(name: 'a', age: 12, potential: 60, heightCm: 150, heightGenes: 0.5),
        rng: Random(1));

    test('同じ練習を3回続けるとマンネリ。休養・交流は対象外', () {
      final g = g0();
      expect(g.isRut(Action.practice), isFalse);
      g.choose(Action.practice, Ability.pass);
      expect(g.isRut(Action.practice), isFalse, reason: '2回目まではまだ');
      g.choose(Action.practice, Ability.pass);
      expect(g.isRut(Action.practice), isTrue);
      expect(g.isRut(Action.intense), isFalse, reason: '違う練習なら大丈夫');
      expect(g.isRut(Action.rest), isFalse);
      expect(g.isRut(Action.social), isFalse);
    });

    test('マンネリの回は伸びが小さい。別の練習を挟めば戻る', () {
      double grow(List<Action> before, Action a) {
        var total = 0;
        for (var seed = 0; seed < 120; seed++) {
          final g = Game(
              eventsEnabled: false,
              player: Player(name: 'a', age: 12, potential: 60, heightCm: 150, heightGenes: 0.5),
              rng: Random(seed));
          g.recentActions.addAll(before);
          final b = Ability.values.fold(0, (s, x) => s + g.player.of(x));
          g.choose(a, Ability.threePoint);
          total += Ability.values.fold(0, (s, x) => s + g.player.of(x)) - b;
        }
        return total / 120;
      }

      final rut = grow([Action.practice, Action.practice], Action.practice);
      final fresh = grow([Action.practice, Action.intense], Action.practice);
      expect(rut, lessThan(fresh));
    });

    test('直近3つだけ覚え、保存される。マンネリの知らせが出る', () {
      final g = g0();
      for (final a in [Action.practice, Action.intense, Action.study, Action.rest]) {
        g.choose(a, Ability.pass);
      }
      expect(g.recentActions.length, lessThanOrEqualTo(3));
      expect(Game.fromJson(g.toJson()).recentActions, g.recentActions);
      final h = g0();
      h.choose(Action.practice, Ability.pass);
      h.choose(Action.practice, Ability.pass);
      h.choose(Action.practice, Ability.pass);
      expect(h.lastWasRut, isTrue);
    });
  });

  group('チームメイトとコーチの名前', () {
    test('始めると名前がつき、出来事の文に入る', () {
      final g = Game.start('a', rng: Random(3), events: false);
      expect(g.mate, isNotEmpty);
      expect(g.coachLabel, isNotEmpty);
      g.pendingEventId = 'friends';
      expect(g.fill(g.pendingEvent!.body), contains(g.mate));
      g.pendingEventId = 'coach_talk';
      expect(g.fill(g.pendingEvent!.body), contains('${g.coachLabel}コーチ'));
      for (final e in events) {
        expect(g.fill(e.body), isNot(contains('{')), reason: e.id);
      }
    });

    test('名前が無い古いセーブでも自然な文になる', () {
      final g = Game.fromJson({'player': {'name': 'old'}, 'pendingEventId': 'friends'});
      expect(g.fill(g.pendingEvent!.body), contains('仲間'));
      expect(g.fill('{coach}'), 'コーチ');
    });

    test('進学すると新しい名前になり、保存される', () {
      final g = Game(
        eventsEnabled: false,
        player: Player(name: 'a', age: 12, potential: 50, heightCm: 150, heightGenes: 0.5),
        rng: Random(4),
        mate: '旧チーム',
        coachLabel: '旧',
      );
      for (var i = 0; i < 4; i++) {
        g.choose(Action.rest, Ability.pass);
      }
      expect(g.stage, Stage.juniorHigh);
      expect(g.mate, isNot('旧チーム'));
      expect(Game.fromJson(g.toJson()).mate, g.mate);
      expect(Game.fromJson(g.toJson()).coachLabel, g.coachLabel);
    });
  });

  group('エンディングの感謝', () {
    String end({int coach = 20, int tw = 40, String mate = '佐野タクミ', String label = '大島'}) {
      final g = Game(
        eventsEnabled: false,
        player: strong().copyWith(age: 25),
        rng: Random(1),
        track: Track.pro,
        coachBond: coach,
        teamwork: tw,
        mate: mate,
        coachLabel: label,
      )..retire();
      return epilogueLines(g).join(' ');
    }

    test('信頼・チームワークが高いときだけ、コーチと仲間への一言が入る', () {
      expect(end(), isNot(contains('大島コーチ')));
      expect(end(), isNot(contains('佐野タクミ')));
      expect(end(coach: 80), contains('大島コーチへの感謝'));
      expect(end(tw: 80), contains('佐野タクミとは'));
    });

    test('名前が無いセーブでは、入れない', () {
      expect(end(coach: 90, tw: 90, mate: '', label: ''), isNot(contains('感謝')));
    });
  });

  group('エンディングの文章の質', () {
    test('年齢が重複しない(「41歳、41歳で…」にならない)', () {
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
      final text = epilogueLines(g).join(' ');
      final age = g.player.age;
      expect(RegExp('$age歳、$age歳').hasMatch(text), isFalse);
      expect('歳'.allMatches(text).length, greaterThan(0));
    });

    test('古いセーブの理由(年齢入り)でも重複しない', () {
      final g = Game(
        eventsEnabled: false,
        player: strong().copyWith(age: 41),
        rng: Random(1),
        track: Track.pro,
        retiredReason: '41歳で現役を退いた',
      );
      final text = epilogueLines(g).join(' ');
      expect(text.contains('41歳、41歳'), isFalse);
      expect(text, contains('41歳で現役を退いた'));
    });

    test('全盛期は、実績が同程度なら格上の舞台を選ぶ', () {
      YearRecord rec(int age, League l, double ach) => YearRecord(
          age: age, league: l, wins: 3, games: 4, ppg: 12, rpg: 4, apg: 3,
          champion: false, achievement: ach);
      final g = Game(
        eventsEnabled: false,
        player: strong().copyWith(age: 30),
        rng: Random(1),
        track: Track.pro,
      );
      g.records.addAll([
        rec(10, League.minibasket, 70),
        rec(26, League.proAbroad, 60),
      ]);
      g.retire();
      final text = epilogueLines(g).join(' ');
      expect(text, contains('26歳'));
      expect(text, contains('海外プロ'));
    });
  });

  group('フリースローとファウルをもらう', () {
    Player shooter(int ft) => strong().copyWith(abilities: {
          for (final a in Ability.values) a: 70,
          Ability.freeThrow: ft,
        });

    test('フリースロー力が高いほど入り、ファウルをもらうの成功率が上がる', () {
      expect(freeThrowChance(shooter(90), 1), greaterThan(freeThrowChance(shooter(30), 1)));
      expect(clutchChance(shooter(90), Clutch.drawFoul, 50, 1),
          greaterThan(clutchChance(shooter(30), Clutch.drawFoul, 50, 1)));
    });

    test('相手の守備が強いほどファウルを誘いにくい', () {
      final p = shooter(70);
      expect(foulDrawChance(p, 30), greaterThan(foulDrawChance(p, 90)));
    });

    test('フリースロー2本の結果が得点に入る(0〜2点)。2本とも入れば成功', () {
      final s = MatchState(
        team: 60, opp: 61, points: 10, rebounds: 4, assists: 3,
        teamStrength: 60, oppStrength: 60, form: 1,
        teamQuarters: const [15, 15, 15, 15], oppQuarters: const [15, 15, 15, 16],
      );
      final scored = <int>{};
      var okCount = 0;
      for (var seed = 0; seed < 300; seed++) {
        final r = finishMatch(shooter(90), s, Clutch.drawFoul, Random(seed));
        final gained = r.points - s.points;
        scored.add(gained);
        expect(gained, inInclusiveRange(0, 2));
        if (r.clutchSuccess == true) {
          okCount++;
          expect(gained, 2);
        }
      }
      expect(scored, {0, 1, 2}, reason: '0・1・2点のどれも起きる');
      expect(okCount, greaterThan(0));
    });

    test('おまかせでは、フリースローが上手く外が苦手な選手はファウルを選ぶことがある', () {
      final p = strong(height: 180).copyWith(abilities: {
        for (final a in Ability.values) a: 40,
        Ability.freeThrow: 99,
        Ability.physical: 99,
        Ability.dribble: 99,
      });
      expect(bestClutch(p, 50, 1), Clutch.drawFoul);
    });

    test('フリースローは能力に加わり、古いセーブでは初期値になる', () {
      expect(Ability.freeThrow.label, 'フリースロー');
      final old = Player.fromJson({
        'name': 'old',
        'abilities': {'pass': 50},
      });
      expect(old.of(Ability.freeThrow), startLevel);
    });
  });

  group('得意技', () {
    Player build({double h = 190, Map<Ability, int> ab = const {}}) => Player(
          name: 'a', age: 17, potential: 70, heightCm: h, heightGenes: 0.5,
          abilities: {for (final a in Ability.values) a: 40, ...ab},
        );

    test('条件を満たす得意技だけが身につく', () {
      final shooter = build(ab: {Ability.threePoint: 82, Ability.dribble: 60});
      final got = newlyQualified(shooter);
      expect(got, containsAll([Skill.stepBack, Skill.sniper]));
      expect(got.contains(Skill.postHook), isFalse);
      expect(newlyQualified(build()), isEmpty, reason: '能力が低ければ何も無い');
    });

    test('身長で分かれる: フローターは低め、ポストフックは高さが要る', () {
      final ab = {Ability.inside: 70, Ability.dribble: 65};
      expect(Skill.floater.qualifies(build(h: 185, ab: ab)), isTrue);
      expect(Skill.floater.qualifies(build(h: 205, ab: ab)), isFalse);
      expect(Skill.postHook.qualifies(build(h: 205, ab: ab)), isTrue);
      expect(Skill.postHook.qualifies(build(h: 185, ab: ab)), isFalse);
    });

    test('得意技は対応する勝負どころの成功率を上げる。関係ないものは変えない', () {
      final base = build(ab: {Ability.threePoint: 70, Ability.dribble: 60});
      final withSkill = base.copyWith(skills: {Skill.stepBack});
      expect(clutchChance(withSkill, Clutch.threePoint, 50, 1),
          greaterThan(clutchChance(base, Clutch.threePoint, 50, 1)));
      expect(clutchChance(withSkill, Clutch.pass, 50, 1),
          clutchChance(base, Clutch.pass, 50, 1));
      final ft = build(ab: {Ability.freeThrow: 80}).copyWith(skills: {Skill.clutchShooter});
      expect(clutchChance(ft, Clutch.drawFoul, 50, 1),
          greaterThan(clutchChance(ft.copyWith(skills: {}), Clutch.drawFoul, 50, 1)));
    });

    test('ハンドラーは大会の味方の強さに効く', () {
      final g = Game(eventsEnabled: false, player: build(), rng: Random(1));
      final h = Game(
          eventsEnabled: false,
          player: build().copyWith(skills: {Skill.handler}),
          rng: Random(1));
      expect(h.teamBonus - g.teamBonus, closeTo(1.0, 1e-9));
    });

    test('ターンの終わりに条件を満たしたら身につき、知らせが残る。保存もされる', () {
      final g = Game(
        eventsEnabled: false,
        player: build(ab: {Ability.threePoint: 79, Ability.dribble: 60}),
        rng: Random(1),
      );
      // 3P を重点に練習して 80 に届くまで。
      var learned = false;
      for (var i = 0; i < 12 && !learned; i++) {
        g.choose(Action.practice, Ability.threePoint);
        if (g.lastNewSkills.isNotEmpty) learned = true;
        if (g.phase == Phase.clutch) g.resolveClutch(Clutch.drive);
      }
      expect(g.player.skills, isNotEmpty);
      expect(Game.fromJson(g.toJson()).player.skills, g.player.skills);
    });

    test('出来事で能力が上がって得意技が身につく', () {
      final g = Game(
        eventsEnabled: false,
        player: build(ab: {Ability.freeThrow: 73}),
        rng: Random(1),
        pendingEventId: 'ft_practice',
      );
      g.resolveEvent(0);
      expect(g.player.skills, contains(Skill.clutchShooter));
      expect(g.lastNewSkills, contains(Skill.clutchShooter));
    });

    test('古いセーブ(得意技なし)でも読める。得意技の名前が不明でも落ちない', () {
      expect(Player.fromJson({'name': 'old'}).skills, isEmpty);
      expect(Player.fromJson({'name': 'x', 'skills': ['stepBack', 'ふめい']}).skills, {Skill.stepBack});
    });

    test('エンディングと共有の文に得意技が入る', () {
      final g = Game(
        eventsEnabled: false,
        player: build().copyWith(age: 30, skills: {Skill.stepBack, Skill.sniper}),
        rng: Random(1),
        track: Track.pro,
      )..retire();
      expect(epilogueLines(g).join(' '), contains('ステップバック3'));
      expect(shareText(g), contains('得意技'));
    });

    test('5つで実績「技の百貨店」', () {
      final g = Game(
        eventsEnabled: false,
        player: build().copyWith(skills: {...Skill.values.take(5)}),
        rng: Random(1),
      );
      expect(earnedBy(g), contains('skills5'));
    });

    test('どの得意技にも条件・説明・効果がある', () {
      for (final k in Skill.values) {
        expect(k.label, isNotEmpty);
        expect(k.description, isNotEmpty);
        final hasEffect = Clutch.values.any((c) => k.clutchBonus(c) > 0) || k.teamBonus > 0;
        expect(hasEffect, isTrue, reason: k.name);
      }
    });
  });

  group('スタッツ(スティール・ブロック・3P・キャリアハイ)', () {
    double avg(Player p, int Function(MatchState) pick) {
      var t = 0;
      for (var i = 0; i < 400; i++) {
        t += pick(playQuarters(p, teamStrength: 55, oppStrength: 55, form: 1, rng: Random(i)));
      }
      return t / 400;
    }

    Player build(double h, Map<Ability, int> ab) => Player(
          name: 'a', age: 20, potential: 70, heightCm: h, heightGenes: 0.5,
          abilities: {for (final a in Ability.values) a: 50, ...ab},
        );

    test('背が高く守りが強いほどブロックが多い', () {
      final big = build(208, {Ability.defense: 85});
      final guard = build(176, {Ability.defense: 85});
      expect(avg(big, (s) => s.blocks), greaterThan(avg(guard, (s) => s.blocks)));
    });

    test('守りと足があるほどスティールが多い', () {
      final thief = build(180, {Ability.defense: 85, Ability.speed: 85});
      final slow = build(180, {Ability.defense: 30, Ability.speed: 30});
      expect(avg(thief, (s) => s.steals), greaterThan(avg(slow, (s) => s.steals)));
    });

    test('3Pが得意な選手ほど3Pを多く決め、センターは少ない', () {
      final sniper = build(188, {Ability.threePoint: 90, Ability.inside: 40});
      final post = build(208, {Ability.threePoint: 30, Ability.inside: 90});
      expect(avg(sniper, (s) => s.threes), greaterThan(avg(post, (s) => s.threes)));
    });

    test('勝負どころで3Pを決めると3P本数に1加わる', () {
      final s = MatchState(
        team: 60, opp: 61, points: 10, rebounds: 4, assists: 3, threes: 2,
        teamStrength: 60, oppStrength: 60, form: 1,
        teamQuarters: const [15, 15, 15, 15], oppQuarters: const [15, 15, 15, 16],
      );
      final p = build(190, {Ability.threePoint: 99});
      for (var seed = 0; seed < 100; seed++) {
        final r = finishMatch(p, s, Clutch.threePoint, Random(seed));
        expect(r.threes, r.clutchSuccess == true ? 3 : 2);
      }
    });

    test('年の記録に集計され、キャリアハイと通算が出る。保存される', () {
      final g = Game(eventsEnabled: false, player: strong(), rng: Random(1));
      g.records.addAll([
        YearRecord(age: 15, league: League.juniorHigh, wins: 3, games: 3, ppg: 10, rpg: 3, apg: 2, champion: false, achievement: 60, steals: 4, blocks: 1, threes: 6, highPoints: 18),
        YearRecord(age: 16, league: League.highSchool, wins: 3, games: 4, ppg: 12, rpg: 4, apg: 2, champion: false, achievement: 65, steals: 5, blocks: 2, threes: 7, highPoints: 31),
      ]);
      expect(g.totalSteals, 9);
      expect(g.totalBlocks, 3);
      expect(g.totalThrees, 13);
      expect(g.careerHigh, (points: 31, age: 16));
      expect(earnedBy(g), contains('big_game'));
      final h = Game.fromJson(g.toJson());
      expect(h.careerHigh, g.careerHigh);
      expect(Game.fromJson({'player': {'name': 'old'}}).careerHigh, isNull);
    });

    test('大会の合計は試合の合計。1試合の最多得点が入る', () {
      MatchResult m(int pts, int st, int bl, int th) => MatchResult(
          won: true, teamScore: 70, oppScore: 60, points: pts, rebounds: 3,
          assists: 2, steals: st, blocks: bl, threes: th);
      final t = TournamentResult(
          league: League.highSchool,
          matches: [m(8, 2, 0, 1), m(24, 1, 3, 4), m(12, 0, 1, 0)],
          wins: 3,
          achievement: 70);
      expect(t.steals, 3);
      expect(t.blocks, 4);
      expect(t.threes, 5);
      expect(t.highPoints, 24);
    });

    test('エンディングにキャリアハイが入る(20点以上のとき)', () {
      final g = Game(
        eventsEnabled: false,
        player: strong().copyWith(age: 30),
        rng: Random(1),
        track: Track.pro,
      );
      g.records.add(YearRecord(age: 27, league: League.proDomestic, wins: 4, games: 6, ppg: 15, rpg: 5, apg: 3, champion: false, achievement: 70, highPoints: 34));
      g.retire();
      expect(epilogueLines(g).join(' '), contains('キャリアハイは27歳の34得点'));
      expect(shareText(g), contains('キャリアハイ34点'));
    });
  });

  group('ハーフタイムの作戦', () {
    Player pl({int ovr = 60, int stamina = 60}) => Player(
          name: 'a', age: 17, potential: 70, heightCm: 188, heightGenes: 0.5,
          abilities: {for (final a in Ability.values) a: ovr, Ability.stamina: stamina},
        );

    MatchHalf half(Player p, int seed, {double opp = 55}) => playFirstHalf(p,
        teamStrength: 55, oppStrength: opp, form: 1, rng: Random(seed));

    ({double mean, double sd, double pts}) second(Player p, Halftime h) {
      final margins = <int>[];
      var pts = 0;
      for (var i = 0; i < 600; i++) {
        final f = half(p, i);
        final s = playSecondHalf(p, f, h, Random(10000 + i));
        margins.add((s.team - s.opp) - f.margin); // 後半だけの点差
        pts += s.points;
      }
      final mean = margins.reduce((a, b) => a + b) / margins.length;
      final v = margins.fold(0.0, (a, m) => a + (m - mean) * (m - mean)) / margins.length;
      return (mean: mean, sd: sqrt(v), pts: pts / 600);
    }

    test('ペースを上げるとばらつきが大きく、守りを固めると小さい', () {
      final p = pl();
      final keep = second(p, Halftime.keep).sd;
      expect(second(p, Halftime.tempo).sd, greaterThan(keep));
      expect(second(p, Halftime.defense).sd, lessThan(keep));
    });

    test('エースに任せると、自分の得点とチームの点差が伸びる(スタミナと総合力があるほど)', () {
      final strongP = pl(ovr: 80, stamina: 85);
      final keep = second(strongP, Halftime.keep);
      final star = second(strongP, Halftime.star);
      expect(star.pts, greaterThan(keep.pts));
      expect(star.mean, greaterThan(keep.mean));
      // 力のない選手は、効きが小さい
      final weakP = pl(ovr: 35, stamina: 30);
      expect(starPower(weakP), lessThan(starPower(strongP)));
    });

    test('前半だけ進めても、前半の得点・点差が決まり、後半で4クォーターになる', () {
      final p = pl();
      final h = half(p, 3);
      expect(h.teamQuarters, hasLength(2));
      final s = playSecondHalf(p, h, Halftime.keep, Random(1));
      expect(s.teamQuarters, hasLength(4));
      expect(s.teamQuarters.take(2), h.teamQuarters);
      expect(s.team, s.teamQuarters.reduce((a, b) => a + b));
    });

    test('点差が12点以内のときだけ作戦を選ぶ価値がある', () {
      MatchHalf h(int t, int o) => MatchHalf(
          team: t, opp: o, teamQuarters: const [], oppQuarters: const [],
          mine: 50, oppStrength: 50, form: 1, share: 0.15,
          rebounds: 0, assists: 0, steals: 0, blocks: 0);
      expect(h(40, 30).needsDecision, isTrue);
      expect(h(40, 28).needsDecision, isTrue);
      expect(h(45, 28).needsDecision, isFalse);
      expect(h(20, 40).needsDecision, isFalse);
    });

    test('自動の作戦: 追っていればペース、リードなら守り', () {
      final p = pl(ovr: 40, stamina: 40);
      MatchHalf h(int t, int o) => MatchHalf(
          team: t, opp: o, teamQuarters: const [], oppQuarters: const [],
          mine: 50, oppStrength: 50, form: 1, share: 0.15,
          rebounds: 0, assists: 0, steals: 0, blocks: 0);
      expect(bestHalftime(p, h(30, 40)), Halftime.tempo);
      expect(bestHalftime(p, h(40, 30)), Halftime.defense);
    });

    test('前半の保存・復元で値が変わらない', () {
      final h = half(pl(), 5);
      final j = MatchHalf.fromJson(h.toJson());
      expect(j.team, h.team);
      expect(j.share, h.share);
      expect(j.teamQuarters, h.teamQuarters);
      expect(Halftime.parse('tempo'), Halftime.tempo);
      expect(Halftime.parse('なにか'), isNull);
    });

    Game summer(int seed) => Game(
          eventsEnabled: false,
          player: strong().copyWith(age: 15),
          rng: Random(seed),
          slot: 1,
        );

    int halftimeSeed() {
      for (var seed = 0; seed < 400; seed++) {
        final g = summer(seed);
        g.choose(Action.rest, Ability.pass, askClutch: true, askHalftime: true);
        if (g.phase == Phase.halftime) return seed;
      }
      throw StateError('ハーフタイムで止まる乱数が見つからない');
    }

    test('askHalftime なら点差が近い試合のハーフタイムで止まり、選ぶと続く', () {
      final g = summer(halftimeSeed());
      final r = g.choose(Action.rest, Ability.pass, askClutch: true, askHalftime: true);
      expect(r.paused, isTrue);
      expect(g.phase, Phase.halftime);
      expect(g.slot, 1);
      expect(g.halftimeInfo!.margin.abs(), lessThanOrEqualTo(12));
      expect(() => g.choose(Action.rest, Ability.pass), throwsStateError);
      var guard = 0;
      while ((g.phase == Phase.halftime || g.phase == Phase.clutch) && guard++ < 30) {
        if (g.phase == Phase.halftime) {
          g.resolveHalftime(Halftime.tempo);
        } else {
          g.resolveClutch(Clutch.drive);
        }
      }
      expect(g.slot, 2);
      expect(g.records, hasLength(1));
    });

    test('止まっていないときに選ぶと StateError', () {
      expect(() => summer(0).resolveHalftime(Halftime.keep), throwsStateError);
    });

    test('askHalftime を指定しなければ止まらない。勝負どころを固定した場合も止まらない', () {
      for (var seed = 0; seed < 60; seed++) {
        final g = summer(seed);
        g.choose(Action.rest, Ability.pass, askClutch: true);
        expect(g.phase, isNot(Phase.halftime));
        final h = summer(seed);
        h.choose(Action.rest, Ability.pass,
            askClutch: true, askHalftime: true, chooseClutch: (_) => Clutch.pass);
        expect(h.phase, isNot(Phase.halftime));
        expect(h.phase, isNot(Phase.clutch));
      }
    });

    test('ハーフタイムで止まっていても、保存して読み戻して続けられる(大会の設定も保つ)', () {
      final g = summer(halftimeSeed());
      g.choose(Action.rest, Ability.pass, askClutch: true, askHalftime: true);
      final h = Game.fromJson(g.toJson());
      expect(h.phase, Phase.halftime);
      expect(h.run!.pendingHalf!.team, g.run!.pendingHalf!.team);
      expect(h.run!.askHalftime, isTrue);
      var guard = 0;
      while ((h.phase == Phase.halftime || h.phase == Phase.clutch) && guard++ < 30) {
        if (h.phase == Phase.halftime) {
          h.resolveHalftime(Halftime.defense);
        } else {
          h.resolveClutch(Clutch.pass);
        }
      }
      expect(h.slot, 2);
    });
  });
}
