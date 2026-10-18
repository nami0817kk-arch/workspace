import 'career.dart';
import 'player.dart';

/// 野球選手らしさを出すための、見た目の情報。**すべて名前と能力から決まる**
/// (保存データは増やさず、同じ選手なら毎回同じになる)。国名・学校名・球団名は架空。

/// 名前から決まる安定した数(乱数を使わない)。
int _h(String s, [int salt = 0]) {
  var v = 17 + salt * 31;
  for (final c in s.codeUnits) {
    v = (v * 131 + c) & 0x7fffffff;
  }
  return v;
}

/// 練習の名前。重点にする能力で、やることが変わる。
String trainingMenu(Ability a) => switch (a) {
      Ability.contact => '素振りとティー打撃',
      Ability.power => 'ウエイトと打ち込み',
      Ability.speed => 'ダッシュとベースランニング',
      Ability.fielding => 'ノック(守備練習)',
      Ability.eye => 'マシンで球の見極め',
      Ability.stuff => 'ブルペンで投げ込み',
      Ability.control => '的を狙うコントロール練習',
      Ability.stamina => 'ランニングと投げ込み',
    };

const _youthTeams = ['青葉', '若鷹', '北風', '朝日', '白波', '緑ヶ丘', '星空', '双葉'];
const _schools = ['青陵', '北嶺', '朱鷺', '光明', '紅葉台', '大和', '桜丘', '蒼海', '白鷺', '緑風'];

/// 所属(少年野球のチーム・中学・高校・プロ球団)。プロ入り前後で変わる。
String affiliationOf(Stage stage, String name, {String? proTeam}) {
  switch (stage) {
    case Stage.youth:
      return '${_youthTeams[_h(name, 1) % _youthTeams.length]}ジュニアーズ';
    case Stage.juniorHigh:
      return '${_schools[_h(name, 2) % _schools.length]}中学 野球部';
    case Stage.highSchool:
      return '${_schools[_h(name, 3) % _schools.length]}高校 野球部';
    case Stage.pathChoice:
      return '進路を考え中';
    case Stage.pro:
    case Stage.retired:
      return proTeam ?? 'プロ野球';
  }
}

/// 投打(右投右打など)。
String handednessOf(String name) {
  final r = _h(name, 4) % 100;
  if (r < 62) return '右投右打';
  if (r < 78) return '右投左打';
  if (r < 96) return '左投左打';
  return '左投右打';
}

/// 守備位置。投手は投手、野手は能力の組み合わせから決める。
String positionOf(Player p) {
  if (p.role == Role.pitcher) return '投手';
  if (p.role == Role.twoWay) return '投手・指名打者';
  int v(Ability a) => p.of(a);
  final score = <String, double>{
    '捕手': v(Ability.fielding) * 1.0 + v(Ability.power) * 0.5,
    '一塁手': v(Ability.power) * 1.0 + v(Ability.contact) * 0.4,
    '二塁手': v(Ability.contact) * 0.6 + v(Ability.fielding) * 0.8,
    '三塁手': v(Ability.power) * 0.7 + v(Ability.fielding) * 0.7,
    '遊撃手': v(Ability.fielding) * 1.0 + v(Ability.speed) * 0.7,
    '左翼手': v(Ability.power) * 0.6 + v(Ability.contact) * 0.6,
    '中堅手': v(Ability.speed) * 1.0 + v(Ability.fielding) * 0.6,
    '右翼手': v(Ability.power) * 0.5 +
        v(Ability.speed) * 0.5 +
        v(Ability.fielding) * 0.3,
  };
  final order = score.keys.toList()
    ..sort((a, b) {
      final d = score[b]!.compareTo(score[a]!);
      return d != 0
          ? d
          : _h(p.name, a.codeUnitAt(0)).compareTo(_h(p.name, b.codeUnitAt(0)));
    });
  return order.first;
}

/// 背番号。少年野球は付けない(null)。投手は1〜19、野手は2〜99。
int? uniformNumberOf(Stage stage, Player p) {
  if (stage == Stage.youth) return null;
  final h = _h(p.name, 5 + stage.index);
  if (p.role == Role.pitcher) {
    return stage == Stage.pro ? 11 + h % 19 : 1 + h % 11;
  }
  if (stage == Stage.pro) return 2 + h % 98;
  return 2 + h % 17; // アマチュアは1〜18
}

/// 1行の選手カード: 「背番号18 ・ 右投左打 ・ 遊撃手」。
String playerCardLine(Stage stage, Player p) {
  final n = uniformNumberOf(stage, p);
  return [
    if (n != null) '背番号$n',
    handednessOf(p.name),
    positionOf(p),
  ].join(' ・ ');
}
