import 'dart:math';

import 'career.dart';
import 'exp.dart';
import 'player.dart';
import 'season.dart' show Line, playGame;
import 'traits.dart';

/// 特殊能力(パワプロの特殊能力のように、経験点で取る)。特性(生まれつきの体質・性格)とは別の枠。
///
/// - 取るには、その種類(打撃・守備走塁・投球)の経験点を払う(`skillCost`)。
/// - **コツ**(0〜`maxSkillTips`)が貯まるほど安くなる。コツは研究・特訓・練習試合・交流・コーチで貯まる。
/// - 金の特殊能力(`gold`)は、もとになる特殊能力(`requires`)を持っていないと取れない。
/// - 効き方: 試合の間だけ能力に上乗せ(`effects` → `skillAbilityDelta`)と、大会の勝負どころ(`match` → `skillMatchBonus`)。
///   総合評価にも入る(`skillRating`)。試合への影響の見込みは `skillImpact`。
/// - **名前を変えない**(保存は `name`)。足すときは末尾に足し、テストの個数も直す。
enum Skill {
  // ── 打者(打撃) ──
  chance('チャンス○', '得点圏で集中力が増す。', Category.batting, 30, match: 6),
  powerHitter('パワーヒッター', '打球が遠くへ飛ぶ。', Category.batting, 40,
      effects: {Ability.power: 6}),
  averageHitter('アベレージヒッター', 'ヒットを打つのがうまい。', Category.batting, 40,
      effects: {Ability.contact: 6}),
  eyePlus('選球眼○', 'ボール球に手を出さない。', Category.batting, 35,
      effects: {Ability.eye: 6, Ability.contact: 1}),
  wideAngle('広角打法', 'どの方向にも強い打球が打てる。', Category.batting, 45,
      effects: {Ability.contact: 3, Ability.power: 3}),
  // ── 打者(守備走塁) ──
  stealer('盗塁○', 'スタートがうまく、盗塁が増える。', Category.running, 30,
      effects: {Ability.speed: 6}),
  fieldMaster('守備職人', '打球への反応が速い。', Category.running, 30,
      effects: {Ability.fielding: 6}),
  strongArm('強肩', '矢のような送球。', Category.running, 35,
      effects: {Ability.fielding: 3, Ability.speed: 3}),
  // ── 打者の金特 ──
  geniusBat('天才打者', '金の特殊能力。打撃のすべてが一段上。', Category.batting, 120,
      effects: {Ability.contact: 8, Ability.power: 4, Ability.eye: 4},
      gold: true,
      requiresName: 'averageHitter'),
  artist('アーチスト', '金の特殊能力。本塁打を量産する。', Category.batting, 120,
      effects: {Ability.power: 12}, gold: true, requiresName: 'powerHitter'),
  // ── 投手(投球) ──
  strikeout('奪三振', '決め球で三振が取れる。', Category.pitching, 40,
      effects: {Ability.stuff: 5}),
  controlPlus('コントロール○', '狙ったところに投げられる。', Category.pitching, 40,
      effects: {Ability.control: 6}),
  staminaPlus('スタミナ○', '長いイニングを投げられる。', Category.pitching, 35,
      effects: {Ability.stamina: 6}),
  pinch('対ピンチ○', 'ピンチで力を出せる。', Category.pitching, 30, match: 6),
  nobi('ノビ○', '速球が手元で伸びる。', Category.pitching, 40,
      effects: {Ability.stuff: 3, Ability.control: 2}),
  heavyBall('重い球', '打たれても飛ばない。', Category.pitching, 35,
      effects: {Ability.stuff: 3, Ability.stamina: 2}),
  // ── 投手の金特 ──
  geniusArm('天才投手', '金の特殊能力。球の力と精度が一段上。', Category.pitching, 130,
      effects: {Ability.stuff: 8, Ability.control: 6},
      gold: true,
      requiresName: 'strikeout'),
  precision('精密機械', '金の特殊能力。四球をほとんど出さない。', Category.pitching, 120,
      effects: {Ability.control: 12}, gold: true, requiresName: 'controlPlus'),

