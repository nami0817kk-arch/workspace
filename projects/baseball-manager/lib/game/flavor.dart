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
      Ability.trajectory => 'ティー打撃で打球の角度づくり',
      Ability.speed => 'ダッシュとベースランニング',
      Ability.arm => '遠投と送球練習',
      Ability.fielding => 'ノック(守備練習)',
      Ability.catching => 'キャッチボールとゴロ捕球',
      Ability.stuff => 'ブルペンで投げ込み',
      Ability.control => '的を狙うコントロール練習',
      Ability.stamina => 'ランニングと投げ込み',
    };

const _youthTeams = [
  '青葉',
  '若鷹',
  '北風',
  '朝日',
  '白波',
  '緑ヶ丘',
  '星空',
  '双葉',
  '若竹',
  '虹ヶ丘',
  '小鷲',
  '海風',
  '若草',
  '桜台',
  '富士見',
  '銀杏',
];
const _schools = [
  '青陵',
  '北嶺',
  '朱鷺',
  '光明',
  '紅葉台',
  '大和',
  '桜丘',
  '蒼海',
  '白鷺',
  '緑風',
  '清流',
  '星城',
  '朝霧',
  '若松',
  '東陽',
  '西峰',
  '南風',
  '北翔',
  '城山',
  '晴嵐',
];
const _ownUni = ['青嶺', '城北', '海南', '東和', '武蔵野台', '関西学林', '北海', '九州文理'];
const _ownCorp = ['東邦鉄鋼', '日本海運', '中央自動車', '山陽電力', '北陸化学', '若葉生命'];

/// 所属(少年野球のチーム・中学・高校・プロ球団)。プロ入り前後で変わる。
/// `seed` は選手ごとの種(`Game.teamSeed`)。名前だけだと、同じ名前で始めるたびに同じチームだった。
/// 0 は古いセーブ(名前だけで決める)。`course` は大学・社会人のどちらに進んだか(未定なら null)。
String affiliationOf(Stage stage, String name,
    {String? proTeam, int seed = 0, bool? corporate}) {
  final key = seed == 0 ? name : '$name#$seed';
  switch (stage) {
    case Stage.youth:
      return '${_youthTeams[_h(key, 1) % _youthTeams.length]}ジュニアーズ';
    case Stage.juniorHigh:
      return '${_schools[_h(key, 2) % _schools.length]}中学 野球部';
    case Stage.highSchool:
      return '${_schools[_h(key, 3) % _schools.length]}高校 野球部';
    case Stage.pathChoice:
      if (corporate == null) return '進路を考え中';
      return corporate
          ? '${_ownCorp[_h(key, 4) % _ownCorp.length]} 野球部'
          : '${_ownUni[_h(key, 4) % _ownUni.length]}大学 野球部';
    case Stage.pro:
    case Stage.retired:
      return proTeam ?? 'プロ野球';
  }
}

const _prefectures = [
  '北海道',
  '青森県',
  '岩手県',
  '宮城県',
  '秋田県',
  '山形県',
  '福島県',
  '茨城県',
  '栃木県',
  '群馬県',
  '埼玉県',
  '千葉県',
  '東京都',
  '神奈川県',
  '新潟県',
  '富山県',
  '石川県',
  '福井県',
  '山梨県',
  '長野県',
  '岐阜県',
  '静岡県',
  '愛知県',
  '三重県',
  '滋賀県',
  '京都府',
  '大阪府',
  '兵庫県',
  '奈良県',
  '和歌山県',
  '鳥取県',
  '島根県',
  '岡山県',
  '広島県',
  '山口県',
  '徳島県',
  '香川県',
  '愛媛県',
  '高知県',
  '福岡県',
  '佐賀県',
  '長崎県',
  '熊本県',
  '大分県',
  '宮崎県',
  '鹿児島県',
  '沖縄県',
];

