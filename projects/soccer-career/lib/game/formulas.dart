import '../models/attributes.dart';

/// ゲームの数値定義を1か所に集めたもの。
///
/// バランス調整はここだけを触る。各所に散らすと、1つ変えたときに
/// 何が連動して壊れるのかが追えなくなる。
class Formulas {
  const Formulas._();

  /// 1シーズンの試合数（20クラブの2回戦総当たり）。
  static const int matchesPerSeason = 38;

  /// リーグのクラブ数。
  static const int clubsPerLeague = 20;

  /// 1試合で提示する局面の数。全38試合に介入する設計なので、
  /// 1試合を短く保たないとシーズンが終わらない。
  static const int scenariosPerStart = 3;

  /// 途中出場のときの局面数。出場時間が短い分だけ見せ場も減る。
  static const int scenariosPerSub = 2;

  /// 評価点の基準値と上下限。サッカー専門誌の採点に合わせて 4.0〜10.0。
  static const double baseRating = 6.0;
  static const double minRating = 4.0;
  static const double maxRating = 10.0;

  /// 決定機を作ったあと、実際に決まる確率。
  ///
  /// 「良い判断ができた」ことと「点が入った」ことを分けている。
  /// 分けないと、3つの局面すべてで強気に行くだけで1試合1.5点になり、
  /// 通算600ゴールのような数字が出る。枠に飛んでも止められるのが
  /// サッカーで、そこが分かれているほうが1点の重みも出る。
  static const double goalConversion = 0.5;
  /// アシストは「この後に味方が決める予定」があるときだけ決まる（スコアに
  /// 乗せるため）。予定が無いときは決まらないので、そのぶん高めにしてある。
  /// 予定が無くても点を足す形にすると、自分のクラブだけ点が増えて
  /// リーグ優勝が3倍に膨らんだ（3743シーズンで 244回 → 842回）。
  static const double assistConversion = 1.0;

  /// 終盤とみなす時間。ここからの1点は重い。
  static const int lateGameMinute = 75;

  /// 展開に合わせた局面に差し替える時間。
  ///
  /// これより後の局面は、勝っていれば守り切る局面、負けていれば
  /// 追いかける局面に入れ替える。全部を状況で決めると試合が
  /// 型どおりになるので、差し替わるのは終盤の1つだけになるよう
  /// 遅めに置いてある。
  static const int situationalMinute = 70;

  /// 2点差以上を追う展開は、もう少し早くから勝負に出る。
  static const int bigDeficitMinute = 58;

  /// 追いついた・突き放した得点の評価点の倍率。
  static const double decisiveGoalFactor = 1.4;

  /// 味方が決める得点の量。自分の得点を上乗せするので、その分を差し引く。
  ///
  /// 差し引く量はポジションで変える。一律にすると、点を取らない選手の
  /// チームだけが弱くなり、GK や CB のクラブが勝てなくなる。
  static double teammateGoalShareFor(ScenarioFamily family) =>
      switch (family) {
        ScenarioFamily.forward => 0.65,
        ScenarioFamily.midfield => 0.85,
        ScenarioFamily.defence || ScenarioFamily.goalkeeper => 1.0,
      };

  /// 局面の成否が評価点に与える増減。
  ///
  /// 成功のほうを小さく、失敗のほうを大きくしてある。ここが逆だと、
  /// 手が通るようになった選手の評価点が青天井に上がり、
  /// キャリア平均7.5のような数字になる（実際になっていた）。
  static const double ratingPerSuccess = 0.32;
  static const double ratingPerFailure = -0.4;
  static const double ratingPerGoal = 0.95;
  static const double ratingPerAssist = 1.1;

  /// 決定機を作ったぶん。ゴール・アシストの手が通れば、決まらなくても付く。
  ///
  /// これが無いと、枠内シュートを GK に止められた手と、無難な横パスが
  /// 同じ +0.32 になり、攻撃の選手だけ評価点が 6.8〜6.9 に沈んでいた
  /// （守備の選手には無失点の項があるのに、攻撃の選手には得点しか無かった）。
  static const double ratingPerChance = 0.08;

  /// 守る側の評価。失点の少なさがそのまま点数になる。
  ///
  /// 得点とアシストしか評価点に乗らなかった頃は、GK のキャリア平均が
  /// 6.39、ストライカーが7.33 だった。評価点は移籍・代表・出場機会の
  /// すべての入口なので、この差はそのまま「GK は上に行けない」になる。
  /// 無失点は守備者にとってのゴールとして扱う。
  static const double cleanSheetBase = 2.4;
  static const double cleanSheetSlope = 0.42;
  static const double cleanSheetMin = -0.6;
  static const double cleanSheetMax = 1.0;

