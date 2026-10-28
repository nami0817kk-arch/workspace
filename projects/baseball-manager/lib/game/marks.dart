import 'competition.dart';
import 'dart:math';

import 'calendar.dart';
import 'career.dart';
import 'flavor.dart' show positionOf;
import 'path.dart' show overall;
import 'player.dart';
import 'training.dart' show abilityCap, yearlyDelta;
import 'records.dart';
import 'snapshot.dart';
import 'talent.dart';
import 'rival_story.dart';
import 'season.dart';

/// 通算の節目(初安打・通算100本塁打など)。`before` から `after` で越えたものを返す。
/// 成績から計算するだけで、保存も勝敗への影響もない。
List<String> careerMarks(Line before, Line after) {
  final m = <String>[];
  void cross(int a, int b, List<int> marks, String Function(int) text) {
    for (final t in marks) {
      if (a < t && b >= t) m.add(text(t));
    }
  }

  cross(before.hits, after.hits, const [1, 100, 500, 1000, 1500, 2000, 2500],
      (t) => t == 1 ? 'プロ初安打' : '通算$t安打');
  cross(before.homeRuns, after.homeRuns, const [1, 50, 100, 200, 300, 400, 500],
      (t) => t == 1 ? 'プロ初本塁打' : '通算$t本塁打');
  cross(before.rbi, after.rbi, const [500, 1000, 1500], (t) => '通算$t打点');
  cross(
      before.stolenBases, after.stolenBases, const [100, 300], (t) => '通算$t盗塁');
  cross(before.wins, after.wins, const [1, 50, 100, 150, 200],
      (t) => t == 1 ? 'プロ初勝利' : '通算$t勝');
  cross(before.strikeouts, after.strikeouts, const [500, 1000, 2000, 3000],
      (t) => '通算$t奪三振');
  // 実際の野球にある、長く第一線で続けた人の記録。
  cross(before.games, after.games, const [1000, 1500, 2000], (t) => '通算$t試合出場');
  cross(before.walks, after.walks, const [1000], (t) => '通算$t四球');
  return m;
}

/// プロの記録で、タイトルを獲った年が連続した最長の年数(「N年連続タイトル」)。
int longestTitleStreak(Iterable<SeasonRecord> records) {
  var best = 0, run = 0;
  for (final r in records) {
    if (r.stage != Stage.pro) continue;
    run = r.titles.isEmpty ? 0 : run + 1;
    if (run > best) best = run;
  }
  return best;
}

/// 今の年までで、タイトルの連続が何年か(直近から数える)。
int currentTitleStreak(Iterable<SeasonRecord> records) {
  var run = 0;
  for (final r
      in records.where((r) => r.stage == Stage.pro).toList().reversed) {
    if (r.titles.isEmpty) break;
    run++;
  }
  return run;
}

/// 入団会見のひとこと。ドラフトの順位(`round`)で、期待のされ方が違う。
String pressConferenceNote(int round, int? number) {
  final n = number == null ? '' : '背番号$number。';
  return switch (round) {
    1 => '入団会見: $n「1位指名の期待に応えたい。新人王を狙います」',
    2 || 3 => '入団会見: $n「早く一軍で戦力になりたい」',
    _ => '入団会見: $n「まずは二軍で結果を出して、一軍を目指します」',
  };
}

/// 愛称。いちばん高い能力から決める(同じ選手なら同じ)。
String nicknameOf(Player p) {
  final top = p.abilities.entries
      .reduce((a, b) => b.value > a.value ? b : a); // 同点は先のもの
  if (top.value < 60) return '';
  return switch (top.key) {
    Ability.contact => '安打製造機',
    Ability.power => '大砲',
    Ability.speed => '韋駄天',
    Ability.fielding => '守備の職人',
    Ability.eye => '選球眼の鬼',
    Ability.stuff => '剛腕',
    Ability.control => '精密機械',
    Ability.stamina => '鉄腕',
  };
}

/// 起用の目安: 打者は打順、投手は先発・中継ぎ・抑え。能力から決める。
String lineupRoleOf(Player p) {
  int a(Ability x) => p.abilities[x] ?? 0;
  final isPitcher = p.role == Role.pitcher;
  if (p.role == Role.twoWay) return '二刀流(先発・主軸)';
  if (isPitcher) {
    if (a(Ability.stamina) >= 55) return '先発';
    return a(Ability.stuff) >= 65 ? '抑え' : '中継ぎ';
  }
  final power = a(Ability.power), contact = a(Ability.contact);
  final speed = a(Ability.speed), eye = a(Ability.eye);
  if (power >= 70 && power >= contact) return '4番';
  if (contact + power >= 130) return '3番';
  if (speed + eye >= 130) return '1番';
  if (contact >= 60) return '2番';
  if (power >= 55) return '5番';
  return a(Ability.fielding) >= 60 ? '8番' : '6番';
}

