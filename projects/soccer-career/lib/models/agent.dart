import 'dart:math';

/// 代理人。キャリア開始時に3人の候補から1人選ぶ。
///
/// 交渉力が高いほど上乗せ要求が通りやすく、人脈が広いほど強いクラブの
/// オファーを引いてくる。手数料はその対価で、年俸から引かれる。
class Agent {
  const Agent({
    required this.name,
    required this.style,
    required this.negotiation,
    required this.reach,
    required this.feePercent,
  });

  final String name;
  final String style;

  /// 交渉力 1〜5。
  final int negotiation;

  /// 人脈。オファー元クラブの強さの上限に足される。
  final int reach;

  /// 手数料（年俸の %）。
  final int feePercent;

  String get description =>
      '交渉力 ${'★' * negotiation}${'☆' * (5 - negotiation)}  人脈 +$reach  手数料 $feePercent%';

  /// 全員架空。
  static const List<Agent> pool = [
    Agent(name: '柏木 誠', style: '堅実', negotiation: 3, reach: 2, feePercent: 5),
    Agent(name: 'ヴィクトル・ラング', style: '強気', negotiation: 5, reach: 4, feePercent: 12),
    Agent(name: '長谷 由紀', style: '人脈', negotiation: 2, reach: 8, feePercent: 8),
    Agent(name: 'マルコ・ペレス', style: '新人', negotiation: 2, reach: 1, feePercent: 3),
    Agent(name: '大塚 玲', style: 'バランス', negotiation: 4, reach: 4, feePercent: 9),
    Agent(name: 'エレナ・コスタ', style: '交渉', negotiation: 5, reach: 1, feePercent: 10),
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
