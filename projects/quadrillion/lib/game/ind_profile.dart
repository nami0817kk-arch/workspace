// ignore_for_file: constant_identifier_names
/// 業種ごとの稼ぎ方の型と特性（1.1.0+26 から。企画書「現実に寄せる」の「業種ごとの特性」）。
///
/// - 200業種のすべてを、7つの稼ぎの型（店・工場・ネット・人・許認可・当たり外れ・インフラ）のどれかに当てる（[KIND_OF]）
/// - 業種ごとに約30の特性を持つ（[IndProfile]）。型ごとの決まった値に、分類（食・ものづくり…）と業種ごとの上書きを重ねて作る
/// - 1単位（店・ライン・利用者10万人・人・拠点・作品・設備）の初期投資と月の売上は、2020年の円の実額。時代の物価だけを掛ける
library;

import '../l10n/l10n.dart';
import 'models_static.dart';

/// 稼ぎの型（並びは画面と図鑑の順）
const List<String> KINDS = ['shop', 'factory', 'net', 'people', 'license', 'hit', 'infra'];

/// 型の名前
const Map<String, String> KIND_JA = {
  'shop': '店舗型',
  'factory': '工場型',
  'net': 'ネット型',
  'people': '人で稼ぐ型',
  'license': '許認可型',
  'hit': '当たり外れ型',
  'infra': 'インフラ型',
};

/// 型の伸ばし方（企画書の表）
const Map<String, String> KIND_HOW_JA = {
  'shop': '物件・店長・本部の指導員・物流をそろえて店を出す',
  'factory': 'ラインを増やすのに1〜3年。稼働率が低いと赤字',
  'net': '利用者数×課金率。開発と宣伝で集め、解約で減る',
  'people': '人数×単価×稼働率。採用と育成の速さで決まる',
  'license': '参入に許可と年単位の時間。入れば安定',
  'hit': '作品ごとの賭け。当たれば大きく、外れれば赤字',
  'infra': '数年がかりの巨額の投資。できれば長く稼ぐ',
};

/// 1単位の呼び名
const Map<String, String> KIND_UNIT_JA = {
  'shop': '店',
  'factory': 'ライン',
  'net': '利用者10万人',
  'people': '人',
  'license': '拠点',
  'hit': '作品',
  'infra': '設備',
};

/// 1単位を数える言い方（{0} に数）
const Map<String, String> KIND_COUNT_JA = {
  'shop': '{0}店',
  'factory': '{0}ライン',
  'net': '{0}万人',
  'people': '{0}人@@units',
  'license': '{0}拠点',
  'hit': '{0}作品',
  'infra': '{0}設備',
};

/// 1単位に1人要る責任者（無い型は null）・育つまでの月
const Map<String, String?> KIND_LEAD_JA = {'shop': '店長', 'factory': '工場長', 'net': null, 'people': null, 'license': '支店長', 'hit': null, 'infra': null};
const Map<String, int> KIND_LEAD_MONTHS = {'shop': 6, 'factory': 12, 'license': 9};

/// 本部で見る人（指導員など）と、1人で見られる単位の数
const Map<String, String> KIND_SV_JA = {
  'shop': '指導員',
  'factory': '品質の担当',
  'net': '開発チーム',
  'people': 'シニア',
  'license': '管理の担当',
  'hit': 'プロデューサー',
  'infra': '現場監督',
};
const Map<String, double> KIND_SV_RATIO = {'shop': 8, 'factory': 3, 'net': 5, 'people': 8, 'license': 10, 'hit': 3, 'infra': 2};

/// 開くまでの月（最短・最長）
const Map<String, (int, int)> KIND_OPEN = {'shop': (3, 6), 'factory': (12, 36), 'net': (1, 2), 'people': (1, 2), 'license': (6, 12), 'hit': (6, 18), 'infra': (24, 60)};

/// 開いてから売上が育ちきるまでの月（その間も固定費は丸ごとかかる。黒字まで1〜2年の元）
const Map<String, int> KIND_RAMP = {'shop': 15, 'factory': 8, 'net': 3, 'people': 6, 'license': 18, 'hit': 0, 'infra': 12};

/// 固定費（家賃・光熱費・物流・保険・修繕）が、育ちきった1単位の売上の何割か
const Map<String, double> KIND_FIXED = {'shop': .22, 'factory': .30, 'net': .25, 'people': .10, 'license': .25, 'hit': .15, 'infra': .45};

