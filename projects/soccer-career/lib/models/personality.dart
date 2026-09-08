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
    required this.temper,
  });

  final int confidence;
  final int ambition;
  final int professionalism;
  final int temper;

  static const int min = 1;
  static const int max = 20;

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

  Personality bump(PersonalityAxis axis, int delta) {
    int c(int v) => v.clamp(min, max);
    return Personality(
      confidence:
          c(confidence + (axis == PersonalityAxis.confidence ? delta : 0)),
      ambition: c(ambition + (axis == PersonalityAxis.ambition ? delta : 0)),
      professionalism: c(professionalism +
          (axis == PersonalityAxis.professionalism ? delta : 0)),
      temper: c(temper + (axis == PersonalityAxis.temper ? delta : 0)),
    );
  }

  /// 自信が試合の成功率に与える増減。
  ///
  /// 平均（10）で 0。極端でも ±3% 程度に収める。性格で試合が決まると
  /// 能力を伸ばす意味が薄れる。
  double get chanceModifier => (confidence - 10) * 0.003;

  /// プロ意識が練習の効果に与える倍率。
  double get trainingFactor => 0.7 + professionalism * 0.03;

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
    final top =
        entries.entries.reduce((a, b) => a.value >= b.value ? a : b);
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
        'temper': temper,
      };

  factory Personality.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      // 性格を持たせる前の保存データは、すべて平均で読む。
      return const Personality(
          confidence: 10, ambition: 10, professionalism: 10, temper: 10);
    }
    return Personality(
      confidence: json['confidence'] as int? ?? 10,
      ambition: json['ambition'] as int? ?? 10,
      professionalism: json['professionalism'] as int? ?? 10,
      temper: json['temper'] as int? ?? 10,
    );
  }
}
