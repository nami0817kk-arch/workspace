import '../l10n/tr.dart';
import '../models/club_infrastructure.dart';

/// クラブ価値(万円)の内訳。
///
/// 選手・施設・ブランド・稼ぐ力・手元の資金から、負債を引いたもの。
/// 売却するときの値段の目安で、オーナーの目標「クラブ価値を2倍に」の物差し。
class ClubValue {
  const ClubValue({
    required this.players,
    required this.facilities,
    required this.brand,
    required this.earnings,
    required this.cash,
    required this.debt,
  });

  /// 選手の市場価値の合計。
  final int players;

  /// 施設とスタッフへの投資の積み上げ。
  final int facilities;

  /// 優勝歴と監督の評判。
  final int brand;

  /// 稼ぐ力(営業収入の1年分)。
  final int earnings;

  /// 手元の資金(マイナスならそのまま引かれる)。
  final int cash;

  /// 融資の残り。
  final int debt;

  int get total => players + facilities + brand + earnings + cash - debt;

  /// 内訳を(名前, 金額)で。画面用。負債は負で返す。
  List<(String, int)> get lines => [
        (Tr.pick('選手', 'Players'), players),
        (Tr.pick('施設・スタッフ', 'Facilities & staff'), facilities),
        (Tr.pick('ブランド(優勝歴・評判)', 'Brand (titles & reputation)'), brand),
        (Tr.pick('稼ぐ力', 'Earning power'), earnings),
        (Tr.pick('手元の資金', 'Cash'), cash),
        if (debt > 0) (Tr.pick('融資の残り', 'Loans'), -debt),
      ];
}

class ClubValueEngine {
  const ClubValueEngine._();

  /// 施設 [type] がレベル [level] のときの価値(万円)。建て直すときに
  /// かかる額で数える(工事費は部でも国でも変わらないので、価値も変えない)。
  ///
  /// 以前は「レベル1つぶん300万 × 部の規模」で、レベル1は数えなかった。
  /// 1万2,000席のスタジアムが0円で、増築に12億かけても価値は3部で4,300万
  /// しか増えなかった(2026-11-23 に直した)。
  ///
  /// - スタジアム: レベル1の席(1万2,000席)を、最初の増築と同じ1席の値段
  ///   (20万円)で数えて24億。増築した席は、増築の工事費
  ///   ([ClubInfrastructure.stadiumUpgradeCost])をそのまま足す
  ///   (Lv2 36億、Lv5 144億、Lv6 4万2,000席で204億)。
  /// - ほかの施設: レベル1を最初の増築と同じ1.5億で数え、増築の工事費
  ///   ([ClubInfrastructure.facilityUpgradeCost])を足す。
  ///
  /// 増築すると、払った工事費(割引の前)と同じだけ価値が増える。
  static int facilityValue(FacilityType type, int level) {
    final lv = level.clamp(1, ClubInfrastructure.maxLevel);
    final base = type == FacilityType.stadium
        ? ClubInfrastructure.stadiumCapacity(1) *
            ClubInfrastructure.stadiumSeatCost(1)
        : ClubInfrastructure.facilityUpgradeCost(1);
    var total = base;
    for (var k = 1; k < lv; k++) {
      total += ClubInfrastructure.upgradeCostFor(type, k);
    }
    return total;
  }

  /// スタッフ1人のレベル1つぶんの価値(万円)。
  static const int staffPerLevel = 100;

  /// リーグ優勝・カップ優勝1回ぶんのブランド価値(万円)。
  static const int leagueTitleBrand = 1500;
  static const int cupTitleBrand = 500;

  /// 監督の評判(0〜100)1点ぶんのブランド価値(万円)。
  static const int reputationPerPoint = 20;

  /// 稼ぐ力は、営業収入の1年分をそのまま価値として数える。
  static const double earningsMultiple = 1.0;

  static ClubValue compute({
    required int playersValue,
    required Map<FacilityType, int> facilityLevels,
    required Iterable<int> staffLevels,
    required int leagueTitles,
    required int cupTitles,
    required int managerReputation,
    required int annualOperatingIncome,
    required int cash,
    required int debt,
    double scale = 1,
  }) {
    // 施設は建て直す額で、部の規模は掛けない([facilityValue])。スタッフ・
    // ブランドの額は5部の規模で書いてある。[scale] は今の部の規模
    // (moneyScale)。
    final facilities = facilityLevels.entries
            .fold<int>(0, (s, e) => s + facilityValue(e.key, e.value)) +
        (staffLevels.fold<int>(0, (s, l) => s + l.clamp(0, 99)) *
                staffPerLevel *
                scale)
            .round();
    return ClubValue(
      players: playersValue,
      facilities: facilities,
      brand: ((leagueTitles * leagueTitleBrand +
                  cupTitles * cupTitleBrand +
                  managerReputation.clamp(0, 100) * reputationPerPoint) *
              scale)
          .round(),
      earnings: (annualOperatingIncome * earningsMultiple).round(),
      cash: cash,
      debt: debt,
    );
  }
}