  // ── 2026-10-24 追加(打者・打撃) ──
  firstPitch('初球○', '初球から迷わず振れる。', Category.batting, 30,
      effects: {Ability.contact: 2, Ability.power: 2}),
  oppositeField('流し打ち', '逆方向へうまく運ぶ。', Category.batting, 35,
      effects: {Ability.contact: 4}),
  pullHitter('プルヒッター', '引っ張って強い打球を飛ばす。', Category.batting, 35,
      effects: {Ability.power: 4}),
  tenacious('粘り打ち', '追い込まれても粘る。', Category.batting, 35,
      effects: {Ability.eye: 4, Ability.contact: 1}),
  multiHit('固め打ち', '当たり出すと止まらない。', Category.batting, 40,
      effects: {Ability.contact: 3, Ability.power: 1}),
  walkOff('サヨナラ男', '試合の最後に強い。', Category.batting, 30, match: 4),
  // ── 追加(打者・守備走塁) ──
  baserunning('走塁○', '次の塁を狙う判断がうまい。', Category.running, 30,
      effects: {Ability.speed: 4}),
  infieldHit('内野安打○', '足で内野安打をもぎ取る。', Category.running, 35,
      effects: {Ability.speed: 3, Ability.contact: 1}),
  throwing('送球○', '送球がそれない。', Category.running, 30,
      effects: {Ability.fielding: 4}),
  // ── 追加(打者の金特) ──
  hitMachine('安打製造機', '金の特殊能力。ヒットを打ち続ける。', Category.batting, 120,
      effects: {Ability.contact: 12}, gold: true, requiresName: 'wideAngle'),
  lightning('電光石火', '金の特殊能力。塁上を駆け回る。', Category.running, 110,
      effects: {Ability.speed: 12}, gold: true, requiresName: 'stealer'),
  ironWall('鉄壁', '金の特殊能力。どんな打球も逃さない。', Category.running, 110,
      effects: {Ability.fielding: 12}, gold: true, requiresName: 'fieldMaster'),
  gambler('勝負師', '金の特殊能力。大一番で必ず打つ。', Category.batting, 110,
      match: 12, gold: true, requiresName: 'chance'),
  // ── 追加(投手) ──
  kire('キレ○', '変化球が鋭く曲がる。', Category.pitching, 40,
      effects: {Ability.stuff: 2, Ability.control: 3}),
  resilient('打たれ強さ', '走者を出しても崩れない。', Category.pitching, 35,
      effects: {Ability.stamina: 3, Ability.control: 2}),
  lateStrong('尻上がり', '回を追うごとに良くなる。', Category.pitching, 30,
      effects: {Ability.stamina: 4}),
  pickoff('牽制○', '走者をくぎ付けにする。', Category.pitching, 30,
      effects: {Ability.control: 3}),
  lowBall('低め○', '低めに集めて打たせて取る。', Category.pitching, 35,
      effects: {Ability.control: 3, Ability.stuff: 1}),
  intimidate('威圧感', 'マウンドに立つだけで打者がひるむ。', Category.pitching, 40,
      effects: {Ability.stuff: 4}),
  goodHold('球持ち○', '打者がタイミングを取りにくい。', Category.pitching, 35,
      effects: {Ability.stuff: 2, Ability.stamina: 2}),
  // ── 追加(投手の金特) ──
  ironArm('鉄腕', '金の特殊能力。何イニングでも投げられる。', Category.pitching, 110,
      effects: {Ability.stamina: 12}, gold: true, requiresName: 'staminaPlus'),
  doctorK('ドクターK', '金の特殊能力。三振の山を築く。', Category.pitching, 120,
      effects: {Ability.stuff: 10, Ability.control: 2},
      gold: true,
      requiresName: 'nobi'),
  braveHeart('強心臓', '金の特殊能力。どんなピンチでも動じない。', Category.pitching, 110,
      match: 12, gold: true, requiresName: 'pinch'),

