import 'childhood.dart';
import 'data.dart';
import 'game.dart';
import 'history_lines.dart';
import 'life.dart';
import 'rng.dart';

/// 庶民の生業の一生の岐路（2026-11-23）。id・旗は `cr_`。
///
/// 生まれの大半は庶民なのに、身分の差が岐路に出るのは百姓（`tf_f_`・`v_`）と商人（`tf_m_`）が中心で、
/// 漁民・山の民・職人・河原者・町人の生業ごとの岐路が薄かったので足した。
/// 前の段の旗がなければ次の段が出ない「筋」を持つ（[kCraftPrev]）。段を踏んだ年は旗 `cr_at:<筋>:<年>` に残し、
/// 次の段は何年か空けてから出す（[kCraftGap]）。
///
/// - 浜（漁民。`cr_u_`）: 網元の網 → 船を持つか／寄り鯨／海の衆の誘い → その後／嵐の浜の遭難者 → その後／塩浜。
/// - 山（山の民。`cr_y_`）: 山の神の日／手負いの獣／炭焼きの山／里との取引 → 凶作の年の里／落人 → その後。
/// - 職人（`cr_k_`）: 弟子入りの口（村や町の若い者が職人になる入口）／親方の仕込み → 腕比べ／大名の御用／
///   技を盗まれる／弟子を取る → 弟子の独り立ち／名を刻むか。
/// - 河原者（`cr_e_`）: 寺の庭の石 → 作庭を任される／河原の一座 → 勧進の舞台／皮を鞣す／疫病の骸。
/// - 町人（`cr_t_`）: 町の月行事 → 町の祭りと武家／町の火事／裏の借家 → その後／南蛮の品（一五六〇年から）／門前町。
/// - 漁民と山の民は同じ身分（`fisher`）なので、内陸の国（甲斐・信濃・美濃・近江・山城・会津）は山の民、
///   ほかの国では名と生まれ年から乱数を使わずに分ける（[crMountainFolk]）。
/// - 身分（位）は動かさない。能力（武・知・政・魅）が高いと出る手や、低いとしくじりやすい手がある。

// ---------------------------------------------------------------- 誰に出るか

/// 身分がなく、隠居でも浪人でも仏門でも野の道でもない庶民。
bool _commoner(Game g) {
  final l = g.l;
  return l.rank == 0 &&
      g.active &&
      !l.ronin &&
      !g.hasFlag('priesthood') &&
      !g.hasFlag('way_outlaw');
}

/// 海のない国（漁民・山の民の家は山の民になる）。
const kInlandRegions = ['甲斐', '信濃', '美濃', '近江', '山城', '会津'];

/// 漁民・山の民の家の人が、山の民か（乱数を使わない）。
bool crMountainFolk(Game g) {
  final l = g.l;
  if (kInlandRegions.contains(l.region)) return true;
  final s = l.name.codeUnits.fold<int>(0, (a, b) => a + b);
  return (s + l.startYear) % 3 == 0;
}

bool _fisherHouse(Game g) =>
    _commoner(g) && !g.hasFlag('way_merchant') && g.l.cls.id == 'fisher';

/// 浜で生きる漁民。
bool crSea(Game g) => _fisherHouse(g) && !crMountainFolk(g);

/// 山で生きる者（木地師・猟師・炭焼き）。
bool crMountain(Game g) => _fisherHouse(g) && crMountainFolk(g);

/// 職人（弟子入りした人・自分の工房を開いた人・関の鍛冶に弟子入りした人）。
bool crArtisan(Game g) =>
    _commoner(g) &&
    !g.hasFlag('way_merchant') &&
    (g.hasFlag('cr_craft') || g.hasFlag('craftsman') || g.hasFlag('rg_seki_deshi'));

/// 職人への弟子入りの口が来る人（村・浜・町の若い者で、まだ職人でない）。
bool crApprenticeOpen(Game g) =>
    _commoner(g) &&
    !g.hasFlag('way_merchant') &&
    const ['farmer', 'fisher', 'merchant'].contains(g.l.cls.id) &&
    !crArtisan(g);

/// 河原者・下人。
bool crKawara(Game g) =>
    _commoner(g) && !g.hasFlag('way_merchant') && g.l.cls.id == 'beggar';

/// 町人（町人・商人の家の人。商いの道に入っていてもよい）。
bool crTown(Game g) => _commoner(g) && g.l.cls.id == 'merchant';

/// 生業の名（テストと実測が使う）。当てはまらなければ null。職人は家の生業より先に見る。
String? crLivelihood(Game g) {
  if (crArtisan(g)) return 'artisan';
  if (crSea(g)) return 'sea';
  if (crMountain(g)) return 'mountain';
  if (crKawara(g)) return 'kawara';
  if (crTown(g)) return 'town';
  return null;
}

/// この岐路が出てよい人。テストも使う。
bool crLife(Game g) => crLivelihood(g) != null || crApprenticeOpen(g);

// ---------------------------------------------------------------- 表

const kCraftSeaIds = [
  'cr_u_amimoto',
  'cr_u_fune',
  'cr_u_kujira',
  'cr_u_suigun',
  'cr_u_suigun_after',
  'cr_u_nanpa',
  'cr_u_nanpa_after',
  'cr_u_enden',
];

const kCraftMountainIds = [
  'cr_y_okite',
  'cr_y_kemono',
  'cr_y_sumi',
  'cr_y_sato',
  'cr_y_sato_after',
  'cr_y_ochudo',
  'cr_y_ochudo_after',
];

const kCraftArtisanIds = [
  'cr_k_oyakata',
  'cr_k_udekurabe',
  'cr_k_goyo',
  'cr_k_nusumi',
  'cr_k_deshi',
  'cr_k_deshi_after',
  'cr_k_mei',
];

/// 職人になる入口（職人でない人に出る）。
const kCraftEntryIds = ['cr_k_iri'];

const kCraftKawaraIds = [
  'cr_e_niwa',
  'cr_e_niwa_after',
  'cr_e_gei',
  'cr_e_gei_after',
  'cr_e_kawa',
  'cr_e_ekibyo',
];

const kCraftTownIds = [
  'cr_t_gyoji',
  'cr_t_gyoji_after',
  'cr_t_kaji',
  'cr_t_shakuya',
  'cr_t_shakuya_after',
  'cr_t_nanban',
  'cr_t_monzen',
];

/// この岐路の id すべて（テストが使う）。
const kCraftLifeIds = [
  ...kCraftSeaIds,
  ...kCraftMountainIds,
  ...kCraftEntryIds,
  ...kCraftArtisanIds,
  ...kCraftKawaraIds,
  ...kCraftTownIds,
];

/// 岐路 → それが出てよい生業（`crLivelihood` の名。入口は 'entry'）。テストが使う。
String crKindOf(String id) {
  if (kCraftEntryIds.contains(id)) return 'entry';
  if (id.startsWith('cr_u_')) return 'sea';
  if (id.startsWith('cr_y_')) return 'mountain';
  if (id.startsWith('cr_k_')) return 'artisan';
  if (id.startsWith('cr_e_')) return 'kawara';
  return 'town';
}

/// その生業の人かを確かめる（テストが使う）。
bool crFits(Game g, String id) => switch (crKindOf(id)) {
  'entry' => crApprenticeOpen(g),
  'sea' => crSea(g),
  'mountain' => crMountain(g),
  'artisan' => crArtisan(g),
  'kawara' => crKawara(g),
  _ => crTown(g),
};

// ---------------------------------------------------------------- 筋

/// 筋の後段 → その前の段で立つ旗（どれか一つがあれば出られる）。テストも使う。
const kCraftPrev = <String, List<String>>{
  'cr_u_fune': ['cr_ami_ko', 'cr_ami_kumi', 'cr_ami_alone', 'cr_ami_deal'],
  'cr_u_suigun_after': ['cr_suigun_in', 'cr_suigun_told', 'cr_suigun_no'],
  'cr_u_nanpa_after': ['cr_nanpa_saved', 'cr_nanpa_took'],
  'cr_y_sato_after': ['cr_sato_cheap', 'cr_sato_market', 'cr_sato_deal'],
  'cr_y_ochudo_after': ['cr_ochudo_hid', 'cr_ochudo_told', 'cr_ochudo_path'],
  'cr_k_udekurabe': ['cr_oya_endured', 'cr_oya_watched', 'cr_oya_asked'],
  'cr_k_deshi_after': ['cr_deshi_strict', 'cr_deshi_open'],
  'cr_e_niwa_after': ['cr_niwa_eye', 'cr_niwa_worked'],
  'cr_e_gei_after': ['cr_gei_in'],
  'cr_t_gyoji_after': ['cr_gyoji_took', 'cr_gyoji_kido', 'cr_gyoji_paid'],
  'cr_t_shakuya_after': ['cr_ie_out', 'cr_ie_wait', 'cr_ie_work'],
};

/// 筋の後段 → (筋の名, 前の段から空ける年)。
const kCraftGap = <String, (String, int)>{
  'cr_u_fune': ('ami', 3),
  'cr_u_suigun_after': ('suigun', 2),
  'cr_u_nanpa_after': ('nanpa', 2),
  'cr_y_sato_after': ('sato', 3),
  'cr_y_ochudo_after': ('ochudo', 3),
  'cr_k_udekurabe': ('oya', 2),
  'cr_k_deshi_after': ('deshi', 4),
  'cr_e_niwa_after': ('niwa', 3),
  'cr_e_gei_after': ('gei', 2),
  'cr_t_gyoji_after': ('gyoji', 2),
  'cr_t_shakuya_after': ('ie', 3),
};

/// 筋の段を踏んだ年を残す（同じ筋の古い年は消す）。
void _stamp(Game g, String chain) {
  g.l.flags.removeWhere((f) => f.startsWith('cr_at:$chain:'));
  g.setFlag('cr_at:$chain:${g.year}');
}

/// 筋の段を最後に踏んでから何年たったか。踏んでいなければ -1。
int crSince(Game g, String chain) {
  for (final f in g.l.flags) {
    if (f.startsWith('cr_at:$chain:')) {
      return g.year - int.parse(f.substring('cr_at:$chain:'.length));
    }
  }
  return -1;
}

/// 筋の後段に進めるか（前の段の旗があり、年が空いている）。
bool crChainReady(Game g, String id) {
  final prev = kCraftPrev[id];
  if (prev == null) return true;
  if (!prev.any(g.hasFlag)) return false;
  final gap = kCraftGap[id];
  if (gap == null) return true;
  return crSince(g, gap.$1) >= gap.$2;
}

// ---------------------------------------------------------------- 補助

int _c(int v) => clampInt(v, 0, 100);
void _net(Game g, int n) => g.l.net = g.l.net + n < 0 ? 0 : g.l.net + n;
void _pay(Game g, int n) => g.l.gold = g.l.gold >= n ? g.l.gold - n : 0;
void _fame(Game g, int n) => g.l.fame = g.l.fame + n < 0 ? 0 : g.l.fame + n;
void _hurt(Game g, int n) => g.l.hp -= n;

void _bond(Person? p, int n) {
  if (p != null) p.bond = _c(p.bond + n);
}

/// 旗 `<頭><名>` から名を取り出す。なければ [fallback]。
String _named(Game g, String head, String fallback) {
  for (final f in g.l.flags) {
    if (f.startsWith(head)) return f.substring(head.length);
  }
  return fallback;
}

