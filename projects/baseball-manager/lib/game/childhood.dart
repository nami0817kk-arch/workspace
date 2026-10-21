import 'dart:math';

import 'characters.dart';
import 'life.dart';
import 'player.dart';
import 'talent.dart';
import 'training.dart';
import 'traits.dart';

/// 幼少期(少年野球の6〜12歳)の「分かれ道」。1年に1回、決まった年に必ず出て、
/// 選んだことが特性・能力・仲間との絆として一生に残る。選択は記録して保存し、
/// 選手情報の「育ち」と引退後のひとことに出る。
/// `events`(ふだんの出来事)とは別の一覧で、くじでは出ない。
class ChildhoodStep {
  const ChildhoodStep(this.age, this.event, this.notes,
      [this.extras = const [], this.minSlot = 1]);

  /// この年(歳)の、年の途中に出る。
  final int age;

  /// この年の何回目の行動のあとから出るか(0始まりの番号)。同じ歳に2つある分かれ道の
  /// 2つ目は、1つ目より後ろに置く。
  final int minSlot;
  final GameEvent event;

  /// 選択肢ごとの、あとで見返す短い記録(「育ち」に出す)。選択肢と同じ順。
  final List<String> notes;

  /// 選択肢ごとの、能力・体調のほかに残るもの(ドラフトでの印象・チームの雰囲気)。
  /// 選択肢と同じ順。空なら全部なし。
  final List<Lasting> extras;

  String get id => event.id;

  /// 幼少期(少年野球)の分かれ道か。中学・高校・進路の分かれ道は false。
  bool get isChildhood => id.startsWith('kid-');
}

/// 分かれ道が残すもの。`draft` はスカウトへの印象(ドラフトの点)、
/// `spirit` は学生のあいだのチーム力への上乗せ(チームの雰囲気)。
class Lasting {
  const Lasting({this.draft = 0, this.spirit = 0});
  final int draft;
  final int spirit;
}

const _none = Lasting();

Player _gain(Player p, Ability a, int n) {
  if (!abilitiesOf(p.role).contains(a)) return p;
  return p.copyWith(
    abilities: {...p.abilities, a: (p.of(a) + n).clamp(0, abilityCap)},
  );
}

/// 役割に合う能力(打者は第1候補、投手は第2候補)に足す。
Player _byRole(Player p, Ability bat, Ability pit, int n) =>
    _gain(_gain(p, bat, n), pit, n);

/// 素質(才能の総合。星5つの元の数字)を上げる。
Player _potential(Player p, int n) =>
    p.copyWith(potential: (p.potential + n).clamp(0, 100));

/// 重点の能力 `focus` の天賦を1段階上げる(使わない能力・上限なら、いちばん低い能力)。
EventChoice _giftChoice(String label, {int fatigue = 0, int morale = 0}) =>
    EventChoice(
      label,
      (p, c, focus) => (
        player: giftUp(p, focus),
        condition:
            c.copyWith(fatigue: c.fatigue + fatigue, morale: c.morale + morale),
      ),
    );

