/// 投資。プロの年俸を、練習環境・体のケアに使う。レベルが上がるほど効果が大きい。
/// 金額は万円。
enum Invest {
  trainer('専属トレーナー', '練習の伸びが大きくなる(1レベルごとに+6%)。'),
  dietitian('栄養士・リカバリー設備', '休養で疲れがよく抜ける(1レベルごとに+20%)。'),
  medical('医療チーム', '怪我をしにくくなる(1レベルごとに2割減)。');

  const Invest(this.label, this.description);
  final String label;
  final String description;

  static Invest? parse(String? s) {
    for (final i in Invest.values) {
      if (i.name == s) return i;
    }
    return null;
  }
}

const maxInvestLevel = 3;

/// 次のレベルに上げる費用(万円)。`level` は今のレベル(0〜2)。
const investCosts = [2000, 6000, 15000];

/// 次のレベルの費用。最大なら null。
int? investCost(int level) =>
    level >= maxInvestLevel ? null : investCosts[level];

/// 練習の伸びにかかる倍率。
double trainerMultiplier(int level) => 1.0 + 0.06 * level;

/// 休養で疲れが抜ける量にかかる倍率。
double dietitianMultiplier(int level) => 1.0 + 0.20 * level;

/// 怪我の起きやすさにかかる倍率。
double medicalFactor(int level) {
  var f = 1.0;
  for (var i = 0; i < level; i++) {
    f *= 0.8;
  }
  return f;
}

/// 資産の表記(万円): 「3500万円」「1億2000万円」。
String fmtMoney(int man) {
  if (man <= 0) return '0円';
  final oku = man ~/ 10000;
  final rest = man % 10000;
  if (oku == 0) return '$rest万円';
  return rest == 0 ? '$oku億円' : '$oku億$rest万円';
}
