import '../l10n/tr.dart';
import '../models/player.dart';

/// 監督からの提案の種類。オーナーが承認すると実行される。
enum ProposalKind {
  /// 契約が切れそうな主力の契約更新。
  renew,

  /// ユースの有望株の一軍昇格。
  promote;

  String get label => switch (this) {
        renew => Tr.pick('契約更新', 'Contract renewal'),
        promote => Tr.pick('ユース昇格', 'Youth promotion'),
      };
}

/// 承認待ちの提案。
class ManagerProposal {
  const ManagerProposal({
    required this.kind,
    required this.playerId,
    required this.playerName,
  });

  final ProposalKind kind;
  final String playerId;
  final String playerName;

  String get id => '${kind.name}:$playerId';

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'playerId': playerId,
        'playerName': playerName,
      };

  static ManagerProposal? fromJson(Map<String, dynamic> json) {
    final kind =
        ProposalKind.values.where((k) => k.name == json['kind']).firstOrNull;
    if (kind == null) return null;
    return ManagerProposal(
      kind: kind,
      playerId: json['playerId'] as String,
      playerName: json['playerName'] as String,
    );
  }
}

/// 監督が提案を出す条件。
class ProposalEngine {
  const ProposalEngine._();

  /// 同時に溜まる提案の上限。
  static const int maxPending = 3;

  /// 新しく出す提案。[existing]と[declined]にあるものは出さない。
  static List<ManagerProposal> generate({
    required List<Player> squad,
    required List<Player> prospects,
    required List<ManagerProposal> existing,
    required Set<String> declined,
    required bool squadFull,
  }) {
    final out = <ManagerProposal>[];
    bool taken(ManagerProposal p) =>
        declined.contains(p.id) ||
        existing.any((e) => e.id == p.id) ||
        out.any((e) => e.id == p.id);
    var room = maxPending - existing.length;
    if (room <= 0) return out;

    // 契約更新: 残り1年以下で、チームの中央値以上の力がある選手。
    if (squad.isNotEmpty) {
      final sorted = squad.map((p) => p.overall).toList()..sort();
      final median = sorted[sorted.length ~/ 2];
      final candidates = squad
          .where((p) =>
              !p.isLoan &&
              p.contractYearsRemaining <= 1 &&
              p.overall >= median)
          .toList()
        ..sort((a, b) => b.overall.compareTo(a.overall));
      for (final p in candidates) {
        if (room <= 0) break;
        final prop = ManagerProposal(
            kind: ProposalKind.renew, playerId: p.id, playerName: p.name);
        if (taken(prop)) continue;
        out.add(prop);
        room--;
      }
    }

    // ユース昇格: 一軍に空きがあれば、いちばん総合力が高い有望株。
    if (!squadFull && prospects.isNotEmpty && room > 0) {
      final best = [...prospects]
        ..sort((a, b) => b.overall.compareTo(a.overall));
      for (final p in best) {
        final prop = ManagerProposal(
            kind: ProposalKind.promote, playerId: p.id, playerName: p.name);
        if (taken(prop)) continue;
        out.add(prop);
        break;
      }
    }
    return out;
  }
}
