import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/app/app.dart';
import 'package:ranse/app/controller.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/data.dart';
import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/rng.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 試験用の生まれ（2026-11-24、ユーザー「テスト用に、自分で諸々生まれ方を決められるようにして」）。
void main() {
  test('決めた項目はそのとおりになり、決めなかった項目は籤のまま', () {
    for (var s = 0; s < 200; s++) {
      final cls = kClasses[s % kClasses.length];
      final reg = kRegions[s % kRegions.length];
      final female = s.isEven;
      final b = customBirth(
        Rng(s),
        BirthSpec(
          clsId: cls.id,
          region: reg.n,
          female: female,
          order: 1 + s % 3,
          startYear: 1525 + s % 44,
        ),
      );
      expect(b.cls, cls);
      expect(b.region, reg);
      expect(reg.f, contains(b.faction));
      expect(b.female, female);
      expect(b.order, 1 + s % 3);
      expect(b.startYear, 1525 + s % 44);
      expect(b.label, clsLabel(cls, female, 1 + s % 3));
      expect(b.birthRank, calcBirthRank(cls, female, 1 + s % 3));
      expect(b.rarity, 1);
      for (final v in [b.stats.bu, b.stats.chi, b.stats.sei, b.stats.mi, b.stats.un]) {
        expect(v, inInclusiveRange(3, 99));
      }
    }
    // 何も決めなければ、籤と同じ生まれ。
    final a = rollBirth(Rng(7));
    final b = customBirth(Rng(7), const BirthSpec());
    expect(b.name, a.name);
    expect(b.cls, a.cls);
    expect(b.stats.bu, a.stats.bu);
  });

  test('特性と能力を決められ、特性なしも選べる', () {
    final b = customBirth(
      Rng(1),
      const BirthSpec(
        clsId: 'farmer',
        female: true,
        traitIds: ['onna', 'power', 'sickly', 'hardy'],
        stats: [90, 10, 50, 120, 0],
      ),
    );
    expect(b.traits.map((t) => t.id), ['onna', 'power', 'sickly']);
    expect([b.stats.bu, b.stats.chi, b.stats.sei, b.stats.mi, b.stats.un], [
      90,
      10,
      50,
      99,
      3,
    ]);
    final none = customBirth(Rng(1), const BirthSpec(traitIds: []));
    expect(none.traits, isEmpty);
  });

  test('決めた生まれで、最後まで遊べる', () {
    for (var s = 0; s < 120; s++) {
      final r = Rng(500 + s);
      final g = Game(rng: r)
        ..start(
          customBirth(
            r,
            BirthSpec(
              clsId: kClasses[s % kClasses.length].id,
              region: kRegions[(s * 7) % kRegions.length].n,
              female: s % 3 == 0,
              startYear: 1525 + (s * 5) % 44,
              stats: s.isEven ? [95, 95, 95, 95, 95] : null,
            ),
          ),
        );
      final pick = Rng(900 + s);
      var n = 0;
      while (!g.finished && n++ < 3000) {
        g.choose(pick.range(0, g.prompt!.choices.length - 1));
      }
      expect(g.finished, isTrue);
    }
  });

  testWidgets('試しの道具を入れないビルド（App Store の版）では、長押ししても試験用の画面は開かない', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final c = AppController(rng: Rng(3));
    expect(c.testTools, isFalse, reason: '既定は入れない（ビルドのときに RANSE_TEST_TOOLS を渡したときだけ）');
    await tester.pumpWidget(RanseApp(controller: c));
    await tester.pump();
    await tester.longPress(find.text('乱世下剋上'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('試験用の生まれ'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('タイトルの題字を長押しすると試験用の画面が開き、その生まれで始まる', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final c = AppController(rng: Rng(3), testTools: true);
    await tester.pumpWidget(RanseApp(controller: c));
    await tester.pump();
    await tester.longPress(find.text('乱世下剋上'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('試験用の生まれ'), findsOneWidget);
    await tester.ensureVisible(find.text('この生まれで始める'));
    await tester.tap(find.text('この生まれで始める'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(c.screen, AppScreen.birth);
    expect(c.birth, isNotNull);
    expect(find.text('この人生を生きる'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