const _injuries = [
  '右肘の違和感',
  '左太もものはり',
  '腰の張り',
  '右肩の炎症',
  '足首のねんざ',
  '背中の痛み',
  '指のけが',
  'ふくらはぎの肉離れ',
];

/// 怪我の名前(ログの彩り)。年齢と月から決まる。
String injuryNameOf(int age, int slot) =>
    _injuries[(age * 7 + slot * 3) % _injuries.length];

const _abilityWord = {
  Ability.contact: 'ミート',
  Ability.power: 'パワー',
  Ability.speed: '走力',
  Ability.fielding: '守備',
  Ability.eye: '選球眼',
  Ability.stuff: '球威',
  Ability.control: '制球',
  Ability.stamina: 'スタミナ',
};

/// 1年の終わりのコーチのひとこと。いちばん低い能力を磨くよう勧める。
String coachWordOf(Player p) {
  final weakest = abilitiesOf(p.role)
      .reduce((a, b) => (p.abilities[b] ?? 0) < (p.abilities[a] ?? 0) ? b : a);
  return 'コーチ「来年は${_abilityWord[weakest]}を磨こう」';
}

/// 殊勲の試合の理由(ログの「★殊勲(猛打賞)」)。試合の中身から決める。
String heroNoteOf(Line g) {
  if (g.homeRuns >= 2) return '${g.homeRuns}本塁打';
  if (g.rbi >= 4) return '${g.rbi}打点';
  if (g.hits >= 4) return '猛打賞';
  if (g.strikeouts >= 10) return '二桁奪三振';
  if (g.hasPitching && g.outs >= 21 && g.hitsAllowed <= 3) return '好投';
  if (g.hasPitching && g.outs >= 6 && g.hitsAllowed <= 1) return '無安打に近い好投';
  if (g.strikeouts >= 5) return '${g.strikeouts}奪三振';
  return '大活躍';
}

/// 自己ベスト(キャリアハイ)の年。成績表から、項目ごとに一番良かった年を選ぶ。
List<({String label, String value, int age})> careerHighs(
    Iterable<SeasonRecord> rs) {
  final out = <({String label, String value, int age})>[];
  void best(
      String label, num? Function(SeasonRecord) f, String Function(num) fmt,
      {bool lower = false, bool Function(SeasonRecord)? ok}) {
    SeasonRecord? top;
    num? topV;
    for (final r in rs) {
      if (ok != null && !ok(r)) continue;
      final v = f(r);
      if (v == null) continue;
      if (topV == null || (lower ? v < topV : v > topV)) {
        top = r;
        topV = v;
      }
    }
    if (top != null && topV != null && (lower || topV > 0)) {
      out.add((label: label, value: fmt(topV), age: top.age));
    }
  }

  best('打率', (r) => r.line.battingAverage, (v) => fmtRate(v.toDouble()),
      ok: (r) => r.line.atBats >= 100);
  best('本塁打', (r) => r.line.homeRuns, (v) => '$v本');
  best('打点', (r) => r.line.rbi, (v) => '$v');
  best('盗塁', (r) => r.line.stolenBases, (v) => '$v');
  best('勝利', (r) => r.line.wins, (v) => '$v勝');
  best('奪三振', (r) => r.line.strikeouts, (v) => '$v');
  best('防御率', (r) => r.line.era, (v) => fmtEra(v.toDouble()),
      lower: true, ok: (r) => r.line.outs >= 90);
  return out;
}

/// 衰えが始まる年齢の目安(能力の伸びがマイナスになる年)。
int declineAge() {
  var a = 20;
  while (growthFactor(a) >= 0) {
    a++;
  }
  return a;
}

/// ファンクラブの会員数(万人)。人気から計算。人気0なら0。
int fanClubOf(int popularity) => (popularity * popularity / 100).round() * 3;

