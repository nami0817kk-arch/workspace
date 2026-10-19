import 'dart:math';

import 'characters.dart';
import 'life.dart';
import 'player.dart';
import 'training.dart';
import 'traits.dart';

/// 幼少期(少年野球の6〜12歳)の「分かれ道」。1年に1回、決まった年に必ず出て、
/// 選んだことが特性・能力・仲間との絆として一生に残る。選択は記録して保存し、
/// 選手情報の「育ち」と引退後のひとことに出る。
/// `events`(ふだんの出来事)とは別の一覧で、くじでは出ない。
class ChildhoodStep {
  const ChildhoodStep(this.age, this.event, this.notes);

  /// この年(歳)の、年の途中(2回目の行動のあと)に出る。
  final int age;
  final GameEvent event;

  /// 選択肢ごとの、あとで見返す短い記録(「育ち」に出す)。選択肢と同じ順。
  final List<String> notes;

  String get id => event.id;
}

Player _gain(Player p, Ability a, int n) {
  if (!abilitiesOf(p.role).contains(a)) return p;
  return p.copyWith(
    abilities: {...p.abilities, a: (p.of(a) + n).clamp(0, abilityCap)},
  );
}

/// 役割に合う能力(打者は第1候補、投手は第2候補)に足す。
Player _byRole(Player p, Ability bat, Ability pit, int n) =>
    _gain(_gain(p, bat, n), pit, n);

Player _trait(Player p, Trait t) => p.copyWith(traits: gain(p.traits, t));

/// 役割に合う特性を1つ。打者向け・投手向けのどちらかを与える。
Player _roleTrait(Player p, Trait bat, Trait pit) =>
    _trait(p, p.role == Role.pitcher ? pit : bat);

EventChoice _c(
  String label,
  Player Function(Player p) f, {
  int fatigue = 0,
  int morale = 0,
  void Function(Cast cast, Random rng)? onCast,
}) =>
    EventChoice(
      label,
      (p, c, focus) => (
        player: f(p),
        condition:
            c.copyWith(fatigue: c.fatigue + fatigue, morale: c.morale + morale),
      ),
      onCast,
    );

