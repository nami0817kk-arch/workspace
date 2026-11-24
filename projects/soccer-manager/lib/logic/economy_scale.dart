import 'dart:math';

import '../l10n/tr.dart';
import '../models/league_theme.dart';

/// お金の桁を部ごとに変える物差し。金額はすべて万円の int。
///
/// 以前は全部の額が5部の規模で決まっていて、部による差は観客の係数
/// (1つ下がるごとに0.8倍)だけだった。1部に上がっても主力の週俸が
/// 数百万円、移籍金が最大2億円と、実在のサッカーとは桁が2つ違った。
///
/// ここでは、上の部ほど額を大きくする。目安は次の通り(クラブの年収)。
///
/// | 部 | 年収 | 主力の年俸 |
/// |---|---|---|
/// | 1部 | 300〜800億 | 5〜30億 |
/// | 2部 | 40〜80億 | |
/// | 3部 | 10〜20億 | |
///
/// **いまは3部制**(league.dart の totalDivisionTiers = 3)。5部制だった頃の
/// 名残で、額の元(base)は「旧5部の規模」で書いてあり(倍率1)、下の表にも
/// 4部・5部の値が残っている。いまの部(1〜3)では4部・5部の値は使われない。
/// 元の額と倍率の組で今の額が決まっているので、値は動かさずに残してある
/// (元の額を3部基準に書き直すと、すべての呼び出し元の数字を直す必要がある)。
///
/// 選手の価値と給与は部ではなく能力から決まる(1部の選手は能力が高い
/// ので、結果として桁が上がる)。部で決まるのは、クラブの規模で決まる額
/// (費用・賞金・収入)だけ。

/// 費用・賞金など「クラブの規模で決まる額」にかける倍率。
/// 3部 14.4、2部 55、1部 209(旧5部=1 を元にした値。4部 3.8 は使われない)。
double moneyScale(int tier) => pow(3.8, 5 - tier.clamp(1, 5)).toDouble();

/// 元の額 [base](旧5部の規模で書いた額)を、[tier] 部の規模に直す。
int scaleMoneyForTier(int tier, int base) => (base * moneyScale(tier)).round();

/// 観客・グッズ・スポンサーの収入にかける倍率。
///
/// 出発点は moneyScale ÷ (0.8^(部-1) ÷ 0.8^4)。観客の収入は、もともと
/// 0.8^(部-1) の係数を持っている(下の部ほど客が少ない)ので、二重に
/// 掛けないよう割り戻す。この式だと 5部 1、4部 3.0、3部 9.2、2部 28、
/// 1部 85。
///
/// そこから実測で合わせ込んだ(test/economy_scale_test.dart)。
/// - 5部は3倍。もとの観客・グッズの式が小さく、年収が1億に届かなかった。
/// - 1部は式の約0.6倍。放映権(当時は250億)と合わせて年収330億前後、
///   人件費率は 40〜70%。
/// - 2〜4部は式とほぼ同じか少し下(2部 約55億、3部 約13億、4部 約6.5億)。
///   人件費率は 2部 80〜100%、3部 100%前後、4部 45〜70%。
/// 部ごとのクラブの強さの幅(division_strength.dart)と組で合わせてある。
/// 片方だけ変えると人件費率が大きくずれる。
/// (4部・5部の値は5部制だった頃のもの。いまの3部制では使われない。)
double incomeScale(int tier) => switch (tier.clamp(1, 5)) {
      1 => 50,
      2 => 16,
      3 => 6.2,
      4 => 3.6,
      _ => 3,
    };

/// 1人の観客が1試合で払う額の目安(万円。チケットと場内の売上)。
/// 観客収入の上限([GameState] の入場収入の頭打ち)に使う。年間の観客収入は
/// 「入る人数 × ホームの試合の数 × この額」を超えない。
///
/// 以前は観客収入が席の数と関係なく、順位・施設・部の倍率の掛け算で
/// 決まっていて、1部では1季488億(4万人が19試合で払うと1人6万円超)に
/// なっていた(2026-11-23)。
double gateRevenuePerFan(int tier) => switch (tier.clamp(1, 5)) {
      1 => 1.0,
      2 => 0.4,
      3 => 0.2,
      4 => 0.12,
      _ => 0.08,
    };

