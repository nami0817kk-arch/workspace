import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/monetization/ad_service.dart';
import 'package:soccer_manager/monetization/funds_delivery.dart';
import 'package:soccer_manager/monetization/funds_pack.dart';
import 'package:soccer_manager/monetization/monetization_controller.dart';
import 'package:soccer_manager/monetization/purchase_service.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 「払ったのに届かない」道が残っていないかの検査。
///
/// ストアの通知は、購入を始めた瞬間に返ってくるとは限らない。アプリを
/// 落としている間に決済が通る／家族の承認が後から下りる／こちらが待つのを
/// やめた後に届く／別の端末で買ったぶんが起動時に流れてくる。結果を
/// await している側だけに渡していた頃、これらは全部「払ったのに何も
/// 起きない」だった。しかも完了通知だけは返していたので、ストアは二度と
/// 送ってこない。資金パックは消費型で「復元」でも戻らないため、払った額が
/// そのまま消える。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<(MonetizationController, _SilentPurchaseService)> build() async {
    final purchases = _SilentPurchaseService();
    final controller = MonetizationController(
      adService: _NoAdService(),
      purchases: purchases,
    );
    await controller.initialize();
    return (controller, purchases);
  }

  test('待っている人が居なくても、届いたサポーターは受け取る', () async {
    final (money, store) = await build();
    expect(money.isSupporter, isFalse);

    // 誰も buySupporter() を待っていない状態で通知だけが届く。
    await store.deliver(PurchaseService.supporterProductId);

    expect(money.isSupporter, isTrue, reason: '払ったのに特典が付いていない');
  });

  test('受け取ったサポーターは再起動後も残る', () async {
    final (_, store) = await build();
    await store.deliver(PurchaseService.supporterProductId);

    final restarted = MonetizationController(
      adService: _NoAdService(),
      purchases: _SilentPurchaseService(),
    );
    await restarted.initialize();

    expect(restarted.isSupporter, isTrue);
  });

  test('届いた資金パックは預かりに入り、再起動後も残る', () async {
    // 資金はセーブの中に入るので、その場では渡せないことがある。
    // 預かりが消えると、消費型なので払った額がそのまま消える。
    final (money, store) = await build();
    await store.deliver(FundsPack.medium.productId);

    expect(money.undeliveredFundsPacks, [FundsPack.medium]);

    final restarted = MonetizationController(
      adService: _NoAdService(),
      purchases: _SilentPurchaseService(),
    );
    await restarted.initialize();
    expect(restarted.undeliveredFundsPacks, [FundsPack.medium],
        reason: '預かっていたぶんが起動で消えている');
  });

  test('預かったぶんは、セーブが開いたときにクラブ資金へ移る', () async {
    final (money, store) = await build();
    final game = GameState();
    await game.startNewGame('受け取りFC');
    final before = game.save!.budget;

    await store.deliver(FundsPack.small.productId);
    final granted = await deliverPendingFunds(money, game);

    expect(granted, game.purchasedFundsAmount(FundsPack.small));
    expect(game.save!.budget, before + granted);
    expect(money.undeliveredFundsPacks, isEmpty);
  });

  test('二度渡らない', () async {
    final (money, store) = await build();
    final game = GameState();
    await game.startNewGame('二重FC');
    final before = game.save!.budget;

    await store.deliver(FundsPack.small.productId);
    final first = await deliverPendingFunds(money, game);
    final second = await deliverPendingFunds(money, game);

    expect(second, 0, reason: '同じ購入を二度渡している');
    expect(game.save!.budget, before + first);
  });

  test('同じパックを2つ買えば、2つとも渡る', () async {
    // 消費型なので何度でも買える。1つにまとめてしまうと片方が消える。
    final (money, store) = await build();
    final game = GameState();
    await game.startNewGame('連続FC');
    final before = game.save!.budget;

    await store.deliver(FundsPack.small.productId);
    await store.deliver(FundsPack.small.productId);
    expect(money.undeliveredFundsPacks.length, 2);

    final granted = await deliverPendingFunds(money, game);
    expect(granted, game.purchasedFundsAmount(FundsPack.small) * 2);
    expect(game.save!.budget, before + granted);
  });

  test('購入画面と起動時の見張りが同時に移しても、二重に入らない', () async {
    // 両方が同じ預かりを見て加算し、預かりを消す前にもう一方が加算していた。
    final (money, store) = await build();
    final game = GameState();
    await game.startNewGame('同時FC');
    final before = game.save!.budget;

    await store.deliver(FundsPack.small.productId);
    final results = await Future.wait([
      deliverPendingFunds(money, game),
      deliverPendingFunds(money, game),
    ]);

    final amount = game.purchasedFundsAmount(FundsPack.small);
    expect(results.fold<int>(0, (s, r) => s + r), amount);
    expect(game.save!.budget, before + amount, reason: '同じパックが2回入っている');
    expect(money.undeliveredFundsPacks, isEmpty);
  });

  test('セーブが無いあいだは預かったままで、消えない', () async {
    final (money, store) = await build();
    final empty = GameState();
    await empty.init(); // セーブを作らずに起動しただけ

    await store.deliver(FundsPack.large.productId);
    final granted = await deliverPendingFunds(money, empty);

    expect(granted, 0);
    expect(money.undeliveredFundsPacks, [FundsPack.large],
        reason: 'セーブが無いあいだに預かりを捨てている');
  });

  test('同じ取引が二度届いても、一度しか渡さない', () async {
    // 完了通知は投げっぱなしで送るので、届く前に落ちると次の起動で
    // ストアが同じ購入をもう一度送ってくる。消費型は渡すたびに預かりへ
    // 積むので、そのぶん二重に渡ってしまう。払ったのは1回。
    final (money, store) = await build();

    await store.deliver(FundsPack.small.productId, purchaseId: 'tx-1');
    await store.deliver(FundsPack.small.productId, purchaseId: 'tx-1');

    expect(money.undeliveredFundsPacks.length, 1, reason: '同じ取引で二度渡している');
  });

  test('別の取引なら、二度とも渡す', () async {
    // 同じ商品を2つ買うのは正当。取引が違えば両方渡す。
    final (money, store) = await build();

    await store.deliver(FundsPack.small.productId, purchaseId: 'tx-1');
    await store.deliver(FundsPack.small.productId, purchaseId: 'tx-2');

    expect(money.undeliveredFundsPacks.length, 2);
  });

  test('再起動しても、渡した取引を覚えている', () async {
    final (_, store) = await build();
    await store.deliver(FundsPack.small.productId, purchaseId: 'tx-1');

    // 起動し直したところへ、ストアが同じ購入を送り直してくる場面。
    final store2 = _SilentPurchaseService();
    final money2 =
        MonetizationController(adService: _NoAdService(), purchases: store2);
    await money2.initialize();
    await store2.deliver(FundsPack.small.productId, purchaseId: 'tx-1');

    expect(money2.undeliveredFundsPacks.length, 1,
        reason: '再起動で忘れて、二度目を渡している');
  });

  test('知らない商品IDは預からない', () async {
    final (money, store) = await build();
    await store.deliver('not_a_real_product');

    expect(money.undeliveredFundsPacks, isEmpty);
    expect(money.isSupporter, isFalse);
  });

  group('受け取りの途中で落ちる', () {
    // 以前は「渡した」と記録してから預けていた。その間に落ちると、
    // ストアが送り直してきても「渡し済み」として弾き、払ったぶんが
    // 届かなかった(消費型は復元でも戻らない)。

    test('預ける書き込みで落ちても、送り直しで届く', () async {
      final store = _SilentPurchaseService();
      final crashing = _CrashingPrefs(
          await SharedPreferences.getInstance(),
          crashOnKey: 'monetization.undeliveredFunds');
      final money = MonetizationController(
          adService: _NoAdService(),
          purchases: store,
          prefs: () async => crashing);
      await money.initialize();

      // 受け取りが途中で落ちる。窓口は完了通知を返さない(本物は例外で
      // received = false になる)。
      await expectLater(
          store.deliver(FundsPack.small.productId, purchaseId: 'tx-crash'),
          throwsA(isA<_Crash>()));
      expect(money.undeliveredFundsPacks, isEmpty);

      // 起動し直したところへ、ストアが同じ取引を送り直してくる。
      final store2 = _SilentPurchaseService();
      final money2 =
          MonetizationController(adService: _NoAdService(), purchases: store2);
      await money2.initialize();
      await store2.deliver(FundsPack.small.productId, purchaseId: 'tx-crash');

      expect(money2.undeliveredFundsPacks, [FundsPack.small],
          reason: '落ちた取引を「渡し済み」として弾いている(払ったのに届かない)');
    });

    test('預けた後で落ちても、送り直しで二重に渡らない', () async {
      // 預かりの1件に取引の識別子が添えてあるので、記録は預けた時点で
      // 済んでいる。渡し終えた取引の一覧を書く前に落ちても弾ける。
      final store = _SilentPurchaseService();
      final crashing = _CrashingPrefs(
          await SharedPreferences.getInstance(),
          crashOnKey: 'monetization.deliveredPurchaseIds');
      final money = MonetizationController(
          adService: _NoAdService(),
          purchases: store,
          prefs: () async => crashing);
      await money.initialize();
      await store.deliver(FundsPack.medium.productId, purchaseId: 'tx-9');
      expect(money.undeliveredFundsPacks, [FundsPack.medium]);

      final store2 = _SilentPurchaseService();
      final money2 =
          MonetizationController(adService: _NoAdService(), purchases: store2);
      await money2.initialize();
      await store2.deliver(FundsPack.medium.productId, purchaseId: 'tx-9');

      expect(money2.undeliveredFundsPacks, [FundsPack.medium],
          reason: '同じ取引を二度預けている');
    });

    test('クラブ資金へ移した後でも、送り直しで二重に渡らない', () async {
      final (money, store) = await build();
      final game = GameState();
      await game.startNewGame('送り直しFC');
      await store.deliver(FundsPack.small.productId, purchaseId: 'tx-5');
      final first = await deliverPendingFunds(money, game);
      expect(first, greaterThan(0));

      final store2 = _SilentPurchaseService();
      final money2 =
          MonetizationController(adService: _NoAdService(), purchases: store2);
      await money2.initialize();
      await store2.deliver(FundsPack.small.productId, purchaseId: 'tx-5');
      expect(money2.undeliveredFundsPacks, isEmpty,
          reason: '渡し終えた取引を忘れて、もう一度預けている');
    });

    test('サポーターの札を書く前に落ちても、送り直しで届く', () async {
      final store = _SilentPurchaseService();
      final crashing = _CrashingPrefs(
          await SharedPreferences.getInstance(),
          crashOnKey: 'monetization.supporter');
      final money = MonetizationController(
          adService: _NoAdService(),
          purchases: store,
          prefs: () async => crashing);
      await money.initialize();
      await expectLater(
          store.deliver(PurchaseService.supporterProductId,
              purchaseId: 'tx-s'),
          throwsA(isA<_Crash>()));

      final store2 = _SilentPurchaseService();
      final money2 =
          MonetizationController(adService: _NoAdService(), purchases: store2);
      await money2.initialize();
      expect(money2.isSupporter, isFalse);
      await store2.deliver(PurchaseService.supporterProductId,
          purchaseId: 'tx-s');
      expect(money2.isSupporter, isTrue,
          reason: '落ちた取引を「渡し済み」として弾いている');
    });

    test('古い版の預かり(商品IDだけの行)も読める', () async {
      SharedPreferences.setMockInitialValues({
        'monetization.undeliveredFunds': [FundsPack.large.productId],
      });
      final (money, _) = await build();
      expect(money.undeliveredFundsPacks, [FundsPack.large]);
    });
  });

  group('手放しを迫られているあいだ', () {
    test('資金パックは渡さず、新しいクラブに移ってから渡す', () async {
      // 迫られているあいだに渡すと、買い直しで資金が初期の額に戻され、
      // 払ったぶんが消えていた。
      final (money, store) = await build();
      final game = GameState();
      await game.startNewGame('売却FC');
      game.save!.confidence = 0; // サポーターの期待が尽きた
      expect(game.isSaleForced, isTrue);

      await store.deliver(FundsPack.medium.productId);
      final during = await deliverPendingFunds(money, game);
      expect(during, 0, reason: '手放しを迫られているのに渡している');
      expect(money.undeliveredFundsPacks, [FundsPack.medium],
          reason: '渡していないのに預かりを消している');
      // 直接呼ばれても入れない。
      expect(game.claimPurchasedFunds(FundsPack.medium), 0);

      final other = game.save!.league.teams
          .firstWhere((t) => t.id != game.save!.userTeamId);
      expect(await game.buyClub(other.id), isTrue);
      expect(game.isSaleForced, isFalse);
      final startBudget = game.save!.budget;

      final after = await deliverPendingFunds(money, game);
      expect(after, game.purchasedFundsAmount(FundsPack.medium));
      expect(game.save!.budget, startBudget + after,
          reason: '新しいクラブに資金が入っていない');
      expect(money.undeliveredFundsPacks, isEmpty);
      await game.flushPendingSave();
    });
  });
}

