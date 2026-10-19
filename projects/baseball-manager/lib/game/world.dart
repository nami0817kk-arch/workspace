import 'career.dart';
import 'season.dart';

/// 世界大会(日本代表)。U-12・U-15・U-18・U-23と、プロの世界大会。
/// **国名は実在のもの、大会名は「世界大会」という一般的な呼び方だけ**(商標・固有の大会名は使わない)。
class WorldEvent {
  const WorldEvent({
    required this.id,
    required this.name,
    required this.base,
    required this.selectLine,
    required this.countries,
  });

  final String id; // 'u12' など(保存・実績に使う)
  final String name; // 'U-12世界大会'
  final int base; // 大会の強さの基準
  final double selectLine; // 代表に選ばれる総合評価の目安(運を足して判定)

  /// 対戦する国(弱い順)。最後が決勝の相手。
  final List<String> countries;

  /// 日本代表のチーム力。
  int get team => base + 6;

  /// 各ラウンドの相手の強さ(弱い順)。
  List<int> get opponents => [base - 6, base - 1, base + 3, base + 7];
}

const worldEvents = <WorldEvent>[
  WorldEvent(
      id: 'u12',
      name: 'U-12世界大会',
      base: 40,
      selectLine: 38,
      countries: ['メキシコ', '台湾', '韓国', 'アメリカ']),
  WorldEvent(
      id: 'u15',
      name: 'U-15世界大会',
      base: 50,
      selectLine: 47,
      countries: ['カナダ', '台湾', '韓国', 'アメリカ']),
  WorldEvent(
      id: 'u18',
      name: 'U-18世界大会',
      base: 58,
      selectLine: 54,
      countries: ['オーストラリア', '台湾', '韓国', 'アメリカ']),
  WorldEvent(
      id: 'u23',
      name: 'U-23世界大会',
      base: 66,
      selectLine: 60,
      countries: ['オランダ', '韓国', 'キューバ', 'アメリカ']),
  WorldEvent(
      id: 'pro',
      name: '世界大会',
      base: 78,
      selectLine: 72,
      countries: ['イタリア', 'ドミニカ共和国', 'ベネズエラ', 'アメリカ']),
];

/// この年(年齢・段階)に開かれる世界大会。なければ null。
/// U-12 は12歳、U-15 は15歳、U-18 は18歳、U-23 は大学・社会人の21歳、
/// プロは22歳から4年おき(22・26・30…)。
WorldEvent? worldEventFor({
  required Stage stage,
  required int age,
  required bool hasRoute,
}) {
  String? id;
  if (stage == Stage.youth && age == 12) {
    id = 'u12';
  } else if (stage == Stage.juniorHigh && age == 15) {
    id = 'u15';
  } else if (stage == Stage.highSchool && age == 18) {
    id = 'u18';
  } else if (stage == Stage.pathChoice && hasRoute && age == 21) {
    id = 'u23';
  } else if (stage == Stage.pro && age >= 22 && (age - 22) % 4 == 0) {
    id = 'pro';
  }
  if (id == null) return null;
  return worldEvents.firstWhere((e) => e.id == id);
}

/// 世界大会の結果。
class WorldRecord {
  const WorldRecord({
    required this.age,
    required this.eventId,
    required this.eventName,
    required this.roundsWon,
    required this.rounds,
    required this.line,
    this.lostTo,
  });

  final int age;
  final String eventId;
  final String eventName;
  final int roundsWon;
  final int rounds;
  final Line line;

  /// 負けた相手の国(優勝なら null)。
  final String? lostTo;

  bool get champion => roundsWon >= rounds;

  /// 「優勝」「準優勝」「ベスト4」「ベスト8」「1次ラウンド敗退」。
  String get resultText {
    if (champion) return '優勝';
    final left = rounds - roundsWon; // 残りの勝ち抜き数(1=決勝で敗退)
    return switch (left) {
      1 => '準優勝',
      2 => 'ベスト4',
      3 => 'ベスト8',
      _ => '1次ラウンド敗退',
    };
  }

  Map<String, dynamic> toJson() => {
        'age': age,
        'eventId': eventId,
        'eventName': eventName,
        'roundsWon': roundsWon,
        'rounds': rounds,
        'line': line.toJson(),
        'lostTo': lostTo,
      };

  /// 項目を足すときは既定値を置く。
  factory WorldRecord.fromJson(Map<String, dynamic> j) => WorldRecord(
        age: (j['age'] as num?)?.toInt() ?? 0,
        eventId: (j['eventId'] as String?) ?? '',
        eventName: (j['eventName'] as String?) ?? '世界大会',
        roundsWon: (j['roundsWon'] as num?)?.toInt() ?? 0,
        rounds: (j['rounds'] as num?)?.toInt() ?? 4,
        line: Line.fromJson((j['line'] as Map?)?.cast<String, dynamic>() ?? {}),
        lostTo: j['lostTo'] as String?,
      );
}

/// 日本代表として世界大会を戦う。国は弱い順に当たる。
({WorldRecord record, Tournament tournament}) wrapWorld({
  required WorldEvent event,
  required int age,
  required Tournament tournament,
}) {
  final lost =
      tournament.champion ? null : event.countries[tournament.roundsWon];
  return (
    record: WorldRecord(
      age: age,
      eventId: event.id,
      eventName: event.name,
      roundsWon: tournament.roundsWon,
      rounds: tournament.rounds,
      line: tournament.line,
      lostTo: lost,
    ),
    tournament: tournament,
  );
}
