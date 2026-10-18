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

/// 守備位置・役割。ポジションごとに、必要な能力の組み合わせ(適性)が違う。
enum Pos {
  catcher('捕手', {
    Ability.fielding: .5,
    Ability.eye: .2,
    Ability.power: .2,
    Ability.contact: .1
  }),
  first('一塁手', {
    Ability.power: .45,
    Ability.contact: .3,
    Ability.eye: .15,
    Ability.fielding: .1
  }),
  second('二塁手', {
    Ability.fielding: .4,
    Ability.contact: .3,
    Ability.speed: .2,
    Ability.eye: .1
  }),
  third('三塁手', {
    Ability.power: .3,
    Ability.fielding: .35,
    Ability.contact: .25,
    Ability.speed: .1
  }),
  shortstop(
      '遊撃手', {Ability.fielding: .5, Ability.speed: .3, Ability.contact: .2}),
  left('左翼手', {
    Ability.power: .4,
    Ability.contact: .35,
    Ability.eye: .15,
    Ability.speed: .1
  }),
  center(
      '中堅手', {Ability.speed: .4, Ability.fielding: .35, Ability.contact: .25}),
  right('右翼手', {
    Ability.power: .3,
    Ability.speed: .25,
    Ability.fielding: .25,
    Ability.contact: .2
  }),
  dh('指名打者', {Ability.power: .4, Ability.contact: .4, Ability.eye: .2}),
  starter('先発', {Ability.stamina: .4, Ability.control: .3, Ability.stuff: .3}),
  reliever(
      '中継ぎ', {Ability.stuff: .4, Ability.control: .35, Ability.stamina: .25}),
  closer('抑え', {Ability.stuff: .55, Ability.control: .3, Ability.stamina: .15});

  const Pos(this.label, this.weights);
  final String label;

  /// 適性に使う能力と重み(合計1)。
  final Map<Ability, double> weights;

  bool get isPitching =>
      this == Pos.starter || this == Pos.reliever || this == Pos.closer;

  static Pos? parse(String? s) {
    for (final p in Pos.values) {
      if (p.name == s) return p;
    }
    return null;
  }
}

/// その役割の選手が選べるポジション。二刀流は先発と、打者のポジション全部。
List<Pos> positionsFor(Role r) => switch (r) {
      Role.batter => [
          for (final p in Pos.values)
            if (!p.isPitching) p
        ],
      Role.pitcher => const [Pos.starter, Pos.reliever, Pos.closer],
      Role.twoWay => [
          Pos.starter,
          for (final p in Pos.values)
            if (!p.isPitching) p
        ],
    };

/// ポジションへの適性(0〜99)。そのポジションに必要な能力の重み付き平均。
int aptitudeOf(Player p, Pos pos) {
  var v = 0.0;
  for (final e in pos.weights.entries) {
    v += p.of(e.key) * e.value;
  }
  return v.round().clamp(0, 99);
}

/// いちばん適性が高いポジション(同点は名前から決めた順で、毎回同じ)。
Pos bestPosition(Player p) {
  final list = [...positionsFor(p.role)]..sort((a, b) {
      final d = aptitudeOf(p, b).compareTo(aptitudeOf(p, a));
      return d != 0 ? d : _h(p.name, a.index).compareTo(_h(p.name, b.index));
    });
  return list.first;
}

/// 実際に守るポジション。自分で決めていて、この役割で選べるならそれ。なければ適性が最も高いところ。
Pos effectivePosition(Player p, Pos? chosen) =>
    chosen != null && positionsFor(p.role).contains(chosen)
        ? chosen
        : bestPosition(p);

/// 適性の低いポジションを選んだときの、チーム力の補正(0以下)。
/// いちばん適性の高い場所を選べば0。適性が12下がるごとに-1(最大-6)。
int positionTeamAdjust(Player p, Pos pos) {
  final gap = aptitudeOf(p, bestPosition(p)) - aptitudeOf(p, pos);
  return -(gap ~/ 12).clamp(0, 6);
}

/// 守備位置の名前(画面用)。
String positionOf(Player p, [Pos? chosen]) =>
    effectivePosition(p, chosen).label;

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
String playerCardLine(Stage stage, Player p, {Pos? position}) {
  final n = uniformNumberOf(stage, p);
  return [
    if (n != null) '背番号$n',
    handednessOf(p.name),
    positionOf(p, position),
  ].join(' ・ ');
}
