// ignore_for_file: constant_identifier_names
/// 人の仕組みの定数（1.1.0+27。企画書「人を現実の人材に寄せる」と「人の画面」）。
/// 細かい能力の名前と分野・学歴と専攻・資格・技術の分野・国と時代の働き方の慣習
library;

/// 細かい能力の名前（鍵は models.dart の skKeys）
const Map<String, String> SK_JA = {
  'lead': '統率',
  'judge': '判断',
  'nego': '交渉',
  'sales': '営業',
  'mkt': 'マーケティング',
  'ops': '店舗運営',
  'tech': '技術',
  'prod': '生産管理',
  'fin': '財務',
  'acct': '会計',
  'hr': '人事',
  'law': '法務',
  'lang': '語学',
  'nInd': '業界の人脈',
  'nPol': '政界の人脈',
  'nBank': '銀行の人脈',
};

/// 能力の分野（名前・中の能力）
const List<(String, List<String>)> SK_GROUPS = [
  ('経営の能力', ['lead', 'judge', 'nego']),
  ('稼ぐ能力', ['sales', 'mkt', 'ops']),
  ('作る能力', ['tech', 'prod']),
  ('管理の能力', ['fin', 'acct', 'hr', 'law']),
  ('外との能力', ['lang', 'nInd', 'nPol', 'nBank']),
];

/// 4つの能力（統率・開発・営業・財務）の芯になる細かい能力（作るときに、4つの値からこの順に散らす）
const Map<String, List<String>> SK_OF_AB = {
  'tou': ['lead', 'judge', 'hr', 'ops'],
  'kai': ['tech', 'prod'],
  'ei': ['sales', 'mkt', 'nego'],
  'zai': ['fin', 'acct', 'law'],
};

/// 学歴の名前（0〜4）
const List<String> EDU_JA = ['高校', '専門学校・短大', '大学', '名門大学', '大学院'];

/// 専攻の名前と、伸ばす能力
const Map<String, String> MAJOR_JA = {'econ': '経済', 'law': '法律', 'eng': '工学', 'sci': '理学', 'med': '医学', 'lit': '文学', 'biz': '経営', 'info': '情報'};
const Map<String, List<String>> MAJOR_SK = {
  'econ': ['fin', 'judge'],
  'law': ['law', 'nego'],
  'eng': ['tech', 'prod'],
  'sci': ['tech', 'judge'],
  'med': ['tech'],
  'lit': ['lang', 'mkt'],
  'biz': ['mkt', 'acct'],
  'info': ['tech', 'mkt'],
};

/// 資格の名前
const Map<String, String> LIC_JA = {'doctor': '医師', 'lawyer': '弁護士', 'cpa': '会計士', 'pilot': 'パイロット'};

/// 資格が無いと始められない業種（業種の id → 要る資格）
const Map<String, String> IND_LIC = {
  'hospital': 'doctor',
  'clinic': 'doctor',
  'dental': 'doctor',
  'telemed': 'doctor',
  'airline': 'pilot',
};

/// 資格のある人の給料の相場の倍
const Map<String, double> LIC_PAY = {'doctor': 2.0, 'lawyer': 1.7, 'cpa': 1.35, 'pilot': 1.9};

/// 技術の分野の名前
const Map<String, String> TF_JA = {'soft': 'ソフト', 'mech': '機械', 'elec': '電気・電子', 'chem': '化学', 'med': '医療', 'civil': '建設'};

/// 業種の分類ごとの、効く技術の分野（分野が合わない技術は6割しか効かない）
const Map<String, String> CAT_TF = {
  'net': 'soft',
  'fut': 'soft',
  'money': 'soft',
  'fun': 'soft',
  'make': 'mech',
  'ene': 'elec',
  'med': 'med',
  'food': 'chem',
  'live': 'civil',
  'link': 'mech',
};