final List<ChildhoodStep> childhoodSteps = [
  ChildhoodStep(
    6,
    GameEvent('kid-first-play', 'はじめての野球。公園で、何をして遊ぶ?', [
      _c('壁に向かって、ひとりで投げる・打つ',
          (p) => _byRole(p, Ability.contact, Ability.control, 1)),
      _c('鬼ごっこで、走り回る', (p) => _byRole(p, Ability.speed, Ability.stamina, 1)),
      _c('図鑑や本を読んで、野球のことを調べる', (p) => _trait(p, Trait.studious), morale: 5),
    ]),
    const ['壁あてが好きな子だった', '走り回るのが好きな子だった', '野球のことを調べるのが好きな子だった'],
  ),
  ChildhoodStep(
    7,
    GameEvent('kid-lesson', '習い事をひとつ始めることになった。', [
      _c('水泳(体が強くなる)',
          (p) => _trait(_gain(p, Ability.stamina, 1), Trait.ironMan),
          fatigue: 5),
      _c('空手(頑丈になる)', (p) => _trait(_gain(p, Ability.power, 1), Trait.sturdy),
          fatigue: 5),
      _c('書道・そろばん(集中力がつく)', (p) => _byRole(p, Ability.eye, Ability.control, 1)),
      _c('習い事はせず、好きなだけ遊ぶ', (p) => _trait(p, Trait.sunny), morale: 10),
    ]),
    const ['水泳を習っていた', '空手を習っていた', '書道・そろばんを習っていた', '習い事はせず、のびのび育った'],
  ),
  ChildhoodStep(
    8,
    GameEvent('kid-promise', '毎日の約束を決めよう。', [
      _c('毎日30分、素振り(投球)をする', (p) => _byRole(p, Ability.power, Ability.stuff, 1),
          fatigue: 8),
      _c('宿題を終えたら、思いきり遊ぶ', (p) => _trait(p, Trait.quickRecovery), morale: 8),
      _c('家族でキャッチボールをする日を作る', (p) => p,
          morale: 8, onCast: (cast, rng) => cast.family?.addBond(15)),
    ]),
    const ['毎日の素振りを約束した', 'めりはりのある毎日を送った', '家族とのキャッチボールが日課だった'],
  ),
  ChildhoodStep(
    9,
    GameEvent('kid-idol', 'テレビで見た選手に、すっかり夢中になった。どんな選手?', [
      _c(
          '豪快な一発・剛速球の選手',
          (p) => _roleTrait(
              _gain(p, Ability.power, 1), Trait.slugger, Trait.fireballer)),
      _c('技巧派(ねらい打ち・精密な制球)',
          (p) => _roleTrait(p, Trait.contactHitter, Trait.finesse)),
      _c(
          '足と体力で魅せる選手',
          (p) => _roleTrait(
              _gain(p, Ability.speed, 1), Trait.speedster, Trait.workhorse)),
    ]),
    const ['豪快な選手に憧れた', '技巧派の選手に憧れた', '足と体力の選手に憧れた'],
  ),
  ChildhoodStep(
    10,
    GameEvent('kid-team', 'チームでの立ち回りを決めるときが来た。', [
      _c('みんなをまとめるキャプテンになる', (p) => _trait(p, Trait.leader), fatigue: 5),
      _c('場を明るくするムードメーカーになる', (p) => p, morale: 15, fatigue: -5),
      _c('自分の練習に集中して、技をみがく',
          (p) => _byRole(p, Ability.contact, Ability.stuff, 1),
          fatigue: 3),
    ]),
    const ['キャプテンを務めた', 'チームのムードメーカーだった', '自分の技をみがくことに集中した'],
  ),
  ChildhoodStep(
    11,
    GameEvent('kid-defeat', '大事な試合に負けて、悔し涙が止まらない。', [
      _c('「次は絶対に勝つ」と決める', (p) => _trait(p, Trait.clutch), morale: -5),
      _c('友だちと笑って、気持ちを切り替える', (p) => _trait(p, Trait.sunny), morale: 12),
      _c('負けた原因を、ひとりで考え抜く', (p) => _trait(p, Trait.studious), morale: 2),
    ]),
    const ['負けて、次こそ勝つと決めた', '負けても笑って切り替えた', '負けた原因を考え抜いた'],
  ),
  ChildhoodStep(
    12,
    GameEvent('kid-dream', '卒団の日。みんなの前で、将来の夢を語る。', [
      _c('「プロ野球選手になる!」', (p) => p, morale: 20),
      _c('「日本代表で世界一になる!」', (p) => _trait(p, Trait.worldStage), morale: 8),
      _c('「ずっと野球を楽しみたい」', (p) => _trait(p, Trait.longevity), morale: 8),
    ]),
    const ['プロ野球選手になると語った', '世界一になると語った', '一生、野球を楽しむと語った'],
  ),
];

/// その歳に出す分かれ道(まだ選んでいなければ)。
ChildhoodStep? childhoodStepFor(int age, Map<String, int> picked) {
  for (final s in childhoodSteps) {
    if (s.age == age && !picked.containsKey(s.id)) return s;
  }
  return null;
}

ChildhoodStep? childhoodStepById(String? id) {
  for (final s in childhoodSteps) {
    if (s.id == id) return s;
  }
  return null;
}

/// 選んだ分かれ道の記録を、年齢順に。(年齢, 記録) の並び。
List<(int, String)> childhoodNotes(Map<String, int> picked) => [
      for (final s in childhoodSteps)
        if (picked.containsKey(s.id) && picked[s.id]! < s.notes.length)
          (s.age, s.notes[picked[s.id]!]),
    ];