  // ── 弱点(赤い特殊能力。2026-10-25)。生まれつき持つことがあり、経験点を払って「克服」する(消える)。
  //    値段(`baseCost`)は克服に要る経験点。幼いほど安い(`skillAgeMultiplier`)。コツの対象にはならない。
  chanceBad('チャンス×', '大事な場面で力む。', Category.batting, 30,
      match: -6, negative: true),
  strikeoutProne('三振', '空振りが多い。', Category.batting, 30,
      effects: {Ability.contact: -3}, negative: true),
  doublePlay('併殺', '内野ゴロで併殺になりやすい。', Category.batting, 25,
      effects: {Ability.contact: -2, Ability.power: -1}, negative: true),
  slowRunner('鈍足', '足が遅い。', Category.running, 30,
      effects: {Ability.speed: -5}, negative: true),
  errorProne('エラー', '捕球・送球のミスが多い。', Category.running, 30,
      effects: {Ability.fielding: -5}, negative: true),
  pinchBad('対ピンチ×', 'ピンチで崩れる。', Category.pitching, 30,
      match: -6, negative: true),
  wild('四球', '制球が乱れやすい。', Category.pitching, 35,
      effects: {Ability.control: -5}, negative: true),
  longBall('一発', '甘く入って長打を浴びる。', Category.pitching, 35,
      effects: {Ability.stuff: -4}, negative: true),
  slowStarter('スロースターター', '立ち上がりが不安定。', Category.pitching, 30,
      effects: {Ability.stamina: -4}, negative: true);

  const Skill(this.label, this.description, this.category, this.baseCost,
      {this.effects = const {},
      this.match = 0,
      this.gold = false,
      this.negative = false,
      this.requiresName});

  /// 弱点(赤い特殊能力)。持っていると不利で、経験点を払って克服する。
  final bool negative;

  final String label;

  /// ひとことの説明(効き目は `effectText`)。
  final String description;

  /// 払う経験点の種類。
  final Category category;

  /// コツ0のときの値段(経験点)。
  final int baseCost;

  /// 試合の間だけ能力に足す値。
  final Map<Ability, int> effects;

  /// 大会・世界大会の勝負どころの体調に足す値。
  final int match;

  /// 金の特殊能力(もとの特殊能力が要る・高い)。
  final bool gold;
  final String? requiresName;

  /// 金特のもとになる特殊能力。
  Skill? get requires => requiresName == null ? null : Skill.parse(requiresName!);

  /// この役割の選手が取れるか(打者の特殊能力は投手には取れない。二刀流は両方)。
  bool appliesTo(Role r) => usableCategories(r).contains(category);

  /// 大会の勝負どころに効く(練習試合でコツが貯まりやすい)特殊能力か。
  bool get forMatches =>
      !negative && match > 0 ||
      this == Skill.stealer ||
      this == Skill.staminaPlus ||
      this == Skill.baserunning;

  static Skill? parse(String s) {
    for (final k in Skill.values) {
      if (k.name == s) return k;
    }
    return null;
  }
}

/// 効き目の文(「試合でミート+6・パワー+3」「大会の勝負どころ+6」)。
String effectText(Skill s) {
  String jp(Ability a) => switch (a) {
        Ability.contact => 'ミート',
        Ability.power => 'パワー',
        Ability.eye => '選球眼',
        Ability.speed => '走力',
        Ability.fielding => '守備',
        Ability.stuff => '球威',
        Ability.control => '制球',
        Ability.stamina => 'スタミナ',
      };
  final parts = [
    if (s.effects.isNotEmpty)
      '試合で${s.effects.entries.map((e) => '${jp(e.key)}${e.value >= 0 ? '+' : ''}${e.value}').join('・')}',
    if (s.match != 0) '大会の勝負どころ${s.match > 0 ? '+' : ''}${s.match}',
  ];
  return parts.join('、');
}

/// コツの上限。1つで値段が10%下がり、上限で半額。
const maxSkillTips = 5;
const skillTipDiscount = 0.10;

