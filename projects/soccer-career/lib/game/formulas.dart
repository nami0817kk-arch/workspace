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

  /// 1試合で提示する局面の数。
  ///
  /// **38試合すべてを同じ濃さでプレイする前提をやめた**（2026-09-11）。
  /// 全部を等しく3局面にすると、1試合が「3回タップして終わり」の薄さに
  /// 固定される。実測（`matters_sim`）で、**2手で終わる試合では
  /// 「積んで使う」手筋が成立しない**ことが分かっていた——
  /// 刻んでから決める型を書いて回したら最下位になった。
  ///
  /// 重い試合だけを厚くして、ふつうの試合は薄くする。
  /// **総量はほぼ変えない**（重い試合は1シーズンに8前後）。
  static const int scenariosPerStart = 2;
  static const int scenariosPerSub = 1;

  /// **一芸**。総合力から、これだけ突き抜けていれば「一芸」と呼ぶ。
  ///
  /// 総合力はポジションの重みで出すので、**尖らせるほど下がる**——
  /// 実測（16キャリア）で、中盤の選手を守備一本で育てるとピーク総合力が
  /// 75.1 → 69.7 に落ちた。つまり**尖った選手を育てること自体が損**で、
  /// 「尖った選手を育てたい」という遊び方が構造的に成立していなかった。
  ///
  /// 突き抜けた1つは、総合力とは別に値札に乗せる。
  static const int standoutGap = 12;

  /// 一芸と呼べる最低ライン（カテゴリの値）。
  /// 70の選手の「一番高いカテゴリが82」は一芸ではない。
  static const int standoutFloor = 88;

  /// 突き抜けた1ごとに、市場価値が何倍になるか。
  static const double standoutValue = 0.02;

  /// **育てた結果、別のポジションのほうが高くなる差**。
  ///
  /// 総合力はポジションの重みで出すので、そのポジションが求めないものを
  /// 伸ばすほど下がる（実測で、中盤の選手を守備一本で育てるとピークが
  /// 75.4 → 69.4）。**それは間違った育て方ではなく、別の選手になったということ。**
  /// 適性のあるポジションでこれだけ高くなるなら、その道を勧める。
  static const int convertGain = 3;

  /// 一芸があると、代表の総合力の線がどれだけ下がるか。
  ///
  /// 「総合力73だが視野99の司令塔」が代表から締め出されるのはおかしい。
  /// 尖らせるほど総合力は下がるので、ここを開けないと
  /// **尖った育成を選んだ時点で代表が消える**（実測で 代表12 → 0キャップ）。
  static const int standoutCallUpRelief = 6;

  /// 一芸が出場機会に履かせる下駄の上限。
  static const double standoutAppearance = 0.12;

  /// これ以上の力の差がある相手との対戦は、じっくりやる試合にする。
  ///
  /// `MatchInProgress.bigMatch`（重圧が掛かる線）は 8 だが、
  /// そこを使うと下位クラブの半分近くが重い試合になってしまう。
  /// **重い試合は1シーズンに8前後**に収める。
  static const int bigFixtureGap = 14;

  /// 終盤、目標や約束に手が届く試合を重くする残り節数。
  static const int bigFixtureRunIn = 4;

  /// 評価点の物差しにする局面数。
  ///
  /// 局面の数が試合の重さで変わるので、**1試合ぶんの重みに割り戻す**。
  /// 割り戻さないと、重い試合に出ただけで評価点が跳ね、薄い試合では下がる。
  /// ここは「重さが入る前の先発の局面数」で、動かすとバランスが全部動く。
  static const int ratingScenarios = 3;

  /// 重い試合（`Fixture.big`）の局面数。ここが密度。
  ///
  /// 6局面あれば「刻んでノリを作り、勝負どころで決める」に5手使える。
  /// 3局面では2手しかなく、積むコストが必ず見返りを上回っていた。
  ///
  /// **総量を増やさない**ように決めてある。重い試合が全体の25%として
  /// 0.25×6 + 0.75×2 = 3.0 ＝ 変更前の1試合3局面と同じ。
  /// 8局面にしたら ST の通算ゴールが 359 → 702 に膨らんだ（実測）。
  static const int scenariosPerBigStart = 6;
  static const int scenariosPerBigSub = 4;

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
  /// ノリが乗ると決定率が最大2倍になるぶん、素の値を下げて釣り合わせる
  /// （2026-09-11）。0.5 のままだと ST の通算ゴールが 291 → 422 に膨らんだ。
  static const double goalConversion = 0.42;

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
  static double teammateGoalShareFor(ScenarioFamily family) => switch (family) {
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

  /// 身体の消耗 0〜100。**最近どう踏み込んできたか**を映す。
  ///
  /// 実測（40キャリア×3条件）で、「流す」に上振れが一つも無かった——
  /// ピーク 73.0/74.7/75.1、平均評価 6.91/6.99/6.99、コツ 3%/88%/98%。
  /// 見返りは怪我が年 0.22回減ることだけで、**リスクを避けたことに
  /// 固有の勝ち筋が無かった**。760回ある週の選択が「追い込む」を
  /// 押し続ける作業になっていた。
  ///
  /// 消耗は累積ではなく、その踏み込み方の落ち着き先へ**寄っていく**。
  /// 累積にすると若い頃の1年で残りが決まってしまい、30歳で流し始めても
  /// 何も起きない。寄せる形にすると「若いうちは追い込み、歳を取ったら流す」
  /// がキャリアの形として成立する。
  /// 「普通」で来た選手が実際に落ち着く値。ここが真ん中で、
  /// 衰え始めも重傷の割合も、ここで増減 0 になる。
  ///
  /// 落ち着き先（50）より低いのは、疲れた週に自動休養が踏み込み方を
  /// 「流す」に落とすため。**書いてある落ち着き先ではなく、実際に着く値**で
  /// 真ん中を取らないと、普通に遊んだ選手に代償が付く。
  static const double strainNeutral = 38;

  /// 週ごとに落ち着き先へ寄る速さ。1シーズン（38週）でほぼ着く。
  static const double strainDrift = 0.045;

  /// **ノリ**。その試合で成功を重ねるほど、決まるようになる。
  ///
  /// 実測（24キャリア）で、中身の違う3つの遊び方が同じ結果になっていた——
  /// 最善 74.9/7.07、安全 74.8/7.06、勝負 74.8/7.06。
  /// **失敗の罰はあるのに、上手くやった見返りが無い。**
  /// しかも期待値に従うと中盤の選手が20年で9ゴールしか取らない
  /// （何も読まずに押した選手のほうが36ゴール取る）。
  ///
  /// 効かせるのは**成功率ではなく決まる確率**。成功率に乗せると
  /// 「安全な手をひたすら積む」がさらに強くなるだけで、また一本道になる。
  /// 決定率に乗せると「刻んでノリを作り、勝負どころで決めにいく」という
  /// 試合の中の段取りが生まれる。
  /// **1試合3局面しかないので、段数は2まで。**
  /// 3段にすると、積むのに2局面使って残り1局面でしか使えない
  /// （実測で「刻んでから決める」型が最下位になった: 評価 6.92 / 代表4キャップ）。
  /// 1局面の成功で乗るようにして、初めて段取りが成立する。
  static const int momentumMax = 2;

  /// ノリ1段ごとに、ゴール・アシストが決まる確率が何倍になるか。
  static const double momentumPerStep = 0.5;

  /// 決定機の手（ゴール・アシスト）で成功したときに上がる段数。
  /// 無難な手は1段。難しい手を通したほうが乗る。
  static const int momentumFromChance = 2;

  /// 相手の戦い方と噛み合わない手の重り。慣れ（`adaptationFor`）で消える。
  static const double styleMismatch = 0.08;

  /// 大一番の重圧。経験（`composure`）と自信で薄まる。
  static const double bigMatchPressure = 0.10;

  /// **切り札**。構えた個人技が、その手に乗る大きさ。
  ///
  /// 個人技は身に付くと**常に少しだけ**効く飾りだった（実測: 1人あたり2.83個、
  /// 局面の70%に乗って平均 +3.1%）。**誰でも3つ揃い、選ぶ余地も、
  /// 使いどころの判断も無い**。積み上げた技が試合を動かした瞬間が無い。
  ///
  /// 1試合に1回だけ「ここで出す」と構えられるようにして、
  /// 受け身の +3% を**使いどころの判断**にする。
  static const double signatureArmedBonus = 0.15;

  /// 構えて外したときの、その試合の残りへの重り。力んだぶん。
  ///
  /// 代償が無いと「乗る局面が来たら必ず構える」が正解になり、
  /// 判断がまた消える。
  static const double signatureMissPenalty = 0.05;

  /// **決定的な仕事**（ゴール・アシスト・守る選手の無失点）が、
  /// 出場機会の判断に足す下駄。
  ///
  /// 平均評価だけがすべての入口だったので、**変動を嫌う＝安全な手が常に正しい**
  /// 形になっていた。点を取る選手が干されない道を、評価点とは別に1本通す。
  static const double decisivePerAct = 0.06;
  static const double decisiveBonusMax = 0.30;

  /// 得点関与だけでも代表に届く線（1試合あたり）。
  ///
  /// 評価点が `callUpRating` に届かなくても、これを超えていれば呼ばれる。
  /// 「6.8だが25ゴール」のシーズンが代表から締め出されるのはおかしい。
  static const double callUpProduction = 0.55;

  /// 引退させた選手が、次のキャリアの監督・メンターとして現れる確率。
  ///
  /// 1.0 にすると毎回同じ顔が出て、世界が自分の過去だけで埋まる。
  /// 0.1 だと20年遊んで一度も会わない。
  static const double legendCastChance = 0.4;

  /// 性格が、その季に落ち着き先へ1歩寄る確率。
  /// 毎季きっちり動くと、同じ立場の選手が同じ速さで同じ値に着く。
  static const double personalitySettleChance = 0.7;

  /// 消耗が衰え始めを動かす境目。
  ///
  /// **落ち着き先（22/50/86）ではなく、実際に着く値で切る。**
  /// 疲れた週は自動休養が踏み込み方を「流す」に落とすので、
  /// 追い込み続けても消耗は 86 には行かない（実測 56）。
  /// 落ち着き先で境目を引くと、追い込んだ選手に何の代償も付かなかった。
  /// 実測: 流す 22 / 普通 37 / 追い込む 56。
  static const double strainFresh = 26;
  static const double strainEased = 32;
  static const double strainWorn = 46;
  static const double strainBurnt = 54;

  /// 消耗が重傷の割合を動かす傾き。実測の幅（22〜56）で 0.82〜1.20 になる。
  static const double strainSevereSlope = 0.011;

  /// 今週ぶんだけ、落ち着き先へ寄せる。
  static double driftStrain(double now, double target) =>
      (now + (target - now) * strainDrift).clamp(0.0, 100.0);

  /// 消耗が衰え始めの年齢をどれだけ前後させるか。
  ///
  /// 現役年数は 33〜37 で固定なので、**長く走れること**ではなく
  /// **落ちるのが遅いこと**が見返りになる。通算記録とタイトルの機会が増え、
  /// それは殿堂に残る。
  static int declineOffsetForStrain(double strain) {
    if (strain <= strainFresh) return 2;
    if (strain <= strainEased) return 1;
    if (strain >= strainBurnt) return -2;
    if (strain >= strainWorn) return -1;
    return 0;
  }

  /// 消耗が重傷の引きやすさを何倍にするか。
  static double severeFactorForStrain(double strain) =>
      (1 + (strain - strainNeutral) * strainSevereSlope).clamp(0.6, 1.5);

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

  /// **能力値1点が、局面の成功率をどれだけ動かすか。**
  ///
  /// `Ranking.chanceGainPercent` が画面に出す「能力+1 = 成功率 +◯%」も
  /// ここから出す。**表示用に別の式を書かない。**
  ///
  /// 実測（`test/chance_sim.dart`）では 0.009 でも 19歳→28歳で
  /// 地力が +22% 動いていて、式の傾きが足りないわけではなかった。
  /// それでも上げたのは、**1週間に伸びる1点が +0.9% で、画面の丸めに
  /// 埋もれる**から。育てたことが試合の数字に出る瞬間を作るための幅。
  static const double attributeChanceSlope = 0.012;

  /// 相手の強さが成功率に与える傾き。
  ///
  /// これが無いと、3部でも1部でも同じ手が同じ確率で通り、
  /// 上のリーグへ移る意味が「年俸が上がる」だけになる。
  ///
  /// **浅すぎた。** `test/chance_sim.dart` で 24キャリアぶんの局面を
  /// 年齢で束ねて測ると、**22歳で成功率 78% に着き、そこから15年で +6%**
  /// しか動かなかった（18歳 40% → 22歳 78% → 28歳 84%）。
  /// 能力の効き（0.9%/点）が弱いのではなく、**効き切ってしまう**のが問題で、
  /// キャリアの8割が「何を伸ばしても数字が変わらない」時間になっていた。
  ///
  /// 原因は世界の側が育たないこと。局面の難易度は 30〜80 で止まっているのに
  /// 選ぶ手の能力は 95 まで行き、相手の格は平均 −3.0% しか引いていなかった。
  /// 傾きを深くして、**上のリーグへ行くほど同じ手が通らなくなる**ようにする。
  /// 基準は測った値（18歳の頃に当たる相手＝52）に合わせて下げる——
  /// 60 のままで傾きだけ立てると、**駆け出しの頃が今より楽になる**
  /// （傾きを立てると、格下と当たる若手ほど得をするため。56 で実測 45.0%、
  /// 変更前は 40.3% だった）。52 なら 18歳の成功率は元のままで、
  /// 上へ行ったぶんだけが引かれる。
  static const int opponentBaseline = 52;
  static const double opponentChanceSlope = 0.008;

  /// 選手の総合力と評価点から、移籍先クラブの強さの上限を決める係数。
  static const double transferReachFactor = 1.08;

  /// **名前は値段になる。**
  ///
  /// 知名度（`Person.fameFor`）には 代表・大陸カップ・世界大会・ゴール・
  /// リーグの格・特性（華がある ×1.4／生まれながらの主役 ×2.0）が
  /// 全部集まってくるのに、**効いていたのは愛称と引退後の道だけ**だった。
  /// 移籍にも年俸にも一切返らないので、知名度を上げる特性も出来事も飾りになる。
  ///
  /// 同じ実力でも、名の知れた選手のほうが高く売れ、上のクラブから声がかかる。
  /// 知名度は0〜100なので、値札は最大 ×1.3、届く強さは最大 +1.5。
  ///
  /// **届く先のほうは効きすぎる。** 最初 0.03 に置いたら、200キャリアで
  /// リーグ優勝が 252 → 335回（+33%）、無出場シーズンが 0.29 → 0.60 に
  /// なった——名前で身の丈より上のクラブへ行き、そこで登録から外れる。
  /// 値札と違って、ここは**世界の側**を動かしてしまう。
  static const double fameValue = 0.003;
  static const double fameReach = 0.015;

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

  /// 終盤の消耗。ここから足が止まりはじめる（分）。
  ///
  /// 局面の時間は表示・特性・展開の差し替えには効いていたのに、
  /// **成功率そのものには入っていなかった**。累積疲労もローテーションと
  /// 怪我にしか効いておらず、試合の中では何も起きなかった。
  static const int lateFatigueFrom = 70;

  /// 90分時点の落ち込み（スタミナが基準どおりのとき）。
  static const double lateFatigueBase = 0.05;

  /// スタミナ1あたり、落ち込みがどれだけ小さくなるか。
  ///
  /// スタミナはこれまで「フィジカルの平均に混ざる数字」でしかなかった。
  /// ここで初めて、鍛える理由が試合の中に出る。
  static const double lateFatiguePerStamina = 0.0015;

  /// 累積疲労1あたり、落ち込みがどれだけ大きくなるか。
  ///
  /// 休養・リカバリー・ローテーションが、試合の終盤で初めて手触りになる。
  static const double lateFatiguePerFatigue = 0.0006;

  /// 落ち込みの上限。ここを超えると終盤が理不尽になる。
  static const double lateFatigueMax = 0.20;

  /// 伸びるはずだった1回ぶんが、何点の経験点になるか。
  ///
  /// 値段（`experienceCost`）の平均とここが釣り合っていないと、
  /// 自分で振るだけで成長速度が変わってしまう。実測で揃えてある。
  static const int pointsPerGrowth = 4;

  /// 詳細能力を1上げるのに要る経験点。
  ///
  /// 上に行くほど高い。**平らにすると、一番得意なところに全部注ぐのが
  /// 常に正解になる**。高いところを押し上げるか、安いうちに穴を埋めるか、
  /// が毎回の判断になる幅に置く。
  static int experienceCost(int value) =>
      2 + (value < 45 ? 0 : value - 45) ~/ 9;

  /// 練習で能力が1伸びる確率（ポテンシャルに達していなければ）。
  static const double trainingGrowthChance = 0.3;

  /// 週の手応えが、コンディションでどれだけ動くか。
  ///
  /// 元気なら深く入れるし、疲れていれば空回りする。
  /// これが無いと「追い込む」を毎週押すのが最適解になる。
  static const double trainingGreatPerCondition = 0.0018;
  static const double trainingFlatPerCondition = 0.0045;

  /// プロ意識が、手応えにどれだけ効くか。
  static const double trainingGreatPerPro = 0.006;

  /// 手応えの出方の上下限。運の要素を残すため、0や1には振り切らせない。
  static const double trainingGreatMax = 0.72;
  static const double trainingFlatMax = 0.70;

  /// PK戦で勝つ確率。
  ///
  /// **能力ではほとんど決まらない**のが現実に近い。ここを実力差で決めると、
  /// 一発勝負の意味が消える（格上が必ず勝つなら、それはリーグ戦と同じ）。
  static const double shootoutBase = 0.5;

  /// カップ戦の早いラウンドで、起用に乗る下駄。
  ///
  /// 現実の早いラウンドは控えと若手が出る場。普段出られない選手にも回る。
  static const double cupRotationBonus = 0.45;

  /// 主力がカップの早いラウンドで休まされる確率。
  ///
  /// 0 にするとカップが「主力の試合数が増えるだけ」の装置になり、
  /// 若手が出る場という現実の構図が消える。
  static const double cupRestChance = 0.35;

  /// 休まされる線。これより上の見込みなら主力とみなす。
  static const double cupRestFrom = 0.4;

  /// 監督の信頼がこれを下回ると「構想外」。ベンチにも入れなくなる。
  ///
  /// **取り返しのつかないところが、このゲームには怪我しか無かった。**
  /// 信頼は下がっても、出れば評価点で戻せる。出られなくなって初めて、
  /// 積み上げてきた選択に値段が付く。
  /// 戻る道はある（監督が代わる・移籍する・出来事で歩み寄る）が、
  /// 「評価点で戻す」道だけは閉じている。出られないのだから。
  static const int frozenOutTrust = 12;

  /// これを下回ったら、構想外が近いことを画面で知らせる。
  ///
  /// 予告なしに落とすと、理不尽になる。落ちる前に必ず見えていること。
  static const int trustWarning = 28;

  /// ここを超えたら、疲労を警告として出す。`Fatigue.label` の段と揃える。
  static const int fatigueWarning = 70;

  /// 溜まった疲労が、重傷の割合に与える傾き。
  ///
  /// 数だけ増えて軽傷ばかりなら、無理を通すのはまだ得な賭けになる。
  /// 限界で走り続けた選手が壊れるのは、重いほうの怪我。
  static const double severePerFatigue = 0.0008;

  /// 疲労で増えた重傷の割合の上限。
  static const double severeShareMax = 0.13;

  /// ピッチの外で能力が伸びる出来事に、必ず乗る疲労。
  ///
  /// これが無いと、出来事の頻度がそのまま「強さ」になる。
  static const int eventTrainFatigue = 2;

  /// ここを下回ると「身体が落ちている」出来事が出る。
  static const int lowConditionForEvents = 62;

  /// メンターに付いた週に、プロ意識が1上がる確率。
  ///
  /// 毎週上がると、性格が「積むだけの数字」になる。ゆっくりしか動かさない。
  static const double mentorProfessionalismChance = 0.12;

  /// 一緒に組んだ相手との関係が、その週にどれだけ動くか。
  static const int companionSynergyGain = 2;
  static const int companionTeammatesGain = 1;

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
  /// 限界を超えるのに要る「大成功した週」の数。
  ///
  /// 追い込み続けた選手だけが上限を破る。ここを通さないと、週の選択は
  /// ピークに着く速さを変えるだけで、届く高さは変わらない。
  static const int breakthroughGreatWeeks = 18;

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

  /// 監督の求める形に沿った手・逆らった手が、1試合で信頼を動かす量。
  ///
  /// 監督は `fitFor` で**能力値だけ**を見ていた。つまり「あなたの数字」を
  /// 採点する装置で、あなたが何を選んだかは見ていなかった。
  /// 1試合3局面なので、全部沿えば +1、全部逆らえば -1 くらいに収める。
  /// 大きくすると、型（identity）を通す遊び方が単に損になる。
  static const double trustPerTacticFit = 0.34;

  /// 要求の厳しい監督ほど、選択の善し悪しが強く響く。
  static const double trustPerDemand = 0.12;

  /// 自動で進めるとき、監督の求める形をどれだけ重く見るか。
  ///
  /// 入れないと、自動進行は監督を無視し続けて信頼を失う（実測で
  /// 代表経験が 58%→51% に落ちた）。人が押す「区切りまで」も同じ道を通るので、
  /// これが無いと自動進行そのものが罠になる。
  /// 明らかに良い手を覆すほどではない重さにする。
  static const double tacticPickBonus = 0.06;

  /// 登録メンバーに入るのに必要な、クラブの強さとの差。
  /// これより大きく劣ると25人枠に入れない。
  static const int squadRegistrationGap = -8;

  /// 大陸カップに出た年の年俸倍率。
  static const double continentalSalaryBonus = 1.1;

  /// 目標を達成したときの年俸倍率。達成できなかったときの倍率。
  static const double objectiveMetSalaryFactor = 1.15;
  static const double objectiveMissedSalaryFactor = 0.9;
}
