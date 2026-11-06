/// プレーのカード。試合では毎ラウンド手札を引き、スタミナを払って出す。
///
/// 数字は [CardStats] にまとめ、カードの文はその数字から作る(文と効き目が食い違わないように)。
/// 「＋」は練習で強くしたカード。
library;

enum CardKind {
  /// 点を取る。
  shot('シュート'),

  /// 引く・次のシュートを強くする・スタミナ。
  play('組み立て'),

  /// 守備(相手の得点を減らす)。
  defense('守り'),

  /// 試合のあいだずっと効く。出したら手札に戻らない。
  power('流れ'),

  /// 疲労など。出せない。
  status('状態');

  const CardKind(this.label);
  final String label;
}

enum Rarity {
  starter('基本'),
  common('ふつう'),
  uncommon('いい'),
  rare('すごい'),
  status('状態');

  const Rarity(this.label);
  final String label;
}

/// シュートの種類(仲間の得意で上乗せが付く)。
enum ShotTag { none, inside, mid, three }

/// 数字だけでは書けない効き目。
enum Special {
  none,

  /// このラウンドにパスを出していれば点が増える。
  afterPass,

  /// パスのあとでないと1点にしかならない。
  needsPass,

  /// 相手の堅い守りの影響を受けない。
  ignorePress,

  /// 相手のこのラウンドの得点を半分にする。
  halveOpponent,

  /// 相手がドライブ・速攻なら止める。
  stopDrive,

  /// 毎ラウンドのはじめに守備。
  zone,

  /// 毎ラウンド多く引く。
  gameMaker,

  /// この試合のシュートすべてに上乗せ。
  rhythmPower,

  /// 最後のラウンドなら大きい。
  lastRound,

  /// 第4クォーターのシュートに上乗せ。
  clutchPower,
}

class CardStats {
  const CardStats({
    required this.cost,
    this.points = 0,
    this.guard = 0,
    this.draw = 0,
    this.stamina = 0,
    this.setup = 0,
    this.rhythm = 0,
    this.fatigue = 0,
    this.nextDraw = 0,
    this.bonus = 0,
  });

  final int cost;
  final int points;
  final int guard;
  final int draw;
  final int stamina;

  /// 次のシュートの上乗せ。
  final int setup;

  /// この試合のシュートすべての上乗せ。
  final int rhythm;

  /// 捨て札に足す疲労の枚数(この試合のあいだだけ)。
  final int fatigue;

  /// 次のラウンドに多く引く枚数。
  final int nextDraw;

  /// 特別な効き目の大きさ(パスのあとの上乗せ・最後のラウンドの点・毎ラウンドの守備など)。
  final int bonus;
}

class CardDef {
  const CardDef({
    required this.id,
    required this.name,
    required this.kind,
    required this.rarity,
    required this.icon,
    required this.base,
    required this.plus,
    this.tag = ShotTag.none,
    this.special = Special.none,
    this.isPass = false,
    this.exhaust = false,
    this.unplayable = false,
  });

  final String id;
  final String name;
  final CardKind kind;
  final Rarity rarity;

  /// 絵(`assets/art/icons/<icon>.png`)。
  final String icon;
  final CardStats base;
  final CardStats plus;
  final ShotTag tag;
  final Special special;

  /// パス(アリウープ・ユーロステップの条件になる)。
  final bool isPass;

  /// 出したらこの試合では戻らない。
  final bool exhaust;
  final bool unplayable;

  CardStats stats(bool upgraded) => upgraded ? plus : base;

  /// カードの文。数字は [stats] から作る。
  String text(bool upgraded) {
    final s = stats(upgraded);
    final parts = <String>[];
    switch (special) {
      case Special.needsPass:
        parts.add('パスのあとなら${s.points}点(なければ1点)');
      case Special.lastRound:
        parts.add('最後のラウンドなら${s.bonus}点(それ以外は${s.points}点)');
      case Special.halveOpponent:
        parts.add('このラウンドの相手の得点を半分に');
      case Special.zone:
        parts.add('毎ラウンドのはじめに守備${s.bonus}');
      case Special.gameMaker:
        parts.add('毎ラウンド${s.bonus}枚多く引く');
      case Special.rhythmPower:
        parts.add('この試合のシュートすべて+${s.rhythm}');
      case Special.clutchPower:
        parts.add('第4クォーターのシュート+${s.bonus}');
      default:
        if (s.points > 0) parts.add('${s.points}点');
    }
    if (special == Special.afterPass) parts.add('パスのあとなら+${s.bonus}');
    if (special == Special.ignorePress) parts.add('相手の守りに邪魔されない');
    if (s.guard > 0) parts.add('守備${s.guard}');
    if (special == Special.stopDrive) parts.add('相手がドライブ・速攻なら止める');
    if (s.draw > 0) parts.add('${s.draw}枚引く');
    if (s.setup > 0) parts.add('次のシュート+${s.setup}');
    if (s.stamina > 0) parts.add('スタミナ+${s.stamina}');
    if (s.rhythm > 0 && special != Special.rhythmPower) parts.add('この試合のシュート+${s.rhythm}');
    if (s.nextDraw > 0) parts.add('次のラウンド${s.nextDraw}枚多く引く');
    if (s.fatigue > 0) parts.add('疲労を${s.fatigue}枚足す');
    if (exhaust) parts.add('この試合で1回');
    if (unplayable) parts.add('出せない。試合が終わると消える');
    return parts.join('・');
  }
}