/// 部ごとの、放映権を除いた年収(観客・スポンサー・グッズ・賞金)の目安
/// (万円)。国では変えない。[typicalAnnualIncome] の土台。
int _typicalNonBroadcastIncome(int tier) => switch (tier.clamp(1, 5)) {
      1 => 800000, // 80億
      2 => 250000, // 25億
      3 => 100000, // 10億
      4 => 45000, // 4.5億
      _ => 38000, // 3.8億
    };

/// 大陸大会の賞金(万円。2026-11-22 に実額へ寄せた)。大陸大会に出るのは
/// 1部のクラブだけなので、部の倍率は掛けない。
///
/// チャンピオンズカップ(実在の CL にあたる)は、出るだけで約30億、グループの
/// 勝ち・引き分けごとに加算、決勝トーナメントの回戦に進むたびに加算、
/// 優勝でさらに加算。優勝したクラブの総額は150億を超える(グループ4勝1分で
/// 約167億)。ヨーロッパカップ(EL にあたる)はその3分の1。
///
/// **賞金は年収の目安([typicalAnnualIncome])に入れていない。** 目安は
/// 1部の真ん中のクラブ(大陸大会に出ない)の営業収入で、賞金は大会に出た
/// クラブだけに上乗せで入る(出場だけで1部の年収の約9%)。
const int championsCupParticipationPrize = 300000; // 30億

/// チャンピオンズカップのグループの1勝の賞金(2.8億)。
const int championsCupGroupWinPrize = 28000;

/// チャンピオンズカップのグループの1引き分けの賞金(9,000万)。
const int championsCupGroupDrawPrize = 9000;

/// チャンピオンズカップの決勝トーナメントの回戦に進んだときの賞金。
/// 決勝から数えて [0]=決勝、[1]=準決勝、[2]=準々決勝、[3]=ベスト16。
const List<int> championsCupReachPrize = [300000, 220000, 180000, 150000];

/// チャンピオンズカップの優勝の上乗せ(40億)。
const int championsCupWinnerPrize = 400000;

/// ヨーロッパカップの賞金は、チャンピオンズカップの何分の1か。
const int europaCupPrizeDivisor = 3;

/// 大会の格[level](1=チャンピオンズカップ、2=ヨーロッパカップ)に合わせた額。
int continentalPrize(int level, int championsCupAmount) => level <= 1
    ? championsCupAmount
    : championsCupAmount ~/ europaCupPrizeDivisor;

/// 決勝トーナメントの回戦に進んだ賞金。[fromFinal]は決勝から数えた位置
/// (0=決勝)。表より手前の回戦は、表のいちばん安い額。
int continentalReachPrize(int level, int fromFinal) {
  final i = fromFinal.clamp(0, championsCupReachPrize.length - 1);
  return continentalPrize(level, championsCupReachPrize[i]);
}

/// 優勝したクラブの賞金の総額。[groupWins]・[groupDraws]はグループの成績、
/// [knockoutRounds]は決勝トーナメントの回戦の数(決勝を含む)。
int continentalChampionTotal(int level,
    {required int groupWins,
    required int groupDraws,
    required int knockoutRounds}) {
  var total = continentalPrize(level, championsCupParticipationPrize) +
      groupWins * continentalPrize(level, championsCupGroupWinPrize) +
      groupDraws * continentalPrize(level, championsCupGroupDrawPrize) +
      continentalPrize(level, championsCupWinnerPrize);
  for (var k = 0; k < knockoutRounds; k++) {
    total += continentalReachPrize(level, k);
  }
  return total;
}

/// 部ごとの、真ん中くらいのクラブの年収の目安(万円)。理事会が給与の
/// 枠を組むとき・初期の資金の基準に使う。放映権を除いた分(国で同じ)に、
/// その国の放映権([annualBroadcast])を足す。イングランドの1部で380億、
/// フランスの1部で170億ほど。4部・5部の行は5部制の名残で、いまの3部制
/// では使われない。
int typicalAnnualIncome(int tier, [LeagueTheme theme = LeagueTheme.england]) =>
    _typicalNonBroadcastIncome(tier) + annualBroadcast(tier, theme);

