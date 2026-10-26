import 'dart:math';

import 'career.dart';
import 'competition.dart';
import 'world.dart';
import 'season.dart';

/// 1年ぶんの成績(アマチュアはその年の大会、プロはシーズン通算とポストシーズン)。
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
    this.overseas = false,
    this.awards = const [],
    this.months = const [],
    this.twoWay = false,
    this.farm = false,
    this.chances = 0,
    this.errors = 0,
    this.corporate = false,
    this.post = '',
    this.contract = 0,
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

  /// 海外(アメリカ)のリーグでの年か。
  final bool overseas;

  /// この年の表彰(新人王・ベストナインなど。タイトルとは別)。
  final List<String> awards;

  /// プロのシーズンの月ごとの成績(4〜9月)。
  final List<String> months;

  /// 二刀流で戦った年か(スター性: 年俸×1.4・人気+1)。
  final bool twoWay;

  /// 守備の記録(守備機会・失策)。守っていない年・投手は0。古いセーブも0。
  final int chances;
  final int errors;

  /// 守備率(1 - 失策/守備機会)。守備機会が無ければ null。
  double? get fieldingPct => chances == 0 ? null : 1 - errors / chances;

  /// 二軍(育成契約を含む)で戦った年か。タイトル・表彰・日本一の対象にならず、年俸も低い。
  final bool farm;

  /// 社会人(都市対抗)の年か。大学なら false。古いセーブも false。
  final bool corporate;

  /// プロのポストシーズンの結果(「日本一」「日本シリーズ敗退」「CSファイナル敗退」)。出なかった年・古いセーブは空。
  final String post;

  /// この年の年俸(万円)。シーズン前に決まっている額(1年目は新人の契約、2年目からは前の年の契約更改)。
  /// 0 は古いセーブ(成績から計算した値を使う)。
  final int contract;

  bool get isLeague => rank != null;
  bool get champion =>
      isLeague ? rank == 1 : (rounds > 0 && roundsWon == rounds);

  /// 表の「結果」欄: 「全国優勝」「地方大会 決勝敗退」「リーグ優勝・日本一」「3位・CSファイナル敗退」など。
  String get resultText {
    if (isLeague) {
      final base = rank == 1 ? 'リーグ優勝' : '$rank位';
      return post.isEmpty ? base : '$base・$post';
    }
    if (rounds == 0) return '-';
    if (roundsWon == rounds) {
      return amateurChampionText(stage, corporate: corporate);
    }
    return amateurLossText(stage, roundsWon, rounds, corporate: corporate);
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
        'overseas': overseas,
        'awards': awards,
        'months': months,
        'twoWay': twoWay,
        'farm': farm,
        'chances': chances,
        'errors': errors,
        'corporate': corporate,
        'post': post,
        'contract': contract,
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
        overseas: (j['overseas'] as bool?) ?? false,
        awards: [
          for (final t in (j['awards'] as List?) ?? const []) t as String
        ],
        months: [
          for (final t in (j['months'] as List?) ?? const []) t as String
        ],
        twoWay: (j['twoWay'] as bool?) ?? false,
        farm: (j['farm'] as bool?) ?? false,
        chances: (j['chances'] as num?)?.toInt() ?? 0,
        errors: (j['errors'] as num?)?.toInt() ?? 0,
        corporate: (j['corporate'] as bool?) ?? false,
        post: (j['post'] as String?) ?? '',
        contract: (j['contract'] as num?)?.toInt() ?? 0,
      );
}

/// 打率などの小数を「.285」の形にする(1.000以上は「1.031」)。
String fmtRate(double? v) {
  if (v == null) return '-';
  final s = v.toStringAsFixed(3);
  return v < 1 ? s.substring(1) : s;
}

/// パーセント(0.123 → 12.3%)。
String fmtPct(double? v) =>
    v == null ? '-' : '${(v * 100).toStringAsFixed(1)}%';

/// 小さい数(WHIPや9回あたり): 小数2桁。
String fmt2(double? v) => v == null ? '-' : v.toStringAsFixed(2);

/// 指標(整数。100が平均)。
String fmtPlus(int? v) => v == null ? '-' : '$v';

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

/// 1試合の中身を短く(「3打数2安打 1本塁打」「6回 被安打2 奪三振7」)。
String describeGame(Line g) {
  final parts = <String>[];
  if (g.atBats + g.walks > 0) {
    parts.add('${g.atBats}打数${g.hits}安打'
        '${g.homeRuns > 0 ? ' ${g.homeRuns}本塁打' : ''}'
        '${g.rbi > 0 ? ' ${g.rbi}打点' : ''}');
  }
  if (g.faced > 0) {
    parts.add('${g.inningsText}回 被安打${g.hitsAllowed} 奪三振${g.strikeouts}');
  }
  return parts.join(' / ');
}