void _keepName(Game g, String head, String name) {
  g.l.flags.removeWhere((f) => f.startsWith(head));
  g.setFlag('$head$name');
}

/// 職人の技（鍛冶・番匠・紙漉き・紺屋・塗師）。決まっていなければ一度決めて旗 `cr_waza:<名>` に残す。
const kCraftWaza = ['鍛冶', '番匠', '紙漉き', '紺屋', '塗師'];

String _waza(Game g) {
  final w = _named(g, 'cr_waza:', '');
  if (w.isNotEmpty) return w;
  final pick = g.hasFlag('rg_seki_deshi') ? '鍛冶' : g.rng.pick(kCraftWaza);
  _keepName(g, 'cr_waza:', pick);
  return pick;
}

/// 技ごとの言葉: (仕事場, 作る物, 道具)。
(String, String, String) _wazaWords(String w) => switch (w) {
  '鍛冶' => ('鍛冶場', '刃物', '鎚'),
  '番匠' => ('木屑の積もった仕事場', '建具', '鉋'),
  '紙漉き' => ('紙漉き場', '紙', '簀桁'),
  '紺屋' => ('藍の匂う仕事場', '染め物', '染め刷毛'),
  _ => ('塗り場', '塗りの椀', '漆刷毛'),
};

String _boy(Game g) => g.rng.pick(kGivenM);

/// 近くの家の呼び名（「◯◯家」）。いまいる国に近い家から。
String _nearHouse(Game g) {
  final c = nearest(g.alive, (f) => f.name, region: g.l.region, n: 2);
  if (c.isEmpty) return '近くの家';
  return '${houseName(g, g.rng.pick(c).name)}家';
}

/// 重み。筋の始まり・ひとつきりは生業ごとに [_wSea]〜[_wTown]、前の段を踏んだ人だけに出る後段は [_w2]。
/// 場面の少ない生業（山・職人）と、商人の `tf_m_` と分け合う町人は重くしてある。
const _wSea = 8.0;
const _wMt = 13.0;
const _wArt = 17.0;
const _wKw = 10.0;
const _wTown = 17.0;
const _w2 = 24.0;

SceneDef _chain(
  String id,
  int minAge,
  int maxAge,
  double w,
  bool Function(Game g) who,
  void Function(Game g, void Function() next) run,
) => SceneDef(id, minAge, maxAge, (g) => w, (g) => who(g) && crChainReady(g, id), run);

// ======================================================================
// 岐路
// ======================================================================

List<SceneDef> buildCraftLifeScenes() => [
  ..._seaScenes(),
  ..._mountainScenes(),
  ..._artisanScenes(),
  ..._kawaraScenes(),
  ..._townScenes(),
];

// ---------------------------------------------------------------- 浜

