import 'player.dart';
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