class _Crash implements Exception {
  const _Crash();
}

/// 決めた鍵への書き込みで落ちる保存先。「書き込みの途中でアプリが落ちた」
/// 場面を作る。読み書きは本物の(テスト用の)保存先へそのまま渡す。
class _CrashingPrefs implements SharedPreferences {
  _CrashingPrefs(this._real, {required this.crashOnKey});

  final SharedPreferences _real;
  final String crashOnKey;

  @override
  bool? getBool(String key) => _real.getBool(key);
  @override
  int? getInt(String key) => _real.getInt(key);
  @override
  String? getString(String key) => _real.getString(key);
  @override
  List<String>? getStringList(String key) => _real.getStringList(key);

  @override
  Future<bool> setBool(String key, bool value) async {
    if (key == crashOnKey) throw const _Crash();
    return _real.setBool(key, value);
  }

  @override
  Future<bool> setInt(String key, int value) async {
    if (key == crashOnKey) throw const _Crash();
    return _real.setInt(key, value);
  }

  @override
  Future<bool> setString(String key, String value) async {
    if (key == crashOnKey) throw const _Crash();
    return _real.setString(key, value);
  }

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    if (key == crashOnKey) throw const _Crash();
    return _real.setStringList(key, value);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 買う操作では何も返さず、ストアからの通知だけを起こせる差し替え。
///
/// 「待っている人が居ないときに届く」状況を作るためのもの。買う側の
/// 戻り値に頼っていると、この形は再現できない。
class _SilentPurchaseService implements PurchaseService {
  @override
  set onDelivered(Future<void> Function(String productId, String? purchaseId)? callback) =>
      _onDelivered = callback;

  Future<void> Function(String productId, String? purchaseId)? _onDelivered;

  /// ストアから通知が届いた状態にする。
  /// [purchaseId] を同じにすると「同じ取引がもう一度届いた」状態になる。
  Future<void> deliver(String productId, {String? purchaseId}) async =>
      _onDelivered?.call(productId, purchaseId ?? 'tx-${_seq++}');

  int _seq = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<String?> priceLabel() async => null;

  @override
  Future<String?> priceLabelFor(FundsPack pack) async => null;

  @override
  Future<PurchaseOutcome> buySupporter() async => PurchaseOutcome.failed;

  @override
  Future<PurchaseOutcome> buyFundsPack(FundsPack pack) async =>
      PurchaseOutcome.failed;

  @override
  Future<PurchaseOutcome> restorePurchases() async => PurchaseOutcome.failed;

  @override
  void dispose() {}
}

class _NoAdService implements AdService {
  @override
  Future<void> initialize() async {}

  @override
  bool get isRewardedAdReady => false;

  @override
  Future<bool> showRewardedAd() async => false;

  @override
  bool get isInterstitialAdReady => false;

  @override
  Future<void> showInterstitialAd() async {}

  @override
  void dispose() {}
}
