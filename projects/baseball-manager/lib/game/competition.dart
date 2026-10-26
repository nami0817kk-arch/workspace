import 'dart:math';

import 'career.dart';
import 'path.dart' show draftTeams;

/// 実際の野球に合わせた、段階ごとの試合の形式(2026-10-26 ユーザー「リアルの試合形式に全体的にして」)。
///
/// - 少年・中学: 夏の大会は県大会 → 全国大会(準決勝・決勝)。
/// - 高校: 夏の大会は地方大会 → 全国大会。
/// - 大学: 春のリーグ戦の優勝を決める一戦 → 大学選手権(全国)。
/// - 社会人: 都市対抗の地区予選 → 本大会。
/// - プロ: 143試合のペナント(6月は交流戦)→ クライマックスシリーズ → 日本シリーズ。
///
/// 勝ち負けの決め方(`season.dart` の勝ち抜き戦)は変えず、呼び名と節目だけをここで決める。
/// 大会名は一般的な呼び名にとどめる(実在の大会名・商標は使わない)。

/// アマの大会の名前(ログの主語)。
String amateurEventName(Stage stage, {bool corporate = false}) => switch (stage) {
      Stage.youth => '夏の学童大会',
      Stage.juniorHigh => '夏の中学大会',
      Stage.highSchool => '夏の大会',
      Stage.pathChoice => corporate ? '都市対抗' : '大学選手権',
      _ => '大会',
    };

/// 段階ごとの勝ち抜きの段(段の名前・試合の名前)。回戦の数(`_leagueRaw` の相手の数)と同じ長さ。
List<(String, String)> _rounds(Stage stage, bool corporate) => switch (stage) {
      Stage.youth || Stage.juniorHigh => const [
          ('県大会', '準決勝'),
          ('県大会', '決勝'),
          ('全国大会', '準決勝'),
          ('全国大会', '決勝'),
        ],
      Stage.highSchool => const [
          ('地方大会', '準決勝'),
          ('地方大会', '決勝'),
          ('全国大会', '準々決勝'),
          ('全国大会', '準決勝'),
          ('全国大会', '決勝'),
        ],
      Stage.pathChoice => corporate
          ? const [
              ('地区予選', '代表決定戦'),
              ('本大会', '準々決勝'),
              ('本大会', '準決勝'),
              ('本大会', '決勝'),
            ]
          : const [
              ('リーグ戦', '優勝決定戦'),
              ('大学選手権', '準々決勝'),
              ('大学選手権', '準決勝'),
              ('大学選手権', '決勝'),
            ],
      _ => const [],
    };

/// 段(地方大会など)を勝ち抜けば全国(本大会)へ進む、最初の全国の試合の番号。無ければ null。
int? amateurQualifyIndex(Stage stage, int total, {bool corporate = false}) {
  final r = _rounds(stage, corporate);
  if (r.length != total) return null;
  for (var i = 1; i < r.length; i++) {
    if (r[i].$1 != r[i - 1].$1) return i;
  }
  return null;
}

/// 試合の呼び名(「地方大会 準決勝」)。形式が合わなければ一般的な「N回戦・準決勝・決勝」。
String amateurRoundLabel(Stage stage, int index, int total,
    {bool corporate = false}) {
  final r = _rounds(stage, corporate);
  if (r.length == total && index >= 0 && index < total) {
    return '${r[index].$1} ${r[index].$2}';
  }
  if (index == total - 1) return '決勝';
  if (index == total - 2 && total >= 3) return '準決勝';
  return '${index + 1}回戦';
}

/// 全国(本大会)へ進んだときのログ(「地方大会を制し、全国大会へ!」)。
String amateurQualifyLine(Stage stage, {bool corporate = false}) =>
    switch (stage) {
      Stage.highSchool => '地方大会を制し、全国大会へ!',
      Stage.pathChoice => corporate
          ? '地区予選を突破し、都市対抗の本大会へ!'
          : 'リーグ戦を制し、大学選手権へ!',
      _ => '県大会を制し、全国大会へ!',
    };

