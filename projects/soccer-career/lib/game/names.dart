import '../models/club.dart';

/// クラブ名はすべて架空。実在のクラブ・リーグの名称や商標は使わない
/// （公開・収益化を前提にしているため）。
class Names {
  const Names._();

  static const List<String> firstDivision = [
    'アルティア FC',
    'ノルデン SC',
    'ヴェルナ・ユナイテッド',
    'サンティーロ FC',
    'グラウベルク',
    'マレア・シティ',
    'オルディス FC',
    'カステラ・ローヴェ',
    'ブリンドン FC',
    'テラノヴァ SC',
    'エルシード FC',
    'ヴァイスハイム',
    'ポルタ・レアル',
    'ミストラル FC',
    'コルヴィナ SC',
    'アヴェント FC',
    'ソラーナ・シティ',
    'ドラゴネス FC',
    'リンドバル SC',
    'オーロラ FC',
  ];

  static const List<String> secondDivision = [
    'ハルバーン FC',
    'キャンベル・タウン',
    'セレスタ SC',
    'モンテリオ FC',
    'ノースゲート FC',
    'ヴィオラ・シティ',
    'アステル FC',
    'ラングフォード SC',
    'ペトラノヴァ FC',
    'クレイモア FC',
    'サルヴィア SC',
    'エルムウッド FC',
    'ボレアス・シティ',
    'ジオット FC',
    'ファルコナ SC',
    'ウェストベイ FC',
    'アンバーヒル FC',
    'ネロヴェント SC',
    'シュテルン FC',
    'カルミネ SC',
  ];

  /// リーグを組み立てる。強さに幅を持たせて、順位表が単調にならないようにする。
  ///
  /// 1部と2部で範囲を重ねてあるのは、昇格した直後に力の差が開きすぎて
  /// 何もできなくなるのを避けるため。
  static List<Club> buildLeague(int tier) {
    final names = tier == 1 ? firstDivision : secondDivision;
    final base = tier == 1 ? 58 : 38;
    final span = tier == 1 ? 27 : 24;
    return [
      for (var i = 0; i < names.length; i++)
        Club(
          id: 't$tier-c$i',
          name: names[i],
          strength:
              base + ((span * (names.length - 1 - i)) ~/ (names.length - 1)),
          tier: tier,
        ),
    ];
  }
}
