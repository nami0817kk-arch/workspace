/// **自分の選択で、選手の形が決まるか。**
///
/// 積み上げ（`Development.dedication`）が土台の鎖を緩めること、
/// 尖った1つ（`Person.standoutOf`）が値札と代表と出場機会に返ること、
/// 育てた結果いまのポジションより向いている役が出ることを見る。
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/dependencies.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/game/person.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/aptitude.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/development.dart';
import 'package:soccer_career/models/player.dart';
import 'package:soccer_career/state/career_controller.dart';
import 'package:soccer_career/ui/screens/hub_screen.dart';

class _MemoryRepository implements SaveRepository {
  CareerState? _saved;

  @override
  Future<CareerState?> load() async => _saved;

  @override
  Future<void> save(CareerState state) async => _saved = state;

  @override
  Future<void> clear() async => _saved = null;
}

Future<CareerController> started({int seed = 5}) async {
  final c = CareerController(
    repository: _MemoryRepository(),
    careerEngine: CareerEngine(random: Random(seed)),
    matchEngine: MatchEngine(random: Random(seed)),
    random: Random(seed),
  );
  await c.startCareer(
    name: '検証',
    position: Position.cm,
    age: 19,
    agent: Agent.pool.first,
  );
  return c;
}

Player _player({
  required Attributes attributes,
  Position position = Position.cm,
  Aptitude? aptitude,
}) => Player(
  name: 'P',
  age: 24,
  position: position,
  attributes: attributes,
  potential: 99,
  aptitude: aptitude,
);

