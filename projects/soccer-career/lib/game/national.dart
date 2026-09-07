import '../models/club.dart';

/// 代表チーム。国名も架空。
///
/// 代表は「選ばれること自体が到達点」なので、対戦相手を細かく作り込むより、
/// 招集されるかどうかと、そこで何を残したかを見せることを優先する。
class National {
  const National._();

  /// 自分の代表。
  static const Club home = Club(
    id: 'nat-home',
    name: '代表',
    strength: 74,
    tier: 0,
  );

  /// 対戦相手の候補。
  static const List<Club> opponents = [
    Club(id: 'nat-1', name: 'アルヴェニア代表', strength: 78, tier: 0),
    Club(id: 'nat-2', name: 'ベルガ代表', strength: 72, tier: 0),
    Club(id: 'nat-3', name: 'カルディナ代表', strength: 68, tier: 0),
    Club(id: 'nat-4', name: 'ドルネア代表', strength: 82, tier: 0),
    Club(id: 'nat-5', name: 'エストラーダ代表', strength: 64, tier: 0),
    Club(id: 'nat-6', name: 'フィオルナ代表', strength: 76, tier: 0),
  ];

  /// 代表ウィークが入る節。この節を戦い終えたあとに代表戦が挟まる。
  static const List<int> breakAfterMatchday = [8, 18, 28];
}
