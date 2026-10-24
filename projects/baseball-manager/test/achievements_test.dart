import 'dart:math';

import 'package:baseball_manager/game/achievements.dart';
import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/difficulty.dart';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/life_log.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/records.dart';
import 'package:baseball_manager/game/season.dart';
import 'package:baseball_manager/game/snapshot.dart';
import 'package:baseball_manager/game/traits.dart';
import 'package:flutter_test/flutter_test.dart';

PlayerSnapshot _snap({
  Role role = Role.batter,
  int age = 30,
  int? proStartAge,
  String? ending,
  List<SeasonRecord> records = const [],
  List<LifeEvent> events = const [],
  Set<Trait> traits = const {},
  Map<Ability, int> abilities = const {Ability.contact: 50},
  int rivalWins = 0,
  int rivalLosses = 0,
  Difficulty difficulty = Difficulty.normal,
  bool married = false,
  Course? route,
}) =>
    PlayerSnapshot(
      name: 't',
      role: role,
      age: age,
      stage: Stage.retired,
      potential: 50,
      abilities: abilities,
      traits: traits,
      records: records,
      events: events,
      overallHistory: const [10, 20],
      proStartAge: proStartAge,
      endingTitle: ending,
      rivalWins: rivalWins,
      rivalLosses: rivalLosses,
      difficulty: difficulty,
      married: married,
      route: route,
    );

SeasonRecord _pro(int age, {int rank = 4, List<String> titles = const []}) =>
    SeasonRecord(
        age: age,
        stage: Stage.pro,
        line: const Line(),
        rank: rank,
        titles: titles);

SeasonRecord _ama(int age, Stage st, {bool champion = false}) => SeasonRecord(
    age: age,
    stage: st,
    line: const Line(),
    roundsWon: champion ? 4 : 1,
    rounds: 4);

bool _has(String id, PlayerSnapshot s) => earnedBy(s).contains(id);

