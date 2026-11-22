// 名前（`_label` ほか）は private だが、**`this._label` には書けない**
// ——Dart は名前付き引数を `_` で始められない。外に見せるのは `String` の
// getter なので、持ち物は private のまま置く。
// ignore_for_file: prefer_initializing_formals

import '../l10n/lang.dart';
import 'dart:math';

/// 代理人。キャリア開始時に3人の候補から1人選び、**後から変えられる**。
///
/// 実測（12キャリアずつ）で、代理人ごとに届くものは確かに違った——
/// 人脈は届いた話 22.3・到達した国の格 4.92、交渉は最高年俸 13,712、
/// 新人は引退時の貯蓄 73,372。**ピークはどれも 75.3〜75.6 で変わらない。**
/// つまり代理人は「どこへ行き、いくら受け取るか」を決める。
///
/// **ところが一度選んだら二度と変えられなかった。** 何も知らない18歳の判断で
/// 19シーズンが固定される。欲しいものはキャリアの時期で変わる——
/// 若いうちは人脈（動くため）、名前が付いてからは交渉力か低い手数料。
///
/// 交渉力が高いほど上乗せ要求が通りやすく、人脈が広いほど強いクラブの
/// オファーを引いてくる。手数料はその対価で、年俸から引かれる。
class Agent {
  const Agent({
    required Say name,
    required Say style,
    required this.negotiation,
    required this.reach,
    required this.feePercent,
  }) : _name = name,
       _style = style;

  final Say _name;
  final Say _style;

  String get name => _name.t;
  String get style => _style.t;

  /// 交渉力 1〜5。
  final int negotiation;

  /// 人脈。オファー元クラブの強さの上限に足される。
  final int reach;

  /// 手数料（年俸の %）。
  final int feePercent;

  String get description =>
      tr('交渉力 ${'★' * negotiation}${'☆' * (5 - negotiation)}  人脈 +$reach  手数料 $feePercent%', 'Negotiating ${'★' * negotiation}${'☆' * (5 - negotiation)}  Contacts +$reach  Fee $feePercent%');

  /// 全員架空。
  static const List<Agent> pool = [
    Agent(name: Say('柏木 誠', 'Makoto Kashiwagi'), style: Say('堅実', 'Steady'), negotiation: 3, reach: 2, feePercent: 5),
    Agent(
      name: Say('ヴィクトル・ラング', 'Viktor Lang'),
      style: Say('強気', 'Pushy'),
      negotiation: 5,
      reach: 4,
      feePercent: 12,
    ),
    Agent(name: Say('長谷 由紀', 'Yuki Hase'), style: Say('人脈', 'Contacts'), negotiation: 2, reach: 8, feePercent: 8),
    Agent(
      name: Say('マルコ・ペレス', 'Marco Perez'),
      style: Say('新人', 'New to it'),
      negotiation: 2,
      reach: 1,
      feePercent: 3,
    ),
    Agent(name: Say('大塚 玲', 'Rei Otsuka'), style: Say('バランス', 'Balanced'), negotiation: 4, reach: 4, feePercent: 9),
    Agent(
      name: Say('エレナ・コスタ', 'Elena Costa'),
      style: Say('交渉', 'Negotiating'),
      negotiation: 5,
      reach: 1,
      feePercent: 10,
    ),
  ];

  /// 候補を3人引く。
  static List<Agent> candidates(Random random) {
    final shuffled = [...pool]..shuffle(random);
    return shuffled.take(3).toList();
  }

  Map<String, dynamic> toJson() => {'name': name};

  /// 名前で復元する。プールから消えた名前なら最初の代理人にする。
  factory Agent.fromJson(Map<String, dynamic>? json) {
    final name = json?['name'] as String?;
    return pool.firstWhere((a) => a.name == name, orElse: () => pool.first);
  }
}
