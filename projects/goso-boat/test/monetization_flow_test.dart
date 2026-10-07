// 広告と課金を画面から通して確かめる（2026-09-28 リリース前の確認）。
// 本物の AdMob と App Store の代わりに、結果を決められる偽物をつなぐ。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goso_boat/app/progress.dart';
import 'package:goso_boat/app/settings.dart';
import 'package:goso_boat/engine/puzzle.dart';
import 'package:goso_boat/main.dart';
import 'package:goso_boat/monetization/ad_service.dart';
import 'package:goso_boat/monetization/monetization.dart';
import 'package:goso_boat/monetization/purchase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAds implements AdService {
  bool ready = true;
  bool watchToEnd = true;
  int rewarded = 0;
  int interstitials = 0;
  int reloads = 0;

  @override
  Future<void> initialize() async {}
  @override
  bool get isRewardedAdReady => ready;
  @override
  bool get isInterstitialReady => interstitialReady;
  bool interstitialReady = true;
  @override
  Future<bool> waitForRewarded(Duration max) async => ready;
  @override
  void ensureLoaded() => reloads++;
  @override
  Future<RewardResult> showRewardedAd() async {
    rewarded++;
    return watchToEnd ? RewardResult.earned : RewardResult.closedEarly;
  }

  @override
  Future<bool> showInterstitialAd() async {
    if (!interstitialReady) return false;
    interstitials++;
    return true;
  }
  @override
  void dispose() {}
}

class FakeStore implements PurchaseService {
  bool available = true;
  String? price = '¥370';
  PurchaseOutcome buyResult = PurchaseOutcome.purchased;
  PurchaseOutcome restoreResult = PurchaseOutcome.purchased;
  int buys = 0;
  Future<void> Function(String)? delivered;

  @override
  set onDelivered(Future<void> Function(String productId)? cb) => delivered = cb;
  Future<void> Function(String)? revoked;
  @override
  set onRevoked(Future<void> Function(String productId)? cb) => revoked = cb;
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> isAvailable() async => available;
  @override
  Future<String?> priceLabel() async => price;
  @override
  Future<PurchaseOutcome> buyRemoveAds() async {
    buys++;
    // 本物と同じく、成立したらストアからの通知が先に届く
    if (buyResult == PurchaseOutcome.purchased) await delivered?.call(PurchaseService.removeAdsId);
    return buyResult;
  }

  @override
  Future<bool?> hasEntitlement() async => null;

  @override
  Future<PurchaseOutcome> restore() async {
    if (restoreResult == PurchaseOutcome.purchased) await delivered?.call(PurchaseService.removeAdsId);
    return restoreResult;
  }

  @override
  void dispose() {}
}

List<Level> _levels() {
  final data = jsonDecode(File('assets/levels.json').readAsStringSync()) as Map<String, Object?>;
  return (data['levels']! as List).map((e) => Level.fromJson(e as Map<String, Object?>)).toList();
}

Future<(Progress, Monetization, FakeAds, FakeStore, GameSettings)> _open([Map<String, Object> saved = const {}]) async {
  SharedPreferences.setMockInitialValues({for (var w = 1; w <= 8; w++) 'intro.$w': true, ...saved});
  final p = await Progress.open(_levels());
  final ads = FakeAds(), store = FakeStore();
  final m = Monetization(p.prefsForTest, ads: ads, store: store);
  await m.start();
  return (p, m, ads, store, GameSettings(p.prefsForTest, silent: true));
}

Future<void> _pumpApp(WidgetTester tester, Progress p, Monetization m, GameSettings st) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(GosoBoatApp(progress: p, money: m, settings: st, locale: const Locale('ja')));
  await tester.pump(const Duration(milliseconds: 300));
}

/// ホームから「つづきから／はじめる」で面に入る。
Future<void> _enterGame(WidgetTester tester) async {
  final start = find.textContaining(RegExp('はじめる|つづきから'));
  await tester.ensureVisible(start);
  await tester.tap(start);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(seconds: 2));
}

/// ヒントに従って今の面を解ききる（ヒントは動画か、広告を消していれば無料）。
Future<void> _solveWithHints(WidgetTester tester, int par) async {
  for (var i = 0; i < par; i++) {
    await tester.tap(find.textContaining('ヒント'));
    await tester.pump(const Duration(milliseconds: 300));
    final target = ['向こう岸', '中州', '手前の岸'].firstWhere((pl) => find.textContaining('で$plへ').evaluate().isNotEmpty);
    await tester.tap(find.text('$targetへ'));
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 600));
  }
  await tester.pump(const Duration(milliseconds: 800));
}

/// 設定画面の中の項目（ListView は画面外を作らないので、そこまで送ってから探す）。
Future<Finder> _inSettings(WidgetTester tester, String text) async {
  final f = find.descendant(of: find.byType(ListView), matching: find.text(text));
  await tester.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).last);
  await tester.pump(const Duration(milliseconds: 100));
  return f;
}

