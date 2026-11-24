// ignore_for_file: non_constant_identifier_names, constant_identifier_names
/// 関税・輸送・交通とインフラ・海外の難しさ・供給の網の数字（1.1.0+28 から。企画書「現実に寄せる」の段5）。
/// Flutter に依存しない、ただの表。使う式は game_trade.dart。
///
/// 数字は大まかな実際の水準に合わせた目安で、年の間は線で補う。大きな流れ（WTO の加盟年・貿易協定の発効年・
/// コンテナ化の時期・大きな災害と紛争の年月）は現実どおり。出どころ（どれも無料の公開資料）:
/// - 関税: 世界銀行 WDI「Tariff rate, applied, simple mean, all products (%)」（TM.TAX.MRCH.SM.AR.ZS。1988年より前は
///   UNCTAD TRAINS と各国の関税の改正の年から推した値）。2025年の米国は、同年の上乗せ関税を平均にならした目安
/// - WTO の加盟年: WTO「Members and Observers」。協定の発効年: WTO「Regional Trade Agreements Database」と各国の発表
/// - 海上と航空の運賃の水準: Hummels, D. (2007) "Transportation Costs and International Trade in the Second Era of
///   Globalization", Journal of Economic Perspectives 21(3)。輸送の日数の重み: Hummels & Schaur (2013) AER 103(7)
///   （1日の遅れは値段の0.6〜2.1%にあたる。ここでは在庫の重さとして小さめに使う）。2021年の運賃の跳ね上がりは
///   国連 UNCTAD「Review of Maritime Transport 2021/2022」
/// - コンテナ化の時期: Bernhofen, El-Sahli & Kneller (2016) "Estimating the effects of the container revolution on world
///   trade", Journal of International Economics 98（国ごとの港の導入年）と各国の港の歴史
/// - 電気・通信: 世界銀行 WDI「Access to electricity (% of population)」・ITU「Individuals using the Internet」
/// - 道路と物流: 世界銀行「Logistics Performance Index」（2007〜2023年）。それより前は道路の舗装率などから推した値
/// - 会社を作る日数: 世界銀行「Doing Business」（2004・2010・2020年の Starting a business）
/// - 送金の制限: IMF「Annual Report on Exchange Arrangements and Exchange Restrictions」の大きな流れ
/// - 災害と紛争: 各国の政府と国連の報告（阪神・淡路大震災 1995-01、台湾の集集地震 1999-09、東日本大震災 2011-03、
///   タイの大洪水 2011-10、新型コロナ 2020〜、上海の封鎖 2022-03 など）
library;

import 'dart:math' as math;

/// 年の目安（年, 値）を線で補って引く（範囲の外は端の値）
double kp(List<(int, double)> pts, double y) {
  if (pts.isEmpty) return 0;
  if (y <= pts.first.$1) return pts.first.$2;
  if (y >= pts.last.$1) return pts.last.$2;
  for (var i = 1; i < pts.length; i++) {
    final a = pts[i - 1], b = pts[i];
    if (y <= b.$1) return a.$2 + (b.$2 - a.$2) * (y - a.$1) / (b.$1 - a.$1);
  }
  return pts.last.$2;
}

// ===== 関税 =====
/// 欧州の共通の関税（EC/EU の加盟国は同じ）
const List<(int, double)> _euTariff = [(1980, 8.0), (1990, 6.5), (2000, 4.3), (2010, 4.0), (2025, 4.2)];

