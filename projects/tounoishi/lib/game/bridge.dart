import 'dart:async';
import 'dart:convert';

import '../monetization/monetization.dart';
import '../monetization/purchase_service.dart';

/// ゲーム本体（WebView の中の JS）から届く広告・課金の頼みを受ける（ひかりの指名の bridge.dart と同じ流儀）。
///
/// 窓口は JavaScript チャンネル `TouApp`。届く形は JSON 1つ:
/// `{"type": "inter"|"prepInter"|"buy"|"restore"|"refresh", ...}`。
/// - `inter`（`at` は `lose` / `grow`）: 全画面広告を出す。出しても出さなくても、終わったら `touInterDone()` を呼ぶ。
///   表示が始まったら `touAdShowing()` を呼ぶ（ゲームはそれまでの打ち切りの時計を止める）。
/// - `prepInter`: この先で出しそうなので読み込み始める（塔を始めた・続きから・次の階が始まった）。
/// - `buy` / `restore`: 「広告を消す」を買う・購入を復元する。
/// - `refresh`: 値段と広告なしかを送り直す。
///
/// 返事は JS の関数で返す（`touSetApp({adFree, price, canBuy, storeOk, msg?})`）。
/// 保存の窓口 `TouStore`・`window.__boot`・`window.__saveNow` は別（lib/main.dart）。
class GameBridge {
  GameBridge({required this.money, required this.runJs});

  final Monetization money;
  final Future<void> Function(String js) runJs;

  /// 全画面広告を扱っている最中か（2度届いても重ねて出さない）。
  bool _interBusy = false;

  Future<void> handle(String raw) async {
    Map<String, Object?> m;
    try {
      m = (jsonDecode(raw) as Map).cast<String, Object?>();
    } catch (_) {
      return;
    }
    switch (m['type']) {
      case 'inter':
        await _inter();
      case 'prepInter':
        money.prepareInterstitial();
      case 'refresh':
        await pushApp();
      case 'buy':
        await _buy();
      case 'restore':
        await _restore();
    }
  }

  Future<void> _inter() async {
    if (_interBusy) {
      // 前の広告を出している最中。待っているゲームを止めないよう、すぐ返す
      await runJs('window.touInterDone&&touInterDone()');
      return;
    }
    _interBusy = true;
    try {
      await money.showInterstitial(onShown: () => unawaited(runJs('window.touAdShowing&&touAdShowing()')));
    } catch (_) {
      // 広告の失敗で進行を止めない
    } finally {
      _interBusy = false;
      // 広告を閉じてから結果画面・次の階へ進める（出さなかったときもすぐ返す）
      await runJs('window.touInterDone&&touInterDone()');
    }
  }

  Future<void> _buy() async {
    final r = await money.buy();
    await pushApp(msg: switch (r) {
      PurchaseOutcome.purchased => '広告を消しました。ありがとうございます',
      PurchaseOutcome.pending => '保護者の承認を待っています。承認されると広告が消えます',
      PurchaseOutcome.timedOut => '購入の結果がまだ届いていません。届きしだい自動で広告が消えます',
      PurchaseOutcome.canceled => null,
      PurchaseOutcome.unavailable => 'ストアに接続できませんでした',
      PurchaseOutcome.failed => '購入できませんでした',
    });
  }

  Future<void> _restore() async {
    final had = money.adFree;
    final r = await money.restore();
    final msg = had
        ? '購入はすでに入っています'
        : r == PurchaseOutcome.purchased || money.adFree
            ? '購入を復元しました'
            : '復元できる購入が見つかりませんでした';
    await pushApp(msg: msg);
  }

  /// 広告を消したか・値段をゲーム本体に伝える（購入が後から届いたときにも呼ぶ）。
  Future<void> pushApp({String? msg}) async {
    final s = await appState();
    if (msg != null) s['msg'] = msg;
    await runJs('window.touSetApp&&touSetApp(${jsonEncode(s)})');
  }

  Future<Map<String, Object?>> appState() async {
    // 1つ取れなくても、ほかは渡す
    Future<T?> get<T>(Future<T?> f) async {
      try {
        return await f.timeout(const Duration(seconds: 3));
      } catch (_) {
        return null;
      }
    }

    return {
      'adFree': money.adFree,
      'price': await get<String>(money.price),
      'canBuy': await get<bool>(money.canBuy) ?? false,
      'storeOk': await get<bool>(money.storeAvailable) ?? false,
    };
  }
}