void main() {
  group('広告を消す（買い切り）', () {
    testWidgets('ホームに値段つきで出て、買うと「広告なし」に変わる', (tester) async {
      final (p, m, _, store, st) = await _open();
      await _pumpApp(tester, p, m, st);
      await tester.pump(const Duration(milliseconds: 300));
      final btn = find.text('広告を消す（¥370）');
      expect(btn, findsOneWidget, reason: '値段はストアから取った表示をそのまま出す');
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pump(const Duration(milliseconds: 300));
      expect(store.buys, 1);
      expect(m.adFree, isTrue);
      expect(find.text('広告を消しました。ご購入ありがとうございます！'), findsOneWidget);
      expect(find.text('広告なし'), findsOneWidget);
      expect(find.text('広告を消す（¥370）'), findsNothing, reason: '買った後はボタンを出さない');
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('取りやめたら何も変わらず、失敗したら知らせる', (tester) async {
      final (p, m, _, store, st) = await _open();
      store.buyResult = PurchaseOutcome.canceled;
      await _pumpApp(tester, p, m, st);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(find.text('広告を消す（¥370）'));
      await tester.tap(find.text('広告を消す（¥370）'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(m.adFree, isFalse);
      expect(find.byType(SnackBar), findsNothing, reason: '自分でやめたときはエラーを出さない');
      await tester.pump(const Duration(seconds: 1));
      store.buyResult = PurchaseOutcome.failed;
      await tester.tap(find.text('広告を消す（¥370）'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(m.adFree, isFalse);
      expect(find.text('購入できませんでした。支払いが済んでいれば、少しして自動で広告が消えます'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('値段が取れないときは買うボタンだけ隠し、「購入を復元」は残す', (tester) async {
      final (p, m, _, store, st) = await _open();
      store.price = null;
      await _pumpApp(tester, p, m, st);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('広告を消す'), findsNothing);
      expect(find.text('購入を復元'), findsOneWidget, reason: '機種変更した人が戻せなくならないように');
    });

    testWidgets('ストアそのものが使えないときは何も出さない', (tester) async {
      final (p, m, _, store, st) = await _open();
      store.available = false;
      await _pumpApp(tester, p, m, st);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('広告を消す'), findsNothing);
      expect(find.text('購入を復元'), findsNothing);
    });

    testWidgets('購入の保留（承認待ち）は、そう知らせて広告はまだ消さない', (tester) async {
      final (p, m, _, store, st) = await _open();
      store.buyResult = PurchaseOutcome.pending;
      await _pumpApp(tester, p, m, st);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(find.text('広告を消す（¥370）'));
      await tester.tap(find.text('広告を消す（¥370）'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('購入の手続きが保留中です。完了すると広告が消えます'), findsOneWidget);
      expect(m.adFree, isFalse);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('設定の「購入を復元」: 戻れば広告なし、無ければそう知らせる', (tester) async {
      final (p, m, _, store, st) = await _open();
      store.restoreResult = PurchaseOutcome.unavailable;
      await _pumpApp(tester, p, m, st);
      await tester.tap(find.byTooltip('設定'));
      await tester.pump(const Duration(milliseconds: 600));
      final restore = await _inSettings(tester, '購入を復元');
      await tester.tap(restore);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('復元できる購入が見つかりませんでした'), findsOneWidget);
      expect(m.adFree, isFalse);
      await tester.pump(const Duration(seconds: 5));
      store.restoreResult = PurchaseOutcome.purchased;
      await tester.tap(restore);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('購入を復元しました'), findsOneWidget);
      expect(m.adFree, isTrue);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  testWidgets('設定にプライバシーポリシーと「お問い合わせ・広告の報告」がある（Apple 5.1.1・2.5.18）', (tester) async {
    final (p, m, _, _, st) = await _open();
    await _pumpApp(tester, p, m, st);
    await tester.tap(find.byTooltip('設定'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(await _inSettings(tester, 'プライバシーポリシー'), findsOneWidget);
    expect(await _inSettings(tester, 'お問い合わせ・広告の報告'), findsOneWidget);
  });

  group('ヒントの動画', () {
    testWidgets('「動画でヒント」を押すと動画を1本見せ、見終えたらヒントが出る', (tester) async {
      final (p, m, ads, _, st) = await _open();
      await _pumpApp(tester, p, m, st);
      await _enterGame(tester);
      expect(find.text('動画で\nヒント'), findsOneWidget, reason: '動画が要ることをボタンに書く');
      await tester.tap(find.text('動画で\nヒント'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(ads.rewarded, 1);
      expect(find.textContaining('で向こう岸へ'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('途中で閉じたらヒントは出ない／読み込めていなければ出さずに知らせる', (tester) async {
      final (p, m, ads, _, st) = await _open();
      await _pumpApp(tester, p, m, st);
      await _enterGame(tester);
      ads.watchToEnd = false;
      await tester.tap(find.text('動画で\nヒント'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('動画を最後まで見るとヒントが出る'), findsOneWidget);
      expect(find.textContaining('で向こう岸へ'), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      ads.ready = false;
      await tester.tap(find.text('動画で\nヒント'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('動画の準備ができていません。少し待ってもう一度'), findsOneWidget);
      expect(ads.rewarded, 1, reason: '読み込めていない動画は出そうとしない');
      expect(ads.reloads, 1, reason: '読み込み直しを始める');
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('広告を消した人は、動画なしでヒントが出る', (tester) async {
      final (p, m, ads, _, st) = await _open({'adFree': true});
      await _pumpApp(tester, p, m, st);
      await _enterGame(tester);
      expect(find.text('ヒント'), findsOneWidget);
      await tester.tap(find.text('ヒント'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(ads.rewarded, 0);
      expect(find.textContaining('で向こう岸へ'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  testWidgets('クリア後に「もう一度」でやり直しても、2回目のクリアで結果の札が出る（ヒントを見た面は星2のまま）', (tester) async {
    final ls = _levels();
    final w2 = ls.firstWhere((l) => l.world == 2);
    final (p, m, ads, _, st) = await _open({
      for (final l in ls.where((l) => l.world == 1)) 'stars.${l.id}': 3,
    });
    await _pumpApp(tester, p, m, st);
    await _enterGame(tester);
    await _solveWithHints(tester, w2.par);
    expect(find.text('全員護送'), findsOneWidget);
    await tester.tap(find.text('もう一度'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('全員護送'), findsNothing);
    await _solveWithHints(tester, w2.par);
    expect(find.text('全員護送'), findsOneWidget, reason: '2回目のクリアでも結果の札が出る');
    expect(find.textContaining('ヒントを使ったので星2つまで'), findsOneWidget);
    expect(ads.rewarded, w2.par * 2, reason: '動画1本でヒント1回');
    await tester.pump(const Duration(seconds: 3));
  });

  group('全画面広告', () {
    testWidgets('広告の番では600ms置いてから出し、その間に2度押ししても1回だけ', (tester) async {
      final ls = _levels();
      final w2 = ls.firstWhere((l) => l.world == 2);
      final (p, m, ads, _, st) = await _open({
        for (final l in ls.where((l) => l.world == 1)) 'stars.${l.id}': 3,
        'clearsSinceAd': 2,
      });
      await _pumpApp(tester, p, m, st);
      await _enterGame(tester);
      await _solveWithHints(tester, w2.par);
      await tester.tap(find.text('次の面へ'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(ads.interstitials, 0, reason: '押した指が広告に当たらないよう、まだ出さない');
      await tester.tap(find.text('次の面へ'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 400));
      expect(ads.interstitials, 1);
      expect(p.prefsForTest.getInt('clearsSinceAd'), 0);
      await tester.pump(const Duration(seconds: 3));
      expect(ads.interstitials, 1);
    });

    testWidgets('広告の番で手元に無ければ、「次の面へ」は待たせずに進み、次の面でもう一度試す', (tester) async {
      final ls = _levels();
      final w2 = ls.where((l) => l.world == 2).toList();
      final (p, m, ads, _, st) = await _open({
        for (final l in ls.where((l) => l.world == 1)) 'stars.${l.id}': 3,
        'clearsSinceAd': 2,
      });
      ads.interstitialReady = false;
      await _pumpApp(tester, p, m, st);
      await _enterGame(tester);
      final before = ads.reloads;
      await _solveWithHints(tester, w2.first.par);
      expect(ads.reloads, greaterThan(before), reason: '結果の札の間に読み込みを始める');
      await tester.tap(find.text('次の面へ'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 2));
      expect(ads.interstitials, 0);
      expect(p.prefsForTest.getInt('clearsSinceAd'), 3, reason: '出せなければ次でもう一度');
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('「次の面へ」を2度押ししても1回ぶんしか数えない（舞台2）', (tester) async {
      final ls = _levels();
      final w2 = ls.firstWhere((l) => l.world == 2);
      final (p, m, ads, _, st) = await _open({
        for (final l in ls.where((l) => l.world == 1)) 'stars.${l.id}': 3,
      });
      await _pumpApp(tester, p, m, st);
      await _enterGame(tester);
      expect(find.textContaining(w2.id), findsWidgets);
      await _solveWithHints(tester, w2.par);
      expect(find.text('全員護送'), findsOneWidget);
      await tester.tap(find.text('次の面へ'));
      await tester.tap(find.text('次の面へ'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(seconds: 2));
      expect(p.prefsForTest.getInt('clearsSinceAd'), 1, reason: '2度押しで数えが進まない');
      expect(ads.interstitials, 0, reason: '3面に1回なので、まだ出ない');
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('逃げられたとき（失敗）には全画面広告を数えない', (tester) async {
      final (p, m, ads, _, st) = await _open();
      await _pumpApp(tester, p, m, st);
      await _enterGame(tester);
      // 1-1 で警官を3人とも乗せて出す（囚人が1人残って逃げる）
      for (var i = 0; i < 3; i++) {
        final pol = find.bySemanticsLabel('警官、手前の岸');
        await tester.tap(pol.first);
        await tester.pump(const Duration(milliseconds: 300));
      }
      await tester.tap(find.text('向こう岸へ'));
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('脱走された'), findsOneWidget);
      expect(p.prefsForTest.getInt('clearsSinceAd'), isNull);
      expect(ads.interstitials, 0);
      await tester.pump(const Duration(seconds: 3));
    }, semanticsEnabled: true);
  });
}