/// 名前の言葉（data.dart の NAMEC の値）ごとの、外国語の名前
const Map<String, String> LANG_JA = {
  'en': '英語',
  'zh': '中国語',
  'ko': '韓国語',
  'hi': 'ヒンディー語',
  'id': 'インドネシア語',
  'th': 'タイ語',
  'vi': 'ベトナム語',
  'tl': 'タガログ語',
  'es': 'スペイン語',
  'pt': 'ポルトガル語',
  'de': 'ドイツ語',
  'fr': 'フランス語',
  'it': 'イタリア語',
  'ru': 'ロシア語',
  'ar': 'アラビア語',
  'yo': 'ヨルバ語',
  'jp': '日本語@@lang',
};

/// 働き方の慣習（国と時代で変わる）。
/// [life] 終身雇用の強さ（0〜1。強いと中途の市場が薄く、解雇が重い）・[hop] 1年に辞める人の割合・
/// [senior] 年功の強さ（0〜1。強いと給料が年で決まる）・[union] 組合の強さ（0〜1）・[retire] 定年
class WorkNorm {
  final double life, hop, senior, union;
  final int retire;
  const WorkNorm(this.life, this.hop, this.senior, this.union, this.retire);
}

/// 国の組ごとの、1980年・2000年・2025年の慣習（あいだの年はならす）
const Map<String, List<WorkNorm>> NORM_TABLE = {
  // 日本: 終身雇用と年功が強く、2000年代から転職が当たり前に。定年は55→60（1986年）→65（2013年）
  'jp': [WorkNorm(.9, .04, .85, .5, 55), WorkNorm(.72, .07, .65, .3, 60), WorkNorm(.5, .1, .45, .17, 65)],
  // 韓国: 日本に近いが、1997年の通貨危機のあとで崩れが速い
  'kr': [WorkNorm(.82, .06, .8, .4, 55), WorkNorm(.55, .1, .6, .3, 58), WorkNorm(.35, .15, .45, .2, 60)],
  // 中国: 国の会社の「鉄の飯碗」から、2000年代に転職の国へ
  'cn': [WorkNorm(.95, .01, .6, .1, 60), WorkNorm(.5, .12, .4, .1, 60), WorkNorm(.3, .16, .3, .1, 60)],
  // 台湾・シンガポール: 転職が多く、成果で払う
  'tw': [WorkNorm(.5, .12, .5, .1, 60), WorkNorm(.4, .14, .4, .1, 62), WorkNorm(.3, .15, .3, .1, 65)],
  // 米国・英国・カナダ・オーストラリア: 解雇しやすく、転職が多い
  'us': [WorkNorm(.2, .2, .2, .3, 65), WorkNorm(.15, .22, .15, .2, 65), WorkNorm(.1, .24, .1, .15, 67)],
  // 欧州の大陸: 解雇が重く、組合が強い
  'eu': [WorkNorm(.6, .08, .5, .7, 63), WorkNorm(.5, .09, .4, .6, 63), WorkNorm(.45, .1, .35, .5, 65)],
  // ロシア: 1991年に体制が変わったあとの国
  'ru': [WorkNorm(.3, .2, .3, .2, 60), WorkNorm(.3, .2, .3, .2, 60), WorkNorm(.3, .18, .3, .2, 62)],
  // 新興国: 転職が多く、年功はほどほど
  'em': [WorkNorm(.4, .15, .5, .3, 58), WorkNorm(.3, .17, .4, .3, 60), WorkNorm(.25, .18, .35, .25, 62)],
};

/// 国 → 慣習の組
const Map<String, String> NORM_GROUP = {
  'jp': 'jp',
  'kr': 'kr',
  'cn': 'cn',
  'tw': 'tw',
  'sg': 'tw',
  'us': 'us',
  'uk': 'us',
  'ca': 'us',
  'au': 'us',
  'de': 'eu',
  'fr': 'eu',
  'it': 'eu',
  'es': 'eu',
  'ru': 'ru',
};

/// 健康の注意の線（これを下回ると「体を壊しそう」）・燃え尽きる線
const double healthWarn = 40, healthBreak = 18;

/// 給料が相場のこの割合を下回ると、不満が出て引き抜かれやすくなる
const double payLowRatio = .88;