/// 国ごとの放映権の大きさ(イングランド = 1)。2026-11-22 に実際に寄せた。
///
/// 以前は5か国とも同じ額だった。実際の1クラブあたりの国内放映権は、
/// プレミアが飛び抜けて大きく(約300億円)、スペイン・ドイツ・イタリアが
/// その半分ほど、フランスは3割ほど。2部はイングランドのチャンピオン
/// シップが大きく、ドイツの2部が続く。3部は、どこもわずか。
double broadcastCountryFactor(LeagueTheme theme, int tier) =>
    switch ((theme, tier.clamp(1, 3))) {
      (LeagueTheme.england, _) => 1.0,
      (LeagueTheme.spain, 1) => 0.6,
      (LeagueTheme.germany, 1) => 0.55,
      (LeagueTheme.italy, 1) => 0.5,
      (LeagueTheme.france, 1) => 0.3,
      (LeagueTheme.germany, 2) => 0.55,
      (LeagueTheme.spain, 2) => 0.45,
      (LeagueTheme.italy, 2) => 0.4,
      (LeagueTheme.france, 2) => 0.3,
      (LeagueTheme.germany, _) => 0.7,
      (LeagueTheme.spain, _) => 0.6,
      (LeagueTheme.italy, _) => 0.55,
      (LeagueTheme.france, _) => 0.45,
    };

/// 1シーズンの放映権料(万円)。上の部ほど大きく、イングランドの1部では
/// 年収の8割近くになる。国で額が違う([broadcastCountryFactor])。下の部は、
/// ほとんど入らない。4部・5部の行は5部制の名残で、いまの3部制では
/// 使われない。
///
/// イングランドの額: 1部 300億・2部 40億・3部 5億(以前は5か国とも
/// 250億・30億・4億)。イングランドは上がり、ほかの4か国は下がった
/// (5か国の平均は1部で177億)。
int annualBroadcast(int tier, [LeagueTheme theme = LeagueTheme.england]) {
  final england = switch (tier.clamp(1, 5)) {
    1 => 3000000, // 300億
    2 => 400000, // 40億
    3 => 50000, // 5億
    4 => 10000, // 1億
    _ => 2000, // 2,000万
  };
  return (england * broadcastCountryFactor(theme, tier)).round();
}

/// 毎節入る放映権料(万円)。1シーズンの額を節の数で割る。
/// 節の数は国(部のクラブ数)で違うので、渡せるようにしてある。
int weeklyBroadcast(int tier,
        {int matchdays = 38, LeagueTheme theme = LeagueTheme.england}) =>
    (annualBroadcast(tier, theme) / max(1, matchdays)).round();

/// 能力 [overall] から見た市場価値の基準(万円)。
///
/// 60 × e^(0.1768 × (総合 − 40))。総合45で約145万、78で約5億、
/// 85で約17億、90で約41億、95で約100億。年齢・潜在・性格・リーダー
/// シップの係数は、ここに掛ける。
double marketValueBase(int overall) => 60 * exp(0.1768 * (overall - 40));

/// 市場価値の上限(万円)。150億。
const int maxMarketValue = 1500000;

/// 市場価値の下限(万円)。
const int minMarketValue = 50;

