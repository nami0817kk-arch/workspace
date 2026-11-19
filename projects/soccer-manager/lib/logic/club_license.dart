import '../l10n/tr.dart';

/// クラブライセンス(昇格の条件)。上の部で戦うには、スタジアムの規模と
/// 健全な財務が要る。満たさないと、順位で昇格を決めても上がれない
/// (権利は次の順位のクラブに移る)。
class ClubLicenseEngine {
  /// [tier]部に必要なスタジアムの段階。
  static int stadiumLevelFor(int tier) => switch (tier) {
        1 => 3,
        2 => 2,
        _ => 1,
      };

  /// [tier]部では、季の終わりに資金がマイナスだと許可が下りない。
  static bool needsSolvency(int tier) => tier <= 3;

  /// [tier]部のライセンスで満たしていない条件(満たしていれば空)。
  static List<String> unmet(int tier,
      {required int stadiumLevel, required int budget}) {
    final need = stadiumLevelFor(tier);
    return [
      if (stadiumLevel < need)
        Tr.pick('スタジアムが$need段階以上(今は$stadiumLevel段階)',
            'Stadium at level $need or above (now $stadiumLevel)'),
      if (needsSolvency(tier) && budget < 0)
        Tr.pick('季の終わりに資金がマイナスでない',
            'Funds not in the red at the end of the season'),
    ];
  }
}