void main() {
  group('積み上げが土台の鎖を緩める', () {
    test('積むほど、土台より先に行ける幅が広がる', () {
      expect(Dependencies.headroomFor(0), Dependencies.headroom);
      expect(
        Dependencies.headroomFor(Dependencies.dedicationStep),
        Dependencies.headroom + 1,
      );
      expect(
        Dependencies.headroomFor(Dependencies.dedicationStep * 3),
        Dependencies.headroom + 3,
      );
    });

    test('広がり方には上限がある', () {
      final far = Dependencies.headroomFor(
        Dependencies.dedicationStep * (Dependencies.dedicationMax + 20),
      );
      expect(far, Dependencies.headroom + Dependencies.dedicationMax);
    });

    test('積んだ項目は、土台に吸われずに伸びる', () {
      // 決定力はボールコントロールとシュート力を土台に持つ。
      // ちょうど頭打ちになる形を組む。
      final attributes = Attributes.fromDetails({
        for (final d in Detail.values) d: 60,
        Detail.finishing: 60 + Dependencies.headroom,
      });

      // 積んでいなければ土台のほうへ回る。
      expect(
        Dependencies.resolve(Detail.finishing, attributes),
        isNot(Detail.finishing),
        reason: '積んでいないのに、頭打ちの項目がそのまま伸びた',
      );

      // 積んでいれば、その項目が伸びる。
      expect(
        Dependencies.resolve(
          Detail.finishing,
          attributes,
          dedicationOf: (d) =>
              d == Detail.finishing ? Dependencies.dedicationStep : 0,
        ),
        Detail.finishing,
        reason: '積み上げても鎖が緩まない',
      );
    });

    test('積んだ項目だけが緩む', () {
      final attributes = Attributes.fromDetails({
        for (final d in Detail.values) d: 60,
        Detail.finishing: 60 + Dependencies.headroom,
      });
      expect(
        Dependencies.resolve(
          Detail.finishing,
          attributes,
          dedicationOf: (d) =>
              d == Detail.longShots ? Dependencies.dedicationStep * 5 : 0,
        ),
        isNot(Detail.finishing),
        reason: '別の項目に積んだぶんで緩んだ',
      );
    });
  });

  group('積み上げの記録', () {
    test('狙うたびに1つずつ積まれる', () {
      var development = const Development();
      expect(development.dedicationOf(Detail.finishing), 0);
      development = development.aiming(Detail.finishing);
      development = development.aiming(Detail.finishing);
      development = development.aiming(Detail.vision);
      expect(development.dedicationOf(Detail.finishing), 2);
      expect(development.dedicationOf(Detail.vision), 1);
    });

    test('保存に乗る', () async {
      final c = await started();
      final state = c.state!;
      state.development = state.development
          .aiming(Detail.tackling)
          .aiming(Detail.tackling);
      final back = CareerState.fromJson(state.toJson());
      expect(back.development.dedicationOf(Detail.tackling), 2);
    });

    test('積み上げを知らない保存データでも読める', () async {
      final c = await started();
      final json = c.state!.toJson();
      (json['development'] as Map).remove('dedication');
      expect(
        CareerState.fromJson(json).development.dedicationOf(Detail.finishing),
        0,
      );
    });

    test('経験点を振ると積まれる', () async {
      final c = await started();
      final state = c.state!;
      state.autoSpend = false;
      state.development = state.development.copyWith(
        points: {AttributeKey.passing: 999},
      );
      await c.spendPoint(Detail.shortPassing);
      expect(
        state.development.dedicationOf(Detail.shortPassing),
        greaterThan(0),
        reason: '自分で振ったぶんが積み上げに残らない',
      );
    });
  });

  group('一芸', () {
    test('平らな選手には一芸が付かない', () {
      final flat = _player(
        attributes: Attributes.fromDetails({
          for (final d in Detail.values) d: 75,
        }),
      );
      expect(Person.standoutOf(flat), 0);
      expect(Person.standoutKey(flat), isNull);
    });

    test('一芸と呼べる高さに届いていなければ付かない', () {
      // 総合力との差はあるが、カテゴリの値が低い選手。
      final low = _player(
        attributes: Attributes(
          pace: 40,
          shooting: 40,
          passing: Formulas.standoutFloor - 2,
          dribbling: 40,
          defending: 40,
          physical: 40,
        ),
      );
      expect(Person.standoutOf(low), 0, reason: '低い山でも一芸になった');
    });

    test('突き抜けていれば、その差だけ付く', () {
      final sharp = _player(
        attributes: Attributes(
          pace: 55,
          shooting: 55,
          passing: 96,
          dribbling: 55,
          defending: 55,
          physical: 55,
        ),
      );
      expect(Person.standoutKey(sharp), AttributeKey.passing);
      expect(
        Person.standoutOf(sharp),
        96 - sharp.overall - Formulas.standoutGap,
      );
      expect(Person.standoutOf(sharp), greaterThan(0));
    });

    test('代表の線は、一芸のぶんだけ下がる', () {
      // 尖らせるほど総合力は下がるので、ここが開いていないと
      // 尖った育成を選んだ時点で代表が消える。
      expect(Formulas.standoutCallUpRelief, greaterThan(0));
      expect(
        Formulas.standoutCallUpRelief,
        lessThan(Formulas.callUpOverall),
        reason: '一芸があれば誰でも呼ばれる',
      );
    });

    test('出場機会への下駄には上限がある', () {
      expect(Formulas.standoutAppearance, greaterThan(0));
      expect(Formulas.standoutAppearance, lessThanOrEqualTo(0.2));
    });

    test('同じ総合力でも、一芸があれば値札が高い', () async {
      // 総合力とは別に返らないと、尖らせることがただの損になる。
      final c = await started();
      final state = c.state!;

      // 尖った選手（パス96・他55）と、同じ総合力の平らな選手を比べる。
      final sharp = Attributes(
        pace: 55,
        shooting: 55,
        passing: 96,
        dribbling: 55,
        defending: 55,
        physical: 55,
      );
      state.player = state.player.copyWith(attributes: sharp);
      final overall = state.player.overall;
      expect(Person.standoutOf(state.player), greaterThan(0));
      final sharpValue = Person(random: Random(1)).marketValueFor(state);

      state.player = state.player.copyWith(
        attributes: Attributes.fromDetails({
          for (final d in Detail.values) d: overall,
        }),
      );
      expect(state.player.overall, overall, reason: '比べる相手の総合力がずれた');
      expect(Person.standoutOf(state.player), 0);
      final flatValue = Person(random: Random(1)).marketValueFor(state);

      expect(sharpValue, greaterThan(flatValue), reason: '一芸が値札に乗っていない');
    });
  });

  group('画面に出す', () {
    testWidgets('一芸は選手タブに出る', (tester) async {
      // 見えないと「伸ばしたのに総合力が落ちた」だけが残る。
      final c = await started();
      c.state!.player = c.state!.player.copyWith(
        attributes: Attributes(
          pace: 55,
          shooting: 55,
          passing: 96,
          dribbling: 55,
          defending: 55,
          physical: 55,
        ),
      );
      await tester.pumpWidget(MaterialApp(home: HubScreen(controller: c)));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, '選手'));
      await tester.pumpAndSettle();
      expect(find.textContaining('一芸 パス'), findsOneWidget);
    });
  });

  group('向いているポジション', () {
    test('本職が一番なら勧めない', () {
      final p = _player(
        attributes: Attributes.fromDetails({
          for (final d in Detail.values) d: 70,
        }),
        aptitude: Aptitude.initial(Position.cm),
      );
      expect(p.suitedPosition, isNull);
    });

    test('適性を持たない選手には勧めない', () {
      // 適性を知らない保存データで、いきなりコンバートを勧めない。
      final p = _player(
        attributes: Attributes(
          pace: 60,
          shooting: 60,
          passing: 60,
          dribbling: 60,
          defending: 95,
          physical: 90,
        ),
      );
      expect(p.aptitude.isUnknown, isTrue);
      expect(p.suitedPosition, isNull);
    });

    test('育てた先のほうが高ければ、その道を出す', () {
      // 中盤の選手を守備一本で育てた形。
      final p = _player(
        attributes: Attributes(
          pace: 60,
          shooting: 45,
          passing: 50,
          dribbling: 45,
          defending: 99,
          physical: 95,
        ),
        aptitude: Aptitude.initial(Position.cm),
      );
      final suited = p.suitedPosition;
      expect(suited, isNotNull, reason: '別の役のほうが高いのに出ない');
      expect(suited, isNot(p.position));
      expect(
        p.overallAt(suited!),
        greaterThanOrEqualTo(p.overall + Formulas.convertGain),
        reason: '大差ないのに勧めている',
      );
    });
  });
}
