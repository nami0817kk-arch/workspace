/// 仲間。コートに立つ5人まで連れて行け、それぞれ試合ずっと効く得意を持つ。
/// 強豪に勝つ・部室で迎える・出来事で加わる。名前はすべて架空。
library;

enum MateEffect {
  shooter,
  slasher,
  speedster,
  ace,
  center,
  stopper,
  captain,
  playmaker,
  sixthMan,
  iron,
  manager,
  scout,
  closer,
}

class MateDef {
  const MateDef({
    required this.id,
    required this.name,
    required this.position,
    required this.effect,
    required this.text,
    required this.sprite,
    this.rare = false,
  });

  final String id;
  final String name;

  /// PG・SG・SF・PF・C・6th・マネージャー。
  final String position;
  final MateEffect effect;
  final String text;

  /// 絵(`assets/art/players/<sprite>_<色>.png` の姿勢)。
  final String sprite;
  final bool rare;
}

/// 連れて行ける人数(コートの5人)。
const maxMates = 5;

const allMates = <MateDef>[
  MateDef(
      id: 'shooter', name: '一ノ瀬', position: 'SG', effect: MateEffect.shooter,
      text: '3Pのシュート+1', sprite: 'adult_shoot'),
  MateDef(
      id: 'slasher', name: '鷹野', position: 'SF', effect: MateEffect.slasher,
      text: 'ゴール下のシュート+1', sprite: 'adult_dunk'),
  MateDef(
      id: 'speedster', name: '早乙女', position: 'PG', effect: MateEffect.speedster,
      text: 'スタミナ0のシュート+1', sprite: 'adult'),
  MateDef(
      id: 'ace', name: '天城', position: 'SF', effect: MateEffect.ace,
      text: '毎ラウンド、最初のシュート+2', sprite: 'adult_shoot', rare: true),
  MateDef(
      id: 'center', name: '氷室', position: 'C', effect: MateEffect.center,
      text: '毎ラウンドのはじめに守備2', sprite: 'adult_defense'),
  MateDef(
      id: 'stopper', name: '黒瀬', position: 'SG', effect: MateEffect.stopper,
      text: '守りのカードの守備+1', sprite: 'adult_defense'),
  MateDef(
      id: 'captain', name: '桐生', position: 'PF', effect: MateEffect.captain,
      text: '試合のはじめから、シュートすべて+1', sprite: 'adult', rare: true),
  MateDef(
      id: 'playmaker', name: '月島', position: 'PG', effect: MateEffect.playmaker,
      text: '最初のラウンドに2枚多く引く', sprite: 'adult'),
  MateDef(
      id: 'sixthman', name: '真田', position: '6th', effect: MateEffect.sixthMan,
      text: '第4クォーターと延長は、スタミナ+1', sprite: 'adult'),
  MateDef(
      id: 'iron', name: '御影', position: 'PF', effect: MateEffect.iron,
      text: '疲労のカードが入らない', sprite: 'adult_defense'),
  MateDef(
      id: 'manager', name: '白石', position: 'マネージャー', effect: MateEffect.manager,
      text: '試合で入る部費+50%', sprite: 'adult'),
  MateDef(
      id: 'scout', name: '九条', position: 'マネージャー', effect: MateEffect.scout,
      text: '勝ったあとのカードを4枚から選べる', sprite: 'adult'),
  MateDef(
      id: 'closer', name: '神谷', position: 'SG', effect: MateEffect.closer,
      text: '最後のラウンドのシュート+3', sprite: 'adult_shoot', rare: true),
];

final mateById = {for (final m in allMates) m.id: m};