/// 固定費の内訳の割合（家賃・光熱費・物流費・保険料・修繕と更新）
const Map<String, List<double>> KIND_FIX_SPLIT = {
  'shop': [.55, .2, .1, .05, .1],
  'factory': [.15, .35, .15, .1, .25],
  'net': [.1, .5, 0, .1, .3],
  'people': [.7, .1, 0, .1, .1],
  'license': [.45, .15, .05, .15, .2],
  'hit': [.3, .2, .2, .1, .2],
  'infra': [.1, .3, .1, .15, .35],
};

/// 都市圏を「都心・郊外」に分けて持つ型（ほかの型は国ごとに1つ）
const Set<String> KIND_ZONED = {'shop', 'factory', 'license', 'infra'};

/// 立地ごとの1単位の売上の倍（都心・郊外・地方）
const Map<String, List<double>> KIND_ZONE_SALES = {
  'shop': [1.38, 1, .74],
  'factory': [1.1, 1, .95],
  'license': [1.3, 1, .75],
  'infra': [1.15, 1, .9],
};

/// 立地ごとの固定費の倍（都心は家賃が高い）
const Map<String, List<double>> KIND_ZONE_COST = {
  'shop': [1.4, 1, .8],
  'factory': [1.6, 1, .8],
  'license': [1.4, 1, .8],
  'infra': [1.3, 1, .85],
};

/// 人口1人あたりの店の置きやすさ（都心・郊外・地方。上限を立地に分けるときに使う）
const Map<String, List<double>> KIND_ZONE_DENSITY = {
  'shop': [1.6, 1, .75],
  'factory': [.1, .8, 1.3],
  'license': [2, 1, .6],
  'infra': [.5, 1, 1.2],
};

/// 立地の名前
const List<String> ZONE_JA = ['都心', '郊外', '地方'];

/// 代金をもらうまでの月（売掛）
const Map<String, double> KIND_PAYLAG = {'shop': 0, 'factory': 2, 'net': .5, 'people': 2, 'license': 0, 'hit': 3, 'infra': 1};

