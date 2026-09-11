/// 特性の効きが、判定と画面で同じものを読んでいること。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/dependencies.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/game/person.dart';
import 'package:soccer_career/game/scenarios.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/aptitude.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/club.dart';
import 'package:soccer_career/models/development.dart';
import 'package:soccer_career/models/player.dart';
import 'package:soccer_career/models/reputation.dart';
import 'package:soccer_career/models/season.dart';
import 'package:soccer_career/models/training.dart';
import 'package:soccer_career/models/traits.dart';
import 'package:soccer_career/state/career_controller.dart';

class _MemoryRepository implements SaveRepository {
  CareerState? _saved;

  @override
  Future<CareerState?> load() async => _saved;

  @override
  Future<void> save(CareerState state) async => _saved = state;

  @override
  Future<void> clear() async => _saved = null;
}

Future<CareerController> started({int seed = 3, Position position = Position.cb}) async {
  final c = CareerController(
    repository: _MemoryRepository(),
    careerEngine: CareerEngine(random: Random(seed)),
    matchEngine: MatchEngine(random: Random(seed)),
    random: Random(seed),
  );
  await c.startCareer(
      name: '検証', position: position, age: 24, agent: Agent.pool.first);
  return c;
}

const _club = Club(id: 'm', name: 'M', strength: 60, tier: 1, countryId: 'yamato');
const _opponent =
    Club(id: 'x', name: 'X', strength: 60, tier: 1, countryId: 'yamato');

Player player({
  List<Trait> traits = const [],
  Position position = Position.cb,
  int condition = 100,
  Aptitude? aptitude,
}) =>
    Player(
      name: 'P',
      age: 26,
      position: position,
      attributes: Attributes(
        pace: 70,
        shooting: 55,
        passing: 62,
        dribbling: 58,
        defending: 78,
        physical: 74,
      ),
      potential: 90,
      traits: traits,
      condition: condition,
      aptitude: aptitude,
    );

/// 決めた時間に守備の局面を並べた1試合。
MatchInProgress match({
  required List<int> minutes,
  List<Trait> traits = const [],
  Appearance appearance = Appearance.start,
  List<int> conceded = const [],
  int seed = 1,
}) {
  final scenario = ScenarioPool.defence.first;
  return MatchInProgress(
    matchday: 1,
    opponent: _opponent,
    home: true,
    appearance: appearance,
    scenarios: [for (final _ in minutes) scenario],
    minutes: minutes,
    player: player(traits: traits),
    club: _club,
    concededMinutes: [...conceded],
    random: Random(seed),
  );
}

TraitContext ctx({
  int minute = 40,
  Outcome outcome = Outcome.play,
  bool afterSuccess = false,
  bool substitute = false,
}) =>
    TraitContext(
      minute: minute,
      home: true,
      outcome: outcome,
      afterFailure: false,
      afterSuccess: afterSuccess,
      key: AttributeKey.defending,
      detail: Detail.tackling,
      scenarioId: 'def-x',
      international: false,
      substitute: substitute,
    );

