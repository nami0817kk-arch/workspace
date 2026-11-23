import '../monetization/purchase_service.dart';

/// 購入・復元の結果を、利用者に見せる一言にする(取りやめは何も出さない)。
String? purchaseMessage(PurchaseOutcome r, {required bool restore}) => switch (r) {
      PurchaseOutcome.purchased => restore ? '購入を復元した。広告が出なくなった。' : 'ありがとう! 広告が出なくなった。',
      PurchaseOutcome.pending => '承認待ち。承認されると広告が消える。',
      PurchaseOutcome.canceled => null,
      PurchaseOutcome.unavailable => restore ? '復元できる購入が見つからなかった。' : '購入できなかった。',
      PurchaseOutcome.failed => restore ? '復元に失敗した。あとでもう一度。' : '購入に失敗した。あとでもう一度。',
    };