/// 引退後の進路。成績・資産・人気から決める(同じ一生なら同じ)。
String afterCareerOf({
  required String title,
  required int proYears,
  required int popularity,
  required int money,
  required bool madePro,
  String? team,
}) {
  if (!madePro) return '野球で学んだことを生かして、新しい仕事で活躍する。';
  if (title == 'レジェンド' && popularity >= 60) {
    return '解説者として人気を集め、のちに監督としてチームを率いる。';
  }
  if (money >= 50000) return '資産をもとに事業を起こし、実業家として成功する。';
  if (title == 'レジェンド' || title == '一流選手') {
    return '${team ?? '球団'}のコーチとして、次の世代の育成に力を注ぐ。';
  }
  if (proYears >= 10) return '野球教室を開き、子どもたちに野球の楽しさを伝える。';
  return '地元でスポーツ用品店を営み、野球を支え続ける。';
}

int _hash(String s, int salt) {
  var v = 17 + salt;
  for (final c in s.codeUnits) {
    v = (v * 131 + c) & 0x7fffffff;
  }
  return v;
}

/// ライバルとの直接対決(月の一コマ)。結果は今月の成績から決める。プロ同士のときだけ。
String? rivalDuelLine(RivalStory s, int age, int slot, Line month) {
  final pa = s.proAge;
  if (pa == null || age < pa || age > s.retireAge) return null;
  if (slot != 1 && slot != 4) return null;
  final good = (month.hasBatting && (month.ops ?? 0) >= 0.800) ||
      (month.hasPitching && (month.era ?? 99) <= 3.00);
  final n = s.name;
  return good ? '${s.team}の$nとの直接対決。気迫で上回った!' : '${s.team}の$nとの直接対決。ここは競り負けた…';
}

/// 1試合の平均の観客数(万人)。人気と勝率から。球場の大きさがあるので、満員(4.5万人)で頭打ち
/// (2026-10-26 ログを読んで、人気の高い選手のいる年に「平均6.7万人」が出ていた)。
double attendanceOf(int popularity, double winPct) =>
    (1.6 + popularity * 0.022 + winPct * 1.0).clamp(1.2, 4.5);

/// 月報の観客動員の一行。満員なら、そう言う。
String attendanceLine(int popularity, double winPct) {
  final a = attendanceOf(popularity, winPct);
  return a >= 4.5
      ? '観客動員: 連日の満員(平均4.5万人)。'
      : '観客動員: 平均${a.toStringAsFixed(1)}万人。';
}

/// 月間MVP(リーグで毎月1人)。飛び抜けた月(打者 OPS1.100以上・50打数〜、投手 防御率1.20以下・
/// 18回〜)のうち、出来が良いほど選ばれやすい。選ぶのは名前・年齢・月から(乱数の並びは変えない)。
/// それまでは OPS1.000 で必ず選ばれ、強い打者は毎月のように取っていた。
bool monthlyMvp(Line l, String name, int age, int slot) {
  double chance = 0;
  if (l.hasBatting && l.atBats >= 50 && (l.ops ?? 0) >= 1.100) {
    chance = 0.35 + ((l.ops ?? 0) - 1.100) * 2;
  }
  if (l.hasPitching && l.outs >= 54 && (l.era ?? 99) <= 1.20) {
    chance = max(chance, 0.35 + (1.20 - (l.era ?? 99)) * 0.6);
  }
  if (chance <= 0) return false;
  return _hash('$name/mvp/$slot', age) % 100 < (chance.clamp(0, 0.8) * 100);
}

/// 優勝パレードに集まった人数(万人)。人気から。
int paradeCrowd(int popularity) => 2 + popularity ~/ 4;

/// 子どもの人数(結婚した選手のみ。1〜3人)。名前から決まる。
int childrenOf(String partnerName) => 1 + _hash(partnerName, 3) % 3;

/// 人気に応じた、CM出演料(万円/年)。人気40以上から。
int cmFeeOf(int popularity) => popularity >= 90
    ? 15000
    : (popularity >= 70 ? 5000 : (popularity >= 40 ? 1000 : 0));

const _slogans = [
  '一丸',
  '挑戦',
  '突き進め',
  '勝つ野球',
  '全員野球',
  '燃えろ',
  '飛躍',
  '不屈',
  '前へ',
  '頂点へ',
];

/// 球団の年間スローガン。球団名と年齢から決まる(年ごとに変わる)。
String sloganOf(String team, int age) =>
    _slogans[_hash(team, age) % _slogans.length];

const _stadiums = [
  '青波スタジアム',
  '北斗ドーム',
  '朱雀パーク',
  '紅葉フィールド',
  '銀嶺ドーム',
  '黒潮スタジアム',
  '碧海パーク',
  '大和ドーム'
];