List<SceneDef> _seaScenes() => [
  // ============================================ 筋: 網元の網
  SceneDef('cr_u_amimoto', 17, 50, (g) => _wSea, crSea, (g, next) {
    final l = g.l;
    g.ask('網元の網', '浜の網元が、鰯の大網を引く網子を集めている。網子になれば分け前は少ないが、漁のない日も網元の蔵から米が出る。浜の若い者たちは、自分たちで網を合わせようかと話している。', [
      Choice.h('網元の網子になる', '暮らしは安らぐ。網元の言うことには逆らえない', () {
        l.gold += 3;
        g.j(1);
        g.setFlag('cr_ami_ko');
        _stamp(g, 'ami');
        return '網元の印の入った半纏をもらった。夜明け前の浜で、何十人もの網子と声を合わせて網を引いた。';
      }),
      Choice.h('浜の仲間と網を合わせて引く', '分け前は大きい。不漁の年は皆で飢える', () {
        _net(g, 2);
        g.setFlag('cr_ami_kumi');
        _stamp(g, 'ami');
        return '古い網を持ち寄り、繕い合わせて一張りの網にした。最初の漁で、仲間の一人が「わしらの網じゃ」と泣き笑いした。';
      }),
      Choice.h('一人で小舟を出し、釣りで食う', '誰にも頭を下げずに済む。稼ぎは細い', () {
        g.j(1);
        g.setFlag('cr_ami_alone');
        _stamp(g, 'ami');
        return '網元の誘いを断り、夜明けごとに一人で沖へ出た。釣れる日も、釣れぬ日もあった。';
      }),
      if (l.mi >= 60)
        Choice.h('網元の座敷に上がり、網子の分け前を掛け合う', '人柄が通じれば浜の皆が潤う。睨まれれば浜にいづらくなる', () {
          _stamp(g, 'ami');
          if (g.rng.chance(clampD(.45 + l.mi / 300, .45, .85))) {
            _net(g, 4);
            l.gold += 3;
            g.setFlag('cr_ami_deal');
            g.mark('浜の網元に掛け合い、網子たちの分け前を増やさせた');
            return '網元は長く黙っていたが、やがて「お前の言うことにも理はある」と煙管を置いた。その年から、網子の取り分が一割増えた。';
          }
          g.j(-2);
          g.setFlag('cr_ami_alone');
          return '網元は「網子が座敷に上がるとは」と笑い、あなたを網から外した。その年は一人で小舟を出すほかなかった。';
        }),
    ], after: next);
  }),

  _chain('cr_u_fune', 20, 60, _w2, crSea, (g, next) {
    final l = g.l;
    final lead = g.hasFlag('cr_ami_ko')
        ? '網元が老いて、あなたに「わしの古い船を譲ってもよい。代は年ごとの漁で払えばよい」と言ってきた。'
        : (g.hasFlag('cr_ami_kumi') || g.hasFlag('cr_ami_deal'))
            ? '網を合わせた仲間たちが、今度は皆で一艘の船を造ろうと言い出した。舟大工は、手付けの銭を求めている。'
            : '浜に、持ち主を亡くした古い船が上げられたままになっている。後家が、安く譲ってもよいと言う。';
    g.ask('船を持つか', '$lead船を持てば、沖の深い漁場まで出られる。借りは長く背負うことになる。', [
      Choice.h('借りを背負って船を持つ', '浜で一人前と見られる。不漁が続けば借りに追われる', () {
        _pay(g, 8);
        _fame(g, 3);
        g.j(3);
        g.setFlag('cr_fune_own');
        _stamp(g, 'ami');
        g.mark('借りを背負って、自分の船を持った');
        return '船の舳先に、浜の神社でもらった札を打ちつけた。初めて沖へ漕ぎ出した朝、浜の子らが波打ち際まで追いかけてきた。';
      }),
      Choice.h('仲間と持ち合いにする', '借りは軽い。船の使い方で揉めることもある', () {
        _pay(g, 3);
        _net(g, 3);
        g.setFlag('cr_fune_kumi');
        _stamp(g, 'ami');
        return '船には、持ち合う五人の名を刻んだ。誰が沖へ出るかで、夜ごと浜で言い合いになった。';
      }),
      Choice.h('いまの暮らしのままでいる', '借りは作らない。沖の漁場は遠いまま', () {
        _stamp(g, 'ami');
        return '話を断った。船は、隣の浜の男が買っていった。';
      }),
      if (l.sei >= 60)
        Choice.h('船の代わりに、浜の干し場を借りて干物で稼ぐ', '才があれば船より堅い。浜の者に商人気取りと言われる', () {
          _stamp(g, 'ami');
          if (g.rng.chance(clampD(.45 + l.sei / 250, .45, .85))) {
            l.gold += 10;
            g.setFlag('cr_himono');
            g.mark('浜の干し場を借りて干物を作り、市へ出して稼いだ');
            return '干した鰯を俵に詰め、内陸の市へ出した。山の村では、干物が米と同じように重宝された。';
          }
          g.j(-2);
          return '長雨が続き、干した魚はみな傷んだ。浜の者は、気の毒そうに目をそらした。';
        }),
    ], after: next);
  }),

  // ============================================ ひとつきり: 寄り鯨
  SceneDef('cr_u_kujira', 18, 65, (g) => _wSea, crSea, (g, next) {
    final l = g.l;
    g.ask('寄り鯨', '朝の浜が騒がしい。沖の浅瀬に、大きな鯨が迷い込んでもがいている。鯨一頭で七つの浦が潤うと言われる。浜の長は、まず領主と社に届けるのが古い習いだと言う。', [
      Choice.h('浜の皆で引き上げ、分け合う', '浜は潤う。届けを怠れば咎めがあるかもしれない', () {
        l.gold += 5;
        _net(g, 3);
        g.j(3);
        g.setFlag('cr_kujira_shared');
        g.mark('浅瀬に迷い込んだ鯨を、浜の皆で引き上げて分け合った');
        return '浜じゅうの者が綱を引き、鯨は砂の上に横たわった。その夜、どの家の竈にも鯨の脂が燃えた。';
      }),
      Choice.h('先に銛を打ちに漕ぎ出す', '仕留めれば一番の取り分。暴れる鯨は小舟を砕く', () {
        if (g.rng.chance(.03)) {
          g.die('浅瀬の鯨に銛を打ちに漕ぎ出し、尾に小舟を打ち砕かれた', 'sai');
          return '鯨の尾が、空を覆うように持ち上がった。';
        }
        if (g.rng.chance(clampD(.35 + l.bu / 200, .35, .8))) {
          l.gold += 9;
          _fame(g, 4);
          g.setFlag('cr_kujira_struck');
          g.mark('浅瀬の鯨に真っ先に銛を打ち込み、浜の語り草になった');
          return '揺れる小舟の上で、渾身の銛を打ち込んだ。浜へ戻ると、年寄りたちが「あの銛は、わしらの若い頃にもなかった」と言った。';
        }
        _hurt(g, 10);
        return '銛は脂に滑って抜け、小舟は大きく傾いた。這うように浜へ戻ると、鯨はもう皆の手で引き上げられていた。';
      }),
      Choice.h('浜の長に従い、領主と社に届ける', '咎めはない。浜の取り分は減る', () {
        l.gold += 2;
        _net(g, 1);
        return '社の神主が祝詞を上げ、領主の役人が鯨の半ばを持っていった。残りの肉は、浜の家々に少しずつ配られた。';
      }),
    ], after: next);
  }),

  // ============================================ 筋: 海の衆の誘い
  SceneDef('cr_u_suigun', 18, 45, (g) => _wSea * (g.l.bu >= 50 ? 1.3 : 1), crSea, (g, next) {
    final l = g.l;
    g.ask('海の衆の誘い', '島陰に船を並べる海の衆が、浜へ人を寄越した。潮の流れと浅瀬をよく知る者に、水先を頼みたいという。通る船から帆別の銭を取り、戦となればどこかの家に雇われる者たちだ。', [
      Choice.h('海の衆に加わる', '稼ぎは浜の何倍にもなる。海の戦に駆り出される', () {
        l.gold += 6;
        l.bu = clampInt(l.bu + 2, 0, 99);
        g.setFlag('cr_suigun_in');
        _stamp(g, 'suigun');
        g.mark('島陰の海の衆に加わり、潮を読む水先を務めた');
        return '島の砦で、頭は潮の読み方を試すように問うてきた。答えると、黙って盃を差し出した。';
      }),
      Choice.h('浜の暮らしを捨てられぬと断る', '波風は立たない。海の衆の機嫌は分からない', () {
        g.setFlag('cr_suigun_no');
        _stamp(g, 'suigun');
        return '使いの男は「気が変わったら、島の火を見よ」とだけ言って帰っていった。';
      }),
      Choice.h('浜の長を通して役人に知らせる', '浜の掟は守れる。海の衆の恨みを買う', () {
        _net(g, -1);
        g.setFlag('cr_suigun_told');
        _stamp(g, 'suigun');
        return '役人は話を聞いて帳面に何か書きつけたが、船を出すことはなかった。島の灯りは、その夜も消えなかった。';
      }),
    ], after: next);
  }),

  _chain('cr_u_suigun_after', 20, 60, _w2, crSea, (g, next) {
    final l = g.l;
    if (g.hasFlag('cr_suigun_in')) {
      final h = _nearHouse(g);
      g.ask('海の衆の戦', '$hが、海の衆をまとめて雇い入れた。敵の兵糧を運ぶ船を、沖で待ち伏せるという。頭は、潮を読むあなたを先頭の舟に乗せたがっている。', [
        Choice.h('先頭の舟で潮を読む', '名が上がる。沖の戦は命がけだ', () {
          _stamp(g, 'suigun');
          if (g.rng.chance(.04)) {
            g.die('海の衆に加わって沖の戦に出、波間に消えた', 'senshi');
            return '潮目の先に、敵の帆が見えた。';
          }
          l.gold += 8;
          _fame(g, 4);
          g.setFlag('cr_suigun_led');
          g.mark('海の衆の先頭の舟で潮を読み、沖の待ち伏せを当てた');
          return '潮の変わり目を読み当て、敵の荷船を浅瀬へ追い込んだ。頭は砦に戻ると、取り分の銭をあなたの前に積んだ。';
        }),
        Choice.h('後ろの舟で荷を運ぶ', '危うさは少ない。取り分も少ない', () {
          l.gold += 3;
          _stamp(g, 'suigun');
          return '後ろの舟で、奪った米俵を島へ運んだ。沖の方で、法螺貝が長く鳴っていた。';
        }),
        Choice.h('これを機に浜へ帰る', '命は拾える。海の衆とは縁が切れる', () {
          g.j(2);
          g.l.flags.remove('cr_suigun_in');
          g.setFlag('cr_suigun_left');
          _stamp(g, 'suigun');
          return '頭に暇を乞うと、意外にもあっさり許された。「潮の匂いを忘れるなよ」と言われた。';
        }),
      ], after: next);
      return;
    }
    if (g.hasFlag('cr_suigun_told')) {
      g.ask('焼かれた網', 'ある朝、浜に干してあったあなたの網が、灰になっていた。浜の者たちは、海の衆の仕返しだと囁き合っている。', [
        Choice.h('網を編み直し、黙って漁を続ける', '浜の者に見直される。暮らしはしばらく苦しい', () {
          _pay(g, 4);
          _net(g, 2);
          _stamp(g, 'suigun');
          return '夜ごと囲炉裏の前で網を編んだ。浜の女たちが、黙って麻糸を置いていった。';
        }),
        Choice.h('島へ詫びの酒を届ける', '仕返しは止む。浜の者には腰抜けと見られる', () {
          _pay(g, 3);
          _net(g, -1);
          _stamp(g, 'suigun');
          return '酒樽を小舟に積んで島の近くまで漕いだ。翌朝、浜の網はもう焼かれなかった。';
        }),
      ], after: next);
      return;
    }
    g.ask('島の火', '断ってから二年。夜の沖に、島の砦の火が見える。不漁が続き、浜の暮らしは苦しい。あの使いの男の言葉が、耳に残っている。', [
      Choice.h('島へ漕ぎ出し、水先を申し出る', '銭は入る。海の衆の掟に縛られる', () {
        l.gold += 5;
        g.setFlag('cr_suigun_in');
        _stamp(g, 'suigun');
        return '島の砦で、頭は「来ると思っていた」と笑った。';
      }),
      Choice.h('浜で耐える', '浜の暮らしは守れる。腹は満たされない', () {
        g.j(-2);
        _stamp(g, 'suigun');
        return '島の火に背を向けて、浜の小屋に戻った。';
      }),
    ], after: next);
  }),

  // ============================================ 筋: 嵐の浜の遭難者
  SceneDef('cr_u_nanpa', 16, 65, (g) => _wSea, crSea, (g, next) {
    final l = g.l;
    g.ask('嵐の明けた浜', '一夜荒れた海が明けると、浜に壊れた荷船の板と、ずぶ濡れの男が打ち上げられていた。息はある。波打ち際には、油紙に包まれた荷がいくつも転がっている。浜の古い習いでは、寄った物は拾った者のものだ。', [
      Choice.h('男を小屋へ運び、手当てする', '命は救える。荷は浜の者たちに拾われていく', () {
        _net(g, 2);
        g.j(2);
        g.setFlag('cr_nanpa_saved');
        _stamp(g, 'nanpa');
        g.mark('嵐の明けた浜に打ち上げられた男を、小屋へ運んで手当てした');
        return '囲炉裏で体を温め、粥を口に運んでやった。三日目に目を開けた男は、遠い湊の言葉で礼を言った。';
      }),
      Choice.h('寄った荷を先に拾い集める', '習いどおり荷は自分のものになる。男のことは誰かに任せる', () {
        l.gold += 6;
        g.setFlag('cr_nanpa_took');
        _stamp(g, 'nanpa');
        return '油紙の中は、上等な反物だった。男は、浜の年寄りたちが寺へ運んでいった。';
      }),
      Choice.h('浜の長を呼びに走る', '浜の掟に任せる。何も得ず、何も失わない', () {
        _stamp(g, 'nanpa');
        return '浜の長が人を集め、男も荷も浜の寄合の預かりになった。';
      }),
    ], after: next);
  }),

  _chain('cr_u_nanpa_after', 18, 70, _w2, crSea, (g, next) {
    final l = g.l;
    if (g.hasFlag('cr_nanpa_saved')) {
      g.ask('湊からの使い', '嵐の浜で助けた男が、身なりのよい手代を連れて浜へ来た。遠い湊の廻船問屋の跡取りだったという。礼をしたい、望みを言ってくれ、と頭を下げる。', [
        Choice.h('礼の銭を受け取る', '暮らしは楽になる。縁はそれきり', () {
          l.gold += 12;
          _stamp(g, 'nanpa');
          return '手代は、重い銭袋を置いていった。その年の冬は、浜の誰よりも温かく越した。';
        }),
        Choice.h('浜の干物を湊で商ってほしいと頼む', '浜に長い稼ぎ口ができる。すぐには銭にならない', () {
          _net(g, 4);
          l.gold += 3;
          g.setFlag('cr_nanpa_bond');
          g.mark('嵐の浜で助けた湊の跡取りと、浜の干物を商う約束を結んだ');
          return '男は笑って手を打った。翌年から、湊の船が年に二度、浜の干物を積みに来るようになった。';
        }),
        Choice.h('礼には及ばぬと断る', '心は軽い。浜の者に馬鹿正直と笑われる', () {
          g.j(3);
          _fame(g, 2);
          _stamp(g, 'nanpa');
          return '男は困ったように笑い、浜の社に灯籠を一つ寄進して帰っていった。';
        }),
      ], after: next);
      return;
    }
    g.ask('荷の詮議', '嵐の浜で拾った反物のことで、湊の問屋の者が役人を連れて浜へ来た。荷には問屋の印があり、浜の習いなど知らぬ、返せと言う。', [
      Choice.h('素直に返す', '咎めは軽い。拾った分は手元に残らない', () {
        _pay(g, 5);
        _stamp(g, 'nanpa');
        return '売らずにしまってあった反物を差し出した。問屋の者は、何も言わずに受け取った。';
      }),
      Choice.h('浜の習いだと言い張る', '通れば荷は手元に残る。役人の機嫌しだいで罰を受ける', () {
        _stamp(g, 'nanpa');
        if (g.rng.chance(clampD(.3 + l.mi / 250, .3, .7))) {
          _net(g, 1);
          return '浜の長が古い書き付けを持ち出し、役人は渋い顔で引き上げた。';
        }
        _pay(g, 8);
        _hurt(g, 6);
        g.j(-3);
        return '役人は聞く耳を持たなかった。過料を取られ、浜の者の前で打たれた。';
      }),
    ], after: next);
  }),

  // ============================================ ひとつきり: 塩浜
  SceneDef('cr_u_enden', 18, 60, (g) => _wSea * .8, crSea, (g, next) {
    final l = g.l;
    g.ask('塩浜', '浜の外れの干潟で、潮を撒いて砂に塩を吹かせ、釜で煮詰める塩焼きが人手を求めている。塩は内陸の村へ高く売れるが、夏の日照りの下で桶を担ぎ続ける辛い仕事だ。', [
      Choice.h('塩焼きの浜で働く', '稼ぎは堅い。体はすり減る', () {
        l.gold += 5;
        _hurt(g, 6);
        g.setFlag('cr_enden_work');
        return '日の出から日の入りまで、潮を汲んでは砂に撒いた。夏の終わりには、肩の皮が二度むけた。';
      }),
      Choice.h('漁を続ける', '慣れた暮らしを守れる。稼ぎは海しだい', () {
        g.j(1);
        return '塩焼きの煙を横目に、いつものように沖へ出た。';
      }),
      if (l.chi >= 60)
        Choice.h('釜の焚き方と砂の撒き方を工夫する', '才が当たれば塩が増える。外れれば薪を無駄にする', () {
          if (g.rng.chance(clampD(.45 + l.chi / 300, .45, .85))) {
            l.gold += 8;
            _fame(g, 3);
            g.setFlag('cr_enden_kufu');
            g.mark('塩浜の釜の焚き方を工夫し、同じ薪で多くの塩を取った');
            return '砂を撒く厚みを変え、釜の下の火を細く長く保った。塩焼きの親方が、あなたのやり方を真似し始めた。';
          }
          _pay(g, 2);
          return '工夫した釜は煮えたぎりすぎて、塩が焦げた。親方に薪の代を払わされた。';
        }),
    ], after: next);
  }),
];

// ---------------------------------------------------------------- 山

