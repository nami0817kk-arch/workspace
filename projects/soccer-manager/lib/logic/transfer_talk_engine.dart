import 'dart:math';

import 'transfer_value.dart';

/// 相手のクラブの返事の種類。
enum TalkReplyKind { agree, counter, collapse }

/// 相手のクラブの返事。合意・対案なら条件が付く。
class TalkReply {
  final TalkReplyKind kind;
  final int fee;
  final int sellOnPercent;
  final bool installmentsOk;

  const TalkReply(this.kind,
      {this.fee = 0, this.sellOnPercent = 0, this.installmentsOk = false});
}

/// クラブ同士の移籍金の交渉の決まり(画面・状態から切り離した計算)。
class TransferTalkEngine {
  const TransferTalkEngine._();

  /// 提示できる回数。3回目でも届かなければ決裂する。
  static const int maxRounds = 3;

  /// 提示してから返事が来るまでの日数。
  static const int replyDays = 2;

  /// 合意してから移籍を決めるまでの猶予(日)。
  static const int agreementDays = 14;

  /// 言い値のこれより下は、話にならないとして打ち切られる。
  static const double walkAwayRatio = 0.6;

  /// 相手のクラブの言い値(万円)。市場価値に、そのクラブの事情を掛ける。
  ///
  /// - 主力(クラブで総合力の上位3人)は手放したくない(×1.3)。先発なら ×1.15
  /// - 契約の残り[contractYearsLeft](年。半端も可)の係数
  ///   ([TransferValue.contractFactor]。残り半年 ×0.2〜4年以上 ×1.1)。
  ///   以前は残り1年以内でも ×0.8 までで、契約切れ間近の選手も高かった
  /// - 21歳以下で伸びしろが大きい(潜在が総合力より8以上高い)なら ×1.15
  static int askingPrice({
    required int marketValue,
    required bool keyPlayer,
    required bool starter,
    required num contractYearsLeft,
    required int age,
    required int potentialGap,
  }) {
    var f = 1.0;
    if (keyPlayer) {
      f *= 1.3;
    } else if (starter) {
      f *= 1.15;
    }
    f *= TransferValue.contractFactor(contractYearsLeft.toDouble());
    if (age <= 21 && potentialGap >= 8) f *= 1.15;
    return (marketValue * f).round();
  }

  /// 提示[bid]への相手の返事。[asking]は言い値、[round]は何回目の提示か、
  /// [roll]は 0〜1 の乱数(言い値に近い額をそのまま受けるかに使う)。
  static TalkReply reply({
    required int asking,
    required int bid,
    required bool installments,
    required int round,
    required double roll,
  }) {
    if (asking <= 0 || bid >= asking) {
      return TalkReply(TalkReplyKind.agree,
          fee: bid, installmentsOk: installments);
    }
    final ratio = bid / asking;
    if (ratio < walkAwayRatio) return const TalkReply(TalkReplyKind.collapse);
    // 言い値に近ければ、そのまま受けることもある(95%で半々、100%で必ず)。
    if (ratio >= 0.95 && roll < (ratio - 0.9) / 0.1) {
      return TalkReply(TalkReplyKind.agree,
          fee: bid, installmentsOk: installments);
    }
    if (round >= maxRounds) return const TalkReply(TalkReplyKind.collapse);
    // 対案。回を重ねるほど少し下げる。大きく値切られたら、将来の取り分
    // (売却条項)を求める代わりに少し下げる。
    var fee = (asking * (1 - 0.04 * (round - 1))).round();
    final sellOn = ratio < 0.8 ? 10 : (ratio < 0.9 ? 5 : 0);
    if (sellOn > 0) fee = (fee * (1 - sellOn / 200)).round();
    if (fee <= bid) {
      return TalkReply(TalkReplyKind.agree,
          fee: bid, installmentsOk: installments);
    }
    return TalkReply(TalkReplyKind.counter,
        fee: max(fee, bid + 1),
        sellOnPercent: sellOn,
        // 分割は、言い値に近い提示でなければ認めない(一括を求める)。
        installmentsOk: installments && ratio >= 0.85);
  }

