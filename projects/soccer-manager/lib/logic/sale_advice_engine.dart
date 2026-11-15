import '../l10n/tr.dart';
import '../models/incoming_offer.dart';
import '../models/player.dart';
import '../models/team.dart';

/// 監督の見立て。
enum SaleVerdict { sell, keep, either }

/// 売却オファーに対する、監督の見立て。オーナーは承認か断るかを決める。
class SaleAdvice {
  const SaleAdvice({required this.verdict, required this.comment});

  final SaleVerdict verdict;

  /// 画面にそのまま出す一文。
  final String comment;
}

class SaleAdviceEngine {
  const SaleAdviceEngine._();

  /// 提示額が市場価値のこの倍率以上なら、売り時とみなす。
  static const double sellRatio = 1.2;

  /// 提示額がこの倍率未満で、先発級なら、手放さない方がよい。
  static const double keepRatio = 1.0;

  /// [player] は売却対象。いなければ(すでに移籍した等)中立の見立てを返す。
  static SaleAdvice advise(IncomingOffer offer, Player? player, Team team) {
    if (player == null) {
      return SaleAdvice(
        verdict: SaleVerdict.either,
        comment: Tr.pick('判断材料がありません。', 'Not enough information.'),
      );
    }
    final ratio = player.marketValue <= 0
        ? 2.0
        : offer.amount / player.marketValue;
    final byOverall = [...team.players]
      ..sort((a, b) => b.overall.compareTo(a.overall));
    final rank = byOverall.indexWhere((p) => p.id == player.id);
    final isStarter = rank >= 0 && rank < 11;

    if (ratio >= sellRatio) {
      return SaleAdvice(
        verdict: SaleVerdict.sell,
        comment: Tr.pick('市場価値を大きく上回る額です。売り時です。',
            'The bid is well above his market value. A good time to sell.'),
      );
    }
    if (isStarter && ratio < keepRatio) {
      return SaleAdvice(
        verdict: SaleVerdict.keep,
        comment: Tr.pick('先発級で、額も市場価値に届いていません。断るべきです。',
            'He is a starter and the bid is below his value. Turn it down.'),
      );
    }
    if (!isStarter && ratio >= keepRatio) {
      return SaleAdvice(
        verdict: SaleVerdict.sell,
        comment: Tr.pick('出番の少ない選手に妥当な額です。売って資金にできます。',
            'A fair price for a fringe player. Sell and free up funds.'),
      );
    }
    return SaleAdvice(
      verdict: SaleVerdict.either,
      comment: Tr.pick('売っても断っても大きな差はありません。',
          'Selling or keeping makes little difference.'),
    );
  }
}