List<SceneDef> _mountainScenes() => [
  // ============================================ ひとつきり: 山の神の日
  SceneDef('cr_y_okite', 16, 65, (g) => _wMt, crMountain, (g, next) {
    final l = g.l;
    final b = _boy(g);
    g.ask('山の神の日', '山の神の祭りの日は、誰も山に入らぬのが掟だ。なのに若い$bが、その日に大きな鹿を担いで下りてきた。山の衆は、掟を破った者の獲物は神に返せと言い、$bは家に病の母がいると言い返している。', [
      Choice.h('掟どおり、獲物を山の神に返させる', '山の掟は守られる。若い者の恨みを買う', () {
        _net(g, 1);
        g.setFlag('cr_okite_kept');
        return '鹿は山の祠の前に置かれた。$bは唇を噛んで、それを見ていた。';
      }),
      Choice.h('肉を病の母に分け、皮だけを神に返させる', '情けは通る。年寄りは掟がゆるむと嘆く', () {
        _net(g, 2);
        g.j(1);
        g.setFlag('cr_okite_mercy');
        g.mark('山の神の日の掟を破った若者の獲物を、病の母のために分けさせた');
        return '鹿の皮を剥いで祠に掛け、肉は$bの家へ運ばせた。年寄りたちは渋い顔をしたが、何も言わなかった。';
      }),
      if (l.mi >= 60)
        Choice.h('山の衆を集め、病の家に分ける新しい決まりを話し合う', '人柄が通じれば掟が生きたまま変わる。年寄りを怒らせることもある', () {
          if (g.rng.chance(clampD(.45 + l.mi / 300, .45, .85))) {
            _net(g, 4);
            _fame(g, 2);
            g.setFlag('cr_okite_new');
            g.mark('山の衆を集め、病の家に獲物を分ける決まりを掟に加えた');
            return '囲炉裏を囲んで夜更けまで話した。最後に、いちばんの年寄りが「山の神も、病の母は捨て置くまい」と言った。';
          }
          _net(g, -2);
          return '年寄りたちは「よそ者の言うような理屈だ」と席を立った。';
        }),
    ], after: next);
  }),

  // ============================================ ひとつきり: 手負いの獣
  SceneDef('cr_y_kemono', 16, 60, (g) => _wMt, crMountain, (g, next) {
    final l = g.l;
    g.ask('手負いの熊', '里の侍が鷹狩りで仕損じた熊が、手負いのまま山をうろついている。炭焼きの小屋が一つ荒らされた。熊は手負いになると、人を恨むように襲うという。', [
      Choice.h('山の衆と追って仕留める', '山は静かになる。手負いの熊は怖ろしい', () {
        if (g.rng.chance(.03)) {
          g.die('手負いの熊を追って奥山へ分け入り、帰らなかった', 'yukue');
          return '熊の足跡は、霧の谷へ続いていた。';
        }
        if (g.rng.chance(clampD(.4 + l.bu / 200, .4, .85))) {
          l.gold += 4;
          _fame(g, 3);
          g.setFlag('cr_kuma_slain');
          g.mark('手負いの熊を山の衆と追い、仕留めた');
          return '三日目の夕暮れ、谷の倒木の陰で熊と向き合った。槍を突き出したとき、手は不思議と震えなかった。熊の胆は、里の薬屋が高く買った。';
        }
        _hurt(g, 14);
        return '熊は藪から飛び出し、あなたの肩を爪で裂いて逃げた。仲間に担がれて小屋へ戻った。';
      }),
      Choice.h('落とし穴と罠で待つ', '危うさは少ない。かかるまで山に入れない', () {
        g.j(-1);
        if (g.rng.chance(.6)) {
          l.gold += 2;
          return '半月ののち、熊は谷の落とし穴にかかっていた。';
        }
        return '罠には何もかからなかった。熊はいつの間にか、隣の山へ移っていった。';
      }),
      Choice.h('しばらく山を下りて里で過ごす', '命は守れる。炭も椀も作れず、稼ぎが止まる', () {
        _pay(g, 3);
        return '里の知り合いの家の土間を借りて、ひと月を過ごした。';
      }),
    ], after: next);
  }),

  // ============================================ 筋: 里との取引
  SceneDef('cr_y_sato', 17, 60, (g) => _wMt, crMountain, (g, next) {
    final l = g.l;
    final what = g.rng.pick(['挽いた木地の椀', '焼いた炭', '干した獣の肉と皮']);
    _keepName(g, 'cr_sato_what:', what);
    g.ask('里の商人', '山で作った$whatを、里の商人が買いに上がってくる。言い値はいつも安い。里の市へ自分で下りれば高く売れるが、山の者は市で軽く見られる。', [
      Choice.h('商人の言い値で売る', '手間はかからない。安く買い叩かれ続ける', () {
        l.gold += 2;
        g.setFlag('cr_sato_cheap');
        _stamp(g, 'sato');
        return '商人は荷を背負子に積み、銭を数えて置いていった。';
      }),
      Choice.h('自分で里の市へ下りる', '高く売れる。市の者に何を言われるか分からない', () {
        l.gold += 5;
        g.j(-1);
        g.setFlag('cr_sato_market');
        _stamp(g, 'sato');
        return '市の端に筵を敷いた。「山の者か」と囁く声もしたが、荷は昼までに売れた。';
      }),
      if (l.sei >= 60)
        Choice.h('里の問屋と、一年分の値を決める約定を結ぶ', '才があれば値が守られる。不作の年も同じ値で納めねばならない', () {
          _stamp(g, 'sato');
          if (g.rng.chance(clampD(.45 + l.sei / 250, .45, .85))) {
            l.gold += 6;
            _net(g, 2);
            g.setFlag('cr_sato_deal');
            g.mark('山で作った品の値を、里の問屋と一年ごとの約定で決めさせた');
            return '問屋の主人は帳面を開き、あなたの言う数に筆を入れた。「山の衆にも、算盤のわかる者がおるか」と目を丸くした。';
          }
          g.setFlag('cr_sato_cheap');
          return '問屋は約定の書き付けに細工を入れていた。気づいたときには、いつもの安値で荷を渡していた。';
        }),
    ], after: next);
  }),

  _chain('cr_y_sato_after', 20, 70, _w2, crMountain, (g, next) {
    final l = g.l;
    final what = _named(g, 'cr_sato_what:', '山の品');
    final lead = g.hasFlag('cr_sato_deal')
        ? '約定を結んだ問屋が、蔵の米を少し分けるから$whatを早めに納めてほしいと言ってきた。'
        : g.hasFlag('cr_sato_market')
            ? '里の市で顔なじみになった者たちが、山なら食べられる物があるだろうと、痩せた子を連れて上がってきた。'
            : 'いつもの商人は来なくなった。里の者が、食べられる草や木の実を探して山へ入ってくる。';
    g.ask('凶作の年の里', '里が凶作に見舞われた。$lead山の暮らしも楽ではない。', [
      Choice.h('山の蓄えを里の者に分ける', '里の者に恩が残る。山の冬が苦しくなる', () {
        _pay(g, 3);
        _net(g, 4);
        g.j(2);
        g.setFlag('cr_sato_shared');
        _stamp(g, 'sato');
        g.mark('里の凶作の年、山の蓄えを分けて里の者に食わせた');
        return '干した栗と獣の肉を、背負える限り持たせて帰した。春になって、里の者が山の小屋の前に餅を置いていった。';
      }),
      Choice.h('山の衆の分だけを守る', '山は冬を越せる。里の者との間は冷える', () {
        _net(g, -2);
        _stamp(g, 'sato');
        return '山の入口に、山の衆の印を下げた縄を張った。里の者は、黙ってそれを見上げて帰っていった。';
      }),
      if (g.hasFlag('cr_sato_deal'))
        Choice.h('問屋の米と引き換えに、山の品を納める', '約定が生きる。山の手は休まらない', () {
          l.gold += 4;
          _net(g, 2);
          _stamp(g, 'sato');
          return '夜通し手を動かし、約束の荷を納めた。問屋の米で、山の衆は冬を越した。';
        }),
    ], after: next);
  }),

  // ============================================ ひとつきり: 炭焼きの山
  SceneDef('cr_y_sumi', 18, 65, (g) => _wMt, crMountain, (g, next) {
    final l = g.l;
    final h = _nearHouse(g);
    g.ask('炭焼きの山', '$hの城下の鍛冶場から、炭を例年の三倍納めよという注文が来た。戦が近いらしい。応じるには、まだ若い木の山まで伐らねばならない。年寄りは、山は一度裸にすると二十年は戻らぬと言う。', [
      Choice.h('注文どおり伐って焼く', '銭は大きい。山が痩せる', () {
        l.gold += 9;
        _hurt(g, 4);
        g.setFlag('cr_sumi_cut');
        return '尾根から谷まで、木という木を伐った。窯の煙は、ひと冬じゅう絶えなかった。春、裸の山肌から土が流れ出した。';
      }),
      Choice.h('伐る山を順に回し、納められる分だけ納める', '山は守れる。鍛冶場の機嫌を損ねる', () {
        l.gold += 3;
        _net(g, 2);
        g.setFlag('cr_sumi_rotate');
        g.mark('炭の注文に追われても、伐る山を順に回して若い木を残した');
        return '年寄りに教わった順に、伐ってよい山だけを伐った。鍛冶場の使いは不満げだったが、山の衆は黙ってうなずいた。';
      }),
      if (l.chi >= 60)
        Choice.h('窯の口と焚き方を工夫し、同じ木から多くの炭を取る', '才が当たれば山も銭も守れる。窯を一つ駄目にするかもしれない', () {
          if (g.rng.chance(clampD(.45 + l.chi / 300, .45, .85))) {
            l.gold += 7;
            _fame(g, 2);
            g.setFlag('cr_sumi_rotate');
            g.setFlag('cr_sumi_kufu');
            g.mark('炭窯の口と焚き方を工夫し、同じ木から多くの炭を焼いた');
            return '窯の口を狭め、火を落とす刻を見極めた。出てきた炭は、叩くと澄んだ音がした。';
          }
          _pay(g, 2);
          return '工夫した窯は火が回りすぎて、木はみな灰になった。';
        }),
    ], after: next);
  }),

  // ============================================ 筋: 落人
  SceneDef('cr_y_ochudo', 18, 70, (g) => _wMt, crMountain, (g, next) {
    final h = _nearHouse(g);
    g.ask('山へ来た落人', '戦に敗れた$hの侍が、傷ついた若い主を背負って山小屋の戸を叩いた。追手が里で山狩りの人を集めているという。山の衆は、里の戦に関わらぬのが掟だ。', [
      Choice.h('山奥の炭焼き小屋にかくまう', '恩が残るかもしれない。見つかれば山の衆ごと咎めを受ける', () {
        _pay(g, 2);
        g.j(1);
        g.setFlag('cr_ochudo_hid');
        _stamp(g, 'ochudo');
        g.mark('追われる落人の主従を、山奥の炭焼き小屋にかくまった');
        return '獣道を通って、山奥の古い炭焼き小屋に二人を移した。若い主は熱に浮かされながら、あなたの手を握った。';
      }),
      Choice.h('峠越えの道だけを教えて去らせる', '関わりは浅く済む。落人が逃げ切れるかは分からない', () {
        g.setFlag('cr_ochudo_path');
        _stamp(g, 'ochudo');
        return '握り飯を持たせ、杣道を指さした。二人の背中は、夕暮れの尾根に消えた。';
      }),
      Choice.h('里の追手に知らせる', '咎めは受けない。山の衆は眉をひそめる', () {
        g.l.gold += 4;
        _net(g, -2);
        g.setFlag('cr_ochudo_told');
        _stamp(g, 'ochudo');
        return '追手の侍は褒美の銭を投げてよこした。その夜、山の衆の誰も、あなたと目を合わせなかった。';
      }),
    ], after: next);
  }),

  _chain('cr_y_ochudo_after', 21, 75, _w2, crMountain, (g, next) {
    final l = g.l;
    if (g.hasFlag('cr_ochudo_hid')) {
      g.ask('落人の礼', 'かくまった若い主が、家を立て直したという。立派な身なりの使いが山へ来て、主が城下に招きたいと言っている。山を下りて仕えるなら、取り立てるとも。', [
        Choice.h('山に残り、礼の品だけ受け取る', '山の暮らしは変わらない。縁は細く続く', () {
          l.gold += 8;
          _net(g, 2);
          g.setFlag('cr_ochudo_thanked');
          _stamp(g, 'ochudo');
          g.mark('かくまった落人の主から、山まで礼の使いを受けた');
          return '使いは、反物と銭と、主の自筆の文を置いていった。字は読めなくとも、文は囲炉裏の上の梁に大事に挟んだ。';
        }),
        Choice.h('城下へ下りて、主に目通りする', '思わぬ縁が開ける。山の衆には去る者と見られる', () {
          l.gold += 4;
          _fame(g, 4);
          _net(g, 3);
          g.setFlag('cr_ochudo_thanked');
          _stamp(g, 'ochudo');
          g.mark('かくまった落人の主に城下で目通りし、山の衆の暮らしを守る約束をもらった');
          return '主は上座を下りてきて、あなたの手を取った。山の衆の木を伐る山は、末までそのままにすると約した。';
        }),
      ], after: next);
      return;
    }
    if (g.hasFlag('cr_ochudo_told')) {
      g.ask('山の衆の目', '落人を追手に売ってから、山の衆の寄合に呼ばれなくなった。冬を前に、炭を焼く窯を共に使わせてもらえないと困る。', [
        Choice.h('寄合に頭を下げて詫びる', '許されるかもしれない。しばらくは小さくなって暮らす', () {
          _pay(g, 3);
          _net(g, 2);
          _stamp(g, 'ochudo');
          return '囲炉裏の端に手をついた。年寄りは長く黙っていたが、やがて「窯は使え」と言った。';
        }),
        Choice.h('一人で窯を築く', '誰にも頭を下げない。冬の仕事は重くなる', () {
          _hurt(g, 6);
          g.j(-2);
          _stamp(g, 'ochudo');
          return '石を積み、粘土を塗って小さな窯を築いた。最初の炭は、半ばが灰になった。';
        }),
      ], after: next);
      return;
    }
    g.ask('尾根の墓', '杣道を指さして去らせた落人のことを、炭焼きの仲間が話していた。峠の向こうの尾根に、名のない小さな墓が二つあるという。', [
      Choice.h('墓に花と水を供えに行く', '心の重さが少し和らぐ。山の掟には触れない', () {
        g.j(2);
        _stamp(g, 'ochudo');
        return '尾根の墓の前に、山百合と竹筒の水を置いた。風の音だけがしていた。';
      }),
      Choice.h('山の衆に話さずにおく', '何も変わらない', () {
        _stamp(g, 'ochudo');
        return 'あの日の二人の背中を、ときどき夢に見た。';
      }),
    ], after: next);
  }),
];

