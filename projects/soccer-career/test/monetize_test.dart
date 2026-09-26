/// 広告と課金。
///
/// **売っているものが「広告を消す」と「応援」だけ**であることと、
/// 広告がいつ出るかを見張る。ここが緩むと、10ラウンドかけて測ってきた
/// バランスが金で飛ばせるものになる。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_career/monetize/ad_service.dart';
import 'package:soccer_career/monetize/monetization.dart';
import 'package:soccer_career/monetize/purchase_service.dart';

class FakeAds implements AdService {
  int tried = 0;
  int shown = 0;
  bool disposed = false;
  bool ready = true;

  @override
  Future<void> initialize() async {}

  @override
  bool get isInterstitialReady => ready;

  @override
  Future<bool> showInterstitial() async {
    tried++;
    // 在庫が無ければ、出さずに false を返す（本物と同じ振る舞い）。
    if (!ready) return false;
    shown++;
    return true;
  }

  @override
  void dispose() => disposed = true;
}

class FakeStore implements PurchaseService {
  FakeStore({this.available = true, this.outcome = PurchaseOutcome.purchased});

  final bool available;
  PurchaseOutcome outcome;
  final List<Product> bought = [];
  int restores = 0;

  @override
  set onDelivered(void Function(Product product)? callback) =>
      _onDelivered = callback;

  void Function(Product product)? _onDelivered;

  /// ストアから後から流れてくるぶん（アプリを落としている間に決済が通った、
  /// 家族の承認が下りた、別の端末で買った）。
  void deliver(Product product) => _onDelivered?.call(product);

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<String?> priceOf(Product product) async =>
      available ? '¥${product == Product.noAds ? 400 : 200}' : null;

  @override
  Future<PurchaseOutcome> buy(Product product) async {
    if (outcome == PurchaseOutcome.purchased) {
      bought.add(product);
      _onDelivered?.call(product);
    }
    return outcome;
  }

  @override
  Future<PurchaseOutcome> restore() async {
    restores++;
    if (outcome == PurchaseOutcome.purchased) {
      _onDelivered?.call(Product.noAds);
    }
    return outcome;
  }

  @override
  void dispose() {}
}

