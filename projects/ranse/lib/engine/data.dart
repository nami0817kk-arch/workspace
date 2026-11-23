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

class Trait {
  const Trait(this.id, this.name, this.fx);
  final String id, name;
  final void Function(Abil) fx;
}

final kTraits = <Trait>[
  Trait('power', '剛力', (a) => a.bu += 15),
  Trait('prodigy', '神童', (a) => a.chi += 15),
  Trait('beauty', '人好きのする顔', (a) => a.mi += 15),
  Trait('lucky', '強運', (a) => a.un += 20),
  Trait('sickly', '病弱', (a) => a.maxhp -= 30),
  Trait('hardy', '頑健', (a) => a.maxhp += 20),
  Trait('amb', '野心家', (a) {}),
  Trait('loyal', '義理堅い', (a) {}),
  Trait('gunner', '鉄砲の才', (a) {}),
  Trait('rider', '馬術の達人', (a) => a.bu += 8),
  Trait('abacus', '算盤上手', (a) => a.sei += 15),
  Trait('tongue', '弁舌巧み', (a) {
    a.mi += 8;
    a.chi += 5;
  }),
];
final kTraitOnna = Trait('onna', '女武者', (a) => a.bu += 12);

String traitName(String id) {
  if (id == kTraitOnna.id) return kTraitOnna.name;
  return kTraits.firstWhere((t) => t.id == id).name;
}

const kGivenM = [
  '弥吉',
  '与作',
  '源太',
  '藤吉',
  '小六',
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
  'お市',
  'おいち',
  'お菊',
  'お鶴',
];
const kSurnames = [
  '佐々木',
  '山本',
  '竹中',
  '前田',
  '堀',
  '安藤',
  '稲葉',
  '石川',
  '本多',
  '榊原',
  '真田',
  '島',
  '藤堂',
  '加藤',
  '福島',
  '黒田',
  '蜂須賀',
  '吉川',
  '滝川',
  '丹羽',
];
const kHeirNames = ['竹千代', '犬千代', '鶴丸', '虎千代', '松千代', '菊童丸', '徳寿丸'];
const kHimeNames = ['市姫', '鶴姫', '菊姫', '桜姫', '松姫', '千代姫'];