/// 年齢による値段の倍率。**幼いほど身につけやすく、大人になるほど身につけにくい**(2026-10-25 ユーザー指示)。
/// 少年(〜12歳)0.5・中学0.7・高校0.85・19〜24歳1.0・25〜29歳1.25・30歳〜1.5。
double skillAgeMultiplier(int age) => age <= 12
    ? 0.5
    : age <= 15
        ? 0.7
        : age <= 18
            ? 0.85
            : age <= 24
                ? 1.0
                : age <= 29
                    ? 1.25
                    : 1.5;

/// コツ `tips`・年齢 `age` のときの値段(年齢を渡さなければ倍率1.0の基準値)。
int skillCost(Skill s, int tips, [int age = 20]) => max(
    1,
    (s.baseCost *
            (1 - skillTipDiscount * tips.clamp(0, maxSkillTips)) *
            skillAgeMultiplier(age))
        .round());

/// 役割で取れる特殊能力の一覧(画面の並び順: 金特は最後)。
List<Skill> skillsFor(Role r) => [
      for (final s in Skill.values)
        if (s.appliesTo(r) && !s.gold && !s.negative) s,
      for (final s in Skill.values)
        if (s.appliesTo(r) && s.gold) s,
    ];

/// 役割の弱点(赤い特殊能力)の一覧。
List<Skill> weaknessesFor(Role r) => [
      for (final s in Skill.values)
        if (s.negative && s.appliesTo(r)) s
    ];

/// 生まれつきの弱点。0個55%・1個33%・2個12%。乱数の並びを変えないよう、`seed`(素質・天賦から作る)で決める。
Set<Skill> birthWeaknesses(Role r, int seed) {
  // 近い種でも偏らないよう、混ぜてから使う
  final rng = Random((seed * 0x9E3779B1 + 0x7F4A7C15) & 0x7fffffff);
  final x = rng.nextDouble();
  final n = x < 0.55 ? 0 : (x < 0.88 ? 1 : 2);
  final pool = weaknessesFor(r)..shuffle(rng);
  return pool.take(n).toSet();
}

/// 取れない理由(取れるなら null)。
String? skillBlock(Player p, Skill s, ExpPool pool, int tips) {
  if (!s.appliesTo(p.role)) return 'この役割では取れない';
  if (s.negative) {
    // 弱点は「克服」(持っているものを消す)
    if (!p.skills.contains(s)) return '持っていない';
    if (pool.of(s.category) < skillCost(s, 0, p.age)) return '経験点が足りない';
    return null;
  }
  if (p.skills.contains(s)) return '取得済み';
  final req = s.requires;
  if (req != null && !p.skills.contains(req)) return '「${req.label}」が先に要る';
  if (pool.of(s.category) < skillCost(s, tips, p.age)) return '経験点が足りない';
  return null;
}

/// 試合の間だけ効く能力の上乗せ(特殊能力のぶん)。
Map<Ability, int> skillAbilityDelta(Set<Skill> s) {
  final d = <Ability, int>{};
  for (final k in s) {
    for (final e in k.effects.entries) {
      d[e.key] = (d[e.key] ?? 0) + e.value;
    }
  }
  return d;
}

/// 特殊能力が総合評価に足す値。上乗せの合計(大会の勝負どころの値も)を5で割り、半分にする。
/// 定価で取ると、同じ経験点で能力を上げるのとほぼ同じ。コツが貯まるほど得になる(コツ5で倍)。
double skillRating(Player p) {
  if (p.skills.isEmpty) return 0;
  final pts = skillAbilityDelta(p.skills).values.fold<int>(0, (a, b) => a + b) +
      skillMatchBonus(p.skills);
  // 投手は能力が3つで1点の重みが大きいので、打者と同じ5で割るのが基本(役割で得にならないように)。
  // ただし投手は経験点が1つの種類(投球)に集まり、特殊能力にも回しにくいので、少し重くする(`tPitcherSkillDiv`)。
  final div = p.role == Role.pitcher ? tPitcherSkillDiv / 10 : 5.0;
  return pts / div * tSkillWeight / 100;
}

