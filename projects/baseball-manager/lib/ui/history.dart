import '../game/game.dart';
import '../game/player.dart';

/// 殿堂: 過去に育てた選手の記録。引退のたびに1件増える(端末ごと)。
class HistoryEntry {
  const HistoryEntry({
    required this.name,
    required this.title,
    required this.role,
    required this.madePro,
    required this.proYears,
    required this.peakOverall,
    required this.championships,
    required this.married,
    required this.wasTwoWay,
  });

  final String name;
  final String title;
  final Role role;
  final bool madePro;
  final int proYears;
  final int peakOverall;
  final int championships;
  final bool married;
  final bool wasTwoWay;

  factory HistoryEntry.of(Game g) {
    final e = g.ending!;
    return HistoryEntry(
      name: g.player.name,
      title: e.title,
      role: g.player.role,
      madePro: e.madePro,
      proYears: e.proYears,
      peakOverall: e.peakOverall,
      championships: e.championships,
      married: e.married,
      wasTwoWay: e.wasTwoWay,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'title': title,
        'role': role.name,
        'madePro': madePro,
        'proYears': proYears,
        'peakOverall': peakOverall,
        'championships': championships,
        'married': married,
        'wasTwoWay': wasTwoWay,
      };

  /// 項目を足すときは既定値を置く。
  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
        name: (j['name'] as String?) ?? '名無し',
        title: (j['title'] as String?) ?? '',
        role: Role.values.firstWhere((r) => r.name == j['role'], orElse: () => Role.batter),
        madePro: (j['madePro'] as bool?) ?? false,
        proYears: (j['proYears'] as num?)?.toInt() ?? 0,
        peakOverall: (j['peakOverall'] as num?)?.toInt() ?? 0,
        championships: (j['championships'] as num?)?.toInt() ?? 0,
        married: (j['married'] as bool?) ?? false,
        wasTwoWay: (j['wasTwoWay'] as bool?) ?? false,
      );
}

/// 殿堂に残す最大件数。
const historyLimit = 30;