/// 輸入の関税の平均（%。その国が外から入る物にかける、適用されている税率の単純平均）
const Map<String, List<(int, double)>> TARIFF = {
  'jp': [(1980, 6.5), (1990, 5.0), (2000, 3.3), (2010, 2.6), (2025, 2.4)],
  'cn': [(1980, 50.0), (1992, 40.0), (1996, 23.0), (2001, 15.0), (2005, 9.5), (2010, 9.0), (2018, 7.5), (2025, 7.0)],
  'kr': [(1980, 25.0), (1990, 13.0), (2000, 9.0), (2025, 8.5)],
  'tw': [(1980, 30.0), (1990, 10.0), (2002, 6.0), (2025, 5.5)],
  'in': [(1980, 70.0), (1990, 80.0), (1995, 40.0), (2000, 33.0), (2005, 15.0), (2010, 8.5), (2015, 9.0), (2020, 12.0), (2025, 12.0)],
  'id': [(1980, 30.0), (1990, 18.0), (2000, 7.0), (2010, 5.0), (2025, 6.0)],
  'th': [(1980, 35.0), (1990, 40.0), (1995, 23.0), (2000, 13.0), (2010, 8.5), (2025, 9.0)],
  'vn': [(1990, 20.0), (2000, 15.0), (2007, 12.0), (2015, 6.0), (2025, 5.0)],
  'ph': [(1980, 40.0), (1990, 25.0), (2000, 7.0), (2025, 6.0)],
  'sg': [(1980, .3), (2025, .2)],
  'us': [(1980, 6.0), (1990, 5.0), (2000, 3.5), (2017, 2.8), (2024, 3.0), (2025, 15.0)],
  'ca': [(1980, 8.0), (1990, 7.0), (2000, 4.5), (2025, 3.5)],
  'mx': [(1980, 25.0), (1986, 25.0), (1988, 13.0), (1994, 13.0), (2000, 16.0), (2010, 7.0), (2025, 7.0)],
  'br': [(1980, 55.0), (1988, 50.0), (1990, 30.0), (1995, 12.0), (2010, 13.0), (2025, 12.0)],
  'uk': _euTariff,
  'de': _euTariff,
  'fr': _euTariff,
  'it': _euTariff,
  'es': [(1980, 15.0), (1986, 12.0), (1993, 6.0), (2000, 4.3), (2010, 4.0), (2025, 4.2)],
  'ru': [(1991, 10.0), (2000, 12.0), (2012, 10.0), (2016, 7.0), (2025, 6.5)],
  'sa': [(1980, 4.0), (1990, 12.0), (2005, 5.0), (2025, 5.0)],
  'ng': [(1980, 35.0), (1990, 33.0), (2000, 25.0), (2005, 12.0), (2025, 12.0)],
  'za': [(1980, 25.0), (1990, 20.0), (1995, 10.0), (2000, 8.0), (2025, 7.0)],
  'au': [(1980, 15.0), (1990, 10.0), (2000, 5.0), (2010, 3.0), (2025, 2.5)],
};

/// GATT・WTO に入った年（1995年の WTO 発足のときの加盟国は、それより前から GATT にいた）。データの範囲より前は 0
const Map<String, int> WTO_YEAR = {
  'jp': 0, 'kr': 0, 'in': 0, 'id': 0, 'th': 0, 'ph': 0, 'sg': 0, 'us': 0, 'ca': 0, 'br': 0, 'uk': 0, 'de': 0, //
  'fr': 0, 'it': 0, 'es': 0, 'ng': 0, 'za': 0, 'au': 0, 'mx': 1986, 'cn': 2001, 'tw': 2002, 'sa': 2005, 'vn': 2007, 'ru': 2012,
};

/// 貿易協定（加盟国どうしの関税を、発効から [phase] 年かけて [cut] の割合まで下げる。[end] の年から無くなる）。
/// 名前は日本語（英語は trade_en.dart）。関税同盟（EC）は cut 1。原産地の決まりで使えない分があるので、ふつうの協定は 0.85
class Fta {
  final String ja;
  final List<String> members;
  final int year, phase, end;
  final double cut;
  const Fta(this.ja, this.members, this.year, {this.phase = 10, this.cut = .85, this.end = 9999});
}

