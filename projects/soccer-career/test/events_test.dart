/// ピッチの外の出来事。人が出てくること、効きが行きすぎないこと。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/life_events.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/development.dart';
import 'package:soccer_career/models/life_event.dart';

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