/// 本拠地の球場(球団名から決まる)。
String stadiumOf(String team) => _stadiums[_hash(team, 9) % _stadiums.length];

/// 身長・体重(名前から決まる体格に、年齢で成長する)。
String bodyOf(String name, int age) {
  final h = _hash(name, 11);
  final base = 172 + h % 14; // 完成時 172〜185
  final grow = age >= 18 ? 1.0 : (age - 6) / 12 * 0.5 + 0.5;
  final cm = (base * (age >= 18 ? 1.0 : 0.72 + 0.28 * (age - 6) / 12)).round();
  final kg = (cm - 100 + (h ~/ 7) % 10 - 2) * (age >= 18 ? 1.0 : grow);
  return '身長${cm}cm 体重${kg.round()}kg';
}

const _hobbies = [
  '釣り',
  'ゲーム',
  '読書',
  '料理',
  'ドライブ',
  '映画鑑賞',
  '筋トレ',
  'サウナ',
  '音楽',
  '犬の散歩'
];

/// 趣味(名前から決まる)。
String hobbyOf(String name) => _hobbies[_hash(name, 13) % _hobbies.length];

/// 座右の銘。いちばん高い能力から。
String mottoOf(Player p) {
  final top =
      p.abilities.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  return switch (top) {
    Ability.contact => '「一球入魂」',
    Ability.power => '「豪快に、大胆に」',
    Ability.speed => '「足は裏切らない」',
    Ability.fielding => '「守りは勝利の土台」',
    Ability.eye => '「球をよく見よう」',
    Ability.stuff => '「腕を振りきれ」',
    Ability.control => '「丁寧に低めへ」',
    Ability.stamina => '「最後に立っている者が勝つ」',
  };
}

/// 殿堂入り投票の得票率(%)。プロ10年以上の選手だけ資格がある(なければ null)。
/// 称号・タイトル・優勝・通算記録から計算する(保存せず、記録から出す)。
int? hallOfFameVote({
  required List<SeasonRecord> records,
  required String title,
  required bool madePro,
}) {
  final pro = records.where((r) => r.stage == Stage.pro).toList();
  if (!madePro || pro.length < 10) return null;
  final total = totalOf(pro);
  var v = switch (title) {
    'レジェンド' => 70.0,
    '一流選手' => 48.0,
    'レギュラー' => 28.0,
    _ => 12.0,
  };
  v += pro.fold<int>(0, (a, r) => a + r.titles.length) * 3;
  v += pro.where((r) => r.champion).length * 1.5;
  v += pro.fold<int>(0, (a, r) => a + r.awards.length) * 0.8;
  if (total.hits >= 2000) v += 8;
  if (total.homeRuns >= 400) v += 8;
  if (total.wins >= 200) v += 8;
  if (total.strikeouts >= 2500) v += 6;
  return v.round().clamp(0, 100);
}

bool inHallOfFame(int? vote) => vote != null && vote >= 75;

/// 順位表の1行。
typedef StandingRow = ({String team, int wins, int losses, bool mine});

/// プロの1シーズンの順位表(6球団)。自分の球団を `rank` 位に置き、他球団は名前から決まる。
/// 他球団の勝敗は自分の勝敗と矛盾しない(順位どおりに並ぶ)。
List<StandingRow> standingsOf({
  required String team,
  required int rank,
  required int wins,
  required int losses,
  required int age,
  required List<String> league,
}) {
  final others = [
    for (final t in league)
      if (t != team) t
  ]..sort((a, b) => _hash(a, age).compareTo(_hash(b, age)));
  final total = wins + losses;
  final w = <int>[];
  for (var r = 1; r <= 6; r++) {
    var v = (total * (0.62 - 0.05 * (r - 1))).round();
    if (r < rank) v = v < wins + 1 ? wins + 1 : v;
    if (r > rank) v = v > wins - 1 ? wins - 1 : v;
    w.add(v.clamp(0, total));
  }
  // 順位どおりに並び替わらないよう、単調に直す(上から)。
  for (var r = 1; r < 6; r++) {
    if (r + 1 == rank || r == rank) continue;
    if (w[r] > w[r - 1]) w[r] = w[r - 1];
  }
  final rows = <StandingRow>[];
  var oi = 0;
  for (var r = 1; r <= 6; r++) {
    if (r == rank) {
      rows.add((team: team, wins: wins, losses: losses, mine: true));
    } else {
      rows.add((
        team: others[oi++ % others.length],
        wins: w[r - 1],
        losses: total - w[r - 1],
        mine: false
      ));
    }
  }
  return rows;
}