/// 特殊能力が総合評価に効く重み(×100)。dart run -DBAL_SKW=40 で試せる。
const tSkillWeight = int.fromEnvironment('BAL_SKW', defaultValue: 33);

/// 投手の特殊能力が総合評価に効く重み(割る数×10)。dart run -DBAL_PSKILL=40 で試せる。
const tPitcherSkillDiv = int.fromEnvironment('BAL_PSKILL', defaultValue: 35);

/// 大会(世界大会も)の体調に足す値(特殊能力のぶん)。
int skillMatchBonus(Set<Skill> s) => s.fold(0, (a, k) => a + k.match);

/// 試合への影響の見込み。いまの能力で、その特殊能力が「ある/ない」を同じ乱数で
/// `games` 試合ずつ戦わせ、1シーズン(打者は143試合、投手は先発28試合)あたりに直す。表示用(乱数の並びは本編と関係ない)。
class SkillImpact {
  const SkillImpact(this.lines);

  /// 「打率 +.012」「本塁打 +3」「防御率 -0.21」のような、変わった項目(1シーズンあたり)。
  final List<String> lines;
}

/// 段階ごとの、試算の相手の強さ。
int impactOpponent(Stage s) => switch (s) {
      Stage.youth => 30,
      Stage.juniorHigh => 40,
      Stage.highSchool => 50,
      Stage.pathChoice => 55,
      Stage.pro || Stage.retired => 62,
    };

final _impactCache = <String, SkillImpact>{};

SkillImpact skillImpact(Player p, Skill s, Stage stage, {int games = 250}) {
  final key = [
    p.role.name,
    for (final a in Ability.values) p.of(a),
    for (final k in p.skills) k.name,
    s.name,
    stage.name,
    games,
  ].join(',');
  final hit = _impactCache[key];
  if (hit != null) return hit;
  final lines = <String>[];
  if (s.effects.isNotEmpty) {
    final opp = impactOpponent(stage);
    // 弱点は「克服したら(なくなったら)」どれだけ良くなるかを出す(向きを逆にする)
    final off = p.copyWith(skills: {...p.skills}..remove(s));
    final on = off.copyWith(skills: {...off.skills, s});
    final without = s.negative ? on : off;
    final with_ = s.negative ? off : on;
    var a = const Line(), b = const Line();
    final r1 = Random(7), r2 = Random(7);
    for (var i = 0; i < games; i++) {
      a += playGame(traitAdjusted(without), opp, r1);
      b += playGame(traitAdjusted(with_), opp, r2);
    }
    // 打者は143試合、投手は先発28試合ぶん(5試合に1度の先発)に直す。
    final per = 143 / games;
    final perStart = 28 / games;
    String sg(num v, int digits) =>
        '${v >= 0 ? '+' : ''}${v.toStringAsFixed(digits)}';
    // 乱数のずれで関係ない数字が動いて見えないよう、その特殊能力が上げる能力に結びつく項目だけ出す。
    final e = s.effects.keys.toSet();
    bool has(Ability x) => e.contains(x);
    if (p.role != Role.pitcher && a.atBats > 0) {
      if (has(Ability.contact) || has(Ability.eye) || has(Ability.power)) {
        final d = b.hits / max(1, b.atBats) - a.hits / a.atBats;
        if (d.abs() >= 0.0015) {
          lines.add(
              '打率 ${d >= 0 ? '+' : '-'}${d.abs().toStringAsFixed(3).replaceFirst('0.', '.')}');
        }
      }
      if (has(Ability.power)) {
        final hr = (b.homeRuns - a.homeRuns) * per;
        if (hr.abs() >= 0.5) lines.add('本塁打 ${sg(hr, 0)}');
      }
      if (has(Ability.speed)) {
        final sb = (b.stolenBases - a.stolenBases) * per;
        if (sb.abs() >= 0.5) lines.add('盗塁 ${sg(sb, 0)}');
      }
      if (has(Ability.eye)) {
        final bb = (b.walks - a.walks) * per;
        if (bb.abs() >= 1) lines.add('四球 ${sg(bb, 0)}');
      }
    }
    if (p.role != Role.batter && a.outs > 0) {
      if (has(Ability.stuff) || has(Ability.control)) {
        final d = b.runsAllowed * 27 / max(1, b.outs) - a.runsAllowed * 27 / a.outs;
        if (d.abs() >= 0.02) lines.add('防御率 ${sg(d, 2)}');
      }
      if (has(Ability.stuff)) {
        final k = (b.strikeouts - a.strikeouts) * perStart;
        if (k.abs() >= 1) lines.add('奪三振 ${sg(k, 0)}');
      }
      if (has(Ability.control)) {
        final w = (b.walksGiven - a.walksGiven) * perStart;
        if (w.abs() >= 1) lines.add('与四球 ${sg(w, 0)}');
      }
      if (has(Ability.stamina)) {
        final ip = (b.outs - a.outs) / 3 * perStart;
        if (ip.abs() >= 0.5) lines.add('投球回 ${sg(ip, 0)}');
      }
    }
    if (lines.isEmpty && s.effects.containsKey(Ability.fielding)) {
      lines.add('守備率が上がる(失策が減る)');
    }
    if (lines.isEmpty) lines.add('打席・投球の数字はほぼ変わらない');
  }
  if (s.match != 0) {
    // 大会の1試合の勝率: 体調の差 / 500(`season.dart` の勝ち抜き戦と同じ式)。弱点は克服したときの上がり幅
    lines.add('大会の1試合の勝率 +${(s.match.abs() / 500 * 100).toStringAsFixed(1)}%');
  }
  final out = SkillImpact(lines);
  if (_impactCache.length > 500) _impactCache.clear();
  _impactCache[key] = out;
  return out;
}