/// 国・部ごとの年俸の水準(イングランド = 1)。2026-11-22 に入れた。
///
/// 以前は年俸が国によらず、放映権を国ごとにした([broadcastCountryFactor])
/// ことで、放映権の小さい国の1部は人件費率が100%を超えていた(年俸の
/// 合計 ÷ 年収の目安。クラブ全体の真ん中で、スペイン・ドイツ 約105%・
/// イタリア 約115%・フランス 約155%。イングランドは約70%)。実際も、同じ
/// 力の選手でプレミアの年俸が最も高く、フランスは低い。市場価値(移籍金)は
/// 国で変えない。
///
/// 放映権の差よりゆるめ(1部: 放映権はスペイン 0.6・フランス 0.3、年俸は
/// 0.7・0.54)。放映権を除いた年収(観客・スポンサーなど)は国で同じなので、
/// 年収の差は放映権の差より小さい。真ん中のクラブの人件費率が 1部
/// 50〜80%・2部 70〜110% に入るように、部ごとに合わせた
/// (test/economy_scale_test.dart)。2部はイングランドのチャンピオンシップの
/// 放映権が飛び抜けているので、国の差が1部より大きい。ドイツの2部は
/// クラブが少し弱く(年俸の合計が小さい)、高めの水準で釣り合う。
/// イングランドの2部は水準1だと 90〜110% と範囲の上の端に寄ったので
/// 0.9(それでも2部で一番高い)。3部は年収に占める放映権が小さく、国の差も
/// 小さい(3部は人件費率の目安を決めていない。4季で破綻しないことだけ
/// test/long_run_balance_test.dart などで見る)。1部を
/// もっとゆるめ(西0.8・独0.75・伊0.75・仏0.6)にすると、4か国とも 80% を
/// 超えた(82〜94%)。
///
/// **どの国も、部が下がるほど同じか低い(1部 ≥ 2部 ≥ 3部)。** 同じ選手の
/// 相場は、実際も部でほとんど変わらないか、下の部ほど下がる。以前は
/// 人件費率だけを見て部ごとに合わせたため、フランス(1部0.45・2部0.55・
/// 3部0.6)・ドイツ(0.65・0.75・0.7)などで下の部ほど高く、同じ選手が
/// フランスの1部より2部で22%高く求め、降格しても年俸が下がらなかった
/// (2026-11-23 に直した)。
///
/// 部の年収の差は、各部の選手の強さ(division_strength.dart の強さのくじ)
/// で吸収する。強さのくじと年俸の式の指数は5か国で同じなので、年俸の合計の
/// 部の間の比も5か国で同じ(実測で 1部÷2部 約4.2倍、2部÷3部 約3.2倍)。
/// 一方、年収の部の間の比は国の放映権で違う(1部÷2部: スペイン 6.0・
/// イングランド 5.8・フランス 4.6)。フランスは1部の放映権が小さく、部の
/// 間の年収の差が小さいので、係数を部で下げられない(下げると2部・3部の
/// 人件費率が低くなりすぎる)。そのためフランスは1部をやや高め(人件費率
/// 約80%。実際のリーグ・アンも5大リーグで高いほう)にして、部の間をほぼ
/// 平らにした。強さのくじや指数を変えると5か国が一緒に動き、国の差は
/// 直らない(試合・昇格の難しさまで変わる)ので、係数で合わせる。
///
/// 作ったばかりのリーグの全クラブ(80ゲームぶん)の人件費率の真ん中
/// (年俸の合計 ÷ 年収の目安。1部/2部/3部。2026-11-23):
/// イングランド 67/81/91%、スペイン 71/85/90%、ドイツ 73/81/91%、
/// イタリア 74/83/89%、フランス 81/83/82%。3部は運営費が入ったので、
/// 季を重ねて年俸が上がっても 110% 前後に収まるよう、90% ほどに置く。
double wageCountryFactor(LeagueTheme theme, int tier) =>
    switch ((theme, tier.clamp(1, 3))) {
      (LeagueTheme.england, 1) => 1.0,
      // 水準1だと 90〜110% と2部の範囲の上の端に寄った。
      (LeagueTheme.england, 2) => 0.9,
      // 3部は年収に占める放映権が小さく、収入に比べて年俸が重い(0.74 で
      // 真ん中が 94〜101% と、季を重ねると 110% を超えた)。
      (LeagueTheme.england, _) => 0.65,
      (LeagueTheme.spain, 1) => 0.7,
      (LeagueTheme.spain, 2) => 0.64,
      (LeagueTheme.spain, _) => 0.55,
      (LeagueTheme.germany, 1) => 0.7,
      (LeagueTheme.germany, 2) => 0.65,
      (LeagueTheme.germany, _) => 0.6,
      (LeagueTheme.italy, 1) => 0.68,
      (LeagueTheme.italy, 2) => 0.62,
      (LeagueTheme.italy, _) => 0.58,
      // 部の間の年収の差が小さいので、部の間はほぼ平ら(上を参照)。
      (LeagueTheme.france, 1) => 0.54,
      (LeagueTheme.france, 2) => 0.52,
      (LeagueTheme.france, _) => 0.5,
    };

/// 自クラブのいる国と部。年俸の水準([currentWageLevel])を決める。
/// GameState が、始めたとき・読み込んだとき・新しい季・クラブを買い替えた
/// ときに合わせる([setHomeWageLevel])。
LeagueTheme _wageHomeTheme = LeagueTheme.england;
int _wageHomeTier = 1;

/// 他の国・部のクラブの選手を作っている間だけ、その水準に差し替える。
double? _wageLevelOverride;

