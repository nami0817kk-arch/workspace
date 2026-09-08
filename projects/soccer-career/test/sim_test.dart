import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/models/training.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/game/names.dart';
import 'package:soccer_career/game/scenarios.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/player.dart';
import 'package:soccer_career/models/season.dart';
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

Player player({
  List<Trait> traits = const [],
  Attributes? attributes,
  Position position = Position.st,
}) =>
    Player(
      name: 'P',
      age: 22,
      position: position,
      attributes: attributes ??
          Attributes(
              pace: 60, shooting: 60, passing: 60, dribbling: 60,
              defending: 60, physical: 60),
      potential: 99,
      traits: traits,
    );

MatchInProgress startMatch({
  int seed = 1,
  Player? p,
  bool international = false,
  Appearance appearance = Appearance.start,
}) {
  final league = Names.buildLeague(2);
  return MatchEngine(random: Random(seed)).start(
    matchday: 1,
    player: p ?? player(),
    club: league.first,
    opponent: league.last,
    home: true,
    appearance: appearance,
    international: international,
  );
}

TraitContext ctx({
  int minute = 30,
  bool home = true,
  Outcome outcome = Outcome.play,
  bool afterFailure = false,
  bool afterSuccess = false,
  AttributeKey key = AttributeKey.passing,
  Detail? detail,
  String scenarioId = 'x',
  bool international = false,
}) =>
    TraitContext(
      minute: minute,
      home: home,
      outcome: outcome,
      afterFailure: afterFailure,
      afterSuccess: afterSuccess,
      key: key,
      detail: detail,
      scenarioId: scenarioId,
      international: international,
    );

