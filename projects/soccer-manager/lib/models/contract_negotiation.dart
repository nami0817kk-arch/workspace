import 'player.dart';

/// 契約交渉1回分の提示・対案のやり取りを表す。
class ContractNegotiation {
  final String playerId;
  final int initialWage;
  int offeredWage;
  int counterWage;
  int roundsUsed;

  /// 結ぶ契約の満了の年。null は年齢に応じた既定の年数。
  int? endYear;

  /// クラブ側の1年延長オプションを付けるか。
  bool option;

  /// 約束する序列(null は今の序列のまま)。上の立場ほど高い週俸を求める。
  SquadStatus? promise;

  ContractNegotiation({
    required this.playerId,
    required this.initialWage,
    required this.offeredWage,
    required this.counterWage,
    this.roundsUsed = 0,
    this.endYear,
    this.option = false,
    this.promise,
  });

  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'initialWage': initialWage,
        'offeredWage': offeredWage,
        'counterWage': counterWage,
        'roundsUsed': roundsUsed,
        if (endYear != null) 'endYear': endYear,
        if (option) 'option': true,
        if (promise != null) 'promise': promise!.name,
      };

  factory ContractNegotiation.fromJson(Map<String, dynamic> json) =>
      ContractNegotiation(
        playerId: json['playerId'] as String,
        initialWage: json['initialWage'] as int,
        offeredWage: json['offeredWage'] as int,
        counterWage: json['counterWage'] as int,
        roundsUsed: json['roundsUsed'] as int? ?? 0,
        endYear: json['endYear'] as int?,
        option: json['option'] as bool? ?? false,
        // 2026-11-25 より前のセーブには無い(今の序列のまま)。
        promise: SquadStatus.values
            .where((s) => s.name == json['promise'])
            .firstOrNull,
      );
}

/// 契約交渉で週俸を提示した結果。
enum ContractOfferResult {
  /// 提示額で合意し、契約が更新された。
  accepted,

  /// 提示額では折り合わず、選手側から対案が届いた(交渉継続)。
  countered,

  /// 選手の要求は満たしたが、クラブの資金が足りず更新できなかった。
  insufficientFunds,

  /// 交渉が規定回数を超え、選手が交渉から離脱した。
  walkedAway,
}