/// 自クラブのいる国・部を、年俸の水準の基準にする。
void setHomeWageLevel(LeagueTheme theme, int tier) {
  _wageHomeTheme = theme;
  _wageHomeTier = tier;
}

/// 自クラブのいる国(年俸の水準の基準)。
LeagueTheme get wageHomeTheme => _wageHomeTheme;

/// いまの年俸の水準。ふだんは自クラブのいる国・部の [wageCountryFactor]。
/// [withWageLevel] の中では、その水準。
double get currentWageLevel =>
    _wageLevelOverride ?? wageCountryFactor(_wageHomeTheme, _wageHomeTier);

/// [level] の水準で [body] を行う(他の国・部のクラブの選手を作るとき)。
T withWageLevel<T>(double level, T Function() body) {
  final prev = _wageLevelOverride;
  _wageLevelOverride = level;
  try {
    return body();
  } finally {
    _wageLevelOverride = prev;
  }
}

/// [originLeague](国の名前 [LeagueTheme.name]。他国の1部のクラブの選手)
/// の年俸を、自クラブの国の水準に直す倍率。同じ国・分からないときは 1。
/// 国をまたいで移る選手は、行き先の国の水準で年俸を求める。
double wageScaleToHome(String? originLeague) {
  if (originLeague == null || originLeague == _wageHomeTheme.name) return 1.0;
  final from =
      LeagueTheme.values.where((t) => t.name == originLeague).firstOrNull;
  if (from == null) return 1.0;
  return currentWageLevel / wageCountryFactor(from, 1);
}

/// 市場価値 [value] から見た年俸(万円)。2.4 × 価値^0.88 に、
/// 年俸の水準 [level](省略時は [currentWageLevel]。イングランド = 1)を掛ける。
/// 2026-11-23 から選手の年俸の基準は [annualWageForAbility](能力と経験)。
/// これは人件費の水準を合わせるときの比べる元として残している。
int annualWageForValue(int value, [double? level]) =>
    (2.4 * pow(max(0, value), 0.88) * (level ?? currentWageLevel)).round();

/// 年俸の年齢の係数(経験)。若手は安め、20代後半〜30代前半が高く、
/// 30代半ばからやや下がる。年齢の間は線でつなぐ(誕生日で大きく跳ねない)。
///
/// 年俸は「今の能力 × 経験」で決まる。伸びしろ(若さ)の分は移籍金
/// (市場価値)だけに効く。以前は年俸を市場価値から出していたため、
/// 総合60の19歳が32歳の約4.6倍の年俸を求めていた(2026-11-23 に変更)。
double wageExperienceFactor(int age) =>
    piecewiseLinear(_wageExperiencePoints, age);

const List<(int, double)> _wageExperiencePoints = [
  (17, 0.45),
  (20, 0.62),
  (23, 0.82),
  (26, 0.97),
  (28, 1.05),
  (32, 1.08),
  (34, 1.0),
  (36, 0.9),
  (39, 0.82),
];

/// [points](年齢の昇順)を線でつないだ値。範囲の外は端の値。
double piecewiseLinear(List<(int, double)> points, num x) {
  if (x <= points.first.$1) return points.first.$2;
  for (var i = 1; i < points.length; i++) {
    final (x1, y1) = points[i];
    if (x <= x1) {
      final (x0, y0) = points[i - 1];
      return y0 + (y1 - y0) * (x - x0) / (x1 - x0);
    }
  }
  return points.last.$2;
}

/// 総合力・年齢から年俸を出す倍率。選手全体の人件費の水準が、市場価値
/// から出していた頃([annualWageForValue])と同じくらいになるように合わせた
/// (作ったばかりのリーグの全選手の年俸の合計で比べる)。
const double wageAbilityScale = 2.79;

/// 総合力 [overall]・年齢 [age] の選手が求める年俸(万円)。
/// [wageAbilityScale] × 市場価値の基準([marketValueBase])^0.88 ×
/// 経験の係数([wageExperienceFactor])に、年俸の水準 [level](省略時は
/// [currentWageLevel]。イングランド = 1)を掛ける。伸びしろ・性格は見ない。
int annualWageForAbility(int overall, int age, [double? level]) =>
    (wageAbilityScale *
            pow(marketValueBase(overall), 0.88) *
            wageExperienceFactor(age) *
            (level ?? currentWageLevel))
        .round();

