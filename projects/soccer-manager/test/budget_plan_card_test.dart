import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/models/budget_plan.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/theme/fm_look.dart';
import 'package:soccer_manager/theme/semantic_colors.dart';
import 'package:soccer_manager/widgets/budget_plan_card.dart';

/// 「今年の予算の配り方」のカード。つまみをやめ、−／＋・残り・決定・
/// 元に戻す・おまかせの型にした(2026-11-24)。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
  });
  tearDown(() => Tr.language = AppLanguage.system);

  Future<GameState> pumpCard(
    WidgetTester tester, {
    BudgetPlan? saved,
    Size size = const Size(360, 900),
  }) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    late GameState gameState;
    await tester.runAsync(() async {
      gameState = GameState();
      await gameState.startNewGame('テストFC');
      if (saved != null) await gameState.setBudgetPlan(saved);
    });
    await tester.pumpWidget(ChangeNotifierProvider<GameState>.value(
      value: gameState,
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: BudgetPlanCard()),
        ),
      ),
    ));
    return gameState;
  }

  Finder key(String k) => find.byKey(ValueKey(k));
  String textOf(WidgetTester tester, String k) =>
      tester.widget<Text>(key(k)).data!;
  bool enabled(WidgetTester tester, String k) =>
      tester.widget<ButtonStyleButton>(key(k)).onPressed != null;
  bool iconEnabled(WidgetTester tester, String k) =>
      tester.widget<IconButton>(key(k)).onPressed != null;
  Map<BudgetCategory, int> shown(WidgetTester tester) => {
        for (final c in BudgetCategory.values)
          c: int.parse(
              textOf(tester, 'budget-share-${c.name}').replaceAll('%', '')),
      };
  Future<void> tap(WidgetTester tester, String k) async {
    await tester.ensureVisible(key(k));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(key(k));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
  }

  testWidgets('つまみは無く、−を押すと残りが出て、他の配り先は変わらない', (tester) async {
    final gameState = await pumpCard(tester);
    expect(find.byType(Slider), findsNothing);
    expect(textOf(tester, 'budget-remaining'), contains('残り 0%'));
    expect(textOf(tester, 'budget-detail-signing'), contains('給与の上限 +0%'));

    await tap(tester, 'budget-minus-signing');

    expect(shown(tester), {
      BudgetCategory.signing: 25,
      BudgetCategory.youth: 20,
      BudgetCategory.facilities: 15,
      BudgetCategory.marketing: 15,
      BudgetCategory.dividend: 20,
    });
    expect(textOf(tester, 'budget-remaining'), contains('残り 5%'));

    // 効き目は下書きの値ですぐ変わる(補強 30%→20% で給与の上限 -5%)。
    await tap(tester, 'budget-minus-signing');
    expect(textOf(tester, 'budget-detail-signing'), contains('給与の上限 -5%'));
    expect(textOf(tester, 'budget-remaining'), contains('残り 10%'));
    // 押しただけでは保存されない。
    expect(gameState.budgetPlan.share(BudgetCategory.signing), 30);
  });

  testWidgets('残りが0でないと決定が押せず、理由が出る。配り切ると押せる', (tester) async {
    await pumpCard(tester);
    // 何も変えていないうちは、どちらのボタンも押せない。
    expect(enabled(tester, 'budget-commit'), isFalse);
    expect(enabled(tester, 'budget-reset'), isFalse);
    // 残りが無いので、＋はどれも押せない。
    for (final c in BudgetCategory.values) {
      expect(iconEnabled(tester, 'budget-plus-${c.name}'), isFalse);
    }

    await tap(tester, 'budget-minus-dividend');
    await tap(tester, 'budget-minus-dividend');
    expect(enabled(tester, 'budget-commit'), isFalse);
    expect(enabled(tester, 'budget-reset'), isTrue);
    expect(textOf(tester, 'budget-reason'), '残り10%を配ってください');

    await tap(tester, 'budget-plus-youth');
    expect(textOf(tester, 'budget-reason'), '残り5%を配ってください');
    await tap(tester, 'budget-plus-youth');
    expect(key('budget-reason'), findsNothing);
    expect(enabled(tester, 'budget-commit'), isTrue);

    // 同じ配分に戻したら、変えていないのと同じ扱い。
    await tap(tester, 'budget-minus-youth');
    await tap(tester, 'budget-minus-youth');
    await tap(tester, 'budget-plus-dividend');
    await tap(tester, 'budget-plus-dividend');
    expect(enabled(tester, 'budget-commit'), isFalse);
    expect(enabled(tester, 'budget-reset'), isFalse);
  });

  testWidgets('0%まで減らせて、0%では−が押せない', (tester) async {
    await pumpCard(tester);
    for (var i = 0; i < 3; i++) {
      await tap(tester, 'budget-minus-facilities');
    }
    expect(shown(tester)[BudgetCategory.facilities], 0);
    expect(iconEnabled(tester, 'budget-minus-facilities'), isFalse);
    expect(textOf(tester, 'budget-remaining'), contains('残り 15%'));
  });

  testWidgets('決定で5つまとめて保存され、元に戻すで保存してある配分に戻る', (tester) async {
    final gameState = await pumpCard(tester);

    await tap(tester, 'budget-minus-dividend');
    await tap(tester, 'budget-plus-signing');
    expect(shown(tester)[BudgetCategory.signing], 35);
    await tap(tester, 'budget-reset');
    expect(shown(tester), BudgetPlan.balanced().shares);
    expect(gameState.budgetPlan.sameAs(BudgetPlan.balanced()), isTrue);

    await tap(tester, 'budget-minus-dividend');
    await tap(tester, 'budget-minus-marketing');
    await tap(tester, 'budget-plus-signing');
    await tap(tester, 'budget-plus-youth');
    await tap(tester, 'budget-commit');

    expect(gameState.budgetPlan.shares, {
      BudgetCategory.signing: 35,
      BudgetCategory.youth: 25,
      BudgetCategory.facilities: 15,
      BudgetCategory.marketing: 10,
      BudgetCategory.dividend: 15,
    });
    expect(shown(tester), gameState.budgetPlan.shares);
    expect(enabled(tester, 'budget-commit'), isFalse);
    expect(enabled(tester, 'budget-reset'), isFalse);
  });

  testWidgets('おまかせの型はどれも合計100・5の倍数で、決定するまで保存しない', (tester) async {
    final gameState = await pumpCard(tester);
    for (final id in ['signing', 'youth', 'balanced']) {
      await tap(tester, 'budget-preset-$id');
      final s = shown(tester);
      expect(s.values.fold<int>(0, (t, v) => t + v), 100, reason: id);
      expect(s.values.every((v) => v % 5 == 0), isTrue, reason: id);
      expect(textOf(tester, 'budget-remaining'), contains('残り 0%'));
      expect(gameState.budgetPlan.sameAs(BudgetPlan.balanced()), isTrue);
    }
    await tap(tester, 'budget-preset-signing');
    expect(shown(tester)[BudgetCategory.signing], 50);
    await tap(tester, 'budget-commit');
    expect(gameState.budgetPlan.sameAs(BudgetPlan.signingFocus()), isTrue);
  });

  testWidgets('5の倍数でない保存値は実値のまま見せ、−／＋で5の倍数へ寄せ、合計100で決定できる', (tester) async {
    final odd = BudgetPlan.draft(const {
      BudgetCategory.signing: 33,
      BudgetCategory.youth: 22,
      BudgetCategory.facilities: 14,
      BudgetCategory.marketing: 13,
      BudgetCategory.dividend: 18,
    });
    final gameState = await pumpCard(tester, saved: odd);
    expect(shown(tester), odd.shares);
    expect(enabled(tester, 'budget-commit'), isFalse);

    await tap(tester, 'budget-minus-signing'); // 33 → 30、残り3
    expect(shown(tester)[BudgetCategory.signing], 30);
    await tap(tester, 'budget-minus-youth'); // 22 → 20、残り5
    expect(shown(tester)[BudgetCategory.youth], 20);
    await tap(tester, 'budget-plus-facilities'); // 14 → 15、残り4
    expect(shown(tester)[BudgetCategory.facilities], 15);
    await tap(tester, 'budget-plus-marketing'); // 13 → 15、残り2
    expect(shown(tester)[BudgetCategory.marketing], 15);
    await tap(tester, 'budget-plus-dividend'); // 18 → 20、残り0
    expect(shown(tester)[BudgetCategory.dividend], 20);

    expect(textOf(tester, 'budget-remaining'), contains('残り 0%'));
    await tap(tester, 'budget-commit');
    expect(gameState.budgetPlan.sameAs(BudgetPlan.balanced()), isTrue);
  });

  testWidgets('残りが1刻みに足りないときは、＋で残りを全部足して配り切れる', (tester) async {
    final gameState = await pumpCard(
      tester,
      saved: BudgetPlan.draft(const {
        BudgetCategory.signing: 33,
        BudgetCategory.youth: 20,
        BudgetCategory.facilities: 15,
        BudgetCategory.marketing: 15,
        BudgetCategory.dividend: 17,
      }),
    );
    await tap(tester, 'budget-minus-signing'); // 残り3
    await tap(tester, 'budget-plus-youth'); // 20 → 23(残りは3しか無い)
    expect(shown(tester)[BudgetCategory.youth], 23);
    expect(textOf(tester, 'budget-remaining'), contains('残り 0%'));
    await tap(tester, 'budget-commit');
    expect(gameState.budgetPlan.total, 100);
    expect(gameState.budgetPlan.share(BudgetCategory.youth), 23);
  });

  testWidgets('−と＋は 52 以上(横画面の 0.93 倍で 48pt 以上)', (tester) async {
    await pumpCard(tester);
    for (final c in BudgetCategory.values) {
      for (final side in ['minus', 'plus']) {
        final s = tester.getSize(key('budget-$side-${c.name}'));
        expect(s.width * 0.93, greaterThanOrEqualTo(48));
        expect(s.height * 0.93, greaterThanOrEqualTo(48));
      }
    }
  });

  testWidgets('狭い列(幅300)でも、日本語・英語ともはみ出さない', (tester) async {
    for (final lang in [AppLanguage.japanese, AppLanguage.english]) {
      Tr.language = lang;
      await pumpCard(tester, size: const Size(300, 1200));
      await tap(tester, 'budget-minus-signing');
      expect(tester.takeException(), isNull, reason: '$lang');
    }
  });

  test('配り先の色は、明るい箱・暗い箱のどちらでも 3:1 以上', () {
    for (final p in [FmPalette.light, FmPalette.dark]) {
      for (final c in BudgetCategory.values) {
        final color = BudgetPlanCard.colorFor(c, p.brightness);
        expect(SemanticColors.contrast(color, p.surfaceContainerLow),
            greaterThanOrEqualTo(3.0),
            reason: '${c.name} ${p.brightness}');
      }
    }
  });

  group('BudgetPlan の下書き', () {
    test('stepDown / stepUp は他を動かさず、合計は100を超えない', () {
      var p = BudgetPlan.balanced();
      expect(p.stepUp(BudgetCategory.youth).sameAs(p), isTrue);
      p = p.stepDown(BudgetCategory.signing);
      expect(p.remaining, 5);
      expect(p.share(BudgetCategory.youth), 20);
      p = p.stepUp(BudgetCategory.youth);
      expect(p.isComplete, isTrue);
      expect(p.share(BudgetCategory.youth), 25);
    });

    test('draft は範囲の外と合計100超えを受け付けない', () {
      Map<BudgetCategory, int> m(int s) => {
            BudgetCategory.signing: s,
            BudgetCategory.youth: 20,
            BudgetCategory.facilities: 15,
            BudgetCategory.marketing: 15,
            BudgetCategory.dividend: 20,
          };
      expect(BudgetPlan.draft(m(10)).remaining, 20);
      expect(() => BudgetPlan.draft(m(31)), throwsArgumentError);
      expect(() => BudgetPlan.draft(m(-1)), throwsArgumentError);
    });

    test('setBudgetPlan は配り切っていない配分を保存しない', () async {
      final gameState = GameState();
      await gameState.startNewGame('テストFC');
      final partial = BudgetPlan.balanced().stepDown(BudgetCategory.signing);
      await expectLater(gameState.setBudgetPlan(partial), throwsArgumentError);
      expect(gameState.budgetPlan.sameAs(BudgetPlan.balanced()), isTrue);
    });
  });
}