/// 優勝したときの短い結果(表の「結果」欄)。
String amateurChampionText(Stage stage, {bool corporate = false}) =>
    switch (stage) {
      Stage.pathChoice => corporate ? '都市対抗優勝' : '大学日本一',
      Stage.youth || Stage.juniorHigh || Stage.highSchool => '全国優勝',
      _ => '優勝',
    };

/// 優勝したときのログ(「夏の大会で全国優勝した!」)。必ず「優勝した!」で終わる(節目の演出が拾う)。
String amateurChampionLine(Stage stage, {bool corporate = false}) =>
    '${amateurEventName(stage, corporate: corporate)}で'
    '${stage == Stage.pathChoice ? '' : '全国'}優勝した!';

/// 負けたときの表の「結果」欄(「地方大会 決勝敗退」「準優勝」)。
String amateurLossText(Stage stage, int roundsWon, int total,
    {bool corporate = false}) {
  if (roundsWon == total - 1) return '準優勝';
  return '${amateurRoundLabel(stage, roundsWon, total, corporate: corporate)}敗退';
}

/// 負けたときのログ(「夏の大会は地方大会の決勝で敗れた。」)。
String amateurLossLine(Stage stage, int roundsWon, int total,
    {bool corporate = false}) {
  final name = amateurEventName(stage, corporate: corporate);
  if (roundsWon == 0) return '$nameは初戦で敗れた。';
  if (roundsWon == total - 1) return '$nameは準優勝。';
  var label = amateurRoundLabel(stage, roundsWon, total, corporate: corporate);
  // 「大学選手権は大学選手権の準々決勝」のような重なりを避ける
  label = label.startsWith('$name ')
      ? label.substring(name.length + 1)
      : label.replaceFirst(' ', 'の');
  return '$nameは$labelで敗れた。';
}

// ---------------------------------------------------------------------------
// プロのポストシーズン

/// ポストシーズン(クライマックスシリーズ・日本シリーズ)の結果。
class Postseason {
  const Postseason({
    required this.lines,
    required this.champion,
    required this.result,
  });

  /// ログに出す行(シリーズごとの○●と勝敗)。
  final List<String> lines;

  /// 日本一(海外ならリーグの頂点)になったか。
  final bool champion;

  /// 表の「結果」欄に足す短い言葉(「日本一」「日本シリーズ敗退」「CSファイナル敗退」)。出なければ空。
  final String result;
}

int _hash(String s, int salt) {
  var v = 29 + salt;
  for (final c in s.codeUnits) {
    v = (v * 131 + c) & 0x7fffffff;
  }
  return v;
}

/// 短期決戦の1試合に勝つ確率。チームの勝率と自分の出来(`rating`、50が普通)から。
double postseasonWinChance(double winPct, int rating) =>
    (0.5 + (winPct - 0.5) * 0.5 + (rating - 50) / 400).clamp(0.35, 0.65);

/// 先に `need` 勝した方が勝ち抜ける。`lead` は始めからの1勝(リーグ優勝のアドバンテージ)。
/// 試合ごとの○●と、勝ち抜いたかを返す。最大 `maxGames` 試合(決着しなければ、アドバンテージのある側が勝ち抜け)。
({String marks, int wins, int losses, bool won}) _series(Random r, double p,
    {required int need, required int maxGames, int lead = 0, int oppLead = 0}) {
  var w = lead, l = oppLead;
  final b = StringBuffer();
  for (var g = 0; g < maxGames && w < need && l < need; g++) {
    if (r.nextDouble() < p) {
      w++;
      b.write('○');
    } else {
      l++;
      b.write('●');
    }
  }
  final won = w >= need || (l < need && lead > oppLead);
  return (marks: b.toString(), wins: w, losses: l, won: won);
}