const List<Fta> FTAS = [
  Fta('欧州共同体', ['de', 'fr', 'it'], 1958, phase: 1, cut: 1),
  Fta('欧州共同体', ['uk', 'de', 'fr', 'it'], 1973, phase: 1, cut: 1, end: 2021),
  Fta('欧州共同体', ['es', 'de', 'fr', 'it'], 1986, phase: 7, cut: 1),
  Fta('欧州共同体', ['es', 'uk'], 1986, phase: 7, cut: 1, end: 2021),
  Fta('英国とEUの協定', ['uk', 'de', 'fr', 'it', 'es'], 2021, phase: 1, cut: .9),
  Fta('米加自由貿易協定', ['us', 'ca'], 1989),
  Fta('北米自由貿易協定', ['us', 'ca', 'mx'], 1994),
  Fta('ASEAN自由貿易地域', ['id', 'th', 'ph', 'sg'], 1993, phase: 10),
  Fta('ASEAN自由貿易地域', ['vn', 'id', 'th', 'ph', 'sg'], 1996, phase: 15),
  Fta('中国とASEANの協定', ['cn', 'id', 'th', 'ph', 'sg', 'vn'], 2005, phase: 6),
  Fta('日本とシンガポールの協定', ['jp', 'sg'], 2002),
  Fta('日本とメキシコの協定', ['jp', 'mx'], 2005),
  Fta('日本とタイの協定', ['jp', 'th'], 2007),
  Fta('日本とインドネシアの協定', ['jp', 'id'], 2008),
  Fta('日本とフィリピンの協定', ['jp', 'ph'], 2008),
  Fta('日本とベトナムの協定', ['jp', 'vn'], 2009),
  Fta('日本とインドの協定', ['jp', 'in'], 2011),
  Fta('日本とオーストラリアの協定', ['jp', 'au'], 2015),
  Fta('環太平洋の協定（CPTPP）', ['jp', 'ca', 'mx', 'au', 'sg', 'vn'], 2018),
  Fta('日本とEUの協定', ['jp', 'de', 'fr', 'it', 'es'], 2019),
  Fta('日本と英国の協定', ['jp', 'uk'], 2021),
  Fta('地域的な包括的経済連携（RCEP）', ['jp', 'cn', 'kr', 'au', 'id', 'th', 'vn', 'ph', 'sg'], 2022, phase: 15),
  Fta('韓国とASEANの協定', ['kr', 'id', 'th', 'ph', 'sg', 'vn'], 2007),
  Fta('韓国とEUの協定', ['kr', 'de', 'fr', 'it', 'es', 'uk'], 2011),
  Fta('米韓自由貿易協定', ['us', 'kr'], 2012),
  Fta('韓国と中国の協定', ['kr', 'cn'], 2015, phase: 15),
  Fta('米国とシンガポールの協定', ['us', 'sg'], 2004),
  Fta('米国とオーストラリアの協定', ['us', 'au'], 2005),
  Fta('EUとメキシコの協定', ['mx', 'de', 'fr', 'it', 'es', 'uk'], 2000),
  Fta('EUと南アフリカの協定', ['za', 'de', 'fr', 'it', 'es', 'uk'], 2000, phase: 12),
  Fta('EUとカナダの協定', ['ca', 'de', 'fr', 'it', 'es'], 2017, phase: 7),
  Fta('EUとシンガポールの協定', ['sg', 'de', 'fr', 'it', 'es'], 2019),
  Fta('EUとベトナムの協定', ['vn', 'de', 'fr', 'it', 'es'], 2020),
  Fta('オーストラリアと中国の協定', ['au', 'cn'], 2015),
  Fta('インドとASEANの協定', ['in', 'id', 'th', 'ph', 'sg', 'vn'], 2010),
];

/// 貿易摩擦（[to] が [from] から入る物に、[y0]年[m0]月から [y1] 年の終わりまで関税を上乗せする。%）
class Friction {
  final String to, from, ja;
  final int y0, m0, y1;
  final double add;
  const Friction(this.to, this.from, this.y0, this.m0, this.y1, this.add, this.ja);
}

const List<Friction> FRICTIONS = [
  Friction('us', 'jp', 1987, 4, 1991, 4, '日米の半導体摩擦'),
  Friction('us', 'cn', 2018, 7, 2099, 15, '米中の貿易摩擦'),
  Friction('cn', 'us', 2018, 7, 2099, 15, '米中の貿易摩擦'),
  Friction('cn', 'au', 2020, 5, 2023, 10, '中国とオーストラリアの貿易摩擦'),
];

// ===== 輸送 =====
/// 国の位置（緯度・経度。主な港や都市のあたり）
const Map<String, (double, double)> GEO = {
  'jp': (35.5, 139.8), 'cn': (31.2, 121.5), 'kr': (35.1, 129.0), 'tw': (22.6, 120.3), 'in': (19.0, 72.8), 'id': (-6.1, 106.8), //
  'th': (13.1, 100.9), 'vn': (10.8, 106.7), 'ph': (14.6, 121.0), 'sg': (1.3, 103.8), 'us': (34.0, -118.2), 'ca': (49.3, -123.1), //
  'mx': (19.2, -96.1), 'br': (-23.9, -46.3), 'uk': (51.5, 0.0), 'de': (53.5, 10.0), 'fr': (49.5, 0.1), 'it': (44.4, 8.9), //
  'es': (39.5, -0.3), 'ru': (59.9, 30.3), 'sa': (21.5, 39.2), 'ng': (6.5, 3.4), 'za': (-29.9, 31.0), 'au': (-33.9, 151.2),
};