void main() {
  test('実績は十数個から数十個で、idは重複せず、名前と説明がある', () {
    expect(achievements.length, inInclusiveRange(15, 60));
    expect(achievements.map((a) => a.id).toSet().length, achievements.length);
    for (final a in achievements) {
      expect(a.title, isNotEmpty, reason: a.id);
      expect(a.description, isNotEmpty, reason: a.id);
    }
  });

  test('何も成し遂げなかった一生では、何も解除されない', () {
    expect(earnedBy(_snap(age: 19)), isEmpty);
  });

  group('それぞれの条件', () {
    test('プロ入り・遠回り', () {
      expect(_has('first-pro', _snap(proStartAge: 19)), isTrue);
      expect(_has('first-pro', _snap()), isFalse);
      expect(_has('comeback', _snap(proStartAge: 22, route: Course.university)),
          isTrue);
      expect(_has('comeback', _snap(proStartAge: 19)), isFalse);
      expect(
          _has('comeback', _snap(route: Course.corporate)), isFalse); // 入れなかった
    });

    test('アマチュアの優勝・最後の夏', () {
      expect(
          _has('amateur-champion',
              _snap(records: [_ama(12, Stage.youth, champion: true)])),
          isTrue);
      expect(_has('amateur-champion', _snap(records: [_ama(12, Stage.youth)])),
          isFalse);
      expect(
          _has('last-summer',
              _snap(records: [_ama(18, Stage.highSchool, champion: true)])),
          isTrue);
      expect(
          _has('last-summer',
              _snap(records: [_ama(17, Stage.highSchool, champion: true)])),
          isFalse);
    });

    test('リーグ優勝・連覇', () {
      expect(
          _has('league-champion', _snap(records: [_pro(25, rank: 1)])), isTrue);
      expect(_has('league-champion', _snap(records: [_pro(25, rank: 2)])),
          isFalse);
      expect(
          _has(
              'dynasty',
              _snap(records: [
                _pro(25, rank: 1),
                _pro(26, rank: 1),
                _pro(27, rank: 1)
              ])),
          isTrue);
      // 間が空いたら連覇ではない。
      expect(
          _has(
              'dynasty',
              _snap(records: [
                _pro(25, rank: 1),
                _pro(26, rank: 1),
                _pro(27, rank: 3),
                _pro(28, rank: 1)
              ])),
          isFalse);
      expect(
          _has(
              'dynasty',
              _snap(records: [
                _pro(25, rank: 1),
                _pro(27, rank: 1),
                _pro(29, rank: 1)
              ])),
          isFalse);
    });

    test('タイトル・二冠王・MVP', () {
      expect(
          _has(
              'title',
              _snap(records: [
                _pro(25, titles: ['首位打者'])
              ])),
          isTrue);
      expect(_has('title', _snap(records: [_pro(25)])), isFalse);
      expect(
          _has(
              'double-crown',
              _snap(records: [
                _pro(25, titles: ['首位打者', '本塁打王'])
              ])),
          isTrue);
      // MVPは数えない。別の年のタイトルも合算しない。
      expect(
          _has(
              'double-crown',
              _snap(records: [
                _pro(25, titles: ['首位打者', 'MVP'])
              ])),
          isFalse);
      expect(
          _has(
              'double-crown',
              _snap(records: [
                _pro(25, titles: ['首位打者']),
                _pro(26, titles: ['本塁打王'])
              ])),
          isFalse);
      expect(
          _has(
              'mvp',
              _snap(records: [
                _pro(25, titles: ['MVP'])
              ])),
          isTrue);
    });

    test('称号・長く続ける', () {
      expect(_has('legend', _snap(ending: 'レジェンド')), isTrue);
      expect(_has('legend', _snap(ending: '一流選手')), isFalse);
      expect(
          _has('iron-man',
              _snap(records: [for (var a = 20; a < 35; a++) _pro(a)])),
          isTrue);
      expect(
          _has('iron-man',
              _snap(records: [for (var a = 20; a < 34; a++) _pro(a)])),
          isFalse);
      expect(_has('veteran', _snap(proStartAge: 19, age: 40)), isTrue);
      expect(_has('veteran', _snap(proStartAge: 19, age: 39)), isFalse);
      expect(_has('veteran', _snap(age: 40)), isFalse); // プロでなければ
    });

    test('二刀流・結婚・ライバル・Sランク・特性', () {
      final role = [const LifeEvent(30, 'role', '二刀流になった')];
      expect(
          _has(
              'two-way-title',
              _snap(events: role, records: [
                _pro(31, titles: ['最多勝'])
              ])),
          isTrue);
      expect(
          _has(
              'two-way-title',
              _snap(role: Role.twoWay, records: [
                _pro(31, titles: ['最多勝'])
              ])),
          isTrue);
      expect(
          _has(
              'two-way-title',
              _snap(records: [
                _pro(31, titles: ['最多勝'])
              ])),
          isFalse);
      expect(_has('two-way-title', _snap(events: role)), isFalse); // タイトル無し
      expect(_has('married', _snap(married: true)), isTrue);
      expect(
          _has('rival-winner', _snap(rivalWins: 10, rivalLosses: 9)), isTrue);
      expect(
          _has('rival-winner', _snap(rivalWins: 10, rivalLosses: 10)), isFalse);
      expect(
          _has('rival-winner', _snap(rivalWins: 9, rivalLosses: 0)), isFalse);
      expect(_has('s-rank', _snap(abilities: {Ability.contact: 90})), isTrue);
      expect(_has('s-rank', _snap(abilities: {Ability.contact: 89})), isFalse);
      expect(
          _has(
              'traits-full',
              _snap(traits: {
                Trait.genius,
                Trait.sturdy,
                Trait.sunny,
                Trait.ironMan
              })),
          isTrue);
      expect(
          _has('traits-full',
              _snap(traits: {Trait.genius, Trait.sturdy, Trait.sunny})),
          isFalse);
    });

    test('難しさの選択はなくしたので、むずかしい専用の実績も無い', () {
      expect(achievements.any((a) => a.id.startsWith('hard-')), isFalse);
    });
  });

  test('実際に遊んだ一生で、実績が矛盾なく解除される(プロ入りした一生は「プロの舞台へ」を含む)', () {
    var checked = 0;
    for (var seed = 0; seed < 40 && checked < 5; seed++) {
      final g = Game.newGame(
          name: 't', role: Role.batter, rng: Random(seed), potential: 100);
      var steps = 0;
      while (g.phase != Phase.retired) {
        if (++steps > 4000) fail('終わらない');
        g.autoSpend();
        switch (g.phase) {
          case Phase.term:
            if (g.stage == Stage.pro && g.player.age >= 34) {
              g.retire();
            } else {
              g.choose(g.condition.fatigue >= 60 ? Plan.rest : Plan.train,
                  Ability.contact);
            }
          case Phase.event:
            g.resolveEvent(0);
          case Phase.pathChoice:
            g.chooseRoute(Course.university);
          case Phase.retired:
            break;
        }
      }
      final earned = earnedBy(PlayerSnapshot.fromGame(g));
      expect(earned.contains('first-pro'), g.ending!.madePro,
          reason: 'seed=$seed');
      expect(earned.contains('legend'), g.ending!.title == 'レジェンド',
          reason: 'seed=$seed');
      expect(
          earned.contains('title'), g.records.any((r) => r.titles.isNotEmpty),
          reason: 'seed=$seed');
      checked++;
    }
    expect(checked, 5);
  });

  group('年俸の実績', () {
    // 評価が高いほど年俸が高い。強い成績の1年を作る。
    SeasonRecord star(int age) => SeasonRecord(
        age: age,
        stage: Stage.pro,
        line: const Line(
            games: 140, atBats: 500, hits: 190, totalBases: 360, walks: 90),
        rank: 1,
        titles: const ['首位打者', '本塁打王', 'MVP']);

    test('年俸が1億円を超える年があれば解除、無ければ解除されない', () {
      expect(salaryOf(star(28)), greaterThanOrEqualTo(10000));
      expect(_has('salary-oku', _snap(records: [star(28)])), isTrue);
      expect(_has('salary-oku', _snap(records: [_pro(28)])), isFalse);
    });

    test('通算10億円は、年俸の積み重ねで達成する', () {
      final many = [for (var a = 22; a < 40; a++) star(a)];
      final total = careerEarnings(many);
      expect(_has('earnings-10', _snap(records: many)), total >= 100000);
      expect(_has('earnings-10', _snap(records: [_pro(25)])), isFalse);
    });
  });
}