/// プロのポストシーズンを進める。乱数は名前と年齢から作る(本編の乱数の並びは変えない)。
/// 3位までがクライマックスシリーズに出る。2位と3位はファーストステージ(3試合・2勝)、
/// 勝った方が1位とファイナルステージ(6試合・4勝。1位に1勝のアドバンテージ)。
/// 勝ち抜けば日本シリーズ(7試合・4勝)。海外の年はプレーオフと優勝決定シリーズ。
Postseason playPostseason({
  required String name,
  required int age,
  required int rank,
  required double winPct,
  required int rating,
  String? team,
  bool overseas = false,
}) {
  if (rank > 3) return const Postseason(lines: [], champion: false, result: '');
  final r = Random(_hash(name, age));
  final p = postseasonWinChance(winPct, rating);
  final lines = <String>[];
  String rec(({String marks, int wins, int losses, bool won}) s,
          {int lead = 0, int oppLead = 0}) =>
      '${s.marks} ${s.wins}勝${s.losses}敗'
      '${lead > 0 ? '(アドバンテージの1勝を含む)' : ''}'
      '${oppLead > 0 ? '(相手のアドバンテージ1勝を含む)' : ''}';
  final cs = overseas ? 'プレーオフ' : 'クライマックスシリーズ';
  if (rank > 1) {
    // ファーストステージ: 2位と3位(2位の本拠地。引き分けは考えない)
    final first = _series(r, p + (rank == 2 ? 0.03 : -0.03),
        need: 2, maxGames: 3);
    lines.add('$cs ファーストステージ: ${rec(first)}'
        '${first.won ? 'で突破!' : 'で敗退。'}');
    if (!first.won) {
      return Postseason(
          lines: lines,
          champion: false,
          result: overseas ? 'プレーオフ敗退' : 'CSファースト敗退');
    }
    // ファイナルステージ: 1位に1勝のアドバンテージ
    final fin = _series(r, p - 0.03, need: 4, maxGames: 6, oppLead: 1);
    lines.add('$cs ファイナルステージ: ${rec(fin, oppLead: 1)}'
        '${fin.won ? 'で突破!' : 'で敗退。'}');
    if (!fin.won) {
      return Postseason(
          lines: lines,
          champion: false,
          result: overseas ? 'プレーオフ敗退' : 'CSファイナル敗退');
    }
  } else {
    final fin = _series(r, p + 0.03, need: 4, maxGames: 6, lead: 1);
    lines.add('$cs ファイナルステージ: ${rec(fin, lead: 1)}'
        '${fin.won ? 'で突破!' : 'で敗退。'}');
    if (!fin.won) {
      return Postseason(
          lines: lines,
          champion: false,
          result: overseas ? 'プレーオフ敗退' : 'CSファイナル敗退');
    }
  }
  final series = overseas ? '優勝決定シリーズ' : '日本シリーズ';
  final others = [
    for (final t in draftTeams)
      if (t != team) t
  ];
  final opp = overseas ? '東地区の覇者' : others[_hash(name, age + 7) % others.length];
  // 相手ももう一方のリーグを勝ち抜いた球団なので、5割に寄せる
  final js = _series(r, 0.5 + (p - 0.5) * 0.5, need: 4, maxGames: 7);
  lines.add('$series(vs $opp): ${rec(js)}'
      '${js.won ? (overseas ? 'で、アメリカのリーグの頂点に立った!' : 'で制し、日本一に輝いた!') : 'で敗れた。'}');
  return Postseason(
    lines: lines,
    champion: js.won,
    result: js.won
        ? (overseas ? '全米制覇' : '日本一')
        : (overseas ? '優勝決定シリーズ敗退' : '日本シリーズ敗退'),
  );
}

/// 交流戦の月(6月。もう一方のリーグの球団と戦う)。
bool isInterleagueMonth(String slotName) => slotName == '6月';
