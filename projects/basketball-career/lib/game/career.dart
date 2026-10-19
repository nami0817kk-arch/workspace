/// キャリアの段階。年齢で決まる。
enum Stage { minibasket, juniorHigh, highSchool, college, pathChoice, pro, retired }

const int startAge = 6;
const int maxProAge = 40; // これを超えたら強制引退

/// 段階の判定はここ1か所。`retired` は引退を決めた後に呼び出し側が立てる。
Stage stageOf(int age, {bool turnedPro = false}) {
  if (age < 13) return Stage.minibasket;
  if (age < 16) return Stage.juniorHigh;
  if (age < 19) return Stage.highSchool;
  if (turnedPro) return age > maxProAge ? Stage.retired : Stage.pro;
  return Stage.pathChoice;
}

/// その年の伸びやすさ(1.0 が基準)。少年期は大きく伸び、30代で下降する。
double growthFactor(int age) {
  if (age < 13) return 1.6;
  if (age < 16) return 1.4;
  if (age < 19) return 1.2;
  if (age < 24) return 1.0;
  if (age < 28) return 0.4;
  if (age < 31) return -0.2;
  return -0.8;
}

/// 1年の身長の伸び(cm)の目安。成長期(10〜17歳)に集中し、20歳でほぼ止まる。
/// `genes` は 0〜1 の素質(1 で最終身長が大きい)。
double heightGrowthPerYear(int age, double genes) {
  final base = switch (age) {
    < 10 => 5.5,
    < 13 => 6.5,
    < 15 => 7.5,
    < 17 => 4.5,
    < 19 => 1.8,
    < 21 => 0.6,
    _ => 0.0,
  };
  return base * (0.8 + genes * 0.4);
}
