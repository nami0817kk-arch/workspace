import 'dart:math';

/// 性格の4軸。1〜20 で持つ。
///
/// 能力値と違って伸ばすものではなく、**経験で少しずつ変わる**もの。
/// 試合の判断、契約の交渉、監督との関係に効く。
enum PersonalityAxis {
  confidence('自信', '高いと難しい手でも成功率が落ちない。低いと失敗を引きずる'),
  ambition('野心', '高いと格上への移籍を望み、出場機会に厳しい'),
  professionalism('プロ意識', '高いと練習の効果が上がり、衰えが遅い'),
  temper('気性', '高いと交渉で強気に出られるが、監督とぶつかりやすい');

  const PersonalityAxis(this.label, this.description);

  final String label;
  final String description;
}

/// 選手の性格。
class Personality {
  const Personality({
    required this.confidence,
    required this.ambition,
    required this.professionalism,
    this.origin,
    required this.temper,
  });

  final int confidence;
  final int ambition;
  final int professionalism;

  /// **生まれ持った値**。立場で動いた性格を、ここへ引き戻す。
  ///
  /// null なら「これが生まれ持った値」。入れ子は1段だけで、
  /// origin 自身は origin を持たない。
  final Personality? origin;

  /// 生まれ持った性格。動いていなければ自分自身。
  Personality get born => origin ?? withOrigin(null);

  /// 生まれ持った値を覚えたまま、1つの軸だけ差し替える。
  Personality withAxis(PersonalityAxis axis, int value) => Personality(
    confidence: axis == PersonalityAxis.confidence ? value : confidence,
    ambition: axis == PersonalityAxis.ambition ? value : ambition,
    professionalism: axis == PersonalityAxis.professionalism
        ? value
        : professionalism,
    temper: axis == PersonalityAxis.temper ? value : temper,
    origin: origin ?? withOrigin(null),
  );

  Personality withOrigin(Personality? next) => Personality(
    confidence: confidence,
    ambition: ambition,
    professionalism: professionalism,
    temper: temper,
    origin: next,
  );

  /// 立場から決まる落ち着き先へ、1シーズンに1歩だけ寄る。
  ///
  /// 足し算にすると、条件が続く限りいくらでも上がる。
  /// 実測（40キャリア）では**全員がプロ意識 20（上限）で引退**していて、
  /// 練習効率も衰え始めの年齢も全員同じになっていた。
  /// 落ち着き先へ寄せる形にすれば、立場が変われば戻る。
  Personality settleToward(PersonalityAxis axis, int target) {
    final now = this[axis];
    final want = target.clamp(driftMin, driftMax);
    if (now == want) return this;
    return withAxis(axis, now + (want > now ? 1 : -1));
  }

  final int temper;

  static const int min = 1;
  static const int max = 20;

  /// **生活イベントで動ける範囲。**
  ///
  /// 40キャリアを回すと、全員がプロ意識 20（上限）で引退していた。
  /// 生活イベントの選択に「+1 プロ意識」が19か所あって、しかも
  /// **下げるものが1つも無かった**——性格の4軸すべてが一方通行のラチェットで、
  /// 20年やれば誰でも天井に着く。練習効率（0.7+0.03×プロ意識）も
  /// 衰え始めの年齢も全員同じになり、**性格で選手が違ってくる部分が消えていた**。
  ///
  /// イベントで動かせるのはここまで。生まれ持った値（5〜15）はそのまま。
  static const int driftMin = 4;
  static const int driftMax = 16;

  int operator [](PersonalityAxis axis) => switch (axis) {
    PersonalityAxis.confidence => confidence,
    PersonalityAxis.ambition => ambition,
    PersonalityAxis.professionalism => professionalism,
    PersonalityAxis.temper => temper,
  };

  /// 5〜16 のあたりに寄せて引く。極端な性格は珍しい。
  factory Personality.roll(Random random) {
    int roll() => 5 + random.nextInt(6) + random.nextInt(6);
    return Personality(
      confidence: roll(),
      ambition: roll(),
      professionalism: roll(),
      temper: roll(),
    );
  }