/// 200業種の稼ぎの型（全部を当てる。test/units_test.dart で数を確かめる）
const Map<String, String> KIND_OF = {
  // 店舗型（小売り・飲食・サービスの店）
  'yatai': 'shop', 'teishoku': 'shop', 'ff': 'shop', 'konbini': 'shop', 'bento': 'shop', 'dining': 'shop', 'hotel': 'shop',
  'depart': 'shop', 'apparel': 'shop', 'furniture': 'shop', 'rentalvideo': 'shop', 'keitaishop': 'shop', 'cdshop': 'shop',
  'karaoke': 'shop', 'arcade': 'shop', 'gyudon': 'shop', 'sushi': 'shop', 'cafe': 'shop', 'drug': 'shop', 'yen100': 'shop',
  'homecenter': 'shop', 'kadenstore': 'shop', 'juku': 'shop', 'eikaiwa': 'shop', 'travel': 'shop', 'wedding': 'shop', 'gym': 'shop',
  'pet': 'shop', 'funeral': 'shop', 'dagashi': 'shop', 'ramen': 'shop', 'izakaya': 'shop', 'famires': 'shop', 'boba': 'shop',
  'sento': 'shop', 'laundry': 'shop', 'photolab': 'shop', 'salon': 'shop', 'storage': 'shop', 'kimono': 'shop', 'gasstation': 'shop',
  'pachinko': 'shop', 'bowling': 'shop', 'seitai': 'shop',
  // 工場型（製造業）
  'frozen': 'factory', 'kaden': 'factory', 'auto': 'factory', 'semi': 'factory', 'foodmaker': 'factory', 'steel': 'factory',
  'ev': 'factory', 'pc': 'factory', 'newspaper': 'factory', 'cosme': 'factory', 'chem': 'factory', 'shipbuild': 'factory',
  'sake': 'factory', 'drink': 'factory', 'farm': 'factory', 'semiequip': 'factory', 'parts': 'factory', 'lcd': 'factory',
  'robot': 'factory', 'flyingcar': 'factory', 'culturedmeat': 'factory', 'confect': 'factory', 'fishery': 'factory',
  'plantmeat': 'factory', 'smarthome': 'factory', 'textile': 'factory', 'camera': 'factory', 'watch': 'factory', 'mdplayer': 'factory',
  'handset': 'factory', 'machine': 'factory', 'paper': 'factory', 'battery': 'factory', 'printer3d': 'factory', 'printing': 'factory',
  'generic': 'factory', 'medequip': 'factory', 'android': 'factory', 'vertfarm': 'factory',
  // ネット型（利用者数×課金率）
  'portal': 'net', 'ec': 'net', 'sns': 'net', 'app': 'net', 'video': 'net', 'cloud': 'net', 'ai': 'net', 'rideshare': 'net',
  'delivery': 'net', 'minpaku': 'net', 'matching': 'net', 'ebook': 'net', 'security': 'net', 'metaverse': 'net', 'mealkit': 'net',
  'crowdfund': 'net', 'mobilesite': 'net', 'blog': 'net', 'jobboard': 'net', 'flea': 'net', 'review': 'net', 'saas': 'net',
  'livestream': 'net',
  // 人で稼ぐ型（人数×単価×稼働率）
  'shosha': 'people', 'adagency': 'people', 'haken': 'people', 'keibi': 'people', 'hikkoshi': 'people', 'construct': 'people',
  'consult': 'people', 'sier': 'people', 'reform': 'people', 'wholesale': 'people', 'callcenter': 'people', 'translation': 'people',
  'webdesign': 'people', 'cro': 'people',
  // 許認可型（銀行・電力・通信・医療など。参入に許可と年単位）
  'power': 'license', 'telecom': 'license', 'bank': 'license', 'secur': 'license', 'insur': 'license', 'netsec': 'license',
  'pay': 'license', 'tv': 'license', 'hospital': 'license', 'care': 'license', 'pager': 'license', 'airline': 'license',
  'taxi': 'license', 'hoiku': 'license', 'card': 'license', 'consumer': 'license', 'crypto': 'license', 'waste': 'license',
  'citygas': 'license', 'lpg': 'license', 'powerretail': 'license', 'bus': 'license', 'pawn': 'license', 'lease': 'license',
  'fx': 'license', 'reit': 'license', 'asset': 'license', 'robo': 'license', 'bnpl': 'license', 'exchange': 'license',
  'radio': 'license', 'clinic': 'license', 'dental': 'license', 'telemed': 'license', 'pharmacy': 'license', 'rojin': 'license',
  // 当たり外れ型（作品・新薬ごとの賭け）
  'movie': 'hit', 'game': 'hit', 'music': 'hit', 'pharma': 'hit', 'quantum': 'hit', 'publish': 'hit', 'anime': 'hit',
  'autodrive': 'hit', 'gene': 'hit', 'regen': 'hit', 'esports': 'hit', 'vtuber': 'hit', 'talent': 'hit', 'proteam': 'hit',
  'bci': 'hit', 'longevity': 'hit', 'weather': 'hit',
  // インフラ型（鉄道・発電・物流網など。数年がかりの巨額の投資）
  'estate': 'infra', 'oil': 'infra', 'solar': 'infra', 'logi': 'infra', 'ship': 'infra', 'rail': 'infra', 'space': 'infra',
  'fusion': 'infra', 'drone': 'infra', 'spacetravel': 'infra', 'hydrogen': 'infra', 'smr': 'infra', 'seabed': 'infra',
  'coal': 'infra', 'nuclear': 'infra', 'wind': 'infra', 'gridbatt': 'infra', 'geothermal': 'infra', 'warehouse': 'infra',
  'courier': 'infra', 'datacenter': 'infra', 'dialup': 'infra', 'themepark': 'infra', 'golf': 'infra', 'spaceelev': 'infra',
  'moon': 'infra', 'ccs': 'infra',
};

