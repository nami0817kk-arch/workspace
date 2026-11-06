import 'dart:math';

import 'package:basketball_career/deck/bot.dart';
import 'package:basketball_career/deck/cards.dart';
import 'package:basketball_career/deck/mates.dart';
import 'package:basketball_career/deck/run.dart';
import 'package:basketball_career/ui/app.dart';
import 'package:basketball_career/ui/deck/card_view.dart';
import 'package:basketball_career/ui/deck_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<DeckController> _controller([Map<String, Object> saved = const {}]) async {
  SharedPreferences.setMockInitialValues(saved);
  return DeckController(prefs: await SharedPreferences.getInstance(), seedSource: Random(3));
}

void _size(WidgetTester t, double w, double h) {
  t.view.physicalSize = Size(w, h);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

void main() {
  testWidgets('はじめの画面から始めて、試合を1つ遊び、カードを選んで次の行き先へ', (tester) async {
    _size(tester, 430, 932);
    final c = await _controller();
    await tester.pumpWidget(BasketballCareerApp(controller: c));
    await tester.pumpAndSettle();
    expect(find.text('ブザービーター'), findsOneWidget);

    await tester.tap(find.text('新しいシーズン'));
    await tester.pumpAndSettle();
    // はじめてなら、先に遊び方
    expect(find.text('遊び方'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('はじめる'), 300);
    await tester.tap(find.text('はじめる'));
    await tester.pumpAndSettle();
    expect(find.text('地区予選'), findsOneWidget);

    await tester.tap(find.text('試合').first);
    await tester.pumpAndSettle();
    expect(find.text('相手の予告'), findsOneWidget);
    expect(find.text('第1クォーター'), findsOneWidget);

    // 手札を押して出す
    final b = c.run!.battle!;
    final first = b.hand.firstWhere(b.canPlay);
    final before = b.stamina;
    await tester.tap(find.byWidgetPredicate((w) => w is CardView && identical(w.card, first)));
    await tester.pumpAndSettle();
    expect(b.stamina, before - first.cost);

    // 残りは自動で打って、ラウンド終了を押していく
    for (var i = 0; i < 20 && !b.over; i++) {
      botPlayRound(b);
      await tester.tap(find.textContaining('ラウンド終了'));
      await tester.pumpAndSettle();
    }
    expect(b.over, isTrue);
    final won = b.won;
    await tester.tap(find.textContaining('次へ'));
    await tester.pumpAndSettle();
    // 実績の知らせ(はじめての勝利など)を閉じる
    while (find.text('OK').evaluate().isNotEmpty) {
      await tester.tap(find.text('OK').first);
      await tester.pumpAndSettle();
    }
    if (won) {
      expect(find.text('勝利!'), findsOneWidget);
      await tester.tap(find.byType(CardView).first);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('をデッキに入れる'));
      await tester.pumpAndSettle();
      expect(c.run!.deck, hasLength(11));
    }
    expect(c.run!.phase, Phase.map);
    expect(c.run!.floor, 1);
  });

  testWidgets('続きは保存され、起動するとはじめの画面から「続きから」で戻れる', (tester) async {
    _size(tester, 390, 844);
    final c = await _controller();
    c.newRun();
    await tester.pumpWidget(const SizedBox());
    // 同じ保存で、新しく起動したことにする
    final prefs = await SharedPreferences.getInstance();
    final c2 = DeckController(prefs: prefs, seedSource: Random(4));
    await tester.pumpWidget(BasketballCareerApp(controller: c2));
    await tester.pumpAndSettle();
    expect(find.textContaining('続きから'), findsOneWidget);
    await tester.tap(find.textContaining('続きから'));
    await tester.pumpAndSettle();
    expect(find.text('地区予選'), findsOneWidget);
    expect(c2.run!.deck, hasLength(c.run!.deck.length));
  });

  group('どの画面も、小さいスマホ・大きいスマホ・iPad ではみ出さない', () {
    const sizes = [Size(360, 640), Size(390, 844), Size(430, 932), Size(1032, 1376)];

    Future<void> show(WidgetTester tester, DeckController c, Size s) async {
      _size(tester, s.width, s.height);
      await tester.pumpWidget(BasketballCareerApp(controller: c));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$s');
      await tester.pumpWidget(const SizedBox());
    }

    for (final s in sizes) {
      testWidgets('$s', (tester) async {
        final c = await _controller({'deckHowtoSeen': true});
        await show(tester, c, s); // はじめの画面
        c.newRun();
        final r = c.run!;
        r.mates.addAll(allMates.take(3));
        await show(tester, c, s); // 行き先
        await c.choose(NodeType.game);
        // 手札を多めにして並びを見る
        r.battle!.draw(5);
        await show(tester, c, s);
        botPlayBattle(r.battle!);
        await show(tester, c, s); // 試合終了
        r.phase = Phase.reward;
        r.rewardCards = [for (final id in ['deepthree', 'nolook', 'zone', 'eurostep']) CardInstance(card(id))];
        await show(tester, c, s);
        r.phase = Phase.mateReward;
        r.rewardMates = allMates.skip(3).take(2).toList();
        await show(tester, c, s);
        r.phase = Phase.practice;
        await show(tester, c, s);
        r.money = 500;
        r.map[r.floor] = [NodeType.shop];
        r.phase = Phase.map;
        await c.choose(NodeType.shop);
        await show(tester, c, s);
        r.phase = Phase.event;
        r.event = allEvents.reduce((a, b) => a.choices.join().length > b.choices.join().length ? a : b);
        await show(tester, c, s);
        r.phase = Phase.finished;
        r.champion = true;
        await show(tester, c, s);
      });
    }
  });

  testWidgets('カードの説明は長押しで大きく出る', (tester) async {
    _size(tester, 390, 844);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: CardView(
            card: CardInstance(card('alleyoop')),
            onLongPress: () => showCardDetail(context, CardInstance(card('alleyoop'))),
          ),
        ),
      ),
    ));
    await tester.longPress(find.byType(CardView));
    await tester.pumpAndSettle();
    expect(find.textContaining('強くすると'), findsOneWidget);
  });
}