void main() {
  group('詳細能力', () {
    test('22項目あり、7カテゴリに漏れなく属する', () {
      expect(Detail.values.length, 22);
      for (final key in AttributeKey.values) {
        expect(key.details, isNotEmpty, reason: key.label);
      }
      final covered = AttributeKey.values.fold(0, (s, k) => s + k.details.length);
      expect(covered, Detail.values.length);
    });

    test('カテゴリの値は詳細の平均', () {
      final a = Attributes.fromDetails({
        Detail.acceleration: 40,
        Detail.sprintSpeed: 60,
      });
      expect(a.pace, 50);
    });

    test('カテゴリ指定で作ると詳細はすべて同じ値', () {
      final a = Attributes(
          pace: 55, shooting: 60, passing: 65, dribbling: 70,
          defending: 45, physical: 50);
      for (final d in AttributeKey.shooting.details) {
        expect(a.detail(d), 60);
      }
    });

    test('ばらつき付きで作ると詳細が揃わないが、範囲内に収まる', () {
      final a = Attributes.scattered(
        pace: 50, shooting: 50, passing: 50, dribbling: 50,
        defending: 50, physical: 50, goalkeeping: 50, random: Random(3), spread: 6,
      );
      final values = Detail.values.map(a.detail).toSet();
      expect(values.length, greaterThan(1));
      for (final d in Detail.values) {
        expect(a.detail(d), inInclusiveRange(44, 56));
      }
    });

    test('7項目だった頃の保存データを読み、詳細に展開する', () {
      final a = Attributes.fromJson({
        'pace': 70, 'shooting': 50, 'passing': 55,
        'dribbling': 60, 'defending': 40, 'physical': 65,
      });
      expect(a.detail(Detail.acceleration), 70);
      expect(a.detail(Detail.sprintSpeed), 70);
      expect(a.detail(Detail.reflexes), Formulas.defaultGoalkeeping);
    });

    test('詳細ごとの保存を往復できる', () {
      final a = Attributes.scattered(
        pace: 50, shooting: 50, passing: 50, dribbling: 50,
        defending: 50, physical: 50, random: Random(4),
      );
      final r = Attributes.fromJson(a.toJson());
      for (final d in Detail.values) {
        expect(r.detail(d), a.detail(d), reason: d.label);
      }
    });

    test('局面の選択肢は詳細能力で判定される', () {
      final strongFinisher = Attributes.fromDetails({
        for (final d in Detail.values) d: 50,
        Detail.finishing: 90,
      });
      final weakFinisher = Attributes.fromDetails({
        for (final d in Detail.values) d: 50,
        Detail.finishing: 30,
      });
      final option = ScenarioPool.forward
          .expand((s) => s.options)
          .firstWhere((o) => o.detail == Detail.finishing);

      final strong = startMatch(p: player(attributes: strongFinisher));
      final weak = startMatch(p: player(attributes: weakFinisher));
      expect(strong.attributeFor(option), 90);
      expect(weak.attributeFor(option), 30);
      expect(strong.chanceFor(option), greaterThan(weak.chanceFor(option)));
    });

    test('ほとんどの選択肢に詳細能力が付いている', () {
      final all = [
        for (final f in ScenarioFamily.values)
          ...ScenarioPool.forFamily(f).expand((s) => s.options),
      ];
      final withDetail = all.where((o) => o.detail != null).length;
      expect(withDetail, all.length, reason: '詳細の無い選択肢が残っている');
      // 詳細はそのカテゴリに属していること。
      for (final o in all) {
        expect(o.detail!.category, o.key, reason: o.label);
      }
    });

    test('新規キャリアの初期能力には詳細のばらつきがある', () {
      final s = CareerEngine(random: Random(5)).startCareer(
          name: 'N', position: Position.cm, age: 18, agent: Agent.pool.first);
      final values = Detail.values.map(s.player.attributes.detail).toSet();
      expect(values.length, greaterThan(3));
    });
  });

  group('特性の拡充', () {
    test('十分な数があり、欠点も一通り揃っている', () {
      // 引ける長所が少ないと、同じ能力値の選手ばかりになる。
      expect(Trait.values.length, greaterThanOrEqualTo(40));
      expect(Trait.strengths.length, greaterThanOrEqualTo(30));
      expect(Trait.flaws.length, greaterThanOrEqualTo(5));
    });

    test('どの特性にも、名前と説明がある', () {
      final labels = <String>{};
      for (final trait in Trait.values) {
        expect(trait.label, isNotEmpty);
        expect(trait.description, isNotEmpty);
        expect(labels.add(trait.label), isTrue, reason: '${trait.label} が重複');
      }
    });

    test('上位互換を作らない（何かしら効き、噛み合わない組み合わせは避ける）', () {
      for (final trait in Trait.values) {
        // 試合の中か外か、どこかには効いていること。
        final affectsMatch = Trait.values.any((_) => false) ||
            trait.ratingBonus != 0 ||
            trait.peakAgeOffset != 0 ||
            trait.declineAgeOffset != 0 ||
            trait.injuryFactor != 1.0 ||
            trait.conditionCostFactor != 1.0 ||
            trait.fatigueFactor != 1.0 ||
            trait.trainingFactor != 1.0 ||
            trait.setPieceFactor != 1.0 ||
            trait.rehabFactor != 1.0 ||
            trait.moraleFactor != 1.0 ||
            trait.formFactor != 1.0 ||
            trait.deadBallThresholdOffset != 0 ||
            trait.growthFactor(20) != 1.0 ||
            trait.growthFactor(30) != 1.0;
        expect(affectsMatch || _affectsPlay(trait), isTrue,
            reason: '${trait.label} は何も効いていない');
      }
    });

    test('長所2つに、3割で欠点が付く', () {
      var withFlaw = 0;
      for (var seed = 0; seed < 300; seed++) {
        final traits = Trait.roll(Random(seed));
        final strengths = traits.where((t) => !t.flaw).length;
        final flaws = traits.where((t) => t.flaw).length;
        expect(strengths, 2, reason: 'seed $seed');
        expect(flaws, lessThanOrEqualTo(1));
        if (flaws == 1) withFlaw++;
        for (var i = 0; i < traits.length; i++) {
          for (var j = i + 1; j < traits.length; j++) {
            expect(Trait.compatible(traits[i], traits[j]), isTrue,
                reason: '${traits[i].label} と ${traits[j].label}');
          }
        }
      }
      expect(withFlaw, inInclusiveRange(50, 130));
    });

    test('欠点無しで引くこともできる', () {
      for (var seed = 0; seed < 50; seed++) {
        final traits = Trait.roll(Random(seed), flawChance: 0);
        expect(traits.length, 2);
        expect(traits.any((t) => t.flaw), isFalse);
      }
    });

    test('得意技は対応する能力の手だけに効く', () {
      expect(Trait.aerialAce.chanceBonus(ctx(detail: Detail.heading)), greaterThan(0));
      expect(Trait.aerialAce.chanceBonus(ctx(detail: Detail.finishing)), 0);
      expect(Trait.poacher.chanceBonus(ctx(detail: Detail.finishing)), greaterThan(0));
      expect(Trait.poacher.chanceBonus(ctx(detail: Detail.heading)), 0);
      expect(Trait.sprinter.chanceBonus(ctx(key: AttributeKey.pace)), greaterThan(0));
      expect(Trait.wall.chanceBonus(ctx(key: AttributeKey.defending)), greaterThan(0));
      expect(Trait.wall.chanceBonus(ctx(key: AttributeKey.passing)), 0);
    });

    test('PK職人はPKの局面だけ、大舞台は代表戦だけ', () {
      expect(Trait.penaltyKing.chanceBonus(ctx(scenarioId: 'fw-pk')), greaterThan(0));
      expect(Trait.penaltyKing.chanceBonus(ctx(scenarioId: 'fw-box')), 0);
      expect(Trait.bigGame.chanceBonus(ctx(international: true)), greaterThan(0));
      expect(Trait.bigGame.chanceBonus(ctx()), 0);
      // ホームの英雄は代表戦では効かない（ホームの概念が違う）。
      expect(Trait.homeHero.chanceBonus(ctx(home: true, international: true)), 0);
    });

    test('欠点は成功率を下げる', () {
      expect(Trait.slowStarter.chanceBonus(ctx(minute: 10)), lessThan(0));
      expect(Trait.slowStarter.chanceBonus(ctx(minute: 60)), 0);
      expect(Trait.moody.chanceBonus(ctx(afterFailure: true)), lessThan(0));
      expect(Trait.moody.chanceBonus(ctx(afterSuccess: true)), greaterThan(0));
    });

    test('体の特性は確率と消耗に効く', () {
      expect(const [Trait.robust].injuryFactor, lessThan(1));
      expect(const [Trait.fragile].injuryFactor, greaterThan(1));
      expect(const [Trait.engine].conditionCostFactor, lessThan(1));
      expect(const <Trait>[].injuryFactor, 1.0);
    });

    test('怪我がちは実際に怪我が増える', () {
      int count(List<Trait> traits) {
        var n = 0;
        for (var seed = 0; seed < 500; seed++) {
          final p = Player(
            name: 'I', age: 24, position: Position.cm,
            attributes: Attributes(
                pace: 50, shooting: 50, passing: 50, dribbling: 50,
                defending: 50, physical: 50),
            potential: 99, traits: traits, condition: 40,
          );
          if (MatchEngine(random: Random(seed))
                  .rollInjury(p, baseChance: Formulas.injuryBaseChance) !=
              null) {
            n++;
          }
        }
        return n;
      }

      expect(count(const [Trait.fragile]), greaterThan(count(const [Trait.robust])));
    });

    test('無尽蔵は試合の消耗が少ない', () {
      // 休養だと上限で頭打ちになって差が見えないので、練習した週で比べる。
      final normal = MatchEngine(random: Random(6))
          .applyWeek(player(), menu: TrainingMenu.sprint, played: true);
      final tireless = MatchEngine(random: Random(6)).applyWeek(
          player(traits: const [Trait.engine]),
          menu: TrainingMenu.sprint,
          played: true);
      expect(tireless.condition, greaterThan(normal.condition));
    });

    test('キャプテンは評価点が少し高い', () {
      final plain = startMatch(seed: 7);
      final captain = startMatch(seed: 7, p: player(traits: const [Trait.captain]));
      expect(captain.rating, greaterThan(plain.rating));
    });

    test('特性の保存を往復でき、知らない名前は捨てる', () {
      final s = CareerEngine(random: Random(8)).startCareer(
          name: 'T', position: Position.cb, age: 20, agent: Agent.pool.first);
      final json = s.toJson();
      final playerJson = json['player'] as Map<String, dynamic>;
      playerJson['traits'] = [...(playerJson['traits'] as List), 'unknownTrait'];
      final r = CareerState.fromJson(json);
      expect(r.player.traits, s.player.traits);
    });
  });

  group('自動で進める', () {
    test('安全は成功率が最も高い手を選ぶ', () {
      final m = startMatch(seed: 9);
      final pick = m.pickFor(SimStyle.safe);
      final best = m.current.options.map(m.chanceFor).reduce(max);
      expect(m.chanceFor(pick), best);
    });

    test('バランスは期待値が最も高い手を選ぶ', () {
      final m = startMatch(seed: 9);
      final pick = m.pickFor(SimStyle.balanced);
      final best = m.current.options.map(m.expectedDelta).reduce(max);
      expect(m.expectedDelta(pick), best);
    });

    test('勝負は得点に繋がる手を選ぶ（あれば）', () {
      for (var seed = 0; seed < 30; seed++) {
        final m = startMatch(seed: seed);
        final pick = m.pickFor(SimStyle.aggressive);
        final hasScoring = m.current.options.any((o) => o.outcome != Outcome.play);
        if (hasScoring) {
          expect(pick.outcome, isNot(Outcome.play), reason: 'seed $seed');
        }
      }
    });

    test('autoPlay は残りの局面を全部消化する', () {
      final m = startMatch(seed: 10);
      m.choose(m.current.options.first);
      m.autoPlay(SimStyle.balanced);
      expect(m.isFinished, isTrue);
      expect(m.resolutions.length, Formulas.scenariosPerStart);
    });

    test('simulateMatch は1試合を終えて結果を返す', () async {
      final c = CareerController(
        repository: _MemoryRepository(),
        careerEngine: CareerEngine(random: Random(11)),
        matchEngine: MatchEngine(random: Random(11)),
      );
      await c.startCareer(
          name: 'S', position: Position.st, age: 19, agent: Agent.pool.first);
      final before = c.state!.matchday;
      final result = await c.simulateMatch();
      expect(result, isNotNull);
      expect(c.state!.matchday, before + 1);
      expect(c.currentMatch, isNull);
    });

    test('simulateUntilEvent は区切りで止まり、消化した試合を返す', () async {
      final c = CareerController(
        repository: _MemoryRepository(),
        careerEngine: CareerEngine(random: Random(12)),
        matchEngine: MatchEngine(random: Random(12)),
      );
      await c.startCareer(
          name: 'S', position: Position.cm, age: 19, agent: Agent.pool.first);
      final report = await c.simulateUntilEvent();
      expect(report.played, greaterThan(0));
      expect(report.played, c.state!.leagueResults.length);
      expect(report.won + report.drawn + report.lost, report.played);
      // 止まった理由と状態が一致している。
      switch (report.stoppedBy) {
        case SimStop.injury:
          expect(c.state!.injured, isTrue);
          expect(report.injury, isNotNull);
        case SimStop.callUp:
          expect(c.state!.pendingInternational, isTrue);
        case SimStop.seasonEnd:
          expect(c.state!.seasonFinished, isTrue);
        case SimStop.limit:
          break;
      }
    });

    test('シーズン終了まで自動で進められる', () async {
      final c = CareerController(
        repository: _MemoryRepository(),
        careerEngine: CareerEngine(random: Random(13)),
        matchEngine: MatchEngine(random: Random(13)),
      );
      await c.startCareer(
          name: 'S', position: Position.wg, age: 19, agent: Agent.pool.first);
      var guard = 0;
      while (!c.state!.seasonFinished && guard < 20) {
        final report = await c.simulateUntilEvent();
        if (report.stoppedBy == SimStop.callUp) {
          // 代表ウィークは代表戦（または飛ばし）を経て次へ。
          await c.simulateMatch();
        }
        guard++;
      }
      expect(c.state!.seasonFinished, isTrue);
      expect(c.state!.leagueResults.length, c.state!.fixtures.length);
    });

    test('スタイルは保存を往復しても残る', () {
      final s = CareerEngine(random: Random(14)).startCareer(
          name: 'S', position: Position.st, age: 19, agent: Agent.pool.first);
      s.simStyle = SimStyle.aggressive;
      expect(CareerState.fromJson(s.toJson()).simStyle, SimStyle.aggressive);
      final json = s.toJson()..remove('simStyle');
      expect(CareerState.fromJson(json).simStyle, SimStyle.balanced);
    });
  });
}


/// 局面の中で効く特性かどうか。文脈を振って、どこかで動けば効いている。
bool _affectsPlay(Trait trait) {
  for (final minute in [10, 40, 80]) {
    for (final outcome in Outcome.values) {
      for (final key in AttributeKey.values) {
        for (final detail in [null, ...Detail.values]) {
          for (final flags in const [
            [true, true, true, true],
            [false, false, false, false],
          ]) {
            final context = TraitContext(
              minute: minute,
              home: flags[0],
              outcome: outcome,
              afterFailure: flags[1],
              afterSuccess: flags[2],
              key: key,
              detail: detail,
              scenarioId: 'fw-pk',
              international: flags[3],
              bigMatch: flags[0],
              margin: flags[1] ? -1 : 1,
              weakFoot: flags[2],
              abroad: flags[3],
            );
            if (trait.chanceBonus(context) != 0) return true;
          }
        }
      }
    }
  }
  return false;
}