Future<Monetization> started({
  FakeAds? ads,
  FakeStore? store,
  Map<String, Object> saved = const {},
}) async {
  SharedPreferences.setMockInitialValues(saved);
  final money = Monetization(
    ads: ads ?? FakeAds(),
    purchases: store ?? FakeStore(),
  );
  await money.initialize();
  return money;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('売っているもの', () {
    test('強くなるものは1つも無い', () {
      // **この検査が要点。** 伸びしろ・金・出場機会を売る商品を足したら
      // ここで落ちる。バランスは `balance_sim` で測って釣り合わせてあり、
      // 売った瞬間にその調整が意味を失う。
      expect(Product.values.length, 2);
      expect(Product.values.toSet(), {Product.noAds, Product.tip});
      expect(Product.noAds.consumable, isFalse);
      expect(Product.tip.consumable, isTrue);
    });

    test('商品IDは重ならず、IDから引ける', () {
      expect(Product.ids.length, Product.values.length);
      for (final product in Product.values) {
        expect(Product.byId(product.id), product);
      }
      expect(Product.byId('知らない商品'), isNull);
    });
  });

  group('広告を出すかどうか', () {
    test('始めたばかりのうちは出さない', () async {
      final ads = FakeAds();
      final money = await started(ads: ads);
      for (var season = 0; season < Monetization.freeSeasons; season++) {
        await money.showSeasonAd(seasonsPlayed: season);
      }
      expect(ads.shown, 0, reason: '序盤で広告が出ている');
    });

    test('数シーズン過ぎたら出る', () async {
      final ads = FakeAds();
      final money = await started(ads: ads);
      await money.showSeasonAd(seasonsPlayed: Monetization.freeSeasons);
      expect(ads.shown, 1);
    });

    test('間隔が空いていなければ出さない', () async {
      // シーズンは自動で飛ばせるので、間隔を置かないと連発する。
      final ads = FakeAds();
      final money = await started(ads: ads);
      final now = DateTime(2026, 9, 25, 12);
      await money.showSeasonAd(seasonsPlayed: 5, now: now);
      await money.showSeasonAd(
        seasonsPlayed: 6,
        now: now.add(const Duration(minutes: 1)),
      );
      expect(ads.shown, 1);
      await money.showSeasonAd(
        seasonsPlayed: 7,
        now: now.add(Monetization.adInterval),
      );
      expect(ads.shown, 2);
    });

    test('在庫が無かった回は、間隔を数えない', () async {
      // **出せた回だけ数える。** 出す前に記録していた頃は、在庫が無くて
      // 何も起きなかった回まで「出した」ことになり、**見せていないのに
      // 次の機会が潰れていた**（そのぶんそのまま収入が消える）。
      final ads = FakeAds()..ready = false;
      final money = await started(ads: ads);
      final now = DateTime(2026, 9, 25, 12);
      await money.showSeasonAd(seasonsPlayed: 5, now: now);
      expect(ads.tried, 1);
      expect(ads.shown, 0);
      expect(
        money.shouldShowSeasonAd(
          seasonsPlayed: 6,
          now: now.add(const Duration(minutes: 1)),
        ),
        isTrue,
        reason: '出していない回で間隔を潰している',
      );
    });

    test('出せた回のあとは、間隔を空ける', () async {
      final ads = FakeAds();
      final money = await started(ads: ads);
      final now = DateTime(2026, 9, 25, 12);
      await money.showSeasonAd(seasonsPlayed: 5, now: now);
      expect(ads.shown, 1);
      expect(
        money.shouldShowSeasonAd(
          seasonsPlayed: 6,
          now: now.add(const Duration(minutes: 1)),
        ),
        isFalse,
      );
    });

    test('買った人には出さない', () async {
      final ads = FakeAds();
      final money = await started(
        ads: ads,
        saved: const {'monetize.noAds': true},
      );
      expect(money.noAds, isTrue);
      await money.showSeasonAd(seasonsPlayed: 20);
      expect(ads.shown, 0);
    });
  });

  group('購入', () {
    test('広告を消すと、次からは出ない', () async {
      final ads = FakeAds();
      final store = FakeStore();
      final money = await started(ads: ads, store: store);
      expect(money.shouldShowSeasonAd(seasonsPlayed: 10), isTrue);

      expect(await money.buy(Product.noAds), PurchaseOutcome.purchased);
      expect(money.noAds, isTrue);
      expect(money.shouldShowSeasonAd(seasonsPlayed: 10), isFalse);
      // もう出さないので、読み込み済みの広告も手放す。
      expect(ads.disposed, isTrue);

      // 端末に残る（次の起動でも消えたまま）。
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('monetize.noAds'), isTrue);
    });

    test('取りやめても、状態は変わらない', () async {
      final store = FakeStore(outcome: PurchaseOutcome.canceled);
      final money = await started(store: store);
      expect(await money.buy(Product.noAds), PurchaseOutcome.canceled);
      expect(money.noAds, isFalse);
    });

    test('応援はゲームに何もしない。数だけ残る', () async {
      final ads = FakeAds();
      final money = await started(ads: ads);
      await money.buy(Product.tip);
      await money.buy(Product.tip);
      expect(money.tips, 2);
      // 応援では広告は消えない。
      expect(money.noAds, isFalse);
      expect(money.shouldShowSeasonAd(seasonsPlayed: 10), isTrue);
    });

    test('復元で広告が消える', () async {
      final store = FakeStore();
      final money = await started(store: store);
      expect(await money.restore(), PurchaseOutcome.purchased);
      expect(store.restores, 1);
      expect(money.noAds, isTrue);
    });

    test('アプリを落としている間に決済が通っても、ちゃんと受け取る', () async {
      // **払ったのに何も起きない**を潰す検査。ストアの通知は購入を始めた
      // 瞬間に返ってくるとは限らない（家族の承認、5分の上限を過ぎた後、
      // 別の端末で買ったぶん）。待っている人が居なくても受け取る。
      final ads = FakeAds();
      final store = FakeStore();
      final money = await started(ads: ads, store: store);
      expect(money.noAds, isFalse);

      store.deliver(Product.noAds); // 誰も await していない
      await Future<void>.delayed(Duration.zero);

      expect(money.noAds, isTrue);
      expect(money.shouldShowSeasonAd(seasonsPlayed: 10), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('monetize.noAds'), isTrue);
    });

    test('同じ購入が二度流れてきても、応援を二重に数えない', () async {
      final store = FakeStore();
      final money = await started(store: store);
      store.deliver(Product.noAds);
      store.deliver(Product.noAds);
      await Future<void>.delayed(Duration.zero);
      expect(money.noAds, isTrue);
      // 広告を消すのは何度届いても1回ぶん。
      expect(money.tips, 0);
    });

    test('ストアに繋がらなければ、購入の導線を出さない', () async {
      final money = await started(store: FakeStore(available: false));
      expect(money.storeAvailable, isFalse);
      expect(money.prices, isEmpty);
    });
  });

  group('Web版とテスト', () {
    test('広告も課金も、何もしない実装になる', () async {
      // ここが NoAdService でなくなると、テストと Web 版が広告SDKを
      // 呼びに行って落ちる。
      expect(createAdService(), isA<NoAdService>());

      final ads = NoAdService();
      expect(ads.isInterstitialReady, isFalse);
      await ads.showInterstitial(); // 例外を投げないこと
      ads.dispose();

      final store = NoPurchaseService();
      expect(await store.isAvailable(), isFalse);
      expect(await store.priceOf(Product.noAds), isNull);
      expect(await store.buy(Product.noAds), PurchaseOutcome.unavailable);
      expect(await store.restore(), PurchaseOutcome.unavailable);
    });
  });
}