/// 陸でつながっている（トラックと鉄道で運べる）国の組。英国と大陸は1994年の海峡トンネルから
const Map<String, int> LAND = {
  'us/ca': 0, 'us/mx': 0, 'ca/mx': 0, 'de/fr': 0, 'de/it': 0, 'fr/it': 0, 'fr/es': 0, 'de/es': 0, 'it/es': 0, //
  'uk/fr': 1994, 'uk/de': 1994, 'uk/it': 1994, 'uk/es': 1994, 'cn/vn': 0, 'th/sg': 0, 'cn/ru': 1992, 'de/ru': 1992, 'ru/fr': 1992,
};

/// 港がコンテナ船にほぼ移った年（それより前は海の運賃が高く、遅い）
const Map<String, int> CONTAINER_YEAR = {
  'jp': 1975, 'us': 1970, 'uk': 1972, 'de': 1970, 'fr': 1972, 'it': 1975, 'es': 1978, 'ca': 1972, 'au': 1975, 'kr': 1978, //
  'tw': 1978, 'sg': 1975, 'th': 1985, 'ph': 1987, 'id': 1990, 'in': 1995, 'cn': 1990, 'vn': 2000, 'br': 1990, 'mx': 1993, //
  'sa': 1985, 'ng': 2006, 'za': 1985, 'ru': 2000,
};

/// 海の運賃（ふつうの品の値段に対する割合・1万km）。2021〜22年はコンテナ不足で跳ね上がった。2024年は紅海の迂回
const List<(int, double)> SEA_BASE = [(1980, .075), (1990, .062), (2000, .048), (2010, .042), (2019, .036), (2020, .045), (2021, .09), (2022, .065), (2023, .036), (2024, .048), (2025, .042)];

/// 空の運賃（同じ物差し。距離にあまり寄らない）。2020〜21年は旅客便が止まって上がった
const List<(int, double)> AIR_BASE = [(1980, .26), (1990, .2), (2000, .15), (2010, .12), (2019, .1), (2020, .16), (2021, .15), (2022, .12), (2025, .1)];

/// 陸の運賃（1,000km）
const List<(int, double)> LAND_BASE = [(1980, .016), (2000, .012), (2025, .01)];

/// 運ぶ手段の名前（日本語。英語は trade_en.dart）
const Map<String, String> SHIP_MODE_JA = {'sea': '船', 'air': '飛行機', 'land': 'トラック・鉄道', 'home': '国内'};

// ===== 交通とインフラ =====
/// 電気が届き、止まらないか（0〜1。1980・1990・2000・2010・2020・2025年）
const Map<String, List<double>> POWER = {
  'cn': [.6, .75, .92, .98, 1, 1], 'kr': [.97, 1, 1, 1, 1, 1], 'tw': [.98, 1, 1, 1, 1, 1], 'in': [.3, .45, .55, .72, .93, .97], //
  'id': [.25, .45, .85, .93, .97, .99], 'th': [.5, .75, .85, .95, .99, 1], 'vn': [.25, .35, .75, .95, .99, 1], 'ph': [.45, .6, .75, .85, .95, .97], //
  'mx': [.8, .88, .95, .99, 1, 1], 'br': [.75, .87, .94, .99, 1, 1], 'ru': [.95, .95, .95, .97, .98, .98], 'sa': [.85, .95, .98, 1, 1, 1], //
  'ng': [.25, .3, .4, .48, .55, .6], 'za': [.5, .6, .7, .8, .75, .8],
};

/// 道路と物流の整い具合（0〜1。同じ年の並び）。電気・道路が無い国は 1（整っている）
const Map<String, List<double>> ROAD = {
  'jp': [.85, .88, .9, .92, .93, .93], 'us': [.9, .9, .92, .92, .92, .92], 'de': [.9, .9, .92, .93, .93, .93], 'uk': [.85, .86, .88, .9, .9, .9], //
  'fr': [.85, .86, .88, .88, .88, .88], 'it': [.75, .78, .8, .8, .8, .8], 'es': [.65, .72, .8, .85, .85, .85], 'ca': [.85, .86, .88, .88, .88, .88], //
  'au': [.8, .82, .85, .86, .86, .86], 'kr': [.6, .75, .85, .88, .9, .9], 'tw': [.65, .75, .82, .85, .88, .88], 'sg': [.85, .9, .92, .95, .95, .95], //
  'cn': [.3, .38, .55, .72, .85, .88], 'in': [.3, .33, .4, .52, .65, .68], 'id': [.3, .36, .45, .5, .6, .63], 'th': [.4, .5, .62, .7, .75, .77], //
  'vn': [.2, .25, .38, .5, .65, .7], 'ph': [.35, .38, .45, .5, .55, .57], 'mx': [.45, .5, .6, .62, .65, .66], 'br': [.45, .5, .55, .58, .6, .6], //
  'ru': [.45, .45, .45, .55, .6, .55], 'sa': [.55, .62, .7, .75, .8, .82], 'ng': [.2, .22, .27, .3, .35, .36], 'za': [.5, .55, .62, .65, .65, .62],
};