/// デッキの1枚(同じカードでも、強くしたかどうかは1枚ごと)。
class CardInstance {
  CardInstance(this.def, {this.upgraded = false, int? uid}) : uid = uid ?? _next++;

  static int _next = 1;

  final CardDef def;
  bool upgraded;

  /// 画面で同じカードを見分けるための番号(保存はしない)。
  final int uid;

  CardStats get stats => def.stats(upgraded);
  String get name => upgraded ? '${def.name}＋' : def.name;
  String get text => def.text(upgraded);
  int get cost => stats.cost;

  /// 練習で強くできるか(状態のカードと、強くした後は不可)。
  bool get canUpgrade => !upgraded && def.kind != CardKind.status;

  Map<String, dynamic> toJson() => {'id': def.id, if (upgraded) 'up': true};

  static CardInstance? fromJson(Object? j) {
    if (j is! Map) return null;
    final def = cardById[j['id']];
    if (def == null) return null;
    return CardInstance(def, upgraded: j['up'] == true);
  }

  CardInstance copy() => CardInstance(def, upgraded: upgraded);
}


const allCards = <CardDef>[
  // ── 基本(始めのデッキ)
  CardDef(
      id: 'jumper', name: 'ジャンプシュート', kind: CardKind.shot, rarity: Rarity.starter,
      icon: 'half_star', tag: ShotTag.mid,
      base: CardStats(cost: 1, points: 2), plus: CardStats(cost: 1, points: 3)),
  CardDef(
      id: 'defense', name: 'ディフェンス', kind: CardKind.defense, rarity: Rarity.starter,
      icon: 'clutch_defend',
      base: CardStats(cost: 1, guard: 3), plus: CardStats(cost: 1, guard: 4)),
  CardDef(
      id: 'pass', name: 'パス', kind: CardKind.play, rarity: Rarity.starter,
      icon: 'clutch_pass', isPass: true,
      base: CardStats(cost: 0, draw: 1, setup: 1), plus: CardStats(cost: 0, draw: 2, setup: 1)),
  CardDef(
      id: 'three', name: '3Pシュート', kind: CardKind.shot, rarity: Rarity.starter,
      icon: 'clutch_threePoint', tag: ShotTag.three,
      base: CardStats(cost: 2, points: 4), plus: CardStats(cost: 2, points: 5)),

  // ── ふつう
  CardDef(
      id: 'layup', name: 'レイアップ', kind: CardKind.shot, rarity: Rarity.common,
      icon: 'clutch_drive', tag: ShotTag.inside,
      base: CardStats(cost: 1, points: 2, guard: 1), plus: CardStats(cost: 1, points: 3, guard: 2)),
  CardDef(
      id: 'drive', name: 'ドライブ', kind: CardKind.shot, rarity: Rarity.common,
      icon: 'clutch_drive', tag: ShotTag.inside,
      base: CardStats(cost: 1, points: 2, draw: 1), plus: CardStats(cost: 1, points: 3, draw: 1)),
  CardDef(
      id: 'post', name: 'ポストアップ', kind: CardKind.shot, rarity: Rarity.common,
      icon: 'act_intense', tag: ShotTag.inside,
      base: CardStats(cost: 2, points: 3, guard: 3), plus: CardStats(cost: 2, points: 4, guard: 4)),
  CardDef(
      id: 'bank', name: 'バンクショット', kind: CardKind.shot, rarity: Rarity.common,
      icon: 'half_keep', tag: ShotTag.mid,
      base: CardStats(cost: 0, points: 1), plus: CardStats(cost: 0, points: 2)),
  CardDef(
      id: 'fastbreak', name: '速攻', kind: CardKind.shot, rarity: Rarity.common,
      icon: 'half_tempo', tag: ShotTag.inside,
      base: CardStats(cost: 0, points: 3, fatigue: 1), plus: CardStats(cost: 0, points: 4, fatigue: 1)),
  CardDef(
      id: 'drawfoul', name: 'ファウルをもらう', kind: CardKind.shot, rarity: Rarity.common,
      icon: 'clutch_drawFoul', tag: ShotTag.inside, special: Special.ignorePress,
      base: CardStats(cost: 1, points: 2), plus: CardStats(cost: 1, points: 3)),
  CardDef(
      id: 'boxout', name: 'ボックスアウト', kind: CardKind.defense, rarity: Rarity.common,
      icon: 'half_defense',
      base: CardStats(cost: 1, guard: 4), plus: CardStats(cost: 1, guard: 5)),
  CardDef(
      id: 'block', name: 'ブロックショット', kind: CardKind.defense, rarity: Rarity.common,
      icon: 'clutch_defend',
      base: CardStats(cost: 2, guard: 7), plus: CardStats(cost: 2, guard: 9)),
  CardDef(
      id: 'hustle', name: '全力ディフェンス', kind: CardKind.defense, rarity: Rarity.common,
      icon: 'act_intense',
      base: CardStats(cost: 1, guard: 5, fatigue: 1), plus: CardStats(cost: 1, guard: 7, fatigue: 1)),
  CardDef(
      id: 'rebound', name: 'リバウンド', kind: CardKind.defense, rarity: Rarity.common,
      icon: 'half_defense',
      base: CardStats(cost: 1, guard: 2, nextDraw: 1), plus: CardStats(cost: 1, guard: 3, nextDraw: 1)),
  CardDef(
      id: 'handsup', name: 'ハンズアップ', kind: CardKind.defense, rarity: Rarity.common,
      icon: 'clutch_defend',
      base: CardStats(cost: 0, guard: 1), plus: CardStats(cost: 0, guard: 2)),
  CardDef(
      id: 'shout', name: '声かけ', kind: CardKind.play, rarity: Rarity.common,
      icon: 'act_social',
      base: CardStats(cost: 0, stamina: 1, fatigue: 1), plus: CardStats(cost: 0, stamina: 1)),
  CardDef(
      id: 'screen', name: 'スクリーン', kind: CardKind.play, rarity: Rarity.common,
      icon: 'act_scrimmage',
      base: CardStats(cost: 1, setup: 2, guard: 2), plus: CardStats(cost: 1, setup: 3, guard: 3)),

  // ── いい
  CardDef(
      id: 'eurostep', name: 'ユーロステップ', kind: CardKind.shot, rarity: Rarity.uncommon,
      icon: 'clutch_drive', tag: ShotTag.inside, special: Special.afterPass,
      base: CardStats(cost: 1, points: 2, bonus: 2), plus: CardStats(cost: 1, points: 3, bonus: 3)),
  CardDef(
      id: 'dunk', name: 'ダンク', kind: CardKind.shot, rarity: Rarity.uncommon,
      icon: 'act_intense', tag: ShotTag.inside,
      base: CardStats(cost: 2, points: 4, rhythm: 1), plus: CardStats(cost: 2, points: 6, rhythm: 1)),
  CardDef(
      id: 'stepback', name: 'ステップバック', kind: CardKind.shot, rarity: Rarity.uncommon,
      icon: 'clutch_threePoint', tag: ShotTag.three,
      base: CardStats(cost: 2, points: 4, guard: 2), plus: CardStats(cost: 2, points: 5, guard: 3)),
  CardDef(
      id: 'steal', name: 'スティール', kind: CardKind.defense, rarity: Rarity.uncommon,
      icon: 'half_tempo',
      base: CardStats(cost: 1, guard: 2, points: 2), plus: CardStats(cost: 1, guard: 3, points: 3)),
  CardDef(
      id: 'doubleteam', name: 'ダブルチーム', kind: CardKind.defense, rarity: Rarity.uncommon,
      icon: 'half_defense', special: Special.halveOpponent,
      base: CardStats(cost: 2), plus: CardStats(cost: 1)),
  CardDef(
      id: 'charge', name: 'チャージング', kind: CardKind.defense, rarity: Rarity.uncommon,
      icon: 'clutch_drawFoul', special: Special.stopDrive,
      base: CardStats(cost: 1, guard: 2), plus: CardStats(cost: 1, guard: 4)),
  CardDef(
      id: 'nolook', name: 'ノールックパス', kind: CardKind.play, rarity: Rarity.uncommon,
      icon: 'clutch_pass', isPass: true,
      base: CardStats(cost: 1, draw: 2, setup: 2), plus: CardStats(cost: 1, draw: 3, setup: 2)),
  CardDef(
      id: 'pickroll', name: 'ピック＆ロール', kind: CardKind.play, rarity: Rarity.uncommon,
      icon: 'act_scrimmage', isPass: true,
      base: CardStats(cost: 1, draw: 1, setup: 3), plus: CardStats(cost: 1, draw: 1, setup: 5)),
  CardDef(
      id: 'alleyoop', name: 'アリウープ', kind: CardKind.shot, rarity: Rarity.uncommon,
      icon: 'act_intense', tag: ShotTag.inside, special: Special.needsPass,
      base: CardStats(cost: 1, points: 6), plus: CardStats(cost: 1, points: 8)),
  CardDef(
      id: 'hothand', name: 'リズムに乗る', kind: CardKind.power, rarity: Rarity.uncommon,
      icon: 'half_star', special: Special.rhythmPower,
      base: CardStats(cost: 1, rhythm: 1), plus: CardStats(cost: 0, rhythm: 1)),
  CardDef(
      id: 'floater', name: 'フローター', kind: CardKind.shot, rarity: Rarity.uncommon,
      icon: 'half_keep', tag: ShotTag.mid, special: Special.ignorePress,
      base: CardStats(cost: 1, points: 3), plus: CardStats(cost: 1, points: 4)),

  // ── すごい
  CardDef(
      id: 'deepthree', name: 'ディープスリー', kind: CardKind.shot, rarity: Rarity.rare,
      icon: 'clutch_threePoint', tag: ShotTag.three,
      base: CardStats(cost: 3, points: 8), plus: CardStats(cost: 3, points: 11)),
  CardDef(
      id: 'zone', name: 'ゾーンディフェンス', kind: CardKind.power, rarity: Rarity.rare,
      icon: 'half_defense', special: Special.zone,
      base: CardStats(cost: 2, bonus: 2), plus: CardStats(cost: 2, bonus: 3)),
  CardDef(
      id: 'gamemaker', name: 'ゲームメイク', kind: CardKind.power, rarity: Rarity.rare,
      icon: 'act_study', special: Special.gameMaker,
      base: CardStats(cost: 2, bonus: 1), plus: CardStats(cost: 1, bonus: 1)),
  CardDef(
      id: 'timeout', name: 'タイムアウト', kind: CardKind.play, rarity: Rarity.rare,
      icon: 'act_rest', exhaust: true,
      base: CardStats(cost: 0, stamina: 2, draw: 2), plus: CardStats(cost: 0, stamina: 3, draw: 2)),
  CardDef(
      id: 'buzzer', name: 'ブザービーター', kind: CardKind.shot, rarity: Rarity.rare,
      icon: 'clutch_threePoint', tag: ShotTag.three, special: Special.lastRound,
      base: CardStats(cost: 1, points: 2, bonus: 9), plus: CardStats(cost: 1, points: 3, bonus: 12)),
  CardDef(
      id: 'clutch', name: '勝負強さ', kind: CardKind.power, rarity: Rarity.rare,
      icon: 'half_star', special: Special.clutchPower,
      base: CardStats(cost: 1, bonus: 2), plus: CardStats(cost: 1, bonus: 3)),

  // ── 状態
  CardDef(
      id: 'fatigue', name: '疲労', kind: CardKind.status, rarity: Rarity.status,
      icon: 'act_rest', unplayable: true,
      base: CardStats(cost: 0), plus: CardStats(cost: 0)),
];

final cardById = {for (final c in allCards) c.id: c};

CardDef card(String id) => cardById[id]!;

/// 始めのデッキ(10枚)。
List<CardInstance> starterDeck() => [
      for (var i = 0; i < 4; i++) CardInstance(card('jumper')),
      for (var i = 0; i < 4; i++) CardInstance(card('defense')),
      CardInstance(card('pass')),
      CardInstance(card('three')),
    ];

/// 報酬・売店に出るカード(基本と状態は出ない)。
List<CardDef> rewardPool({Set<String> locked = const {}}) => [
      for (final c in allCards)
        if (c.rarity != Rarity.starter && c.rarity != Rarity.status && !locked.contains(c.id)) c,
    ];
