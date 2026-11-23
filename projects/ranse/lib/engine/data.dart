// マスタデータ。人口比などは戦国期の日本の概算。

/// 戦国期の日本の人口（概算）。「同じ身分の者が何人いたか」の計算に使う。
const kPopulation = 15000000;

const kRanksM = [
  '無役',
  '足軽',
  '足軽組頭',
  '馬廻',
  '侍大将',
  '城主',
  '家老',
  '宿老',
  '大名',
  '天下人',
];
const kRanksF = ['無役', '下女', '女中頭', '奥女中', '上臈', '御方', '老女', '大局', '正室', '女大名'];
const kStipend = [0, 4, 7, 12, 22, 40, 70, 110];
const kTroopCap = [0, 0, 15, 30, 60, 100, 180, 300];

class Promo {
  const Promo(this.merit, this.fav, this.troops);
  final int merit, fav, troops;
}

/// 昇進に要る条件。キーは「なる先の位」。
const kPromo = <int, Promo>{
  2: Promo(15, 20, 0),
  3: Promo(35, 30, 5),
  4: Promo(70, 35, 20),
  5: Promo(120, 40, 40),
  6: Promo(190, 50, 70),
  7: Promo(280, 55, 110),
};

class ClassDef {
  const ClassDef(
    this.id,
    this.name,
    this.w,
    this.rank,
    this.gold,
    this.m,
    this.mod,
    this.d,
  );
  final String id, name, d;

  /// 人口比（相対）。
  final double w;

  /// 十五歳で得る身分（嫡男の場合）。
  final int rank;
  final int gold;

  /// 乳幼児期の死亡倍率。
  final double m;
  final Map<String, int> mod;
}

const kClasses = <ClassDef>[
  ClassDef('beggar', '河原者・下人', 3, 0, 2, 1.8, {
    'bu': -3,
    'mi': -6,
  }, '世の底。それでも命は一つ。'),
  ClassDef('farmer', '農民', 74, 0, 3, 1.1, {'bu': 3}, '田を耕す百姓の子。'),
  ClassDef('fisher', '漁民・山の民', 4, 0, 3, 1.1, {'bu': 5, 'un': 3}, '海や山で生きる者の子。'),
  ClassDef('merchant', '町人・商人', 4, 0, 30, .9, {
    'chi': 5,
    'sei': 6,
  }, '銭の流れを知る家に生まれた。'),
  ClassDef('priest', '僧侶・神職の子', 1.5, 0, 8, .9, {
    'chi': 10,
    'sei': 3,
  }, '寺社で読み書きを学べる身。'),
  ClassDef('ronin', '浪人の子', 1, 0, 5, 1, {'bu': 8}, '刀だけは家にあった。'),
  ClassDef('ninja', '忍びの里の子', .15, 0, 6, 1.1, {
    'bu': 8,
    'chi': 5,
    'un': 2,
  }, '闇に生きる術を叩き込まれる。'),
  ClassDef('ashigaru', '足軽の子', 6, 1, 6, 1, {'bu': 4}, '父は足軽。主家に籍がある。'),
  ClassDef('lowsamurai', '下級武士の子', 1.8, 2, 15, .8, {
    'bu': 4,
    'chi': 3,
  }, 'わずかな知行をもつ武家。'),
  ClassDef('samurai', '上級武士の子', .4, 3, 40, .7, {
    'bu': 5,
    'chi': 6,
    'mi': 4,
  }, '馬廻に連なる名のある家。'),
  ClassDef('kokujin', '国人領主の子', .02, 5, 80, .6, {
    'bu': 6,
    'chi': 6,
    'sei': 6,
    'mi': 6,
  }, '小さな城と領民を継ぐ身。'),
  ClassDef('daimyo', '大名の子', .0008, 8, 150, .6, {
    'bu': 8,
    'chi': 8,
    'sei': 10,
    'mi': 10,
  }, '一国を継ぐ家。生まれながらの頂点。'),
];

ClassDef classById(String id) => kClasses.firstWhere((c) => c.id == id);

class Region {
  const Region(this.n, this.w, this.f);
  final String n;
  final double w;
  final List<String> f;
}

const kRegions = <Region>[
  Region('尾張', 6, ['織田']),
  Region('美濃', 5, ['斎藤']),
  Region('三河', 4, ['松平']),
  Region('駿河', 4, ['今川']),
  Region('甲斐', 3, ['武田']),
  Region('信濃', 4, ['武田']),
  Region('越後', 5, ['上杉']),
  Region('相模', 6, ['北条']),
  Region('近江', 6, ['浅井', '六角']),
  Region('山城', 6, ['三好']),
  Region('摂津', 6, ['三好']),
  Region('越前', 4, ['朝倉']),
  Region('安芸', 4, ['毛利']),
  Region('出雲', 4, ['尼子']),
  Region('土佐', 3, ['長宗我部']),
  Region('薩摩', 5, ['島津']),
  Region('豊後', 4, ['大友']),
  Region('肥前', 4, ['龍造寺']),
  Region('陸奥', 6, ['伊達']),
  Region('出羽', 4, ['最上']),
  Region('常陸', 5, ['佐竹']),
  Region('会津', 3, ['蘆名']),
];