/// ネットを使う人の割合（0〜1。1995・2000・2005・2010・2015・2020・2025年）
const Map<String, List<double>> TELE = {
  'jp': [.02, .3, .67, .78, .91, .9, .93], 'us': [.09, .43, .68, .72, .75, .91, .93], 'kr': [.01, .45, .74, .84, .9, .97, .98], //
  'cn': [0, .02, .085, .34, .5, .7, .78], 'tw': [.02, .28, .58, .71, .8, .9, .92], 'in': [0, .005, .024, .075, .17, .43, .56], //
  'id': [0, .01, .036, .11, .22, .54, .7], 'th': [0, .037, .15, .22, .39, .78, .88], 'vn': [0, .003, .13, .31, .45, .7, .79], //
  'ph': [0, .02, .05, .25, .36, .5, .75], 'sg': [.03, .36, .61, .71, .79, .92, .94], 'ca': [.04, .51, .72, .8, .89, .92, .94], //
  'mx': [0, .05, .17, .31, .57, .72, .8], 'br': [0, .03, .21, .41, .58, .81, .85], 'uk': [.02, .26, .7, .85, .92, .95, .96], //
  'de': [.02, .3, .69, .82, .87, .9, .93], 'fr': [.02, .14, .43, .77, .78, .85, .88], 'it': [.01, .23, .35, .54, .58, .7, .86], //
  'es': [.01, .13, .48, .66, .79, .94, .95], 'ru': [0, .02, .15, .43, .7, .85, .9], 'sa': [0, .02, .13, .41, .7, .98, .99], //
  'ng': [0, .001, .035, .11, .24, .36, .45], 'za': [.01, .05, .08, .24, .52, .7, .75], 'au': [.03, .47, .63, .76, .85, .9, .95],
};

const List<int> INFRA_YEARS = [1980, 1990, 2000, 2010, 2020, 2025];
const List<int> TELE_YEARS = [1995, 2000, 2005, 2010, 2015, 2020, 2025];

// ===== 海外の難しさ =====
/// 政治の不安定さ（0〜1。政変・国有化の起きやすさ。1980・1990・2000・2010・2020・2025年）。無い国は 0.06
const Map<String, List<double>> POLRISK = {
  'it': [.15, .15, .12, .12, .12, .12], 'es': [.3, .15, .1, .1, .1, .1], 'uk': [.08, .08, .08, .08, .1, .08], 'fr': [.08, .08, .08, .08, .1, .1], //
  'sg': [.1, .1, .08, .08, .08, .08], 'kr': [.35, .25, .15, .12, .12, .12], 'tw': [.2, .15, .15, .12, .15, .2], 'cn': [.45, .45, .35, .3, .35, .4], //
  'in': [.4, .4, .3, .25, .25, .25], 'id': [.4, .4, .55, .3, .3, .3], 'th': [.3, .3, .3, .35, .3, .3], 'vn': [.6, .5, .35, .3, .3, .3], //
  'ph': [.5, .5, .35, .35, .35, .35], 'mx': [.35, .4, .3, .3, .35, .35], 'br': [.45, .5, .3, .3, .35, .35], 'ru': [.6, .6, .55, .45, .55, .85], //
  'sa': [.35, .35, .3, .3, .3, .3], 'ng': [.7, .65, .55, .55, .55, .55], 'za': [.55, .55, .35, .35, .35, .4],
};

