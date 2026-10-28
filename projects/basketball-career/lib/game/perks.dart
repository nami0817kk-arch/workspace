// 季節のターンを使わずにできること: 人に頼る(`Favor`)と、お金を使う(`Spend`)。
//
// 頼るのは、コーチとの信頼・チームワーク・ライバルとの縁を「使う」操作。信頼やチームワークを減らす代わりに、
// 熟練度や伸び・気持ち・進路の評価が上がる。頼みごとは1ターンに1つまで。
// お金はプロの年俸とスポンサー収入(季節ごとに4分の1ずつ入る)から払う。広告で回復する「回復」と同じ効き目の
// 買い物は置かない(広告の価値を下げないため)。

/// 頼みごと。文中の {mate} {coach} {rival} は `Game.fill` で名前にする。
enum Favor {
  lesson('{coach}に個別指導を頼む', 'コーチとの信頼 -10', '第1重点の熟練度 +2。次のターンの伸びが1.2倍。'),
  extra('{mate}と居残り練習', 'チームワーク -15', '第1重点の熟練度 +2。気持ち +5、疲れ +5。'),
  talk('{mate}に悩みを相談する', 'チームワーク -5', '気持ち +15。'),
  rival('{rival}と合同練習', '1年に1回。ライバルも少し伸びる', '第1重点の熟練度 +2。気持ち +10。'),
  letter('{coach}に推薦状を頼む', 'コーチとの信頼 -20', '次の進路で、プロの評価点 +3。');

  const Favor(this.label, this.cost, this.effect);
  final String label;
  final String cost;
  final String effect;
}

/// 頼みごとに要るコーチとの信頼・チームワーク。
const lessonBond = 30;
const lessonCost = 10;
const extraTeamwork = 50;
const extraCost = 15;
const talkTeamwork = 30;
const talkCost = 5;
const letterBond = 45;
const letterCost = 20;

/// 個別指導の次のターンの伸びの倍率と、推薦状で足す実績(評価点では 0.3 倍で +3)。
const lessonGrowth = 1.2;
const letterAchievement = 10.0;

/// 買える回数の決まり。
enum SpendLimit { term, year, active, life }

/// お金の使い道。金額は万円。
enum Spend {
  treat('{mate}たちに食事をおごる', 50, 'チームワーク +15。', SpendLimit.term),
  gear('{coach}に分析機材を贈る', 300, 'コーチとの信頼 +15。', SpendLimit.year),
  trainer('個人トレーナーを雇う', 600, 'これから4ターン、伸びが1.1倍。', SpendLimit.active),
  nutrition('栄養士と契約する', 400, 'これから4ターン、衰えが2割減り、怪我をしにくい。', SpendLimit.active),
  camp('海外キャンプに参加する', 1000, '第1重点の熟練度 +3。疲れ +15。', SpendLimit.year),
  parents('両親に家を贈る', 5000, '気持ち +30。一生に1度。', SpendLimit.life),
  court('地元にバスケコートを寄付する', 10000, '人気が上がり、来年からスポンサー契約が増える。一生に1度。', SpendLimit.life);

  const Spend(this.label, this.price, this.effect, this.limit);
  final String label;
  final int price;
  final String effect;
  final SpendLimit limit;
}

/// 雇う・契約するものが効くターン数。
const perkTerms = 4;
const trainerGrowth = 1.1;
const nutritionDecline = 0.8;
const nutritionInjury = 0.7;
