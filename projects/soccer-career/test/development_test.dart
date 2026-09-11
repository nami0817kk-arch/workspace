import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/club.dart';
import 'package:soccer_career/models/development.dart';
import 'package:soccer_career/models/personality.dart';
import 'package:soccer_career/models/physique.dart';
import 'package:soccer_career/models/player.dart';
import 'package:soccer_career/models/season.dart';
import 'package:soccer_career/models/training.dart';

final flat = Attributes(
  pace: 50,
  shooting: 50,
  passing: 50,
  dribbling: 50,
  defending: 50,
  physical: 50,
  goalkeeping: 50,
);

Player player({
  Position position = Position.cm,
  int age = 22,
  int potential = 99,
  Attributes? attributes,
  Physique? physique,
  int confidence = 10,
}) => Player(
  name: 'P',
  age: age,
  position: position,
  attributes: attributes ?? flat,
  potential: potential,
  physique:
      physique ??
      const Physique(
        heightCm: Physique.baseHeight,
        weightKg: Physique.baseWeight,
      ),
  personality: Personality(
    confidence: confidence,
    ambition: 10,
    professionalism: 10,
    temper: 10,
  ),
);

Club club(String id, {int strength = 60}) =>
    Club(id: id, name: id, strength: strength, tier: 1, countryId: 'yamato');

