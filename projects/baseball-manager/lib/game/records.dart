import 'dart:math';

import 'career.dart';
import 'season.dart';

/// 1年ぶんの成績(アマチュアは夏の大会、プロはシーズン通算)。
class SeasonRecord {
  const SeasonRecord({
    required this.age,
    required this.stage,
    required this.line,
    this.roundsWon = 0,
    this.rounds = 0,
    this.teamWins = 0,
    this.teamLosses = 0,
    this.rank,
    this.titles = const [],
    this.rivalWon,
  });

  final int age;
  final Stage stage;
  final Line line;

  /// 大会: 勝ち上がった回戦数 / 全体の回戦数。
  final int roundsWon;
  final int rounds;

  /// プロのリーグ戦: チームの勝敗と順位。
  final int teamWins;
  final int teamLosses;
  final int? rank;

  /// この年に獲得したタイトル(首位打者など)。
  final List<String> titles;

  /// ライバルとの勝負の結果(その年に勝負があれば)。
  final bool? rivalWon;

  bool get isLeague => rank != null;
  bool get champion =>
      isLeague ? rank == 1 : (rounds > 0 && roundsWon == rounds);

  /// 表の「結果」欄: 「優勝」「2回戦敗退」「3位」など。
  String get resultText {
    if (isLeague) return rank == 1 ? 'リーグ優勝' : '$rank位';
    if (rounds == 0) return '-';
    if (roundsWon == rounds) return '優勝';
    return '${roundsWon + 1}回戦敗退';
  }

  Map<String, dynamic> toJson() => {
        'age': age,
        'stage': stage.name,
        'line': line.toJson(),
        'roundsWon': roundsWon,
        'rounds': rounds,
        'teamWins': teamWins,
        'teamLosses': teamLosses,
        'rank': rank,
        'titles': titles,
        'rivalWon': rivalWon,
      };

  /// 項目を足すときは既定値を置く。
  factory SeasonRecord.fromJson(Map<String, dynamic> j) => SeasonRecord(
        age: (j['age'] as num?)?.toInt() ?? 0,
        stage: Stage.values
            .firstWhere((s) => s.name == j['stage'], orElse: () => Stage.youth),
        line: Line.fromJson((j['line'] as Map?)?.cast<String, dynamic>() ?? {}),
        roundsWon: (j['roundsWon'] as num?)?.toInt() ?? 0,
        rounds: (j['rounds'] as num?)?.toInt() ?? 0,
        teamWins: (j['teamWins'] as num?)?.toInt() ?? 0,
        teamLosses: (j['teamLosses'] as num?)?.toInt() ?? 0,
        rank: (j['rank'] as num?)?.toInt(),
        titles: [
          for (final t in (j['titles'] as List?) ?? const []) t as String
        ],
        rivalWon: j['rivalWon'] as bool?,
      );
}

/// 打率などの小数を「.285」の形にする(1.000以上は「1.031」)。
String fmtRate(double? v) {
  if (v == null) return '-';
  final s = v.toStringAsFixed(3);
  return v < 1 ? s.substring(1) : s;
}

String fmtEra(double? v) => v == null ? '-' : v.toStringAsFixed(2);

/// 成績の短い説明(画面のログ用)。打者・投手のどちらか、または両方。
String describeLine(Line l) {
  final parts = <String>[];
  if (l.hasBatting) {
    parts.add(
        '打率${fmtRate(l.battingAverage)} 本塁打${l.homeRuns} OPS${fmtRate(l.ops)}');
  }
  if (l.hasPitching) {
    final wl = (l.wins + l.losses) > 0 ? '${l.wins}勝${l.losses}敗 ' : '';
    parts.add('$wl防御率${fmtEra(l.era)} 奪三振${l.strikeouts}');
  }
  return parts.join(' / ');
}

/// プロのシーズン成績からタイトルを決める。規定は試合数に比例(打席は3.1/試合、投球回は0.7/試合)。
List<String> titlesOf(Line l, {required int games, required int rank}) {
  final t = <String>[];
  final qualifiedBat = l.plateAppearances >= games * 3.1;
  final qualifiedPitch = l.inningsPitched >= games * 0.7;
  if (qualifiedBat && (l.battingAverage ?? 0) >= 0.340) t.add('首位打者');
  if (l.homeRuns >= 40) t.add('本塁打王');
  if (qualifiedPitch && (l.era ?? 99) <= 1.60) t.add('最優秀防御率');
  if (l.wins >= 21) t.add('最多勝');
  if (l.strikeouts >= 250) t.add('最多奪三振');
  if (t.length >= 2 || (t.isNotEmpty && rank == 1)) t.add('MVP');
  return t;
}

/// 通算(複数年の合計)。
Line totalOf(Iterable<SeasonRecord> rs) =>
    rs.fold(const Line(), (a, r) => a + r.line);

/// 通算成績の短い説明。プロの記録があればプロ通算、なければ大会通算。
String careerSummary(List<SeasonRecord> rs) {
  final pro = rs.where((r) => r.stage == Stage.pro).toList();
  final target = pro.isNotEmpty ? pro : rs;
  if (target.isEmpty) return '';
  final l = totalOf(target);
  final d = describeLine(l);
  return '${pro.isNotEmpty ? 'プロ通算' : '大会通算'} $d';
}

/// プロの年俸(万円)。保存せず、その年の成績から計算する。
/// 評価50で約1750万、70で約6000万、90で約2億。タイトルを獲るごとに +15%。
/// プロ以外の年は 0。
int salaryOf(SeasonRecord r) {
  if (r.stage != Stage.pro) return 0;
  final base = 500 * pow(1.065, r.line.rating - 30);
  final v = base * (1 + 0.15 * r.titles.length);
  return ((v.clamp(400, 80000) / 10).round() * 10).toInt();
}

/// 年俸の表記: 「1750万円」「2億3000万円」。
String fmtSalary(int man) {
  if (man <= 0) return '-';
  final oku = man ~/ 10000;
  final rest = man % 10000;
  if (oku == 0) return '$rest万円';
  return rest == 0 ? '$oku億円' : '$oku億$rest万円';
}

/// プロ通算の収入(万円)。
int careerEarnings(List<SeasonRecord> rs) =>
    rs.fold(0, (a, r) => a + salaryOf(r));