/// 1単位の初期投資（2020年の円）と、育ちきった1単位の月の売上が初期投資の何割か（回転）。ここに無い業種は型の決まりで作る
const Map<String, (double, double)> UNIT_OVERRIDE = {
  'konbini': (3e7, .5),
  'drug': (1e8, .6),
  'yen100': (3e7, .35),
  'gasstation': (8e7, 1),
  'kadenstore': (1e9, .3),
  'homecenter': (1.5e9, .2),
  'depart': (2e10, .12),
  'hotel': (3e9, .035),
  'dining': (1e8, .1),
  'ff': (6e7, .25),
  'gyudon': (4e7, .3),
  'sushi': (1e8, .2),
  'cafe': (4e7, .2),
  'ramen': (2e7, .25),
  'famires': (1e8, .15),
  'izakaya': (3e7, .25),
  'pachinko': (1e9, .25),
  'auto': (1e11, .15),
  'semi': (3e11, .04),
  'steel': (2e11, .05),
  'airline': (1.5e10, .06),
  'bank': (1e9, .05),
  'hospital': (3e9, .06),
  'rail': (5e11, .012),
};

/// 業種の特性（約30）。画面には目立つ3〜4個を札で出し、全部は図鑑で見せる
class IndProfile {
  final String id, kind;

  // 稼ぎの形
  /// 利益率の相場・固定費の重さ（0〜1）・規模の効き方（0〜1）
  final double mg, fixed, scale;

  /// 客の種類（b2c 一般 / b2b 会社 / gov 役所）
  final String cust;

  // お金の入り方
  /// 代金をもらうまでの月・定期収入の割合・解約のしやすさ（月の率）・値上げのしやすさ（0〜1）
  final double payLag, recur, churn, pricing;

  // 作る・運ぶ
  /// 主な原価（cost の名前の鍵）
  final String costKey;

  /// 開発の長さ（月）と成功率・設備の寿命（年）・運びやすさ（0〜1）・原料を外国に頼る割合（0〜1）・技術の寿命（年）
  final double devMonths, devHit, life, ship, imported, techLife;

  /// 在庫（rot 腐る / trend 流行で古くなる / none 無い / keep 持てる）
  final String inv;

  // 時と外の力
  /// 季節の波・天候の影響・景気への弱さ・金利への弱さ・ブームのなりやすさ（0〜1）
  final double season, weather, sens, rateSens, boom;

  /// 為替の向き（1 自国の通貨が安いと得・-1 損・0 どちらでもない）
  final int fx;

  // 人
  /// 要る人材（効く能力の鍵）・熟練に要る年数・辞めやすさ（0〜1）
  final String talent;
  final double skillYears, quit;

  /// 24時間・夜の仕事があるか
  final bool night;

  // 社会と規制
  /// 入りにくさ（0〜1）・公共事業への頼り（0〜1）・環境の規制（0〜1）・個人情報の重さ（0〜1）・事故と訴訟（0〜1）
  final double barrier, publicDep, env, privacy, liability;

  /// 国が値段を決めるか・評判の悪い業種か
  final bool priceReg, stigma;

  // 市場の形
  /// 業界の集まり方（0 乱立〜1 寡占）・下請けの構造があるか
  final double conc;
  final bool subcon;

  // 立ち上げ
  /// 立ち上げ（開くまで）の月・損益分岐までの年数
  final (int, int) open;
  final double breakEven;

  // 時代
  /// 生まれる年・頂点・沈み始め（0 は沈まない）
  final int born, peak, fall;

  // 1単位
  /// 1単位の初期投資（2020年の円）・育ちきった1単位の月の売上（2020年の円）
  final double unitCapex, unitRev;

  const IndProfile({
    required this.id,
    required this.kind,
    required this.mg,
    required this.fixed,
    required this.scale,
    required this.cust,
    required this.payLag,
    required this.recur,
    required this.churn,
    required this.pricing,
    required this.costKey,
    required this.devMonths,
    required this.devHit,
    required this.life,
    required this.ship,
    required this.imported,
    required this.techLife,
    required this.inv,
    required this.season,
    required this.weather,
    required this.sens,
    required this.rateSens,
    required this.boom,
    required this.fx,
    required this.talent,
    required this.skillYears,
    required this.quit,
    required this.night,
    required this.barrier,
    required this.publicDep,
    required this.env,
    required this.privacy,
    required this.liability,
    required this.priceReg,
    required this.stigma,
    required this.conc,
    required this.subcon,
    required this.open,
    required this.breakEven,
    required this.born,
    required this.peak,
    required this.fall,
    required this.unitCapex,
    required this.unitRev,
  });

  /// 特性の数（画面の「約30の特性」）
  static const int count = 37;