  /// 能力値の下限・上限。
  static const int minAttribute = 1;
  static const int maxAttribute = 99;

  /// 「超越」の特性が、1つの詳細能力の上限をどれだけ持ち上げるか。
  ///
  /// 上限を超えた値は保存にも乗るので、読むときの丸めは [absoluteMax] で行う。
  static const int ceilingBreak = 10;
  static const int absoluteMax = maxAttribute + ceilingBreak;

  /// ポテンシャルに達したあとも超越の能力が伸び続けるには、ここまで
  /// 来ている必要がある。誰でも無条件に伸び続けると、ポテンシャルの
  /// 意味が4人に1人で消える（実測で代表経験が 57%→64% に膨らんだ）。
  static const int transcendRunway = maxAttribute - ceilingBreak;

  /// GK 以外の選手の GK 能力。保存データに無いときの既定値でもある。
  static const int defaultGoalkeeping = 25;

  /// ポテンシャル（総合力の上限）の範囲。
  static const int potentialMin = 62;
  static const int potentialMax = 94;

  /// 成長判定のしきい値。この評価点を超えた試合だけ伸びる可能性がある。
  static const double growthRatingThreshold = 6.5;

  /// 成長のピーク年齢。これを過ぎると伸びにくくなり、衰え始める。
  static const int peakAge = 27;
  static const int declineAge = 31;

  /// 年齢ごとの伸びやすさ。
  ///
  /// 一律だと、10代でも30代でも同じ速さで伸びる。100シーズン回すと
  /// 25歳で総合力63、引退時でもポテンシャルに届かない選手ばかりになり、
  /// 「若いうちに伸ばす」という判断そのものが無くなっていた。
  static double growthByAge(int age) {
    if (age <= 18) return 2.6;
    if (age <= 21) return 2.2;
    if (age <= 24) return 1.6;
    if (age <= peakAge) return 1.0;
    if (age <= 30) return 0.5;
    return 0.25;
  }

  /// 成長を割り戻すときの基準の重み。
  ///
  /// だいたいのポジションで、1カテゴリが総合力に占める割合。
  /// これより集中しているポジション（GK）は伸びを抑え、
  /// 分散しているポジション（CM）は少し上げて、体感を揃える。
  static const double growthShareBaseline = 0.26;

  /// 割り戻しの上下限。ここを外すと、極端なポジションで成長が壊れる。
  static const double growthShareMin = 0.45;
  static const double growthShareMax = 1.3;

  /// ポジションの重みから、成長の倍率を出す。
  static double growthShareFactor(double share) => share <= 0
      ? 1.0
      : (growthShareBaseline / share).clamp(growthShareMin, growthShareMax);

  /// この年齢までは、1回の成長で2つぶん伸びる。
  ///
  /// 確率を上げるだけでは足りず、かといって確率を1に張り付かせると
  /// 練習の選択が意味を失う。若いうちだけ「伸び方が違う」形にする。
  static const int rapidGrowthAge = 21;

  /// 出場評価。直近の平均評価点がこれ未満だと先発から外れる。
  static const double benchThreshold = 6.2;

  /// これ未満だと招集外（ベンチにも入れない）。
  static const double squadThreshold = 5.6;

  /// 直近何試合の評価点で出場可否を判断するか。
  static const int formWindow = 5;

  /// 何試合外れ続けたら、まず途中出場で戻すか。
  ///
  /// 外れた試合には評価点が付かないので、これが無いと窓の中身が
  /// 一生変わらず、一度ベンチに落ちた選手が永久に出られなくなる。
  static const int benchPatience = 3;

  /// 外れている1試合ごとに、評価が甘く見られる量。
  /// 監督の記憶が薄れ、練習での様子が効いてくるぶん。
  static const double benchRecoveryPerMatch = 0.12;

  /// その上限。ここを外すと、干され続けるほど有利になる。
  static const double benchRecoveryMax = 0.7;

  /// 好調でも休まされることがある確率の下限。
  ///
  /// 毎試合フル出場では連戦の重みが出ず、「途中出場」という状態が
  /// ほとんど現れない。疲れているほど休まされやすくする。
  /// 100シーズン回して決めた値。0.04 + 傾き大では、先発が7割を切って
  /// 「たまに先発する選手」になっていた。主力の実感は8割の先発から。
  static const double rotationBase = 0.03;
  static const double rotationPerCondition = 0.003;
  static const double rotationPerFatigue = 0.001;
  static const double rotationMax = 0.22;

