import 'package:soccer_manager/models/incoming_offer.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 選手を売る(売却は「移籍リストに載せる → 届いたオファーを受ける」の
/// 形だけ。2026-11-23 にその場で売れる sellPlayer をやめた)。
///
/// 移籍リストに載せ、オファーを1件その場で届けて([GameState.debugOfferFor])
/// 受ける。売れたらそのオファー、買い手が見つからない・受けられなければ null。
Future<IncomingOffer?> sellViaOffer(GameState gs, String playerId) async {
  await gs.setTransferListed(playerId, true);
  final o = gs.debugOfferFor(playerId);
  if (o == null) return null;
  return await gs.acceptIncomingOffer(o.id) ? o : null;
}