/// 大会の体調に足す値(特性＋特殊能力)。
int matchBonus(Player p) => tournamentBonus(p.traits) + skillMatchBonus(p.skills);

/// 古いセーブの特性の名前(特殊能力に移したもの)を、特殊能力に読み替える。
const legacyTraitSkills = <String, Skill>{
  'slugger': Skill.powerHitter,
  'contactHitter': Skill.averageHitter,
  'patient': Skill.eyePlus,
  'speedster': Skill.stealer,
  'fireballer': Skill.strikeout,
  'finesse': Skill.controlPlus,
  'workhorse': Skill.staminaPlus,
  'prodigyBat': Skill.geniusBat,
  'prodigyArm': Skill.geniusArm,
};

/// コツを貯める先を選ぶ。`category` が与えられればその種類から。取れるもの(未取得・役割に合う)のうち、
/// コツがいちばん多いもの(同じならくじ)。金特は、もとを持っているときだけ候補にする。
Skill? pickTipTarget(Player p, Map<Skill, int> tips, Random rng,
    {Category? category, bool matchesOnly = false}) {
  final cands = [
    for (final s in skillsFor(p.role))
      if (!p.skills.contains(s) &&
          !s.negative &&
          (tips[s] ?? 0) < maxSkillTips &&
          (category == null || s.category == category) &&
          (!matchesOnly || s.forMatches) &&
          (s.requires == null || p.skills.contains(s.requires)))
        s
  ];
  if (cands.isEmpty) return null;
  final best = cands.map((s) => tips[s] ?? 0).reduce(max);
  final top = [
    for (final s in cands)
      if ((tips[s] ?? 0) == best) s
  ];
  return top[rng.nextInt(top.length)];
}

Map<String, int> skillTipsToJson(Map<Skill, int> m) =>
    {for (final e in m.entries) if (e.value > 0) e.key.name: e.value};

Map<Skill, int> skillTipsFromJson(Object? j) {
  final out = <Skill, int>{};
  if (j is Map) {
    for (final e in j.entries) {
      final s = Skill.parse('${e.key}');
      if (s != null) out[s] = ((e.value as num?)?.toInt() ?? 0).clamp(0, maxSkillTips);
    }
  }
  return out;
}
