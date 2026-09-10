/// 局面の絵。
///
/// 試合画面はずっと文字だけだった。「ライン間で前を向いて受けた」と
/// 書いてあっても、それがピッチのどこで、相手がどう構えているのかは
/// 読んで想像するしかなかった。
///
/// 絵にする以上、**書いてあることと絵が違う**のが一番まずい。
/// ここで見張るのは、局面の文章と場所が食い違っていないことと、
/// 相手の戦い方の説明文と、描かれるブロックの形が噛み合っていること。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/scenarios.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/club.dart';
import 'package:soccer_career/models/development.dart';
import 'package:soccer_career/models/pitch.dart';
import 'package:soccer_career/ui/pitch_view.dart';

List<Scenario> get all => [
  for (final family in ScenarioFamily.values) ...ScenarioPool.forFamily(family),
];

Club club(String id) => Club(id: id, name: id, strength: 70, tier: 1);

void main() {
  group('場所', () {
    test('座標がピッチの中に収まっている', () {
      for (final spot in PitchSpot.values) {
        expect(spot.along, inInclusiveRange(0.0, 1.0), reason: spot.name);
        expect(spot.across, inInclusiveRange(0.0, 1.0), reason: spot.name);
        expect(spot.label, isNotEmpty);
      }
    });

    test('ラベルが重複していない', () {
      // 同じ名前の場所が2つあると、絵とチップの対応が付かない。
      final labels = PitchSpot.values.map((s) => s.label).toSet();
      expect(labels.length, PitchSpot.values.length);
    });

    test('全ての局面に場所がある', () {
      expect(all.length, 74);
      for (final s in all) {
        expect(PitchSpot.values.contains(s.spot), isTrue, reason: s.id);
      }
    });
  });

  group('文章と場所が食い違わない', () {
    test('GKの局面は自陣。上がるのは終盤のコーナーだけ', () {
      for (final s in ScenarioPool.goalkeeper) {
        if (s.id == 'gk-chase-corner') {
          expect(s.spot.isOwnHalf, isFalse, reason: '上がったのに自陣に居る');
          continue;
        }
        expect(s.spot.isOwnHalf, isTrue, reason: s.id);
      }
    });

    test('ペナルティエリアの局面は、その側のエリアに置いてある', () {
      for (final s in all) {
        if (!s.situation.contains('ペナルティエリア内') &&
            !s.situation.contains('PA内')) {
          continue;
        }
        // 自分が守る局面（DF/GK）は自陣、決める局面は敵陣。
        final own =
            ScenarioPool.goalkeeper.contains(s) ||
            ScenarioPool.defence.contains(s);
        expect(s.spot.isOwnHalf, own, reason: s.id);
        expect(
          [
            PitchSpot.ownBox,
            PitchSpot.box,
            PitchSpot.penaltySpot,
            PitchSpot.farPost,
            PitchSpot.opponentGoal,
            PitchSpot.ownGoalLine,
          ].contains(s.spot),
          isTrue,
          reason: '${s.id} が ${s.spot.label} に置かれている',
        );
      }
    });

    test('自陣で守る局面が敵陣に描かれていない', () {
      for (final s in all) {
        if (!s.situation.contains('自陣')) continue;
        expect(s.spot.isOwnHalf, isTrue, reason: s.id);
      }
    });

    test('コーナーキックの局面は隅にある', () {
      for (final s in all) {
        if (!s.id.endsWith('corner') || !s.situation.contains('自分')) continue;
        expect(s.spot, PitchSpot.cornerFlag, reason: s.id);
      }
    });
  });

  group('絵', () {
    testWidgets('描ける。場所と相手の戦い方が読み上げに乗る', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PitchView(
              spot: PitchSpot.betweenLines,
              club: club('home'),
              opponent: club('away'),
              style: ClubStyle.pressing,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PitchView), findsOneWidget);
      expect(find.bySemanticsLabel('ライン間。相手はハイプレス'), findsOneWidget);
    });

    testWidgets('どの場所・どの戦い方でも落ちない', (tester) async {
      for (final spot in PitchSpot.values) {
        for (final style in ClubStyle.values) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: PitchView(
                  spot: spot,
                  club: club('home'),
                  opponent: club('away'),
                  style: style,
                ),
              ),
            ),
          );
          await tester.pump();
        }
      }
      expect(tester.takeException(), isNull);
    });
  });
}
