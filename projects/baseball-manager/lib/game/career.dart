/// キャリアの段階。年齢で決まる。
enum Stage { youth, juniorHigh, highSchool, pathChoice, pro, retired }

const int startAge = 6;
const int proEntryAge = 18; // 高校卒業でプロ志望届を出せる
const int maxProAge = 45; // これを超えたら強制引退

/// 段階の判定はここ1か所。`retired` は引退を決めた後に呼び出し側が立てる。
Stage stageOf(int age, {bool turnedPro = false}) {
  if (age < 13) return Stage.youth;
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
  if (age < 25) return 1.0;
  if (age < 30) return 0.5;
  if (age < 34) return -0.2;
  return -0.8;
}