/// 総合力 [overall]・年齢 [age] の選手の週俸(万円)。年俸 ÷ 52、最低
/// [minWeeklyWage]。選手が「見合う」と考える額で、契約・満足度・移籍の
/// 要求の基準になる。
int weeklyWageForAbility(int overall, int age, [double? level]) =>
    max(minWeeklyWage,
        (annualWageForAbility(overall, age, level) / 52).round());

/// 給与の下限(万円/週)。
const int minWeeklyWage = 5;

/// 市場価値 [value] の選手の週俸(万円)。年俸 ÷ 52、最低 [minWeeklyWage]。
/// [level] は [annualWageForValue] と同じ。
int weeklyWageForValue(int value, [double? level]) =>
    max(minWeeklyWage, (annualWageForValue(value, level) / 52).round());

/// 週俸を年俸に直す(表示用)。
int annualFromWeekly(int weekly) => weekly * 52;

/// 1年(52週)の給与を、その年の節の数で割って毎節払う。
/// 表示の年俸(週俸×52)と、1年に払う総額が一致する。
int perMatchdayFromWeekly(int weekly, int matchdays) =>
    (weekly * 52 / max(1, matchdays)).round();

/// 金額の表示。1億以上は「1.2億」(小数1桁、整数なら「3億」)、
/// それ未満は「3,500万」。英語は円の桁で「1.2bn yen」「120m yen」
/// 「35m yen」(1億円 = 100m yen)。同梱フォントに「¥」の字形が無いので、
/// 記号ではなく yen と書く。
String formatMoney(int man) {
  final neg = man < 0;
  final v = man.abs();
  final sign = neg ? '-' : '';
  return Tr.pick('$sign${_formatJa(v)}', '$sign${_formatEn(v)}');
}

/// 狭い所(上の帯など)に出す短い金額。日本語は [formatMoney] と同じ。英語は
/// 「 yen」を付けない(810.8m yen → 810.8m)。単位は見出しの側に書く
/// (「Funds (yen)」)。上の帯の資金が英語で「810.8m y…」と切れていた
/// (2026-11-25 の第7段)。円の記号は同梱の字体に無く、箱の字になる。
String formatMoneyCompact(int man) {
  final neg = man < 0;
  final v = man.abs();
  final sign = neg ? '-' : '';
  if (v == 0) return Tr.pick(_formatJa(0), '0');
  final en = v >= 100000
      ? '${_oneDecimal(v / 100000)}bn'
      : v >= 100
          ? '${_oneDecimal(v / 100)}m'
          : '${v * 10}k';
  return Tr.pick('$sign${_formatJa(v)}', '$sign$en');
}

/// 符号付きの表示(+1.2億 / -3,500万)。0 は符号なし。
String formatMoneySigned(int man) =>
    man > 0 ? '+${formatMoney(man)}' : formatMoney(man);

// i18n-ignore: 単位の字(億・万)。formatMoney の Tr.pick の日本語側でだけ使う。
String _formatJa(int v) {
  // 0 は「0万」ではなく「0円」(2026-11-23)。
  if (v == 0) return '0円';
  if (v >= 10000) {
    return '${_oneDecimal(v / 10000)}億';
  }
  return '${_grouped(v)}万';
}

String _formatEn(int v) {
  if (v == 0) return '0 yen';
  // 1万円 = 10k yen。10億円 = 1bn yen。
  if (v >= 100000) return '${_oneDecimal(v / 100000)}bn yen';
  if (v >= 100) return '${_oneDecimal(v / 100)}m yen';
  return '${v * 10}k yen';
}

String _oneDecimal(double x) {
  final r = (x * 10).round() / 10;
  if (r == r.roundToDouble()) return _grouped(r.round());
  // 小数ありの側も桁区切りを付ける(12345.6億 → 12,345.6億)。
  final whole = r.truncate();
  final tenth = ((r - whole) * 10).round();
  return '${_grouped(whole)}.$tenth';
}

/// 人数・席数などの数の表示。3桁ごとに区切る(12000 → 12,000)。
/// 金額は [formatMoney] を使う。
String formatCount(int v) => v < 0 ? '-${_grouped(-v)}' : _grouped(v);

String _grouped(int v) {
  final s = v.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}
