import '../state/game_state.dart';
import 'monetization_controller.dart';

/// 預かっている資金パックをクラブ資金へ移し、移した合計額を返す。
///
/// 資金はセーブの中(クラブ資金)に入るので、買った瞬間に渡せるとは限らない。
/// セーブを開く前に決済が通ることもあれば、タイトル画面に居ることもある。
/// [MonetizationController] は端末側に預かるだけにして、実際に移すのは
/// セーブが開いているこの関数に集める。
///
/// 移してから預かり分を消す。逆にすると、途中で落ちたときに払ったぶんが
/// 消える(消費型なので「復元」では戻らない)。この順なら、最悪でも
/// 二重に渡ることはあっても、払ったのに届かないことは起きない。
///
/// **移す処理は同時に1つだけ走る。** 購入画面(資金パックのカード)と起動時の
/// 見張り(main.dart の _DeliverPendingPurchases)の両方がここを呼ぶ。
/// 同時に走ると、どちらも同じ預かりを見て加算し、預かりを消す前に
/// もう一方が加算するので、同じパックが2回入っていた。後から来た呼び出しは
/// 先の呼び出しが終わるのを待ち、残っているぶんだけを移す。
Future<int> deliverPendingFunds(
  MonetizationController money,
  GameState gameState,
) async {
  while (_deliveryInFlight != null) {
    await _deliveryInFlight;
  }
  final run = _deliverPendingFundsUnlocked(money, gameState);
  _deliveryInFlight = run;
  try {
    return await run;
  } finally {
    if (identical(_deliveryInFlight, run)) _deliveryInFlight = null;
  }
}

Future<int>? _deliveryInFlight;

Future<int> _deliverPendingFundsUnlocked(
  MonetizationController money,
  GameState gameState,
) async {
  if (!gameState.hasSave) return 0;
  var total = 0;
  for (final pack in [...money.undeliveredFundsPacks]) {
    final amount = gameState.claimPurchasedFunds(pack);
    // 0 が返るのはセーブが無いときだけ。預かったまま次の機会に回す。
    if (amount <= 0) break;
    total += amount;
    await money.markFundsPackDelivered(pack);
  }
  return total;
}