/// 出身地(都道府県)。名前から決まる。
String hometownOf(String name) =>
    _prefectures[_h(name, 6) % _prefectures.length];

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
    Ability.catching: .35,
    Ability.arm: .2,
    Ability.fielding: .15,
    Ability.power: .15,
    Ability.contact: .15
  }),
  first('一塁手', {
    Ability.power: .4,
    Ability.contact: .3,
    Ability.trajectory: .1,
    Ability.catching: .1,
    Ability.fielding: .1
  }),
  second('二塁手', {
    Ability.fielding: .3,
    Ability.contact: .25,
    Ability.speed: .2,
    Ability.catching: .15,
    Ability.arm: .1
  }),
  third('三塁手', {
    Ability.power: .25,
    Ability.fielding: .25,
    Ability.arm: .2,
    Ability.contact: .2,
    Ability.catching: .1
  }),
  shortstop('遊撃手', {
    Ability.fielding: .35,
    Ability.speed: .25,
    Ability.arm: .2,
    Ability.catching: .1,
    Ability.contact: .1
  }),
  left('左翼手', {
    Ability.power: .35,
    Ability.contact: .3,
    Ability.trajectory: .15,
    Ability.speed: .1,
    Ability.arm: .1
  }),
  center('中堅手', {
    Ability.speed: .3,
    Ability.fielding: .25,
    Ability.contact: .2,
    Ability.arm: .15,
    Ability.catching: .1
  }),
  right('右翼手', {
    Ability.power: .25,
    Ability.arm: .25,
    Ability.speed: .2,
    Ability.fielding: .15,
    Ability.contact: .15
  }),
  dh('指名打者',
      {Ability.power: .35, Ability.contact: .35, Ability.trajectory: .3}),
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
/// `ikusei` は育成契約(二軍スタート)の間。実際のプロ野球と同じく3桁の背番号で、
/// 一軍に上がる(支配下登録)と2桁に変わる。
int? uniformNumberOf(Stage stage, Player p, {bool ikusei = false}) {
  if (stage == Stage.youth) return null;
  final h = _h(p.name, 5 + stage.index);
  if (stage == Stage.pro && ikusei) return 101 + h % 40;
  if (p.role == Role.pitcher) {
    return stage == Stage.pro ? 11 + h % 19 : 1 + h % 11;
  }
  if (stage == Stage.pro) return 2 + h % 98;
  return 2 + h % 17; // アマチュアは1〜18
}

/// 1行の選手カード: 「背番号18 ・ 右投左打 ・ 遊撃手」。
String playerCardLine(Stage stage, Player p,
    {Pos? position, int? numberOverride, bool ikusei = false}) {
  final n = (stage == Stage.pro ? numberOverride : null) ??
      uniformNumberOf(stage, p, ikusei: ikusei);
  return [
    if (n != null) '背番号$n',
    handednessOf(p.name),
    positionOf(p, position),
  ].join(' ・ ');
}

const _oppYouth = [
  '北斗',
  '若葉',
  '黒潮',
  '大空',
  '赤城',
  '旭',
  '鷲羽',
  '松風',
  '蒼',
  '日向',
  '飛鳥',
  '白樺',
  '千歳',
  '岬',
  '湊',
  '高原',
];
const _oppSchool = [
  '桜丘',
  '東雲',
  '白鳳',
  '岩城',
  '翠嵐',
  '天城',
  '紫雲',
  '栄光',
  '潮見',
  '雷鳴',
  '鳳凰',
  '明星',
  '大鷲',
  '若潮',
  '常盤',
  '春日',
  '霧島',
  '有明',
];
const _oppUni = ['東都', '西海', '北辰', '南陵', '中京', '湘南', '浪速', '瀬戸'];
const _oppCorp = ['大和製作所', '日の出重工', '三星ガス', '青空電機', '北辰食品', '新生運輸'];

/// 勝ち抜き戦の相手の名前(架空)。同じ年・同じ回戦なら毎回同じ。自分の所属とは別の名前にする。
/// `seed` は選手ごとの種(0 は古いセーブ)。年齢と回戦だけで決めると、どの選手でも同じ相手だった。
String opponentName(Stage stage, int age, int round,
    {bool corporate = false, String own = '', int seed = 0}) {
  final pool = switch (stage) {
    Stage.youth => _oppYouth.map((n) => '$nジュニアーズ').toList(),
    Stage.juniorHigh => _oppSchool.map((n) => '$n中学').toList(),
    Stage.highSchool => _oppSchool.map((n) => '$n高校').toList(),
    Stage.pathChoice => corporate
        ? List<String>.of(_oppCorp)
        : _oppUni.map((n) => '$n大学').toList(),
    _ => _oppSchool.map((n) => '$n高校').toList(),
  };
  var i = _h(seed == 0
          ? '$age/$round/${stage.index}'
          : '$age/$round/${stage.index}/$seed') %
      pool.length;
  // 自分の所属と同じ名前は避ける。
  for (var k = 0;
      k < pool.length &&
          own.contains(pool[i].replaceAll(RegExp(r'(ジュニアーズ|中学|高校|大学)$'), ''));
      k++) {
    i = (i + 1) % pool.length;
  }
  return pool[i];
}

/// 海外(アメリカ)のリーグの球団(架空)。
const overseasTeams = [
  'サンベイ・コンドルズ',
  'ニューポート・ブレイカーズ',
  'ミッドランド・グリズリーズ',
  'レイクサイド・ジェッツ',
  'デザートリッジ・コヨーテズ',
  'ハーバーシティ・アンカーズ',
];
