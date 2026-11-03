// 広告の流れを、本物と同じ「後から結果が来る」形の偽物で念入りに試す(2026-11-03)。
// monetization_test の FakeAds は show の中ですぐ結果を返すので、次の穴は通ってしまう:
// - 動画を見ている間に画面を離れると、見終えても何も入らない(docs/app-pitfalls.md 2番)
// - show を await しても見終わるまで待てていない(9番)
// - 見ている間に「広告を消す」が届く・2度押し・アプリが裏・返金で広告が戻る
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:baseball_manager/game/game.dart' show Phase;
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/monetization/ad_service.dart';
import 'package:baseball_manager/monetization/monetization.dart';
import 'package:baseball_manager/monetization/purchase_service.dart';
import 'package:baseball_manager/ui/app.dart';
import 'package:baseball_manager/ui/controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'monetization_test.dart' show FakeStore;

/// 結果をテストが後から決める広告。show は「閉じられるまで」戻らない(本物と同じ)。
class SlowAds implements AdService {
  bool ready = true;
  bool interstitialReady = true;
  bool interstitialShows = true;
  int inits = 0, disposes = 0, reloads = 0, rewardedShown = 0, interstitials = 0;
  Completer<RewardResult>? playing;

  @override
  Future<void> initialize() async => inits++;
  @override
  bool get isRewardedAdReady => ready;
  @override
  bool get isInterstitialReady => interstitialReady;
  @override
  Future<bool> waitForRewarded(Duration max) async => ready;
  @override
  void ensureLoaded() => reloads++;
  @override
  Future<RewardResult> showRewardedAd() {
    rewardedShown++;
    return (playing = Completer<RewardResult>()).future;
  }

  /// 動画を閉じる(最後まで見た/途中で閉じた)。
  void finish(RewardResult r) => playing!.complete(r);

  @override
  Future<bool> showInterstitialAd() async {
    if (!interstitialReady) return false;
    interstitials++;
    return interstitialShows;
  }

  @override
  void dispose() => disposes++;
}

Future<(Monetization, SlowAds, FakeStore)> _open(
    [Map<String, Object> saved = const {}]) async {
  SharedPreferences.setMockInitialValues(saved);
  final prefs = await SharedPreferences.getInstance();
  final ads = SlowAds(), store = FakeStore();
  final m = Monetization(prefs, ads: ads, store: store);
  await m.start();
  return (m, ads, store);
}

GameController _tired(Monetization m) {
  final c = GameController(rng: Random(3), money: m);
  c.newGame('動画', Role.batter);
  c.game!.condition =
      c.game!.condition.copyWith(fatigue: 85, injuredTerms: 0);
  return c;
}