void main() {
  group('効き方の言葉', () {
    test('どの特性にも、数字の入った効き方が1つ以上ある', () {
      for (final trait in Trait.values) {
        expect(trait.effects, isNotEmpty, reason: '${trait.label} の効き方が空');
        for (final line in trait.effects) {
          expect(RegExp(r'[0-9]').hasMatch(line), isTrue,
              reason: '${trait.label}「$line」に数字が無い');
        }
      }
    });

    test('局面での判定は、画面に出す規則の合計と同じ', () {
      // 表示用に別の式を書いていないことの確認。
      final contexts = [
        ctx(),
        ctx(minute: 80),
        ctx(minute: 10),
        ctx(outcome: Outcome.goal),
        ctx(outcome: Outcome.assist),
        ctx(afterSuccess: true),
        ctx(substitute: true),
      ];
      for (final trait in Trait.values) {
        for (final c in contexts) {
          final fromRules = trait.rules
              .where((r) => r.applies(c))
              .fold<double>(0, (s, r) => s + r.value);
          expect(trait.chanceBonus(c), fromRules, reason: trait.label);
        }
      }
    });

    test('％の書き方', () {
      expect(Trait.percent(0.08), '+8%');
      expect(Trait.percent(-0.02), '-2%');
      expect(Trait.clutch.rules.single.text, '後半30分以降 +15%');
    });

    test('種類は 60 を超え、欠点は 10 ある', () {
      expect(Trait.values.length, greaterThanOrEqualTo(60));
      expect(Trait.flaws.length, greaterThanOrEqualTo(10));
    });
  });

  group('新しい特性', () {
    test('スーパーサブは途中出場のときだけ、途中出場が苦手はその逆', () {
      expect(Trait.superSub.chanceBonus(ctx(substitute: true)), greaterThan(0));
      expect(Trait.superSub.chanceBonus(ctx()), 0);
      expect(Trait.benchCold.chanceBonus(ctx(substitute: true)), lessThan(0));
      expect(Trait.benchCold.chanceBonus(ctx()), 0);
    });

    test('途中出場の試合では、局面の文脈が途中出場になっている', () {
      final sub = match(minutes: const [60, 80], appearance: Appearance.sub);
      expect(sub.traitContextFor(sub.current.options.first).substitute, isTrue);
      final start = match(minutes: const [60, 80]);
      expect(
          start.traitContextFor(start.current.options.first).substitute, isFalse);
    });

    test('出足が速いと乗ると止まらない', () {
      expect(Trait.fastStarter.chanceBonus(ctx(minute: 10)), greaterThan(0));
      expect(Trait.fastStarter.chanceBonus(ctx(minute: 60)), 0);
      expect(Trait.hotHand.chanceBonus(ctx(afterSuccess: true)), greaterThan(0));
      expect(Trait.hotHand.chanceBonus(ctx()), 0);
      expect(Trait.assistKing.chanceBonus(ctx(outcome: Outcome.assist)),
          greaterThan(0));
      expect(Trait.assistKing.chanceBonus(ctx(outcome: Outcome.goal)), 0);
    });

    test('警告の受けやすさは、荒い手にだけ効く', () {
      final rough = ScenarioPool.defence
          .expand((s) => s.options)
          .firstWhere((o) => o.foul > 0 && !o.isTacticalFoul);
      final tactical = ScenarioPool.defence
          .expand((s) => s.options)
          .firstWhere((o) => o.isTacticalFoul);
      final plain = match(minutes: const [40]);
      final hot = match(minutes: const [40], traits: const [Trait.hothead]);
      final clean =
          match(minutes: const [40], traits: const [Trait.cleanPlayer]);
      expect(hot.cardChanceFor(rough), greaterThan(plain.cardChanceFor(rough)));
      expect(clean.cardChanceFor(rough), lessThan(plain.cardChanceFor(rough)));
      // 止めるための反則は、誰が選んでも必ず警告。
      expect(hot.cardChanceFor(tactical), 1);
      expect(clean.cardChanceFor(tactical), 1);
    });

    test('寝れば戻るは、休養で戻る量が大きい', () {
      int rested(List<Trait> traits) => MatchEngine(random: Random(1))
          .applyWeek(player(traits: traits, condition: 40),
              menu: TrainingMenu.rest, played: false)
          .condition;
      expect(rested(const [Trait.quickRecovery]), greaterThan(rested(const [])));
    });

    test('守備の統率者は、無失点のときだけ評価が上がる', () {
      double rating(List<Trait> traits, List<int> conceded) {
        final m = match(minutes: const [40], traits: traits, conceded: conceded);
        m.choose(m.current.options.first);
        return m.finish().rating!;
      }

      expect(rating(const [Trait.organizer], const []),
          greaterThan(rating(const [], const [])));
      expect(rating(const [Trait.organizer], const [30]),
          rating(const [], const [30]));
    });

    test('ユーティリティは、慣れないポジションの減点が半分', () {
      final aptitude = Aptitude.initial(Position.cb);
      final plain = player(aptitude: aptitude);
      final utility = player(aptitude: aptitude, traits: const [Trait.utility]);
      final plainPenalty =
          plain.attributes.overallFor(Position.st) - plain.overallAt(Position.st);
      final utilityPenalty = utility.attributes.overallFor(Position.st) -
          utility.overallAt(Position.st);
      expect(plainPenalty, greaterThan(0));
      expect(utilityPenalty, lessThan(plainPenalty));
      // 本職は誰でも0。
      expect(utility.overallAt(Position.cb), plain.overallAt(Position.cb));
    });

    test('研究熱心は相手に慣れるのが速く、足踏みしないは停滞期が短い', () {
      const dev = Development(faced: {ClubStyle.pressing: 10});
      expect(dev.adaptationFor(ClubStyle.pressing, factor: 2.0),
          greaterThan(dev.adaptationFor(ClubStyle.pressing)));
      // 慣れの上限は同じ。
      const veteran = Development(faced: {ClubStyle.pressing: 100});
      expect(veteran.adaptationFor(ClubStyle.pressing, factor: 2.0),
          veteran.adaptationFor(ClubStyle.pressing));

      const streak = Development(growthStreak: Development.plateauStreak - 1);
      for (var seed = 0; seed < 20; seed++) {
        final normal = streak.afterGrowth(grew: true, random: Random(seed));
        final short = streak.afterGrowth(
            grew: true, random: Random(seed), plateauFactor: 0.5);
        expect(short.plateau, lessThan(normal.plateau), reason: 'seed $seed');
        expect(short.plateau, greaterThanOrEqualTo(1));
      }
    });

    test('監督受けと扱いにくさは、上がるときと下がるときで別に効く', () async {
      final c = await started(seed: 11);
      final state = c.state!;
      final person = Person(random: Random(1));
      Relations withTraits(List<Trait> traits) {
        state.player = state.player.copyWith(traits: traits);
        return person.updateRelations(state);
      }

      // まだ1試合も出ていないので、信頼は下がる方向。
      final plain = withTraits(const []).manager;
      final difficult = withTraits(const [Trait.difficult]).manager;
      final coachable = withTraits(const [Trait.coachable]).manager;
      expect(plain, lessThan(state.relations.manager));
      expect(difficult, lessThan(plain), reason: '下がるときは扱いにくい方が大きく');
      expect(coachable, plain, reason: '下がるときに監督受けは効かない');
    });

    test('華があると、同じ働きで知名度が伸びる', () async {
      final c = await started(seed: 12);
      while (!c.state!.seasonFinished) {
        await c.simulateMatch();
      }
      final state = c.state!;
      final person = Person(random: Random(1));
      final plain = person.fameFor(state);
      state.player = state.player.copyWith(traits: const [Trait.showman]);
      final showman = person.fameFor(state);
      expect(showman, greaterThanOrEqualTo(plain));
      expect(showman, lessThanOrEqualTo(100));
    });
  });

  group('稀な特性', () {
    test('20人に1人ほどにしか付かず、付いても長所は2つのまま', () {
      var rareCount = 0;
      var rareFlawCount = 0;
      for (var seed = 0; seed < 2000; seed++) {
        final traits = Trait.roll(Random(seed), position: Position.cm);
        final rares = traits.where((t) => t.rare && !t.flaw).length;
        final rareFlaws = traits.where((t) => t.rare && t.flaw).length;
        expect(rares, lessThanOrEqualTo(1));
        expect(traits.where((t) => !t.flaw).length, 2, reason: 'seed $seed');
        expect(traits.where((t) => t.flaw).length, lessThanOrEqualTo(1));
        if (rares == 1) rareCount++;
        if (rareFlaws == 1) rareFlawCount++;
        for (var i = 0; i < traits.length; i++) {
          for (var j = i + 1; j < traits.length; j++) {
            expect(Trait.compatible(traits[i], traits[j]), isTrue,
                reason: '${traits[i].label} と ${traits[j].label}');
          }
        }
      }
      // 5% と 2% の前後。
      expect(rareCount, inInclusiveRange(60, 140));
      expect(rareFlawCount, inInclusiveRange(15, 65));
    });

    test('稀なものは普通の引きには入らない', () {
      expect(Trait.strengths.any((t) => t.rare), isFalse);
      expect(Trait.flaws.any((t) => t.rare), isFalse);
      expect(Trait.rares.length, greaterThanOrEqualTo(5));
      expect(Trait.rares.any((t) => t.flaw), isTrue);
    });

    test('稀なものが外れた種では、これまでと同じ選手が出る', () {
      // 稀の判定を普通の引きの後ろに置いたことの確認。
      for (var seed = 0; seed < 200; seed++) {
        final traits = Trait.roll(Random(seed), position: Position.cm);
        if (traits.any((t) => t.rare)) continue;
        final again = Trait.roll(Random(seed), position: Position.cm);
        expect(again, traits);
      }
    });

    test('天才はポテンシャルに乗り、上限は超えない', () async {
      var found = false;
      for (var seed = 0; seed < 400 && !found; seed++) {
        final c = await started(seed: seed, position: Position.cm);
        final player = c.state!.player;
        if (!player.traits.contains(Trait.genius)) continue;
        found = true;
        expect(player.potential, lessThanOrEqualTo(99));
        expect(player.potential, greaterThan(player.overall));
      }
      expect(found, isTrue, reason: '400人に天才が1人も居ない');
      expect(const [Trait.genius].potentialBonus, greaterThan(0));
      expect(Trait.genius.effects.any((e) => e.contains('ポテンシャル')), isTrue);
    });

    test('大一番の申し子は終盤と大一番で効き、それ以外は平常', () {
      expect(Trait.bigMoment.chanceBonus(ctx(minute: 80)), greaterThan(0));
      expect(Trait.bigMoment.chanceBonus(ctx(minute: 40)), 0);
    });
  });

  group('超越', () {
    test('対象の能力だけ上限が 109 になり、他は 99 のまま', () {
      const traits = [Trait.eagleEye];
      expect(traits.ceilingFor(Detail.vision), Formulas.absoluteMax);
      expect(traits.ceilingFor(Detail.shortPassing), Formulas.maxAttribute);
      expect(const <Trait>[].ceilingFor(Detail.vision), Formulas.maxAttribute);
      expect(Trait.eagleEye.effects.single, contains('視野'));
      expect(Trait.eagleEye.effects.single, contains('109'));
    });

    test('超越は1人に1つしか付かない', () {
      for (var seed = 0; seed < 2000; seed++) {
        final traits = Trait.roll(Random(seed), position: Position.cm);
        expect(traits.where((t) => t.transcendDetail != null).length,
            lessThanOrEqualTo(1),
            reason: 'seed $seed');
      }
      expect(Trait.catReflex.fitsPosition(Position.st), isFalse);
      expect(Trait.eagleEye.fitsPosition(Position.gk), isFalse);
      expect(Trait.ironLungs.fitsPosition(Position.gk), isTrue);
    });

    test('99 で止まらず、109 で止まる', () {
      final at99 = Attributes.fromDetails(
          {for (final d in Detail.values) d: 99});
      expect(at99.bumpDetail(Detail.vision, 2).detail(Detail.vision), 99);
      expect(
          at99
              .bumpDetail(Detail.vision, 2, max: Formulas.absoluteMax)
              .detail(Detail.vision),
          101);
      final at109 = at99.bumpDetail(Detail.vision, 20,
          max: Formulas.absoluteMax);
      expect(at109.detail(Detail.vision), 109);
      // 土台を持たない能力の上限は、そのまま渡した ceiling になる。
      expect(Dependencies.supports[Detail.shortPassing], isNull);
      expect(Dependencies.blocked(Detail.shortPassing, at99), isTrue);
      expect(
          Dependencies.blocked(Detail.shortPassing, at99,
              ceiling: Formulas.absoluteMax),
          isFalse);
      // 土台を持つ能力は、土台の平均 + 18 のまま（ここでは 99 で丸めない）。
      expect(Dependencies.capFor(Detail.vision, at99), greaterThan(99));
    });

    test('上限を超えた値は、保存を往復しても潰れない', () {
      final a = Attributes.fromDetails(
          {for (final d in Detail.values) d: 80, Detail.vision: 105});
      final back = Attributes.fromJson(a.toJson());
      expect(back.detail(Detail.vision), 105);
      // ただし 109 までしか読まない。
      final json = a.toJson();
      (json['details'] as Map<String, dynamic>)['vision'] = 150;
      expect(Attributes.fromJson(json).detail(Detail.vision),
          Formulas.absoluteMax);
    });

    test('判定に使う値も上限を超える', () {
      final p = Player(
        name: 'P',
        age: 26,
        position: Position.cm,
        attributes: Attributes.fromDetails(
            {for (final d in Detail.values) d: 80, Detail.vision: 105}),
        potential: 90,
        traits: const [Trait.eagleEye],
      );
      expect(p.effective(Detail.vision), greaterThanOrEqualTo(105));
      final plain = Player(
        name: 'P',
        age: 26,
        position: Position.cm,
        attributes: p.attributes,
        potential: 90,
      );
      expect(plain.effective(Detail.vision), 99);
    });

    test('ポテンシャルに達しても、超越の1項目だけは練習で伸び続ける', () {
      Player at(List<Trait> traits) => Player(
            name: 'P',
            age: 22,
            position: Position.cm,
            attributes: Attributes.fromDetails(
                {for (final d in Detail.values) d: 88, Detail.vision: 99}),
            potential: 60,
            traits: traits,
          );
      var grew = 0;
      var others = 0;
      for (var seed = 0; seed < 200; seed++) {
        final week = MatchEngine(random: Random(seed)).applyWeek(
          at(const [Trait.eagleEye]),
          menu: TrainingMenu.forKey(AttributeKey.passing),
          played: false,
        );
        if (week.attributes.detail(Detail.vision) > 99) grew++;
        for (final d in Detail.values) {
          if (d != Detail.vision && week.attributes.detail(d) != 88) others++;
        }
      }
      expect(grew, greaterThan(0), reason: '200週で一度も伸びない');
      expect(others, 0, reason: '超越以外が伸びた');

      // 助走の手前（89未満）なら、ポテンシャルで止まる。
      final early = Player(
        name: 'P',
        age: 22,
        position: Position.cm,
        attributes: Attributes.fromDetails(
            {for (final d in Detail.values) d: 80}),
        potential: 60,
        traits: const [Trait.eagleEye],
      );
      for (var seed = 0; seed < 50; seed++) {
        final week = MatchEngine(random: Random(seed)).applyWeek(
          early,
          menu: TrainingMenu.forKey(AttributeKey.passing),
          played: false,
        );
        expect(week.attributes.detail(Detail.vision), 80);
      }

      // 特性が無ければ、ポテンシャルで止まる。
      for (var seed = 0; seed < 50; seed++) {
        final week = MatchEngine(random: Random(seed)).applyWeek(
          at(const []),
          menu: TrainingMenu.forKey(AttributeKey.passing),
          played: false,
        );
        expect(week.attributes.detail(Detail.vision), 99);
      }
    });

    test('試合の成長も同じ', () {
      final p = Player(
        name: 'P',
        age: 22,
        position: Position.cm,
        attributes: Attributes.fromDetails(
            {for (final d in Detail.values) d: 88, Detail.vision: 99}),
        potential: 60,
        traits: const [Trait.eagleEye],
      );
      var grew = 0;
      for (var seed = 0; seed < 200; seed++) {
        final next = MatchEngine(random: Random(seed))
            .grow(p, 8.5);
        if (next.detail(Detail.vision) > 99) grew++;
        for (final d in Detail.values) {
          if (d != Detail.vision) expect(next.detail(d), 88);
        }
      }
      expect(grew, greaterThan(0));
    });
  });

  group('ポジションに合った特性', () {
    test('GK に得意技のフィールド特性は付かず、FW に GK の特性は付かない', () {
      for (var seed = 0; seed < 300; seed++) {
        final gk = Trait.roll(Random(seed), position: Position.gk);
        for (final t in gk) {
          expect(t.fitsPosition(Position.gk), isTrue,
              reason: 'GK に ${t.label}（seed $seed）');
        }
        final st = Trait.roll(Random(seed), position: Position.st);
        for (final t in st) {
          expect(t.fitsPosition(Position.st), isTrue,
              reason: 'ST に ${t.label}（seed $seed）');
        }
        expect(gk.where((t) => !t.flaw).length, 2);
        expect(st.where((t) => !t.flaw).length, 2);
      }
    });

    test('反応の鬼は GK だけ、ポーチャーは GK 以外、統率者は守備の選手だけ', () {
      expect(Trait.reflexKeeper.fitsPosition(Position.gk), isTrue);
      expect(Trait.reflexKeeper.fitsPosition(Position.st), isFalse);
      expect(Trait.poacher.fitsPosition(Position.gk), isFalse);
      expect(Trait.poacher.fitsPosition(Position.st), isTrue);
      expect(Trait.organizer.fitsPosition(Position.cb), isTrue);
      expect(Trait.organizer.fitsPosition(Position.st), isFalse);
      // ポジションを渡さなければ、これまでどおり全部から引く。
      expect(Trait.clutch.fitsPosition(Position.gk), isTrue);
    });

    test('新しいキャリアの選手には、そのポジションに合う特性だけが付く', () async {
      for (var seed = 0; seed < 30; seed++) {
        final c = await started(seed: seed, position: Position.gk);
        for (final t in c.state!.player.traits) {
          expect(t.fitsPosition(Position.gk), isTrue, reason: t.label);
        }
      }
    });
  });

  group('今季に効いた回数', () {
    test('効いた局面だけを数える', () {
      // 40分では効かず、80分と88分で効く。
      final m = match(minutes: const [40, 80, 88], traits: const [Trait.clutch]);
      m.choose(m.current.options.first);
      expect(m.traitHits[Trait.clutch], isNull);
      m.choose(m.current.options.first);
      m.choose(m.current.options.first);
      expect(m.traitHits[Trait.clutch], 2);
    });

    test('試合ごとに積み上がり、保存を往復し、古い保存データでは空', () async {
      final c = await started(seed: 21);
      final state = c.state!;
      state.recordTraitHits({Trait.clutch: 2});
      state.recordTraitHits({Trait.clutch: 1, Trait.wall: 3});
      expect(state.traitHits[Trait.clutch], 3);
      expect(state.traitHits[Trait.wall], 3);

      final json = state.toJson();
      final restored = CareerState.fromJson(json);
      expect(restored.traitHits[Trait.clutch], 3);

      final legacy = CareerState.fromJson(json..remove('traitHits'));
      expect(legacy.traitHits, isEmpty);

      // 知らない名前は読み飛ばす（特性を消した版との互換）。
      final odd = CareerState.fromJson(
          state.toJson()..['traitHits'] = {'ghost': 4, 'wall': 1});
      expect(odd.traitHits, {Trait.wall: 1});
    });

    test('シーズンの起点で空になる', () async {
      final c = await started(seed: 22);
      final state = c.state!;
      state.recordTraitHits({Trait.clutch: 2});
      state.beginSeasonRecord();
      expect(state.traitHits, isEmpty);
    });

    test('効く場面が来たら、体感できる大きさで動く', () {
      // **影響度 = 頻度 × 深さ。** 実測（`test/influence_sim.dart`）で、
      // 特性はどれも「常に少しだけ効く飾り」で、1つあたり増減の
      // 0.1〜1.4% しか占めていなかった。条件が狭いものほど、
      // 効いた瞬間は深くないと存在しないのと同じになる。
      for (final trait in Trait.values) {
        if (trait.rules.isEmpty) continue;
        if (trait.flaw) continue;
        final best = trait.rules
            .map((r) => r.value)
            .reduce((a, b) => a > b ? a : b);
        expect(
          best,
          greaterThanOrEqualTo(0.08),
          reason: '${trait.label} は効いても動かない',
        );
      }
    });

    test('長所と欠点の深さが釣り合っている', () {
      // 長所だけ深くすると「上位互換を作らない」の線が崩れる。
      for (final trait in Trait.values.where((t) => t.flaw)) {
        if (trait.rules.isEmpty) continue;
        final worst = trait.rules
            .map((r) => r.value)
            .reduce((a, b) => a < b ? a : b);
        expect(
          worst,
          lessThanOrEqualTo(-0.08),
          reason: '${trait.label} の代償が浅い',
        );
      }
    });

    test('試合を進めると、効いた特性が記録される', () async {
      // 前半30分までに必ず1局面はあるので、出足が速いは毎試合効く。
      final c = await started(seed: 23);
      final state = c.state!;
      state.player = state.player.copyWith(traits: const [Trait.fastStarter]);
      // 先発の最初の局面は 7〜30分。30分ちょうどには効かないので、数試合見る。
      var played = 0;
      for (var i = 0; i < 10 && played < 3; i++) {
        final result = await c.simulateMatch();
        if (result?.appearance == Appearance.start) played++;
      }
      expect(played, greaterThan(0), reason: '10試合で先発が無い');
      expect(state.traitHits[Trait.fastStarter] ?? 0, greaterThan(0));
    });
  });
}
