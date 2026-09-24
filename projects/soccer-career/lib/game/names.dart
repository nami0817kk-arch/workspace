import '../models/club.dart';
import 'world.dart';

/// クラブ名の旧API。
///
/// 国を持つ前の名残で、既存のテストと呼び出しのために残してある。
/// 実体は [World] にあり、クラブ名は国ごとの命名規則から作られる。
/// 新しいコードは `World.buildLeague(countryId, tier)` を使う。
class Names {
  const Names._();

  /// 既定の国のリーグを組み立てる。
  static List<Club> buildLeague(int tier) =>
      World.buildLeague(World.defaultCountryId, tier);
}
