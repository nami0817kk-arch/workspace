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

/// 市場価値 [value] の選手が求める年俸(万円)。2.4 × 価値^0.88。
int annualWageForValue(int value) => (2.4 * pow(max(0, value), 0.88)).round();

/// 給与の下限(万円/週)。
const int minWeeklyWage = 5;

/// 市場価値 [value] の選手の週俸(万円)。年俸 ÷ 52、最低 [minWeeklyWage]。
int weeklyWageForValue(int value) =>
    max(minWeeklyWage, (annualWageForValue(value) / 52).round());

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

/// 符号付きの表示(+1.2億 / -3,500万)。0 は符号なし。
String formatMoneySigned(int man) =>
    man > 0 ? '+${formatMoney(man)}' : formatMoney(man);

// i18n-ignore: 単位の字(億・万)。formatMoney の Tr.pick の日本語側でだけ使う。
String _formatJa(int v) {
  if (v >= 10000) {
    return '${_oneDecimal(v / 10000)}億';
  }
  return '${_grouped(v)}万';
}

String _formatEn(int v) {
  // 1万円 = 10k yen。10億円 = 1bn yen。
  if (v >= 100000) return '${_oneDecimal(v / 100000)}bn yen';
  if (v >= 100) return '${_oneDecimal(v / 100)}m yen';
  return '${v * 10}k yen';
}

String _oneDecimal(double x) {
  final r = (x * 10).round() / 10;
  if (r == r.roundToDouble()) return _grouped(r.round());
  return r.toStringAsFixed(1);
}

String _grouped(int v) {
  final s = v.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}