// ---------------------------------------------------------------- 職人

List<SceneDef> _artisanScenes() => [
  // ============================================ 入口: 弟子入りの口
  SceneDef('cr_k_iri', 15, 28, (g) => 1.2 + (g.l.order >= 2 ? .6 : 0), crApprenticeOpen, (g, next) {
    final l = g.l;
    final w = g.rng.pick(kCraftWaza);
    final ww = _wazaWords(w);
    g.ask('弟子入りの口', '町の$wの親方が、住み込みの弟子を探しているという。十年は給金もなく、親方の家の飯を食って${ww.$3}を握る。腕がつけば、どこへ行っても食いはぐれない。', [
      Choice.h('$wの親方に弟子入りする', '手に職がつく。長い修業で家の手は離れる', () {
        _hurt(g, 4);
        l.sei = clampInt(l.sei + 2, 0, 99);
        g.setFlag('cr_craft');
        _keepName(g, 'cr_waza:', w);
        g.mark('$wの親方に弟子入りし、住み込みで修業を始めた');
        return '親方は、あなたの手を裏返して掌を見ると、「明日から来い」とだけ言った。';
      }),
      Choice.h('いまの暮らしを続ける', '慣れた家にいられる。手に職はつかない', () {
        return '話を断った。親方の仕事場の前を通ることも、それきりなくなった。';
      }),
    ], after: next);
  }),

  // ============================================ 筋: 親方の仕込み
  SceneDef('cr_k_oyakata', 15, 40, (g) => _wArt * 1.2, crArtisan, (g, next) {
    final l = g.l;
    final w = _waza(g);
    final ww = _wazaWords(w);
    g.ask('親方の仕込み', '$wの親方は、何も教えない。${ww.$3}にも触らせず、朝から晩まで水汲みと掃除ばかりだ。兄弟子は「技は見て盗め」と言うが、見ていると怒鳴られる。', [
      Choice.h('黙って下働きに耐える', '親方の信は得られる。腕が上がるのは遅い', () {
        g.j(-1);
        _hurt(g, 3);
        g.setFlag('cr_oya_endured');
        _stamp(g, 'oya');
        return '三年、雑巾と桶だけを持った。ある朝、親方が黙って${ww.$3}を差し出した。';
      }),
      Choice.h('夜中に起き出し、親方の仕事を覗き見る', '腕は早く上がる。見つかれば追い出されるかもしれない', () {
        g.setFlag('cr_oya_watched');
        _stamp(g, 'oya');
        if (g.rng.chance(.7)) {
          l.chi = clampInt(l.chi + 2, 0, 99);
          return '戸の隙間から、親方の手元を毎夜見た。真似て作った物を、親方は見ないふりをして見ていた。';
        }
        g.j(-3);
        return '物音を立てて見つかった。親方は何も言わず、翌日から仕事場の戸に心張り棒をかけた。';
      }),
      if (l.mi >= 55)
        Choice.h('親方の酒の相手をして、昔話を聞き出す', '人柄が通じれば勘所を教わる。軽く見られることもある', () {
          _stamp(g, 'oya');
          if (g.rng.chance(clampD(.45 + l.mi / 300, .45, .85))) {
            l.chi = clampInt(l.chi + 2, 0, 99);
            g.setFlag('cr_oya_asked');
            return '酔った親方は、若い頃にしくじった仕事の話をした。その中に、仕事の勘所がいくつも混じっていた。';
          }
          g.setFlag('cr_oya_endured');
          return '親方は「口で覚える技はない」と盃を伏せた。それきり、また水汲みの日々に戻った。';
        }),
    ], after: next);
  }),

  _chain('cr_k_udekurabe', 18, 50, _w2, crArtisan, (g, next) {
    final l = g.l;
    final w = _waza(g);
    final ww = _wazaWords(w);
    final rival = _boy(g);
    g.ask('腕比べ', '親方が隠居を口にした。跡を継ぐのは、兄弟子の$rivalか、あなたか。親方は、二人に同じ${ww.$2}を作らせて決めると言う。', [
      Choice.h('夜も寝ずに打ち込む', '腕が出れば勝てる。体を壊すこともある', () {
        _stamp(g, 'oya');
        _hurt(g, 8);
        final p = .35 + (g.hasFlag('cr_oya_watched') ? .1 : 0) + (g.hasFlag('cr_oya_asked') ? .1 : 0) + l.chi / 400;
        if (g.rng.chance(clampD(p, .3, .8))) {
          l.gold += 6;
          _fame(g, 4);
          g.setFlag('cr_kurabe_won');
          g.mark('$wの腕比べで兄弟子に勝ち、親方の跡を継いだ');
          return '親方は二つの${ww.$2}を長いこと見比べ、黙ってあなたの方を指さした。$rivalは唇を噛み、その夜のうちに荷をまとめた。';
        }
        g.j(-3);
        return '親方が選んだのは、$rivalの${ww.$2}だった。「お前のは、まだ急いでいる」と言われた。';
      }),
      Choice.h('兄弟子に跡を譲り、その下で腕を磨く', '恨みは残らない。親方の跡は継げない', () {
        _stamp(g, 'oya');
        _net(g, 3);
        g.setFlag('cr_kurabe_yielded');
        return '$rivalは驚いた顔をして、それから深く頭を下げた。仕事場には、いままでどおり二人の手の音が響いた。';
      }),
      if (g.hasFlag('cr_oya_endured'))
        Choice.h('親方に、下働きで見てきたことをそのまま作ってみせる', '下働きの年月が生きる。派手さはない', () {
          _stamp(g, 'oya');
          if (g.rng.chance(.55)) {
            _fame(g, 3);
            g.setFlag('cr_kurabe_won');
            g.mark('$wの腕比べで、下働きの年月に見てきた親方の技をそのまま形にし、跡を継いだ');
            return '派手な工夫は何もしなかった。親方はあなたの${ww.$2}を手に取り、「わしの若い頃の仕事じゃ」と目を細めた。';
          }
          return '親方は「ようできた」と言ったが、跡は$rivalに譲った。';
        }),
    ], after: next);
  }),

  // ============================================ ひとつきり: 大名の御用
  SceneDef('cr_k_goyo', 18, 65, (g) => _wArt, crArtisan, (g, next) {
    final l = g.l;
    final w = _waza(g);
    final h = _nearHouse(g);
    final job = switch (w) {
      '鍛冶' => '侍大将に下される刀を十振り',
      '番匠' => '新しい屋形の書院の建具を一式',
      '紙漉き' => '書状に使う厚い奉書紙を千枚',
      '紺屋' => '戦の旗指物を百本',
      _ => '具足の漆塗りを二十領',
    };
    g.ask('大名の御用', '$hの奉行が仕事場に来た。$job、ひと月のうちに納めよという。御用を務めれば名が上がるが、期日は無理なほど短い。', [
      Choice.h('寝ずに働いて期日に間に合わせる', '名が上がる。仕事は荒れるかもしれない', () {
        _hurt(g, 8);
        if (g.rng.chance(clampD(.45 + l.sei / 300, .45, .8))) {
          l.gold += 8;
          _fame(g, 4);
          g.setFlag('cr_goyo_done');
          g.mark('$hの御用を引き受け、期日までに納めた');
          return '最後の品を納めた朝、奉行は一つ一つ改めてうなずいた。仕事場の前に、御用の札が掛けられた。';
        }
        l.gold += 3;
        _fame(g, -2);
        return '期日には間に合ったが、いくつかに粗が出た。奉行は「次はない」と言い捨てた。';
      }),
      Choice.h('仕事を落とせぬと、期日を延ばしてもらう', '仕事の質は守れる。奉行の機嫌を損ねる', () {
        if (g.rng.chance(.5)) {
          l.gold += 6;
          _fame(g, 3);
          g.setFlag('cr_goyo_honest');
          return '奉行は眉を寄せたが、出来上がった品を見ると何も言わなかった。';
        }
        _fame(g, -1);
        return '奉行は「代わりはいくらでもおる」と、隣の町の職人に仕事を回した。';
      }),
      if (l.chi >= 60)
        Choice.h('近在の職人を集め、仕事を割って段取りを組む', '才が当たれば質も期日も守れる。割り振りを誤れば揉める', () {
          if (g.rng.chance(clampD(.5 + l.chi / 300, .5, .85))) {
            l.gold += 9;
            _fame(g, 4);
            _net(g, 3);
            g.setFlag('cr_goyo_done');
            g.mark('近在の職人を束ねて段取りを組み、$hの御用を期日に納めた');
            return '下ごしらえ、仕上げ、改めと手を分けた。奉行は「職人にも采配のできる者がおる」と笑った。';
          }
          _net(g, -2);
          return '割り振りで職人たちが揉め、仕事は遅れた。結局、夜を徹して自分で仕上げた。';
        }),
      Choice.h('御用を断る', '面倒は避けられる。この町では仕事がしにくくなる', () {
        _fame(g, -2);
        return '奉行は鼻を鳴らして帰った。しばらく、町の問屋からの注文が減った。';
      }),
    ], after: next);
  }),

  // ============================================ ひとつきり: 技を盗まれる
  SceneDef('cr_k_nusumi', 20, 65, (g) => _wArt * .9, crArtisan, (g, next) {
    final l = g.l;
    final w = _waza(g);
    final ww = _wazaWords(w);
    g.ask('盗まれた技', '半年前に雇った流れの職人が、ある日ふっといなくなった。ほどなく隣の町で、あなたの工夫そっくりの${ww.$2}が安く売られ始めた。', [
      Choice.h('町の年寄に訴え出る', '筋は通る。手間がかかり、言い逃れされることもある', () {
        if (g.rng.chance(.5)) {
          l.gold += 3;
          g.setFlag('cr_nusumi_won');
          return '年寄の前で、あなたの${ww.$2}と並べて見せた。細工の癖まで同じだと分かり、男は町を追われた。';
        }
        _pay(g, 3);
        return '男は「工夫は誰のものでもない」と言い張り、年寄も首をかしげるばかりだった。';
      }),
      Choice.h('盗まれたものは仕方がないと割り切る', '心は乱されない。客は安い方へ流れる', () {
        _pay(g, 3);
        g.j(1);
        return '黙って仕事を続けた。昔からの客は、それでもあなたの仕事場へ来た。';
      }),
      if (l.chi >= 55)
        Choice.h('さらに一歩先の工夫を重ねる', '才があれば盗んだ者を置き去りにできる。工夫が外れることもある', () {
          if (g.rng.chance(clampD(.45 + l.chi / 300, .45, .85))) {
            l.gold += 6;
            _fame(g, 3);
            g.setFlag('cr_nusumi_ahead');
            g.mark('技を盗まれたあと、さらに一歩先の工夫を重ねて客を取り戻した');
            return '新しい工夫の${ww.$2}を出すと、客は戻ってきた。盗んだ男の品は、ひと月で古く見えた。';
          }
          return '工夫は思ったようにいかず、試しに作った物は売り物にならなかった。';
        }),
    ], after: next);
  }),

  // ============================================ 筋: 弟子を取る
  SceneDef('cr_k_deshi', 24, 65, (g) => _wArt * 1.2, crArtisan, (g, next) {
    final l = g.l;
    final w = _waza(g);
    final b = _boy(g);
    g.ask('弟子入りの頼み', '村の後家が、痩せた男の子を連れてきた。$bという。父を戦で亡くし、食べさせられないので、$wの弟子にしてほしいと頭を下げる。', [
      Choice.h('弟子にとり、厳しく仕込む', '腕のいい職人に育つかもしれない。逃げ出す子もいる', () {
        l.gold -= l.gold >= 2 ? 2 : l.gold;
        g.meet('職人の弟子', b, 40);
        g.setFlag('cr_deshi_strict');
        _stamp(g, 'deshi');
        return '$bには、自分が親方にされたように、水汲みと掃除から始めさせた。';
      }),
      Choice.h('弟子にとり、惜しまず教える', '早く育つ。甘やかしと見られる', () {
        l.gold -= l.gold >= 2 ? 2 : l.gold;
        g.meet('職人の弟子', b, 55);
        g.setFlag('cr_deshi_open');
        _stamp(g, 'deshi');
        return '最初の日から、$bに道具を握らせた。親方に知られたら叱られるだろうと思った。';
      }),
      Choice.h('食べ物だけ持たせて帰す', '手間はかからない。後家の背中が目に残る', () {
        _pay(g, 1);
        g.j(-1);
        return '米を一袋持たせて帰した。後家は何度も振り返って頭を下げた。';
      }),
    ], after: next);
  }),

  _chain('cr_k_deshi_after', 27, 75, _w2, crArtisan, (g, next) {
    final l = g.l;
    final w = _waza(g);
    final d = l.people['職人の弟子'];
    final b = d?.name ?? '弟子';
    if (d == null) {
      g.ask('去った弟子', 'かつての弟子が、よその町で$wの仕事場を開いたと聞いた。あなたのもとを去ってから、一度も便りはない。', [
        Choice.h('祝いの品を届けさせる', '縁が戻るかもしれない', () {
          _pay(g, 2);
          _net(g, 2);
          _stamp(g, 'deshi');
          return '祝いの品に、使い慣れた道具を一つ添えた。';
        }),
        Choice.h('何もしない', '心は静か', () {
          _stamp(g, 'deshi');
          return '仕事場の隅に、弟子の使っていた古い道具がそのまま残っていた。';
        }),
      ], after: next);
      return;
    }
    final strict = g.hasFlag('cr_deshi_strict');
    g.ask('弟子の独り立ち', '$bが一人前になった。${strict ? '厳しく仕込んだ甲斐があり、仕事は手堅い。' : '惜しまず教えたので腕は早く伸びたが、まだ危なっかしいところもある。'}よその町に自分の仕事場を持ちたいと言っている。', [
      Choice.h('道具を分け与えて送り出す', '弟子は恩を忘れない。仕事場の手は減る', () {
        _bond(d, 20);
        _net(g, 3);
        g.j(3);
        g.setFlag('cr_deshi_sent');
        _stamp(g, 'deshi');
        g.mark('$wの弟子の$bを一人前に育て、道具を分けて送り出した');
        return '一番よく手に馴染んだ道具を$bに持たせた。$bは仕事場の敷居で振り返り、土間に額をつけた。';
      }),
      Choice.h('もう少し手元に置く', '仕事場は回る。弟子は不満を抱えるかもしれない', () {
        _bond(d, -10);
        _stamp(g, 'deshi');
        if (g.rng.chance(.3)) {
          l.people.remove('職人の弟子');
          return 'ある朝、$bの寝床は空になっていた。';
        }
        return '$bは黙ってうなずいたが、その日から口数が減った。';
      }),
      if (l.mi >= 55)
        Choice.h('自分の仕事場を譲る約束をする', '人柄が通じれば家のように続く。仕事場の行く末を他人に預ける', () {
          _bond(d, 25);
          _net(g, 2);
          g.setFlag('cr_deshi_sent');
          g.setFlag('cr_deshi_heir');
          _stamp(g, 'deshi');
          g.mark('$wの弟子の$bに、自分の仕事場を譲る約束をした');
          return '「よそへ行かずとも、ここをお前の仕事場にすればよい」と言うと、$bは道具を握ったまま泣いた。';
        }),
    ], after: next);
  }),

  // ============================================ ひとつきり: 名を刻むか
  SceneDef('cr_k_mei', 25, 75, (g) => _wArt, crArtisan, (g, next) {
    final l = g.l;
    final w = _waza(g);
    final ww = _wazaWords(w);
    g.ask('名を刻むか', '腕が知られるにつれ、あなたの${ww.$2}を名指しで求める客が出てきた。問屋は、品に名を入れよ、そうすれば値が倍になると言う。古い職人たちは、職人が名を誇るのは驕りだと言う。', [
      Choice.h('品に名を入れる', '名が残る。しくじった品にも名が付いて回る', () {
        _fame(g, 4);
        l.gold += 5;
        g.setFlag('cr_mei_cut');
        g.mark('自分の${ww.$2}に名を入れるようになった');
        return '最初の品に名を入れた夜、手が震えて眠れなかった。';
      }),
      Choice.h('名を入れずに作り続ける', '驕りとは言われない。品は名もなく人の手に渡る', () {
        g.j(2);
        g.setFlag('cr_mei_none');
        return '名を入れずに、いつものように仕事を続けた。それでも客は、手触りであなたの品を見分けた。';
      }),
      if (l.chi >= 55)
        Choice.h('名の代わりに、自分だけが分かる小さな印を入れる', '驕りとは言われず、作り手も分かる。気づく者は少ない', () {
          _fame(g, 2);
          g.setFlag('cr_mei_sign');
          g.mark('自分の${ww.$2}の目立たぬところに、小さな印を入れるようになった');
          return '品の裏の目立たぬところに、小さな印を入れた。それに気づいた客は、黙って笑ってうなずいた。';
        }),
    ], after: next);
  }),
];