void main() {
  group('試合経験値', () {
    test('先発は途中出場より積み、出ない試合では積まない', () {
      const base = Development();
      final started = base.afterMatch(
        appearance: Appearance.start,
        international: false,
      );
      final sub = base.afterMatch(
        appearance: Appearance.sub,
        international: false,
      );
      final benched = base.afterMatch(
        appearance: Appearance.benched,
        international: false,
      );

      expect(started.experience, greaterThan(sub.experience));
      expect(sub.experience, greaterThan(0));
      expect(benched.experience, 0);
    });

    test('代表戦は余分に積む', () {
      const base = Development();
      final league = base.afterMatch(
        appearance: Appearance.start,
        international: false,
      );
      final national = base.afterMatch(
        appearance: Appearance.start,
        international: true,
      );
      expect(national.experience, greaterThan(league.experience));
    });

    test('経験は落ち着きになるが、上限がある', () {
      expect(const Development().composure, 0);
      // 上限 0.05 では、大一番の重圧がキャリア中盤で完全に消えていた
      // （実測で平均 −0.10% ＝ 実質ゼロ）。重圧と揃えて 0.10 に。
      expect(
        const Development(experience: 5000).composure,
        Formulas.bigMatchPressure,
      );
    });
  });

  group('プレイング・アイデンティティ', () {
    test('選択が偏ってはじめて型になる', () {
      var dev = const Development();
      for (var i = 0; i < 20; i++) {
        dev = dev.afterMatch(
          appearance: Appearance.start,
          international: false,
          used: [AttributeKey.dribbling],
        );
      }
      // まだ数が足りない。
      expect(dev.identity, isNull);

      for (var i = 0; i < 20; i++) {
        dev = dev.afterMatch(
          appearance: Appearance.start,
          international: false,
          used: [AttributeKey.dribbling],
        );
      }
      expect(dev.identity, AttributeKey.dribbling);
      expect(dev.identityLabel, '仕掛ける選手');
      expect(dev.identityBonusFor(AttributeKey.dribbling), greaterThan(0));
      expect(dev.identityBonusFor(AttributeKey.defending), lessThan(0));
    });

    test('何でも選ぶ選手は何者にもならない', () {
      var dev = const Development();
      for (var i = 0; i < 40; i++) {
        dev = dev.afterMatch(
          appearance: Appearance.start,
          international: false,
          used: AttributeKey.values,
        );
      }
      expect(dev.identity, isNull);
    });
  });

  group('対戦相手への適応', () {
    test('同じクラブの戦い方は毎回同じ', () {
      final c = club('alpha');
      expect(ClubStyle.of(c), ClubStyle.of(club('alpha')));
    });

    test('当たるほど苦手ではなくなるが、頭打ちになる', () {
      const dev = Development(faced: {ClubStyle.pressing: 5});
      const veteran = Development(faced: {ClubStyle.pressing: 200});
      expect(
        veteran.adaptationFor(ClubStyle.pressing),
        greaterThan(dev.adaptationFor(ClubStyle.pressing)),
      );
      // 苦手（styleMismatch）を消しきれるところまで慣れる。
      expect(veteran.adaptationFor(ClubStyle.pressing), Formulas.styleMismatch);
      expect(dev.adaptationFor(ClubStyle.defensive), 0);
    });

    test('相手の得意な形は難しくなり、慣れるとその差が縮む', () {
      MatchInProgress start(Development dev) =>
          MatchEngine(random: Random(3)).start(
            matchday: 1,
            player: player(),
            club: club('home'),
            opponent: club('alpha'),
            home: true,
            appearance: Appearance.start,
            development: dev,
          );

      final green = start(const Development());
      final used = start(
        Development(faced: {ClubStyle.of(club('alpha')): 200}),
      );
      final hard = green.opponentStyle.hardFor;
      final option = green.current.options.firstWhere(
        (o) => o.key == hard,
        orElse: () => green.current.options.first,
      );
      if (option.key != hard) return;
      expect(used.chanceFor(option), greaterThan(green.chanceFor(option)));
    });
  });

  group('本番発揮率', () {
    MatchInProgress start({
      required int opponentStrength,
      int confidence = 10,
      Development dev = const Development(),
    }) => MatchEngine(random: Random(8)).start(
      matchday: 1,
      player: player(confidence: confidence),
      club: club('home', strength: 60),
      opponent: club('rival', strength: opponentStrength),
      home: true,
      appearance: Appearance.start,
      development: dev,
    );

    test('格上との対戦は大一番になる', () {
      expect(start(opponentStrength: 60).bigMatch, isFalse);
      expect(start(opponentStrength: 80).bigMatch, isTrue);
    });

    test('自信と経験のある選手は大一番でも落ちない', () {
      final timid = start(opponentStrength: 80, confidence: 3);
      final strong = start(
        opponentStrength: 80,
        confidence: 18,
        dev: const Development(experience: 5000),
      );
      final option = timid.current.options.first;
      expect(strong.chanceFor(option), greaterThan(timid.chanceFor(option)));
    });
  });

  group('逆足', () {
    test('両利きには逆足の局面が来ない', () {
      final match = MatchEngine(random: Random(2)).start(
        matchday: 1,
        player: player(
          physique: const Physique(
            heightCm: 180,
            weightKg: 75,
            foot: Foot.both,
            weakFoot: 5,
          ),
        ),
        club: club('a'),
        opponent: club('b'),
        home: true,
        appearance: Appearance.start,
      );
      expect(match.weakFootMoments.every((v) => !v), isTrue);
    });

    test('逆足の局面では精度の低い選手ほど落ちる', () {
      // 局面の数は試合の重さで変わる（重い試合は6、ふつうは2）。
      // 数を決め打ちにすると、重さを入れた日に落ちる。
      final scenarios = MatchEngine(random: Random(1))
          .start(
            matchday: 1,
            player: player(),
            club: club('a'),
            opponent: club('b'),
            home: true,
            appearance: Appearance.start,
          )
          .scenarios;
      MatchInProgress matchWith(int weakFoot) => MatchInProgress(
        matchday: 1,
        opponent: club('b'),
        home: true,
        appearance: Appearance.start,
        scenarios: scenarios,
        minutes: [for (var i = 0; i < scenarios.length; i++) 10 + i * 30],
        player: player(
          physique: Physique(heightCm: 180, weightKg: 75, weakFoot: weakFoot),
        ),
        club: club('a'),
        weakFootMoments: [for (final _ in scenarios) true],
        random: Random(1),
      );

      final poor = matchWith(1);
      final good = matchWith(5);
      // 足で扱う手だけが落ちる。ヘディングと守備には関係しない。
      final gaps = <double>[];
      while (!poor.isFinished) {
        for (final o in poor.current.options) {
          gaps.add(good.chanceFor(o) - poor.chanceFor(o));
        }
        poor.choose(poor.current.options.first);
        good.choose(good.current.options.first);
      }
      expect(gaps.any((g) => g > 0), isTrue);
      expect(gaps.every((g) => g >= 0), isTrue);
    });

    test('逆足の練習で精度が上がり、形になると知らせる', () {
      final engine = MatchEngine(random: Random(7));
      var p = player(
        physique: const Physique(heightCm: 180, weightKg: 75, weakFoot: 1),
      );
      var awakened = false;
      for (var i = 0; i < 200; i++) {
        final week = engine.applyWeek(
          p,
          menu: TrainingMenu.weakFootWork,
          played: false,
        );
        awakened = awakened || week.weakFootAwakened;
        p = p.copyWith(physique: week.physique, condition: 100);
      }
      expect(p.physique.weakFoot, 5);
      expect(awakened, isTrue);
    });

    test('逆足の練習は休養ではない', () {
      expect(TrainingMenu.weakFootWork.isRest, isFalse);
      final week = MatchEngine(random: Random(1)).applyWeek(
        player().copyWith(condition: 60),
        menu: TrainingMenu.weakFootWork,
        played: false,
      );
      expect(week.condition, lessThan(60));
    });
  });

  group('個人技', () {
    test('能力が水準に届いてはじめて覚える', () {
      final engine = MatchEngine(random: Random(12));
      final low = player();
      var learned = false;
      for (var i = 0; i < 200; i++) {
        final week = engine.applyWeek(
          low,
          menu: TrainingMenu.passingWork,
          played: false,
        );
        learned = learned || week.learned != null;
      }
      expect(learned, isFalse);

      final skilled = player(
        attributes: Attributes.fromDetails({
          for (final d in Detail.values) d: Signature.requirement + 5,
        }),
        potential: 99,
      );
      var dev = const Development();
      for (var i = 0; i < 300 && dev.signatures.isEmpty; i++) {
        final week = engine.applyWeek(
          skilled,
          menu: TrainingMenu.passingWork,
          development: dev,
          played: false,
        );
        if (week.learned != null) dev = dev.learn(week.learned!);
      }
      expect(dev.signatures, isNotEmpty);
      expect(dev.signatures.first.key, AttributeKey.passing);
    });

    test('持てるのは3つまで', () {
      var dev = const Development();
      for (final s in Signature.values) {
        dev = dev.learn(s);
      }
      expect(dev.signatures.length, Signature.maxOwned);
    });

    test('覚えた技はその局面の確率を上げる', () {
      const dev = Development(signatures: [Signature.noLook]);
      expect(
        dev.signatureBonus(AttributeKey.passing, Detail.vision),
        greaterThan(dev.signatureBonus(AttributeKey.passing, null)),
      );
      expect(dev.signatureBonus(AttributeKey.defending, null), 0);
    });
  });

  group('停滞期', () {
    test('伸び続けると足踏みが来る', () {
      var dev = const Development();
      final random = Random(4);
      for (var i = 0; i < Development.plateauStreak; i++) {
        dev = dev.afterGrowth(grew: true, random: random);
      }
      expect(dev.inPlateau, isTrue);
      expect(dev.growthStreak, 0);
    });

    test('停滞期は試合ごとに明けていく', () {
      var dev = const Development(plateau: 2);
      dev = dev.afterMatch(appearance: Appearance.start, international: false);
      expect(dev.plateau, 1);
      dev = dev.afterMatch(
        appearance: Appearance.benched,
        international: false,
      );
      expect(dev.plateau, 0);
      expect(dev.inPlateau, isFalse);
    });

    test('停滞期は練習が身になりにくい', () {
      int grown({required bool plateau}) {
        final engine = MatchEngine(random: Random(15));
        var attrs = flat;
        var count = 0;
        for (var i = 0; i < 300; i++) {
          final week = engine.applyWeek(
            player(attributes: attrs),
            menu: TrainingMenu.passingWork,
            plateau: plateau,
            played: false,
          );
          if (week.trained != null) count++;
          attrs = week.attributes;
        }
        return count;
      }

      expect(grown(plateau: true), lessThan(grown(plateau: false)));
    });
  });

  group('限界突破', () {
    CareerState stateAt({
      required int age,
      required int professionalism,
      required int experience,
      required bool atPotential,
      int greatWeeks = 99,
    }) {
      final s = CareerEngine(random: Random(2)).startCareer(
        name: 'B',
        position: Position.cm,
        age: age,
        agent: Agent.pool.first,
      );
      s.player = Player(
        name: 'B',
        age: age,
        position: Position.cm,
        attributes: flat,
        potential: atPotential ? flat.overallFor(Position.cm) : 99,
        personality: Personality(
          confidence: 10,
          ambition: 10,
          professionalism: professionalism,
          temper: 10,
        ),
      );
      s.development = Development(
        experience: experience,
        greatWeeks: greatWeeks,
      );
      return s;
    }

    test('頭打ちで、若く、積み上げた選手にだけ起きる', () {
      final engine = CareerEngine(random: Random(1));
      expect(
        engine.breaksThrough(
          stateAt(
            age: 23,
            professionalism: 18,
            experience: 20,
            atPotential: true,
          ),
        ),
        isFalse,
        reason: '経験が足りない',
      );
      expect(
        engine.breaksThrough(
          stateAt(
            age: 23,
            professionalism: 5,
            experience: 900,
            atPotential: true,
          ),
        ),
        isFalse,
        reason: 'プロ意識が足りない',
      );
      expect(
        engine.breaksThrough(
          stateAt(
            age: 34,
            professionalism: 18,
            experience: 900,
            atPotential: true,
          ),
        ),
        isFalse,
        reason: '歳を取りすぎている',
      );
      expect(
        engine.breaksThrough(
          stateAt(
            age: 23,
            professionalism: 18,
            experience: 900,
            atPotential: false,
          ),
        ),
        isFalse,
        reason: 'まだ頭打ちではない',
      );

      expect(
        engine.breaksThrough(
          stateAt(
            age: 23,
            professionalism: 18,
            experience: 900,
            atPotential: true,
            greatWeeks: 0,
          ),
        ),
        isFalse,
        reason: '追い込んでいない選手が限界を超えている',
      );

      // 条件を満たせば、確率で起きる。
      var happened = false;
      for (var i = 0; i < 60 && !happened; i++) {
        happened = CareerEngine(random: Random(i)).breaksThrough(
          stateAt(
            age: 23,
            professionalism: 18,
            experience: 900,
            atPotential: true,
          ),
        );
      }
      expect(happened, isTrue);
    });
  });

  test('積み上げは保存を往復しても残り、無い保存データも読める', () {
    final ce = CareerEngine(random: Random(19));
    final s = ce.startCareer(
      name: 'D',
      position: Position.wg,
      age: 20,
      agent: Agent.pool[1],
    );
    s.development = const Development(
      experience: 420,
      choices: {AttributeKey.dribbling: 80},
      faced: {ClubStyle.pressing: 12},
      signatures: [Signature.turn],
      growthStreak: 3,
      plateau: 2,
      breakthroughs: 1,
    );
    final r = CareerState.fromJson(s.toJson());
    expect(r.development.experience, 420);
    expect(r.development.choices[AttributeKey.dribbling], 80);
    expect(r.development.faced[ClubStyle.pressing], 12);
    expect(r.development.signatures, [Signature.turn]);
    expect(r.development.plateau, 2);
    expect(r.development.breakthroughs, 1);

    final legacy = CareerState.fromJson(s.toJson()..remove('development'));
    expect(legacy.development.experience, 0);
    expect(legacy.development.signatures, isEmpty);
  });
}
