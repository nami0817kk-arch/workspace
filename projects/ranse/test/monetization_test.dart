import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/app/controller.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/rng.dart';
import 'package:ranse/monetization/ad_service.dart';
import 'package:ranse/monetization/monetization.dart';
import 'package:ranse/monetization/purchase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 差し替えの広告。本物と同じく、動画の報酬は「出す」を頼んだあとで届く（docs/app-pitfalls.md の9）。
class FakeAds implements AdService {
  bool rewardedReady = true;
  bool watchToEnd = true;
  bool interstitialReady = true;
  bool interstitialShows = true;
  int interstitials = 0;
  int rewardeds = 0;
  int reloads = 0;
  int initializes = 0;
  int disposes = 0;

  /// 動画を閉じるのを外から決める（画面を離れてから見終える、を試すため）。
  Completer<void>? holdRewarded;

  @override
  Future<void> initialize() async => initializes++;
  @override
  bool get isRewardedAdReady => rewardedReady;
  @override
  bool get isInterstitialReady => interstitialReady;
  @override
  Future<bool> waitForRewarded(Duration max) async => rewardedReady;
  @override
  void ensureLoaded() => reloads++;
  @override
  Future<RewardResult> showRewardedAd() async {
    rewardeds++;
    final h = holdRewarded;
    if (h != null) await h.future;
    await Future<void>.delayed(Duration.zero);
    return watchToEnd ? RewardResult.earned : RewardResult.closedEarly;
  }

  @override
  Future<bool> showInterstitialAd() async {
    if (!interstitialReady) return false;
    await Future<void>.delayed(Duration.zero);
    if (!interstitialShows) return false;
    interstitials++;
    return true;
  }

  @override
  void dispose() => disposes++;
}

class FakeStore extends NoOpPurchaseService {
  PurchaseOutcome next = PurchaseOutcome.purchased;
  Future<void> Function(String)? _delivered;
  Future<void> Function(String)? _revoked;
  @override
  set onDelivered(Future<void> Function(String productId)? cb) =>
      _delivered = cb;
  @override
  set onRevoked(Future<void> Function(String productId)? cb) => _revoked = cb;

  /// ストアから直接届く（家族の承認・起動時の再送。誰も待っていない）。
  Future<void> deliver([String id = PurchaseService.removeAdsId]) async =>
      _delivered?.call(id);
  Future<void> revoke() async => _revoked?.call(PurchaseService.removeAdsId);

  bool? entitlement;
  @override
  Future<bool?> hasEntitlement() async => entitlement;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<PurchaseOutcome> buyRemoveAds() async {
    // 本物と同じく、結果を返す前に通知で届ける
    if (next == PurchaseOutcome.purchased) await deliver();
    return next;
  }

  @override
  Future<PurchaseOutcome> restore() async => buyRemoveAds();
}

class Clock {
  DateTime t = DateTime(2026, 11, 25, 12);
  DateTime now() => t;
  void pass(Duration d) => t = t.add(d);
}

Future<(Monetization, FakeAds, FakeStore, Clock)> make({
  Map<String, Object> saved = const {},
  bool? entitlement,
}) async {
  SharedPreferences.setMockInitialValues(saved);
  final ads = FakeAds(), store = FakeStore()..entitlement = entitlement;
  final clock = Clock();
  final m = Monetization(
    await SharedPreferences.getInstance(),
    ads: ads,
    store: store,
    clock: clock.now,
    foreground: () => true,
  );
  await m.start();
  return (m, ads, store, clock);
}

/// 一つの人生を、亡くなるか天下統一まで流す。
void playOut(Game g, Rng pick) {
  var n = 0;
  while (!g.finished && n++ < 6000) {
    final p = g.prompt!;
    g.choose(pick.range(0, p.choices.length - 1));
  }
}