/// 国のおおよその位置（経度・緯度）。遠すぎる家に奉公・仕官する選択肢を出さないために使う。
const kRegionPos = <String, (double, double)>{
  '尾張': (136.9, 35.2),
  '美濃': (136.8, 35.6),
  '三河': (137.3, 34.9),
  '駿河': (138.4, 35.0),
  '甲斐': (138.6, 35.7),
  '信濃': (138.2, 36.3),
  '越後': (138.9, 37.5),
  '相模': (139.3, 35.4),
  '近江': (136.1, 35.2),
  '山城': (135.8, 35.0),
  '摂津': (135.5, 34.7),
  '越前': (136.2, 35.9),
  '安芸': (132.5, 34.4),
  '出雲': (132.8, 35.4),
  '土佐': (133.5, 33.6),
  '薩摩': (130.5, 31.6),
  '豊後': (131.6, 33.2),
  '肥前': (130.0, 33.3),
  '陸奥': (140.9, 38.3),
  '出羽': (140.3, 38.2),
  '常陸': (140.4, 36.4),
  '会津': (139.9, 37.5),
};

/// 国から家までの、おおよその隔たり（その家の国のうち最も近いもの）。
/// 表にない家（明智など、のちに立った家）は京に本拠があるとみなす。
double factionDistance(String region, String faction) {
  final (x, y) = kRegionPos[region] ?? kRegionPos['山城']!;
  double d(String r) {
    final (a, b) = kRegionPos[r]!;
    return (a - x) * (a - x) + (b - y) * (b - y);
  }

  final homes = [
    for (final r in kRegions)
      if (r.f.contains(faction)) r.n,
  ];
  if (homes.isEmpty) return d('山城');
  return homes.map(d).reduce((a, b) => a < b ? a : b);
}

/// 家と家の隔たり（[a] の家の国のうち、[b] に最も近いものから測る）。
double factionGap(String a, String b) {
  final homes = [
    for (final r in kRegions)
      if (r.f.contains(a)) r.n,
  ];
  if (homes.isEmpty) return factionDistance('山城', b);
  return homes
      .map((r) => factionDistance(r, b))
      .reduce((x, y) => x < y ? x : y);
}

/// [from]（国、または家）から近い順に並べ替えた候補の、先頭 [n] 件。
List<T> nearest<T>(
  Iterable<T> candidates,
  String Function(T) nameOf, {
  String? region,
  String? faction,
  int n = 3,
}) {
  double d(T x) => region != null
      ? factionDistance(region, nameOf(x))
      : factionGap(faction!, nameOf(x));
  final l = candidates.toList()..sort((a, b) => d(a).compareTo(d(b)));
  return l.take(n).toList();
}

const kFactionBase = <String, double>{
  '織田': 28,
  '斎藤': 22,
  '松平': 15,
  '今川': 50,
  '武田': 55,
  '上杉': 45,
  '北条': 52,
  '浅井': 20,
  '六角': 30,
  '三好': 55,
  '朝倉': 30,
  '毛利': 40,
  '尼子': 32,
  '長宗我部': 15,
  '島津': 28,
  '大友': 40,
  '龍造寺': 14,
  '伊達': 35,
  '最上': 18,
  '佐竹': 20,
  '蘆名': 18,
};

/// 生まれつきの能力。特性の効果をこれに足し込む。
class Abil {
  Abil(this.bu, this.chi, this.sei, this.mi, this.un, this.maxhp);
  int bu, chi, sei, mi, un, maxhp;
}

/// 特性の段（2026-11-24 ユーザー「影響が強いほどレア」）。効き目が強いほど出にくい。
/// [chance] は、生まれたときにこの段の特性のどれか一つを持つ確率（段ごとに一度ずつ籤を引く。`rollBirth`）。
enum TraitTier {
  common('よくある', .25),
  uncommon('珍しい', .075),
  rare('稀', .025),
  mythic('幻', .0035);

  const TraitTier(this.label, this.chance);
  final String label;
  final double chance;
}

void _noFx(Abil a) {}

bool _onlyF(ClassDef c, bool female) => female;
bool _notDaimyo(ClassDef c, bool female) => c.id != 'daimyo';
bool _commonBorn(ClassDef c, bool female) => c.rank == 0;
bool _lowBorn(ClassDef c, bool female) => c.rank <= 2;