// ---------------------------------------------------------------- 河原者

List<SceneDef> _kawaraScenes() => [
  // ============================================ 筋: 寺の庭の石
  SceneDef('cr_e_niwa', 16, 50, (g) => _wKw * 1.2, crKawara, (g, next) {
    final l = g.l;
    g.ask('寺の庭の石', '京から来た庭作りの者が、近くの寺の庭を作り直している。石を運ぶ人足として、河原の者たちが雇われた。重い石を据えるたびに、庭作りの者は首をかしげて、少しずつ向きを変えさせる。', [
      Choice.h('石の向きの理を、じっと見て覚える', '目が育つ。人足の手が遅れて叱られる', () {
        l.chi = clampInt(l.chi + 2, 0, 99);
        g.setFlag('cr_niwa_eye');
        _stamp(g, 'niwa');
        return '石を運びながら、庭作りの者が見ている方を一緒に見た。石が向きを変えるたびに、庭がふっと広がって見えた。';
      }),
      Choice.h('黙って運び、日銭を得る', '銭は入る。それ以上のことはない', () {
        l.gold += 3;
        g.setFlag('cr_niwa_worked');
        _stamp(g, 'niwa');
        return '日が暮れるまで、もっこを担いだ。手間賃は、河原の家族の三日分の米になった。';
      }),
      if (l.chi >= 50 || l.mi >= 55)
        Choice.h('思い切って、石の置き場所を申し出る', '目が当たれば名を覚えられる。人足の分際でと打たれるかもしれない', () {
          _stamp(g, 'niwa');
          if (g.rng.chance(clampD(.4 + l.chi / 300, .4, .8))) {
            _fame(g, 3);
            g.setFlag('cr_niwa_eye');
            g.setFlag('cr_niwa_spoke');
            g.mark('寺の庭作りで、人足の身で石の置き場所を申し出て、庭作りの者に名を覚えられた');
            return '庭作りの者は驚いた顔をして、あなたの言うとおりに石を据えさせた。しばらく黙って庭を眺め、「お前、名は」と聞いた。';
          }
          _hurt(g, 6);
          g.setFlag('cr_niwa_worked');
          return '寺の役僧が「人足が口を出すな」と怒鳴り、竹で打った。庭作りの者は、何も言わなかった。';
        }),
    ], after: next);
  }),

  _chain('cr_e_niwa_after', 20, 65, _w2, crKawara, (g, next) {
    final l = g.l;
    final h = _nearHouse(g);
    final eye = g.hasFlag('cr_niwa_eye');
    g.ask('任された庭', eye
        ? 'あの庭作りの者が年老いて、あなたを呼んだ。$hの屋形の庭を頼まれたが、もう石を見に歩けない。代わりに石を選び、据える場所を決めてくれという。河原の者が、殿様の庭を作るのだ。'
        : '寺の庭を作った庭作りの者が、また人足を集めている。今度は$hの屋形の庭だという。河原の者の中から、石を見る目のある者を一人、手元に置きたいと言っている。', [
      Choice.h('引き受け、石を選びに山と河原を歩く', '一生に一度の機会になる。しくじれば河原の者がまとめて嘲られる', () {
        _stamp(g, 'niwa');
        final p = .3 + (eye ? .25 : 0) + l.chi / 300;
        if (g.rng.chance(clampD(p, .3, .85))) {
          l.gold += 10;
          _fame(g, 6);
          g.j(4);
          g.setFlag('cr_niwa_master');
          g.mark('河原の者の身で、$hの屋形の庭の石組みを任された');
          return '川の石を一つずつ見て歩き、ふた月かけて据えた。出来上がった庭を見た殿様は、作り手が河原の者と聞いても、ただ「よい庭じゃ」とだけ言った。';
        }
        _hurt(g, 6);
        g.j(-3);
        return '石組みは、屋形の家臣たちの気に入らなかった。「河原の者に任せるからだ」という声が、塀の外まで聞こえた。';
      }),
      Choice.h('身の程を思って断る', '危うさはない。同じ機会は二度と来ないかもしれない', () {
        _stamp(g, 'niwa');
        g.j(-1);
        return '頭を下げて断った。屋形の庭は、京から呼ばれた別の者が作った。';
      }),
      if (eye)
        Choice.h('河原の仲間を連れて行き、皆で据えさせてほしいと頼む', '仲間にも道が開ける。人が多ければ揉め事も増える', () {
          _stamp(g, 'niwa');
          _net(g, 4);
          l.gold += 5;
          g.setFlag('cr_niwa_master');
          g.mark('河原の仲間を率いて、$hの屋形の庭の石を据えた');
          return '河原の若い者たちに、石の向きの見方を教えながら据えた。仕事が終わった夜、皆で河原に火を焚いて、庭の話をした。';
        }),
    ], after: next);
  }),

  // ============================================ 筋: 河原の一座
  SceneDef('cr_e_gei', 15, 40, (g) => _wKw, crKawara, (g, next) {
    final l = g.l;
    g.ask('河原の一座', '河原に小屋を掛けた猿楽の一座が、囃子と舞の稽古をしている。座頭が、あなたの身のこなしを見て、一座に入らぬかと声をかけてきた。旅から旅の暮らしで、行く先々で芸を見せて食う。', [
      Choice.h('一座に入る', '芸が身を立てるかもしれない。旅の暮らしは辛い', () {
        l.mi = clampInt(l.mi + 3, 0, 99);
        _hurt(g, 3);
        g.setFlag('cr_gei_in');
        _stamp(g, 'gei');
        return '座頭は扇を一本くれて、「足の運びから覚えよ」と言った。';
      }),
      Choice.h('河原の暮らしを離れられぬと断る', '慣れた暮らしを守れる', () {
        return '一座は、桜の散るころに次の国へ発っていった。';
      }),
    ], after: next);
  }),

  _chain('cr_e_gei_after', 18, 55, _w2, crKawara, (g, next) {
    final l = g.l;
    g.ask('勧進の舞台', '大きな寺の勧進のために、境内に舞台が組まれた。一座に、あなたの舞う番が回ってきた。見物の桟敷には、町衆も侍も並んでいる。座頭は、古い型どおりに舞えと言う。', [
      Choice.h('型どおりに、ひたすら丁寧に舞う', '座頭の信は厚くなる。目立つことはない', () {
        _stamp(g, 'gei');
        _net(g, 2);
        l.gold += 3;
        g.setFlag('cr_gei_kata');
        return '一つの型も崩さずに舞い終えた。座頭は楽屋で、黙ってあなたの肩を叩いた。';
      }),
      Choice.h('自分の工夫を入れて舞う', '見物の心をつかめば名が出る。座頭の怒りを買うかもしれない', () {
        _stamp(g, 'gei');
        if (g.rng.chance(clampD(.35 + l.mi / 250, .35, .8))) {
          _fame(g, 6);
          l.gold += 6;
          g.j(4);
          g.setFlag('cr_gei_named');
          g.mark('寺の勧進の舞台で自分の工夫を入れて舞い、町じゅうに名を知られた');
          return '舞い終えると、桟敷がしんと静まり、それから声が湧いた。翌日から、町の辻で子どもたちがあなたの舞を真似した。';
        }
        g.j(-3);
        return '見物の反応は冷たかった。座頭は「型も守れぬ者が工夫などと」と言い、しばらく舞台に出さなかった。';
      }),
      Choice.h('舞台を若い者に譲る', '座の和は保てる。好機は逃す', () {
        _stamp(g, 'gei');
        _net(g, 3);
        return '楽屋で若い者の衣装を直してやった。舞台からは、拍子木の音が響いてきた。';
      }),
    ], after: next);
  }),

  // ============================================ ひとつきり: 皮を鞣す
  SceneDef('cr_e_kawa', 16, 60, (g) => _wKw, crKawara, (g, next) {
    final l = g.l;
    final h = _nearHouse(g);
    g.ask('皮を鞣す', '$hの具足師から、鞣した牛の皮をまとめて納めよという注文が来た。戦が近いらしい。河原の皮作りは、人の嫌がる仕事だが、皮がなければ具足も馬具も作れない。', [
      Choice.h('仲間と夜を徹して鞣す', '稼ぎは大きい。体はきつい', () {
        l.gold += 7;
        _hurt(g, 5);
        g.setFlag('cr_kawa_done');
        return '川の水で皮を晒し、灰と脂で揉み続けた。納めた皮を見た具足師は「これなら矢も通るまい」と言った。';
      }),
      Choice.h('値を上げてくれと掛け合う', '通れば暮らしが楽になる。仕事を取り上げられることもある', () {
        if (g.rng.chance(clampD(.35 + l.mi / 250 + l.sei / 400, .35, .8))) {
          l.gold += 10;
          _net(g, 2);
          g.setFlag('cr_kawa_price');
          g.mark('具足師に掛け合い、河原の皮作りの値を上げさせた');
          return '「皮がなければ、殿様の具足もできますまい」と言うと、具足師は苦い顔で値を上げた。河原の仲間たちは、その夜あなたを囲んで酒を飲んだ。';
        }
        l.gold += 2;
        g.j(-2);
        return '具足師は鼻で笑い、注文の半ばを隣の河原の者に回した。';
      }),
      Choice.h('戦の道具は作らぬと断る', '心は軽い。暮らしは苦しくなる', () {
        _pay(g, 2);
        g.j(1);
        return '注文を断った。具足師の使いは、聞こえるように舌打ちして帰った。';
      }),
    ], after: next);
  }),

  // ============================================ ひとつきり: 疫病の骸
  SceneDef('cr_e_ekibyo', 16, 65, (g) => _wKw, crKawara, (g, next) {
    final l = g.l;
    g.ask('疫病の骸', '町に疫病が出て、毎日のように人が死んでいる。町の年寄が河原に来て、骸を運び出して葬ってほしいと頼んだ。誰も触れたがらない仕事だ。', [
      Choice.h('引き受け、一人ずつ丁寧に葬る', '町の者は救われる。病がうつるかもしれない', () {
        if (g.rng.chance(.03)) {
          g.die('疫病の骸を運ぶうちに、自らも熱に倒れた', 'byo');
          return '幾日目かの朝、体が重く、起き上がれなかった。';
        }
        l.gold += 4;
        _fame(g, 3);
        _net(g, 3);
        g.setFlag('cr_ekibyo_buried');
        g.mark('疫病の町で、誰も触れたがらない骸を一人ずつ葬った');
        return '骸の一つ一つに筵を掛け、名の分かる者には木の札を立てた。疫病が去ったあと、町の年寄が河原に米俵を届けに来た。';
      }),
      Choice.h('旅の僧に経を頼み、それから葬る', '弔いは手厚くなる。手間と銭がかかる', () {
        _pay(g, 3);
        g.j(1);
        g.setFlag('cr_ekibyo_buried');
        return '旅の僧は、骸の前で一晩じゅう経を読んだ。夜明けに、二人で土をかけた。';
      }),
      Choice.h('病がうつると断る', '身は守れる。町の者にはさらに蔑まれる', () {
        _net(g, -2);
        return '年寄は黙って帰っていった。翌日、町の外れに骸が積まれていると聞いた。';
      }),
    ], after: next);
  }),
];