/// 試合を決めた(勝ち+個人の出来が際立った)試合か。ログに「★殊勲」を付ける目安。
bool isHeroGame(Line g, {required bool won}) => won && g.rating >= 75;

/// 勝ち抜き戦の呼び名。最後は決勝、その前は準決勝、あとは「N回戦」。
String roundLabel(int index, int total) {
  if (index == total - 1) return '決勝';
  if (index == total - 2 && total >= 3) return '準決勝';
  return '${index + 1}回戦';
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
  // 海外のリーグは年俸が桁違い(×2.5)。
  final v = base *
      (1 + 0.15 * r.titles.length) *
      (r.overseas ? 2.5 : 1.0) *
      (r.twoWay ? 1.4 : 1.0) * // 二刀流は話題性で年俸が高い
      (r.farm ? 0.4 : 1.0); // 二軍(育成契約を含む)は年俸が低い
  return ((v.clamp(400, 200000) / 10).round() * 10).toInt();
}

/// 年俸の表記: 「1750万円」「2億3000万円」。
String fmtSalary(int man) {
  if (man <= 0) return '-';
  final oku = man ~/ 10000;
  final rest = man % 10000;
  if (oku == 0) return '$rest万円';
  return rest == 0 ? '$oku億円' : '$oku億$rest万円';
}

/// 新人の年俸(万円)。ドラフトの順位で決まる(実際のプロ野球の目安。6位=育成契約)。
int rookieSalary(int round) => switch (round) {
      1 => 1500,
      2 => 1200,
      3 => 1000,
      4 => 900,
      5 => 800,
      _ => 400,
    };

/// 契約更改: 今季の年俸 `current` と今季の記録 `r` から、来季の年俸を決める。
/// 今季の成績の年俸(`salaryOf`)を65%・今季の年俸を35%で混ぜる。下がるときは、
/// 減額の上限(1億円を超える年俸は4割、それ以下は2割5分まで)より下げない。
int renewSalary(int current, SeasonRecord r) {
  final raw = salaryOf(r);
  final floor = current * (current > 10000 ? 0.6 : 0.75);
  final v = max(0.65 * raw + 0.35 * current, floor);
  return ((v / 10).round() * 10).clamp(400, 200000).toInt();
}

/// 年ごとの年俸(万円)。記録に年俸(`contract`)があればそれを、無い古い記録は
/// 前の年の年俸と成績から契約更改のように計算する。プロ以外の年は 0。
List<int> salariesOf(List<SeasonRecord> rs) {
  final out = <int>[];
  int? prev;
  SeasonRecord? prevRec;
  for (final r in rs) {
    if (r.stage != Stage.pro) {
      out.add(0);
      continue;
    }
    final s = r.contract > 0
        ? r.contract
        : (prev == null || prevRec == null
            ? salaryOf(r)
            : renewSalary(prev, prevRec));
    out.add(s);
    prev = s;
    prevRec = r;
  }
  return out;
}

/// 記録 `r` の年の年俸(一覧 `rs` の中での、なだらかにした値)。一覧に無ければ、その年の成績だけで。
int salaryIn(List<SeasonRecord> rs, SeasonRecord r) {
  final i = rs.indexOf(r);
  return i < 0 ? salaryOf(r) : salariesOf(rs)[i];
}

/// プロ通算の収入(万円)。
int careerEarnings(List<SeasonRecord> rs) =>
    salariesOf(rs).fold(0, (a, s) => a + s);

/// 人気(0〜100)。タイトル・優勝・日本代表・海外での活躍で上がる。古い年ほど薄れる。
/// 保存せず、成績から計算する。
int popularityOf(List<SeasonRecord> records, List<WorldRecord> world) {
  if (records.isEmpty && world.isEmpty) return 0;
  final last = [
    ...records.map((r) => r.age),
    ...world.map((w) => w.age),
  ].reduce(max);
  double fade(int age) => last - age <= 8 ? 1.0 : 0.5;
  var v = 0.0;
  for (final r in records) {
    var x = 0.0;
    x += r.titles.length * 4;
    if (r.champion) x += r.isLeague ? 4 : 2;
    if (r.isLeague && r.rank != null && r.rank! <= 3) x += 1;
    if (r.overseas) x += 1;
    if (r.twoWay) x += 1; // 二刀流はそれだけで注目される
    if (r.stage == Stage.pro) x += 0.5; // プロにいるだけで知名度が少しある
    v += x * fade(r.age);
  }
  for (final w in world) {
    v += (w.champion ? 9 : 3) * fade(w.age);
  }
  return v.round().clamp(0, 100);
}