/// 送金の制限（国, 始まりの年, 終わりの年, 利益のうち国の外へ出せない割合）
const List<(String, int, int, double)> CAPCTL = [
  ('cn', 1980, 1993, .6), ('cn', 1994, 2015, .25), ('cn', 2016, 2017, .35), ('cn', 2018, 2099, .25), //
  ('in', 1980, 1991, .5), ('in', 1992, 2099, .1), ('br', 1980, 1994, .4), ('mx', 1982, 1991, .3), //
  ('ru', 1991, 2006, .35), ('ru', 2022, 2099, .8), ('ng', 1980, 1995, .5), ('ng', 2016, 2023, .35), //
  ('vn', 1980, 2010, .3), ('ph', 1980, 1992, .3), ('za', 1980, 1995, .3), ('th', 1980, 1991, .15), ('kr', 1980, 1991, .2), ('tw', 1980, 1987, .3),
];

/// 税の取り決め（二重の課税を避ける条約）が、その国とほぼ結ばれた年。無ければ送るときに1割を取られる
const Map<String, int> TREATY_YEAR = {
  'tw': 2012, 'sa': 2010, 'vn': 1995, 'cn': 1985, 'in': 1990, 'id': 1985, 'th': 1985, 'ph': 1985, 'ru': 1996, 'za': 1996, 'mx': 1995, 'ng': 2020,
};

/// 会社を作るのにかかった日数（世界銀行 Doing Business。2004・2010・2020年）。1990年代より前は2004年の1.5倍とする
const Map<String, List<double>> STARTDAYS = {
  'jp': [31, 23, 11], 'us': [5, 6, 4], 'cn': [48, 37, 9], 'in': [89, 30, 18], 'id': [151, 60, 13], 'th': [33, 32, 6], //
  'vn': [50, 44, 16], 'ph': [50, 52, 33], 'sg': [8, 3, 1.5], 'kr': [22, 14, 4], 'tw': [48, 42, 10], 'mx': [58, 9, 8], //
  'br': [152, 120, 17], 'ca': [3, 5, 2], 'uk': [18, 13, 4.5], 'de': [45, 18, 8], 'fr': [8, 7, 4], 'it': [13, 10, 11], //
  'es': [114, 47, 12.5], 'ru': [36, 30, 10], 'sa': [64, 5, 1.5], 'ng': [44, 34, 7], 'za': [38, 22, 40], 'au': [2, 2, 2],
};

/// 文化の近さで分けた組（同じ組は近い）
const Map<String, String> CULT_GROUP = {
  'jp': 'ea', 'kr': 'ea', 'cn': 'ea', 'tw': 'ea', 'th': 'sea', 'vn': 'sea', 'id': 'sea', 'ph': 'sea', 'sg': 'sea', //
  'us': 'an', 'uk': 'an', 'ca': 'an', 'au': 'an', 'de': 'eu', 'fr': 'eu', 'it': 'eu', 'es': 'eu', 'mx': 'la', 'br': 'la', //
  'in': 'in', 'ru': 'ru', 'sa': 'me', 'ng': 'af', 'za': 'af',
};

/// 言葉の近さの組（同じ組の言葉は、まったく違う言葉より通じやすい）
const Map<String, String> LANG_GROUP = {'jp': 'ea', 'zh': 'ea', 'ko': 'ea', 'es': 'ro', 'pt': 'ro', 'it': 'ro', 'fr': 'ro', 'en': 'ge', 'de': 'ge'};

/// 災害の起きやすさ（地震・台風・洪水。1 がふつう）
const Map<String, double> HAZARD = {
  'jp': 1.4, 'tw': 1.3, 'ph': 1.5, 'id': 1.3, 'th': 1.1, 'cn': 1.0, 'in': 1.0, 'vn': 1.1, 'us': .8, 'mx': 1.0, 'kr': .6, //
  'sg': .2, 'uk': .3, 'de': .3, 'fr': .3, 'it': .6, 'es': .4, 'ca': .4, 'au': .6, 'br': .5, 'ru': .5, 'sa': .3, 'ng': .7, 'za': .5,
};

/// 実際に起きた、仕入れと現場が止まる出来事（国・年・月・止まる月の数・現場の落ち込み・仕入れの止まり方・名前）
class StopDef {
  final String c, ja;
  final int y, m, months;
  final double unit, sup;
  const StopDef(this.c, this.y, this.m, this.months, this.unit, this.sup, this.ja);
}