// ---------------------------------------------------------------- 町人

List<SceneDef> _townScenes() => [
  // ============================================ 筋: 町の月行事
  SceneDef('cr_t_gyoji', 18, 60, (g) => _wTown, crTown, (g, next) {
    final l = g.l;
    g.ask('町の月行事', '町の寄合で、月ごとに町を取り仕切る月行事の番が回ってきた。木戸の番、夜回り、町の掟を破った者の詮議まで、ひと月は商いどころではない。', [
      Choice.h('引き受けて務める', '町衆に重んじられる。商いの手は止まる', () {
        _pay(g, 3);
        _net(g, 3);
        g.setFlag('cr_gyoji_took');
        _stamp(g, 'gyoji');
        return '町の帳面と木戸の鍵を預かった。夜回りの拍子木を打ちながら、町の家々の灯りを数えた。';
      }),
      Choice.h('銭を出して、ほかの者に代わってもらう', '商いは続けられる。町衆には軽く見られる', () {
        _pay(g, 4);
        _net(g, -2);
        g.setFlag('cr_gyoji_paid');
        _stamp(g, 'gyoji');
        return '隣の隠居が、銭を受け取って代わりに務めた。寄合で、あなたの席は少し下座になった。';
      }),
      if (l.mi >= 60 || l.sei >= 60)
        Choice.h('木戸と夜回りの決まりを町衆と話し合って改める', '才があれば町が守りやすくなる。古い者の反発を受ける', () {
          _stamp(g, 'gyoji');
          if (g.rng.chance(clampD(.45 + (l.mi + l.sei) / 600, .45, .85))) {
            _net(g, 5);
            _fame(g, 2);
            g.setFlag('cr_gyoji_kido');
            g.mark('月行事として、町の木戸と夜回りの決まりを町衆と改めた');
            return '辻ごとに夜回りの番を割り振り、木戸を閉める刻を決めた。その秋、隣町に押し込みが出たが、この町には入れなかった。';
          }
          g.setFlag('cr_gyoji_took');
          return '古い町衆が「昔からのやり方を変えるな」と言い張り、話はまとまらなかった。';
        }),
    ], after: next);
  }),

  _chain('cr_t_gyoji_after', 20, 70, _w2, crTown, (g, next) {
    final l = g.l;
    final kyo = g.l.region == '山城';
    final fest = kyo ? '祇園会' : '町の祭り';
    final who = g.hasFlag('cr_gyoji_paid') && !g.hasFlag('cr_gyoji_took') && !g.hasFlag('cr_gyoji_kido')
        ? '月行事の役を銭で逃れたあなたにも、今度ばかりは町衆が、話をつけてくれと詰め寄る。'
        : '月行事を務めたあなたに、町衆は話をつけてくれと言う。';
    g.ask('町の祭りと武家', '$festの支度のさなか、町に陣取った侍たちが、祭りの山車の通る道を塞いで動かない。$who侍は「町人の祭りなど知らぬ」と取り合わない。', [
      Choice.h('町衆を率いて侍の頭に掛け合う', '町の自治を示せる。侍を怒らせれば痛い目を見る', () {
        _stamp(g, 'gyoji');
        if (g.rng.chance(clampD(.4 + l.mi / 250, .4, .85))) {
          _net(g, 5);
          _fame(g, 4);
          g.setFlag('cr_machi_led');
          g.mark('$festのさなか、町衆を率いて侍に掛け合い、祭りの道を開けさせた');
          return '侍の頭は、町衆が束になって頭を下げるのを見て、ついに道を開けさせた。山車が通るとき、囃子がひときわ高く鳴った。';
        }
        _hurt(g, 8);
        _net(g, 2);
        return '侍は刀の鞘であなたを打ち据えた。それでも町衆は、あなたを担いで祭りの道を回った。';
      }),
      Choice.h('侍に酒と銭を届けて道を開けてもらう', '祭りは通る。侍に足元を見られる', () {
        _pay(g, 5);
        _stamp(g, 'gyoji');
        return '酒樽と銭を届けると、侍たちは笑って道を開けた。来年も同じことを求められるだろうと、町衆は囁き合った。';
      }),
      Choice.h('道を変えて祭りを通す', '揉め事は避けられる。古い習わしが崩れる', () {
        _net(g, -1);
        _stamp(g, 'gyoji');
        return '山車は、裏の細い道を窮屈そうに通った。年寄りたちは、昔はこんなことはなかったと嘆いた。';
      }),
    ], after: next);
  }),

  // ============================================ ひとつきり: 町の火事
  SceneDef('cr_t_kaji', 18, 75, (g) => _wTown * .9, crTown, (g, next) {
    g.ask('町の火事', '夜半、隣の町から火が出た。風に煽られて、火の粉がこちらの屋根に降り始めている。町衆は、火の通り道の家を壊して火を止めるしかないと言う。その一軒が、あなたの家だ。', [
      Choice.h('自分の家を壊させて火を止める', '町は救われる。家と家財を失う', () {
        _pay(g, 12);
        _net(g, 6);
        _fame(g, 4);
        g.setFlag('cr_kaji_broke');
        g.mark('町の火事の夜、火の通り道にあった自分の家を壊させて火を止めた');
        return '鳶口で柱が倒され、屋根が崩れた。火はそこで止まった。夜明けに焼け残った町を見て、町衆の一人が「お前の家が町を救った」と言った。';
      }),
      Choice.h('家財を運び出し、ほかの家を壊してくれと頼む', '家財は守れる。町衆との間にしこりが残る', () {
        _pay(g, 3);
        _net(g, -3);
        return '荷車に家財を積んで逃げた。火は二つ先の辻まで広がってから、ようやく止まった。';
      }),
      Choice.h('逃げ遅れた子がいないか、燃える家々を見て回る', '命を救えるかもしれない。火の中は危うい', () {
        if (g.rng.chance(.03)) {
          g.die('町の火事で、逃げ遅れた子を抱えたまま煙に呑まれた', 'sai');
          return '煙の向こうで、子の泣き声がした。';
        }
        _hurt(g, 10);
        _fame(g, 3);
        _net(g, 3);
        g.setFlag('cr_kaji_saved');
        g.mark('町の火事の夜、逃げ遅れた子を背負って煙の中から出てきた');
        return '煙の中から、子を背負って転がり出た。髪も眉も焼けていたが、子は泣き声を上げていた。';
      }),
    ], after: next);
  }),

  // ============================================ 筋: 裏の借家
  SceneDef('cr_t_shakuya', 22, 70, (g) => _wTown, crTown, (g, next) {
    final l = g.l;
    final b = _boy(g);
    _keepName(g, 'cr_ie_name:', b);
    g.ask('裏の借家', '店の裏に建てた借家の店子、$bが、三月も店賃を払っていない。戦で得意先の店が潰れ、仕事がないという。家には小さな子が三人いる。', [
      Choice.h('店賃を払えぬなら出ていってもらう', '筋は通る。町の者は冷たいと噂する', () {
        l.gold += 2;
        _net(g, -2);
        g.setFlag('cr_ie_out');
        _stamp(g, 'ie');
        return '$bの一家は、荷車一つに家財を積んで町を出ていった。';
      }),
      Choice.h('払えるようになるまで待つ', '情けは通る。銭は入らない', () {
        _pay(g, 2);
        _net(g, 2);
        g.setFlag('cr_ie_wait');
        _stamp(g, 'ie');
        return '「春まで待とう」と言うと、$bは土間に額をこすりつけた。';
      }),
      if (l.sei >= 55)
        Choice.h('知り合いの店に、$bの仕事を世話する', '才があれば両方が救われる。世話した先で揉めれば自分の顔が潰れる', () {
          _stamp(g, 'ie');
          if (g.rng.chance(clampD(.45 + l.sei / 250, .45, .85))) {
            _net(g, 4);
            l.gold += 2;
            g.setFlag('cr_ie_work');
            g.mark('店賃の払えぬ店子に、知り合いの店の仕事を世話した');
            return '問屋の荷運びの口を世話した。$bはその月のうちに、溜まった店賃を少しずつ払い始めた。';
          }
          g.setFlag('cr_ie_wait');
          return '世話した店で$bは喧嘩をして、三日で戻ってきた。結局、春まで待つことにした。';
        }),
    ], after: next);
  }),

  _chain('cr_t_shakuya_after', 25, 75, _w2, crTown, (g, next) {
    final l = g.l;
    final b = _named(g, 'cr_ie_name:', '店子');
    if (g.hasFlag('cr_ie_out')) {
      g.ask('出ていった店子', '追い出した店子の$bが、隣の町で死んだと聞いた。残された子らは、寺の門前で物乞いをしているという。', [
        Choice.h('子らを引き取り、店で使う', '償いになる。食い扶持は増える', () {
          _pay(g, 4);
          _net(g, 3);
          g.j(2);
          g.setFlag('cr_ie_kids');
          _stamp(g, 'ie');
          g.mark('かつて追い出した店子の遺した子らを引き取り、店で使った');
          return '寺の門前で、痩せた三人の子を見つけた。上の子は、あなたの顔を覚えていた。';
        }),
        Choice.h('寺に米を届ける', '少しは心が軽くなる', () {
          _pay(g, 2);
          _stamp(g, 'ie');
          return '寺に米を一俵届けた。住持は、何も聞かずに受け取った。';
        }),
        Choice.h('聞かなかったことにする', '何も変わらない', () {
          g.j(-2);
          _stamp(g, 'ie');
          return 'その夜は、なかなか寝つけなかった。';
        }),
      ], after: next);
      return;
    }
    g.ask('店子の恩', '店賃を待ってやった店子の$bは、いまでは問屋の荷を任される身になった。この冬、あなたの店の得意先が潰れて、売り掛けが戻らない。$bが、話を聞いて訪ねてきた。', [
      Choice.h('$bの申し出を受け、問屋に口を利いてもらう', '店が持ち直すかもしれない。恩を返させることになる', () {
        l.gold += 8;
        _net(g, 3);
        g.setFlag('cr_ie_repaid');
        _stamp(g, 'ie');
        g.mark('かつて店賃を待った店子に、店の窮地を救われた');
        return '$bの口利きで、問屋が新しい得意先を回してくれた。$bは「春まで待ってくだすった恩です」とだけ言った。';
      }),
      Choice.h('気持ちだけ受け取る', '恩着せがましくならない。店は苦しいまま', () {
        g.j(2);
        _pay(g, 2);
        _stamp(g, 'ie');
        return '$bは、それでもと言って、酒を一升置いていった。';
      }),
    ], after: next);
  }),

  // ============================================ ひとつきり: 南蛮の品（一五六〇年から）
  SceneDef('cr_t_nanban', 20, 70, (g) => _wTown * .8, crTown, (g, next) {
    final l = g.l;
    g.ask('南蛮の品', '堺から来た商人が、南蛮渡りの眼鏡や玻璃の盃、金平糖を町の店に卸したいと言ってきた。町の年寄の中には、伴天連の怪しい品を町に入れるなと言う者もいる。', [
      Choice.h('店先に並べて売る', '珍しさで客が集まる。年寄たちに睨まれる', () {
        l.gold += 6;
        _net(g, -2);
        g.setFlag('cr_nanban_sold');
        return '店先に玻璃の盃を並べると、見物の人垣ができた。寄合では、年寄の一人があなたの方を見ずに「町の風が乱れる」と言った。';
      }),
      Choice.h('金平糖だけを置く', '角は立たない。儲けは小さい', () {
        l.gold += 2;
        g.j(1);
        return '金平糖は、町の子らの小遣いで少しずつ売れていった。';
      }),
      Choice.h('断る', '町の年寄の覚えはよい。商いの風には乗り遅れる', () {
        _net(g, 1);
        return '商人は肩をすくめ、隣の町へ荷を運んでいった。';
      }),
      if (l.chi >= 55)
        Choice.h('眼鏡を自ら試し、目の弱った職人や筆耕に勧める', '才が当たれば町の役に立つ品になる。怪しい物と噂されることもある', () {
          if (g.rng.chance(clampD(.45 + l.chi / 300, .45, .85))) {
            l.gold += 5;
            _net(g, 3);
            g.setFlag('cr_nanban_glasses');
            g.mark('南蛮の眼鏡を町の老いた職人や筆耕に勧め、細かな仕事を続けさせた');
            return '目の弱った老いた筆耕が、眼鏡をかけて帳面を読み、声を上げて笑った。年寄たちも、それきり何も言わなくなった。';
          }
          _net(g, -2);
          return '眼鏡をかけた者の目がつぶれたという噂が流れ、誰も手に取らなくなった。';
        }),
    ], after: next);
  }, ageOk: (g, a) => g.l.startYear + a >= 1560),

  // ============================================ ひとつきり: 門前町
  SceneDef('cr_t_monzen', 20, 70, (g) => _wTown * .8, crTown, (g, next) {
    final l = g.l;
    g.ask('門前の地子', '町は大きな寺社の門前にあり、家の建つ地は寺社のものだ。寺社の役人が、地子を今年から二割増しにすると触れてきた。参詣の客が減って、町も苦しい。', [
      Choice.h('町衆と寺社へ減免を願い出る', '通れば町が楽になる。寺社に睨まれるかもしれない', () {
        if (g.rng.chance(clampD(.35 + l.mi / 250 + l.sei / 400, .35, .8))) {
          _net(g, 4);
          l.gold += 3;
          g.setFlag('cr_monzen_won');
          g.mark('門前の町衆と寺社へ願い出て、地子の増しを取りやめさせた');
          return '町衆の連判を携えて寺社の役所へ出向いた。役人は渋い顔をしたが、参詣の客が減っては寺社も困ると、増しを見送った。';
        }
        _pay(g, 4);
        g.j(-2);
        return '役人は願いを聞き置いただけで、地子は増やされた。願い出た者の名は、寺社の帳面に残された。';
      }),
      Choice.h('黙って払う', '波風は立たない。暮らしは苦しくなる', () {
        _pay(g, 5);
        return '言われたとおりに地子を納めた。町の誰もが、同じように黙って払った。';
      }),
      if (l.chi >= 55)
        Choice.h('参詣の客を増やす工夫を町衆に持ちかける', '才が当たれば町も寺社も潤う。外れれば笑い者になる', () {
          if (g.rng.chance(clampD(.4 + l.chi / 300, .4, .8))) {
            l.gold += 6;
            _net(g, 3);
            _fame(g, 2);
            g.setFlag('cr_monzen_fair');
            g.mark('門前の町衆に持ちかけて縁日の市を開き、参詣の客を呼び戻した');
            return '月に一度、門前に縁日の市を立てることにした。人が戻ると、寺社の役人も地子の話をしなくなった。';
          }
          _pay(g, 3);
          return '縁日の市を立てたが、雨続きで人は集まらなかった。';
        }),
    ], after: next);
  }),
];
