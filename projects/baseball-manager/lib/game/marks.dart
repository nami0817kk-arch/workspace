import 'career.dart';
import 'player.dart';
import 'records.dart';
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
  return m;
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
}) {
  if (!madePro) return '野球で学んだことを生かして、新しい仕事で活躍する。';
  if (title == 'レジェンド' && popularity >= 60) {
    return '解説者として人気を集め、のちに監督としてチームを率いる。';
  }
  if (money >= 50000) return '資産をもとに事業を起こし、実業家として成功する。';
  if (title == 'レジェンド' || title == '一流選手') return '球団のコーチとして、次の世代の育成に力を注ぐ。';
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

/// 日本シリーズ(リーグ優勝のあと)。乱数は使わず、年齢と名前と今年の出来から決める。
bool wonSeries(String name, int age, Line season) {
  final bonus = ((season.rating - 50) / 2).round();
  return _hash(name, age) % 100 < 50 + bonus;
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