  /// 勝点。
  static const int pointsWin = 3;
  static const int pointsDraw = 1;

  /// 移籍オファーが届く最低シーズン平均評価点。
  static const double transferOfferRating = 6.7;

  /// 相手の強さが成功率に与える傾き。
  ///
  /// これが無いと、3部でも1部でも同じ手が同じ確率で通り、
  /// 上のリーグへ移る意味が「年俸が上がる」だけになる。
  static const int opponentBaseline = 60;
  static const double opponentChanceSlope = 0.004;

  /// 選手の総合力と評価点から、移籍先クラブの強さの上限を決める係数。
  static const double transferReachFactor = 1.08;

  /// 2部でこの順位以内なら昇格。
  static const int promotionPlaces = 2;

  /// 1部でこの順位以下なら降格（20クラブ中）。
  static const int relegationFrom = 18;

  /// 昇格・降格したクラブの強さの補正。同じクラブでも上のリーグでは相対的に弱い。
  static const int promotionStrengthBonus = 6;

  /// この年齢から、古巣が「最後の1年」に呼ぶことがある。
  static const int lastDanceAge = 31;

  /// この年齢からシーズン終了時に引退を選べる。
  static const int retirementOptionalAge = 33;

  /// この年齢でシーズンを終えたら引退する。
  static const int retirementForcedAge = 37;

  /// 成長判定で、その試合に成功した手の能力が選ばれる確率。
  /// 残りは無作為。プレースタイルが選手を形作るが、偏りすぎない。
  static const double growthFocusChance = 0.7;

  /// コンディション（0〜100）。
  static const int conditionMax = 100;

  /// 1試合で消耗するコンディション。
  static const int matchConditionCost = 12;

  /// 休養（完全オフ）で抜ける累積疲労。リカバリーでは抜けない。
  ///
  /// 無いと、休養はリカバリー（戻りが大きく怪我も減る）の下位互換だった。
  /// コンディションを戻すならリカバリー、溜まった疲労を抜くなら休養、と分ける。
  static const int restFatigueRelief = 3;

  /// 練習で消耗するコンディション。
  static const int trainingConditionCost = 10;

  /// 休養で回復するコンディション。
  static const int restRecovery = 30;

  /// コンディションが成功率に効く傾き。基準値からの差 × 傾き。
  /// 100 なら +6%、20 なら −6%。疲れたまま練習し続けると試合で払う。
  static const int conditionBaseline = 60;
  static const double conditionChanceSlope = 0.0015;

  /// 練習で能力が1伸びる確率（ポテンシャルに達していなければ）。
  static const double trainingGrowthChance = 0.3;

  /// 居残り練習で余分に減るコンディション。
  static const int drillConditionCost = 6;

  /// 居残り練習でセットプレーの精度が1上がる確率（上に行くほど鈍る）。
  static const double drillGrowthChance = 0.55;

  /// キッカーを任されている選手に、1試合でセットプレーの好機が回る確率。
  static const double deadBallChanceStart = 0.22;
  static const double deadBallChanceSub = 0.09;

  /// 1試合のうち、逆足で対応することになる局面の割合。
  ///
  /// 中央の役割はこの値。サイドに立つ選手は、利き足と同じ側なら
  /// 外を向いたまま蹴れるので減り、逆サイドなら増える。
  static const double weakFootMomentChance = 0.25;
  static const double weakFootMomentOnSide = 0.16;
  static const double weakFootMomentInverted = 0.38;

  /// 逆サイドに立つ選手が、内へ切り込んで利き足で打てるぶんの上乗せ。
  ///
  /// 逆足の局面が増えるだけだと、逆サイドはただの罰になる。
  /// 実際のサッカーで逆足のウイングが置かれる理由をそのまま効かせる。
  static const double invertedShootingBonus = 0.04;

  /// 逆足練習で精度が1段上がる確率。反復するしかない。
  static const double weakFootGrowthChance = 0.12;

  /// 個人技を覚える確率（条件を満たした週）。
  static const double signatureChance = 0.06;

  /// 停滞期のあいだ、成長の確率に掛かる倍率。
  static const double plateauGrowthFactor = 0.25;

  /// 限界突破が起きる確率と、上がるポテンシャル。
  static const double breakthroughChance = 0.25;
  static const int breakthroughGain = 3;

  /// 上乗せ要求が通る確率 = 基本 + 交渉力 × 係数 + 成績の補正。
  static const double negotiationBase = 0.25;
  static const double negotiationPerSkill = 0.09;

