// 特殊能力: 育てながら貯めた「特殊能力ポイント(SP)」で、自分で選んで習得する能力。
// 特性(生まれつき・出来事で身につく)や得意技(条件を満たすと自然に身につく)と違い、
// 何を習得するか・どの順で取るかをプレーヤーが決める(前提のある能力もある)。固有名詞は使わない。
//
// 効き方はこのファイルの関数に集める(他のファイルは能力の名前を直接見ない)。

enum SpecialKind { passive, active }

enum Special {
  calm('冷静沈着', '勝負どころの成功率 +3%。', 3),
  clutchMaster('クラッチの申し子', '勝負どころの成功率 +4%。', 7, requires: Special.calm),
  zone('ゾーン', '大会ごとに1回、勝負どころで使うと成功率 +12%。', 7,
      requires: Special.calm, kind: SpecialKind.active),
  ironWall('鉄壁の守り', 'ファウルが25%減る。', 3),
  fireSpirit('熱血', '連勝・連敗の勢いの効きが1.5倍。', 3),
  allSeeing('万能の目', 'ハーフタイムの作戦と相手の相性が、1.3倍効く。', 5),
  prodigy('努力の天才', '練習での伸びが +5%(伸びる年だけ)。', 6),
  resilience('不屈', '休養・交流での疲れの回復が +25%。', 3),
  gameMaker('ゲームメイカー', '大会の味方の強さ +0.7。', 5),
  moodMaker('ムードメーカー', 'チームワークが薄れる速さが半分になる。', 3);

  const Special(this.label, this.description, this.cost,
      {this.requires, this.kind = SpecialKind.passive});

  final String label;
  final String description;

  /// 習得に要る特殊能力ポイント。
  final int cost;

  /// 先に習得しておく必要がある能力。
  final Special? requires;
  final SpecialKind kind;

  static Special? parse(String? s) {
    for (final v in values) {
      if (v.name == s) return v;
    }
    return null;
  }
}

/// 習得できるか(ポイントが足り、前提の能力があり、まだ持っていない)。
bool canLearn(Set<Special> have, int sp, Special s) =>
    !have.contains(s) &&
    sp >= s.cost &&
    (s.requires == null || have.contains(s.requires));

/// 習得できない理由(できるなら null)。画面に出す。
String? whyNot(Set<Special> have, int sp, Special s) {
  if (have.contains(s)) return '習得済み';
  if (s.requires != null && !have.contains(s.requires)) {
    return '先に「${s.requires!.label}」が要る';
  }
  if (sp < s.cost) return 'ポイントが足りない(あと${s.cost - sp})';
  return null;
}

/// 勝負どころの成功率への加算(0〜1の確率)。ゾーンは `zone` で使ったときだけ別に足す。
double specialClutchBonus(Set<Special> s) =>
    (s.contains(Special.calm) ? 0.03 : 0.0) +
    (s.contains(Special.clutchMaster) ? 0.04 : 0.0);

/// ゾーンを使ったときの勝負どころの加算。
const zoneBonus = 0.12;

/// ファウルの数の倍率。
double specialFoulMultiplier(Set<Special> s) =>
    s.contains(Special.ironWall) ? 0.75 : 1.0;

/// 勢い(連勝・連敗)の効きの倍率。
double specialMomentumMultiplier(Set<Special> s) =>
    s.contains(Special.fireSpirit) ? 1.5 : 1.0;

/// ハーフタイムの相性の効きの倍率。
double specialFitMultiplier(Set<Special> s) =>
    s.contains(Special.allSeeing) ? 1.3 : 1.0;

/// 練習での伸びの倍率(伸びる年だけ)。
double specialGrowthMultiplier(Set<Special> s) =>
    s.contains(Special.prodigy) ? 1.05 : 1.0;

/// 疲れの回復(マイナスの疲労変化)の倍率。
double specialRecoveryMultiplier(Set<Special> s) =>
    s.contains(Special.resilience) ? 1.25 : 1.0;

/// 大会の味方の強さへの加算。
double specialTeamBonus(Set<Special> s) =>
    s.contains(Special.gameMaker) ? 0.7 : 0.0;

/// チームワークが毎ターン薄れる量(特性のキャプテンシーとは重ねず、小さいほうを取る)。
int specialTeamworkDecay(Set<Special> s, int base) =>
    s.contains(Special.moodMaker) ? (base / 2).ceil().clamp(0, base) : base;

/// 年末に得られる特殊能力ポイント: 毎年1、目標達成+1、優勝+1。夢がかなったときは別に+2。
int spForYear({required bool goalAchieved, required bool champion}) =>
    1 + (goalAchieved ? 1 : 0) + (champion ? 1 : 0);

const dreamSp = 2;

/// 習得の優先順(おまかせ・測定ツール用)。安くて広く効くものから。
const learnPriority = [
  Special.calm,
  Special.prodigy,
  Special.ironWall,
  Special.clutchMaster,
  Special.resilience,
  Special.gameMaker,
  Special.allSeeing,
  Special.fireSpirit,
  Special.moodMaker,
  Special.zone,
];
