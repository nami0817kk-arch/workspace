// 夢: 始めるときに決める、一生をかけた目標。
// 年の目標(1年ごと)と違い、引退までの長い目標。進み具合が育成画面に出続け、
// かなうと節目で祝い、エンディングで語る。固有名詞は使わない。

/// 夢の判定に使う数字(Game から渡す。Game を参照しないので循環しない)。
class DreamStats {
  const DreamStats({
    required this.turnedPro,
    required this.points,
    required this.titles,
    required this.honors,
    required this.caps,
  });

  final bool turnedPro;
  final int points;
  final int titles;
  final int honors;
  final int caps;
}

enum Dream {
  pro('プロの舞台へ', 'プロ契約を勝ち取る', 1),
  scorer('エースの証', '通算1,500得点', 1500),
  champion('勝ち続けるチーム', '大会で通算2回優勝する', 2),
  honors('名を残す', '個人タイトル・表彰を通算3つ', 3),
  national('日の丸を背負う', '日本代表に招集され、世界の舞台に立つ', 1);

  const Dream(this.label, this.goalText, this.target);
  final String label;
  final String goalText;
  final int target;

  /// いまの数字(目標を超えても目標値で止める)。
  int current(DreamStats s) => switch (this) {
        Dream.pro => s.turnedPro ? 1 : 0,
        Dream.scorer => s.points,
        Dream.champion => s.titles,
        Dream.honors => s.honors,
        Dream.national => s.caps,
      }
          .clamp(0, target);

  double progress(DreamStats s) => current(s) / target;

  bool achieved(DreamStats s) => current(s) >= target;

  /// 画面に出す進み具合。
  String progressText(DreamStats s) => switch (this) {
        Dream.pro => s.turnedPro ? '契約済み' : 'これから',
        Dream.scorer => '${current(s)} / $target 得点',
        Dream.champion => '${current(s)} / $target 回',
        Dream.honors => '${current(s)} / $target 個',
        Dream.national => s.caps >= 1 ? '招集された' : 'これから',
      };

  /// かなったときのごほうび(全能力 +1 と気持ち)。
  static const rewardAbilityBonus = 1;
  static const rewardMorale = 20;

  static Dream parse(String? s) =>
      Dream.values.firstWhere((d) => d.name == s, orElse: () => Dream.pro);
}

/// エンディングの1文。かなった年齢があれば添える。
String dreamLine(Dream d, {required int achievedAge}) {
  if (achievedAge > 0) {
    return '幼い日に描いた夢「${d.label}」は、$achievedAge歳でかなった。';
  }
  return '幼い日に描いた夢「${d.label}」には届かなかった。それでも、追い続けた日々が自分をここまで連れてきた。';
}