  // ---- 提示の中身(FM の移籍金の提示。2026-11-25) ----

  /// 分割で今払う割合(頭金)。
  static const double downPaymentShare = 0.3;

  /// 分割の年数として選べるもの(0 は契約の年数に合わせる、の旧い形)。
  static const List<int> installmentYearChoices = [2, 3, 4];

  /// 出来高の条件(加入後の公式戦の出場数)。
  static const int addOnApps = 20;

  /// こちらから約束できる売却時の上乗せ(%)。
  static const List<int> sellOnChoices = [0, 10, 15, 20, 25];

  /// 相手のクラブが、提示の中身を移籍金に直して見る値打ち(万円)。
  ///
  /// - 一括はそのまま。分割は頭金3割と残り。残りは待つぶん1年あたり3%
  ///   割り引いて見る([installmentYears]。0 なら3年として見る)
  /// - 出来高[addOn]は、届くかわからないので半分に見る
  /// - 売却時の上乗せ[sellOn]%は、選手の市場価値[marketValue]のその割合の
  ///   6割に見る(いつ・いくらで売れるかわからない)
  /// - 交換で受け取る選手は、市場価値[exchangeValue]の[exchangeFit]倍
  ///   (相手のクラブがその位置を欲しいかで 0.6〜0.85)
  static int packageValue({
    required int cash,
    bool installments = false,
    int installmentYears = 0,
    int addOn = 0,
    int sellOn = 0,
    int marketValue = 0,
    int exchangeValue = 0,
    double exchangeFit = 0.75,
  }) {
    return (cashValue(cash,
                installments: installments, installmentYears: installmentYears) +
            addOn * 0.5 +
            marketValue * sellOn / 100 * 0.6 +
            exchangeValue * exchangeFit)
        .round();
  }

  /// 移籍金[cash]の、相手から見た値打ち(分割なら待つぶん割り引く)。
  static double cashValue(int cash,
      {bool installments = false, int installmentYears = 0}) {
    if (!installments) return cash.toDouble();
    final years = installmentYears <= 0 ? 3 : installmentYears;
    final later = cash * (1 - downPaymentShare);
    return cash * downPaymentShare + later * (1 - 0.03 * years);
  }

  /// 中身つきの提示への返事。値打ち([packageValue])で[reply]に掛け、
  /// 対案の額は移籍金(お金の部分)に直して返す。合意なら移籍金は[cash]。
  static TalkReply replyToPackage({
    required int asking,
    required int cash,
    required int value,
    required bool installments,
    int installmentYears = 0,
    required int round,
    required double roll,
  }) {
    final r = reply(
        asking: asking,
        bid: value,
        installments: installments,
        round: round,
        roll: roll);
    switch (r.kind) {
      case TalkReplyKind.collapse:
        return r;
      case TalkReplyKind.agree:
        return TalkReply(TalkReplyKind.agree,
            fee: cash,
            sellOnPercent: r.sellOnPercent,
            installmentsOk: r.installmentsOk);
      case TalkReplyKind.counter:
        // お金以外の値打ちはそのまま、足りない分をお金で求める。
        final perYen = cash <= 0
            ? 1.0
            : cashValue(cash,
                    installments: installments,
                    installmentYears: installmentYears) /
                cash;
        final nonCash = value - cash * perYen;
        final need = ((r.fee - nonCash) / max(0.5, perYen)).ceil();
        return TalkReply(TalkReplyKind.counter,
            fee: max(need, cash + 1),
            sellOnPercent: r.sellOnPercent,
            installmentsOk: r.installmentsOk);
    }
  }

  /// 自クラブの選手に来たオファーで、買い手が出せる上限(万円)。
  /// 最初の提示の 1.1〜1.35 倍。オファーごとに決まっている。
  static int buyerLimit(String offerId, int amount) {
    final h = offerId.codeUnits.fold<int>(7, (a, c) => (a * 31 + c) % 1000003);
    return (amount * (1.1 + (h % 100) / 400)).round();
  }

  /// 上限をこれだけ超える要求には、買い手は話を打ち切る。
  static const double buyerWalkAwayRatio = 1.25;
}