Future<void> _settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('見終えたのに入らない、を起こさない', () {
    testWidgets('動画を見ている間に画面を離れても、見終えれば疲れが抜ける(2番)', (t) async {
      final (m, ads, _) = await t.runAsync(() => _open()) ?? (throw 'x');
      final c = GameController(rng: Random(3), money: m);
      t.view.physicalSize = const Size(900, 2400);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(BaseballManagerApp(controller: c));
      await t.pumpAndSettle();
      c.newGame('離れる', Role.batter);
      c.game!.condition =
          c.game!.condition.copyWith(fatigue: 85, injuredTerms: 0);
      c.notifyListeners();
      await t.pumpAndSettle();
      final button = find.byKey(const Key('ad-recovery'));
      await t.ensureVisible(button);
      await t.tap(button);
      await t.pump();
      expect(ads.rewardedShown, 1);
      // 動画の再生中に、画面ごと捨てる
      await t.pumpWidget(const SizedBox());
      ads.finish(RewardResult.earned);
      await t.pump();
      await t.pump();
      expect(c.game!.condition.fatigue, 25);
      expect(t.takeException(), isNull);
    });

    test('見終わるまで疲れは抜けず、閉じた時点で抜ける(show が先に戻る形にしない。9番)', () async {
      final (m, ads, _) = await _open();
      final c = _tired(m);
      final run = c.recoverByAd();
      await _settle();
      expect(ads.rewardedShown, 1);
      expect(c.game!.condition.fatigue, 85); // まだ見ている
      ads.finish(RewardResult.earned);
      expect(await run, contains('抜けました'));
      expect(c.game!.condition.fatigue, 25);
    });

    test('経験点の動画も、見終えてから入る。途中で閉じたら入らず、もう一度使える', () async {
      final (m, ads, _) = await _open();
      final c = _tired(m);
      final before = c.game!.exp.total;
      var run = c.expByAd();
      await _settle();
      ads.finish(RewardResult.closedEarly);
      expect(await run, contains('最後まで'));
      expect(c.game!.exp.total, before);
      expect(c.canExpByAd, isTrue);
      run = c.expByAd();
      await _settle();
      expect(c.canExpByAd, isFalse); // 再生中に2本目を出さない
      ads.finish(RewardResult.earned);
      expect(await run, contains('経験点 +'));
      expect(c.game!.exp.total, greaterThan(before));
    });

    test('動画を見ている間に「広告を消す」が届いたら、途中で閉じても特典を渡す', () async {
      final (m, ads, store) = await _open();
      final c = _tired(m);
      final run = c.recoverByAd();
      await _settle();
      await store.delivered!(PurchaseService.removeAdsId); // 家族の承認など
      ads.finish(RewardResult.closedEarly);
      expect(await run, contains('抜けました'));
      expect(c.game!.condition.fatigue, 25);
    });

    test('2度押ししても、動画は1本・特典は1回', () async {
      final (m, ads, _) = await _open();
      final c = _tired(m);
      final a = c.recoverByAd();
      final b = c.recoverByAd();
      expect(await b, '今は使えません。');
      await _settle();
      ads.finish(RewardResult.earned);
      await a;
      expect(ads.rewardedShown, 1);
      expect(c.game!.condition.fatigue, 25);
    });

    test('表示に失敗したら特典は渡さず、その年のうちにもう一度試せる', () async {
      final (m, ads, _) = await _open();
      final c = _tired(m);
      final run = c.recoverByAd();
      await _settle();
      ads.finish(RewardResult.showFailed);
      expect(await run, contains('出せませんでした'));
      expect(c.game!.condition.fatigue, 85);
      expect(c.canRecoverByAd, isTrue);
    });

    test('動画を読み込めないときはタダで渡さず、待っている合図を出す', () async {
      final (m, ads, _) = await _open();
      ads.ready = false;
      final c = _tired(m);
      var waited = false;
      final text = await c.recoverByAd(onWaiting: () => waited = true);
      expect(text, contains('読み込めません'));
      expect(waited, isTrue);
      expect(ads.reloads, greaterThan(0)); // 読み直しを頼んでいる
      expect(ads.rewardedShown, 0);
      expect(c.game!.condition.fatigue, 85);
    });
  });

  group('全画面広告', () {
    testWidgets('アプリが裏のときは出さず、数えは保って次の年に出す', (t) async {
      final (m, ads, _) =
          await t.runAsync(() => _open({'baseball_yearsSinceAd': 3})) ??
              (throw 'x');
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(await t.runAsync(() => m.afterYear(20)), isFalse);
      expect(ads.interstitials, 0);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(await t.runAsync(() => m.afterYear(21)), isTrue);
      expect(ads.interstitials, 1);
    });

    test('年が変わった直後に出来事の選択肢が出ていたら、答えて季節の選択に戻ってから出す', () async {
      // 年替わりの直後に出来事が出る選手を探す(選択肢の上に広告が被さると、押し間違えで広告を開いてしまう)
      for (var seed = 0; seed < 200; seed++) {
        final (m, ads, _) = await _open({'baseball_yearsSinceAd': 3});
        final c = GameController(rng: Random(seed), money: m);
        c.newGame('節目', Role.batter);
        final g = c.game!;
        g.player = g.player.copyWith(age: 15);
        while (g.phase == Phase.event) {
          c.chooseEvent(0);
        }
        c.act(Plan.rest); // 15歳として覚える
        while (g.phase == Phase.event) {
          c.chooseEvent(0);
        }
        g.player = g.player.copyWith(age: 16);
        c.act(Plan.rest); // 16歳になった
        if (g.phase != Phase.event) continue;
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        expect(ads.interstitials, 0, reason: '出来事の選択中に出した(seed $seed)');
        while (g.phase == Phase.event) {
          c.chooseEvent(0);
        }
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        expect(ads.interstitials, 1, reason: '選択が終わっても出ていない(seed $seed)');
        return;
      }
      fail('年替わりの直後に出来事が出る選手が見つからなかった');
    });

    test('出そうとして失敗したら数えは戻さず、次の年にもう一度試す', () async {
      final (m, ads, _) = await _open({'baseball_yearsSinceAd': 3});
      ads.interstitialShows = false;
      expect(await m.afterYear(20), isFalse);
      ads.interstitialShows = true;
      expect(await m.afterYear(21), isTrue);
      expect(await m.afterYear(22), isFalse); // 出したら数え直し
    });

    test('少年野球(13歳未満)のあいだは数えも進めない', () async {
      final (m, ads, _) = await _open();
      for (var age = 6; age < 13; age++) {
        await m.afterYear(age);
      }
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('baseball_yearsSinceAd') ?? 0, 0);
      expect(ads.interstitials, 0);
    });
  });

  group('広告を消す と広告の準備', () {
    test('広告を消した人は、起動時に広告を準備しない', () async {
      final (_, ads, _) = await _open({'baseball_adFree': true});
      expect(ads.inits, 0);
    });

    test('買ったら読み込み済みの広告と読み直しを止める', () async {
      final (m, ads, store) = await _open();
      expect(ads.inits, 1);
      await store.delivered!(PurchaseService.removeAdsId);
      expect(ads.disposes, 1);
      m.refreshAds(); // アプリに戻っても読み直さない
      expect(ads.reloads, 0);
    });

    test('返金で広告が戻ったら、広告を準備し直し、戻った直後の年替わりでは出さない', () async {
      final (m, ads, store) =
          await _open({'baseball_adFree': true, 'baseball_yearsSinceAd': 3});
      store.entitlement = false;
      await store.revoked!(PurchaseService.removeAdsId);
      expect(m.adFree, isFalse);
      expect(ads.inits, 1);
      expect(await m.afterYear(20), isFalse);
      expect(ads.interstitials, 0);
    });

    test('返金の照合の最中に買い直しが届いたら、古い記録で広告を戻さない', () async {
      final (m, _, store) = await _open({'baseball_adFree': true});
      final gate = Completer<bool?>();
      final slow = _GatedStore(store, gate);
      final prefs = await SharedPreferences.getInstance();
      final m2 = Monetization(prefs, ads: SlowAds(), store: slow);
      final starting = m2.start();
      await _settle();
      await slow.delivered!(PurchaseService.removeAdsId); // 照合の途中で届く
      gate.complete(false); // 記録の上では返金済み(古い記録)
      await starting;
      expect(m2.adFree, isTrue);
      expect(m.adFree, isTrue);
    });

    test('ほかのアプリの商品が届いても、何も付けない', () async {
      final (m, _, store) = await _open();
      await store.delivered!('com.example.other');
      await store.revoked!('com.example.other');
      expect(m.adFree, isFalse);
      expect(m.legacyBoost, isFalse);
    });
  });

  test('ストアの半角の円記号は、同梱フォントにある全角で出す(docs/app-pitfalls.md 6番)', () {
    expect(displayPrice('\u00A5370'), '\uFFE5370');
    expect(displayPrice('\uFFE5370'), '\uFFE5370');
    expect(displayPrice(r'$2.99'), r'$2.99');
    expect(displayPrice(null), isNull);
  });

  group('設定画面の購入', () {
    Future<(GameController, FakeStore)> openSettings(WidgetTester t,
        {void Function(FakeStore)? tweak}) async {
      final (m, _, store) = await t.runAsync(() => _open()) ?? (throw 'x');
      tweak?.call(store);
      final c = GameController(rng: Random(3), money: m);
      t.view.physicalSize = const Size(900, 3000);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(BaseballManagerApp(controller: c));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('設定').first);
      await t.pumpAndSettle();
      return (c, store);
    }

    Future<void> tapItem(WidgetTester t, Key key) async {
      final f = find.byKey(key);
      await t.scrollUntilVisible(f, 200,
          scrollable: find.byType(Scrollable).last);
      await t.tap(f);
      await t.pumpAndSettle();
    }

    testWidgets('継承ブーストは ¥250 で出て、買うと購入済みになる。広告は消えない', (t) async {
      final (c, store) = await openSettings(t);
      const key = Key('buy-${PurchaseService.legacyBoostId}');
      await t.scrollUntilVisible(find.byKey(key), 200,
          scrollable: find.byType(Scrollable).last);
      expect(find.text('\uFFE5250'), findsOneWidget);
      await tapItem(t, key);
      expect(store.bought, [PurchaseService.legacyBoostId]);
      expect(c.money!.legacyBoost, isTrue);
      expect(c.money!.adFree, isFalse);
      expect(find.byKey(const Key('owned-${PurchaseService.legacyBoostId}')),
          findsOneWidget);
      expect(find.byKey(const Key('remove-ads')), findsOneWidget);
      expect(find.textContaining('購入が完了しました'), findsOneWidget);
    });

    testWidgets('承認待ち・取りやめ・失敗で、それぞれの案内が出て、何も付かない', (t) async {
      final (c, store) = await openSettings(t);
      store.buyResult = PurchaseOutcome.pending;
      await tapItem(t, const Key('remove-ads'));
      expect(find.textContaining('保護者の承認'), findsOneWidget);
      expect(c.money!.adFree, isFalse);
      store.buyResult = PurchaseOutcome.canceled;
      await t.pump(const Duration(seconds: 5));
      await t.pumpAndSettle();
      await tapItem(t, const Key('remove-ads'));
      expect(find.byType(SnackBar), findsNothing); // 自分でやめたのに叱らない
      store.buyResult = PurchaseOutcome.failed;
      await tapItem(t, const Key('remove-ads'));
      expect(find.textContaining('購入できませんでした'), findsOneWidget);
      expect(c.money!.adFree, isFalse);
    });

    testWidgets('復元するものが無ければそう伝え、あれば両方戻る', (t) async {
      final (c, store) = await openSettings(t);
      store.restoreResult = PurchaseOutcome.unavailable;
      await tapItem(t, const Key('restore-purchases'));
      expect(find.textContaining('見つかりませんでした'), findsOneWidget);
      await t.pump(const Duration(seconds: 5));
      await t.pumpAndSettle();
      store
        ..restoreResult = PurchaseOutcome.purchased
        ..restoreIds = PurchaseService.allIds;
      await tapItem(t, const Key('restore-purchases'));
      expect(c.money!.adFree && c.money!.legacyBoost, isTrue);
      expect(find.textContaining('復元しました'), findsOneWidget);
    });

    testWidgets('価格が取れない商品は出さないが、復元の入口は残す(審査で復元が見えるように)',
        (t) async {
      await openSettings(t, tweak: (s) => s.price = null);
      expect(find.byKey(const Key('remove-ads')), findsNothing);
      await t.scrollUntilVisible(
          find.byKey(const Key('restore-purchases')), 200,
          scrollable: find.byType(Scrollable).last);
      expect(find.byKey(const Key('restore-purchases')), findsOneWidget);
    });
  });

  group('広告SDKの使い方(原文。9番: show を await しても見終わるまで待てない)', () {
    final src = File('lib/monetization/ad_service.dart').readAsStringSync();
    // AdMob の実装(NoOp は「=>」の1行なので、波かっこで始まるほう)
    final body = src.substring(
        src.indexOf('Future<RewardResult> showRewardedAd() async {'),
        src.indexOf('Future<bool> showInterstitialAd() async {'));

    test('動画の show を直接 await して報酬を返さない', () {
      expect(body, isNot(contains('await ad.show(')));
    });

    test('閉じた通知(onAdDismissedFullScreenContent)まで待ち、報酬の遅れも少し待つ', () {
      expect(src, contains('onAdDismissedFullScreenContent'));
      expect(src, contains('onAdFailedToShowFullScreenContent'));
      expect(src, contains('return closed.future;'));
      expect(body, contains('_rewardGrace'));
      expect(body, contains('keepAfterDismiss: true'));
    });

    test('表示が始まった後は打ち切らない(広告から App Store へ行って戻らなくても報酬を捨てない)', () {
      expect(src, contains('onAdShowedFullScreenContent'));
      expect(src, contains('started.future'));
    });

    test('リリースの CI が本物の広告IDに差し替えたかを確かめている', () {
      final wf = File('../../.github/workflows/baseball-ios-release.yml')
          .readAsStringSync();
      expect(wf, contains('ADMOB_REWARDED_IOS'));
      expect(wf, contains('ADMOB_INTERSTITIAL_IOS'));
      expect(wf, contains('3940256099942544')); // テスト用IDのままなら止める検査
    });
  });
}

/// 購入記録の読み出しを、テストが返すまで止めておくストア。
class _GatedStore extends FakeStore {
  _GatedStore(FakeStore base, this.gate) {
    entitlement = base.entitlement;
  }
  final Completer<bool?> gate;

  @override
  Future<bool?> hasEntitlement(String productId) =>
      productId == PurchaseService.removeAdsId ? gate.future : Future.value(null);
}
