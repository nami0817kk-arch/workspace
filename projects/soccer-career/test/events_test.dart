/// ピッチの外の出来事。人が出てくること、効きが行きすぎないこと。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/life_events.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/development.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/game/newsroom.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/life.dart';
import 'package:soccer_career/models/life_event.dart';
import 'package:soccer_career/models/news.dart';
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

Future<CareerController> started({int seed = 3}) async {
  final c = CareerController(
    repository: _MemoryRepository(),
    careerEngine: CareerEngine(random: Random(seed)),
    matchEngine: MatchEngine(random: Random(seed)),
    random: Random(seed),
  );
  await c.startCareer(
      name: '検証', position: Position.cm, age: 24, agent: Agent.pool.first);
  return c;
}

LifeContext context({
  int age = 24,
  int fame = 30,
  Map<PersonKind, String> people = const {},
  int overall = 70,
}) =>
    LifeContext(
      age: age,
      fame: fame,
      savings: 5000,
      abroad: false,
      afterInjury: false,
      sponsorOffered: false,
      captaincyOffered: false,
      lowMorale: false,
      people: people,
      overall: overall,
    );

void main() {
  group('外から見える節目は見出しに残る', () {
    test('腕章・スポンサー・財団は記事になり、断った話はならない', () async {
      // 出来事は33種あって毎季何度も起きるのに、見出しには一度も
      // 残っていなかった（NewsKind.life はスタッフ解散だけが使っていた）。
      final c = await started();
      final state = c.state!;
      state.sponsor = const Sponsor(name: 'アストレア', annual: 500);

      expect(Newsroom.lifeMoment(state, LifeSpecial.takeCaptain), isNotNull);
      expect(Newsroom.lifeMoment(state, LifeSpecial.acceptSponsor), isNotNull);
      expect(Newsroom.lifeMoment(state, LifeSpecial.foundCharity), isNotNull);

      // 断った話は世の中に出ない。
      expect(Newsroom.lifeMoment(state, LifeSpecial.declineCaptain), isNull);
      expect(Newsroom.lifeMoment(state, LifeSpecial.declineSponsor), isNull);
      expect(Newsroom.lifeMoment(state, LifeSpecial.none), isNull);

      // 中身は数字まで書く。
      final sponsor =
          Newsroom.lifeMoment(state, LifeSpecial.acceptSponsor)!;
      expect(sponsor.kind, NewsKind.life);
      expect(sponsor.headline, contains('アストレア'));
      expect(sponsor.body, contains('500'));
    });

    test('スポンサーが決まっていなければ、記事にしない', () async {
      final c = await started();
      c.state!.sponsor = null;
      expect(
          Newsroom.lifeMoment(c.state!, LifeSpecial.acceptSponsor), isNull);
    });

    test('腕章を受けると、実際に見出しへ積まれる', () async {
      final c = await started();
      final state = c.state!;
      final before = state.news.length;
      c.pendingEvent = LifeEvent(
        id: 'test-captain',
        title: '腕章',
        body: '任せたい',
        choices: const [
          LifeChoice(
            label: '引き受ける',
            outcome: '引き受けた',
            effect: LifeEffect(special: LifeSpecial.takeCaptain),
          ),
        ],
      );
      await c.resolveEvent(c.pendingEvent!.choices.first);
      expect(state.captain, isTrue);
      expect(state.news.length, before + 1);
      expect(state.news.first.kind, NewsKind.life);
    });
  });

  group('人が出てくる', () {
    test('しるしを使う出来事は、その人が居ることを条件にしている', () {
      // 条件を付け忘れると、画面に <mentor> がそのまま出る。
      for (final event in LifeEvents.catalogue) {
        final text = [
          event.title,
          event.body,
          for (final c in event.choices) ...[c.label, c.outcome],
        ].join();
        for (final kind in PersonKind.values) {
          if (!text.contains(kind.token)) continue;
          expect(event.requirement.needsPerson, kind,
              reason: '${event.id} が ${kind.token} を使っているのに'
                  '条件になっていない');
        }
      }
    });

    test('名前に差し替わる', () {
      final event = LifeEvents.catalogue
          .firstWhere((e) => e.requirement.needsPerson == PersonKind.mentor);
      final filled = event.withNames({PersonKind.mentor: '田中 一郎'});
      final text = [
        filled.title,
        filled.body,
        for (final c in filled.choices) ...[c.label, c.outcome],
      ].join();
      expect(text, contains('田中 一郎'));
      expect(text, isNot(contains(PersonKind.mentor.token)));
      // 選択肢の中身は変わらない。
      expect(filled.choices.length, event.choices.length);
      expect(filled.choices.first.effect, event.choices.first.effect);
    });

    test('その人が居なければ引かれない', () {
      final events = LifeEvents(random: Random(1));
      // 誰も居ない状態で100回引いて、人の出来事が混ざらないこと。
      for (var i = 0; i < 100; i++) {
        final picked = events.pick(context());
        if (picked == null) continue;
        expect(picked.requirement.needsPerson, isNull, reason: picked.id);
      }
    });

    test('居れば引かれる', () {
      final events = LifeEvents(random: Random(2));
      var sawPerson = false;
      for (var i = 0; i < 200 && !sawPerson; i++) {
        final picked = events.pick(context(people: {
          PersonKind.mentor: 'M',
          PersonKind.rival: 'R',
        }));
        if (picked?.requirement.needsPerson != null) sawPerson = true;
      }
      expect(sawPerson, isTrue, reason: '人の出来事が一度も出ない');
    });
  });

  group('出来事が週の主役になる', () {
    LifeContext context({
      bool pushingHard = false,
      bool promised = false,
      bool lowCondition = false,
      Map<PersonKind, String> people = const {},
    }) =>
        LifeContext(
          age: 26,
          fame: 40,
          savings: 5000,
          abroad: false,
          afterInjury: false,
          sponsorOffered: false,
          captaincyOffered: false,
          lowMorale: false,
          overall: 72,
          people: people,
          pushingHard: pushingHard,
          promised: promised,
          lowCondition: lowCondition,
        );

    /// [pick] を何度も引いて、出た ID を数える。
    Map<String, int> draws(
      LifeContext c, {
      PersonKind? with_,
      List<String> recent = const [],
      int times = 600,
    }) {
      final counts = <String, int>{};
      for (var seed = 0; seed < times; seed++) {
        final e = LifeEvents(random: Random(seed))
            .pick(c, with_: with_, recent: recent);
        if (e == null) continue;
        counts[e.id] = (counts[e.id] ?? 0) + 1;
      }
      return counts;
    }

    test('3節に1回くらいは何か起きる', () {
      // 6節に1回だと「たまに何か出る画面」で、週の主役にはならない。
      expect(LifeEvents.chancePerMatch, greaterThan(0.2));
      // 毎試合だと邪魔になる。
      expect(LifeEvents.chancePerMatch, lessThan(0.4));
    });

    test('自分が選んだことが、出来事になって返ってくる', () {
      final plain = draws(context()).keys.toSet();
      expect(plain.contains('push-body'), isFalse);
      expect(plain.contains('promise-weight'), isFalse);

      expect(draws(context(pushingHard: true)).keys, contains('push-body'));
      expect(draws(context(promised: true)).keys, contains('promise-weight'));
      expect(draws(context(lowCondition: true)).keys, contains('tired-choice'));
    });

    test('一緒に練習している相手の話が出やすい', () {
      const people = {
        PersonKind.partner: '相方',
        PersonKind.mentor: 'メンター',
        PersonKind.competitor: '競争相手',
      };
      int partnerDraws({PersonKind? with_}) {
        final counts = draws(context(people: people), with_: with_);
        var total = 0;
        counts.forEach((id, n) {
          if (LifeEvents.catalogue
                  .firstWhere((e) => e.id == id)
                  .person ==
              PersonKind.partner) {
            total += n;
          }
        });
        return total;
      }

      expect(partnerDraws(with_: PersonKind.partner),
          greaterThan(partnerDraws()));
      expect(LifeEvents.companionWeight, greaterThan(1));
    });

    test('直前に出た話は、続けて出さない', () {
      final counts = draws(context());
      final common = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
      final after = draws(context(), recent: [common.key]);
      expect(after.containsKey(common.key), isFalse,
          reason: '同じ話が続けて出ている');
    });

    test('避けた結果ゼロになるなら、そのまま出す', () {
      // 候補が1つしか無い状況で黙って何も出さないと、出来事が消える。
      final all = draws(context()).keys.toList();
      final e = LifeEvents(random: Random(1)).pick(context(), recent: all);
      expect(e, isNotNull);
    });

    test('選択肢に「何に効くか」が出る', () {
      // 名前だけの三択は、どれを押しても同じに見えて選ぶ材料が無かった。
      for (final event in LifeEvents.catalogue) {
        for (final choice in event.choices) {
          expect(choice.effect.summary, isNotEmpty,
              reason: '${event.id} の「${choice.label}」に効きが無い');
        }
      }
    });

    test('画面に出す疲労と、実際に乗る疲労が同じ', () {
      // 表示用に別の式を書かない。
      for (final event in LifeEvents.catalogue) {
        for (final choice in event.choices) {
          final e = choice.effect;
          if (e.totalFatigue == 0) continue;
          expect(e.summary, contains('疲労 ${e.totalFatigue > 0 ? '+' : ''}${e.totalFatigue}'),
              reason: event.id);
        }
      }
    });

    test('ピッチの外で伸びるにも、身体を使う', () {
      // 出来事の頻度を上げたとき、伸びの効きだけが倍になって
      // ピーク総合力と代表経験が膨らんだ。ただの上乗せ装置にしない。
      for (final event in LifeEvents.catalogue) {
        for (final choice in event.choices) {
          final e = choice.effect;
          if (e.train == null) continue;
          expect(e.totalFatigue, greaterThan(e.fatigue), reason: event.id);
        }
      }
    });

    test('直近に出た話は保存に乗り、古い保存データでは空', () async {
      final c = await started();
      c.state!.recentEvents = ['a', 'b'];
      final json = c.state!.toJson();
      expect(CareerState.fromJson(json).recentEvents, ['a', 'b']);
      expect(CareerState.fromJson(json..remove('recentEvents')).recentEvents,
          isEmpty);
    });

    test('答えた話は、覚えておく数だけ残る', () async {
      final c = await started();
      final state = c.state!;
      for (var i = 0; i < 40; i++) {
        await c.simulateMatch();
      }
      expect(state.recentEvents.length,
          lessThanOrEqualTo(CareerState.recentEventsKept));
    });
  });

  group('効きの上限', () {
    test('繰り返し起きる出来事は、性格を動かさない', () {
      // 性格は「経験で1シーズンに1〜2点」動くもの。毎年何度も動かすと、
      // プロ意識が練習の効きを押し上げて総合力が膨らむ。
      for (final event in LifeEvents.catalogue.where((e) => !e.once)) {
        for (final choice in event.choices) {
          final e = choice.effect;
          expect(
            e.confidence.abs() +
                e.ambition.abs() +
                e.professionalism.abs() +
                e.temper.abs(),
            lessThanOrEqualTo(1),
            reason: '${event.id} の「${choice.label}」が性格を動かしすぎる',
          );
        }
      }
    });

    test('1回で人生が決まる大きさにしない', () {
      for (final event in LifeEvents.catalogue) {
        for (final choice in event.choices) {
          final e = choice.effect;
          // 気持ちは0〜100で、成功率への効きは±3%まで。一度きりの
          // 大きな出来事でも、この幅なら人生は決まらない。
          expect(e.morale.abs(), lessThanOrEqualTo(20), reason: event.id);
          expect(e.fame.abs(), lessThanOrEqualTo(10), reason: event.id);
          expect(e.manager.abs(), lessThanOrEqualTo(10), reason: event.id);
          expect(e.teammates.abs(), lessThanOrEqualTo(10), reason: event.id);
          expect(e.trainAmount, lessThanOrEqualTo(2), reason: event.id);
          expect(e.condition.abs(), lessThanOrEqualTo(12), reason: event.id);
        }
      }
    });

    test('選択肢は2つ以上あり、文が埋まっている', () {
      for (final event in LifeEvents.catalogue) {
        expect(event.choices.length, greaterThanOrEqualTo(2),
            reason: event.id);
        expect(event.title, isNotEmpty, reason: event.id);
        expect(event.body, isNotEmpty, reason: event.id);
        for (final c in event.choices) {
          expect(c.label, isNotEmpty, reason: event.id);
          expect(c.outcome, isNotEmpty, reason: event.id);
        }
      }
    });

    test('IDが重複していない', () {
      final ids = LifeEvents.catalogue.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('数と中身', () {
    test('人の出来事も、練習の中の出来事も揃っている', () {
      expect(LifeEvents.catalogue.length, greaterThanOrEqualTo(30),
          reason: '出来事が少ないと、同じものばかり出る');
      final withPerson = LifeEvents.catalogue
          .where((e) => e.requirement.needsPerson != null)
          .length;
      expect(withPerson, greaterThanOrEqualTo(8), reason: '人が出てこない');
      final withTrain = LifeEvents.catalogue
          .where((e) => e.choices.any((c) => c.effect.train != null))
          .length;
      expect(withTrain, greaterThanOrEqualTo(4), reason: '能力に繋がらない');
      final withInsight = LifeEvents.catalogue
          .where((e) => e.choices.any((c) => c.effect.insight != null))
          .length;
      expect(withInsight, greaterThanOrEqualTo(2), reason: '技を閃く機会が無い');
    });

    test('伸びる能力は、そのカテゴリの詳細になっている', () {
      for (final event in LifeEvents.catalogue) {
        for (final c in event.choices) {
          final train = c.effect.train;
          if (train == null) continue;
          expect(Detail.values, contains(train), reason: event.id);
        }
        for (final c in event.choices) {
          final insight = c.effect.insight;
          if (insight == null) continue;
          expect(Signature.values, contains(insight), reason: event.id);
        }
      }
    });
  });
}
