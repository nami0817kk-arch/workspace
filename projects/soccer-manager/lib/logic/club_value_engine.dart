import '../l10n/tr.dart';

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

  /// 施設1つのレベル1つぶんの価値(万円)。レベル1は初期値なので数えない。
  static const int facilityPerLevel = 300;

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
    required Iterable<int> facilityLevels,
    required Iterable<int> staffLevels,
    required int leagueTitles,
    required int cupTitles,
    required int managerReputation,
    required int annualOperatingIncome,
    required int cash,
    required int debt,
  }) {
    final facilities =
        facilityLevels.fold<int>(0, (s, l) => s + (l - 1).clamp(0, 99)) *
                facilityPerLevel +
            staffLevels.fold<int>(0, (s, l) => s + l.clamp(0, 99)) *
                staffPerLevel;
    return ClubValue(
      players: playersValue,
      facilities: facilities,
      brand: leagueTitles * leagueTitleBrand +
          cupTitles * cupTitleBrand +
          managerReputation.clamp(0, 100) * reputationPerPoint,
      earnings: (annualOperatingIncome * earningsMultiple).round(),
      cash: cash,
      debt: debt,
    );
  }
}