/// 生まれつきの特性（2026-11-24 に13から100へ。4回に分けて作り、1回目で仕組みと25の特性の場面を作った）。
/// どの特性も遊びの中で効く（能力に数字を足すだけのものは作らない。能力の上げ下げは元の13にだけ残した）。
/// 場面のある特性は `trait_scenes.dart` の `kTraitScenesDone`（4回目で百すべて。場面の続きは `trait_scenes2.dart`〜`trait_scenes4.dart`）。
class Trait {
  const Trait(
    this.id,
    this.name,
    this.tier,
    this.desc, {
    this.fx = _noFx,
    this.ok,
    this.w = 1,
  });
  final String id, name;
  final TraitTier tier;

  /// 画面に出す一言の説明（数字は出さない。2026-11-23 ユーザー「特性の説明がない」）。
  final String desc;

  /// 生まれつきの能力の上げ下げ（元の13だけ）。
  final void Function(Abil) fx;

  /// この身分・性別に付くか。null なら誰にでも付く。
  final bool Function(ClassDef cls, bool female)? ok;

  /// 段の中での付きやすさ（既定1）。
  final double w;

  bool fits(ClassDef cls, bool female) => ok == null || ok!(cls, female);
}

/// 100の特性。段の目安は よくある40・珍しい32・稀20・幻8。行末の「効く所」は覚え書き
/// （「済」は1回目で場面・手・倍率を作ったもの。ほかは2回目以降に作る）。
final kTraits = <Trait>[
  // ================================================================ よくある（40）
  // ---- 体
  Trait(
    'power',
    '剛力',
    TraitTier.common,
    '生まれつき腕っぷしが強い。力仕事でも喧嘩でも頼りにされる',
    fx: (a) => a.bu += 15,
  ), // 済: 武。場面「力比べ」
  Trait(
    'sickly',
    '病弱',
    TraitTier.common,
    '体が弱い。病にかかりやすく、重くなりやすい',
    fx: (a) => a.maxhp -= 30,
    w: 1.5,
  ), // 済: 乳幼児・大人の病死（game.dart）。場面は4回目（trait_scenes4.dart）
  Trait(
    'hardy',
    '頑健',
    TraitTier.common,
    '体が丈夫。病にも深手にも強い',
    fx: (a) => a.maxhp += 20,
    w: 1.5,
  ), // 済: 乳幼児・大人の病死・熱病（game.dart・childhood.dart）。場面は4回目（trait_scenes4.dart）
  Trait(
    'glutton',
    '大食い',
    TraitTier.common,
    '人の倍は食う。よく働くが、飢えの年にはこたえる',
  ), // 済: 場面「大食いの賭け」
  Trait(
    'drinker',
    '酒豪',
    TraitTier.common,
    'いくら飲んでも崩れない。酒の席で人の本音を聞ける',
  ), // 済: 場面「酒の席」
  Trait(
    'loud',
    '声が大きい',
    TraitTier.common,
    '腹の底から声が出る。戦場でも市でもよく通る',
  ), // 済: 場面「火事の夜」・合戦の名乗り
  Trait(
    'nimble',
    '手先が器用',
    TraitTier.common,
    '細かい手仕事が得意。壊れた物を直してしまう',
  ), // 済（2回目）: 場面と効き方は trait_scenes2.dart
  Trait(
    'light_sleeper',
    '眠りが浅い',
    TraitTier.common,
    '小さな物音でも目を覚ます。夜討ちや盗人に気づきやすい',
  ), // 済（2回目）: 場面と効き方は trait_scenes2.dart
  Trait(
    'walker',
    '健脚',
    TraitTier.common,
    '一日に人の倍の道を歩く。旅も使い走りも苦にしない',
  ), // 済（3回目）: 場面と効き方は trait_scenes3.dart
  Trait('big', '大柄', TraitTier.common, '人より頭ひとつ大きい。目立つぶん、狙われもする'), // 済（3回目）: 場面と効き方は trait_scenes3.dart（女性の場面は4回目）
  Trait(
    'small',
    '小柄',
    TraitTier.common,
    '体が小さく身軽。人ごみに紛れ、狭い所にもぐり込める',
  ), // 済（3回目）: 場面と効き方は trait_scenes3.dart
  Trait(
    'swimmer',
    '泳ぎ達者',
    TraitTier.common,
    '水を怖がらない。川も海も泳いで渡る',
  ), // 済（2回目）: 場面と効き方は trait_scenes2.dart
  // ---- 心
  Trait(
    'amb',
    '野心家',
    TraitTier.common,
    '上を狙う気性。下剋上の誘いが来やすく、成し遂げやすい',
  ), // 済: 下剋上（game.dart・adult.dart）。場面は4回目（trait_scenes4.dart）
  Trait(
    'loyal',
    '義理堅い',
    TraitTier.common,
    '恩を忘れない。主君の信頼を得やすいが、主家を裏切りにくい',
  ), // 済: 下剋上・主君の信頼（game.dart・adult.dart）。場面は4回目（trait_scenes4.dart）
  Trait(
    'coward',
    '臆病',
    TraitTier.common,
    '危うい所に近づきたがらない。手柄は遠いが、命は拾いやすい',
  ), // 済: 場面「陣触れの夜」
  Trait(
    'hothead',
    '短気',
    TraitTier.common,
    '頭に血がのぼりやすい。侮られると黙っていられない',
  ), // 済: 場面「侮りの言葉」
  Trait(
    'kind',
    '情け深い',
    TraitTier.common,
    '弱い者を見捨てられない。恩も厄介ごとも背負い込む',
  ), // 済（2回目）: 場面と効き方は trait_scenes2.dart
  Trait(
    'pious',
    '信心深い',
    TraitTier.common,
    '神仏を篤く敬う。寺社の者に好かれ、迷いの時に支えを得る',
  ), // 済: 場面「旅の聖」
  Trait(
    'lustful',
    '好色',
    TraitTier.common,
    '色恋に目がない。縁も揉め事も向こうからやって来る',
  ), // 済（4回目）: 場面と効き方は trait_scenes4.dart
  Trait(
    'frugal',
    '倹約家',
    TraitTier.common,
    '銭を無駄にしない。蓄えは増えるが、けちと陰口も叩かれる',
  ), // 済: 場面「蓄えの壺」
  Trait(
    'lazy',
    '怠け者',
    TraitTier.common,
    '楽な道を選びたがる。無理をしないので長持ちはする',
  ), // 済（4回目）: 場面と効き方は trait_scenes4.dart
  Trait(
    'stubborn',
    '頑固',
    TraitTier.common,
    '一度決めたら曲げない。信は得るが、折れどきを誤る',
  ), // 済（3回目）: 場面と効き方は trait_scenes3.dart
  Trait(
    'cheerful',
    '楽天家',
    TraitTier.common,
    'くよくよしない。悪い年も笑って越す',
  ), // 済（3回目）: 場面と効き方は trait_scenes3.dart
  Trait(
    'worrier',
    '心配性',
    TraitTier.common,
    '先の悪いことばかり考える。備えはよいが、心が休まらない',
  ), // 済（3回目）: 場面と効き方は trait_scenes3.dart
  Trait(
    'curious',
    '物好き',
    TraitTier.common,
    '見慣れぬものに首を突っ込む。南蛮の品にも妖しい噂にも',
  ), // 済（3回目）: 場面と効き方は trait_scenes3.dart
  Trait(
    'honest',
    '正直者',
    TraitTier.common,
    '嘘がつけない。信じられるが、隠し事には向かない',
  ), // 済（2回目）: 場面と効き方は trait_scenes2.dart
  Trait(
    'vain',
    '見栄っ張り',
    TraitTier.common,
    '人前で格好をつけたがる。身の丈を越えた買い物もする',
  ), // 済（4回目）: 場面と効き方は trait_scenes4.dart
  Trait(
    'shy',
    '人見知り',
    TraitTier.common,
    '知らない人の前では口が重い。親しい者とは深く結ばれる',
  ), // 済（4回目）: 場面と効き方は trait_scenes4.dart
  Trait(
    'gambler',
    '博打好き',
    TraitTier.common,
    '賭け事に目がない。勝てば大きいが、負けも大きい',
  ), // 済（2回目）: 場面と効き方は trait_scenes2.dart
  Trait(
    'filial',
    '親孝行',
    TraitTier.common,
    '親を何より大事にする。親の病や老いには家を空けられない',
  ), // 済（3回目）: 場面と効き方は trait_scenes3.dart
  Trait(
    'patient',
    '辛抱強い',
    TraitTier.common,
    '苦しい時に耐えられる。籠城や長い修行で折れない',
  ), // 済（3回目）: 場面と効き方は trait_scenes3.dart
  // ---- 才
  Trait(
    'abacus',
    '算盤上手',
    TraitTier.common,
    '勘定に明るい。政に秀で、稼ぎも増える',
    fx: (a) => a.sei += 15,
  ), // 済: 政・稼ぎ（adult.dart）。場面は4回目（trait_scenes4.dart）
  Trait(
    'beauty',
    '人好きのする顔',
    TraitTier.common,
    '誰にでも好かれやすい。初めて会う人にも心を開かせる',
    fx: (a) => a.mi += 15,
  ), // 済: 魅。場面「通りすがりの縁」
  Trait(
    'singer',
    '唄がうまい',
    TraitTier.common,
    '田植え唄も舟唄も、聞く者の手を止めさせる',
  ), // 済（2回目）: 場面と効き方は trait_scenes2.dart
  Trait(
    'cook',
    '料理上手',
    TraitTier.common,
    'ありあわせで旨いものを作る。台所から人の心をつかむ',
  ), // 済（2回目）: 場面と効き方は trait_scenes2.dart
  Trait(
    'animals',
    '生き物に好かれる',
    TraitTier.common,
    '犬も馬もすぐなつく。荒れた獣もおとなしくなる',
  ), // 済（3回目）: 場面と効き方は trait_scenes3.dart
  Trait(
    'weather',
    '空読み',
    TraitTier.common,
    '雲と風で明日の天気を当てる。田にも船にも戦にも役立つ',
  ), // 済（2回目）: 場面と効き方は trait_scenes2.dart
  Trait(
    'handwriting',
    '達筆',
    TraitTier.common,
    '字が美しい。代筆を頼まれ、書状で人に覚えられる',
  ), // 済（2回目）: 場面と効き方は trait_scenes2.dart
  // ---- 生まれ
  Trait(
    'birthmark',
    '痣がある',
    TraitTier.common,
    '顔に目立つ痣がある。一度で人に覚えられ、気味悪がられもする',
  ), // 済（4回目）: 場面と効き方は trait_scenes4.dart
  Trait(
    'big_family',
    '親類が多い',
    TraitTier.common,
    'あちこちに叔父や従兄がいる。頼る先も頼られる先も多い',
  ), // 済（4回目）: 場面と効き方は trait_scenes4.dart
  // ================================================================ 珍しい（32）
  // ---- 体
  Trait(
    'swift',
    '俊足',
    TraitTier.uncommon,
    '誰より足が速い。合戦で危うい場を走り抜け、使いにも立てられる',
  ), // 済: 合戦の危うさ（battles.dart）。場面「早駆けの使い」
  Trait(
    'nighteye',
    '夜目',
    TraitTier.uncommon,
    '暗がりでも物がよく見える。夜の合戦や夜道に強い',
  ), // 済: 合戦の危うさ（battles.dart）。場面「闇の中の影」
  Trait(
    'keen_ear',
    '地獄耳',
    TraitTier.uncommon,
    '遠くのささやきまで聞こえる。噂も陰口も耳に入る',
  ), // 済（3回目）: 場面と効き方は trait_scenes3.dart
  Trait(
    'iron_gut',
    '鉄の胃袋',
    TraitTier.uncommon,
    '何を食べても腹を壊さない。毒にも傷んだ物にも強い',
  ), // 済（2回目）: 場面と効き方は trait_scenes2.dart
  Trait(
    'painless',
    '痛みに強い',
    TraitTier.uncommon,
    '深手を負っても顔色を変えない。戦場で倒れにくい',
  ), // 済（2回目）: 場面と効き方は trait_scenes2.dart
  Trait(
    'lefty',
    '左利き',
    TraitTier.uncommon,
    '刀も箸も左で持つ。打ち合いで相手の調子を狂わせる',
  ), // 済（4回目）: 場面と効き方は trait_scenes4.dart
  Trait(
    'longlived',
    '長命の血筋',
    TraitTier.uncommon,
    '祖父も祖母も長生きだった。老いてなお足腰が強い',
  ), // 済（2回目）: 場面と効き方は trait_scenes2.dart
  Trait(
    'sea_legs',
    '船に強い',
    TraitTier.uncommon,
    '荒れた海でも酔わない。船の上でも陸と同じに働ける',
  ), // 済（3回目）: 場面と効き方は trait_scenes3.dart
  // ---- 心
  Trait(
    'brave',
    '豪胆',
    TraitTier.uncommon,
    '肝が据わっている。恐ろしい場でも手が震えない',
  ), // 済（2回目）: 場面と効き方は trait_scenes2.dart
  Trait(
    'cunning',
    '悪知恵',
    TraitTier.uncommon,
    '人を出し抜く手をすぐ思いつく。使えば得も恨みも大きい',
  ), // 済（4回目）: 場面と効き方は trait_scenes4.dart
  Trait(
    'calm',
    '沈着',
    TraitTier.uncommon,
    '何があっても慌てない。乱れた場で人をまとめる',
  ), // 済（3回目）: 場面と効き方は trait_scenes3.dart
  Trait(
    'generous',
    '気前がいい',
    TraitTier.uncommon,
    '惜しまず人に分け与える。慕う者が集まるが、蔵は空きやすい',
  ), // 済（3回目）: 場面と効き方は trait_scenes3.dart
  Trait(
    'jealous',
    '嫉妬深い',
    TraitTier.uncommon,
    '人の出世や幸せが妬ましい。それを糧に励みもする',
  ), // 済（4回目）: 場面と効き方は trait_scenes4.dart
  Trait(
    'vengeful',
    '執念深い',
    TraitTier.uncommon,
    '受けた仇を決して忘れない。何年かけても返す',
  ), // 済（4回目）: 場面と効き方は trait_scenes4.dart
  // ---- 才
  Trait(
    'prodigy',
    '神童',
    TraitTier.uncommon,
    '幼いころから物覚えが早い。学ぶほどにぐんぐん伸びる',
    fx: (a) => a.chi += 15,
  ), // 済: 知・読み書きと寺の手習いの伸び（childhood.dart）。場面「学僧の問い」
  Trait(
    'tongue',
    '弁舌巧み',
    TraitTier.uncommon,
    '口が立つ。合戦の場でも人を説き伏せやすい',
    fx: (a) {
      a.mi += 8;
      a.chi += 5;
    },
  ), // 済: 魅・知・合戦で説く手（battles.dart）。場面「口争い」
  Trait(
    'rider',
    '馬術の達人',
    TraitTier.uncommon,
    '馬を自在に操る。合戦で馬を駆って手柄を立て、危うい場を抜ける',
    fx: (a) => a.bu += 8,
  ), // 済: 武・合戦の危うさと手柄（battles.dart）。場面「荒馬」
  Trait(
    'gunner',
    '鉄砲の才',
    TraitTier.uncommon,
    '鉄砲を手にすれば、すぐに腕を上げる。撃てば手柄も大きい',
  ), // 済: 鉄砲を覚える（adult.dart）・合戦の手柄（battles.dart）。場面「鉄砲の試し撃ち」
  Trait(
    'herbal',
    '薬の心得',
    TraitTier.uncommon,
    '草木の効き目が分かる。自分や家の者の病を和らげられる',
  ), // 済: 熱病・子と連れ合いの病の手（childhood.dart・family.dart）。場面「流行り病の村」
  Trait(
    'appraiser',
    '目利き',
    TraitTier.uncommon,
    '品の良し悪しを見抜く。仕入れで損をしにくい',
  ), // 済: 仕入れの旅の儲け（ways.dart）。場面「市の掘り出し物」
  Trait(
    'poet',
    '歌詠み',
    TraitTier.uncommon,
    '和歌を詠む才がある。公家や風流人の座に呼ばれる',
  ), // 済（3回目）: 場面と効き方は trait_scenes3.dart
  Trait(
    'builder',
    '普請上手',
    TraitTier.uncommon,
    '石垣も堤も、どう組めば持つかが分かる',
  ), // 済（2回目）: 場面と効き方は trait_scenes2.dart
  Trait(
    'tea',
    '茶の心',
    TraitTier.uncommon,
    '茶の湯の作法を自然に身につける。茶の席で人に覚えられる',
  ), // 済（3回目）: 場面と効き方は trait_scenes3.dart
  Trait(
    'dialects',
    '国言葉に通じる',
    TraitTier.uncommon,
    '諸国の言葉を聞き分け、真似られる。旅先でもよそ者と見られない',
  ), // 済（4回目）: 場面と効き方は trait_scenes4.dart
  Trait(
    'tactics',
    '兵法の勘',
    TraitTier.uncommon,
    '陣の形を見ただけで、どこが崩れるか分かる',
  ), // 済（2回目）: 場面と効き方は trait_scenes2.dart
  Trait(
    'archer',
    '弓の才',
    TraitTier.uncommon,
    '狙った的を外さない。遠矢でも狩りでも名を上げる',
  ), // 済（2回目）: 場面と効き方は trait_scenes2.dart
  Trait(
    'sword',
    '剣の筋',
    TraitTier.uncommon,
    '太刀筋がよい。師につけばすぐに目録をもらう',
  ), // 済（4回目）: 場面と効き方は trait_scenes4.dart
  Trait(
    'stealth',
    '忍び足',
    TraitTier.uncommon,
    '足音を立てずに歩ける。誰にも気づかれずに近づける',
  ), // 済（4回目）: 場面と効き方は trait_scenes4.dart
  // ---- 生まれ
  Trait(
    'onna',
    '女武者',
    TraitTier.uncommon,
    '女の身で武芸に生きる。戦に出られ、武に秀でる',
    fx: (a) => a.bu += 12,
    ok: _onlyF,
    w: 6,
  ), // 済: 戦える（game.dart ほか）。場面は4回目（trait_scenes4.dart）
  Trait(
    'fallen',
    '没落した名家の出',
    TraitTier.uncommon,
    '先祖は名のある家だった。系図だけが家に残っている',
    ok: _commonBorn,
  ), // 済（3回目）: 場面と効き方は trait_scenes3.dart
  Trait(
    'temple_kin',
    '寺に縁者',
    TraitTier.uncommon,
    '叔父が寺の住持をしている。困った時の逃げ込み先がある',
    ok: _notDaimyo,
  ), // 済（3回目）: 場面と効き方は trait_scenes3.dart
  Trait(
    'sakai_kin',
    '堺に親類',
    TraitTier.uncommon,
    '堺の商家に親類がいる。南蛮の品や銭の話が届く',
    ok: _notDaimyo,
  ), // 済（2回目）: 場面と効き方は trait_scenes2.dart
  // ================================================================ 稀（20）
  Trait(
    'lucky',
    '強運',
    TraitTier.rare,
    '天に味方されている。死地からも不思議と生きて戻る',
    fx: (a) => a.un += 20,
  ), // 済: 運。場面「易者の見立て」→「兜に止まった矢」→「拾った運」
  Trait(
    'faces',
    '人の顔を忘れない',
    TraitTier.rare,
    '一度見た顔は何年たっても見分ける。化けた者も見破る',
  ), // 済: 場面「見覚えのある顔」→「お忍びの客」
  Trait(
    'twin',
    '双子',
    TraitTier.rare,
    '双子に生まれた。片割れは忌まれて、どこかへ里子に出されたという',
  ), // 済: 場面「片割れの噂」→「片割れとの対面」→「入れ替わり」
  Trait(
    'nanban',
    '南蛮の血',
    TraitTier.rare,
    '母方に南蛮の船乗りの血が混じる。髪も目も人と少し違う',
    ok: _notDaimyo,
  ), // 済: 場面「伴天連の目」→「通詞の口」→「南蛮船の誘い」
  Trait(
    'sixth',
    '虫の知らせ',
    TraitTier.rare,
    '悪いことの前に胸がざわつく。それがよく当たる',
  ), // 済: 場面「胸騒ぎの夜」→「虫の知らせの別れ」
  Trait(
    'painter',
    '絵の才',
    TraitTier.rare,
    '筆を持たせれば、見たものをそのまま写す。絵師が目を留める',
  ), // 済: 場面「襖の落書き」→「絵師の工房」→「城の襖絵」
  Trait(
    'surgeon',
    '金創の手',
    TraitTier.rare,
    '刀傷を縫い、矢を抜く手際がある。陣中で重宝される',
  ), // 済（2回目）: 場面と効き方は trait_scenes2.dart
  Trait('general', '将の器', TraitTier.rare, '人の上に立つと、兵が自ずと従う'), // 済（2回目）: 場面と効き方は trait_scenes2.dart
  Trait(
    'stars',
    '星を読む',
    TraitTier.rare,
    '天文に明るい。暦や吉凶を言い当て、殿に重んじられる',
  ), // 済（3回目）: 場面と効き方は trait_scenes3.dart
  Trait(
    'smith',
    '鍛冶の血',
    TraitTier.rare,
    '父祖は名工だった。鉄を打てば、よい刃になる',
  ), // 済（3回目）: 場面と効き方は trait_scenes3.dart
  Trait('flute', '笛の名手', TraitTier.rare, '笛を吹けば、敵も味方も聞き入る'), // 済（3回目）: 場面と効き方は trait_scenes3.dart
  Trait(
    'go',
    '碁の才',
    TraitTier.rare,
    '碁盤の上では誰にも負けない。名のある人と打つ機会が来る',
  ), // 済（2回目）: 場面と効き方は trait_scenes2.dart
  Trait(
    'mimic',
    '声色',
    TraitTier.rare,
    '人の声をそっくり真似られる。使い方しだいで身を助ける',
  ), // 済（4回目）: 場面と効き方は trait_scenes4.dart
  Trait('deathless', '不死身', TraitTier.rare, '大きな傷を負っても、なぜか生き延びる'), // 済（2回目）: 場面と効き方は trait_scenes2.dart
  Trait(
    'mosugo',
    '神仏の申し子',
    TraitTier.rare,
    '親が願をかけて授かった子。寺社に大事にされる',
  ), // 済（3回目）: 場面と効き方は trait_scenes3.dart
  Trait(
    'seer',
    '見鬼',
    TraitTier.rare,
    '人に見えないものが見えると言う。恐れられ、頼られもする',
  ), // 済（4回目）: 場面と効き方は trait_scenes4.dart
  Trait('nito', '二刀の才', TraitTier.rare, '左右の手で同じように刀を使う'), // 済（4回目）: 場面と効き方は trait_scenes4.dart
  Trait(
    'dowser',
    '水脈を当てる',
    TraitTier.rare,
    '地を見て、どこを掘れば水が出るかを当てる',
  ), // 済（2回目）: 場面と効き方は trait_scenes2.dart
  Trait(
    'kaizoku',
    '海賊衆の血',
    TraitTier.rare,
    '父祖は瀬戸内の海賊衆だった。海の者に顔がきく',
  ), // 済（4回目）: 場面と効き方は trait_scenes4.dart
  Trait(
    'kamikakushi',
    '神隠しの子',
    TraitTier.rare,
    '幼いころ山で消え、ひと月後に戻ってきた。何があったかは覚えていない',
  ), // 済（3回目）: 場面と効き方は trait_scenes3.dart
  // ================================================================ 幻（8）
  Trait(
    'rakuin',
    '落胤',
    TraitTier.mythic,
    '実は名のある家の当主の血を引いている。本人はまだ知らない',
    ok: _lowBorn,
  ), // 済: 場面「形見の守り袋」→「実の父の家の使い」→「名乗りの時」→「血を分けた兄」
  Trait(
    'yume',
    '正夢',
    TraitTier.mythic,
    '見た夢が、のちに本当になる。それが人の生き死にでも',
  ), // 済: 場面「燃える寺の夢」→「夢のとおりの朝」→「夢を告げるか」
  Trait(
    'imiko',
    '忌み子',
    TraitTier.mythic,
    '不吉な星の下に生まれたと言われ、捨てられかけた',
  ), // 済（3回目）: 場面と効き方は trait_scenes3.dart
  Trait(
    'tenka_so',
    '天下の相',
    TraitTier.mythic,
    '人相見が「天下を取る相だ」と言って青ざめた',
  ), // 済（4回目）: 場面と効き方は trait_scenes4.dart
  Trait(
    'kensei',
    '剣聖の器',
    TraitTier.mythic,
    '剣を持てば、師がやがて教えることがなくなる',
  ), // 済（2回目）: 場面と効き方は trait_scenes2.dart
  Trait(
    'ryujin',
    '竜神の加護',
    TraitTier.mythic,
    '水に落ちても、なぜか沈まない。海の者に拝まれる',
  ), // 済（2回目）: 場面と効き方は trait_scenes2.dart
  Trait(
    'kitsune',
    '狐の子',
    TraitTier.mythic,
    '母は狐だったと噂される。妙に勘が当たり、人に恐れられる',
  ), // 済（3回目）: 場面と効き方は trait_scenes3.dart
  Trait(
    'keikoku',
    '傾国の美貌',
    TraitTier.mythic,
    '人の運命を狂わせるほど美しい。望まぬ縁も引き寄せる',
  ), // 済（4回目）: 場面と効き方は trait_scenes4.dart
];