  /// 上乗せの倍率。
  static const double negotiationRaise = 1.2;

  /// 上乗せに失敗したとき、オファーが撤回される確率。
  static const double withdrawChanceOnFail = 0.5;

  /// 警告が溜まって出場停止になる枚数。
  ///
  /// 実際のリーグと同じで、シーズンをまたぐと消える。
  static const int yellowCardsForBan = 5;

  /// 累積警告での出場停止の試合数。
  static const int banForYellows = 1;

  /// 退場での出場停止の試合数。
  static const int banForRedCard = 2;

  /// 荒い手が失敗したときに、カードが出る確率の基準。
  ///
  /// 選択肢ごとの `foul` に掛かる。気性が荒いほど上がる。
  static const double cardChanceBase = 1.0;

  /// 気性（10が普通）がカードの出やすさに効く傾き。
  static const double cardPerTemper = 0.05;

  /// 失点を1つ止めたときの評価点。守備の選手ほど、無失点が効く。
  ///
  /// 自動で進めるときに、止めるための反則を「安いだけの手」とも
  /// 「損なだけの手」とも見ないようにするための重み。
  static const double ratingPerGoalPrevented = 0.6;

  /// 警告を受けた試合の評価点への響き。退場はその倍。
  static const double ratingPerYellow = -0.35;
  static const double ratingPerRedCard = -1.2;

  /// 1試合あたりの負傷確率の基準。コンディションと年齢で増減する。
  ///
  /// 100シーズン回して決めた値。0.045 だと1シーズンに2.7回離脱し、
  /// 38節のうち14節を棒に振っていた。実際の選手は年1〜2回で、
  /// 休むのは5〜8試合ぶん。
  static const double injuryBaseChance = 0.011;

  /// 練習1回あたりの負傷確率。試合より低いが、疲れていると効いてくる。
  static const double injuryTrainingChance = 0.008;

  /// 重傷になる確率。能力とポテンシャルを恒久的に削るので、稀に保つ。
  static const double severeInjuryShare = 0.05;

  /// コンディションが基準を下回るほど怪我しやすくなる傾き。
  static const double injuryConditionSlope = 0.0009;

  /// この年齢を超えると、1歳ごとに怪我しやすくなる。
  static const int injuryAgeFrom = 29;
  static const double injuryPerAgeYear = 0.004;

  /// 重傷で落ちる能力値とポテンシャル。
  static const int severeInjuryAttributeLoss = 3;
  static const int severeInjuryPotentialLoss = 2;

  /// 復帰直後のコンディション。
  static const int conditionAfterInjury = 45;

  /// キャプテンの試合ごとの評価点への上乗せ。
  static const double captainRatingBonus = 0.1;

  /// 復帰してから、再発の危険が高い試合数。
  static const int rehabWatchMatches = 3;

  /// 代表に招集される最低総合力。
  ///
  /// 72 だと、普通に育てた選手のほぼ全員（94%）が代表に入っていた。
  /// 代表は「選ばれること自体が到達点」なので、ここは上位だけに保つ。
  static const int callUpOverall = 77;

  /// 代表に招集される最低の直近平均評価点。
  static const double callUpRating = 6.9;

  /// 代表戦の前に必要な出場試合数（実績が無いと選ばれない）。
  static const int callUpMinAppearances = 5;

  /// この年齢以下で始めると、育成年代（一番下の部）から始まる。
  static const int youthAge = 17;

  /// ローンに出せる上限の年齢。伸びしろへの投資なので、若手だけ。
  static const int loanMaxAge = 23;

  /// この先発回数に届かない若手には、ローンの話が来る。
  ///
  /// 「出場が少ない」で見ていた頃は、途中出場でも数だけは並ぶので、
  /// ベンチ要員がローンの対象から外れていた。見るべきは先発の数。
  static const int loanStartsThreshold = 12;

  /// 契約年数の範囲。
  static const int contractYearsMin = 2;
  static const int contractYearsMax = 4;

  /// 登録メンバーに入るのに必要な、クラブの強さとの差。
  /// これより大きく劣ると25人枠に入れない。
  static const int squadRegistrationGap = -8;

  /// 大陸カップに出た年の年俸倍率。
  static const double continentalSalaryBonus = 1.1;

  /// 目標を達成したときの年俸倍率。達成できなかったときの倍率。
  static const double objectiveMetSalaryFactor = 1.15;
  static const double objectiveMissedSalaryFactor = 0.9;
}