  /// 生活イベントで1歩動かす。
  ///
  /// 外へ向かう変化は [driftMin]〜[driftMax] で止まる。内へ戻る変化は止めない
  /// （生まれつき極端な選手が、経験で真ん中に寄るのは自然なこと）。
  Personality bump(PersonalityAxis axis, int delta) {
    int c(int v) {
      final was = this[axis];
      if (delta > 0 && v > driftMax) return was > driftMax ? was : driftMax;
      if (delta < 0 && v < driftMin) return was < driftMin ? was : driftMin;
      return v.clamp(min, max);
    }

    return Personality(
      confidence: c(
        confidence + (axis == PersonalityAxis.confidence ? delta : 0),
      ),
      ambition: c(ambition + (axis == PersonalityAxis.ambition ? delta : 0)),
      professionalism: c(
        professionalism + (axis == PersonalityAxis.professionalism ? delta : 0),
      ),
      temper: c(temper + (axis == PersonalityAxis.temper ? delta : 0)),
      origin: origin ?? withOrigin(null),
    );
  }

  /// 自信が試合の成功率に与える増減。
  ///
  /// 平均（10）で 0。極端でも ±3% 程度に収める。性格で試合が決まると
  /// 能力を伸ばす意味が薄れる。
  double get chanceModifier => (confidence - 10) * 0.003;

  /// プロ意識が練習の効果に与える倍率。
  ///
  /// 天井に張り付いていた頃、この式は**全員に 1.30 を返していた**
  /// （プロ意識 20）。バランスはその値で取れているので、中心はそのままに、
  /// 傾きだけ立てる。実測の平均 12.8 で 1.30、生まれ持った幅 5〜16 で
  /// 0.91〜1.46——ここで初めて、性格が選手の伸びを変える。
  double get trainingFactor => 0.66 + professionalism * 0.05;

  /// プロ意識が衰えの遅さに与える年数。
  int get declineAgeOffset => professionalism >= 16
      ? 2
      : professionalism >= 12
      ? 1
      : professionalism <= 6
      ? -1
      : 0;

  /// 気性が交渉の通りやすさに与える増減。
  double get negotiationModifier => (temper - 10) * 0.012;

  /// 一言で表す。画面に出す用。
  String get label {
    final entries = <PersonalityAxis, int>{
      PersonalityAxis.confidence: confidence,
      PersonalityAxis.ambition: ambition,
      PersonalityAxis.professionalism: professionalism,
      PersonalityAxis.temper: temper,
    };
    final top = entries.entries.reduce((a, b) => a.value >= b.value ? a : b);
    if (top.value <= 12) return 'つかみどころがない';
    return switch (top.key) {
      PersonalityAxis.confidence => '自信家',
      PersonalityAxis.ambition => '野心家',
      PersonalityAxis.professionalism => '求道者',
      PersonalityAxis.temper => '激情家',
    };
  }

  Map<String, dynamic> toJson() => {
    'confidence': confidence,
    'ambition': ambition,
    'professionalism': professionalism,
    if (origin != null) 'origin': origin!.toJson(),
    'temper': temper,
  };

  factory Personality.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      // 性格を持たせる前の保存データは、すべて平均で読む。
      return const Personality(
        confidence: 10,
        ambition: 10,
        professionalism: 10,
        temper: 10,
      );
    }
    return Personality(
      confidence: json['confidence'] as int? ?? 10,
      ambition: json['ambition'] as int? ?? 10,
      professionalism: json['professionalism'] as int? ?? 10,
      // 知らない保存データは「今の値が生まれ持った値」として読む。
      // ここで 10 に寄せると、続きを読み込んだ選手の性格が跳ねる。
      origin: json['origin'] is Map
          ? Personality.fromJson(
              (json['origin'] as Map).cast<String, dynamic>(),
            )
          : null,
      temper: json['temper'] as int? ?? 10,
    );
  }
}