const _kohai = [
  'ひなた',
  'そうた',
  'れん',
  'あおい',
  'かいと',
  'ゆうま',
  'りく',
  'はると',
  'さくら',
  'いつき'
];

/// 新入団選手(後輩)の名前。年齢から決まる。
String kohaiOf(String team, int age) =>
    _kohai[_hash(team, age) % _kohai.length];

/// 同期(同じドラフトで入団した選手)。名前と順位は名前と球団から決まる。
List<(String, int)> classmatesOf(String name, String team) => [
      for (var i = 0; i < 3; i++)
        (
          _kohai[_hash(name + team, i) % _kohai.length],
          1 + _hash(team, i + 20) % 6
        ),
    ];

/// 節目の年齢のひとこと(なければ null)。
/// `finalYear` は大学・社会人の最後の年(この夏のあと、秋のドラフトが最後のチャンス)。
String? ageNote(int age, {bool finalYear = false}) => switch (age) {
      _ when finalYear => '$age歳。大学・社会人の最後の年。この夏のあとのドラフトが、プロへの最後のチャンスだ。',
      12 => '12歳。来年は中学生だ。',
      15 => '15歳。高校でどこを目指すか考える時期だ。',
      18 => '18歳。高校最後の年。進路を決める時が来た。',
      30 => '30歳になった。ここから体の衰えと向き合っていく。',
      35 => '35歳。ベテランと呼ばれるようになった。',
      40 => '40歳。まだ現役でいられることに感謝している。',
      _ => null,
    };

/// 1年間の練習と休養の回数のまとめ。
String yearSummaryOf(int trains, int rests, [int combos = 0]) =>
    'この1年: 練習・特訓$trains回、休養$rests回${combos > 0 ? '、連携$combos回' : ''}。';

/// 背番号の格上げ。タイトルを取った投手はエースナンバー18、打者は3。なければ null。
int? specialNumberOf(Role role, List<SeasonRecord> records) {
  final titled = records.any((r) => r.titles.isNotEmpty);
  if (!titled) return null;
  return role == Role.pitcher ? 18 : 3;
}

/// ライバルのプロでの通算成績のめやす(素質と年数から。実際の試合は行わない)。
String? rivalStatsOf(RivalStory s, int age) {
  final pa = s.proAge;
  if (pa == null || age < pa) return null;
  final years = (age < s.retireAge ? age : s.retireAge) - pa + 1;
  if (years < 1) return null;
  final power = (s.talent - 40) * 0.6; // 年あたり本塁打(めやす)
  final hr = (power * years).round();
  final avg = 0.230 + (s.talent - 50) * 0.0012;
  return '通算 約$hr本塁打・打率${fmtRate(avg.clamp(0.2, 0.34))}($years年)';
}

/// 能力を伸ばし続けたときの総合評価のめやす。`toAge` の歳まで、重点の能力を鍛え続ける。
/// 乱数は使わず、1年の伸びの平均で計算する。
int projectedOverall(Player p, Ability focus, int toAge) {
  var q = p;
  while (q.age < toAge) {
    final next = {
      for (final a in abilitiesOf(q.role))
        a: (q.of(a) + yearlyDelta(q, a, focus).round()).clamp(0, abilityCap),
    };
    q = q.copyWith(age: q.age + 1, abilities: next);
  }
  return overall(q).round();
}

const _tips = [
  '同じ能力を続けて鍛えると、経験点が少し増えて「開眼」することもある。',
  '疲れがたまると怪我をしやすい。70を超えたら休養しよう。',
  'やる気が高いほど、経験点がたくさん貯まる。交流でやる気を上げよう。',
  'ポジションの適性は、能力の組み合わせで決まる。ランクを見て選ぼう。',
  '進学先は、強豪ならプロ入りしやすく、進学校なら最終的な評価が少し高い。',
  'プロ8年目からは、一生に一度だけFA権が使える。',
  '投資は早いほど効く。年俸が入ったらトレーナーに投資してみよう。',
  'コーチに間をあけて教わると、経験点が多い。4回でコーチの特殊能力のコツが満タンになる。',
  '特殊能力は、幼いほど安く取れる。コツを1つ以上つかんでから、経験点で取ろう。',
  '研究は、選んだ特殊能力のコツを2つ貯める。能力タブの本のボタンで選べる。',
  '赤い特殊能力は弱点。経験点を払って克服すると消える。幼いうちほど安い。',
  '金特は16歳(高校)から。もとになる特殊能力を先に取っておこう。',
  '二世として始めると、親の素質と良い特性を受け継げる。',
  '世界大会に出るには、その年の総合評価が目安を超えている必要がある。',
  'オフの過ごし方は、自主トレ・家族旅行・治療から選べる。',
  '殿堂入りには、プロ10年以上と高い称号が必要。',
];