/// 女武者（女だけに付く。`Game.canFight`）。
final kTraitOnna = kTraits.firstWhere((t) => t.id == 'onna');

final _traitById = {for (final t in kTraits) t.id: t};

Trait traitOf(String id) => _traitById[id]!;

String traitName(String id) => traitOf(id).name;

const kGivenM = [
  '弥吉',
  '与作',
  '源太',
  '藤助',
  '小七',
  '権兵衛',
  '太郎',
  '次郎',
  '吉蔵',
  '五郎',
  '又八',
  '孫六',
  '彦助',
  '勘兵衛',
  '甚五郎',
  '助三郎',
  '長吉',
  '久蔵',
  '平八',
  '茂助',
];
const kGivenF = [
  'お梅',
  'おたつ',
  'お福',
  'お松',
  'おさき',
  'お千代',
  'おしの',
  'おはる',
  'お菊',
  'お鶴',
];

/// 生まれや縁談の相手の名字。名の知れた家（本多・真田・黒田・吉川など、特定の大名家の重臣や一門）は避け、
/// どの国にいてもおかしくない名字にする（越後の武家の子が「本多」、三好の家臣の妻が「本多家の娘」とならないように）。
const kSurnames = [
  '中村',
  '小川',
  '松井',
  '青木',
  '岡田',
  '西村',
  '原',
  '林',
  '野口',
  '杉山',
  '大野',
  '吉田',
  '高木',
  '川村',
  '今井',
  '平野',
  '宮本',
  '岩田',
  '野村',
  '藤井',
];

/// 跡継ぎの幼名・姫の名。名の知れた人の幼名（竹千代＝家康・犬千代＝前田利家・虎千代＝謙信・菊童丸＝足利義輝）や
/// 名の知れた姫（市姫＝お市・松姫と菊姫＝信玄の娘）は、史実の人物と取り違えるので使わない。
const kHeirNames = ['亀千代', '千代丸', '鶴丸', '福千代', '長寿丸', '梅千代', '岩千代'];
const kHimeNames = ['花姫', '鶴姫', '雪姫', '桜姫', '藤姫', '千代姫'];