  /// 型の名前（今の言語）
  String get kindName => de(KIND_JA[kind]!);
}

/// 原価の名前
const Map<String, String> COST_JA = {
  'food': '食材',
  'goods': '仕入れの品',
  'parts': '部品と原料',
  'energy': '燃料と電気',
  'server': 'サーバーと開発',
  'people': '人の給料',
  'content': '制作費',
  'money': '集めたお金の利息',
  'land': '土地と建物',
};

/// 在庫の名前
const Map<String, String> INV_JA = {'rot': '腐る', 'trend': '流行で古くなる', 'none': '無い', 'keep': '持てる'};

/// 客の種類の名前
const Map<String, String> CUST_JA = {'b2c': '一般の客', 'b2b': '会社', 'gov': '役所'};

final Map<String, IndProfile> _profiles = {};

/// 業種の特性（初めて引いたときに作って覚える）
IndProfile profileOf(Industry ind) => _profiles[ind.id] ??= _make(ind);

/// 業種の稼ぎの型
String kindOf(Industry ind) => KIND_OF[ind.id] ?? 'shop';

bool _in(String id, List<String> l) => l.contains(id);

IndProfile _make(Industry i) {
  final k = kindOf(i);
  final id = i.id, cat = i.cat;
  // 1単位の初期投資と回転
  final ov = UNIT_OVERRIDE[id];
  double capex, turn;
  switch (k) {
    case 'shop':
      capex = i.capex * .06;
      if (capex < (i.capex < 1.5e7 ? i.capex : 1.5e7)) capex = i.capex < 1.5e7 ? i.capex : 1.5e7;
      turn = .4;
    case 'factory':
      capex = i.capex * .35;
      turn = .1;
    case 'net':
      capex = (i.capex * .3).clamp(5e6, 3e9).toDouble();
      turn = .12;
    case 'people':
      final w = wageCatBase[cat] ?? 4e6;
      capex = w * .4;
      final bill = id == 'shosha' || id == 'wholesale'
          ? 6.0
          : id == 'consult'
              ? 3.5
              : id == 'construct' || id == 'sier'
                  ? 2.5
                  : 1.7;
      turn = w * bill / 12 / capex;
    case 'license':
      capex = i.capex * .1;
      if (capex < 2e7) capex = 2e7;
      turn = .12;
    case 'hit':
      capex = i.capex * .3;
      if (capex < 1e7) capex = 1e7;
      turn = .12;
    default:
      capex = i.capex * .5;
      turn = .035;
  }
  if (ov != null) {
    capex = ov.$1;
    turn = ov.$2;
  }
  final fixed = KIND_FIXED[k]!;
  // 型の決まりに、分類と業種の上書きを重ねる
  final food = cat == 'food', make = cat == 'make', ene = cat == 'ene', money = cat == 'money', med = cat == 'med', fun = cat == 'fun';
  final tech = cat == 'net' || cat == 'fut';
  return IndProfile(
    id: id,
    kind: k,
    mg: i.mg,
    fixed: fixed + (k == 'infra' || k == 'factory' ? .1 : 0),
    scale: switch (k) { 'net' => .9, 'infra' => .8, 'factory' => .7, 'license' => .6, 'shop' => .5, 'hit' => .4, _ => .2 },
    cust: _in(id, ['construct', 'waste', 'keibi', 'power', 'rail', 'bus', 'nuclear', 'smr', 'fusion', 'seabed', 'space', 'ccs', 'weather', 'spaceelev', 'moon'])
        ? 'gov'
        : k == 'people' || make && !_in(id, ['kaden', 'auto', 'pc', 'cosme', 'camera', 'watch', 'mdplayer', 'handset', 'ev', 'flyingcar', 'smarthome', 'android', 'confect', 'sake', 'drink']) ||
                _in(id, ['cloud', 'saas', 'security', 'datacenter', 'warehouse', 'logi', 'ship', 'lease', 'semiequip', 'cro', 'adagency', 'shosha', 'wholesale', 'printing'])
            ? 'b2b'
            : 'b2c',
    payLag: KIND_PAYLAG[k]! + (_in(id, ['construct', 'shosha', 'wholesale']) ? 1 : 0),
    recur: _in(id, ['telecom', 'power', 'citygas', 'insur', 'cloud', 'saas', 'video', 'gym', 'juku', 'eikaiwa', 'care', 'rojin', 'hoiku', 'security', 'newspaper', 'keibi', 'lease', 'storage', 'powerretail', 'lpg'])
        ? .85
        : k == 'license' || k == 'infra'
            ? .6
            : k == 'net'
                ? .4
                : k == 'shop' || k == 'hit'
                    ? .05
                    : .3,
    churn: k == 'net'
        ? (_in(id, ['cloud', 'saas', 'security']) ? .015 : _in(id, ['matching', 'app', 'metaverse', 'livestream', 'mobilesite', 'blog']) ? .06 : .035)
        : k == 'hit'
            ? .05
            : 0,
    pricing: _in(id, ['dining', 'hotel', 'cosme', 'watch', 'pharma', 'semiequip', 'cloud', 'saas', 'consult', 'themepark', 'golf', 'proteam'])
        ? .8
        : k == 'license'
            ? .3
            : food || k == 'shop'
                ? .35
                : .5,
    costKey: food
        ? 'food'
        : k == 'shop'
            ? 'goods'
            : k == 'factory'
                ? 'parts'
                : ene || _in(id, ['airline', 'ship', 'rail', 'logi', 'courier', 'taxi', 'bus'])
                    ? 'energy'
                    : k == 'net'
                        ? 'server'
                        : k == 'people'
                            ? 'people'
                            : k == 'hit'
                                ? 'content'
                                : money
                                    ? 'money'
                                    : 'land',
    devMonths: switch (k) { 'net' => 3, 'shop' => 2, 'people' => 2, 'license' => 6, 'factory' => 12, 'hit' => 14, _ => 18 } + (_in(id, ['pharma', 'gene', 'regen', 'longevity']) ? 60 : 0),
    devHit: _in(id, ['pharma', 'gene', 'regen', 'longevity', 'bci', 'quantum', 'fusion'])
        ? .1
        : k == 'hit'
            ? .25
            : .5,
    life: switch (k) { 'infra' => 40, 'factory' => 20, 'license' => 25, 'shop' => 12, 'hit' => 3, 'net' => 4, _ => 8 },
    ship: food && !_in(id, ['frozen', 'confect', 'sake', 'drink'])
        ? .2
        : k == 'shop' || k == 'people' || k == 'license'
            ? 0
            : _in(id, ['semi', 'parts', 'pharma', 'generic', 'medequip', 'watch', 'cosme'])
                ? .95
                : k == 'net'
                    ? 1
                    : .5,
    imported: ene || _in(id, ['steel', 'chem', 'textile', 'paper', 'foodmaker', 'frozen', 'gyudon', 'ff', 'cafe', 'airline', 'ship', 'gasstation', 'plantmeat', 'kaden', 'pc', 'handset'])
        ? .7
        : food
            ? .4
            : make
                ? .35
                : .1,
    techLife: tech
        ? 6
        : _in(id, ['semi', 'lcd', 'pc', 'handset', 'mdplayer', 'pager', 'camera', 'battery', 'semiequip', 'parts'])
            ? 5
            : k == 'factory'
                ? 15
                : 30,
    inv: food || _in(id, ['dining', 'konbini', 'bento', 'farm', 'vertfarm', 'fishery', 'culturedmeat'])
        ? 'rot'
        : _in(id, ['apparel', 'kimono', 'boba', 'cdshop', 'rentalvideo', 'mdplayer', 'handset', 'pc', 'camera', 'game', 'music', 'publish', 'movie', 'anime'])
            ? 'trend'
            : k == 'shop' || k == 'factory'
                ? 'keep'
                : 'none',
    season: _in(id, ['travel', 'hotel', 'themepark', 'golf', 'airline', 'kimono', 'funeral', 'wedding', 'drink', 'sake', 'apparel', 'juku', 'homecenter', 'pachinko', 'karaoke', 'izakaya', 'bowling', 'solar', 'citygas', 'lpg', 'farm', 'confect'])
        ? .6
        : food || fun
            ? .3
            : .1,
    weather: _in(id, ['themepark', 'golf', 'farm', 'solar', 'wind', 'drink', 'yatai', 'boba', 'airline', 'travel', 'construct', 'bowling', 'fishery'])
        ? .7
        : food || k == 'shop'
            ? .25
            : .05,
    sens: i.sens,
    rateSens: _in(id, ['estate', 'reit', 'construct', 'reform', 'lease', 'consumer', 'card', 'bank', 'secur', 'auto', 'ship', 'airline', 'storage'])
        ? .8
        : k == 'infra'
            ? .6
            : .2,
    boom: _in(id, ['boba', 'crypto', 'metaverse', 'karaoke', 'arcade', 'bowling', 'pager', 'mdplayer', 'blog', 'vtuber', 'ai', 'fx', 'mobilesite', 'esports', 'livestream'])
        ? .9
        : tech || k == 'hit'
            ? .6
            : .2,
    fx: make && !_in(id, ['foodmaker', 'frozen', 'confect', 'sake', 'drink', 'paper', 'textile', 'newspaper', 'printing'])
        ? 1
        : _in(id, ['hotel', 'travel', 'themepark', 'minpaku', 'shosha', 'ship', 'anime', 'game'])
            ? 1
            : food || ene || _in(id, ['airline', 'gasstation', 'kadenstore', 'apparel', 'yen100', 'pc', 'handset'])
                ? -1
                : 0,
    talent: i.key,
    skillYears: switch (k) { 'license' => 8, 'factory' => 6, 'infra' => 8, 'hit' => 6, 'people' => _in(id, ['consult', 'sier']) ? 5 : 2, 'net' => 4, _ => 2 } +
        (med && k == 'license' ? 4 : 0),
    quit: _in(id, ['izakaya', 'callcenter', 'haken', 'care', 'rojin', 'konbini', 'ff', 'famires', 'gyudon', 'hikkoshi', 'keibi', 'taxi', 'courier', 'adagency', 'pachinko'])
        ? .75
        : k == 'shop' || k == 'people'
            ? .5
            : .25,
    night: _in(id, ['konbini', 'ff', 'gyudon', 'famires', 'izakaya', 'karaoke', 'hotel', 'hospital', 'care', 'rojin', 'keibi', 'taxi', 'courier', 'logi', 'rail', 'airline', 'power', 'telecom', 'datacenter', 'callcenter', 'semi', 'steel', 'chem', 'gasstation', 'laundry', 'sento', 'pachinko', 'bowling']),
    barrier: k == 'license'
        ? .85
        : k == 'infra'
            ? .8
            : _in(id, ['semi', 'auto', 'steel', 'chem', 'shipbuild', 'lcd', 'semiequip', 'pharma', 'gene', 'regen', 'quantum', 'airline'])
                ? .75
                : k == 'factory'
                    ? .45
                    : k == 'net'
                        ? .2
                        : .25,
    publicDep: _in(id, ['construct', 'rail', 'power', 'waste', 'keibi', 'care', 'rojin', 'hoiku', 'hospital', 'clinic', 'dental', 'pharmacy', 'space', 'nuclear', 'smr', 'fusion', 'bus', 'sier'])
        ? .7
        : k == 'infra'
            ? .4
            : .05,
    env: ene || _in(id, ['steel', 'chem', 'paper', 'auto', 'oil', 'coal', 'nuclear', 'waste', 'ship', 'airline', 'semi', 'textile', 'fishery', 'gasstation', 'ccs'])
        ? .8
        : k == 'factory'
            ? .4
            : .1,
    privacy: money || med || _in(id, ['sns', 'matching', 'ec', 'portal', 'jobboard', 'haken', 'telecom', 'cloud', 'saas', 'security', 'callcenter', 'wedding', 'juku', 'card', 'pay', 'flea', 'review', 'rideshare'])
        ? .8
        : k == 'net'
            ? .5
            : .1,
    liability: _in(id, ['airline', 'rail', 'bus', 'taxi', 'nuclear', 'smr', 'chem', 'pharma', 'generic', 'hospital', 'clinic', 'dental', 'care', 'rojin', 'hoiku', 'construct', 'auto', 'ev', 'autodrive', 'flyingcar', 'drone', 'food', 'ff', 'sushi', 'bento', 'frozen', 'foodmaker', 'themepark', 'gym', 'spacetravel', 'oil'])
        ? .8
        : .2,
    priceReg: _in(id, ['power', 'citygas', 'telecom', 'rail', 'bus', 'taxi', 'hospital', 'clinic', 'dental', 'pharmacy', 'care', 'rojin', 'hoiku', 'generic', 'pharma', 'tv', 'radio', 'water', 'insur', 'lpg']),
    stigma: _in(id, ['consumer', 'pachinko', 'crypto', 'fx', 'haken', 'pawn', 'coal', 'nuclear', 'oil', 'talent', 'bnpl']),
    conc: _in(id, ['konbini', 'telecom', 'power', 'citygas', 'airline', 'rail', 'semi', 'auto', 'steel', 'oil', 'portal', 'sns', 'cloud', 'ec', 'card', 'tv', 'bank', 'shipbuild', 'semiequip', 'lcd', 'nuclear', 'courier', 'pay', 'flea', 'drink'])
        ? .8
        : k == 'license' || k == 'infra'
            ? .6
            : k == 'net'
                ? .6
                : k == 'factory'
                    ? .45
                    : _in(id, ['yatai', 'teishoku', 'dagashi', 'salon', 'izakaya', 'ramen', 'seitai', 'reform', 'translation', 'webdesign', 'sento', 'kimono', 'cafe'])
                        ? .1
                        : .3,
    subcon: _in(id, ['construct', 'auto', 'kaden', 'sier', 'shipbuild', 'parts', 'printing', 'callcenter', 'haken', 'ev', 'android', 'machine', 'textile', 'anime', 'game', 'tv']),
    open: KIND_OPEN[k]!,
    breakEven: switch (k) { 'shop' => 1.5, 'factory' => 3, 'net' => 2, 'people' => 1, 'license' => 4, 'hit' => 2, _ => 10 },
    born: i.b,
    peak: i.p,
    fall: i.f,
    unitCapex: capex,
    unitRev: capex * turn,
  );
}