const List<StopDef> STOPS = [
  StopDef('sa', 1990, 8, 6, .08, .3, '湾岸危機'),
  StopDef('jp', 1995, 1, 3, .05, .3, '阪神・淡路大震災'),
  StopDef('tw', 1999, 9, 2, .1, .45, '台湾の大地震'),
  StopDef('us', 2001, 9, 1, .03, .2, '米国の同時多発テロ'),
  StopDef('us', 2002, 10, 1, .02, .25, '米国西海岸の港の封鎖'),
  StopDef('cn', 2003, 3, 3, .12, .2, 'SARS の流行'),
  StopDef('jp', 2011, 3, 4, .1, .5, '東日本大震災'),
  StopDef('th', 2011, 10, 4, .15, .6, 'タイの大洪水'),
  StopDef('cn', 2020, 2, 3, .4, .6, '新型コロナの封鎖'),
  StopDef('in', 2020, 4, 2, .4, .5, '新型コロナの封鎖'),
  StopDef('vn', 2021, 7, 3, .3, .5, '新型コロナの封鎖'),
  StopDef('cn', 2022, 4, 2, .15, .35, '上海の封鎖'),
];

// ===== 仕入れの網 =====
/// 仕入れる物の種類。[density] 重さ（運賃の倍）・[timeCost] 運ぶ1日あたりの重さ（値段に対する割合）・
/// [tariffK] 関税の倍（原油や鉱石はほぼかからず、農産物は高い）・[commodity] 相場の品（どこで買っても値段は同じ）・
/// [sources] 主な産地（国, 産地になった年）
class InputGroup {
  final String ja;
  final double density, timeCost, tariffK;
  final bool commodity;
  final List<(String, int)> sources;
  const InputGroup(this.ja, this.density, this.timeCost, this.tariffK, this.commodity, this.sources);
}

const Map<String, InputGroup> GROUPS = {
  'oil': InputGroup('原油・燃料', .5, .0002, .1, true, [('sa', 0), ('ru', 1992), ('us', 0), ('ng', 0), ('mx', 0), ('ca', 0), ('id', 0), ('au', 1990), ('br', 2005)]),
  'ore': InputGroup('鉱石・木材', 2.0, .0002, .1, true, [('au', 0), ('br', 0), ('ca', 0), ('za', 0), ('in', 0), ('ru', 1992), ('cn', 0)]),
  'grain': InputGroup('農産物・食材', 1.2, .0008, 1.5, true, [('us', 0), ('au', 0), ('br', 0), ('ca', 0), ('th', 0), ('vn', 1995), ('cn', 1985), ('id', 0)]),
  'goods': InputGroup('日用品・雑貨', 1.0, .0006, 1.0, false, [('cn', 1985), ('th', 0), ('vn', 2000), ('id', 0), ('in', 1995), ('mx', 0), ('it', 0), ('de', 0), ('us', 0), ('kr', 0), ('tw', 0)]),
  'parts': InputGroup('機械と電気の部品', .6, .0015, 1.0, false, [('jp', 0), ('de', 0), ('us', 0), ('tw', 0), ('kr', 0), ('cn', 1995), ('th', 1990), ('mx', 1995), ('vn', 2010), ('ph', 1995), ('sg', 0)]),
  'chip': InputGroup('半導体の材料と装置', .1, .004, .6, false, [('jp', 0), ('us', 0), ('tw', 1987), ('kr', 1990), ('de', 0), ('sg', 1990), ('cn', 2010)]),
  'fiber': InputGroup('糸・布', 1.0, .001, 1.3, false, [('cn', 1985), ('in', 0), ('vn', 1995), ('id', 0), ('th', 0), ('us', 0), ('it', 0)]),
  'pharma': InputGroup('薬の原料', .1, .002, .5, false, [('in', 1990), ('cn', 1995), ('de', 0), ('us', 0), ('it', 0), ('fr', 0), ('jp', 0), ('uk', 0)]),
  'tech': InputGroup('サーバーと通信の機器', .2, .002, .3, false, [('us', 0), ('tw', 0), ('cn', 2000), ('kr', 0), ('jp', 0)]),
};