void main() {
  group('全画面広告', () {
    test('最初の1回の人生では出さない。二つめの人生から出す', () async {
      final (m, ads, _, _) = await make();
      await m.noteLifeStarted();
      expect(m.inFirstLife, isTrue);
      expect(await m.maybeInterstitial(), isFalse);
      expect(ads.interstitials, 0);
      await m.noteLifeStarted();
      expect(m.inFirstLife, isFalse);
      expect(await m.maybeInterstitial(), isTrue);
      expect(ads.interstitials, 1);
    });

    test('前に遊んでいた人（これまでの人生がある）は、最初の人生とみなさない', () async {
      final (m, _, _, _) = await make();
      await m.noteLifeStarted(finishedBefore: 4);
      expect(m.inFirstLife, isFalse);
    });

    test('前の広告から3分あいていなければ出さない', () async {
      final (m, ads, _, clock) = await make(
        saved: {'ranse.livesStarted': 3},
      );
      expect(await m.maybeInterstitial(), isTrue);
      clock.pass(const Duration(minutes: 2, seconds: 59));
      expect(await m.maybeInterstitial(), isFalse);
      clock.pass(const Duration(seconds: 1));
      expect(await m.maybeInterstitial(), isTrue);
      expect(ads.interstitials, 2);
      // 時計を戻されたら、あいていないとみなす
      clock.pass(const Duration(hours: -1));
      expect(await m.maybeInterstitial(), isFalse);
    });

    test('在庫が無い・出せなかったときは間隔を数え始めない（次の機会に出す）', () async {
      final (m, ads, _, _) = await make(saved: {'ranse.livesStarted': 3});
      ads.interstitialReady = false;
      expect(await m.maybeInterstitial(), isFalse);
      expect(ads.reloads, greaterThan(0), reason: '在庫が無ければ読み込みを始める');
      ads.interstitialReady = true;
      ads.interstitialShows = false;
      expect(await m.maybeInterstitial(), isFalse);
      ads.interstitialShows = true;
      expect(await m.maybeInterstitial(), isTrue);
    });

    test('動画を見たすぐあとには全画面広告を重ねない', () async {
      final (m, ads, _, clock) = await make(saved: {'ranse.livesStarted': 3});
      expect(await m.beforeRedo(), RedoGate.granted);
      expect(await m.maybeInterstitial(), isFalse);
      clock.pass(Monetization.adGap);
      expect(await m.maybeInterstitial(), isTrue);
      expect(ads.interstitials, 1);
    });

    test('広告を消した人には出さない', () async {
      final (m, ads, _, _) = await make(
        saved: {'ranse.livesStarted': 3, 'ranse.adFree': true},
      );
      expect(await m.maybeInterstitial(), isFalse);
      expect(ads.interstitials, 0);
      expect(ads.initializes, 0, reason: '広告を消した人の端末では広告を準備しない');
    });
  });

  group('やり直しの動画', () {
    test('見終えたらやり直せる、途中で閉じたらやり直せない、読み込めなければタダではやり直させない', () async {
      final (m, ads, _, _) = await make();
      expect(m.redoNeedsAd, isTrue);
      expect(await m.beforeRedo(), RedoGate.granted);
      ads.watchToEnd = false;
      expect(await m.beforeRedo(), RedoGate.declined);
      ads.rewardedReady = false;
      expect(await m.beforeRedo(), RedoGate.unavailable);
      expect(ads.rewardeds, 2);
    });

    test('広告を消した人は動画なしでやり直せる', () async {
      final (m, ads, _, _) = await make(saved: {'ranse.adFree': true});
      expect(m.redoNeedsAd, isFalse);
      expect(await m.beforeRedo(), RedoGate.granted);
      expect(ads.rewardeds, 0);
    });
  });

  group('広告を消す', () {
    test('誰も待っていないときに届いた購入でも広告が消え、再起動後も残る', () async {
      final (m, ads, store, _) = await make();
      await store.deliver();
      expect(m.adFree, isTrue);
      expect(ads.disposes, 1);
      final p = await SharedPreferences.getInstance();
      expect(p.getBool('ranse.adFree'), isTrue);
    });

    test('返金されたら広告が戻る。ほかに有効な取引があれば戻さない', () async {
      final (m, _, store, _) = await make(saved: {'ranse.adFree': true});
      store.entitlement = true;
      await store.revoke();
      expect(m.adFree, isTrue);
      store.entitlement = false;
      await store.revoke();
      expect(m.adFree, isFalse);
    });

    test('再インストール後は、端末の購入記録から広告なしに戻す', () async {
      final (m, ads, _, _) = await make(entitlement: true);
      expect(m.adFree, isTrue);
      expect(ads.initializes, 0);
    });
  });

  group('やり直し（アプリ）', () {
    Future<(AppController, FakeAds)> app(int seed) async {
      SharedPreferences.setMockInitialValues({'ranse.livesStarted': 5});
      final ads = FakeAds();
      final m = Monetization(
        await SharedPreferences.getInstance(),
        ads: ads,
        store: FakeStore(),
        foreground: () => true,
      );
      final c = AppController(rng: Rng(seed), money: m);
      await c.init();
      await m.start();
      return (c, ads);
    }

    test('亡くなった年の始めに戻り、一つの人生に一度だけ。図鑑とこれまでの人生には最後の最期だけが残る', () async {
      var tried = 0;
      for (var s = 0; s < 40 && tried < 8; s++) {
        final (c, _) = await app(100 + s);
        c.birth = rollBirth(Rng(300 + s));
        c.begin();
        final g = c.game;
        playOut(g, Rng(500 + s));
        if (g.l.dead == null) continue; // 天下統一ではやり直しは出ない
        if (g.age < 5) {
          // 一度も選ばないうちに亡くなった乳幼児には、戻る年の始めの区切りが無い（やり直しは出さない）
          expect(c.canRedo, isFalse);
          continue;
        }
        tried++;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        final diedAge = g.age;
        final name = g.l.name;
        expect(c.canRedo, isTrue);
        final before = await c.store.lives();
        expect(before.first.name, name);

        expect(await c.redo(), RedoGate.granted);
        expect(g.finished, isFalse, reason: '戻った年はまだ生きている');
        expect(g.l.name, name);
        expect(g.age, lessThanOrEqualTo(diedAge));
        expect(diedAge - g.age, lessThanOrEqualTo(1), reason: '亡くなった年の始めに戻る');
        expect(g.l.flags.contains(Game.kRedoFlag), isTrue);
        expect(c.canRedo, isFalse, reason: '生きているあいだはやり直しは出ない');
        final mid = await c.store.lives();
        expect(mid.isEmpty || mid.first.name != name || mid.length < before.length,
            isTrue, reason: 'やり直した人生の最期は、これまでの人生から消える');

        playOut(g, Rng(900 + s));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(c.canRedo, isFalse, reason: 'やり直しは一つの人生に一度だけ');
        final after = await c.store.lives();
        expect(after.length, before.length, reason: '最後に迎えた最期だけが一件残る');
        c.dispose();
      }
      expect(tried, greaterThanOrEqualTo(5));
    });

    test('動画を最後まで見なければ戻らない', () async {
      for (var s = 0; s < 40; s++) {
        final (c, ads) = await app(700 + s);
        c.birth = rollBirth(Rng(800 + s));
        c.begin();
        playOut(c.game, Rng(600 + s));
        if (c.game.l.dead == null || c.game.age < 5) continue;
        ads.watchToEnd = false;
        expect(await c.redo(), RedoGate.declined);
        expect(c.game.finished, isTrue);
        expect(c.canRedo, isTrue, reason: '見なかったぶんは、また押せる');
        c.dispose();
        return;
      }
      fail('亡くなる人生が見つからなかった');
    });

    test('章の区切り（30歳）に入った年に、全画面広告を出す', () async {
      for (var s = 0; s < 200; s++) {
        final (c, ads) = await app(1000 + s);
        c.birth = rollBirth(Rng(2000 + s));
        c.begin();
        final g = c.game;
        final pick = Rng(3000 + s);
        var n = 0;
        while (!g.finished && g.age < 30 && n++ < 6000) {
          g.choose(pick.range(0, g.prompt!.choices.length - 1));
        }
        if (g.finished || g.age != 30) {
          c.dispose();
          continue;
        }
        expect(g.hasFlag('chapter:30'), isTrue);
        await Future<void>.delayed(const Duration(milliseconds: 1700));
        expect(ads.interstitials, 1);
        c.dispose();
        return;
      }
      fail('30歳まで生きる人生が見つからなかった');
    });
  });

  test('広告の読み込みと表示は、閉じるまで待つ形になっている（app-pitfalls の3と9）', () {
    final src = File('lib/monetization/ad_service.dart').readAsStringSync();
    expect(src.contains('await InterstitialAd.load('), isFalse);
    expect(src.contains('await RewardedAd.load('), isFalse);
    expect(src.contains('onAdDismissedFullScreenContent'), isTrue);
    expect(src.contains('Completer<bool>()'), isTrue);
    expect(src.contains('Duration(minutes: 55)'), isTrue, reason: '1時間で期限切れになる前に読み直す');
  });
}