/// 分類ごとの現場の人1人の年の人件費（2020年の円。game.dart の wageByCat と同じ）
const Map<String, double> wageCatBase = {'food': 3e6, 'live': 3e6, 'make': 5e6, 'ene': 5e6, 'link': 4.5e6, 'money': 6.5e6, 'net': 6.5e6, 'med': 6.5e6, 'fun': 4e6, 'fut': 8e6};

/// 業種の札（目立つ特性を最大4つ。日本語の名前と、良いか悪いか）。画面の右上と図鑑に出す
List<(String, bool)> profileTags(IndProfile p) {
  final out = <(String, int, bool)>[];
  void add(String ja, int score, bool good) => out.add((ja, score, good));
  if (p.fixed >= .35) add('固定費が重い', 90, false);
  if (p.sens >= 1.2) add('景気に弱い', 85, false);
  if (p.sens <= .15) add('不況に強い', 85, true);
  if (p.barrier >= .8) add('入りにくい（許可・元手）', 80, true);
  if (p.churn >= .05) add('解約が多い', 75, false);
  if (p.kind == 'hit') add('当たり外れが大きい', 80, false);
  if (p.recur >= .8) add('毎月決まった収入', 78, true);
  if (p.priceReg) add('国が値段を決める', 70, false);
  if (p.conc >= .8) add('大手が寡占', 65, false);
  if (p.conc <= .1) add('小さな店が乱立', 60, true);
  if (p.season >= .6) add('季節で波がある', 60, false);
  if (p.weather >= .7) add('天気に左右される', 55, false);
  if (p.night) add('24時間・夜の仕事', 50, false);
  if (p.imported >= .7) add('原料を輸入に頼る', 55, false);
  if (p.fx > 0 && p.kind == 'factory') add('円安で得をする', 45, true);
  if (p.stigma) add('評判の悪い業種', 50, false);
  if (p.boom >= .9) add('ブームで急に伸び縮み', 60, false);
  if (p.inv == 'rot') add('在庫が腐る', 40, false);
  if (p.techLife <= 6) add('技術がすぐ古くなる', 58, false);
  if (p.subcon) add('下請けの構造', 35, false);
  if (p.scale >= .8) add('大きいほど強い', 52, true);
  if (p.payLag >= 2) add('代金の回収が遅い', 48, false);
  if (p.liability >= .8) add('事故と訴訟が怖い', 42, false);
  if (p.rateSens >= .8) add('金利に弱い', 46, false);
  out.sort((a, b) => b.$2.compareTo(a.$2));
  return [for (final x in out.take(4)) (x.$1, x.$3)];
}