/// 業種ごとの仕入れ（種類, 原価のうち外から買う部分の割合, 止まると作れなくなるか（false なら高くつくだけ））。
/// ここに無い業種は仕入れの網を持たない（人で稼ぐ・場をつくる業種など）
const Map<String, (String, double, bool)> INPUT_OF = {
  // 燃料を使う
  'oil': ('oil', .7, false), 'gasstation': ('oil', .6, false), 'power': ('oil', .45, false), 'citygas': ('oil', .55, false),
  'lpg': ('oil', .55, false), 'chem': ('oil', .45, false), 'airline': ('oil', .3, false), 'ship': ('oil', .3, false),
  'logi': ('oil', .15, false), 'courier': ('oil', .1, false), 'taxi': ('oil', .1, false), 'bus': ('oil', .1, false), 'coal': ('oil', .1, false),
  // 鉱石・木材
  'steel': ('ore', .5, false), 'shipbuild': ('ore', .3, false), 'paper': ('ore', .4, false), 'nuclear': ('ore', .1, false),
  // 食材
  'foodmaker': ('grain', .4, false), 'frozen': ('grain', .35, false), 'confect': ('grain', .3, false), 'drink': ('grain', .2, false),
  'sake': ('grain', .2, false), 'fishery': ('grain', .4, false), 'plantmeat': ('grain', .3, false), 'gyudon': ('grain', .3, false),
  'ff': ('grain', .25, false), 'famires': ('grain', .2, false), 'ramen': ('grain', .2, false), 'sushi': ('grain', .3, false),
  'teishoku': ('grain', .15, false), 'bento': ('grain', .15, false), 'cafe': ('grain', .3, false), 'mealkit': ('grain', .2, false),
  'boba': ('grain', .3, false), 'dining': ('grain', .15, false), 'izakaya': ('grain', .15, false), 'yatai': ('grain', .1, false),
  'farm': ('grain', .2, false), 'culturedmeat': ('grain', .1, false),
  // 日用品を仕入れて売る
  'konbini': ('goods', .2, false), 'yen100': ('goods', .5, false), 'homecenter': ('goods', .35, false), 'kadenstore': ('goods', .4, false),
  'depart': ('goods', .2, false), 'drug': ('goods', .25, false), 'pet': ('goods', .3, false), 'furniture': ('goods', .35, false),
  'wholesale': ('goods', .3, false), 'shosha': ('goods', .2, false), 'cosme': ('goods', .25, false), 'cdshop': ('goods', .1, false),
  'dagashi': ('goods', .2, false), 'ec': ('goods', .2, false), 'flea': ('goods', .05, false),
  // 部品を組み立てる（止まると作れない）
  'kaden': ('parts', .35, true), 'pc': ('parts', .5, true), 'handset': ('parts', .5, true), 'camera': ('parts', .35, true),
  'watch': ('parts', .3, true), 'mdplayer': ('parts', .4, true), 'printer3d': ('parts', .35, true), 'robot': ('parts', .3, true),
  'android': ('parts', .35, true), 'ev': ('parts', .4, true), 'auto': ('parts', .3, true), 'battery': ('parts', .4, true),
  'gridbatt': ('parts', .4, true), 'medequip': ('parts', .3, true), 'machine': ('parts', .35, true), 'solar': ('parts', .4, true),
  'wind': ('parts', .3, true), 'drone': ('parts', .3, true), 'flyingcar': ('parts', .35, true), 'smarthome': ('parts', .3, true),
  'keitaishop': ('parts', .3, false),
  // 半導体（止まると作れない）
  'semi': ('chip', .35, true), 'lcd': ('chip', .35, true), 'parts': ('chip', .3, true), 'semiequip': ('chip', .3, true), 'quantum': ('chip', .2, true),
  // 糸と布
  'apparel': ('fiber', .35, true), 'textile': ('fiber', .5, false), 'kimono': ('fiber', .3, false), 'printing': ('fiber', .2, false),
  // 薬
  'pharma': ('pharma', .25, true), 'generic': ('pharma', .4, true), 'pharmacy': ('pharma', .3, false),
  // 機器
  'datacenter': ('tech', .3, true), 'cloud': ('tech', .1, false), 'telecom': ('tech', .15, false), 'ai': ('tech', .15, true),
};

/// 仕入れの値段の基準（国内で、ふつうの国内の運び賃で買ったときの倍。今の業種の利益率は、これを前提にしている）
const double landedRef = 1.04;

/// 仕入れ先を1つ増やすごとに上がる、外から買う物の値段（まとめ買いの値引きが減る・品質を合わせる手間）
const double diversifyPremium = .025;

/// 仕入れ先の数の上限
const int maxSuppliers = 4;

/// 2点の間のおおよその距離（km。大円）
double geoKm(String a, String b) {
  final p = GEO[a], q = GEO[b];
  if (p == null || q == null) return 8000;
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(q.$1 - p.$1), dLon = rad(q.$2 - p.$2);
  final h = math.pow(math.sin(dLat / 2), 2) + math.cos(rad(p.$1)) * math.cos(rad(q.$1)) * math.pow(math.sin(dLon / 2), 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(h.toDouble())));
}