/// 今日のヒント(日付から選ぶ。同じ日は同じ)。
String tipOf(DateTime d) =>
    _tips[(d.year * 372 + d.month * 31 + d.day) % _tips.length];

int get tipCount => _tips.length;

/// 今年の予定(段階ごとの主なできごと)。
List<String> yearPlanOf(Stage stage, int age) => switch (stage) {
      Stage.youth => [
          '春〜冬: 練習・休養・交流を選んで育てる',
          '特殊能力・弱点の克服は、少年のうちが半額',
          '夏: 少年野球の大会',
          '12歳: U-12の世界大会（実力しだい）'
        ],
      Stage.juniorHigh => [
          '入学の年: 進学先とポジションを決める',
          '夏: 中学の大会',
          '15歳: U-15の世界大会（実力しだい）'
        ],
      Stage.highSchool => [
          '入学の年: 進学先とポジションを決める',
          if (age == 16) 'この年から: 金特が取れる',
          '7月: 夏の大会（地方大会→全国大会。ドラフトの評価になる）',
          '18歳: U-18の世界大会（実力しだい）',
          '卒業の年: ドラフト会議'
        ],
      Stage.pathChoice => [
          '大学: 春のリーグ戦→大学選手権 / 社会人: 都市対抗(地区予選→本大会)',
          '卒業の年: ドラフト会議',
          '21歳: U-23の世界大会（実力しだい）'
        ],
      Stage.pro => [
          '年のはじめ: ポジション・オフの過ごし方・今年の目標',
          '4〜9月: ペナントレース143試合（6月は交流戦、7月にオールスター）',
          '10月: 3位までがクライマックスシリーズ→日本シリーズ。表彰・契約更改',
          if (age >= 22 && (age - 22) % 4 == 0) 'この年: 世界大会（実力しだい）',
          '8年目〜: 一生に一度のFA権',
        ],
      Stage.retired => const [],
    };

/// 次の大会(プロはシーズン終了)までの残り。大会のターンを過ぎていれば null(来年)。
({int left, String name, String unit})? untilTournament(Stage stage, int slot,
    {bool corporate = false}) {
  if (stage == Stage.retired) return null;
  final t = stage == Stage.pro ? 6 : (isMonthly(stage) ? 3 : 1);
  if (slot > t) return null;
  return (
    left: t - slot,
    name: stage == Stage.pro
        ? 'シーズン終了'
        : amateurEventName(stage, corporate: corporate),
    unit: isMonthly(stage) ? 'か月' : '季節',
  );
}

const _names = [
  'はると',
  'そうた',
  'れん',
  'あおい',
  'かいと',
  'ゆうま',
  'りく',
  'いつき',
  'ひなた',
  'こうき',
  'たいが',
  'ゆうせい',
  'みなと',
  'しょう',
  'けんた',
  'だいき',
  'つばさ',
  'ひろと',
  'りょう',
  'まさき',
];

/// 名前のおまかせ(ランダム)。
String randomNameOf(Random rng) => _names[rng.nextInt(_names.length)];

/// 選手カードの文章(コピーして友だちに見せる用)。
String profileText(PlayerSnapshot s) {
  final p = Player(
      name: s.name,
      role: s.role,
      age: s.age,
      potential: s.potential,
      abilities: s.abilities);
  final ov = overall(p).round();
  return [
    '【野球育成】${s.name} (${s.age}歳)',
    '総合評価 $ov ・ 素質 ${talentStars(s.potential)}',
    if (nicknameOf(p).isNotEmpty)
      '「${nicknameOf(p)}」 ${s.role == Role.pitcher ? positionOf(p, s.position) : lineupRoleOf(p)}',
    if (s.traits.isNotEmpty) '特性: ${s.traits.map((t) => t.label).join('・')}',
    if (s.endingTitle != null) '称号: ${s.endingTitle}',
  ].join('\n');
}
