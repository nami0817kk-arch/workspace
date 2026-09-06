import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_clicker/game/engine.dart';
import 'package:soccer_clicker/game/formulas.dart';
import 'package:soccer_clicker/game/game_controller.dart';
import 'package:soccer_clicker/game/models.dart';
import 'package:soccer_clicker/storage/save_store.dart';

/// 進められる時計。放置収入を待たずに検証するために使う。
class FakeClock {
  int now = 0;
  int call() => now;
  void advance(Duration d) => now += d.inMilliseconds;
}

void main() {
  late InMemorySaveStore store;
  late FakeClock clock;

  setUp(() {
    store = InMemorySaveStore();
    clock = FakeClock();
  });

  GameController build() => GameController(
        store: store,
        clock: clock.call,
        random: Random(7),
      );

  test('初回起動は新規ゲームで始まる', () async {
    final controller = build();
    await controller.start();
    addTearDown(controller.dispose);

    expect(controller.isReady, isTrue);
    expect(controller.state.ep, 0);
    expect(controller.state.players, hasLength(1));
    expect(controller.offlineGain, 0);
  });

  test('セーブが残っていれば引き継ぐ', () async {
    final first = build();
    await first.start();
    first.tap();
    first.tap();
    final epBefore = first.state.ep;
    first.dispose();

    final second = build();
    await second.start();
    addTearDown(second.dispose);

    expect(second.state.ep, epBefore);
    expect(second.state.totalTaps, 2);
  });

  test('閉じている間の放置収入が復帰時に入る', () async {
    final first = build();
    await first.start();
    // コーチを買えるだけの EP をタップで貯める
    while (!first.canBuy(UpgradeKind.coach)) {
      first.tap();
    }
    first.buyUpgrade(UpgradeKind.coach);
    final epBefore = first.state.ep;
    first.dispose();

    clock.advance(const Duration(minutes: 10));

    final second = build();
    await second.start();
    addTearDown(second.dispose);

    final expected = Formulas.epPerSecond(1) * 600;
    expect(second.offlineGain, closeTo(expected, 1e-6));
    expect(second.state.ep, closeTo(epBefore + expected, 1e-6));
  });

  test('放置収入は8時間で頭打ちになる', () async {
    final first = build();
    await first.start();
    while (!first.canBuy(UpgradeKind.coach)) {
      first.tap();
    }
    first.buyUpgrade(UpgradeKind.coach);
    first.dispose();

    clock.advance(const Duration(days: 3));

    final second = build();
    await second.start();
    addTearDown(second.dispose);

    final capped = Formulas.epPerSecond(1) * Formulas.offlineCap.inSeconds;
    expect(second.offlineGain, closeTo(capped, 1e-6));
  });

  test('コーチが居なければ放置しても増えない', () async {
    final first = build();
    await first.start();
    first.tap();
    final epBefore = first.state.ep;
    first.dispose();

    clock.advance(const Duration(hours: 5));

    final second = build();
    await second.start();
    addTearDown(second.dispose);

    expect(second.offlineGain, 0);
    expect(second.state.ep, epBefore);
  });

  test('買えないときは状態が変わらない', () async {
    final controller = build();
    await controller.start();
    addTearDown(controller.dispose);

    final reason = controller.buyUpgrade(UpgradeKind.training);
    expect(reason, RejectReason.notEnoughEp);
    expect(controller.state.trainingLevel, 0);
  });

  test('壊れたセーブは新規開始に倒す', () async {
    store.seedRaw('{ this is not json');

    final controller = build();
    await controller.start();
    addTearDown(controller.dispose);

    expect(controller.isReady, isTrue);
    expect(controller.state.ep, 0);
    expect(controller.state.players, hasLength(1));
  });

  test('形が違う JSON でも新規開始に倒す', () async {
    store.seedRaw('{"ep": "文字列", "players": 3}');

    final controller = build();
    await controller.start();
    addTearDown(controller.dispose);

    expect(controller.state.ep, 0);
  });

  test('リセットで最初からになる', () async {
    final controller = build();
    await controller.start();
    addTearDown(controller.dispose);

    for (var i = 0; i < 30; i++) {
      controller.tap();
    }
    expect(controller.state.ep, greaterThan(0));

    await controller.reset();
    expect(controller.state.ep, 0);
    expect(controller.state.totalTaps, 0);
    expect(await store.load(), isNotNull);
  });

  test('操作のたびに保存される', () async {
    final controller = build();
    await controller.start();
    addTearDown(controller.dispose);

    controller.tap();
    final saved = await store.load();
    expect(saved, isNotNull);
    expect(saved!.totalTaps, 1);
  });
}
