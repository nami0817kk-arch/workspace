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
Future<int> deliverPendingFunds(
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