/// 特性を足す。持てない(もう上限・重複・矛盾)ときは、選んだことが無駄にならないよう、
/// いちばん低い能力を+1にする。
Player _trait(Player p, Trait t) {
  if (canGain(p.traits, t)) return p.copyWith(traits: gain(p.traits, t));
  final abilities = [...abilitiesOf(p.role)]
    ..sort((a, b) => p.of(a).compareTo(p.of(b)));
  return _gain(p, abilities.first, 1);
}

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
      _c('図鑑や本を読んで、野球のことを調べる',
          (p) => _byRole(p, Ability.eye, Ability.control, 1),
          morale: 8),
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
      _c('習い事はせず、好きなだけ遊ぶ', (p) => p, morale: 20),
    ]),
    const ['水泳を習っていた', '空手を習っていた', '書道・そろばんを習っていた', '習い事はせず、のびのび育った'],
  ),
  ChildhoodStep(
    8,
    GameEvent('kid-promise', '毎日の約束を決めよう。', [
      _c('毎日30分、素振り(投球)をする', (p) => _byRole(p, Ability.power, Ability.stuff, 1),
          fatigue: 8),
      _c('宿題を終えたら、思いきり遊ぶ', (p) => p, morale: 12, fatigue: -8),
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
      _c('みんなをまとめるキャプテンになる', (p) => p, fatigue: 5, morale: 8,
          onCast: (cast, rng) {
        for (final m in cast.teammates) {
          m.addBond(10);
        }
      }),
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
      _c('友だちと笑って、気持ちを切り替える', (p) => p, morale: 20),
      _c('負けた原因を、ひとりで考え抜く', (p) => p, morale: 2),
    ]),
    const ['負けて、次こそ勝つと決めた', '負けても笑って切り替えた', '負けた原因を考え抜いた'],
  ),
  ChildhoodStep(
    12,
    GameEvent('kid-dream', '卒団の日。みんなの前で、将来の夢を語る。', [
      _c('「プロ野球選手になる!」', (p) => p, morale: 20),
      _c('「日本代表で世界一になる!」', (p) => _byRole(p, Ability.power, Ability.stuff, 1),
          morale: 12),
      _c('「ずっと野球を楽しみたい」', (p) => _byRole(p, Ability.speed, Ability.stamina, 1),
          morale: 12),
    ]),
    const ['プロ野球選手になると語った', '世界一になると語った', '一生、野球を楽しむと語った'],
  ),

  // ── 中学 ──
  ChildhoodStep(
    13,
    GameEvent('turn-jh-club', 'いよいよ中学生。野球は、どこでやる?', [
      _c('強豪の硬式クラブに入る', (p) => _byRole(p, Ability.contact, Ability.stuff, 1),
          fatigue: 10, morale: -3),
      _c('学校の野球部で、仲間と楽しむ', (p) => p, morale: 12, onCast: (cast, rng) {
        for (final m in cast.teammates) {
          m.addBond(8);
        }
      }),
      _c('勉強と野球を、両立させる', (p) => p, morale: 8),
    ]),
    const ['強豪の硬式クラブで鍛えた', '学校の野球部で仲間と楽しんだ', '勉強と野球を両立した'],
    const [_none, Lasting(spirit: 1), _none],
  ),
  ChildhoodStep(
    14,
    GameEvent('turn-jh-body', '体が大きく変わる時期。まず何を大切にする?', [
      _c('食事とトレーニングを徹底する', (p) => _byRole(p, Ability.power, Ability.stamina, 1),
          fatigue: 8),
      _c('しっかり寝て、体を休める', (p) => p, fatigue: -20, morale: 3),
      _c('ストレッチで、体のケアを覚える',
          (p) => _byRole(p, Ability.speed, Ability.stamina, 1),
          morale: 3),
    ]),
    const ['食事とトレーニングで体をつくった', '睡眠を大切にした', '体のケアを覚えた'],
  ),
  ChildhoodStep(
    15,
    GameEvent('turn-jh-exam', '中学最後の年。受験と野球、どうする?', [
      _c('野球は減らさず、受験に挑む',
          (p) => _byRole(p, Ability.contact, Ability.control, 1),
          morale: -8, fatigue: 5),
      _c('勉強に集中して、野球は短く', (p) => p, morale: 5, fatigue: -5),
      _c('先輩やコーチに、進路を相談する', (p) => p, morale: 5, onCast: (cast, rng) {
        cast.coach?.tips += 1;
      }),
    ]),
    const ['野球を減らさず受験に挑んだ', '受験は勉強を優先した', '先輩やコーチに進路を相談した'],
  ),

  // ── 高校 ──
  ChildhoodStep(
    16,
    GameEvent('turn-hs-first', '高校の野球部に入部した。最初の目標は?', [
      _c('1年からレギュラーを狙って、猛アピール',
          (p) => _byRole(p, Ability.fielding, Ability.stamina, 1),
          fatigue: 10, morale: -3),
      _c('1年生の雑用もこなして、チームに溶け込む', (p) => p, morale: 3, onCast: (cast, rng) {
        for (final m in cast.teammates) {
          m.addBond(10);
        }
      }),
      _c('スカウトの目を意識して、自分を磨く', (p) => p, fatigue: 5),
    ]),
    const ['1年からレギュラーを狙った', '雑用をこなしてチームに溶け込んだ', '最初からスカウトの目を意識した'],
    const [_none, Lasting(spirit: 1), _none],
  ),
  ChildhoodStep(
    17,
    GameEvent('turn-hs-rival', '同じ学年に、気になる選手が現れた。どう向き合う?', [
      _c('真っ向勝負で、負けないと決める', (p) => _byRole(p, Ability.power, Ability.stuff, 1),
          morale: -5),
      _c('互いに高め合う仲間として、話しかける', (p) => p, morale: 8, onCast: (cast, rng) {
        cast.rival?.addBond(15);
      }),
      _c('気にせず、自分の野球に集中する', (p) => p, morale: 3),
    ]),
    const ['ライバルに真っ向勝負を挑んだ', 'ライバルと高め合った', '自分の野球に集中した'],
  ),
  ChildhoodStep(
    18,
    GameEvent('turn-hs-last', '高校最後の夏が近づいてきた。どう臨む?', [
      _c('主将として、チームを引っ張る', (p) => _trait(p, Trait.leader), fatigue: 8),
      _c('チームの中心として、結果で語る', (p) => _byRole(p, Ability.power, Ability.stuff, 1),
          fatigue: 8, morale: 3),
      _c('スカウトに、いちばん良い姿を見せる', (p) => p, fatigue: 8, morale: -8),
    ]),
    const ['高校最後の夏、主将として引っ張った', '高校最後の夏、結果で語った', '高校最後の夏、スカウトに全力で見せた'],
    const [Lasting(spirit: 1), _none, Lasting(draft: 1)],
  ),

  // ── 進路(大学・社会人) ──
  ChildhoodStep(
    19,
    GameEvent('turn-route-new', '新しい環境での生活が始まった。何を大切にする?', [
      _c('1年目から主力を狙う', (p) => _byRole(p, Ability.contact, Ability.control, 1),
          fatigue: 8, morale: -3),
      _c('寮生活で、体づくりに専念する', (p) => _byRole(p, Ability.power, Ability.stamina, 1),
          fatigue: 5),
      _c('勉強や仕事も、きちんとこなす', (p) => p, morale: 8),
    ]),
    const ['1年目から主力を狙った', '寮で体づくりに専念した', '勉強や仕事と野球を両立した'],
  ),
  ChildhoodStep(
    20,
    GameEvent('turn-route-slump', '思うように結果が出ない時期が来た。どうする?', [
      _c('原因を分析して、フォームを見直す', (p) => _byRole(p, Ability.eye, Ability.control, 1),
          morale: -3),
      _c('仲間と話して、気分を変える', (p) => p, morale: 12),
      _c('量をこなして、乗り越える', (p) => _trait(p, Trait.hardWorker), fatigue: 12),
    ]),
    const ['不調のとき、フォームを見直した', '不調のとき、仲間と気分を変えた', '不調を練習量で乗り越えた'],
  ),
  ChildhoodStep(
    21,
    GameEvent('turn-route-pro', 'ドラフトが近づいてきた。どうアピールする?', [
      _c('リーグ戦で結果を出すことに集中する',
          (p) => _byRole(p, Ability.power, Ability.stuff, 1),
          fatigue: 5),
      _c('スカウトとの面談に力を入れる', (p) => p, morale: 3),
      _c('いつも通りの自分で、勝負する', (p) => p, morale: 12),
    ]),
    const ['ドラフトの年、結果に集中した', 'ドラフトの年、スカウトに力を入れた', 'ドラフトの年、いつも通りで勝負した'],
    const [_none, _none, _none],
  ),

  // ── 同じ歳に2つめの分かれ道(後ろの回に出る) ──
  ChildhoodStep(
    9,
    GameEvent('kid-stadium', '家族が、球場に試合を見に連れて行ってくれた。何をする?', [
      _c('グラウンドの動きを、食い入るように見る',
          (p) => _byRole(p, Ability.eye, Ability.control, 1),
          morale: 3),
      _c('大声で応援して、思いきり楽しむ', (p) => p, morale: 15),
      _c('帰り道に、家族とたくさん話す', (p) => p,
          morale: 5, onCast: (cast, rng) => cast.family?.addBond(12)),
    ]),
    const ['球場で試合を食い入るように見た', '球場で思いきり応援した', '球場の帰り道、家族と野球の話をした'],
    const [],
    2,
  ),
  ChildhoodStep(
    12,
    GameEvent('kid-friend', 'いちばんの親友と、ケンカをしてしまった。どうする?', [
      _c('自分から謝って、仲直りする', (p) => p, morale: 10, onCast: (cast, rng) {
        for (final m in cast.teammates) {
          m.addBond(6);
        }
      }),
      _c('お互い頭が冷えるまで、野球に打ち込む',
          (p) => _byRole(p, Ability.power, Ability.stuff, 1),
          morale: -5, fatigue: 5),
      _c('コーチに間に入ってもらう', (p) => p, morale: 5, onCast: (cast, rng) {
        cast.coach?.tips += 1;
      }),
    ]),
    const ['親友とケンカして、自分から謝った', '親友とケンカして、野球に打ち込んだ', '親友とのケンカを、コーチに助けてもらった'],
    const [],
    2,
  ),
  // ── 才能が上がる分かれ道(素質の星・能力ごとの天賦の星が増える) ──
  ChildhoodStep(
    7,
    GameEvent('kid-talent-coach', '近所の元選手が、君の動きを見て「筋がいいね」と声をかけてくれた。', [
      _c('「ぜひ、教えてください!」', (p) => _potential(p, 4), fatigue: 10),
      _c('家族に相談して、通うか決める', (p) => _potential(p, 2),
          morale: 5, onCast: (cast, rng) => cast.family?.addBond(10)),
      _c('今は友だちと遊びたい', (p) => p, morale: 15),
    ]),
    const ['元選手に才能を見いだされ、教わった', '元選手の誘いを、家族と相談して決めた', '才能を認められたが、友だちと遊ぶほうを選んだ'],
    const [],
    2,
  ),
  ChildhoodStep(
    10,
    GameEvent('kid-talent-mentor', '憧れの選手の野球教室に参加できた。直接アドバイスをもらえる!', [
      _c('全部メモして、毎日実践する', (p) => _potential(p, 3), fatigue: 8),
      _giftChoice('いちばん得意にしたい動きを、教えてもらう', morale: 5),
      _c('サインをもらって、大喜びする', (p) => p, morale: 20),
    ]),
    const ['憧れの選手の教えを、毎日実践した', '憧れの選手に、得意な動きを教わった', '憧れの選手のサインをもらって大喜びした'],
    const [],
    2,
  ),
  ChildhoodStep(
    11,
    GameEvent('kid-talent-flash', '練習の途中、体の使い方がふっとつかめた気がする!', [
      _giftChoice('この感覚を、重点の能力で繰り返す', fatigue: 6),
      _c('もう少し、いろいろ試してみる', (p) => _potential(p, 3), fatigue: 8),
      _c('気のせいかな、と遊びに戻る', (p) => p, morale: 12),
    ]),
    const ['体の使い方をつかみ、得意を伸ばした', '感覚をつかみかけて、いろいろ試した', '感覚を気にせず、遊びに戻った'],
    const [],
    2,
  ),
  ChildhoodStep(
    14,
    GameEvent('turn-jh-friend', '同級生に「野球より、遊びに行こうよ」と誘われた。', [
      _c('断って、練習に行く', (p) => _byRole(p, Ability.contact, Ability.control, 1),
          morale: -5, fatigue: 5),
      _c('たまには一緒に遊んで、気分転換', (p) => p, morale: 15, fatigue: -8),
      _c('友だちを、野球に誘ってみる', (p) => p, morale: 5, onCast: (cast, rng) {
        for (final m in cast.teammates) {
          m.addBond(8);
        }
      }),
    ]),
    const ['遊びの誘いを断って練習に行った', '友だちと遊んで気分転換した', '友だちを野球に誘った'],
    const [],
    2,
  ),
  ChildhoodStep(
    17,
    GameEvent('turn-hs-love', '気になる人ができた。野球との向き合い方は?', [
      _c('野球が一番。気持ちは胸にしまう',
          (p) => _byRole(p, Ability.speed, Ability.stamina, 1),
          morale: -5),
      _c('試合を見に来てもらえるよう、誘ってみる', (p) => p,
          morale: 12, onCast: (cast, rng) => cast.lover?.addBond(15)),
      _c('友だちに相談して、背中を押してもらう', (p) => p, morale: 8, onCast: (cast, rng) {
        cast.lover?.addBond(8);
        for (final m in cast.teammates) {
          m.addBond(5);
        }
      }),
    ]),
    const ['気になる人への想いを胸にしまい、野球に打ち込んだ', '気になる人を試合に誘った', '友だちに背中を押してもらった'],
    const [],
    5,
  ),
  ChildhoodStep(
    18,
    GameEvent('turn-hs-future', '卒業後の進路を、本気で考えるときが来た。', [
      _c('プロ一本。覚悟を決めて練習に打ち込む',
          (p) => _byRole(p, Ability.contact, Ability.stuff, 1),
          fatigue: 8, morale: 3),
      _c('大学や社会人でじっくり力をつける道も考える', (p) => p, morale: 5, onCast: (cast, rng) {
        cast.coach?.tips += 1;
      }),
      _c('家族に、正直な気持ちを話す', (p) => p,
          morale: 8, onCast: (cast, rng) => cast.family?.addBond(15)),
    ]),
    const ['卒業後はプロ一本と覚悟を決めた', '大学や社会人の道も考えた', '家族に進路の気持ちを話した'],
    const [],
    7,
  ),
  ChildhoodStep(
    20,
    GameEvent('turn-route-money', '野球だけでなく、お金のことも考える年になった。', [
      _c('アルバイトで、生活を支える', (p) => _byRole(p, Ability.speed, Ability.stamina, 1),
          fatigue: 10),
      _c('仕送りや支援に感謝して、野球に専念する',
          (p) => _byRole(p, Ability.power, Ability.stamina, 1),
          morale: 3, onCast: (cast, rng) => cast.family?.addBond(10)),
      _c('スポンサーや後援会に、あいさつに回る', (p) => p, morale: 5, fatigue: 5),
    ]),
    const ['アルバイトで生活を支えた', '支援に感謝して野球に専念した', '後援会にあいさつに回った'],
    const [],
    2,
  ),
];

/// 選んだ分かれ道が残した、ドラフトでの印象の合計。
int draftImpression(Map<String, int> picked) {
  var n = 0;
  for (final s in childhoodSteps) {
    final i = picked[s.id];
    if (i != null && i < s.extras.length) n += s.extras[i].draft;
  }
  return n;
}

/// 選んだ分かれ道が残した、学生のあいだのチームの雰囲気(チーム力への上乗せ)の合計。
int spiritBoost(Map<String, int> picked) {
  var n = 0;
  for (final s in childhoodSteps) {
    final i = picked[s.id];
    if (i != null && i < s.extras.length) n += s.extras[i].spirit;
  }
  return n;
}

/// その歳に出す分かれ道(まだ選んでいなければ)。
ChildhoodStep? childhoodStepFor(int age, Map<String, int> picked, int slot) {
  for (final s in childhoodSteps) {
    if (s.age == age && slot >= s.minSlot && !picked.containsKey(s.id)) {
      return s;
    }
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
